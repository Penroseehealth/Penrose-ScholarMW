/* ModelLoaderService: validate + load Grab3D GLBs through the same-origin relay.
   Only GLB is accepted; URLs must stay on our /grab3d/dl/ allowlist; models are
   parsed by GLTFLoader as data (never executed); dispose() frees GPU resources. */
import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

export function createModelLoader(options) {
  var opts = options || {};
  var loader = new GLTFLoader();
  var maxBytes = opts.maxBytes || 48 * 1024 * 1024;
  var counters = { loads: 0, failures: 0, active: 0, disposed: 0 };

  function validate(file) {
    if (!file || typeof file.url !== "string" || !file.url) return { ok: false, reason: "missing url" };
    if (file.format && file.format !== "glb") return { ok: false, reason: "unsupported format: " + file.format };
    if (!/^\/grab3d\/dl\/[a-z0-9-]+\/[A-Za-z0-9._-]+\.glb$/.test(file.url) && !/^\.?\/[\w./-]+\.glb$/.test(file.url)) {
      return { ok: false, reason: "url not allowlisted: " + file.url };
    }
    if (file.bytes != null) {
      if (typeof file.bytes !== "number" || file.bytes <= 0) return { ok: false, reason: "invalid byte size" };
      if (file.bytes > maxBytes) return { ok: false, reason: "too large: " + Math.round(file.bytes / 1048576) + "MB" };
    }
    return { ok: true };
  }

  /* load(url,{onProgress,timeoutMs}) -> Promise<{gltf, url, ms}>; rejects on
     timeout / HTTP error / parse error. GLTFLoader has no native abort, so the
     promise settles exactly once and late events are ignored. */
  function load(url, options2) {
    var o = options2 || {};
    var timeoutMs = o.timeoutMs || 180000;
    counters.loads++;
    counters.active++;
    return new Promise(function (resolve, reject) {
      var done = false;
      var timer = setTimeout(function () {
        if (done) return;
        done = true;
        counters.active--;
        counters.failures++;
        reject(new Error("load timeout after " + timeoutMs + "ms"));
      }, timeoutMs);
      function settle(err, gltf, ms) {
        if (done) return;
        done = true;
        clearTimeout(timer);
        counters.active--;
        if (err) { counters.failures++; reject(err); return; }
        resolve({ gltf: gltf, url: url, ms: ms });
      }
      var t0 = (typeof performance !== "undefined" ? performance.now() : Date.now());
      loader.load(url, function (gltf) {
        settle(null, gltf, Math.round((typeof performance !== "undefined" ? performance.now() : Date.now()) - t0));
      }, function (ev) {
        if (o.onProgress) {
          var total = ev && ev.lengthComputable && ev.total ? ev.total : 0;
          o.onProgress({ loaded: ev ? ev.loaded : 0, total: total });
        }
      }, function (err) {
        settle(new Error("glb load failed: " + ((err && err.message) || err)));
      });
    });
  }

  function describe(gltfOrScene) {
    var root = gltfOrScene && gltfOrScene.scene ? gltfOrScene.scene : gltfOrScene;
    var meshes = 0, materials = 0, tris = 0, nodes = 0;
    var mats = {};
    if (!root) return { nodes: 0, meshes: 0, materials: 0, triangles: 0 };
    root.traverse(function (o) {
      nodes++;
      if (o.isMesh && o.geometry) {
        meshes++;
        var g = o.geometry;
        var count = g.index ? g.index.count : (g.attributes.position ? g.attributes.position.count : 0);
        tris += Math.floor(count / 3);
        var list = Array.isArray(o.material) ? o.material : [o.material];
        for (var i = 0; i < list.length; i++) if (list[i]) mats[list[i].uuid] = list[i];
      }
    });
    materials = Object.keys(mats).length;
    return { nodes: nodes, meshes: meshes, materials: materials, triangles: tris };
  }

  function dispose(gltfOrScene) {
    var root = gltfOrScene && gltfOrScene.scene ? gltfOrScene.scene : gltfOrScene;
    if (!root) return 0;
    var freed = 0;
    root.traverse(function (o) {
      if (o.geometry) { o.geometry.dispose(); freed++; }
      var list = o.material ? (Array.isArray(o.material) ? o.material : [o.material]) : [];
      for (var i = 0; i < list.length; i++) {
        var m = list[i];
        if (!m) continue;
        for (var k in m) {
          var v = m[k];
          if (v && v.isTexture) v.dispose();
        }
        m.dispose();
        freed++;
      }
    });
    if (root.parent) root.parent.remove(root);
    counters.disposed += freed;
    return freed;
  }

  return { validate: validate, load: load, describe: describe, dispose: dispose, counters: counters };
}
