import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/services/tutor_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TutorPreferences> loadWith(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    return TutorPreferences.load();
  }

  test('defaults match the agreed product behaviour', () {
    final TutorPreferences prefs = TutorPreferences.memoryOnly();

    expect(prefs.handwrittenMath, isTrue, reason: 'handwriting is the default');
    expect(prefs.typedMath, isFalse, reason: 'typed maths is off by default');
    expect(prefs.showHandwriting, isTrue);
    expect(prefs.gridVisible, isFalse, reason: 'the board is plain, with no grid');
    expect(prefs.plainWhiteboard, isTrue);
    expect(prefs.animateSteps, isTrue, reason: 'steps animate by default');
    expect(prefs.contextualMemory, isTrue, reason: 'context memory is on by default');
    expect(prefs.speakReplies, isFalse);
  });

  test('typed maths replaces handwriting rather than stacking with it', () async {
    final TutorPreferences prefs = await loadWith(<String, Object>{});

    await prefs.setTypedMath(true);

    expect(prefs.typedMath, isTrue);
    expect(prefs.handwrittenMath, isFalse);
    expect(prefs.showHandwriting, isFalse);
  });

  test('handwriting replaces typed maths', () async {
    final TutorPreferences prefs = await loadWith(<String, Object>{'tutor.typed_math': true});

    expect(prefs.showHandwriting, isFalse);

    await prefs.setHandwrittenMath(true);

    expect(prefs.showHandwriting, isTrue);
    expect(prefs.typedMath, isFalse);
  });

  test('choices are written to storage', () async {
    final TutorPreferences prefs = await loadWith(<String, Object>{});
    await prefs.setGridVisible(true);
    await prefs.setAnimateSteps(false);
    await prefs.setVoiceLanguage('en-KE');
    await prefs.setSpeakReplies(true);

    final SharedPreferences stored = await SharedPreferences.getInstance();

    expect(stored.getBool('tutor.grid_visible'), isTrue);
    expect(stored.getBool('tutor.animate_steps'), isFalse);
    expect(stored.getString('tutor.voice_language'), 'en-KE');
    expect(stored.getBool('tutor.speak_replies'), isTrue);
  });

  test('stored choices are read back on the next load', () async {
    final TutorPreferences first = await loadWith(<String, Object>{});
    await first.setGridVisible(true);
    await first.setAnimateSteps(false);
    await first.setVoiceLanguage('en-KE');
    await first.setSpeakReplies(true);
    await first.setTypedMath(true);

    // Same backing store, fresh instance: what a student sees after a reload.
    final TutorPreferences second = await TutorPreferences.load();

    expect(second.gridVisible, isTrue);
    expect(second.animateSteps, isFalse);
    expect(second.voiceLanguage, 'en-KE');
    expect(second.speakReplies, isTrue);
    expect(second.showHandwriting, isFalse);
  });

  test('reset clears stored choices too', () async {
    final TutorPreferences prefs = await loadWith(<String, Object>{});
    await prefs.setGridVisible(true);
    await prefs.reset();

    final TutorPreferences reloaded = await TutorPreferences.load();

    expect(reloaded.gridVisible, isFalse);
  });

  test('memory-only preferences never touch storage', () async {
    final TutorPreferences prefs = TutorPreferences.memoryOnly();

    await prefs.setGridVisible(true);
    await prefs.setSpeakReplies(true);
    await prefs.reset();

    expect(prefs.gridVisible, isFalse);
    expect(prefs.speakReplies, isFalse);
  });

  test('reset restores every default', () async {
    final TutorPreferences prefs = await loadWith(<String, Object>{});
    await prefs.setGridVisible(true);
    await prefs.setTypedMath(true);
    await prefs.setContextualMemory(false);
    await prefs.setSpeakReplies(true);

    await prefs.reset();

    expect(prefs.handwrittenMath, isTrue);
    expect(prefs.typedMath, isFalse);
    expect(prefs.gridVisible, isFalse);
    expect(prefs.plainWhiteboard, isTrue);
    expect(prefs.animateSteps, isTrue);
    expect(prefs.contextualMemory, isTrue);
    expect(prefs.speakReplies, isFalse);
    expect(prefs.voiceLanguage, 'en-US');
  });

  test('notifies listeners so open screens repaint', () async {
    final TutorPreferences prefs = TutorPreferences.memoryOnly();
    int notifications = 0;
    prefs.addListener(() => notifications++);

    await prefs.setAnimateSteps(false);
    await prefs.setAnimateSteps(false);

    expect(notifications, 1, reason: 'setting the same value again is not a change');
  });
}
