/* Penrose MathDrill — chat area for asking questions.
 *
 * Two jobs:
 *   1. a transcript + composer that lives inside the Solve section (moves
 *      between the "ask" card and the workspace's step column, never covers
 *      the graph, never renders outside Solve);
 *   2. PASTE FIDELITY — a pasted question must not lose the position of any
 *      character. Rich text keeps <sup>/<sub> (rendered as real sup/sub in
 *      the transcript) and its plain mirror keeps Unicode superscript /
 *      subscript code points (x², H₂O) so the solver receives the same shape
 *      as the original. Whitespace and newlines are preserved verbatim.
 *
 * The composer and the app's own .qbox both go through the same paste
 * handler. Everything is DOM-additive and re-mounted by a MutationObserver
 * if React re-renders the Solve card.
 */
/* the engine lives at the mathsdrill root (shared with workspace.js, so both
   resolve to the same module URL and share one renderer stack) */
import { createMdGraph } from "../graph3d.js";

(function () {
  "use strict";

  /* ── Unicode maps: position-preserving, character-for-character ─── */
  var SUP = {
    "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
    "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
    "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
    n: "ⁿ", i: "ⁱ",
    a: "ᵃ", b: "ᵇ", d: "ᵈ", e: "ᵉ", g: "ᵍ", h: "ʰ",
    j: "ʲ", k: "ᵏ", l: "ˡ", m: "ᵐ", o: "ᵒ", p: "ᵖ",
    r: "ʳ", t: "ᵗ", u: "ᵘ", v: "ᵛ", w: "ʷ", x: "ˣ",
    y: "ʸ", z: "ᶻ",
  };
  var SUB = {
    "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
    "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
    "+": "₊", "-": "₋", "=": "₌",
    a: "ₐ", e: "ₑ", h: "ₕ", i: "ᵢ", j: "ⱼ", k: "ₖ",
    l: "ₗ", m: "ₘ", n: "ₙ", o: "ₒ", p: "ₚ", r: "ᵣ",
    s: "ₛ", t: "ₜ", u: "ᵤ", v: "ᵥ", x: "ₓ",
  };

  function mapChars(text, map) {
    var out = "";
    for (var i = 0; i < text.length; i++) {
      var c = text.charAt(i);
      out += map[c] !== undefined ? map[c] : c;
    }
    return out;
  }

  /* ── rich paste → sanitized tree (positions kept as real sup/sub) ── */
  var KEEP = { SUP: "sup", SUB: "sub", B: "b", STRONG: "b", I: "i", EM: "i", U: "u", BR: null };

  function sanitize(html, fallbackText) {
    var doc;
    try {
      doc = new DOMParser().parseFromString(html, "text/html");
    } catch (e) {
      doc = null;
    }
    if (!doc || !doc.body) return esc(fallbackText || "");
    var frag = document.createElement("div");
    walk(doc.body, frag, null);
    return frag.innerHTML;
  }

  function walk(src, dst, wrapTag) {
    var kids = src.childNodes;
    for (var i = 0; i < kids.length; i++) {
      var n = kids[i];
      if (n.nodeType === 3) {
        // text: never trimmed or collapsed — positions and spacing survive
        dst.appendChild(document.createTextNode(n.nodeValue));
        continue;
      }
      if (n.nodeType !== 1) continue;
      var tag = n.tagName;
      if (tag === "SCRIPT" || tag === "STYLE" || tag === "IFRAME" || tag === "SVG" ||
          tag === "IMG" || tag === "A" || tag === "FORM" || tag === "INPUT") continue;

      var mapped = KEEP[tag];
      // a span that only shifts vertical-align is really a sup/sub
      if (mapped === undefined && tag === "SPAN") {
        var va = (n.style && n.style.verticalAlign) || "";
        if (/super/i.test(va)) mapped = "sup";
        else if (/sub/i.test(va)) mapped = "sub";
        else mapped = "";            // plain span → unwrap
      }
      if (mapped === undefined) {
        // unknown container (p, div, h1…) → keep its text, add a line break
        if (tag === "P" || tag === "DIV" || tag === "LI" || /H[1-6]/.test(tag)) {
          walk(n, dst, null);
          if (i < kids.length - 1) dst.appendChild(document.createElement("br"));
        } else {
          walk(n, dst, null);
        }
        continue;
      }
      if (mapped === null) {
        dst.appendChild(document.createElement("br"));
        continue;
      }
      if (mapped === "") {
        walk(n, dst, null);
        continue;
      }
      var el = document.createElement(mapped);
      walk(n, el, null);
      dst.appendChild(el);
    }
  }

  function esc(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  /* ── rich → plain, keeping every character in its original position ──
     The solver gets the same shape the user pasted: superscript digits stay
     superscript, subscripts stay subscripts, newlines stay newlines. */
  function toPlain(html) {
    var doc;
    try {
      doc = new DOMParser().parseFromString(html, "text/html");
    } catch (e) {
      return html || "";
    }
    return readText(doc.body, "");
  }

  function readText(node, acc) {
    var kids = node.childNodes;
    for (var i = 0; i < kids.length; i++) {
      var n = kids[i];
      if (n.nodeType === 3) { acc += n.nodeValue; continue; }
      if (n.nodeType !== 1) continue;
      var tag = n.tagName;
      if (tag === "BR") { acc += "\n"; continue; }
      if (tag === "SCRIPT" || tag === "STYLE" || tag === "IFRAME" || tag === "IMG") continue;
      if (tag === "SUP") { acc += mapChars(n.textContent, SUP); continue; }
      if (tag === "SUB") { acc += mapChars(n.textContent, SUB); continue; }
      if (tag === "SPAN") {
        var va = (n.style && n.style.verticalAlign) || "";
        if (/super/i.test(va)) { acc += mapChars(n.textContent, SUP); continue; }
        if (/sub/i.test(va)) { acc += mapChars(n.textContent, SUB); continue; }
      }
      if (tag === "P" || tag === "DIV" || tag === "LI" || /H[1-6]/.test(tag)) {
        acc = readText(n, acc) + "\n";
        continue;
      }
      acc = readText(n, acc);
    }
    return acc;
  }

  /* ── shared paste handler for the composer AND the app's .qbox ────── */
  function onPaste(e) {
    var t = e.target;
    if (!t || !t.classList) return;
    var mine = t.classList.contains("hpc-input");
    var qbox = t.classList.contains("qbox");
    if (!mine && !qbox) return;

    var cd = e.clipboardData || window.clipboardData;
    if (!cd) return;
    var html = cd.getData("text/html") || "";
    var plainText = cd.getData("text/plain") || "";
    e.preventDefault();

    if (mine) {
      if (html) {
        var frag = document.createElement("div");
        frag.innerHTML = sanitize(html, plainText);
        insertNodesAtCaret(t, frag.childNodes);
      } else {
        insertTextAtCaret(t, plainText);   // verbatim: no trimming
      }
      return;
    }

    // .qbox is a plain textarea — keep positions by writing Unicode forms
    var out = html ? toPlain(sanitize(html, plainText)) : plainText;
    var start = t.selectionStart || 0;
    var end = t.selectionEnd || 0;
    if (typeof t.setRangeText === "function") t.setRangeText(out, start, end, "end");
    else t.value = t.value.slice(0, start) + out + t.value.slice(end);
    t.dispatchEvent(new Event("input", { bubbles: true }));
  }

  function insertTextAtCaret(el, text) {
    var sel = window.getSelection();
    if (!sel || !sel.rangeCount) { el.appendChild(document.createTextNode(text)); caretEnd(el); return; }
    var range = sel.getRangeAt(0);
    range.deleteContents();
    var node = document.createTextNode(text);
    range.insertNode(node);
    range.setStartAfter(node);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
    afterEdit(el);
  }

  function insertNodesAtCaret(el, nodes) {
    var sel = window.getSelection();
    var range = sel && sel.rangeCount ? sel.getRangeAt(0) : null;
    var list = Array.prototype.slice.call(nodes);
    var last = null;
    if (range) range.deleteContents();          // paste replaces the selection
    for (var i = 0; i < list.length; i++) {
      var n = list[i];
      if (range) {
        range.insertNode(n);
        // advance past the node just inserted — without this the next block
        // lands in front of it and a multi-block paste comes out reversed
        range.setStartAfter(n);
        range.collapse(true);
      } else {
        el.appendChild(n);
      }
      last = n;
    }
    if (last) {
      if (range) {
        range.setStartAfter(last);
        range.collapse(true);
        if (sel) {
          sel.removeAllRanges();
          sel.addRange(range);
        }
      } else {
        caretEnd(el);
      }
    }
    afterEdit(el);
  }

  function caretEnd(el) {
    var sel = window.getSelection();
    if (!sel) return;
    var r = document.createRange();
    r.selectNodeContents(el);
    r.collapse(false);
    sel.removeAllRanges();
    sel.addRange(r);
  }

  function afterEdit(el) {
    el.dispatchEvent(new Event("input", { bubbles: true }));
  }

  /* ── chat UI ─────────────────────────────────────────────────────── */
  function mk(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  var node = mk("div", "hpc-chat");
  node.dataset.hpc = "chat";

  var log = mk("div", "hpc-log");
  log.setAttribute("aria-live", "polite");
  log.setAttribute("aria-label", "Question and answer transcript");
  var empty = mk("div", "hpc-empty",
    "Paste or type a question — superscripts, subscripts and formula spacing are kept exactly as written.");
  log.appendChild(empty);

  var composer = mk("div", "hpc-composer");
  var input = mk("div", "hpc-input");
  input.contentEditable = "true";
  input.setAttribute("role", "textbox");
  input.setAttribute("aria-label", "Question");
  input.setAttribute("aria-multiline", "true");
  input.dataset.ph = "Paste or type your question…";

  var send = mk("button", "btn primary hpc-send", "Ask");
  send.type = "button";

  composer.appendChild(input);
  composer.appendChild(send);
  node.appendChild(log);
  /* The entry panel is pinned to the bottom of the viewport (not inside the
     flow) so it stays visible while a solution is being generated, and it
     travels with the page as a plain body child: no ancestor can transform it
     out of place or clip it. place() hides it outside the Solve section. */
  composer.hidden = true;
  document.body.appendChild(composer);

  function addMsg(role, richHtml, plainText) {
    if (empty.parentNode) empty.parentNode.removeChild(empty);
    var m = mk("div", "hpc-msg " + role);
    m.appendChild(mk("span", "hpc-role", role === "user" ? "You" : "Penrose"));
    var body = mk("div", "hpc-body");
    if (role === "user" && richHtml) {
      body.innerHTML = richHtml;          // already sanitized by sanitize()
      if (plainText && toPlain(richHtml).replace(/\s+/g, "") !== plainText.replace(/\s+/g, "")) {
        body.appendChild(mk("div", "hpc-mirror", plainText));
      }
    } else {
      body.textContent = plainText || "";
    }
    m.appendChild(body);
    log.appendChild(m);
    reveal();
    return m;
  }

  /* keep the newest message on screen. A finished solution opens at the TOP so
     step 1 is the first thing read (the answer and graph follow underneath);
     short messages (the question, the working indicator) open at the bottom. */
  function reveal(mode) {
    log.scrollTop = mode === "top" ? 0 : log.scrollHeight;
    if (node.isConnected && typeof node.scrollIntoView === "function") {
      node.scrollIntoView({ block: "nearest", behavior: "auto" });
    }
  }

  /* ── AI solve: POST /api/v1/mathsdrill/solve ──────────────────────────
     The React classifier only recognises its own built-in families, so the
     chat no longer hands questions to it — that is exactly what produced
     "I couldn't classify that question … Steps and the graph are ready".
     The mathematics tutor answers instead: SymPy first (every line
     independently verified), then the AI provider chain whenever the wording
     cannot be turned into a symbolic problem. */
  function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

  /* Session token handed over by the Flutter host in the embed URL; scrubbed
     from the address bar as soon as it is read so it never sits in history. */
  var TOKEN = "";
  try {
    var qp = new URLSearchParams(window.location.search);
    TOKEN = qp.get("token") || "";
    if (TOKEN) {
      qp.delete("token");
      var left = qp.toString();
      window.history.replaceState(
        null, "", window.location.pathname + (left ? "?" + left : "") + window.location.hash
      );
    }
  } catch (e) {
    TOKEN = "";
  }

  /* ── presentation helpers ──────────────────────────────────────────── */
  var LATEX_WORDS = {
    "\\pm": "±", "\\times": "×", "\\div": "÷", "\\leq": "≤", "\\le": "≤",
    "\\geq": "≥", "\\ge": "≥", "\\neq": "≠", "\\approx": "≈", "\\cdot": "·",
    "\\infty": "∞", "\\pi": "π", "\\theta": "θ", "\\alpha": "α", "\\beta": "β",
    "\\left": "", "\\right": "", "\\substack": "", "\\!": "", "\\,": "",
    "\\;": "", "\\quad": " ",
    "\\text": "", "\\mathrm": "", "\\textrm": "", "\\displaystyle": "",
  };

  /* Word-boundary pass: "\\le" must never eat the start of "\\left"
     (that produced "≤ft." in the worked steps). Longest key first. */
  var LATEX_WORDS_RE = new RegExp(
    "(" + Object.keys(LATEX_WORDS)
      .sort(function (a, b) { return b.length - a.length; })
      .map(function (k) { return k.replace(/([\\^$.*+?()[\]{}|])/g, "\\$1"); })
      .join("|") + ")(?![a-zA-Z])",
    "g"
  );

  /* Steps come back as LaTeX from the symbolic engine; the chat shows plain
     readable maths (the app has no KaTeX global to render into). */
  function latexToText(src) {
    var s = String(src == null ? "" : src);
    for (var i = 0; i < 8 && s.indexOf("\\frac") !== -1; i++) {
      s = s.replace(/\\frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}/g, "($1)/($2)");
    }
    for (var j = 0; j < 8 && s.indexOf("\\sqrt") !== -1; j++) {
      s = s.replace(/\\sqrt\s*(?:\[[^\]]*\])?\s*\{([^{}]*)\}/g, "√($1)");
    }
    s = s.replace(/\\(?:text|mathrm|textrm)\s*\{([^{}]*)\}/g, "$1");
    s = s.replace(/\^\s*\{([^{}]*)\}/g, "^$1");
    s = s.replace(/_\s*\{([^{}]*)\}/g, "_$1");
    s = s.replace(LATEX_WORDS_RE, function (m) { return LATEX_WORDS[m]; });
    s = s.replace(/[{}]/g, function (c) { return c === "{" ? "(" : ")"; });
    s = s.replace(/\\\\/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
    return s;
  }

  function cleanExpr(e) {
    return String(e)
      .replace(/−/g, "-").replace(/–/g, "-")
      .replace(/×/g, "*").replace(/\s+/g, " ")
      .replace(/X/g, "x").trim();
  }

  function fmtPoly(a, b, c) {
    function term(coef, part, first) {
      if (Math.abs(coef) < 1e-12) return "";
      var neg = coef < 0;
      var mag = Math.abs(coef);
      // coefficient 1 must not leave a leading "*" ("*x^2" is not an expression)
      var isOne = part !== "" && Math.abs(mag - 1) < 1e-12;
      var body = isOne
        ? part.replace(/^\*/, "")
        : String(Number(mag.toFixed(6))) + part;
      if (first) return (neg ? "-" : "") + body;
      return (neg ? " - " : " + ") + body;
    }
    var out = term(a, "*x^2", true);
    out += term(b, "*x", out === "");
    out += term(c, "", out === "");
    return out || "0";
  }

  /* Which curve should be drawn for this answer? */
  function deriveExpression(res) {
    var v = res && res.visual;
    if (v && v.kind === "parabola" && v.params) {
      var a = Number(v.params.a), b = Number(v.params.b), c = Number(v.params.c);
      if (isFinite(a) && isFinite(b) && isFinite(c)) return fmtPoly(a, b, c);
    }
    var src = ((res && res.question) || "") + "\n" + ((res && res.answer_latex) || "");
    var lines = src.split("\n");
    for (var i = 0; i < lines.length; i++) {
      var t = cleanExpr(latexToText(lines[i]));
      var m = /^(?:y|f\s*\(\s*x\s*\))\s*=\s*(.+)$/.exec(t);
      if (m && /[x]/.test(m[1])) return cleanExpr(m[1]);
      m = /^(.+?)\s*=\s*0\s*$/.exec(t);
      // an equation in x: only treat it as plottable when it is pure maths
      if (m && /^[\d\sx+\-*/^().,]+$/.test(m[1]) && /[x]/.test(m[1])) {
        return cleanExpr(m[1]);
      }
    }
    return null;
  }

  /* ── graph / diagram rendering for an answer ───────────────────────── */
  var aiGraph = null;

  function svgEl(tag, attrs) {
    var e = document.createElementNS("http://www.w3.org/2000/svg", tag);
    Object.keys(attrs || {}).forEach(function (k) { e.setAttribute(k, String(attrs[k])); });
    return e;
  }
  function svgText(x, y, txt, anchor) {
    var t = svgEl("text", { x: x, y: y, class: "hpc-dg-text" + (anchor ? " " + anchor : "") });
    t.textContent = txt;
    return t;
  }

  function mountGraph(box, expr) {
    if (aiGraph) { try { aiGraph.dispose(); } catch (e) { /* already gone */ } aiGraph = null; }
    box.textContent = "";
    var dark = document.documentElement.dataset.theme === "dark";
    var note = mk("div", "hpc-limit");
    aiGraph = createMdGraph({
      container: box,
      theme: dark ? "dark" : "light",
      onLimitation: function (msg) {
        note.textContent = msg + " — no graph is drawn rather than a wrong one.";
        if (!note.parentNode) box.appendChild(note);
      },
    });
    if (!aiGraph) {
      note.textContent = "The graphing engine could not start.";
      box.appendChild(note);
      return false;
    }
    var res = aiGraph.setProblem({ expr: expr });
    if (!res.ok) {
      note.textContent = (res.error || "Unsupported expression") +
        " — no graph is drawn for “" + expr + "”.";
      box.appendChild(note);
      return false;
    }
    return true;
  }

  function mountTriangle(box, p) {
    var a = Number(p.a) || 0, b = Number(p.b) || 0, c = Number(p.c) || 0;
    var unit = p.unit || "";
    var W = 300, H = 190, pad = 42;
    var s = Math.min((W - pad * 2) / (a || 1), (H - pad * 2) / (b || 1));
    var ox = pad + (W - pad * 2 - a * s) / 2;
    var oy = H - pad;
    var A = [ox, oy], B = [ox + a * s, oy], C = [ox, oy - b * s];
    var pts = function (arr) { return arr.map(function (q) { return q.join(","); }).join(" "); };
    var svg = svgEl("svg", { viewBox: "0 0 " + W + " " + H, class: "hpc-dg", role: "img" });
    svg.setAttribute("aria-label",
      "Right triangle, legs " + a + unit + " and " + b + unit + ", hypotenuse " + c + unit);
    svg.appendChild(svgEl("polygon", { points: pts([A, B, C]), class: "hpc-dg-fill" }));
    svg.appendChild(svgEl("polyline", { points: pts([A, B, C, A]), class: "hpc-dg-line" }));
    var m = Math.min(15, Math.abs(a * s) * 0.3, Math.abs(b * s) * 0.3);
    svg.appendChild(svgEl("polyline", {
      points: pts([[A[0], A[1] - m], [A[0] + m, A[1] - m], [A[0] + m, A[1]]]),
      class: "hpc-dg-line hpc-dg-mark",
    }));
    // "3 cm", not "3cm": the unit comes back as a bare word
    var u = unit ? String(unit).trim() : "";
    var lab = function (n) { return (n + (u ? " " + u : "")).trim(); };
    svg.appendChild(svgText((A[0] + B[0]) / 2, A[1] + 17, lab(a)));
    svg.appendChild(svgText(A[0] - 8, (A[1] + C[1]) / 2, lab(b), "end"));
    svg.appendChild(svgText((B[0] + C[0]) / 2 + 8, (B[1] + C[1]) / 2 - 7, lab(c), "start"));
    box.appendChild(svg);
  }

  function mountBar(box, p) {
    var whole = Number(p.whole) || 0;
    var part = Number(p.part) || 0;
    var frac = whole > 0 ? Math.max(0, Math.min(1, part / whole)) : 0;
    var W = 300, H = 104, x0 = 16, y0 = 22, w = W - 32, h = 36;
    var svg = svgEl("svg", { viewBox: "0 0 " + W + " " + H, class: "hpc-dg", role: "img" });
    svg.setAttribute("aria-label",
      (p.percent != null ? p.percent + " percent" : Math.round(frac * 100) + " percent") +
      " of " + whole + " equals " + part);
    svg.appendChild(svgEl("rect", { x: x0, y: y0, width: w, height: h, rx: 5, class: "hpc-dg-line" }));
    svg.appendChild(svgEl("rect", {
      x: x0, y: y0, width: w * frac, height: h, rx: 5, class: "hpc-dg-fill hpc-dg-bar",
    }));
    svg.appendChild(svgText(W / 2, y0 + h + 24,
      (p.percent != null ? p.percent + "%" : Math.round(frac * 100) + "%") +
      " of " + whole + " = " + part));
    box.appendChild(svg);
  }

  function renderSolution(m, res) {
    var body = m.querySelector(".hpc-body");
    if (!body) return;
    body.textContent = "";

    var src = res.source || "sympy";
    var head = mk("div", "hpc-solhead");
    head.appendChild(mk("span", "hpc-topic",
      (res.subject || "mathematics") + " · " + (res.topic || "")));
    var badges = mk("span", "hpc-badges");
    var srcLabel = src === "ai" ? "AI tutor"
      : src === "clarification" ? "Needs more detail" : "SymPy verified";
    badges.appendChild(mk("span", "hpc-badge hpc-src-" + src, srcLabel));
    if (res.verification_status) {
      badges.appendChild(mk("span", "hpc-badge hpc-ver",
        String(res.verification_status).replace(/_/g, " ")));
    }
    head.appendChild(badges);
    body.appendChild(head);

    var steps = Array.isArray(res.steps) ? res.steps : [];
    if (steps.length) {
      var list = mk("ol", "hpc-steps");
      steps.forEach(function (st, i) {
        var li = mk("li", "hpc-step");
        li.appendChild(mk("span", "hpc-step-n", String(i + 1)));
        var col = mk("div", "hpc-step-col");
        if (st.title) col.appendChild(mk("div", "hpc-step-title", st.title));
        (st.latex_lines || []).forEach(function (line) {
          var t = latexToText(line);
          if (t) col.appendChild(mk("div", "hpc-step-work", t));
        });
        if (st.explanation) col.appendChild(mk("div", "hpc-step-why", st.explanation));
        li.appendChild(col);
        list.appendChild(li);
      });
      body.appendChild(list);
    }

    var answer = res.answer_latex || res.answer_text || "";
    if (answer) {
      var ans = mk("div", "hpc-answer");
      ans.appendChild(mk("span", "hpc-answer-lbl",
        src === "clarification" ? "What I still need" : "Answer"));
      ans.appendChild(mk("span", "hpc-answer-val", latexToText(answer)));
      body.appendChild(ans);
    }
    if (res.verification_detail) {
      body.appendChild(mk("div", "hpc-verdict", latexToText(res.verification_detail)));
    }

    var v = res.visual;
    var expr = deriveExpression(res);
    if (expr) {
      var gw = mk("div", "hpc-graph");
      body.appendChild(gw);
      if (mountGraph(gw, expr)) body.appendChild(mk("div", "hpc-cap", "y = " + expr));
    } else if (v && v.kind === "right_triangle") {
      var d1 = mk("div", "hpc-diagram");
      body.appendChild(d1);
      mountTriangle(d1, v.params || {});
      if (v.caption) body.appendChild(mk("div", "hpc-cap", latexToText(v.caption)));
    } else if (v && v.kind === "percentage_bar") {
      var d2 = mk("div", "hpc-diagram");
      body.appendChild(d2);
      mountBar(d2, v);
      if (v.caption) body.appendChild(mk("div", "hpc-cap", latexToText(v.caption)));
    }
    if (src === "clarification") {
      body.appendChild(mk("div", "hpc-hint",
        "Give me the missing numbers or the exact equation and I will work it through."));
    }
    // reveal AFTER the answer is fully built — and start at step 1
    reveal("top");
  }

  var running = false;
  async function ask() {
    if (running) return;
    var rich = input.innerHTML.trim();
    var plain = toPlain(rich);
    if (!plain.trim()) { input.focus(); return; }

    addMsg("user", rich, plain);
    input.innerHTML = "";
    running = true;
    send.setAttribute("aria-busy", "true");
    send.textContent = "Working…";
    var pending = mk("div", "hpc-pending", "Working out your question…");
    log.appendChild(pending);
    log.scrollTop = log.scrollHeight;

    try {
      var headers = { "Content-Type": "application/json" };
      if (TOKEN) headers.Authorization = "Bearer " + TOKEN;
      var resp = await fetch("/api/v1/mathsdrill/solve", {
        method: "POST",
        headers: headers,
        body: JSON.stringify({ question: plain }),
      });
      if (pending.parentNode) pending.parentNode.removeChild(pending);

      if (resp.status === 401 || resp.status === 403) {
        addMsg("bot", null,
          "Sign in to Penrose to use the AI solver — this window has no session, so the question was not sent.");
        return;
      }
      if (!resp.ok) {
        addMsg("bot", null,
          "The solver could not be reached (HTTP " + resp.status + "). Please try again in a moment.");
        return;
      }
      var res = await resp.json();
      renderSolution(addMsg("bot", null, ""), res);
    } catch (err) {
      if (pending.parentNode) pending.parentNode.removeChild(pending);
      addMsg("bot", null,
        "The solver could not be reached (" + err.message + "). Check the connection and try again.");
    } finally {
      running = false;
      send.removeAttribute("aria-busy");
      send.textContent = "Ask";
    }
  }

  send.addEventListener("click", function () { ask(); });
  input.addEventListener("keydown", function (e) {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); ask(); }
  });
  document.addEventListener("paste", onPaste, true);

  /* ── transcript lives in Solve; the entry panel stays pinned to the bottom
     of the viewport for the whole calculation (see .hpc-composer in the CSS)
     and is only shown while the Solve section is on screen. ─────────────── */
  function place() {
    var inSolve = !!document.querySelector(".solve");
    composer.hidden = !inSolve;
    if (inSolve) document.documentElement.dataset.hpc = "on";
    else delete document.documentElement.dataset.hpc;

    if (!inSolve) {
      if (node.parentElement) node.parentElement.removeChild(node);
      return;
    }
    var ws = document.querySelector(".solve .workspace");
    var panel = ws && ws.querySelector(".panel");
    var card = document.querySelector(".solve .solve-input.card") ||
      document.querySelector(".solve .solve-input");
    var host = panel || card || document.querySelector(".solve");
    if (!host || node.parentElement === host) return;
    if (panel) {
      host.insertBefore(node, host.firstChild);
      return;
    }
    if (card) {
      // sit between the card's intro and its own question box, so the answer
      // is above the fold instead of after the example chips
      var anchor = card.querySelector("p.muted");
      if (anchor && anchor.nextSibling) card.insertBefore(node, anchor.nextSibling);
      else card.appendChild(node);
      return;
    }
    host.appendChild(node);
  }

  place();

  var t = null;
  function schedule() {
    if (t) return;
    t = setTimeout(function () { t = null; place(); }, 120);
  }
  if (window.MutationObserver) {
    new MutationObserver(schedule).observe(document.documentElement, {
      childList: true,
      subtree: true,
    });
  }
  window.addEventListener("pageshow", schedule);
  window.addEventListener("pagehide", function () {
    if (aiGraph) {
      try { aiGraph.dispose(); } catch (e) { /* already gone */ }
      aiGraph = null;
    }
  });
})();
