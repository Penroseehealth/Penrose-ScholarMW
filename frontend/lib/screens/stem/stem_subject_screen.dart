import 'package:flutter/material.dart';
import 'stem_topic_screen.dart';
import '../../services/stem_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../core/theme/theme_colors.dart';

class StemSubjectScreen extends StatefulWidget {
  final String slug;
  final String title;

  const StemSubjectScreen({
    super.key,
    required this.slug,
    this.title = 'Subject',
  });

  @override
  State<StemSubjectScreen> createState() => _StemSubjectScreenState();
}

class _StemSubjectScreenState extends State<StemSubjectScreen> {
  final StemService _stemService = StemService();
  Map<String, dynamic>? _subject;
  List<dynamic> _disciplines = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final subject = await _stemService.getSubject(widget.slug);
      final disciplines = await _stemService.getDisciplines(widget.slug);
      if (mounted) {
        setState(() {
          _subject = subject;
          _disciplines = disciplines;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _getSubjectColor() {
    final colorHex = _subject?['color'];
    if (colorHex != null && colorHex.toString().startsWith('#')) {
      final hex = colorHex.toString().replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final subjectColor = _getSubjectColor();

    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            expandedHeight: 70,
            pinned: true,
            backgroundColor: subjectColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [subjectColor, subjectColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: _subject != null
                    ? Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            _subject!['description'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Disciplines',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(child: ErrorState(message: 'Failed to load subject', details: _error, onRetry: _loadData))
          else if (_loading)
            SliverToBoxAdapter(child: ShimmerLoading.list(count: 5))
          else if (_disciplines.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.category_outlined,
                title: 'No disciplines available',
                subtitle: 'Disciplines will appear here',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: _disciplines.length,
                itemBuilder: (context, index) => _buildDisciplineCard(_disciplines[index]),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildDisciplineCard(dynamic discipline) {
    return _DisciplineExpansionCard(
      discipline: discipline,
      onTopicTap: (topic) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StemTopicScreen(
              topicId: topic['id'],
              title: topic['name'] ?? 'Topic',
              difficulty: topic['difficulty'] ?? 'beginner',
            ),
          ),
        );
      },
    );
  }
}

class _DisciplineExpansionCard extends StatefulWidget {
  final dynamic discipline;
  final void Function(dynamic topic) onTopicTap;

  const _DisciplineExpansionCard({
    required this.discipline,
    required this.onTopicTap,
  });

  @override
  State<_DisciplineExpansionCard> createState() => _DisciplineExpansionCardState();
}

class _DisciplineExpansionCardState extends State<_DisciplineExpansionCard> {
  bool _expanded = false;
  List<dynamic> _topics = [];
  bool _loadingTopics = false;
  bool _topicsLoaded = false;

  final StemService _stemService = StemService();

  Future<void> _toggleExpand() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && !_topicsLoaded) {
      setState(() => _loadingTopics = true);
      final topics = await _stemService.getTopics(widget.discipline['id']);
      if (mounted) {
        setState(() {
          _topics = topics;
          _loadingTopics = false;
          _topicsLoaded = true;
        });
      }
    }
  }

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty) {
      case 'advanced':
        return context.colors.error;
      case 'intermediate':
        return context.colors.warning;
      case 'beginner':
      default:
        return context.colors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicCount = widget.discipline['topic_count'] ?? _topics.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.discipline['name'] ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$topicCount topics',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: context.colors.textMuted,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: context.colors.border),
            if (_loadingTopics)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                ),
              )
            else if (_topics.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No topics available',
                    style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                  ),
                ),
              )
            else
              ...List.generate(_topics.length, (index) {
                final topic = _topics[index];
                final diffColor = _getDifficultyColor(topic['difficulty']);
                final isLast = index == _topics.length - 1;

                return GestureDetector(
                  onTap: () => widget.onTopicTap(topic),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(color: context.colors.borderLight, width: 0.5),
                            ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            topic['name'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: diffColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            topic['difficulty'] ?? 'beginner',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: diffColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: 18),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
