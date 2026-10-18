/* KidneyBoard: displays the Grab3D kidney on the classroom whiteboard (Stage 3b).
   Owns an offscreen scene + render target: the lab renderer draws the kidney
   into the RT each frame, and an unlit overlay plane added just in front of the
   whiteboard surface shows the result. Loads the real CC0 GLB through the
   Stage 2 catalogue/loader and falls back to the local half-section if the
   upstream relay is unavailable. */
import * as THREE from "three";
import { createKidneyModel } from "./kidney_model.js";

export function createKidneyBoard(options) {
  const opts = options || {};
  const catalogue = opts.catalogue || null;
  const loader = opts.loader || null;
  const width = opts.width || 4.2;
  const height = opts.height || 1.72;
  const position = opts.position || [0, 1.95, -5.55];
  const rtSize = opts.rtSize || 1024;

  const rt = new THREE.WebGLRenderTarget(rtSize, Math.max(1, Math.round(rtSize / (width / height))));
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0e131b);
  const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 100);
  camera.position.set(2.405, 1.58, 5.68);   // same default framing as the ?kidney=1 viewer (az .40, pol 1.32, r 6.4)
  camera.lookAt(0, 0, -0.25);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x40485c, 1.15));
  const dir = new THREE.DirectionalLight(0xffffff, 1.15);
  dir.position.set(3, 5, 4);
  scene.add(dir);

  let plane = null;
  let active = false;
  let prepared = null;
  let stage = null;
  let localModel = null;

  function normalize(gltfScene) {
    gltfScene.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(gltfScene);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());
    const s = 3.4 / (size.y || 1);
    gltfScene.scale.setScalar(s);
    gltfScene.position.set(-center.x * s, -center.y * s, -center.z * s);
    return gltfScene;
  }

  function prepareReal() {
    if (!catalogue || !loader) return Promise.reject(new Error("catalogue/loader services required"));
    return catalogue.load().then(function () {
      const m = catalogue.get("human-kidney");
      if (!m) throw new Error("human-kidney not in catalogue");
      const file = (m.glb && (m.glb.light || m.glb.full)) || null;
      const v = loader.validate(file);
      if (!v.ok) throw new Error("glb invalid: " + v.reason);
      return loader.load(file.url, { timeoutMs: 180000 });
    }).then(function (res) {
      const root = normalize(res.gltf.scene);
      scene.add(root);
      stage = { source: "grab3d", dispose: function () { return loader.dispose(res.gltf); } };
      const d = loader.describe(res.gltf);
      return { source: "grab3d", triangles: d.triangles, meshes: d.meshes };
    });
  }

  function prepare() {
    if (prepared) return prepared;
    prepared = prepareReal().catch(function (err) {
      localModel = createKidneyModel().build();
      scene.add(localModel.root);
      stage = { source: "local", dispose: function () { return localModel.dispose(); } };
      return {
        source: "local",
        triangles: localModel.stats.triangles,
        error: String((err && err.message) || err)
      };
    });
    return prepared;
  }

  function ensurePlane() {
    if (plane) return plane;
    const mat = new THREE.MeshBasicMaterial({ map: rt.texture });
    plane = new THREE.Mesh(new THREE.PlaneGeometry(width - 0.04, height - 0.04), mat);
    plane.position.set(position[0], position[1], position[2]);
    plane.visible = false;
    return plane;
  }

  return {
    prepare: prepare,
    isActive: function () { return active; },
    show: function (whiteboardGroup) {
      const p = ensurePlane();
      if (p.parent !== whiteboardGroup) whiteboardGroup.add(p);
      p.visible = true;
      active = true;
      return true;
    },
    hide: function () { active = false; if (plane) plane.visible = false; return true; },
    getPlane: function () { return plane; },
    getTexture: function () { return rt.texture; },
    getRTSize: function () { return { width: rt.width, height: rt.height, aspect: rt.width / rt.height }; },
    renderTo: function (renderer) {
      if (!active) return false;
      renderer.setRenderTarget(rt);
      renderer.render(scene, camera);
      renderer.setRenderTarget(null);
      return true;
    },
    readCenter: function (renderer) {
      const buf = new Uint8Array(4);
      try {
        renderer.readRenderTargetPixels(rt, rt.width >> 1, rt.height >> 1, 1, 1, buf);
      } catch (e) { return null; }
      return [buf[0], buf[1], buf[2], buf[3]];
    },
    dispose: function () {
      active = false;
      let freed = 0;
      if (stage) { try { freed += stage.dispose(); } catch (e) { /* best effort */ } stage = null; }
      if (plane) { if (plane.parent) plane.parent.remove(plane); plane.material.dispose(); plane.geometry.dispose(); plane = null; }
      prepared = null;
      rt.dispose();
      return freed;
    }
  };
}
