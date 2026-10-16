import { createEnvironment, daylightFactor, WEATHERS } from '../js/environment.js';
import { createBiology } from '../js/biology_assets.js';
import { createSafety } from '../js/safety.js';

let pass = 0, fail = 0;
function ck(name, ok, detail) {
  if (ok) { pass++; console.log('  PASS ' + name); }
  else { fail++; console.log('  FAIL ' + name + (detail ? ' - ' + detail : '')); }
}

console.log('=== Phase 7 unit: environment ===');
{
  const e = createEnvironment({ autoClock: false });
  ck('default hour is 10', e.state.hour === 10);
  ck('daylight at noon = 1', daylightFactor(12) === 1);
  ck('daylight at midnight = 0', daylightFactor(0) === 0);
  ck('daylight at 6 = 0 (sunrise)', daylightFactor(6) === 0);
  ck('daylight at 18 = 0 (sunset)', daylightFactor(18) === 0);
  ck('daylight at 9 in (0,1)', daylightFactor(9) > 0 && daylightFactor(9) < 1);
  ck('indoorLux with lights on is high', e.indoorLux() > 0.7, e.indoorLux());
  e.setLights(false, false);
  ck('indoorLux drops with lights off', e.indoorLux() <= 0.6, e.indoorLux());
  e.setLights(true, false);

  ck('setFans toggles + emits', e.setFans(false) === true && e.state.fansOn === false);
  ck('setFans idempotent returns false', e.setFans(false) === false);
  ck('setAircon toggles', e.setAircon(false) === true && e.state.airconsOn === false);
  e.setAircon(true); e.setFans(true);

  const v0 = e.ventilationScore();
  e.setWindow(0, true);
  ck('open window raises ventilation', e.ventilationScore() > v0, e.ventilationScore() + '>' + v0);
  const adv = e.events.filter(ev => ev.type === 'advice').length;
  ck('setWindow emits events', e.events.some(ev => ev.type === 'window' && ev.index === 0 && ev.open === true));
  e.setWindow(0, false);

  e.setDoor(0, true);
  ck('door toggle emits door event', e.events.some(ev => ev.type === 'door' && ev.index === 0 && ev.open === true));
  const snd = e.events.filter(ev => ev.type === 'sound');
  ck('sound events carry gain 0..1', snd.length > 0 && snd.every(s => s.gain >= 0 && s.gain <= 1));
  const gNear = e.gainAt({ x: 0, z: -2.4 });
  const gFar = e.gainAt({ x: 0, z: 30 });
  ck('distance attenuation: near > far', gNear > gFar, gNear + ' vs ' + gFar);
  ck('gain at listener = 1', gNear === 1);
  ck('gain far is small', gFar < 0.1, gFar);

  e.setHour(3);
  ck('night daylight = 0', e.daylight() === 0);
  e.state.lightsManual = false;
  e.setLights(false, false);
  e.setHour(3.1);
  ck('auto policy turns lights on at night', e.state.lightsOn === true);
  e.setHour(12);
  ck('auto policy turns lights off at bright noon', e.state.lightsOn === false);
  e.setLights(false, true);
  e.setHour(12.1);
  ck('manual override respected at noon', e.state.lightsOn === false);
  e.setLights(true, true);

  e.setWeather('rain');
  ck('rain cools and humidifies', e.state.tempC < 21 && e.state.humidityPct > 45, e.state.tempC + '/' + e.state.humidityPct);
  ck('rain not windows-advised', e.windowsAdvised() === false);
  const adviceOnOpen = e.setWindow(1, true) && e.events.some(ev => ev.type === 'advice');
  e.setWindow(1, false);
  ck('opening window in rain gives advice', !!adviceOnOpen);
  e.setWeather('wind');
  ck('wind closes open windows', e.state.windows.every(w => w === 0));
  ck('weather enum valid', WEATHERS.join(',') === 'clear,rain,wind,storm');

  const tid = e.setTimer('stain', 2);
  ck('timer registered', e.state.timers.length === 1);
  e.tick(1.5);
  ck('timer not done yet', e.state.timers.length === 1 && !e.state.alarm);
  e.tick(1.0);
  ck('timer fires alarm', e.state.alarm && e.state.alarm.kind === 'timer');
  ck('timer-done event emitted', e.events.some(ev => ev.type === 'timer-done' && ev.label === 'stain'));
  e.clearAlarm();
  ck('clearAlarm clears', e.state.alarm === null);

  e.alarm('fire');
  e.setEvacuation(true);
  ck('evacuation flag set', e.state.evacuation === true);
  ck('evacuation raises alarm', e.state.alarm && e.state.alarm.kind === 'evacuation');
  e.setEvacuation(false);
  ck('evacuation off flag cleared', e.state.evacuation === false);

  e.state.autoClock = true;
  e.setEvacuation(true);
  const hPause = e.state.hour;
  e.tick(2);
  ck('clock paused during evacuation', e.state.hour === hPause);
  e.setEvacuation(false);
  e.tick(2);
  ck('clock resumes after evacuation', e.state.hour > hPause);
  e.state.autoClock = false;

  const json = e.serialize();
  const e2 = createEnvironment({ autoClock: false });
  ck('restore round-trip ok', e2.restore(json) === true);
  ck('restore keeps weather', e2.state.weather === e.state.weather);
  ck('restore keeps hour', Math.abs(e2.state.hour - e.state.hour) < 1e-9);

  const e3 = createEnvironment({ hour: 8, autoClock: true, clockRate: 1 });
  e3.tick(3);
  ck('clockRate 1h/s: +3h in 3s', Math.abs(e3.state.hour - 11) < 1e-9, e3.state.hour);
}

console.log('=== Phase 7 unit: biology assets ===');
{
  const b = createBiology();
  const audit = b.audit();
  ck('scientific accuracy audit passes', audit.ok, JSON.stringify(audit.checks.filter(c => !c.ok)));
  ck('audit has >= 12 checks', audit.checks.length >= 12, audit.checks.length);

  const onion = b.cells.onionEpidermis;
  ck('onion cell 15 um', Math.abs(onion.widthMm - 0.015) < 1e-9);
  ck('onion parts include nucleus + vacuole + wall', ['nucleus', 'vacuole', 'cellWall'].every(p => onion.parts.includes(p)));

  const parts = b.cellParts('onionEpidermis');
  ck('cellParts returns roles', parts.length > 0 && parts.every(p => p.role && p.present));

  const sc = b.describeScale('cell');
  ck('describeScale cell = 15 um', sc && Math.abs(sc.sizeM - 1.5e-5) < 1e-12);
  ck('describeScale unknown = null', b.describeScale('molecule') === null);

  const gDry = b.growth('cress', { waterPresent: false }, 10);
  ck('no water -> no growth', gDry.heightMm === 0 && gDry.stage === 'no growth');
  const gCold = b.growth('cress', { tempC: 2 }, 10);
  ck('cold -> no growth', gCold.heightMm === 0);
  const gHot = b.growth('cress', { tempC: 40 }, 10);
  ck('too hot -> no growth', gHot.heightMm === 0);
  const gSeed = b.growth('cress', {}, 1);
  ck('day 1 = imbibing', gSeed.stage === 'imbibing' && gSeed.heightMm === 0);
  const gSap = b.growth('cress', {}, 3);
  ck('day 3 = seedling', gSap.stage === 'seedling' && gSap.heightMm > 0, gSap.stage);
  const gMat = b.growth('cress', { tempC: 22 }, 30);
  ck('day 30 = mature cress ~60 mm', gMat.stage === 'mature' && gMat.heightMm > 40 && gMat.heightMm < 80, gMat.heightMm);
  ck('mature has leaves', gMat.leaves >= 4, gMat.leaves);
  const gBean = b.growth('bean', {}, 30);
  ck('bean grows taller than cress at day 30', gBean.heightMm > gMat.heightMm, gBean.heightMm + ' vs ' + gMat.heightMm);
  const gDark = b.growth('cress', { lightMinutesPerDay: 60 }, 30);
  ck('low light stunts growth', gDark.heightMm < gMat.heightMm, gDark.heightMm);

  const w = b.woodliceChoice(10, true, 10);
  ck('woodlice 8/2 damp preference', w.dampArm === 8 && w.dryArm === 2);
  const w2 = b.woodliceChoice(10, true, 2);
  ck('settling is time-dependent (2 min less settled)', w2.dampArm < w.dampArm, w2.dampArm);
  const wInv = b.woodliceChoice(10, false, 10);
  ck('inverted chamber swaps arms', wInv.dampArm === 2 && wInv.dryArm === 8);
  const w12 = b.woodliceChoice(12, true, 10);
  ck('n=12 -> dampArm = round(12*0.8)=10', w12.dampArm === 10, w12.dampArm);

  ck('organelle sizes ordered nucleus>mito>ribosome',
    b.organelles.nucleus.sizeM > b.organelles.mitochondrion.sizeM &&
    b.organelles.mitochondrion.sizeM > b.organelles.ribosome.sizeM);
  ck('tissues reference real cells', Object.values(b.tissues).every(t => t.cells.every(c => !!b.cells[c])));
  ck('organs reference real tissues', Object.values(b.organs).every(o => o.tissues.every(t => !!b.tissues[t])));
}

console.log('=== Phase 7 unit: safety ===');
{
  const s = createSafety({ students: ['alice', 'bob'], teacherPresent: false });
  const sT = createSafety({ teacherPresent: true });

  ck('PPE defaults missing', s.ppeOk('alice') === false);
  ck('ppeMissing lists all three', s.ppeMissing('alice').join(',') === 'goggles,coat,tied hair');
  s.setPPE('alice', { goggles: true, coat: true, tiedHair: true });
  ck('PPE complete', s.ppeOk('alice') === true);
  s.setPPE('bob', { goggles: false, coat: false, tiedHair: false });

  ck('glassware blocked without goggles', s.canHandle('bob', 'glassware').allowed === false);
  ck('glassware feedback mentions goggles', /goggle/i.test(s.canHandle('bob', 'glassware').feedback));
  ck('glassware allowed with goggles', s.canHandle('alice', 'glassware').allowed === true);
  s.setPPE('bob', { goggles: true, coat: false, tiedHair: false });
  ck('partial PPE lists coat + hair', s.ppeMissing('bob').join(',') === 'coat,tied hair');
  ck('specimen needs coat too', s.canHandle('bob', 'specimen').allowed === false && s.canHandle('bob', 'specimen').missing.includes('coat'));
  ck('glassware allowed once goggles on', s.canHandle('bob', 'glassware').allowed === true);
  const sharps = s.canHandle('alice', 'sharps');
  ck('sharps need teacher (absent) - blocked', sharps.allowed === false && /teacher/i.test(sharps.feedback));
  sT.setPPE('alice', { goggles: true, coat: true, tiedHair: true });
  ck('sharps allowed with teacher present', sT.canHandle('alice', 'sharps').allowed === true);
  ck('unknown item is allowed', s.canHandle('bob', 'pencil').allowed === true);
  const v0 = s.state.violations;
  s.canHandle('alice', 'sharps');
  ck('failed handling increments violations', s.state.violations === v0 + 1);

  const w = s.classifyWaste('broken-beaker');
  ck('broken beaker = glass bin', w.class === 'glass' && /broken-glass/i.test(w.bin));
  ck('glass waste note mentions never general bin', /never put broken glass/i.test(w.note));
  const org = s.classifyWaste('onion-skin');
  ck('onion skin = organic', org.class === 'organic');
  const chem = s.classifyWaste('iodine-solution');
  ck('iodine = chemical', chem.class === 'chemical');
  ck('unknown waste = general', s.classifyWaste('pen').class === 'general');

  const { incident, plan } = s.incident('breakage', { x: 0, z: 0 });
  ck('breakage plan has steps', plan.steps.length >= 5);
  ck('breakage not evacuate', plan.evacuate === false);
  ck('breakage alarm kind', plan.alarm === 'breakage');
  ck('open incident tracked', s.state.openIncident === incident);
  ck('incident report logged', s.report().total === 1 && s.report().open === 1);
  s.resolveIncident(incident.id, 'cleaned');
  ck('resolve closes incident', s.report().open === 0 && s.state.openIncident === null);

  const fire = s.incident('fire');
  ck('fire triggers evacuation', s.state.evacuation === true);
  ck('fire steps include roll call', fire.plan.steps.some(x => /roll-call/.test(x)));
  s.setEvacuation(false);

  const iv = s.intervention('running-in-lab');
  ck('intervention feedback + teacherNotified', /walk/i.test(iv.feedback) && iv.teacherNotified === true);
  ck('intervention counts as violation', s.state.violations > 0);
  const iv2 = s.intervention('unknown-action');
  ck('unknown intervention still guides', /lab rules/i.test(iv2.feedback));

  const json = s.serialize();
  const s2 = createSafety({});
  ck('safety restore round-trip', s2.restore(json) === true && s2.state.violations === s.state.violations);
  ck('restore keeps PPE', s2.ppeOk('alice') === true);
}

console.log('=== Phase 7 unit: cross-module integration ===');
{
  const e = createEnvironment({ autoClock: false });
  const s = createSafety({ students: ['alice'] });
  e.setWeather('rain');
  e.setWindow(0, true);
  const advice = e.events.filter(ev => ev.type === 'advice');
  ck('window-in-rain advice feeds safety intervention', advice.length > 0 && s.intervention('window-open-rain').teacherNotified);
  const { incident } = s.incident('spill');
  ck('spill response complete', incident.steps.length >= 5 && !s.state.evacuation);
  const b = createBiology();
  const g = b.growth('cress', { tempC: 20, waterPresent: true, germinationDays: 2 }, 4);
  ck('biology growth usable as lesson observation', g.stage === 'seedling' && g.heightMm > 0, g.stage);
  const audit = b.audit();
  ck('cross-module audit still ok', audit.ok);
}

console.log(`\nPhase 7 unit: ${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
