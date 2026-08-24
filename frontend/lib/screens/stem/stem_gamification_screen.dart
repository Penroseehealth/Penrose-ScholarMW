import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../core/theme/theme_colors.dart';

class StemGamificationScreen extends StatefulWidget {
  const StemGamificationScreen({super.key});

  @override
  State<StemGamificationScreen> createState() => _StemGamificationScreenState();
}

class _StemGamificationScreenState extends State<StemGamificationScreen>
    with SingleTickerProviderStateMixin {
  final StemService _stemService = StemService();
  late TabController _tabController;

  int _currentStreak = 0;
  int _totalPoints = 0;
  int _badgesEarned = 0;

  List<dynamic> _allBadges = [];
  Set<dynamic> _earnedBadgeIds = {};
  String _selectedBadgeCategory = '';

  List<dynamic> _challenges = [];
  String _selectedChallengeType = 'daily';
  final Set<int> _joiningChallengeIds = {};

  List<dynamic> _leaderboard = [];
  String _selectedLeaderboardSubject = '';

  bool _loadingBadges = true;
  bool _loadingChallenges = true;
  bool _loadingLeaderboard = true;
  String? _error;

  static const _badgeCategories = [
    'All',
    'Milestone',
    'Streak',
    'Assessment',
    'Subject',
    'Knowledge',
    'Social',
    'Achievement',
  ];

  static const _challengeTypes = ['daily', 'weekly', 'monthly'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadStats();
    _loadBadges();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final idx = _tabController.index;
    if (idx == 1 && _loadingChallenges) _loadChallenges();
    if (idx == 2 && _loadingLeaderboard) _loadLeaderboard();
  }

  Future<void> _loadStats() async {
    _error = null;
    try {
      final streak = await _stemService.getStreak();
      final points = await _stemService.getPoints();
      if (mounted) {
        setState(() {
          _currentStreak = streak['current_streak'] ?? streak['streak'] ?? 0;
          _totalPoints = points['total_points'] ?? points['points'] ?? 0;
        });
      }
      final earned = await _stemService.getEarnedBadges();
      if (mounted) {
        setState(() {
          _badgesEarned = earned.length;
          _earnedBadgeIds = earned.map((b) => b['id']).toSet();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadBadges() async {
    setState(() {
      _loadingBadges = true;
      _error = null;
    });
    try {
      final badges = await _stemService.getBadges(
        category: _selectedBadgeCategory.isNotEmpty && _selectedBadgeCategory != 'All'
            ? _selectedBadgeCategory
            : null,
      );
      if (mounted) {
        setState(() {
          _allBadges = badges;
          _loadingBadges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = e.toString();
        _loadingBadges = false;
      });
      }
    }
  }

  Future<void> _loadChallenges() async {
    setState(() {
      _loadingChallenges = true;
      _error = null;
    });
    try {
      final challenges = await _stemService.getChallenges(type: _selectedChallengeType);
      if (mounted) {
        setState(() {
          _challenges = challenges;
          _loadingChallenges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = e.toString();
        _loadingChallenges = false;
      });
      }
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _loadingLeaderboard = true;
      _error = null;
    });
    try {
      final leaderboard = await _stemService.getLeaderboard(
        subjectSlug: _selectedLeaderboardSubject.isNotEmpty &&
                _selectedLeaderboardSubject != 'All'
            ? _selectedLeaderboardSubject
            : null,
      );
      if (mounted) {
        setState(() {
          _leaderboard = leaderboard;
          _loadingLeaderboard = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = e.toString();
        _loadingLeaderboard = false;
      });
      }
    }
  }

  Future<void> _joinChallenge(int challengeId) async {
    setState(() => _joiningChallengeIds.add(challengeId));
    final result = await _stemService.joinChallenge(challengeId);
    if (mounted) {
      setState(() => _joiningChallengeIds.remove(challengeId));
      if (result.isNotEmpty) _loadChallenges();
    }
  }

  IconData _getBadgeIcon(String? iconName) {
    switch (iconName) {
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'calculate':
        return Icons.calculate_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      case 'group':
        return Icons.group_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'leaderboard':
        return Icons.leaderboard_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'biotech':
        return Icons.biotech_rounded;
      case 'architecture':
        return Icons.architecture_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'insights':
        return Icons.insights_rounded;
      case 'auto_awesome':
        return Icons.auto_awesome_rounded;
      case 'celebration':
        return Icons.celebration_rounded;
      case 'emoji_events_outlined':
        return Icons.emoji_events_outlined;
      default:
        return Icons.badge_rounded;
    }
  }

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return context.colors.success;
      case 'medium':
        return context.colors.warning;
      case 'hard':
        return context.colors.error;
      case 'expert':
        return AppColors.primary;
      default:
        return context.colors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 90,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'STEM Achievements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryMuted],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildStatsRow()),
          if (_error != null && !_loadingBadges && !_loadingChallenges && !_loadingLeaderboard)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorState(message: _error!, onRetry: () { _loadStats(); _loadBadges(); _loadChallenges(); _loadLeaderboard(); }),
              ),
            ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: context.colors.textPrimary,
                unselectedLabelColor: context.colors.textMuted,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: context.colors.border,
                dividerHeight: 1,
                tabs: [
                  const Tab(text: 'Badges'),
                  const Tab(text: 'Challenges'),
                  const Tab(text: 'Leaderboard'),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _loadStats(),
                  _loadBadges(),
                  _loadChallenges(),
                  _loadLeaderboard(),
                ]);
              },
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBadgesTab(),
                  _buildChallengesTab(),
                  _buildLeaderboardTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Expanded(child: _buildStatItem(Icons.local_fire_department_rounded, '$_currentStreak', 'Current Streak', context.colors.warning)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatItem(Icons.star_rounded, '$_totalPoints', 'Total Points', AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatItem(Icons.emoji_events_rounded, '$_badgesEarned', 'Badges Earned', context.colors.teal)),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesTab() {
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            scrollDirection: Axis.horizontal,
            itemCount: _badgeCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _badgeCategories[index];
              final selected = _selectedBadgeCategory == cat ||
                  (_selectedBadgeCategory.isEmpty && cat == 'All');
              return ChoiceChip(
                label: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : context.colors.textSecondary,
                  ),
                ),
                selected: selected,
                selectedColor: AppColors.primary,
                backgroundColor: context.colors.surface,
                side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
                onSelected: (_) {
                  setState(() => _selectedBadgeCategory = cat == 'All' ? '' : cat);
                  _loadBadges();
                },
              );
            },
          ),
        ),
        Expanded(
          child: _loadingBadges
              ? Center(child: ShimmerLoading.list(count: 3))
              : _allBadges.isEmpty
                  ? const EmptyState(icon: Icons.emoji_events_rounded, title: 'No badges found', subtitle: 'Complete STEM activities to earn badges')
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _allBadges.length,
                      itemBuilder: (context, index) => _buildBadgeCard(_allBadges[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(dynamic badge) {
    final earned = _earnedBadgeIds.contains(badge['id']);
    final iconData = _getBadgeIcon(badge['icon'] ?? badge['icon_name']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: earned ? context.colors.surfaceHighest : context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: earned ? const Color(0xFFFFD700) : context.colors.border,
          width: earned ? 2 : 1,
        ),
      ),
      child: Opacity(
        opacity: earned ? 1.0 : 0.45,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: earned ? const Color(0x33FFD700) : context.colors.surfaceHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 26, color: earned ? const Color(0xFFFFD700) : context.colors.textMuted),
            ),
            const SizedBox(height: 10),
            Text(
              badge['title'] ?? badge['name'] ?? '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: earned ? context.colors.textPrimary : context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              badge['description'] ?? '',
              style: TextStyle(fontSize: 10, color: context.colors.textMuted),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.primaryGlow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${badge['points'] ?? 0} pts',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesTab() {
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            scrollDirection: Axis.horizontal,
            itemCount: _challengeTypes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final type = _challengeTypes[index];
              final selected = _selectedChallengeType == type;
              return ChoiceChip(
                label: Text(
                  type[0].toUpperCase() + type.substring(1),
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : context.colors.textSecondary,
                  ),
                ),
                selected: selected,
                selectedColor: AppColors.primary,
                backgroundColor: context.colors.surface,
                side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
                onSelected: (_) {
                  setState(() => _selectedChallengeType = type);
                  _loadChallenges();
                },
              );
            },
          ),
        ),
        Expanded(
          child: _loadingChallenges
              ? Center(child: ShimmerLoading.list(count: 3))
              : _challenges.isEmpty
                  ? const EmptyState(icon: Icons.emoji_events_rounded, title: 'No challenges available', subtitle: 'Check back later for new challenges')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _challenges.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _buildChallengeCard(_challenges[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(dynamic challenge) {
    final joined = challenge['is_joined'] == true || challenge['status'] == 'in_progress';
    final joining = _joiningChallengeIds.contains(challenge['id']);
    final diffColor = _getDifficultyColor(challenge['difficulty']);
    final progress = (challenge['progress'] ?? 0).toDouble();
    final target = (challenge['target'] ?? 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge['title'] ?? challenge['name'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              if (challenge['difficulty'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    challenge['difficulty'],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: diffColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            challenge['description'] ?? '',
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.primaryGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${challenge['points_reward'] ?? challenge['points'] ?? 0} pts',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (joined) ...[
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${progress.toInt()}/${target.toInt()}',
                        style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: target > 0 ? (progress / target).clamp(0.0, 1.0) : 0,
                          minHeight: 6,
                          backgroundColor: context.colors.surfaceHighest,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: joining ? null : () => _joinChallenge(challenge['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: joining
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : const Text('Join', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    final subjects = _leaderboard.isNotEmpty && _leaderboard.first['subjects'] != null
        ? List<String>.from(_leaderboard.first['subjects'])
        : <String>[];

    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            scrollDirection: Axis.horizontal,
            itemCount: subjects.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                final selected = _selectedLeaderboardSubject.isEmpty;
                return ChoiceChip(
                  label: const Text('All', style: TextStyle(fontSize: 12)),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  backgroundColor: context.colors.surface,
                  side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
                  onSelected: (_) {
                    setState(() => _selectedLeaderboardSubject = '');
                    _loadLeaderboard();
                  },
                );
              }
              final subj = subjects[index - 1];
              final selected = _selectedLeaderboardSubject == subj;
              return ChoiceChip(
                label: Text(
                  subj,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : context.colors.textSecondary,
                  ),
                ),
                selected: selected,
                selectedColor: AppColors.primary,
                backgroundColor: context.colors.surface,
                side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
                onSelected: (_) {
                  setState(() => _selectedLeaderboardSubject = subj);
                  _loadLeaderboard();
                },
              );
            },
          ),
        ),
        Expanded(
          child: _loadingLeaderboard
              ? Center(child: ShimmerLoading.list(count: 3))
              : _leaderboard.isEmpty
                  ? const EmptyState(icon: Icons.emoji_events_rounded, title: 'No leaderboard data', subtitle: 'Be the first to earn points')
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_leaderboard.length >= 3) _buildTopThree(),
                        const SizedBox(height: 12),
                        ...List.generate(
                          _leaderboard.length > 3 ? _leaderboard.length - 3 : 0,
                          (i) {
                            final idx = i + 3;
                            final entry = _leaderboard[idx];
                            return _buildLeaderboardRow(idx + 1, entry);
                          },
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildTopThree() {
    final medals = ['🥇', '🥈', '🥉'];
    final colors = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [1, 0, 2].map((podiumIdx) {
        final entry = _leaderboard[podiumIdx];
        final height = podiumIdx == 0 ? 120.0 : (podiumIdx == 1 ? 100.0 : 85.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Text(medals[podiumIdx], style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors[podiumIdx].withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors[podiumIdx]),
                  ),
                  child: Center(
                    child: Text(
                      (entry['name'] ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors[podiumIdx],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry['name'] ?? '',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry['points'] ?? 0} pts',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors[podiumIdx]),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry['streak'] ?? 0}🔥',
                  style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: height,
                  decoration: BoxDecoration(
                    color: colors[podiumIdx].withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border.all(color: colors[podiumIdx].withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      '#${podiumIdx + 1}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors[podiumIdx].withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaderboardRow(int rank, dynamic entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.colors.primaryGlow,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (entry['name'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry['name'] ?? '',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${entry['points'] ?? 0} pts',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            '${entry['streak'] ?? 0}🔥',
            style: TextStyle(fontSize: 11, color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }

}
