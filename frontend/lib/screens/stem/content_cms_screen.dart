import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../core/theme/theme_colors.dart';

class ContentCmsScreen extends StatefulWidget {
  const ContentCmsScreen({super.key});
  @override
  State<ContentCmsScreen> createState() => _ContentCmsScreenState();
}

class _ContentCmsScreenState extends State<ContentCmsScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<dynamic> _subjects = [];

  final Set<int> _expandedSubjects = {};
  final Map<int, List<dynamic>> _disciplinesCache = {};
  final Set<int> _expandedDisciplines = {};
  final Map<int, List<dynamic>> _topicsCache = {};
  final Set<int> _expandedTopics = {};
  final Map<int, List<dynamic>> _subtopicsCache = {};
  final Set<int> _expandedSubtopics = {};
  final Map<int, List<dynamic>> _conceptsCache = {};

  dynamic _editingItem;
  String? _editingType;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statsRes = await _api.get('/stem/cms/stats');
      final subsRes = await _api.get('/stem/cms/subjects');
      if (mounted) {
        setState(() {
          _stats = statsRes.statusCode == 200 ? jsonDecode(statsRes.body) : {};
          _subjects = subsRes.statusCode == 200 ? jsonDecode(subsRes.body) : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadDisciplines(int subjectId) async {
    if (_disciplinesCache.containsKey(subjectId)) return;
    try {
      final res = await _api.get('/stem/cms/subjects/$subjectId/disciplines');
      if (mounted && res.statusCode == 200) {
        setState(() { _disciplinesCache[subjectId] = jsonDecode(res.body); });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load disciplines')));
    }
  }

  Future<void> _loadTopics(int disciplineId) async {
    if (_topicsCache.containsKey(disciplineId)) return;
    try {
      final res = await _api.get('/stem/cms/disciplines/$disciplineId/topics');
      if (mounted && res.statusCode == 200) {
        setState(() { _topicsCache[disciplineId] = jsonDecode(res.body); });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load topics')));
    }
  }

  Future<void> _loadSubtopics(int topicId) async {
    if (_subtopicsCache.containsKey(topicId)) return;
    try {
      final res = await _api.get('/stem/cms/topics/$topicId/subtopics');
      if (mounted && res.statusCode == 200) {
        setState(() { _subtopicsCache[topicId] = jsonDecode(res.body); });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load subtopics')));
    }
  }

  Future<void> _loadConcepts(int subtopicId) async {
    if (_conceptsCache.containsKey(subtopicId)) return;
    try {
      final res = await _api.get('/stem/cms/subtopics/$subtopicId/concepts');
      if (mounted && res.statusCode == 200) {
        setState(() { _conceptsCache[subtopicId] = jsonDecode(res.body); });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load concepts')));
    }
  }

  void _enterEditor(dynamic item, String type) {
    setState(() { _editingItem = item; _editingType = type; });
  }

  void _exitEditor() {
    setState(() { _editingItem = null; _editingType = null; });
  }

  String _createEndpoint(String type, int? parentId) {
    switch (type) {
      case 'Subject': return '/stem/cms/subjects';
      case 'Discipline': return '/stem/cms/subjects/$parentId/disciplines';
      case 'Topic': return '/stem/cms/disciplines/$parentId/topics';
      case 'Subtopic': return '/stem/cms/topics/$parentId/subtopics';
      case 'Concept': return '/stem/cms/subtopics/$parentId/concepts';
      default: return '';
    }
  }

  Future<void> _saveItem(String type, Map<String, dynamic> body, {int? id, int? parentId}) async {
    try {
      final dynamic res;
      if (id == null) {
        final endpoint = _createEndpoint(type, parentId);
        if (endpoint.isEmpty) return;
        res = await _api.post(endpoint, body: body);
      } else {
        final endpoint = _endpointForType(type);
        res = await _api.put('$endpoint/$id', body: body);
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type saved')));
          _exitEditor();
          _clearCaches();
          _loadDashboard();
        }
      } else {
        final msg = jsonDecode(res.body)['detail'] ?? 'Save failed';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteItem(String type, int id) async {
    try {
      final endpoint = _endpointForType(type);
      final res = await _api.delete('$endpoint/$id');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type deleted')));
          _exitEditor();
          _clearCaches();
          _loadDashboard();
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _endpointForType(String type) {
    switch (type) {
      case 'Subject': return '/stem/cms/subjects';
      case 'Discipline': return '/stem/cms/disciplines';
      case 'Topic': return '/stem/cms/topics';
      case 'Subtopic': return '/stem/cms/subtopics';
      case 'Concept': return '/stem/cms/concepts';
      default: return '';
    }
  }

  void _clearCaches() {
    _disciplinesCache.clear();
    _topicsCache.clear();
    _subtopicsCache.clear();
    _conceptsCache.clear();
    _expandedSubjects.clear();
    _expandedDisciplines.clear();
    _expandedTopics.clear();
    _expandedSubtopics.clear();
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CreatePickerSheet(
        onPick: (type) {
          Navigator.pop(context);
          _enterEditor(null, type);
        },
      ),
    );
  }

  void _showItemActions(dynamic item, String type) {
    final id = item['id'] as int;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
              title: Text('Edit $type', style: TextStyle(color: context.colors.textPrimary)),
              onTap: () { Navigator.pop(context); _enterEditor(item, type); },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: context.colors.error),
              title: Text('Delete $type', style: TextStyle(color: context.colors.error)),
              onTap: () { Navigator.pop(context); _confirmDelete(type, id); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String type, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: context.colors.border)),
        title: Text('Delete $type?', style: TextStyle(color: context.colors.textPrimary)),
        content: Text('This action cannot be undone.', style: TextStyle(color: context.colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: context.colors.textSecondary))),
          TextButton(
            onPressed: () { Navigator.pop(context); _deleteItem(type, id); },
            child: Text('Delete', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_editingItem != null || _editingType != null) {
      return _buildEditorView();
    }
    return _buildDashboardView();
  }

  Widget _buildDashboardView() {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: AppColors.primary,
        backgroundColor: context.colors.surface,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            if (_loading)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const SizedBox(height: 12),
                  ShimmerLoading.grid(count: 4, childAspectRatio: 1.8),
                  const SizedBox(height: 24),
                  ShimmerLoading.list(count: 5, height: 56),
                ]),
              ))
            else if (_error != null)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: context.colors.error),
                  const SizedBox(height: 12),
                  Text('Failed to load content', style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: context.colors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _loadDashboard, child: const Text('Retry', style: TextStyle(color: AppColors.primary))),
                ]),
              ))
            else ...[
              SliverToBoxAdapter(child: _buildStatsRow()),
              SliverToBoxAdapter(child: _buildTreeHeader()),
              _buildTree(),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  SliverAppBar _buildAppBar() => SliverAppBar(
    expandedHeight: 90, pinned: true, backgroundColor: AppColors.primaryDark,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      onPressed: () => context.go('/'),
    ),
    flexibleSpace: FlexibleSpaceBar(
      title: const Text('Content Manager', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),
    ),
  );

  Widget _buildStatsRow() {
    final items = [
      _StatCard(icon: Icons.book_rounded, label: 'Subjects', value: _stats['total_subjects'] ?? _subjects.length, color: AppColors.primary),
      _StatCard(icon: Icons.account_tree_rounded, label: 'Disciplines', value: _stats['total_disciplines'] ?? 0, color: context.colors.teal),
      _StatCard(icon: Icons.menu_book_rounded, label: 'Topics', value: _stats['total_topics'] ?? 0, color: context.colors.warning),
      _StatCard(icon: Icons.lightbulb_rounded, label: 'Concepts', value: _stats['total_concepts'] ?? 0, color: context.colors.success),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: items.map((c) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4), child: c,
      ))).toList()),
    );
  }

  Widget _buildTreeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(children: [
        Icon(Icons.account_tree_rounded, size: 18, color: context.colors.textSecondary),
        const SizedBox(width: 8),
        Text('Content Tree', style: TextStyle(color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (_subjects.isNotEmpty) Text('${_subjects.length} subjects', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
      ]),
    );
  }

  Widget _buildTree() {
    if (_subjects.isEmpty) {
      return SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Icon(Icons.folder_open_rounded, size: 48, color: context.colors.textMuted),
          const SizedBox(height: 12),
          Text('No subjects yet', style: TextStyle(color: context.colors.textSecondary)),
          const SizedBox(height: 4),
          Text('Tap + to create your first subject', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
        ]),
      ));
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, i) => _subjectNode(_subjects[i]), childCount: _subjects.length),
      ),
    );
  }

  Widget _buildTreeNode({
    required dynamic item,
    required String type,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required double borderRadius,
    required double iconSize,
    required double fontSize,
    required double leftPad,
    required double borderAlpha,
    List<dynamic> children = const [],
    bool expanded = false,
    VoidCallback? onExpand,
    String? subtitle,
  }) {
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final nodeCount = children.length;
    return Column(
      children: [
        Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            onTap: onExpand,
            onLongPress: () => _showItemActions(item, type),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: leftPad, vertical: leftPad),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: context.colors.border.withValues(alpha: borderAlpha)),
              ),
              child: Row(
                children: [
                  Container(
                    width: iconSize + 12, height: iconSize + 12,
                    decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(iconSize / 2 + 2)),
                    child: Icon(icon, size: iconSize, color: iconColor),
                  ),
                  SizedBox(width: leftPad - 2),
                  Expanded(
                    child: subtitle != null
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(title, style: TextStyle(color: context.colors.textPrimary, fontSize: fontSize, fontWeight: FontWeight.w500)),
                            Text(subtitle, style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
                          ])
                        : Text(title, style: TextStyle(color: context.colors.textPrimary, fontSize: fontSize, fontWeight: FontWeight.w600)),
                  ),
                  if (nodeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: context.colors.surfaceHighest, borderRadius: BorderRadius.circular(6)),
                      child: Text('$nodeCount', style: TextStyle(color: context.colors.textMuted, fontSize: fontSize - 3)),
                    ),
                  if (onExpand != null) ...[
                    SizedBox(width: leftPad - 6),
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: fontSize + 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (expanded && onExpand != null)
          Padding(
            padding: EdgeInsets.only(left: leftPad + 6, top: 4),
            child: children.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Text('No ${type.toLowerCase()}s', style: TextStyle(color: context.colors.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                  )
                : Column(children: children.cast<Widget>()),
          ),
      ],
    );
  }

  Widget _subjectNode(dynamic subject) {
    final id = subject['id'] as int;
    final expanded = _expandedSubjects.contains(id);
    final children = (_disciplinesCache[id] ?? []).map((d) => _disciplineNode(d)).toList();
    return _buildTreeNode(
      item: subject, type: 'Subject', icon: Icons.book_rounded,
      iconColor: AppColors.primary, iconBg: context.colors.primaryGlow,
      borderRadius: 14, iconSize: 18, fontSize: 14, leftPad: 14, borderAlpha: 1.0,
      expanded: expanded, children: children,
      onExpand: () { if (!expanded) _loadDisciplines(id); setState(() { expanded ? _expandedSubjects.remove(id) : _expandedSubjects.add(id); }); },
    );
  }

  Widget _disciplineNode(dynamic discipline) {
    final id = discipline['id'] as int;
    final expanded = _expandedDisciplines.contains(id);
    final children = (_topicsCache[id] ?? []).map((t) => _topicNode(t)).toList();
    return _buildTreeNode(
      item: discipline, type: 'Discipline', icon: Icons.account_tree_rounded,
      iconColor: context.colors.success, iconBg: context.colors.successMuted,
      borderRadius: 12, iconSize: 15, fontSize: 13, leftPad: 12, borderAlpha: 0.6,
      expanded: expanded, children: children,
      onExpand: () { if (!expanded) _loadTopics(id); setState(() { expanded ? _expandedDisciplines.remove(id) : _expandedDisciplines.add(id); }); },
    );
  }

  Widget _topicNode(dynamic topic) {
    final id = topic['id'] as int;
    final expanded = _expandedTopics.contains(id);
    final diff = topic['difficulty_level']?.toString() ?? '';
    final children = (_subtopicsCache[id] ?? []).map((s) => _subtopicNode(s)).toList();
    return _buildTreeNode(
      item: topic, type: 'Topic', icon: Icons.menu_book_rounded,
      iconColor: context.colors.warning, iconBg: context.colors.warningMuted,
      borderRadius: 10, iconSize: 14, fontSize: 13, leftPad: 12, borderAlpha: 0.4,
      expanded: expanded, children: children, subtitle: diff.isNotEmpty ? diff : null,
      onExpand: () { if (!expanded) _loadSubtopics(id); setState(() { expanded ? _expandedTopics.remove(id) : _expandedTopics.add(id); }); },
    );
  }

  Widget _subtopicNode(dynamic subtopic) {
    final id = subtopic['id'] as int;
    final expanded = _expandedSubtopics.contains(id);
    final children = (_conceptsCache[id] ?? []).map((c) => _conceptNode(c)).toList();
    return _buildTreeNode(
      item: subtopic, type: 'Subtopic', icon: Icons.topic_rounded,
      iconColor: context.colors.info, iconBg: context.colors.infoMuted,
      borderRadius: 8, iconSize: 13, fontSize: 12, leftPad: 10, borderAlpha: 0.3,
      expanded: expanded, children: children,
      onExpand: () { if (!expanded) _loadConcepts(id); setState(() { expanded ? _expandedSubtopics.remove(id) : _expandedSubtopics.add(id); }); },
    );
  }

  Widget _conceptNode(dynamic concept) {
    final title = concept['title'] ?? 'Untitled';
    final diff = concept['difficulty_level']?.toString() ?? '';
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onLongPress: () => _showItemActions(concept, 'Concept'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: context.colors.border.withValues(alpha: 0.2))),
          child: Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: context.colors.primaryGlow, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.lightbulb_rounded, size: 12, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(color: context.colors.textPrimary, fontSize: 12)),
                  if (diff.isNotEmpty) Text(diff, style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorView() {
    return _CmsEditor(
      type: _editingType!,
      item: _editingItem,
      onSave: _saveItem,
      onBack: _exitEditor,
      onDelete: _confirmDelete,
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text('$value', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _CreatePickerSheet extends StatelessWidget {
  final void Function(String type) onPick;

  const _CreatePickerSheet({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final items = [
      const _PickerItem(icon: Icons.book_rounded, label: 'Subject', color: AppColors.primary),
      _PickerItem(icon: Icons.account_tree_rounded, label: 'Discipline', color: context.colors.success),
      _PickerItem(icon: Icons.menu_book_rounded, label: 'Topic', color: context.colors.warning),
      _PickerItem(icon: Icons.topic_rounded, label: 'Subtopic', color: context.colors.info),
      _PickerItem(icon: Icons.lightbulb_rounded, label: 'Concept', color: context.colors.accent),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Create New', style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: item.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(item.icon, size: 18, color: item.color),
            ),
            title: Text(item.label, style: TextStyle(color: context.colors.textPrimary, fontSize: 14)),
            trailing: Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: 18),
            onTap: () => onPick(item.label),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PickerItem {
  final IconData icon;
  final String label;
  final Color color;
  const _PickerItem({required this.icon, required this.label, required this.color});
}

class _CmsEditor extends StatefulWidget {
  final String type;
  final dynamic item;
  final Function(String type, Map<String, dynamic> body, {int? id, int? parentId}) onSave;
  final VoidCallback onBack;
  final Function(String type, int id) onDelete;

  const _CmsEditor({
    required this.type,
    this.item,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
  });

  @override
  State<_CmsEditor> createState() => _CmsEditorState();
}

class _CmsEditorState extends State<_CmsEditor> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  String _difficultyLevel = 'beginner';
  String _color = '#58A6FF';
  String _icon = 'book';

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final item = widget.item;
    final fields = _fieldsForType();
    for (final f in fields) {
      _controllers[f] = TextEditingController(text: item != null ? '${item[f] ?? ''}' : '');
    }
    if (item != null) {
      _difficultyLevel = item['difficulty_level']?.toString() ?? 'beginner';
      _color = item['color']?.toString() ?? '#58A6FF';
      _icon = item['icon']?.toString() ?? 'book';
    }
  }

  List<String> _fieldsForType() {
    switch (widget.type) {
      case 'Subject': return ['title', 'subject_slug', 'description', 'icon', 'color'];
      case 'Discipline': return ['title', 'discipline_slug', 'description', 'order_index'];
      case 'Topic': return ['title', 'description', 'order_index'];
      case 'Subtopic': return ['title', 'description', 'order_index'];
      case 'Concept': return ['title', 'description', 'learning_objectives_text', 'prerequisites_text', 'order_index'];
      default: return ['title', 'description'];
    }
  }

  bool _showDifficulty() => widget.type == 'Topic' || widget.type == 'Subtopic' || widget.type == 'Concept';

  String _labelForField(String f) {
    switch (f) {
      case 'title': return 'Title';
      case 'subject_slug': return 'Subject Slug';
      case 'discipline_slug': return 'Discipline Slug';
      case 'description': return 'Description';
      case 'learning_objectives_text': return 'Learning Objectives';
      case 'prerequisites_text': return 'Prerequisites';
      case 'order_index': return 'Order Index';
      case 'icon': return 'Icon Name';
      case 'color': return 'Color (hex)';
      default: return f;
    }
  }

  bool _isMultiline(String f) => f == 'description' || f == 'learning_objectives_text' || f == 'prerequisites_text';

  Widget _buildDropdown(String label, String value, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: context.colors.surfaceElevated,
                style: TextStyle(color: context.colors.textPrimary),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final body = <String, dynamic>{};
    for (final f in _controllers.keys) {
      final val = _controllers[f]!.text.trim();
      if (f == 'order_index') {
        body[f] = int.tryParse(val) ?? 0;
      } else if (val.isNotEmpty) {
        body[f] = val;
      }
    }
    if (widget.item != null) body['id'] = widget.item['id'];
    if (_showDifficulty()) body['difficulty_level'] = _difficultyLevel;
    if (widget.type == 'Subject') {
      body['color'] = _color;
      body['icon'] = _icon;
    }

    widget.onSave(
      widget.type,
      body,
      id: widget.item?['id'],
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: Text(
          '${isEditing ? "Edit" : "Create"} ${widget.type}',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.white70),
              onPressed: () => widget.onDelete(widget.type, widget.item['id']),
            ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            onPressed: _handleSave,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ..._controllers.keys.map((f) => _buildField(f)),
            if (_showDifficulty()) _buildDropdown('Difficulty Level', _difficultyLevel, [
              const DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
              const DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
              const DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
              const DropdownMenuItem(value: 'expert', child: Text('Expert')),
            ], (v) => setState(() { _difficultyLevel = v ?? 'beginner'; })),
            if (widget.type == 'Subject') _buildDropdown('Icon', _icon, [
              const DropdownMenuItem(value: 'book', child: Text('Book')),
              const DropdownMenuItem(value: 'science', child: Text('Science')),
              const DropdownMenuItem(value: 'calculate', child: Text('Calculator')),
              const DropdownMenuItem(value: 'code', child: Text('Code')),
              const DropdownMenuItem(value: 'eco', child: Text('Economics')),
              const DropdownMenuItem(value: 'psychology', child: Text('Psychology')),
            ], (v) => setState(() { _icon = v ?? 'book'; })),
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Create ${widget.type}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String field) {
    final ctrl = _controllers[field]!;
    final isNumber = field == 'order_index';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_labelForField(field), style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextFormField(
            controller: ctrl,
            maxLines: _isMultiline(field) ? 4 : 1,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter ${_labelForField(field).toLowerCase()}',
              hintStyle: TextStyle(color: context.colors.textMuted),
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) {
              if (field == 'title' && (v == null || v.trim().isEmpty)) return 'Required';
              return null;
            },
          ),
        ],
      ),
    );
  }
}
