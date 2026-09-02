import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../modules/subject_module.dart';
import '../../services/services.dart';

class StemSyllabusScreen extends StatefulWidget {
  final String slug;
  final String title;

  const StemSyllabusScreen({super.key, required this.slug, this.title = ''});

  @override
  State<StemSyllabusScreen> createState() => _StemSyllabusScreenState();
}

class _StemSyllabusScreenState extends State<StemSyllabusScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  String _subjectName = '';
  List<Map<String, dynamic>> _forms = [];
  String _searchQuery = '';
  late TabController _tabCtrl;
  int _selectedForm = 0;

  final Map<int, IconData> _formIcons = {
    1: Icons.looks_one_rounded,
    2: Icons.looks_two_rounded,
    3: Icons.looks_3_rounded,
    4: Icons.looks_4_rounded,
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _selectedForm = _tabCtrl.index);
      }
    });
    _loadSyllabus();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Color get _accentColor {
    final module = SubjectModule.fromSlug(widget.slug);
    return module?.color ?? AppColors.primary;
  }

  Future<void> _loadSyllabus() async {
    try {
      final res = await _api.get('/syllabus/subjects/${widget.slug}/tree');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final subject = data['subject'] as Map<String, dynamic>? ?? {};
        _subjectName = subject['name'] as String? ?? widget.slug;

        final versions = data['versions'] as List? ?? [];
        final currentVersion = versions.cast<Map<String, dynamic>>().firstWhere(
              (v) => v['is_current'] == true,
              orElse: () => versions.isNotEmpty ? versions.last as Map<String, dynamic> : {},
            );

        final coreElements = currentVersion['core_elements'] as List? ?? [];
        final formsMap = <int, Map<String, dynamic>>{};

        for (final ce in coreElements) {
          final ceData = ce as Map<String, dynamic>;
          final topics = ceData['topics'] as List? ?? [];

          for (final topic in topics) {
            final t = topic as Map<String, dynamic>;
            final yearLevel = t['year_level'] as int? ?? 1;

            formsMap.putIfAbsent(yearLevel, () {
              return {
                'form': 'Form $yearLevel',
                'year_level': yearLevel,
                'themes': <Map<String, dynamic>>[],
              };
            });

            final formEntry = formsMap[yearLevel]!;
            final themes = formEntry['themes'] as List<Map<String, dynamic>>;

            var themeEntry = themes
                .cast<Map<String, dynamic>>()
                .where(
                  (t) => t['name'] == ceData['name'],
                )
                .firstOrNull;

            if (themeEntry == null) {
              themeEntry = {
                'name': ceData['name'] as String,
                'number': ceData['number'] as int? ?? 0,
                'description': (ceData['description'] as String?) ?? '',
                'topics': <Map<String, dynamic>>[],
              };
              themes.add(themeEntry);
            }

            final topicEntry = {
              'title': t['title'] as String? ?? '',
              'description': (t['description'] as String?) ?? '',
              'subtopics': (t['subtopics'] as List? ?? []).map<Map<String, dynamic>>((s) {
                final sub = s as Map<String, dynamic>;
                return {
                  'title': sub['title'] as String? ?? '',
                  'description': (sub['description'] as String?) ?? '',
                  'learning_objectives': (sub['learning_objectives'] as List? ?? []).map<Map<String, dynamic>>((lo) {
                    final loData = lo as Map<String, dynamic>;
                    return {
                      'objective': loData['objective'] as String? ?? '',
                      'description': (loData['description'] as String?) ?? '',
                      'cognitive_level': (loData['cognitive_level'] as String?) ?? 'Knowledge',
                      'teaching_activity': (loData['teaching_activity'] as String?) ?? '',
                      'teaching_method': (loData['teaching_method'] as String?) ?? '',
                    };
                  }).toList(),
                };
              }).toList(),
              'resources': [],
            };

            (themeEntry!['topics'] as List<Map<String, dynamic>>).add(topicEntry);
          }
        }

        final sortedForms = formsMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

        setState(() {
          _forms = sortedForms.map((e) => e.value).toList();
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted)
      setState(() {
        _loading = false;
        _error = 'Failed to load syllabus';
      });
  }

  List<Map<String, dynamic>> get _filteredThemes {
    if (_forms.isEmpty) return [];
    final form = _selectedForm < _forms.length ? _forms[_selectedForm] : _forms.first;
    final themes = form['themes'] as List? ?? [];
    if (_searchQuery.isEmpty) return themes.cast<Map<String, dynamic>>();
    final q = _searchQuery.toLowerCase();
    return themes.cast<Map<String, dynamic>>().where((theme) {
      if (theme['name'].toString().toLowerCase().contains(q)) return true;
      final topics = theme['topics'] as List? ?? [];
      for (final t in topics) {
        if (t['title'].toString().toLowerCase().contains(q)) return true;
        final subs = t['subtopics'] as List? ?? [];
        for (final s in subs) {
          if (s['title'].toString().toLowerCase().contains(q)) return true;
        }
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.surface,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.colors.textPrimary, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 22, color: _accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _subjectName.isNotEmpty
                      ? '$_subjectName Syllabus'
                      : widget.title.isNotEmpty
                          ? '${widget.title} Syllabus'
                          : 'Syllabus',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          bottom: _forms.isNotEmpty
              ? TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: _accentColor,
                  unselectedLabelColor: context.colors.textMuted,
                  indicatorColor: _accentColor,
                  tabs: List.generate(4, (i) {
                    final formNum = i + 1;
                    final form = _forms.firstWhere(
                      (f) => f['year_level'] == formNum,
                      orElse: () => {},
                    );
                    final count = (form['themes'] as List? ?? []).length;
                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_formIcons[formNum], size: 16),
                          const SizedBox(width: 6),
                          Text('Form $formNum'),
                          if (count > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                )
              : null,
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: _accentColor))
            : _error != null
                ? _buildErrorState()
                : _forms.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          _buildSearchBar(),
                          Expanded(child: _buildThemesList()),
                        ],
                      ),
      );

  Widget _buildErrorState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: context.colors.error.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(fontSize: 16, color: context.colors.textPrimary)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadSyllabus();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );

  Widget _buildSearchBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search themes, topics, subtopics...',
            hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.colors.textMuted),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: Icon(Icons.close_rounded, size: 18, color: context.colors.textMuted),
                  )
                : null,
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
              borderSide: BorderSide(color: _accentColor),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      );

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 64, color: context.colors.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              '${widget.title.isNotEmpty ? widget.title : _subjectName} Syllabus',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'The Malawi MSCE syllabus\nwill appear here once available.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
            ),
          ],
        ),
      );

  Widget _buildThemesList() {
    final themes = _filteredThemes;
    if (themes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: context.colors.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'No content for this form yet',
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: themes.length,
      itemBuilder: (ctx, i) => _ThemeCard(
        theme: themes[i],
        formNumber: _selectedForm + 1,
        accentColor: _accentColor,
      ),
    );
  }
}

class _ThemeCard extends StatefulWidget {
  final Map<String, dynamic> theme;
  final int formNumber;
  final Color accentColor;

  const _ThemeCard({required this.theme, required this.formNumber, required this.accentColor});

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final name = (widget.theme['name'] ?? '') as String;
    final description = (widget.theme['description'] ?? '') as String;
    final topics = widget.theme['topics'] as List? ?? [];
    final number = widget.theme['number'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: widget.accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textMuted.withValues(alpha: 0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${topics.length} topic${topics.length != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: context.colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: context.colors.border),
            ...topics.map<Widget>((t) => _TopicTile(topic: t as Map<String, dynamic>, accentColor: widget.accentColor)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _TopicTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final Color accentColor;

  const _TopicTile({required this.topic, required this.accentColor});

  @override
  State<_TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<_TopicTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final title = (widget.topic['title'] ?? '') as String;
    final description = (widget.topic['description'] ?? '') as String;
    final subtopics = widget.topic['subtopics'] as List? ?? [];

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.folder_open_rounded : Icons.folder_rounded,
                  size: 18,
                  color: widget.accentColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (description.isNotEmpty && _expanded) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(fontSize: 11, color: context.colors.textMuted.withValues(alpha: 0.8)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (subtopics.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${subtopics.length}',
                      style: TextStyle(fontSize: 9, color: context.colors.textMuted),
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: context.colors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...subtopics
              .map<Widget>((s) => _SubtopicTile(subtopic: s as Map<String, dynamic>, accentColor: widget.accentColor)),
      ],
    );
  }
}

class _SubtopicTile extends StatefulWidget {
  final Map<String, dynamic> subtopic;
  final Color accentColor;

  const _SubtopicTile({required this.subtopic, required this.accentColor});

  @override
  State<_SubtopicTile> createState() => _SubtopicTileState();
}

class _SubtopicTileState extends State<_SubtopicTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final title = (widget.subtopic['title'] ?? '') as String;
    final los = widget.subtopic['learning_objectives'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 14),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                    ),
                  ),
                  if (los.isNotEmpty)
                    Text(
                      '${los.length} LO',
                      style: TextStyle(
                        fontSize: 9,
                        color: context.colors.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16,
                    color: context.colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...los.map<Widget>((lo) => _LearningObjectiveCard(lo: lo as Map<String, dynamic>)),
        ],
      ),
    );
  }
}

class _LearningObjectiveCard extends StatelessWidget {
  final Map<String, dynamic> lo;

  const _LearningObjectiveCard({required this.lo});

  @override
  Widget build(BuildContext context) {
    final objective = (lo['objective'] ?? '') as String;
    final cognitiveLevel = (lo['cognitive_level'] ?? 'Knowledge') as String;
    final teachingActivity = (lo['teaching_activity'] ?? '') as String;
    final teachingMethod = (lo['teaching_method'] ?? '') as String;

    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 0, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _cognitiveColor(cognitiveLevel).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cognitiveLevel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _cognitiveColor(cognitiveLevel),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _containsLatex(objective)
                    ? _buildLatexText(objective)
                    : Text(
                        objective,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textPrimary,
                          height: 1.4,
                        ),
                      ),
              ),
            ],
          ),
          if (teachingActivity.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.school_rounded, size: 12, color: context.colors.textMuted.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    teachingActivity,
                    style: TextStyle(fontSize: 10, color: context.colors.textMuted.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ],
          if (teachingMethod.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.build_rounded, size: 12, color: context.colors.textMuted.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    teachingMethod,
                    style: TextStyle(fontSize: 10, color: context.colors.textMuted.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _containsLatex(String text) =>
      text.contains('\\') ||
      text.contains('\$') ||
      text.contains('\u00B2') ||
      text.contains('\u00B3') ||
      text.contains('\u221A') ||
      text.contains('\u222B') ||
      text.contains('\u2211') ||
      text.contains('\u03C0') ||
      text.contains('\u03B8');

  Widget _buildLatexText(String text) {
    try {
      return Math.tex(
        text,
        textStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        mathStyle: MathStyle.text,
        onErrorFallback: (err) => Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
      );
    } catch (_) {
      return Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      );
    }
  }

  Color _cognitiveColor(String level) {
    switch (level.toLowerCase()) {
      case 'knowledge':
        return const Color(0xFF3B82F6);
      case 'comprehension':
        return const Color(0xFF10B981);
      case 'application':
        return const Color(0xFFF59E0B);
      case 'analysis':
        return const Color(0xFFEF4444);
      case 'evaluation':
        return const Color(0xFF8B5CF6);
      case 'synthesis':
        return const Color(0xFFEC4899);
      default:
        return AppColors.textMuted;
    }
  }
}
