// Web implementation of live speech recognition via the Web Speech API.
// The recognizer is created from `SpeechRecognition` / `webkitSpeechRecognition`
// (not statically exported by package:web) and driven through the raw JS
// interop extensions; property reads are nullable so a missing recognizer is
// detected cleanly.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'speech_input_engine.dart';

SpeechRecognitionEngine createSpeechRecognitionEngine({
  required SpeechResultCallback onResult,
  SpeechStatusCallback? onStatus,
}) =>
    _WebSpeechRecognitionEngine(onResult: onResult, onStatus: onStatus);

JSAny? _recognitionConstructor() {
  final constructor = web.window.getProperty<JSAny?>('webkitSpeechRecognition'.toJS) ??
      web.window.getProperty<JSAny?>('SpeechRecognition'.toJS);
  return constructor;
}

class _WebSpeechRecognitionEngine implements SpeechRecognitionEngine {
  _WebSpeechRecognitionEngine({required this.onResult, this.onStatus});

  final SpeechResultCallback onResult;
  final SpeechStatusCallback? onStatus;

  JSObject? _recognition;
  bool _active = false;

  @override
  bool get supported => _recognitionConstructor() != null;

  @override
  bool get listening => _active;

  @override
  void start() {
    cancel();
    final ctor = _recognitionConstructor();
    if (ctor == null) {
      onStatus?.call('error:unsupported');
      return;
    }
    final recognition = (ctor as JSFunction).callAsConstructor<JSObject>();
    _recognition = recognition;
    recognition['lang'] = 'en-US'.toJS;
    recognition['interimResults'] = true.toJS;
    recognition['continuous'] = true.toJS;
    recognition['maxAlternatives'] = 1.toJS;
    recognition['onstart'] = _handleStart.toJS;
    recognition['onresult'] = _handleResult.toJS;
    recognition['onerror'] = _handleError.toJS;
    recognition['onend'] = _handleEnd.toJS;
    try {
      recognition.callMethod<JSAny?>('start'.toJS);
      _active = true;
    } catch (_) {
      _recognition = null;
      _active = false;
      onStatus?.call('error:start');
    }
  }

  @override
  void stop() {
    final recognition = _recognition;
    if (recognition == null || !_active) {
      return;
    }
    try {
      recognition.callMethod<JSAny?>('stop'.toJS);
    } catch (_) {
      // The recognizer may already have ended; onend settles the state.
    }
  }

  @override
  void cancel() {
    final recognition = _recognition;
    _recognition = null;
    _active = false;
    if (recognition == null) {
      return;
    }
    try {
      recognition.callMethod<JSAny?>('abort'.toJS);
    } catch (_) {
      // Best effort.
    }
  }

  @override
  void dispose() {
    cancel();
  }

  void _handleStart(JSAny? _) {
    _active = true;
    onStatus?.call('listening');
  }

  void _handleEnd(JSAny? _) {
    _recognition = null;
    _active = false;
    onStatus?.call('idle');
  }

  void _handleError(JSAny? event) {
    final code = ((event as JSObject?)?['error'] as JSString?)?.toDart ?? 'unknown';
    _recognition = null;
    _active = false;
    onStatus?.call('error:$code');
  }

  void _handleResult(JSAny? event) {
    final results = (event as JSObject?)?['results'] as JSObject?;
    if (results == null) {
      onStatus?.call('error:parse');
      return;
    }
    final committed = <String>[];
    var interim = '';
    final length = (results['length'] as JSNumber?)?.toDartInt ?? 0;
    for (var i = 0; i < length; i++) {
      final item = results.callMethod<JSObject?>('item'.toJS, i.toJS);
      if (item == null) {
        continue;
      }
      final itemLength = (item['length'] as JSNumber?)?.toDartInt ?? 0;
      if (itemLength == 0) {
        continue;
      }
      final first = item.callMethod<JSObject?>('item'.toJS, 0.toJS);
      if (first == null) {
        continue;
      }
      final transcript = (first['transcript'] as JSString?)?.toDart.trim() ?? '';
      final isFinal = (item['isFinal'] as JSBoolean?)?.toDart ?? false;
      if (isFinal) {
        committed.add(transcript);
      } else {
        interim = transcript;
      }
    }
    onResult(interim, committed.join(' '));
  }
}
