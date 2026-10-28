"""End-to-end verification of the AI-connected MathsDrill chat.

Covers: token delivery + scrubbing, the problem-entry panel staying pinned to
the bottom of the viewport *while a solution is being generated* (the solve
request is held open with CDP Fetch interception so the in-flight state can be
measured), the structured AI/tutor answer (steps + answer + graph/diagram), the
absence of the old "couldn't classify …" canned reply, and the honest message
when there is no session.
"""

import asyncio
import base64
import json
import socket
import subprocess
import sys
import urllib.request

# Windows consoles default to cp1252; model replies contain maths glyphs
# (e.g. "√") that would otherwise crash the run instead of just printing.
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
BASE = "http://127.0.0.1:8000/"
_sk = socket.socket()
_sk.bind(("127.0.0.1", 0))
PORT = _sk.getsockname()[1]
_sk.close()

CANNED = ["couldn’t classify", "couldn't classify", "Steps and the graph are ready"]

ENTER = """
async () => {
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
  var out = {entered:false};
  for (var i=0;i<30;i++){
    var inp=document.querySelector('input[type="text"], input:not([type])');
    if(inp && !inp.value) setVal(inp,"Verify");
    var go=[...document.querySelectorAll("button")].find(b=>txt(b)==="Let's go");
    if(go) go.click();
    await sleep(300);
    if(!document.body.textContent.includes("Welcome")){ out.entered=true; break; }
  }
  var role=document.querySelector("select.role");
  if(role){ setVal(role,"solve"); await sleep(1200); out.role=role.value; }
  return out;
}
"""

COMPOSER = """
(() => {
  var c = document.querySelector(".hpc-composer");
  if (!c) return {present:false};
  var r = c.getBoundingClientRect();
  var cs = getComputedStyle(c);
  var hit = document.elementFromPoint(Math.round(innerWidth/2), innerHeight-4);
  var send = document.querySelector(".hpc-send");
  return {
    present: true,
    hidden: c.hidden,
    position: cs.position,
    display: cs.display,
    bottom: Math.round(r.bottom),
    height: Math.round(r.height),
    viewportH: innerHeight,
    pinnedToViewport: Math.abs(r.bottom - innerHeight) <= 2,
    coversBottom: !!(hit && hit.closest && hit.closest(".hpc-composer")),
    busy: send ? send.getAttribute("aria-busy") : null,
    hpc: document.documentElement.dataset.hpc || null,
    searchText: (document.querySelector(".hpc-input")||{}).textContent || "",
  };
})()
"""

ASK = """
(text) => {
  var input = document.querySelector(".hpc-input");
  if (!input) return {ok:false, why:"no composer"};
  input.focus();
  document.execCommand("selectAll", false, null);
  document.execCommand("insertText", false, text);
  var send = document.querySelector(".hpc-send");
  if (!send) return {ok:false, why:"no button"};
  send.click();
  return {ok:true, text:(input.textContent||"").slice(0,60)};
}
"""

RESULT = """
(() => {
  function txt(e){ return (e.textContent||"").replace(/\\s+/g," ").trim(); }
  var bots = [...document.querySelectorAll(".hpc-msg.bot")];
  if (!bots.length) return {ready:false, pending: !!document.querySelector(".hpc-pending")};
  var m = bots[bots.length-1];
  var body = m.querySelector(".hpc-body");
  var canvas = m.querySelector(".hpc-graph canvas");
  var graphBox = m.querySelector(".hpc-graph");
  return {
    ready: true,
    text: txt(body).slice(0, 1200),
    steps: m.querySelectorAll(".hpc-step").length,
    stepTitles: [...m.querySelectorAll(".hpc-step-title")].map(e=>txt(e)).slice(0,8),
    workLines: [...m.querySelectorAll(".hpc-step-work")].map(e=>txt(e)).slice(0,8),
    answer: txt(m.querySelector(".hpc-answer-val") || {textContent:""}),
    badges: [...m.querySelectorAll(".hpc-badge")].map(e=>txt(e)),
    hasGraph: !!graphBox,
    graphH: graphBox ? Math.round(graphBox.getBoundingClientRect().height) : 0,
    canvasSize: canvas ? [canvas.width, canvas.height] : null,
    cap: txt(m.querySelector(".hpc-cap") || {textContent:""}),
    diagram: !!m.querySelector(".hpc-diagram svg"),
    diagramLabels: [...m.querySelectorAll(".hpc-diagram text")].map(e=>txt(e)),
    bar: !!m.querySelector(".hpc-dg-bar"),
    limitNote: !!m.querySelector(".hpc-limit"),
    hint: txt(m.querySelector(".hpc-hint") || {textContent:""}),
    pending: !!document.querySelector(".hpc-pending"),
    // the answer must be readable without scrolling (reveal() keeps it on screen)
    stepsInView: (function () {
      var t = m.querySelector(".hpc-step-title");
      if (!t) return false;
      var r = t.getBoundingClientRect();
      return r.top >= 0 && r.bottom <= innerHeight - 60;
    })(),
  };
})()
"""


def login() -> str:
    req = urllib.request.Request(
        BASE + "api/v1/auth/login",
        data=json.dumps(
            {"email": "student@scholar.mw", "password": "student123"}
        ).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)["access_token"]


async def main():
    import tempfile

    token = login()
    print("login token length:", len(token))

    prof = tempfile.mkdtemp(prefix="pmw_chat_")
    cerr = open("/tmp/pmw_chat.log", "wb")
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

    results = []
    console_errs = []

    def ck(name, ok, detail=""):
        results.append((name, bool(ok), detail))
        print(
            ("  PASS  " if ok else "  FAIL  ")
            + name
            + ("  | " + str(detail)[:300] if detail else "")
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
            print("FAIL: no devtools target")
            return 1

        import websockets

        async with websockets.connect(target, max_size=60_000_000) as ws:
            pending = {}
            handlers = []
            mid = 0
            loop = asyncio.get_running_loop()

            async def reader():
                try:
                    async for raw in ws:
                        msg = json.loads(raw)
                        if "id" in msg and msg["id"] in pending:
                            fut = pending.pop(msg["id"])
                            if not fut.done():
                                fut.set_result(msg)
                        elif "method" in msg:
                            for h in handlers:
                                try:
                                    await h(msg)
                                except Exception:  # noqa: BLE001 - never kill the reader
                                    pass
                except asyncio.CancelledError:
                    pass

            reader_task = asyncio.create_task(reader())

            async def call(method, params=None):
                nonlocal mid
                mid += 1
                fut = loop.create_future()
                pending[mid] = fut
                await ws.send(
                    json.dumps({"id": mid, "method": method, "params": params or {}})
                )
                msg = await asyncio.wait_for(fut, 45)
                if "error" in msg:
                    raise RuntimeError(str(msg["error"]))
                return msg.get("result", {})

            async def ev(expr, ap=False):
                r = await call(
                    "Runtime.evaluate",
                    {
                        "expression": expr,
                        "returnByValue": True,
                        "awaitPromise": ap,
                    },
                )
                res = r.get("result", {})
                if res.get("subtype") == "error":
                    return {"error": str(res.get("description"))}
                return res.get("value")

            async def shot(name):
                r = await call("Page.captureScreenshot", {"format": "png"})
                open(name, "wb").write(base64.b64decode(r["data"]))
                print("  shot:", name)

            # route console + fetch events
            paused = asyncio.Queue()

            async def on_event(msg):
                if msg["method"] == "Runtime.consoleAPICalled":
                    if msg["params"].get("type") == "error":
                        console_errs.append(
                            json.dumps(msg["params"].get("args", []))[:200]
                        )
                elif msg["method"] == "Log.entryAdded":
                    e = msg["params"].get("entry", {})
                    if e.get("level") == "error":
                        console_errs.append(str(e.get("text"))[:200])
                elif msg["method"] == "Fetch.requestPaused":
                    await paused.put(msg["params"])

            handlers.append(on_event)

            await call("Page.enable")
            await call("Runtime.enable")
            await call("Log.enable")
            await call(
                "Emulation.setDeviceMetricsOverride",
                {"width": 1500, "height": 900, "deviceScaleFactor": 1, "mobile": False},
            )

            # ══ 1. signed-in session: token reaches the page and is scrubbed ══
            await call(
                "Page.navigate",
                {"url": BASE + "mathsdrill/index.html?theme=dark&token=" + token},
            )
            for _ in range(45):
                await asyncio.sleep(1)
                if await ev("!!document.querySelector('input')"):
                    break
            await asyncio.sleep(1)
            st = await ev("(" + ENTER + ")()", True)
            print("enter:", json.dumps(st, ensure_ascii=False))

            url_now = await ev("location.search")
            ck(
                "T1 token carried then scrubbed from the URL",
                isinstance(url_now, str)
                and "token=" not in url_now
                and "theme=dark" in url_now,
                url_now,
            )

            # ══ 2. entry panel pinned to the bottom (idle) ══
            c = await ev(COMPOSER)
            print("composer:", json.dumps(c, ensure_ascii=False))
            ck(
                "T2 composer present, fixed and pinned to the viewport bottom",
                isinstance(c, dict)
                and c.get("present")
                and c.get("position") == "fixed"
                and c.get("pinnedToViewport")
                and c.get("display") != "none"
                and c.get("hidden") is False
                and c.get("hpc") == "on",
                c,
            )

            # ══ 3. ask, holding the request open to measure the in-flight state ══
            await call(
                "Fetch.enable",
                {
                    "patterns": [
                        {
                            "urlPattern": "*api/v1/mathsdrill/solve*",
                            "requestStage": "Request",
                        },
                    ]
                },
            )
            a = await ev(f"({ASK})({json.dumps('Solve x^2 - 4x + 3 = 0')})")
            print("ask:", json.dumps(a, ensure_ascii=False))

            held = None
            try:
                params = await asyncio.wait_for(paused.get(), 20)
                await asyncio.sleep(0.4)
                held = await ev(COMPOSER)
                print("in-flight:", json.dumps(held, ensure_ascii=False))
                await asyncio.sleep(1.4)  # keep the generation running
                await call("Fetch.continueRequest", {"requestId": params["requestId"]})
            except asyncio.TimeoutError:
                print("  (request was not paused — measuring without interception)")
            finally:
                try:
                    await call("Fetch.disable")
                except Exception:  # noqa: BLE001
                    pass

            if held:
                ck(
                    "T3 composer stays on screen while the solution is generated",
                    held.get("busy") == "true"
                    and held.get("hidden") is False
                    and held.get("pinnedToViewport")
                    and held.get("display") != "none",
                    held,
                )
            else:
                ck(
                    "T3 composer stays on screen while the solution is generated",
                    False,
                    "request never paused",
                )

            # wait for the answer
            res = None
            for _ in range(60):
                await asyncio.sleep(1)
                res = await ev(RESULT)
                if isinstance(res, dict) and res.get("ready"):
                    break
            print("result:", json.dumps(res, ensure_ascii=False)[:900])
            ck(
                "T4 answer is worked step by step with a final answer",
                isinstance(res, dict)
                and res.get("ready")
                and (res.get("steps") or 0) >= 3
                and bool(res.get("answer"))
                and res.get("stepsInView") is True,
                {k: res.get(k) for k in ("steps", "answer", "stepsInView", "badges")}
                if isinstance(res, dict)
                else res,
            )

            body_text = (res or {}).get("text", "")
            ck(
                "T5 reports which engine answered (verified vs AI)",
                any(
                    ("SymPy verified" in b) or ("AI tutor" in b)
                    for b in (res or {}).get("badges", [])
                ),
                (res or {}).get("badges"),
            )

            ck(
                "T6 the old canned reply is gone",
                isinstance(body_text, str)
                and not any(s in body_text for s in CANNED)
                and "classify" not in body_text.lower(),
                body_text[:160],
            )

            ck(
                "T6b LaTeX words never collide into glyph junk (no '≤ft.')",
                isinstance(body_text, str)
                and "≤ft" not in body_text
                and "\\substack" not in body_text,
                body_text[:200],
            )

            ck(
                "T7 graph generated from the answer's mathematics",
                (res or {}).get("hasGraph")
                and (res.get("canvasSize") or [0, 0])[0] > 0
                and (res.get("graphH") or 0) > 100
                and str(res.get("cap", "")).startswith("y =")
                and not res.get("limitNote"),
                {
                    "cap": (res or {}).get("cap"),
                    "canvas": (res or {}).get("canvasSize"),
                    "limit": (res or {}).get("limitNote"),
                },
            )

            c2 = await ev(COMPOSER)
            ck(
                "T8 composer still pinned after the answer",
                isinstance(c2, dict)
                and c2.get("pinnedToViewport")
                and c2.get("hidden") is False
                and c2.get("busy") in (None, "null"),
                c2,
            )
            await shot(".chat_ai_answer.png")

            # ══ 4. a geometry question should produce a diagram ══
            await ev(
                f"({ASK})({json.dumps('Find the hypotenuse of a right triangle with legs 3 and 4 cm')})"
            )
            res2 = None
            for _ in range(60):
                await asyncio.sleep(1)
                res2 = await ev(RESULT)
                if (
                    isinstance(res2, dict)
                    and res2.get("ready")
                    and "hypotenuse"
                    in res2.get("text", "").lower()
                    + " ".join(res2.get("stepTitles", [])).lower()
                ):
                    break
            print(
                "triangle:",
                json.dumps(
                    {
                        k: (res2 or {}).get(k)
                        for k in (
                            "steps",
                            "answer",
                            "badges",
                            "diagram",
                            "diagramLabels",
                            "hasGraph",
                        )
                    },
                    ensure_ascii=False,
                )[:400],
            )
            ck(
                "T9 triangle question returns its diagram with the side labels",
                isinstance(res2, dict)
                and res2.get("diagram")
                and all(
                    any(str(n) in lbl for lbl in (res2.get("diagramLabels") or []))
                    for n in ("3", "4", "5")
                ),
                (res2 or {}).get("diagramLabels"),
            )

            # ══ 5. a percentage question should produce a bar ══
            await ev(f"({ASK})({json.dumps('What is 15% of 240?')})")
            res3 = None
            for _ in range(60):
                await asyncio.sleep(1)
                res3 = await ev(RESULT)
                if (
                    isinstance(res3, dict)
                    and res3.get("ready")
                    and "36" in res3.get("text", "")
                ):
                    break
            print(
                "percentage:",
                json.dumps(
                    {k: (res3 or {}).get(k) for k in ("answer", "badges", "bar")},
                    ensure_ascii=False,
                )[:300],
            )
            ck(
                "T10 percentage question returns its bar diagram",
                isinstance(res3, dict)
                and res3.get("bar")
                and "36" in (res3.get("answer") or ""),
                (res3 or {}).get("answer"),
            )
            await shot(".chat_ai_diagrams.png")

            # ══ 6. a free-form word problem → the ScholarAI assistant (live) ══
            # SymPy cannot parse this wording; the structured JSON call may
            # fail; the /ai/chat fallback must work it instead of the canned
            # "I could not turn that into a calculation yet …" clarification.
            await ev(
                f"({ASK})({json.dumps('A farmer has 3 times as many goats as cows. '
                'Altogether there are 32 animals. How many goats are there?')})"
            )
            res_ai = None
            for _ in range(60):  # one real provider round-trip
                await asyncio.sleep(1)
                res_ai = await ev(RESULT)
                if isinstance(res_ai, dict) and res_ai.get("ready"):
                    if "goats" in (res_ai.get("answer") or "").lower():
                        break
            print("free-form:", json.dumps(res_ai, ensure_ascii=False)[:400])
            ck(
                "T10b a question SymPy cannot parse is worked by the AI assistant live",
                isinstance(res_ai, dict)
                and res_ai.get("ready")
                and "AI tutor" in (res_ai.get("badges") or [])
                and res_ai.get("steps", 0) >= 3
                and "24" in (res_ai.get("answer") or "")
                and "could not turn that into a calculation"
                not in (res_ai.get("text") or "")
                and not (res_ai.get("hint") or "")
                and not res_ai.get("pending"),
                (res_ai or {}).get("badges"),
            )
            await shot(".chat_ai_live.png")

            # ══ 7. no session → an honest message, never the canned one ══
            # this phase *deliberately* triggers a 403, so only console errors
            # seen during the signed-in phases above are judged below
            signed_phase_errors = list(console_errs)
            await call(
                "Page.navigate", {"url": BASE + "mathsdrill/index.html?theme=dark"}
            )
            for _ in range(45):
                await asyncio.sleep(1)
                if await ev("!!document.querySelector('input')"):
                    break
            await asyncio.sleep(1)
            await ev("(" + ENTER + ")()", True)
            await ev(f"({ASK})({json.dumps('Solve x^2 - 4x + 3 = 0')})")
            res4 = None
            for _ in range(40):
                await asyncio.sleep(1)
                res4 = await ev(RESULT)
                if isinstance(res4, dict) and res4.get("ready"):
                    break
            print("no session:", json.dumps(res4, ensure_ascii=False)[:300])
            t4 = (res4 or {}).get("text", "")
            ck(
                "T11 without a session it says so instead of faking an answer",
                isinstance(res4, dict)
                and res4.get("ready")
                and "Sign in to Penrose" in t4
                and not (res4.get("steps") or 0),
                t4[:200],
            )

            ck(
                "T12 zero console errors (signed-in phases)",
                len(signed_phase_errors) == 0,
                signed_phase_errors[:4],
            )

            passed = sum(1 for _, ok, _ in results if ok)
            print("=" * 70)
            print("RESULT: %d/%d checks passed" % (passed, len(results)))
            for name, ok, detail in results:
                if not ok:
                    print("  FAILED:", name, "->", detail)
            reader_task.cancel()
            return 0 if passed == len(results) else 2
    finally:
        proc.kill()


sys.exit(asyncio.run(main()))
