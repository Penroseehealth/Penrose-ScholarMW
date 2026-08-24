import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../core/theme/theme_colors.dart';

class ResearchLab extends StatefulWidget {
  const ResearchLab({super.key});

  @override
  State<ResearchLab> createState() => _ResearchLabState();
}

class _ResearchLabState extends State<ResearchLab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ResearchService _researchService = ResearchService();
  List<dynamic> _projects = [];
  List<dynamic> _searchResults = [];
  bool _loadingProjects = true;
  bool _searchingLiterature = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await _researchService.listProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
        _loadingProjects = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Research Intelligence Lab',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.colors.textMuted,
          indicatorColor: AppColors.primary,
          dividerColor: context.colors.border,
          tabs: [
            const Tab(text: 'Projects'),
            const Tab(text: 'Literature'),
            const Tab(text: 'Evidence'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProjectsTab(),
          _buildLiteratureTab(),
          _buildEvidenceTab(),
        ],
      ),
    );
  }

  Widget _buildProjectsTab() {
    return RefreshIndicator(
      onRefresh: _loadProjects,
      color: AppColors.primary,
      backgroundColor: context.colors.surface,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showNewProjectDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Research Project'),
            ),
          ),
          const SizedBox(height: 20),
          if (_loadingProjects)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_projects.isEmpty)
            _buildEmptyState('No projects yet', 'Start a research project to organize your work')
          else
            ...(_projects.map((p) => _buildProjectCard(p))),
        ],
      ),
    );
  }

  Widget _buildLiteratureTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search literature...',
              prefixIcon: Icon(Icons.search_rounded, color: context.colors.textMuted),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                onPressed: _searchLiterature,
              ),
            ),
            onSubmitted: (_) => _searchLiterature(),
          ),
          const SizedBox(height: 16),
          if (_searchingLiterature)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (ctx, i) => _buildLiteratureCard(_searchResults[i]),
              ),
            )
          else
            Expanded(
              child: _buildEmptyState(
                'Search for papers',
                'Find academic literature from multiple sources',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEvidenceTab() {
    return Center(
      child: _buildEmptyState(
        'Evidence Matrix',
        'Build evidence tables from your research',
      ),
    );
  }

  Widget _buildProjectCard(dynamic project) {
    final isActive = project['status'] == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.primaryGlow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.science_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  project['description'] ?? 'No description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? context.colors.successMuted : context.colors.surfaceHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              project['status'] ?? 'draft',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? context.colors.success : context.colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiteratureCard(dynamic paper) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paper['title'] ?? '',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            paper['authors'] ?? '',
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (paper['year'] != null)
                Text(
                  '${paper['year']}',
                  style: TextStyle(fontSize: 12, color: context.colors.info),
                ),
              const SizedBox(width: 8),
              if (paper['source'] != null && (paper['source'] as String).isNotEmpty)
                Text(
                  paper['source'],
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                ),
            ],
          ),
          if (paper['doi'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'DOI: ${paper['doi']}',
              style: TextStyle(fontSize: 11, color: context.colors.accent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 56, color: context.colors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
        ],
      ),
    );
  }

  Future<void> _searchLiterature() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _searchingLiterature = true);
    final results = await _researchService.searchLiterature(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searchingLiterature = false;
      });
    }
  }

  void _showNewProjectDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final rqCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Research Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rqCtrl,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Research Question'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _researchService.createProject({
                'title': titleCtrl.text,
                'description': descCtrl.text,
                'research_question': rqCtrl.text,
              });
              _loadProjects();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
}
