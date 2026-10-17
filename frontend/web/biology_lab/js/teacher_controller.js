/**
 * Teacher behaviour controller (Phase 1) for the biology lab.
 *
 * Owns the Phase-1 state set — IDLE, TURN, NAVIGATE, APPROACH, RECOVER — and
 * drives a rig adapter that the host (index.html) implements with the real
 * skinned model / AnimationMixer. Movement math lives here so the controller
 * is unit-testable in Node with a fake rig (no THREE, no DOM).
 *
 * The host supplies:
 *   nav                 - LabNav instance (already built)
 *   rig = {
 *     getPos()          - {x,z} current ground position
 *     getYaw()          - current facing (radians, same convention as the scene)
 *     setPose(x,z,yaw)  - place the teacher (y/foot-lock handled host-side)
 *     setLocomotion(t)  - t in [0,1]: walk/idle blend + clip timeScale
 *     radius            - body radius used for safety look-ahead (metres)
 *   }
 *   config = {speed, accel, decel, yawRate, standOff, arriveDist, timeout}
 *
 * Public API:
 *   ctl.update(dt)                     - advance one frame
 *   ctl.goto(x, z, opts)               - start a task; opts: {standOff, faceYaw,
 *                                        faceX, faceZ, timeout, label}
 *                                        returns the task handle (with .cancel())
 *   ctl.stop(reason)                   - interrupt the active task
 *   ctl.state                          - current state name
 *   ctl.lastResult                     - {status, x, z, elapsed, pathLen, label}
 *   ctl.transitions                    - ring log of {t, from, to, why}
 *   ctl.path                           - current waypoint list (debug/tests)
 */
"use strict";

var STATES = {
    IDLE: "IDLE",
    TURN: "TURN",
    NAVIGATE: "NAVIGATE",
    APPROACH: "APPROACH",
    RECOVER: "RECOVER",
  };

  var DEFAULTS = {
    speed: 1.05, // cruise m/s (matches CONFIG.teacherSpeed / walk-clip tuning)
    accel: 2.2, // m/s^2
    decel: 3.4, // m/s^2 (gentle stop keeps the planted foot believable)
    yawRate: 2.4, // rad/s turn-in-place
    standOff: 0.55, // stop this far from the target point (bench edge etc.)
    arriveDist: 0.1, // considered arrived within this of the final point
    /* Intermediate waypoints must be reached almost exactly: corridors between
       inflated benches leave ~0.05 m of slack, so "arriving" 0.1 m early cuts
       corners and the next leg clips furniture. Half a grid cell (0.04) keeps
       the walker on the LOS-verified polyline. */
    wpArriveDist: 0.04,
    timeout: 45, // hard stop, seconds
    recoverLimit: 3, // re-path attempts before giving up (long routes have corners)
    /* how far a requested goal may be snapped to walkable space. Bench-top
       interaction points (equipment on the surface) sit ~0.9 m from the nearest
       walkable floor, so 0.95 covers realistic targets while points deep
       inside a 3 m bench (1.5 m+ from any edge) still fail as unreachable. */
    maxSnap: 0.95,
  };

  function angDelta(a, b) {
    var d = b - a;
    while (d > Math.PI) d -= 2 * Math.PI;
    while (d < -Math.PI) d += 2 * Math.PI;
    return d;
  }

  function createTeacherController(nav, rig, config) {
    var cfg = {};
    Object.keys(DEFAULTS).forEach(function (k) {
      cfg[k] = (config && config[k] != null) ? config[k] : DEFAULTS[k];
    });

    var ctl = {
      state: STATES.IDLE,
      speed: 0,
      path: null,
      pathIdx: 0,
      lastResult: null,
      transitions: [],
      task: null,
    };
    var time = 0;
    var taskSeq = 0;
    var recoverCount = 0;
    var stuckTimer = 0;
    var lastPos = null;
    var lastWalkable = null;

    function logTransition(from, to, why) {
      ctl.transitions.push({
        t: +time.toFixed(3),
        from: from,
        to: to,
        why: why || "",
      });
      if (ctl.transitions.length > 200) ctl.transitions.shift();
    }

    function setState(to, why) {
      if (ctl.state === to) return;
      var from = ctl.state;
      ctl.state = to;
      logTransition(from, to, why);
    }

    function finish(task, status) {
      if (ctl.task !== task) return; // already superseded
      var pos = rig.getPos();
      ctl.lastResult = {
        status: status,
        x: +pos.x.toFixed(4),
        z: +pos.z.toFixed(4),
        elapsed: +time.toFixed(3),
        pathLen: task.pathLen != null ? +task.pathLen.toFixed(3) : null,
        label: task.label || "",
        target: { x: task.x, z: task.z },
      };
      ctl.task = null;
      ctl.path = null;
      stuckTimer = 0;
      recoverCount = 0;
      setState(STATES.IDLE, "task:" + status);
      rig.setLocomotion(0);
      if (task.resolve) task.resolve(ctl.lastResult);
    }

    function computePath(task) {
      var pos = rig.getPos();
      /* Path to the snapped walkable point nearest the target. standOff is NOT
         applied by pre-pulling the goal (that can land inside an obstacle);
         instead, if the path ends closer to the true target than standOff,
         trim it back along the waypoints so the final stop respects standOff. */
      var path = nav.findPath(pos.x, pos.z, task.x, task.z, { maxSnap: cfg.maxSnap });
      if (!path || path.length < 2) return null;
      if (task.standOff > 0) {
        var end = path.length - 1;
        var dEnd = Math.hypot(path[end].x - task.x, path[end].z - task.z);
        if (dEnd < task.standOff) {
          var cut = -1;
          for (var i = end - 1; i >= 0; i--) {
            if (Math.hypot(path[i].x - task.x, path[i].z - task.z) >= task.standOff) {
              cut = i;
              break;
            }
          }
          if (cut >= 0 && cut < end) {
            /* interpolate the exact standOff crossing on the segment so the
               stop is precise, but only if that point is on walkable floor */
            var a = path[cut],
              b = path[cut + 1];
            var lo = 0,
              hi = 1;
            for (var k = 0; k < 24; k++) {
              var m = (lo + hi) / 2;
              var mx = a.x + (b.x - a.x) * m,
                mz = a.z + (b.z - a.z) * m;
              if (Math.hypot(mx - task.x, mz - task.z) >= task.standOff) lo = m;
              else hi = m;
            }
            var sx = a.x + (b.x - a.x) * lo,
              sz = a.z + (b.z - a.z) * lo;
            if (nav.isWalkable(sx, sz)) path = path.slice(0, cut + 1).concat([{ x: sx, z: sz }]);
            else path = path.slice(0, cut + 1);
          } else if (cut < 0) {
            /* even the path start is inside the standOff radius: stay put */
            path = [path[0], { x: path[0].x, z: path[0].z }];
          }
        }
      }
      var plen = 0;
      for (var j = 1; j < path.length; j++) {
        plen += Math.hypot(path[j].x - path[j - 1].x, path[j].z - path[j - 1].z);
      }
      task.pathLen = plen;
      var endPt = path[path.length - 1];
      if (task.faceYaw != null) task.finalFace = task.faceYaw;
      else if (task.faceX != null)
        task.finalFace = Math.atan2(task.faceX - endPt.x, task.faceZ - endPt.z);
      else task.finalFace = null;
      return path;
    }

    function beginTask(task) {
      var path = computePath(task);
      if (!path) {
        ctl.lastResult = {
          status: "unreachable",
          x: +rig.getPos().x.toFixed(4),
          z: +rig.getPos().z.toFixed(4),
          elapsed: +time.toFixed(3),
          pathLen: null,
          label: task.label || "",
          target: { x: task.x, z: task.z },
        };
        logTransition(STATES.IDLE, STATES.IDLE, "unreachable:" + (task.label || ""));
        if (task.resolve) task.resolve(ctl.lastResult);
        return false;
      }
      ctl.path = path;
      ctl.pathIdx = 0;
      stuckTimer = 0;
      recoverCount = 0;
      lastPos = rig.getPos();
      lastWalkable = { x: lastPos.x, z: lastPos.z };
      var yaw0 = rig.getYaw();
      var d0 = Math.atan2(path[1].x - path[0].x, path[1].z - path[0].z);
      if (Math.abs(angDelta(yaw0, d0)) > 0.35) {
        task.turnTo = d0;
        setState(STATES.TURN, "align-start");
      } else {
        setState(STATES.NAVIGATE, "start");
      }
      return true;
    }

    ctl.goto = function (x, z, opts) {
      opts = opts || {};
      if (ctl.task) finish(ctl.task, "interrupted");
      var task = {
        id: ++taskSeq,
        x: x,
        z: z,
        standOff: opts.standOff != null ? opts.standOff : cfg.standOff,
        faceYaw: opts.faceYaw,
        faceX: opts.faceX,
        faceZ: opts.faceZ,
        timeout: opts.timeout != null ? opts.timeout : cfg.timeout,
        label: opts.label || "",
        started: time,
        cancelled: false,
        resolve: opts.resolve,
      };
      task.cancel = function () {
        if (ctl.task === task) finish(task, "interrupted");
      };
      ctl.task = task;
      if (!beginTask(task)) ctl.task = null;
      return task;
    };

    ctl.stop = function (why) {
      if (ctl.task) finish(ctl.task, why || "interrupted");
    };

    function turnTowards(task, targetYaw, dt, next) {
      var yaw = rig.getYaw();
      var d = angDelta(yaw, targetYaw);
      var maxStep = cfg.yawRate * dt;
      if (Math.abs(d) <= maxStep || Math.abs(d) < 0.02) {
        rig.setPose(rig.getPos().x, rig.getPos().z, targetYaw);
        next();
        return;
      }
      rig.setPose(rig.getPos().x, rig.getPos().z, yaw + Math.sign(d) * maxStep);
      rig.setLocomotion(0);
    }

    /* Waypoint follower target: the path already encodes standOff trimming, so
       every waypoint (including the last) is walked to directly. */
    function steeringTarget(path, idx) {
      return path[idx];
    }

    ctl.update = function (dt) {
      if (!(dt > 0)) return;
      if (dt > 0.1) dt = 0.1; // clamp hitches
      time += dt;
      var task = ctl.task;
      if (!task) {
        /* idle: keep blend at 0, ease any residual speed to rest */
        if (ctl.speed > 0) {
          ctl.speed = Math.max(0, ctl.speed - cfg.decel * dt);
          rig.setLocomotion(ctl.speed / cfg.speed);
        }
        return;
      }
      if (time - task.started > task.timeout) {
        finish(task, "timeout");
        return;
      }

      var pos = rig.getPos();

      if (ctl.state === STATES.TURN) {
        turnTowards(task, task.turnTo, dt, function () {
          setState(STATES.NAVIGATE, "aligned");
        });
        return;
      }

      if (ctl.state === STATES.RECOVER) {
        /* one in-place pause then re-path; fail after recoverLimit */
        rig.setLocomotion(0);
        ctl.speed = 0;
        /* if a bad step left the rig inside an inflated obstacle, snap back to
           the last walkable pose first — re-pathing from blocked space makes
           every immediate look-ahead step fail and the recover loop never escapes */
        if (!nav.isWalkable(pos.x, pos.z) && lastWalkable) {
          rig.setPose(lastWalkable.x, lastWalkable.z, rig.getYaw());
          pos = rig.getPos();
        }
        recoverCount++;
        if (recoverCount > cfg.recoverLimit) {
          finish(task, "unreachable");
          return;
        }
        var path = computePath(task);
        if (!path) {
          finish(task, "unreachable");
          return;
        }
        ctl.path = path;
        ctl.pathIdx = 0;
        stuckTimer = 0;
        lastPos = rig.getPos();
        setState(STATES.NAVIGATE, "recovered");
        return;
      }

      /* NAVIGATE / APPROACH share the waypoint follower */
      if (!ctl.path || ctl.pathIdx >= ctl.path.length) {
        finish(task, "arrived");
        return;
      }
      var isLast = ctl.pathIdx === ctl.path.length - 1;
      var wp = steeringTarget(ctl.path, ctl.pathIdx);
      var dx = wp.x - pos.x,
        dz = wp.z - pos.z,
        dist = Math.hypot(dx, dz);
      var arriveR = isLast ? cfg.arriveDist : cfg.wpArriveDist;

      if (dist < arriveR) {
        if (isLast) {
          /* final facing turn, then done */
          if (task.finalFace != null && Math.abs(angDelta(rig.getYaw(), task.finalFace)) > 0.05) {
            task.turnTo = task.finalFace;
            setState(STATES.TURN, "align-end");
            return;
          }
          rig.setPose(wp.x, wp.z, rig.getYaw());
          finish(task, "arrived");
          return;
        }
        ctl.pathIdx++;
        /* Corner legs: turn in place before starting the next segment. Walking
           the turn at speed swings the body off the LOS-verified polyline
           (yaw lags the heading), and in one-cell corridors (island/cabinet
           gaps, stool belts) that chord clips furniture and the recover loop
           never escapes. Same 0.35 rad threshold as align-start. */
        var pv = ctl.path[ctl.pathIdx - 1];
        var nv = ctl.path[ctl.pathIdx];
        var legYaw = Math.atan2(nv.x - pv.x, nv.z - pv.z);
        if (Math.abs(angDelta(rig.getYaw(), legYaw)) > 0.35) {
          task.turnTo = legYaw;
          setState(STATES.TURN, "align-corner");
        }
        return;
      }

      /* decelerate into the final stop so the walk clip does not stall mid-stride */
      var desired = cfg.speed;
      if (isLast) {
        var slow = Math.sqrt(2 * cfg.decel * Math.max(0, dist - cfg.arriveDist));
        desired = Math.min(cfg.speed, Math.max(0.18, slow));
      }
      if (ctl.speed < desired) ctl.speed = Math.min(desired, ctl.speed + cfg.accel * dt);
      else ctl.speed = Math.max(desired, ctl.speed - cfg.decel * dt);

      var dirX = dx / dist,
        dirZ = dz / dist;
      var step = ctl.speed * dt;
      if (step > dist) step = dist;
      var nx = pos.x + dirX * step,
        nz = pos.z + dirZ * step;

      /* safety look-ahead: never commit a step into blocked space (paths should
         already be clear; this catches dt spikes / registry drift) */
      if (!nav.isWalkable(nx, nz)) {
        var lx = pos.x + dirX * Math.min(step, rig.radius * 0.9);
        var lz = pos.z + dirZ * Math.min(step, rig.radius * 0.9);
        if (nav.isWalkable(lx, lz)) {
          nx = lx;
          nz = lz;
          ctl.speed *= 0.5;
        } else {
          setState(STATES.RECOVER, "blocked-step");
          return;
        }
      }

      var yaw = Math.atan2(dirX, dirZ);
      var dyaw = angDelta(rig.getYaw(), yaw);
      var maxYaw = cfg.yawRate * dt * 2; /* allow slight turning while walking */
      if (Math.abs(dyaw) > maxYaw) yaw = rig.getYaw() + Math.sign(dyaw) * maxYaw;

      if (isLast && dist < cfg.standOff) setState(STATES.APPROACH, "near-goal");
      rig.setPose(nx, nz, yaw);
      rig.setLocomotion(ctl.speed / cfg.speed);
      lastWalkable = { x: nx, z: nz };

      /* stuck detector: moving-command but no displacement over 0.9 s */
      if (ctl.speed > 0.15) {
        stuckTimer += dt;
        if (stuckTimer > 0.9) {
          var moved = Math.hypot(pos.x - lastPos.x, pos.z - lastPos.z);
          if (moved < 0.03) {
            setState(STATES.RECOVER, "stuck");
            return;
          }
          stuckTimer = 0;
          lastPos = { x: pos.x, z: pos.z };
        }
      } else {
        stuckTimer = 0;
      }
    };

    ctl.states = STATES;
    return ctl;
}

export { createTeacherController, STATES };
