/* Gram-staining FX planning models — THREE-free, importable from plain Node.
   Shared by the renderers (js/gram_slide|pour|rinse|choreo.js), the bottle
   choreography in index.html and the scripts/gram_*_unit.mjs tests, so the
   timings the bottle tween plays and the timings the liquid FX fires can never
   drift apart. Depends only on js/gram_shared.js. */

import { GRAM_GEOMETRY, clamp01, degToRad } from "./gram_shared.js";

/* ---------------- pour timeline ----------------
   The bottle tween in index.html and the liquid ribbon both read these phase
   fractions of POUR.duration (seconds at speed 1). The ribbon may only run
   while the bottle is actually tilted (hold window), and the on-slide film
   starts accumulating the moment the reagent first touches the glass. */

export const POUR = {
  duration: 3.0,
  phases: {
    lift: 0.22,      /* 0 → rise clear of the tray */
    travel: 0.34,    /* → positioned above the slide */
    holdStart: 0.34, /* tilted, liquid flowing */
    holdEnd: 0.70,   /* untilt begins */
    untilt: 0.84,    /* level again */
    end: 1.0,
  },
};

/** Named pour phase at normalised time k∈[0,1]. The travel segment includes
    the tilt-in rotation, so the bottle is already pouring by 'hold'. */
export function pourPhaseAt(k) {
  const f = POUR.phases;
  const t = clamp01(k);
  if (t < f.lift) return "lift";
  if (t < f.travel) return "travel";
  if (t < f.holdEnd) return "hold";
  if (t < f.untilt) return "untilt";
  return "return";
}

/** Seconds [from,to] during which the liquid ribbon is visible (bottle tilted). */
export function ribbonWindow(duration) {
  const d = Number(duration) > 0 ? Number(duration) : POUR.duration;
  const f = POUR.phases;
  return { from: f.holdStart * d, to: f.holdEnd * d };
}

/** Film coverage 0..1 at time t seconds after the ribbon starts (spread ramp). */
export function coverageAt(t) {
  return clamp01(Number(t) / 0.8);
}

/* ---------------- smear layout ----------------
   Deterministic cell placement for the two populations: gram-positive cocci in
   grape-like clusters, gram-negative rods scattered between them, both biased
   toward the centre so the smear fades out naturally at its edges (the
   renderer turns each entry into a soft-edged canvas stamp). */

export function smearLayout(opts) {
  const o = opts || {};
  const w = Number(o.w) > 0 ? Number(o.w) : 0.015;
  const h = Number(o.h) > 0 ? Number(o.h) : 0.055;
  let seed = Number.isFinite(o.seed) ? Math.floor(o.seed) : 7;
  function rnd() {
    seed = (seed * 9301 + 49297) % 233280;
    return seed / 233280;
  }
  const clusters = [];
  const gpCount = Number(o.gpClusters) > 0 ? Number(o.gpClusters) : 5;
  const negCount = Number(o.negRods) > 0 ? Number(o.negRods) : 14;
  const edge = Math.min(w, h) * 0.18;

  /* gram-positive: tight clusters of cocci, biased to the smear core */
  for (let c = 0; c < gpCount; c++) {
    const cx = edge + rnd() * (w - 2 * edge);
    const cy = edge + rnd() * (h - 2 * edge);
    const cells = [];
    const n = 5 + Math.floor(rnd() * 5);
    for (let i = 0; i < n; i++) {
      const a = rnd() * Math.PI * 2;
      const d = (0.12 + rnd() * 0.88) * w * 0.14;
      cells.push({
        x: Math.min(w - edge, Math.max(edge, cx + Math.cos(a) * d)),
        y: Math.min(h - edge, Math.max(edge, cy + Math.sin(a) * d)),
        r: w * (0.055 + rnd() * 0.03),
      });
    }
    clusters.push({ x: cx, y: cy, cells: cells });
  }

  /* gram-negative: slender rods, random angles, centre-biased */
  const rods = [];
  for (let i = 0; i < negCount; i++) {
    const bias = Math.sqrt(rnd());
    const cy = h * 0.5 + (rnd() - 0.5) * h * bias;
    const cx = edge + rnd() * (w - 2 * edge);
    rods.push({
      x: Math.min(w - edge, Math.max(edge, cx)),
      y: Math.min(h - edge, Math.max(edge, cy)),
      len: w * (0.34 + rnd() * 0.2),
      wid: w * (0.075 + rnd() * 0.02),
      rot: rnd() * Math.PI,
    });
  }
  return { w: w, h: h, gp: clusters, neg: rods };
}

/* ---------------- slide pose maths ----------------
   Mirrors the slide contract: positive tilt dips the +z end. Kept here so the
   renderer and the unit tests agree on where the stream lands and where the
   rinse water drains off. */

export function impactPoint(pos, tilt, size) {
  const s = size || GRAM_GEOMETRY.slide;
  const t = Number(tilt) || 0;
  const c = Math.cos(t), sn = Math.sin(t);
  const dy = s.y / 2, dz = 0;
  return { x: pos.x, y: pos.y + (dy * c - dz * sn), z: pos.z + (dy * sn + dz * c) };
}

export function lowEdgePoint(pos, tilt, size) {
  const s = size || GRAM_GEOMETRY.slide;
  const t = Number(tilt) || 0;
  const c = Math.cos(t), sn = Math.sin(t);
  const dy = -s.y / 2;
  const dz = t >= 0 ? s.z / 2 : -s.z / 2;
  return { x: pos.x, y: pos.y + (dy * c - dz * sn), z: pos.z + (dy * sn + dz * c) };
}

/* ---------------- rinse schedule ----------------
   The slide travels ~0.9 s to the sink; the water must strike it only once it
   sits under the nozzle, then hold the 25-45° working band while washing and
   level out again on the way back to the rack. */

export const RINSE = {
  arriveAt: 1.0,                    /* seconds after stage entry: slide under nozzle */
  tiltDeg: 30,                      /* wash angle beneath the stream */
  tiltRamp: 0.6,                    /* seconds to reach the wash angle */
  sheetDelay: 0.12,                 /* film of water once contact is made */
  manualGate: 3.5,                  /* seconds the tap must run for a manual rinse */
  runoffRate: 9,                    /* droplets per second off the low edge */
};

export function rinseTiltAt(t) {
  const k = clamp01((Number(t) - RINSE.arriveAt) / RINSE.tiltRamp);
  return degToRad(RINSE.tiltDeg) * (k * k * (3 - 2 * k));
}

/** True when the tap's eased flow value counts as running water. */
export function flowActive(flow) {
  return Math.abs(Number(flow) || 0) > 0.3;
}
