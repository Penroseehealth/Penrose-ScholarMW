// Encoding of decoded PCM audio as a 16-bit PCM WAV container.
//
// The browser's MediaRecorder can only emit compressed WebM/Opus. Nothing on the
// training path understands it: the backend measures clip quality with the
// stdlib `wave` reader, and OpenVoice loads the sample through the same kind of
// reader. A compressed sample therefore reports an unmeasurable length, skips
// every quality check, and then fails to train. Decoding the capture in the
// browser and re-wrapping it as WAV is what makes the length verifiable and the
// sample trainable.
import 'dart:math' as math;
import 'dart:typed_data';

/// Maps a linear root-mean-square amplitude to a 0..100 meter level on a dBFS
/// scale, where -60dBFS (near silence) is 0 and 0dBFS (full scale) is 100.
///
/// The waveform must be supplied as a linear amplitude. Taking the logarithm of
/// an already-decibelled value (as an analyser's frequency data returns) would
/// produce a constant and pin the meter, which is what makes a voice-activity
/// detector believe the user is permanently speaking.
int meterLevelForRms(double rms) {
  final safe = rms.isFinite && rms > 1e-9 ? rms : 1e-9;
  final db = 20 * math.log(safe) / math.ln10;
  return ((db + 60) / 60 * 100).round().clamp(0, 100);
}

/// Decoded plain PCM, ready to be wrapped in a container.
class PcmAudio {
  const PcmAudio({required this.samples, required this.sampleRate});

  /// Mono samples nominally in -1.0..1.0.
  final Float32List samples;
  final int sampleRate;

  /// Clip length in milliseconds, taken from the decoded frame count rather
  /// than a wall-clock timer, so it always describes the audio being uploaded.
  int get durationMs => sampleRate <= 0 ? 0 : (samples.length * 1000 / sampleRate).round();
}

/// Averages channel planes into a single mono plane.
Float32List downmixToMono(List<Float32List> channels) {
  if (channels.isEmpty) {
    return Float32List(0);
  }
  if (channels.length == 1) {
    return channels.first;
  }
  final frames = channels.first.length;
  final mono = Float32List(frames);
  for (var i = 0; i < frames; i++) {
    var sum = 0.0;
    var counted = 0;
    for (final channel in channels) {
      if (i < channel.length) {
        sum += channel[i];
        counted++;
      }
    }
    mono[i] = counted == 0 ? 0 : sum / counted;
  }
  return mono;
}

/// Wraps [audio] in a canonical 44-byte PCM WAV container: RIFF/WAVE, a 16-byte
/// `fmt ` chunk, and little-endian signed 16-bit mono samples.
Uint8List encodePcm16Wav(PcmAudio audio) {
  final rate = audio.sampleRate > 0 ? audio.sampleRate : 16000;
  final dataBytes = audio.samples.length * 2;
  final out = Uint8List(44 + dataBytes);
  final view = ByteData.sublistView(out);

  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      out[offset + i] = text.codeUnitAt(i);
    }
  }

  ascii(0, 'RIFF');
  view.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  view.setUint32(16, 16, Endian.little); // PCM fmt chunk size
  view.setUint16(20, 1, Endian.little); // format 1 = uncompressed PCM
  view.setUint16(22, 1, Endian.little); // channels: mono
  view.setUint32(24, rate, Endian.little);
  view.setUint32(28, rate * 2, Endian.little); // byte rate
  view.setUint16(32, 2, Endian.little); // block align
  view.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  view.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < audio.samples.length; i++) {
    var sample = audio.samples[i];
    // NaN has no direction to clamp towards and would throw on round(); treat
    // it as silence. Infinities still saturate, as a clamp should.
    if (sample.isNaN) {
      sample = 0;
    }
    if (sample > 1) sample = 1;
    if (sample < -1) sample = -1;
    view.setInt16(44 + i * 2, (sample * 32767).round(), Endian.little);
  }
  return out;
}
