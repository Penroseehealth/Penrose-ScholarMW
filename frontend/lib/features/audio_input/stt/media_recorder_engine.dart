// Shared contract for microphone recording (used for Groq-server STT).
import 'dart:typed_data';

/// Result of a finished recording: MIME type, raw audio bytes and how long the
/// user actually spoke (excluding paused time), so the server can show an
/// accurate clip length and cap the transcript by real speech.
class RecordedAudio {
  const RecordedAudio({
    required this.bytes,
    required this.mimeType,
    this.durationMs = 0,
    this.waveform = const <int>[],
  });

  final List<int> bytes;
  final String mimeType;

  /// Milliseconds of captured audio, ignoring any paused span.
  final int durationMs;

  /// Coarse amplitude samples (0..100) captured while recording, for drawing a
  /// waveform. Empty when the platform cannot measure levels.
  final List<int> waveform;
}

/// Platform microphone recorder. Web hires the MediaRecorder API; the stub
/// (VM/tests) reports unsupported and is inert.
abstract class MediaRecorderEngine {
  /// Whether this platform can record audio in the browser.
  bool get supported;

  /// True while capturing (including a paused span, so the UI can show state).
  bool get recording;

  /// True while the recorder is capturing but not receiving audio.
  bool get paused;

  /// Milliseconds captured so far, excluding paused spans.
  int get elapsedMs;

  /// Latest coarse amplitude sample (0..100), or 0 when unavailable.
  int get level;

  /// Starts capturing from the microphone. Throws on permission failure.
  Future<void> start();

  /// Suspends capture without discarding audio. No-op when not recording.
  void pause();

  /// Resumes a paused recording. No-op when not paused.
  void resume();

  /// Stops and resolves with the captured audio. No-op safe when idle.
  Future<RecordedAudio> stop();

  /// Aborts without producing audio.
  void cancel();
}

/// Optional capability for recorders that can hand out audio *while* the user
/// is still speaking, which is what makes incremental (pseudo-streaming)
/// transcription possible.
///
/// This is deliberately separate from [MediaRecorderEngine]: the MediaRecorder
/// API only emits self-contained WebM/Opus at the very end of a take, so a
/// recorder that can stream has to tap decoded PCM instead. A recorder that
/// does not implement this simply has no live partials, and the caller falls
/// back to transcribing once when the capture finishes.
abstract class ChunkedRecorderEngine implements MediaRecorderEngine {
  /// Called with each decoded audio segment as it becomes available, oldest
  /// first. Segments are provisional: the finished capture remains the
  /// authoritative recording.
  set onChunk(void Function(RecordedAudio chunk)? listener);

  /// Roughly how much speech each segment covers, so a caller can size its own
  /// timeouts.
  int get chunkIntervalMs;
}

/// Amplitude samples accumulated by a recorder, drawn as a waveform.
Uint8List buildWaveformBars(List<int> samples, {int bars = 48}) {
  if (samples.isEmpty || bars <= 0) {
    return Uint8List(0);
  }
  final out = Uint8List(bars);
  final step = samples.length / bars;
  for (var i = 0; i < bars; i++) {
    final start = (i * step).floor();
    final end = ((i + 1) * step).ceil().clamp(start + 1, samples.length);
    var peak = 0;
    for (var j = start; j < end && j < samples.length; j++) {
      if (samples[j] > peak) peak = samples[j];
    }
    out[i] = peak.clamp(0, 100);
  }
  return out;
}
