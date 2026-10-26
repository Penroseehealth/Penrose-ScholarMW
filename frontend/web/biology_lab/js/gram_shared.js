/* Gram-staining shared foundation: the THREE-free domain layer for the 3D Gram
   practical, shared by the slide, pour, rinse and choreography streams.

   This module must stay importable from plain Node — it must NOT depend on
   the Three.js library — so the *_model.js files and the scripts/gram_*_unit.mjs
   share the reagent table, geometry, colour maths and chemistry state machine.
   Rendering modules receive every scene object via their options and must keep
   the GRAM_CONTRACT signatures pinned below; the makeStub* factories let one
   stream unit-test against another stream's interface before its renderer
   exists. */

/* ---------------- small helpers ---------------- */

export function clamp01(v) {
  const n = Number(v);
  if (!Number.isFinite(n)) return 0;
  return n < 0 ? 0 : (n > 1 ? 1 : n);
}

export function degToRad(d) {
  const n = Number(d);
  return (Number.isFinite(n) ? n : 0) * Math.PI / 180;
}

export function radToDeg(r) {
  const n = Number(r);
  return (Number.isFinite(n) ? n : 0) * 180 / Math.PI;
}

/* ---------------- colour constants ---------------- */

/** Fully colourless endpoint every fade/runoff converges toward. */
export const COLOURLESS = 0xffffff;

/** Crystal violet–iodine complex: the deep purple both populations hold after
    the mordant step (matches the iodine step colour in index.html). */
export const CV_COMPLEX = 0x3b1a66;

/* ---------------- reagents ---------------- */
/* Per-reagent constants the renderers and the chemistry share:
   filmOpacity  — target opacity of the retained film layer on the slide;
   pourDuration — seconds of visible pour at speed 1 (streams may scale);
   fade         — per-second rate at which this reagent's film washes off;
   stainRate    — per-second chemistry approach rate at full coverage (the
                  decolouriser is slow: gram-negative decolourising runs 5-15s). */

export const REAGENTS = {
  cv: { id: "cv", name: "Crystal violet", colour: 0x6a2fa0, role: "primary",
    filmOpacity: 0.88, pourDuration: 2.4, fade: 1.2, stainRate: 2.6 },
  io: { id: "io", name: "Gram's iodine", colour: 0x8a5a1f, role: "mordant",
    filmOpacity: 0.7, pourDuration: 2.2, fade: 1.4, stainRate: 1.8 },
  de: { id: "de", name: "Decolouriser", colour: 0xffffff, role: "decolouriser",
    filmOpacity: 0.22, pourDuration: 3.0, fade: 2.0, stainRate: 0.8 },
  sa: { id: "sa", name: "Safranin", colour: 0xe0457b, role: "counterstain",
    filmOpacity: 0.75, pourDuration: 2.0, fade: 1.5, stainRate: 2.0 },
  sl: { id: "sl", name: "Normal saline", colour: 0xcfe6f4, role: "rinse",
    filmOpacity: 0.3, pourDuration: 1.8, fade: 2.2, stainRate: 0 },
  water: { id: "water", name: "Tap water", colour: 0xcbe7f3, role: "rinse",
    filmOpacity: 0.3, pourDuration: 1.6, fade: 2.6, stainRate: 0 },
};

/* ---------------- geometry, poses and budgets ---------------- */

export const GRAM_GEOMETRY = {
  /* slide footprint in scene units (x, y, z) — matches the current slide box */
  slide: { x: 0.026, y: 0.003, z: 0.1 },
  /* workstation poses (index.html: rack anchor on the tray; the resting slide
     sits 0.0445 higher on the rack rails — integration keeps gRackPos) */
  rackPose: { x: -5.425, y: 0.92, z: 0.18 },
  sinkPose: { x: -5.62, y: 0.955, z: -0.6 },
  warmPose: { x: -5.511, y: 1.03, z: -0.19 },
  scopePose: { x: 0.45, y: 0.93, z: -2.6 },
  /* rinse/drain working band: the slide tilts 25-45 deg over the sink basin */
  tilt: { minDeg: 25, maxDeg: 45, minRad: degToRad(25), maxRad: degToRad(45) },
  /* radii of the liquid columns (tap values match the lab's streamGeo/coreGeo) */
  streamRadii: {
    tapOuter: 0.0075,
    tapCore: 0.0028,
    tapDrop: 0.0032,
    pour: 0.004,
    pourDrop: 0.0026,
    runoff: 0.005,
    impactRing: 0.016,
  },
  /* perf budgets shared by every Gram renderer */
  budgets: { maxAddedMeshes: 45, maxTexturePx: 512, maxRepaintHz: 20 },
};

/* ---------------- hex colour maths ---------------- */

/** Channel-linear interpolation of two 0xRRGGBB colours; t is clamped to
    [0,1] and each channel steps toward its target endpoint (ceil when rising,
    floor when falling) so repeated small fades converge on the endpoint
    exactly instead of stalling on rounding. */
export function mixHex(a, b, t) {
  const k = clamp01(t);
  let out = 0;
  for (let s = 16; s >= 0; s -= 8) {
    const c0 = (a >> s) & 255;
    const c1 = (b >> s) & 255;
    let v;
    if (c0 === c1) {
      v = c0;
    } else {
      v = c1 > c0 ? Math.ceil(c0 + (c1 - c0) * k) : Math.floor(c0 + (c1 - c0) * k);
    }
    out |= v << s;
  }
  return out;
}

/** Reading alias of {@link mixHex} for interpolation call sites. */
export function lerpHex(a, b, t) {
  return mixHex(a, b, t);
}

/** Fade a colour toward colourless: fadeHex(c, 0) === c, fadeHex(c, 1) === white. */
export function fadeHex(hex, amount) {
  return mixHex(hex, COLOURLESS, amount);
}

/* Exponential runoff fade: one dt-step of dilution moves the film colour
   toward colourless without ever overshooting or teleporting (per-call change
   is bounded, dt and dilution are clamped, and a half-life is the most a single
   call may move). Monotonic: channels only ever rise toward 255. */
const RUNOFF_FADE = 1.6;

export function runoffColour(filmColour, dilution, dt) {
  const dn = Number(dilution);
  const d = Number.isFinite(dn) ? Math.min(Math.max(dn, 0), 4) : 0;
  const step = Math.max(0, Math.min(0.5, Number(dt) || 0));
  const k = RUNOFF_FADE * d * step;
  if (!(k > 0)) return filmColour >>> 0 & 0xffffff;
  return mixHex(filmColour, COLOURLESS, Math.min(1 - Math.exp(-k), 0.5));
}

/* ---------------- chemistry state machine ---------------- */

const FILM_RATE = 3.0;      /* film wetting, per second at full coverage */
const RINSE_RATE = 2.0;     /* film wash-off while water runs */
const DAMP_RATE = 1.5;      /* slide wets while reagents/water sit on it */
const SA_TINT = 0.06;       /* faint pink cast the counterstain leaves on Gram+ */
const NEG_REST_ALPHA = 0.12;    /* decolourised ghosts of gram-negative cells */
const NEG_COUNTER_ALPHA = 0.85; /* safranin-loaded gram-negative cells */

function approachHex(cur, tgt, k) {
  if (!(k > 0)) return cur >>> 0 & 0xffffff;
  return mixHex(cur, tgt, k >= 9 ? 1 : 1 - Math.exp(-k));
}

function approach01(cur, tgt, k) {
  if (!(k > 0)) return cur;
  const v = cur + (tgt - cur) * (k >= 9 ? 1 : 1 - Math.exp(-k));
  return Math.abs(tgt - v) < 1e-3 ? tgt : v;
}

/* True when a cell colour still carries crystal violet (used so the mordant
   only deepens stained cells and the counterstain never re-pinks purple ones). */
function holdsCrystalViolet(colour) {
  const r = (colour >> 16) & 255;
  const g = (colour >> 8) & 255;
  const b = colour & 255;
  return b >= r && b > g + 12 && r > g + 8;
}

/**
 * Chemistry state machine for the Gram stain. Populations:
 *   gramPos — retains crystal violet through decolourisation, keeps deep purple;
 *   gramNeg — loses crystal violet when decolourised, then takes up safranin.
 * Transitions are exponential (per-tick bounded, no pops) and snap to their
 * exact targets once within rendering resolution.
 *
 * @returns {{
 *   applyReagent: (id: string, dt: number, coverage?: number) => boolean,
 *   rinse: (dt: number) => void,
 *   setDamp: (w: number) => void,
 *   getDamp: () => number,
 *   snapshot: () => {pos:{colour:number,alpha:number}, neg:{colour:number,alpha:number}, film:{colour:number,alpha:number}}
 * }}
 */
export function createStainState() {
  const st = {
    pos: { colour: COLOURLESS, alpha: 0 },
    neg: { colour: COLOURLESS, alpha: 0 },
    film: { colour: COLOURLESS, alpha: 0 },
    filmId: null,
    damp: 0,
  };

  function settleFilm() {
    st.film.alpha = 0;
    st.film.colour = COLOURLESS;
    st.filmId = null;
  }

  function applyReagent(id, dt, coverage) {
    const r = REAGENTS[id];
    if (!r) return false;
    if (!(dt > 0)) return true;
    const cov = clamp01(coverage === undefined || coverage === null ? 1 : coverage);
    if (cov <= 0) return true;
    const k = dt * cov;

    if (r.role === "primary") {
      st.pos.colour = approachHex(st.pos.colour, r.colour, r.stainRate * k);
      st.pos.alpha = approach01(st.pos.alpha, 1, r.stainRate * k);
      st.neg.colour = approachHex(st.neg.colour, r.colour, r.stainRate * k);
      st.neg.alpha = approach01(st.neg.alpha, 1, r.stainRate * k);
    } else if (r.role === "mordant") {
      /* iodine complexes only the dye already inside the cells */
      if (st.pos.alpha > 0.01 && holdsCrystalViolet(st.pos.colour)) {
        st.pos.colour = approachHex(st.pos.colour, CV_COMPLEX, r.stainRate * k);
        st.pos.alpha = approach01(st.pos.alpha, 1, r.stainRate * k);
      }
      if (st.neg.alpha > 0.01 && holdsCrystalViolet(st.neg.colour)) {
        st.neg.colour = approachHex(st.neg.colour, CV_COMPLEX, r.stainRate * k);
        st.neg.alpha = approach01(st.neg.alpha, 1, r.stainRate * k);
      }
    } else if (r.role === "decolouriser") {
      /* gram-positive walls trap the dye: gramPos is deliberately untouched.
         No colour guard here — the fade must be allowed to run all the way to
         colourless (a guard on "still violet" would cut off mid-way). */
      if (st.neg.alpha > 0.05) {
        st.neg.colour = approachHex(st.neg.colour, COLOURLESS, r.stainRate * k);
        st.neg.alpha = approach01(st.neg.alpha, NEG_REST_ALPHA, r.stainRate * k);
      }
    } else if (r.role === "counterstain") {
      if (st.neg.alpha > 0.05 && !holdsCrystalViolet(st.neg.colour)) {
        st.neg.colour = approachHex(st.neg.colour, r.colour, r.stainRate * k);
        st.neg.alpha = approach01(st.neg.alpha, NEG_COUNTER_ALPHA, r.stainRate * k);
      }
      if (st.pos.alpha > 0.05) {
        st.pos.colour = approachHex(st.pos.colour, mixHex(CV_COMPLEX, r.colour, SA_TINT), r.stainRate * k);
        st.pos.alpha = approach01(st.pos.alpha, 1, r.stainRate * k);
      }
    }

    if (r.role === "rinse") {
      if (st.film.alpha > 0) {
        st.film.alpha = approach01(st.film.alpha, 0, r.fade * k);
        if (st.film.alpha < 0.005) settleFilm();
        else st.film.colour = runoffColour(st.film.colour, 1, k);
      }
    } else {
      st.film.colour = approachHex(st.film.colour, r.colour, FILM_RATE * k);
      st.film.alpha = approach01(st.film.alpha, r.filmOpacity, FILM_RATE * k);
      st.filmId = r.id;
    }
    st.damp = approach01(st.damp, 1, DAMP_RATE * k);
    return true;
  }

  function rinse(dt) {
    if (!(dt > 0)) return;
    if (st.film.alpha > 0) {
      st.film.alpha = approach01(st.film.alpha, 0, RINSE_RATE * dt);
      if (st.film.alpha < 0.005) settleFilm();
      else st.film.colour = runoffColour(st.film.colour, 1, dt);
    }
    st.damp = approach01(st.damp, 1, DAMP_RATE * dt);
  }

  function setDamp(w) {
    st.damp = clamp01(w);
  }

  function getDamp() {
    return st.damp;
  }

  function snapshot() {
    return {
      pos: { colour: st.pos.colour, alpha: st.pos.alpha },
      neg: { colour: st.neg.colour, alpha: st.neg.alpha },
      film: { colour: st.film.colour, alpha: st.film.alpha },
    };
  }

  return { applyReagent, rinse, setDamp, getDamp, snapshot };
}

/* ---------------- frozen stream contract ---------------- */

/**
 * Plain {x,y,z} position, THREE-free.
 * @typedef {{x:number, y:number, z:number}} GramVec3
 */

/**
 * Stain snapshot shared by the chemistry and every renderer.
 * @typedef {Object} GramStainSnapshot
 * @property {{colour:number, alpha:number}} pos  gram-positive population
 * @property {{colour:number, alpha:number}} neg  gram-negative population
 * @property {{colour:number, alpha:number}} film retained reagent film
 */

/**
 * @typedef {Object} GramSlideApi
 * @property {Object|null} group                scene root (THREE.Group in the browser)
 * @property {function(GramStainSnapshot): void} setPopulations
 * @property {function(number): void} setTilt    tilt in radians (bounded by GRAM_GEOMETRY.tilt)
 * @property {function(number): void} setWetness wetness 0..1
 * @property {function(): GramVec3} getImpactPoint centre of the upper smear face
 * @property {function(): GramVec3} getLowEdge    dipped long edge during a tilt
 */

/**
 * @typedef {Object} GramRoute
 * @property {GramVec3} [from]  bottle-tip world position the ribbon starts at
 * @property {GramVec3} [to]    slide impact point the ribbon strikes
 * @property {function(): void} [onDone] fired once when the pour finishes
 */

/**
 * @typedef {Object} GramPourApi
 * @property {function(string, GramRoute): void} startPour
 * @property {function(number): void} tick
 * @property {function(GramStainSnapshot): void} setFilm
 * @property {function(): void} clear
 */

/**
 * @typedef {Object} GramRinseApi
 * @property {function({tapRef:*, slide:*, reagentId:string}): void} start
 * @property {function(): void} stop
 * @property {function(number): void} tick
 * @property {function(*, boolean): void} streamMode force/restore tap.mode='stream'
 */

/**
 * @typedef {Object} GramStep  one GP_STEPS entry passed in by the integration
 * @property {string} n  short name
 * @property {string} k  kind: 'flame' | 'stain' | 'rinse' | 'none'
 * @property {string} a  action, e.g. 'bottle:cv' | 'tap' | 'slide' | 'micro'
 * @property {number} [color]
 */

/**
 * @typedef {Object} GramChoreoApi
 * @property {function(number, Array<GramStep>): void} setStep
 * @property {function(number): void} tick
 */

/**
 * Frozen factory signatures every stream module must export verbatim.
 * @type {{createGramSlide: string, createGramPour: string, createGramRinse: string, createGramChoreo: string}}
 */
export const GRAM_CONTRACT = {
  createGramSlide: "createGramSlide(opts) -> { group, setPopulations(state), setTilt(rad), setWetness(w), getImpactPoint(), getLowEdge() }",
  createGramPour: "createGramPour(opts) -> { startPour(reagentId, {from, to, onDone}), tick(dt), setFilm(state), clear() }",
  createGramRinse: "createGramRinse(opts) -> { start({tapRef, slide, reagentId}), stop(), tick(dt), streamMode(tapRef, on) }",
  createGramChoreo: "createGramChoreo({slide, pour, rinse, steps, chem}) -> { setStep(i, steps), tick(dt) }",
};

/* Tilt clamp for renderers: bounds magnitude to the 45 deg maximum so a slide
   may also lie flat (0 rad) at the rack; rinse schedules stay inside the
   25-45 deg working band (GRAM_GEOMETRY.tilt). */
export function clampTilt(rad) {
  const r = Number.isFinite(rad) ? rad : 0;
  const lim = GRAM_GEOMETRY.tilt.maxRad;
  return Math.min(Math.max(r, -lim), lim);
}

/* ---------------- stub factories ---------------- */
/* Contract-shaped, scene-free stand-ins so a stream's unit test can exercise
   its choreography/integration logic without the other streams' renderers. */

function snapCopy(v) {
  try {
    return JSON.parse(JSON.stringify(v));
  } catch (e) {
    return null;
  }
}

/**
 * @param {{position?: GramVec3, group?: *}} [opts]
 * @returns {GramSlideApi & {calls: Object, getTilt: function(): number, getWetness: function(): number}}
 */
export function makeStubSlide(opts) {
  const o = opts || {};
  const size = GRAM_GEOMETRY.slide;
  const p = o.position || { x: 0, y: 0, z: 0 };
  const pos = { x: Number(p.x) || 0, y: Number(p.y) || 0, z: Number(p.z) || 0 };
  const calls = { populations: [], tilts: [], wets: [] };
  let tilt = 0;
  let wet = 0;

  function rot(dy, dz) {
    const c = Math.cos(tilt);
    const s = Math.sin(tilt);
    return { y: dy * c - dz * s, z: dy * s + dz * c };
  }

  return {
    group: o.group !== undefined ? o.group : null,
    calls: calls,
    setPopulations: function (state) {
      calls.populations.push(snapCopy(state));
    },
    setTilt: function (rad) {
      tilt = clampTilt(rad);
      calls.tilts.push(tilt);
    },
    setWetness: function (w) {
      wet = clamp01(w);
      calls.wets.push(wet);
    },
    getImpactPoint: function () {
      const q = rot(size.y / 2, 0);
      return { x: pos.x, y: pos.y + q.y, z: pos.z + q.z };
    },
    getLowEdge: function () {
      /* positive tilt dips the +z end, negative tilt the -z end */
      const dz = tilt >= 0 ? size.z / 2 : -size.z / 2;
      const q = rot(-size.y / 2, dz);
      return { x: pos.x, y: pos.y + q.y, z: pos.z + q.z };
    },
    getTilt: function () { return tilt; },
    getWetness: function () { return wet; },
  };
}

/**
 * Records pours and fires onDone once REAGENTS[id].pourDuration has ticked by.
 * @param {{speed?: number}} [opts]
 * @returns {GramPourApi & {calls: Object, isPouring: function(): boolean}}
 */
export function makeStubPour(opts) {
  const o = opts || {};
  const speed = o.speed > 0 ? o.speed : 1;
  const calls = { pours: [], films: [], cleared: 0, ticks: 0 };
  let pending = null;

  return {
    calls: calls,
    startPour: function (reagentId, route) {
      const r = route || {};
      const def = REAGENTS[reagentId];
      calls.pours.push({ reagentId: reagentId, from: r.from || null, to: r.to || null });
      pending = {
        reagentId: reagentId,
        t: 0,
        dur: ((def && def.pourDuration) || 2) / speed,
        onDone: typeof r.onDone === "function" ? r.onDone : null,
        done: false,
      };
    },
    tick: function (dt) {
      calls.ticks++;
      if (pending && !pending.done && dt > 0) {
        pending.t += dt;
        if (pending.t >= pending.dur) {
          pending.done = true;
          if (pending.onDone) pending.onDone();
        }
      }
    },
    setFilm: function (state) {
      calls.films.push(snapCopy(state));
    },
    clear: function () {
      calls.cleared++;
      pending = null;
    },
    isPouring: function () {
      return !!pending && !pending.done;
    },
  };
}

/**
 * Records rinse lifecycle calls; streamMode forces tapRef.mode='stream' and
 * restores the previous mode, mirroring what the real renderer must do.
 * @param {Object} [opts]
 * @returns {GramRinseApi & {calls: Object, isRunning: function(): boolean}}
 */
export function makeStubRinse(opts) {
  const o = opts || {};
  const calls = { starts: [], stops: 0, ticks: 0, modes: [], lastDt: 0 };
  let running = !!o.running;

  return {
    calls: calls,
    start: function (args) {
      const a = args || {};
      running = true;
      calls.starts.push({
        tapRef: a.tapRef || null,
        slide: a.slide || null,
        reagentId: a.reagentId || null,
      });
    },
    stop: function () {
      running = false;
      calls.stops++;
    },
    tick: function (dt) {
      calls.ticks++;
      calls.lastDt = dt;
    },
    streamMode: function (tapRef, on) {
      const forced = !!on;
      calls.modes.push({ tapRef: tapRef || null, on: forced });
      if (tapRef && typeof tapRef === "object") {
        if (forced) {
          if (tapRef.mode !== "stream") tapRef.__prevMode = tapRef.mode;
          tapRef.mode = "stream";
        } else if (tapRef.mode === "stream" && tapRef.__prevMode !== undefined) {
          tapRef.mode = tapRef.__prevMode;
          delete tapRef.__prevMode;
        }
      }
    },
    isRunning: function () {
      return running;
    },
  };
}
