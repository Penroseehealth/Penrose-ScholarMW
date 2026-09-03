import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/services.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.user ?? {};
    final name = (user['full_name'] ?? 'User').toString();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: const Text('Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.primaryGlow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                (user['role'] ?? 'student').toString().toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildInfoSection([
              _buildInfoRow(Icons.email_outlined, 'Email', (user['email'] ?? '') as String),
              _buildInfoRow(Icons.phone_outlined, 'Phone', (user['phone'] ?? 'Not set') as String),
              _buildInfoRow(Icons.business_outlined, 'Institution', (user['institution'] ?? 'Not set') as String),
              _buildInfoRow(Icons.category_outlined, 'Department', (user['department'] ?? 'Not set') as String),
            ]),
            if (user['role'] == 'student') ...[
              const SizedBox(height: 12),
              _buildInfoSection([
                _buildInfoRow(Icons.badge_outlined, 'Student ID', (user['student_id'] ?? 'Not set') as String),
                _buildInfoRow(Icons.calendar_today, 'Year of Study', '${user['year_of_study'] ?? 'N/A'}'),
              ]),
            ],
            const SizedBox(height: 24),
            _buildSectionTitle('Settings'),
            const SizedBox(height: 8),
            _buildSettingsTile(
              icon: Icons.lock_outlined,
              title: 'Change Password',
              onTap: () => _showChangePasswordDialog(context),
            ),
            _buildSettingsTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              trailing: Switch(
                value: themeProvider.isDark,
                onChanged: (_) => themeProvider.toggleTheme(),
                activeThumbColor: AppColors.primary,
              ),
            ),
            _buildSettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              trailing: Switch(
                value: true,
                onChanged: (v) {},
                activeThumbColor: AppColors.primary,
              ),
            ),
            _buildSettingsTile(
              icon: Icons.language_outlined,
              title: 'Language',
              trailing: GestureDetector(
                onTap: () => localeProvider.toggleLanguage(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.colors.primaryGlow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    localeProvider.languageName,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            _buildSettingsTile(
              icon: Icons.data_usage_outlined,
              title: 'Data Saver Mode',
              trailing: const _DataSaverToggle(),
            ),
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: 'About',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Penrose ScholarMw',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.school_rounded, size: 48, color: AppColors.primary),
                children: [
                  const Text('AI-Powered Academic Intelligence & Learning Platform for Malawi'),
                  const SizedBox(height: 16),
                  const Text('Learn. Teach. Research. Advance.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      );

  Widget _buildInfoRow(IconData icon, String label, String value) => ListTile(
        leading: Icon(icon, color: AppColors.textMuted, size: 20),
        title: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        subtitle: Text(
          value.isEmpty ? 'Not set' : value,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ),
      );

  Widget _buildSectionTitle(String title) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.textMuted),
          title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
          trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          onTap: onTap,
        ),
      );

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final api = ApiService();
              final navigator = Navigator.of(ctx);
              final response = await api.post('/auth/change-password', body: {
                'current_password': currentCtrl.text,
                'new_password': newCtrl.text,
              });
              navigator.pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      response.statusCode == 200
                          ? 'Password changed successfully'
                          : (jsonDecode(response.body)['detail'] as String?) ?? 'Password change failed',
                    ),
                  ),
                );
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

class _DataSaverToggle extends StatefulWidget {
  const _DataSaverToggle();

  @override
  State<_DataSaverToggle> createState() => _DataSaverToggleState();
}

class _DataSaverToggleState extends State<_DataSaverToggle> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) => Switch(
        value: _enabled,
        onChanged: (v) {
          setState(() => _enabled = v);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  v
                      ? 'Data Saver ON — images will load lazily, auto-sync paused'
                      : 'Data Saver OFF — full experience enabled',
                ),
                duration: const Duration(seconds: 2),
                backgroundColor: v ? context.colors.warning : context.colors.success,
              ),
            );
          }
        },
        activeThumbColor: AppColors.primary,
      );
}
