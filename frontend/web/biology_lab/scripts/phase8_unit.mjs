import { createCameraRig, CAM_MODES, wrapPi, easeInOut, lookFrom } from '../js/camera.js';
import { createPerf, TIERS } from '../js/perf.js';

let pass = 0, fail = 0;
function ck(name, ok, detail) {
  if (ok) { pass++; console.log('  PASS ' + name); }
  else { fail++; console.log('  FAIL ' + name + (detail ? ' - ' + detail : '')); }
}

const SEAT = { x: 1.2, y: 1.22, z: 0.6 };
const BENCH = { x: -5.2, y: 1.0, z: 0.0 };
const EYEPIECE = { pos: { x: 0, y: 1.35, z: -2.6 }, look: { x: 0, y: 1.05, z: -2.65 } };

function makeRig(over) {
  let teacher = { x: 0, z: 0, yaw: 0 };
  const orbitState = { target: { x: 0.3, y: 1.05, z: -0.7 }, theta: 0.55, phi: 1.32, r: 4.4 };
  const rig = createCameraRig(Object.assign({
    orbit: () => ({ target: { ...orbitState.target }, theta: orbitState.theta, phi: orbitState.phi, r: orbitState.r }),
    seat: () => SEAT,
    studentEye: () => ({ x: SEAT.x, y: 1.22, z: SEAT.z }),
    teacher: () => teacher,
    equip: (id) => (id === 'micro.front' ? { x: 0, y: 1.1, z: -2.6 } : null),
    eyepiece: () => EYEPIECE,
    demoPoint: () => BENCH,
  }, over || {}));
  return { rig, orbitState, setTeacher: (t) => { teacher = t; } };
}

console.log('=== Phase 8 unit: helpers ===');
{
  ck('wrapPi(3*pi) = pi', Math.abs(wrapPi(3 * Math.PI) - Math.PI) < 1e-9);
  ck('wrapPi(-3*pi) = -pi', Math.abs(wrapPi(-3 * Math.PI) + Math.PI) < 1e-9);
  ck('wrapPi small unchanged', wrapPi(0.5) === 0.5);
  ck('easeInOut(0)=0', easeInOut(0) === 0);
  ck('easeInOut(1)=1', easeInOut(1) === 1);
  ck('easeInOut(0.5)=0.5', Math.abs(easeInOut(0.5) - 0.5) < 1e-9);
  ck('easeInOut monotonic', easeInOut(0.25) < easeInOut(0.75));
  const sph = lookFrom({ x: 0, y: 0, z: 1 }, { x: 0, y: 0, z: 0 });
  ck('lookFrom r=1', Math.abs(sph.r - 1) < 1e-9);
  ck('lookFrom phi=pi/2 horizontal', Math.abs(sph.phi - Math.PI / 2) < 1e-9);
}

console.log('=== Phase 8 unit: camera rig ===');
{
  const { rig, setTeacher } = makeRig();
  ck('initial mode orbit', rig.status().mode === 'orbit');
  ck('CAM_MODES complete', CAM_MODES.join(',') === 'orbit,student,follow,closeup,eyepiece,demo');

  /* free inspection (existing controls) preserved in orbit mode */
  const o0 = rig.tick(0.016);
  ck('orbit tick returns orbit view (controls preserved)', o0 && o0.r === 4.4 && o0.theta === 0.55, JSON.stringify(o0));

  /* student first-person view */
  ck('student view sets mode', rig.setView('student') === true && rig.status().mode === 'student');
  const s1 = rig.tick(10);
  ck('student view settles between seat and bench', s1 && s1.target.x < SEAT.x && s1.target.x > BENCH.x, JSON.stringify(s1 && s1.target));
  ck('student view nearly horizontal', s1.phi > 1.2 && s1.phi <= 1.5, s1.phi);

  /* follow camera tracks the teacher */
  setTeacher({ x: 1.0, z: -1.0, yaw: 0.5 });
  ck('follow mode on', rig.setView('follow') === true);
  const f1 = rig.tick(10);
  ck('follow settles behind teacher', f1 && Math.abs(f1.r - 2.4) < 1e-6 && Math.abs(f1.theta - (0.5 + Math.PI)) < 1e-6);
  setTeacher({ x: -2.0, z: 2.0, yaw: 1.5 });
  const f2 = rig.tick(0.5);
  ck('follow re-aims continuously', f2 && Math.abs(f2.target.x - -0.7) < 1.5, f2 && f2.target.x);

  /* close-up + selection */
  ck('closeup on selected object', rig.setView('closeup', 'micro.front') === true);
  const c1 = rig.tick(10);
  ck('closeup targets the equipment', c1 && Math.abs(c1.target.y - 1.1) < 1e-9 && Math.abs(c1.r - 0.85) < 1e-9, JSON.stringify(c1));
  ck('closeup keeps the selection', rig.status().selected === 'micro.front');
  ck('closeup narrows fov', c1.fov === 38);

  /* eyepiece view */
  ck('eyepiece mode on', rig.setView('eyepiece') === true);
  const e1 = rig.tick(10);
  ck('eyepiece aims along the optical axis', e1 && Math.abs(e1.target.z - EYEPIECE.look.z) < 1e-9);
  ck('eyepiece narrow fov', e1.fov === 26);
  ck('unknown object closeup refused', rig.setView('closeup', 'nope') === false);
  ck('unknown mode refused', rig.setView('teleport') === false);

  /* smoothness: angular speed capped during transitions */
  const { rig: rig2 } = makeRig();
  rig2.setView('orbit', null, { instant: true });
  /* force a big angular jump by hand-setting a far theta target via student->follow */
  rig2.setView('student');
  let maxAng = 0;
  let prev = rig2.tick(0).theta;
  for (let t = 0; t < 3.0; t += 0.033) {
    const v = rig2.tick(0.033);
    const d = Math.abs(wrapPi(v.theta - prev));
    maxAng = Math.max(maxAng, d / 0.033);
    prev = v.theta;
  }
  ck('transition angular speed <= 2.2 rad/s', maxAng <= 2.2, maxAng.toFixed(2));
  ck('transitioning clears after settle', rig2.status().transitioning === false);

  /* orbit return restores controls */
  ck('back to orbit', rig2.setView('orbit') === true);
  const back = rig2.tick(10);
  ck('orbit view restored', back && back.r === 4.4);

  /* transitions logged */
  ck('transitions logged', rig2.status().transitions >= 2, rig2.status().transitions);
}

console.log('=== Phase 8 unit: demo (step-by-step, pause/resume/replay) ===');
{
  const { rig } = makeRig();
  const n = rig.demoSet([
    { id: 'micro.front', hold: 0.5 },
    { id: 'phone', hold: 0.2 },
  ]);
  ck('demoSet registers steps', n === 2);
  ck('demo play starts at step 0', rig.demoPlay() === true && rig.status().demoI === 0 && rig.status().demoPlaying === true);
  ck('demo paused', rig.demoPause() === true && rig.status().demoPaused === true);
  const vP = rig.tick(10);
  rig.demoFrame(1);
  ck('paused demo does not advance', rig.status().demoI === 0);
  ck('demo resume', rig.demoResume() === true && rig.status().demoPaused === false);
  rig.tick(1);   /* finish glide */
  rig.demoFrame(1);
  ck('demo advances after hold', rig.status().demoI === 1, rig.status().demoI);
  rig.tick(1); rig.demoFrame(2);
  ck('demo stops after last step', rig.status().demoPlaying === false && rig.status().demoI === 1);
  ck('demo prev', rig.demoPrev() === true && rig.status().demoI === 0);
  ck('demo replay restarts', rig.demoReplay() === true && rig.status().demoI === 0 && rig.status().demoPlaying === true);
  ck('empty demo refuses play', (() => { const r = makeRig().rig; r.demoSet([]); return r.demoPlay() === false; })());
}

console.log('=== Phase 8 unit: perf monitor ===');
{
  const perf = createPerf({ studentHz: 10, hysteresis: 0.5 });
  ck('default tier high', perf.state.tier === 'high');
  for (let i = 0; i < 30; i++) perf.sample(16.7);
  ck('60fps on 16.7ms frames', Math.abs(perf.state.fps - 60) < 1, perf.state.fps);
  ck('p95 computed', perf.state.frameMsP95 > 0);

  /* tier degrade with hysteresis */
  let seconds = 0;
  for (let i = 0; i < 60; i++) { seconds += 1 / 60; perf.sample(40); }
  ck('slow frames degrade tier', perf.state.tier !== 'high', perf.state.tier);
  for (let i = 0; i < 150; i++) { seconds += 1 / 60; perf.sample(16.7); }
  ck('fast frames restore high tier', perf.state.tier === 'high', perf.state.tier);

  /* reduced update rates */
  perf.setBudget('students', 10);
  let runs = 0;
  for (let t = 0; t < 1.0; t += 1 / 60) if (perf.shouldRun('students', t)) runs++;
  ck('students budget ~10Hz', runs >= 9 && runs <= 11, runs);

  /* loop guard */
  ck('single loop', perf.startLoop() === 1 && perf.state.loops === 1);
  ck('duplicate loop detected', perf.startLoop() === 2 && perf.state.loops === 2);
  perf.stopLoop(); perf.stopLoop();
  ck('loops released', perf.state.loops === 0);

  /* listener registry */
  perf.addListener('canvas'); perf.addListener('canvas'); perf.removeListener('canvas');
  ck('unbalanced listeners detected', perf.listenersBalanced() === false);
  perf.removeListener('canvas');
  ck('balanced after cleanup', perf.listenersBalanced() === true);

  /* progressive asset queue with retry */
  let attempts = 0;
  perf.enqueue({ id: 'glb' });
  const bad = perf.drain(() => { attempts++; throw new Error('io'); });
  ck('failed drain reports the error', bad && bad.failed === true && /io/.test(bad.error));
  ck('retry requeues', perf.snapshot().queue === 1 && perf.snapshot().retries === 1);
  const ok = perf.drain(() => { attempts++; });
  ck('retry succeeds', ok && ok.id === 'glb' && perf.snapshot().assetsLoaded === 1);

  /* bridge coalescing */
  for (let i = 0; i < 40; i++) perf.bridgePost({ n: i });
  ck('bridge queue capped', perf.bridgePending().length === 32);
  ck('overflow counted', perf.state.bridgeDropped === 8, perf.state.bridgeDropped);
  const sent = perf.bridgeFlush((m) => { if (m.n == null) throw new Error('bad'); }, 4);
  ck('flush sends a few per tick', sent === 4 && perf.bridgePending().length === 28);
  perf.bridgeFlush(() => {}, 100);
  ck('flush drains the rest', perf.bridgePending().length === 0 && perf.state.bridgeSent === 32);

  /* reuse counter */
  perf.noteReuse(); perf.noteReuse();
  ck('asset reuse counted', perf.state.assetReuses === 2);

  const snap = perf.snapshot();
  ck('snapshot carries tier+fps+listeners', snap.tier === 'high' && snap.fps > 0 && snap.listeners.canvas.add === 2);
}

console.log('=== Phase 8 unit: cross-checks ===');
{
  const { rig } = makeRig();
  const perf = createPerf({});
  rig.setView('student');
  for (let i = 0; i < 90; i++) { rig.tick(1 / 60); perf.sample(16.7); }
  const v = rig.view();
  ck('rig + perf coexist', !!v && perf.state.fps > 0);
  ck('view fov tracked', rig.status().fov === 50, rig.status().fov);
}

console.log(`\nPhase 8 unit: ${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
