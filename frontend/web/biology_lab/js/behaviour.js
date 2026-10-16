/**
 * Teacher behaviour controller (Phase 2) for the biology lab.
 *
 * Hierarchical control, no THREE / no DOM (unit-testable in Node):
 *
 *   Supervisor  — task stack + priority queue + event intake + safe pause/resume
 *   Task        — ordered list of data steps (the "scenarios" are plain arrays)
 *   Step        — one deterministic action, mapped to an explicit CSV state:
 *                 IDLE, OBSERVE, LISTEN, PLAN, NAVIGATE, APPROACH, ALIGN, REACH,
 *                 GRASP, MANIPULATE, CARRY, PLACE, TEACH, SIT, STAND, VERIFY,
 *                 RECOVER
 *
 * Locomotion delegates to the Phase-1 controller (js/teacher_controller.js),
 * which owns NAVIGATE/APPROACH/TURN/RECOVER movement math. Physical object
 * truth lives in the world store (js/objects.js); this module only reads and
 * writes it, so a task can never report success for an action that failed —
 * VERIFY steps check the store before the handle resolves 'completed'.
 *
 * The host supplies an extended rig on top of the Phase-1 surface:
 *   setLook(x,y,z|null)      head/neck toward a point (eased host-side)
 *   setLean(0..1)            torso pitch forward
 *   setReach('L'|'R', pt|null)  arm toward a world point
 *   headWorldPos() -> {x,y,z}
 *   attachToHand(objId,'L'|'R') / detachFromHand(objId,{x,y,z})
 * All are optional; missing methods degrade to state-only behaviour.
 *
 * Public API:
 *   behav.update(dt)                    advance one frame
 *   behav.submit({label,priority,steps,timeout,resolve}) -> handle
 *   behav.emit(evt) / behav.on(type,fn) tiny event bus (host maps to sounds)
 *   behav.state, behav.held, behav.active, behav.transitions, behav.lastResult
 */
"use strict";

var STATES = {
  IDLE: "IDLE",
  OBSERVE: "OBSERVE",
  LISTEN: "LISTEN",
  PLAN: "PLAN",
  NAVIGATE: "NAVIGATE",
  APPROACH: "APPROACH",
  ALIGN: "ALIGN",
  REACH: "REACH",
  GRASP: "GRASP",
  MANIPULATE: "MANIPULATE",
  CARRY: "CARRY",
  PLACE: "PLACE",
  TEACH: "TEACH",
  SIT: "SIT",
  STAND: "STAND",
  VERIFY: "VERIFY",
  RECOVER: "RECOVER",
};

var DEFAULTS = {
  planDur: 0.4,
  recoverDur: 0.4,
  yawRate: 2.4,
  alignTol: 0.05,
  taskTimeout: 120,
  defaultDur: 0.5,
};

function angDelta(a, b) {
  var d = b - a;
  while (d > Math.PI) d -= 2 * Math.PI;
  while (d < -Math.PI) d += 2 * Math.PI;
  return d;
}

function createBehaviour(opts) {
  var cfg = {};
  Object.keys(DEFAULTS).forEach(function (k) {
    cfg[k] = (opts && opts.config && opts.config[k] != null) ? opts.config[k] : DEFAULTS[k];
  });
  var rig = (opts && opts.rig) || {};
  var world = opts && opts.world;
  var loco = opts && opts.loco;

  var behav = {
    state: STATES.IDLE,
    held: null,
    active: null,
    lastResult: null,
    transitions: [],
  };
  var time = 0;
  var taskSeq = 0;
  var paused = [];
  var pending = [];
  var busListeners = {};

  /* ---------- transitions ---------- */
  function logTransition(from, to, why) {
    behav.transitions.push({ t: +time.toFixed(3), from: from, to: to, why: why || "" });
    if (behav.transitions.length > 400) behav.transitions.shift();
  }
  function setState(to, why) {
    if (behav.state === to) return;
    var from = behav.state;
    behav.state = to;
    logTransition(from, to, why);
  }

  /* ---------- bus ---------- */
  behav.on = function (type, fn) {
    (busListeners[type] = busListeners[type] || []).push(fn);
  };
  behav.emit = function (evt) {
    if (!evt || !evt.type) return;
    (busListeners[evt.type] || []).forEach(function (fn) { fn(evt); });
    (busListeners["*"] || []).forEach(function (fn) { fn(evt); });
  };

  /* ---------- rig helpers (all optional) ---------- */
  function rigLook(pt) { if (rig.setLook) rig.setLook(pt); }
  function rigLean(v) { if (rig.setLean) rig.setLean(v || 0); }
  function rigReach(hand, pt) { if (rig.setReach) rig.setReach(hand, pt); }
  function retractArms() {
    if (rig.setReach) { rig.setReach("L", null); rig.setReach("R", null); }
    if (rig.setLook) rig.setLook(null);
    if (rig.setLean) rig.setLean(0);
  }

  function resolveTarget(t) {
    if (!t) return null;
    if (t.obj && world) {
      var p = world.point(t.obj, t.point);
      if (!p) return null;
      return { x: p.x, y: p.y, z: p.z };
    }
    if (t.head && rig.headWorldPos) {
      var hp = rig.headWorldPos();
      return { x: hp.x + (t.head.x || 0), y: hp.y + (t.head.y || 0), z: hp.z + (t.head.z || 0) };
    }
    if (t.x != null && t.z != null) return { x: t.x, y: t.y != null ? t.y : 0, z: t.z };
    return null;
  }

  function resolveLook(s) {
    if (!s) return null;
    var pt = resolveTarget(s.look || s.at || s.to);
    if (pt) return pt;
    if (s.obj && world) return resolveTarget({ obj: s.obj });
    return null;
  }

  /* ---------- task lifecycle ---------- */
  function makeHandle(def) {
    return {
      id: ++taskSeq,
      label: def.label || "",
      priority: def.priority != null ? def.priority : 1,
      steps: def.steps || [],
      timeout: def.timeout != null ? def.timeout : cfg.taskTimeout,
      status: "queued",
      reason: "",
      started: 0,
      resolve: def.resolve || null,
      done: false,
    };
  }

  function resolveHandle(h, status, reason) {
    if (h.done) return;
    h.done = true;
    h.status = status;
    h.reason = reason || "";
    behav.lastResult = { label: h.label, status: status, reason: reason || "", t: +time.toFixed(3) };
    if (h.resolve) h.resolve({ label: h.label, status: status, reason: reason || "" });
  }

  function taskComplete() {
    var h = behav.active.h;
    behav.active = null;
    setState(STATES.IDLE, "task:completed");
    retractArms();
    if (loco && loco.state === "IDLE" && !loco.task) { /* settle */ }
    resolveHandle(h, "completed", "");
    behav.emit({ type: "task:done", label: h.label, status: "completed" });
  }

  function taskFail(reason) {
    var act = behav.active;
    if (!act || act.phase === "recovery") return;
    act.phase = "recovery";
    act.recElapsed = 0;
    setState(STATES.RECOVER, "fail:" + reason);
    retractArms();
    if (loco) loco.stop("recover");
    act.failReason = reason;
  }

  function finishRecovery() {
    var act = behav.active;
    var h = act.h;
    var reason = act.failReason || "failed";
    behav.active = null;
    var status = reason === "timeout" ? "timeout" : reason.indexOf("unreachable") === 0 ? "unreachable" : reason.indexOf("interrupted") === 0 ? "interrupted" : "failed";
    setState(STATES.IDLE, "task:" + status);
    resolveHandle(h, status, reason);
    behav.emit({ type: "task:done", label: h.label, status: status, reason: reason });
  }

  function pauseActive(why) {
    var act = behav.active;
    if (!act) return;
    act.step.stale = true;
    if (act.op && act.op.op === "goto" && loco) loco.stop("paused");
    retractArms();
    paused.push({ handle: act.h, index: act.i });
    act.h.status = "paused";
    behav.active = null;
    setState(STATES.IDLE, "paused:" + why);
  }

  function startHandle(h) {
    h.status = "running";
    h.started = time;
    behav.active = { h: h, i: -1, step: null, op: null, phase: "run", elapsed: 0 };
    if (!h.steps.length) { taskComplete(); return; }
    enterStep(0);
  }

  function nextReady() {
    if (behav.active) return;
    if (paused.length) {
      var p = paused.pop();
      behav.active = { h: p.handle, i: -1, step: null, op: null, phase: "run", elapsed: 0 };
      p.handle.status = "running";
      if (p.index >= p.handle.steps.length) taskComplete();
      else enterStep(p.index);
      return;
    }
    if (pending.length) {
      pending.sort(function (a, b) { return b.priority - a.priority || a.id - b.id; });
      startHandle(pending.shift());
    }
  }

  behav.submit = function (def) {
    var h = makeHandle(def);
    if (behav.active && h.priority > behav.active.h.priority) {
      pauseActive("preempt:" + h.label);
      startHandle(h);
    } else if (behav.active || paused.length) {
      pending.push(h);
    } else {
      startHandle(h);
    }
    return h;
  };

  behav.stop = function (why) {
    if (behav.active) taskFail("interrupted:" + (why || "stop"));
    paused = [];
    pending = [];
  };

  /* ---------- Phase 3: interact via the object action catalogue ----------
     Submit a task built from a world-registered action. Preconditions are
     checked before the task starts; completion conditions run as a VERIFY
     step appended by world.actionSteps, so an action can never report
     success for a state that did not actually change. */
  behav.interact = function (objId, actionName, opts) {
    opts = opts || {};
    if (!world || !world.action) {
      var h0 = makeHandle({ label: objId + ":" + actionName, priority: opts.priority || 1, steps: [] });
      resolveHandle(h0, "failed", "no-world");
      return h0;
    }
    var def = world.action(objId, actionName);
    var label = (opts.label || "") + objId + ":" + actionName;
    if (!def) {
      var h1 = makeHandle({ label: label, priority: opts.priority || 1, steps: [] });
      resolveHandle(h1, "failed", "no-action:" + objId + ":" + actionName);
      return h1;
    }
    if (!world.checkPre(objId, actionName, opts)) {
      var h2 = makeHandle({ label: label, priority: opts.priority || def.priority, steps: [] });
      resolveHandle(h2, "failed", "precondition:" + objId + ":" + actionName);
      behav.emit({ type: "task:done", label: label, status: "failed", reason: "precondition" });
      return h2;
    }
    var steps = world.actionSteps(objId, actionName, opts);
    if (!steps || !steps.length) {
      var h3 = makeHandle({ label: label, priority: opts.priority || def.priority, steps: [] });
      resolveHandle(h3, "failed", "no-steps:" + objId + ":" + actionName);
      return h3;
    }
    return behav.submit({
      label: label,
      priority: opts.priority != null ? opts.priority : def.priority,
      steps: steps,
      timeout: opts.timeout,
      resolve: opts.resolve,
    });
  };

  /* ---------- step execution ---------- */
  function stepDone() {
    var act = behav.active;
    act.step.stale = true;
    if (act.i + 1 >= act.h.steps.length) taskComplete();
    else enterStep(act.i + 1);
  }

  function enterStep(i) {
    var act = behav.active;
    act.i = i;
    var s = act.h.steps[i];
    act.op = s;
    act.elapsed = 0;
    act.step = { elapsed: 0, stale: false, locoTask: null, yawTarget: null };
    act.phase = "run";

    switch (s.op) {
      case "plan":
        setState(STATES.PLAN, "step:plan");
        break;
      case "listen":
        setState(STATES.LISTEN, "step:listen");
        rigLook(resolveLook(s));
        if (s.lean) rigLean(s.lean);
        break;
      case "observe":
        setState(STATES.OBSERVE, "step:observe");
        rigLook(resolveLook(s));
        break;
      case "goto": {
        var to = resolveTarget(s.to) || resolveTarget({ obj: s.toObj });
        if (!to) { taskFail("goto:bad-target"); break; }
        var faceX = s.faceX, faceZ = s.faceZ, faceYaw = s.faceYaw;
        if (s.face != null && typeof s.face === "object") {
          var fp = resolveTarget(s.face);
          if (fp) { faceX = fp.x; faceZ = fp.z; }
        } else if (typeof s.face === "string" && world) {
          var fpt = world.point(s.face);
          if (fpt) { faceX = fpt.x; faceZ = fpt.z; }
        }
        setState(behav.held ? STATES.CARRY : STATES.NAVIGATE, "step:goto");
        var my = act;
        act.step.locoTask = loco.goto(to.x, to.z, {
          standOff: s.standOff != null ? s.standOff : undefined,
          faceYaw: faceYaw, faceX: faceX, faceZ: faceZ,
          timeout: s.timeout,
          label: (act.h.label || "behav") + ":goto",
          resolve: function (r) {
            if (my.step.stale || behav.active !== act) return;
            if (r.status === "arrived") stepDone();
            else if (r.status === "interrupted" || r.status === "timeout") taskFail(r.status === "timeout" ? "timeout" : "interrupted:goto");
            else taskFail("unreachable:" + (s.label || s.op));
          },
        });
        break;
      }
      case "align": {
        var pos = rig.getPos();
        var yt = s.faceYaw;
        if (yt == null && s.face != null) {
          var tp = resolveTarget(s.face);
          if (tp) yt = Math.atan2(tp.x - pos.x, tp.z - pos.z);
        }
        if (yt == null && s.obj && world) {
          var op2 = world.point(s.obj);
          if (op2) yt = Math.atan2(op2.x - pos.x, op2.z - pos.z);
        }
        if (yt == null) { taskFail("align:no-target"); break; }
        setState(STATES.ALIGN, "step:align");
        act.step.yawTarget = yt;
        break;
      }
      case "reach":
        setState(STATES.REACH, "step:reach");
        rigReach(s.hand || "R", resolveTarget(s.to) || resolveTarget({ obj: s.obj }));
        break;
      case "grasp": {
        setState(STATES.GRASP, "step:grasp");
        if (!s.obj) { taskFail("grasp:no-obj"); break; }
        if (!behav.held) {
          if (rig.attachToHand) rig.attachToHand(s.obj, s.hand || "R");
          if (world) world.set(s.obj, { heldBy: s.hand || "R" });
          behav.held = s.obj;
        }
        break;
      }
      case "manipulate":
        setState(STATES.MANIPULATE, "step:manipulate");
        if (s.look !== undefined) rigLook(resolveLook(s));
        if (s.lean != null) rigLean(s.lean);
        if (s.gesture && rig.setGesture) rig.setGesture(s.gesture);
        break;
      case "drawer":
        setState(STATES.MANIPULATE, "step:drawer");
        if (!s.id) { taskFail("drawer:no-id"); break; }
        if (world) world.set(s.id, { open: !!s.open });
        break;
      case "release": {
        setState(STATES.PLACE, "step:release");
        if (!s.obj || behav.held !== s.obj) { taskFail("release:not-held"); break; }
        var at = resolveTarget(s.at) || (world ? world.point(s.obj) : null);
        if (!at) { taskFail("release:no-point"); break; }
        if (rig.detachFromHand) rig.detachFromHand(s.obj, at);
        if (world) { world.move(s.obj, at.x, at.y, at.z); world.set(s.obj, { heldBy: null }); }
        behav.held = null;
        break;
      }
      case "set":
        if (world && s.id) world.set(s.id, s.patch || {});
        stepDone();
        return;
      case "emit":
        behav.emit({ type: s.name, at: s.at || null });
        stepDone();
        return;
      case "verify": {
        setState(STATES.VERIFY, "step:verify");
        var ok = world ? world.check(s.expect || {}) : true;
        if (!ok) { taskFail("verify:" + (s.label || "mismatch")); return; }
        stepDone();
        return;
      }
      case "hold":
        setState(s.state && STATES[s.state] ? STATES[s.state] : STATES.LISTEN, "step:hold");
        if (s.look !== undefined) rigLook(resolveLook(s));
        break;
      case "teach":
        setState(STATES.TEACH, "step:teach");
        if (s.look !== undefined) rigLook(resolveLook(s));
        break;
      case "sit":
        setState(STATES.SIT, "step:sit");
        break;
      case "stand":
        setState(STATES.STAND, "step:stand");
        break;
      case "idle":
        setState(STATES.IDLE, "step:idle");
        stepDone();
        return;
      default:
        taskFail("unknown-op:" + s.op);
        return;
    }
  }

  function stepDur(s) {
    return s.dur != null ? s.dur : cfg.defaultDur;
  }

  function updateActive(dt) {
    var act = behav.active;
    var h = act.h;
    if (act.phase === "recovery") {
      act.recElapsed += dt;
      if (act.recElapsed >= cfg.recoverDur) finishRecovery();
      return;
    }
    if (h.timeout && time - h.started > h.timeout) { taskFail("timeout"); return; }

    var s = act.op;
    act.elapsed += dt;
    act.step.elapsed += dt;

    switch (s.op) {
      case "goto":
        /* completion arrives via the loco resolve callback */
        break;
      case "align": {
        var pos = rig.getPos();
        var yaw = rig.getYaw();
        var d = angDelta(yaw, act.step.yawTarget);
        var maxStep = cfg.yawRate * dt;
        if (Math.abs(d) <= Math.max(maxStep, cfg.alignTol)) {
          if (rig.setPose) rig.setPose(pos.x, pos.z, act.step.yawTarget);
          if (rig.setLocomotion) rig.setLocomotion(0);
          stepDone();
        } else {
          if (rig.setPose) rig.setPose(pos.x, pos.z, yaw + Math.sign(d) * maxStep);
          if (rig.setLocomotion) rig.setLocomotion(0);
        }
        break;
      }
      default:
        if (act.elapsed >= stepDur(s)) {
          if (s.op === "manipulate" && rig.setGesture) rig.setGesture(null);
          stepDone();
        }
        break;
    }
  }

  behav.update = function (dt) {
    if (!(dt > 0)) return;
    if (dt > 0.1) dt = 0.1;
    time += dt;
    if (loco) loco.update(dt);
    if (!behav.active) {
      nextReady();
      if (!behav.active) return;
    }
    updateActive(dt);
  };

  behav.states = STATES;
  behav.stats = function () {
    return {
      state: behav.state,
      held: behav.held,
      active: behav.active ? behav.active.h.label : null,
      pending: pending.length,
      paused: paused.length,
      transitions: behav.transitions.length,
    };
  };
  behav.pendingCount = function () { return pending.length + paused.length + (behav.active ? 1 : 0); };

  return behav;
}

export { createBehaviour, STATES };
