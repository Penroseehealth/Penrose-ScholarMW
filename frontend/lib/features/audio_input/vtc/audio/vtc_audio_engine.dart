// Shared contract for the Voice Training Center's audio player.
//
// Web drives a real <audio> element so duration, seeking, volume and download
// are genuine values read back from the element. Other platforms get an inert
// stub that reports "unsupported" rather than faking a player.

/// Outcome of a load attempt. [ok] false means the browser refused the data,
/// and the UI must not claim success.
class AudioLoadResult {
  const AudioLoadResult(this.ok, {this.error});

  final bool ok;
  final String? error;
}

/// Outcome of a share attempt.
class AudioShareResult {
  const AudioShareResult(this.ok, {this.message, this.fellBackToDownload = false});

  final bool ok;
  final String? message;
  final bool fellBackToDownload;
}

abstract class VtcAudioEngine {
  /// True when this platform can actually play audio.
  bool get supported;

  /// Loads [base64] audio. Returns a failure instead of silently succeeding.
  AudioLoadResult load(String base64, String mime);

  void play();
  void pause();
  void stop();

  /// Seeks to [seconds]; ignored when out of range.
  void seek(double seconds);

  /// Sets volume 0..1.
  void setVolume(double value);

  double get volume;

  /// Current playback position in seconds (0 when unknown).
  double get position;

  /// Track length in seconds (0 until metadata has loaded).
  double get duration;

  bool get playing;

  /// True once metadata is available, so the UI can enable the scrubber.
  bool get ready;

  /// True while the user is dragging the scrubber.
  bool get seeking;

  void setSeeking(bool value);

  /// Saves the loaded audio to disk under [filename].
  Future<AudioShareResult> download(String filename);

  /// Shares the loaded audio; reports honestly when unsupported.
  Future<AudioShareResult> share(String filename);

  void dispose();
}
