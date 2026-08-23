import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../core/theme/theme_colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final StemService _stemService = StemService();
  bool _loading = true;
  bool _saving = false;

  bool _assessmentReminders = true;
  bool _studyNudges = true;
  bool _resourceAlerts = true;
  bool _weeklySummary = true;
  bool _aiInsights = true;
  TimeOfDay _quietStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await _stemService.getNotificationPreferences();
      if (mounted && prefs.isNotEmpty) {
        setState(() {
          _assessmentReminders = prefs['assessment_reminders'] ?? true;
          _studyNudges = prefs['study_nudges'] ?? true;
          _resourceAlerts = prefs['resource_alerts'] ?? true;
          _weeklySummary = prefs['weekly_summary'] ?? true;
          _aiInsights = prefs['ai_insights'] ?? true;
          if (prefs['quiet_start'] != null) {
            _quietStart = TimeOfDay(
              hour: prefs['quiet_start_hour'] ?? 22,
              minute: prefs['quiet_start_minute'] ?? 0,
            );
          }
          if (prefs['quiet_end'] != null) {
            _quietEnd = TimeOfDay(
              hour: prefs['quiet_end_hour'] ?? 7,
              minute: prefs['quiet_end_minute'] ?? 0,
            );
          }
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _savePreferences() async {
    setState(() => _saving = true);
    try {
      await _stemService.updateNotificationPreferences({
        'assessment_reminders': _assessmentReminders,
        'study_nudges': _studyNudges,
        'resource_alerts': _resourceAlerts,
        'weekly_summary': _weeklySummary,
        'ai_insights': _aiInsights,
        'quiet_start_hour': _quietStart.hour,
        'quiet_start_minute': _quietStart.minute,
        'quiet_end_hour': _quietEnd.hour,
        'quiet_end_minute': _quietEnd.minute,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings saved'),
            backgroundColor: context.colors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietStart : _quietEnd,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: context.colors.surfaceElevated,
              hourMinuteColor: context.colors.surfaceHighest,
              dialBackgroundColor: context.colors.surface,
              dialHandColor: AppColors.primary,
              dialTextColor: context.colors.textPrimary,
              entryModeIconColor: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietStart = picked;
        } else {
          _quietEnd = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colors.textSecondary),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          'Notification Settings',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _savePreferences,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    children: [
                      _buildToggle(
                        icon: Icons.quiz_rounded,
                        title: 'Assessment Reminders',
                        subtitle: 'Get notified about upcoming assessments',
                        value: _assessmentReminders,
                        onChanged: (v) => setState(() => _assessmentReminders = v),
                      ),
                      Divider(height: 1, color: context.colors.border),
                      _buildToggle(
                        icon: Icons.psychology_rounded,
                        title: 'Study Nudges',
                        subtitle: 'Reminders to continue studying',
                        value: _studyNudges,
                        onChanged: (v) => setState(() => _studyNudges = v),
                      ),
                      Divider(height: 1, color: context.colors.border),
                      _buildToggle(
                        icon: Icons.menu_book_rounded,
                        title: 'Resource Alerts',
                        subtitle: 'New learning materials available',
                        value: _resourceAlerts,
                        onChanged: (v) => setState(() => _resourceAlerts = v),
                      ),
                      Divider(height: 1, color: context.colors.border),
                      _buildToggle(
                        icon: Icons.summarize_rounded,
                        title: 'Weekly Summary',
                        subtitle: 'Your weekly progress digest',
                        value: _weeklySummary,
                        onChanged: (v) => setState(() => _weeklySummary = v),
                      ),
                      Divider(height: 1, color: context.colors.border),
                      _buildToggle(
                        icon: Icons.auto_awesome_rounded,
                        title: 'AI Insights',
                        subtitle: 'Personalized learning recommendations',
                        value: _aiInsights,
                        onChanged: (v) => setState(() => _aiInsights = v),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Quiet Hours',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          'No notifications during these hours',
                          style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                        ),
                      ),
                      Divider(height: 1, color: context.colors.border),
                      ListTile(
                        leading: Icon(Icons.nightlight_round, color: context.colors.textMuted, size: 22),
                        title: Text('Start', style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
                        trailing: Text(
                          _formatTime(_quietStart),
                          style: TextStyle(color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        onTap: () => _pickTime(true),
                      ),
                      Divider(height: 1, color: context.colors.border),
                      ListTile(
                        leading: Icon(Icons.wb_sunny_rounded, color: context.colors.textMuted, size: 22),
                        title: Text('End', style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
                        trailing: Text(
                          _formatTime(_quietEnd),
                          style: TextStyle(color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        onTap: () => _pickTime(false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: value ? AppColors.primary : context.colors.textMuted, size: 22),
      title: Text(title, style: TextStyle(color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      inactiveTrackColor: context.colors.surfaceHighest,
    );
  }
}
