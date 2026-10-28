/* MathDrill theme boot bridge.
   Runs BEFORE the app bundle so a theme deep-link (?theme=dark|light) is
   written to mathdrill.theme and <html data-theme> ahead of React's first
   render — the Settings → Theme switch remains the normal control.

   ?mdverify=1 (temporary verification hook) walks the first-run flow until a
   question with calculations/drawings is on screen and mirrors what it finds
   into <html data-mdverify> + document.title for headless checks. */
(function () {
  try {
    var q = new URLSearchParams(window.location.search);
    var t = q.get("theme");
    if (t === "dark" || t === "light") {
      localStorage.setItem("mathdrill.theme", t);
      document.documentElement.dataset.theme = t;
    }
  } catch (e) { /* private mode etc. — app falls back to its own default */ }

  /* ── Text appearance (Settings → Text) ─────────────────────────────
     Read + apply BEFORE React mounts so a restored size/colour/weight
     never flashes at the wrong value. font_settings.js drives this same
     API from the Settings panel and is the only writer of the store. */
  var FS_KEY = "mathdrill.font";
  var FS_DEFAULTS = { size: 100, color: "", weight: 400, sharp: 0 };
  function fsClamp(n, lo, hi, dflt) {
    return typeof n === "number" && isFinite(n) ? Math.min(hi, Math.max(lo, n)) : dflt;
  }
  function fsRead() {
    try {
      var raw = localStorage.getItem(FS_KEY);
      if (!raw) return { size: 100, color: "", weight: 400, sharp: 0 };
      var p = JSON.parse(raw) || {};
      return {
        size: fsClamp(Number(p.size), 80, 160, FS_DEFAULTS.size),
        color:
          typeof p.color === "string" && /^#[0-9a-f]{6}$/i.test(p.color)
            ? p.color
            : FS_DEFAULTS.color,
        weight: fsClamp(Number(p.weight), 300, 800, FS_DEFAULTS.weight),
        sharp: fsClamp(Number(p.sharp), 0, 100, FS_DEFAULTS.sharp),
      };
    } catch (e) {
      return { size: 100, color: "", weight: 400, sharp: 0 };
    }
  }
  function fsApply(p) {
    var s = p || FS_DEFAULTS;
    var r = document.documentElement;
    if (s.size !== FS_DEFAULTS.size) {
      r.dataset.fsSize = "on";
      r.style.setProperty("--fs-size", String(s.size / 100));
    } else {
      delete r.dataset.fsSize;
      r.style.removeProperty("--fs-size");
    }
    if (s.color) {
      r.dataset.fsColor = "on";
      r.style.setProperty("--fs-color", s.color);
      r.style.setProperty("--text", s.color);
    } else {
      delete r.dataset.fsColor;
      r.style.removeProperty("--fs-color");
      r.style.removeProperty("--text");
    }
    if (s.weight !== FS_DEFAULTS.weight) {
      r.dataset.fsWeight = "on";
      r.style.setProperty("--fs-weight", String(s.weight));
    } else {
      delete r.dataset.fsWeight;
      r.style.removeProperty("--fs-weight");
    }
    if (s.sharp !== FS_DEFAULTS.sharp) {
      r.dataset.fsSharp = "on";
      r.style.setProperty("--fs-sharp", String(s.sharp / 100));
    } else {
      delete r.dataset.fsSharp;
      r.style.removeProperty("--fs-sharp");
    }
    return s;
  }
  window.PenroseFont = { defaults: FS_DEFAULTS, key: FS_KEY, read: fsRead, apply: fsApply };
  fsApply(fsRead());

  var mvMatch = /[?&]mdverify=([a-z]*)/.exec(location.search);
  if (!mvMatch) return;
  var mvMode = mvMatch[1] === "diagram" ? "diagram" : "steps";

  function fire(el, type) {
    if (!el) return false;
    el.dispatchEvent(new Event(type, { bubbles: true }));
    return true;
  }
  function setNativeValue(el, value) {
    var proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype
      : el instanceof HTMLSelectElement ? HTMLSelectElement.prototype
      : HTMLInputElement.prototype;
    var setter = Object.getOwnPropertyDescriptor(proto, "value").set;
    setter.call(el, value);
    fire(el, "input");
    fire(el, "change");
  }
  function findButton(label) {
    var all = document.querySelectorAll("button");
    for (var i = 0; i < all.length; i++) {
      if ((all[i].textContent || "").trim() === label) return all[i];
    }
    return null;
  }
  function findNav(label) {
    var all = document.querySelectorAll("button, a");
    for (var i = 0; i < all.length; i++) {
      var t = (all[i].textContent || "").replace(/\s+/g, " ").trim();
      if (t.indexOf(label) !== -1 && all[i].offsetParent !== null) return all[i];
    }
    return null;
  }

  var steps = 0, entered = false;
  function tick() {
    var root = document.documentElement;
    var katex = document.querySelectorAll(".katex").length;
    var strokes = document.querySelectorAll("svg [stroke]").length;
    var theme = root.dataset.theme || "light";
    var wsteps = document.querySelectorAll(".wstep").length;
    if (mvMode === "diagram" ? strokes >= 30 : katex > 0) {
      root.setAttribute("data-mdverify",
        "mode=" + mvMode + ",theme=" + theme + ",katex=" + katex +
        ",strokes=" + strokes + ",wsteps=" + wsteps);
      document.title = "MDVERIFYREADY";
      return;
    }
    if (++steps > 70) {   // report whatever state we reached
      root.setAttribute("data-mdverify",
        "mode=" + mvMode + ",theme=" + theme + ",katex=" + katex +
        ",strokes=" + strokes + ",wsteps=" + wsteps +
        ",entered=" + entered + ",steps=" + steps);
      document.title = "MDVERIFYDONE";
      return;
    }
    if (!document.querySelector(".side-item")) {
      // wait for React to mount before reading/acting on the DOM
      setTimeout(tick, 150);
      return;
    }
    if (!entered) {
      // step 1: leave the welcome screen (name → Let's go)
      var input = document.querySelector('input[type="text"], input:not([type])');
      if (input && !input.value) setNativeValue(input, "Verify");
      var go = findButton("Let's go") ||
        document.querySelector("button.btn.primary:not([disabled]), button[type=submit]:not([disabled])");
      if (go) { try { go.click(); } catch (e) {} }
      if ((document.body.textContent || "").indexOf("Welcome") === -1) entered = true;
    } else {
      // step 2: navigate to the requested section
      var want = mvMode === "diagram" ? (steps < 40 ? "Solve" : "Math Drill") : "Settings";
      var nav = findNav(want) || (mvMode === "diagram" ? findNav("Practice") : null);
      if (nav) { try { nav.click(); } catch (e) {} }
    }
    setTimeout(tick, 200);
  }
  setTimeout(tick, 600);
})();
