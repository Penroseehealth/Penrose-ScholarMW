import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                (user['full_name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user['full_name'] ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                (user['role'] ?? 'student').toString().toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildInfoSection([
              _buildInfoRow(Icons.email_outlined, 'Email', user['email'] ?? ''),
              _buildInfoRow(Icons.phone_outlined, 'Phone', user['phone'] ?? 'Not set'),
              _buildInfoRow(Icons.business_outlined, 'Institution', user['institution'] ?? 'Not set'),
              _buildInfoRow(Icons.category_outlined, 'Department', user['department'] ?? 'Not set'),
            ]),
            if (user['role'] == 'student') ...[
              const SizedBox(height: 16),
              _buildInfoSection([
                _buildInfoRow(Icons.badge_outlined, 'Student ID', user['student_id'] ?? 'Not set'),
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
              title: 'Appearance',
              trailing: Switch(
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (v) {},
                activeColor: AppColors.primary,
              ),
            ),
            _buildSettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              trailing: Switch(
                value: true,
                onChanged: (v) {},
                activeColor: AppColors.primary,
              ),
            ),
            _buildSettingsTile(
              icon: Icons.language_outlined,
              title: 'Language',
              trailing: const Text('English', style: TextStyle(color: AppColors.textSecondary)),
            ),
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: 'About',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Penrose ScholarMW',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.school, size: 48, color: AppColors.primary),
                children: const [
                  Text('AI-Powered Academic Intelligence & Learning Platform for Malawi'),
                  SizedBox(height: 16),
                  Text('Learn. Teach. Research. Advance.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      subtitle: Text(value.isEmpty ? 'Not set' : value, style: const TextStyle(fontSize: 15)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }

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
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final api = ApiService();
              final response = await api.post('/auth/change-password', body: {
                'current_password': currentCtrl.text,
                'new_password': newCtrl.text,
              });
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      response.statusCode == 200
                          ? 'Password changed successfully'
                          : jsonDecode(response.body)['detail'] ?? 'Password change failed',
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
