/* KidneyViewer: standalone overlay viewer for the half-section kidney (Stage 3).
   Own WebGL canvas over the lab (never touches the classroom scene), drag/wheel
   orbit rig, projected HTML labels, raycast pick + highlight, and a second view
   of the real Grab3D human-kidney GLB through the Stage 2 catalogue/loader. */
import * as THREE from "three";
import { createKidneyModel, KIDNEY_VERIFIED_LABELS } from "./kidney_model.js";

export function createKidneyViewer(options) {
  const opts = options || {};
  const container = opts.container || document.body;
  const catalogue = opts.catalogue || null;
  const loader = opts.loader || null;

  const wrapper = document.createElement("div");
  wrapper.className = "kidney-viewer";
  wrapper.style.cssText =
    "position:fixed;left:0;top:0;width:100vw;height:100vh;background:#0e131b;" +
    "z-index:" + (opts.zIndex || 60) + ";overflow:hidden;touch-action:none;";
  const canvas = document.createElement("canvas");
  canvas.style.cssText = "position:absolute;left:0;top:0;width:100%;height:100%;display:block;";
  wrapper.appendChild(canvas);

  const labelLayer = document.createElement("div");
  labelLayer.style.cssText = "position:absolute;left:0;top:0;width:100%;height:100%;pointer-events:none;";
  wrapper.appendChild(labelLayer);

  const toolbar = document.createElement("div");
  toolbar.style.cssText =
    "position:absolute;left:12px;top:12px;display:flex;gap:8px;align-items:center;" +
    "font:13px 'Segoe UI',system-ui,sans-serif;";
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
  const btnHalf = makeButton("Half-section (labeled)");
  const btnModel = makeButton("Real model (Grab3D)");
  const btnReset = makeButton("Reset view");
  const status = document.createElement("span");
  status.style.cssText = "font:13px 'Segoe UI',system-ui,sans-serif;color:#9fb0c8;padding-left:6px;";
  status.textContent = "drag to orbit - click a part";
  toolbar.appendChild(status);
  wrapper.appendChild(toolbar);

  const footer = document.createElement("div");
  footer.style.cssText =
    "position:absolute;left:14px;bottom:12px;font:13px 'Segoe UI',system-ui,sans-serif;" +
    "color:#dbe4f0;background:rgba(14,19,27,.78);border:1px solid #2a3646;" +
    "border-radius:6px;padding:6px 10px;min-width:120px;";
  footer.textContent = "";
  wrapper.appendChild(footer);
  container.appendChild(wrapper);

  const w = wrapper.clientWidth || window.innerWidth || 800;
  const h = wrapper.clientHeight || window.innerHeight || 600;
  const renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true });
  renderer.setPixelRatio(1);
  renderer.setSize(w, h, false);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0e131b);
  const camera = new THREE.PerspectiveCamera(45, w / h, 0.1, 100);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x40485c, 1.15));
  const dir = new THREE.DirectionalLight(0xffffff, 1.15);
  dir.position.set(3, 5, 4);
  scene.add(dir);

  const model = createKidneyModel().build();
  scene.add(model.root);
  const realGroup = new THREE.Group();
  realGroup.visible = false;
  scene.add(realGroup);

  const labelEls = model.labels.map(function (l) {
    const el = document.createElement("div");
    el.textContent = l.name;
    el.style.cssText =
      "position:absolute;transform:translate(10px,-50%);font:12px 'Segoe UI',system-ui,sans-serif;" +
      "color:#f2f6fc;background:rgba(20,29,42,.85);border:1px solid #4a5a72;border-left:3px solid #7fb3ff;" +
      "padding:2px 7px;border-radius:4px;white-space:nowrap;";
    labelLayer.appendChild(el);
    return { label: l, el: el };
  });

  const cam = { az: 0.62, pol: 1.32, r: 6.4, tx: 0, ty: 0, tz: -0.25 };
  function applyCamera() {
    cam.pol = Math.min(Math.PI - 0.15, Math.max(0.15, cam.pol));
    cam.r = Math.min(14, Math.max(3.2, cam.r));
    camera.position.set(
      cam.tx + cam.r * Math.sin(cam.pol) * Math.sin(cam.az),
      cam.ty + cam.r * Math.cos(cam.pol),
      cam.tz + cam.r * Math.sin(cam.pol) * Math.cos(cam.az)
    );
    camera.lookAt(cam.tx, cam.ty, cam.tz);
    camera.updateMatrixWorld(true);
  }
  applyCamera();

  let view = "half";
  let highlighted = null;
  let disposed = false;
  let raf = 0;
  const raycaster = new THREE.Raycaster();

  function labelAnchorWorld(l) {
    return new THREE.Vector3(l.anchor[0], l.anchor[1], l.anchor[2]);
  }
  function updateLabels() {
    const show = view === "half";
    labelLayer.style.display = show ? "" : "none";
    if (!show) return;
    camera.updateMatrixWorld(true);
    for (const item of labelEls) {
      const v = labelAnchorWorld(item.label).project(camera);
      const on = v.z > -1 && v.z < 1;
      item.el.style.display = on ? "" : "none";
      if (!on) continue;
      item.el.style.left = ((v.x * 0.5 + 0.5) * w) + "px";
      item.el.style.top = ((-v.y * 0.5 + 0.5) * h) + "px";
    }
  }
  function frame() {
    if (disposed) return;
    updateLabels();
    renderer.render(scene, camera);
    raf = requestAnimationFrame(frame);
  }
  raf = requestAnimationFrame(frame);

  // --- pointer orbit / wheel zoom ---
  let dragging = false, lastX = 0, lastY = 0, moved = 0;
  function onDown(e) {
    dragging = true; moved = 0;
    lastX = e.clientX; lastY = e.clientY;
    wrapper.setPointerCapture && wrapper.setPointerCapture(e.pointerId);
  }
  function onMove(e) {
    if (!dragging) return;
    const dx = e.clientX - lastX, dy = e.clientY - lastY;
    moved += Math.abs(dx) + Math.abs(dy);
    lastX = e.clientX; lastY = e.clientY;
    cam.az -= dx * 0.006;
    cam.pol -= dy * 0.006;
    applyCamera();
  }
  function onUp(e) {
    if (!dragging) return;
    dragging = false;
    if (moved < 6) pickAt(e.clientX, e.clientY);
  }
  function onWheel(e) {
    e.preventDefault();
    cam.r *= e.deltaY > 0 ? 1.08 : 0.93;
    applyCamera();
  }
  wrapper.addEventListener("pointerdown", onDown);
  wrapper.addEventListener("pointermove", onMove);
  wrapper.addEventListener("pointerup", onUp);
  wrapper.addEventListener("wheel", onWheel, { passive: false });

  function setHighlight(partId) {
    highlighted = partId || null;
    model.root.traverse(function (o) {
      if (!o.isMesh) return;
      const list = Array.isArray(o.material) ? o.material : [o.material];
      const on = partId && o.userData.partId === partId;
      for (const m of list) if (m && m.emissive) m.emissive.setHex(on ? 0x554422 : 0x000000);
    });
    const part = model.parts.find(function (p) { return p.id === partId; });
    footer.textContent = part ? part.name : "";
    return highlighted;
  }
  function pickNdc(nx, ny) {
    raycaster.setFromCamera({ x: nx, y: ny }, camera);
    const hits = raycaster.intersectObject(model.root, true);
    for (const hit of hits) {
      if (hit.object.visible && hit.object.userData.partId) {
        return { partId: hit.object.userData.partId, name: hit.object.userData.partName, distance: hit.distance };
      }
    }
    return null;
  }
  function pickAt(clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    const hit = pickNdc(((clientX - rect.left) / rect.width) * 2 - 1, -(((clientY - rect.top) / rect.height) * 2 - 1));
    setHighlight(hit ? hit.partId : null);
    return hit;
  }
  function projectAnchor(labelId) {
    const item = labelEls.find(function (l) { return l.label.id === labelId || l.label.partId === labelId || l.label.name === labelId; });
    if (!item) return null;
    const v = labelAnchorWorld(item.label).project(camera);
    return { x: v.x, y: v.y, z: v.z, visible: v.z > -1 && v.z < 1 };
  }

  // --- real Grab3D model view (Stage 2 pipeline) ---
  let realP = null, realStats = null, catInfo = null;
  function ensureReal() {
    if (realP) return realP;
    if (!catalogue || !loader) return Promise.reject(new Error("catalogue/loader services required"));
    realP = catalogue.load().then(function (info) {
      catInfo = info;
      const m = catalogue.get("human-kidney");
      if (!m) throw new Error("human-kidney not in catalogue");
      const file = (m.glb && (m.glb.light || m.glb.full)) || null;
      const v = loader.validate(file);
      if (!v.ok) throw new Error("glb invalid: " + v.reason);
      return loader.load(file.url, { timeoutMs: 180000 });
    }).then(function (res) {
      res.gltf.scene.updateMatrixWorld(true);
      const box = new THREE.Box3().setFromObject(res.gltf.scene);
      const size = box.getSize(new THREE.Vector3());
      const center = box.getCenter(new THREE.Vector3());
      const s = 3.4 / (size.y || 1);
      res.gltf.scene.scale.setScalar(s);
      res.gltf.scene.position.set(-center.x * s, -center.y * s, -center.z * s);
      realGroup.add(res.gltf.scene);
      realStats = loader.describe(res.gltf);
      realStats.source = catInfo ? { count: catInfo.count, source: catInfo.source } : null;
      return realStats;
    });
    return realP;
  }
  function setView(name) {
    if (name === "model") {
      return ensureReal().then(function (st) {
        model.root.visible = false;
        realGroup.visible = true;
        view = "model";
        footer.textContent = "Grab3D human-kidney (CC0)";
        btnModel.style.background = "#24384f";
        btnHalf.style.background = "#182231";
        return st;
      }, function (err) {
        status.textContent = "real model failed: " + ((err && err.message) || err);
        throw err;
      });
    }
    if (realGroup) realGroup.visible = false;
    model.root.visible = true;
    view = "half";
    footer.textContent = "";
    btnHalf.style.background = "#24384f";
    btnModel.style.background = "#182231";
    return Promise.resolve({ view: "half" });
  }
  btnHalf.addEventListener("click", function () { setView("half"); });
  btnModel.addEventListener("click", function () { status.textContent = "loading Grab3D model..."; setView("model").then(function () { status.textContent = "drag to orbit - click a part"; }); });
  btnReset.addEventListener("click", function () { cam.az = 0.62; cam.pol = 1.32; cam.r = 6.4; applyCamera(); });
  setView("half");

  function dispose() {
    if (disposed) return 0;
    disposed = true;
    cancelAnimationFrame(raf);
    let freed = model.dispose();
    if (realGroup.children.length) {
      realGroup.traverse(function (o) {
        if (o.geometry) { o.geometry.dispose(); freed++; }
        const list = o.material ? (Array.isArray(o.material) ? o.material : [o.material]) : [];
        for (const m of list) if (m) { m.dispose(); freed++; }
      });
      realGroup.clear();
    }
    renderer.dispose();
    if (wrapper.parentNode) wrapper.parentNode.removeChild(wrapper);
    return freed;
  }

  return {
    wrapper: wrapper,
    canvas: canvas,
    dom: { wrapper: wrapper, canvas: canvas, toolbar: toolbar, labelLayer: labelLayer, labels: labelEls.map(function (l) { return l.el; }) },
    setView: setView,
    getView: function () { return view; },
    orbitBy: function (dx, dy) { cam.az -= dx; cam.pol -= dy; applyCamera(); },
    zoomBy: function (f) { cam.r *= f; applyCamera(); },
    getCameraState: function () { return { az: cam.az, pol: cam.pol, r: cam.r }; },
    pickNdc: pickNdc,
    pickAt: pickAt,
    highlight: setHighlight,
    getHighlight: function () { return highlighted; },
    projectAnchor: projectAnchor,
    renderOnce: function () { updateLabels(); renderer.render(scene, camera); },
    getLabels: function () { return model.labels.map(function (l) { return { id: l.id, name: l.name, partId: l.partId, anchor: l.anchor.slice() }; }); },
    getModelStats: function () { return model.stats; },
    getRealStats: function () { return realStats; },
    verifiedLabels: KIDNEY_VERIFIED_LABELS,
    isDisposed: function () { return disposed; },
    dispose: dispose
  };
}
