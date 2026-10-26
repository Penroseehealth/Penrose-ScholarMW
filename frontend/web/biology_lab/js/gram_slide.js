/* 3D Gram-staining slide renderer: proper glass slab with edges, a frosted
   ID label, the two-population smear (gram-positive clusters / gram-negative
   rods) as soft-edged layers, the retained reagent film that visibly pools on
   the glass, and a wetness sheen. Implements the GramSlideApi contract. */

import * as THREE from "three";
import { GRAM_GEOMETRY, clampTilt, clamp01 } from "./gram_shared.js";
import { smearLayout, impactPoint, lowEdgePoint } from "./gram_models.js";
import { blobTexture, streakTexture } from "./gram_tex.js";

const SLIDE = GRAM_GEOMETRY.slide;

/* soft white RGBA stamps for one population; drawn once and cached per kind */
const texCache = new Map();
function smearTexture(layout, kind) {
  const key = kind + ":" + layout.w + ":" + layout.h + ":" + layout.gp.length + ":" + layout.neg.length;
  if (texCache.has(key)) return texCache.get(key);
  const W = 120, H = Math.round(W * (layout.h / layout.w));
  const c = document.createElement("canvas");
  c.width = W; c.height = H;
  const x = c.getContext("2d");
  x.clearRect(0, 0, W, H);
  const sx = W / layout.w, sy = H / layout.h;
  if (kind === "gp") {
    layout.gp.forEach(function (cl) {
      cl.cells.forEach(function (cell) {
        const px = cell.x * sx, py = cell.y * sy, r = cell.r * sx;
        const g = x.createRadialGradient(px, py, 0, px, py, r);
        g.addColorStop(0, "rgba(255,255,255,0.98)");
        g.addColorStop(0.62, "rgba(255,255,255,0.92)");
        g.addColorStop(1, "rgba(255,255,255,0)");
        x.fillStyle = g;
        x.beginPath(); x.arc(px, py, r, 0, Math.PI * 2); x.fill();
      });
    });
  } else {
    if (typeof x.filter === "string") x.filter = "blur(1.4px)";
    layout.neg.forEach(function (rod) {
      x.save();
      x.translate(rod.x * sx, rod.y * sy);
      x.rotate(rod.rot);
      const L = rod.len * sx, w = rod.wid * sy * 2.2;
      const g = x.createLinearGradient(0, -w / 2, 0, w / 2);
      g.addColorStop(0, "rgba(255,255,255,0.35)");
      g.addColorStop(0.5, "rgba(255,255,255,0.95)");
      g.addColorStop(1, "rgba(255,255,255,0.35)");
      x.fillStyle = g;
      x.beginPath();
      if (x.roundRect) x.roundRect(-L / 2, -w / 2, L, w, w / 2);
      else x.rect(-L / 2, -w / 2, L, w);
      x.fill();
      x.restore();
    });
    if (typeof x.filter === "string") x.filter = "none";
  }
  /* natural smear edge: fade everything toward the border */
  x.globalCompositeOperation = "destination-in";
  const edge = x.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, Math.max(W, H) / 2);
  edge.addColorStop(0, "rgba(255,255,255,1)");
  edge.addColorStop(0.66, "rgba(255,255,255,0.96)");
  edge.addColorStop(1, "rgba(255,255,255,0)");
  x.fillStyle = edge;
  x.fillRect(0, 0, W, H);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.needsUpdate = true;
  texCache.set(key, t);
  return t;
}

function labelTexture(id) {
  const key = "label:" + id;
  if (texCache.has(key)) return texCache.get(key);
  const c = document.createElement("canvas");
  c.width = 256; c.height = 96;
  const x = c.getContext("2d");
  x.fillStyle = "#e7edf1";
  x.fillRect(0, 0, 256, 96);
  x.strokeStyle = "#9aa7b0";
  x.lineWidth = 5;
  x.strokeRect(4, 4, 248, 88);
  x.fillStyle = "#2e3a45";
  x.font = "bold 40px 'Segoe UI',Arial";
  x.textAlign = "center";
  x.textBaseline = "middle";
  x.fillText(id, 128, 50);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.needsUpdate = true;
  texCache.set(key, t);
  return t;
}

/**
 * @param {{group?:*, id?:string, seed?:number, smearZ?:number}} [opts]
 * @returns {GramSlideApi & {getTilt:function():number, getWetness:function():number, parts:Object}}
 */
export function createGramSlide(opts) {
  const o = opts || {};
  const group = o.group || new THREE.Group();
  const inner = new THREE.Group();
  group.add(inner);

  const layout = smearLayout({ seed: o.seed === undefined ? 7 : o.seed, w: 0.015, h: 0.055 });
  const smearZ = o.smearZ === undefined ? 0.008 : o.smearZ;

  /* glass slab: real proportions, transparent with visible edges */
  const glassGeo = new THREE.BoxGeometry(SLIDE.x, SLIDE.y, SLIDE.z);
  const glass = new THREE.Mesh(glassGeo, new THREE.MeshPhysicalMaterial({
    color: 0xeaf3f7, transparent: true, opacity: 0.3, roughness: 0.07,
    metalness: 0, clearcoat: 0.7, clearcoatRoughness: 0.12, depthWrite: false,
  }));
  glass.renderOrder = 1;
  inner.add(glass);
  const edges = new THREE.LineSegments(new THREE.EdgesGeometry(glassGeo),
    new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.6 }));
  edges.renderOrder = 2;
  inner.add(edges);

  /* frosted identification label on one end */
  const label = new THREE.Mesh(new THREE.PlaneGeometry(SLIDE.x * 0.94, SLIDE.z * 0.18),
    new THREE.MeshBasicMaterial({ map: labelTexture(o.id || "MNH-0427"), transparent: true, opacity: 0.95, toneMapped: false }));
  label.rotation.x = -Math.PI / 2;
  label.position.set(0, SLIDE.y / 2 + 0.0004, -SLIDE.z / 2 + SLIDE.z * 0.095);
  label.renderOrder = 3;
  inner.add(label);

  /* smear population layers — tinted per chemistry snapshot */
  function layer(tex, y) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(layout.w, layout.h),
      new THREE.MeshStandardMaterial({
        map: tex, color: 0xffffff, transparent: true, opacity: 0,
        roughness: 0.5, depthWrite: false,
      }));
    m.rotation.x = -Math.PI / 2;
    m.position.set(0, y, smearZ);
    m.renderOrder = 4;
    inner.add(m);
    return m;
  }
  const gp = layer(smearTexture(layout, "gp"), SLIDE.y / 2 + 0.0007);
  const neg = layer(smearTexture(layout, "neg"), SLIDE.y / 2 + 0.0011);

  /* retained reagent film: a glossy pool spreading over the smear */
  const film = new THREE.Mesh(new THREE.PlaneGeometry(SLIDE.x * 0.86, SLIDE.z * 0.78),
    new THREE.MeshPhysicalMaterial({
      map: blobTexture({ size: 128 }), color: 0xffffff, transparent: true,
      opacity: 0, roughness: 0.22, clearcoat: 0.9, clearcoatRoughness: 0.15,
      depthWrite: false,
    }));
  film.rotation.x = -Math.PI / 2;
  film.position.set(0, SLIDE.y / 2 + 0.0015, smearZ);
  film.scale.set(0.4, 0.4, 1);
  film.renderOrder = 5;
  inner.add(film);

  /* wetness sheen: scrolling micro-streaks that read as a water film */
  const sheenMat = new THREE.MeshBasicMaterial({
    map: streakTexture({ size: 128 }), color: 0xdff2ff, transparent: true,
    opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending,
  });
  sheenMat.map.repeat.set(1, 1.6);
  const sheen = new THREE.Mesh(new THREE.PlaneGeometry(SLIDE.x * 0.95, SLIDE.z * 0.96), sheenMat);
  sheen.rotation.x = -Math.PI / 2;
  sheen.position.set(0, SLIDE.y / 2 + 0.0019, 0);
  sheen.renderOrder = 6;
  inner.add(sheen);

  let tilt = 0;
  let wet = 0;
  let filmScale = 0.4;
  let lastMs = (typeof performance !== "undefined" ? performance.now() : Date.now());

  function worldPos() {
    group.updateWorldMatrix(true, false);
    const v = new THREE.Vector3();
    group.getWorldPosition(v);
    return v;
  }

  return {
    group: group,
    parts: { inner: inner, glass: glass, label: label, gp: gp, neg: neg, film: film, sheen: sheen },
    setPopulations: function (state) {
      if (!state) return;
      const now = (typeof performance !== "undefined" ? performance.now() : Date.now());
      const dt = Math.min(0.1, Math.max(0, (now - lastMs) / 1000));
      lastMs = now;
      if (state.pos) {
        gp.material.color.setHex(state.pos.colour);
        gp.material.opacity = clamp01(state.pos.alpha);
        gp.visible = state.pos.alpha > 0.01;
      }
      if (state.neg) {
        neg.material.color.setHex(state.neg.colour);
        neg.material.opacity = clamp01(state.neg.alpha);
        neg.visible = state.neg.alpha > 0.01;
      }
      if (state.film) {
        const a = clamp01(state.film.alpha);
        film.material.color.setHex(state.film.colour);
        film.material.opacity = a;
        film.visible = a > 0.01;
        /* the pool spreads outward while reagent lands, then holds */
        const target = a > 0.01 ? 1 : 0.4;
        filmScale += (target - filmScale) * Math.min(1, dt * 4);
        film.scale.set(0.4 + 0.6 * filmScale, 0.4 + 0.6 * filmScale, 1);
      }
    },
    setTilt: function (rad) {
      tilt = clampTilt(rad);
      inner.rotation.x = tilt;
    },
    setWetness: function (w) {
      wet = clamp01(w);
      sheen.material.opacity = wet * 0.42;
      sheen.visible = wet > 0.02;
      if (sheenMat.map) sheenMat.map.offset.y -= 0.012 * wet;
    },
    getImpactPoint: function () {
      return impactPoint(worldPos(), tilt, SLIDE);
    },
    getLowEdge: function () {
      return lowEdgePoint(worldPos(), tilt, SLIDE);
    },
    getTilt: function () { return tilt; },
    getWetness: function () { return wet; },
  };
}
