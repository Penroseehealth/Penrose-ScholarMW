"""Cycle solve problems properly: New question -> pick example -> measure.
Covers several graph families in dark theme.
"""

import asyncio
import base64
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

PREP = r"""
(async () => {
  function sleep(m){return new Promise(r=>setTimeout(r,m));}
  function txt(e){return (e.textContent||"").replace(/\s+/g," ").trim();}
  function setVal(el,v){
    var p = el instanceof HTMLSelectElement ? HTMLSelectElement.prototype
      : el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype
      : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(p,"value").set.call(el,v);
    el.dispatchEvent(new Event("input",{bubbles:true}));
    el.dispatchEvent(new Event("change",{bubbles:true}));
  }
  for(var i=0;i<30;i++){
    var inp=document.querySelector('input[type="text"], input:not([type])');
    if(inp && !inp.value) setVal(inp,"Verify");
    var go=[...document.querySelectorAll("button")].find(b=>txt(b)==="Let's go");
    if(go) go.click();
    await sleep(300);
    if(!document.body.textContent.includes("Welcome")) break;
  }
  var role=document.querySelector("select.role");
  if(role){ setVal(role,"solve"); await sleep(1200); }
  return {role:(document.querySelector("select.role")||{}).value,
          examples:[...document.querySelectorAll(".ex")].map(b=>txt(b).slice(0,56))};
})()
"""

PICK = r"""
(async (idx) => {
  function sleep(m){return new Promise(r=>setTimeout(r,m));}
  function txt(e){return (e.textContent||"").replace(/\s+/g," ").trim();}
  var out={};
  // back to the input card if a problem is already open
  var back=[...document.querySelectorAll("button")].find(b=>txt(b).indexOf("New question")!==-1 && b.offsetParent!==null);
  if(back){ back.click(); out.reset=true; await sleep(900); }
  var ex=[...document.querySelectorAll(".ex")];
  if(!ex[idx]){ out.err="no example "+idx+" (have "+ex.length+")"; return out; }
  out.text=txt(ex[idx]).slice(0,58);
  ex[idx].click();
  for(var j=0;j<45;j++){ await sleep(500); if(document.querySelector(".board svg")) break; }
  await sleep(800);
  out.title=txt(document.querySelector(".board strong")||{textContent:""});
  out.shapes=document.querySelectorAll(".board svg *").length;
  out.texts=document.querySelectorAll(".board svg text").length;
  out.workingCls=(document.querySelector(".working")||{}).className||null;
  return out;
})()
"""

MEASURE = r"""
(() => {
  function parse(c){var m=/rgba?\(([^)]+)\)/.exec(c||""); if(!m)return null;
    var p=m[1].split(",").map(s=>parseFloat(s)); return {r:p[0],g:p[1],b:p[2],a:p.length>3?p[3]:1};}
  function lum(c){return 0.2126*c.r+0.7152*c.g+0.0722*c.b;}
  function txt(e){return (e.textContent||"").replace(/\s+/g," ").trim();}
  var out={light:[],labels:[],surfaces:[]};
  document.querySelectorAll("body *").forEach(function(el){
    var r=el.getBoundingClientRect();
    if(r.width<6||r.height<6) return;
    var cs=getComputedStyle(el);
    if(cs.visibility==="hidden"||cs.display==="none") return;
    var bg=parse(cs.backgroundColor);
    if(bg && bg.a>0.15 && lum(bg)>140){
      out.light.push({cls:(el.className||"").toString().slice(0,44),bg:cs.backgroundColor,
        box:[Math.round(r.x),Math.round(r.y),Math.round(r.width),Math.round(r.height)],txt:txt(el).slice(0,40)});
    }
  });
  document.querySelectorAll(".canvas-wrap svg text").forEach(function(t){
    var cs=getComputedStyle(t), r=t.getBoundingClientRect();
    if(r.width<1) return;
    out.labels.push({txt:(t.textContent||"").slice(0,16),fill:cs.fill,stroke:cs.stroke,fw:cs.fontWeight});
  });
  [".board",".working.paper",".workspace.fullscreen",".canvas-wrap svg"].forEach(function(s){
    document.querySelectorAll(s).forEach(function(el){
      var cs=getComputedStyle(el);
      out.surfaces.push({sel:s,bg:cs.backgroundColor,color:cs.color});
    });
  });
  return out;
})()
"""


async def main():
    import tempfile

    prof = tempfile.mkdtemp(prefix="pmw_ex_")
    cerr = open("/tmp/pmw_ex.log", "wb")
    proc = subprocess.Popen(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            f"--remote-debugging-port={PORT}",
            f"--user-data-dir={prof}",
            "--window-size=1600,900",
            "about:blank",
        ],
        stdout=cerr,
        stderr=cerr,
    )
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
            print("FAIL: no target")
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

            async def shot(n):
                r = await cmd("Page.captureScreenshot", {"format": "png"})
                open(n, "wb").write(base64.b64decode(r["data"]))
                print("   shot:", n)

            await cmd("Page.enable")
            await cmd(
                "Emulation.setDeviceMetricsOverride",
                {"width": 1600, "height": 900, "deviceScaleFactor": 1, "mobile": False},
            )
            await cmd(
                "Page.navigate", {"url": BASE + "mathsdrill/index.html?theme=dark"}
            )
            for _ in range(45):
                await asyncio.sleep(1)
                if await ev("!!document.querySelector('input')"):
                    break
            await asyncio.sleep(1)
            p = await ev(PREP, True)
            print(
                "PREP:",
                json.dumps({k: v for k, v in (p or {}).items()}, ensure_ascii=False)[
                    :900
                ],
            )
            await asyncio.sleep(1)

            report = {}
            for idx in (1, 4, 6, 7, 3):
                print("-" * 64)
                st = await ev(PICK.rsplit("})", 1)[0] + "})(" + str(idx) + ")", True)
                if not isinstance(st, dict) or st.get("error") or st.get("err"):
                    print(
                        "  idx",
                        idx,
                        "-> skipped:",
                        json.dumps(st, ensure_ascii=False)[:200],
                    )
                    continue
                print("  idx %d -> %r" % (idx, st.get("text", "")))
                print(
                    "     title:",
                    st.get("title"),
                    "| shapes:",
                    st.get("shapes"),
                    "| texts:",
                    st.get("texts"),
                )
                await asyncio.sleep(1)
                m = await ev(MEASURE)
                if not isinstance(m, dict) or "error" in m:
                    print("     measure error:", m)
                    continue
                print("     light surfaces:", len(m.get("light", [])))
                for L in m.get("light", [])[:6]:
                    print("        %-42s %-22s %s" % (L["cls"][:42], L["bg"], L["box"]))
                labs = m.get("labels", [])
                u = {}
                for lab in labs:
                    u[(lab["fill"], lab["stroke"])] = (
                        u.get((lab["fill"], lab["stroke"]), 0) + 1
                    )
                print("     labels:", len(labs))
                for k, v in sorted(u.items(), key=lambda x: -x[1]):
                    print("        fill=%-22s stroke=%-18s x%d" % (k[0], k[1], v))
                ss = {}
                for s2 in m.get("surfaces", []):
                    ss[s2["sel"]] = s2["bg"]
                print("     surfaces:", json.dumps(ss))
                report[str(idx)] = {
                    "state": st,
                    "light": m.get("light", []),
                    "labels": labs,
                    "surfaces": ss,
                }
                if idx in (6, 7):
                    await shot(".ex_%d.png" % idx)
            json.dump(
                report,
                open(".ex_report.json", "w", encoding="utf8"),
                ensure_ascii=False,
                indent=1,
            )
            print("\nwrote .ex_report.json")
            return 0
    finally:
        proc.kill()


sys.exit(asyncio.run(main()))
