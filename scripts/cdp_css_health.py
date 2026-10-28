"""Health check for the dark-theme stylesheet:
* every rule in theme-dark.css actually parsed (a malformed rule is
  silently dropped by CSS — count must match the source)
* no console errors / CSS parse warnings while the solve section renders
"""

import asyncio
import json
import os
import socket
import subprocess
import sys
import urllib.request

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
BASE = "http://127.0.0.1:8000/"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "frontend", "web", "mathsdrill", "assets", "theme-dark.css")
_sk = socket.socket()
_sk.bind(("127.0.0.1", 0))
PORT = _sk.getsockname()[1]
_sk.close()

PROBE = r"""
(() => {
  var out={sheets:[],theme:document.documentElement.dataset.theme||"light"};
  for(var i=0;i<document.styleSheets.length;i++){
    var sh=document.styleSheets[i];
    var href=sh.href||"";
    if(href.indexOf("theme-dark")===-1) continue;
    var n=-1, err=null;
    try{ n=sh.cssRules.length; }catch(e){ err=String(e); }
    out.sheets.push({href:href.split("/").pop(), rules:n, err:err});
  }
  return out;
})()
"""


def source_rule_count():
    css = open(SRC, encoding="utf8").read()
    # no @media / nesting in this file -> one closing brace per top-level rule
    return css.count("}")


async def main():
    import tempfile

    expected = source_rule_count()
    prof = tempfile.mkdtemp(prefix="pmw_css_")
    cerr = open("/tmp/pmw_css.log", "wb")
    proc = subprocess.Popen(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            f"--remote-debugging-port={PORT}",
            f"--user-data-dir={prof}",
            "--window-size=1400,900",
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

        async with websockets.connect(target, max_size=20_000_000) as ws:
            mid = 0
            console = []

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
                    # collect unsolicited console/log events
                    if msg.get("method") in (
                        "Runtime.consoleAPICalled",
                        "Log.entryAdded",
                    ):
                        console.append(msg.get("params", {}))

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
            await cmd("Log.enable")
            await cmd(
                "Emulation.setDeviceMetricsOverride",
                {"width": 1400, "height": 900, "deviceScaleFactor": 1, "mobile": False},
            )
            await cmd(
                "Page.navigate", {"url": BASE + "mathsdrill/index.html?theme=dark"}
            )
            for _ in range(45):
                await asyncio.sleep(1)
                if await ev("!!document.querySelector('input')"):
                    break
            await asyncio.sleep(3)
            # force a stylesheet re-read
            await ev("""(() => {
              var l=[...document.querySelectorAll('link')].find(x=>x.href.indexOf('theme-dark')!==-1);
              return l ? l.sheet ? l.sheet.cssRules.length : -1 : -2;
            })()""")
            p = await ev(PROBE)
            await asyncio.sleep(2)
            print("source rules (closing braces):", expected)
            print("parsed:", json.dumps(p))
            parsed = None
            if isinstance(p, dict) and p.get("sheets"):
                parsed = p["sheets"][0]["rules"]
            ok = parsed == expected
            print("RULES MATCH:", ok, "(", parsed, "vs", expected, ")")
            # console noise
            errors = [
                c
                for c in console
                if c.get("type") == "error"
                or (c.get("entry", {}).get("level") in ("error", "warning"))
            ]
            print("console error/warning entries:", len(errors))
            for c in errors[:10]:
                print("   ", json.dumps(c)[:300])
            return 0 if ok else 2
    finally:
        proc.kill()


sys.exit(asyncio.run(main()))
