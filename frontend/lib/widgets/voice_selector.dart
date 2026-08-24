import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';

class VoiceSelector extends StatefulWidget {
  final String? selectedVoiceId;
  final void Function(String voiceId) onVoiceSelected;

  const VoiceSelector({
    super.key,
    this.selectedVoiceId,
    required this.onVoiceSelected,
  });

  @override
  State<VoiceSelector> createState() => _VoiceSelectorState();
}

class _VoiceSelectorState extends State<VoiceSelector> {
  final List<Map<String, String>> _voices = [
    {'id': 'en-us-academic-male-1', 'name': 'Academic Male 1', 'desc': 'Clear, professional', 'lang': 'en'},
    {'id': 'en-us-academic-male-2', 'name': 'Academic Male 2', 'desc': 'Warm, engaging', 'lang': 'en'},
    {'id': 'en-us-academic-male-3', 'name': 'Academic Male 3', 'desc': 'Deep, authoritative', 'lang': 'en'},
    {'id': 'en-us-academic-female-1', 'name': 'Academic Female 1', 'desc': 'Clear, articulate', 'lang': 'en'},
    {'id': 'en-us-academic-female-2', 'name': 'Academic Female 2', 'desc': 'Friendly tutor', 'lang': 'en'},
    {'id': 'en-us-academic-female-3', 'name': 'Academic Female 3', 'desc': 'Professional narrator', 'lang': 'en'},
    {'id': 'en-us-calm-tutor', 'name': 'Calm Tutor', 'desc': 'Slow, clear pace', 'lang': 'en'},
    {'id': 'en-us-energetic-tutor', 'name': 'Energetic Tutor', 'desc': 'Enthusiastic', 'lang': 'en'},
    {'id': 'en-us-professional-narrator', 'name': 'Professional Narrator', 'desc': 'Formal narration', 'lang': 'en'},
    {'id': 'en-us-friendly-assistant', 'name': 'Friendly Assistant', 'desc': 'Conversational', 'lang': 'en'},
    {'id': 'zh-academic-female-1', 'name': 'Chinese Female 1', 'desc': 'Mandarin academic', 'lang': 'zh'},
    {'id': 'zh-academic-male-1', 'name': 'Chinese Male 1', 'desc': 'Mandarin professional', 'lang': 'zh'},
    {'id': 'ar-academic-female-1', 'name': 'Arabic Female 1', 'desc': 'Arabic academic', 'lang': 'ar'},
    {'id': 'ar-academic-male-1', 'name': 'Arabic Male 1', 'desc': 'Arabic professional', 'lang': 'ar'},
  ];

  String? _previewing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Voice Library',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your preferred AI voice',
                style: TextStyle(fontSize: 13, color: context.colors.textMuted),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _voices.length,
                  itemBuilder: (ctx, i) => _voiceCard(_voices[i]),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _voiceCard(Map<String, String> voice) {
    final isSelected = voice['id'] == widget.selectedVoiceId;
    final isPreviewing = voice['id'] == _previewing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? AppColors.primaryMuted.withValues(alpha: 0.3) : context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onVoiceSelected(voice['id']!),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : context.colors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : context.colors.surfaceHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    voice['lang'] == 'zh'
                        ? Icons.language_rounded
                        : voice['lang'] == 'ar'
                            ? Icons.translate_rounded
                            : Icons.record_voice_over_rounded,
                    size: 18,
                    color: isSelected ? AppColors.primary : context.colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voice['name']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        voice['desc']!,
                        style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _previewing = voice['id']);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _previewing = null);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPreviewing ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                      size: 16,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
