import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/ai-tutor') || location.startsWith('/knowledge-retrieval')) {
      currentIndex = 1;
    } else if (location.startsWith('/research')) {
      currentIndex = 2;
    } else if (location.startsWith('/vault') || location.startsWith('/malawi-context')) {
      currentIndex = 3;
    } else if (location.startsWith('/profile')) {
      currentIndex = 4;
    } else {
      currentIndex = 0;
    }

    return Scaffold(
      body: child,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, size: 32, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.userName.isNotEmpty ? auth.userName : 'ScholarMW',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      auth.userRole.toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _drawerItem(context, Icons.analytics_outlined, 'Analytics', '/analytics'),
              _drawerItem(context, Icons.psychology_outlined, 'Learning Coach', '/learning-coach'),
              _drawerItem(context, Icons.school_outlined, 'Examinations', '/examinations'),
              _drawerItem(context, Icons.edit_note_outlined, 'Writing Studio', '/writing-studio'),
              _drawerItem(context, Icons.history_edu_outlined, 'Malawi Context', '/malawi-context'),
              _drawerItem(context, Icons.record_voice_over_outlined, 'Voice Scholar', '/knowledge-retrieval'),
              _drawerItem(context, Icons.emoji_events_outlined, 'Gamification', '/gamification'),
              _drawerItem(context, Icons.notifications_active_outlined, 'Smart Notifications', '/smart-notifications'),
              _drawerItem(context, Icons.search_outlined, 'Global Search', '/search'),
              _drawerItem(context, Icons.sync_outlined, 'Offline Sync', '/offline-sync'),
              const Divider(),
              _drawerItem(context, Icons.smart_toy_outlined, 'ScholarAI Chat', '/ai-tutor'),
              _drawerItem(context, Icons.science_outlined, 'Research Lab', '/research'),
              _drawerItem(context, Icons.folder_outlined, 'Knowledge Vault', '/vault'),
              if (auth.userRole == 'lecturer') ...[
                const Divider(),
                _drawerItem(context, Icons.quiz_outlined, 'Assessment Studio', '/assessment-studio'),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          Navigator.of(context).pop(); // close drawer if open
          switch (index) {
            case 0:
              context.go(auth.userRole == 'lecturer' ? '/lecturer' : '/student');
              break;
            case 1:
              context.go('/ai-tutor');
              break;
            case 2:
              context.go('/research');
              break;
            case 3:
              context.go('/vault');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Hub',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'ScholarAI',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Research',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: currentIndex == 1
          ? FloatingActionButton(
              onPressed: () => context.go('/knowledge-retrieval'),
              backgroundColor: const Color(0xFF1B5E20),
              tooltip: 'Voice Scholar',
              child: const Icon(Icons.mic, color: Colors.white),
            )
          : null,
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, String path) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final isSelected = currentPath == path;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF1B5E20) : null),
      title: Text(label, style: TextStyle(
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? const Color(0xFF1B5E20) : null,
      )),
      selected: isSelected,
      onTap: () {
        Navigator.of(context).pop();
        context.go(path);
      },
    );
  }
}
