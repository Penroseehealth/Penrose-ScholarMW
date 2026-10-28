/* Penrose MathDrill — Settings → Text panel.
 *
 * Injects four controls (font size, colour, thickness, sharpness) into the
 * Settings card, persists them to localStorage["mathdrill.font"] and applies
 * them through the early API declared in theme-boot.js (window.PenroseFont),
 * which is what guarantees a restored value is in place before first paint.
 *
 * It also maintains <html data-calc="on">: while a solution is being worked
 * the brand / user-row header is removed (see font_text.css §5).
 *
 * Everything here is DOM-additive: no React component is patched, and the
 * panel re-inserts itself if a React re-render drops it.
 */
(function () {
  "use strict";

  var API = window.PenroseFont;
  var DEFAULTS = (API && API.defaults) || { size: 100, color: "", weight: 400, sharp: 0 };

  function read() {
    if (API && API.read) return API.read();
    return Object.assign({}, DEFAULTS);
  }
  function apply(state) {
    if (API && API.apply) return API.apply(state);
    return state;
  }
  function persist(state) {
    try {
      localStorage.setItem(API && API.key ? API.key : "mathdrill.font", JSON.stringify(state));
    } catch (e) {
      /* private mode / quota — the value still applies for this session */
    }
  }

  var state = read();

  /* ── vocabulary for the controls ─────────────────────────────── */
  function weightLabel(w) {
    if (w <= 300) return "Light";
    if (w <= 400) return "Regular";
    if (w <= 500) return "Medium";
    if (w <= 600) return "Semibold";
    if (w <= 700) return "Bold";
    return "Extra bold";
  }

  var ROWS = [
    {
      key: "size",
      title: "Font size",
      help: "Scales every step, label and formula. 100% is the app default.",
      label: "Size",
      min: 80,
      max: 160,
      step: 5,
      fmt: function (v) {
        return v + "%";
      },
    },
    {
      key: "color",
      title: "Font colour",
      help: "Text colour for the working. Auto keeps the theme's own palette.",
      type: "color",
    },
    {
      key: "weight",
      title: "Thickness",
      help: "Stroke weight of headings, steps and diagram labels.",
      label: "Weight",
      min: 300,
      max: 800,
      step: 100,
      fmt: weightLabel,
    },
    {
      key: "sharp",
      title: "Sharpness",
      help: "Edge crispness of the glyphs. Off uses the browser default.",
      label: "Edge",
      min: 0,
      max: 100,
      step: 10,
      fmt: function (v) {
        return v === 0 ? "Off" : v + "%";
      },
    },
  ];

  /* ── tiny DOM helpers (no innerHTML: values are user-controlled) ─ */
  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  function rangeRow(def) {
    var row = el("div", "setting");
    row.dataset.fsrow = def.key;

    var text = el("div", "setting-text");
    text.appendChild(el("strong", null, def.title));
    text.appendChild(el("span", "muted small", def.help));
    row.appendChild(text);

    var ctl = el("div", "fs-ctl");
    var wrap = el("label", "slider");
    wrap.appendChild(el("span", "slabel", def.label));

    var input = document.createElement("input");
    input.type = "range";
    input.min = String(def.min);
    input.max = String(def.max);
    input.step = String(def.step);
    input.value = String(state[def.key]);
    input.dataset.fsinput = def.key;
    input.setAttribute("aria-label", def.title);

    var out = el("span", "sval fs-val", def.fmt(state[def.key]));
    input.addEventListener("input", function () {
      state[def.key] = Number(input.value);
      out.textContent = def.fmt(state[def.key]);
      apply(state);
    });
    input.addEventListener("change", function () {
      persist(state);
    });

    wrap.appendChild(input);
    wrap.appendChild(out);
    ctl.appendChild(wrap);
    row.appendChild(ctl);
    return row;
  }

  function colorRow(def) {
    var row = el("div", "setting");
    row.dataset.fsrow = def.key;

    var text = el("div", "setting-text");
    text.appendChild(el("strong", null, def.title));
    text.appendChild(el("span", "muted small", def.help));
    row.appendChild(text);

    var ctl = el("div", "fs-ctl");

    var picker = document.createElement("input");
    picker.type = "color";
    picker.className = "fs-color";
    picker.dataset.fsinput = "color";
    picker.value = state.color || "#1f2a44";
    picker.setAttribute("aria-label", "Font colour");
    picker.addEventListener("input", function () {
      state.color = picker.value;
      apply(state);
      if (autoBtn) autoBtn.textContent = "Auto";
    });
    picker.addEventListener("change", function () {
      persist(state);
    });

    var autoBtn = el("button", "btn ghost small", state.color ? "Auto" : "Auto ✓");
    autoBtn.type = "button";
    autoBtn.title = "Use the theme's own text colour";
    autoBtn.addEventListener("click", function () {
      state.color = "";
      apply(state);
      persist(state);
      picker.value = "#1f2a44";
      autoBtn.textContent = "Auto ✓";
    });

    ctl.appendChild(picker);
    ctl.appendChild(autoBtn);
    row.appendChild(ctl);
    return row;
  }

  /* ── theme, packed into the settings gear alongside the text controls ──
     Same key the app itself reads/writes (mathdrill.theme), so the two
     never disagree: whoever flips it last persists it. */
  var THEME_KEY = "mathdrill.theme";
  function currentTheme() {
    try {
      return localStorage.getItem(THEME_KEY) === "dark" ? "dark" : "light";
    } catch (e) {
      return document.documentElement.dataset.theme === "dark" ? "dark" : "light";
    }
  }
  function setTheme(t) {
    try {
      localStorage.setItem(THEME_KEY, t);
    } catch (e) {
      /* private mode — still applies for this session */
    }
    document.documentElement.dataset.theme = t;
    syncThemeRow();
  }
  function syncThemeRow() {
    var active = currentTheme();
    document.querySelectorAll("[data-fstheme]").forEach(function (btn) {
      var on = btn.dataset.fstheme === active;
      btn.classList.toggle("active", on);
      btn.setAttribute("aria-pressed", String(on));
    });
  }
  function themeRow() {
    var row = el("div", "setting");
    row.dataset.fsrow = "theme";
    var text = el("div", "setting-text");
    text.appendChild(el("strong", null, "Theme"));
    text.appendChild(el("span", "muted small", "Switch between the light and dark look."));
    row.appendChild(text);
    var seg = el("div", "segmented");
    seg.setAttribute("role", "group");
    seg.setAttribute("aria-label", "Theme");
    ["light", "dark"].forEach(function (t) {
      var b = document.createElement("button");
      b.type = "button";
      b.className = "seg";
      b.dataset.fstheme = t;
      b.textContent = t === "light" ? "Light" : "Dark";
      b.setAttribute("aria-pressed", "false");
      b.addEventListener("click", function () {
        setTheme(t);
      });
      seg.appendChild(b);
    });
    row.appendChild(seg);
    syncThemeRow();
    return row;
  }

  function buildGroup(withTheme) {
    var group = el("div", "fs-group");
    group.dataset.fsgroup = "text";

    if (withTheme) group.appendChild(themeRow());

    ROWS.forEach(function (def) {
      group.appendChild(def.type === "color" ? colorRow(def) : rangeRow(def));
    });

    var foot = el("div", "fs-ctl");
    var reset = el("button", "btn ghost small", "Reset text settings");
    reset.type = "button";
    reset.addEventListener("click", function () {
      state = { size: DEFAULTS.size, color: "", weight: DEFAULTS.weight, sharp: DEFAULTS.sharp };
      apply(state);
      persist(state);
      syncInputs();
    });
    foot.appendChild(reset);
    group.appendChild(foot);
    return group;
  }

  function syncInputs() {
    document.querySelectorAll("[data-fsinput]").forEach(function (input) {
      var key = input.dataset.fsinput;
      if (input.type === "color") {
        input.value = state.color || "#1f2a44";
      } else {
        input.value = String(state[key]);
        var out = input.parentElement && input.parentElement.querySelector(".fs-val");
        var def = ROWS.filter(function (d) {
          return d.key === key;
        })[0];
        if (out && def && def.fmt) out.textContent = def.fmt(state[key]);
      }
    });
    syncThemeRow();
  }

  /* Configurations are packed in TWO places on purpose: the Settings page
     (where the app keeps Theme / Working style) and the settings GEAR of the
     solve menu, which is what is on screen while a problem is open. */
  function inject() {
    var ok = false;

    var card = document.querySelector(".settings.card");
    if (card) {
      if (card.querySelector("[data-fsgroup]")) syncInputs();
      else {
        var preview = card.querySelector(".setting-preview");
        var pageGroup = buildGroup(false);
        if (preview) card.insertBefore(pageGroup, preview);
        else card.appendChild(pageGroup);
      }
      ok = true;
    }

    var gear = document.querySelector(".solve-dropdown");
    if (gear) {
      if (gear.querySelector("[data-fsgroup]")) syncInputs();
      else gear.appendChild(buildGroup(true));   // theme + text, packed together
      ok = true;
    }

    syncThemeRow();
    return ok;
  }

  /* ── calculation mode ──────────────────────────────────────────
     A solution is on screen when the solve workspace is open, or the
     practice worked-solution panel is mounted. Settings preview uses
     neither, so it never triggers. */
  function calcActive() {
    return !!(
      document.querySelector(".solve .workspace") ||
      document.querySelector(".md-solscroll") ||
      document.querySelector(".md-solution")
    );
  }
  function syncCalc() {
    var on = calcActive();
    var isOn = document.documentElement.dataset.calc === "on";
    if (on === isOn) return;
    if (on) document.documentElement.dataset.calc = "on";
    else delete document.documentElement.dataset.calc;
  }

  /* ── boot: apply once now, then re-assert on React re-renders ──── */
  apply(read());
  inject();
  syncCalc();

  var timer = null;
  function resync() {
    if (timer) return;
    timer = setTimeout(function () {
      timer = null;
      inject();
      syncCalc();
    }, 120);
  }

  if (window.MutationObserver) {
    new MutationObserver(resync).observe(document.documentElement, {
      childList: true,
      subtree: true,
    });
  }

  // keep the two signals correct across history/back-forward restores
  window.addEventListener("pageshow", resync);
})();
