import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

class MalawiContextScreen extends StatefulWidget {
  const MalawiContextScreen({super.key});

  @override
  State<MalawiContextScreen> createState() => _MalawiContextScreenState();
}

class _MalawiContextScreenState extends State<MalawiContextScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _queryCtrl = TextEditingController();

  List<dynamic> _layers = [];
  bool _loading = true;
  bool _querying = false;

  dynamic _selectedLayer;
  List<dynamic> _layerDocuments = [];
  bool _loadingDocs = false;

  @override
  void initState() {
    super.initState();
    _loadLayers();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLayers() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/api/v1/malawi-context/layers');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded is List
            ? decoded
            : (decoded['layers'] ?? decoded['data'] ?? []);
        setState(() {
          _layers = List.from(data);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openLayer(dynamic layer) async {
    setState(() {
      _selectedLayer = layer;
      _loadingDocs = true;
    });
    try {
      final id = layer['id'] ?? layer['layer_id'];
      final response =
          await _api.get('/api/v1/malawi-context/layers/$id/documents');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final docs = decoded is List
            ? decoded
            : (decoded['documents'] ?? decoded['data'] ?? []);
        setState(() {
          _layerDocuments = List.from(docs);
          _loadingDocs = false;
        });
      } else {
        setState(() => _loadingDocs = false);
      }
    } catch (e) {
      setState(() => _loadingDocs = false);
    }
  }

  Future<void> _queryKnowledge() async {
    final question = _queryCtrl.text.trim();
    if (question.isEmpty) return;

    Navigator.pop(context);
    setState(() {
      _querying = true;
    });

    try {
      final layerType = _selectedLayer?['layer_type'] ?? '';
      final response =
          await _api.post('/api/v1/malawi-context/query', body: {
        'question': question,
        'layer_type': layerType,
      });
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final results = decoded is List
            ? decoded
            : (decoded['results'] ?? decoded['documents'] ?? []);
        if (mounted) {
          _showResultsDialog(question, List.from(results));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Query failed. Please try again.')),
        );
      }
    } finally {
      setState(() => _querying = false);
    }
  }

  void _showResultsDialog(String query, List<dynamic> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Results for "$query"',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${results.length} document${results.length == 1 ? '' : 's'} found',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'No matching documents found',
                        style: TextStyle(
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: results.length,
                      itemBuilder: (ctx, i) => _buildResultCard(results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(dynamic doc) {
    final title = doc['title'] ?? doc['name'] ?? 'Untitled';
    final docType = doc['doc_type'] ?? doc['type'] ?? '';
    final snippet = doc['snippet'] ?? doc['summary'] ?? '';
    final source = doc['source'] ?? doc['layer_type'] ?? '';
    final score = doc['score'] ?? doc['relevance'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (score != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(score is num ? (score * 100).round() : score)}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (docType.toString().isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      docType.toString().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                if (source.toString().isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Source: $source',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (snippet.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                snippet,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedLayer = null;
      _layerDocuments = [];
    });
  }

  Color _layerColor(String? type) {
    switch (type) {
      case 'national':
        return AppColors.primary;
      case 'university':
        return AppColors.accent;
      case 'faculty':
        return AppColors.secondary;
      case 'department':
        return Colors.teal;
      case 'course':
        return Colors.indigo;
      case 'personal':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _layerIcon(String? type) {
    switch (type) {
      case 'national':
        return Icons.flag_outlined;
      case 'university':
        return Icons.account_balance_outlined;
      case 'faculty':
        return Icons.school_outlined;
      case 'department':
        return Icons.business_outlined;
      case 'course':
        return Icons.menu_book_outlined;
      case 'personal':
        return Icons.person_outline;
      default:
        return Icons.layers_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedLayer != null
              ? (_selectedLayer!['name'] ?? 'Layer Documents')
              : 'Malawi Academic Context',
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: _selectedLayer != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearSelection,
              )
            : null,
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _querying
            ? null
            : () => _showQuerySheet(context),
        backgroundColor: _querying ? AppColors.textSecondary : AppColors.primary,
        icon: _querying
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.search, color: Colors.white),
        label: Text(
          _querying ? 'Searching...' : 'Query Knowledge',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _selectedLayer != null ? _buildLayerDetail() : _buildLayersList(),
    );
  }

  Widget _buildLayersList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_layers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No knowledge layers found',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Layers are built from your academic context',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLayers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'KNOWLEDGE LAYERS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Academic knowledge organized by institutional hierarchy',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ..._layers.map((layer) => _buildLayerCard(layer)),
        ],
      ),
    );
  }

  Widget _buildLayerCard(dynamic layer) {
    final name = layer['name'] ?? 'Unknown Layer';
    final type = layer['layer_type'] ?? layer['type'] ?? 'unknown';
    final docCount = layer['document_count'] ?? layer['doc_count'] ?? 0;
    final color = _layerColor(type);
    final icon = _layerIcon(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        onTap: () => _openLayer(layer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            type.toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$docCount documents',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerDetail() {
    if (_loadingDocs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_layerDocuments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No documents in this layer',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _layerDocuments.length,
      itemBuilder: (ctx, i) => _buildDocumentCard(_layerDocuments[i]),
    );
  }

  Widget _buildDocumentCard(dynamic doc) {
    final title = doc['title'] ?? doc['name'] ?? 'Untitled';
    final docType = doc['doc_type'] ?? doc['type'] ?? 'document';
    final snippet = doc['snippet'] ?? doc['summary'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                docType.toString().toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
            if (snippet.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                snippet,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showQuerySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Query Knowledge Base',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedLayer != null
                  ? 'Searching in: ${_selectedLayer!['name'] ?? 'selected layer'}'
                  : 'Search across all academic layers',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _queryCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. What is covered in ICT101?',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onSubmitted: (_) => _queryKnowledge(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _queryKnowledge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Search'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
