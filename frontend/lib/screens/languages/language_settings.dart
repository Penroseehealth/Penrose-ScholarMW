import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class LanguageSettings extends StatefulWidget {
  const LanguageSettings({super.key});

  @override
  State<LanguageSettings> createState() => _LanguageSettingsState();
}

class _LanguageSettingsState extends State<LanguageSettings> {
  bool _dailyReminder = true;
  bool _soundEffects = true;
  bool _autoPlayAudio = false;
  bool _darkMode = true;
  String _difficulty = 'Beginner';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Learning Preferences'),
          const SizedBox(height: 12),
          _buildSettingCard(
            Icons.speed_rounded,
            'Difficulty Level',
            _difficulty,
            const Color(0xFF2196F3),
            trailing: DropdownButton<String>(
              value: _difficulty,
              dropdownColor: context.colors.surface,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
              underline: const SizedBox(),
              items: ['Beginner', 'Intermediate', 'Advanced'].map((d) {
                return DropdownMenuItem(value: d, child: Text(d));
              }).toList(),
              onChanged: (v) => setState(() => _difficulty = v ?? 'Beginner'),
            ),
          ),
          _buildSwitchCard(Icons.record_voice_over_rounded, 'Auto-play Audio',
              'Automatically play pronunciation audio', const Color(0xFF4CAF50), _autoPlayAudio,
              (v) => setState(() => _autoPlayAudio = v)),
          const SizedBox(height: 28),
          _buildSectionHeader('Notifications'),
          const SizedBox(height: 12),
          _buildSwitchCard(Icons.notifications_active_rounded, 'Daily Reminder',
              'Get reminded to practice every day', const Color(0xFFFF9800), _dailyReminder,
              (v) => setState(() => _dailyReminder = v)),
          const SizedBox(height: 28),
          _buildSectionHeader('Appearance'),
          const SizedBox(height: 12),
          _buildSwitchCard(Icons.dark_mode_rounded, 'Dark Mode',
              'Use dark theme', const Color(0xFF9C27B0), _darkMode,
              (v) => setState(() => _darkMode = v)),
          const SizedBox(height: 28),
          _buildSectionHeader('Audio'),
          const SizedBox(height: 12),
          _buildSwitchCard(Icons.volume_up_rounded, 'Sound Effects',
              'Play sounds during exercises', const Color(0xFF607D8B), _soundEffects,
              (v) => setState(() => _soundEffects = v)),
          const SizedBox(height: 28),
          _buildSectionHeader('Data'),
          const SizedBox(height: 12),
          _buildActionCard(Icons.refresh_rounded, 'Reset Progress', 'Clear all learning progress',
              context.colors.error, () {}),
          _buildActionCard(Icons.delete_outline_rounded, 'Clear Cache', 'Remove downloaded content',
              context.colors.textMuted, () {}),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ],
    );
  }

  static Widget _buildSettingCard(IconData icon, String title, String value,
      Color color, {Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  static Widget _buildSwitchCard(IconData icon, String title, String subtitle,
      Color color, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }

  static Widget _buildActionCard(
      IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
