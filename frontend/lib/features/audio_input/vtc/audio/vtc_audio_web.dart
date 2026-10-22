// Web implementation: a real <audio> element, so every value the UI shows
// (duration, position, volume) is read back from the browser.
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'vtc_audio_engine.dart';

class _WebVtcAudioEngine implements VtcAudioEngine {
  web.HTMLAudioElement? _el;
  String _base64 = '';
  String _mime = 'audio/mpeg';
  bool _seeking = false;

  @override
  bool get supported => true;

  web.HTMLAudioElement? get _audio => _el;

  @override
  AudioLoadResult load(String base64, String mime) {
    if (base64.isEmpty) {
      return const AudioLoadResult(false, error: 'No audio was returned.');
    }
    try {
      stop();
      final el = web.HTMLAudioElement()
        ..preload = 'auto'
        ..src = 'data:${mime.isEmpty ? 'audio/mpeg' : mime};base64,$base64';
      _base64 = base64;
      _mime = mime;
      _el = el;
      return const AudioLoadResult(true);
    } catch (e) {
      _el = null;
      return AudioLoadResult(false, error: 'Could not load audio: $e');
    }
  }

  @override
  void play() {
    final el = _audio;
    if (el == null) return;
    // Autoplay policies can reject until the user gestures; swallow the
    // rejection so the UI simply reflects the element's real paused state.
    el.play().toDart.catchError((Object _) => null);
  }

  @override
  void pause() => _audio?.pause();

  @override
  void stop() {
    final el = _audio;
    if (el == null) return;
    try {
      el.pause();
      el.currentTime = 0;
    } catch (_) {
      // Element may already be torn down.
    }
  }

  @override
  void seek(double seconds) {
    final el = _audio;
    if (el == null) return;
    final d = duration;
    if (d <= 0) return;
    final target = seconds.clamp(0.0, d);
    try {
      el.currentTime = target;
    } catch (_) {
      // Seeking before metadata is available is not fatal.
    }
  }

  @override
  void setVolume(double value) {
    final el = _audio;
    if (el == null) return;
    try {
      el.volume = value.clamp(0.0, 1.0);
    } catch (_) {
      // Ignore.
    }
  }

  @override
  double get volume {
    final el = _audio;
    if (el == null) return 1.0;
    try {
      return el.volume;
    } catch (_) {
      return 1.0;
    }
  }

  @override
  double get position {
    final el = _audio;
    if (el == null) return 0;
    try {
      final v = el.currentTime;
      return v.isFinite && v > 0 ? v.toDouble() : 0.0;
    } catch (_) {
      return 0;
    }
  }

  @override
  double get duration {
    final el = _audio;
    if (el == null) return 0;
    try {
      final d = el.duration;
      return d.isFinite && d > 0 ? d.toDouble() : 0.0;
    } catch (_) {
      return 0;
    }
  }

  @override
  bool get playing {
    final el = _audio;
    if (el == null) return false;
    try {
      return !el.paused && !el.ended;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get ready => duration > 0;

  @override
  bool get seeking => _seeking;

  @override
  void setSeeking(bool value) => _seeking = value;

  @override
  Future<AudioShareResult> download(String filename) async {
    if (_base64.isEmpty) {
      return const AudioShareResult(false, message: 'Nothing to download yet.');
    }
    try {
      final blob = _blob();
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = filename
        ..style.display = 'none';
      web.document.body?.appendChild(anchor);
      anchor.click();
      anchor.remove();
      // Give the browser a moment to start the download before revoking.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      web.URL.revokeObjectURL(url);
      return const AudioShareResult(true, message: 'Download started.');
    } catch (e) {
      return AudioShareResult(false, message: 'Download failed: $e');
    }
  }

  @override
  Future<AudioShareResult> share(String filename) async {
    if (_base64.isEmpty) {
      return const AudioShareResult(false, message: 'Nothing to share yet.');
    }
    try {
      final nav = web.window.navigator;
      final file = web.File(<JSAny>[_blob()].toJS, filename, web.FilePropertyBag(type: _mime));
      final data = web.ShareData(files: <web.File>[file].toJS, title: 'Penrose voice preview');
      if (nav.canShare(data)) {
        await nav.share(data).toDart;
        return const AudioShareResult(true, message: 'Shared.');
      }
      // Honest: this browser cannot share audio files, so say so.
      return AudioShareResult(
        false,
        message: 'This browser cannot share audio files — use Download.',
        fellBackToDownload: true,
      );
    } catch (_) {
      return AudioShareResult(false, message: 'Sharing is unavailable here — use Download.', fellBackToDownload: true);
    }
  }

  web.Blob _blob() {
    final bytes = _decodeBase64(_base64);
    return web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: _mime));
  }

  @override
  void dispose() {
    final el = _audio;
    _el = null;
    _base64 = '';
    if (el == null) return;
    try {
      el.pause();
      el.removeAttribute('src');
      el.load();
    } catch (_) {
      // Best effort.
    }
  }
}

Uint8List _decodeBase64(String input) {
  // atob works for the base64 payloads the backend returns.
  final binary = web.window.atob(input);
  final out = Uint8List(binary.length);
  for (var i = 0; i < binary.length; i++) {
    out[i] = binary.codeUnitAt(i);
  }
  return out;
}

VtcAudioEngine createVtcAudioEngine() => _WebVtcAudioEngine();
