import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// A narration voice offered for tutor playback, identified by accent+gender.
class TutorVoice {
  final String id;
  final String label;
  final String accent;
  final String gender;
  final String locale;
  final String description;
  final String previewText;

  const TutorVoice({
    required this.id,
    required this.label,
    required this.accent,
    required this.gender,
    required this.locale,
    required this.description,
    required this.previewText,
  });

  factory TutorVoice.fromJson(Map<String, dynamic> json) => TutorVoice(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        accent: json['accent'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        locale: json['locale'] as String? ?? 'en-GB',
        description: json['description'] as String? ?? '',
        previewText: json['preview_text'] as String? ?? '',
      );

  bool get isMale => gender == 'male';
}

/// Loads the accent/gender voice catalog from the backend and remembers the
/// student's choice. Falls back to a built-in catalog when the API is
/// unreachable so the picker still works offline.
class VoiceCatalogService {
  VoiceCatalogService({ApiService? api}) : _api = api ?? ApiService();

  static const String defaultVoiceId = 'en-gb-female';
  static const String voicePrefsKey = 'penrose.tutor.voice_id';
  static const String speedPrefsKey = 'penrose.tutor.speech_speed';

  static const List<String> accents = <String>['American', 'British', 'Indian'];
  static const List<String> genders = <String>['male', 'female'];

  static const Map<String, String> _accentPrefixes = <String, String>{
    'american': 'en-us',
    'british': 'en-gb',
    'indian': 'en-in',
  };

  static const List<TutorVoice> _offlineCatalog = <TutorVoice>[
    TutorVoice(
      id: 'en-us-male',
      label: 'American Male',
      accent: 'American',
      gender: 'male',
      locale: 'en-US',
      description: 'General American, steady and clear',
      previewText: _offlinePreview,
    ),
    TutorVoice(
      id: 'en-us-female',
      label: 'American Female',
      accent: 'American',
      gender: 'female',
      locale: 'en-US',
      description: 'General American, warm and articulate',
      previewText: _offlinePreview,
    ),
    TutorVoice(
      id: 'en-gb-male',
      label: 'British Male',
      accent: 'British',
      gender: 'male',
      locale: 'en-GB',
      description: 'Received pronunciation, measured and formal',
      previewText: _offlinePreview,
    ),
    TutorVoice(
      id: 'en-gb-female',
      label: 'British Female',
      accent: 'British',
      gender: 'female',
      locale: 'en-GB',
      description: 'Received pronunciation, calm and encouraging',
      previewText: _offlinePreview,
    ),
    TutorVoice(
      id: 'en-in-male',
      label: 'Indian Male',
      accent: 'Indian',
      gender: 'male',
      locale: 'en-IN',
      description: 'Indian English, direct and confident',
      previewText: _offlinePreview,
    ),
    TutorVoice(
      id: 'en-in-female',
      label: 'Indian Female',
      accent: 'Indian',
      gender: 'female',
      locale: 'en-IN',
      description: 'Indian English, friendly and precise',
      previewText: _offlinePreview,
    ),
  ];

  static const String _offlinePreview = "Let's work through this together, one clear step at a time.";

  final ApiService _api;

  List<TutorVoice> voices = List<TutorVoice>.of(_offlineCatalog);
  bool loadedFromApi = false;

  /// Stable id for an accent+gender pair, matching the backend catalog ids.
  static String idFor(String accent, String gender) {
    final prefix = _accentPrefixes[accent.toLowerCase()] ?? 'en-gb';
    return '$prefix-$gender';
  }

  Future<void> load() async {
    try {
      final response = await _api.get('/voice/voices');
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = (data['voices'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TutorVoice.fromJson)
          .where((v) => v.id.isNotEmpty)
          .toList();
      if (parsed.isEmpty) return;
      voices = parsed;
      loadedFromApi = true;
    } catch (_) {
      // Keep the offline catalog; the picker must never be empty.
    }
  }

  TutorVoice? byId(String id) {
    for (final voice in voices) {
      if (voice.id == id) return voice;
    }
    return null;
  }

  TutorVoice forAccentGender(String accent, String gender) => byId(idFor(accent, gender)) ?? voices.first;

  TutorVoice voiceForId(String? id) => byId(id ?? defaultVoiceId) ?? byId(defaultVoiceId) ?? voices.first;

  static Future<String> loadPreferredVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(voicePrefsKey) ?? defaultVoiceId;
  }

  static Future<void> savePreferredVoiceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(voicePrefsKey, id);
  }

  static Future<double> loadPreferredSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(speedPrefsKey) ?? 1.0;
  }

  static Future<void> savePreferredSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(speedPrefsKey, speed);
  }
}
