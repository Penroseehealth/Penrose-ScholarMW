import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';
import '../services/api_service.dart';
import '../services/voice_catalog_service.dart';
import '../services/web_speech_service.dart';
import '../voice/tts_audio_player.dart';

class TextToSpeechPlayer extends StatefulWidget {
  const TextToSpeechPlayer({
    super.key,
    required this.text,
    this.voiceId,
    this.apiService,
    this.speechService,
    this.audioPlayer,
  });

  final String text;
  final String? voiceId;
  final ApiService? apiService;
  final WebSpeechService? speechService;
  final TtsAudioPlayer? audioPlayer;

  @override
  State<TextToSpeechPlayer> createState() => _TextToSpeechPlayerState();
}

class _TextToSpeechPlayerState extends State<TextToSpeechPlayer> {
  late final ApiService _api = widget.apiService ?? ApiService();
  late final WebSpeechService _speech = widget.speechService ?? WebSpeechService();
  late final TtsAudioPlayer _audioPlayer = widget.audioPlayer ?? TtsAudioPlayer();

  bool _isPlaying = false;
  bool _isPaused = false;
  double _speed = 1.0;
  double _progress = 0.0;
  Timer? _progressTimer;

  final List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void dispose() {
    _progressTimer?.cancel();
    _speech.cancelSpeech();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _playBtn(),
                const SizedBox(width: 10),
                Expanded(child: _progressBar()),
                const SizedBox(width: 10),
                _speedChip(),
              ],
            ),
          ],
        ),
      );

  Widget _playBtn() => GestureDetector(
        onTap: widget.text.trim().isEmpty ? null : _togglePlay,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: _isPlaying
                ? null
                : const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
            color: _isPlaying ? context.colors.warning : null,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPlaying ? (_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded) : Icons.volume_up_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      );

  Widget _progressBar() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: widget.text.trim().isEmpty ? 0 : _progress,
              backgroundColor: context.colors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.text.trim().isEmpty
                ? 'Nothing to read aloud'
                : (_isPlaying ? 'Listening at ${_speed}x' : 'Tap to listen'),
            style: TextStyle(fontSize: 10, color: context.colors.textMuted),
          ),
        ],
      );

  Widget _speedChip() => GestureDetector(
        onTap: widget.text.trim().isEmpty ? null : _cycleSpeed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.surfaceHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.border),
          ),
          child: Text(
            '${_speed}x',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      );

  Future<void> _togglePlay() async {
    if (widget.text.trim().isEmpty) return;

    if (_isPlaying) {
      _stopPlayback();
      return;
    }

    await _playCurrentText();
  }

  void _cycleSpeed() {
    final idx = _speedOptions.indexOf(_speed);
    setState(() {
      _speed = _speedOptions[(idx + 1) % _speedOptions.length];
    });
  }

  Future<void> _playCurrentText() async {
    final text = widget.text.trim();
    if (text.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _progress = 0.0;
    });
    _startProgressLoop();

    try {
      final response = await _api.post(
        '/voice/tts',
        body: {
          'text': text,
          'speed': _speed,
          'voice_id': (widget.voiceId ?? VoiceCatalogService.defaultVoiceId).trim(),
          'language': 'en',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final base64Audio = payload['audio_base64'] as String? ?? '';
        if (base64Audio.isNotEmpty) {
          await _audioPlayer.playBase64(base64Audio);
          _finishPlayback();
          return;
        }
      }

      if (mounted) {
        await _speech.speak(text, lang: 'en-US');
      }
    } catch (_) {
      if (mounted) {
        await _speech.speak(text, lang: 'en-US');
      }
    } finally {
      if (mounted) {
        _finishPlayback();
      }
    }
  }

  void _startProgressLoop() {
    _progressTimer?.cancel();
    _progressTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_isPlaying || _isPaused) return;
      setState(() {
        _progress = (_progress + 0.03).clamp(0.0, 1.0);
        if (_progress >= 1.0) {
          _progress = 1.0;
          _isPlaying = false;
        }
      });
      if (_isPlaying) {
        _startProgressLoop();
      }
    });
  }

  void _finishPlayback() {
    if (!mounted) return;
    setState(() {
      _progress = 0.0;
      _isPlaying = false;
      _isPaused = false;
    });
    _progressTimer?.cancel();
    _progressTimer = null;
    _speech.cancelSpeech();
    _audioPlayer.stop();
  }

  void _stopPlayback() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _speech.cancelSpeech();
    _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _progress = 0.0;
      });
    }
  }
}
