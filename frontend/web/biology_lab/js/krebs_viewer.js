/* Krebs cycle lesson viewer (P3-001/P3-002/P4-001).
 *
 * A self-contained overlay for the curated Krebs model (krebs.js). It renders the
 * eight reactions as a 2D SVG cycle with the link reaction (pyruvate -> acetyl-CoA)
 * feeding in, and drives an interactive walkthrough:
 *   - step highlight on the cycle
 *   - narration text per step (verified science only)
 *   - pause / replay / step-through controls
 *   - a short quiz at the end
 *
 * Accessibility (P3-002): every control is a real <button> with an aria-label and
 * keyboard-operable; the stage list is exposed with aria-live narration; the SVG
 * carries a role="img" + <title>/<desc>; layout is responsive (SVG viewBox) and
 * respects prefers-reduced-motion.
 *
 * This is a DOM/SVG module: it uses no THREE and no network. It reads the curated
 * model read-only; it never mutates science.
 */
import { KREBS_MODEL, verifyModel } from "./krebs.js";

var NS = "http://www.w3.org/2000/svg";

function el(tag, attrs, style) {
  var e = document.createElement(tag);
  if (attrs) Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); });
  if (style) e.style.cssText = style;
  return e;
}

function reducedMotion() {
  try { return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches; } catch (e) { return false; }
}

export function createKrebsViewer(options) {
  var opts = options || {};
  var container = opts.container;
  var model = opts.model || KREBS_MODEL;
  var onNarrate = typeof opts.onNarrate === "function" ? opts.onNarrate : null;

  var check = verifyModel(model);
  var order = model.stages.slice().sort(function (a, b) { return a.n - b.n; });

  var wrapper = el("div", { class: "krebs-viewer", role: "group", "aria-label": "Citric acid (Krebs) cycle lesson" },
    "position:absolute;inset:0;display:flex;flex-direction:column;background:#0d1522;color:#dfe8f5;font:14px 'Segoe UI',system-ui,sans-serif;overflow:hidden;");
  if (container) {
    if (getComputedStyle(container).position === "static") container.style.position = "relative";
    container.appendChild(wrapper);
  }

  /* ---- header ---- */
  var header = el("div", null, "flex:0 0 auto;padding:10px 14px;border-bottom:1px solid #1e2c3f;display:flex;align-items:center;gap:10px;");
  header.appendChild(el("strong", null, "font-size:15px;")).textContent = model.title;
  var badge = el("span", null, "font-size:11px;padding:2px 7px;border-radius:10px;background:#12351f;color:#7fe3a3;border:1px solid #1f6b3a;");
  badge.textContent = check.ok ? "curated science" : "data warning";
  if (!check.ok) badge.style.cssText = "font-size:11px;padding:2px 7px;border-radius:10px;background:#3a1d1d;color:#ff9a9a;border:1px solid #7a2f2f;";
  header.appendChild(badge);
  var close = el("button", { "aria-label": "Close Krebs cycle lesson", title: "Close" }, "margin-left:auto;background:#1b2737;color:#dfe8f5;border:1px solid #2c3f57;border-radius:6px;padding:4px 10px;cursor:pointer;");
  close.textContent = "Close";
  close.addEventListener("click", function () { destroy(); if (opts.onClose) opts.onClose(); });
  header.appendChild(close);
  wrapper.appendChild(header);

  /* ---- body: svg + side panel ---- */
  var body = el("div", null, "flex:1 1 auto;display:flex;min-height:0;flex-wrap:wrap;");
  var svgWrap = el("div", null, "flex:1 1 420px;min-width:0;position:relative;display:flex;align-items:center;justify-content:center;padding:8px;");
  var svg = document.createElementNS(NS, "svg");
  svg.setAttribute("viewBox", "-40 15 520 430");
  svg.setAttribute("preserveAspectRatio", "xMidYMid meet");
  svg.setAttribute("role", "img");
  svg.setAttribute("aria-label", "Citric acid cycle diagram showing eight reactions and the link reaction");
  svg.style.cssText = "width:100%;height:100%;max-height:100%;";
  var title = document.createElementNS(NS, "title");
  title.textContent = model.title + " - eight reactions regenerating oxaloacetate";
  var desc = document.createElementNS(NS, "desc");
  desc.textContent = "Acetyl-CoA from the link reaction enters at citrate synthase; the cycle regenerates oxaloacetate after eight reactions, releasing carbon dioxide and producing NADH, FADH2 and GTP.";
  svg.appendChild(title); svg.appendChild(desc);
  svgWrap.appendChild(svg);
  body.appendChild(svgWrap);

  var panel = el("div", null, "flex:1 1 300px;max-width:380px;padding:12px 14px;border-left:1px solid #1e2c3f;overflow:auto;");
  body.appendChild(panel);
  wrapper.appendChild(body);

  /* ---- controls ---- */
  var controls = el("div", null, "flex:0 0 auto;padding:8px 14px;border-top:1px solid #1e2c3f;display:flex;gap:8px;align-items:center;flex-wrap:wrap;");
  var btnStyle = "background:#1b2737;color:#dfe8f5;border:1px solid #2c3f57;border-radius:6px;padding:6px 12px;cursor:pointer;font:13px inherit;";
  var prev = mkBtn("Previous step", "Previous");
  var play = mkBtn("Play or pause the walkthrough", "Play");
  var next = mkBtn("Next step", "Next");
  var replay = mkBtn("Replay from the start", "Replay");
  var quizBtn = mkBtn("Start the quiz", "Quiz");
  function mkBtn(label, text) { var b = el("button", { "aria-label": label }); b.style.cssText = btnStyle; b.textContent = text; controls.appendChild(b); return b; }
  var progress = el("span", null, "margin-left:auto;color:#9fb0c8;font-size:12px;");
  progress.setAttribute("aria-live", "polite");
  controls.appendChild(progress);
  wrapper.appendChild(controls);

  /* ---- build the cycle geometry ---- */
  var cx = 220, cy = 220, R = 150;
  var nodes = [];
  var n = order.length;
  for (var i = 0; i < n; i++) {
    var ang = -Math.PI / 2 + (i * 2 * Math.PI) / n;
    nodes.push({ x: cx + R * Math.cos(ang), y: cy + R * Math.sin(ang) });
  }
  var gArrows = document.createElementNS(NS, "g");
  var gNodes = document.createElementNS(NS, "g");
  svg.appendChild(gArrows); svg.appendChild(gNodes);

  /* Map a curated intermediate name to its offline structure SVG (rendered by
     RDKit from verified SMILES; see assets/structures/). Names come straight
     from krebs.js, so this is science-driven, never inferred. */
  var STRUCTURE = {
    "oxaloacetate": "oxaloacetate",
    "citrate": "citrate",
    "isocitrate": "isocitrate",
    "alpha-ketoglutarate": "alpha_ketoglutarate",
    "succinyl-CoA": "succinyl_coa",
    "succinate": "succinate",
    "fumarate": "fumarate",
    "malate": "malate",
  };
  /* Molecular formula of each intermediate, as drawn (the free-acid form that
     the RDKit structure depicts). Digits are rendered as subscripts. */
  var FORMULA = {
    "oxaloacetate": "C4H4O5",
    "citrate": "C6H8O7",
    "isocitrate": "C6H8O7",
    "alpha-ketoglutarate": "C5H6O5",
    "succinyl-CoA": "C25H40N7O19P3S",
    "succinate": "C4H6O4",
    "fumarate": "C4H4O4",
    "malate": "C4H6O5",
  };
  /* The ion the cell actually uses, with its charge as a superscript. */
  var ION = {
    "oxaloacetate": { label: "oxaloacetate", charge: "2\u2212", formula: "C4H2O5" },
    "citrate": { label: "citrate", charge: "3\u2212", formula: "C6H5O7" },
    "isocitrate": { label: "isocitrate", charge: "3\u2212", formula: "C6H5O7" },
    "alpha-ketoglutarate": { label: "2-oxoglutarate", charge: "2\u2212", formula: "C5H2O5" },
    "succinate": { label: "succinate", charge: "2\u2212", formula: "C4H4O4" },
    "fumarate": { label: "fumarate", charge: "2\u2212", formula: "C4H2O4" },
    "malate": { label: "malate", charge: "2\u2212", formula: "C4H4O5" },
  };

  /* A "+" or "-" is only a charge when it closes a chemical token (end of the
     string or before a space): "NAD+" and "citrate2-" are charges, but the
     hyphen in "CoA-SH" is a bond and must stay in the base text. */
  function isCharge(s, i) {
    var next = i + 1 < s.length ? s.charAt(i + 1) : " ";
    return next === " " || next === "";
  }
  /* Split a formula into runs so subscripts and superscripts can be typeset.
     Digits after a letter are subscripts; a closing charge is a superscript. */
  function formulaParts(str) {
    var out = [], s = String(str == null ? "" : str), i = 0;
    while (i < s.length) {
      var ch = s.charAt(i);
      if (ch >= "0" && ch <= "9") {
        var d = "";
        while (i < s.length && s.charAt(i) >= "0" && s.charAt(i) <= "9") { d += s.charAt(i); i++; }
        out.push({ t: d, k: "sub" });
      } else if ((ch === "+" || ch === "-") && isCharge(s, i)) {
        out.push({ t: ch === "-" ? "\u2212" : "+", k: "sup" });
        i++;
      } else {
        out.push({ t: ch, k: "base" });
        i++;
      }
    }
    return out;
  }
  function escapeHtml(t) {
    return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }
  /* Same formula as HTML, with real <sub>/<sup> markup. */
  function formulaHtml(str) {
    return formulaParts(str).map(function (p) {
      var t = escapeHtml(p.t);
      if (p.k === "sub") return "<sub>" + t + "</sub>";
      if (p.k === "sup") return "<sup>" + t + "</sup>";
      return t;
    }).join("");
  }
  /* Runs for a physiological ion: name with a superscript charge, then the
     formula of the ion itself, e.g. citrate(3-) C6H5O7(3-). */
  function ionParts(ion) {
    var out = formulaParts(ion.label);
    out.push({ t: ion.charge, k: "sup" });
    out.push({ t: " (", k: "base" });
    out = out.concat(formulaParts(ion.formula));
    out.push({ t: ")", k: "base" });
    return out;
  }
  function ionHtml(ion) {
    return ionParts(ion).map(function (p) {
      var t = escapeHtml(p.t);
      if (p.k === "sub") return "<sub>" + t + "</sub>";
      if (p.k === "sup") return "<sup>" + t + "</sup>";
      return t;
    }).join("");
  }
  /* Reaction equations mix operators with chemical tokens: " + " is an
     addition operator, while an unspaced "+" that closes a token is a charge
     (NAD+ -> NAD with a superscript). "->" becomes a real arrow glyph.
     Operators are marked with sentinels first, so the surrounding spaces are
     consumed exactly once and the spacing stays even. */
  var ARROW = "\u0002", PLUS = "\u0001";
  function reactionParts(str) {
    var out = [], i = 0;
    var s = String(str == null ? "" : str)
      .replace(/\s*->\s*/g, ARROW)
      .replace(/ \+ /g, PLUS);
    while (i < s.length) {
      var ch = s.charAt(i);
      if (ch >= "0" && ch <= "9") {
        var d = "";
        while (i < s.length && s.charAt(i) >= "0" && s.charAt(i) <= "9") { d += s.charAt(i); i++; }
        out.push({ t: d, k: "sub" });
      } else if ((ch === "+" || ch === "-") && reactionIsCharge(s, i)) {
        out.push({ t: ch === "-" ? "\u2212" : "+", k: "sup" }); i += 1;
      } else if (ch === ARROW) {
        out.push({ t: " \u2192 ", k: "base" }); i += 1;
      } else if (ch === PLUS) {
        out.push({ t: " + ", k: "base" }); i += 1;
      } else {
        out.push({ t: ch, k: "base" }); i += 1;
      }
    }
    return out;
  }
  /* A charge ends a token, and an operator also ends it. */
  function reactionIsCharge(s, i) {
    var next = i + 1 < s.length ? s.charAt(i + 1) : " ";
    return next === " " || next === "" || next === ARROW || next === PLUS;
  }
  function reactionHtml(str) {
    return reactionParts(str).map(function (p) {
      var t = escapeHtml(p.t);
      if (p.k === "sub") return "<sub>" + t + "</sub>";
      if (p.k === "sup") return "<sup>" + t + "</sup>";
      return t;
    }).join("");
  }
  /* Formula as SVG text with true sub/superscripts (dy + reduced font-size). */
  function formulaSvg(parent, str, opts) {
    var o = opts || {};
    var fs = o.size || 9;
    var text = document.createElementNS(NS, "text");
    text.setAttribute("x", o.x); text.setAttribute("y", o.y);
    text.setAttribute("text-anchor", o.anchor || "middle");
    text.setAttribute("fill", o.fill || "#dfe8f5");
    text.setAttribute("font-size", String(fs));
    if (o.weight) text.setAttribute("font-weight", o.weight);
    if (o.title) { var tt = document.createElementNS(NS, "title"); tt.textContent = o.title; text.appendChild(tt); }
    var shift = 0;
    formulaParts(str).forEach(function (p) {
      var target = p.k === "sub" ? fs * 0.22 : (p.k === "sup" ? -fs * 0.42 : 0);
      var ts = document.createElementNS(NS, "tspan");
      if (p.k === "sub" || p.k === "sup") ts.setAttribute("font-size", (fs * 0.72).toFixed(2));
      var dy = target - shift;
      if (Math.abs(dy) > 0.01) ts.setAttribute("dy", dy.toFixed(2));
      shift = target;
      ts.textContent = p.t;
      text.appendChild(ts);
    });
    parent.appendChild(text);
    return text;
  }

  var NODE_BOX = 60;   /* side of the structure card */
  var BADGE_R = 9;     /* small shaded circle that carries the step number */

  var nodeEls = [];
  for (var j = 0; j < n; j++) {
    var p = nodes[j], q = nodes[(j + 1) % n];
    var a = arrow(p, q, NODE_BOX / 2);
    gArrows.appendChild(a);
    /* Stage j PRODUCES node j, so the cofactors it releases belong on the
       arrow that enters node j (from node j-1) - not on the arrow leaving it. */
    cofactorChips(gArrows, nodes[(j + n - 1) % n], p, order[j]);

    var g = document.createElementNS(NS, "g");
    g.setAttribute("tabindex", "0");
    g.setAttribute("role", "button");
    g.setAttribute("aria-label", "Step " + order[j].n + ": " + order[j].name + ", " + order[j].to);

    /* white card holding the verified structure drawing */
    var card = document.createElementNS(NS, "rect");
    card.setAttribute("x", p.x - NODE_BOX / 2); card.setAttribute("y", p.y - NODE_BOX / 2);
    card.setAttribute("width", String(NODE_BOX)); card.setAttribute("height", String(NODE_BOX));
    card.setAttribute("rx", "7"); card.setAttribute("fill", "#ffffff");
    card.setAttribute("stroke", "#c9d4e2"); card.setAttribute("stroke-width", "1");

    var fileName = STRUCTURE[order[j].to];
    var img = null;
    if (fileName) {
      img = document.createElementNS(NS, "image");
      var inset = 4;
      img.setAttributeNS("http://www.w3.org/1999/xlink", "href", "assets/structures/" + fileName + ".svg");
      img.setAttribute("href", "assets/structures/" + fileName + ".svg");
      img.setAttribute("x", p.x - NODE_BOX / 2 + inset); img.setAttribute("y", p.y - NODE_BOX / 2 + inset);
      img.setAttribute("width", String(NODE_BOX - inset * 2)); img.setAttribute("height", String(NODE_BOX - inset * 2));
      img.setAttribute("preserveAspectRatio", "xMidYMid meet");
      img.setAttribute("class", "krebs-structure");
    }

    /* small shaded badge on the card corner carrying the step number */
    var badge = document.createElementNS(NS, "circle");
    badge.setAttribute("cx", p.x - NODE_BOX / 2); badge.setAttribute("cy", p.y - NODE_BOX / 2);
    badge.setAttribute("r", String(BADGE_R));
    badge.setAttribute("fill", "#12351f"); badge.setAttribute("stroke", "#2c3f57"); badge.setAttribute("stroke-width", "1.5");

    var num = document.createElementNS(NS, "text");
    num.setAttribute("x", p.x - NODE_BOX / 2); num.setAttribute("y", p.y - NODE_BOX / 2 + 3.4);
    num.setAttribute("text-anchor", "middle");
    num.setAttribute("fill", "#dfe8f5"); num.setAttribute("font-size", "10"); num.setAttribute("font-weight", "700");
    num.textContent = String(order[j].n);

    var lbl = document.createElementNS(NS, "text");
    lbl.setAttribute("x", p.x); lbl.setAttribute("y", p.y + NODE_BOX / 2 + 13); lbl.setAttribute("text-anchor", "middle");
    lbl.setAttribute("fill", "#9fb0c8"); lbl.setAttribute("font-size", "9");
    lbl.textContent = shortLabel(order[j].to);

    g.appendChild(card);
    if (img) g.appendChild(img);
    g.appendChild(badge); g.appendChild(num); g.appendChild(lbl);
    if (FORMULA[order[j].to]) {
      formulaSvg(g, FORMULA[order[j].to], {
        x: p.x, y: p.y + NODE_BOX / 2 + 24, size: 8, fill: "#7f93ab",
        title: (FORMULA[order[j].to] + " (" + order[j].to + ")")
      });
    }
    g.addEventListener("click", (function (k) { return function () { setStep(k); pause(false); }; })(j));
    g.addEventListener("keydown", (function (k) { return function (ev) { if (ev.key === "Enter" || ev.key === " ") { ev.preventDefault(); setStep(k); pause(false); } }; })(j));
    gNodes.appendChild(g);
    nodeEls.push({ g: g, card: card, badge: badge, num: num, lbl: lbl, img: img });
  }

  /* Cofactors produced at a step are drawn as compact chips just off the arrow
     midpoint, so the diagram reads the way a textbook annotates it (e.g. NADH
     and CO2 leaving the isocitrate-dehydrogenase step). */
  function cofactorChips(parent, p, q, stage) {
    var names = (stage.cofactors || []).map(function (c) { return String(c).replace(/\s*\(.*$/, "").trim(); })
      .filter(function (c) { return /^(NADH|FADH2|CO2|GTP|NAD\+|FAD)$/.test(c); });
    if (!names.length) return;
    var mx = (p.x + q.x) / 2, my = (p.y + q.y) / 2;
    /* push the chips outward from the ring centre */
    var ox = mx - 220, oy = my - 220, l = Math.sqrt(ox * ox + oy * oy) || 1;
    var bx = mx + (ox / l) * 22, by = my + (oy / l) * 22;
    var chipColors = { NADH: "#1f6b3a", FADH2: "#1f5b6b", CO2: "#5b4a1f", GTP: "#5a2f6b", "NAD+": "#1f4b6b", FAD: "#3a4b6b" };
    names.forEach(function (nm, idx) {
      var cw = 34, ch = 12, gap = 3;
      var y = by + idx * (ch + gap) - ((names.length - 1) * (ch + gap)) / 2;
      var rect = document.createElementNS(NS, "rect");
      rect.setAttribute("x", bx - cw / 2); rect.setAttribute("y", y - ch / 2);
      rect.setAttribute("rx", "6"); rect.setAttribute("width", cw); rect.setAttribute("height", ch);
      rect.setAttribute("fill", chipColors[nm] || "#33445c"); rect.setAttribute("stroke", "#7fe3a3"); rect.setAttribute("stroke-width", "0.6");
      /* proper typesetting: CO2 -> CO(2), NAD+ -> NAD(+) */
      var t = formulaSvg(document.createElementNS(NS, "g"), nm, {
        x: bx, y: y + 3, size: 7, fill: "#dff5e6", anchor: "middle", weight: "700"
      });
      var gc = document.createElementNS(NS, "g");
      gc.setAttribute("class", "krebs-cofactor");
      gc.appendChild(rect); gc.appendChild(t);
      parent.appendChild(gc);
    });
  }


  /* link-reaction feeder: acetyl-CoA enters at step 1 (top of the ring). It is
     parked in the upper-left gutter so it never overlaps a metabolite card. */
  var feeder = document.createElementNS(NS, "g");
  var fx = cx - R - 66, fy = cy - R + 34;
  var fimg = document.createElementNS(NS, "image");
  fimg.setAttributeNS("http://www.w3.org/1999/xlink", "href", "assets/structures/acetyl_coa.svg");
  fimg.setAttribute("href", "assets/structures/acetyl_coa.svg");
  fimg.setAttribute("x", fx - 20); fimg.setAttribute("y", fy - 34);
  fimg.setAttribute("width", 44); fimg.setAttribute("height", 44);
  fimg.setAttribute("preserveAspectRatio", "xMidYMid meet");
  fimg.setAttribute("class", "krebs-structure");
  var ftext = document.createElementNS(NS, "text");
  ftext.setAttribute("x", fx + 2); ftext.setAttribute("y", fy + 22); ftext.setAttribute("text-anchor", "middle");
  ftext.setAttribute("fill", "#7fb0e0"); ftext.setAttribute("font-size", "9");
  ftext.textContent = "Acetyl-CoA (link)";
  /* dashed lead line into the step-1 card, with an arrowhead */
  var targetX = nodes[0].x - NODE_BOX / 2 - 6, targetY = nodes[0].y;
  var fline = line(fx + 26, fy - 4, targetX, targetY);
  fline.setAttribute("stroke", "#3a6ea5"); fline.setAttribute("stroke-dasharray", "5 4");
  var fdx = targetX - (fx + 26), fdy = targetY - (fy - 4);
  var flen = Math.sqrt(fdx * fdx + fdy * fdy) || 1;
  var fux = fdx / flen, fuy = fdy / flen, fah = 7;
  var fpt = document.createElementNS(NS, "polygon");
  fpt.setAttribute("points",
    targetX + "," + targetY + " " +
    (targetX - fux * fah - fuy * 4) + "," + (targetY - fuy * fah + fux * 4) + " " +
    (targetX - fux * fah + fuy * 4) + "," + (targetY - fuy * fah - fux * 4));
  fpt.setAttribute("fill", "#3a6ea5");
  feeder.appendChild(fimg); feeder.appendChild(fline); feeder.appendChild(fpt); feeder.appendChild(ftext);
  svg.appendChild(feeder);

  function arrow(p, q, half) {
    /* half = half-side of the square card; the arrow starts and ends on the
       card edge, so it must follow the actual chord direction. */
    var dx = q.x - p.x, dy = q.y - p.y, len = Math.sqrt(dx * dx + dy * dy);
    var ux = dx / len, uy = dy / len;
    var m = Math.max(Math.abs(ux), Math.abs(uy)) || 1;
    var shrink = half / m + 2;
    var sx = p.x + ux * shrink, sy = p.y + uy * shrink, ex = q.x - ux * shrink, ey = q.y - uy * shrink;
    var g = document.createElementNS(NS, "g");
    g.appendChild(line(sx, sy, ex, ey));
    var ah = 7;
    var pt = document.createElementNS(NS, "polygon");
    pt.setAttribute("points",
      ex + "," + ey + " " +
      (ex - ux * ah - uy * 4) + "," + (ey - uy * ah + ux * 4) + " " +
      (ex - ux * ah + uy * 4) + "," + (ey - uy * ah - ux * 4));
    pt.setAttribute("fill", "#2c3f57");
    g.appendChild(pt);
    g.setAttribute("class", "krebs-arrow");
    return g;
  }
  function line(x1, y1, x2, y2) {
    var l = document.createElementNS(NS, "line");
    l.setAttribute("x1", x1); l.setAttribute("y1", y1); l.setAttribute("x2", x2); l.setAttribute("y2", y2);
    l.setAttribute("stroke", "#2c3f57"); l.setAttribute("stroke-width", "2");
    return l;
  }
  function shortLabel(s) { return String(s).split("(")[0].trim().slice(0, 22); }

  /* ---- step state ---- */
  var current = -1, playing = false, timer = null;
  function setStep(k) {
    current = k;
    for (var m = 0; m < n; m++) {
      var on = m === k;
      nodeEls[m].card.setAttribute("stroke", on ? "#7fe3a3" : "#c9d4e2");
      nodeEls[m].card.setAttribute("stroke-width", on ? "2.5" : "1");
      nodeEls[m].badge.setAttribute("fill", on ? "#7fe3a3" : "#12351f");
      nodeEls[m].badge.setAttribute("stroke", on ? "#7fe3a3" : "#2c3f57");
      nodeEls[m].num.setAttribute("fill", on ? "#0b1220" : "#dfe8f5");
      if (nodeEls[m].img) nodeEls[m].img.setAttribute("opacity", on ? "1" : "0.72");
      nodeEls[m].g.setAttribute("aria-current", on ? "true" : "false");
    }
    var s = order[k];
    renderPanel(s);
    progress.textContent = "Step " + s.n + " of " + n + " - " + s.name;
    if (onNarrate) onNarrate(narrationFor(s), s);
  }
  function renderPanel(s) {
    panel.innerHTML = "";
    var h = el("div", null, "font-weight:700;font-size:15px;margin-bottom:6px;");
    h.textContent = "Step " + s.n + ": " + s.name;
    panel.appendChild(h);
    /* structure of the intermediate formed at this step (offline SVG) */
    var fileName = STRUCTURE[s.to];
    if (fileName) {
      var fig = el("div", null, "background:#0b1220;border:1px solid #1e2c3f;border-radius:8px;padding:6px;margin:6px 0 10px;display:flex;align-items:center;gap:10px;");
      var im = document.createElementNS(NS, "img");
      im.setAttribute("src", "assets/structures/" + fileName + ".svg");
      im.setAttribute("alt", s.to + " molecular structure");
      im.style.cssText = "width:104px;height:104px;object-fit:contain;flex:0 0 auto;background:#fff;border-radius:6px;";
      fig.appendChild(im);
      var cap = el("div", null, "font-size:12px;line-height:1.6;color:#c3d2e6;");
      cap.innerHTML = "<strong>" + s.to + "</strong><br>Formula " + formulaHtml(FORMULA[s.to] || "-") +
        (ION[s.to] ? "<br>In the cell: " + ionHtml(ION[s.to]) : "") +
        "<br>" + s.carbonCount + "C" + (s.direction ? " &middot; " + s.direction : "");
      fig.appendChild(cap);
      panel.appendChild(fig);
    }
    panel.appendChild(metaRow("Reaction", reactionHtml(s.reaction), true));
    panel.appendChild(metaRow("Enzyme", s.enzymes.join(", ")));
    var produces = el("span", null, "color:#dfe8f5;");
    produces.innerHTML = s.cofactors.length ? s.cofactors.map(function (c) { return formulaHtml(c); }).join(", ") : "-";
    var prow = el("div", null, "display:flex;gap:8px;margin:4px 0;font-size:12px;");
    var pk = el("span", null, "flex:0 0 74px;color:#7f93ab;"); pk.textContent = "Produces";
    prow.appendChild(pk); prow.appendChild(produces);
    panel.appendChild(prow);
    panel.appendChild(metaRow("Carbons", String(s.carbonCount) + (s.direction ? " (" + s.direction + ")" : "")));
    var d = el("p", null, "margin:10px 0 0;line-height:1.5;color:#c3d2e6;");
    d.textContent = s.detail;
    panel.appendChild(d);
  }
  function metaRow(k, v, isHtml) {
    var row = el("div", null, "display:flex;gap:8px;margin:4px 0;font-size:12px;");
    var kk = el("span", null, "flex:0 0 74px;color:#7f93ab;"); kk.textContent = k;
    var vv = el("span", null, "color:#dfe8f5;");
    if (isHtml) vv.innerHTML = v; else vv.textContent = v;
    row.appendChild(kk); row.appendChild(vv);
    return row;
  }
  /* Narration is spoken aloud, so it needs a spoken form of the equation:
     "->" must not be read as "dash greater than" and formulas must not be
     read digit by digit. */
  function spokenReaction(str) {
    return String(str == null ? "" : str)
      .replace(/H2O/g, "water")
      .replace(/CO2/g, "carbon dioxide")
      .replace(/NAD\+/g, "NAD plus")
      .replace(/FADH2/g, "FAD H two")
      .replace(/\s*->\s*/g, " gives ")
      .replace(/\s\+\s/g, " plus ");
  }
  function narrationFor(s) {
    return "Step " + s.n + ", " + s.name + ". " + spokenReaction(s.reaction) + ". " + s.detail;
  }

  function play_(on) {
    playing = on;
    play.textContent = on ? "Pause" : "Play";
    play.setAttribute("aria-pressed", on ? "true" : "false");
    if (timer) { clearInterval(timer); timer = null; }
    if (on) {
      if (current < 0) setStep(0);
      var delay = reducedMotion() ? 2200 : 2600;
      timer = setInterval(function () {
        if (current >= n - 1) { pause(true); return; }
        setStep(current + 1);
      }, delay);
    }
  }
  function pause(atEnd) { play_(false); if (atEnd) { progress.textContent = "Cycle complete - " + n + " reactions. Try the quiz."; } }

  prev.addEventListener("click", function () { pause(false); setStep(current <= 0 ? n - 1 : current - 1); });
  next.addEventListener("click", function () { pause(false); setStep(current >= n - 1 ? 0 : current + 1); });
  play.addEventListener("click", function () { play_(!playing); });
  replay.addEventListener("click", function () { pause(false); setStep(0); });

  /* ---- quiz: questions are derived from the curated model, so answers are facts ---- */
  var QUIZ = [
    { q: "Which step regenerates oxaloacetate?", a: "step 8", options: ["step 1", "step 5", "step 8"] },
    { q: "Which reaction produces GTP by substrate-level phosphorylation?", a: "succinyl-CoA -> succinate", options: ["citrate -> isocitrate", "succinyl-CoA -> succinate", "malate -> oxaloacetate"] },
    { q: "Which step yields FADH2?", a: "succinate -> fumarate", options: ["succinate -> fumarate", "isocitrate -> alpha-ketoglutarate", "fumarate -> malate"] },
    { q: "How many CO2 are released per acetyl-CoA?", a: "2", options: ["1", "2", "3"] },
    { q: "Where does the cycle occur in eukaryotes?", a: "mitochondrial matrix", options: ["cytosol", "mitochondrial matrix", "nucleus"] },
  ];
  var quizIndex = 0, quizScore = 0;
  quizBtn.addEventListener("click", function () { quizIndex = 0; quizScore = 0; pause(false); renderQuiz(); });
  function renderQuiz() {
    panel.innerHTML = "";
    if (quizIndex >= QUIZ.length) {
      var done = el("div", null, "font-size:15px;line-height:1.6;");
      done.textContent = "Quiz complete: " + quizScore + " / " + QUIZ.length + " correct.";
      panel.appendChild(done);
      var again = el("button", null, btnStyle); again.textContent = "Try again";
      again.style.marginTop = "10px";
      again.addEventListener("click", function () { quizIndex = 0; quizScore = 0; renderQuiz(); });
      panel.appendChild(again);
      progress.textContent = "Quiz complete";
      return;
    }
    var item = QUIZ[quizIndex];
    var qh = el("div", null, "font-weight:700;margin-bottom:8px;");
    qh.textContent = "Q" + (quizIndex + 1) + "/" + QUIZ.length + ": " + item.q;
    panel.appendChild(qh);
    item.options.forEach(function (opt) {
      var b = el("button", { "aria-label": "Answer: " + opt }); b.style.cssText = btnStyle + "display:block;width:100%;text-align:left;margin:6px 0;";
      b.textContent = opt;
      b.addEventListener("click", function () {
        if (opt === item.a) quizScore++;
        quizIndex++;
        renderQuiz();
      });
      panel.appendChild(b);
    });
    progress.textContent = "Quiz " + (quizIndex + 1) + " / " + QUIZ.length;
  }

  setStep(0);

  function destroy() {
    if (timer) clearInterval(timer);
    timer = null;
    if (wrapper.parentNode) wrapper.parentNode.removeChild(wrapper);
  }

  return {
    wrapper: wrapper,
    model: model,
    verification: check,
    setStep: setStep,
    play: function () { play_(true); },
    pause: function () { pause(false); },
    next: function () { pause(false); setStep(current >= n - 1 ? 0 : current + 1); },
    prev: function () { pause(false); setStep(current <= 0 ? n - 1 : current - 1); },
    currentStep: function () { return current; },
    quizQuestions: QUIZ.length,
    destroy: destroy,
  };
}

export default createKrebsViewer;
