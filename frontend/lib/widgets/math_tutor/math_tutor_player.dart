import 'package:flutter/foundation.dart';

import '../../voice/tts_service.dart';
import '../../voice/voice_session_manager.dart';
import 'math_solution.dart';

enum MathTutorPlaybackState { idle, loading, playing, paused, finished }

/// Drives step-by-step narration for a solved problem.
///
/// Each solution step is spoken on its own, so the visual and the narration can
/// never drift apart: the canvas shows step N and the tutor is saying step N.
/// Pausing stops the audio and keeps the step, so resuming restarts that step
/// rather than skipping into the next one.
class MathTutorPlayer extends ChangeNotifier {
  MathTutorPlayer({PenroseTtsService? tts}) : _tts = tts ?? PenroseTtsService(session: VoiceSessionManager());

  final PenroseTtsService _tts;

  TutorSolution? _solution;
  int _index = 0;
  double _speed = 1.0;
  MathTutorPlaybackState _state = MathTutorPlaybackState.idle;
  bool _followVisual = true;
  bool _disposed = false;
  int _generation = 0;

  TutorSolution? get solution => _solution;
  int get index => _index;
  double get speed => _speed;
  MathTutorPlaybackState get state => _state;
  bool get followVisual => _followVisual;
  bool get isPlaying => _state == MathTutorPlaybackState.playing;
  bool get isBusy => _state == MathTutorPlaybackState.loading;
  bool get hasSolution => _solution != null;
  int get stepNumber => _index + 1;
  int get stepCount => _solution?.stepCount ?? 0;
  bool get isFirstStep => _index == 0;
  bool get isLastStep => _solution != null && _index >= _solution!.stepCount - 1;

  TutorStep? get currentStep {
    final solution = _solution;
    if (solution == null) return null;
    return solution.stepAt(_index);
  }

  /// Attach a solution and speak from its first step.
  Future<void> load(TutorSolution solution, {bool autoplay = true}) async {
    await stopNarration();
    _solution = solution;
    _index = 0;
    _state = MathTutorPlaybackState.idle;
    _notify();
    if (autoplay) await play();
  }

  /// Play, resume, or restart a finished solution.
  Future<void> play() async {
    final solution = _solution;
    if (solution == null) return;

    if (_state == MathTutorPlaybackState.finished) {
      await _playFrom(0);
      return;
    }
    if (_state == MathTutorPlaybackState.playing) return;
    await _playFrom(_index);
  }

  Future<void> _playFrom(int startIndex) async {
    final solution = _solution;
    if (solution == null) return;

    _index = startIndex.clamp(0, solution.stepCount - 1);
    final generation = ++_generation;

    while (true) {
      final step = solution.stepAt(_index);
      _state = MathTutorPlaybackState.loading;
      _notify();

      await _tts.speakOnce(step.narration, lang: _localeTag, speed: _speed);

      if (_disposed || generation != _generation) return;

      _state = MathTutorPlaybackState.playing;
      _notify();

      if (_index >= solution.stepCount - 1) {
        _state = MathTutorPlaybackState.finished;
        _notify();
        return;
      }
      _index++;
      _notify();
    }
  }

  /// Stop the narration and keep the current step.
  Future<void> pause() async {
    if (_state != MathTutorPlaybackState.playing && _state != MathTutorPlaybackState.loading) {
      return;
    }
    _generation++;
    await stopNarration();
    _state = MathTutorPlaybackState.paused;
    _notify();
  }

  /// Stop the narration entirely.
  Future<void> stopNarration() async {
    _generation++;
    _tts.stop();
    if (_state == MathTutorPlaybackState.playing || _state == MathTutorPlaybackState.loading) {
      _state = MathTutorPlaybackState.paused;
      _notify();
    }
  }

  /// Jump straight to a step, optionally narrating it.
  Future<void> seekTo(int stepId, {bool autoplay = true}) async {
    final solution = _solution;
    if (solution == null) return;
    if (stepId < 1 || stepId > solution.stepCount) return;
    await stopNarration();
    _index = stepId - 1;
    _state = MathTutorPlaybackState.paused;
    _notify();
    if (autoplay) await _playFrom(_index);
  }

  /// Replay the current step from the beginning.
  Future<void> replay() async {
    if (_solution == null) return;
    await _playFrom(_index);
  }

  Future<void> next() async {
    final solution = _solution;
    if (solution == null || isLastStep) return;
    await _playFrom(_index + 1);
  }

  Future<void> previous() async {
    final solution = _solution;
    if (solution == null || isFirstStep) return;
    await _playFrom(_index - 1);
  }

  /// Start again from step one.
  Future<void> restart() async {
    if (_solution == null) return;
    await _playFrom(0);
  }

  Future<void> setSpeed(double value) async {
    if (value == _speed) return;
    _speed = value;
    _notify();
    if (_state == MathTutorPlaybackState.playing || _state == MathTutorPlaybackState.loading) {
      await replay();
    }
  }

  void setFollowVisual(bool value) {
    if (value == _followVisual) return;
    _followVisual = value;
    _notify();
  }

  /// Language tag matching the selected accent, used for the browser fallback.
  set lang(String value) {
    if (value == _lang) return;
    _lang = value;
  }

  /// Catalog voice id sent to the server TTS engine for every narration.
  ///
  /// The player owns the microphone too: without this the maths tutor would
  /// silently fall back to the backend default speaker instead of the voice the
  /// student chose in the picker.
  set voiceId(String? value) {
    final resolved = (value == null || value.isEmpty) ? null : value;
    if (resolved == _tts.voiceId) return;
    _tts.voiceId = resolved;
  }

  String? get voiceId => _tts.voiceId;

  String _lang = 'en-GB';

  String get _localeTag {
    final normalized = _lang.replaceAll('_', '-');
    return normalized.length > 2 ? normalized : 'en-$normalized';
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _tts.stop();
    super.dispose();
  }
}
