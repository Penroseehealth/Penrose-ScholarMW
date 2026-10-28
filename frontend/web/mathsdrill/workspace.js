/* MathDrill workspace glue — full-screen layout state, compact graph toolbar,
   and the synchronisation bridge between the React app's DOM and the Three.js
   graphing engine (graph3d + graph_core).

   • sets data-mdws on <html> (sidebars collapse; the rail becomes a hamburger)
   • builds the toolbar inside the existing question header
   • watches #md-fn (the app's own function selector) and the worked-solution
     steps, feeding the engine and highlighting matching features both ways
   • keeps the original SVG diagram as the documented fallback when an
     expression cannot be handled (never a fabricated graph)
   • URL probe ?mdws=1 mirrors engine state into data-mdws-state for tests
*/

import { createMdGraph } from "./graph3d.js";
import { normalizeExpr, fmtCoord } from "./graph_core.js";

(function workspace() {
  const doc = document;
  const root = doc.documentElement;
  root.dataset.mdws = "on";                    // MathDrill is open → workspace layout

  let engine = null, engineWrap = null, stepTexts = [], initScale = null, failNorm = null;

  /* ── collapsible navigation (never reserves width) ── */
  const menu = doc.createElement("button");
  menu.className = "g3tb-menu";
  menu.type = "button";
  menu.title = "Menu";
  menu.setAttribute("aria-label", "Toggle navigation menu");
  menu.textContent = "\u2630";
  menu.addEventListener("click", () => root.classList.toggle("md-rail-open"));
  doc.body.appendChild(menu);

  const sel = () => doc.getElementById("md-fn");
  const wrap = () => doc.querySelector(".md-graph .canvas-wrap");
  const grid = () => doc.querySelector(".mathdrill .md-grid");
  const header = () => doc.querySelector(".md-header");

  function selectedExpr() {
    /* probe-only override (?expr=… with ?mdws=1) so headless tests can drive
       arbitrary families through the real UI; absent in production use */
    if (window.__mdwsExprOverride && /[?&]mdws=1/.test(location.search)) {
      return window.__mdwsExprOverride;
    }
    const s = sel();
    if (!s || s.selectedIndex < 0) return null;
    const opt = s.options[s.selectedIndex];
    return opt ? (opt.text || opt.textContent || "").trim() : null;
  }
  function collectSteps() {
    return Array.from(doc.querySelectorAll(".md-solscroll .md-step"))
      .map((el) => (el.textContent || "").replace(/\s+/g, " ").trim());
  }

  /* ── notices ── */
  function showLimit(msg) {
    const w = wrap();
    if (!w) return;
    let el = w.querySelector(".g3d-lim");
    if (!el) { el = doc.createElement("div"); el.className = "g3d-lim"; el.setAttribute("role", "status"); w.appendChild(el); }
    el.textContent = msg;
  }
  function clearLimit() {
    const w = wrap();
    const el = w && w.querySelector(".g3d-lim");
    if (el) el.remove();
  }
  function showSvg(on) {
    const w = wrap();
    if (w) w.classList.toggle("g3d-on", !!on);
  }

  /* ── compact toolbar inside the existing question header ── */
  function buildToolbar() {
    const h = header();
    if (!h || h.querySelector(".g3tb")) return;
    const tb = doc.createElement("div");
    tb.className = "g3tb";
    tb.setAttribute("role", "group");
    tb.setAttribute("aria-label", "Graph tools");
    const btn = (label, title, fn, pressed) => {
      const b = doc.createElement("button");
      b.className = "g3b" + (pressed ? " on" : "");
      b.type = "button";
      b.textContent = label;
      b.title = title;
      if (pressed !== undefined) b.setAttribute("aria-pressed", String(!!pressed));
      b.addEventListener("click", () => fn(b));
      tb.appendChild(b);
      return b;
    };
    const sep = () => {
      const s = doc.createElement("span");
      s.className = "g3sep";
      tb.appendChild(s);
    };
    const t = engine ? engine.toggles : { labels: true, grid: true, asymp: true };
    btn("Labels", "Show or hide coordinate annotations", (b) => {
      const v = !engine.toggles.labels;
      engine.setToggle("labels", v);
      b.classList.toggle("on", v); b.setAttribute("aria-pressed", String(v));
    }, t.labels);
    btn("Grid", "Show or hide gridlines", (b) => {
      const v = !engine.toggles.grid;
      engine.setToggle("grid", v);
      b.classList.toggle("on", v); b.setAttribute("aria-pressed", String(v));
    }, t.grid);
    btn("Asymp", "Show or hide asymptotes", (b) => {
      const v = !engine.toggles.asymp;
      engine.setToggle("asymp", v);
      b.classList.toggle("on", v); b.setAttribute("aria-pressed", String(v));
    }, t.asymp);
    sep();
    btn("\u2212", "Zoom out", () => engine.zoomOut());
    btn("+", "Zoom in", () => engine.zoomIn());
    btn("Reset", "Reset to the default view", () => engine.resetView());
    sep();
    const g = grid();
    const setPan = (mode) => {
      if (g) g.dataset.panels = mode;
      Array.prototype.forEach.call(tb.querySelectorAll("[data-panel]"), (x) => {
        const on = x.dataset.panel === mode;
        x.classList.toggle("on", on);
        x.setAttribute("aria-pressed", String(on));
      });
      if (engine) setTimeout(() => engine.resize(), 80);
    };
    const cur = g && g.dataset.panels ? g.dataset.panels : "both";
    [["both", "Both"], ["graph", "Graph"], ["steps", "Steps"]].forEach(([m, l]) => {
      const b = btn(l, "Prioritise the " + l.toLowerCase() + " view", () => setPan(m), m === cur);
      b.dataset.panel = m;
    });
    sep();
    btn(root.dataset.theme === "dark" ? "\u2600 Light" : "\u263E Dark",
      "Switch theme (same store as Settings \u2192 Theme)", (b) => {
        const nd = root.dataset.theme !== "dark";
        try { localStorage.setItem("mathdrill.theme", nd ? "dark" : "light"); } catch (e) { /* ignore */ }
        root.dataset.theme = nd ? "dark" : "light";
        b.textContent = nd ? "\u2600 Light" : "\u263E Dark";
        b.classList.toggle("on", nd);
      }, root.dataset.theme === "dark");
    h.appendChild(tb);
  }

  /* ── engine lifecycle (one renderer per solve view; reused across questions) ── */
  function ensureEngine() {
    const w = wrap();
    if (!w) return null;
    if (engine && engineWrap === w) return engine;
    if (engine) { engine.dispose(); engine = null; }   // solve view was unmounted
    w.style.position = w.style.position || "relative";
    w.classList.remove("g3d-on");
    engine = createMdGraph({
      container: w,
      theme: root.dataset.theme === "dark" ? "dark" : "light",
      onLimitation: (msg) => {
        showLimit(msg + " \u2014 the original diagram is shown instead.");
        showSvg(false);                 // documented fallback: never a fake graph
      },
      onPick: (pt) => syncStepToFeature(pt),
    });
    if (!engine) { engineWrap = null; showSvg(false); return null; }
    engineWrap = w;
    return engine;
  }

  /* ── question + steps synchronisation ── */
  function loadQuestion() {
    const e = ensureEngine();
    if (!e) return;
    const expr = selectedExpr();
    if (!expr) return;
    const res = e.setProblem({ expr });   // failure → onLimitation callback shows the notice
    failNorm = res.ok ? null : normalizeExpr(expr);
    if (res.ok) {
      clearLimit();
      showSvg(true);
      syncStepsToGraph();
    }
  }
  function syncStepsToGraph() {
    if (engine && stepTexts.length) engine.highlightFromText(stepTexts);
  }
  function syncStepToFeature(pt) {
    const steps = doc.querySelectorAll(".md-solscroll .md-step");
    const tight = (str) => str.replace(/\s+/g, "");
    const want = fmtCoord(pt.x, pt.y);
    for (const el of steps) {
      const txt = (el.textContent || "").replace(/\u2212/g, "-").replace(/\s+/g, " ");
      if (txt.includes(want) || tight(txt).includes(tight(want))) {
        el.classList.remove("md-flip");
        void el.offsetWidth;                       // restart the flash animation
        el.classList.add("md-flip");
        el.scrollIntoView({ block: "nearest", behavior: "smooth" });
        setTimeout(() => el.classList.remove("md-flip"), 1600);
        return;
      }
    }
  }

  /* ── debounced DOM sync ── */
  let syncT = 0;
  function scheduleSync() { clearTimeout(syncT); syncT = setTimeout(syncAll, 150); }
  function syncAll() {
    const w = wrap();
    if (!w || !sel()) {
      if (engine) { engine.dispose(); engine = null; engineWrap = null; }  // left the solve view
      return;
    }
    const e = ensureEngine();
    if (!e) return;
    const g = grid();
    if (g && !g.dataset.panels) g.dataset.panels = "both";   // default prioritisation state
    buildToolbar();
    const expr = selectedExpr();
    if (!expr) return;
    const norm = normalizeExpr(expr);
    const state = e.getState();
    if (state.ok ? state.norm !== norm : failNorm !== norm) loadQuestion();
    const steps = collectSteps();
    if (JSON.stringify(steps) !== JSON.stringify(stepTexts)) {
      stepTexts = steps;
      syncStepsToGraph();
    }
  }

  new MutationObserver(scheduleSync).observe(doc.body, { childList: true, subtree: true });
  doc.addEventListener("change", (ev) => { if (ev.target && ev.target.id === "md-fn") scheduleSync(); });

  /* theme comes from the app's own store (Settings → Theme) */
  new MutationObserver(() => {
    if (engine) engine.setTheme(root.dataset.theme === "dark" ? "dark" : "light");
    const b = doc.querySelector(".g3tb [title*='Switch theme']");
    if (b) b.textContent = root.dataset.theme === "dark" ? "\u2600 Light" : "\u263E Dark";
  }).observe(root, { attributes: true, attributeFilter: ["data-theme"] });

  /* ── URL probe for headless verification ── */
  if (/[?&]mdws=1/.test(location.search)) {
    /* probe-only: ?expr=… feeds the engine a raw expression (asymptote /
       family checks through the real renderer); ?fn=N selects the N-th
       function from the app's own selector (expression → update path) */
    const expr = (location.search.match(/[?&]expr=([^&]+)/) || [])[1];
    if (expr) window.__mdwsExprOverride = decodeURIComponent(expr);
    const fnSel = (location.search.match(/[?&]fn=(\d+)/) || [])[1];
    if (fnSel !== undefined) {
      const pick = () => {
        const s = sel();
        if (!s || s.options.length <= Number(fnSel)) return false;
        s.selectedIndex = Number(fnSel);
        s.dispatchEvent(new Event("change", { bubbles: true }));
        return true;
      };
      if (!pick()) {
        const wait = setInterval(() => { if (pick()) clearInterval(wait); }, 200);
        setTimeout(() => clearInterval(wait), 8000);
      }
    }
    const iv = setInterval(() => {
      if (!engine) return;
      const s = engine.getState();
      if (initScale === null) {
        initScale = s.scale;
        const cv = engine.renderer.domElement;
        const rc = cv.getBoundingClientRect();
        cv.dispatchEvent(new WheelEvent("wheel", {
          deltaY: -260, clientX: rc.left + rc.width / 2, clientY: rc.top + rc.height / 2,
          bubbles: true, cancelable: true,
        }));
      }
      const sb = doc.querySelector(".app-sidebar");
      const railHidden = sb ? sb.getBoundingClientRect().right <= 2 : false;
      root.setAttribute("data-mdws-state", JSON.stringify({
        ok: s.ok, norm: s.norm, roots: s.roots, vertex: s.vertex, axis: s.axis, yint: s.yint,
        asymp: s.asymp, scale: s.scale, center: s.center, zoomed: s.scale !== initScale,
        theme: s.theme, labels: s.labels, grid: s.grid, asympOn: s.asympOn,
        steps: stepTexts.length, panels: (grid() && grid().dataset.panels) || "",
        toolbar: !!doc.querySelector(".g3tb"), railHidden: railHidden,
        limitation: (doc.querySelector(".g3d-lim") || {}).textContent || null,
      }));
      root.title = "MDWSREADY";
    }, 400);
  }

  /* first paint */
  scheduleSync();
})();
