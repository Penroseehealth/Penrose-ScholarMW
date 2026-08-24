import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'web_speech_service.dart';

WebSpeechService createWebSpeechService() => WebSpeechServiceImpl();

class WebSpeechServiceImpl implements WebSpeechService {
  JSObject? _recognition;
  Completer<void>? _speechCompleter;

  @override
  bool get isSupported {
    try {
      return globalContext.hasProperty('SpeechRecognition'.toJS).toDart ||
          globalContext.hasProperty('webkitSpeechRecognition'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isListening => _recognition != null;

  JSFunction? _getCtor() {
    try {
      final ctor = globalContext.getProperty<JSFunction?>('SpeechRecognition'.toJS);
      return ctor ?? globalContext.getProperty<JSFunction?>('webkitSpeechRecognition'.toJS);
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

    final rec = ctor.callAsConstructor<JSObject>();
    rec.setProperty('lang'.toJS, lang.toJS);
    rec.setProperty('interimResults'.toJS, true.toJS);
    rec.setProperty('continuous'.toJS, false.toJS);

    rec.setProperty(
        'onresult'.toJS,
        ((JSAny? event) {
          final e = event! as JSObject;
          final results = e.getProperty<JSObject>('results'.toJS);
          final len = results.getProperty<JSNumber>('length'.toJS).toDartInt;
          final startIdx = e.getProperty<JSNumber>('resultIndex'.toJS).toDartInt;

          for (var i = startIdx; i < len; i++) {
            final r = results.getProperty<JSObject>(i.toString().toJS);
            final isFinal = r.getProperty<JSBoolean>('isFinal'.toJS).toDart;
            final alt = r.getProperty<JSObject>('0'.toJS);
            final transcript = alt.getProperty<JSString>('transcript'.toJS).toDart;
            onResult(transcript, isFinal);
          }
        }).toJS);

    rec.setProperty(
        'onend'.toJS,
        ((JSAny? _) {
          _recognition = null;
          onEnd();
        }).toJS);

    rec.setProperty(
        'onerror'.toJS,
        ((JSAny? event) {
          final e = event as JSObject?;
          final errorType = e?.getProperty<JSString>('error'.toJS).toDart ?? 'unknown';
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
        }).toJS);

    try {
      rec.callMethod('start'.toJS);
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
        _recognition!.callMethod('stop'.toJS);
      } catch (_) {}
      _recognition = null;
    }
  }

  @override
  Future<void> speak(String text, {String lang = 'en-US'}) async {
    cancelSpeech();
    try {
      final synth = globalContext.getProperty<JSObject?>('speechSynthesis'.toJS);
      if (synth == null) return;

      final ctor = globalContext.getProperty<JSFunction?>('SpeechSynthesisUtterance'.toJS);
      if (ctor == null) return;

      final utt = ctor.callAsConstructor<JSObject>();
      utt.setProperty('text'.toJS, text.toJS);
      utt.setProperty('lang'.toJS, lang.toJS);

      _speechCompleter = Completer<void>();
      final completer = _speechCompleter!;

      utt.setProperty(
          'onend'.toJS,
          ((JSAny? _) {
            if (!completer.isCompleted) completer.complete();
          }).toJS);

      utt.setProperty(
          'onerror'.toJS,
          ((JSAny? _) {
            if (!completer.isCompleted) completer.complete();
          }).toJS);

      synth.callMethodVarArgs('speak'.toJS, [utt as JSAny?]);
      return await completer.future;
    } catch (_) {
      return Future.value();
    }
  }

  @override
  void cancelSpeech() {
    try {
      final synth = globalContext.getProperty<JSObject?>('speechSynthesis'.toJS);
      if (synth != null) {
        synth.callMethod('cancel'.toJS);
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
