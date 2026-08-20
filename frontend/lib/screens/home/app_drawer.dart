import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildProfileHeader(context, auth),
                  const SizedBox(height: 20),
                  _buildSectionHeader('ACADEMIC'),
                  _buildDrawerItem(context, Icons.dashboard_rounded, 'Dashboard', '/', currentPath),
                  _buildDrawerItem(context, Icons.school_rounded, 'STEM Intelligence', '/stem', currentPath),
                  _buildDrawerItem(context, Icons.account_tree_rounded, 'Knowledge Graph', '/stem-knowledge-graph', currentPath),
                  _buildDrawerItem(context, Icons.functions_rounded, 'Formula Centre', '/stem-formula-centre', currentPath),
                  _buildDrawerItem(context, Icons.science_rounded, 'STEM Labs', '/stem-labs', currentPath),
                  _buildDrawerItem(context, Icons.psychology_rounded, 'STEM Tutor', '/stem-tutor', currentPath),
                  _buildDrawerItem(context, Icons.trending_up_rounded, 'My Mastery', '/stem-mastery', currentPath),
                  _buildDrawerItem(context, Icons.work_rounded, 'Career Explorer', '/stem-careers', currentPath),
                  _buildDrawerItem(context, Icons.analytics_rounded, 'STEM Analytics', '/stem-analytics', currentPath),
                  _buildDrawerItem(context, Icons.flag_rounded, 'Malawi STEM', '/stem-malawi', currentPath),
                  _buildDrawerItem(context, Icons.style_rounded, 'Revision Tools', '/stem-revision', currentPath),
                  _buildDrawerItem(context, Icons.emoji_events_rounded, 'Achievements', '/stem-gamification', currentPath),
                  _buildDrawerItem(context, Icons.group_rounded, 'Study Groups', '/stem-groups', currentPath),
                  _buildDrawerItem(context, Icons.calendar_today_rounded, 'Classes', '/classes', currentPath),
                  _buildDrawerItem(context, Icons.assignment_rounded, 'Assignments', '/assignments', currentPath),
                  _buildDrawerItem(context, Icons.quiz_rounded, 'Assessments', '/assessments', currentPath),
                  _buildDrawerItem(context, Icons.bar_chart_rounded, 'Grades', '/grades', currentPath),
                  _buildDrawerItem(context, Icons.event_rounded, 'Calendar', '/calendar', currentPath),
                  _buildDrawerItem(context, Icons.notifications_rounded, 'Notifications', '/smart-notifications', currentPath, badge: 3),
                  _buildDrawerItem(context, Icons.chat_bubble_outline_rounded, 'Messages', '/messages', currentPath),
                  _buildDrawerItem(context, Icons.forum_rounded, 'Q&A Forum', '/forum', currentPath),
                  _buildDrawerItem(context, Icons.campaign_rounded, 'Announcements', '/announcements', currentPath),
                  const SizedBox(height: 12),
                  _buildDivider(),
                  const SizedBox(height: 12),
                  _buildSectionHeader('TOOLS'),
                  _buildDrawerItem(context, Icons.edit_note_rounded, 'Notes', '/notes', currentPath),
                  _buildDrawerItem(context, Icons.menu_book_rounded, 'Books & Materials', '/vault', currentPath),
                  _buildDrawerItem(context, Icons.download_rounded, 'Downloads', '/offline-sync', currentPath),
                  _buildDrawerItem(context, Icons.mic_rounded, 'Voice Tutor', '/knowledge-retrieval', currentPath),
                  _buildDrawerItem(context, Icons.analytics_rounded, 'Analytics Export', '/analytics-export', currentPath),
                  _buildDrawerItem(context, Icons.admin_panel_settings_rounded, 'Content Manager', '/content-cms', currentPath),
                  const SizedBox(height: 12),
                  _buildDivider(),
                  const SizedBox(height: 12),
                  _buildSectionHeader('ACCOUNT'),
                  _buildDrawerItem(context, Icons.person_rounded, 'Profile', '/profile', currentPath),
                  _buildDrawerItem(context, Icons.notifications_active_rounded, 'Notification Settings', '/notification-settings', currentPath),
                  _buildDrawerItem(context, Icons.settings_rounded, 'Settings', '/settings', currentPath),
                  _buildDrawerItem(context, Icons.help_rounded, 'Help & Support', '/help', currentPath),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildLogoutButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AuthProvider auth) {
    final name = auth.userName.isNotEmpty ? auth.userName : 'ScholarMW Student';
    final firstName = name.split(' ').first;
    final lastName = name.split(' ').length > 1 ? name.split(' ').last : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceElevated, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$firstName$lastName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                    auth.user?['department'] ?? 'Computer Science',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGlow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    auth.userRole.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, AppColors.border, Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String label,
    String path,
    String currentPath, {
    int? badge,
  }) {
    final isSelected = currentPath == path;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? AppColors.primaryGlow : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).pop();
            context.go(path);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.errorMuted,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showLogoutDialog(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                SizedBox(width: 8),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('LOG OUT?'),
        content: const Text('Are you sure you want to sign out of Penrose ScholarMW?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
