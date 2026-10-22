import 'package:flutter/material.dart';

import '../vtc_controller.dart';
import '../vtc_theme.dart';

/// Consent + capability disclosure shown before any recording happens.
///
/// The wording reflects the real backend: this app transcribes and analyses a
/// sample through the configured STT engine, and it does not train a cloned
/// voice profile. It says so rather than implying a trained voice exists.
class VoiceTrainingConsent extends StatelessWidget {
  const VoiceTrainingConsent({super.key, required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0x59130F35),
        border: Border.all(color: VtcPalette.electric.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 19, color: VtcPalette.goldLight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Before you record',
                  style: VtcType.bodyIvory(context).copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your recording is used to analyse and transcribe your voice with '
            'the speech engine configured on this server. The clip is held in '
            'memory for this session only — closing the page discards it, and '
            'you can delete it at any time below.',
            style: VtcType.body(context).copyWith(fontSize: 13.5),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: accepted,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: VtcPalette.gold,
                checkColor: VtcPalette.navyDeep,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(!accepted),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'I consent to my voice being processed for this session.',
                      style: VtcType.bodyIvory(context).copyWith(fontSize: 13.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Record / stop / replay / pause controls plus the upload path.
class VoiceRecorder extends StatelessWidget {
  const VoiceRecorder({
    super.key,
    required this.stage,
    required this.recording,
    required this.consentGiven,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    required this.onReplay,
    required this.onPauseToggle,
    required this.onUpload,
    required this.isPreviewPlaying,
    this.recordError = '',
    this.busy = false,
  });

  final SampleStage stage;
  final bool recording;
  final bool consentGiven;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final VoidCallback onReplay;
  final VoidCallback onPauseToggle;
  final VoidCallback onUpload;
  final bool isPreviewPlaying;
  final String recordError;
  final bool busy;

  bool get _hasClip => stage == SampleStage.captured || stage == SampleStage.transcribing || stage == SampleStage.ready;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (recording)
              _Action(icon: Icons.stop_rounded, label: 'Stop', tone: _Tone.danger, onPressed: onStop)
            else
              _Action(
                icon: Icons.mic_rounded,
                label: 'Record Voice',
                tone: _Tone.gold,
                onPressed: consentGiven && !busy ? onStart : null,
                tooltip: consentGiven ? null : 'Give consent above to enable recording',
              ),
            if (_hasClip) ...[
              _Action(
                icon: isPreviewPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: isPreviewPlaying ? 'Pause' : 'Replay',
                tone: _Tone.neutral,
                onPressed: onPauseToggle,
              ),
              _Action(
                icon: Icons.delete_outline_rounded,
                label: 'Discard',
                tone: _Tone.neutral,
                onPressed: busy ? null : onCancel,
              ),
            ],
            _Action(
              icon: Icons.upload_file_rounded,
              label: 'Upload Recording',
              tone: _Tone.neutral,
              onPressed: busy ? null : onUpload,
            ),
          ],
        ),
        if (recording) ...[const SizedBox(height: 12), _RecordingPulse()],
        if (recordError.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(recordError, style: VtcType.body(context).copyWith(fontSize: 13, color: VtcPalette.danger)),
        ],
      ],
    );
  }
}

enum _Tone { gold, neutral, danger }

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.tone, required this.onPressed, this.tooltip});

  final IconData icon;
  final String label;
  final _Tone tone;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ({LinearGradient? gradient, Color? fill, Color fg, Color? border}) style = switch (tone) {
      _Tone.gold => (gradient: VtcPalette.goldGradient, fill: null, fg: VtcPalette.navyDeep, border: null),
      _Tone.danger => (
          gradient: null,
          fill: const Color(0x33FF8A80),
          fg: VtcPalette.danger,
          border: VtcPalette.danger.withValues(alpha: 0.5),
        ),
      _Tone.neutral => (
          gradient: null,
          fill: const Color(0x26FFFFFF),
          fg: VtcPalette.ivory,
          border: VtcPalette.ivory.withValues(alpha: 0.28),
        ),
    };
    final fg = style.fg;

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: style.gradient,
                color: style.fill,
                border: style.border == null ? null : Border.all(color: style.border!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 9),
                  Text(
                    label,
                    style: VtcType.bodyIvory(context).copyWith(fontSize: 14, color: fg, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final tooltipText = tooltip;
    return tooltipText == null ? button : Tooltip(message: tooltipText, child: button);
  }
}

/// Animated bars shown while the microphone is live.
class _RecordingPulse extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 4,
              height: 14 + (i.isEven ? 10 : 0),
              decoration: BoxDecoration(color: VtcPalette.danger, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        const SizedBox(width: 10),
        Text('Recording…', style: VtcType.body(context).copyWith(fontSize: 13, color: VtcPalette.danger)),
      ],
    );
  }
}

/// Measured facts about the sample plus the real STT result. No score is
/// invented: only byte size, format, source and the returned transcript.
class AudioQualityFeedback extends StatelessWidget {
  const AudioQualityFeedback({super.key, required this.sample});

  final VoiceSample sample;

  @override
  Widget build(BuildContext context) {
    final facts = sample.facts;
    final transcript = sample.transcript ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0x4D0B1330),
        border: Border.all(color: VtcPalette.electric.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18, color: VtcPalette.electricBright),
              const SizedBox(width: 9),
              Text(
                'Sample analysis',
                style: VtcType.bodyIvory(context).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: facts.formatLabel),
              _Chip(label: facts.sizeLabel),
              _Chip(label: facts.source),
              _Chip(
                label: facts.durationSeconds > 0 ? '${facts.durationSeconds.toStringAsFixed(1)}s' : 'duration pending',
              ),
            ],
          ),
          if (transcript.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Transcript', style: VtcType.body(context).copyWith(fontSize: 12, letterSpacing: 1.2)),
            const SizedBox(height: 5),
            Text(transcript, style: VtcType.bodyIvory(context).copyWith(fontSize: 13.5)),
          ],
          if (transcript.isEmpty && sample.transcript != null) ...[
            const SizedBox(height: 12),
            Text(
              'The engine returned no text for this clip. Try a recording with '
              'clearer speech or less background noise.',
              style: VtcType.body(context).copyWith(fontSize: 13),
            ),
          ],
          if (facts.bytes < 12000) ...[
            const SizedBox(height: 10),
            Text(
              'This clip is very short. A longer sample gives the engine more to work with.',
              style: VtcType.body(context).copyWith(fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: VtcPalette.ivory.withValues(alpha: 0.16)),
        ),
        child: Text(label, style: VtcType.body(context).copyWith(fontSize: 12, color: VtcPalette.ivory)),
      );
}

/// Real progress of the sample pipeline. Labels describe what actually runs.
class TrainingProgress extends StatelessWidget {
  const TrainingProgress({super.key, required this.stage});

  final SampleStage stage;

  static const List<SampleStage> _steps = [
    SampleStage.empty,
    SampleStage.recording,
    SampleStage.captured,
    SampleStage.transcribing,
    SampleStage.ready,
  ];

  String get _label {
    switch (stage) {
      case SampleStage.empty:
        return 'Ready to record';
      case SampleStage.recording:
        return 'Recording…';
      case SampleStage.captured:
        return 'Processing recording…';
      case SampleStage.transcribing:
        return 'Transcribing with the speech engine…';
      case SampleStage.ready:
        return 'Voice sample ready';
      case SampleStage.failed:
        return 'Could not process the sample';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = stage == SampleStage.failed ? 0 : _steps.indexOf(stage).clamp(0, _steps.length - 1);
    final failed = stage == SampleStage.failed;
    final fraction = (_steps.length == 1) ? 0.0 : (currentIndex / (_steps.length - 1)).clamp(0.0, 1.0);

    return Semantics(
      liveRegion: true,
      label: _label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                failed
                    ? Icons.error_outline_rounded
                    : stage == SampleStage.ready
                        ? Icons.check_circle_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: failed
                    ? VtcPalette.danger
                    : stage == SampleStage.ready
                        ? VtcPalette.success
                        : VtcPalette.ivoryDim,
              ),
              const SizedBox(width: 8),
              Text(
                _label,
                style: VtcType.body(
                  context,
                ).copyWith(fontSize: 13.5, color: failed ? VtcPalette.danger : VtcPalette.ivoryDim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 320),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation<Color>(failed ? VtcPalette.danger : VtcPalette.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Distinguishes standard engine voices from a user's own trained voice, and
/// reports honestly when no trained profile exists.
class VoiceTrainingStatus extends StatelessWidget {
  const VoiceTrainingStatus({
    super.key,
    required this.ttsConfigured,
    required this.sttConfigured,
    required this.ttsProvider,
    required this.ttsModel,
    required this.sttProvider,
    required this.sttModel,
    required this.cloningAvailable,
    this.cloneProvider = '',
  });

  final bool ttsConfigured;
  final bool sttConfigured;
  final String ttsProvider;
  final String ttsModel;
  final String sttProvider;
  final String sttModel;
  final bool cloningAvailable;

  /// The configured cloning provider, used only to explain an outage. Empty
  /// means nothing is configured at all, which is a different problem.
  final String cloneProvider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CapabilityRow(
          label: 'Standard voices (TTS)',
          available: ttsConfigured,
          detail: ttsConfigured ? '$ttsProvider · $ttsModel' : 'Not configured on the backend',
        ),
        const SizedBox(height: 10),
        _CapabilityRow(
          label: 'Speech-to-text analysis',
          available: sttConfigured,
          detail: sttConfigured ? '$sttProvider · $sttModel' : 'Not configured on the backend',
        ),
        const SizedBox(height: 10),
        // Honest in both directions: a real provider is named when one is
        // configured, and the reason is stated plainly when it is not, whether
        // that is a missing endpoint or a local sidecar that is not running.
        _CapabilityRow(
          label: 'Your trained voice',
          available: cloningAvailable,
          detail: cloningAvailable
              ? cloneProvider.isEmpty
                  ? 'Voice profile available'
                  : 'Trained locally with $cloneProvider'
              : cloneProvider.isEmpty
                  ? 'No voice-cloning provider is configured on the backend, so no '
                      'profile can be created.'
                  : '$cloneProvider is configured but not answering. Start the local '
                      'voice service and reload.',
        ),
      ],
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.label, required this.available, required this.detail});

  final String label;
  final bool available;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final color = available ? VtcPalette.success : VtcPalette.ivory.withValues(alpha: 0.5);
    return Semantics(
      label: '$label: ${available ? 'available' : 'unavailable'}. $detail',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.045),
            border: Border.all(
              color: available ? VtcPalette.success.withValues(alpha: 0.35) : VtcPalette.ivory.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                available ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                size: 17,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: VtcType.bodyIvory(context).copyWith(fontSize: 13.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (label == 'Your trained voice') ...[
                          const SizedBox(width: 8),
                          _Badge(
                            text: available ? 'TRAINED' : 'NOT TRAINED',
                            color: available ? VtcPalette.gold : VtcPalette.ivoryDim,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(detail, style: VtcType.body(context).copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          color: color.withValues(alpha: 0.12),
        ),
        child: Text(
          text,
          style: VtcType.body(context)
              .copyWith(fontSize: 9.5, letterSpacing: 1, color: color, fontWeight: FontWeight.w600),
        ),
      );
}
