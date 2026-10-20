/* NeuronViewer: standalone overlay viewer for the Phase-9 neurone model.
   Own WebGL canvas over the lab (never touches the classroom scene), an
   orbit rig, projected HTML labels, raycast pick + highlight, and a stage
   timeline driven by the pure-JS model in js/neuron_model.js. */
import * as THREE from "three";
import {
  buildNeuronGeometry,
  frameAt,
  NEURON_TIMELINE,
  NEURON_MODES,
  neuronStructureById,
  expectedMeshCounts,
} from "./neuron_model.js";

export function createNeuronViewer(options) {
  const opts = options || {};
  const container = opts.container || document.body;

  const wrapper = document.createElement("div");
  wrapper.className = "neuron-viewer";
  wrapper.style.cssText =
    "position:fixed;left:0;top:0;width:100vw;height:100vh;background:#0b1018;" +
    "z-index:" + (opts.zIndex || 61) + ";overflow:hidden;touch-action:none;";
  const canvas = document.createElement("canvas");
  canvas.style.cssText = "position:absolute;left:0;top:0;width:100%;height:100%;display:block;";
  wrapper.appendChild(canvas);

  const labelLayer = document.createElement("div");
  labelLayer.style.cssText = "position:absolute;left:0;top:0;width:100%;height:100%;pointer-events:none;";
  wrapper.appendChild(labelLayer);

  const toolbar = document.createElement("div");
  toolbar.style.cssText =
    "position:absolute;left:12px;top:12px;display:flex;gap:8px;align-items:center;flex-wrap:wrap;" +
    "font:13px 'Segoe UI',system-ui,sans-serif;max-width:calc(100% - 24px);";
  function makeButton(text) {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = text;
    b.style.cssText =
      "font:13px 'Segoe UI',system-ui,sans-serif;padding:6px 12px;border:1px solid #3a4657;" +
      "background:#182231;color:#dbe4f0;border-radius:6px;cursor:pointer;";
    toolbar.appendChild(b);
    return b;
  }
  const btnLabels = makeButton("Labels: on");
  const modeButtons = {};
  const modeRow = document.createElement("div");
  modeRow.style.cssText = "display:flex;gap:6px;";
  toolbar.appendChild(modeRow);
  NEURON_MODES.forEach(function (m) {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = m.title;
    b.style.cssText =
      "font:12px 'Segoe UI',system-ui,sans-serif;padding:6px 10px;border:1px solid #3a4657;" +
      "background:#182231;color:#9fb0c8;border-radius:6px;cursor:pointer;";
    b.addEventListener("click", function () { setMode(m.id); });
    modeRow.appendChild(b);
    modeButtons[m.id] = b;
  });
  const btnPlay = makeButton("Play");
  const btnReset = makeButton("Reset view");
  const btnClose = makeButton("Close");
  const status = document.createElement("span");
  status.style.cssText = "font:13px 'Segoe UI',system-ui,sans-serif;color:#9fb0c8;padding-left:6px;";
  status.textContent = "drag to orbit - wheel to zoom - click a part";
  toolbar.appendChild(status);
  wrapper.appendChild(toolbar);

  const footer = document.createElement("div");
  footer.style.cssText =
    "position:absolute;left:14px;bottom:12px;max-width:min(560px,calc(100% - 28px));font:13px 'Segoe UI',system-ui,sans-serif;" +
    "color:#dbe4f0;background:rgba(11,16,24,.82);border:1px solid #2a3646;" +
    "border-radius:6px;padding:8px 12px;";
  wrapper.appendChild(footer);

  const stageBar = document.createElement("div");
  stageBar.style.cssText =
    "position:absolute;left:14px;right:14px;bottom:64px;display:flex;gap:4px;align-items:center;";
  wrapper.appendChild(stageBar);

  container.appendChild(wrapper);

  const w = wrapper.clientWidth || window.innerWidth || 800;
  const h = wrapper.clientHeight || window.innerHeight || 600;
  const renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true });
  renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
  renderer.setSize(w, h, false);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0b1018);
  const camera = new THREE.PerspectiveCamera(45, w / h, 0.1, 200);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x2a3346, 1.05));
  const dir = new THREE.DirectionalLight(0xffffff, 1.2);
  dir.position.set(3, 6, 5);
  scene.add(dir);
  const fill = new THREE.DirectionalLight(0x9fd8ff, 0.4);
  fill.position.set(-5, -3, -4);
  scene.add(fill);

  /* ---- build meshes from the pure geometry spec ---- */
  const geo = buildNeuronGeometry();
  const root = new THREE.Group();
  scene.add(root);

  const pickables = [];
  function tag(mesh, id, baseColor) {
    mesh.userData.structureId = id;
    mesh.userData.baseColor = baseColor;
    root.add(mesh);
    pickables.push(mesh);
    return mesh;
  }

  const COL = {
    soma: 0x9b7bd4,
    nucleus: 0x6f57a8,
    dendrite: 0xa992dd,
    hillock: 0xf0ac5a,
    axon: 0xe4c98a,
    myelin: 0xf1f3f6,
    node: 0x8fd0f0,
    terminal: 0xc98fe0,
    vesicle: 0x86e0c0,
    neurotransmitter: 0x65d6ff,
    post: 0x7fa6d0,
    receptor: 0xff9db0,
    impulse: 0xffe066,
    calcium: 0xffb347,
  };

  const somaMesh = tag(
    new THREE.Mesh(new THREE.SphereGeometry(geo.soma.radius, 32, 24),
      new THREE.MeshStandardMaterial({ color: COL.soma, roughness: 0.55 })),
    "soma", COL.soma);
  somaMesh.position.set(geo.soma.x, geo.soma.y, geo.soma.z);

  const nucleusMesh = tag(
    new THREE.Mesh(new THREE.SphereGeometry(geo.nucleus.radius, 24, 18),
      new THREE.MeshStandardMaterial({ color: COL.nucleus, roughness: 0.7 })),
    "nucleus", COL.nucleus);
  nucleusMesh.position.set(geo.nucleus.x, geo.nucleus.y, geo.nucleus.z);

  const hillockMesh = tag(
    new THREE.Mesh(new THREE.ConeGeometry(geo.hillock.radius, geo.hillock.radius * 2.4, 20),
      new THREE.MeshStandardMaterial({ color: COL.hillock, roughness: 0.6 })),
    "axon_hillock", COL.hillock);
  hillockMesh.rotation.z = -Math.PI / 2;
  hillockMesh.position.set(geo.hillock.x, geo.hillock.y, geo.hillock.z);

  geo.dendrites.forEach(function (d) {
    const len = d.length;
    const m = new THREE.Mesh(
      new THREE.CylinderGeometry(d.radius * 0.4, d.radius, len, 8),
      new THREE.MeshStandardMaterial({ color: COL.dendrite, roughness: 0.6 }));
    m.position.set(d.origin.x - Math.cos(d.angle) * len * 0.5,
      d.origin.y + Math.sin(d.angle) * len * 0.5, d.origin.z);
    m.rotation.z = d.angle - Math.PI / 2;
    tag(m, "dendrites", COL.dendrite);
  });

  const axonGroup = new THREE.Group();
  const axonLen = geo.axon.endX - geo.axon.startX;
  const axonMesh = tag(
    new THREE.Mesh(new THREE.CylinderGeometry(geo.axon.radius, geo.axon.radius, axonLen, 12),
      new THREE.MeshStandardMaterial({ color: COL.axon, roughness: 0.6 })),
    "axon", COL.axon);
  axonMesh.rotation.z = -Math.PI / 2;
  axonMesh.position.set((geo.axon.startX + geo.axon.endX) / 2, geo.axon.y, geo.axon.z);

  const myelinMeshes = [];
  geo.internodes.forEach(function (seg) {
    const len = seg.x1 - seg.x0;
    const m = new THREE.Mesh(
      new THREE.CylinderGeometry(seg.radius, seg.radius, len, 16, 1, true),
      new THREE.MeshStandardMaterial({ color: COL.myelin, roughness: 0.5, metalness: 0.05,
        transparent: true, opacity: 0.92 }));
    m.rotation.z = -Math.PI / 2;
    m.position.set((seg.x0 + seg.x1) / 2, seg.y, seg.z);
    tag(m, "myelin", COL.myelin);
    myelinMeshes.push(m);
  });

  const nodeMeshes = [];
  geo.nodes.forEach(function (n) {
    const m = new THREE.Mesh(
      new THREE.CylinderGeometry(n.radius, n.radius, geo.axon.radius * 2.6, 10),
      new THREE.MeshStandardMaterial({ color: COL.node, emissive: 0x2a5f7a, roughness: 0.5 }));
    m.rotation.z = -Math.PI / 2;
    m.position.set(n.x, n.y, n.z);
    tag(m, "node_of_ranvier", COL.node);
    nodeMeshes.push(m);
  });

  const terminalMesh = tag(
    new THREE.Mesh(new THREE.SphereGeometry(geo.terminal.radius, 20, 16),
      new THREE.MeshStandardMaterial({ color: COL.terminal, roughness: 0.55 })),
    "axon_terminal", COL.terminal);
  terminalMesh.position.set(geo.terminal.x, geo.terminal.y, geo.terminal.z);

  const vesicleMeshes = [];
  for (let i = 0; i < geo.vesicleCount; i++) {
    const a = (i / geo.vesicleCount) * Math.PI * 2;
    const m = new THREE.Mesh(
      new THREE.SphereGeometry(0.055, 10, 8),
      new THREE.MeshStandardMaterial({ color: COL.vesicle, roughness: 0.4 }));
    m.position.set(geo.terminal.x - 0.02, Math.cos(a) * 0.14, Math.sin(a) * 0.14);
    tag(m, "vesicles", COL.vesicle);
    vesicleMeshes.push(m);
  }

  const cleftMesh = tag(
    new THREE.Mesh(new THREE.BoxGeometry(geo.cleft.width, 0.7, 0.7),
      new THREE.MeshStandardMaterial({ color: COL.neurotransmitter, transparent: true, opacity: 0.14 })),
    "synaptic_cleft", COL.neurotransmitter);
  cleftMesh.position.set(geo.cleft.x, geo.cleft.y, geo.cleft.z);

  const postMesh = tag(
    new THREE.Mesh(new THREE.SphereGeometry(geo.postsynaptic.radius, 20, 16, 0, Math.PI),
      new THREE.MeshStandardMaterial({ color: COL.post, roughness: 0.6, side: THREE.DoubleSide })),
    "postsynaptic", COL.post);
  postMesh.position.set(geo.postsynaptic.x, geo.postsynaptic.y, geo.postsynaptic.z);

  const receptorMeshes = [];
  for (let i = 0; i < geo.receptorCount; i++) {
    const a = (i / geo.receptorCount) * Math.PI * 2;
    const m = new THREE.Mesh(
      new THREE.TorusGeometry(0.05, 0.02, 8, 12, Math.PI),
      new THREE.MeshStandardMaterial({ color: COL.receptor, roughness: 0.5 }));
    m.position.set(geo.postsynaptic.x - geo.postsynaptic.radius * 0.6, Math.cos(a) * 0.2, Math.sin(a) * 0.2);
    m.rotation.y = Math.PI / 2;
    tag(m, "receptors", COL.receptor);
    receptorMeshes.push(m);
  }

  const ntMeshes = [];
  for (let i = 0; i < geo.neurotransmitterCount; i++) {
    const a = (i / geo.neurotransmitterCount) * Math.PI * 2;
    const m = new THREE.Mesh(
      new THREE.SphereGeometry(0.028, 8, 6),
      new THREE.MeshStandardMaterial({ color: COL.neurotransmitter, emissive: 0x1d6b8a, roughness: 0.4 }));
    m.userData.homeX = geo.terminal.x + 0.04;
    m.userData.angle = a;
    tag(m, "neurotransmitter", COL.neurotransmitter);
    ntMeshes.push(m);
  }

  const impulseMesh = new THREE.Mesh(
    new THREE.SphereGeometry(0.14, 16, 12),
    new THREE.MeshStandardMaterial({ color: COL.impulse, emissive: 0x8a6a00, roughness: 0.3 }));
  root.add(impulseMesh);

  /* ---- labels ---- */
  const LABEL_ANCHORS = [
    { id: "dendrites", x: -1.5, y: 0.9, z: 0 },
    { id: "soma", x: 0, y: 0.75, z: 0 },
    { id: "nucleus", x: 0, y: 0, z: 0.1 },
    { id: "axon_hillock", x: geo.hillock.x, y: -0.42, z: 0 },
    { id: "axon", x: (geo.axon.startX + geo.axon.endX) / 2, y: -0.4, z: 0 },
    { id: "myelin", x: geo.internodes[1] ? geo.internodes[1].x0 : geo.axon.startX, y: 0.42, z: 0 },
    { id: "node_of_ranvier", x: geo.nodes[0] ? geo.nodes[0].x : geo.axon.startX, y: 0.42, z: 0 },
    { id: "axon_terminal", x: geo.terminal.x, y: 0.5, z: 0 },
    { id: "vesicles", x: geo.terminal.x, y: -0.45, z: 0 },
    { id: "synaptic_cleft", x: geo.cleft.x, y: 0.55, z: 0 },
    { id: "neurotransmitter", x: geo.cleft.x, y: -0.5, z: 0 },
    { id: "postsynaptic", x: geo.postsynaptic.x + 0.3, y: 0.35, z: 0 },
    { id: "receptors", x: geo.postsynaptic.x + 0.1, y: -0.5, z: 0 },
  ];
  let labelsOn = true;
  const labelEls = LABEL_ANCHORS.map(function (a) {
    const el = document.createElement("div");
    const s = neuronStructureById[a.id];
    el.textContent = s ? s.short : a.id;
    el.style.cssText =
      "position:absolute;transform:translate(-50%,-50%);font:11px 'Segoe UI',system-ui,sans-serif;" +
      "color:#dbe4f0;background:rgba(11,16,24,.7);border:1px solid #2a3646;border-radius:4px;" +
      "padding:2px 6px;white-space:nowrap;pointer-events:none;";
    labelLayer.appendChild(el);
    return { el: el, anchor: a };
  });

  /* ---- stage timeline UI ---- */
  let modeId = "full";
  let stage = 0;
  let playing = false;
  let progress = 0;
  let lastT = performance.now();
  const STAGE_MS = 2600;
  let visibleStages = NEURON_TIMELINE.slice();
  const stageCells = NEURON_TIMELINE.map(function (st) {
    const c = document.createElement("button");
    c.type = "button";
    c.textContent = String(st.id + 1);
    c.style.cssText =
      "flex:1;font:11px 'Segoe UI',system-ui,sans-serif;padding:6px 0;border:1px solid #2a3646;" +
      "background:#141c28;color:#9fb0c8;border-radius:5px;cursor:pointer;";
    c.addEventListener("click", function () { setStage(st.id); playing = false; progress = 0; syncPlayButton(); });
    stageBar.appendChild(c);
    return c;
  });
  const footTitle = document.createElement("div");
  footTitle.style.cssText = "font-weight:700;color:#ffe9a8;";
  const footSummary = document.createElement("div");
  footSummary.style.cssText = "color:#c7d2e2;margin-top:2px;";
  const footNote = document.createElement("div");
  footNote.style.cssText = "color:#8ea3bd;font-style:italic;margin-top:4px;font-size:12px;";
  footer.appendChild(footTitle);
  footer.appendChild(footSummary);
  footer.appendChild(footNote);

  function setMode(id) {
    modeId = id;
    const m = NEURON_MODES.filter(function (x) { return x.id === id; })[0] || NEURON_MODES[0];
    visibleStages = NEURON_TIMELINE.slice(m.first, m.last + 1);
    stage = m.first;
    progress = 0;
    for (const key in modeButtons) {
      const on = key === id;
      modeButtons[key].style.background = on ? "#2a3b52" : "#182231";
      modeButtons[key].style.color = on ? "#ffe9a8" : "#9fb0c8";
      modeButtons[key].style.borderColor = on ? "#5b7ca0" : "#3a4657";
    }
    footNote.textContent = m.simplified ? "Simplified model - omits much of the biological complexity." : "";
    syncStageCells();
    syncFooter();
  }

  function setStage(s) {
    stage = Math.max(0, Math.min(NEURON_TIMELINE.length - 1, s));
    syncStageCells();
    syncFooter();
  }

  function syncStageCells() {
    stageCells.forEach(function (c, i) {
      const inMode = visibleStages.indexOf(NEURON_TIMELINE[i]) !== -1;
      const on = i === stage;
      c.style.display = inMode ? "block" : "none";
      c.style.background = on ? "#3a2f12" : "#141c28";
      c.style.color = on ? "#ffe9a8" : (inMode ? "#9fb0c8" : "#4a5568");
      c.style.borderColor = on ? "#8a6a2a" : "#2a3646";
    });
  }

  function syncFooter() {
    const st = NEURON_TIMELINE[stage];
    footTitle.textContent = (stage + 1) + ". " + st.title;
    footSummary.textContent = st.summary;
  }

  function syncPlayButton() { btnPlay.textContent = playing ? "Pause" : "Play"; }

  btnLabels.addEventListener("click", function () {
    labelsOn = !labelsOn;
    labelsElsSet(labelsOn);
    btnLabels.textContent = "Labels: " + (labelsOn ? "on" : "off");
  });
  function labelsElsSet(on) { labelEls.forEach(function (l) { l.el.style.display = on ? "block" : "none"; }); }

  btnPlay.addEventListener("click", function () {
    playing = !playing;
    if (playing && stage >= lastStageInMode()) { stage = firstStageInMode(); progress = 0; }
    syncPlayButton();
  });
  btnReset.addEventListener("click", function () { resetView(); });
  btnClose.addEventListener("click", function () { close(); });

  function firstStageInMode() { return visibleStages[0].id; }
  function lastStageInMode() { return visibleStages[visibleStages.length - 1].id; }

  /* ---- orbit rig ---- */
  const orbit = { target: new THREE.Vector3(1.4, 0, 0), theta: 0.6, phi: 1.25, r: 7.5 };
  function resetView() {
    orbit.target.set(1.4, 0, 0);
    orbit.theta = 0.6;
    orbit.phi = 1.25;
    orbit.r = 7.5;
  }
  function applyCamera() {
    const sinPhi = Math.sin(orbit.phi);
    camera.position.set(
      orbit.target.x + orbit.r * sinPhi * Math.sin(orbit.theta),
      orbit.target.y + orbit.r * Math.cos(orbit.phi),
      orbit.target.z + orbit.r * sinPhi * Math.cos(orbit.theta));
    camera.lookAt(orbit.target);
  }

  let dragging = false, lastX = 0, lastY = 0;
  canvas.addEventListener("pointerdown", function (e) { dragging = true; lastX = e.clientX; lastY = e.clientY; canvas.setPointerCapture(e.pointerId); });
  canvas.addEventListener("pointerup", function (e) { dragging = false; try { canvas.releasePointerCapture(e.pointerId); } catch (_) {} });
  canvas.addEventListener("pointermove", function (e) {
    if (!dragging) return;
    orbit.theta -= (e.clientX - lastX) * 0.006;
    orbit.phi = Math.max(0.25, Math.min(Math.PI - 0.25, orbit.phi - (e.clientY - lastY) * 0.006));
    lastX = e.clientX; lastY = e.clientY;
  });
  canvas.addEventListener("wheel", function (e) { e.preventDefault(); orbit.r = Math.max(3, Math.min(20, orbit.r + e.deltaY * 0.01)); }, { passive: false });

  /* ---- raycast pick + highlight ---- */
  const raycaster = new THREE.Raycaster();
  const mouse = new THREE.Vector2();
  let selected = null;
  function baseColorOf(mesh) { return mesh.userData.baseColor; }
  function clearHighlight() {
    if (!selected) return;
    selected.forEach(function (m) { if (m.material && m.userData.baseColor != null) m.material.color.setHex(m.userData.baseColor); });
    selected = null;
  }
  function highlight(id) {
    clearHighlight();
    selected = pickables.filter(function (m) { return m.userData.structureId === id; });
    selected.forEach(function (m) { if (m.material) m.material.color.setHex(0xffd166); });
    const s = neuronStructureById[id];
    if (s) { footTitle.textContent = s.label; footSummary.textContent = s.role + " - " + s.detail; }
  }
  canvas.addEventListener("click", function (e) {
    const rect = canvas.getBoundingClientRect();
    mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
    raycaster.setFromCamera(mouse, camera);
    const hits = raycaster.intersectObjects(pickables, false);
    if (hits.length) highlight(hits[0].object.userData.structureId);
    else { clearHighlight(); syncFooter(); }
  });

  /* ---- per-frame animation ---- */
  function update(frame) {
    /* impulse travels along the axon fraction; map to x */
    const x0 = geo.hillock.x;
    const x1 = geo.axon.endX;
    const ix = x0 + (x1 - x0) * frame.impulse;
    const saltatory = frame.stage === 4;
    impulseMesh.visible = frame.impulse > 0.001;
    if (saltatory && geo.nodes.length) {
      /* snap toward the nearest node to suggest jumping */
      let bx = geo.nodes[0].x, best = Infinity;
      geo.nodes.forEach(function (n) { const d = Math.abs(n.x - ix); if (d < best) { best = d; bx = n.x; } });
      impulseMesh.position.set(bx, geo.axon.y, geo.axon.z);
    } else {
      impulseMesh.position.set(ix, geo.axon.y, geo.axon.z);
    }

    /* terminal glow: calcium in */
    const ca = frame.calcium ? (frame.stage === 5 ? frame.progress : 1) : 0;
    terminalMesh.material.emissive = new THREE.Color(COL.calcium).multiplyScalar(ca * 0.5);

    /* vesicles dim as they fuse */
    vesicleMeshes.forEach(function (m, i) {
      const fade = Math.max(0, 1 - frame.releaseAmount * 1.2);
      m.material.opacity = fade;
      m.material.transparent = true;
      m.scale.setScalar(0.6 + 0.4 * fade);
    });

    /* neurotransmitter flows from terminal to postsynaptic as it diffuses */
    ntMeshes.forEach(function (m) {
      const homeX = m.userData.homeX;
      const targetX = geo.postsynaptic.x - geo.postsynaptic.radius * 0.7;
      const t = frame.diffusionAmount;
      m.position.set(homeX + (targetX - homeX) * t,
        Math.cos(m.userData.angle) * (0.14 + 0.1 * t),
        Math.sin(m.userData.angle) * (0.14 + 0.1 * t));
      m.material.opacity = frame.releaseAmount > 0 ? 1 : 0.0;
      m.material.transparent = true;
      m.visible = frame.releaseAmount > 0.01;
    });

    /* receptors light up on binding */
    receptorMeshes.forEach(function (m) {
      m.material.emissive = new THREE.Color(COL.receptor)
        .multiplyScalar(frame.bindingAmount * 0.5);
    });
  }

  function projectLabels() {
    const rect = wrapper.getBoundingClientRect();
    labelEls.forEach(function (l) {
      if (!labelsOn) return;
      const v = new THREE.Vector3(l.anchor.x, l.anchor.y, l.anchor.z).project(camera);
      const sx = (v.x * 0.5 + 0.5) * rect.width;
      const sy = (-v.y * 0.5 + 0.5) * rect.height;
      const behind = v.z > 1;
      l.el.style.display = behind ? "none" : "block";
      l.el.style.left = sx + "px";
      l.el.style.top = sy + "px";
    });
  }

  let raf = 0;
  function renderFrame(dt) {
    if (playing) {
      progress += dt / STAGE_MS;
      while (progress >= 1) {
        progress -= 1;
        if (stage >= lastStageInMode()) { stage = firstStageInMode(); }
        else { stage += 1; }
        syncStageCells();
        syncFooter();
      }
    }
    const frame = frameAt(stage, progress);
    update(frame);
    applyCamera();
    projectLabels();
    renderer.render(scene, camera);
  }
  function loop(now) {
    const dt = now - lastT;
    lastT = now;
    renderFrame(dt);
    raf = requestAnimationFrame(loop);
  }

  function onResize() {
    const rw = wrapper.clientWidth || window.innerWidth;
    const rh = wrapper.clientHeight || window.innerHeight;
    renderer.setSize(rw, rh, false);
    camera.aspect = rw / rh;
    camera.updateProjectionMatrix();
  }
  window.addEventListener("resize", onResize);

  function close() {
    cancelAnimationFrame(raf);
    window.removeEventListener("resize", onResize);
    if (wrapper.parentNode) wrapper.parentNode.removeChild(wrapper);
    if (typeof opts.onClose === "function") opts.onClose();
  }

  setMode("full");
  resetView();
  labelsElsSet(true);
  if (!opts.static) {
    raf = requestAnimationFrame(loop);
  } else {
    lastT = performance.now();
    renderFrame(0);
  }

  function getStats() {
    var meshes = 0;
    var byStructure = {};
    pickables.forEach(function (m) {
      meshes++;
      var id = m.userData.structureId;
      byStructure[id] = (byStructure[id] || 0) + 1;
    });
    var expected = expectedMeshCounts(geo);
    var mismatches = [];
    Object.keys(expected).forEach(function (id) {
      if ((byStructure[id] || 0) !== expected[id]) {
        mismatches.push(id + ":" + (byStructure[id] || 0) + "!=" + expected[id]);
      }
    });
    return {
      meshes: meshes,
      byStructure: byStructure,
      expected: expected,
      mismatches: mismatches,
      internodes: geo.internodes.length,
      nodes: geo.nodes.length,
      dendrites: geo.dendrites.length,
      vesicles: geo.vesicleCount,
      neurotransmitters: geo.neurotransmitterCount,
      receptors: geo.receptorCount,
      labels: labelEls.length,
      modes: NEURON_MODES.map(function (m) { return m.id; }),
    };
  }

  function pick(id) { highlight(id); return selected ? selected.length : 0; }

  return {
    close: close,
    setStage: setStage,
    setMode: setMode,
    play: function () { playing = true; syncPlayButton(); },
    getStats: getStats,
    pick: pick,
    renderOnce: function () { renderFrame(0); },
    wrapper: wrapper,
    canvas: canvas,
  };
}
