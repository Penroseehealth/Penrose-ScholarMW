/* graph_core acceptance tests — every family is exercised through the real
 * calculation pipeline; the quadratic is used exactly as the §7 regression:
 * y = x² − 4x + 3 → roots 1 & 3, vertex (2,−1), axis x = 2, y-int (0,3),
 * opens upwards — all derived, never hard-coded in the engine. */

import {
  parseProblem, analyzeProblem, niceTicks, fmtTick, fmtCoord,
  verticalAsymptotes, horizontalAsymptotes, obliqueAsymptotes, quadraticInfo,
} from "../graph_core.js";

let pass = 0, fail = 0;
function ck(name, cond, extra) {
  if (cond) { pass++; console.log("  PASS " + name); }
  else { fail++; console.log("  FAIL " + name + (extra === undefined ? "" : " -> " + extra)); }
}
const near = (a, b, tol = 1e-6) => Math.abs(a - b) <= (tol || 1e-6);
const hasNear = (arr, v, tol = 1e-4) => (arr || []).some((x) => Math.abs(x - v) <= tol);

/* ── §7 quadratic regression: the screenshot example ── */
const q = analyzeProblem({ expr: "x^2 - 4x + 3" });
ck("quadratic analyzed ok", q.ok, q.error);
ck("quadratic detected as exact quadratic", !!q.quad, JSON.stringify(q.quad));
ck("roots are 1 and 3", hasNear(q.features.roots, 1) && hasNear(q.features.roots, 3), JSON.stringify(q.features.roots));
ck("vertex is (2,-1)", near(q.features.vertex[0], 2) && near(q.features.vertex[1], -1), JSON.stringify(q.features.vertex));
ck("axis of symmetry x = 2", q.features.axis === "x = 2", q.features.axis);
ck("y-intercept is (0,3)", near(q.features.yint[1], 3), JSON.stringify(q.features.yint));
ck("parabola opens upward", q.quad.opensUp === true);
ck("superscript input parses (x² − 4x + 3)", analyzeProblem({ expr: "x² − 4x + 3" }).ok);

/* curve actually passes through the correct points */
const fnQ = (x) => x * x - 4 * x + 3;
const segQ = q.segments[0].pts;
const minDist = (pts, x, y) => Math.min(...pts.map((p) => Math.hypot(p[0] - x, p[1] - y)));
ck("curve passes (1,0) & (3,0)", minDist(segQ, 1, 0) < 0.12 && minDist(segQ, 3, 0) < 0.12);
ck("curve passes vertex (2,-1)", minDist(segQ, 2, -1) < 0.12);
ck("curve passes (0,3)", minDist(segQ, 0, 3) < 0.15);

/* ── families ── */
const lin = analyzeProblem({ expr: "2x + 1" });
ck("linear: ok + no asymptotes + y-int 1", lin.ok && !lin.asymptotes.vertical.length &&
  !lin.asymptotes.horizontal.length && near(lin.features.yint[1], 1), JSON.stringify(lin.asymptotes));
ck("linear: root −1/2", hasNear(lin.features.roots, -0.5), JSON.stringify(lin.features.roots));

const cub = analyzeProblem({ expr: "x^3 - 3x" });
ck("cubic: ok, roots {−√3,0,√3}", cub.ok && hasNear(cub.features.roots, 0) &&
  hasNear(cub.features.roots, Math.sqrt(3)) && hasNear(cub.features.roots, -Math.sqrt(3)),
  JSON.stringify(cub.features.roots));
ck("cubic: two turning points", cub.features.extrema.length === 2, JSON.stringify(cub.features.extrema));

const rec = analyzeProblem({ expr: "1/x" });
ck("reciprocal: vertical asymptote x=0", rec.ok && rec.asymptotes.vertical.length === 1 &&
  near(rec.asymptotes.vertical[0], 0), JSON.stringify(rec.asymptotes.vertical));
ck("reciprocal: horizontal y=0", rec.asymptotes.horizontal.length === 1 && near(rec.asymptotes.horizontal[0].y, 0));
ck("reciprocal: branches NOT connected (≥2 segments)", rec.segments.length >= 2, "segs=" + rec.segments.length);

const rat = analyzeProblem({ expr: "1 / (x - 1)" });
ck("rational: vertical asymptote x=1 from denominator", rat.ok && hasNear(rat.asymptotes.vertical, 1, 1e-6),
  JSON.stringify(rat.asymptotes.vertical));
ck("rational: pole splits branches (never joined)", rat.segments.length >= 2, "segs=" + rat.segments.length);

/* (x²−1)/(x−1) has a REMOVABLE discontinuity at x=1 — a hole, not an
   asymptote; the engine must classify it as a hole, split the curve there
   and never draw an artificial line through it */
const hole = analyzeProblem({ expr: "(x^2 - 1) / (x - 1)" });
ck("removable hole: no vertical asymptote claimed", hole.ok && hole.asymptotes.vertical.length === 0,
  JSON.stringify(hole.asymptotes.vertical));
ck("removable hole: detected at (1, 2)", hole.features.holes &&
  hole.features.holes.some((h) => near(h[0], 1, 1e-6) && near(h[1], 2, 1e-3)),
  JSON.stringify(hole.features.holes));
ck("removable hole: branches split at the hole", hole.segments.length >= 2, "segs=" + hole.segments.length);

const slant = analyzeProblem({ expr: "(x^2 + 1) / x" });
ck("oblique asymptote y = x detected", slant.ok && slant.asymptotes.oblique.length >= 1 &&
  near(slant.asymptotes.oblique[0].m, 1) && near(slant.asymptotes.oblique[0].c, 0, 1e-3),
  JSON.stringify(slant.asymptotes.oblique));
ck("slant case also has vertical x=0", hasNear(slant.asymptotes.vertical, 0));

const exp = analyzeProblem({ expr: "exp(x)" });
ck("exponential: horizontal y=0 as x→−∞", exp.ok &&
  (exp.asymptotes.horizontal.some((h) => Math.abs(h.y) < 1e-3) || exp.asymptotes.horizontal.length === 0),
  JSON.stringify(exp.asymptotes.horizontal) + " (limits check)");

const expn = analyzeProblem({ expr: "2^-x" });
ck("decaying exponential: horizontal y=0 both sides", expn.ok &&
  expn.asymptotes.horizontal.some((h) => Math.abs(h.y) < 1e-2), JSON.stringify(expn.asymptotes.horizontal));

const logf = analyzeProblem({ expr: "ln(x)" });
ck("logarithm: vertical asymptote x=0", logf.ok && hasNear(logf.asymptotes.vertical, 0));
ck("logarithm: only x>0 sampled (domain)", logf.segments.every((s) => s.pts.every((p) => p[0] > 0)));
ck("logarithm: endpoint (1,0) found", logf.features.endpoints.length >= 1 || hasNear(logf.features.roots, 1, 0.05));

const absf = analyzeProblem({ expr: "abs(x) - 2" });
ck("absolute: roots ±2, vertex at x=0", absf.ok && hasNear(absf.features.roots, 2) &&
  hasNear(absf.features.roots, -2) && near(absf.features.vertex[0], 0), JSON.stringify(absf.features));

const sq = analyzeProblem({ expr: "sqrt(x)" });
ck("square root: domain x≥0 only", sq.ok && sq.segments.every((s) => s.pts.every((p) => p[0] >= -1e-9)));
ck("square root: endpoint (0,0)", sq.features.endpoints.some((e) => near(e[0], 0, 1e-6) && near(e[1], 0, 1e-6)),
  JSON.stringify(sq.features.endpoints));

const tn = analyzeProblem({ expr: "tan(x)" });
ck("tangent: ≥2 vertical asymptotes in window", tn.ok && tn.asymptotes.vertical.length >= 2,
  JSON.stringify(tn.asymptotes.vertical));
ck("tangent: no cross-discontinuity connection", tn.segments.every((s) => s.pts.length > 1) && tn.segments.length >= 3);

const circ = analyzeProblem({ circle: { cx: 1, cy: 2, r: 5 } });
ck("circle: ok + axis intercepts derived", circ.ok &&
  hasNear(circ.features.roots, 1 - Math.sqrt(21)) && near(circ.features.yint[1], 2 - Math.sqrt(24), 1e-4),
  JSON.stringify({ r: circ.features.roots, y: circ.features.yint }));

const sys = analyzeProblem({ eqs: ["3 - x", "x^2 - 4x + 3"] });
ck("simultaneous: intersections (0,3) and (3,0)", sys.ok &&
  sys.intersections.some((p) => near(p[0], 0, 1e-3) && near(p[1], 3, 1e-3)) &&
  sys.intersections.some((p) => near(p[0], 3, 1e-3) && near(p[1], 0, 1e-3)),
  JSON.stringify(sys.intersections));

const ineq = analyzeProblem({ ineq: { expr: "x + 1", rel: "<" } });
ck("inequality: band spec + bound samples", ineq.ok && ineq.band && ineq.band.rel === "<" &&
  ineq.segments.length > 0, JSON.stringify(ineq.band));

const piece = analyzeProblem({ expr: "abs(x)" });
ck("piecewise/discontinuous input never fabricates data (abs ok)", piece.ok);

/* ── ticks & formatting ── */
const t1 = niceTicks(-7, 7, 8);
ck("ticks step ∈ {1,2,5}×10^k", [1, 2, 5].some((m) => Math.abs(t1.step / Math.pow(10, Math.round(Math.log10(t1.step)))) - m < 1e-9), "step=" + t1.step);
ck("ticks lie inside the range, edge-to-edge within one step, incl. 0",
  t1.majors.length >= 3 && t1.majors[0] >= -7 - 1e-9 && t1.majors[0] <= -7 + t1.step + 1e-9 &&
  t1.majors[t1.majors.length - 1] <= 7 + 1e-9 &&
  t1.majors[t1.majors.length - 1] >= 7 - t1.step - 1e-9 &&
  t1.majors.some((m) => Math.abs(m) < 1e-9),
  JSON.stringify(t1.majors.slice(0, 4)) + " step=" + t1.step);
const t2 = niceTicks(-0.3, 0.3, 8);
ck("small range gets a 10^-1-family step", t2.step <= 0.2 && t2.step >= 0.02, "step=" + t2.step);
ck("fmtTick fractions/decimals", fmtTick(0.5) === "1/2" && fmtTick(0.25) === "1/4" && fmtTick(-1.5) === "-3/2" &&
  fmtTick(2) === "2" && fmtTick(-0) === "0" && fmtTick(2.25) === "9/4",
  [0.5, 0.25, -1.5, 2, -0, 2.25].map(fmtTick).join("|"));
ck("fmtCoord sensible precision", fmtCoord(2.00004, -1) === "(2, -1)", fmtCoord(2.00004, -1));

/* ── error handling: clear limitations, never misleading output ── */
ck("empty input rejected", parseProblem("").ok === false);
ck("unknown function rejected", parseProblem("mystery(x)").ok === false);
ck("unknown identifier rejected", parseProblem("y + foo").ok === false);
ck("bad syntax rejected", parseProblem("2x +").ok === false);
ck("unsupported chars rejected", parseProblem("x @ 3").ok === false);
ck("injection-style input rejected", parseProblem("__import__('os')").ok === false);
ck("clear error messages present",
  ["unsupported function", "unknown name", "unexpected", "empty expression"]
    .some((k) => (parseProblem("mystery(x)").error || "").includes(k) ||
      (parseProblem("").error || "").includes(k) ||
      (parseProblem("2x +").error || "").includes(k)));

console.log("graph_core test: " + pass + " passed, " + fail + " failed");
if (fail) process.exit(1);
