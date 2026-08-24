import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/shimmer_loading.dart';

class StemLabScreen extends StatefulWidget {
  final String subjectSlug;
  final String labType;
  const StemLabScreen({super.key, this.subjectSlug = '', this.labType = ''});

  @override
  State<StemLabScreen> createState() => _StemLabScreenState();
}

class _StemLabScreenState extends State<StemLabScreen> {
  final StemService _stemService = StemService();
  List<dynamic> _labs = [];
  List<dynamic> _subjects = [];
  bool _loading = true;
  String _selectedSubject = '';
  String _selectedLabType = '';
  String? _error;
  final Set<int> _expandedIndices = {};

  static const _labTypes = ['all', 'virtual', 'physical', 'simulation', 'field'];

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.subjectSlug;
    _selectedLabType = widget.labType;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subjects = await _stemService.getSubjects();
      final labs = await _stemService.getLabs(
        subjectSlug: _selectedSubject.isNotEmpty ? _selectedSubject : null,
        labType: _selectedLabType.isNotEmpty && _selectedLabType != 'all' ? _selectedLabType : null,
      );
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _labs = labs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 90,
                pinned: true,
                backgroundColor: AppColors.primaryDark,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'STEM Labs',
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
                          backgroundColor: context.colors.surface,
                          side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
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
                          (s['name'] ?? '') as String,
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
                          setState(() => _selectedSubject = (s['slug'] ?? '') as String);
                          _loadData();
                        },
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    scrollDirection: Axis.horizontal,
                    itemCount: _labTypes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final type = _labTypes[index];
                      final selected = _selectedLabType == type || (_selectedLabType.isEmpty && type == 'all');
                      return ChoiceChip(
                        label: Text(
                          type == 'all' ? 'All Types' : type[0].toUpperCase() + type.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white : context.colors.textSecondary,
                          ),
                        ),
                        selected: selected,
                        selectedColor: context.colors.teal,
                        backgroundColor: context.colors.surface,
                        side: BorderSide(color: selected ? context.colors.teal : context.colors.border),
                        onSelected: (_) {
                          setState(() => _selectedLabType = type == 'all' ? '' : type);
                          _loadData();
                        },
                      );
                    },
                  ),
                ),
              ),
              if (_error != null)
                SliverToBoxAdapter(
                    child: ErrorState(message: 'Failed to load labs', details: _error, onRetry: _loadData))
              else if (_loading)
                SliverToBoxAdapter(child: ShimmerLoading.list())
              else if (_labs.isEmpty)
                const SliverToBoxAdapter(
                    child: EmptyState(
                        icon: Icons.science_rounded, title: 'No labs found', subtitle: 'Try adjusting your filters'))
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.separated(
                    itemCount: _labs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildLabCard(index, _labs[index]),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      );

  Color _difficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
      case 'beginner':
        return context.colors.success;
      case 'medium':
      case 'intermediate':
        return context.colors.warning;
      case 'hard':
      case 'advanced':
      case 'expert':
        return context.colors.error;
      default:
        return context.colors.textMuted;
    }
  }

  Widget _buildLabCard(int index, dynamic lab) {
    final expanded = _expandedIndices.contains(index);
    final difficulty = (lab['difficulty'] ?? 'medium') as String;
    final diffColor = _difficultyColor(difficulty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: expanded ? AppColors.primary : context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (lab['title'] ?? '') as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  difficulty.toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: diffColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (lab['subject'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.colors.infoMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    lab['subject'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.colors.info,
                    ),
                  ),
                ),
              if (lab['duration'] != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.schedule_rounded, size: 12, color: context.colors.textMuted),
                const SizedBox(width: 3),
                Text(
                  lab['duration'].toString(),
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (lab['description'] ?? '') as String,
            style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            maxLines: expanded ? 20 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          if ((lab['materials'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Materials Needed',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: (lab['materials'] as List)
                  .map<Widget>((m) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.colors.warningMuted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m.toString(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.colors.warning),
                        ),
                      ))
                  .toList(),
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
                  expanded ? 'Hide steps' : 'Show steps',
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
          if (expanded && (lab['steps'] as List?)?.isNotEmpty == true) ...[
            Divider(color: context.colors.border, height: 20),
            ...List.generate(
              (lab['steps'] as List).length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 10, top: 1),
                      decoration: BoxDecoration(
                        color: context.colors.primaryGlow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        (lab['steps'] as List)[i].toString(),
                        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
