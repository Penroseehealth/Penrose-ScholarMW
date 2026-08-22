import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

class WritingStudio extends StatefulWidget {
  const WritingStudio({super.key});

  @override
  State<WritingStudio> createState() => _WritingStudioState();
}

class _WritingStudioState extends State<WritingStudio>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _collections = [];
  List<Map<String, dynamic>> _citations = [];
  List<Map<String, dynamic>> _sections = [];
  bool _loadingProjects = true;
  bool _loadingCollections = true;
  bool _loadingCitations = false;
  bool _loadingBibliography = false;

  Map<String, dynamic>? _selectedProject;
  Map<String, dynamic>? _selectedSection;
  bool _editingSection = false;
  final TextEditingController _sectionEditorController = TextEditingController();
  int? _selectedCollectionId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProjects();
    _loadCollections();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sectionEditorController.dispose();
    super.dispose();
  }

  // ── Projects ──

  Future<void> _loadProjects() async {
    setState(() => _loadingProjects = true);
    try {
      final response = await _api.get('/writing/projects');
      final data = jsonDecode(response.body)['data'];
      setState(() {
        _projects = List<Map<String, dynamic>>.from(
          data is List ? data : (data?['items'] ?? []),
        );
        _loadingProjects = false;
      });
    } catch (e) {
      setState(() => _loadingProjects = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load projects: $e')),
        );
      }
    }
  }

  Future<void> _openProject(Map<String, dynamic> project) async {
    setState(() {
      _selectedProject = project;
      _selectedSection = null;
      _editingSection = false;
    });
    // Load sections from project detail
    try {
      final response = await _api.get('/writing/projects/${project['id']}');
      final data = jsonDecode(response.body)['data'];
      setState(() {
        _sections = List<Map<String, dynamic>>.from(
          data is List
              ? data
              : (data is Map<String, dynamic>
                  ? (data['sections'] ?? [])
                  : []),
        );
      });
    } catch (e) {
      // sections may come from project directly
      setState(() {
        _sections = List<Map<String, dynamic>>.from(
          project['sections'] ?? [],
        );
      });
    }
  }

  Future<void> _createProject() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Project Title',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              try {
                await _api.post('/writing/projects', body: {
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result == true) {
      _loadProjects();
    }
  }

  // ── Sections ──

  void _openSectionEditor(Map<String, dynamic> section) {
    setState(() {
      _selectedSection = section;
      _editingSection = true;
      _sectionEditorController.text = section['content'] ?? section['body'] ?? '';
    });
  }

  // ── References ──

  Future<void> _loadCollections() async {
    setState(() => _loadingCollections = true);
    try {
      final response = await _api.get('/writing/references/collections');
      final data = jsonDecode(response.body)['data'];
      setState(() {
        _collections = List<Map<String, dynamic>>.from(
          data is List ? data : (data?['items'] ?? []),
        );
        _loadingCollections = false;
      });
    } catch (e) {
      setState(() => _loadingCollections = false);
    }
  }

  Future<void> _loadCitations(int collectionId) async {
    setState(() {
      _loadingCitations = true;
      _selectedCollectionId = collectionId;
    });
    try {
      final response = await _api.get(
        '/writing/references/citations?collection_id=$collectionId',
      );
      final data = jsonDecode(response.body)['data'];
      setState(() {
        _citations = List<Map<String, dynamic>>.from(
          data is List ? data : (data?['items'] ?? []),
        );
        _loadingCitations = false;
      });
    } catch (e) {
      setState(() => _loadingCitations = false);
    }
  }

  Future<void> _addCitation() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final yearController = TextEditingController();
    final doiController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Citation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: authorController,
                decoration: InputDecoration(
                  labelText: 'Author(s)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearController,
                decoration: InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doiController,
                decoration: InputDecoration(
                  labelText: 'DOI (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              try {
                await _api.post('/writing/references/citations', body: {
                  'collection_id': _selectedCollectionId,
                  'title': titleController.text.trim(),
                  'authors': authorController.text.trim(),
                  'year': yearController.text.trim(),
                  'doi': doiController.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add citation: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result == true && _selectedCollectionId != null) {
      _loadCitations(_selectedCollectionId!);
    }
  }

  Future<void> _generateBibliography() async {
    if (_selectedCollectionId == null) return;
    setState(() => _loadingBibliography = true);
    try {
      final response = await _api.post(
        '/writing/references/bibliography',
        body: {'collection_id': _selectedCollectionId},
      );
      if (mounted) {
        final decoded = jsonDecode(response.body);
        final bib = decoded['data']?['bibliography'] ??
            decoded['data']?['text'] ??
            response.body;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Bibliography'),
            content: SingleChildScrollView(
              child: Text(bib.toString(),
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textPrimary, height: 1.6)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate bibliography: $e')),
        );
      }
    } finally {
      setState(() => _loadingBibliography = false);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: _editingSection || _selectedProject != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    if (_editingSection) {
                      _editingSection = false;
                      _selectedSection = null;
                    } else {
                      _selectedProject = null;
                      _sections.clear();
                    }
                  });
                },
              )
            : null,
        title: Text(
          _editingSection
              ? (_selectedSection?['title'] ?? 'Edit Section')
              : _selectedProject != null
                  ? (_selectedProject!['title'] ?? 'Project')
                  : 'Writing Studio',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        bottom: _selectedProject == null && !_editingSection
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'My Projects'),
                  Tab(text: 'References'),
                ],
              )
            : null,
      ),
      body: _editingSection
          ? _buildSectionEditor()
          : _selectedProject != null
              ? _buildProjectDetail()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProjectsTab(),
                    _buildReferencesTab(),
                  ],
                ),
      floatingActionButton: _editingSection
          ? FloatingActionButton.extended(
              onPressed: _showAIAssist,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI Assist'),
            )
          : null,
    );
  }

  // ── Projects Tab ──

  Widget _buildProjectsTab() {
    if (_loadingProjects) return _buildSpinner();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _createProject,
              icon: Icon(Icons.add, color: AppColors.primary),
              label: Text('New Project',
                  style: TextStyle(color: AppColors.primary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _projects.isEmpty
              ? _buildEmptyState(
                  'No Projects Yet',
                  'Start your academic writing journey by creating a new project.',
                  Icons.article_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) =>
                        _buildProjectCard(_projects[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final title = project['title'] ?? 'Untitled';
    final desc = project['description'] ?? '';
    final sectionCount = project['sections_count'] ??
        (project['sections'] as List?)?.length ??
        0;
    final updatedAt = project['updated_at'] ?? project['created_at'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openProject(project),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.article_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.list, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('$sectionCount sections',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  if (updatedAt.toString().isNotEmpty)
                    Text(updatedAt.toString().substring(0, updatedAt.toString().length > 10 ? 10 : updatedAt.toString().length),
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Project Detail ──

  Widget _buildProjectDetail() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('Sections',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddSectionDialog(),
                icon: Icon(Icons.add, size: 18, color: AppColors.primary),
                label: Text('Add',
                    style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _sections.isEmpty
              ? _buildEmptyState(
                  'No Sections',
                  'Add sections to organize your writing.',
                  Icons.format_list_bulleted,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _sections.length,
                  itemBuilder: (context, index) =>
                      _buildSectionCard(_sections[index], index),
                ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section, int index) {
    final title = section['title'] ?? 'Section ${index + 1}';
    final content = section['content'] ?? section['body'] ?? '';
    final wordCount = content.toString().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openSectionEditor(section),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('$wordCount words',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSectionDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Section Title',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _sections.add({'title': result, 'content': '', 'id': DateTime.now().millisecondsSinceEpoch});
      });
    }
  }

  // ── Section Editor ──

  Widget _buildSectionEditor() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedSection?['title'] ?? '',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
              Text(
                '${_sectionEditorController.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TextField(
            controller: _sectionEditorController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: 'Start writing here...',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: TextStyle(
                fontSize: 15, color: AppColors.textPrimary, height: 1.6),
            onChanged: (val) {
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  // ── References Tab ──

  Widget _buildReferencesTab() {
    if (_loadingCollections) return _buildSpinner();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('Collections',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
        if (_collections.isEmpty)
          _buildEmptyState(
            'No Collections',
            'Create a reference collection to get started.',
            Icons.folder_open,
          )
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _collections.length,
              itemBuilder: (context, index) =>
                  _buildCollectionChip(_collections[index]),
            ),
          ),
        if (_selectedCollectionId != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Citations',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addCitation,
                  icon: Icon(Icons.add, size: 18, color: AppColors.primary),
                  label: Text('Add',
                      style: TextStyle(color: AppColors.primary)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed:
                      _loadingBibliography ? null : _generateBibliography,
                  icon: _loadingBibliography
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.format_list_numbered,
                          size: 18, color: AppColors.secondary),
                  label: Text('Bibliography',
                      style: TextStyle(color: AppColors.secondary)),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: _selectedCollectionId == null
              ? Center(
                  child: Text('Select a collection to view citations',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : _loadingCitations
                  ? _buildSpinner()
                  : _citations.isEmpty
                      ? _buildEmptyState(
                          'No Citations',
                          'Add citations to this collection.',
                          Icons.book_outlined,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _citations.length,
                          itemBuilder: (context, index) =>
                              _buildCitationCard(_citations[index]),
                        ),
        ),
      ],
    );
  }

  Widget _buildCollectionChip(Map<String, dynamic> collection) {
    final name = collection['name'] ?? collection['title'] ?? 'Collection';
    final count = collection['citations_count'] ?? collection['count'] ?? 0;
    final isSelected = collection['id'] == _selectedCollectionId;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => _loadCitations(collection['id']),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.folder,
                  color: isSelected ? Colors.white : AppColors.primary,
                  size: 22),
              const SizedBox(height: 8),
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary)),
              const Spacer(),
              Text('$count citations',
                  style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCitationCard(Map<String, dynamic> citation) {
    final title = citation['title'] ?? 'Untitled';
    final authors = citation['authors'] ?? citation['author'] ?? '';
    final year = citation['year'] ?? '';
    final doi = citation['doi'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary)),
            if (authors.toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(authors.toString(),
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            Row(
              children: [
                if (year.toString().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(year.toString(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (doi.toString().isNotEmpty)
                  Expanded(
                    child: Text('DOI: $doi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Assist ──

  void _showAIAssist() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.7,
        minChildSize: 0.25,
        expand: false,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('AI Writing Assist',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Choose an action to improve your writing',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _aiActionTile(
              Icons.spellcheck,
              'Grammar Check',
              'Fix grammar and spelling errors',
              AppColors.error,
            ),
            _aiActionTile(
              Icons.tune,
              'Adjust Tone',
              'Make it more formal, casual, or academic',
              AppColors.primary,
            ),
            _aiActionTile(
              Icons.account_tree,
              'Improve Structure',
              'Reorganize for better flow and clarity',
              AppColors.info,
            ),
            _aiActionTile(
              Icons.expand,
              'Expand',
              'Elaborate on key points with more detail',
              AppColors.success,
            ),
            _aiActionTile(
              Icons.compress,
              'Concise',
              'Remove redundancy and tighten the prose',
              AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiActionTile(
      IconData icon, String title, String subtitle, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title — feature coming soon')),
          );
        },
      ),
    );
  }

  // ── Shared ──

  Widget _buildSpinner() {
    return Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
