'use strict';

/* Phase 5: virtual students.
   Lightweight per-student state machines driven by lesson + simulation state.
   Every spoken line comes from a local, predefined pool (seeded selection) -
   no AI process is invoked per student; apiCalls stays 0 by construction.
   A future selective AI hook can append lines to `dialogue` pools; the FSM
   does not care where a line came from. */

function makeRng(seed) {
  var a = (seed >>> 0) || 1;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    var t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

var STUDENT_NAMES = ['Ada', 'Ben', 'Chloe', 'Dev', 'Esha', 'Farid'];

var STUDENT_SEATS = [
  { x: -1.9, z: -1.5 }, { x: -2.9, z: -1.5 },
  { x: -1.9, z: 0.7 }, { x: -2.9, z: 0.7 },
  { x: -1.9, z: 2.9 }, { x: -2.9, z: 2.9 },
];

var STUDENT_STATES = {
  IDLE: 'idle', WATCH: 'watch', LOOK: 'look', RAISE: 'raise', ASK: 'ask',
  LISTEN: 'listen', RESPOND: 'respond', COLLECT: 'collect', AT_STATION: 'atStation',
  MISTAKE: 'mistake', FEEDBACK: 'feedback', RETRY: 'retry', RECORD: 'record',
  RETURN: 'return', COLLAB: 'collaborate', COMPLETE: 'complete',
};

var DIALOGUE = {
  ask: {
    microscope: [
      'which objective should I start with, the low power one?',
      'why do we swing the nosepiece instead of pulling the lens out?',
      'how do I know the focus is sharp and not just soft?',
      'should the lamp be brightest at 40x or at 4x?',
    ],
    osmosis: [
      'why does the potato gain mass in pure water?',
      'what does the isotonic concentration actually mean?',
      'should we blot the cylinder before weighing it every time?',
      'why is the tissue water potential negative?',
    ],
    enzyme: [
      'why does the rate fall after the optimum temperature?',
      'what exactly does the iodine test tell us about starch?',
      'does changing pH denature the enzyme or just slow it down?',
    ],
    general: [
      'can you repeat how we record the measurement?',
      'is one repeat enough or should we average three?',
      'where do we write the uncertainty?',
    ],
  },
  answer: {
    microscope: [
      'start on the low power objective - wider field, easier to find the specimen',
      'always swing the nosepiece; the objectives are parfocal so focus carries over',
      'sharp means the cell edges are crisp; soft focus still shows cells but blurred',
      'brighter light helps at low power; close the aperture at 40x for contrast',
    ],
    osmosis: [
      'water moves down its potential gradient, so it enters the tissue in pure water',
      'the isotonic concentration is where tissue and solution potentials balance - no net movement',
      'yes - blot dry each time, or you weigh the surface water not the tissue',
      'the solutes inside make the tissue potential negative relative to pure water',
    ],
    enzyme: [
      'above the optimum the active site loses its shape - that is denaturation',
      'iodine goes blue-black while starch is present, so its disappearance marks the endpoint',
      'pH changes ionisation of the active site; it slows the enzyme but denaturation is permanent',
    ],
    general: [
      'write the raw reading first, then the calculated value with units',
      'three repeats is the minimum for a mean you can trust',
      'uncertainty goes next to the value, not in a separate paragraph',
    ],
  },
  mistake: [
    'wait - that reading looks wrong, let me check the setup',
    'hmm, I think I recorded that too early',
    'that does not match the pattern we expect - something is off',
    'I may have mixed up the readings between the tubes',
  ],
  feedback: [
    'check the apparatus state first, then repeat the measurement',
    'compare your reading with the expected trend before recording it',
    're-read the method step - the order matters here',
    'use the low power first and work up; that usually explains it',
  ],
  record: [
    'I have the reading - writing it in the table now',
    'got it - measurement recorded with units',
    'that is stable - recording the value',
  ],
  collab: [
    'our values are close - shall we use the class mean?',
    'mine is a bit higher than yours; let us check who blotted longer',
    'same trend at least - water entered in both',
  ],
  complete: [
    'task done - apparatus back on the bench',
    'finished my run; happy with the record',
    'done - I will wait for the review',
  ],
  watch: [
    'watching the demonstration',
  ],
  look: [
    'looking at the demonstration',
  ],
};

function createStudents(opts) {
  opts = opts || {};
  var world = opts.world || null;
  var seed = opts.seed == null ? 7 : opts.seed;
  var rng = makeRng(seed);
  var names = (opts.names || STUDENT_NAMES).slice();
  var seats = opts.seats || STUDENT_SEATS;
  var dialogue = opts.dialogue || DIALOGUE;
  var stationId = opts.stationId || 'micro.front';
  var science = opts.science || (typeof window !== 'undefined' && window.BioLabScience) || null;
  var S = STUDENT_STATES;

  var lesson = { phase: 'idle', topic: 'general', experimentId: 'osmosis', t: 0 };
  var prevPhase = 'idle';
  var demoAsked = false;
  var t = 0;
  var apiCalls = 0;                       /* stays 0: local pools only */
  var events = [];
  var students = [];
  var askerIdx = 0;

  function emit(type, s, line, extra) {
    var ev = { t: +t.toFixed(2), type: type, student: s ? s.id : null, line: line || null };
    if (extra) for (var k in extra) ev[k] = extra[k];
    events.push(ev);
    if (events.length > 400) events.splice(0, events.length - 400);
    if (s) s.log.push(ev);
    return ev;
  }

  function add(name, seat) {
    var s = {
      id: 's' + (students.length + 1),
      name: name || names[students.length] || ('Student ' + (students.length + 1)),
      seat: seat || seats[students.length] || { x: -2.4, z: 0.7 },
      state: S.IDLE, stateT: 0, dwell: 1,
      attention: 0.6 + rng() * 0.35,      /* how long they stay on task */
      skill: 0.55 + rng() * 0.4,          /* first-attempt success chance */
      patience: 1,
      mistakes: 0, records: 0, questions: 0,
      record: null, task: 'none', retryCount: 0,
      inputs: null,
      log: [],
    };
    students.push(s);
    return s;
  }
  for (var i = 0; i < names.length; i++) add(names[i], seats[i]);
  readWorldLesson();   /* adopt any lesson already registered in the world */

  function line(pool, fallback) {
    if (!pool || !pool.length) return fallback || '';
    apiCalls += 0;                        /* hook point: an AI could fill pools offline */
    return pool[Math.floor(rng() * pool.length) % pool.length];
  }

  function setLesson(phase, topic, experimentId) {
    if (phase) lesson.phase = phase;
    if (topic) lesson.topic = topic;
    if (experimentId) lesson.experimentId = experimentId;
    if (world && world.get && world.get('lesson')) {
      world.set('lesson', { phase: lesson.phase, topic: lesson.topic, experimentId: lesson.experimentId });
    }
  }

  function readWorldLesson() {
    if (!world || !world.get) return;
    var e = world.get('lesson');
    if (!e || !e.state) return;
    lesson.phase = e.state.phase || lesson.phase;
    lesson.topic = e.state.topic || lesson.topic;
    lesson.experimentId = e.state.experimentId || lesson.experimentId;
  }

  /* one practice attempt against the live simulation state */
  function attempt(s) {
    if (lesson.topic === 'microscope' && world && world.get && world.get(stationId)) {
      var st = world.get(stationId).state;
      var ev = science && science.microscope
        ? science.microscope.evaluate(st, st.specimen || 'none') : null;
      var ok = ev ? ev.ok : false;
      if (!ok) {
        s.mistakes++;
        s.patience = Math.max(0, s.patience - 0.03);
        emit('mistake', s, line(dialogue.mistake), { reason: ev ? ev.consequence || (ev.issues || []).join(',') : 'unusable settings' });
        s.state = S.FEEDBACK; s.stateT = 0; s.dwell = 1;
        return false;
      }
      s.record = { ok: true, cellsAcross: ev.cellsAcross, fovMm: ev.fovMm, field: ev.field, objective: st.objective };
      return true;
    }
    /* non-microscope topics: procedural chance on first try, then the correct method */
    var first = s.retryCount === 0 && rng() > s.skill;
    if (first) {
      s.mistakes++;
      emit('mistake', s, line(dialogue.mistake), { reason: 'procedural' });
      s.state = S.FEEDBACK; s.stateT = 0; s.dwell = 1;
      return false;
    }
    var run = science ? science.run(lesson.experimentId, science.defaults(lesson.experimentId)) : null;
    s.record = run ? { ok: true, summary: run.observations && run.observations[0] ? run.observations[0] : 'recorded', value: run.results } : { ok: true, summary: 'recorded' };
    return true;
  }

  function step(s, dt) {
    s.stateT += dt;
    switch (s.state) {
      case S.IDLE:
        if (lesson.phase === 'demo') { s.state = S.WATCH; s.stateT = 0; s.dwell = 1 + rng() * 2; emit('watch', s, line(dialogue.watch)); }
        else if (lesson.phase === 'practice') { s.state = S.COLLECT; s.stateT = 0; s.dwell = 1 + rng(); s.task = 'practice'; s.retryCount = 0; }
        else if (lesson.phase === 'review') { s.state = S.COLLAB; s.stateT = 0; s.dwell = 1 + rng(); }
        break;

      case S.WATCH:
        if (lesson.phase !== 'demo') { s.state = lesson.phase === 'practice' ? S.COLLECT : (lesson.phase === 'review' ? S.COLLAB : S.IDLE); s.stateT = 0; s.dwell = 1 + rng(); break; }
        if (s.stateT >= s.dwell) {
          var r = rng();
          if (r < 0.25) { s.state = S.LOOK; s.stateT = 0; s.dwell = 0.8 + rng() * 1.2; emit('look', s, line(dialogue.look)); }
          else if (!demoAsked && students[askerIdx % students.length] === s) {
            demoAsked = true; askerIdx++;
            s.state = S.RAISE; s.stateT = 0; s.dwell = 0.6; s.questions++;
            emit('raise', s);
          } else { s.dwell = 1.5 + rng() * 2 * s.attention; s.stateT = 0; }
        }
        break;

      case S.LOOK:
        if (lesson.phase !== 'demo') { s.state = S.WATCH; s.stateT = 0; s.dwell = 1; break; }
        if (s.stateT >= s.dwell) { s.state = S.WATCH; s.stateT = 0; s.dwell = 1.5 + rng() * 2 * s.attention; }
        break;

      case S.RAISE:
        if (s.stateT >= s.dwell) { s.state = S.ASK; s.stateT = 0; s.dwell = 1; emit('ask', s, line(dialogue.ask[lesson.topic] || dialogue.ask.general)); }
        break;

      case S.ASK:
        if (s.stateT >= s.dwell) { s.state = S.LISTEN; s.stateT = 0; s.dwell = 1.2; emit('listen', s, line(dialogue.answer[lesson.topic] || dialogue.answer.general)); }
        break;

      case S.LISTEN:
        if (s.stateT >= s.dwell) { s.state = S.RESPOND; s.stateT = 0; s.dwell = 0.8; emit('respond', s); }
        break;

      case S.RESPOND:
        if (s.stateT >= s.dwell) { s.state = S.WATCH; s.stateT = 0; s.dwell = 1.5 + rng() * 2 * s.attention; }
        break;

      case S.COLLECT:
        if (lesson.phase !== 'practice') { s.state = S.IDLE; s.stateT = 0; break; }
        if (s.stateT >= s.dwell) { emit('collect', s); s.state = S.AT_STATION; s.stateT = 0; s.dwell = 0.5; }
        break;

      case S.AT_STATION:
        if (lesson.phase !== 'practice') { s.state = S.IDLE; s.stateT = 0; break; }
        if (s.stateT >= s.dwell) {
          if (attempt(s)) { s.state = S.RECORD; s.stateT = 0; s.dwell = 1; }
          /* attempt() already moved s to FEEDBACK on failure */
        }
        break;

      case S.FEEDBACK:
        if (s.stateT >= s.dwell) { emit('feedback', s, line(dialogue.feedback)); s.state = S.RETRY; s.stateT = 0; s.dwell = 0.8; }
        break;

      case S.RETRY:
        if (s.stateT >= s.dwell) {
          s.retryCount++;
          s.dwell = Math.min(3, 0.8 + s.retryCount * 0.6);  /* back off while the setup is still wrong */
          s.state = S.AT_STATION; s.stateT = 0;
        }
        break;

      case S.RECORD:
        if (s.stateT >= s.dwell) {
          s.records++; s.task = 'recorded';
          emit('record', s, line(dialogue.record), s.record);
          s.state = S.RETURN; s.stateT = 0; s.dwell = 0.8;
        }
        break;

      case S.RETURN:
        if (s.stateT >= s.dwell) { emit('return', s); emit('complete', s, line(dialogue.complete)); s.task = 'complete'; s.state = S.COMPLETE; s.stateT = 0; }
        break;

      case S.COLLAB:
        if (lesson.phase !== 'review') { s.state = S.IDLE; s.stateT = 0; break; }
        if (s.stateT >= s.dwell) {
          var partner = students[(students.indexOf(s) + 1) % students.length];
          if (s.records > 0 && partner.records > 0) emit('collab', s, line(dialogue.collab), { with: partner.id });
          s.state = S.COMPLETE; s.stateT = 0;
        }
        break;

      case S.COMPLETE:
        /* terminal until the next lesson phase (handled in tick) */
        break;
    }
  }

  function tick(dt) {
    dt = dt == null ? 0.1 : dt;
    t += dt;
    readWorldLesson();
    if (lesson.phase !== prevPhase) {
      if (lesson.phase === 'demo') demoAsked = false;
      /* on a phase change, drop out-of-phase activity back to idle so the
         next phase's entry state (watch / collect / collab) is picked up */
      students.forEach(function (s) {
        var st = s.state;
        var inDemo = st === S.WATCH || st === S.LOOK || st === S.RAISE || st === S.ASK || st === S.LISTEN || st === S.RESPOND;
        var inPractice = st === S.COLLECT || st === S.AT_STATION || st === S.MISTAKE || st === S.FEEDBACK || st === S.RETRY || st === S.RECORD || st === S.RETURN;
        if (st === S.COMPLETE || (inDemo && lesson.phase !== 'demo') || (inPractice && lesson.phase !== 'practice') || st === S.COLLAB) {
          s.state = S.IDLE; s.stateT = 0; s.record = null;
          if (lesson.phase !== 'practice') { s.task = 'none'; s.retryCount = 0; }
        }
      });
      emit('phase', null, null, { phase: lesson.phase, topic: lesson.topic });
      prevPhase = lesson.phase;
    }
    for (var i = 0; i < students.length; i++) step(students[i], dt);
    return events.slice(-20);
  }

  function statuses() {
    return students.map(function (s) {
      return { id: s.id, name: s.name, state: s.state, task: s.task, mistakes: s.mistakes,
        records: s.records, questions: s.questions, patience: +s.patience.toFixed(2) };
    });
  }

  return {
    add: add,
    students: students,
    tick: tick,
    lesson: lesson,
    setLesson: setLesson,
    statuses: statuses,
    events: events,
    dialogue: dialogue,
    STATES: STUDENT_STATES,
    apiCalls: function () { return apiCalls; },
    stats: function () {
      return {
        count: students.length,
        questions: students.reduce(function (a, s) { return a + s.questions; }, 0),
        mistakes: students.reduce(function (a, s) { return a + s.mistakes; }, 0),
        records: students.reduce(function (a, s) { return a + s.records; }, 0),
        completed: students.filter(function (s) { return s.task === 'complete'; }).length,
        events: events.length,
        apiCalls: apiCalls,
      };
    },
  };
}

export { createStudents, DIALOGUE, STUDENT_NAMES, STUDENT_SEATS, STUDENT_STATES };
