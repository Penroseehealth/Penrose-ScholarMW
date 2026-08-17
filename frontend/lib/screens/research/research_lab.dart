import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

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
      appBar: AppBar(
        title: const Text('Research Intelligence Lab'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Projects'),
            Tab(text: 'Literature'),
            Tab(text: 'Evidence'),
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: _showNewProjectDialog,
            icon: const Icon(Icons.add),
            label: const Text('New Research Project'),
          ),
          const SizedBox(height: 16),
          if (_loadingProjects)
            const Center(child: CircularProgressIndicator())
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search literature...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _searchLiterature,
              ),
            ),
            onSubmitted: (_) => _searchLiterature(),
          ),
          const SizedBox(height: 16),
          if (_searchingLiterature)
            const Center(child: CircularProgressIndicator())
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: const Icon(Icons.science, color: AppColors.primary),
        ),
        title: Text(project['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          project['description'] ?? 'No description',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: project['status'] == 'active'
                ? AppColors.success.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            project['status'] ?? 'draft',
            style: TextStyle(
              fontSize: 11,
              color: project['status'] == 'active' ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiteratureCard(dynamic paper) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paper['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              paper['authors'] ?? '',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (paper['year'] != null)
                  Text(
                    '${paper['year']}',
                    style: const TextStyle(fontSize: 12, color: AppColors.info),
                  ),
                const SizedBox(width: 8),
                if (paper['source'] != null && (paper['source'] as String).isNotEmpty)
                  Text(
                    paper['source'],
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
            if (paper['doi'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'DOI: ${paper['doi']}',
                style: const TextStyle(fontSize: 11, color: AppColors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
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
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rqCtrl,
              decoration: const InputDecoration(labelText: 'Research Question'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
