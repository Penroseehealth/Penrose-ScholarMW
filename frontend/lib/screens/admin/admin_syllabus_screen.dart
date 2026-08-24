import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/services.dart';

const Color _bioGreen = Color(0xFF10B981);

class AdminSyllabusScreen extends StatefulWidget {
  const AdminSyllabusScreen({super.key});

  @override
  State<AdminSyllabusScreen> createState() => _AdminSyllabusScreenState();
}

class _AdminSyllabusScreenState extends State<AdminSyllabusScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  String _selectedSubject = '';
  List<dynamic> _subjects = [];
  Map<String, dynamic>? _syllabusTree;
  int? _expandedCE;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/syllabus/subjects');
      if (res.statusCode == 200) {
        _subjects = jsonDecode(res.body);
        if (_subjects.isNotEmpty) {
          _selectedSubject = _subjects[0]['slug'];
          await _loadTree();
        } else {
          _loading = false;
        }
      } else {
        _error = 'Failed to load subjects (${res.statusCode})';
        _loading = false;
      }
    } catch (e) {
      _error = 'Failed to load subjects: $e';
      _loading = false;
    }
  }

  Future<void> _loadTree() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/syllabus/subjects/$_selectedSubject/tree');
      if (res.statusCode == 200) {
        _syllabusTree = jsonDecode(res.body);
      } else {
        _error = 'Failed to load syllabus tree (${res.statusCode})';
      }
    } catch (e) {
      _error = 'Failed to load syllabus tree: $e';
    }
    setState(() => _loading = false);
  }

  Future<void> _createSubject() async {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title: const Text('Create Syllabus Subject',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(nameCtrl, 'Subject Name'),
            const SizedBox(height: 12),
            _buildDialogField(slugCtrl, 'Slug (e.g. biology)'),
            const SizedBox(height: 12),
            _buildDialogField(descCtrl, 'Description', maxLines: 2),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final res = await _api.post('/syllabus/admin/subjects', body: {
                'name': nameCtrl.text.trim(),
                'slug': slugCtrl.text.trim(),
                'description': descCtrl.text.trim(),
              });
              if (res.statusCode == 200 || res.statusCode == 201) {
                if (ctx.mounted) Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _bioGreen),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _loadSubjects();
    }
  }

  Future<void> _createTopic(int coreElementId) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: '3');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title: const Text('Add Topic', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(titleCtrl, 'Topic Title'),
            const SizedBox(height: 12),
            _buildDialogField(descCtrl, 'Description', maxLines: 2),
            const SizedBox(height: 12),
            _buildDialogField(yearCtrl, 'Year Level (3 or 4)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final res = await _api.post('/syllabus/admin/topics', body: {
                'core_element_id': coreElementId,
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'year_level': int.tryParse(yearCtrl.text) ?? 3,
              });
              if (res.statusCode == 200 || res.statusCode == 201) {
                if (ctx.mounted) Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _bioGreen),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _loadTree();
    }
  }

  Future<void> _deleteTopic(int topicId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title: const Text('Delete Topic', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete the topic and all its subtopics and learning objectives.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _api.delete('/syllabus/admin/topics/$topicId');
      await _loadTree();
    }
  }

  Future<void> _deleteSubtopic(int subId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title:
            const Text('Delete Subtopic', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete the subtopic and its learning objectives.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _api.delete('/syllabus/admin/subtopics/$subId');
      await _loadTree();
    }
  }

  Future<void> _deleteLO(int loId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title: const Text('Delete Learning Objective',
            style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _api.delete('/syllabus/admin/learning-objectives/$loId');
      await _loadTree();
    }
  }

  Widget _buildDialogField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _bioGreen),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1623),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/admin'),
        ),
        title: const Text('Syllabus Management',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: _bioGreen),
            onPressed: _createSubject,
            tooltip: 'Create Subject',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _bioGreen))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48,
                          color: Colors.redAccent.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSubjects,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildSubjectSelector(),
                    Expanded(child: _buildSyllabusBody()),
                  ],
                ),
    );
  }

  Widget _buildSubjectSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF0F1623),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: _bioGreen, size: 20),
          const SizedBox(width: 10),
          const Text('Subject:',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          ..._subjects.map((s) {
            final selected = _selectedSubject == s['slug'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s['name'],
                    style: const TextStyle(fontSize: 13)),
                selected: selected,
                onSelected: (_) {
                  setState(() => _selectedSubject = s['slug']);
                  _loadTree();
                },
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                selectedColor: _bioGreen,
                labelStyle:
                    TextStyle(color: selected ? Colors.white : Colors.white70),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSyllabusBody() {
    if (_syllabusTree == null) {
      return Center(
        child: Text('No syllabus data',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      );
    }
    final versions = _syllabusTree!['versions'] as List? ?? [];
    if (versions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded,
                size: 48, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text('No syllabus versions found',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
      );
    }
    final version = versions[0];
    final coreElements = version['core_elements'] as List? ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: coreElements.length,
      itemBuilder: (_, i) {
        final ce = coreElements[i];
        final expanded = _expandedCE == i;
        return _coreElementCard(ce, i, expanded);
      },
    );
  }

  Widget _coreElementCard(Map<String, dynamic> ce, int index, bool expanded) {
    final topics = ce['topics'] as List? ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expanded
              ? _bioGreen.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              _expandedCE = expanded ? null : index;
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _bioGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('${ce['number']}',
                          style: const TextStyle(
                              color: _bioGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(ce['name'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _bioGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${topics.length} topics',
                        style: TextStyle(
                            color: _bioGreen.withValues(alpha: 0.8),
                            fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded,
                        color: _bioGreen.withValues(alpha: 0.6), size: 20),
                    onPressed: () => _createTopic(ce['id']),
                    tooltip: 'Add Topic',
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            ...topics.map((t) => _topicCard(t)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _topicCard(Map<String, dynamic> topic) {
    final subs = topic['subtopics'] as List? ?? [];
    final topicId = topic['id'];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Icon(Icons.bookmark_rounded,
                    color: _bioGreen.withValues(alpha: 0.7), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(topic['title'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                Text('${subs.length} subtopics',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11)),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent.withValues(alpha: 0.5),
                      size: 18),
                  onPressed: () => _deleteTopic(topicId),
                  tooltip: 'Delete Topic',
                ),
              ],
            ),
          ),
          ...subs.map((sub) => _subtopicTile(sub)),
        ],
      ),
    );
  }

  Widget _subtopicTile(Map<String, dynamic> sub) {
    final los = sub['learning_objectives'] as List? ?? [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 4, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 6, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(sub['title'] ?? '',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13)),
              ),
              Text('${los.length} L.O.s',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10)),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: Colors.redAccent.withValues(alpha: 0.4), size: 14),
                onPressed: () => _deleteSubtopic(sub['id']),
                tooltip: 'Delete Subtopic',
              ),
            ],
          ),
          ...los.map((lo) => Padding(
                padding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
                child: Row(
                  children: [
                    Icon(Icons.circle,
                        size: 4,
                        color: _cognitiveColor(lo['cognitive_level'])),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(lo['objective'] ?? '',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _cognitiveColor(lo['cognitive_level'])
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(lo['cognitive_level'] ?? '',
                          style: TextStyle(
                              color: _cognitiveColor(lo['cognitive_level']),
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: Colors.redAccent.withValues(alpha: 0.3),
                          size: 12),
                      onPressed: () => _deleteLO(lo['id']),
                      tooltip: 'Delete L.O.',
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Color _cognitiveColor(String? level) {
    if (level == null) return Colors.white54;
    if (level.contains('Knowledge')) return Colors.blue;
    if (level.contains('Comprehension')) return Colors.teal;
    if (level.contains('Application')) return _bioGreen;
    if (level.contains('Analysis')) return Colors.orange;
    if (level.contains('Evaluation')) return Colors.purple;
    if (level.contains('Practical')) return Colors.red;
    return Colors.white54;
  }
}
