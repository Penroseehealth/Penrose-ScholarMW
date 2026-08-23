import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../core/theme/theme_colors.dart';

class SmartNotificationsScreen extends StatefulWidget {
  SmartNotificationsScreen({super.key});

  @override
  State<SmartNotificationsScreen> createState() =>
      _SmartNotificationsScreenState();
}

class _SmartNotificationsScreenState extends State<SmartNotificationsScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;

  List<dynamic> _notifications = [];
  int _totalNotifications = 0;

  bool _prefsLoading = true;
  Map<String, dynamic> _preferences = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifRes = await _api.get('/smart-notifications/');
      final prefsRes =
          await _api.get('/smart-notifications/preferences');

      if (!mounted) return;

      if (notifRes.statusCode == 200) {
        final notifBody = jsonDecode(notifRes.body);
        setState(() {
          _notifications = notifBody['notifications'] ?? [];
          _totalNotifications = notifBody['total'] ?? 0;
        });
      }

      if (prefsRes.statusCode == 200) {
        setState(() {
          _preferences = jsonDecode(prefsRes.body);
        });
      }

      setState(() {
        _loading = false;
        _prefsLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred: $e';
          _loading = false;
          _prefsLoading = false;
        });
      }
    }
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    setState(() {
      _preferences[key] = value;
    });

    try {
      final res = await _api.put(
        '/smart-notifications/preferences',
        body: Map<String, dynamic>.from(_preferences),
      );

      if (res.statusCode != 200 && mounted) {
        setState(() {
          _preferences[key] = !(value as bool);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update preference')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _preferences[key] = !(value as bool);
        });
      }
    }
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return context.colors.error;
      case 'medium':
        return context.colors.warning;
      case 'low':
        return context.colors.success;
      default:
        return context.colors.info;
    }
  }

  IconData _notificationIcon(String? type) {
    switch (type) {
      case 'assessment_reminder':
        return Icons.quiz_outlined;
      case 'study_nudge':
        return Icons.menu_book_outlined;
      case 'resource_alert':
        return Icons.folder_open_outlined;
      case 'weekly_summary':
        return Icons.summarize_outlined;
      case 'ai_insight':
        return Icons.auto_awesome;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 70,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Smart Notifications',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_totalNotifications > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$_totalNotifications new',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Intelligent alerts & study nudges',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Notifications'),
        SizedBox(height: 8),
        _buildNotificationsList(),
        SizedBox(height: 20),
        _buildSectionHeader('Preferences'),
        SizedBox(height: 8),
        _buildPreferencesPanel(),
      ],
    );
  }

  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return _buildEmptyCard('No notifications right now');
    }

    return Column(
      children: _notifications.map((n) => _buildNotificationCard(n)).toList(),
    );
  }

  Widget _buildNotificationCard(dynamic notification) {
    final type = notification['type'] as String?;
    final title = notification['title'] ?? '';
    final message = notification['message'] ?? '';
    final priority = notification['priority'] as String?;
    final link = notification['link'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: link != null ? () {} : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _priorityColor(priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _notificationIcon(type),
                  color: _priorityColor(priority),
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _priorityColor(priority).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (priority ?? 'info').toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _priorityColor(priority),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesPanel() {
    if (_prefsLoading) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            _buildPreferenceToggle(
              key: 'assessment_reminders',
              title: 'Assessment Reminders',
              subtitle: 'Get notified about upcoming tests & assignments',
              icon: Icons.quiz_outlined,
            ),
            Divider(height: 1, indent: 56),
            _buildPreferenceToggle(
              key: 'study_nudges',
              title: 'Study Nudges',
              subtitle: 'AI-powered reminders to keep you on track',
              icon: Icons.menu_book_outlined,
            ),
            Divider(height: 1, indent: 56),
            _buildPreferenceToggle(
              key: 'resource_alerts',
              title: 'Resource Alerts',
              subtitle: 'New materials & library updates',
              icon: Icons.folder_open_outlined,
            ),
            Divider(height: 1, indent: 56),
            _buildPreferenceToggle(
              key: 'weekly_summary',
              title: 'Weekly Summary',
              subtitle: 'End-of-week performance digest',
              icon: Icons.summarize_outlined,
            ),
            Divider(height: 1, indent: 56),
            _buildPreferenceToggle(
              key: 'ai_insights',
              title: 'AI Insights',
              subtitle: 'Personalised learning recommendations',
              icon: Icons.auto_awesome,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceToggle({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final value = _preferences[key] == true;

    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style:
            TextStyle(fontSize: 12, color: context.colors.textSecondary),
      ),
      trailing: Switch(
        value: value,
        onChanged: (newVal) => _updatePreference(key, newVal),
        activeColor: AppColors.primary,
      ),
    );
  }

  // ── Shared Widgets ──────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: context.colors.textPrimary,
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style:
                TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.error),
            SizedBox(height: 12),
            Text(
              _error!,
              style:
                  TextStyle(fontSize: 14, color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
