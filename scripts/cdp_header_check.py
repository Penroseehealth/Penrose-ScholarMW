"""Does the built Flutter shell hand the session token to the embedded app,
and what does the Mathsdrill app bar actually show now?"""

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

PROBE = """
(() => {
  var f = document.querySelector("iframe");
  var src = f ? (f.getAttribute("src") || "") : null;
  return {
    src: src,
    hasToken: src ? src.indexOf("token=") !== -1 : false,
    tokenLen: (src && src.indexOf("token=") !== -1)
      ? src.slice(src.indexOf("token=") + 6).split("&")[0].length : 0,
    flutterView: !!document.querySelector("flutter-view"),
    splash: (document.body.innerText || "").indexOf("Loading") !== -1,
  };
})()
"""


async def main():
    import tempfile

    prof = tempfile.mkdtemp(prefix="pmw_hdr_")
    cerr = open("/tmp/pmw_hdr2.log", "wb")
    proc = subprocess.Popen(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            f"--remote-debugging-port={PORT}",
            f"--user-data-dir={prof}",
            "--window-size=1400,880",
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

            async def shot(n):
                r = await cmd("Page.captureScreenshot", {"format": "png"})
                open(n, "wb").write(base64.b64decode(r["data"]))
                print("  shot:", n)

            await cmd("Page.enable")
            await cmd("Runtime.enable")
            await cmd(
                "Emulation.setDeviceMetricsOverride",
                {"width": 1400, "height": 880, "deviceScaleFactor": 1, "mobile": False},
            )
            await cmd("Page.navigate", {"url": BASE + "#/mathsdrill"})
            # wait for real content (splash gone) — auth round-trip + route build
            state = None
            for _ in range(60):
                await asyncio.sleep(2)
                state = await ev(PROBE)
                if (
                    isinstance(state, dict)
                    and state.get("flutterView")
                    and not state.get("splash")
                ):
                    break
            await asyncio.sleep(4)
            state = await ev(PROBE)
            print("state:", json.dumps(state, ensure_ascii=False))
            await shot(".hdr_appbar.png")

            # embedded app loaded?
            await ev(
                """
              (async () => {
                function sleep(m){ return new Promise(r=>setTimeout(r,m)); }
                for (var i=0;i<25;i++){
                  var f=document.querySelector('iframe');
                  try { if (f && f.contentDocument && f.contentDocument.querySelector('input')) return true; }
                  catch(e){ return true; }   // cross-origin: frame is alive
                  await sleep(500);
                }
                return false;
              })()
            """,
                True,
            )
            return 0
    finally:
        proc.kill()


sys.exit(asyncio.run(main()))
