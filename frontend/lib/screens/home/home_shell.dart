import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colors.dart';
import 'app_drawer.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/ai-tutor') || location.startsWith('/knowledge-retrieval')) {
      currentIndex = 1;
    } else if (location.startsWith('/courses') ||
        location.startsWith('/vault') ||
        location.startsWith('/assignments') ||
        location.startsWith('/assessments') ||
        location.startsWith('/grades') ||
        location.startsWith('/study-plan')) {
      currentIndex = 2;
    } else if (location.startsWith('/research') ||
        location.startsWith('/writing-studio') ||
        location.startsWith('/malawi-context')) {
      currentIndex = 3;
    } else {
      currentIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= AppBreakpoints.tablet;

        const destinations = [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'ScholarAI',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'My Learning',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science_rounded),
            label: 'Research',
          ),
        ];

        void onNavTap(int index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/ai-tutor');
              break;
            case 2:
              context.go('/vault');
              break;
            case 3:
              context.go('/research');
              break;
          }
        }

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: onNavTap,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: context.colors.surface,
                  leading: const SizedBox(height: 8),
                  trailing: const Expanded(child: SizedBox()),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      selectedIcon: Icon(Icons.auto_awesome_rounded),
                      label: Text('ScholarAI'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book_rounded),
                      label: Text('My Learning'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.science_outlined),
                      selectedIcon: Icon(Icons.science_rounded),
                      label: Text('Research'),
                    ),
                  ],
                ),
                VerticalDivider(width: 1, color: context.colors.border),
                Expanded(child: child),
              ],
            ),
            endDrawer: const AppDrawer(),
          );
        }

        return Scaffold(
          body: child,
          endDrawer: const AppDrawer(),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: context.colors.surfaceElevated,
              border: Border(
                top: BorderSide(color: context.colors.border, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: onNavTap,
                backgroundColor: Colors.transparent,
                elevation: 0,
                height: 72,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: destinations,
              ),
            ),
          ),
        );
      },
    );
  }
}
