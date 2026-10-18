/* KidneyModel: locally built half-section kidney (Stage 3). The Grab3D anatomy
   GLBs are single-mesh, so per spec the interactive segmented organ is built
   here in Three.js: extruded cut-face parts behind a shallow outer shell.
   Verified labels mirror the Grab3D human-kidney summary terms:
   cortex, renal pyramids, pelvis, ureter, red/blue renal vessels. */
import * as THREE from "three";

export const KIDNEY_VERIFIED_LABELS = ["Cortex", "Renal pyramids", "Renal pelvis", "Ureter", "Renal artery", "Renal vein"];

export function createKidneyModel(options) {
  const opts = options || {};
  const A = opts.a || 1.15;          // outline half-width
  const B = opts.b || 1.75;          // outline half-height
  const DIP = 0.42;                  // hilum notch depth (fraction of radius)
  const SIG = 0.45;                  // notch angular width (rad)
  const SEG = opts.samples || 160;   // outline samples
  const SHELL_D = 1.30;              // outer-half depth behind the cut face
  const BAND = 0.40;                 // cortex band width
  const G = 0.30;                    // cortex gap half-angle at hilum (rad)
  const FACE_Z = 0.02;               // cut-face parts sit just above the shell
  const FACE_D = 0.15;               // extrusion depth of flat parts
  const T_COLLECT = new THREE.Vector2(-0.42, 0); // collecting-system focus

  function angDelta(t) {
    let d = t - Math.PI;
    while (d > Math.PI) d -= Math.PI * 2;
    while (d < -Math.PI) d += Math.PI * 2;
    return d;
  }
  function pt(t, sx, sy) {
    const d = angDelta(t);
    const dip = 1 - DIP * Math.exp(-(d * d) / (2 * SIG * SIG));
    return new THREE.Vector2(Math.cos(t) * A * sx * dip, Math.sin(t) * B * sy * dip);
  }
  function outerPt(t) { return pt(t, 1, 1); }
  function innerPt(t) { return pt(t, (A - BAND) / A, (B - BAND) / B); }
  function shapeFrom(points) { const s = new THREE.Shape(); s.setFromPoints(points); return s; }
  function extrude(shape, depth) {
    return new THREE.ExtrudeGeometry(shape, { depth: depth, bevelEnabled: false, curveSegments: 4, steps: 1 });
  }
  function tube(points, radius) {
    const curve = new THREE.CatmullRomCurve3(points.map(function (p) { return new THREE.Vector3(p[0], p[1], p[2]); }));
    return new THREE.TubeGeometry(curve, 40, radius, 8, false);
  }
  function mat(color, roughness) {
    return new THREE.MeshStandardMaterial({ color: color, roughness: roughness == null ? 0.55 : roughness, metalness: 0.0 });
  }

  function build() {
    const root = new THREE.Group();
    root.name = "kidney-half-section";
    const parts = [];
    const labels = [];
    let freed = 0;

    function addPart(id, name, geometry, material, z) {
      const mesh = new THREE.Mesh(geometry, material);
      if (z) mesh.position.z = z;
      mesh.userData.partId = id;
      mesh.userData.partName = name || id;
      root.add(mesh);
      if (!parts.some(function (p) { return p.id === id; })) parts.push({ id: id, name: name || id, mesh: mesh });
      return mesh;
    }

    // outer half (behind the cut plane): pale face = interior background, tan sides
    const shellPts = [];
    for (let i = 0; i < SEG; i++) shellPts.push(outerPt((Math.PI * 2 * i) / SEG));
    const shellGeo = extrude(shapeFrom(shellPts), SHELL_D);
    const shellMats = [mat(0xf2e3d0, 0.7), mat(0xc9a487, 0.6)];
    const shell = new THREE.Mesh(shellGeo, shellMats);
    shell.position.z = -SHELL_D;
    shell.userData.partId = "shell";
    shell.userData.partName = "Outer half";
    root.add(shell);
    parts.push({ id: "shell", name: "Outer half", mesh: shell });

    // cortex: open band (gap at the hilum) laid on the cut face
    const CS = 110;
    const outerO = [], innerO = [];
    for (let i = 0; i <= CS; i++) {
      const t = Math.PI + G + ((Math.PI * 2 - 2 * G) * i) / CS;
      outerO.push(outerPt(t).multiplyScalar(0.99));
    }
    for (let i = CS; i >= 0; i--) {
      const t = Math.PI + G + ((Math.PI * 2 - 2 * G) * i) / CS;
      innerO.push(innerPt(t).multiplyScalar(1.01));
    }
    addPart("cortex", "Cortex", extrude(shapeFrom(outerO.concat(innerO)), FACE_D), mat(0xe07a5f), FACE_Z);

    // renal pyramids: triangles, bases on the cortex, apexes at the collecting focus
    const step = (Math.PI * 2 - 2 * G) / 8;
    const pyrApexes = [];
    for (let k = 1; k <= 7; k++) {
      const t = Math.PI + G + k * step;
      const hw = step * 0.42;
      const inset = (A - BAND - 0.04) / A, insetY = (B - BAND - 0.04) / B;
      const p1 = pt(t - hw, inset, insetY);
      const p2 = pt(t + hw, inset, insetY);
      const mid = p1.clone().add(p2).multiplyScalar(0.5);
      const apex = mid.clone().multiplyScalar(0.45).add(T_COLLECT.clone().multiplyScalar(0.55));
      pyrApexes.push(apex);
      addPart("pyramids", "Renal pyramids", extrude(shapeFrom([p1, p2, apex]), FACE_D), mat(0xa63d40, 0.5), FACE_Z);
    }

    // renal pelvis: funnel from the pyramid apexes to the hilum mouth
    const pelvisPts = [
      new THREE.Vector2(-0.26, 0.72), new THREE.Vector2(0.12, 0.44),
      new THREE.Vector2(0.30, 0.02), new THREE.Vector2(0.12, -0.44),
      new THREE.Vector2(-0.26, -0.72), new THREE.Vector2(-0.62, -0.16),
      new THREE.Vector2(-0.60, 0.16)
    ];
    addPart("pelvis", "Renal pelvis", extrude(shapeFrom(pelvisPts), FACE_D + 0.06), mat(0xf0e0b0, 0.5), FACE_Z + FACE_D);

    // ureter: exits the pelvis mouth and drops below the lower pole
    addPart("ureter", "Ureter", tube([
      [-0.56, -0.10, 0.14], [-0.74, -0.55, 0.14], [-0.66, -1.15, 0.12], [-0.52, -1.90, 0.10]
    ], 0.09), mat(0xe8cf7a, 0.45));

    // renal artery (red) and vein (blue) cross the cortex gap at the hilum
    addPart("artery", "Renal artery", tube([
      [-1.05, 0.52, 0.42], [-0.60, 0.30, 0.40], [-0.15, 0.22, 0.40], [0.30, 0.44, 0.40]
    ], 0.085), mat(0xc0392b, 0.4));
    addPart("vein", "Renal vein", tube([
      [-1.08, 0.10, 0.52], [-0.55, 0.06, 0.50], [0.05, -0.06, 0.50], [0.48, -0.32, 0.50]
    ], 0.10), mat(0x3f7fbf, 0.4));

    const anchors = {
      "Cortex": [0.75, 1.02, 0.12],
      "Renal pyramids": [0.0, -0.95, 0.10],
      "Renal pelvis": [0.0, 0.0, 0.24],
      "Ureter": [-0.72, -0.90, 0.16],
      "Renal artery": [-0.10, 0.26, 0.42],
      "Renal vein": [0.10, -0.08, 0.54]
    };
    for (const name of KIDNEY_VERIFIED_LABELS) {
      const part = parts.find(function (p) { return p.name === name; });
      labels.push({
        id: name.toLowerCase().replace(/\s+/g, "-"),
        name: name,
        partId: part ? part.id : null,
        anchor: anchors[name].slice()
      });
    }

    root.updateMatrixWorld(true);
    const bbox = new THREE.Box3().setFromObject(root);
    let triangles = 0;
    root.traverse(function (o) {
      if (o.isMesh && o.geometry) {
        const g = o.geometry;
        const count = g.index ? g.index.count : (g.attributes.position ? g.attributes.position.count : 0);
        triangles += Math.floor(count / 3);
      }
    });

    function dispose() {
      root.traverse(function (o) {
        if (o.geometry) { o.geometry.dispose(); freed++; }
        const list = o.material ? (Array.isArray(o.material) ? o.material : [o.material]) : [];
        for (const m of list) if (m) { m.dispose(); freed++; }
      });
      if (root.parent) root.parent.remove(root);
      return freed;
    }

    return {
      root: root,
      parts: parts,
      labels: labels,
      dispose: dispose,
      stats: {
        parts: parts.map(function (p) { return p.id; }),
        labels: labels.map(function (l) { return l.name; }),
        triangles: triangles,
        shellDepth: SHELL_D,
        faceDepth: 0.60,
        bbox: { min: bbox.min.toArray(), max: bbox.max.toArray() },
        halfSection: true
      }
    };
  }

  return { build: build, labels: KIDNEY_VERIFIED_LABELS };
}
