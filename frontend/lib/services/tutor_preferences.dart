import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-controlled tutor behaviour, persisted between sessions.
///
/// The defaults are the agreed product defaults: a plain whiteboard with no
/// grid, handwritten mathematics, step-by-step animation and contextual memory
/// all switched on, and computer typeset maths off.
///
/// [memoryOnly] builds an instance that never touches storage, which is what
/// screens use for their very first frame before preferences have been read.
class TutorPreferences extends ChangeNotifier {
  TutorPreferences._({
    required SharedPreferences? prefs,
    bool? handwrittenMath,
    bool? typedMath,
    bool? gridVisible,
    bool? plainWhiteboard,
    bool? animateSteps,
    bool? contextualMemory,
    bool? speakReplies,
    String? voiceLanguage,
  })  : _prefs = prefs,
        _handwrittenMath = handwrittenMath ?? prefs?.getBool(_kHandwritten) ?? true,
        _typedMath = typedMath ?? prefs?.getBool(_kTyped) ?? false,
        _gridVisible = gridVisible ?? prefs?.getBool(_kGrid) ?? false,
        _plainWhiteboard = plainWhiteboard ?? prefs?.getBool(_kPlain) ?? true,
        _animateSteps = animateSteps ?? prefs?.getBool(_kAnimate) ?? true,
        _contextualMemory = contextualMemory ?? prefs?.getBool(_kMemory) ?? true,
        _speakReplies = speakReplies ?? prefs?.getBool(_kSpeak) ?? false,
        _voiceLanguage = voiceLanguage ?? prefs?.getString(_kLang) ?? 'en-US';

  static const String _kHandwritten = 'tutor.handwritten_math';
  static const String _kTyped = 'tutor.typed_math';
  static const String _kGrid = 'tutor.grid_visible';
  static const String _kPlain = 'tutor.plain_whiteboard';
  static const String _kAnimate = 'tutor.animate_steps';
  static const String _kMemory = 'tutor.contextual_memory';
  static const String _kSpeak = 'tutor.speak_replies';
  static const String _kLang = 'tutor.voice_language';

  static Future<TutorPreferences> load() async => TutorPreferences._(prefs: await SharedPreferences.getInstance());

  /// Defaults without storage, for the first frame before loading finishes.
  static TutorPreferences memoryOnly() => TutorPreferences._(prefs: null);

  final SharedPreferences? _prefs;

  bool _handwrittenMath;
  bool _typedMath;
  bool _gridVisible;
  bool _plainWhiteboard;
  bool _animateSteps;
  bool _contextualMemory;
  bool _speakReplies;
  String _voiceLanguage;

  bool get handwrittenMath => _handwrittenMath;
  bool get typedMath => _typedMath;
  bool get gridVisible => _gridVisible;
  bool get plainWhiteboard => _plainWhiteboard;
  bool get animateSteps => _animateSteps;
  bool get contextualMemory => _contextualMemory;
  bool get speakReplies => _speakReplies;
  String get voiceLanguage => _voiceLanguage;

  /// Computer typeset and handwritten are alternatives, never both at once.
  ///
  /// Handwriting is the default, so turning typeset maths on turns handwriting
  /// off rather than leaving the tutor rendering every line twice.
  bool get showHandwriting => _handwrittenMath && !_typedMath;

  Future<void> setHandwrittenMath(bool value) async {
    if (_handwrittenMath == value && !_typedMath) return;
    _handwrittenMath = value;
    if (value) _typedMath = false;
    notifyListeners();
    await _prefs?.setBool(_kHandwritten, value);
    await _prefs?.setBool(_kTyped, _typedMath);
  }

  Future<void> setTypedMath(bool value) async {
    if (_typedMath == value && !_handwrittenMath) return;
    _typedMath = value;
    if (value) _handwrittenMath = false;
    notifyListeners();
    await _prefs?.setBool(_kTyped, value);
    await _prefs?.setBool(_kHandwritten, _handwrittenMath);
  }

  Future<void> setGridVisible(bool value) async {
    if (_gridVisible == value) return;
    _gridVisible = value;
    notifyListeners();
    await _prefs?.setBool(_kGrid, value);
  }

  Future<void> setPlainWhiteboard(bool value) async {
    if (_plainWhiteboard == value) return;
    _plainWhiteboard = value;
    notifyListeners();
    await _prefs?.setBool(_kPlain, value);
  }

  Future<void> setAnimateSteps(bool value) async {
    if (_animateSteps == value) return;
    _animateSteps = value;
    notifyListeners();
    await _prefs?.setBool(_kAnimate, value);
  }

  Future<void> setContextualMemory(bool value) async {
    if (_contextualMemory == value) return;
    _contextualMemory = value;
    notifyListeners();
    await _prefs?.setBool(_kMemory, value);
  }

  Future<void> setSpeakReplies(bool value) async {
    if (_speakReplies == value) return;
    _speakReplies = value;
    notifyListeners();
    await _prefs?.setBool(_kSpeak, value);
  }

  Future<void> setVoiceLanguage(String value) async {
    if (_voiceLanguage == value) return;
    _voiceLanguage = value;
    notifyListeners();
    await _prefs?.setString(_kLang, value);
  }

  /// Restores every default in one step.
  Future<void> reset() async {
    _handwrittenMath = true;
    _typedMath = false;
    _gridVisible = false;
    _plainWhiteboard = true;
    _animateSteps = true;
    _contextualMemory = true;
    _speakReplies = false;
    _voiceLanguage = 'en-US';
    notifyListeners();
    final prefs = _prefs;
    if (prefs == null) return;
    await Future.wait<void>(<Future<void>>[
      prefs.setBool(_kHandwritten, true).then((_) {}),
      prefs.setBool(_kTyped, false).then((_) {}),
      prefs.setBool(_kGrid, false).then((_) {}),
      prefs.setBool(_kPlain, true).then((_) {}),
      prefs.setBool(_kAnimate, true).then((_) {}),
      prefs.setBool(_kMemory, true).then((_) {}),
      prefs.setBool(_kSpeak, false).then((_) {}),
      prefs.setString(_kLang, 'en-US').then((_) {}),
    ]);
  }
}
