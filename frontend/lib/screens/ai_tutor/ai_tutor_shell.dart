import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class AiTutorShell extends StatefulWidget {
  final Widget child;
  final Function(String)? onToolSelected;

  const AiTutorShell({super.key, required this.child, this.onToolSelected});

  @override
  State<AiTutorShell> createState() => _AiTutorShellState();
}

class _AiTutorShellState extends State<AiTutorShell> {
  bool _presentationsExpanded = true;

  static const _tools = [
    _ToolDef(Icons.show_chart, 'Graph'),
    _ToolDef(Icons.pie_chart, 'Pie Chart'),
    _ToolDef(Icons.bar_chart, 'Bar Chart'),
    _ToolDef(Icons.equalizer, 'Histogram'),
    _ToolDef(Icons.timeline, 'Line Graph'),
    _ToolDef(Icons.change_history, 'Triangle'),
    _ToolDef(Icons.circle, 'Circle'),
    _ToolDef(Icons.crop_square, 'Quadrilateral'),
    _ToolDef(Icons.calculate, 'Equation'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        if (isMobile) {
          return Scaffold(
            body: widget.child,
            backgroundColor: colors.background,
          );
        }

        final currentNav = _navIndexFor(location);

        return Scaffold(
          backgroundColor: colors.background,
          body: Row(
            children: [
              _buildSidebar(colors, currentNav),
              Container(width: 1, color: colors.border),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
    );
  }

  int _navIndexFor(String location) {
    if (location.startsWith('/ai-tutor')) return 1;
    if (location.startsWith('/vault') || location.startsWith('/courses')) return 2;
    if (location.startsWith('/research')) return 3;
    return 0;
  }

  Widget _buildSidebar(ThemeColors colors, int currentNav) {
    return Container(
      width: 200,
      color: const Color(0xFF10111C),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildAppIcon(),
          const SizedBox(height: 24),
          _navItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard', currentNav, colors),
          _navItem(1, Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'ScholarAI', currentNav, colors),
          _navItem(2, Icons.menu_book_outlined, Icons.menu_book_rounded, 'My Learning', currentNav, colors),
          _navItem(3, Icons.science_outlined, Icons.science_rounded, 'Research', currentNav, colors),
          const Spacer(),
          _buildSettingsButton(colors),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAppIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.grid_view_rounded, color: context.colors.textMuted, size: 20),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label, int currentNav, ThemeColors colors) {
    final isActive = currentNav == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: GestureDetector(
        onTap: () {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/ai-tutor');
            case 2:
              context.go('/vault');
            case 3:
              context.go('/research');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primaryDark.withValues(alpha: 0.6)])
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(isActive ? activeIcon : icon, size: 18, color: isActive ? Colors.white : colors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? const Color(0xFFD4B5FF) : colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
  Widget _toolItem(_ToolDef tool, ThemeColors colors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onToolSelected?.call(tool.label.toLowerCase()),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(tool.icon, size: 18, color: const Color(0xFF38D5E8)),
              const SizedBox(width: 12),
              Text(
                tool.label,
                style: TextStyle(fontSize: 13, color: colors.textSecondary.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton(ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => context.go('/settings'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings_outlined, size: 16, color: colors.textMuted),
              const SizedBox(width: 8),
              Text('Settings', style: TextStyle(fontSize: 13, color: colors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolDef {
  final IconData icon;
  final String label;
  const _ToolDef(this.icon, this.label);
}
