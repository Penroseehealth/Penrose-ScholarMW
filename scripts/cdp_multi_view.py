"""Multi-view dark-theme sweep after the solve-section fix.

For each solve example: click it, then measure light surfaces + diagram
label fills + shape counts. Also covers Settings (preview) and the practice
graph view to prove no regression.
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
  var out={log:[]};
  for(var i=0;i<30;i++){
    var inp=document.querySelector('input[type="text"], input:not([type])');
    if(inp && !inp.value) setVal(inp,"Verify");
    var go=[...document.querySelectorAll("button")].find(b=>txt(b)==="Let's go");
    if(go) go.click();
    await sleep(300);
    if(!document.body.textContent.includes("Welcome")){out.log.push("entered");break;}
  }
  var role=document.querySelector("select.role");
  if(role){ setVal(role,"solve"); await sleep(1000); out.role=role.value; }
  out.examples=[...document.querySelectorAll(".ex")].map(b=>txt(b).slice(0,58));
  return out;
})()
"""

ASK = r"""
(async (idx) => {
  function sleep(m){return new Promise(r=>setTimeout(r,m));}
  function txt(e){return (e.textContent||"").replace(/\s+/g," ").trim();}
  function setVal(el,v){
    var p = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(p,"value").set.call(el,v);
    el.dispatchEvent(new Event("input",{bubbles:true}));
    el.dispatchEvent(new Event("change",{bubbles:true}));
  }
  var out={};
  var ex=[...document.querySelectorAll(".ex")][idx];
  if(ex){ out.used="example"; out.text=txt(ex).slice(0,60); ex.click(); }
  else { out.err="no .ex example at index "+idx; return out; }
  for(var j=0;j<45;j++){
    await sleep(500);
    if(document.querySelector(".board svg")) break;
  }
  await sleep(700);
  out.workspace=(document.querySelector("[class*=workspace]")||{}).className||null;
  out.title=txt(document.querySelector(".board strong")||{textContent:""});
  out.shapes=document.querySelectorAll(".board svg *").length;
  out.texts=document.querySelectorAll(".board svg text").length;
  out.hasAnswer=!!document.querySelector(".answer");
  out.hasTable=!!document.querySelector(".wtable");
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
      out.light.push({cls:(el.className||"").toString().slice(0,46),bg:cs.backgroundColor,
        color:cs.color,box:[Math.round(r.x),Math.round(r.y),Math.round(r.width),Math.round(r.height)],
        txt:txt(el).slice(0,44)});
    }
  });
  document.querySelectorAll(".canvas-wrap svg text").forEach(function(t){
    var cs=getComputedStyle(t), r=t.getBoundingClientRect();
    if(r.width<1) return;
    out.labels.push({txt:(t.textContent||"").slice(0,16),fill:cs.fill,stroke:cs.stroke,strokeW:cs.strokeWidth,fw:cs.fontWeight});
  });
  [".board",".answer",".wtable th",".wtable td",".working",".working.paper",".workspace.fullscreen",
   ".ink-wrap",".canvas-wrap svg",".setting-preview",".setting-preview .working",".md-card",".md-graph .canvas-wrap svg"
  ].forEach(function(s){
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

    prof = tempfile.mkdtemp(prefix="pmw_mv_")
    cerr = open("/tmp/pmw_mv.log", "wb")
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

            report = {}

            def summarise(tag, m, st=None):
                if not isinstance(m, dict) or "error" in m:
                    print("   ERROR:", m)
                    report[tag] = {"error": str(m)}
                    return
                print("   light surfaces:", len(m.get("light", [])))
                for L in m.get("light", [])[:8]:
                    print("      %-44s %-22s %s" % (L["cls"][:44], L["bg"], L["box"]))
                    if L["txt"]:
                        print("         txt:", L["txt"][:52])
                labs = m.get("labels", [])
                u = {}
                for lab in labs:
                    u[(lab["fill"], lab["stroke"])] = (
                        u.get((lab["fill"], lab["stroke"]), 0) + 1
                    )
                print("   labels:", len(labs))
                for k, v in sorted(u.items(), key=lambda x: -x[1]):
                    print("      fill=%-22s stroke=%-18s x%d" % (k[0], k[1], v))
                print("   surfaces:")
                seen = set()
                for s2 in m.get("surfaces", []):
                    key = (s2["sel"], s2["bg"])
                    if key in seen:
                        continue
                    seen.add(key)
                    print(
                        "      %-30s bg=%-22s color=%s"
                        % (s2["sel"][:30], s2["bg"], s2["color"])
                    )
                report[tag] = {
                    "state": st,
                    "light": m.get("light", []),
                    "labels": labs,
                    "surfaces": m.get("surfaces", []),
                }

            # ---------- DARK: solve examples ----------
            await cmd(
                "Page.navigate", {"url": BASE + "mathsdrill/index.html?theme=dark"}
            )
            for _ in range(45):
                await asyncio.sleep(1)
                if await ev("!!document.querySelector('input')"):
                    break
            await asyncio.sleep(1)
            prep = await ev(PREP, True)
            print("=" * 66)
            print(
                "PREP:",
                json.dumps(
                    {k: v for k, v in prep.items() if k != "log"}, ensure_ascii=False
                )[:600],
            )
            await asyncio.sleep(1)

            for idx, name in (
                (0, "solve_lp"),
                (6, "solve_quadratic"),
                (7, "solve_simultaneous"),
            ):
                print("-" * 60)
                print("EXAMPLE", idx, "->", name)
                # ASK is an IIFE ending in "})()" — strip the call, then invoke with idx
                st = await ev(ASK.rsplit("})", 1)[0] + "})(" + str(idx) + ")", True)
                print(
                    "   state:",
                    json.dumps(
                        {
                            k: v
                            for k, v in (st or {}).items()
                            if k
                            in (
                                "used",
                                "text",
                                "workspace",
                                "title",
                                "shapes",
                                "texts",
                                "hasAnswer",
                                "hasTable",
                                "workingCls",
                                "err",
                            )
                        },
                        ensure_ascii=False,
                    )[:420],
                )
                await asyncio.sleep(1)
                m = await ev(MEASURE)
                summarise(name, m, st)
                if name == "solve_quadratic":
                    await shot(".mv_dark_quadratic.png")
                if name == "solve_lp":
                    await shot(".mv_dark_lp.png")

            # ---------- DARK: Settings (preview panel) ----------
            await cmd(
                "Page.navigate",
                {"url": BASE + "mathsdrill/index.html?theme=dark&mdverify=steps"},
            )
            for _ in range(60):
                await asyncio.sleep(1)
                t = await ev("document.title")
                if isinstance(t, str) and "MDVERIFY" in t:
                    break
            await asyncio.sleep(2)
            m = await ev(MEASURE)
            summarise("settings", m, {"title": await ev("document.title")})
            await shot(".mv_dark_settings.png")

            # ---------- DARK: practice graph view ----------
            await cmd(
                "Page.navigate",
                {"url": BASE + "mathsdrill/index.html?theme=dark&mdverify=diagram"},
            )
            for _ in range(70):
                await asyncio.sleep(1)
                t = await ev("document.title")
                if isinstance(t, str) and "MDVERIFY" in t:
                    break
            await asyncio.sleep(3)
            m = await ev(MEASURE)
            summarise("practice_graph", m, {"title": await ev("document.title")})
            await shot(".mv_dark_graph.png")

            json.dump(
                report,
                open(".mv_report.json", "w", encoding="utf8"),
                ensure_ascii=False,
                indent=1,
            )
            print("\nwrote .mv_report.json")
            return 0
    finally:
        proc.kill()


sys.exit(asyncio.run(main()))
