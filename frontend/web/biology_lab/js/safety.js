'use strict';

/* Phase 7c: safety-aware lesson logic - PPE checks, safe handling, waste
   classification, simulated spills/breakages, alarm/evacuation responses,
   incident reports, corrective feedback and teacher intervention for unsafe
   actions. Pure rules; the host feeds it real user actions and the lesson
   engine consumes its interruptions (safetyViolation). */

var PPE_RULES = {
  goggles: 'eye protection required for any wet work, glassware or specimen handling',
  coat: 'lab coat required to protect skin and clothing',
  tiedHair: 'long hair must be tied back near glassware and equipment',
};

var HANDLING_RULES = [
  { id: 'glassware', needs: ['goggles'], feedback: 'put on safety goggles before handling glassware' },
  { id: 'specimen', needs: ['goggles', 'coat'], feedback: 'goggles and coat on before opening a specimen jar' },
  { id: 'microscope-slide', needs: ['goggles'], feedback: 'goggles on - slides can crack under the coverslip' },
  { id: 'sharps', needs: ['goggles', 'coat'], teacher: true, feedback: 'scalpel/probe work is teacher-supervised only' },
  { id: 'chemical', needs: ['goggles', 'coat'], teacher: true, feedback: 'chemical handling needs teacher approval' },
];

var WASTE_CLASSES = {
  glass: { bin: 'broken-glass box', note: 'never put broken glass in the general bin; report every breakage' },
  organic: { bin: 'biological waste bag', note: 'plant waste and specimens - no live specimens down the sink' },
  chemical: { bin: 'hazardous waste container', note: 'label and date; never pour concentrated reagents down the sink' },
  general: { bin: 'general waste', note: 'paper towels and non-hazardous rubbish' },
  sharps: { bin: 'sharps container', note: 'never re-cap a used probe by hand; teacher disposes' },
};

var WASTE_ITEMS = {
  'broken-beaker': 'glass', 'broken-flask': 'glass', 'slide': 'glass', 'cotton-bud': 'general',
  'paper-towel': 'general', 'onion-skin': 'organic', 'germinated-seed': 'organic',
  'woodlouse': 'organic', 'iodine-solution': 'chemical', 'methylene-blue': 'chemical',
  'used-probe': 'sharps',
};

var INCIDENT_RESPONSES = {
  spill: {
    alarm: 'spill',
    steps: ['stop work', 'alert the teacher', 'contain the spill with the spill tray', 'classify the liquid', 'clean with the correct kit', 'record the incident'],
    evacuate: false,
    feedback: 'spills are contained first, cleaned second, reported always',
  },
  breakage: {
    alarm: 'breakage',
    steps: ['stop work', 'do not pick up glass by hand', 'use the brush and dustpan', 'dispose in the broken-glass box', 'report the breakage', 'record the incident'],
    evacuate: false,
    feedback: 'broken glass goes in the broken-glass box only - never the general bin',
  },
  fire: {
    alarm: 'fire',
    steps: ['stop work', 'raise the alarm', 'leave by the nearest exit', 'gather at the roll-call point', 'wait for the teacher to take the register'],
    evacuate: true,
    feedback: 'fire: stop, raise the alarm, leave, roll call - never collect belongings',
  },
  chemical: {
    alarm: 'chemical',
    steps: ['stop work', 'alert the teacher', 'rinse affected skin for 15 minutes if contacted', 'use the eyewash for splash to eyes', 'record the incident'],
    evacuate: false,
    feedback: 'chemical splash: rinse first, then call the teacher - never rub the eyes',
  },
};

function createSafety(opts) {
  opts = opts || {};
  var state = {
    ppe: {},            /* studentId -> {goggles, coat, tiedHair} */
    students: opts.students ? opts.students.slice() : [],
    incidents: [],
    openIncident: null,
    evacuation: false,
    violations: 0,
    reports: [],
  };
  var seq = 0;

  function lineFor(id, extra) { return (extra ? extra + ' - ' : '') + id; }

  function setPPE(studentId, worn) {
    var cur = state.ppe[studentId] || { goggles: false, coat: false, tiedHair: false };
    var next = { goggles: !!worn.goggles, coat: !!worn.coat, tiedHair: !!worn.tiedHair };
    state.ppe[studentId] = next;
    return next;
  }
  function ppeOk(studentId) {
    var p = state.ppe[studentId];
    return !!(p && p.goggles && p.coat && p.tiedHair);
  }
  function ppeMissing(studentId) {
    var p = state.ppe[studentId] || {};
    var miss = [];
    if (!p.goggles) miss.push('goggles');
    if (!p.coat) miss.push('coat');
    if (!p.tiedHair) miss.push('tied hair');
    return miss;
  }

  function canHandle(studentId, itemId) {
    var rule = null;
    for (var i = 0; i < HANDLING_RULES.length; i++) if (HANDLING_RULES[i].id === itemId) rule = HANDLING_RULES[i];
    if (!rule) return { allowed: true, feedback: '', violations: 0 };
    var miss = (rule.needs || []).filter(function (need) {
      var p = state.ppe[studentId] || {};
      if (need === 'goggles') return !p.goggles;
      if (need === 'coat') return !p.coat;
      if (need === 'tiedHair') return !p.tiedHair;
      return true;
    });
    var teacher = !!rule.teacher && !opts.teacherPresent;
    var allowed = miss.length === 0 && !teacher;
    var feedback = allowed ? '' : (miss.length ? rule.feedback : (teacher ? 'teacher must supervise this item' : ''));
    if (!allowed) state.violations++;
    return { allowed: allowed, missing: miss, feedback: feedback, violations: state.violations };
  }

  function classifyWaste(itemId) {
    var cls = WASTE_ITEMS[itemId] || 'general';
    return { item: itemId, class: cls, bin: WASTE_CLASSES[cls].bin, note: WASTE_CLASSES[cls].note };
  }

  function incident(kind, pos) {
    var plan = INCIDENT_RESPONSES[kind] || INCIDENT_RESPONSES.spill;
    var inc = {
      id: 'inc' + (++seq), kind: kind, at: state.reports.length,
      pos: pos || null, steps: plan.steps.slice(), resolved: false,
      feedback: plan.feedback,
    };
    state.incidents.push(inc);
    state.openIncident = inc;
    if (plan.evacuate) state.evacuation = true;
    state.reports.push({ id: inc.id, kind: kind, open: true });
    return { incident: inc, plan: plan };
  }

  function resolveIncident(id, action) {
    var inc = null;
    for (var i = 0; i < state.incidents.length; i++) if (state.incidents[i].id === id) inc = state.incidents[i];
    if (!inc || inc.resolved) return false;
    inc.resolved = true;
    inc.resolvedBy = action || 'closed';
    state.openIncident = null;
    state.reports.forEach(function (r) { if (r.id === id) r.open = false; });
    return true;
  }

  function setEvacuation(on) {
    state.evacuation = !!on;
    return state.evacuation;
  }

  function intervention(action) {
    /* teacher intervention for a named unsafe action */
    var known = {
      'running-in-lab': 'stop running - walk in the lab',
      'no-ppe': 'put on goggles, coat and tie hair before continuing',
      'forced-drawer': 'never force a jammed drawer - ask the teacher',
      'taste-test': 'never taste or smell directly - waft only, and only when the teacher says so',
      'window-open-rain': 'close the window during rain - use the fans for ventilation',
    };
    var feedback = known[action] || 'follow the lab rules and wait for the teacher';
    state.violations++;
    return { action: action, feedback: feedback, teacherNotified: true };
  }

  function report() {
    return {
      total: state.incidents.length,
      open: state.incidents.filter(function (i) { return !i.resolved; }).length,
      violations: state.violations,
      evacuation: state.evacuation,
      incidents: state.incidents.map(function (i) {
        return { id: i.id, kind: i.kind, resolved: i.resolved };
      }),
    };
  }

  function serialize() { return JSON.stringify({ v: 1, state: state }); }
  function restore(json) {
    var data = typeof json === 'string' ? JSON.parse(json) : json;
    if (!data || !data.state || data.v !== 1) return false;
    Object.keys(state).forEach(function (k) { if (data.state[k] !== undefined) state[k] = data.state[k]; });
    return true;
  }

  return {
    state: state,
    setPPE: setPPE,
    ppeOk: ppeOk,
    ppeMissing: ppeMissing,
    canHandle: canHandle,
    classifyWaste: classifyWaste,
    incident: incident,
    resolveIncident: resolveIncident,
    setEvacuation: setEvacuation,
    intervention: intervention,
    report: report,
    serialize: serialize,
    restore: restore,
    PPE_RULES: PPE_RULES,
    HANDLING_RULES: HANDLING_RULES,
    WASTE_CLASSES: WASTE_CLASSES,
    INCIDENT_RESPONSES: INCIDENT_RESPONSES,
  };
}

export { createSafety, PPE_RULES, HANDLING_RULES, WASTE_CLASSES, INCIDENT_RESPONSES };
