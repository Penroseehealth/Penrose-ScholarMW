import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../core/theme/theme_colors.dart';

class StemMalawiScreen extends StatefulWidget {
  const StemMalawiScreen({super.key});

  @override
  State<StemMalawiScreen> createState() => _StemMalawiScreenState();
}

class _StemMalawiScreenState extends State<StemMalawiScreen>
    with SingleTickerProviderStateMixin {
  final StemService _stemService = StemService();
  late TabController _tabController;

  Map<String, dynamic> _stats = {};
  List<dynamic> _examples = [];
  List<dynamic> _curriculum = [];
  bool _loading = true;
  String? _error;
  final Set<int> _expandedExampleIndices = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stats = await _stemService.getMalawiStats();
      final examples = await _stemService.getMalawiExamples();
      final curriculum = await _stemService.getMalawiCurriculum();
      if (mounted) {
        setState(() {
          _stats = stats;
          _examples = examples;
          _curriculum = curriculum;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Malawi STEM',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Connecting STEM to Malawian Context',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
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
          SliverToBoxAdapter(
            child: _loading
                ? const SizedBox()
                : _buildStatsRow(),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: context.colors.textPrimary,
                unselectedLabelColor: context.colors.textMuted,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(text: 'Local Examples'),
                  const Tab(text: 'MSCE Curriculum'),
                ],
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: ErrorState(
                message: 'Failed to load content',
                details: _error,
                onRetry: _loadData,
              ),
            )
          else if (_loading)
            SliverToBoxAdapter(child: ShimmerLoading.list(count: 3))
          else
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExamplesTab(),
                  _buildCurriculumTab(),
                ],
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalExamples = _stats['total_examples'] ?? 0;
    final totalAlignments = _stats['total_alignments'] ?? 0;
    final subjectsCovered = _stats['subjects_covered'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _buildStatChip('$totalExamples', 'Examples'),
          const SizedBox(width: 8),
          _buildStatChip('$totalAlignments', 'MSCE Alignments'),
          const SizedBox(width: 8),
          _buildStatChip('$subjectsCovered', 'Regions'),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamplesTab() {
    if (_examples.isEmpty) return const EmptyState(icon: Icons.school_rounded, title: 'No local examples found', subtitle: 'Content will appear here once available');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _examples.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildExampleCard(index, _examples[index]),
    );
  }

  Widget _buildExampleCard(int index, dynamic example) {
    final expanded = _expandedExampleIndices.contains(index);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (expanded) {
            _expandedExampleIndices.remove(index);
          } else {
            _expandedExampleIndices.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: expanded ? AppColors.primary : context.colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    example['title'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (example['region'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.successMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      example['region'],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: context.colors.success,
                      ),
                    ),
                  ),
              ],
            ),
            if (example['concept_name'] != null) ...[
              const SizedBox(height: 4),
              Text(
                example['concept_name'],
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              example['description'] ?? '',
              style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              maxLines: expanded ? 20 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (expanded) ...[
              if (example['local_context'] != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Local Context',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  example['local_context'],
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                ),
              ],
              if (example['real_world_application'] != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Real-World Application',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  example['real_world_application'],
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurriculumTab() {
    if (_curriculum.isEmpty) return const EmptyState(icon: Icons.school_rounded, title: 'No curriculum alignments found', subtitle: 'Content will appear here once available');

    final grouped = <String, List<dynamic>>{};
    for (final item in _curriculum) {
      final formLevel = item['form_level'] ?? 'Other';
      grouped.putIfAbsent(formLevel, () => []).add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final formLevel = sortedKeys[index];
        final items = grouped[formLevel]!;
        return _buildCurriculumGroup(formLevel, items);
      },
    );
  }

  Widget _buildCurriculumGroup(String formLevel, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.colors.primaryGlow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Form $formLevel',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _buildCurriculumCard(item)),
        ],
      ),
    );
  }

  Widget _buildCurriculumCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                  item['concept_name'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              if (item['syllabus_code'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.infoMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item['syllabus_code'],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: context.colors.info,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (item['form_level'] != null)
                _buildMetaTag('Form ${item['form_level']}'),
              if (item['exam_board'] != null) ...[
                const SizedBox(width: 6),
                _buildMetaTag(item['exam_board']),
              ],
            ],
          ),
          if (item['learning_outcome'] != null) ...[
            const SizedBox(height: 8),
            Text(
              item['learning_outcome'],
              style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.surfaceHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }

}
