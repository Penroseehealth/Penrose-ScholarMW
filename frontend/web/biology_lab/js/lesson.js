'use strict';

/* Phase 6: lesson engine - a complete practical session from setup through
   cleanup, plus student performance assessment with persistence.

   Phases (linear, each with a checklist):
     setup -> safety -> demo -> practice -> record -> interpret -> assess
           -> cleanup -> done
   - Condition-based steps auto-advance when the live world / student state
     satisfies them (equipment present, students watched, students recorded...).
   - Manual steps (safety acknowledgement, interpretation answers) are
     completed through the API by the host / teacher UI / test harness.
   - `pause()` / `resume()` and `setSpeed(n)` gate the engine clock; `tick(dt)`
     advances only while running, so long-running experiments can be skipped
     or accelerated without touching the science model (which is already
     instantaneous and deterministic).
   - `serialize()` / `restore(json)` persist completed steps, conditions,
     observations, results, feedback and assessment scores - a resumed lesson
     keeps everything (optionally mirrored into `opts.storage` under one key).
   - Assessment dimensions per student: procedural accuracy, equipment
     handling, safety, observations, calculations, scientific reasoning -
     derived from the student FSM counters (Phase 5), science.assess output
     (Phase 4) and lesson-level safety events. */

var LESSON_PHASES = ['setup', 'safety', 'demo', 'practice', 'record', 'interpret', 'assess', 'cleanup', 'done'];

var LESSON_STEPS = {
  setup: [
    { id: 'check-equipment', label: 'equipment registered in the world store' },
    { id: 'prepare-apparatus', label: 'specimen / apparatus prepared at the station' },
    { id: 'demo-ready', label: 'demonstration state ready (scope usable)' },
  ],
  safety: [
    { id: 'brief', label: 'safety briefing delivered' },
    { id: 'ack', label: 'safety briefing acknowledged' },
  ],
  demo: [
    { id: 'students-watch', label: 'students observing the demonstration' },
    { id: 'question', label: 'a student asked the demonstration question' },
  ],
  practice: [
    { id: 'students-practice', label: 'students working at their stations' },
    { id: 'students-record', label: 'every student has recorded a measurement' },
  ],
  record: [
    { id: 'observations', label: 'observations collated from student records' },
  ],
  interpret: [
    { id: 'answers', label: 'interpretation answers submitted' },
  ],
  assess: [
    { id: 'scores', label: 'performance scores computed' },
  ],
  cleanup: [
    { id: 'taps-off', label: 'taps closed' },
    { id: 'scope-safe', label: 'microscope lamp off / safe state' },
    { id: 'drawer-closed', label: 'bench drawer closed' },
  ],
  done: [],
};

function createLesson(opts) {
  opts = opts || {};
  var world = opts.world || null;
  var science = opts.science || null;
  var students = opts.students || null;          /* the Phase-5 student manager */
  var storage = opts.storage || null;            /* e.g. window.localStorage */
  var storageKey = opts.storageKey || 'bioLessonState';

  var state = {
    v: 1,
    running: false,                              /* false once started, until done */
    paused: false,
    speed: 1,
    phase: 'idle',                               /* idle | <LESSON_PHASES> */
    stepIndex: 0,
    steps: {},                                   /* id -> {done, data} */
    conditions: {},                              /* experiment conditions snapshot */
    observations: {},
    results: {},
    feedback: {},                                /* studentId -> [lines] */
    scores: {},                                  /* studentId -> dimensions */
    experimentId: 'osmosis',
    topic: 'osmosis',
    elapsed: 0,                                  /* engine-clock seconds (speed-scaled) */
    safetyAcknowledged: false,
    safetyViolations: [],
    interpretation: null,
    assessmentComplete: false,
    resumedFrom: null,
  };
  var events = [];

  function emit(type, data) {
    var ev = { t: +state.elapsed.toFixed(2), type: type };
    if (data) for (var k in data) ev[k] = data[k];
    events.push(ev);
    if (events.length > 400) events.splice(0, events.length - 400);
    persist();
    return ev;
  }

  function persist() {
    if (!storage) return;
    try { storage.setItem(storageKey, serialize()); } catch (e) { /* quota / private mode */ }
  }

  function stepDef(phase, id) {
    var list = LESSON_STEPS[phase] || [];
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i];
    return null;
  }

  function done(id, data) {
    if (!state.steps[id]) state.steps[id] = { done: false, data: null };
    if (state.steps[id].done) return false;
    state.steps[id].done = true;
    if (data !== undefined) state.steps[id].data = data;
    emit('step', { id: id, phase: state.phase });
    return true;
  }

  function isDone(id) { return !!(state.steps[id] && state.steps[id].done); }

  function stepsFor(phase) {
    return (LESSON_STEPS[phase] || []).map(function (s) {
      return { id: s.id, label: s.label, done: isDone(s.id) };
    });
  }

  function phaseComplete(phase) {
    var list = LESSON_STEPS[phase] || [];
    for (var i = 0; i < list.length; i++) if (!isDone(list[i].id)) return false;
    return true;
  }

  function setStudentsPhase(phase, topic, experimentId) {
    if (!world || !world.get || !world.get('lesson')) return;
    world.set('lesson', { phase: phase, topic: topic || state.topic, experimentId: experimentId || state.experimentId });
  }

  function enter(phase) {
    state.phase = phase;
    state.stepIndex = 0;
    emit('phase', { phase: phase });
    if (phase === 'demo') setStudentsPhase('demo');
    else if (phase === 'practice') setStudentsPhase('practice');
    else if (phase === 'record' || phase === 'interpret' || phase === 'assess') setStudentsPhase('review');
    else if (phase === 'done') setStudentsPhase('idle');
    if (phase === 'safety' && !isDone('brief')) done('brief');
    persist();
  }

  function advance() {
    var idx = LESSON_PHASES.indexOf(state.phase);
    if (idx < 0 || idx >= LESSON_PHASES.length - 1) return;
    if (!phaseComplete(state.phase)) return;
    enter(LESSON_PHASES[idx + 1]);
  }

  /* ---- condition checks against the live world + student state ---- */
  function checkConditions() {
    var st = students ? students.stats() : null;
    switch (state.phase) {
      case 'setup':
        if (world && world.get) {
          if (world.get('micro.front') && world.get('balance') && world.get('lesson')) done('check-equipment');
          var jar = world.get('item.jar');
          if (world.get('micro.front') && (!jar || typeof jar.state.massG === 'number')) done('prepare-apparatus');
        }
        if (world && world.get && world.get('micro.front') && world.get('micro.front').state) {
          var ms = world.get('micro.front').state;
          if (ms.illumination && (ms.objective === 4 || ms.objective === 10)) done('demo-ready');
        }
        break;
      case 'demo':
        if (st && st.questions >= 1) done('question');
        if (world && world.get && world.get('lesson') && world.get('lesson').state.phase === 'demo') done('students-watch');
        break;
      case 'practice':
        if (st && st.records > 0) done('students-practice');
        if (st && students.students.every(function (s) { return s.records >= 1; })) {
          done('students-record');
          /* snapshot observations NOW: students clear their record pointer on
             the next phase change, so capture + run the science model here */
          var obs = {};
          students.students.forEach(function (s) {
            if (s.record && s.record.ok) obs[s.id] = s.record;
          });
          state.observations = obs;
          if (science) {
            var run = science.run(state.experimentId, state.conditions);
            state.results = run.results;
            state.conditions = run.inputs;
          }
        }
        break;
      case 'record':
        if (Object.keys(state.observations).length > 0) {
          done('observations', { count: Object.keys(state.observations).length });
        }
        break;
      case 'cleanup': {
        if (world && world.get) {
          var tap = world.get('tap.front');
          if (!tap || !tap.state.running) done('taps-off');
          var micro = world.get('micro.front');
          if (micro && micro.state && !micro.state.illumination) done('scope-safe');
          var drawer = world.get('benchFront.drawer');
          if (!drawer || !drawer.state.open) done('drawer-closed');
        }
        break;
      }
    }
  }

  /* ---- assessment ---- */
  function assessStudent(s) {
    var mistakes = s.mistakes || 0, records = s.records || 0;
    var procedural = records === 0 ? (mistakes === 0 ? 0.4 : 0.2) : (mistakes === 0 ? 1 : (mistakes <= 2 ? 0.75 : 0.5));
    var equipment = mistakes === 0 ? 1 : Math.max(0.3, 1 - mistakes * 0.08);
    var safety = (state.safetyAcknowledged && state.safetyViolations.length === 0) ? 1 :
      (state.safetyAcknowledged ? 0.6 : 0.3);
    var observations = records > 0 ? 1 : 0.3;
    var ratio = 0.5;
    if (state.interpretation && state.interpretation.ratios && state.interpretation.ratios[s.id] != null) {
      ratio = state.interpretation.ratios[s.id];
    } else if (state.interpretation && state.interpretation.ratio != null) {
      ratio = state.interpretation.ratio;
    }
    var calculations = ratio;
    var reasoning = ratio;
    var overall = +((procedural + equipment + safety + observations + calculations + reasoning) / 6).toFixed(3);
    var fb = [];
    fb.push(procedural >= 0.75 ? 'procedure followed accurately' : 'procedure: revise the steps that caused the mistakes');
    fb.push(equipment >= 0.75 ? 'equipment handled well' : 'equipment: check the setup before recording');
    fb.push(safety >= 0.6 ? 'safety rules observed' : 'safety: complete the briefing before working');
    fb.push(observations >= 1 ? 'observations recorded for every run' : 'observations: record a measurement next time');
    fb.push(calculations >= 0.75 ? 'calculations/interpretation correct' : 'interpretation: revisit the expected trend');
    fb.push(reasoning >= 0.75 ? 'scientific reasoning is sound' : 'reasoning: explain the result from the water-potential gradient');
    return { procedural: procedural, equipment: equipment, safety: safety,
      observations: observations, calculations: calculations, reasoning: reasoning,
      overall: overall, feedback: fb };
  }

  function computeScores() {
    if (!students || !students.students) return;
    students.students.forEach(function (s) {
      state.scores[s.id] = assessStudent(s);
      state.feedback[s.id] = state.scores[s.id].feedback.slice();
    });
    state.assessmentComplete = true;
    done('scores', { students: students.students.length });
    emit('assessed', { complete: true });
  }

  /* ---- public API ---- */
  function start(experimentId, topic, conditions) {
    if (state.phase !== 'idle' && state.phase !== 'done') return false;
    state.experimentId = experimentId || 'osmosis';
    state.topic = topic || state.experimentId;
    state.running = true;
    state.paused = false;
    state.elapsed = 0;
    state.steps = {};
    state.observations = {};
    state.results = {};
    state.feedback = {};
    state.scores = {};
    state.interpretation = null;
    state.assessmentComplete = false;
    state.safetyAcknowledged = false;
    state.safetyViolations = [];
    if (science) {
      state.conditions = science.defaults(state.experimentId);
      if (conditions) for (var k in conditions) state.conditions[k] = conditions[k];
    }
    enter('setup');
    return true;
  }

  function safetyAck() {
    if (state.phase !== 'safety' && state.phase !== 'setup') return false;
    state.safetyAcknowledged = true;
    done('ack');
    advance();
    return true;
  }

  function submitInterpretation(answers) {
    if (state.phase !== 'interpret' && state.phase !== 'record') return null;
    if (state.phase === 'record') enter('interpret');
    var a = answers || {};
    var out = { ratio: 0.5, ratios: {}, perStudent: {} };
    if (students && students.students && science) {
      var ok = 0, n = 0;
      students.students.forEach(function (s) {
        var res = science.assess(state.experimentId, state.conditions, state.results, a[s.id] || a);
        var r = res.max > 0 ? res.score / res.max : 0;
        out.ratios[s.id] = r;
        out.perStudent[s.id] = res;
        ok += res.score; n += res.max;
      });
      out.ratio = n > 0 ? ok / n : 0.5;
    } else if (science && state.results && science.assess) {
      var res2 = science.assess(state.experimentId, state.conditions, state.results, a);
      out.ratio = res2.max > 0 ? res2.score / res2.max : 0.5;
    }
    state.interpretation = out;
    done('answers', { ratio: +out.ratio.toFixed(3) });
    enter('assess');
    computeScores();
    advance();          /* assess -> cleanup -> ... */
    return out;
  }

  function pause() { if (state.phase === 'done' || state.phase === 'idle') return false; state.paused = true; emit('pause'); return true; }
  function resume() { if (!state.paused) return false; state.paused = false; emit('resume'); return true; }
  function setSpeed(n) { state.speed = Math.max(1, Math.min(60, Math.round(n) || 1)); emit('speed', { speed: state.speed }); return state.speed; }

  function tick(dt) {
    if (!state.running || state.paused || state.phase === 'idle' || state.phase === 'done') return state.phase;
    dt = dt == null ? 0.1 : dt;
    state.elapsed += dt * state.speed;
    checkConditions();
    advance();
    if (state.phase === 'done') { state.running = false; emit('done'); }
    return state.phase;
  }

  /* accelerated time: run the engine clock forward without the host loop
     (students are advanced separately by the host / harness) */
  function fastForward(seconds, studentTick) {
    var dt = 0.1, n = Math.round((seconds * state.speed) / dt);
    for (var i = 0; i < n; i++) {
      if (studentTick) studentTick(dt * state.speed);
      tick(dt);
      if (state.phase === 'done') break;
    }
    return state.phase;
  }

  function status() {
    return {
      phase: state.phase, running: state.running, paused: state.paused, speed: state.speed,
      elapsed: +state.elapsed.toFixed(1), steps: stepsFor(state.phase),
      stepsDone: Object.keys(state.steps).filter(function (k) { return state.steps[k].done; }).length,
      assessmentComplete: state.assessmentComplete,
      scoresAvailable: Object.keys(state.scores).length > 0,
      experimentId: state.experimentId, topic: state.topic,
    };
  }

  function scores(studentId) {
    if (studentId) return state.scores[studentId] || null;
    return state.scores;
  }

  function overall() {
    var ks = Object.keys(state.scores);
    if (!ks.length) return null;
    var sum = 0;
    ks.forEach(function (k) { sum += state.scores[k].overall; });
    return +(sum / ks.length).toFixed(3);
  }

  function serialize() {
    return JSON.stringify({ v: 1, state: state, events: events.slice(-50) });
  }

  function restore(json) {
    var data = typeof json === 'string' ? JSON.parse(json) : json;
    if (!data || !data.state || data.state.v !== 1) return false;
    var keepPhase = data.state.phase;
    var keys = Object.keys(state);
    keys.forEach(function (k) { if (data.state[k] !== undefined) state[k] = data.state[k]; });
    state.paused = false;                 /* a restored lesson is always resumable */
    state.resumedFrom = keepPhase;
    if (data.events && data.events.length) {
      events.length = 0;
      data.events.forEach(function (e) { events.push(e); });
    }
    emit('restore', { from: keepPhase });
    return true;
  }

  /* construct: resume from storage if a lesson was persisted */
  if (storage) {
    try {
      var saved = storage.getItem(storageKey);
      if (saved) restore(saved);
    } catch (e) { /* ignore corrupt storage */ }
  }

  return {
    LESSON_PHASES: LESSON_PHASES,
    LESSON_STEPS: LESSON_STEPS,
    state: state,
    events: events,
    start: start,
    tick: tick,
    fastForward: fastForward,
    safetyAck: safetyAck,
    submitInterpretation: submitInterpretation,
    pause: pause,
    resume: resume,
    setSpeed: setSpeed,
    status: status,
    stepsFor: stepsFor,
    scores: scores,
    overall: overall,
    serialize: serialize,
    restore: restore,
    /* host hook: record a safety event (e.g. a student opened a culture plate) */
    safetyViolation: function (note) { state.safetyViolations.push(note || 'violation'); emit('safety', { note: note }); },
  };
}

export { createLesson, LESSON_PHASES, LESSON_STEPS };
