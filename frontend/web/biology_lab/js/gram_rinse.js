/* Rinse FX: continuous tap water over the tilted slide — a flowing sheet
   across the smeared surface, an impact crown where the tap stream lands, and
   coloured runoff droplets draining off the low edge into the basin, fading
   from the reagent's colour toward clear as the wash progresses. Forces the
   lab tap into its continuous 'stream' mode while rinsing. Implements the
   GramRinseApi contract (superset: setFilmState). */

import * as THREE from "three";
import { REAGENTS, GRAM_GEOMETRY, clamp01, mixHex, runoffColour, COLOURLESS } from "./gram_shared.js";
import { RINSE, flowActive } from "./gram_models.js";
import { streakTexture, splashRingTexture } from "./gram_tex.js";

const RAD = GRAM_GEOMETRY.streamRadii;

/**
 * @param {{scene:*}} opts
 * @returns {GramRinseApi & {setFilmState:function(Object):void, isRunning:function():boolean}}
 */
export function createGramRinse(opts) {
  const o = opts || {};
  const root = new THREE.Group();
  root.name = "gramRinseFX";
  if (o.scene) o.scene.add(root);

  const streak = streakTexture({ size: 128 });
  const ringTex = splashRingTexture({ size: 128 });

  /* water sheet flowing down the tilted slide surface */
  const sheetMat = new THREE.MeshBasicMaterial({
    map: streak, color: 0xd8eefb, transparent: true, opacity: 0,
    depthWrite: false, side: THREE.DoubleSide, toneMapped: false,
  });
  sheetMat.map.repeat.set(1, 1.5);
  const sheet = new THREE.Mesh(
    new THREE.PlaneGeometry(GRAM_GEOMETRY.slide.x * 0.92, GRAM_GEOMETRY.slide.z * 0.94), sheetMat);
  sheet.rotation.x = -Math.PI / 2;
  sheet.visible = false;
  sheet.renderOrder = 7;
  root.add(sheet);

  /* impact crown where the tap column strikes */
  const crownMat = new THREE.MeshBasicMaterial({
    map: ringTex, color: 0xeaf7ff, transparent: true, opacity: 0,
    depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, toneMapped: false,
  });
  const crown = new THREE.Mesh(new THREE.PlaneGeometry(RAD.impactRing * 2.2, RAD.impactRing * 2.2), crownMat);
  crown.rotation.x = -Math.PI / 2;
  crown.visible = false;
  crown.renderOrder = 8;
  root.add(crown);

  /* spray hops at the strike point */
  const spray = [];
  for (let i = 0; i < 4; i++) {
    const m = new THREE.Mesh(new THREE.SphereGeometry(RAD.tapDrop * 0.7, 6, 5),
      new THREE.MeshBasicMaterial({ color: 0xeaf7ff, transparent: true, opacity: 0, depthWrite: false }));
    m.visible = false;
    root.add(m);
    spray.push({ m: m, ph: i / 4 });
  }

  /* runoff droplets from the low edge + rings where they land */
  const drops = [];
  for (let i = 0; i < 9; i++) {
    const m = new THREE.Mesh(new THREE.SphereGeometry(RAD.runoff * 0.62, 6, 5),
      new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0, depthWrite: false }));
    m.visible = false;
    root.add(m);
    drops.push({ m: m, on: false, v: new THREE.Vector3() });
  }
  const rings = [];
  for (let i = 0; i < 5; i++) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(RAD.impactRing * 2, RAD.impactRing * 2),
      new THREE.MeshBasicMaterial({ map: ringTex, color: 0xffffff, transparent: true, opacity: 0,
        depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, toneMapped: false }));
    m.rotation.x = -Math.PI / 2;
    m.visible = false;
    root.add(m);
    rings.push({ m: m, t: -1 });
  }

  let running = false;
  let tap = null;
  let slide = null;
  let tint = COLOURLESS;          /* current runoff colour, fading toward clear */
  let filmAlpha = 0;
  let spawnAcc = 0;
  let ringIdx = 0;
  let basinY = null;
  let baseTint = COLOURLESS;

  function nozzleWorld() {
    if (!tap || !tap.stream) return null;
    tap.stream.updateWorldMatrix(true, false);
    const v = new THREE.Vector3();
    tap.stream.getWorldPosition(v);
    return v;
  }

  function resolveBasinY(noz) {
    if (tap && tap.pool) {
      tap.pool.updateWorldMatrix(true, false);
      const p = new THREE.Vector3();
      tap.pool.getWorldPosition(p);
      if (Number.isFinite(p.y)) return p.y + 0.004;
    }
    if (tap && Number.isFinite(tap.fall)) return noz.y - tap.fall + 0.06;
    return noz.y - 0.34;
  }

  function landRing(x, y, z, colour) {
    const r = rings[ringIdx++ % rings.length];
    r.m.position.set(x, y + 0.004, z);
    r.m.material.color.setHex(colour);
    r.m.material.opacity = 0.5;
    r.m.scale.setScalar(0.3);
    r.m.visible = true;
    r.t = 0;
  }

  return {
    start: function (args) {
      const a = args || {};
      tap = a.tapRef || null;
      slide = a.slide || null;
      const def = REAGENTS[a.reagentId];
      baseTint = def ? (a.reagentId === "de" ? 0xe8f2ee : def.colour) : 0xcbe7f3;
      tint = baseTint;
      running = true;
      spawnAcc = 0;
      basinY = null;
      this.streamMode(tap, true);
    },
    stop: function () {
      running = false;
      this.streamMode(tap, false);
      sheet.visible = false; sheetMat.opacity = 0;
      crown.visible = false; crownMat.opacity = 0;
      spray.forEach(function (s) { s.m.visible = false; s.m.material.opacity = 0; });
      drops.forEach(function (d) { d.on = false; d.m.visible = false; d.m.material.opacity = 0; });
      rings.forEach(function (r) { r.t = -1; r.m.visible = false; r.m.material.opacity = 0; });
      tap = null; slide = null; filmAlpha = 0;
    },
    streamMode: function (tapRef, on) {
      const forced = !!on;
      if (tapRef && typeof tapRef === "object") {
        if (forced) {
          if (tapRef.mode !== "stream") tapRef.__gramPrevMode = tapRef.mode;
          tapRef.mode = "stream";
        } else if (tapRef.mode === "stream" && tapRef.__gramPrevMode !== undefined) {
          tapRef.mode = tapRef.__gramPrevMode;
          delete tapRef.__gramPrevMode;
        }
      }
    },
    setFilmState: function (state) {
      if (state && state.film) filmAlpha = clamp01(state.film.alpha);
    },
    tick: function (dt) {
      if (!running || !tap || !slide) return;
      const d = Math.min(0.1, Math.max(0, Number(dt) || 0));
      const flow = flowActive(tap.t) && Math.abs(tap.target) > 0.3;
      const noz = nozzleWorld();
      if (!noz) return;
      if (basinY === null) basinY = resolveBasinY(noz);
      const imp = slide.getImpactPoint();
      const tilt = typeof slide.getTilt === "function" ? slide.getTilt() : 0;

      /* progressive runoff fade: the wash colour dilutes toward clear over time */
      if (flow && filmAlpha > 0.02) tint = runoffColour(tint, 0.9, d);
      else if (!flow && filmAlpha <= 0.02) tint = mixHex(tint, COLOURLESS, Math.min(1, d * 2));

      /* sheet over the smear */
      const n = { x: 0, y: Math.cos(tilt), z: Math.sin(tilt) };
      sheet.position.set(imp.x + n.x * 0.0016, imp.y + n.y * 0.0016, imp.z + n.z * 0.0016);
      sheet.rotation.x = -Math.PI / 2 + tilt;
      sheet.visible = flow;
      sheetMat.opacity = flow ? 0.55 : 0;
      if (flow && sheetMat.map) sheetMat.map.offset.y -= d * 3.2;

      /* strike point directly under the nozzle */
      crown.position.set(noz.x, imp.y + 0.0016, noz.z);
      crown.visible = flow;
      if (flow) {
        crownMat.opacity = 0.5 + 0.22 * Math.sin(performance.now() * 0.02);
        crown.scale.setScalar(0.85 + 0.3 * Math.sin(performance.now() * 0.031));
      } else crownMat.opacity = 0;

      /* spray hops */
      const tt = performance.now() * 0.001;
      spray.forEach(function (s) {
        const ph = (tt * 2.4 + s.ph) % 1;
        if (!flow) { s.m.visible = false; return; }
        const ang = s.ph * Math.PI * 2 + tt * 1.7;
        s.m.visible = true;
        s.m.material.opacity = (1 - ph) * 0.8;
        s.m.position.set(noz.x + Math.cos(ang) * 0.016 * (1 - ph),
          imp.y + 0.004 + Math.sin(ph * Math.PI) * 0.03,
          noz.z + Math.sin(ang) * 0.016 * (1 - ph));
      });

      /* runoff off the dipped edge, tinted by the fading wash colour */
      if (flow && filmAlpha > 0.03) {
        spawnAcc += d * RINSE.runoffRate * clamp01(filmAlpha + 0.25);
        while (spawnAcc >= 1) {
          spawnAcc -= 1;
          const free = drops.find(function (x) { return !x.on; });
          if (!free) break;
          const edge = slide.getLowEdge();
          free.on = true;
          free.m.visible = true;
          free.m.material.opacity = 0.85;
          free.m.material.color.setHex(tint);
          free.m.position.set(edge.x + (Math.random() - 0.5) * 0.01, edge.y, edge.z + (Math.random() - 0.5) * 0.006);
          free.v.set((Math.random() - 0.5) * 0.03, -0.05, Math.cos(tilt) * 0.16 + 0.04);
        }
      }
      drops.forEach(function (dr) {
        if (!dr.on) return;
        dr.v.y -= 6.5 * d;
        dr.m.position.x += dr.v.x * d;
        dr.m.position.y += dr.v.y * d;
        dr.m.position.z += dr.v.z * d;
        if (dr.m.position.y <= basinY) {
          landRing(dr.m.position.x, basinY, dr.m.position.z, tint);
          dr.on = false;
          dr.m.visible = false;
          dr.m.material.opacity = 0;
        }
      });

      /* expanding rings where runoff lands */
      rings.forEach(function (r) {
        if (r.t < 0) return;
        r.t += d;
        const k = r.t / 0.7;
        if (k >= 1) { r.t = -1; r.m.visible = false; r.m.material.opacity = 0; return; }
        r.m.scale.setScalar(0.3 + k * 1.4);
        r.m.material.opacity = (1 - k) * 0.5;
      });
    },
    isRunning: function () { return running; },
    debug: function () {
      let on = 0;
      drops.forEach(function (d) { if (d.on) on++; });
      return { running: running, mode: tap ? tap.mode : null, target: tap ? tap.target : null,
        sheet: +sheetMat.opacity.toFixed(3), sheetVis: sheet.visible, crownVis: crown.visible,
        drops: on, tint: '#' + tint.toString(16).padStart(6, '0'),
        filmAlpha: +filmAlpha.toFixed(2) };
    },
    root: root,
  };
}
