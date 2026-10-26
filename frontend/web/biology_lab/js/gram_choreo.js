/* Gram-practical choreography: the THREE-free step director that ties the
   chemistry state machine to the slide, pour and rinse renderers. Owns the
   reagent timeline: liquid starts when the bottle reaches its tilt window,
   coverage ramps as it spreads, rinses run under the tap once the slide sits
   under the nozzle, and the slide holds the wash angle while draining.
   Implements the GramChoreoApi contract (superset: inspection helpers). */

import { createStainState } from "./gram_shared.js";
import { POUR, ribbonWindow, coverageAt, RINSE, rinseTiltAt } from "./gram_models.js";

/**
 * @param {{slide?:*, pour?:*, rinse?:*, steps?:Array, chem?:*, deps?:Object}} [opts]
 *   deps.route(reagentId) -> {from,to}  bottle-tip → slide-impact world route
 *   deps.tap()            -> lab tap ref for the station sink
 * @returns {GramChoreoApi & {getSnapshot:Function, getLastStain:Function, getStep:Function, isRinsing:Function}}
 */
export function createGramChoreo(opts) {
  const o = opts || {};
  const slide = o.slide, pour = o.pour, rinse = o.rinse;
  const steps = o.steps || [];
  const deps = o.deps || {};
  let chem = o.chem || createStainState();
  const win = ribbonWindow(POUR.duration);

  let idx = -1, t = 0;
  let poured = false, rinseOn = false;
  let lastStain = null, tiltCur = 0;

  function stepDef() {
    return steps[Math.max(0, Math.min(steps.length - 1, idx))];
  }
  function resetChem() {
    if (chem && typeof chem.reset === "function") chem.reset();
    else chem = createStainState();
    lastStain = null;
  }

  return {
    setStep: function (i, flag) {
      const prev = idx;
      idx = Math.max(0, Math.min(steps.length - 1, Number(i) | 0));
      t = 0;
      poured = false;
      if (rinseOn) {
        rinseOn = false;
        if (rinse && rinse.stop) rinse.stop();
        if (rinse && rinse.streamMode && deps.tap) rinse.streamMode(deps.tap(), false);
      }
      if (pour && pour.clear) pour.clear();
      /* replaying from the top (Start at the end / a jump back to a fresh smear)
         starts the chemistry over; lateral jumps keep what has been applied */
      if (idx === 0 && prev > 0) resetChem();
      if (flag && flag.reset) resetChem();
    },
    tick: function (dt) {
      const d = Math.min(0.1, Math.max(0, Number(dt) || 0));
      if (idx < 0 || !steps.length) return;
      t += d;
      const st = stepDef();

      /* slide attitude: wash angle under the stream, level everywhere else */
      let tgt = 0;
      if (st.k === "rinse" && t >= RINSE.arriveAt) tgt = rinseTiltAt(t);
      tiltCur += (tgt - tiltCur) * Math.min(1, d * (st.k === "rinse" ? 2.2 : 3.2));
      if (Math.abs(tgt - tiltCur) < 1e-4) tiltCur = tgt;
      if (slide && slide.setTilt) slide.setTilt(tiltCur);

      if (st.k === "stain" && st.a && st.a.indexOf("bottle:") === 0) {
        const rid = st.a.slice(7);
        if (!poured && t >= win.from) {
          poured = true;
          lastStain = rid;
          if (pour && pour.startPour) pour.startPour(rid, (deps.route ? deps.route(rid) : null) || {});
        }
        if (poured && chem.applyReagent) chem.applyReagent(rid, d, coverageAt(t - win.from));
      } else if (st.k === "rinse") {
        if (!rinseOn && t >= RINSE.arriveAt) {
          rinseOn = true;
          const tapRef = deps.tap ? deps.tap() : null;
          /* continuous flow while rinsing, whatever mode the tap was left in */
          if (rinse && rinse.streamMode) rinse.streamMode(tapRef, true);
          if (rinse && rinse.start) {
            rinse.start({ tapRef: tapRef, slide: slide, reagentId: lastStain });
          }
        }
        if (rinseOn && chem.rinse) chem.rinse(d);
      }

      /* push one chemistry snapshot into every renderer */
      const snap = chem.snapshot ? chem.snapshot() : null;
      if (snap) {
        if (slide && slide.setPopulations) slide.setPopulations(snap);
        if (slide && slide.setWetness && chem.getDamp) slide.setWetness(chem.getDamp());
        if (pour && pour.setFilm) pour.setFilm(snap);
        if (rinse && rinse.setFilmState) rinse.setFilmState(snap);
      }
      if (pour && pour.tick) pour.tick(d);
      if (rinse && rinse.tick) rinse.tick(d);
    },
    getSnapshot: function () { return chem && chem.snapshot ? chem.snapshot() : null; },
    getLastStain: function () { return lastStain; },
    getStep: function () { return idx; },
    isRinsing: function () { return rinseOn; },
  };
}
