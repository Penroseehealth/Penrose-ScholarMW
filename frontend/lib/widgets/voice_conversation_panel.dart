import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';
import '../voice/penrose_voice_engine.dart';
import '../voice/voice_session_manager.dart';

/// PIVE Voice Conversation Panel.
///
/// Shows real-time voice session status, transcript, waveform animation,
/// and controls for push-to-talk, hands-free, and continuous modes.
class VoiceConversationPanel extends StatefulWidget {
  final PenroseVoiceEngine engine;
  final VoidCallback? onClose;
  final void Function(String transcript)? onTranscriptSent;

  const VoiceConversationPanel({
    super.key,
    required this.engine,
    this.onClose,
    this.onTranscriptSent,
  });

  @override
  State<VoiceConversationPanel> createState() => _VoiceConversationPanelState();
}

class _VoiceConversationPanelState extends State<VoiceConversationPanel> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    widget.engine.session.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
    if (widget.engine.isListening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    widget.engine.session.removeListener(_onStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.engine.state;
    final session = widget.engine.session;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            const SizedBox(height: 16),
            _buildStateLabel(state),
            const SizedBox(height: 12),
            _buildTranscriptArea(session),
            const SizedBox(height: 16),
            _buildWaveformAnimation(state),
            const SizedBox(height: 20),
            _buildControls(state, session),
            const SizedBox(height: 12),
            _buildModeSelector(session),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: context.colors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildStateLabel(VoiceEngineState state) {
    final labels = {
      VoiceEngineState.idle: 'Ready',
      VoiceEngineState.listening: 'Listening...',
      VoiceEngineState.transcribing: 'Processing...',
      VoiceEngineState.thinking: 'Thinking...',
      VoiceEngineState.generating: 'Generating...',
      VoiceEngineState.speaking: 'Speaking...',
      VoiceEngineState.interrupted: 'Interrupted',
    };

    final colors = {
      VoiceEngineState.idle: context.colors.textMuted,
      VoiceEngineState.listening: AppColors.primary,
      VoiceEngineState.transcribing: Colors.orange,
      VoiceEngineState.thinking: Colors.amber,
      VoiceEngineState.generating: Colors.teal,
      VoiceEngineState.speaking: Colors.green,
      VoiceEngineState.interrupted: context.colors.error,
    };

    return Text(
      labels[state] ?? 'Unknown',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors[state],
      ),
    );
  }

  Widget _buildTranscriptArea(VoiceSessionManager session) {
    final hasTranscript = session.currentTranscript.isNotEmpty;
    final hasAiText = session.currentAiText.isNotEmpty;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasTranscript)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  session.currentTranscript,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (hasAiText)
              Text(
                session.currentAiText,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textPrimary,
                  height: 1.5,
                ),
              ),
            if (!hasTranscript && !hasAiText)
              Text(
                'Start speaking — your voice will be sent automatically when you pause.',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformAnimation(VoiceEngineState state) {
    final isActive = state == VoiceEngineState.listening ||
        state == VoiceEngineState.speaking ||
        state == VoiceEngineState.generating;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isActive ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: state == VoiceEngineState.speaking
                    ? [Colors.green.shade400, Colors.green.shade700]
                    : [AppColors.primary, AppColors.primaryDark],
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: (state == VoiceEngineState.speaking ? Colors.green : AppColors.primary)
                            .withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              _stateIcon(state),
              color: Colors.white,
              size: 36,
            ),
          ),
        );
      },
    );
  }

  IconData _stateIcon(VoiceEngineState state) {
    return switch (state) {
      VoiceEngineState.listening => Icons.mic_rounded,
      VoiceEngineState.transcribing => Icons.sync_rounded,
      VoiceEngineState.thinking => Icons.psychology_rounded,
      VoiceEngineState.generating => Icons.auto_awesome_rounded,
      VoiceEngineState.speaking => Icons.volume_up_rounded,
      VoiceEngineState.interrupted => Icons.pause_circle_rounded,
      VoiceEngineState.idle => Icons.mic_none_rounded,
    };
  }

  Widget _buildControls(VoiceEngineState state, VoiceSessionManager session) {
    final canStopSpeaking = state == VoiceEngineState.speaking;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Stop speaking button
        if (canStopSpeaking)
          _controlButton(
            icon: Icons.stop_rounded,
            color: context.colors.error,
            onTap: () => widget.engine.stopSpeaking(),
          ),
        if (canStopSpeaking) const SizedBox(width: 24),

        // Main mic button
        _controlButton(
          icon: session.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: session.isListening ? context.colors.error : AppColors.primary,
          isLarge: true,
          onTap: () => widget.engine.toggleListening(),
        ),
        const SizedBox(width: 24),

        // Close button
        _controlButton(
          icon: Icons.close_rounded,
          color: context.colors.textSecondary,
          onTap: () {
            widget.engine.stopSpeaking();
            widget.engine.stopListening();
            widget.onClose?.call();
          },
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    final size = isLarge ? 64.0 : 44.0;
    final iconSize = isLarge ? 30.0 : 20.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }

  Widget _buildModeSelector(VoiceSessionManager session) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: VoiceConversationMode.values.map((mode) {
        final labels = {
          VoiceConversationMode.pushToTalk: 'Push to Talk',
          VoiceConversationMode.handsFree: 'Hands Free',
          VoiceConversationMode.continuous: 'Continuous',
        };
        final isSelected = session.mode == mode;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(
              labels[mode] ?? '',
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : context.colors.textSecondary,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: context.colors.surfaceElevated,
            side: BorderSide(
              color: isSelected ? AppColors.primary : context.colors.border,
            ),
            onSelected: (_) => session.setMode(mode),
          ),
        );
      }).toList(),
    );
  }
}
