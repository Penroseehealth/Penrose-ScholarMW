import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/audio_input/stt/media_recorder.dart';
import 'voice_session_manager.dart';

/// Energy-based barge-in detector.
///
/// While the assistant is speaking, the microphone is held open through the
/// recorder's level meter (the audio graph requests `echoCancellation`, so the
/// assistant's own voice is largely removed before it reaches the meter). When
/// the measured level stays above [threshold] for [requiredHits] consecutive
/// polls, the user is judged to have started talking and the session is
/// interrupted.
///
/// This is deliberately *energy* detection rather than full voice-activity
/// detection: it cannot tell a cough from a word, and it is not a substitute for
/// a real VAD. It is the pragmatic option for a browser stack where the Web
/// Speech recogniser is not continuously open during playback. The sustained-hit
/// requirement plus a short arm delay after speech begins guard against the
/// assistant triggering itself.
class BargeInMonitor {
  BargeInMonitor({
    required VoiceSessionManager session,
    MediaRecorderEngine? recorder,
    this.threshold = 18,
    this.requiredHits = 2,
    this.pollInterval = const Duration(milliseconds: 100),
    this.armDelay = const Duration(milliseconds: 350),
  })  : _session = session,
        _recorder = recorder ?? MediaRecorderInput.create();

  final VoiceSessionManager _session;
  final MediaRecorderEngine _recorder;

  /// Meter level (0..100) at or above which a frame counts as speech.
  final int threshold;

  /// Consecutive speech-level frames needed before a barge-in fires. Two polls
  /// at 100 ms is ~200 ms of sustained energy, which rejects a single click.
  final int requiredHits;

  /// How often the meter is sampled.
  final Duration pollInterval;

  /// Grace period after speech starts before barge-in is armed, so the very
  /// start of playback (and its room echo) does not trip the detector.
  final Duration armDelay;

  Timer? _poll;
  DateTime? _armedAt;
  int _hits = 0;
  bool _running = false;
  bool _starting = false;

  bool get isRunning => _running;

  /// Begin watching for barge-in. Safe to call when already running.
  Future<void> start() async {
    if (_running || _starting) return;
    if (!_recorder.supported) return;
    _starting = true;
    try {
      await _recorder.start();
      // Held paused: the mic graph keeps producing levels but no audio is
      // buffered, since barge-in only needs the energy reading, not a clip.
      _recorder.pause();
      _hits = 0;
      _armedAt = DateTime.now().add(armDelay);
      _running = true;
      _poll = Timer.periodic(pollInterval, (_) => _tick());
    } catch (_) {
      // A failed meter must never block the conversation.
      _running = false;
    } finally {
      _starting = false;
    }
  }

  /// Stop watching and release the microphone.
  void stop() {
    _poll?.cancel();
    _poll = null;
    _running = false;
    _hits = 0;
    _armedAt = null;
    try {
      _recorder.cancel();
    } catch (_) {
      // Best effort.
    }
  }

  void _tick() {
    if (!_running) return;
    // Only meaningful while the assistant is actually speaking.
    if (!_session.isSpeaking) {
      _hits = 0;
      return;
    }
    final armedAt = _armedAt;
    if (armedAt != null && DateTime.now().isBefore(armedAt)) {
      return;
    }
    final level = _recorder.level;
    if (level >= threshold) {
      _hits++;
      if (_hits >= requiredHits) {
        _hits = 0;
        debugPrint('BargeIn: user speech detected (level=$level) — interrupting');
        _session.interrupt();
      }
    } else {
      _hits = 0;
    }
  }

  void dispose() => stop();
}
