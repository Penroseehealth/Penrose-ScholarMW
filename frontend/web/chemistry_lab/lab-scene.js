/**
 * Penrose ScholarMW — Chemistry Lab 3D adapter.
 *
 * Loaded lazily (script tag injected by Dart) ONLY when the Chemistry Lab opens.
 * Static-imports ./three.module.min.js (three.js 0.169.0, MIT — see THREE-LICENSE.txt).
 *
 * Contract with Flutter/Dart (documented in lib/modules/chemistry_lab/docs/INTEGRATION.md):
 *   Dart -> JS : window.PenroseChemLab.handle(jsonString)   // single command entry
 *   JS   -> Dart: window.__penroseChemLabEvent(type, json)  // registered by Dart before load
 *                 window.__penroseChemLabEngineLoaded()     // API object is ready
 *
 * Commands: init, dispose, loadExperiment, loadModel, play, pause, resume,
 *           reset, replay, setSpeed, setLabelsVisible, updateParams, selectObject.
 * Events:   engineLoaded, ready, error, stateChanged, selection, progress.
 *
 * Science lives in Dart: this file only interpolates visual state sent by Dart.
 */
import * as THREE from './three.module.min.js';

const API_VERSION = '1.0.0';

// ── Event emission to Dart ──────────────────────────────────────────────────

function emit(type, payload) {
  const sink = window.__penroseChemLabEvent;
  if (typeof sink === 'function') {
    try {
      sink(type, JSON.stringify(payload || {}));
    } catch (_) {
      /* never let a bridge error break rendering */
    }
  }
}

function fail(code, message, detail) {
  emit('error', { code: code, message: message, detail: detail || null });
  console.error('[PenroseChemLab]', code, message, detail || '');
}

// ── Engine state ────────────────────────────────────────────────────────────

const engine = {
  hostId: null,
  host: null,
  renderer: null,
  scene: null,
  camera: null,
  labelsLayer: null,
  resizeObserver: null,
  rafId: 0,
  disposed: true,
  running: false, // render loop active
  animating: false, // parameter interpolation allowed (play/pause)
  speed: 1.0,
  labelsVisible: true,
  objects: new Map(), // id -> { mesh, label, labelEl, initial, target }
  selectableIds: [],
  selectedId: null,
  initialCamera: null,
  lastFrameTime: 0,
};

// ── WebGL capability check ──────────────────────────────────────────────────

function webglSupported() {
  try {
    const canvas = document.createElement('canvas');
    return !!(
      window.WebGLRenderingContext &&
      (canvas.getContext('webgl2') || canvas.getContext('webgl'))
    );
  } catch (_) {
    return false;
  }
}

// ── Orbit-style camera controls (custom: no external examples/jsm deps) ─────

const controls = {
  target: new THREE.Vector3(0, 1, 0),
  theta: 0.7, // azimuth
  phi: 1.15, // polar (0..PI)
  radius: 14,
  // damped goals
  gTheta: 0.7,
  gPhi: 1.15,
  gRadius: 14,
  gTarget: new THREE.Vector3(0, 1, 0),
  minRadius: 3,
  maxRadius: 60,
  minPhi: 0.15,
  maxPhi: Math.PI - 0.15,
  pointers: new Map(),
  pinchDistance: 0,
  mode: null, // 'rotate' | 'pan'
  lastX: 0,
  lastY: 0,
  moved: 0,
  downTime: 0,
  listeners: [],
};

function addListener(target, type, fn, opts) {
  target.addEventListener(type, fn, opts);
  controls.listeners.push([target, type, fn, opts]);
}

function applyCameraFromControls(dt) {
  const k = 1 - Math.exp(-12 * dt);
  controls.theta += (controls.gTheta - controls.theta) * k;
  controls.phi += (controls.gPhi - controls.phi) * k;
  controls.radius += (controls.gRadius - controls.radius) * k;
  controls.target.lerp(controls.gTarget, k);
  const sp = Math.sin(controls.phi);
  engine.camera.position.set(
    controls.target.x + controls.radius * sp * Math.sin(controls.theta),
    controls.target.y + controls.radius * Math.cos(controls.phi),
    controls.target.z + controls.radius * sp * Math.cos(controls.theta),
  );
  engine.camera.lookAt(controls.target);
}

function zoomBy(factor) {
  controls.gRadius = THREE.MathUtils.clamp(
    controls.gRadius * factor,
    controls.minRadius,
    controls.maxRadius,
  );
}

function onPointerDown(ev) {
  if (!engine.running) return;
  const el = engine.renderer.domElement;
  el.setPointerCapture && el.setPointerCapture(ev.pointerId);
  controls.pointers.set(ev.pointerId, { x: ev.clientX, y: ev.clientY });
  controls.moved = 0;
  controls.downTime = performance.now();
  if (controls.pointers.size === 1) {
    controls.mode = ev.button === 2 || ev.shiftKey ? 'pan' : 'rotate';
    controls.lastX = ev.clientX;
    controls.lastY = ev.clientY;
  } else if (controls.pointers.size === 2) {
    controls.mode = 'pinch';
    const pts = Array.from(controls.pointers.values());
    controls.pinchDistance = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
  }
  ev.preventDefault();
}

function onPointerMove(ev) {
  if (!engine.running || !controls.pointers.has(ev.pointerId)) return;
  const prev = controls.pointers.get(ev.pointerId);
  const dx = ev.clientX - prev.x;
  const dy = ev.clientY - prev.y;
  controls.pointers.set(ev.pointerId, { x: ev.clientX, y: ev.clientY });
  controls.moved += Math.abs(dx) + Math.abs(dy);

  if (controls.mode === 'pinch' && controls.pointers.size === 2) {
    const pts = Array.from(controls.pointers.values());
    const dist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
    if (controls.pinchDistance > 0) zoomBy(controls.pinchDistance / dist);
    controls.pinchDistance = dist;
    return;
  }
  if (controls.mode === 'rotate') {
    controls.gTheta -= dx * 0.006;
    controls.gPhi = THREE.MathUtils.clamp(controls.gPhi - dy * 0.006, controls.minPhi, controls.maxPhi);
  } else if (controls.mode === 'pan') {
    panBy(dx, dy);
  }
}

function panBy(dx, dy) {
  const cam = engine.camera;
  const dist = cam.position.distanceTo(controls.target);
  const fovScale = 2 * Math.tan((cam.fov * Math.PI) / 360) * dist;
  const height = engine.renderer.domElement.clientHeight || 1;
  const width = engine.renderer.domElement.clientWidth || 1;
  const right = new THREE.Vector3().setFromMatrixColumn(cam.matrix, 0);
  const up = new THREE.Vector3().setFromMatrixColumn(cam.matrix, 1);
  const factor = (fovScale * dx) / width;
  const vFactor = (fovScale * dy) / height;
  controls.gTarget.addScaledVector(right, -factor);
  controls.gTarget.addScaledVector(up, vFactor);
}

function onPointerUp(ev) {
  controls.pointers.delete(ev.pointerId);
  if (controls.pointers.size === 0) {
    const isTap = controls.moved < 8 && performance.now() - controls.downTime < 450 && ev.button !== 2;
    controls.mode = null;
    if (isTap) pickAt(ev.clientX, ev.clientY);
  } else if (controls.pointers.size === 1) {
    controls.mode = 'rotate';
    const only = Array.from(controls.pointers.values())[0];
    controls.lastX = only.x;
    controls.lastY = only.y;
  }
}

function onWheel(ev) {
  if (!engine.running) return;
  ev.preventDefault();
  zoomBy(ev.deltaY > 0 ? 1.12 : 0.89);
}

function onContextMenu(ev) {
  ev.preventDefault();
}

function onKeyDown(ev) {
  if (!engine.running) return;
  const step = ev.shiftKey ? 0.25 : 0.09;
  switch (ev.key) {
    case 'ArrowLeft':
      controls.gTheta += step;
      break;
    case 'ArrowRight':
      controls.gTheta -= step;
      break;
    case 'ArrowUp':
      controls.gPhi = THREE.MathUtils.clamp(controls.gPhi - step, controls.minPhi, controls.maxPhi);
      break;
    case 'ArrowDown':
      controls.gPhi = THREE.MathUtils.clamp(controls.gPhi + step, controls.minPhi, controls.maxPhi);
      break;
    case '+':
    case '=':
      zoomBy(0.88);
      break;
    case '-':
    case '_':
      zoomBy(1.14);
      break;
    case 'Escape':
      selectObject(null);
      return;
    default:
      return;
  }
  ev.preventDefault();
}

function bindInput() {
  const el = engine.renderer.domElement;
  addListener(el, 'pointerdown', onPointerDown, { passive: false });
  addListener(el, 'pointermove', onPointerMove, { passive: false });
  addListener(el, 'pointerup', onPointerUp);
  addListener(el, 'pointercancel', onPointerUp);
  addListener(el, 'wheel', onWheel, { passive: false });
  addListener(el, 'contextmenu', onContextMenu);
  addListener(el, 'keydown', onKeyDown);
}

function unbindInput() {
  for (const [target, type, fn, opts] of controls.listeners) {
    target.removeEventListener(type, fn, opts);
  }
  controls.listeners = [];
  controls.pointers.clear();
  controls.mode = null;
}

// ── Picking / selection ─────────────────────────────────────────────────────

const raycaster = new THREE.Raycaster();
const ndc = new THREE.Vector2();

function pickAt(clientX, clientY) {
  const rect = engine.renderer.domElement.getBoundingClientRect();
  ndc.x = ((clientX - rect.left) / rect.width) * 2 - 1;
  ndc.y = -((clientY - rect.top) / rect.height) * 2 + 1;
  raycaster.setFromCamera(ndc, engine.camera);
  const meshes = engine.selectableIds.map((id) => engine.objects.get(id)).filter(Boolean).map((r) => r.mesh);
  const hits = raycaster.intersectObjects(meshes, false);
  selectObject(hits.length ? hits[0].object.userData.labId : null);
}

function applyHighlight() {
  for (const [id, rec] of engine.objects) {
    if (!rec.selectable) continue;
    const mat = rec.mesh.material;
    if (!mat) continue;
    if (id === engine.selectedId) {
      mat.emissive && mat.emissive.setHex(0x554422);
    } else if (mat.emissive) {
      mat.emissive.setHex(rec.initialEmissive || 0x000000);
    }
  }
}

function selectObject(id) {
  if (id !== null && !engine.objects.has(String(id))) id = null;
  engine.selectedId = id === null ? null : String(id);
  applyHighlight();
  const rec = engine.selectedId ? engine.objects.get(engine.selectedId) : null;
  emit('selection', {
    id: engine.selectedId,
    name: rec ? rec.name : null,
    kind: rec ? rec.kind : null,
  });
}

// ── Scene construction ──────────────────────────────────────────────────────

function makeGeometry(def) {
  const p = def.params || {};
  // Guard: a non-finite authored parameter would produce a NaN
  // BufferGeometry (three.js then warns "Computed radius is NaN" and the
  // object vanishes). Fail loudly in the console naming the object.
  for (const key of Object.keys(p)) {
    const v = p[key];
    if (typeof v === 'number' && !isFinite(v)) {
      fail('bad-scene-spec', 'Object "' + def.id + '" has non-finite param ' + key + '=' + v);
      p[key] = 0;
    }
  }
  switch (def.type) {
    case 'box':
      return new THREE.BoxGeometry(p.width || 1, p.height || 1, p.depth || 1);
    case 'sphere':
      return new THREE.SphereGeometry(p.radius || 0.5, p.widthSegments || 32, p.heightSegments || 20);
    case 'cone':
      return new THREE.ConeGeometry(p.radius || 0.5, p.height || 1, p.radialSegments || 32);
    case 'torus':
      return new THREE.TorusGeometry(p.radius || 0.5, p.tube || 0.1, p.radialSegments || 16, p.tubularSegments || 48);
    case 'cylinder':
    default:
      return new THREE.CylinderGeometry(
        p.radiusTop !== undefined ? p.radiusTop : p.radius || 0.5,
        p.radiusBottom !== undefined ? p.radiusBottom : p.radius || 0.5,
        p.height || 1,
        p.radialSegments || 32,
        p.openEnded || false,
      );
  }
}

function makeMaterial(def) {
  const transparent = def.opacity !== undefined && def.opacity < 1;
  return new THREE.MeshStandardMaterial({
    color: new THREE.Color(def.color || '#8899aa'),
    roughness: def.roughness !== undefined ? def.roughness : 0.55,
    metalness: def.metalness !== undefined ? def.metalness : 0.05,
    transparent: transparent,
    opacity: def.opacity !== undefined ? def.opacity : 1,
    side: def.doubleSided ? THREE.DoubleSide : THREE.FrontSide,
    depthWrite: def.depthWrite !== undefined ? def.depthWrite : !transparent,
  });
}

function clearScene() {
  for (const [, rec] of engine.objects) {
    if (rec.labelEl && rec.labelEl.parentNode) rec.labelEl.parentNode.removeChild(rec.labelEl);
    engine.scene.remove(rec.mesh);
    rec.mesh.geometry && rec.mesh.geometry.dispose();
    rec.mesh.material && rec.mesh.material.dispose();
  }
  engine.objects.clear();
  engine.selectableIds = [];
  engine.selectedId = null;
}

function snapshotInitial(rec) {
  const m = rec.mesh;
  return {
    position: m.position.clone(),
    rotation: m.rotation.clone(),
    scale: m.scale.clone(),
    color: m.material.color.clone(),
    opacity: m.material.opacity,
    visible: m.visible,
    emissive: m.material.emissive ? m.material.emissive.clone() : null,
  };
}

function buildObject(def) {
  const geometry = makeGeometry(def);
  const material = makeMaterial(def);
  const mesh = new THREE.Mesh(geometry, material);
  mesh.userData.labId = def.id;
  if (def.position) mesh.position.fromArray(def.position);
  if (def.rotation) mesh.rotation.fromArray(def.rotation);
  if (def.scale !== undefined) {
    if (Array.isArray(def.scale)) mesh.scale.fromArray(def.scale);
    else mesh.scale.setScalar(def.scale);
  }
  mesh.visible = def.visible !== false;

  const rec = {
    mesh: mesh,
    name: def.name || def.id,
    kind: def.kind || 'apparatus',
    selectable: def.selectable !== false,
    label: def.label || null,
    labelOffset: def.labelOffset || [0, 0.6, 0],
    labelEl: null,
    initial: null,
    target: null,
    initialEmissive: material.emissive ? material.emissive.getHex() : 0,
  };
  rec.initial = snapshotInitial(rec);
  rec.target = null;
  engine.objects.set(def.id, rec);
  if (rec.selectable) engine.selectableIds.push(def.id);

  if (rec.label) {
    const el = document.createElement('div');
    el.className = 'pcl-label';
    el.textContent = rec.label;
    el.style.display = engine.labelsVisible ? 'block' : 'none';
    engine.labelsLayer.appendChild(el);
    rec.labelEl = el;
  }
  engine.scene.add(mesh);
  return rec;
}

function buildLabelsLayer() {
  if (engine.labelsLayer) return;
  const layer = document.createElement('div');
  layer.className = 'pcl-labels';
  layer.style.cssText =
    'position:absolute;inset:0;pointer-events:none;overflow:hidden;' +
    'font-family:Inter,sans-serif;font-size:12px;z-index:2;';
  engine.host.appendChild(layer);
  engine.labelsLayer = layer;
}

const _v = new THREE.Vector3();

function updateLabels() {
  if (!engine.labelsVisible) return;
  const rect = engine.renderer.domElement.getBoundingClientRect();
  const hostRect = engine.host.getBoundingClientRect();
  const offX = rect.left - hostRect.left;
  const offY = rect.top - hostRect.top;
  for (const [, rec] of engine.objects) {
    if (!rec.labelEl) continue;
    if (!rec.mesh.visible) {
      rec.labelEl.style.display = 'none';
      continue;
    }
    _v.set(rec.labelOffset[0], rec.labelOffset[1], rec.labelOffset[2]);
    rec.mesh.localToWorld(_v);
    _v.project(engine.camera);
    if (_v.z > 1 || _v.z < -1) {
      rec.labelEl.style.display = 'none';
      continue;
    }
    rec.labelEl.style.display = 'block';
    rec.labelEl.style.left = offX + ((_v.x + 1) / 2) * rect.width + 'px';
    rec.labelEl.style.top = offY + ((1 - _v.y) / 2) * rect.height + 'px';
    rec.labelEl.style.transform = 'translate(-50%,-120%)';
  }
}

// ── Parameter interpolation (visual animation driven by Dart) ───────────────

function applyParams(params) {
  if (!params || !params.objects) return;
  for (const [id, props] of Object.entries(params.objects)) {
    const rec = engine.objects.get(id);
    if (!rec) continue;
    rec.target = Object.assign({}, rec.target, props);
    if (!engine.animating) snapTarget(rec); // paused: apply immediately at low level? keep queued
  }
}

function snapTarget(rec) {
  // Apply the target instantly (used by reset and by explicit snaps).
  const t = rec.target;
  if (!t) return;
  applyTargetToMesh(rec.mesh, t, 1);
}

function applyTargetToMesh(mesh, t, k) {
  if (t.position) {
    const goal = Array.isArray(t.position) ? t.position : t.position.elements || null;
    if (goal) {
      const gp = Array.isArray(t.position) ? t.position : [t.position.x, t.position.y, t.position.z];
      mesh.position.x += (gp[0] - mesh.position.x) * k;
      mesh.position.y += (gp[1] - mesh.position.y) * k;
      mesh.position.z += (gp[2] - mesh.position.z) * k;
    }
  }
  if (t.scale !== undefined) {
    const goal = Array.isArray(t.scale) ? t.scale : [t.scale, t.scale, t.scale];
    mesh.scale.x += (goal[0] - mesh.scale.x) * k;
    mesh.scale.y += (goal[1] - mesh.scale.y) * k;
    mesh.scale.z += (goal[2] - mesh.scale.z) * k;
  }
  if (t.color && mesh.material.color) {
    mesh.material.color.lerp(new THREE.Color(t.color), k);
  }
  if (t.opacity !== undefined && mesh.material.transparent) {
    mesh.material.opacity += (t.opacity - mesh.material.opacity) * k;
  }
  if (t.visible !== undefined) mesh.visible = !!t.visible;
}

function interpolateTargets(dt) {
  if (!engine.animating) return;
  const k = 1 - Math.exp(-6 * engine.speed * dt);
  for (const [, rec] of engine.objects) {
    if (!rec.target) continue;
    applyTargetToMesh(rec.mesh, rec.target, k);
  }
}

// ── Render loop ─────────────────────────────────────────────────────────────

function frame(now) {
  engine.rafId = requestAnimationFrame(frame);
  const dt = Math.min((now - engine.lastFrameTime) / 1000, 0.1);
  engine.lastFrameTime = now;
  applyCameraFromControls(dt);
  interpolateTargets(dt);
  engine.renderer.render(engine.scene, engine.camera);
  updateLabels();
}

function startLoop() {
  if (engine.running) return;
  engine.running = true;
  engine.lastFrameTime = performance.now();
  engine.rafId = requestAnimationFrame(frame);
}

function stopLoop() {
  engine.running = false;
  if (engine.rafId) cancelAnimationFrame(engine.rafId);
  engine.rafId = 0;
}

// ── Resize ──────────────────────────────────────────────────────────────────

function handleResize() {
  if (!engine.renderer || !engine.host) return;
  const w = engine.host.clientWidth || 1;
  const h = engine.host.clientHeight || 1;
  engine.renderer.setSize(w, h, false);
  engine.camera.aspect = w / h;
  engine.camera.updateProjectionMatrix();
}

function onContextLost(ev) {
  ev.preventDefault();
  stopLoop();
  fail('context-lost', 'The WebGL context was lost. Close and reopen the laboratory to reinitialise it.');
}

// ── Commands ────────────────────────────────────────────────────────────────

function cmdInit(msg) {
  if (!webglSupported()) {
    fail('no-webgl', 'This browser does not support WebGL, so the 3D laboratory cannot start.');
    return;
  }
  if (!engine.disposed) cmdDispose();
  const host = document.getElementById(msg.hostId);
  if (!host) {
    fail('host-missing', '3D viewport host element was not found: ' + msg.hostId);
    return;
  }
  engine.hostId = msg.hostId;
  engine.host = host;
  engine.disposed = false;
  engine.animating = false;
  engine.speed = 1.0;
  engine.labelsVisible = true;

  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: 'high-performance' });
  } catch (e) {
    fail('renderer-failed', 'Could not create the WebGL renderer.', String(e));
    engine.disposed = true;
    return;
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.domElement.style.cssText = 'display:block;width:100%;height:100%;outline:none;touch-action:none;';
  renderer.domElement.setAttribute('tabindex', '0');
  renderer.domElement.setAttribute('aria-label', '3D chemistry viewport. Use arrow keys to rotate, plus and minus to zoom.');
  engine.renderer = renderer;
  // Attach the canvas to the host element — without this the scene renders
  // into a detached canvas ("renders" with nothing visible).
  engine.host.replaceChildren(renderer.domElement);

  engine.scene = new THREE.Scene();
  engine.scene.background = new THREE.Color('#0b0e17');

  engine.camera = new THREE.PerspectiveCamera(45, 1, 0.1, 500);
  controls.gTheta = controls.theta = 0.7;
  controls.gPhi = controls.phi = 1.15;
  controls.gRadius = controls.radius = 14;
  controls.gTarget.set(0, 1, 0);
  controls.target.set(0, 1, 0);

  buildLabelsLayer();
  engine.labelsLayer.innerHTML = '';
  // Re-append the label layer after the fresh canvas so labels stack above.
  if (engine.labelsLayer.previousSibling !== renderer.domElement) {
    engine.host.appendChild(engine.labelsLayer);
  }


  // Lighting: key + fill + ambient (cheap, no shadow maps for performance).
  const ambient = new THREE.AmbientLight(0xffffff, 0.55);
  const key = new THREE.DirectionalLight(0xffffff, 1.1);
  key.position.set(6, 10, 4);
  const fill = new THREE.DirectionalLight(0x88aaff, 0.35);
  fill.position.set(-6, 4, -6);
  engine.scene.add(ambient, key, fill);

  // Floor / bench: a subtle grid so camera motion is perceptible.
  const grid = new THREE.GridHelper(24, 24, 0x2a3350, 0x1a2036);
  grid.userData.labId = '__floor';
  engine.scene.add(grid);

  handleResize();
  engine.resizeObserver = new ResizeObserver(handleResize);
  engine.resizeObserver.observe(engine.host);
  renderer.domElement.addEventListener('webglcontextlost', onContextLost);
  bindInput();
  startLoop();

  emit('ready', { version: API_VERSION });
}

function cmdLoadExperiment(msg) {
  if (engine.disposed) {
    fail('not-initialised', 'loadExperiment received before init.');
    return;
  }
  emit('progress', { value: 0.1, message: 'Building apparatus…' });
  clearScene();
  engine.labelsLayer.innerHTML = '';
  const spec = msg.spec || {};
  const objs = spec.objects || [];
  for (const def of objs) buildObject(def);
  if (spec.camera) {
    if (spec.camera.position) {
      controls.gTarget.set(
        (spec.camera.target && spec.camera.target[0]) || 0,
        (spec.camera.target && spec.camera.target[1]) || 1,
        (spec.camera.target && spec.camera.target[2]) || 0,
      );
      controls.target.copy(controls.gTarget);
      const p = spec.camera.position;
      const rel = new THREE.Vector3(p[0] - controls.target.x, p[1] - controls.target.y, p[2] - controls.target.z);
      controls.gRadius = controls.radius = rel.length();
      controls.gPhi = controls.phi = Math.acos(THREE.MathUtils.clamp(rel.y / controls.radius, -1, 1));
      controls.gTheta = controls.theta = Math.atan2(rel.x, rel.z);
    }
    if (spec.camera.background && engine.scene) {
      engine.scene.background = new THREE.Color(spec.camera.background);
    }
  }
  emit('progress', { value: 1, message: 'Ready' });
  emit('stateChanged', { state: 'ready' });
}

function cmdLoadModel(msg) {
  if (engine.disposed) return;
  // GLTF/GLB support is a Stage 6 extension: vendoring GLTFLoader requires an
  // import-path rewrite, so report a precise, actionable error until then.
  fail(
    'model-loader-unavailable',
    '3D model loading (GLB/GLTF) is not enabled in this build. Use built-in apparatus instead.',
    String(msg.url || ''),
  );
}

function restoreInitial() {
  for (const [, rec] of engine.objects) {
    const i = rec.initial;
    rec.mesh.position.copy(i.position);
    rec.mesh.rotation.copy(i.rotation);
    rec.mesh.scale.copy(i.scale);
    rec.mesh.material.color.copy(i.color);
    rec.mesh.material.opacity = i.opacity;
    rec.mesh.visible = i.visible;
    if (i.emissive && rec.mesh.material.emissive) rec.mesh.material.emissive.copy(i.emissive);
    rec.target = null;
  }
}

const stateCommands = {
  play: function () {
    engine.animating = true;
    emit('stateChanged', { state: 'running' });
  },
  pause: function () {
    engine.animating = false;
    emit('stateChanged', { state: 'paused' });
  },
  resume: function () {
    engine.animating = true;
    emit('stateChanged', { state: 'running' });
  },
  reset: function () {
    engine.animating = false;
    restoreInitial();
    emit('stateChanged', { state: 'ready' });
  },
  replay: function () {
    restoreInitial();
    engine.animating = true;
    emit('stateChanged', { state: 'running' });
  },
};

function cmdSetSpeed(msg) {
  const v = Number(msg.value);
  if (isFinite(v) && v > 0) engine.speed = Math.min(v, 8);
}

function cmdSetLabels(msg) {
  engine.labelsVisible = !!msg.visible;
  if (engine.labelsLayer) engine.labelsLayer.style.display = engine.labelsVisible ? 'block' : 'none';
}

function cmdDispose() {
  stopLoop();
  unbindInput();
  if (engine.resizeObserver) {
    engine.resizeObserver.disconnect();
    engine.resizeObserver = null;
  }
  if (engine.renderer) {
    engine.renderer.domElement.removeEventListener('webglcontextlost', onContextLost);
  }
  if (engine.scene) clearScene();
  if (engine.labelsLayer && engine.labelsLayer.parentNode) {
    engine.labelsLayer.parentNode.removeChild(engine.labelsLayer);
    engine.labelsLayer = null;
  }
  if (engine.renderer) {
    engine.renderer.dispose();
    if (engine.renderer.domElement.parentNode) {
      engine.renderer.domElement.parentNode.removeChild(engine.renderer.domElement);
    }
    engine.renderer.forceContextLoss && engine.renderer.forceContextLoss();
    engine.renderer = null;
  }
  engine.scene = null;
  engine.camera = null;
  engine.host = null;
  engine.hostId = null;
  engine.disposed = true;
  engine.animating = false;
}

const handlers = {
  init: cmdInit,
  dispose: cmdDispose,
  loadExperiment: cmdLoadExperiment,
  loadModel: cmdLoadModel,
  play: stateCommands.play,
  pause: stateCommands.pause,
  resume: stateCommands.resume,
  reset: stateCommands.reset,
  replay: stateCommands.replay,
  setSpeed: cmdSetSpeed,
  setLabelsVisible: cmdSetLabels,
  updateParams: function (msg) {
    if (!engine.disposed) applyParams(msg.params);
  },
  selectObject: function (msg) {
    if (!engine.disposed) selectObject(msg.id === undefined ? null : msg.id);
  },
};

function handle(jsonString) {
  let msg;
  try {
    msg = JSON.parse(jsonString);
  } catch (e) {
    fail('bad-command', 'Command payload was not valid JSON.', String(e));
    return;
  }
  const fn = handlers[msg.cmd];
  if (!fn) {
    fail('unknown-command', 'Unknown command: ' + String(msg.cmd));
    return;
  }
  try {
    fn(msg);
  } catch (e) {
    fail('command-failed', 'Command ' + msg.cmd + ' failed.', String((e && e.stack) || e));
  }
}

window.PenroseChemLab = {
  version: API_VERSION,
  handle: handle,
  webglSupported: webglSupported,
};

if (typeof window.__penroseChemLabEngineLoaded === 'function') {
  window.__penroseChemLabEngineLoaded();
}
emit('engineLoaded', { version: API_VERSION });
