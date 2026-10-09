/**
 * Penrose ScholarMW — Biology Lab 3D engine.
 *
 * Loaded lazily (script tag injected by Dart) ONLY when the Biology 3D
 * Laboratory opens. Static-imports ./three.module.min.js (three.js 0.169,
 * MIT — see THREE-LICENSE.txt).
 *
 * Contract with Flutter/Dart (documented in
 * lib/modules/biology_lab/docs/INTEGRATION.md):
 *   Dart -> JS : window.PenroseBioLab.handle(jsonString)   // single command entry
 *   JS   -> Dart: window.__penroseBioLabEvent(type, json)  // registered by Dart before load
 *                 window.__penroseBioLabEngineLoaded()     // API object is ready
 *
 * Flutter owns navigation, UI, the biological asset registry and all
 * educational content. This file owns the 3D scene: renderer, camera,
 * picking, HTML labels, keyframe animation, and the Mol* molecular-viewer
 * iframe for the molecular level. Every scene is an educational
 * reconstruction described by the spec Dart sends — this file never
 * invents biology.
 */
import * as THREE from './three.module.min.js';

const API_VERSION = '1.0.0';
const BG_DEFAULT = '#0b1220';
const ACCENT = '#7c4dff';

// ── Event emission to Dart ──────────────────────────────────────────────────

function emit(type, payload) {
  if (typeof window === 'undefined') return;
  const sink = window.__penroseBioLabEvent;
  if (typeof sink === 'function') {
    try {
      sink(type, JSON.stringify(payload || {}));
    } catch (_) {
      /* never let a bridge error break rendering */
    }
  }
}

function emitError(code, message) {
  emit('error', { code, message: String(message || code) });
}

// ── Geometry builders ───────────────────────────────────────────────────────

function buildGeometry(type, params) {
  const p = params || {};
  switch (type) {
    case 'sphere':
      return new THREE.SphereGeometry(p.radius || 1, 32, 24);
    case 'sphereBlob': {
      const g = new THREE.SphereGeometry(p.radius || 1, 48, 32);
      const squash = p.squash || [1, 1, 1];
      g.scale(squash[0], squash[1], squash[2]);
      // Small vertex noise for an organic look.
      const noise = p.noise || 0;
      if (noise > 0) {
        const pos = g.attributes.position;
        for (let i = 0; i < pos.count; i++) {
          const n = 1 + (Math.random() - 0.5) * noise * 2;
          pos.setXYZ(i, pos.getX(i) * n, pos.getY(i) * n, pos.getZ(i) * n);
        }
        g.computeVertexNormals();
      }
      return g;
    }
    case 'capsule': {
      const r = p.radius || 1;
      const length = p.length || 2;
      // THREE.CapsuleGeometry(radius, length-of-cylinder-part)
      return new THREE.CapsuleGeometry(r, Math.max(0.01, length - 2 * r), 8, 24);
    }
    case 'capsuleShell': {
      const r = p.radius || 1;
      const length = p.length || 2;
      const shell = new THREE.Mesh(
        new THREE.CapsuleGeometry(r, Math.max(0.01, length - 2 * r), 8, 32),
        // filled separately; geometry only here
        null
      );
      shell.geometry.computeBoundingSphere();
      return shell.geometry;
    }
    case 'cylinder':
      return new THREE.CylinderGeometry(
        p.radius || 0.5, p.radius || 0.5, p.height || 1, 32);
    case 'tube': {
      const points = (p.points || []).map(
        (pt) => new THREE.Vector3(pt[0], pt[1], pt[2]));
      if (points.length < 2) {
        return new THREE.SphereGeometry(0.1, 8, 6);
      }
      const curve = new THREE.CatmullRomCurve3(points);
      return new THREE.TubeGeometry(curve, Math.max(16, points.length * 12),
        p.radius || 0.1, 10, false);
    }
    case 'helix': {
      // Double helix: two strands.
      const turns = p.turns || 2;
      const height = p.height || 3;
      const radius = p.radius || 0.6;
      const pts1 = [];
      const pts2 = [];
      const steps = turns * 24;
      for (let i = 0; i <= steps; i++) {
        const a = (i / steps) * turns * Math.PI * 2;
        const y = -height / 2 + (i / steps) * height;
        pts1.push(new THREE.Vector3(radius * Math.cos(a), y, radius * Math.sin(a)));
        pts2.push(new THREE.Vector3(-radius * Math.cos(a), y, -radius * Math.sin(a)));
      }
      const g = new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts1),
        steps, 0.08, 8, false);
      const g2 = new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts2),
        steps, 0.08, 8, false);
      // Merge is overkill; return strand 1 (callers use two objects).
      g.userData.secondStrand = g2;
      return g;
    }
    case 'torus':
      return new THREE.TorusGeometry(p.radius || 1, p.tube || 0.3, 16, 48);
    case 'box':
      return new THREE.BoxGeometry(p.width || 1, p.height || 1, p.depth || 1);
    case 'cone':
      return new THREE.ConeGeometry(p.radius || 1, p.height || 2, 24);
    case 'disc':
      return new THREE.CircleGeometry(p.radius || 1, 32);
    default:
      return new THREE.SphereGeometry(0.5, 16, 12);
  }
}

function toVector3(v, fallback) {
  if (!Array.isArray(v)) return fallback;
  return new THREE.Vector3(v[0], v[1], v[2]);
}

function toColor(hex, fallback) {
  try {
    return new THREE.Color(hex || fallback);
  } catch (_) {
    return new THREE.Color(fallback);
  }
}

// ── Labels overlay ──────────────────────────────────────────────────────────

class LabelOverlay {
  constructor(host) {
    this.host = host;
    this.root = document.createElement('div');
    Object.assign(this.root.style, {
      position: 'absolute', inset: '0', overflow: 'hidden',
      pointerEvents: 'none', zIndex: '5',
    });
    this.svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    this.svg.setAttribute('style', 'position:absolute;inset:0;width:100%;height:100%;');
    this.root.appendChild(this.svg);
    host.appendChild(this.root);
    this.labels = new Map(); // id -> {el, textEl, dot, line, anchor(object3d), offset}
    this.visible = true;
  }

  addLabel(id, text, anchorObject, offset) {
    const el = document.createElement('div');
    Object.assign(el.style, {
      position: 'absolute', display: 'flex', alignItems: 'center',
      pointerEvents: 'none', whiteSpace: 'nowrap',
    });
    const dot = document.createElement('span');
    Object.assign(dot.style, {
      width: '8px', height: '8px', borderRadius: '50%',
      background: ACCENT, border: '1.5px solid #ffffff',
      flexShrink: '0',
    });
    const textEl = document.createElement('span');
    Object.assign(textEl.style, {
      marginLeft: '6px', padding: '2px 8px', borderRadius: '6px',
      background: 'rgba(11,18,32,0.82)', color: '#e2e8f0',
      font: '600 11px/1.4 system-ui, sans-serif',
      border: '1px solid rgba(124,77,255,0.35)',
    });
    textEl.textContent = text;
    el.appendChild(dot);
    el.appendChild(textEl);
    this.root.appendChild(el);

    const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    line.setAttribute('stroke', 'rgba(124,77,255,0.65)');
    line.setAttribute('stroke-width', '1.2');
    this.svg.appendChild(line);

    this.labels.set(id, { el, textEl, dot, line, anchor: anchorObject, offset });
  }

  clear() {
    this.labels.clear();
    while (this.root.firstChild) this.root.removeChild(this.root.firstChild);
    this.svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    this.svg.setAttribute('style', 'position:absolute;inset:0;width:100%;height:100%;');
    this.root.appendChild(this.svg);
  }

  update(camera, size, hiddenIds) {
    const rect = { w: size.width, h: size.height };
    this.labels.forEach((l) => {
      if (!l.anchor || !this.visible) {
        l.el.style.display = 'none';
        l.line.style.display = 'none';
        return;
      }
      const world = toVector3(l.offset, new THREE.Vector3())
        .add(l.anchor.getWorldPosition(new THREE.Vector3()));
      const projected = world.clone().project(camera);
      const behind = projected.z > 1;
      const x = (projected.x * 0.5 + 0.5) * rect.w;
      const y = (-projected.y * 0.5 + 0.5) * rect.h;
      const hidden = behind || (hiddenIds && hiddenIds.has(l.anchor.userData.id));
      l.el.style.display = hidden ? 'none' : 'flex';
      l.line.style.display = hidden ? 'none' : 'block';
      if (!hidden) {
        // Dot sits on the anchor point; the chip is offset up-right.
        const cx = x + 18;
        const cy = Math.max(14, y - 22);
        l.el.style.left = cx + 'px';
        l.el.style.top = (cy - 8) + 'px';
        l.line.setAttribute('x1', x);
        l.line.setAttribute('y1', y);
        l.line.setAttribute('x2', cx);
        l.line.setAttribute('y2', cy);
      }
    });
  }

  dispose() {
    if (this.root.parentNode) this.root.parentNode.removeChild(this.root);
    this.labels.clear();
  }
}

// ── Orbit controls (damped, hand-rolled) ────────────────────────────────────

class OrbitControls {
  constructor(camera, dom) {
    this.camera = camera;
    this.dom = dom;
    this.target = new THREE.Vector3();
    this.spherical = new THREE.Spherical(8, Math.PI / 3, Math.PI / 4);
    this.damping = 0.12;
    this.enabled = true;
    this.minDistance = 0.5;
    this.maxDistance = 60;
    this._vel = { theta: 0, phi: 0, radius: 0, panX: 0, panY: 0 };
    this._pointers = new Map();
    this._downPos = null;
    this._moved = 0;
    this._bind();
  }

  _bind() {
    const el = this.dom;
    const opt = { passive: false };
    el.addEventListener('pointerdown', (e) => this._down(e));
    el.addEventListener('pointermove', (e) => this._move(e));
    el.addEventListener('pointerup', (e) => this._up(e));
    el.addEventListener('pointercancel', (e) => this._up(e));
    el.addEventListener('wheel', (e) => this._wheel(e), opt);
    el.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  _down(e) {
    this.dom.setPointerCapture && this.dom.setPointerCapture(e.pointerId);
    this._pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    this._moved = 0;
  }

  _move(e) {
    const prev = this._pointers.get(e.pointerId);
    if (!prev) return;
    const dx = e.clientX - prev.x;
    const dy = e.clientY - prev.y;
    this._moved += Math.abs(dx) + Math.abs(dy);
    this._pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

    if (this._pointers.size === 2) {
      // Pinch zoom.
      const pts = [...this._pointers.values()];
      const d = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
      if (this._lastPinch) {
        this.spherical.radius *= this._lastPinch / d;
        this._clampRadius();
      }
      this._lastPinch = d;
      return;
    }
    if (e.shiftKey || e.button === 1 || e.buttons === 4) {
      this._vel.panX += dx * 0.02;
      this._vel.panY += dy * 0.02;
    } else {
      this._vel.theta -= dx * 0.006;
      this._vel.phi -= dy * 0.006;
    }
  }

  _up(e) {
    this._pointers.delete(e.pointerId);
    this._lastPinch = null;
  }

  _wheel(e) {
    e.preventDefault();
    const factor = e.deltaY > 0 ? 1.12 : 0.89;
    this.spherical.radius *= factor;
    this._clampRadius();
  }

  _clampRadius() {
    this.spherical.radius =
      Math.min(this.maxDistance, Math.max(this.minDistance, this.spherical.radius));
  }

  /** True when the pointer has not dragged (click-like release). */
  get isClickLike() {
    return this._moved < 6;
  }

  panBy(dx, dy) {
    this._vel.panX += dx * 0.02;
    this._vel.panY += dy * 0.02;
  }

  update(dt) {
    const d = Math.pow(0.0001, dt); // damping factor per second
    this.spherical.theta += this._vel.theta;
    this.spherical.phi += this._vel.phi;
    this.spherical.phi = Math.min(Math.PI - 0.05, Math.max(0.05, this.spherical.phi));
    this._clampRadius();
    // Pan along camera-right and camera-up.
    const right = new THREE.Vector3().setFromMatrixColumn(this.camera.matrix, 0);
    const up = new THREE.Vector3().setFromMatrixColumn(this.camera.matrix, 1);
    this.target.addScaledVector(right, -this._vel.panX * this.spherical.radius * 0.1);
    this.target.addScaledVector(up, this._vel.panY * this.spherical.radius * 0.1);
    // Apply damping decay.
    const decay = 1 - Math.pow(this.damping, dt * 60);
    this._vel.theta *= 1 - this.damping;
    this._vel.phi *= 1 - this.damping;
    this._vel.panX *= 1 - this.damping;
    this._vel.panY *= 1 - this.damping;

    const offset = new THREE.Vector3().setFromSpherical(this.spherical);
    this.camera.position.copy(this.target).add(offset);
    this.camera.lookAt(this.target);
  }

  setFromPosition(pos, target) {
    this.target.copy(target || new THREE.Vector3());
    const offset = pos.clone().sub(this.target);
    this.spherical.setFromVector3(offset);
  }
}

// ── Biology Lab engine ──────────────────────────────────────────────────────

class BioLabEngine {
  constructor() {
    this.host = null;
    this.renderer = null;
    this.scene = null;
    this.camera = null;
    this.controls = null;
    this.labels = null;
    this.objects = new Map(); // id -> {mesh, def, basePosition, baseRotation, baseScale, baseOpacity}
    this.animations = new Map();
    this.activeAnimation = null;
    this.timeline = 0;
    this.speed = 1;
    this.playing = false;
    this.selectedId = null;
    this.rafId = 0;
    this.clock = new THREE.Clock();
    this.groupVisible = {};
    this.transparency = 0;
    this.moleculeFrame = null;
    this.scaleBadge = null;
    this.transitionCard = null;
    this._disposed = false;
    this._moleculeListener = (e) => this._onMoleculeMessage(e);
    this._timeEmitAcc = 0;
  }

  init(hostId) {
    const host = document.getElementById(hostId);
    if (!host) throw new Error('host-missing');
    this.host = host;
    host.innerHTML = '';

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    Object.assign(this.renderer.domElement.style, {
      position: 'absolute', inset: '0', width: '100%', height: '100%',
      touchAction: 'none', outline: 'none',
    });
    host.appendChild(this.renderer.domElement);

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(BG_DEFAULT);

    this.camera = new THREE.PerspectiveCamera(50, 1, 0.01, 400);
    this.controls = new OrbitControls(this.camera, this.renderer.domElement);

    const hemi = new THREE.HemisphereLight('#cfd8ff', '#1a1a2e', 0.85);
    this.scene.add(hemi);
    const key = new THREE.DirectionalLight('#ffffff', 1.6);
    key.position.set(6, 10, 8);
    this.scene.add(key);
    const rim = new THREE.DirectionalLight('#7c4dff', 0.5);
    rim.position.set(-8, 4, -6);
    this.scene.add(rim);

    this.labels = new LabelOverlay(host);

    // Scale badge (bottom-left).
    this.scaleBadge = document.createElement('div');
    Object.assign(this.scaleBadge.style, {
      position: 'absolute', left: '12px', bottom: '12px', zIndex: '6',
      padding: '4px 10px', borderRadius: '8px', pointerEvents: 'none',
      background: 'rgba(11,18,32,0.8)', color: '#94a3b8',
      font: '600 11px/1.4 system-ui, sans-serif',
      border: '1px solid rgba(148,163,184,0.25)', display: 'none',
    });
    host.appendChild(this.scaleBadge);

    this._resize();
    if (typeof ResizeObserver !== 'undefined') {
      this._ro = new ResizeObserver(() => this._resize());
      this._ro.observe(host);
    }
    window.addEventListener('resize', () => this._resize());
    window.addEventListener('message', this._moleculeListener);
    this._loop();

    emit('ready', {});
  }

  _resize() {
    if (!this.host || !this.renderer) return;
    const w = this.host.clientWidth || 1;
    const h = this.host.clientHeight || 1;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  _loop() {
    if (this._disposed) return;
    this.rafId = requestAnimationFrame(() => this._loop());
    const dt = Math.min(0.05, this.clock.getDelta());

    if (this.playing && this.activeAnimation) {
      this.timeline += dt * this.speed / this.activeAnimation.duration;
      if (this.timeline >= 1) {
        this.timeline = 1;
        this.playing = false;
        emit('stateChanged', { state: 'idle' });
      }
      this._evaluateTimeline();
      this._timeEmitAcc += dt;
      if (this._timeEmitAcc > 0.1) {
        this._timeEmitAcc = 0;
        emit('time', { t: this.timeline });
      }
    }

    if (this.controls && !this.moleculeFrame) this.controls.update(dt);
    if (this.renderer && this.scene && !this.moleculeFrame) {
      this.renderer.render(this.scene, this.camera);
      if (this.labels) this.labels.update(this.camera, {
        width: this.host.clientWidth, height: this.host.clientHeight,
      });
    }
  }

  // ── Scene building ──

  loadScene(spec) {
    try {
      this._clearScene();
      this.sceneId = spec.sceneId || 'scene';
      this.scene.background = toColor(spec.camera && spec.camera.background, BG_DEFAULT);
      this.camera.position.set(...((spec.camera && spec.camera.position) || [4, 3, 6]));
      const target = toVector3(spec.camera && spec.camera.target, new THREE.Vector3());
      this.controls.setFromPosition(this.camera.position, target);
      this.camera.lookAt(target);

      this.groupVisible = {};
      for (const g of spec.groups || []) this.groupVisible[g] = true;

      for (const def of spec.objects || []) {
        this._addObject(def);
      }

      this.animations = new Map();
      for (const anim of spec.animations || []) {
        this.animations.set(anim.id, anim);
      }
      this.activeAnimation = null;
      this.timeline = 0;
      this.playing = false;

      if (spec.scaleInfo) {
        this.scaleBadge.textContent = spec.scaleInfo.label +
          (spec.scaleInfo.note ? '  ·  ' + spec.scaleInfo.note : '');
        this.scaleBadge.style.display = 'block';
      } else {
        this.scaleBadge.style.display = 'none';
      }
      emit('stateChanged', { state: 'idle' });
    } catch (err) {
      emitError('scene-build-failed', err);
    }
  }

  _addObject(def) {
    let geometry;
    try {
      geometry = buildGeometry(def.type, def.params);
    } catch (err) {
      emitError('geometry-failed', def.type + ': ' + err);
      return;
    }
    let material;
    if (def.type === 'tube' || def.type === 'helix') {
      material = new THREE.MeshStandardMaterial({
        color: toColor(def.color, '#888'),
        opacity: def.opacity != null ? def.opacity : 1,
        transparent: (def.opacity != null ? def.opacity : 1) < 1,
        roughness: def.roughness != null ? def.roughness : 0.5,
        metalness: def.metalness || 0,
        side: THREE.DoubleSide,
        depthWrite: (def.opacity != null ? def.opacity : 1) >= 0.95,
      });
    } else {
      material = new THREE.MeshStandardMaterial({
        color: toColor(def.color, '#888'),
        opacity: def.opacity != null ? def.opacity : 1,
        transparent: (def.opacity != null ? def.opacity : 1) < 1,
        roughness: def.roughness != null ? def.roughness : 0.5,
        metalness: def.metalness || 0,
        side: def.type === 'disc' || def.type === 'capsuleShell'
          ? THREE.DoubleSide : THREE.FrontSide,
        depthWrite: (def.opacity != null ? def.opacity : 1) >= 0.95,
      });
    }

    const mesh = new THREE.Mesh(geometry, material);
    mesh.name = def.id;
    mesh.userData.id = def.id;
    mesh.userData.def = def;
    mesh.position.copy(toVector3(def.position, new THREE.Vector3()));
    if (def.rotation) mesh.rotation.set(def.rotation[0], def.rotation[1], def.rotation[2]);
    if (Array.isArray(def.scale)) mesh.scale.set(def.scale[0], def.scale[1], def.scale[2]);
    else if (typeof def.scale === 'number') mesh.scale.setScalar(def.scale);
    else if (def.params && def.params.squash && def.type === 'capsule') {
      // capsules may be squashed via params already
    }
    mesh.visible = this.groupVisible[def.group] !== false;
    this.scene.add(mesh);

    this.objects.set(def.id, {
      mesh,
      def,
      basePosition: mesh.position.clone(),
      baseRotation: mesh.rotation.clone(),
      baseScale: mesh.scale.clone(),
      baseOpacity: material.opacity,
      baseColor: material.color.clone(),
    });

    if (def.selectable && def.label) {
      this.labels.addLabel(def.id, def.label, mesh,
        toVector3(def.labelOffset, new THREE.Vector3(0, 0.5, 0)));
    }
  }

  _clearScene() {
    if (this.labels) this.labels.clear();
    this.objects.forEach((o) => {
      this.scene.remove(o.mesh);
      o.mesh.geometry.dispose();
      o.mesh.material.dispose();
    });
    this.objects.clear();
    this.selectedId = null;
    this._clearTransition();
    if (this.moleculeFrame) {
      if (this.moleculeFrame.parentNode) this.moleculeFrame.parentNode.removeChild(this.moleculeFrame);
      this.moleculeFrame = null;
    }
  }

  dispose() {
    this._disposed = true;
    cancelAnimationFrame(this.rafId);
    window.removeEventListener('message', this._moleculeListener);
    if (this._ro) this._ro.disconnect();
    this._clearScene();
    if (this.labels) this.labels.dispose();
    if (this.renderer) {
      this.renderer.dispose();
      if (this.renderer.domElement.parentNode) {
        this.renderer.domElement.parentNode.removeChild(this.renderer.domElement);
      }
    }
    if (this.scaleBadge && this.scaleBadge.parentNode) {
      this.scaleBadge.parentNode.removeChild(this.scaleBadge);
    }
    if (this.host) this.host.innerHTML = '';
    this.host = null;
    this.renderer = null;
    this.scene = null;
    this.camera = null;
    this.controls = null;
    emit('stateChanged', { state: 'idle' });
  }

  // ── Selection ──

  selectObject(id) {
    if (id != null && !this.objects.has(id)) {
      emitError('unknown-object', 'No object "' + id + '" in the current scene');
      return;
    }
    this._applySelection(id);
  }

  _applySelection(id) {
    // Clear previous.
    if (this.selectedId) {
      const prev = this.objects.get(this.selectedId);
      if (prev) {
        prev.mesh.material.emissive = new THREE.Color('#000000');
      }
    }
    this.selectedId = id;
    if (id) {
      const o = this.objects.get(id);
      o.mesh.material.emissive = new THREE.Color(ACCENT);
      o.mesh.material.emissiveIntensity = 0.35;
    }
    const def = id ? this.objects.get(id).def : null;
    emit('selection', { id: id, name: def ? def.name : null });
  }

  _pick(clientX, clientY) {
    const rect = this.renderer.domElement.getBoundingClientRect();
    const ndc = new THREE.Vector2(
      ((clientX - rect.left) / rect.width) * 2 - 1,
      -((clientY - rect.top) / rect.height) * 2 + 1);
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(ndc, this.camera);
    const meshes = [];
    this.objects.forEach((o) => {
      if (o.mesh.visible && o.def.selectable) meshes.push(o.mesh);
    });
    const hits = raycaster.intersectObjects(meshes, false);
    return hits.length ? hits[0].object.userData.id : null;
  }

  // ── Visibility / transparency / labels ──

  setVisibility(groups) {
    for (const [g, v] of Object.entries(groups || {})) {
      this.groupVisible[g] = !!v;
      this.objects.forEach((o) => {
        if (o.def.group === g) o.mesh.visible = !!v;
      });
    }
  }

  setTransparency(value) {
    this.transparency = Math.min(1, Math.max(0, value));
    this.objects.forEach((o) => {
      const m = o.mesh.material;
      if (this.selectedId && o.def.id === this.selectedId) return;
      const target = Math.max(0.05, o.baseOpacity * (1 - this.transparency * 0.9));
      m.opacity = target;
      m.transparent = target < 1;
      m.depthWrite = target >= 0.95;
    });
  }

  setLabelsVisible(visible) {
    if (this.labels) this.labels.visible = !!visible;
  }

  // ── Camera ──

  focusObject(id) {
    const o = this.objects.get(id);
    if (!o) {
      emitError('unknown-object', 'No object "' + id + '" to focus on');
      return;
    }
    const center = new THREE.Box3().setFromObject(o.mesh).getCenter(new THREE.Vector3());
    const size = new THREE.Box3().setFromObject(o.mesh).getSize(new THREE.Vector3()).length();
    const dir = this.camera.position.clone().sub(this.controls.target).normalize();
    this._cameraTween = {
      fromPos: this.camera.position.clone(),
      fromTarget: this.controls.target.clone(),
      toTarget: center,
      toPos: center.clone().addScaledVector(dir, Math.max(2.2, size * 2.2)),
      t: 0,
    };
  }

  resetCamera() {
    const spec = this._lastSpec;
    if (!spec || !spec.camera) return;
    this._cameraTween = {
      fromPos: this.camera.position.clone(),
      fromTarget: this.controls.target.clone(),
      toTarget: toVector3(spec.camera.target, new THREE.Vector3()),
      toPos: toVector3(spec.camera.position, new THREE.Vector3(4, 3, 6)),
      t: 0,
    };
  }

  _updateCameraTween(dt) {
    if (!this._cameraTween) return;
    const tw = this._cameraTween;
    tw.t = Math.min(1, tw.t + dt / 0.8);
    const e = tw.t < 0.5 ? 2 * tw.t * tw.t : 1 - Math.pow(-2 * tw.t + 2, 2) / 2;
    this.camera.position.lerpVectors(tw.fromPos, tw.toPos, e);
    this.controls.target.lerpVectors(tw.fromTarget, tw.toTarget, e);
    this.camera.lookAt(this.controls.target);
    this.controls.spherical.setFromVector3(
      this.camera.position.clone().sub(this.controls.target));
    if (tw.t >= 1) this._cameraTween = null;
  }

  // ── Animation ──

  loadAnimation(id) {
    const anim = this.animations.get(id);
    if (!anim) {
      emitError('unknown-animation', 'Scene has no animation "' + id + '"');
      return;
    }
    this.activeAnimation = anim;
    this.timeline = 0;
    this._evaluateTimeline();
    this.playing = false;
    emit('stateChanged', { state: 'paused' });
  }

  play() {
    if (!this.activeAnimation) {
      // Fall back to the first animation in the scene.
      const first = this.animations.keys().next();
      if (first.done) {
        emitError('no-animation', 'This scene has no animations');
        return;
      }
      this.activeAnimation = this.animations.get(first.value);
      this.timeline = 0;
    }
    if (this.timeline >= 1) this.timeline = 0;
    this.playing = true;
    emit('stateChanged', { state: 'running' });
  }

  pause() {
    this.playing = false;
    emit('stateChanged', { state: 'paused' });
  }

  resume() {
    if (this.activeAnimation && this.timeline < 1) {
      this.playing = true;
      emit('stateChanged', { state: 'running' });
    }
  }

  restart() {
    this.timeline = 0;
    this.playing = false;
    this._evaluateTimeline();
    emit('time', { t: 0 });
    emit('stateChanged', { state: 'paused' });
  }

  setSpeed(value) {
    this.speed = Math.min(8, Math.max(0.25, value || 1));
  }

  setTimeline(t) {
    this.timeline = Math.min(1, Math.max(0, t || 0));
    if (!this.activeAnimation) {
      const first = this.animations.keys().next();
      if (!first.done) this.activeAnimation = this.animations.get(first.value);
    }
    this._evaluateTimeline();
    emit('time', { t: this.timeline });
  }

  setStep(index, total) {
    if (total > 1) this.setTimeline(index / (total - 1));
  }

  _evaluateTimeline() {
    const anim = this.activeAnimation;
    if (!anim) return;
    const t = this.timeline;
    for (const track of anim.tracks || []) {
      const o = this.objects.get(track.objectId);
      if (!o) continue;
      const kfs = (track.keyframes || []).slice()
        .sort((a, b) => a.t - b.t);
      if (!kfs.length) continue;
      let from = kfs[0];
      let to = kfs[kfs.length - 1];
      for (let i = 0; i < kfs.length - 1; i++) {
        if (t >= kfs[i].t && t <= kfs[i + 1].t) {
          from = kfs[i];
          to = kfs[i + 1];
          break;
        }
      }
      const span = to.t - from.t;
      let f = span > 0 ? (t - from.t) / span : 1;
      f = f < 0.5 ? 2 * f * f : 1 - Math.pow(-2 * f + 2, 2) / 2; // easeInOut
      const a = from.value;
      const b = to.value;
      switch (track.property) {
        case 'position':
          o.mesh.position.set(a[0] + (b[0] - a[0]) * f,
            a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f);
          break;
        case 'rotation':
          o.mesh.rotation.set(a[0] + (b[0] - a[0]) * f,
            a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f);
          break;
        case 'scale':
          o.mesh.scale.set(a[0] + (b[0] - a[0]) * f,
            a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f);
          break;
        case 'opacity':
          o.mesh.material.opacity = a + (b - a) * f;
          break;
        case 'color':
          o.mesh.material.color.setRGB(
            (a[0] || a.r || 0) + ((b[0] || b.r || 0) - (a[0] || a.r || 0)) * f, 0, 0);
          break;
        case 'visible':
          o.mesh.visible = f < 0.5 ? !!a : !!b;
          break;
        default:
          break;
      }
    }
  }

  // ── Transition overlay & molecule iframe ──

  showTransition(text, scaleLabel) {
    this._clearTransition();
    const card = document.createElement('div');
    Object.assign(card.style, {
      position: 'absolute', left: '50%', top: '40%', zIndex: '20',
      transform: 'translate(-50%,-50%)', padding: '14px 22px',
      borderRadius: '12px', pointerEvents: 'none', textAlign: 'center',
      background: 'rgba(11,18,32,0.92)', color: '#e2e8f0',
      border: '1px solid rgba(124,77,255,0.4)',
      font: '600 13px/1.5 system-ui, sans-serif',
      opacity: '0', transition: 'opacity 0.4s ease',
      maxWidth: '80%', whiteSpace: 'pre-line',
    });
    card.innerHTML = '<div style="font-weight:800;color:#c4b5fd;margin-bottom:4px">' +
      'Conceptual transition — not a continuous zoom</div>' +
      '<div>' + text + '</div>' +
      (scaleLabel ? '<div style="margin-top:6px;color:#94a3b8;font-size:11px">' +
        scaleLabel + '</div>' : '');
    this.host.appendChild(card);
    requestAnimationFrame(() => { card.style.opacity = '1'; });
    this.transitionCard = card;
    setTimeout(() => this._clearTransition(), 2600);
  }

  _clearTransition() {
    if (this.transitionCard && this.transitionCard.parentNode) {
      this.transitionCard.parentNode.removeChild(this.transitionCard);
    }
    this.transitionCard = null;
  }

  showMolecule(pdb, label) {
    this._clearScene();
    this.scaleBadge.style.display = 'none';
    const frame = document.createElement('iframe');
    const base = this._pageBase();
    const src = base + 'biology_lab/molstar/molecule-viewer.html?pdb=' +
      encodeURIComponent(pdb) + '&label=' + encodeURIComponent(label || '');
    frame.src = src;
    Object.assign(frame.style, {
      position: 'absolute', inset: '0', width: '100%', height: '100%',
      border: '0', zIndex: '10',
    });
    frame.setAttribute('title', 'Molecular viewer (Mol*)');
    frame.setAttribute('allow', 'fullscreen');
    this.host.appendChild(frame);
    this.moleculeFrame = frame;
    emit('stateChanged', { state: 'molecular' });
  }

  hideMolecule() {
    if (this.moleculeFrame) {
      if (this.moleculeFrame.parentNode) {
        this.moleculeFrame.parentNode.removeChild(this.moleculeFrame);
      }
      this.moleculeFrame = null;
      emit('stateChanged', { state: 'idle' });
    }
  }

  _pageBase() {
    // The SPA is served from frontend/web as the site root: the app lives at
    // /index.html, so assets resolve relative to '/'.
    const path = window.location.pathname;
    return path.endsWith('/') ? path : path.replace(/[^/]*$/, '/');
  }

  _onMoleculeMessage(e) {
    const d = e.data;
    if (!d || d.source !== 'penrose-bio-lab-molstar') return;
    emit('molecule', { type: d.type, message: d.message });
  }

  // ── Command dispatch ──

  handle(jsonString) {
    let cmd;
    try {
      cmd = JSON.parse(jsonString);
    } catch (err) {
      emitError('bad-command', 'Unparseable command');
      return;
    }
    try {
      const p = cmd || {};
      switch (p.cmd) {
        case 'init': this.init(p.hostId); break;
        case 'dispose': this.dispose(); break;
        case 'loadScene':
          this._lastSpec = p.spec;
          this.loadScene(p.spec);
          break;
        case 'selectObject': this.selectObject(p.id); break;
        case 'setLabelsVisible': this.setLabelsVisible(p.visible); break;
        case 'setVisibility': this.setVisibility(p.groups); break;
        case 'setTransparency': this.setTransparency(p.value); break;
        case 'focusObject': this.focusObject(p.id); break;
        case 'resetCamera': this.resetCamera(); break;
        case 'loadAnimation': this.loadAnimation(p.id); break;
        case 'play': this.play(); break;
        case 'pause': this.pause(); break;
        case 'resume': this.resume(); break;
        case 'restart': this.restart(); break;
        case 'setSpeed': this.setSpeed(p.value); break;
        case 'setTimeline': this.setTimeline(p.t); break;
        case 'setStep': this.setStep(p.index, p.total); break;
        case 'showTransition': this.showTransition(p.text, p.scaleLabel); break;
        case 'showMolecule': this.showMolecule(p.pdb, p.label); break;
        case 'hideMolecule': this.hideMolecule(); break;
        default:
          emitError('unknown-command', String(p.cmd));
      }
    } catch (err) {
      emitError('command-failed', err);
    }
  }
}

// ── Bootstrap ───────────────────────────────────────────────────────────────

const engine = new BioLabEngine();

if (typeof window !== 'undefined') {
  // Picking wiring lives here so pointer logic stays out of init().
  window.addEventListener('pointerup', (e) => {
    if (!engine.renderer || engine.moleculeFrame || !engine.renderer.domElement) return;
    const canvas = engine.renderer.domElement;
    if (e.target !== canvas) return;
    if (!engine.controls || !engine.controls.isClickLike) return;
    const id = engine._pick(e.clientX, e.clientY);
    engine._applySelection(id);
  }, true);

  window.PenroseBioLab = {
    version: API_VERSION,
    handle: (json) => engine.handle(json),
  };
}

export { BioLabEngine };
