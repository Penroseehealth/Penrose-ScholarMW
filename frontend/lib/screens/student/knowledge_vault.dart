import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

class KnowledgeVaultScreen extends StatefulWidget {
  const KnowledgeVaultScreen({super.key});

  @override
  State<KnowledgeVaultScreen> createState() => _KnowledgeVaultScreenState();
}

class _KnowledgeVaultScreenState extends State<KnowledgeVaultScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _documents = [];
  bool _loading = true;
  String _searchQuery = '';
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final response = await _api.getWithCache('/vault/');
    if (response != null && response.statusCode == 200) {
      final data = List.from(Map.from({'data': response.body}).values.first);
      setState(() {
        _documents = data;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _documents.where((d) {
      final matchesSearch = _searchQuery.isEmpty ||
          (d['title'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _filterType == 'all' || d['doc_type'] == _filterType;
      return matchesSearch && matchesType;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Knowledge Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploadDocument,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search vault...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('all', 'All'),
                _buildFilterChip('lecture_notes', 'Lecture Notes'),
                _buildFilterChip('textbook', 'Textbooks'),
                _buildFilterChip('past_paper', 'Past Papers'),
                _buildFilterChip('research', 'Research'),
                _buildFilterChip('video', 'Videos'),
                _buildFilterChip('presentation', 'Presentations'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _buildDocumentCard(filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _filterType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textPrimary)),
        selected: selected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.grey.shade100,
        onSelected: (v) => setState(() => _filterType = value),
      ),
    );
  }

  Widget _buildDocumentCard(dynamic doc) {
    final typeIcons = {
      'lecture_notes': Icons.note_outlined,
      'textbook': Icons.menu_book_outlined,
      'past_paper': Icons.assignment_outlined,
      'research': Icons.science_outlined,
      'video': Icons.videocam_outlined,
      'presentation': Icons.slideshow_outlined,
      'pdf': Icons.picture_as_pdf_outlined,
    };
    final icon = typeIcons[doc['doc_type']] ?? Icons.insert_drive_file_outlined;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(
          doc['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          '${doc['doc_type']} ${doc['is_indexed'] == true ? '• Indexed' : ''}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (doc['is_indexed'] == true)
              const Icon(Icons.check_circle, color: AppColors.success, size: 16),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No documents yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(
            'Upload lecture notes, textbooks, and research papers',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _uploadDocument,
            icon: const Icon(Icons.upload),
            label: const Text('Upload Document'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'pptx', 'xlsx'],
    );
    if (result == null || result.files.isEmpty) return;

    final titleCtrl = TextEditingController(text: result.files.first.name);
    String docType = 'lecture_notes';

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Upload Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: docType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'lecture_notes', child: Text('Lecture Notes')),
                  DropdownMenuItem(value: 'textbook', child: Text('Textbook')),
                  DropdownMenuItem(value: 'past_paper', child: Text('Past Paper')),
                  DropdownMenuItem(value: 'research', child: Text('Research')),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                  DropdownMenuItem(value: 'presentation', child: Text('Presentation')),
                ],
                onChanged: (v) => setDialogState(() => docType = v ?? docType),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final response = await _api.post('/vault/upload', body: {
                  'title': titleCtrl.text,
                  'doc_type': docType,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        response.statusCode == 201
                            ? 'Uploaded: ${titleCtrl.text}'
                            : 'Upload failed',
                      ),
                    ),
                  );
                  _loadDocuments();
                }
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
