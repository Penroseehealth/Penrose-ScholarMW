'use strict';

/* Phase 7a: dynamic lab environment - state + rules (no THREE/DOM).
   Owns the day/night cycle, artificial lighting, fans/ventilation, doors,
   windows, weather, alarms/timers and positioned sound events with distance
   attenuation. The host mirrors this state onto the existing scene lights,
   door/window pivots and UI buttons (two-way, like the Phase-3 taps). */

var WEATHERS = ['clear', 'rain', 'wind', 'storm'];

function envClamp(v, a, b) { return v < a ? a : (v > b ? b : v); }

function daylightFactor(hour) {
  /* 0 at night, 1 at local noon; smooth civil-daylight curve used for the
     window wash. School hours (8-16) sit on the bright shoulder. */
  var h = ((hour % 24) + 24) % 24;
  var x = Math.sin(Math.PI * (h - 6) / 12);       /* -1..1 over 24h */
  if (Math.abs(x) < 1e-9) x = 0;                  /* snap sunrise/sunset */
  return envClamp(x, 0, 1);
}

function createEnvironment(opts) {
  opts = opts || {};
  var state = {
    hour: opts.hour == null ? 10 : opts.hour,     /* 0..24 school clock */
    autoClock: opts.autoClock !== false,          /* advance with real time */
    clockRate: opts.clockRate == null ? 1 / 60 : opts.clockRate, /* hours per second */
    lightsOn: true, lightsManual: true,
    fansOn: true, airconsOn: true,
    doors: [0, 0],                                /* 0 closed .. 1 open (per leaf) */
    windows: [0, 0, 0, 0],
    weather: 'clear',
    tempC: 21, humidityPct: 45,
    alarm: null,                                  /* {kind, at} while sounding */
    evacuation: false,
    timers: [],                                   /* {id, label, remaining} */
    listener: { x: 0, z: -2.4 },                  /* camera-ish ear position */
  };
  var events = [];
  var timerSeq = 0;

  function emit(type, data) {
    var ev = { t: +state.hour.toFixed(3), type: type };
    if (data) for (var k in data) ev[k] = data[k];
    events.push(ev);
    if (events.length > 400) events.splice(0, events.length - 400);
    return ev;
  }

  /* distance attenuation: gain = 1 / (1 + (d/ref)^2), ref = 4 m */
  function gainAt(pos) {
    if (!pos) return 1;
    var dx = (pos.x || 0) - state.listener.x, dz = (pos.z || 0) - state.listener.z;
    var d = Math.sqrt(dx * dx + dz * dz);
    var g = 1 / (1 + Math.pow(d / 4, 2));
    return +g.toFixed(3);
  }

  function sound(name, pos, extra) {
    var ev = emit('sound', { name: name, gain: gainAt(pos), pos: pos || null });
    if (extra) for (var k in extra) ev[k] = extra[k];
    return ev;
  }

  /* ---- derived conditions (lightweight indicators) ---- */
  function daylight() { return +daylightFactor(state.hour).toFixed(3); }
  function indoorLux() {
    var day = daylight();
    var art = state.lightsOn ? 0.72 : 0;
    return +envClamp(0.12 + 0.5 * day + art, 0, 1).toFixed(3);
  }
  function ventilationScore() {
    var v = 0;
    if (state.fansOn) v += 0.4;
    if (state.airconsOn) v += 0.2;
    state.windows.forEach(function (w) { v += 0.15 * w; });
    if (state.weather === 'storm' || state.weather === 'rain') v -= 0.1; /* windows advised shut */
    return +envClamp(v, 0, 1).toFixed(3);
  }
  function comfortIndex() {
    /* 1 = comfortable lab; drops with heat/humidity and no ventilation */
    var t = 1 - Math.min(1, Math.abs(state.tempC - 21) / 14);
    var h = 1 - Math.min(1, Math.max(0, state.humidityPct - 60) / 40);
    return +envClamp(0.5 * t + 0.3 * h + 0.2 * ventilationScore(), 0, 1).toFixed(3);
  }
  function windowsAdvised() {
    if (state.weather === 'rain' || state.weather === 'storm') return false;
    if (state.tempC > 28 && state.humidityPct < 70) return true;
    return ventilationScore() < 0.5;
  }

  /* ---- controls (user actions / events) ---- */
  function setLights(on, manual) {
    if (state.lightsOn === !!on) return false;
    state.lightsOn = !!on;
    if (manual !== false) state.lightsManual = true;
    sound('lights-switch', null);
    emit('lights', { on: state.lightsOn });
    return true;
  }
  function setFans(on) {
    if (state.fansOn === !!on) return false;
    state.fansOn = !!on;
    sound('fan-switch', null);
    emit('fans', { on: state.fansOn });
    return true;
  }
  function setAircon(on) {
    if (state.airconsOn === !!on) return false;
    state.airconsOn = !!on;
    sound('fan-switch', null);
    emit('aircon', { on: state.airconsOn });
    return true;
  }
  function setDoor(i, open) {
    if (state.doors[i] == null) return false;
    var v = open ? 1 : 0;
    if (state.doors[i] === v) return false;
    state.doors[i] = v;
    sound(open ? 'door-open' : 'door-close', { x: 0, z: -5 });
    emit('door', { index: i, open: !!open });
    return true;
  }
  function setWindow(i, open) {
    if (state.windows[i] == null) return false;
    var v = open ? 1 : 0;
    if (state.windows[i] === v) return false;
    state.windows[i] = v;
    sound('window-slide', { x: i < 2 ? -5.8 : 5.8, z: (i % 2 ? 1 : -1) * 2 });
    emit('window', { index: i, open: !!open });
    if (open && !windowsAdvised()) {
      emit('advice', { text: 'window open in ' + state.weather + ' - close it and use the fans', kind: 'window' });
    }
    return true;
  }
  function setWeather(w) {
    if (WEATHERS.indexOf(w) < 0 || state.weather === w) return false;
    state.weather = w;
    if (w === 'rain' || w === 'storm') {
      state.tempC = envClamp(state.tempC - 2, 10, 40);
      state.humidityPct = envClamp(state.humidityPct + 20, 10, 95);
      sound('rain', null, { continuous: true });
    } else if (w === 'wind') {
      sound('wind', null, { continuous: true });
      state.windows.forEach(function (v, i) { if (v > 0) setWindow(i, false); });
    } else {
      state.tempC = envClamp(state.tempC + 1, 10, 40);
      state.humidityPct = envClamp(state.humidityPct - 10, 10, 95);
    }
    emit('weather', { weather: w, tempC: state.tempC, humidityPct: state.humidityPct });
    return true;
  }
  function setHour(h) {
    state.hour = ((h % 24) + 24) % 24;
    /* automatic lighting policy: lights on when the room is dark, unless the
       user took manual control */
    if (!state.lightsManual) {
      var want = daylight() < 0.35;
      if (want !== state.lightsOn) setLights(want, false);
    }
    emit('clock', { hour: state.hour, daylight: daylight() });
    return state.hour;
  }

  /* ---- timers + alarms ---- */
  function setTimer(label, seconds) {
    var id = 'tm' + (++timerSeq);
    state.timers.push({ id: id, label: label, remaining: seconds });
    emit('timer', { id: id, label: label, remaining: seconds });
    return id;
  }
  function alarm(kind, pos) {
    state.alarm = { kind: kind, at: state.hour };
    sound('alarm', pos, { kind: kind });
    emit('alarm', { kind: kind });
    return state.alarm;
  }
  function clearAlarm() {
    if (!state.alarm) return false;
    var k = state.alarm.kind;
    state.alarm = null;
    emit('alarm-clear', { kind: k });
    return true;
  }
  function setEvacuation(on) {
    if (state.evacuation === !!on) return false;
    state.evacuation = !!on;
    emit('evacuation', { on: state.evacuation });
    if (on) alarm('evacuation');
    return true;
  }

  /* ---- tick: clock, easing, timers ---- */
  function tick(dt) {
    dt = dt == null ? 0.1 : dt;
    if (state.autoClock && !state.evacuation) setHour(state.hour + dt * state.clockRate);
    for (var i = state.timers.length - 1; i >= 0; i--) {
      state.timers[i].remaining -= dt;
      if (state.timers[i].remaining <= 0) {
        var tm = state.timers[i];
        state.timers.splice(i, 1);
        alarm('timer', null);
        emit('timer-done', { id: tm.id, label: tm.label });
      }
    }
    return state;
  }

  function serialize() { return JSON.stringify({ v: 1, state: state }); }
  function restore(json) {
    var data = typeof json === 'string' ? JSON.parse(json) : json;
    if (!data || !data.state || data.v !== 1) return false;
    Object.keys(state).forEach(function (k) { if (data.state[k] !== undefined) state[k] = data.state[k]; });
    emit('restore', {});
    return true;
  }

  return {
    state: state,
    events: events,
    tick: tick,
    daylight: daylight,
    indoorLux: indoorLux,
    ventilationScore: ventilationScore,
    comfortIndex: comfortIndex,
    windowsAdvised: windowsAdvised,
    gainAt: gainAt,
    sound: sound,
    setLights: setLights,
    setFans: setFans,
    setAircon: setAircon,
    setDoor: setDoor,
    setWindow: setWindow,
    setWeather: setWeather,
    setHour: setHour,
    setTimer: setTimer,
    alarm: alarm,
    clearAlarm: clearAlarm,
    setEvacuation: setEvacuation,
    serialize: serialize,
    restore: restore,
    WEATHERS: WEATHERS,
  };
}

export { createEnvironment, daylightFactor, WEATHERS };
