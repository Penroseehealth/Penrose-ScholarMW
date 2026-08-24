import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';

class TextToSpeechPlayer extends StatefulWidget {
  final String text;
  final String? voiceId;

  const TextToSpeechPlayer({
    super.key,
    required this.text,
    this.voiceId,
  });

  @override
  State<TextToSpeechPlayer> createState() => _TextToSpeechPlayerState();
}

class _TextToSpeechPlayerState extends State<TextToSpeechPlayer> {
  bool _isPlaying = false;
  bool _isPaused = false;
  double _speed = 1.0;
  double _progress = 0.0;

  final List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return Container(
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
  }

  Widget _playBtn() {
    return GestureDetector(
      onTap: _togglePlay,
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
          _isPlaying
              ? (_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded)
              : Icons.volume_up_rounded,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _progressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: context.colors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _isPlaying ? 'Listening at ${_speed}x' : 'Tap to listen',
          style: TextStyle(fontSize: 10, color: context.colors.textMuted),
        ),
      ],
    );
  }

  Widget _speedChip() {
    return GestureDetector(
      onTap: _cycleSpeed,
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
  }

  void _togglePlay() {
    setState(() {
      if (_isPlaying) {
        _isPlaying = false;
        _isPaused = false;
      } else {
        _isPlaying = true;
        _isPaused = false;
        _simulateProgress();
      }
    });
  }

  void _cycleSpeed() {
    final idx = _speedOptions.indexOf(_speed);
    setState(() {
      _speed = _speedOptions[(idx + 1) % _speedOptions.length];
    });
  }

  void _simulateProgress() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isPlaying && !_isPaused && mounted) {
        setState(() {
          _progress += 0.005 * _speed;
          if (_progress >= 1.0) {
            _progress = 0;
            _isPlaying = false;
          }
        });
        _simulateProgress();
      }
    });
  }
}
