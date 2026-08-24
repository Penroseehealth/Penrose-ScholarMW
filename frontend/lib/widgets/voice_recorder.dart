import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';

class VoiceRecorder extends StatefulWidget {
  final void Function(String audioPath) onRecordingComplete;
  final VoidCallback? onCancel;

  const VoiceRecorder({
    super.key,
    required this.onRecordingComplete,
    this.onCancel,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isPaused = false;
  bool _hasRecording = false;
  int _seconds = 0;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnim = Tween<double>(begin: 1, end: 1.3).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _seconds = 0;
    });
    _pulseCtrl.repeat(reverse: true);
    _startTimer();
  }

  void _stopRecording() {
    _pulseCtrl.stop();
    setState(() {
      _isRecording = false;
      _hasRecording = true;
    });
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && !_isPaused && mounted) {
        setState(() => _seconds++);
        _startTimer();
      }
    });
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRecording) _buildRecordingUI(),
            if (_hasRecording) _buildPlaybackUI(),
            if (!_isRecording && !_hasRecording) _buildStartUI(),
          ],
        ),
      );

  Widget _buildStartUI() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _circleBtn(Icons.close_rounded, context.colors.textSecondary, widget.onCancel),
          const SizedBox(width: 24),
          GestureDetector(
            onTap: _startRecording,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (ctx, child) => Transform.scale(
                scale: _pulseAnim.value,
                child: child,
              ),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.colors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.error.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 24),
          const SizedBox(width: 40),
        ],
      );

  Widget _buildRecordingUI() => Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (ctx, _) => Container(
              width: 64 * _pulseAnim.value,
              height: 64 * _pulseAnim.value,
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.colors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatTime(_seconds),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Recording...',
            style: TextStyle(fontSize: 12, color: context.colors.error),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleBtn(Icons.close_rounded, context.colors.textSecondary, () {
                setState(() {
                  _isRecording = false;
                  _hasRecording = false;
                  _seconds = 0;
                });
                _pulseCtrl.stop();
                widget.onCancel?.call();
              }),
              const SizedBox(width: 24),
              _circleBtn(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                context.colors.warning,
                () => setState(() => _isPaused = !_isPaused),
              ),
              const SizedBox(width: 24),
              _circleBtn(Icons.stop_rounded, AppColors.primary, _stopRecording),
            ],
          ),
        ],
      );

  Widget _buildPlaybackUI() => Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.successMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: context.colors.success, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'Recording: ${_formatTime(_seconds)}',
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleBtn(Icons.close_rounded, context.colors.textSecondary, () {
                setState(() {
                  _hasRecording = false;
                  _seconds = 0;
                });
              }),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => widget.onRecordingComplete('recording_${_seconds}s'),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _circleBtn(IconData icon, Color color, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      );
}
