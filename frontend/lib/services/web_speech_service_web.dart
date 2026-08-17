import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util' as js_util;

import 'web_speech_service.dart';

WebSpeechService createWebSpeechService() => WebSpeechServiceImpl();

class WebSpeechServiceImpl implements WebSpeechService {
  dynamic _recognition;
  Completer<void>? _speechCompleter;

  @override
  bool get isSupported {
    try {
      return js.context.hasProperty('SpeechRecognition') ||
          js.context.hasProperty('webkitSpeechRecognition');
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isListening => _recognition != null;

  dynamic _getCtor() {
    try {
      return js.context['SpeechRecognition'] ??
          js.context['webkitSpeechRecognition'];
    } catch (_) {
      return null;
    }
  }

  @override
  void startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onEnd,
    required void Function(String error) onError,
    String lang = 'en-US',
  }) {
    if (isListening) return;
    final ctor = _getCtor();
    if (ctor == null) {
      onError('Speech recognition not available');
      onEnd();
      return;
    }

    final rec = js_util.callConstructor(ctor, []);
    js_util.setProperty(rec, 'lang', lang);
    js_util.setProperty(rec, 'interimResults', true);
    js_util.setProperty(rec, 'continuous', false);

    js_util.setProperty(rec, 'onresult', js_util.allowInterop((dynamic event) {
      final results = js_util.getProperty(event, 'results');
      final len = js_util.getProperty(results, 'length') as int;
      final startIdx = js_util.getProperty(event, 'resultIndex') as int;

      for (var i = startIdx; i < len; i++) {
        final r = js_util.getProperty(results, i);
        final isFinal = js_util.getProperty(r, 'isFinal') as bool;
        final alt = js_util.getProperty(r, 0);
        final transcript = js_util.getProperty(alt, 'transcript') as String;
        onResult(transcript, isFinal);
      }
    }));

    js_util.setProperty(rec, 'onend', js_util.allowInterop((_) {
      _recognition = null;
      onEnd();
    }));

    js_util.setProperty(rec, 'onerror', js_util.allowInterop((dynamic event) {
      final errorType =
          js_util.getProperty(event, 'error') as String? ?? 'unknown';
      _recognition = null;

      String message;
      switch (errorType) {
        case 'not-allowed':
        case 'service-not-allowed':
          message = 'Microphone permission denied';
          break;
        case 'no-speech':
          message = 'No speech detected';
          break;
        case 'network':
          message = 'Network error';
          break;
        case 'aborted':
          message = '';
          break;
        default:
          message = 'Voice error: $errorType';
      }

      if (message.isNotEmpty) onError(message);
      onEnd();
    }));

    try {
      js_util.callMethod(rec, 'start', []);
      _recognition = rec;
    } catch (e) {
      _recognition = null;
      onError('Failed to start speech recognition');
      onEnd();
    }
  }

  @override
  void stopListening() {
    if (_recognition != null) {
      try {
        js_util.callMethod(_recognition, 'stop', []);
      } catch (_) {}
      _recognition = null;
    }
  }

  @override
  Future<void> speak(String text, {String lang = 'en-US'}) async {
    cancelSpeech();
    try {
      final synth = js.context['speechSynthesis'];
      if (synth == null) return;

      final ctor = js.context['SpeechSynthesisUtterance'];
      if (ctor == null) return;

      final utt = js_util.callConstructor(ctor, []);
      js_util.setProperty(utt, 'text', text);
      js_util.setProperty(utt, 'lang', lang);

      _speechCompleter = Completer<void>();
      final completer = _speechCompleter!;

      js_util.setProperty(utt, 'onend', js_util.allowInterop((_) {
        if (!completer.isCompleted) completer.complete();
      }));

      js_util.setProperty(utt, 'onerror', js_util.allowInterop((_) {
        if (!completer.isCompleted) completer.complete();
      }));

      js_util.callMethod(synth, 'speak', [utt]);
      return completer.future;
    } catch (_) {
      return Future.value();
    }
  }

  @override
  void cancelSpeech() {
    try {
      final synth = js.context['speechSynthesis'];
      if (synth != null) {
        js_util.callMethod(synth, 'cancel', []);
      }
    } catch (_) {}
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
    _speechCompleter = null;
  }

  @override
  void dispose() {
    stopListening();
    cancelSpeech();
  }
}
