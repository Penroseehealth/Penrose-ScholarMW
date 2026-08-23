import 'package:flutter/material.dart';
import 'stem_concept_screen.dart';
import '../../services/stem_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../core/theme/theme_colors.dart';

class StemTopicScreen extends StatefulWidget {
  final int topicId;
  final String title;
  final String difficulty;

  StemTopicScreen({
    super.key,
    required this.topicId,
    required this.title,
    this.difficulty = 'beginner',
  });

  @override
  State<StemTopicScreen> createState() => _StemTopicScreenState();
}

class _StemTopicScreenState extends State<StemTopicScreen> {
  final StemService _stemService = StemService();
  List<dynamic> _subtopics = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubtopics();
  }

  Future<void> _loadSubtopics() async {
    setState(() { _loading = true; _error = null; });
    try {
      final subtopics = await _stemService.getSubtopics(widget.topicId);
      if (mounted) {
        setState(() {
          _subtopics = subtopics;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
    final diffColor = _getDifficultyColor(widget.difficulty);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: diffColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.difficulty,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: diffColor,
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: context.colors.border, height: 1),
        ),
      ),
      body: _error != null
          ? ErrorState(message: 'Failed to load subtopics', details: _error, onRetry: _loadSubtopics)
          : _loading
              ? Center(child: ShimmerLoading.list(count: 5))
              : _subtopics.isEmpty
                  ? EmptyState(
                      icon: Icons.topic_outlined,
                      title: 'No subtopics available',
                      subtitle: 'Subtopics will appear here',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSubtopics,
                      color: AppColors.primary,
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                '${_subtopics.length} subtopic${_subtopics.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textMuted,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList.builder(
                              itemCount: _subtopics.length,
                              itemBuilder: (context, index) => _buildSubtopicExpansionCard(_subtopics[index]),
                            ),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: 40)),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSubtopicExpansionCard(dynamic subtopic) {
    return _SubtopicExpansionCard(
      subtopic: subtopic,
      getDifficultyColor: _getDifficultyColor,
      onConceptTap: (concept) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StemConceptScreen(
              conceptId: concept['id'],
              title: concept['name'] ?? concept['title'] ?? 'Concept',
            ),
          ),
        );
      },
    );
  }
}

class _SubtopicExpansionCard extends StatefulWidget {
  final dynamic subtopic;
  final Color Function(String?) getDifficultyColor;
  final void Function(dynamic concept) onConceptTap;

  const _SubtopicExpansionCard({
    required this.subtopic,
    required this.getDifficultyColor,
    required this.onConceptTap,
  });

  @override
  State<_SubtopicExpansionCard> createState() => _SubtopicExpansionCardState();
}

class _SubtopicExpansionCardState extends State<_SubtopicExpansionCard> {
  bool _expanded = false;
  List<dynamic> _concepts = [];
  bool _loadingConcepts = false;
  bool _conceptsLoaded = false;

  final StemService _stemService = StemService();

  Future<void> _toggleExpand() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && !_conceptsLoaded) {
      setState(() => _loadingConcepts = true);
      final concepts = await _stemService.getConcepts(widget.subtopic['id']);
      if (mounted) {
        setState(() {
          _concepts = concepts;
          _loadingConcepts = false;
          _conceptsLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conceptCount = widget.subtopic['concept_count'] ?? _concepts.length;

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
                          widget.subtopic['name'] ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '$conceptCount concept${conceptCount == 1 ? '' : 's'}',
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
                    duration: Duration(milliseconds: 200),
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
            if (_loadingConcepts)
              Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                ),
              )
            else if (_concepts.isEmpty)
              Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No concepts available',
                    style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                  ),
                ),
              )
            else
              ...List.generate(_concepts.length, (index) {
                final concept = _concepts[index];
                final diffColor = widget.getDifficultyColor(concept['difficulty']);
                final isLast = index == _concepts.length - 1;

                return GestureDetector(
                  onTap: () => widget.onConceptTap(concept),
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
                            concept['name'] ?? concept['title'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: diffColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            concept['difficulty'] ?? 'beginner',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: diffColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
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
