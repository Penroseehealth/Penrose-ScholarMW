import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

class StemKnowledgeGraphScreen extends StatefulWidget {
  final String subjectSlug;
  const StemKnowledgeGraphScreen({super.key, this.subjectSlug = ''});

  @override
  State<StemKnowledgeGraphScreen> createState() => _StemKnowledgeGraphScreenState();
}

class _StemKnowledgeGraphScreenState extends State<StemKnowledgeGraphScreen> {
  final StemService _stemService = StemService();
  List<dynamic> _connections = [];
  List<dynamic> _subjects = [];
  bool _loading = true;
  String? _error;
  String _selectedSubject = '';
  String _selectedRelationship = 'all';

  static const _relationshipTypes = [
    'all',
    'prerequisite_of',
    'applied_in',
    'overlaps_with',
    'foundational_for',
    'related',
  ];

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
      final slug = _selectedSubject.isNotEmpty ? _selectedSubject : (subjects.isNotEmpty ? subjects[0]['slug'] ?? '' : '');
      final connections = await _stemService.getKnowledgeGraph(slug);
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _connections = connections;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _onSubjectChanged(String slug) async {
    setState(() {
      _selectedSubject = slug;
      _loading = true;
      _error = null;
    });
    try {
      final connections = await _stemService.getKnowledgeGraph(slug);
      if (mounted) {
        setState(() {
          _connections = connections;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<dynamic> get _filteredConnections {
    if (_selectedRelationship == 'all') return _connections;
    return _connections.where((c) => c['relationship_type'] == _selectedRelationship).toList();
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
                'Knowledge Graph',
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildSubjectDropdown(),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                scrollDirection: Axis.horizontal,
                itemCount: _relationshipTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final type = _relationshipTypes[index];
                  final selected = _selectedRelationship == type;
                  return ChoiceChip(
                    label: Text(
                      type == 'all' ? 'All' : type.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    onSelected: (_) => setState(() => _selectedRelationship = type),
                  );
                },
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(child: ErrorState(message: 'Failed to load connections', details: _error, onRetry: _loadData))
          else if (_loading)
            SliverToBoxAdapter(child: ShimmerLoading.list(count: 5))
          else if (_filteredConnections.isEmpty)
            SliverToBoxAdapter(child: EmptyState(icon: Icons.account_tree_rounded, title: 'No connections found', subtitle: 'Knowledge connections will appear here'))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: _filteredConnections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildConnectionCard(_filteredConnections[index]),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
        ),
      ),
    );
  }

  Widget _buildSubjectDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<String>(
        value: _selectedSubject.isNotEmpty ? _selectedSubject : null,
        hint: const Text('All Subjects', style: TextStyle(color: AppColors.textMuted)),
        isExpanded: true,
        dropdownColor: AppColors.surfaceElevated,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
        items: [
          const DropdownMenuItem(value: '', child: Text('All Subjects', style: TextStyle(color: AppColors.textSecondary))),
          ..._subjects.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                value: s['slug'] ?? '',
                child: Text(s['name'] ?? '', style: const TextStyle(color: AppColors.textSecondary)),
              )),
        ],
        onChanged: (v) => _onSubjectChanged(v ?? ''),
      ),
    );
  }

  Widget _buildConnectionCard(dynamic conn) {
    final source = conn['source_title'] ?? conn['source'] ?? '';
    final target = conn['target_title'] ?? conn['target'] ?? '';
    final relType = (conn['relationship_type'] ?? '').toString().replaceAll('_', ' ');
    final description = conn['description'] ?? '';
    final sourceTags = (conn['source_subjects'] as List?) ?? [];
    final targetTags = (conn['target_subjects'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  source,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  relType,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  target,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ...sourceTags.map<Widget>((t) => _buildTagChip(t.toString(), AppColors.info)),
              ...targetTags.map<Widget>((t) => _buildTagChip(t.toString(), AppColors.teal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

}
