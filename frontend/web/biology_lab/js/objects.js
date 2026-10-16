/**
 * World object store (Phase 2) — the single source of truth for interactable
 * object state. Pure JS so behaviour logic and Node unit tests share it with
 * the live scene: the host (index.html) subscribes and applies visual side
 * effects (drawer animation, ring sound, mesh parenting), while the behaviour
 * controller only reads/writes state here.
 *
 * Object shape (all fields optional except id):
 *   id        unique string ('phone', 'phone.handset', 'cab.slides', 'item.jar')
 *   kind      coarse type tag for the host
 *   pos       {x,y,z} canonical world position (closed / resting pose)
 *   state     free-form {..} — behaviour and host agree on keys per kind
 *   points    named interaction points {handle:{x,y,z}, cradle:{...}, ...}
 */
"use strict";

function deepHas(obj, path, expect) {
  var parts = path.split("."), cur = obj;
  for (var i = 0; i < parts.length; i++) {
    if (cur == null) return false;
    cur = cur[parts[i]];
  }
  return cur === expect;
}

function createWorld() {
  var objs = {};
  var listeners = [];
  var t = 0;

  function get(id) {
    return objs[id] || null;
  }

  function register(def) {
    if (!def || !def.id) throw new Error("world.register: id required");
    objs[def.id] = {
      id: def.id,
      kind: def.kind || "",
      pos: def.pos ? { x: def.pos.x, y: def.pos.y, z: def.pos.z } : null,
      state: def.state ? JSON.parse(JSON.stringify(def.state)) : {},
      points: def.points ? JSON.parse(JSON.stringify(def.points)) : {},
    };
    return objs[def.id];
  }

  /* merge patch into the object's state (shallow, dotted keys allowed);
     returns true when something actually changed */
  function set(id, patch) {
    var o = objs[id];
    if (!o) return false;
    var changed = false;
    Object.keys(patch || {}).forEach(function (k) {
      var v = patch[k];
      if (k.indexOf(".") >= 0) {
        var parts = k.split("."), cur = o.state;
        for (var i = 0; i < parts.length - 1; i++) {
          if (cur[parts[i]] == null || typeof cur[parts[i]] !== "object") cur[parts[i]] = {};
          cur = cur[parts[i]];
        }
        var leaf = parts[parts.length - 1];
        if (cur[leaf] !== v) { cur[leaf] = v; changed = true; }
      } else if (o.state[k] !== v) { o.state[k] = v; changed = true; }
    });
    if (changed) emit({ type: "world", id: id, patch: patch, t: t });
    return changed;
  }

  /* update the canonical position (held items track the hand host-side, but
     the resting / placed pose lives here so releases never teleport) */
  function move(id, x, y, z) {
    var o = objs[id];
    if (!o) return false;
    if (!o.pos) o.pos = { x: x, y: y, z: z };
    else { o.pos.x = x; o.pos.y = y; o.pos.z = z; }
    emit({ type: "world", id: id, patch: { pos: o.pos }, t: t });
    return true;
  }

  /* world-space point lookup: explicit points table, else canonical pos */
  function point(id, name) {
    var o = objs[id];
    if (!o) return null;
    if (name && o.points && o.points[name]) {
      var p = o.points[name];
      return { x: p.x, y: p.y, z: p.z };
    }
    return o.pos ? { x: o.pos.x, y: o.pos.y, z: o.pos.z } : null;
  }

  /* declarative check used by behaviour VERIFY steps and tests:
     expect = {'phone.state.ringing': false, ...}. Object ids may themselves
     contain dots ('cabFR.slides'), so the id is the longest registered prefix
     of the path and the remainder walks into state. */
  function check(expect) {
    for (var path in expect) {
      var id = null, rest = "";
      Object.keys(objs).forEach(function (k) {
        if (path === k || path.indexOf(k + ".") === 0) {
          if (id === null || k.length > id.length) {
            id = k;
            rest = path.slice(k.length + 1);
          }
        }
      });
      if (id === null) return false;
      var o = objs[id];
      if (!rest) {
        if (o !== expect[path]) return false;
      } else if (!deepHas(o, rest, expect[path])) return false;
    }
    return true;
  }

  function snapshot() {
    var out = {};
    Object.keys(objs).forEach(function (id) {
      var o = objs[id];
      out[id] = { kind: o.kind, pos: o.pos, state: JSON.parse(JSON.stringify(o.state)) };
    });
    return out;
  }

  /* ---------- Phase 3: per-object action catalogue ----------
     An action is a reusable, data-defined interaction attached to an object:
       pre     declarative world.check expectations (or fn(world) -> bool)
       steps   fn(world, opts) -> behaviour step array (or a plain array)
       verify  declarative completion conditions checked before 'completed'
       sound   optional sound event name emitted when the action completes
     Objects then expose consistent interaction behaviour: same precondition
     contract, same step DSL, same verify-before-complete guarantee. */
  var acts = {};

  function defineAction(def) {
    if (!def || !def.id || !def.name) throw new Error("world.defineAction: id+name required");
    if (!objs[def.id]) throw new Error("world.defineAction: unknown object " + def.id);
    var a = {
      id: def.id,
      name: def.name,
      pre: def.pre || null,
      steps: def.steps || [],
      verify: def.verify || null,
      sound: def.sound || null,
      priority: def.priority != null ? def.priority : 4,
    };
    acts[def.id + "::" + def.name] = a;
    return a;
  }

  function action(id, name) {
    return acts[id + "::" + name] || null;
  }

  function actionsFor(id) {
    return Object.keys(acts)
      .filter(function (k) { return acts[k].id === id; })
      .map(function (k) { return acts[k].name; });
  }

  function checkPre(id, name, opts) {
    var a = acts[id + "::" + name];
    if (!a) return false;
    if (!a.pre) return true;
    if (typeof a.pre === "function") return !!a.pre(getWorld(), opts || {});
    return check(a.pre);
  }

  /* materialise the concrete step list for one action invocation */
  function actionSteps(id, name, opts) {
    var a = acts[id + "::" + name];
    if (!a) return null;
    var steps = typeof a.steps === "function" ? a.steps(getWorld(), opts || {}) : a.steps.slice();
    if (!Array.isArray(steps)) return null;
    steps = steps.slice();
    if (a.verify) steps.push({ op: "verify", expect: resolveConds(a.verify, opts), label: id + ":" + name });
    if (a.sound) steps.push({ op: "emit", name: a.sound });
    return steps;
  }

  /* verify/pre may be objects (static) or fns (parameterised by opts) */
  function resolveConds(v, opts) {
    return typeof v === "function" ? v(getWorld(), opts || {}) : v;
  }

  /* Phase 3: balance coupling — placing a registered item on the pan (or
     lifting it away) updates the balance's mass display. Pure world-store
     logic so the unit tests and the live host share one rule. */
  function wireBalance(itemId, balanceId, opts) {
    opts = opts || {};
    var radius = opts.radius != null ? opts.radius : 0.12;
    var massKey = opts.massKey || "massG";
    return subscribe(function (ev) {
      if (ev.id !== itemId && ev.id !== balanceId) return;
      var it = objs[itemId], bal = objs[balanceId];
      if (!it || !bal) return;
      var pan = point(balanceId, "pan") || bal.pos;
      if (!pan || !it.pos) return;
      var d = Math.sqrt(
        (it.pos.x - pan.x) * (it.pos.x - pan.x) + (it.pos.z - pan.z) * (it.pos.z - pan.z)
      );
      if (it.state.heldBy == null && d <= radius) {
        var m = typeof it.state[massKey] === "number" ? it.state[massKey] : 0;
        set(balanceId, { massG: m, tare: false, onItem: itemId });
      } else if (bal.state.onItem === itemId && (it.state.heldBy != null || d > radius)) {
        set(balanceId, { massG: 0, tare: true, onItem: null });
      }
    });
  }

  function getWorld() { return api; }

  function emit(evt) {
    listeners.forEach(function (fn) {
      try { fn(evt); } catch (e) { /* host listener errors must not break the store */ }
    });
  }

  function subscribe(fn) {
    listeners.push(fn);
    return function () {
      var i = listeners.indexOf(fn);
      if (i >= 0) listeners.splice(i, 1);
    };
  }

  var api = {
    get: get,
    register: register,
    set: set,
    move: move,
    point: point,
    check: check,
    snapshot: snapshot,
    subscribe: subscribe,
    tick: function (dt) { t += dt; },
    defineAction: defineAction,
    action: action,
    actionsFor: actionsFor,
    checkPre: checkPre,
    actionSteps: actionSteps,
    wireBalance: wireBalance,
  };
  return api;
}

export { createWorld };
