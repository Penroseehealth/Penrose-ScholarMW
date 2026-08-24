import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'voice_clone_manager.dart';
import '../core/theme/theme_colors.dart';

class VoiceTrainingCenter extends StatelessWidget {
  final String selectedVoiceId;
  final Function(String) onVoiceSelected;
  final double playbackSpeed;
  final Function(double) onSpeedChanged;
  final bool autoRead;
  final Function(bool) onAutoReadChanged;

  const VoiceTrainingCenter({
    super.key,
    required this.selectedVoiceId,
    required this.onVoiceSelected,
    this.playbackSpeed = 1.0,
    required this.onSpeedChanged,
    this.autoRead = false,
    required this.onAutoReadChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Divider(color: context.colors.border, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Default Voice'),
                    const SizedBox(height: 8),
                    _buildVoicePreview(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('Playback Speed'),
                    const SizedBox(height: 8),
                    _buildSpeedSelector(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('Auto-Read'),
                    const SizedBox(height: 8),
                    _buildAutoReadToggle(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('TTS Language'),
                    const SizedBox(height: 8),
                    _buildLanguageSelector(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Voice Cloning'),
                    const SizedBox(height: 8),
                    _buildCloneSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.record_voice_over_rounded, color: AppColors.primary, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Training Center',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Manage your voice settings',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted.withValues(alpha: 0.8),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildVoicePreview() {
    final voices = {
      'en-us-academic-male-1': 'Academic Male 1',
      'en-us-academic-male-2': 'Academic Male 2',
      'en-us-academic-male-3': 'Academic Male 3',
      'en-us-academic-female-1': 'Academic Female 1',
      'en-us-academic-female-2': 'Academic Female 2',
      'en-us-academic-female-3': 'Academic Female 3',
      'en-us-calm-tutor': 'Calm Tutor',
      'en-us-energetic-tutor': 'Energetic Tutor',
      'en-us-professional-narrator': 'Professional Narrator',
      'en-us-friendly-assistant': 'Friendly Assistant',
      'zh-academic-female-1': 'Chinese Female 1',
      'zh-academic-male-1': 'Chinese Male 1',
      'ar-academic-female-1': 'Arabic Female 1',
      'ar-academic-male-1': 'Arabic Male 1',
    };
    final name = voices[selectedVoiceId] ?? selectedVoiceId;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.volume_up_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildSpeedSelector() {
    final speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: speeds.map((s) {
        final isSelected = s == playbackSpeed;
        return GestureDetector(
          onTap: () => onSpeedChanged(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              '${s}x',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAutoReadToggle() {
    return GestureDetector(
      onTap: () => onAutoReadChanged(!autoRead),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              autoRead ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              size: 18,
              color: autoRead ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Auto-read AI answers',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
            Switch(
              value: autoRead,
              onChanged: onAutoReadChanged,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.language_rounded, size: 18, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Auto Detect',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildCloneSection(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => const VoiceCloneManager(),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.fingerprint_rounded, size: 18, color: context.colors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage My Custom Voice',
                    style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
                  ),
                  Text(
                    'Record, upload, and manage cloned voices',
                    style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }
}
