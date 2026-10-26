/* Reagent pouring FX: a flowing liquid ribbon from the bottle tip to the slide,
   an impact ring where the stream lands, and the film colour handoff. The
   ribbon only exists inside the bottle's tilted hold window (gram_models), so
   the stream can never pour while the bottle is upright. Implements the
   GramPourApi contract. */

import * as THREE from "three";
import { REAGENTS, GRAM_GEOMETRY, clamp01 } from "./gram_shared.js";
import { ribbonWindow, POUR } from "./gram_models.js";
import { streakTexture, splashRingTexture } from "./gram_tex.js";

/**
 * @param {{scene:*, speed?:number}} opts
 * @returns {GramPourApi & {isPouring:function():boolean}}
 */
export function createGramPour(opts) {
  const o = opts || {};
  const speed = o.speed > 0 ? o.speed : 1;
  const root = new THREE.Group();
  root.name = "gramPourFX";
  if (o.scene) o.scene.add(root);

  const streak = streakTexture({ size: 128 });
  const ribbonMat = new THREE.MeshBasicMaterial({
    map: streak, color: 0xffffff, transparent: true, opacity: 0,
    depthWrite: false, side: THREE.DoubleSide, toneMapped: false,
  });
  const ribbon = new THREE.Mesh(new THREE.BufferGeometry(), ribbonMat);
  ribbon.visible = false;
  ribbon.renderOrder = 7;
  root.add(ribbon);

  const ringMat = new THREE.MeshBasicMaterial({
    map: splashRingTexture({ size: 128 }), color: 0xffffff, transparent: true,
    opacity: 0, depthWrite: false, side: THREE.DoubleSide,
    blending: THREE.AdditiveBlending, toneMapped: false,
  });
  const impact = new THREE.Mesh(new THREE.PlaneGeometry(
    GRAM_GEOMETRY.streamRadii.impactRing * 2.4, GRAM_GEOMETRY.streamRadii.impactRing * 2.4), ringMat);
  impact.rotation.x = -Math.PI / 2;
  impact.visible = false;
  impact.renderOrder = 8;
  root.add(impact);

  let pending = null;
  let filmColour = 0xffffff;
  let fade = 0;

  function buildRibbon(from, to) {
    const a = new THREE.Vector3(from.x, from.y, from.z);
    const b = new THREE.Vector3(to.x, to.y, to.z);
    const sag = 0.05;
    const pts = [
      a.clone(),
      new THREE.Vector3(a.x + (b.x - a.x) * 0.25, a.y - sag * 0.4, a.z + (b.z - a.z) * 0.25),
      new THREE.Vector3(a.x + (b.x - a.x) * 0.6, (a.y + b.y) / 2 - sag, a.z + (b.z - a.z) * 0.6),
      new THREE.Vector3(b.x, b.y + 0.01, b.z),
      b.clone(),
    ];
    const curve = new THREE.CatmullRomCurve3(pts);
    const geo = new THREE.TubeGeometry(curve, 26, GRAM_GEOMETRY.streamRadii.pour, 8, false);
    ribbon.geometry.dispose();
    ribbon.geometry = geo;
  }

  return {
    startPour: function (reagentId, route) {
      const def = REAGENTS[reagentId];
      const r = route || {};
      if (!def || !r.from || !r.to) return;
      const win = ribbonWindow(POUR.duration / speed);
      pending = {
        reagentId: reagentId,
        t: 0,
        dur: Math.max(0.35, win.to - win.from),
        onDone: typeof r.onDone === "function" ? r.onDone : null,
        done: false,
      };
      buildRibbon(r.from, r.to);
      ribbonMat.color.setHex(def.role === "decolouriser" ? 0xdff2ee : def.colour);
      ribbonMat.opacity = 0.0;
      ribbon.visible = true;
      impact.position.set(r.to.x, r.to.y + 0.0015, r.to.z);
      impact.material.color.copy(ribbonMat.color);
      impact.material.opacity = 0;
      impact.visible = true;
      fade = 0;
    },
    tick: function (dt) {
      const d = Number(dt) || 0;
      if (ribbonMat.map) ribbonMat.map.offset.y -= d * 2.6;
      if (!pending) {
        if (fade > 0 && ribbon.visible) {
          fade = Math.max(0, fade - d * 5);
          ribbonMat.opacity = fade * 0.85;
          ringMat.opacity = fade * 0.5;
          if (fade === 0) { ribbon.visible = false; impact.visible = false; }
        }
        return;
      }
      if (d > 0) pending.t += d;
      const k = clamp01(pending.t / pending.dur);
      /* ramp in fast, hold, ramp out — never a pop */
      const env = k < 0.14 ? k / 0.14 : (k > 0.82 ? (1 - k) / 0.18 : 1);
      ribbonMat.opacity = clamp01(env) * 0.9;
      const pulse = 0.75 + 0.25 * Math.sin(pending.t * 26);
      ringMat.opacity = clamp01(env) * 0.55 * pulse;
      impact.scale.setScalar(0.8 + 0.35 * Math.sin(pending.t * 13));
      if (!pending.done && pending.t >= pending.dur) {
        pending.done = true;
        fade = 1;
        const cb = pending.onDone;
        pending = null;
        if (cb) cb();
      }
    },
    setFilm: function (state) {
      if (state && state.film && state.film.alpha > 0.01) filmColour = state.film.colour;
    },
    clear: function () {
      pending = null;
      fade = 0;
      ribbon.visible = false;
      impact.visible = false;
      ribbonMat.opacity = 0;
      ringMat.opacity = 0;
    },
    isPouring: function () { return !!pending && !pending.done; },
    debug: function () {
      return { pouring: !!pending && !pending.done, opacity: +ribbonMat.opacity.toFixed(3),
        visible: ribbon.visible, id: pending ? pending.reagentId : null };
    },
    root: root,
  };
}

