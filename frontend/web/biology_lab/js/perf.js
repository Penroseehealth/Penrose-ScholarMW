'use strict';

/* Phase 8b: performance + reliability monitor - pure bookkeeping the host
   feeds frame timings into. Owns: fps/frame-time sampling with p95, an
   auto quality tier (high/medium/low) with hysteresis, per-system update
   budgets (reduced update rates when beneficial), an add/remove listener
   registry that detects leaks, a single-animation-loop guard, a coalescing
   outbound bridge queue for Flutter messages, and a retrying asset queue
   for progressive loading. No DOM, no THREE. */

var TIERS = ['high', 'medium', 'low'];

function createPerf(opts) {
  opts = opts || {};
  var state = {
    tier: opts.tier || 'high',
    frames: 0,
    fps: 60,
    frameMsAvg: 16.7,
    frameMsP95: 22,
    tierSince: 0,
    loops: 0,                 /* animation-loop guard (duplicate loop detector) */
    listeners: {},            /* bucket -> {add, remove} */
    disposed: 0,
    assetsLoaded: 0,
    assetReuses: 0,
    retries: 0,
    bridgeSent: 0,
    bridgeDropped: 0,
    bridgeQueue: 0,
  };
  var samples = [];           /* recent frame times (ms), capped */
  var MAX_SAMPLES = opts.maxSamples == null ? 90 : opts.maxSamples;
  var HYST = opts.hysteresis == null ? 2.0 : opts.hysteresis;   /* seconds in tier before switching */
  var pendingSince = null, pendingTier = null;
  var budgets = { students: opts.studentHz == null ? 10 : opts.studentHz,
    behaviour: opts.behaviourHz == null ? 20 : opts.behaviourHz,
    env: opts.envHz == null ? 30 : opts.envHz };
  var lastRun = {};
  var queue = [];
  var BRIDGE_CAP = opts.bridgeCap == null ? 32 : opts.bridgeCap;

  function pct(arr, p) {
    if (!arr.length) return 0;
    var s = arr.slice().sort(function (a, b) { return a - b; });
    var i = Math.min(s.length - 1, Math.max(0, Math.ceil(p / 100 * s.length) - 1));
    return s[i];
  }
  function mean(arr) {
    if (!arr.length) return 0;
    var t = 0; for (var i = 0; i < arr.length; i++) t += arr[i];
    return t / arr.length;
  }

  /* frame timings in milliseconds */
  function sample(dtMs) {
    if (!(dtMs > 0)) return state;
    samples.push(dtMs);
    if (samples.length > MAX_SAMPLES) samples.shift();
    state.frames++;
    state.frameMsAvg = +mean(samples).toFixed(2);
    state.frameMsP95 = +pct(samples, 95).toFixed(2);
    state.fps = +(1000 / (state.frameMsAvg || 16.7)).toFixed(1);
    autoTier(state.frames / 60);
    return state;
  }

  function autoTier(seconds) {
    var want = state.tier;
    if (state.frameMsAvg < 20) want = 'high';
    else if (state.frameMsAvg < 34) want = 'medium';
    else want = 'low';
    if (want === state.tier) { pendingTier = null; pendingSince = null; return state.tier; }
    if (pendingTier !== want) { pendingTier = want; pendingSince = seconds; return state.tier; }
    if (seconds - pendingSince >= HYST) {
      state.tier = want; state.tierSince = seconds;
      pendingTier = null; pendingSince = null;
    }
    return state.tier;
  }

  /* reduced update rates: true when `name` may run on this tick */
  function shouldRun(name, seconds) {
    var hz = budgets[name] || 30;
    if (state.tier === 'low') hz = Math.min(hz, name === 'env' ? 15 : 8);
    else if (state.tier === 'medium') hz = Math.min(hz, name === 'env' ? 24 : 12);
    var last = lastRun[name] || 0;
    if (seconds - last >= 1 / hz - 1e-6) { lastRun[name] = seconds; return true; }
    return false;
  }
  function setBudget(name, hz) { budgets[name] = hz; return budgets; }

  /* single animation-loop guard: every requestAnimationFrame chain must call
     startLoop() exactly once; a second start before stopLoop is a defect */
  function startLoop() {
    state.loops++;
    return state.loops;
  }
  function stopLoop() { state.loops = Math.max(0, state.loops - 1); return state.loops; }

  /* listener registry - balanced add/remove proves no leaked handlers */
  function addListener(bucket) { var b = state.listeners[bucket] || (state.listeners[bucket] = { add: 0, remove: 0 }); b.add++; return b.add; }
  function removeListener(bucket) { var b = state.listeners[bucket] || (state.listeners[bucket] = { add: 0, remove: 0 }); b.remove++; return b.remove; }
  function listenerBuckets() { return state.listeners; }
  function listenersBalanced() {
    for (var k in state.listeners) {
      var b = state.listeners[k];
      if (b.add !== b.remove) return false;
    }
    return true;
  }

  /* progressive asset queue: host drains one task per drain() when idle */
  function enqueue(task) { queue.push({ task: task, tries: 0 }); return queue.length; }
  function drain(runner) {
    var item = queue.shift();
    if (!item) return null;
    try {
      runner(item.task);
      state.assetsLoaded++;
      return item.task;
    } catch (e) {
      item.tries++;
      state.retries++;
      if (item.tries < 3) queue.push(item);   /* retry later, max 3 attempts */
      return { failed: true, error: String((e && e.message) || e), task: item.task };
    }
  }
  function noteReuse() { state.assetReuses++; }

  /* Flutter bridge: coalesce + cap so bursts never flood the channel */
  var _pending = [];
  function bridgePost(msg) {
    _pending.push(msg);
    state.bridgeQueue = _pending.length;
    if (_pending.length > BRIDGE_CAP) { _pending.shift(); state.bridgeDropped++; state.bridgeQueue = _pending.length; }
    return _pending.length;
  }
  function bridgePending() { return _pending; }
  function bridgeFlush(send, maxPerFlush) {
    maxPerFlush = maxPerFlush || 4;
    var sent = 0;
    while (_pending.length && sent < maxPerFlush) {
      send(_pending.shift());
      state.bridgeSent++; sent++;
    }
    state.bridgeQueue = _pending.length;
    return sent;
  }

  function snapshot() {
    return { tier: state.tier, fps: state.fps, frameMsAvg: state.frameMsAvg,
      frameMsP95: state.frameMsP95, frames: state.frames, loops: state.loops,
      budgets: budgets, retries: state.retries, assetsLoaded: state.assetsLoaded,
      assetReuses: state.assetReuses, bridgeSent: state.bridgeSent,
      bridgeDropped: state.bridgeDropped, queue: queue.length,
      listeners: listenerBuckets(), listenersBalanced: listenersBalanced() };
  }

  return {
    state: state,
    TIERS: TIERS,
    sample: sample,
    shouldRun: shouldRun,
    setBudget: setBudget,
    startLoop: startLoop,
    stopLoop: stopLoop,
    addListener: addListener,
    removeListener: removeListener,
    listenerBuckets: listenerBuckets,
    listenersBalanced: listenersBalanced,
    enqueue: enqueue,
    drain: drain,
    noteReuse: noteReuse,
    bridgePost: bridgePost,
    bridgeFlush: bridgeFlush,
    bridgePending: bridgePending,
    snapshot: snapshot,
  };
}

export { createPerf, TIERS };
