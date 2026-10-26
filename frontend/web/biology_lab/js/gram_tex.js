/* Shared CanvasTexture helpers for the Gram-staining liquid renderers (pour
   ribbons, rinse sheet-flow, runoff and splash). Every texture is white with
   varying alpha so each material can tint the same cached texture with its
   reagent colour. Sizes are capped at GRAM_GEOMETRY.budgets.maxTexturePx
   (512px), textures are built once and shared, and repaintDue() gates dynamic
   canvas repaints to <=20Hz per the perf budget. Requires a browser DOM. */
import * as THREE from "three";
import { GRAM_GEOMETRY } from "./gram_shared.js";

export const GRAM_TEX_CAP = GRAM_GEOMETRY.budgets.maxTexturePx;
export const GRAM_TEX_REPAINT_HZ = GRAM_GEOMETRY.budgets.maxRepaintHz;

const cache = new Map();

function capSize(size) {
  const n = Number(size);
  const s = Number.isFinite(n) && n > 0 ? Math.floor(n) : 128;
  return Math.min(s, GRAM_TEX_CAP);
}

function canvasFor(size) {
  if (typeof document === "undefined") {
    throw new Error("gram_tex.js needs a browser DOM canvas");
  }
  const c = document.createElement("canvas");
  c.width = size;
  c.height = size;
  return c;
}

/* deterministic PRNG so the shared cached texture is identical every build */
function rng(seed) {
  let s = (seed >>> 0) || 1;
  return function () {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function finish(canvas, repeatT) {
  const t = new THREE.CanvasTexture(canvas);
  t.colorSpace = THREE.SRGBColorSpace;
  t.wrapS = THREE.ClampToEdgeWrapping;
  t.wrapT = repeatT ? THREE.RepeatWrapping : THREE.ClampToEdgeWrapping;
  t.anisotropy = 4;
  t.needsUpdate = true;
  return t;
}

function cached(key, build) {
  const hit = cache.get(key);
  if (hit) return hit;
  const tex = build();
  cache.set(key, tex);
  return tex;
}

/* Vertical streak field for scrolling down a liquid column: fine bright
   strands over a soft centre highlight. Scroll by moving material.map.offset.y
   (wrapT is RepeatWrapping). */
export function streakTexture(opts) {
  const o = opts || {};
  const size = capSize(o.size || 128);
  return cached("streak:" + size, function () {
    const c = canvasFor(size);
    const x = c.getContext("2d");
    x.clearRect(0, 0, size, size);
    const rand = rng(0x51ea7);
    for (let i = 0; i < 18; i++) {
      const w = 1 + rand() * (size / 22);
      x.fillStyle = "rgba(255,255,255," + (0.08 + rand() * 0.5).toFixed(3) + ")";
      x.fillRect(rand() * size, 0, w, size);
    }
    for (let i = 0; i < 8; i++) {
      const h = 1 + rand() * (size / 18);
      x.fillStyle = "rgba(255,255,255," + (0.05 + rand() * 0.22).toFixed(3) + ")";
      x.fillRect(0, rand() * size, size, h);
    }
    const g = x.createLinearGradient(0, 0, size, 0);
    g.addColorStop(0, "rgba(255,255,255,0)");
    g.addColorStop(0.5, "rgba(255,255,255,0.35)");
    g.addColorStop(1, "rgba(255,255,255,0)");
    x.fillStyle = g;
    x.fillRect(0, 0, size, size);
    return finish(c, true);
  });
}

/* Noise-blob alpha mask: soft interior with an irregular angular edge, for
   spreading pools, film patches and any liquid that must not read as a disc. */
export function blobTexture(opts) {
  const o = opts || {};
  const size = capSize(o.size || 128);
  return cached("blob:" + size, function () {
    const c = canvasFor(size);
    const x = c.getContext("2d");
    const img = x.createImageData(size, size);
    const d = img.data;
    const cx = (size - 1) / 2;
    const R = size / 2;
    for (let py = 0; py < size; py++) {
      for (let px = 0; px < size; px++) {
        const dx = (px - cx) / R;
        const dy = (py - cx) / R;
        const r = Math.sqrt(dx * dx + dy * dy);
        const i = (py * size + px) * 4;
        d[i] = 255;
        d[i + 1] = 255;
        d[i + 2] = 255;
        if (r >= 1) continue;
        const ang = Math.atan2(dy, dx);
        const edge = 0.8 + 0.14 * Math.sin(ang * 3 + 0.7)
          + 0.08 * Math.sin(ang * 5 + 2.3)
          + 0.05 * Math.sin(ang * 8 + 4.9);
        let a = 1 - r / edge;
        if (a <= 0) continue;
        a = Math.min(1, a * 2.2);
        a *= 0.85 + 0.15 * Math.sin(r * 9 + ang * 2);
        d[i + 3] = Math.round(Math.max(0, Math.min(1, a)) * 255);
      }
    }
    x.putImageData(img, 0, 0);
    return finish(c, false);
  });
}

/* Splash-ring alpha mask: a bright irregular ring with a faint inner glow. */
export function splashRingTexture(opts) {
  const o = opts || {};
  const size = capSize(o.size || 128);
  return cached("ring:" + size, function () {
    const c = canvasFor(size);
    const x = c.getContext("2d");
    const img = x.createImageData(size, size);
    const d = img.data;
    const cx = (size - 1) / 2;
    const R = size / 2;
    for (let py = 0; py < size; py++) {
      for (let px = 0; px < size; px++) {
        const dx = (px - cx) / R;
        const dy = (py - cx) / R;
        const r = Math.sqrt(dx * dx + dy * dy);
        const i = (py * size + px) * 4;
        d[i] = 255;
        d[i + 1] = 255;
        d[i + 2] = 255;
        if (r >= 1) continue;
        const ang = Math.atan2(dy, dx);
        let a = Math.exp(-((r - 0.72) * (r - 0.72)) / 0.0162);
        a *= 0.7 + 0.3 * Math.sin(ang * 4 + 1.1);
        a += 0.18 * Math.exp(-(r * r) / 0.16);
        d[i + 3] = Math.round(Math.max(0, Math.min(1, a)) * 255);
      }
    }
    x.putImageData(img, 0, 0);
    return finish(c, false);
  });
}

/* alias spellings so call sites can read either naming style */
export const makeStreakTexture = streakTexture;
export const makeBlobTexture = blobTexture;
export const makeSplashRingTexture = splashRingTexture;
export const makeRingTexture = splashRingTexture;
export const ringTexture = splashRingTexture;

/* True when `nowMs` is at least one repaint interval past `lastMs`, keeping
   dynamic canvas repaints at or under GRAM_TEX_REPAINT_HZ. */
export function repaintDue(lastMs, nowMs, hz) {
  const n = Number(nowMs);
  const l = Number(lastMs);
  if (!Number.isFinite(n) || !Number.isFinite(l)) return true;
  const rate = Number(hz) > 0 ? Number(hz) : GRAM_TEX_REPAINT_HZ;
  return n - l >= 1000 / rate;
}

/* Teardown: dispose cached textures (call only when nothing references them). */
export function clearGramTextures() {
  cache.forEach(function (t) { t.dispose(); });
  cache.clear();
}
