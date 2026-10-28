/* MathDrill graph3d — the calculation-driven graphing engine.
   Renders graph_core output with an ORTHOGRAPHIC mathematical x/y plane in
   Three.js: axes with computed tick intervals (1/2/5×10ⁿ), major/minor grid,
   split curve branches, dashed labelled asymptotes (vertical/horizontal/
   oblique), smart feature annotations, hover/pinned coordinate inspection,
   inequality shading, zoom/pan that preserves mathematical coordinates, and a
   token-based light/blackboard-dark theme. Render-on-demand only (no loop
   while static); full disposal on teardown. */

import * as THREE from "three";
import { analyzeProblem, fmtTick, fmtCoord, niceTicks } from "./graph_core.js";

const THEMES = {
  light: {
    bg: "#ffffff", text: "#17202b", muted: "#5b6675",
    gridMin: "#eaeef4", gridMaj: "#d3dae4", axis: "#334155", axisText: "#334155",
    curve: "#7c3aed", curveHi: "#6d28d9", asymptote: "#d97706",
    vertex: "#2563eb", root: "#e11d48", mark: "#0f172a", band: "#7c3aed",
    chipBg: "rgba(255,255,255,.94)", chipBorder: "#d3dae4",
  },
  dark: {   /* charcoal blackboard — same #14171d as the calculation panels */
    bg: "#14171d", text: "#eef1f2", muted: "#a7b0ba",
    gridMin: "#1f242b", gridMaj: "#2b313a", axis: "#93a1b3", axisText: "#c3ccd8",
    curve: "#a78bfa", curveHi: "#c4b5fd", asymptote: "#f0b429",
    vertex: "#60a5fa", root: "#fb7185", mark: "#ffffff", band: "#8b7cff",
    chipBg: "rgba(20,23,29,.94)", chipBorder: "#343a44",
  },
};

const stateDefaults = { labels: true, grid: true, asymp: true };

export function createMdGraph(opts) {
  const o = opts || {};
  const container = o.container;
  let themeName = o.theme === "dark" ? "dark" : "light";
  const T = () => THEMES[themeName];

  if (!document.getElementById("g3d-style")) {
    const st = document.createElement("style");
    st.id = "g3d-style";
    st.textContent = `
.g3d-labs>div{position:absolute;left:0;top:0;white-space:nowrap;pointer-events:none;
  padding:1px 6px;border:1px solid;border-radius:6px;line-height:1.35;
  text-shadow:0 1px 2px rgba(0,0,0,.35)}
.g3d-labs .g3t{font-size:11px;font-weight:600;opacity:.92}
.g3d-labs .g3f{font-size:11.5px;font-weight:600}
.g3d-labs .g3r{font:600 11.5px ui-monospace,Consolas,monospace}
.g3d-labs .g3pin{font:600 12px ui-monospace,Consolas,monospace;border-width:2px}`;
    document.head.appendChild(st);
  }

  /* ---------- renderer & camera ---------- */
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  } catch (err) {
    if (o.onLimitation) o.onLimitation("WebGL unavailable: " + ((err && err.message) || "renderer failed"));
    return null;
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  container.appendChild(renderer.domElement);
  renderer.domElement.style.display = "block";

  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(-10, 10, 10, -10, -100, 100);
  camera.position.z = 10;

  /* label layer (HTML chips: crisp at any zoom) */
  const labs = document.createElement("div");
  labs.className = "g3d-labs";
  labs.style.cssText = "position:absolute;inset:0;pointer-events:none;overflow:hidden;z-index:2";
  container.appendChild(labs);
  const chipPool = [];
  function chip(cls) {
    let c = chipPool.pop();
    if (!c) c = document.createElement("div");
    if (c.parentNode !== labs) labs.appendChild(c);  // pooled chips arrive detached
    c.className = cls;
    c.style.display = "block";
    return c;
  }
  function releaseChips() {
    while (labs.firstChild) { chipPool.push(labs.firstChild); labs.removeChild(labs.firstChild); }
  }
  function chipStyle(el, x, y, color) {
    el.style.left = x + "px";
    el.style.top = y + "px";
    el.style.background = T().chipBg;
    el.style.borderColor = T().chipBorder;
    el.style.color = color || T().text;
  }

  /* ---------- view state (math coordinates) ---------- */
  const view = { cx: 0, cy: 0, scale: 60 };        // px per math unit
  let problem = null;                              // analyzeProblem result
  const toggles = { ...stateDefaults };
  let world = new THREE.Group();
  scene.add(world);
  let pinned = null;                               // movable point {x}
  let hover = null;                                // {x,y,px,py,onCurve}
  let needsRender = true;
  let disposed = false;
  let rafPending = false;

  const W = () => container.clientWidth || 1;
  const H = () => container.clientHeight || 1;
  /* math ⇄ screen (uniform scale ⇒ circles stay circles) */
  const toScreen = (mx, my) => [
    W() / 2 + (mx - view.cx) * view.scale,
    H() / 2 - (my - view.cy) * view.scale,
  ];
  const toMath = (px, py) => [
    view.cx + (px - W() / 2) / view.scale,
    view.cy - (py - H() / 2) / view.scale,
  ];

  function invalidate() {
    needsRender = true;
    if (!rafPending && !disposed) {
      rafPending = true;
      requestAnimationFrame(frame);
    }
  }
  function frame(ts) {
    rafPending = false;
    if (disposed) return;
    if (needsRender) { needsRender = false; render(ts || 0); }
  }

  /* ---------- camera fitting ---------- */
  function fitWindow(win, animate) {
    const sx = W() / Math.max(1e-9, win.xmax - win.xmin);
    const sy = H() / Math.max(1e-9, win.ymax - win.ymin);
    view.scale = Math.min(sx, sy) * 0.94;
    view.cx = (win.xmin + win.xmax) / 2;
    view.cy = (win.ymin + win.ymax) / 2;
    invalidate();
  }

  /* ---------- world construction (rebuilt per problem/theme) ---------- */
  function disposeWorld() {
    world.traverse((n) => {
      if (n.geometry) n.geometry.dispose();
      if (n.material) {
        if (Array.isArray(n.material)) n.material.forEach((m) => m.dispose());
        else n.material.dispose();
      }
    });
    scene.remove(world);
    world = new THREE.Group();
    scene.add(world);
    mathLabels = [];
    fixedChips = [];
    releaseChips();
  }

  function lineSeg(pts, mat) {
    const g = new THREE.BufferGeometry().setFromPoints(pts.map((p) => new THREE.Vector3(p[0], p[1], 0)));
    return new THREE.Line(g, mat);
  }
  function dashedLine(a, b, mat) {
    const l = lineSeg([a, b], mat);
    l.computeLineDistances();
    return l;
  }

  function buildWorld() {
    disposeWorld();
    const t = T();
    const win = problem.window;
    const ticks = niceTicks(win.xmin, win.xmax, Math.max(5, Math.round(W() / 110)));
    const ticksY = niceTicks(win.ymin, win.ymax, Math.max(4, Math.round(H() / 90)));

    /* grid: minor then major (visual hierarchy) */
    if (toggles.grid) {
      const gm = new THREE.LineBasicMaterial({ color: t.gridMin });
      const gM = new THREE.LineBasicMaterial({ color: t.gridMaj });
      const minor = [], major = [];
      for (const x of ticks.minors) {
        if (x < win.xmin || x > win.xmax) continue;
        minor.push(new THREE.Vector3(x, win.ymin, 0), new THREE.Vector3(x, win.ymax, 0));
      }
      for (const y of ticksY.minors) {
        if (y < win.ymin || y > win.ymax) continue;
        minor.push(new THREE.Vector3(win.xmin, y, 0), new THREE.Vector3(win.xmax, y, 0));
      }
      for (const x of ticks.majors) {
        if (x < win.xmin || x > win.xmax) continue;
        major.push(new THREE.Vector3(x, win.ymin, 0), new THREE.Vector3(x, win.ymax, 0));
      }
      for (const y of ticksY.majors) {
        if (y < win.ymin || y > win.ymax) continue;
        major.push(new THREE.Vector3(win.xmin, y, 0), new THREE.Vector3(win.xmax, y, 0));
      }
      if (minor.length) world.add(lineSeg(minor, gm));
      if (major.length) world.add(lineSeg(major, gM));
    }

    /* axes drawn at 0 when visible, otherwise pinned to the window edge */
    const axisMat = new THREE.LineBasicMaterial({ color: t.axis });
    const yAxisX = win.xmin <= 0 && win.xmax >= 0 ? 0 : (0 > win.xmax ? win.xmax : win.xmin);
    const xAxisY = win.ymin <= 0 && win.ymax >= 0 ? 0 : (0 > win.ymax ? win.ymax : win.ymin);
    world.add(lineSeg([[win.xmin, xAxisY], [win.xmax, xAxisY]], axisMat));
    world.add(lineSeg([[yAxisX, win.ymin], [yAxisX, win.ymax]], axisMat));
    // arrowheads as flat triangles
    const arrow = (x, y, dir) => {
      const s = 0.16 * (Math.max(win.xmax - win.xmin, win.ymax - win.ymin) / 24);
      const shape = new THREE.Shape();
      if (dir === "e") { shape.moveTo(x, y); shape.lineTo(x - s * 2, y + s * 0.6); shape.lineTo(x - s * 2, y - s * 0.6); }
      else { shape.moveTo(x, y); shape.lineTo(x + s * 0.6, y + s * 2); shape.lineTo(x - s * 0.6, y + s * 2); }
      const m = new THREE.Mesh(new THREE.ShapeGeometry(shape), new THREE.MeshBasicMaterial({ color: t.axis }));
      world.add(m);
    };
    arrow(win.xmax, xAxisY, "e");
    arrow(yAxisX, win.ymax, "n");

    /* curves (branches stay separate — never joined) */
    const curveMat = new THREE.LineBasicMaterial({ color: t.curve });
    const curveMat2 = new THREE.LineBasicMaterial({ color: t.curve });  // system second curve
    for (const seg of problem.segments) {
      const mat = seg.which === 1 ? curveMat2 : curveMat;
      world.add(lineSeg(seg.pts, mat));
    }
    if (problem.kind === "circle" && problem.features.center) {
      // circle segments already a closed loop; ensure smooth: drawn as segments above
    }

    /* inequality shading band */
    if (problem.band && problem.segments.length) {
      const rel = problem.band.rel;
      for (const seg of problem.segments) {
        const pts = seg.pts;
        if (pts.length < 2) continue;
        const shape = new THREE.Shape();
        const edge = rel.startsWith(">") ? win.ymax : win.ymin;
        shape.moveTo(pts[0][0], pts[0][1]);
        for (let i = 1; i < pts.length; i++) shape.lineTo(pts[i][0], pts[i][1]);
        shape.lineTo(pts[pts.length - 1][0], edge);
        shape.lineTo(pts[0][0], edge);
        const m = new THREE.Mesh(new THREE.ShapeGeometry(shape),
          new THREE.MeshBasicMaterial({ color: t.band, transparent: true, opacity: 0.16, side: THREE.DoubleSide, depthWrite: false }));
        world.add(m);
      }
    }

    /* asymptotes: dashed + distinct + labelled */
    const asyMat = new THREE.LineDashedMaterial({ color: t.asymptote, dashSize: 0.45, gapSize: 0.28 });
    const feats = problem.features || {};
    const half = Math.max(win.xmax - win.xmin, win.ymax - win.ymin);
    if (toggles.asymp) {
      for (const x of (problem.asymptotes.vertical || [])) {
        const l = dashedLine([x, win.ymin], [x, win.ymax], asyMat);
        world.add(l);
        addLabel("g3f", `x = ${fmtTick(x)} · asymptote`, x, win.ymax, t.asymptote, +10, -6);
      }
      for (const h of (problem.asymptotes.horizontal || [])) {
        if (h.y < win.ymin || h.y > win.ymax) continue;
        let x0 = win.xmin, x1 = win.xmax;
        if (h.sides === "+") x0 = Math.max(0, win.xmin);
        if (h.sides === "-") x1 = Math.min(0, win.xmax);
        if (x1 <= x0) continue;
        world.add(dashedLine([x0, h.y], [x1, h.y], asyMat));
        addLabel("g3f", `y = ${fmtTick(h.y)} · asymptote`, (x0 + x1) / 2, h.y, t.asymptote, 8, -22);
      }
      for (const ob of (problem.asymptotes.oblique || [])) {
        const xa = win.xmin, xb = win.xmax;
        world.add(dashedLine([xa, ob.m * xa + ob.c], [xb, ob.m * xb + ob.c], asyMat));
        addLabel("g3f", `y = ${fmtTick(ob.m)}x + ${fmtTick(ob.c)} · asymptote`,
          (xa + xb) / 2, ob.m * ((xa + xb) / 2) + ob.c, t.asymptote, 8, -22);
      }
      for (const hole of (feats.holes || [])) {
        const ring = new THREE.Mesh(new THREE.RingGeometry(half * 0.012, half * 0.018, 20),
          new THREE.MeshBasicMaterial({ color: t.root, side: THREE.DoubleSide }));
        ring.position.set(hole[0], hole[1], 0.01);
        world.add(ring);
        addLabel("g3f", `hole (${fmtTick(hole[0])}, ${fmtTick(hole[1])})`, hole[0], hole[1], t.root, 8, -20);
      }
    }

    /* feature markers + smart annotations (only what is relevant) */
    const dot = (x, y, color, rad) => {
      const m = new THREE.Mesh(new THREE.CircleGeometry(rad || 0.075 * (half / 40), 20),
        new THREE.MeshBasicMaterial({ color }));
      m.position.set(x, y, 0.02);
      world.add(m);
      return m;
    };
    if (toggles.labels) {
      (feats.roots || []).forEach((x) => {
        const y = problem.kind === "circle" ? null : 0;
        const yy = y !== null ? y : (feats.yint && Math.abs(x) < 1e-9 ? feats.yint[1] : 0);
        dot(x, yy === null ? 0 : yy, t.root);
        addLabel("g3f", `root (${fmtTick(x)}, 0)`, x, 0, t.root, 8, -12);
      });
      if (feats.yint) {
        dot(feats.yint[0], feats.yint[1], t.vertex);
        addLabel("g3f", `y-intercept (${fmtTick(feats.yint[0])}, ${fmtTick(feats.yint[1])})`,
          feats.yint[0], feats.yint[1], t.vertex, 10, -10);
      }
      if (feats.vertex) {
        dot(feats.vertex[0], feats.vertex[1], t.vertex, 0.1);
        addLabel("g3f", `vertex (${fmtTick(feats.vertex[0])}, ${fmtTick(feats.vertex[1])})`,
          feats.vertex[0], feats.vertex[1], t.vertex, 10, -12);
        if (feats.axis && /^x =/.test(feats.axis)) {
          const ax = Number(feats.axis.replace("x =", "").trim());
          if (Number.isFinite(ax) && ax >= win.xmin && ax <= win.xmax) {
            world.add(dashedLine([ax, win.ymin], [ax, win.ymax],
              new THREE.LineDashedMaterial({ color: t.muted, dashSize: 0.3, gapSize: 0.3 })));
            addLabel("g3f", `axis ${feats.axis}`, ax, win.ymax, t.muted, 6, -8);
          }
        }
      }
      (feats.extrema || []).forEach((e) => {
        if (feats.vertex && Math.abs(e[0] - feats.vertex[0]) < 1e-6) return;  // already shown
        dot(e[0], e[1], e[2] === "max" ? t.root : t.vertex, 0.075);
        addLabel("g3f", `${e[2] === "max" ? "max" : "min"} (${fmtTick(e[0])}, ${fmtTick(e[1])})`,
          e[0], e[1], e[2] === "max" ? t.root : t.vertex, 8, -12);
      });
      (problem.intersections || []).forEach((p) => {
        dot(p[0], p[1], t.asymptote, 0.09);
        addLabel("g3f", `intersect ${fmtCoord(p[0], p[1])}`, p[0], p[1], t.asymptote, 8, -14);
      });
      (feats.endpoints || []).forEach((e) => {
        dot(e[0], e[1], t.mark, 0.06);
        addLabel("g3f", `endpoint ${fmtCoord(e[0], e[1])}`, e[0], e[1], t.muted, 8, -14);
      });
      if (problem.kind === "circle" && problem.features.radius) {
        const [cx, cy] = problem.features.center;
        dot(cx, cy, t.vertex, 0.07);
        addLabel("g3f", `centre ${fmtCoord(cx, cy)}, r = ${fmtTick(problem.features.radius)}`, cx, cy, t.vertex, 8, -12);
      }
      /* axis tick numbers — math-anchored so they follow pan/zoom exactly;
         the origin label is drawn once to avoid duplicate/overlapping "0" */
      for (const x of ticks.majors) {
        if (x < win.xmin || x > win.xmax) continue;
        if (Math.abs(x) < 1e-12 && xAxisY === 0) continue;
        addLabel("g3t", fmtTick(x), x, xAxisY, t.axisText, -8, 14);
      }
      for (const y of ticksY.majors) {
        if (y < win.ymin || y > win.ymax) continue;
        if (Math.abs(y) < 1e-12 && xAxisY === 0 && yAxisX === 0) continue;
        addLabel("g3t", fmtTick(y), yAxisX, y, t.axisText, -30, -7);
      }
      addLabel("g3t", "0", yAxisX, xAxisY, t.axisText, -16, 14);
      addLabel("g3t", "x", win.xmax, xAxisY, t.axisText, 6, 14);
      addLabel("g3t", "y", yAxisX, win.ymax, t.axisText, -30, -22);
    }
    renderer.setClearColor(t.bg, 1);
    applyCamera();
  }

  /* label helpers: anchored in math space (re-projected every render) */
  let mathLabels = [];   // {el, mx, my, dx, dy, color, text}
  let fixedChips = [];   // {el, px, py, text, color}
  function addLabel(cls, text, mx, my, color, dx, dy) {
    const el = chip(cls);
    el.innerHTML = text;
    mathLabels.push({ el, mx, my, dx: dx || 0, dy: dy || 0, color });
  }
  function addChipAt(cls, text, px, py, color) {
    const el = chip(cls);
    el.textContent = text;
    fixedChips.push({ el, px, py, color });
  }

  function applyCamera() {
    const hw = (W() / 2) / view.scale, hh = (H() / 2) / view.scale;
    camera.left = view.cx - hw; camera.right = view.cx + hw;
    camera.top = view.cy + hh; camera.bottom = view.cy - hh;
    camera.updateProjectionMatrix();
  }

  function render(ts) {
    if (!problem) return;
    /* labels follow the math view */
    for (const l of mathLabels) {
      const [x, y] = toScreen(l.mx, l.my);
      l.el.style.transform = `translate(${x + l.dx}px, ${y + l.dy}px)`;
      chipStyle(l.el, 0, 0, l.color);
      l.el.style.transform = `translate(${Math.round(x + l.dx)}px, ${Math.round(y + l.dy)}px)`;
    }
    for (const c of fixedChips) {
      c.el.style.left = c.px + "px";
      c.el.style.top = c.py + "px";
      c.el.style.background = "transparent";
      c.el.style.borderColor = "transparent";
      c.el.style.color = c.color;
    }
    drawHoverChip();
    renderer.render(scene, camera);
    if (o.onFrame) o.onFrame(getState());
  }

  /* ---------- pointer: pan / zoom / inspect / movable point ---------- */
  const pointers = new Map();
  let pinch = 0;
  let dragging = false;

  function pickCurve(px, py) {
    if (!problem) return null;
    const [mx] = toMath(px, py);
    const tol = 6 / view.scale;                      // 6 px in math units
    let best = null;
    for (const seg of problem.segments) {
      for (const p of seg.pts) {
        const d = Math.abs(p[0] - mx);
        if (d < tol && (!best || d < best.d)) best = { x: p[0], y: p[1], d };
      }
    }
    return best;
  }

  function drawHoverChip() {
    let el = labs.querySelector(".g3r");
    if (!hover) { if (el) el.style.display = "none"; return; }
    if (!el) { el = document.createElement("div"); el.className = "g3r"; labs.appendChild(el); }
    const onCurve = hover.onCurve;
    el.textContent = onCurve ? `${fmtCoord(hover.x, hover.y)}  ·  f(${fmtTick(hover.x)}) = ${fmtTick(hover.y)}`
      : `x = ${fmtTick(hover.x)}, y = ${fmtTick(hover.y)}`;
    el.style.display = "block";
    el.style.left = Math.round(hover.px + 14) + "px";
    el.style.top = Math.round(hover.py - 30) + "px";
    el.style.background = T().chipBg;
    el.style.borderColor = onCurve ? T().curve : T().chipBorder;
    el.style.color = T().text;
  }

  function localXY(e) {
    const rect = renderer.domElement.getBoundingClientRect();
    return [e.clientX - rect.left, e.clientY - rect.top];
  }
  function onDown(e) {
    try { renderer.domElement.setPointerCapture && renderer.domElement.setPointerCapture(e.pointerId); }
    catch (err) { /* synthetic pointers from tests/assistive tech have no capture target */ }
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    dragging = pointers.size === 1;
    if (pointers.size === 2) {
      const a = [...pointers.values()];
      pinch = Math.hypot(a[0].x - a[1].x, a[0].y - a[1].y);
    }
  }
  function onMove(e) {
    const p = pointers.get(e.pointerId);
    if (!p) {
      // pure hover inspection
      const [px, py] = localXY(e);
      const hit = pickCurve(px, py);
      const [mx, my] = toMath(px, py);
      hover = { px, py, x: hit ? hit.x : mx, y: hit ? hit.y : my, onCurve: !!hit };
      invalidate();
      return;
    }
    const dx = e.clientX - p.x, dy = e.clientY - p.y;
    p.x = e.clientX; p.y = e.clientY;
    if (pointers.size === 1) {
      if (pinned) {
        const [px, py] = localXY(e);
        const hit = pickCurve(px, py);
        if (hit) pinned.x = hit.x;                    // slide the pinned point ALONG the curve
      } else {
        view.cx -= dx / view.scale;                    // pan keeps math meaning
        view.cy += dy / view.scale;
      }
      invalidate();
    } else if (pointers.size === 2 && pinch > 0) {
      const a = [...pointers.values()];
      const nd = Math.hypot(a[0].x - a[1].x, a[0].y - a[1].y);
      const rect = renderer.domElement.getBoundingClientRect();
      zoomAt((a[0].x + a[1].x) / 2 - rect.left, (a[0].y + a[1].y) / 2 - rect.top, nd / pinch);
      pinch = nd;
      invalidate();
    }
  }
  function onUp(e) {
    pointers.delete(e.pointerId);
    if (pointers.size < 2) pinch = 0;
    if (pointers.size === 0) dragging = false;
  }
  function onClick(e) {
    const [px, py] = localXY(e);
    const hit = pickCurve(px, py);
    if (hit) {
      pinned = { x: hit.x };
      if (o.onPick) o.onPick({ x: hit.x, y: hit.y });
      invalidate();
    } else if (pinned) { pinned = null; invalidate(); }
  }
  function onWheel(e) {
    e.preventDefault();
    const [px, py] = localXY(e);
    zoomAt(px, py, Math.exp(-e.deltaY * 0.0014));
  }
  function zoomAt(px, py, k) {
    const [mx, my] = toMath(px, py);
    const ns = Math.min(4000, Math.max(6, view.scale * k));
    const kk = ns / view.scale;
    view.cx = mx - (mx - view.cx) / kk;               // point under cursor stays fixed
    view.cy = my - (my - view.cy) / kk;
    view.scale = ns;
    invalidate();
  }

  renderer.domElement.addEventListener("pointerdown", onDown);
  renderer.domElement.addEventListener("pointermove", onMove);
  renderer.domElement.addEventListener("pointerup", onUp);
  renderer.domElement.addEventListener("pointercancel", onUp);
  renderer.domElement.addEventListener("click", onClick);
  renderer.domElement.addEventListener("wheel", onWheel, { passive: false });
  renderer.domElement.style.touchAction = "none";
  renderer.domElement.style.cursor = "crosshair";

  /* ---------- public API ---------- */
  function setProblem(def, opts2) {
    const res = analyzeProblem(def, opts2 || {});
    if (!res.ok) {
      problem = null;
      if (o.onLimitation) o.onLimitation(res.error || "unsupported expression");
      invalidate();
      return res;
    }
    problem = res;
    pinned = null;
    hover = null;
    mathLabels = [];
    fixedChips = [];
    buildWorld();
    fitWindow(res.window);
    invalidate();
    if (o.onFrame) o.onFrame(getState());
    return res;
  }

  function getState() {
    if (!problem) return { ok: false };
    const f = problem.features || {};
    return {
      ok: true, kind: problem.kind, norm: problem.norm || problem.labelNote,
      roots: (f.roots || []).map((x) => Math.round(x * 1e4) / 1e4),
      vertex: f.vertex ? f.vertex.map((v) => Math.round(v * 1e4) / 1e4) : null,
      axis: f.axis || null, yint: f.yint ? f.yint.map((v) => Math.round(v * 1e4) / 1e4) : null,
      extrema: (f.extrema || []).length, holes: (f.holes || []).length,
      asymp: {
        v: (problem.asymptotes.vertical || []).map((x) => Math.round(x * 1e4) / 1e4),
        h: (problem.asymptotes.horizontal || []).map((h) => Math.round(h.y * 1e4) / 1e4),
        o: (problem.asymptotes.oblique || []).map((ob) => Math.round(ob.m * 1e4) / 1e4),
      },
      intersections: (problem.intersections || []).length,
      scale: Math.round(view.scale * 100) / 100,
      center: [Math.round(view.cx * 100) / 100, Math.round(view.cy * 100) / 100],
      pinned: pinned ? Math.round(pinned.x * 100) / 100 : null,
      theme: themeName, labels: toggles.labels, grid: toggles.grid,
      asympOn: toggles.asymp,          // boolean toggle (counts stay in asymp above)
      labelsMounted: mathLabels.length + fixedChips.length,
    };
  }

  /* synchronise: highlight graph features named in written solution steps */
  function highlightFromText(texts) {
    if (!problem) return;
    const all = String((texts || []).join(" "));
    const want = [];
    const num = (s) => Number(s.replace(/[−–]/g, "-"));
    const re = /\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)/g;
    let m;
    while ((m = re.exec(all))) want.push([num(m[1]), num(m[2])]);
    if (o.onSyncHighlight) o.onSyncHighlight(want);
    invalidate();
    return want;
  }

  function resize() {
    renderer.setSize(W(), H(), false);
    applyCamera();
    buildWorld();          // tick/label layout depends on pixel size
    invalidate();
  }

  function setTheme(name) {
    themeName = name === "dark" ? "dark" : "light";
    container.style.background = T().bg;
    if (problem) { buildWorld(); invalidate(); }
  }
  function setToggle(key, value) {
    toggles[key] = !!value;
    if (problem) { buildWorld(); invalidate(); }
  }

  const ro = ("ResizeObserver" in window) ? new ResizeObserver(() => resize()) : null;
  if (ro) ro.observe(container); else window.addEventListener("resize", resize);

  container.style.position = container.style.position || "relative";
  container.style.background = T().bg;
  renderer.setSize(W(), H(), false);

  function dispose() {
    disposed = true;
    renderer.domElement.removeEventListener("pointerdown", onDown);
    renderer.domElement.removeEventListener("pointermove", onMove);
    renderer.domElement.removeEventListener("pointerup", onUp);
    renderer.domElement.removeEventListener("pointercancel", onUp);
    renderer.domElement.removeEventListener("click", onClick);
    renderer.domElement.removeEventListener("wheel", onWheel);
    if (ro) ro.disconnect(); else window.removeEventListener("resize", resize);
    disposeWorld();
    if (renderer.domElement.parentNode) renderer.domElement.parentNode.removeChild(renderer.domElement);
    if (labs.parentNode) labs.parentNode.removeChild(labs);
    renderer.dispose();
  }

  return {
    setProblem, setTheme, setToggle, getState, resize, dispose,
    zoomIn: () => { zoomAt(W() / 2, H() / 2, 1.25); },
    zoomOut: () => { zoomAt(W() / 2, H() / 2, 0.8); },
    panBy: (dx, dy) => { view.cx -= dx / view.scale; view.cy += dy / view.scale; invalidate(); },
    resetView: () => { if (problem) fitWindow(problem.window); },
    focusWindow: (win) => fitWindow(win),
    highlightFromText,
    setPinned: (x) => { pinned = x === null ? null : { x }; invalidate(); },
    renderer, scene, camera, view, toggles,
  };
}
