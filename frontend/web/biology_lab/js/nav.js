/**
 * Navigation for the biology lab teacher (Phase 1).
 *
 * Pure JS — no THREE import — so it runs both in the browser module graph and
 * in Node unit tests. The lab registers real furniture as obstacles at build
 * time (one call per placement site, using the same world coordinates as the
 * meshes), then `build()` rasterises them into a walkability grid inflated by
 * the teacher's radius. Pathfinding is A* (8-connected, no corner cutting)
 * followed by string-pull smoothing with grid line-of-sight checks.
 *
 * World convention: XZ plane, Y up (matches the scene). Units: metres.
 */
"use strict";

export function createNav() {
    var obstacles = []; // {kind:'rect'|'circle', ...raw geometry, tag}
    var grid = null;
    var meta = null;

    function addRect(x0, z0, x1, z1, tag) {
      obstacles.push({
        kind: "rect",
        x0: Math.min(x0, x1),
        z0: Math.min(z0, z1),
        x1: Math.max(x0, x1),
        z1: Math.max(z0, z1),
        tag: tag || "",
      });
    }

    /* AABB of a box centred at (cx,cz) with size (w,d) rotated by ry (radians). */
    function addRectRot(cx, cz, w, d, ry, tag) {
      var c = Math.abs(Math.cos(ry || 0)),
        s = Math.abs(Math.sin(ry || 0));
      var ex = (w / 2) * c + (d / 2) * s;
      var ez = (w / 2) * s + (d / 2) * c;
      addRect(cx - ex, cz - ez, cx + ex, cz + ez, tag);
    }

    function addCircle(x, z, r, tag) {
      obstacles.push({ kind: "circle", x: x, z: z, r: r, tag: tag || "" });
    }

    /**
     * Rasterise obstacles into a walkability grid.
     * bounds: {x0,z0,x1,z1} walkable room interior (wall inner faces).
     * agentRadius: teacher clearance (obstacles are inflated by this).
     * cell: grid resolution in metres (default 0.1).
     */
    function build(bounds, agentRadius, cell) {
      cell = cell || 0.1;
      var nx = Math.max(1, Math.round((bounds.x1 - bounds.x0) / cell));
      var nz = Math.max(1, Math.round((bounds.z1 - bounds.z0) / cell));
      var walk = new Uint8Array(nx * nz);
      var r = agentRadius;
      for (var iz = 0; iz < nz; iz++) {
        var z = bounds.z0 + (iz + 0.5) * cell;
        for (var ix = 0; ix < nx; ix++) {
          var x = bounds.x0 + (ix + 0.5) * cell;
          var blocked = false;
          for (var o = 0; o < obstacles.length; o++) {
            var ob = obstacles[o];
            if (ob.kind === "rect") {
              if (
                x >= ob.x0 - r &&
                x <= ob.x1 + r &&
                z >= ob.z0 - r &&
                z <= ob.z1 + r
              ) {
                blocked = true;
                break;
              }
            } else {
              var dx = x - ob.x,
                dz = z - ob.z;
              if (dx * dx + dz * dz <= (ob.r + r) * (ob.r + r)) {
                blocked = true;
                break;
              }
            }
          }
          walk[iz * nx + ix] = blocked ? 0 : 1;
        }
      }
      grid = { walk: walk, nx: nx, nz: nz, cell: cell, bounds: bounds, agentRadius: r };
      meta = { cells: nx * nz, walkable: 0, obstacles: obstacles.length };
      for (var i = 0; i < walk.length; i++) if (walk[i]) meta.walkable++;
      return meta;
    }

    function cellOf(x, z) {
      if (!grid) return null;
      var ix = Math.floor((x - grid.bounds.x0) / grid.cell);
      var iz = Math.floor((z - grid.bounds.z0) / grid.cell);
      if (ix < 0 || iz < 0 || ix >= grid.nx || iz >= grid.nz) return null;
      return { ix: ix, iz: iz };
    }

    function isWalkable(x, z) {
      var c = cellOf(x, z);
      if (!c) return false;
      return grid.walk[c.iz * grid.nx + c.ix] === 1;
    }

    function clampIx(v) {
      return Math.max(0, Math.min(grid.nx - 1, v));
    }
    function clampIz(v) {
      return Math.max(0, Math.min(grid.nz - 1, v));
    }

    /**
     * Walkable cell centres near (x,z) within maxDist metres, sorted by
     * distance. The nearest one is not always reachable (bench strips walled
     * off by stool rings form disconnected pockets), so findPath retries the
     * next candidates until A* succeeds.
     */
    function walkableCandidates(x, z, maxDist, limit) {
      var out = [];
      if (!grid) return out;
      limit = limit || 8;
      maxDist = maxDist || 0.6;
      var c = cellOf(x, z);
      if (c && grid.walk[c.iz * grid.nx + c.ix] === 1) {
        out.push({ x: x, z: z, d2: 0 });
        return out;
      }
      var bx = c ? c.ix : clampIx(Math.floor((x - grid.bounds.x0) / grid.cell));
      var bz = c ? c.iz : clampIz(Math.floor((z - grid.bounds.z0) / grid.cell));
      var maxR = Math.ceil(maxDist / grid.cell);
      for (var r = 1; r <= maxR && out.length < limit; r++) {
        for (var dz = -r; dz <= r && out.length < limit; dz++) {
          for (var dx = -r; dx <= r && out.length < limit; dx++) {
            if (Math.max(Math.abs(dx), Math.abs(dz)) !== r) continue; // ring only
            var ix = bx + dx,
              iz = bz + dz;
            if (ix < 0 || iz < 0 || ix >= grid.nx || iz >= grid.nz) continue;
            if (grid.walk[iz * grid.nx + ix] !== 1) continue;
            var wx = grid.bounds.x0 + (ix + 0.5) * grid.cell;
            var wz = grid.bounds.z0 + (iz + 0.5) * grid.cell;
            var d = (wx - x) * (wx - x) + (wz - z) * (wz - z);
            out.push({ x: wx, z: wz, d2: d });
          }
        }
      }
      out.sort(function (a, b) {
        return a.d2 - b.d2;
      });
      return out;
    }

    /* nearest walkable point to (x,z) within maxDist metres */
    function nearestWalkable(x, z, maxDist) {
      if (!grid) return null;
      if (isWalkable(x, z)) return { x: x, z: z };
      var cands = walkableCandidates(x, z, maxDist, 1);
      return cands.length ? { x: cands[0].x, z: cands[0].z } : null;
    }

    function lineOfSight(ax, az, bx, bz) {
      if (!grid) return false;
      var dx = bx - ax,
        dz = bz - az;
      var dist = Math.hypot(dx, dz);
      /* Sample at quarter-cell steps: half-cell steps can straddle the thin
         (~1 cell) blocked sliver where a diagonal segment clips the corner of
         an inflated obstacle, letting string-pull keep a segment the walker
         then trips over mid-step. */
      var steps = Math.max(1, Math.ceil(dist / (grid.cell * 0.25)));
      for (var i = 0; i <= steps; i++) {
        var t = i / steps;
        if (!isWalkable(ax + dx * t, az + dz * t)) return false;
      }
      return true;
    }

    /* binary min-heap over parallel arrays (f = f-scores) */
    function Heap() {
      this.k = [];
      this.v = [];
    }
    Heap.prototype.push = function (key, val) {
      var k = this.k,
        v = this.v,
        i = k.length;
      k.push(key);
      v.push(val);
      while (i > 0) {
        var p = (i - 1) >> 1;
        if (k[p] <= k[i]) break;
        var tk = k[p],
          tv = v[p];
        k[p] = k[i];
        v[p] = v[i];
        k[i] = tk;
        v[i] = tv;
        i = p;
      }
    };
    Heap.prototype.pop = function () {
      var k = this.k,
        v = this.v,
        top = { key: k[0], val: v[0] },
        n = k.length - 1;
      k[0] = k[n];
      v[0] = v[n];
      k.pop();
      v.pop();
      var i = 0;
      while (true) {
        var l = 2 * i + 1,
          r = l + 1,
          m = i;
        if (l < n && k[l] < k[m]) m = l;
        if (r < n && k[r] < k[m]) m = r;
        if (m === i) break;
        var tk = k[m],
          tv = v[m];
        k[m] = k[i];
        v[m] = v[i];
        k[i] = tk;
        v[i] = tv;
        i = m;
      }
      return top;
    };
    Heap.prototype.size = function () {
      return this.k.length;
    };

    /* A* between two walkable cell centres; returns cell path or null. */
    function astar(s, g) {
      var nx = grid.nx,
        nz = grid.nz,
        cell = grid.cell,
        walk = grid.walk;
      var startIdx = s.iz * nx + s.ix,
        goalIdx = g.iz * nx + g.ix;
      var gScore = new Float64Array(nx * nz);
      gScore.fill(Infinity);
      var from = new Int32Array(nx * nz);
      from.fill(-1);
      var closed = new Uint8Array(nx * nz);
      var SQRT2 = Math.SQRT2;
      function h(ix, iz) {
        var dx = Math.abs(ix - g.ix),
          dz = Math.abs(iz - g.iz);
        return (dx + dz) + (SQRT2 - 2) * Math.min(dx, dz);
      }
      var open = new Heap();
      gScore[startIdx] = 0;
      open.push(h(s.ix, s.iz), startIdx);
      var found = false;
      var guard = nx * nz * 4; // hard stop against pathological loops
      var OX = [1, -1, 0, 0, 1, 1, -1, -1];
      var OZ = [0, 0, 1, -1, 1, -1, 1, -1];
      while (open.size() > 0 && guard-- > 0) {
        var top = open.pop();
        var cur = top.val;
        if (closed[cur]) continue;
        closed[cur] = 1;
        if (cur === goalIdx) {
          found = true;
          break;
        }
        var cix = cur % nx,
          ciz = (cur - cix) / nx;
        for (var d = 0; d < 8; d++) {
          var nix = cix + OX[d],
            niz = ciz + OZ[d];
          if (nix < 0 || niz < 0 || nix >= nx || niz >= nz) continue;
          var ni = niz * nx + nix;
          if (!walk[ni] || closed[ni]) continue;
          if (d >= 4) {
            // no corner cutting: both orthogonal neighbours must be walkable
            if (!walk[ciz * nx + nix] || !walk[niz * nx + cix]) continue;
          }
          var step = d < 4 ? 1 : SQRT2;
          var ng = gScore[cur] + step;
          if (ng < gScore[ni]) {
            gScore[ni] = ng;
            from[ni] = cur;
            open.push(ng * cell + h(nix, niz) * cell, ni); // scale to metres for balanced heap keys
          }
        }
      }
      if (!found) return null;
      var cells = [];
      var at = goalIdx;
      while (at !== -1) {
        var ix2 = at % nx,
          iz2 = (at - ix2) / nx;
        cells.push({ x: grid.bounds.x0 + (ix2 + 0.5) * cell, z: grid.bounds.z0 + (iz2 + 0.5) * cell });
        if (at === startIdx) break;
        at = from[at];
      }
      cells.reverse();
      return cells;
    }

    function findPath(ax, az, bx, bz, opts) {
      if (!grid) return null;
      opts = opts || {};
      var maxSnap = opts.maxSnap != null ? opts.maxSnap : 0.6;
      /* The Euclidean-nearest walkable cell to a goal can be a disconnected
         pocket (e.g. a bench strip sealed by stool rings). Retry the next
         nearest snap candidates until A* actually finds a route. */
      var startCands = walkableCandidates(ax, az, maxSnap, 6);
      var goalCands = walkableCandidates(bx, bz, maxSnap, 6);
      if (!startCands.length || !goalCands.length) return null;
      var start = null,
        goal = null,
        cells = null;
      for (var gi = 0; gi < goalCands.length && !cells; gi++) {
        for (var si = 0; si < startCands.length && !cells; si++) {
          var sc = { ix: clampIx(Math.floor((startCands[si].x - grid.bounds.x0) / grid.cell)),
                     iz: clampIz(Math.floor((startCands[si].z - grid.bounds.z0) / grid.cell)) };
          var gc = { ix: clampIx(Math.floor((goalCands[gi].x - grid.bounds.x0) / grid.cell)),
                     iz: clampIz(Math.floor((goalCands[gi].z - grid.bounds.z0) / grid.cell)) };
          cells = astar(sc, gc);
          if (cells) {
            start = startCands[si];
            goal = goalCands[gi];
          }
        }
      }
      if (!cells) return null;
      /* string-pull smoothing (grid LOS). Only append the raw endpoints when
         they are themselves walkable — a goal inside furniture must end at the
         snapped cell centre, otherwise the final segment steps into the
         obstacle and the walker's safety check stalls forever. */
      var head = [{ x: ax, z: az }];
      if (!isWalkable(ax, az)) head = [{ x: start.x, z: start.z }];
      var tail = [{ x: bx, z: bz }];
      if (!isWalkable(bx, bz)) tail = [{ x: goal.x, z: goal.z }];
      var pts = head.concat(cells, tail);
      var out = [pts[0]];
      var i = 0;
      while (i < pts.length - 1) {
        var j = pts.length - 1;
        for (; j > i + 1; j--) {
          if (lineOfSight(pts[i].x, pts[i].z, pts[j].x, pts[j].z)) break;
        }
        out.push(pts[j]);
        i = j;
      }
      // drop zero-length segments
      var clean = [out[0]];
      for (var p = 1; p < out.length; p++) {
        var q = out[p],
          last = clean[clean.length - 1];
        if (Math.hypot(q.x - last.x, q.z - last.z) > 1e-4) clean.push(q);
      }
      return clean.length >= 2 ? clean : null;
    }

    /* minimum distance from (x,z) to any raw (uninflated) obstacle — used by tests
       to prove the walked path keeps clearance from furniture */
    function clearance(x, z) {
      var best = Infinity;
      for (var o = 0; o < obstacles.length; o++) {
        var ob = obstacles[o],
          d;
        if (ob.kind === "rect") {
          var dx = Math.max(ob.x0 - x, 0, x - ob.x1);
          var dz = Math.max(ob.z0 - z, 0, z - ob.z1);
          d = Math.hypot(dx, dz);
        } else {
          d = Math.hypot(x - ob.x, z - ob.z) - ob.r;
        }
        if (d < best) best = d;
      }
      return best;
    }

    return {
      addRect: addRect,
      addRectRot: addRectRot,
      addCircle: addCircle,
      build: build,
      isWalkable: isWalkable,
      nearestWalkable: nearestWalkable,
      lineOfSight: lineOfSight,
      findPath: findPath,
      clearance: clearance,
      stats: function () {
        return meta;
      },
      obstacles: function () {
        return obstacles.slice();
      },
      ready: function () {
        return !!grid;
      },
    };
}
