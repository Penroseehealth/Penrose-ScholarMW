'use strict';

/* Phase 8a: camera rig - viewpoint modes layered on top of the existing
   orbit controls (which remain the "free inspection" mode, untouched).
   Pure state + tween math; the host feeds it context providers (student
   seats, teacher pose, equipment and eyepiece points) and writes the
   returned view into the scene camera. Transitions are time-bounded with
   an angular-speed cap so a mode switch never whips the view around
   (CSV acceptance: camera changes are smooth and do not disorient). */

var CAM_MODES = ['orbit', 'student', 'follow', 'closeup', 'eyepiece', 'demo'];

function wrapPi(a) {
  while (a > Math.PI) a -= Math.PI * 2;
  while (a < -Math.PI) a += Math.PI * 2;
  return a;
}
function easeInOut(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }
function lerp(a, b, t) { return a + (b - a) * t; }

/* spherical offset from a target to an eye position (r, phi, theta) */
function lookFrom(eye, target) {
  var dx = eye.x - target.x, dy = eye.y - target.y, dz = eye.z - target.z;
  var r = Math.sqrt(dx * dx + dy * dy + dz * dz) || 1e-4;
  var phi = Math.acos(Math.max(-1, Math.min(1, dy / r)));
  var theta = Math.atan2(dx, dz);
  return { r: r, phi: phi, theta: theta };
}

function createCameraRig(opts) {
  opts = opts || {};
  var DEFAULT_FOV = opts.fov == null ? 50 : opts.fov;
  var MAX_RAD_PER_SEC = opts.maxRadPerSec == null ? 2.0 : opts.maxRadPerSec;
  var MIN_DUR = opts.minDuration == null ? 0.55 : opts.minDuration;
  var MAX_DUR = opts.maxDuration == null ? 2.6 : opts.maxDuration;

  var ctx = {
    /* all optional; a missing provider falls back to the orbit view */
    orbit: opts.orbit || function () { return null; },
    seat: opts.seat || function () { return null; },
    studentEye: opts.studentEye || function () { return null; },
    teacher: opts.teacher || function () { return null; },
    equip: opts.equip || function () { return null; },
    eyepiece: opts.eyepiece || function () { return null; },
    demoPoint: opts.demoPoint || function () { return null; },
  };

  var state = {
    mode: 'orbit',
    selected: null,
    fov: DEFAULT_FOV,
    transitioning: false,
    transitions: [],
    demo: { steps: [], i: -1, playing: false, paused: false, wait: 0, waitTarget: 0 },
  };
  var tw = null;               /* active tween {from,to,t,dur} */
  var view = null;             /* latest computed view {target,theta,phi,r,fov} */
  var lastTick = null;

  function current() { return view || ctx.orbit() || { target: { x: 0, y: 1, z: 0 }, theta: 0.55, phi: 1.32, r: 4.4, fov: DEFAULT_FOV }; }

  function snapshot() {
    var v = current();
    return { target: { x: v.target.x, y: v.target.y, z: v.target.z },
      theta: v.theta, phi: v.phi, r: v.r, fov: v.fov == null ? DEFAULT_FOV : v.fov };
  }

  /* per-mode destination; returns null when its provider is unavailable */
  function goalFor(mode, id) {
    if (mode === 'orbit') { var o = ctx.orbit(); if (o) return { target: { x: o.target.x, y: o.target.y, z: o.target.z }, theta: o.theta, phi: o.phi, r: o.r, fov: DEFAULT_FOV }; return null; }
    if (mode === 'student') {
      var eye = ctx.studentEye(id) || ctx.seat(id);
      if (!eye) return null;
      var look = ctx.demoPoint('bench') || { x: 0, y: 1.0, z: -2.2 };
      var sph = lookFrom({ x: eye.x, y: eye.y, z: eye.z }, look);
      /* eye the camera; target sits just in front of the face */
      return { target: { x: lerp(eye.x, look.x, 0.12), y: lerp(eye.y, look.y, 0.12), z: lerp(eye.z, look.z, 0.12) },
        theta: sph.theta, phi: Math.min(1.5, sph.phi), r: Math.max(1.4, sph.r * 0.9), fov: DEFAULT_FOV };
    }
    if (mode === 'follow') {
      var tp = ctx.teacher();
      if (!tp) return null;
      var yaw = tp.yaw == null ? 0 : tp.yaw;
      var behind = 2.4;
      return { target: { x: tp.x, y: 1.15, z: tp.z },
        theta: yaw + Math.PI, phi: 1.22, r: behind, fov: DEFAULT_FOV };
    }
    if (mode === 'closeup') {
      var ep = ctx.equip(id || state.selected);
      if (!ep) return null;
      return { target: { x: ep.x, y: ep.y, z: ep.z }, theta: 0.7, phi: 1.15, r: 0.85, fov: 38 };
    }
    if (mode === 'eyepiece') {
      var ee = ctx.eyepiece();
      if (!ee) return null;
      var sphE = lookFrom(ee.pos, ee.look);
      return { target: { x: ee.look.x, y: ee.look.y, z: ee.look.z },
        theta: sphE.theta, phi: sphE.phi, r: Math.max(0.12, sphE.r), fov: opts.eyepieceFov == null ? 26 : opts.eyepieceFov };
    }
    if (mode === 'demo') {
      var st = state.demo.steps[state.demo.i];
      if (!st) return null;
      if (st.view) return st.view;
      return goalFor(st.mode || 'closeup', st.id);
    }
    return null;
  }

  function logTransition(from, to) {
    state.transitions.push({ from: from, to: to, at: Date.now() });
    if (state.transitions.length > 50) state.transitions.shift();
  }

  /* start a tween to a destination; duration grows with angular travel so
     the view never spins faster than MAX_RAD_PER_SEC (anti-disorientation) */
  function startTween(to) {
    var from = snapshot();
    var dTheta = Math.abs(wrapPi(to.theta - from.theta));
    var dPhi = Math.abs(to.phi - from.phi);
    var ang = Math.max(dTheta, dPhi);
    /* easeInOut (cubic) peaks at 3.0x the average rate: scale duration so the
       peak angular speed stays under MAX_RAD_PER_SEC (anti-disorientation) */
    var dur = Math.max(MIN_DUR, Math.min(MAX_DUR, Math.max(ang * 3.0 / MAX_RAD_PER_SEC, 0.35)));
    tw = { from: from, to: to, t: 0, dur: dur, maxAngPerSec: ang / dur };
    state.transitioning = true;
    return dur;
  }

  function setView(mode, id, opts2) {
    if (CAM_MODES.indexOf(mode) < 0) return false;
    opts2 = opts2 || {};
    var to = goalFor(mode, id);
    if (!to) return false;
    var from = state.mode;
    state.mode = mode;
    if (mode === 'closeup' && id) state.selected = id;
    if (mode !== 'demo') { state.demo.playing = false; state.demo.paused = false; }
    logTransition(from, mode);
    if (opts2.instant) { view = to; tw = null; state.transitioning = false; state.fov = to.fov; return true; }
    startTween(to);
    return true;
  }

  function tick(dt) {
    dt = dt == null ? 0.016 : dt;
    if (!view) view = current();
    /* follow mode re-aims continuously (small corrections, no tween) */
    if (state.mode === 'follow' && !tw) {
      var g = goalFor('follow');
      if (g) {
        var c = current();
        var k = Math.min(1, dt * 4);
        view = { target: { x: lerp(c.target.x, g.target.x, k), y: lerp(c.target.y, g.target.y, k), z: lerp(c.target.z, g.target.z, k) },
          theta: c.theta + wrapPi(g.theta - c.theta) * k,
          phi: lerp(c.phi, g.phi, k), r: lerp(c.r, g.r, k), fov: c.fov };
        return view;
      }
    }
    if (tw) {
      tw.t += dt;
      var u = Math.min(1, tw.t / tw.dur);
      var e = easeInOut(u);
      view = {
        target: { x: lerp(tw.from.target.x, tw.to.target.x, e), y: lerp(tw.from.target.y, tw.to.target.y, e), z: lerp(tw.from.target.z, tw.to.target.z, e) },
        theta: tw.from.theta + wrapPi(tw.to.theta - tw.from.theta) * e,
        phi: lerp(tw.from.phi, tw.to.phi, e),
        r: lerp(tw.from.r, tw.to.r, e),
        fov: lerp(tw.from.fov, tw.to.fov, e),
      };
      state.fov = view.fov;
      if (u >= 1) { tw = null; state.transitioning = false; }
      lastTick = { angPerSec: tw ? Math.abs(wrapPi(tw.to.theta - tw.from.theta)) / tw.dur : 0 };
      return view;
    }
    return view;
  }

  /* ---------- step-by-step demonstration (pause / resume / replay) ---------- */
  function demoSet(steps) {
    state.demo.steps = (steps || []).slice();
    state.demo.i = state.demo.steps.length ? 0 : -1;
    state.demo.playing = false; state.demo.paused = false; state.demo.wait = 0;
    return state.demo.steps.length;
  }
  function demoApply() {
    var ok = setView('demo');
    if (ok) state.demo.waitTarget = state.demo.steps[state.demo.i].hold == null ? 2.0 : state.demo.steps[state.demo.i].hold;
    state.demo.wait = 0;
    return ok;
  }
  function demoNext() {
    if (state.demo.i < 0 || !state.demo.steps.length) return false;
    if (state.demo.i >= state.demo.steps.length - 1) { state.demo.playing = false; return false; }
    state.demo.i++; return demoApply();
  }
  function demoPrev() {
    if (state.demo.i <= 0) return false;
    state.demo.i--; return demoApply();
  }
  function demoPlay() { if (!state.demo.steps.length) return false; if (state.demo.i < 0) state.demo.i = 0; state.demo.playing = true; state.demo.paused = false; return demoApply(); }
  function demoPause() { state.demo.paused = true; return state.demo.playing; }
  function demoResume() { if (!state.demo.playing) return false; state.demo.paused = false; return true; }
  function demoReplay() { state.demo.i = 0; return demoPlay(); }
  function demoFrame(dt) {
    if (!state.demo.playing || state.demo.paused) return;
    if (tw) return;                       /* wait for the current glide */
    state.demo.wait += dt;
    if (state.demo.wait >= state.demo.waitTarget) {
      if (!demoNext()) state.demo.playing = false;
    }
  }

  function status() {
    return { mode: state.mode, selected: state.selected, transitioning: state.transitioning,
      fov: +state.fov.toFixed(1), demoI: state.demo.i, demoLen: state.demo.steps.length,
      demoPlaying: state.demo.playing, demoPaused: state.demo.paused,
      transitions: state.transitions.length };
  }

  return {
    state: state,
    CAM_MODES: CAM_MODES,
    setView: setView,
    tick: tick,
    demoFrame: demoFrame,
    demoSet: demoSet,
    demoNext: demoNext,
    demoPrev: demoPrev,
    demoPlay: demoPlay,
    demoPause: demoPause,
    demoResume: demoResume,
    demoReplay: demoReplay,
    status: status,
    view: function () { return view; },
    wrapPi: wrapPi,
    easeInOut: easeInOut,
    lookFrom: lookFrom,
  };
}

export { createCameraRig, CAM_MODES, wrapPi, easeInOut, lookFrom };
