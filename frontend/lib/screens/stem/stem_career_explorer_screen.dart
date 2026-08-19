import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

class StemCareerExplorerScreen extends StatefulWidget {
  final String subjectSlug;
  const StemCareerExplorerScreen({super.key, this.subjectSlug = ''});

  @override
  State<StemCareerExplorerScreen> createState() => _StemCareerExplorerScreenState();
}

class _StemCareerExplorerScreenState extends State<StemCareerExplorerScreen> {
  final StemService _stemService = StemService();
  List<dynamic> _careers = [];
  List<dynamic> _subjects = [];
  bool _loading = true;
  String? _error;
  String _selectedSubject = '';
  Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.subjectSlug;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final subjects = await _stemService.getSubjects();
      final careers = await _stemService.getCareers(
        subjectSlug: _selectedSubject.isNotEmpty ? _selectedSubject : null,
      );
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _careers = careers;
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
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 90,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Career Explorer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
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
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                scrollDirection: Axis.horizontal,
                itemCount: _subjects.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final selected = _selectedSubject.isEmpty;
                    return ChoiceChip(
                      label: const Text('All', style: TextStyle(fontSize: 12)),
                      selected: selected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                      onSelected: (_) {
                        setState(() => _selectedSubject = '');
                        _loadData();
                      },
                    );
                  }
                  final s = _subjects[index - 1];
                  final selected = _selectedSubject == s['slug'];
                  return ChoiceChip(
                    label: Text(
                      s['name'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                    onSelected: (_) {
                      setState(() => _selectedSubject = s['slug'] ?? '');
                      _loadData();
                    },
                  );
                },
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(child: ErrorState(message: 'Failed to load careers', details: _error, onRetry: _loadData))
          else if (_loading)
            SliverToBoxAdapter(child: ShimmerLoading.list(count: 5))
          else if (_careers.isEmpty)
            SliverToBoxAdapter(child: EmptyState(icon: Icons.work_rounded, title: 'No careers found', subtitle: 'Try selecting a different subject'))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: _careers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildCareerCard(index, _careers[index]),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
        ),
      ),
    );
  }

  Widget _buildCareerCard(int index, dynamic career) {
    final expanded = _expandedIndices.contains(index);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: expanded ? AppColors.primary : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  career['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (career['subject'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.infoMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    career['subject'],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            career['description'] ?? '',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            maxLines: expanded ? 20 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          if ((career['required_subjects'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            const Text(
              'Required Subjects',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: (career['required_subjects'] as List).map<Widget>((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGlow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.toString(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                );
              }).toList(),
            ),
          ],
          if ((career['skills'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            const Text(
              'Skills',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: (career['skills'] as List).map<Widget>((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.toString(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedIndices.remove(index);
                } else {
                  _expandedIndices.add(index);
                }
              });
            },
            child: Row(
              children: [
                Text(
                  expanded ? 'Show less' : 'Show more',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Icon(
                  expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            if ((career['related_programmes'] as List?)?.isNotEmpty == true) ...[
              const Divider(color: AppColors.border, height: 20),
              const Text(
                'Related Programmes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              ...((career['related_programmes'] as List).map<Widget>((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${p.toString()}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ))),
            ],
            if ((career['competencies'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text(
                'Competencies',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (career['competencies'] as List).map<Widget>((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warningMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.toString(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warning),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

}
