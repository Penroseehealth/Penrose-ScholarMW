"""Acceptance test for the five reported issues (dark theme, mathsdrill).

T1  large band across the bottom  -> gap to viewport bottom (was 130 px)
T2  graph panel is dark blue      -> graph surfaces must equal the
                                      calculation area's charcoal
T3  black font on dark theme      -> near-black ink on dark surfaces
T4  chat area with paste fidelity -> transcript, sup/sub + positions,
                                      solver receives the same shape
T5  configurations in the gear    -> theme + font controls in .solve-dropdown
"""

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
  if(mode==="solve"){
    var role=document.querySelector("select.role");
    if(role){ setVal(role,"solve"); await sleep(1200); out.role=role.value; }
    out.chatIdle = !!document.querySelector(".solve .solve-input .hpc-chat");
  }
  if(mode==="settings"){
    var nav=[...document.querySelectorAll(".side-item,button")].find(x=>txt(x)==="Settings" && x.offsetParent!==null);
    if(nav){ nav.click(); out.nav="Settings"; }
    await sleep(1200);
  }
  return out;
}
"""

T1 = """
(async () => {
  function sleep(m){ return new Promise(r=>setTimeout(r,m)); }
  var out = {};
  // the band was reported while a problem is open — guarantee that state
  if (!document.querySelector(".solve .workspace")) {
    var ex = [...document.querySelectorAll(".ex")][0];
    out.exCount = document.querySelectorAll(".ex").length;
    if (ex) {
      ex.click();
      for (var k=0; k<50 && !document.querySelector(".board svg"); k++) await sleep(300);
    }
  }
  await sleep(400);
  out.workspace = !!document.querySelector(".solve .workspace");
  out.inputCard = !!document.querySelector(".solve .solve-input");
  var vh = innerHeight, vw = innerWidth;
  var best = 0, who = null;
  [".board",".workspace.fullscreen",".solve .workspace",".working",".panel",".md-grid",".mathdrill"]
    .forEach(function(s){
      document.querySelectorAll(s).forEach(function(e){
        var r = e.getBoundingClientRect();
        if (r.bottom > best) { best = r.bottom; who = s; }
      });
    });
  var at = document.elementFromPoint(Math.round(vw/2), vh-4);
  out.vh = vh; out.vw = vw; out.contentBottom = Math.round(best); out.who = who;
  out.gap = Math.round(vh - best);
  out.bottomHit = at ? (at.tagName+"."+(at.className||"")) : null;
  // the pinned entry panel is supposed to own the bottom of the screen
  var comp = document.querySelector(".hpc-composer");
  out.composerH = comp && !comp.hidden
    ? Math.round(comp.getBoundingClientRect().height) : 0;
  out.composerPinned = comp ? getComputedStyle(comp).position === "fixed" : false;
  return out;
})()
"""

T2 = """
(() => {
  function bg(s){ var e=document.querySelector(s); return e ? getComputedStyle(e).backgroundColor : null; }
  function stroke(s){ var e=document.querySelector(s); return e ? getComputedStyle(e).stroke : null; }
  return {
    wrap: bg(".md-graph .canvas-wrap") || bg(".canvas-wrap"),
    svg: bg(".canvas-wrap svg"),
    board: bg(".solve .board"),
    calcPanel: bg(".working.paper"),
    card: bg(".md-card"),
    gridStroke: stroke(".canvas-wrap .grid line"),
    tokenBg: (window.__g3dThemeProbe ? window.__g3dThemeProbe() : null)
  };
})()
"""

T5 = """
(async () => {
  function sleep(m){ return new Promise(r=>setTimeout(r,m)); }
  function txt(e){ return (e.textContent||"").replace(/\\s+/g," ").trim(); }
  var out={};
  var gear = document.querySelector(".solve-menu .gear");
  if(!gear){ out.err="no gear"; return out; }
  gear.click();
  await sleep(700);
  var dd = document.querySelector(".solve-dropdown");
  out.dropdownOpen = !!dd;
  out.hasGroup = !!document.querySelector(".solve-dropdown [data-fsgroup]");
  out.themeButtons = [...document.querySelectorAll(".solve-dropdown [data-fstheme]")]
    .map(b=>({t:b.dataset.fstheme, active:b.classList.contains("active"),
              pressed:b.getAttribute("aria-pressed")}));
  out.fontRows = [...document.querySelectorAll(".solve-dropdown [data-fsrow]")]
    .map(e=>e.dataset.fsrow);
  out.fontInputs = [...document.querySelectorAll(".solve-dropdown [data-fsinput]")]
    .map(e=>e.dataset.fsinput+"="+e.value);
  if (dd) {
    out.hOverflow = dd.scrollWidth - dd.clientWidth;
    dd.scrollTop = dd.scrollHeight;
    await sleep(200);
    var reset = [...dd.querySelectorAll("button")].filter(b=>/Reset text/i.test(b.textContent))[0];
    if (reset) {
      var dr = dd.getBoundingClientRect(), rr = reset.getBoundingClientRect();
      out.resetReachable = rr.top >= dr.top - 1 && rr.bottom <= dr.bottom + 1;
    }
    dd.scrollTop = 0;
  }

  // flip the theme through the gear
  var light = document.querySelector('.solve-dropdown [data-fstheme="light"]');
  if(light){
    light.click(); await sleep(500);
    out.afterLight = {theme: document.documentElement.dataset.theme,
                      stored: localStorage.getItem("mathdrill.theme"),
                      lightActive: document.querySelector('[data-fstheme="light"]').classList.contains("active")};
    var dark = document.querySelector('.solve-dropdown [data-fstheme="dark"]');
    dark.click(); await sleep(500);
    out.afterDark = {theme: document.documentElement.dataset.theme,
                     stored: localStorage.getItem("mathdrill.theme")};
  }
  // move a font control from the gear
  var size = document.querySelector('.solve-dropdown [data-fsinput="size"]');
  if(size){
    size.value = "130";
    size.dispatchEvent(new Event("input",{bubbles:true}));
    size.dispatchEvent(new Event("change",{bubbles:true}));
    await sleep(400);
    out.sizeApplied = {marker: document.documentElement.dataset.fsSize,
                       html: getComputedStyle(document.documentElement).fontSize};
  }
  return out;
}
"""

BLACK_SOURCES = """
(() => {
  function lum(c){ var m=/rgba?\\(([^)]+)\\)/.exec(c||""); if(!m) return null;
    var p=m[1].split(",").map(s=>parseFloat(s));
    if(p.length>3 && p[3]<0.15) return null;
    return 0.2126*p[0]+0.7152*p[1]+0.0722*p[2]; }
  function bgOf(el){ var n=el,h=0; while(n&&h++<8){ var v=lum(getComputedStyle(n).backgroundColor);
    if(v!==null) return v; n=n.parentElement; } return lum(getComputedStyle(document.body).backgroundColor); }
  function txt(e){ return (e.textContent||"").replace(/\\s+/g," ").trim(); }
  var bad=[];
  document.querySelectorAll("body *").forEach(function(el){
    if(el.tagName==="INPUT") return;
    var t=txt(el); if(!t) return;
    var r=el.getBoundingClientRect(); if(r.width<2||r.height<2) return;
    var cs=getComputedStyle(el);
    if(cs.visibility==="hidden"||cs.display==="none") return;
    var isSvg=(el.tagName==="text"||el.tagName==="tspan");
    var fg=lum(isSvg?cs.fill:cs.color);
    if(fg===null||fg>=60) return;
    var b=bgOf(el); if(b===null||b>=60) return;
    var cls = (el.className && el.className.baseVal !== undefined) ? el.className.baseVal
      : (el.className || "") + "";
    bad.push({cls: cls, ink: isSvg ? cs.fill : cs.color, surface: bgOf(el), txt: t.slice(0, 46),
              html: el.outerHTML.slice(0, 180)});
  });
  return bad;
})()
"""

CHAT_PASTE = """
(async () => {
  function sleep(m){ return new Promise(r=>setTimeout(r,m)); }
  var out={};
  var input = document.querySelector(".hpc-input");
  if(!input){ out.err="no composer"; return out; }
  input.focus();
  var r = document.createRange(); r.selectNodeContents(input); r.collapse(false);
  var s = getSelection(); s.removeAllRanges(); s.addRange(r);
  var dt = new DataTransfer();
  dt.setData("text/html", "<div>Solve y = x<sup>2</sup> - 4x + 3</div><div>level H<sub>2</sub>O</div>");
  dt.setData("text/plain", "Solve y = x2 - 4x + 3\\nlevel H2O");
  input.dispatchEvent(new ClipboardEvent("paste", {clipboardData:dt, bubbles:true, cancelable:true}));
  await sleep(300);
  out.composerHTML = input.innerHTML;
  out.hasSup = /<sup>/.test(input.innerHTML);
  out.hasSub = /<sub>/.test(input.innerHTML);
  out.newlineKept = /\\n/.test(input.innerText || "");
  // block order must survive the paste (a naive caret insert reverses it)
  var h = input.innerHTML;
  var a = h.indexOf("Solve"), b = h.indexOf("level");
  out.orderOK = a !== -1 && b !== -1 && a < b;

  // the app's own question box must keep positions too
  var qbox = document.querySelector(".solve textarea.qbox");
  if(qbox){
    qbox.focus();
    var r2 = document.createRange(); r2.selectNodeContents(qbox); r2.collapse(false);
    var s2 = getSelection(); s2.removeAllRanges(); s2.addRange(r2);
    var dt2 = new DataTransfer();
    dt2.setData("text/html", "H<sub>2</sub>O and x<sup>3</sup>");
    dt2.setData("text/plain", "H2O and x3");
    qbox.dispatchEvent(new ClipboardEvent("paste", {clipboardData:dt2, bubbles:true, cancelable:true}));
    await sleep(200);
    out.qboxValue = qbox.value;
    out.qboxHasSup = (qbox.value || "").indexOf("\\u00b3") !== -1;
    out.qboxHasSub = (qbox.value || "").indexOf("\\u2082") !== -1;
  }

  // stage 2: leave a solvable question in the composer, still rich (superscript)
  input.innerHTML = "";
  input.focus();
  var r3 = document.createRange(); r3.selectNodeContents(input); r3.collapse(false);
  var s3 = getSelection(); s3.removeAllRanges(); s3.addRange(r3);
  var dt3 = new DataTransfer();
  dt3.setData("text/html", "<div>Draw y = x<sup>2</sup> - 4x + 3 and find its roots</div>");
  dt3.setData("text/plain", "Draw y = x2 - 4x + 3 and find its roots");
  input.dispatchEvent(new ClipboardEvent("paste", {clipboardData:dt3, bubbles:true, cancelable:true}));
  await sleep(250);
  out.stagedHTML = input.innerHTML;
  out.stagedIsRich = /<sup>/.test(input.innerHTML);
  return out;
}
"""

CHAT_SEND = """
(async () => {
  function sleep(m){ return new Promise(r=>setTimeout(r,m)); }
  function txt(e){ return (e.textContent||"").replace(/\\s+/g," ").trim(); }
  var out={};
  var input = document.querySelector(".hpc-input");
  if(!input){ out.err="no composer"; return out; }
  var send = document.querySelector(".hpc-send");
  if(!send){ out.err="no send"; return out; }
  out.stagedHTML = (document.querySelector(".hpc-input")||{}).innerHTML || null;
  out.beforeWorkspace = !!document.querySelector(".solve .workspace");
  send.click();
  // wait for the ASSISTANT reply itself — the solver answers over HTTP, and a
  // workspace may already be open from an earlier example
  for (var i=0;i<80;i++){
    await sleep(250);
    if (document.querySelector(".hpc-msg.bot")) break;
  }
  await sleep(500);
  out.afterWorkspace = !!document.querySelector(".solve .workspace");
  out.title = (document.querySelector(".solve .board strong")||{}).textContent || null;
  out.chatParent = (function(){
    var c=document.querySelector(".hpc-chat");
    if(!c) return null;
    var p=c.parentElement;
    return p ? (p.tagName+"."+(p.className||"")) : null;
  })();
  out.msgs = [...document.querySelectorAll(".hpc-msg")].map(m=>({
    role: m.classList.contains("user") ? "user" : "bot",
    html: (m.querySelector(".hpc-body")||{}).innerHTML || "",
    txt: txt(m.querySelector(".hpc-body")||{textContent:""}).slice(0,80)
  }));
  // the structured answer the AI/tutor endpoint produced (replaces the old
  // ".qbox hand-off", which only ever understood the built-in families)
  var bots = [...document.querySelectorAll(".hpc-msg.bot")];
  var last = bots[bots.length-1];
  out.aiSteps = last ? last.querySelectorAll(".hpc-step").length : 0;
  out.aiBadges = last ? [...last.querySelectorAll(".hpc-badge")].map(e=>txt(e)) : [];
  out.aiCap = last ? txt(last.querySelector(".hpc-cap")||{textContent:""}) : "";
  out.aiLimit = last ? !!last.querySelector(".hpc-limit") : false;
  return out;
}
"""


def _login() -> str:
    """Real session for the embedded chat (its solver endpoint is auth-guarded)."""
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

    prof = tempfile.mkdtemp(prefix="pmw_iss5_")
    cerr = open("/tmp/pmw_iss5.log", "wb")
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
                    if msg.get("method") == "Runtime.consoleAPICalled":
                        if msg.get("params", {}).get("type") == "error":
                            console_errs.append(
                                json.dumps(msg["params"].get("args", []))[:200]
                            )
                    if msg.get("method") == "Log.entryAdded":
                        e = msg.get("params", {}).get("entry", {})
                        if e.get("level") == "error":
                            console_errs.append(str(e.get("text"))[:200])

            async def ev(e, ap=False):
                r = await cmd(
                    "Runtime.evaluate",
                    {"expression": e, "returnByValue": True, "awaitPromise": ap},
                )
                res = r.get("result", {})
                if res.get("subtype") == "error":
                    return {"error": str(res.get("description"))}
                return res.get("value")

            async def go(url, wait=45, title_wait=None, wait_input=True):
                await cmd("Page.enable")
                await cmd("Runtime.enable")
                await cmd("Log.enable")
                await cmd("Page.navigate", {"url": url})
                if wait_input:
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

            # ══ T5 + T4 + T1 + T2 + T3 in the solve view ══
            print("=" * 70)
            print("SOLVE VIEW (dark)")
            await go(BASE + "mathsdrill/index.html?theme=dark&token=" + _login())
            st = await ev("(" + ENTER + ")('solve')", True)
            print("  enter:", json.dumps(st, ensure_ascii=False))
            ck(
                "T4a chat area present while asking",
                bool((st or {}).get("chatIdle")),
                st,
            )

            # T4: paste fidelity (composer + app question box)
            p = await ev(CHAT_PASTE + ")()", True)
            print("  paste:", json.dumps(p, ensure_ascii=False)[:700])
            if isinstance(p, dict) and not p.get("error"):
                ck(
                    "T4b composer keeps <sup>/<sub> markup",
                    p.get("hasSup") and p.get("hasSub"),
                    p.get("composerHTML"),
                )
                ck(
                    "T4b2 pasted block order preserved (not reversed)",
                    p.get("orderOK"),
                    p.get("composerHTML"),
                )
                ck(
                    "T4c newlines preserved in composer",
                    p.get("newlineKept"),
                    repr(p.get("composerHTML"))[:80],
                )
                ck(
                    "T4d app question box keeps Unicode positions",
                    p.get("qboxHasSup") and p.get("qboxHasSub"),
                    p.get("qboxValue"),
                )
            else:
                ck("T4b composer keeps <sup>/<sub> markup", False, p)

            # T1: band — measured with a problem actually open, because that is
            # the state the band was reported in
            await ev("(" + ENTER + ")('solve')", True)
            await asyncio.sleep(1.5)
            for w, h in ((1500, 900), (1280, 720)):
                await cmd(
                    "Emulation.setDeviceMetricsOverride",
                    {"width": w, "height": h, "deviceScaleFactor": 1, "mobile": False},
                )
                await asyncio.sleep(1.5)
                g = await ev(T1, True)
                print("  gap @%dx%d:" % (w, h), json.dumps(g, ensure_ascii=False))
                ck(
                    "T1 entry panel owns the bottom, no dead band (%dx%d)" % (w, h),
                    isinstance(g, dict)
                    and "hpc-composer" in (g.get("bottomHit") or "")
                    and g.get("composerPinned") is True
                    and g.get("gap") is not None
                    and (g["gap"] - g.get("composerH", 0)) <= 30,
                    g,
                )
            await cmd(
                "Emulation.setDeviceMetricsOverride",
                {"width": 1500, "height": 900, "deviceScaleFactor": 1, "mobile": False},
            )
            await asyncio.sleep(1)

            # T4: send the pasted question through the real solver
            s4 = await ev(CHAT_SEND + ")()", True)
            print("  send:", json.dumps(s4, ensure_ascii=False)[:900])
            if isinstance(s4, dict) and not s4.get("error"):
                ck(
                    "T4e Ask runs the real solver",
                    s4.get("afterWorkspace"),
                    s4.get("title"),
                )
                ck(
                    "T4f chat moves into the step column",
                    (s4.get("chatParent") or "").find(".panel") != -1,
                    s4.get("chatParent"),
                )
                msgs = s4.get("msgs") or []
                users = [m for m in msgs if m["role"] == "user"]
                bots = [m for m in msgs if m["role"] == "bot"]
                ck(
                    "T4g transcript has user + assistant messages",
                    len(users) >= 1 and len(bots) >= 1,
                    [m["txt"] for m in msgs][:4],
                )
                ck(
                    "T4h user message kept superscript markup",
                    any("<sup>" in m["html"] for m in users),
                    (users[0]["html"][:120] if users else None),
                )
                ck(
                    "T4i AI tutor answered with verified structured steps",
                    (s4.get("aiSteps") or 0) >= 3
                    and any(
                        str(b).startswith("SymPy") or "AI tutor" in str(b)
                        for b in (s4.get("aiBadges") or [])
                    )
                    and not s4.get("aiLimit"),
                    {
                        "steps": s4.get("aiSteps"),
                        "badges": s4.get("aiBadges"),
                        "cap": s4.get("aiCap"),
                    },
                )
            else:
                ck("T4e Ask runs the real solver", False, s4)

            # T5: configurations packed in the gear
            await asyncio.sleep(1)
            t5 = await ev(T5 + ")()", True)
            print("  gear:", json.dumps(t5, ensure_ascii=False)[:900])
            if isinstance(t5, dict) and not t5.get("error"):
                ck("T5a gear opens", t5.get("dropdownOpen"), t5.get("err"))
                ck(
                    "T5b font controls packed in the gear",
                    set(["size", "color", "weight", "sharp"])
                    <= set(t5.get("fontRows") or []),
                    t5.get("fontRows"),
                )
                ck(
                    "T5c theme row packed in the gear",
                    len(t5.get("themeButtons") or []) == 2,
                    t5.get("themeButtons"),
                )
                ck(
                    "T5d current theme reflected on entry",
                    t5.get("themeButtons")
                    and t5["themeButtons"][1]["active"]
                    and t5["themeButtons"][1]["pressed"] == "true",
                    t5.get("themeButtons"),
                )
                al = t5.get("afterLight") or {}
                ad = t5.get("afterDark") or {}
                ck(
                    "T5e gear flips theme + persists it",
                    al.get("theme") == "light"
                    and al.get("stored") == "light"
                    and ad.get("theme") == "dark"
                    and ad.get("stored") == "dark",
                    {"light": al, "dark": ad},
                )
                ck(
                    "T5f gear font control drives the page",
                    (t5.get("sizeApplied") or {}).get("marker") == "on",
                    t5.get("sizeApplied"),
                )
                ck(
                    "T5g gear popup fits its width and stays reachable",
                    (t5.get("hOverflow") or 0) <= 1
                    and t5.get("resetReachable") is not False,
                    {
                        "hOverflow": t5.get("hOverflow"),
                        "resetReachable": t5.get("resetReachable"),
                    },
                )
            else:
                ck("T5a gear opens", False, t5)

            # T2 + T3 (solve, gear closed)
            g2 = await ev(T2)
            print("  surfaces:", json.dumps(g2))
            if isinstance(g2, dict) and not g2.get("error"):
                vals = [
                    v
                    for v in (g2.get("svg"), g2.get("board"), g2.get("calcPanel"))
                    if v
                ]
                ck(
                    "T2a graph surface equals the calculation surface (dark)",
                    len(set(vals)) == 1 and vals[0] == "rgb(20, 23, 29)",
                    g2,
                )
                ck(
                    "T2b wrapper/card share the same charcoal",
                    g2.get("card") in (None, "rgb(20, 23, 29)")
                    or g2.get("wrap") == "rgb(20, 23, 29)",
                    (g2.get("wrap"), g2.get("card")),
                )
                ck(
                    "T2c grid is no longer indigo",
                    g2.get("gridStroke") in (None,)
                    or g2.get("gridStroke") != "rgb(43, 50, 96)",
                    g2.get("gridStroke"),
                )
            else:
                ck("T2a graph surface equals the calculation surface (dark)", False, g2)

            b3 = await ev(BLACK_SOURCES)
            print("  black-on-dark:", json.dumps(b3, ensure_ascii=False)[:500])
            ck(
                "T3a no black font on the dark solve view",
                isinstance(b3, list) and len(b3) == 0,
                b3[:4] if isinstance(b3, list) else b3,
            )

            # T3 in Settings (preview formula was black)
            await go(
                BASE + "mathsdrill/index.html?theme=dark&mdverify=steps",
                wait=45,
                title_wait=True,
                wait_input=True,
            )
            await asyncio.sleep(2)
            await ev("(" + ENTER + ")('settings')", True)
            b3b = await ev(BLACK_SOURCES)
            print("  settings black:", json.dumps(b3b, ensure_ascii=False)[:400])
            ck(
                "T3b no black font in Settings (preview formula)",
                isinstance(b3b, list) and len(b3b) == 0,
                b3b[:4] if isinstance(b3b, list) else b3b,
            )

            ck("T6 zero console errors", len(console_errs) == 0, console_errs[:4])

            passed = sum(1 for _, ok, _ in results if ok)
            print("=" * 70)
            print("RESULT: %d/%d checks passed" % (passed, len(results)))
            for name, ok, detail in results:
                if not ok:
                    print("  FAILED:", name, "->", detail)
            return 0 if passed == len(results) else 2
    finally:
        proc.kill()


sys.exit(asyncio.run(main()))
