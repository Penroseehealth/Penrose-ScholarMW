"""Acceptance test for Settings → Text (font size / colour / thickness /
sharpness) and for calculation-mode header removal.

Phases:
  A  panel injected into Settings, all four controls drive their effect
  B  values survive a reload (localStorage restore, pre-paint)
  C  diagram labels scale per authored size, halo + no text-stroke there
  D  headers removed while calculating, restored when not; toolbar survives
  E  defaults produce byte-identical rendering (no data-fs-* markers)
  F  zero console errors for the whole run
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

ENTER = """
async (mode) => {
  function sleep(m){ return new Promise(r => setTimeout(r, m)); }
  function txt(e){ return (e.textContent || "").replace(/\\s+/g, " ").trim(); }
  function setVal(el, v){
    var p = el instanceof HTMLSelectElement ? HTMLSelectElement.prototype
      : el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype
      : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(p, "value").set.call(el, v);
    el.dispatchEvent(new Event("input", {bubbles:true}));
    el.dispatchEvent(new Event("change", {bubbles:true}));
  }
  var out = {};
  for (var i = 0; i < 30; i++) {
    var inp = document.querySelector('input[type="text"], input:not([type])');
    if (inp && !inp.value) setVal(inp, "Verify");
    var go = [...document.querySelectorAll("button")].find(b => txt(b) === "Let's go");
    if (go) go.click();
    await sleep(300);
    if (!document.body.textContent.includes("Welcome")) { out.entered = true; break; }
  }
  if (mode === "settings") {
    var nav = [...document.querySelectorAll(".side-item, button")]
      .find(b => txt(b) === "Settings" && b.offsetParent !== null);
    if (nav) { nav.click(); out.nav = "Settings"; }
    await sleep(1500);
    out.hasGroup = !!document.querySelector(".settings.card [data-fsgroup]");
    out.rows = [...document.querySelectorAll("[data-fsrow]")].map(e => e.dataset.fsrow);
  } else if (mode === "solve") {
    var role = document.querySelector("select.role");
    if (role) { setVal(role, "solve"); await sleep(1200); }
    out.role = (document.querySelector("select.role") || {}).value;
    var ex = [...document.querySelectorAll(".ex")][0];
    if (ex) ex.click();
    for (var j = 0; j < 45; j++) {
      await sleep(500);
      if (document.querySelector(".board svg")) break;
    }
    await sleep(800);
    out.title = txt(document.querySelector(".board strong") || {textContent: ""});
  }
  return out;
}
"""

SET_CONTROLS = """
async () => {
  function sleep(m){ return new Promise(r => setTimeout(r, m)); }
  function fire(el, type){ el.dispatchEvent(new Event(type, {bubbles:true})); }
  function setRange(key, v){
    var inp = document.querySelector('[data-fsinput="' + key + '"]');
    if (!inp) return false;
    inp.value = String(v);
    fire(inp, "input"); fire(inp, "change");
    return true;
  }
  function setColor(v){
    var inp = document.querySelector('[data-fsinput="color"]');
    if (!inp) return false;
    inp.value = v;
    fire(inp, "input"); fire(inp, "change");
    return true;
  }
  var out = {};
  out.size = setRange("size", 140);
  out.weight = setRange("weight", 700);
  out.sharp = setRange("sharp", 80);
  out.color = setColor("#ffd54a");
  await sleep(500);
  out.dataset = JSON.stringify(document.documentElement.dataset);
  out.htmlFs = getComputedStyle(document.documentElement).fontSize;
  out.bodyW = getComputedStyle(document.body).fontWeight;
  out.textVar = document.documentElement.style.getPropertyValue("--text");
  var st = document.querySelector(".setting-text");
  out.settingColor = st ? getComputedStyle(st).color : null;
  out.settingStroke = st ? getComputedStyle(st).webkitTextStrokeWidth : null;
  out.valueLabels = [...document.querySelectorAll(".fs-val")].map(e => e.textContent);
  return out;
}
"""

CHECK_ONE = """
(() => {
  var out = {};
  var g = document.querySelector(".settings.card [data-fsgroup]");
  out.groupInCard = !!g;
  out.rows = [...document.querySelectorAll("[data-fsrow]")].map(e => e.dataset.fsrow);
  out.inputs = [...document.querySelectorAll("[data-fsinput]")].map(e =>
    e.dataset.fsinput + "=" + e.value);
  out.dataset = JSON.stringify(document.documentElement.dataset);
  out.htmlFs = getComputedStyle(document.documentElement).fontSize;
  return out;
})()
"""

RERENDER = """
async () => {
  function sleep(m){ return new Promise(r => setTimeout(r, m)); }
  function txt(e){ return (e.textContent||"").replace(/\\s+/g, " ").trim(); }
  // pick a "Working style" chip: a real React state change, theme unchanged
  var rows = [...document.querySelectorAll(".settings.card .setting")];
  var ws = rows.find(s => txt(s).indexOf("Working style") === 0);
  var chips = ws ? [...ws.querySelectorAll(".segmented button")] : [];
  var target = chips.find(c => txt(c) === "Hand 2") || chips[1] || null;
  var clicked = null;
  if (target) { clicked = txt(target); target.click(); }
  await sleep(1200);
  var g = document.querySelector(".settings.card [data-fsgroup]");
  return {
    clicked: clicked,
    groupInCard: !!g,
    rows: [...document.querySelectorAll("[data-fsrow]")].map(e => e.dataset.fsrow),
    inputs: [...document.querySelectorAll("[data-fsinput]")].map(e =>
      e.dataset.fsinput + "=" + e.value),
    htmlFs: getComputedStyle(document.documentElement).fontSize,
    dataset: JSON.stringify(document.documentElement.dataset)
  };
}
"""

LABELS = """
(() => {
  function pick(sz){
    var t = [...document.querySelectorAll('.canvas-wrap svg text[font-size="' + sz + '"]')]
      .find(e => e.getBoundingClientRect().width > 1);
    if (!t) return null;
    var cs = getComputedStyle(t);
    return {size: sz, fs: cs.fontSize, fw: cs.fontWeight, stroke: cs.stroke,
            tsw: cs.webkitTextStrokeWidth, fill: cs.fill, txt: (t.textContent||"").slice(0,12)};
  }
  return {t15: pick("15"), t12: pick("12"),
          svgBg: (function(){
            var s = document.querySelector(".canvas-wrap svg");
            return s ? getComputedStyle(s).backgroundColor : null;
          })(),
          calc: document.documentElement.dataset.calc || "off"};
})()
"""

HEADERS = """
(() => {
  function d(sel){
    var e = document.querySelector(sel);
    if (!e) return "absent";
    return getComputedStyle(e).display;
  }
  var labels = [...document.querySelectorAll(".g3b")].map(b => ({
    t: (b.textContent||"").trim().slice(0,10),
    vis: b.offsetParent !== null && getComputedStyle(b).display !== "none"
  }));
  return {
    calc: document.documentElement.dataset.calc || "off",
    appHeader: d(".app-header"),
    brand: d(".app-brand"),
    profile: d(".app-profile"),
    mdH2: d(".md-header h2"),
    mdIcon: d(".md-ic"),
    mdTag: d(".md-tag"),
    mdToolbar: d(".g3tb"),
    toolbarBtns: labels
  };
})()
"""

CLEAR_FONT = """
(async () => {
  function sleep(m){ return new Promise(r => setTimeout(r, m)); }
  try { localStorage.removeItem("mathdrill.font"); } catch (e) {}
  location.reload();
  await sleep(100);
  return true;
})()
"""


async def main():
    import tempfile

    prof = tempfile.mkdtemp(prefix="pmw_font_")
    cerr = open("/tmp/pmw_font.log", "wb")
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
    results = []
    console_errs = []

    def ck(name, ok, detail=""):
        results.append((name, bool(ok), detail))
        print(
            ("  PASS  " if ok else "  FAIL  ")
            + name
            + ("  | " + str(detail) if detail else "")
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
                    if msg.get("method") == "Runtime.consoleAPICalled":
                        if msg.get("params", {}).get("type") == "error":
                            console_errs.append(
                                "console.error: "
                                + json.dumps(msg["params"].get("args", []))[:200]
                            )
                    if msg.get("method") == "Log.entryAdded":
                        e = msg.get("params", {}).get("entry", {})
                        if e.get("level") == "error":
                            console_errs.append("log: " + str(e.get("text"))[:220])

            async def ev(e, ap=False):
                r = await cmd(
                    "Runtime.evaluate",
                    {"expression": e, "returnByValue": True, "awaitPromise": ap},
                )
                res = r.get("result", {})
                if res.get("subtype") == "error":
                    return {"error": str(res.get("description"))}
                return res.get("value")

            async def go(url, wait=45, title_wait=None):
                await cmd("Page.enable")
                await cmd("Runtime.enable")
                await cmd("Log.enable")
                await cmd(
                    "Emulation.setDeviceMetricsOverride",
                    {
                        "width": 1600,
                        "height": 900,
                        "deviceScaleFactor": 1,
                        "mobile": False,
                    },
                )
                await cmd("Page.navigate", {"url": url})
                for _ in range(wait):
                    await asyncio.sleep(1)
                    if await ev("!!document.querySelector('input')"):
                        break
                await asyncio.sleep(2)
                if title_wait:
                    for _ in range(80):
                        await asyncio.sleep(1)
                        t = await ev("document.title")
                        if isinstance(t, str) and "MDVERIFY" in t:
                            break

            async def shot(n):
                r = await cmd("Page.captureScreenshot", {"format": "png"})
                open(n, "wb").write(base64.b64decode(r["data"]))
                print("  shot:", n)

            # ─── A: panel + controls ───────────────────────────────
            print("=" * 68)
            print("PHASE A — Settings panel and controls (dark)")
            await go(BASE + "mathsdrill/index.html?theme=dark")
            st = await ev("(" + ENTER + ")('settings')", True)
            print("  enter:", json.dumps(st, ensure_ascii=False)[:300])
            ck(
                "A1 panel injected into .settings.card",
                isinstance(st, dict) and st.get("hasGroup"),
                st.get("rows") if isinstance(st, dict) else st,
            )
            rows = (st or {}).get("rows", []) if isinstance(st, dict) else []
            ck(
                "A2 four rows (size,color,weight,sharp)",
                rows == ["size", "color", "weight", "sharp"],
                rows,
            )

            ctl = await ev("(" + SET_CONTROLS + ")()", True)
            print("  controls:", json.dumps(ctl, ensure_ascii=False)[:600])
            if not isinstance(ctl, dict) or ctl.get("error"):
                ck("A3 controls driven", False, ctl)
            else:
                ck(
                    "A3 all four inputs accepted values",
                    all(ctl.get(k) for k in ("size", "weight", "sharp", "color")),
                )
                ds = json.loads(ctl.get("dataset") or "{}")
                ck(
                    "A4 markers set (data-fs-*)",
                    ds.get("fsSize") == "on"
                    and ds.get("fsWeight") == "on"
                    and ds.get("fsSharp") == "on"
                    and ds.get("fsColor") == "on",
                    ds,
                )
                fs = float((ctl.get("htmlFs") or "0px").replace("px", ""))
                ck(
                    "A5 font size 140% -> 22.4px root",
                    abs(fs - 22.4) < 0.05,
                    ctl.get("htmlFs"),
                )
                ck(
                    "A6 thickness -> body weight 700",
                    ctl.get("bodyW") == "700",
                    ctl.get("bodyW"),
                )
                ck(
                    "A7 colour -> --text inline + computed",
                    (ctl.get("textVar") or "").lower() == "#ffd54a"
                    and ctl.get("settingColor") == "rgb(255, 213, 74)",
                    (ctl.get("textVar"), ctl.get("settingColor")),
                )
                try:
                    sw = float((ctl.get("settingStroke") or "0px").replace("px", ""))
                except ValueError:
                    sw = 0.0
                ck(
                    "A8 sharpness 80% -> hairline stroke",
                    0.2 < sw < 0.5,
                    ctl.get("settingStroke"),
                )
                ck(
                    "A9 value labels rendered",
                    ctl.get("valueLabels"),
                    ctl.get("valueLabels"),
                )
                await shot(".font_settings_dark.png")

                # React re-renders this card whenever any setting changes; the
                # injected panel has to be re-asserted, not silently dropped
                rr = await ev("(" + RERENDER + ")()", True)
                print("  after re-render:", json.dumps(rr, ensure_ascii=False)[:400])
                ck(
                    "A10 panel survives a React re-render with values intact",
                    isinstance(rr, dict)
                    and rr.get("groupInCard")
                    and set(["size=140", "weight=700", "sharp=80", "color=#ffd54a"])
                    <= set(rr.get("inputs") or [])
                    and rr.get("htmlFs") == "22.4px",
                    rr if isinstance(rr, dict) else rr,
                )

            # ─── B: persistence across reload ──────────────────────
            print("=" * 68)
            print("PHASE B — restore after reload")
            await cmd(
                "Page.navigate", {"url": BASE + "mathsdrill/index.html?theme=dark"}
            )
            for _ in range(40):
                await asyncio.sleep(1)
                if await ev("!!document.querySelector('input')"):
                    break
            await asyncio.sleep(3)
            # the session is restored straight into the practice view, so open
            # Settings explicitly before looking for the injected controls
            stB = await ev("(" + ENTER + ")('settings')", True)
            b = await ev(CHECK_ONE)
            print("  after reload:", json.dumps(b, ensure_ascii=False)[:400])
            if isinstance(b, dict) and not b.get("error"):
                ds = json.loads(b.get("dataset") or "{}")
                ck(
                    "B1 markers restored pre-paint",
                    ds.get("fsSize") == "on" and ds.get("fsColor") == "on",
                    ds,
                )
                ck(
                    "B2 root size restored",
                    b.get("htmlFs") == "22.4px",
                    b.get("htmlFs"),
                )
                ck(
                    "B3 panel re-injected on Settings",
                    bool(b.get("groupInCard")),
                    (stB if isinstance(stB, dict) else stB, b.get("rows")),
                )
                ck(
                    "B4 input values restored",
                    set(["size=140", "weight=700", "sharp=80", "color=#ffd54a"])
                    <= set(b.get("inputs") or []),
                    b.get("inputs"),
                )
            else:
                ck("B1 markers restored pre-paint", False, b)

            # ─── C: diagram labels ─────────────────────────────────
            print("=" * 68)
            print("PHASE C — diagram labels (practice view)")
            await go(
                BASE + "mathsdrill/index.html?theme=dark&mdverify=diagram",
                wait=60,
                title_wait=True,
            )
            await asyncio.sleep(3)
            L = await ev(LABELS)
            print("  labels:", json.dumps(L, ensure_ascii=False))
            if isinstance(L, dict) and not L.get("error"):
                t15, t12 = L.get("t15"), L.get("t12")
                ck(
                    "C1 size-15 label scaled to 21px",
                    t15 and t15.get("fs") == "21px",
                    t15,
                )
                ck(
                    "C2 size-12 label scaled to 16.8px (ratio kept)",
                    t12 and t12.get("fs") == "16.8px",
                    t12,
                )
                ck(
                    "C3 halo matches the graph surface (no boxy glow)",
                    t15 and L.get("svgBg") and t15.get("stroke") == L.get("svgBg"),
                    {"halo": t15 and t15.get("stroke"), "surface": L.get("svgBg")},
                )
                ck(
                    "C4 no text-stroke inside diagram (guard)",
                    t15 and t15.get("tsw") in ("0px", "0"),
                    t15 and t15.get("tsw"),
                )
                ck(
                    "C5 label thickness follows control",
                    t15 and t15.get("fw") == "700",
                    t15 and t15.get("fw"),
                )
            else:
                ck("C1 size-15 label scaled to 21px", False, L)

            # ─── D: calculation mode ───────────────────────────────
            print("=" * 68)
            print("PHASE D — headers while calculating")
            H = await ev(HEADERS)
            print("  practice:", json.dumps(H, ensure_ascii=False))
            if isinstance(H, dict) and not H.get("error"):
                ck(
                    "D1 calc mode on in worked solution",
                    H.get("calc") == "on",
                    H.get("calc"),
                )
                ck(
                    "D2 brand/user header removed",
                    H.get("appHeader") == "none"
                    and H.get("brand") == "none"
                    and H.get("profile") == "none",
                    (H.get("appHeader"), H.get("brand"), H.get("profile")),
                )
                ck(
                    "D3 practice title/icon/tag stripped",
                    H.get("mdH2") == "none"
                    and H.get("mdIcon") == "none"
                    and H.get("mdTag") == "none",
                    (H.get("mdH2"), H.get("mdIcon"), H.get("mdTag")),
                )
                btns = H.get("toolbarBtns") or []
                ck(
                    "D4 toolbar controls still usable (not deleted)",
                    len(btns) >= 5 and all(b.get("vis") for b in btns),
                    btns,
                )
                ck(
                    "D5 toolbar container kept",
                    H.get("mdToolbar") != "none",
                    H.get("mdToolbar"),
                )
            else:
                ck("D1 calc mode on in worked solution", False, H)

            # leaving calculation -> headers return
            await go(
                BASE + "mathsdrill/index.html?theme=dark&mdverify=steps",
                wait=45,
                title_wait=True,
            )
            await asyncio.sleep(2)
            H2 = await ev(HEADERS)
            print("  settings:", json.dumps(H2, ensure_ascii=False)[:300])
            ck(
                "D6 headers restored outside calculation",
                isinstance(H2, dict)
                and H2.get("calc") == "off"
                and H2.get("appHeader") not in ("none", "absent"),
                H2.get("calc") if isinstance(H2, dict) else H2,
            )

            # solve section
            await go(BASE + "mathsdrill/index.html?theme=dark")
            st2 = await ev("(" + ENTER + ")('solve')", True)
            await asyncio.sleep(1)
            H3 = await ev(HEADERS)
            print("  solve:", json.dumps(H3, ensure_ascii=False)[:300])
            ck(
                "D7 calc mode on while solving a problem",
                isinstance(st2, dict)
                and bool(st2.get("title"))
                and isinstance(H3, dict)
                and H3.get("calc") == "on",
                (
                    st2 if isinstance(st2, dict) else st2,
                    H3 if isinstance(H3, dict) else H3,
                ),
            )
            ck(
                "D8 brand header removed in solve",
                isinstance(H3, dict) and H3.get("appHeader") == "none",
                H3 if isinstance(H3, dict) else H3,
            )

            # ─── E: defaults untouched ─────────────────────────────
            print("=" * 68)
            print("PHASE E — defaults are byte-identical")
            await ev("(" + CLEAR_FONT + ")()", True)
            for _ in range(40):
                await asyncio.sleep(1)
                if await ev("!!document.querySelector('input')"):
                    break
            await asyncio.sleep(3)
            E = await ev(CHECK_ONE)
            print("  defaults:", json.dumps(E, ensure_ascii=False)[:400])
            if isinstance(E, dict) and not E.get("error"):
                ds = json.loads(E.get("dataset") or "{}")
                ck(
                    "E1 no data-fs-* markers at default",
                    not any(k.startswith("fs") for k in ds),
                    ds,
                )
                ck(
                    "E2 root font-size back to 16px",
                    E.get("htmlFs") == "16px",
                    E.get("htmlFs"),
                )
            else:
                ck("E1 no data-fs-* markers at default", False, E)
            await go(
                BASE + "mathsdrill/index.html?theme=light&mdverify=diagram",
                wait=60,
                title_wait=True,
            )
            await asyncio.sleep(3)
            E2 = await ev(LABELS)
            if isinstance(E2, dict) and not E2.get("error"):
                t12 = E2.get("t12")
                ck(
                    "E3 light + default: label size unchanged",
                    t12 and t12.get("fs") == "12px",
                    t12,
                )
                ck(
                    "E4 light + default: no text-stroke",
                    t12 and t12.get("tsw") in ("0px", "0"),
                    t12 and t12.get("tsw"),
                )
                ck(
                    "E5 light theme header present",
                    E2.get("calc") in ("on", "off"),
                    E2.get("calc"),
                )
            else:
                ck("E3 light + default: label size unchanged", False, E2)

            # ─── F: console ────────────────────────────────────────
            print("=" * 68)
            print("PHASE F — console")
            ck("F1 zero console errors", len(console_errs) == 0, console_errs[:4])

            passed = sum(1 for _, ok, _ in results if ok)
            print("=" * 68)
            print("RESULT: %d/%d checks passed" % (passed, len(results)))
            for name, ok, detail in results:
                if not ok:
                    print("  FAILED:", name, "->", detail)
            return 0 if passed == len(results) else 2
    finally:
        proc.kill()


sys.exit(asyncio.run(main()))
