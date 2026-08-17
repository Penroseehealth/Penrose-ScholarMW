import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../providers/auth_provider.dart';

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _points;
  List<dynamic> _achievements = [];
  List<dynamic> _leaderboard = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pointsRes = await _api.get('/api/v1/gamification/points');
      final achieveRes = await _api.get('/api/v1/gamification/achievements');
      final leaderRes = await _api.get('/api/v1/gamification/leaderboard');

      if (!mounted) return;

      if (pointsRes.statusCode == 200 &&
          achieveRes.statusCode == 200 &&
          leaderRes.statusCode == 200) {
        setState(() {
          _points = jsonDecode(pointsRes.body);
          _achievements = jsonDecode(achieveRes.body);
          _leaderboard = jsonDecode(leaderRes.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load gamification data';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 80,
              pinned: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: AppColors.primary,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    tabs: const [
                      Tab(text: 'Points'),
                      Tab(text: 'Badges'),
                      Tab(text: 'Leaderboard'),
                    ],
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
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
                          const Text(
                            'Gamification',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track your progress, achievements & rank',
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
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildPointsTab(),
          _buildAchievementsTab(),
          _buildLeaderboardTab(),
        ],
      ),
    );
  }

  // ── Points Tab ──────────────────────────────────────────

  Widget _buildPointsTab() {
    final totalEarned = _points?['total_earned'] ?? 0;
    final level = _points?['level'] ?? 1;
    final streakDays = _points?['streak_days'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildPointsStatCard(
                label: 'Level',
                value: '$level',
                icon: Icons.leaderboard_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPointsStatCard(
                label: 'Total Points',
                value: '$totalEarned',
                icon: Icons.star_outline,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPointsStatCard(
                label: 'Streak',
                value: '$streakDays days',
                icon: Icons.local_fire_department_outlined,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Level Progress'),
        const SizedBox(height: 8),
        _buildLevelProgressCard(level),
        const SizedBox(height: 20),
        _buildSectionHeader('Activity Summary'),
        const SizedBox(height: 8),
        _buildActivitySummary(),
      ],
    );
  }

  Widget _buildPointsStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelProgressCard(int level) {
    final nextLevelPoints = (level + 1) * 100;
    final currentPoints = _points?['total_earned'] ?? 0;
    final progress =
        nextLevelPoints > 0 ? (currentPoints / nextLevelPoints).clamp(0.0, 1.0) : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Level $level',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$currentPoints / $nextLevelPoints pts',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                minHeight: 10,
                backgroundColor: AppColors.divider,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${((1 - progress) * nextLevelPoints).toInt()} points to Level ${level + 1}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySummary() {
    final lastActivity = _points?['last_activity_date'] ?? 'N/A';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.info, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last Activity',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastActivity.toString(),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Achievements Tab ────────────────────────────────────

  Widget _buildAchievementsTab() {
    if (_achievements.isEmpty) {
      return _buildEmptyState('No achievements available yet');
    }

    final earned = _achievements.where((a) => a['earned'] == true).toList();
    final locked = _achievements.where((a) => a['earned'] != true).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Earned (${earned.length})'),
        const SizedBox(height: 8),
        if (earned.isEmpty)
          _buildEmptyCard('No badges earned yet. Keep learning!')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: earned.length,
            itemBuilder: (context, index) => _buildAchievementBadge(earned[index]),
          ),
        const SizedBox(height: 20),
        _buildSectionHeader('Locked (${locked.length})'),
        const SizedBox(height: 8),
        if (locked.isEmpty)
          _buildEmptyCard('All achievements unlocked!')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: locked.length,
            itemBuilder: (context, index) =>
                _buildAchievementBadge(locked[index]),
          ),
      ],
    );
  }

  Widget _buildAchievementBadge(dynamic achievement) {
    final isEarned = achievement['earned'] == true;
    final name = achievement['name'] ?? '';
    final iconStr = achievement['icon'] ?? 'emoji_events';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isEarned ? null : AppColors.surfaceHighest,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _badgeIcon(iconStr),
              size: 36,
              color: isEarned ? AppColors.secondary : AppColors.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isEarned ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _badgeIcon(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'school':
        return Icons.school;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'military_tech':
        return Icons.military_tech;
      case 'workspace_premium_outlined':
        return Icons.workspace_premium_outlined;
      case 'psychology':
        return Icons.psychology;
      default:
        return Icons.emoji_events;
    }
  }

  // ── Leaderboard Tab ─────────────────────────────────────

  Widget _buildLeaderboardTab() {
    if (_leaderboard.isEmpty) {
      return _buildEmptyState('Leaderboard data not available');
    }

    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?['id'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Top Scholars'),
        const SizedBox(height: 8),
        ..._leaderboard.map((entry) {
          final isCurrentUser = entry['user_id'] == currentUserId;
          return _buildLeaderboardEntry(entry, isCurrentUser);
        }),
      ],
    );
  }

  Widget _buildLeaderboardEntry(dynamic entry, bool isCurrentUser) {
    final rank = entry['rank'] ?? 0;
    final displayName = entry['display_name'] ?? 'Unknown';
    final totalEarned = entry['total_earned'] ?? 0;
    final level = entry['level'] ?? 1;
    final streakDays = entry['streak_days'] ?? 0;

    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = AppColors.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isCurrentUser ? AppColors.primary.withOpacity(0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: isCurrentUser
                  ? AppColors.primary.withOpacity(0.15)
                  : AppColors.divider,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCurrentUser ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrentUser
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lv.$level · $streakDays day streak',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              '$totalEarned pts',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared Widgets ──────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
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
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 56, color: AppColors.textMuted.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Complete activities to earn points and badges',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
