"""Find every near-black font rendered on a dark surface, across all views
(dark theme): welcome, practice, solve + gear popup, settings, dashboard,
progress, past papers. Reports HTML colour and SVG fill separately."""

import asyncio
import json
import socket
import subprocess
import sys
import urllib.request

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
BASE = "http://127.0.0.1:8000/"
_sk = socket.socket()
_sk.bind(("127.0.0.1", 0))
PORT = _sk.getsockname()[1]
_sk.close()

SCAN = r"""
(() => {
  function lum(c){
    var m=/rgba?\(([^)]+)\)/.exec(c||""); if(!m) return null;
    var p=m[1].split(",").map(s=>parseFloat(s));
    if(p.length>3 && p[3]<0.15) return null;
    return 0.2126*p[0]+0.7152*p[1]+0.0722*p[2];
  }
  function txt(e){ return (e.textContent||"").replace(/\s+/g," ").trim().slice(0,56); }
  function bgOf(el){
    var n=el, hops=0;
    while(n && hops++<8){
      var v=lum(getComputedStyle(n).backgroundColor);
      if(v!==null) return {v:v, who:(n.tagName+"."+((n.className||"")+"").slice(0,30))};
      n=n.parentElement;
    }
    return {v: lum(getComputedStyle(document.body).backgroundColor), who:"body"};
  }
  var bad={html:[], svg:[]};
  document.querySelectorAll("body *").forEach(function(el){
    if(el.namespaceURI && el.namespaceURI.indexOf("svg")!==-1 && el.tagName!=="text") return;
    var r=el.getBoundingClientRect();
    if(r.width<2||r.height<2) return;
    var cs=getComputedStyle(el);
    if(cs.visibility==="hidden"||cs.display==="none"||cs.opacity==="0") return;
    var isSvgText = (el.tagName==="text"||el.tagName==="tspan");
    // judge TEXT only: controls that paint a box or a swatch (checkbox, colour
    // picker, range…) carry a default colour no user ever reads as font
    if(el.tagName==="INPUT"){
      var ty=(el.type||"text").toLowerCase();
      if(["checkbox","radio","color","range","file","image","reset"].indexOf(ty)!==-1) return;
    }
    if(!txt(el)) return;                                  // must carry visible text
    var fg = lum(isSvgText ? cs.fill : cs.color);
    if(fg===null || fg>=60) return;                       // only near-black ink
    var b=bgOf(el);
    if(b.v===null || b.v>=60) return;                     // only on a dark surface
    bad[isSvgText?"svg":"html"].push({
      tag:el.tagName, cls:((el.className.baseVal!==undefined?el.className.baseVal:el.className)||"")+"",
      ink: isSvgText?cs.fill:cs.color, surface:b.who, surfaceLum:Math.round(b.v),
      box:[Math.round(r.x),Math.round(r.y),Math.round(r.width),Math.round(r.height)],
      txt:txt(el)});
  });
  return bad;
})()
"""

ENTER = """
async (mode) => {
  function sleep(m){ return new Promise(r=>setTimeout(r,m)); }
  function txt(e){ return (e.textContent||"").replace(/\\s+/g," ").trim(); }
  function setVal(el,v){
    var p = el instanceof HTMLSelectElement ? HTMLSelectElement.prototype
      : el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype
      : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(p,"value").set.call(el,v);
    el.dispatchEvent(new Event("input",{bubbles:true}));
    el.dispatchEvent(new Event("change",{bubbles:true}));
  }
  var out={};
  for (var i=0;i<30;i++){
    var inp=document.querySelector('input[type="text"], input:not([type])');
    if(inp && !inp.value) setVal(inp,"Verify");
    var go=[...document.querySelectorAll("button")].find(b=>txt(b)==="Let's go");
    if(go) go.click();
    await sleep(300);
    if(!document.body.textContent.includes("Welcome")) break;
  }
  function nav(label){
    var b=[...document.querySelectorAll("button,a")].find(x=>txt(x)===label && x.offsetParent!==null);
    if(b){ b.click(); return label; }
    return null;
  }
  if(mode==="solve"){
    var role=document.querySelector("select.role");
    if(role){ setVal(role,"solve"); await sleep(1200); }
    out.role=(document.querySelector("select.role")||{}).value;
    var ex=[...document.querySelectorAll(".ex")][0];
    if(ex) ex.click();
    for(var j=0;j<45;j++){ await sleep(500); if(document.querySelector(".board svg")) break; }
    await sleep(700);
    var gear=document.querySelector(".solve-menu .gear");
    if(gear){ gear.click(); out.gear=true; await sleep(600); }
  } else if(mode==="settings"){ out.nav=nav("Settings"); await sleep(1200); }
  else if(mode==="dashboard"){ out.nav=nav("Dashboard"); await sleep(1200); }
  else if(mode==="progress"){ out.nav=nav("My Progress"); await sleep(1500); }
  else if(mode==="papers"){ out.nav=nav("Past Papers"); await sleep(1500); }
  return out;
}
"""


async def main():
    import tempfile

    prof = tempfile.mkdtemp(prefix="pmw_blk_")
    cerr = open("/tmp/pmw_blk.log", "wb")
    proc = subprocess.Popen(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            f"--remote-debugging-port={PORT}",
            f"--user-data-dir={prof}",
            "--window-size=1500,900",
            "about:blank",
        ],
        stdout=cerr,
        stderr=cerr,
    )
    total = {"html": 0, "svg": 0}
    try:
        target = None
        for _ in range(60):
            try:
                with urllib.request.urlopen(
                    f"http://127.0.0.1:{PORT}/json/list", timeout=2
                ) as r:
                    tabs = [t for t in json.load(r) if t.get("type") == "page"]
                if tabs:
                    target = tabs[0]["webSocketDebuggerUrl"]
                    break
            except Exception:
                pass
            await asyncio.sleep(0.5)
        if not target:
            print("FAIL")
            return 1
        import websockets

        async with websockets.connect(target, max_size=30_000_000) as ws:
            mid = 0

            async def cmd(m, p=None):
                nonlocal mid
                mid += 1
                await ws.send(json.dumps({"id": mid, "method": m, "params": p or {}}))
                while True:
                    msg = json.loads(await ws.recv())
                    if msg.get("id") == mid:
                        if "error" in msg:
                            raise RuntimeError(msg["error"])
                        return msg.get("result", {})

            async def ev(e, ap=False):
                r = await cmd(
                    "Runtime.evaluate",
                    {"expression": e, "returnByValue": True, "awaitPromise": ap},
                )
                res = r.get("result", {})
                if res.get("subtype") == "error":
                    return {"error": str(res.get("description"))}
                return res.get("value")

            await cmd("Page.enable")
            await cmd("Runtime.enable")
            await cmd(
                "Emulation.setDeviceMetricsOverride",
                {"width": 1500, "height": 900, "deviceScaleFactor": 1, "mobile": False},
            )
            await cmd(
                "Page.navigate",
                {"url": BASE + "mathsdrill/index.html?theme=dark&mdverify=diagram"},
            )
            for _ in range(80):
                await asyncio.sleep(1)
                if await ev("document.title") == "MDVERIFYREADY":
                    break
            await asyncio.sleep(3)

            # welcome/first-run already passed by mdverify walker -> now walk views
            views = [
                ("practice", None),
                ("solve", None),
                ("settings", None),
                ("dashboard", None),
                ("progress", None),
                ("papers", None),
            ]
            for mode, _x in views:
                st = await ev("(" + ENTER + ")('%s')" % mode, True)
                await asyncio.sleep(2)
                b = await ev(SCAN)
                if not isinstance(b, dict) or b.get("error"):
                    print(mode, "ERR", b)
                    continue
                html_n = len(b.get("html", []))
                svg_n = len(b.get("svg", []))
                n = html_n + svg_n
                total["html"] += html_n
                total["svg"] += svg_n
                print("=" * 70)
                print(
                    "%s -> near-black on dark: html=%d svg=%d total=%d   state=%s"
                    % (
                        mode,
                        html_n,
                        svg_n,
                        n,
                        json.dumps(st, ensure_ascii=False)[:140],
                    )
                )
                for kind in ("html", "svg"):
                    seen = set()
                    for x in b.get(kind, [])[:40]:
                        key = (x["cls"][:30], x["ink"], x["surface"])
                        if key in seen:
                            continue
                        seen.add(key)
                        print(
                            "   [%s] %-26s ink=%-18s surface=%-28s %s %s"
                            % (
                                kind,
                                x["cls"][:26],
                                x["ink"],
                                x["surface"][:28],
                                x["box"],
                                repr(x["txt"])[:44],
                            )
                        )
            print("=" * 70)
            print(
                "TOTAL near-black-on-dark: html=%d svg=%d"
                % (total["html"], total["svg"])
            )
            return 0
    finally:
        proc.kill()


sys.exit(asyncio.run(main()))
