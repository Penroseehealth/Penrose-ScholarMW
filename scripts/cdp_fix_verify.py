"""Post-fix verification of the two reported defects, dark + light.

Reaches the SOLVE role (header role select = "solve"), selects a problem by
clicking an example, then measures:
  A. any remaining light/white surface  (was: .board/.answer/.workspace #fff)
  B. SVG text fills + halo strokes        (was: black fill + 3.5px white halo)
  C. shape geometry unchanged            (CSS-only fix must not re-draw)
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

ENTER_AND_SOLVE = r"""
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
  // 1. leave the welcome gate
  for(var i=0;i<30;i++){
    var inp=document.querySelector('input[type="text"], input:not([type])');
    if(inp && !inp.value) setVal(inp,"Verify");
    var go=[...document.querySelectorAll("button")].find(b=>txt(b)==="Let's go");
    if(go) go.click();
    await sleep(320);
    if(!document.body.textContent.includes("Welcome")) { out.log.push("entered"); break; }
  }
  // 2. switch role -> Solve (this is what opens the .solve section)
  var role=document.querySelector("select.role, select[aria-label='Choose role']");
  if(!role){ out.roleMissing=true; return out; }
  out.roleBefore = role.value;
  setVal(role, "solve");
  await sleep(1200);
  out.roleAfter = document.querySelector("select.role").value;
  out.hasSolve = !!document.querySelector(".solve");
  out.hasQbox  = !!document.querySelector(".qbox");
  // 3. select a problem: type a geometry question with a length + an angle
  var q=document.querySelector("textarea.qbox, textarea");
  if(!q){ out.qboxMissing=true; return out; }
  setVal(q, "Draw a triangle with AB = 6, AC = 8 and angle A = 75 degrees");
  await sleep(300);
  var ask=[...document.querySelectorAll("button")].find(b=>txt(b).indexOf("Solve & draw")!==-1);
  if(!ask){ out.askMissing=true; return out; }
  out.ask = txt(ask);
  ask.click();
  out.log.push("asked");
  // 4. wait for the board + answer to materialise
  for(var j=0;j<40;j++){
    await sleep(500);
    if(document.querySelector(".board svg") && document.querySelector(".answer, .wtable")) break;
  }
  out.workspace = (document.querySelector("[class*=workspace]")||{}).className || null;
  out.boardClass = (document.querySelector(".board")||{}).className || null;
  out.steps = document.querySelectorAll(".working .step, .solution, .step").length;
  out.svgShapes = document.querySelectorAll(".board svg *").length;
  out.svgTexts = document.querySelectorAll(".board svg text").length;
  out.hasAnswer = !!document.querySelector(".answer");
  out.hasTable = !!document.querySelector(".wtable");
  out.body = txt(document.body).slice(0,600);
  return out;
})()
"""

MEASURE = r"""
(() => {
  function parse(c){var m=/rgba?\(([^)]+)\)/.exec(c||""); if(!m)return null;
    var p=m[1].split(",").map(s=>parseFloat(s)); return {r:p[0],g:p[1],b:p[2],a:p.length>3?p[3]:1};}
  function lum(c){return 0.2126*c.r+0.7152*c.g+0.0722*c.b;}
  function txt(e){return (e.textContent||"").replace(/\s+/g," ").trim();}
  var out={theme:document.documentElement.dataset.theme||"light",light:[],labels:[],halos:[],css:[]};
  var all=document.querySelectorAll("body *");
  for(var i=0;i<all.length;i++){
    var el=all[i], r=el.getBoundingClientRect();
    if(r.width<6||r.height<6) continue;
    var cs=getComputedStyle(el);
    if(cs.visibility==="hidden"||cs.display==="none") continue;
    var bg=parse(cs.backgroundColor);
    if(bg && bg.a>0.15 && lum(bg)>140){
      out.light.push({cls:(el.className||"").toString().slice(0,46),tag:el.tagName,
        bg:cs.backgroundColor,color:cs.color,box:[Math.round(r.x),Math.round(r.y),Math.round(r.width),Math.round(r.height)],
        txt:txt(el).slice(0,50)});
    }
  }
  // diagram labels
  document.querySelectorAll(".canvas-wrap svg text").forEach(function(t){
    var cs=getComputedStyle(t), r=t.getBoundingClientRect();
    if(r.width<1) return;
    out.labels.push({txt:(t.textContent||"").slice(0,16), fill:cs.fill, stroke:cs.stroke,
      strokeW:cs.strokeWidth, fw:cs.fontWeight, op:cs.opacity});
  });
  // key surfaces
  [".board",".answer",".workspace.fullscreen",".workspace.fullscreen.one",".workspace.fullscreen.two",
   ".ink-wrap",".wtable th",".wtable td",".canvas-wrap",".canvas-wrap svg",".panel"].forEach(function(s){
    document.querySelectorAll(s).forEach(function(el){
      var cs=getComputedStyle(el);
      out.css.push({sel:s,bg:cs.backgroundColor,color:cs.color,border:cs.borderTopColor});
    });
  });
  return out;
})()
"""


async def main():
    import tempfile

    prof = tempfile.mkdtemp(prefix="pmw_fix_")
    cerr = open("/tmp/pmw_fix.log", "wb")
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

            results = {}
            for theme in ("dark", "light"):
                print("=" * 66)
                print("THEME:", theme)
                await cmd(
                    "Page.navigate",
                    {"url": BASE + f"mathsdrill/index.html?theme={theme}"},
                )
                for _ in range(45):
                    await asyncio.sleep(1)
                    if await ev("!!document.querySelector('input')"):
                        break
                await asyncio.sleep(1)
                st = await ev(ENTER_AND_SOLVE, True)
                print(
                    "  state:",
                    json.dumps(
                        {k: v for k, v in (st or {}).items() if k != "body"},
                        ensure_ascii=False,
                    ),
                )
                if not isinstance(st, dict) or st.get("error"):
                    print("  ERROR:", st)
                    continue
                await asyncio.sleep(2)
                m = await ev(MEASURE)
                if not isinstance(m, dict) or "error" in m:
                    print("  measure error:", m)
                    continue
                print("  -- key surfaces --")
                seen = set()
                for c in m.get("css", []):
                    k = (c["sel"], c["bg"])
                    if k in seen:
                        continue
                    seen.add(k)
                    print(
                        "     %-26s bg=%-22s color=%-20s border=%s"
                        % (c["sel"], c["bg"], c["color"], c["border"])
                    )
                print("  -- LIGHT SURFACES (defect A) :", len(m.get("light", [])))
                for L in m.get("light", [])[:15]:
                    print(
                        "     %-42s bg=%-20s box=%s"
                        % (L["cls"][:42], L["bg"], L["box"])
                    )
                    if L["txt"]:
                        print("        txt:", L["txt"][:60])
                labs = m.get("labels", [])
                print("  -- DIAGRAM LABELS (defect B):", len(labs))
                u = {}
                for lab in labs:
                    u[(lab["fill"], lab["stroke"], lab["strokeW"])] = (
                        u.get((lab["fill"], lab["stroke"], lab["strokeW"]), 0) + 1
                    )
                for k, v in sorted(u.items(), key=lambda x: -x[1]):
                    print(
                        "     fill=%-20s stroke=%-16s w=%-5s x%d"
                        % (k[0], k[1], k[2], v)
                    )
                for lab in labs[:18]:
                    print(
                        "       %-14s fill=%-20s stroke=%-14s fw=%s"
                        % (repr(lab["txt"])[:14], lab["fill"], lab["stroke"], lab["fw"])
                    )
                results[theme] = {
                    "state": {k: v for k, v in st.items() if k != "body"},
                    "light": m.get("light", []),
                    "labels": labs,
                    "css": m.get("css", []),
                }
                await shot(f".fix_{theme}.png")
            json.dump(
                results,
                open(".fix_results.json", "w", encoding="utf8"),
                ensure_ascii=False,
                indent=1,
            )
            print("\nwrote .fix_results.json")
            return 0
    finally:
        proc.kill()


sys.exit(asyncio.run(main()))
