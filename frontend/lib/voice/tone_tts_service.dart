import 'dart:convert';

import '../services/api_service.dart';
import 'tts_audio_player.dart';

/// Tone-specific text-to-speech for the Chinese Tone Lab.
///
/// Uses the backend TTS engine (ElevenLabs / OpenAI) which pronounces each
/// Mandarin syllable with its correct tone — unlike browser speech synthesis,
/// which tends to flatten or ignore tone marks on isolated syllables.
class ToneTtsService {
  final ApiService _api;
  final TtsAudioPlayer _audioPlayer;
  bool _checkedAvailability = false;
  bool _serverAvailable = false;

  ToneTtsService({ApiService? api, TtsAudioPlayer? audioPlayer})
      : _api = api ?? ApiService(),
        _audioPlayer = audioPlayer ?? TtsAudioPlayer();

  bool get isServerAvailable => _serverAvailable;

  /// Check once whether the backend TTS engine is available.
  Future<void> ensureAvailable() async {
    if (_checkedAvailability) return;
    _checkedAvailability = true;
    try {
      final response = await _api.get('/voice/health');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _serverAvailable = data['tts_available'] == true;
      }
    } catch (_) {
      _serverAvailable = false;
    }
  }

  /// Speak a Chinese character/syllable with tone differentiation via the
  /// server TTS engine. Returns `true` if real audio was played.
  Future<bool> speakChar(String text) async {
    await ensureAvailable();
    if (_serverAvailable && _audioPlayer.isSupported) {
      try {
        final response = await _api.post(
          '/voice/tts',
          body: {'text': text, 'speed': 1.0, 'language': 'zh'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final audio = data['audio_base64'] as String?;
          if (audio != null && audio.isNotEmpty) {
            await _audioPlayer.playBase64(audio);
            return true;
          }
        }
      } catch (_) {
        // fall through to no-op
      }
    }
    return false;
  }

  void stop() {
    _audioPlayer.stop();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
