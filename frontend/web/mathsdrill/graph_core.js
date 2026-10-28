/* MathDrill graph core — pure mathematical engine (no Three.js, no DOM).
   Parses a school-level expression or structured problem, derives every
   displayed property from actual calculation (never hard-coded coordinates),
   splits branches across discontinuities, and determines asymptotes
   symbolically where possible (rational poles, tan/log singularities) with
   numerical limit checks as fallback — never "it looks straight".

   Consumed by graph3d.js (renderer) and scripts/graph_core_test.mjs.
   Supported families: linear, quadratic, polynomial (≤ degree 4 numeric),
   reciprocal/rational, exponential, logarithmic, absolute value, square root,
   tangent, simultaneous systems (y=f vs y=g), circles, inequalities, piecewise.
   Anything else returns {ok:false, error} — a clear limitation, never a
   misleading graph.
*/

/* ───────────────────────── tokenizer / parser ───────────────────────── */

const FUNCS = {
  sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos,
  atan: Math.atan, sqrt: Math.sqrt, abs: Math.abs, exp: Math.exp, ln: Math.log,
  log: Math.log, log10: Math.log10, floor: Math.floor, ceil: Math.ceil,
  sign: Math.sign, min: Math.min, max: Math.max,
};
const CONSTS = { pi: Math.PI, e: Math.E };

class ParseError extends Error {}

function tokenize(src) {
  const out = [];
  let i = 0;
  const s = src;
  while (i < s.length) {
    const c = s[i];
    if (/\s/.test(c)) { i++; continue; }
    if (/[0-9.]/.test(c)) {
      let j = i;
      while (j < s.length && /[0-9.]/.test(s[j])) j++;
      const raw = s.slice(i, j);
      const v = Number(raw);
      if (!Number.isFinite(v)) throw new ParseError(`bad number '${raw}'`);
      out.push({ t: "num", v });
      i = j;
      continue;
    }
    if (/[a-zA-Z]/.test(c)) {
      let j = i;
      while (j < s.length && /[a-zA-Z0-9]/.test(s[j])) j++;
      out.push({ t: "name", v: s.slice(i, j) });
      i = j;
      continue;
    }
    if ("+-*/^(),".includes(c)) { out.push({ t: c }); i++; continue; }
    if (c === "−") { out.push({ t: "-" }); i++; continue; }     // U+2212 minus
    throw new ParseError(`unsupported character '${c}'`);
  }
  return out;
}

/* grammar: expr := term (('+'|'-') term)* ; term := unary (('*'|'/') unary)* ;
   unary := ('-'|'+') unary | power ; power := atom ('^' unary)? (right assoc) */
function parse(src) {
  const ts = tokenize(src);
  let p = 0;
  const peek = () => ts[p];
  const eat = (t) => { if (ts[p] && ts[p].t === t) { p++; return true; } return false; };

  function expr() {
    let node = term();
    for (;;) {
      if (eat("+")) node = { k: "+", a: node, b: term() };
      else if (eat("-")) node = { k: "-", a: node, b: term() };
      else return node;
    }
  }
  function term() {
    let node = unary();
    for (;;) {
      if (eat("*")) node = { k: "*", a: node, b: unary() };
      else if (eat("/")) node = { k: "/", a: node, b: unary() };
      else if (peek() && (peek().t === "num" || peek().t === "name" || peek().t === "("))
        node = { k: "*", a: node, b: unary() };   // implicit multiplication: 4x, 2sin(x), 3(x+1)
      else return node;
    }
  }
  function unary() {
    if (eat("-")) return { k: "neg", a: unary() };
    if (eat("+")) return unary();
    return power();
  }
  function power() {
    const base = atom();
    if (eat("^")) return { k: "^", a: base, b: unary() };
    return base;
  }
  function atom() {
    const tk = peek();
    if (!tk) throw new ParseError("unexpected end of expression");
    if (tk.t === "num") { p++; return { k: "num", v: tk.v }; }
    if (tk.t === "(") {
      p++;
      const e = expr();
      if (!eat(")")) throw new ParseError("missing ')'");
      return e;
    }
    if (tk.t === "name") {
      p++;
      const name = tk.v;
      if (peek() && peek().t === "(") {
        p++;
        const argList = [];
        if (!eat(")")) {
          argList.push(expr());
          while (eat(",")) argList.push(expr());
          if (!eat(")")) throw new ParseError(`missing ')' after ${name}(`);
        }
        if (!(name in FUNCS)) throw new ParseError(`unsupported function '${name}'`);
        return { k: "call", f: name, args: argList };
      }
      if (name === "x") return { k: "x" };
      if (name in CONSTS) return { k: "num", v: CONSTS[name] };
      throw new ParseError(`unknown name '${name}' (use x, pi, e or a supported function)`);
    }
    throw new ParseError(`unexpected '${tk.t}'`);
  }

  const node = expr();
  if (p !== ts.length) throw new ParseError(`unexpected '${ts[p].t}'`);
  return node;
}

function compile(ast) {
  switch (ast.k) {
    case "num": { const v = ast.v; return () => v; }
    case "x": return (x) => x;
    case "+": { const a = compile(ast.a), b = compile(ast.b); return (x) => a(x) + b(x); }
    case "-": { const a = compile(ast.a), b = compile(ast.b); return (x) => a(x) - b(x); }
    case "*": { const a = compile(ast.a), b = compile(ast.b); return (x) => a(x) * b(x); }
    case "/": { const a = compile(ast.a), b = compile(ast.b); return (x) => { const d = b(x); return d === 0 ? NaN : a(x) / d; }; }
    case "^": { const a = compile(ast.a), b = compile(ast.b); return (x) => Math.pow(a(x), b(x)); }
    case "neg": { const a = compile(ast.a); return (x) => -a(x); }
    case "call": {
      const f = FUNCS[ast.f];
      const args = ast.args.map(compile);
      if (args.length === 1) return (x) => f(args[0](x));
      if (args.length === 2) return (x) => f(args[0](x), args[1](x));
      return (x) => f(...args.map((g) => g(x)));
    }
    default: throw new ParseError("unsupported node");
  }
}

function hasCall(ast, name) {
  if (!ast || typeof ast !== "object") return false;
  if (ast.k === "call") return ast.f === name || ast.args.some((a) => hasCall(a, name));
  for (const key of ["a", "b", "args"]) {
    const v = ast[key];
    if (Array.isArray(v) && v.some((n) => hasCall(n, name))) return true;
    if (v && typeof v === "object" && hasCall(v, name)) return true;
  }
  return false;
}

/* polynomial extraction over +,-,*,^int (returns null when not a polynomial) */
function polyOf(ast) {
  if (!ast || typeof ast !== "object") return null;
  if (ast.k === "num") return [ast.v];
  if (ast.k === "x") return [0, 1];
  if (ast.k === "neg") {
    const p1 = polyOf(ast.a);
    return p1 && p1.map((c) => -c);
  }
  if (ast.k === "+" || ast.k === "-") {
    const a = polyOf(ast.a), b = polyOf(ast.b);
    if (!a || !b) return null;
    const n = Math.max(a.length, b.length);
    const out = new Array(n).fill(0);
    for (let i = 0; i < n; i++) {
      const s = (a[i] || 0) + (ast.k === "-" ? -(b[i] || 0) : (b[i] || 0));
      out[i] = s;
    }
    return out;
  }
  if (ast.k === "*") {
    const a = polyOf(ast.a), b = polyOf(ast.b);
    if (!a || !b) return null;
    const out = new Array(a.length + b.length - 1).fill(0);
    for (let i = 0; i < a.length; i++)
      for (let j = 0; j < b.length; j++) out[i + j] += a[i] * b[j];
    return out;
  }
  if (ast.k === "^" && ast.b && ast.b.k === "num" && Number.isInteger(ast.b.v) && ast.b.v >= 0 && ast.b.v <= 6) {
    const base = polyOf(ast.a);
    if (!base) return null;
    let out = [1];
    for (let i = 0; i < ast.b.v; i++) {
      const tmp = new Array(out.length + base.length - 1).fill(0);
      for (let m = 0; m < out.length; m++)
        for (let n = 0; n < base.length; n++) tmp[m + n] += out[m] * base[n];
      out = tmp;
    }
    return out;
  }
  return null;
}
function polyDeg(co) {
  let d = co.length - 1;
  while (d > 0 && Math.abs(co[d]) < 1e-12) d--;
  return d;
}
function polyEval(co, x) {
  let v = 0;
  for (let i = co.length - 1; i >= 0; i--) v = v * x + co[i];
  return v;
}

/* real roots of a low-degree polynomial (closed form ≤2, numeric scan otherwise) */
function polyRealRoots(co, lo, hi) {
  const d = polyDeg(co);
  if (d <= 0) return [];
  if (d === 1) return [-co[0] / co[1]];
  if (d === 2) {
    const [c0, c1, c2] = [co[0], co[1], co[2]];
    const disc = c1 * c1 - 4 * c2 * c0;
    if (disc < 0) return [];
    const s = Math.sqrt(disc);
    return [(-c1 + s) / (2 * c2), (-c1 - s) / (2 * c2)];
  }
  // numeric: dense scan + bisection (adequate for classroom windows)
  const roots = [];
  const N = 4000;
  let px = lo, pv = polyEval(co, lo);
  for (let i = 1; i <= N; i++) {
    const x = lo + ((hi - lo) * i) / N;
    const v = polyEval(co, x);
    if (Number.isFinite(pv) && Number.isFinite(v) && pv * v < 0) {
      let a = px, b = x, fa = pv;
      for (let k = 0; k < 60; k++) {
        const m = (a + b) / 2, fm = polyEval(co, m);
        if (fa * fm <= 0) b = m; else { a = m; fa = fm; }
      }
      roots.push((a + b) / 2);
    }
    px = x; pv = v;
  }
  return roots;
}

/* ───────────────────────── asymptotes ───────────────────────── */

function singularities(ast, fn, win) {
  /* returns {vertical: [x...], holes: [x,y...]} — poles vs removable points */
  const vertical = [], holes = [];
  const pushV = (x) => {
    if (x === null || !Number.isFinite(x)) return;
    if (x < win.xmin - 1e-9 || x > win.xmax + 1e-9) return;
    if (vertical.some((v) => Math.abs(v - x) < 1e-6 * Math.max(1, Math.abs(x)))) return;
    vertical.push(x);
  };
  const isPole = (x) => {
    // blow-up on both sides => true pole; stable limits => removable hole
    const e = 1e-6 * Math.max(1, Math.abs(x));
    const a = fn(x - e), b = fn(x + e);
    const big = (v) => Number.isFinite(v) && Math.abs(v) > 1e4;
    if (big(a) || big(b)) return true;
    if (!Number.isFinite(a) || !Number.isFinite(b)) return false;
    return Math.abs(a - b) > 1e3;
  };
  if (ast.k === "/") {
    const den = polyOf(ast.b);
    if (den) {
      for (const root of polyRealRoots(den, win.xmin, win.xmax)) {
        if (isPole(root)) pushV(root);
        else {
          const e = 1e-6 * Math.max(1, Math.abs(root));
          const ya = fn(root - e), yb = fn(root + e);
          const y = (Number.isFinite(ya) && Number.isFinite(yb)) ? (ya + yb) / 2 : NaN;
          if (Number.isFinite(y) && !holes.some((h) => Math.abs(h[0] - root) < 1e-6))
            holes.push([root, y]);
        }
      }
    }
  }
  /* symbolic: tan singularities (2k+1)·π/2 */
  if (hasCall(ast, "tan")) {
    const kMin = Math.floor((win.xmin - Math.PI / 2) / Math.PI) - 1;
    const kMax = Math.ceil((win.xmax - Math.PI / 2) / Math.PI) + 1;
    for (let k = kMin; k <= kMax; k++) pushV((2 * k + 1) * Math.PI / 2);
  }
  /* symbolic: ln/log singularity at x = 0 */
  if ((hasCall(ast, "ln") || hasCall(ast, "log") || hasCall(ast, "log10")) && win.xmin < 0 && win.xmax > 0) pushV(0);
  /* numeric fallback: interior blow-up with opposite infinities on either side */
  const N = 1200;
  let prevX = win.xmin, prevY = fn(win.xmin);
  for (let i = 1; i <= N; i++) {
    const x = win.xmin + ((win.xmax - win.xmin) * i) / N;
    const y = fn(x);
    if (!Number.isFinite(prevY) || !Number.isFinite(y)) { prevX = x; prevY = y; continue; }
    const jump = Math.abs(y - prevY) > 400 * Math.max(1, Math.abs(win.ymax - win.ymin));
    if (jump && Math.sign(prevY) !== Math.sign(y) && Math.max(Math.abs(y), Math.abs(prevY)) > 500) {
      pushV((prevX + x) / 2);
    }
    prevX = x; prevY = y;
  }
  return { vertical: vertical.sort((a, b) => a - b), holes };
}

function verticalAsymptotes(ast, fn, win) {
  const out = [];
  const push = (x) => {
    if (x === null || !Number.isFinite(x)) return;
    if (x < win.xmin - 1e-9 || x > win.xmax + 1e-9) return;
    if (out.some((v) => Math.abs(v - x) < 1e-6 * Math.max(1, Math.abs(x)))) return;
    out.push(x);
  };
  return singularities(ast, fn, win).vertical;
}

function limitAt(fn, dir) {
  const pts = [1e3, 1e4, 1e5, 1e6].map((m) => fn(dir * m));
  if (pts.some((v) => !Number.isFinite(v))) return null;
  const [a, b] = [pts[2], pts[3]];
  if (Math.abs(b - a) > 1e-3 * (1 + Math.abs(b))) return null;  // not converging
  return b;
}

function horizontalAsymptotes(fn) {
  const L = limitAt(fn, 1);
  const R = limitAt(fn, -1);
  const out = [];
  if (L !== null && R !== null && Math.abs(L - R) < 1e-3 * (1 + Math.abs(L))) out.push({ y: L, sides: "both" });
  else {
    if (L !== null) out.push({ y: L, sides: "+" });
    if (R !== null) out.push({ y: R, sides: "-" });
  }
  return out;
}

function obliqueAsymptotes(fn) {
  // m = lim f(x)/x at +∞ (via two far points), c = f(x) − m·x must converge
  const out = [];
  for (const dir of [1, -1]) {
    const x1 = dir * 1e5, x2 = dir * 1e6;
    const f1 = fn(x1), f2 = fn(x2);
    if (!Number.isFinite(f1) || !Number.isFinite(f2)) continue;
    const m = (f2 - f1) / (x2 - x1);
    if (!Number.isFinite(m) || Math.abs(m) < 1e-9 || Math.abs(m) > 1e6) continue;
    const c = f2 - m * x2;
    const probe = fn(dir * 1e4);
    if (!Number.isFinite(probe)) continue;
    if (Math.abs(probe - (m * dir * 1e4 + c)) > 1e-2 * (1 + Math.abs(probe))) continue;
    if (out.some((o) => Math.abs(o.m - m) < 1e-6 && Math.abs(o.c - c) < 1e-4)) continue;
    out.push({ m, c, dir });
  }
  return out;
}

/* ───────────────────── sampling & discontinuities ───────────────────── */

function sampleSegments(fn, win, opts) {
  const N = (opts && opts.samples) || 640;
  const segs = [];
  let cur = [];
  const yrange = Math.max(1e-6, win.ymax - win.ymin);
  const spikes = (opts && opts.poles) || [];
  const splitAt = ((opts && opts.splitAt) || spikes).slice().sort((a, b) => a - b);
  let prev = null;
  for (let i = 0; i <= N; i++) {
    const x = win.xmin + ((win.xmax - win.xmin) * i) / N;
    // break exactly at every singularity crossing — branches are never joined
    if (prev) {
      for (const sx of splitAt) {
        if (prev.x < sx && x >= sx) {
          if (cur.length) { segs.push(cur); cur = []; }
          prev = null;
          break;
        }
      }
    }
    if (!prev && splitAt.some((sx) => Math.abs(x - sx) < (win.xmax - win.xmin) / N * 0.5)) continue;
    const y = fn(x);
    const finite = Number.isFinite(y) && Math.abs(y) < 1e3 * Math.max(1, yrange);
    if (!finite) { if (cur.length) { segs.push(cur); cur = []; } prev = null; continue; }
    if (prev && Math.abs(y - prev.y) > 6 * yrange + 50) {   // discontinuity: never connect
      segs.push(cur); cur = [];
    }
    cur.push([x, y]);
    prev = { x, y };
  }
  if (cur.length) segs.push(cur);
  return segs.filter((s) => s.length > 1);
}

/* ─────────────────────── features / properties ─────────────────────── */

function quadraticInfo(ast) {
  const co = polyOf(ast);
  if (!co || polyDeg(co) !== 2) return null;
  const [c0, c1, c2] = [co[0], co[1], co[2]];
  if (Math.abs(c2) < 1e-12) return null;
  const disc = c1 * c1 - 4 * c2 * c0;
  const vx = -c1 / (2 * c2);
  const vy = polyEval(co, vx);
  const roots = disc < 0 ? [] : [(-c1 + Math.sqrt(disc)) / (2 * c2), (-c1 - Math.sqrt(disc)) / (2 * c2)];
  return {
    a: c2, b: c1, c: c0,
    roots: roots.sort((p, q) => p - q),
    vertex: [vx, vy],
    axis: `x = ${trimNum(vx)}`,
    yint: [0, c0],
    opensUp: c2 > 0,
    disc,
  };
}

function trimNum(v, dp) {
  const d = dp === undefined ? 4 : dp;
  const r = Math.round(v * 10 ** d) / 10 ** d;
  return Object.is(r, -0) ? "0" : String(r);
}

function numericFeatures(fn, win, segs) {
  const feats = { roots: [], extrema: [], endpoints: [], yint: null };
  // y-intercept
  if (win.xmin <= 0 && win.xmax >= 0) {
    const y0 = fn(0);
    if (Number.isFinite(y0)) feats.yint = [0, y0];
  }
  // roots per segment (sign change + bisection)
  for (const seg of segs) {
    for (let i = 1; i < seg.length; i++) {
      const [x0, y0] = seg[i - 1], [x1, y1] = seg[i];
      if (y0 === 0) feats.roots.push(x0);
      else if (y0 * y1 < 0) {
        let a = x0, b = x1, fa = y0;
        for (let k = 0; k < 60; k++) {
          const m = (a + b) / 2, fm = fn(m);
          if (!Number.isFinite(fm)) { b = m; continue; }
          if (fa * fm <= 0) b = m; else { a = m; fa = fm; }
        }
        feats.roots.push((a + b) / 2);
      }
    }
    // endpoints (domain edges where the segment doesn't reach the window edge)
    const [sx] = seg[0], ex = seg[seg.length - 1][0];
    if (sx > win.xmin + (win.xmax - win.xmin) * 0.01 && Number.isFinite(fn(sx - 1e-6)) === false) { /* handled below */ }
    if (sx > win.xmin + (win.xmax - win.xmin) * 0.02) feats.endpoints.push([sx, seg[0][1]]);
    if (ex < win.xmax - (win.xmax - win.xmin) * 0.02) feats.endpoints.push([ex, seg[seg.length - 1][1]]);
  }
  // local extrema via numerical derivative sign changes on a dense pass
  const N = 500;
  let px = null;
  const samples = [];
  for (let i = 0; i <= N; i++) {
    const x = win.xmin + ((win.xmax - win.xmin) * i) / N;
    const y = fn(x);
    if (Number.isFinite(y)) samples.push([x, y]);
  }
  let lastNZ = null;                       // last non-zero derivative sign (kink-safe)
  for (let i = 1; i < samples.length - 1; i++) {
    const [xm, ym] = samples[i - 1], [x0, y0] = samples[i], [xp, yp] = samples[i + 1];
    const d = (yp - ym) / (xp - xm || 1e-9);
    const sgn = Math.abs(d) > 1e-9 ? Math.sign(d) : 0;
    if (sgn !== 0) {
      if (lastNZ !== null && lastNZ * sgn < 0) {
        const isMin = lastNZ < 0;               // slope − → + is a local minimum (and vice versa)
        // ternary refinement on [xm, xp] for machine-precision turning points
        let a = xm, b = xp;
        for (let k = 0; k < 60; k++) {
          const m1 = a + (b - a) / 3, m2 = b - (b - a) / 3;
          const f1 = fn(m1), f2 = fn(m2);
          if (!Number.isFinite(f1) || !Number.isFinite(f2)) { b = m2; continue; }
          if (isMin ? f1 < f2 : f1 > f2) b = m2; else a = m1;
        }
        const xExt = (a + b) / 2, yExt = fn(xExt);
        if (Number.isFinite(yExt) && Math.abs(xExt - x0) < (win.xmax - win.xmin) * 0.12) {
          const kind = isMin ? "min" : "max";
          if (!feats.extrema.some((e) => Math.abs(e[0] - xExt) < 1e-6))
            feats.extrema.push([xExt, yExt, kind]);
        }
      }
      lastNZ = sgn;
    }
    px = x0;
  }
  if (feats.extrema.length === 1) {
    feats.vertex = [feats.extrema[0][0], feats.extrema[0][1]];   // single turning point (e.g. |x|)
  }
  return feats;
}

/* simultaneous systems: y = f(x) vs y = g(x) intersections */
function intersectionsOf(f, g, win) {
  const out = [];
  const N = 1600;
  let lastSign = 0, lastX = null;
  const add = (x0) => {
    if (out.some((p) => Math.abs(p[0] - x0) < 1e-6)) return;
    const y = f(x0);
    if (Number.isFinite(y)) out.push([x0, y]);
  };
  for (let i = 0; i <= N; i++) {
    const x = win.xmin + ((win.xmax - win.xmin) * i) / N;
    const v = f(x) - g(x);
    if (!Number.isFinite(v)) { lastSign = 0; lastX = null; continue; }
    const sg = Math.abs(v) < 1e-12 ? 0 : Math.sign(v);   // exact zeros must not mask a crossing
    if (sg === 0) { add(x); lastSign = 0; lastX = x; continue; }
    if (lastSign !== 0 && sg !== lastSign && lastX !== null) {
      let a = lastX, b = x, fa = f(lastX) - g(lastX);
      for (let k = 0; k < 70; k++) {
        const m = (a + b) / 2, fm = f(m) - g(m);
        if (!Number.isFinite(fm)) { b = m; continue; }
        if (fm === 0) { a = b = m; break; }
        if (fa * fm <= 0) b = m; else { a = m; fa = fm; }
      }
      add((a + b) / 2);
    }
    lastSign = sg; lastX = x;
  }
  return out;
}

/* ───────────────────── ticks & formatting ───────────────────── */

function niceTicks(lo, hi, target) {
  const span = Math.max(Math.abs(hi - Math.abs(lo)), Math.abs(hi - lo), 1e-9);
  const t = target || 9;
  const raw = span / t;
  const pow = Math.pow(10, Math.floor(Math.log10(raw)));
  const candidates = [1, 2, 5, 10].map((m) => m * pow);
  let step = candidates[candidates.length - 1];
  for (const c of candidates) if (span / c <= t + 1) { step = c; break; }
  const majors = [];
  for (let v = Math.ceil(lo / step) * step; v <= hi + step * 1e-9; v += step) {
    majors.push(Math.abs(v) < step * 1e-9 ? 0 : v);
  }
  const minorStep = step / (step / 1 >= 2.5 ? 2 : 5);
  const minors = [];
  for (let v = Math.ceil(lo / minorStep) * minorStep; v <= hi + minorStep * 1e-9; v += minorStep) {
    const vv = Math.abs(v) < minorStep * 1e-9 ? 0 : v;
    if (!majors.some((m) => Math.abs(m - vv) < step * 1e-6)) minors.push(vv);
  }
  return { majors, minors, step };
}

function fmtTick(v) {
  if (Math.abs(v) < 1e-12) return "0";
  const a = Math.abs(v);
  if (a >= 1e6 || (a < 1e-3 && a > 0)) return v.toExponential(0).replace("e+", "e");
  const r4 = Math.round(v * 1e4) / 1e4;
  if (Number.isInteger(r4)) return String(r4);
  const FRAC = [[0.125, 8], [0.25, 4], [0.375, 8], [0.5, 2], [0.625, 8], [0.75, 4], [0.875, 8],
    [0.1, 10], [0.2, 5], [0.3, 10], [0.4, 5], [0.6, 5], [0.7, 10], [0.9, 10]];
  const whole = Math.trunc(r4);
  const frac = Math.abs(r4 - whole);
  for (const [f, den] of FRAC) {
    if (Math.abs(frac - f) < 1e-4) {
      const num = Math.round(f * den);
      const total = (whole === 0 ? 0 : Math.abs(whole) * den) + num;
      return r4 < 0 ? `-${total}/${den}` : `${total}/${den}`;
    }
  }
  return String(Math.round(v * 100) / 100);
}

function fmtCoord(x, y) {
  const fx = trimNum(x, 3), fy = trimNum(y, 3);
  return `(${fx}, ${fy})`;
}

/* window: fit features into a nice-snapped range */
function autoWindow(features, extra, aspect) {
  let xs = [], ys = [];
  for (const f of features || []) { xs.push(f[0]); ys.push(f[1]); }
  for (const e of extra || []) { xs.push(e[0]); ys.push(e[1]); }
  if (!xs.length) { xs = [-5, 5]; ys = [-5, 5]; }
  let x0 = Math.min(...xs), x1 = Math.max(...xs);
  let y0 = Math.min(...ys), y1 = Math.max(...ys);
  const px = Math.max((x1 - x0) * 0.18, 0.8);
  const py = Math.max((y1 - y0) * 0.25, 0.8);
  x0 -= px; x1 += px; y0 -= py; y1 += py;
  const t = niceTicks(x0, x1, 8);
  const ty = niceTicks(y0, y1, 7);
  x0 = Math.floor(x0 / t.step) * t.step; x1 = Math.ceil(x1 / t.step) * t.step;
  y0 = Math.floor(y0 / ty.step) * ty.step; y1 = Math.ceil(y1 / ty.step) * ty.step;
  return { xmin: x0, xmax: x1, ymin: y0, ymax: y1 };
}

/* ─────────────────── problem parsing & analysis ─────────────────── */

const SUP_DIGITS = { "²": "^2", "³": "^3", "⁴": "^4", "−": "-", "–": "-", "×": "*", "÷": "/", ",": ".", "–": "-" };

function normalizeExpr(src) {
  let s = String(src || "");
  s = s.replace(/f\s*\(\s*x\s*\)\s*=\s*/i, "").replace(/^\s*y\s*=\s*/i, "");
  s = s.replace(/Graph of (the )?function\s*:?\s*/i, "");
  s = s.replace(/[²³⁴]/g, (m) => SUP_DIGITS[m]);
  s = s.replace(/[−–]/g, "-").replace(/×/g, "*").replace(/÷/g, "/");
  s = s.replace(/,/g, ".").replace(/\s+/g, "");
  return s;
}

function parseProblem(src) {
  const norm = normalizeExpr(src);
  if (!norm) return { ok: false, error: "empty expression" };
  let ast;
  try {
    ast = parse(norm);
  } catch (e) {
    return { ok: false, error: e instanceof ParseError ? e.message : "cannot parse expression" };
  }
  let fn;
  try {
    fn = compile(ast);
  } catch (e) {
    return { ok: false, error: "cannot evaluate expression" };
  }
  const probe = [0, 1, -1, 0.5].map((x) => fn(x));
  if (probe.every((v) => Number.isNaN(v))) return { ok: false, error: "expression is undefined for all inputs" };
  return { ok: true, norm, ast, fn };
}

/* structured problem: {expr | eqs | circle | ineq, ...} → render-ready spec */
function analyzeProblem(problem, opts) {
  const o = opts || {};
  try {
    if (problem && problem.circle) {
      const { cx = 0, cy = 0, r } = problem.circle;
      if (!(r > 0)) return { ok: false, error: "circle radius must be positive" };
      const N = 256;
      const seg = [];
      for (let i = 0; i <= N; i++) {
        const a = (i / N) * Math.PI * 2;
        seg.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
      }
      const win = o.window || autoWindow([[cx - r, cy - r], [cx + r, cy + r]], [[cx, cy], [cx + r, cy], [cx - r, cy], [cx, cy + r]]);
      const xInt = r * r - cy * cy >= 0 ? [cx - Math.sqrt(r * r - cy * cy), cx + Math.sqrt(r * r - cy * cy)] : [];
      const yInt = r * r - cx * cx >= 0 ? [cy - Math.sqrt(r * r - cx * cx), cy + Math.sqrt(r * r - cx * cx)] : [];
      return {
        ok: true, kind: "circle", window: win,
        segments: [seg],
        asymptotes: { vertical: [], horizontal: [], oblique: [] },
        features: {
          roots: xInt, yint: yInt.length ? [0, yInt[0]] : null,
          extrema: [[cx, cy + r, "max"], [cx, cy - r, "min"]],
          endpoints: [], center: [cx, cy], radius: r, axis: null,
        },
        intersections: [],
        labelNote: `circle: centre (${trimNum(cx)}, ${trimNum(cy)}), r = ${trimNum(r)}`,
      };
    }
    if (problem && Array.isArray(problem.eqs) && problem.eqs.length === 2) {
      const f1 = parseProblem(problem.eqs[0]);
      const f2 = parseProblem(problem.eqs[1]);
      if (!f1.ok) return f1;
      if (!f2.ok) return f2;
      const win = o.window || autoWindow([], [], 1);
      const segs1 = sampleSegments(f1.fn, win, {});
      const xs1 = segs1.flat();
      const xs2 = sampleSegments(f2.fn, win, {}).flat();
      const win2 = autoWindow([], [...xs1, ...xs2]);
      const segsA = sampleSegments(f1.fn, win2, {});
      const segsB = sampleSegments(f2.fn, win2, {});
      const inter = intersectionsOf(f1.fn, f2.fn, win2);
      const featsA = numericFeatures(f1.fn, win2, segsA);
      const featsB = numericFeatures(f2.fn, win2, segsB);
      return {
        ok: true, kind: "system", window: win2,
        segments: [...segsA.map((s) => ({ pts: s, which: 0 })), ...segsB.map((s) => ({ pts: s, which: 1 }))],
        asymptotes: {
          vertical: [...new Set([...verticalAsymptotes(f1.ast, f1.fn, win2), ...verticalAsymptotes(f2.ast, f2.fn, win2)])],
          horizontal: [], oblique: [],
        },
        features: {
          roots: [...new Set([...featsA.roots, ...featsB.roots])].sort((a, b) => a - b),
          yint: featsA.yint, extrema: featsA.extrema, endpoints: [], axis: null,
        },
        intersections: inter,
        labelNote: `y = ${f1.norm}  and  y = ${f2.norm}`,
        exprs: [f1.norm, f2.norm],
      };
    }
    if (problem && problem.ineq) {
      const bound = parseProblem(problem.ineq.expr);
      if (!bound.ok) return bound;
      const rel = problem.ineq.rel || "<";
      const win = o.window || autoWindow([], []);
      const segs = sampleSegments(bound.fn, win, {});
      const poles = verticalAsymptotes(bound.ast, bound.fn, win);
      const segs2 = sampleSegments(bound.fn, win, { poles });
      const feats = numericFeatures(bound.fn, win, segs2);
      return {
        ok: true, kind: "inequality", window: win, segments: segs2,
        asymptotes: { vertical: poles, horizontal: horizontalAsymptotes(bound.fn), oblique: [] },
        features: { roots: feats.roots, yint: feats.yint, extrema: feats.extrema, endpoints: feats.endpoints, axis: null },
        intersections: [], band: { rel, exprNorm: bound.norm },
        labelNote: `y ${rel} ${bound.norm}`,
      };
    }

    // single expression (the MathDrill default path)
    const parsed = parseProblem(problem.expr);
    if (!parsed.ok) return parsed;
    const { ast, fn } = parsed;
    const quad = quadraticInfo(ast);
    const fitWin = { xmin: -10, xmax: 10, ymin: -10, ymax: 10 };   // classroom default viewport
    const win = o.window || (quad
      ? autoWindow(quad.roots.map((r) => [r, 0]).concat([quad.vertex, quad.yint]))
      : fitWin);
    const sing = singularities(ast, fn, win);
    const poles = sing.vertical;
    const splitAt = poles.concat(sing.holes.map((h) => h[0]));
    const segs = sampleSegments(fn, win, { poles, splitAt });
    const feats = numericFeatures(fn, win, segs);
    if (!quad && feats.extrema.length === 1 && !feats.vertex) {
      feats.vertex = [feats.extrema[0][0], feats.extrema[0][1]];
    }
    const hAsy = horizontalAsymptotes(fn);
    const oAsy = obliqueAsymptotes(fn);
    if (quad) {
      feats.roots = quad.roots.slice();
      feats.yint = quad.yint;
      feats.axis = quad.axis;
      feats.vertex = quad.vertex;
      feats.extrema = [[quad.vertex[0], quad.vertex[1], quad.opensUp ? "min" : "max"]];
    }
    return {
      ok: true, kind: "function", norm: parsed.norm, ast, quad,
      window: win, segments: segs.map((s) => ({ pts: s })),
      asymptotes: {
        vertical: poles,
        horizontal: hAsy,
        oblique: oAsy,
      },
      features: {
        roots: feats.roots, yint: feats.yint, extrema: feats.extrema,
        endpoints: feats.endpoints, axis: feats.axis, vertex: feats.vertex || null,
        holes: sing.holes,
      },
      intersections: [], band: null,
      labelNote: `y = ${parsed.norm}`,
      expr: parsed.norm,
    };
  } catch (e) {
    return { ok: false, error: String((e && e.message) || e) };
  }
}

export {
  ParseError, FUNCS, tokenize, parse, compile, polyOf, polyDeg, polyEval,
  polyRealRoots, verticalAsymptotes, horizontalAsymptotes, obliqueAsymptotes,
  sampleSegments, quadraticInfo, numericFeatures, intersectionsOf,
  niceTicks, fmtTick, fmtCoord, trimNum, autoWindow, normalizeExpr,
  parseProblem, analyzeProblem, hasCall,
};
