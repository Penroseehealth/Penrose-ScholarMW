"""Quantify the reported bottom band: what is painted at the bottom of the
viewport, and how much vertical space is left empty, across viewport sizes
and in both calculation views (dark)."""

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

PROBE = """
(() => {
  function txt(e){ return e ? (e.textContent||"").replace(/\\s+/g," ").trim().slice(0,60) : null; }
  function R(sel){ var e=document.querySelector(sel); if(!e) return null;
    var r=e.getBoundingClientRect();
    return {y:Math.round(r.y), bottom:Math.round(r.bottom), h:Math.round(r.height), w:Math.round(r.width)}; }
  var vw=innerWidth, vh=innerHeight;
  var out={vw:vw, vh:vh, scrollH:Math.max(document.body.scrollHeight, document.documentElement.scrollHeight),
           bodyBg:getComputedStyle(document.body).backgroundColor, probes:[], rects:{}};

  // what is actually painted at the bottom of the screen?
  [0.1,0.3,0.5,0.7,0.9].forEach(function(fx){
    [5, 30, 80, 150].forEach(function(dy){
      var x=Math.round(vw*fx), y=vh-dy;
      var el=document.elementFromPoint(x,y);
      out.probes.push({x:x, y:y, hit: el ? (el.tagName+"."+(el.className||"").toString().slice(0,30)) : null,
        bg: el ? getComputedStyle(el).backgroundColor : null, txt: txt(el)});
    });
  });

  [".app-header",".mathdrill",".md-grid",".md-solution",".md-graph",".canvas-wrap",
   ".solve",".solve .workspace",".workspace.fullscreen",".workspace.fullscreen .panel",
   ".workspace.fullscreen .board",".board",".working",".app-main",".app-sidebar",
   ".solve-menu",".solve-dropdown"].forEach(function(s){
    out.rects[s]=R(s);
  });

  // deepest content bottom among main regions
  var maxB=0, who=null;
  [".mathdrill",".md-grid",".md-solution",".md-graph",".solve .workspace",".board",".working"]
    .forEach(function(s){ var r=out.rects[s]; if(r && r.bottom>maxB){maxB=r.bottom; who=s;} });
  out.contentBottom=maxB; out.contentBottomOf=who;
  out.gapToViewportBottom=vh-maxB;
  return out;
})()
"""

ENTER = """
async (mode) => {
  function sleep(m){ return new Promise(r => setTimeout(r, m)); }
  function txt(e){ return (e.textContent||"").replace(/\\s+/g," ").trim(); }
  function setVal(el, v){
    var p = el instanceof HTMLSelectElement ? HTMLSelectElement.prototype
      : el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype
      : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(p,"value").set.call(el, v);
    el.dispatchEvent(new Event("input",{bubbles:true}));
    el.dispatchEvent(new Event("change",{bubbles:true}));
  }
  for (var i=0;i<30;i++){
    var inp=document.querySelector('input[type="text"], input:not([type])');
    if (inp && !inp.value) setVal(inp,"Verify");
    var go=[...document.querySelectorAll("button")].find(b=>txt(b)==="Let's go");
    if (go) go.click();
    await sleep(300);
    if (!document.body.textContent.includes("Welcome")) break;
  }
  if (mode === "solve"){
    var role=document.querySelector("select.role");
    if (role){ setVal(role,"solve"); await sleep(1200); }
    var ex=[...document.querySelectorAll(".ex")][0];
    if (ex) ex.click();
    for (var j=0;j<45;j++){ await sleep(500); if (document.querySelector(".board svg")) break; }
    await sleep(700);
  }
  return true;
}
"""


async def main():
    import tempfile

    prof = tempfile.mkdtemp(prefix="pmw_gap_")
    cerr = open("/tmp/pmw_gap.log", "wb")
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

            sizes = [(1500, 900), (1920, 1080), (1366, 768), (1280, 720)]
            for mode, url in (
                ("solve", BASE + "mathsdrill/index.html?theme=dark"),
                (
                    "practice",
                    BASE + "mathsdrill/index.html?theme=dark&mdverify=diagram",
                ),
            ):
                for w, h in sizes:
                    await cmd("Page.enable")
                    await cmd("Runtime.enable")
                    await cmd(
                        "Emulation.setDeviceMetricsOverride",
                        {
                            "width": w,
                            "height": h,
                            "deviceScaleFactor": 1,
                            "mobile": False,
                        },
                    )
                    await cmd("Page.navigate", {"url": url})
                    for _ in range(60):
                        await asyncio.sleep(1)
                        if await ev("!!document.querySelector('input')"):
                            break
                    await asyncio.sleep(1)
                    await ev("(" + ENTER + ")('%s')" % mode, True)
                    await asyncio.sleep(2)
                    d = await ev(PROBE)
                    if not isinstance(d, dict) or d.get("error"):
                        print(mode, w, h, "ERR", d)
                        continue
                    print("=" * 70)
                    print(
                        "%s @ %dx%d  scrollH=%s vh=%s  contentBottom=%s (%s)  GAP=%s  bodyBg=%s"
                        % (
                            mode,
                            w,
                            h,
                            d.get("scrollH"),
                            d.get("vh"),
                            d.get("contentBottom"),
                            d.get("contentBottomOf"),
                            d.get("gapToViewportBottom"),
                            d.get("bodyBg"),
                        )
                    )
                    # what sits at the very bottom row
                    row = [p for p in d["probes"] if p["y"] == d["vh"] - 5]
                    for p in row:
                        print(
                            "    bottom x=%-5s -> %-34s bg=%-22s txt=%s"
                            % (p["x"], str(p["hit"]), str(p["bg"]), repr(p["txt"])[:40])
                        )
                    interesting = [
                        r
                        for r in (
                            "mathdrill",
                            ".solve .workspace",
                            ".workspace.fullscreen",
                            ".board",
                            ".working",
                            ".md-grid",
                        )
                        if d["rects"].get(r)
                    ]
                    for r in interesting:
                        print("    rect %-26s %s" % (r, d["rects"][r]))
            return 0
    finally:
        proc.kill()


sys.exit(asyncio.run(main()))
