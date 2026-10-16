import * as THREE from '../vendor/three.module.min.js';

function makeMaterial(color, roughness = 0.82, metalness = 0) {
  return new THREE.MeshStandardMaterial({ color, roughness, metalness });
}

function addBox(parent, name, size, position, material, rotation = [0, 0, 0]) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(...size), material);
  mesh.name = name;
  mesh.position.set(...position);
  mesh.rotation.set(...rotation);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function addCylinder(parent, name, radiusTop, radiusBottom, height, position, material, segments = 24) {
  const mesh = new THREE.Mesh(
    new THREE.CylinderGeometry(radiusTop, radiusBottom, height, segments),
    material,
  );
  mesh.name = name;
  mesh.position.set(...position);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function addGlassware(parent, materials, x, z, height = 0.72, color = materials.glass) {
  const group = new THREE.Group();
  group.position.set(x, 1.88, z);
  parent.add(group);
  addCylinder(group, 'glass body', 0.12, 0.15, height * 0.55, [0, height * 0.27, 0], color, 20);
  addCylinder(group, 'glass neck', 0.055, 0.055, height * 0.34, [0, height * 0.72, 0], color, 16);
  addCylinder(group, 'glass rim', 0.075, 0.075, 0.025, [0, height * 0.9, 0], color, 16);
  addCylinder(group, 'solution', 0.13, 0.14, height * 0.12, [0, height * 0.12, 0], materials.liquid, 20);
  return group;
}

function buildRoom() {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color('#d9e0e3');
  scene.fog = new THREE.Fog('#d9e0e3', 22, 45);

  const materials = {
    floor: makeMaterial('#c8c7bf'),
    wall: makeMaterial('#e7e8e3'),
    trim: makeMaterial('#b4b9b7'),
    glass: new THREE.MeshPhysicalMaterial({
      color: '#c9e3e7',
      roughness: 0.18,
      metalness: 0,
      transmission: 0.22,
      transparent: true,
      opacity: 0.62,
      thickness: 0.12,
    }),
    window: new THREE.MeshPhysicalMaterial({
      color: '#98c7d7',
      roughness: 0.22,
      metalness: 0.12,
      transmission: 0.16,
      transparent: true,
      opacity: 0.58,
    }),
    blue: makeMaterial('#176e9b', 0.56),
    blueDark: makeMaterial('#0d527b', 0.58),
    counter: makeMaterial('#dadbd5', 0.36),
    steel: makeMaterial('#919b9d', 0.28, 0.72),
    darkSteel: makeMaterial('#505c60', 0.35, 0.58),
    black: makeMaterial('#242a2c', 0.46),
    white: makeMaterial('#f3f2ec', 0.56),
    rubber: makeMaterial('#373b3a', 0.78),
    wood: makeMaterial('#b68e5d', 0.74),
    liquid: new THREE.MeshStandardMaterial({
      color: '#e7c75a', roughness: 0.3, transparent: true, opacity: 0.78,
    }),
    red: makeMaterial('#b64e45', 0.5),
    green: makeMaterial('#527c63', 0.52),
  };

  scene.add(new THREE.HemisphereLight('#f5f7f5', '#8d9698', 2.25));
  const key = new THREE.DirectionalLight('#fff5df', 3.1);
  key.position.set(-5, 10, 8);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  scene.add(key);
  const fill = new THREE.DirectionalLight('#d7e9ff', 1.15);
  fill.position.set(7, 6, -4);
  scene.add(fill);

  const room = new THREE.Group();
  room.name = 'Chemistry laboratory room';
  scene.add(room);
  addBox(room, 'tiled floor', [14, 0.22, 10], [0, -0.11, 0], materials.floor);
  addBox(room, 'back wall below windows', [14, 3.02, 0.22], [0, 1.51, -4.9], materials.wall);
  addBox(room, 'back wall above windows', [14, 0.86, 0.22], [0, 5.77, -4.9], materials.wall);
  for (const x of [-6.61, -3.3, -0.1, 3.1, 6.51]) {
    const width = Math.abs(x) > 6 ? 0.78 : 0.55;
    addBox(room, 'wall between windows', [width, 2.32, 0.22], [x, 4.18, -4.9], materials.wall);
  }
  addBox(room, 'left wall', [0.22, 6.2, 10], [-7, 3.1, 0], materials.wall);
  addBox(room, 'right wall', [0.22, 6.2, 10], [7, 3.1, 0], materials.wall);
  addBox(room, 'ceiling', [14, 0.18, 10], [0, 6.2, 0], materials.white);

  for (const x of [-4.9, -1.7, 1.5, 4.7]) {
    addBox(room, 'window glass', [2.65, 2.2, 0.06], [x, 4.18, -4.76], materials.window);
    for (const dx of [-1.36, 0, 1.36]) {
      addBox(room, 'window mullion', [0.055, 2.32, 0.09], [x + dx, 4.18, -4.68], materials.trim);
    }
    for (const y of [3.02, 5.34]) {
      addBox(room, 'window rail', [2.82, 0.06, 0.09], [x, y, -4.68], materials.trim);
    }
  }
  addBox(room, 'back wall skirting', [14, 0.2, 0.12], [0, 0.1, -4.73], materials.white);
  addBox(room, 'left wall skirting', [0.12, 0.2, 10], [-6.84, 0.1, 0], materials.white);
  addBox(room, 'right wall skirting', [0.12, 0.2, 10], [6.84, 0.1, 0], materials.white);

  const bench = new THREE.Group();
  bench.name = 'Blue laboratory bench';
  room.add(bench);
  addBox(bench, 'bench worktop', [11.8, 0.2, 1.35], [0, 1.78, -3.55], materials.counter);
  addBox(bench, 'bench front rail', [11.8, 0.15, 0.12], [0, 1.64, -2.86], materials.steel);
  addBox(bench, 'bench back splash', [11.8, 1.4, 0.1], [0, 2.1, -4.26], materials.blueDark);
  for (let x = -5.25; x <= 5.26; x += 1.5) {
    addBox(bench, 'blue cabinet door', [1.35, 1.43, 0.12], [x, 0.83, -2.83], materials.blue);
    addBox(bench, 'cabinet handle', [0.31, 0.035, 0.055], [x, 0.94, -2.72], materials.steel);
  }
  addBox(bench, 'bench side panel', [0.13, 1.47, 1.3], [-5.95, 0.84, -3.52], materials.blueDark);
  addBox(bench, 'bench side panel', [0.13, 1.47, 1.3], [5.95, 0.84, -3.52], materials.blueDark);

  const hood = new THREE.Group();
  hood.name = 'Fume hood';
  room.add(hood);
  addBox(hood, 'hood housing', [3.15, 1.15, 1.12], [3.7, 3.05, -3.73], materials.white);
  addBox(hood, 'hood canopy', [3.4, 0.18, 1.45], [3.7, 3.72, -3.65], materials.steel);
  addBox(hood, 'hood front frame', [3.08, 1.12, 0.12], [3.7, 3.02, -3.12], materials.trim);
  addBox(hood, 'hood sash glass', [2.75, 0.88, 0.045], [3.7, 3.04, -3.04], materials.glass);
  addBox(hood, 'hood work surface', [3.0, 0.12, 1.1], [3.7, 2.34, -3.62], materials.counter);
  addBox(hood, 'hood lower cabinet', [3.1, 0.95, 1.08], [3.7, 1.88, -3.75], materials.blueDark);
  addBox(hood, 'hood exhaust stack', [0.66, 0.9, 0.7], [3.7, 4.22, -4.08], materials.trim);
  for (const x of [2.5, 4.9]) addBox(hood, 'hood upright', [0.1, 1.12, 0.11], [x, 3.03, -3.02], materials.steel);
  addBox(hood, 'hood label', [1.72, 0.38, 0.04], [3.7, 3.2, -2.96], new THREE.MeshStandardMaterial({ color: '#0c3d6b', roughness: 0.5 }));

  const sink = new THREE.Group();
  sink.name = 'Bench sink and tap';
  room.add(sink);
  addBox(sink, 'sink basin', [1.1, 0.13, 0.67], [-2.7, 1.65, -3.52], materials.darkSteel);
  addBox(sink, 'sink inset', [0.83, 0.035, 0.43], [-2.7, 1.72, -3.52], materials.black);
  addCylinder(sink, 'tap stem', 0.055, 0.055, 0.55, [-2.7, 2.1, -4.0], materials.steel);
  addCylinder(sink, 'tap spout', 0.045, 0.045, 0.48, [-2.48, 2.35, -4.0], materials.steel, 16)
    .rotation.z = Math.PI / 2;

  const safetySign = new THREE.Group();
  safetySign.position.set(-6.3, 3.2, -4.15);
  room.add(safetySign);
  addBox(safetySign, 'safety sign backing', [1.82, 1.9, 0.05], [0, 0, 0], new THREE.MeshStandardMaterial({ color: '#f4f6f4', roughness: 0.7 }));
  addCylinder(safetySign, 'safety icon', 0.18, 0.18, 0.08, [-0.5, 0.42, 0.08], materials.blueDark, 28);
  addBox(safetySign, 'safety glove mark', [0.26, 0.12, 0.03], [-0.5, 0.42, 0.12], materials.white);
  addBox(safetySign, 'safety check mark', [0.42, 0.08, 0.03], [0.18, -0.18, 0.12], materials.blueDark);
  addBox(safetySign, 'safety warning stripe', [0.22, 1.2, 0.02], [0.58, 0.1, 0.12], materials.red);

  const shelf = new THREE.Group();
  shelf.name = 'Reagent shelf';
  room.add(shelf);
  for (const y of [2.57, 3.13]) {
    addBox(shelf, 'wall shelf', [4.5, 0.09, 0.48], [-1.45, y, -4.38], materials.wood);
  }
  for (const x of [-3.3, 0.4]) addBox(shelf, 'shelf bracket', [0.08, 0.62, 0.1], [x, 2.83, -4.47], materials.steel);
  const bottleColors = [materials.green, materials.red, materials.white, materials.liquid];
  for (let i = 0; i < 7; i++) {
    const x = -3.2 + i * 0.57;
    const m = bottleColors[i % bottleColors.length];
    addCylinder(shelf, 'reagent bottle', 0.12, 0.16, 0.38, [x, 2.81, -4.02], m, 18);
    addCylinder(shelf, 'bottle stopper', 0.07, 0.07, 0.1, [x, 3.05, -4.02], materials.black, 14);
  }

  const board = new THREE.Group();
  board.position.set(5.25, 3.2, -4.08);
  room.add(board);
  addBox(board, 'whiteboard backing', [2.8, 1.8, 0.06], [0, 0, 0], materials.white);
  addBox(board, 'whiteboard frame', [2.96, 1.96, 0.08], [0, 0, -0.02], materials.trim);
  const periodicTableColors = ['#ff8ca1', '#a2d5ff', '#a9f1b6', '#ffd388', '#f5c4ff', '#9be3ff', '#c8ff8f', '#ffc7a6'];
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 9; c++) {
      const x = -1.1 + (c * 0.25);
      const y = 0.6 - (r * 0.26);
      addBox(board, 'periodic tile', [0.18, 0.12, 0.04], [x, y, 0.08], new THREE.MeshStandardMaterial({ color: periodicTableColors[(r + c) % periodicTableColors.length], roughness: 0.7 }));
    }
  }
  addBox(board, 'reaction title', [1.9, 0.2, 0.04], [0, 0.55, 0.09], materials.white);

  addGlassware(bench, materials, -4.8, -3.47, 0.76);
  addGlassware(bench, materials, -4.1, -3.50, 0.92, materials.glass);
  addGlassware(bench, materials, -0.3, -3.50, 0.7);
  addGlassware(bench, materials, 0.45, -3.48, 0.85, materials.glass);

  const rack = new THREE.Group();
  rack.name = 'Test tube rack';
  bench.add(rack);
  addBox(rack, 'rack base', [1.15, 0.13, 0.42], [-1.4, 1.9, -3.28], materials.wood);
  addBox(rack, 'rack top', [1.15, 0.1, 0.42], [-1.4, 2.2, -3.28], materials.wood);
  for (let i = 0; i < 6; i++) {
    const x = -1.86 + i * 0.18;
    addCylinder(rack, 'test tube', 0.055, 0.055, 0.48, [x, 2.38, -3.28], materials.glass, 14);
    addCylinder(rack, 'sample', 0.047, 0.047, 0.16, [x, 2.18, -3.28], materials.liquid, 14);
  }

  const largeFlask = new THREE.Group();
  largeFlask.position.set(-1.1, 1.7, -3.26);
  bench.add(largeFlask);
  addCylinder(largeFlask, 'flask body', 0.53, 0.66, 1.1, [0, 0.36, 0], materials.glass, 28);
  addCylinder(largeFlask, 'flask neck', 0.13, 0.13, 0.38, [0, 1.08, 0], materials.glass, 18);
  addCylinder(largeFlask, 'liquid fill', 0.48, 0.58, 0.64, [0, 0.18, 0], new THREE.MeshStandardMaterial({ color: '#1d8cd6', roughness: 0.3, transparent: true, opacity: 0.85 }));

  const stirPlate = new THREE.Group();
  stirPlate.position.set(5.2, 1.82, -3.2);
  bench.add(stirPlate);
  addBox(stirPlate, 'stir plate base', [1.45, 0.12, 1.15], [0, 0.06, 0], materials.blue);
  addCylinder(stirPlate, 'stir plate hub', 0.52, 0.52, 0.06, [0, 0.14, 0], materials.steel, 28);
  addCylinder(stirPlate, 'stir plate knob', 0.12, 0.12, 0.08, [0.42, 0.18, -0.18], materials.black, 16);
  addCylinder(stirPlate, 'stir plate vessel', 0.34, 0.44, 0.25, [0, 0.28, 0], materials.glass, 20);

  const microscope = new THREE.Group();
  microscope.name = 'Compound microscope';
  microscope.position.set(-4.85, 1.89, -1.95);
  bench.add(microscope);
  addCylinder(microscope, 'microscope base', 0.34, 0.42, 0.13, [0, 0.08, 0], materials.black);
  addBox(microscope, 'microscope foot', [0.62, 0.11, 0.34], [0, 0.1, 0], materials.black);
  addCylinder(microscope, 'microscope column', 0.09, 0.12, 0.9, [0, 0.53, -0.11], materials.steel, 18)
    .rotation.z = -0.24;
  addBox(microscope, 'microscope stage', [0.58, 0.09, 0.48], [0.06, 0.55, 0.12], materials.darkSteel);
  addCylinder(microscope, 'microscope tube', 0.11, 0.14, 0.54, [0.14, 0.98, 0.01], materials.black, 20)
    .rotation.z = -0.48;
  addCylinder(microscope, 'eyepiece', 0.1, 0.1, 0.18, [-0.01, 1.19, 0.08], materials.steel, 18)
    .rotation.z = -0.48;
  addCylinder(microscope, 'objective turret', 0.17, 0.17, 0.11, [0.3, 0.72, 0.03], materials.steel);
  for (const x of [0.17, 0.3, 0.43]) {
    addCylinder(microscope, 'objective lens', 0.055, 0.07, 0.26, [x, 0.54, 0.1], materials.black, 14);
  }
  addCylinder(microscope, 'focus knob', 0.14, 0.14, 0.08, [-0.13, 0.54, -0.15], materials.steel);

  const burner = new THREE.Group();
  burner.name = 'Bunsen burner';
  burner.position.set(1.9, 1.88, -3.5);
  bench.add(burner);
  addCylinder(burner, 'burner base', 0.2, 0.27, 0.12, [0, 0.06, 0], materials.darkSteel);
  addCylinder(burner, 'burner barrel', 0.085, 0.12, 0.58, [0, 0.39, 0], materials.steel);
  addCylinder(burner, 'burner collar', 0.13, 0.13, 0.1, [0, 0.17, 0], materials.blue);

  const stool = new THREE.Group();
  stool.name = 'Laboratory stool';
  stool.position.set(-1.65, 0, 1.15);
  room.add(stool);
  addCylinder(stool, 'stool seat', 0.66, 0.66, 0.18, [0, 1.36, 0], materials.black);
  addCylinder(stool, 'stool post', 0.095, 0.095, 1.27, [0, 0.68, 0], materials.steel);
  addCylinder(stool, 'stool base hub', 0.2, 0.2, 0.16, [0, 0.1, 0], materials.darkSteel);
  for (let i = 0; i < 5; i++) {
    const angle = (i / 5) * Math.PI * 2;
    const leg = addBox(stool, 'stool foot', [0.75, 0.08, 0.11], [
      Math.cos(angle) * 0.33, 0.06, Math.sin(angle) * 0.33,
    ], materials.darkSteel, [0, -angle, 0]);
    leg.position.x += Math.cos(angle) * 0.28;
    leg.position.z += Math.sin(angle) * 0.28;
  }

  return scene;
}

class ChemistryLabEngine {
  init(hostId) {
    this.dispose();
    this.host = document.getElementById(hostId);
    if (!this.host) throw new Error(`Chemistry Lab viewport host "${hostId}" was not found.`);
    this.scene = buildRoom();
    this.camera = new THREE.PerspectiveCamera(42, 1, 0.1, 100);
    this.target = new THREE.Vector3(0, 2.2, -0.3);
    this.radius = 16;
    this.theta = 0.4;
    this.phi = 1.14;
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.12;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.domElement.style.cssText = 'width:100%;height:100%;display:block;touch-action:none;cursor:grab';
    this.host.replaceChildren(this.renderer.domElement);
    this._drag = null;
    this._onPointerDown = (event) => {
      if (event.button !== 0 && event.button !== 2) return;
      this.renderer.domElement.setPointerCapture(event.pointerId);
      this._drag = { x: event.clientX, y: event.clientY, button: event.button };
      this.renderer.domElement.style.cursor = 'grabbing';
    };
    this._onPointerMove = (event) => {
      if (!this._drag) return;
      const dx = event.clientX - this._drag.x;
      const dy = event.clientY - this._drag.y;
      this._drag.x = event.clientX;
      this._drag.y = event.clientY;
      if (this._drag.button === 2) {
        const shift = this.radius * 0.0018;
        this.target.x -= dx * shift;
        this.target.y += dy * shift;
      } else {
        this.theta -= dx * 0.006;
        this.phi = THREE.MathUtils.clamp(this.phi + dy * 0.006, 0.18, Math.PI - 0.18);
      }
      this._render();
    };
    this._onPointerUp = () => {
      this._drag = null;
      this.renderer.domElement.style.cursor = 'grab';
    };
    this._onWheel = (event) => {
      event.preventDefault();
      this.radius = THREE.MathUtils.clamp(this.radius * Math.exp(event.deltaY * 0.001), 6, 32);
      this._render();
    };
    this._onContextMenu = (event) => event.preventDefault();
    this.renderer.domElement.addEventListener('pointerdown', this._onPointerDown);
    this.renderer.domElement.addEventListener('pointermove', this._onPointerMove);
    this.renderer.domElement.addEventListener('pointerup', this._onPointerUp);
    this.renderer.domElement.addEventListener('pointercancel', this._onPointerUp);
    this.renderer.domElement.addEventListener('wheel', this._onWheel, { passive: false });
    this.renderer.domElement.addEventListener('contextmenu', this._onContextMenu);
    this._onResize = () => this._resize();
    window.addEventListener('resize', this._onResize);
    this._resize();
    this._render();
    if (typeof window.__penroseChemLabReady === 'function') window.__penroseChemLabReady();
  }

  _updateCamera() {
    const sinPhi = Math.sin(this.phi);
    this.camera.position.set(
      this.target.x + this.radius * sinPhi * Math.sin(this.theta),
      this.target.y + this.radius * Math.cos(this.phi),
      this.target.z + this.radius * sinPhi * Math.cos(this.theta),
    );
    this.camera.lookAt(this.target);
  }

  _resize() {
    if (!this.host || !this.renderer) return;
    const width = Math.max(1, this.host.clientWidth);
    const height = Math.max(1, this.host.clientHeight);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height, false);
    this._render();
  }

  _render() {
    if (!this.renderer || !this.scene) return;
    this._updateCamera();
    this.renderer.render(this.scene, this.camera);
  }

  resetCamera() {
    this.target.set(0, 2.2, -0.3);
    this.radius = 16;
    this.theta = 0.4;
    this.phi = 1.14;
    this._render();
  }

  dispose() {
    if (this._onResize) window.removeEventListener('resize', this._onResize);
    if (this.renderer) {
      const canvas = this.renderer.domElement;
      canvas.removeEventListener('pointerdown', this._onPointerDown);
      canvas.removeEventListener('pointermove', this._onPointerMove);
      canvas.removeEventListener('pointerup', this._onPointerUp);
      canvas.removeEventListener('pointercancel', this._onPointerUp);
      canvas.removeEventListener('wheel', this._onWheel);
      canvas.removeEventListener('contextmenu', this._onContextMenu);
      this.scene && this.scene.traverse((object) => {
        if (object.geometry) object.geometry.dispose();
        if (object.material) {
          for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
            material.dispose();
          }
        }
      });
      this.renderer.dispose();
      this.renderer.domElement.remove();
    }
    this.renderer = null;
    this.scene = null;
    this.host = null;
  }

  handle(json) {
    let command;
    try {
      command = JSON.parse(json);
      if (command.cmd === 'init') this.init(command.hostId);
      else if (command.cmd === 'dispose') this.dispose();
      else if (command.cmd === 'resetCamera') this.resetCamera();
      else throw new Error(`Unknown Chemistry Lab command "${command.cmd}".`);
    } catch (error) {
      console.error('[Chemistry Lab 3D]', error);
      if (typeof window.__penroseChemLabError === 'function') {
        window.__penroseChemLabError(String(error));
      }
    }
  }
}

const engine = new ChemistryLabEngine();
window.PenroseChemLab = { handle: (json) => engine.handle(json) };
