import 'dart:convert';

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
    try {
      final response = await _api.get('/vault/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _documents = data;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    setState(() => _loading = false);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Knowledge Vault',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded, color: AppColors.textSecondary),
            onPressed: _uploadDocument,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search vault...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          SizedBox(
            height: 42,
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
        selected: selected,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceElevated,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        checkmarkColor: Colors.white,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryGlow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc['title'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${doc['doc_type'] ?? ''} ${doc['is_indexed'] == true ? '· Indexed' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (doc['is_indexed'] == true)
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 56, color: AppColors.textMuted.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'No documents yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload lecture notes, textbooks, and research papers',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _uploadDocument,
            icon: const Icon(Icons.upload_rounded),
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
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: docType,
                dropdownColor: AppColors.surfaceHighest,
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final fileBytes = result.files.first.bytes;
                if (fileBytes == null) return;
                final response = await _api.uploadFileBytes(
                  '/vault/upload',
                  fileBytes,
                  result.files.first.name,
                  fields: {
                    'title': titleCtrl.text,
                    'doc_type': docType,
                  },
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        response.statusCode == 200 || response.statusCode == 201
                            ? 'Uploaded: ${titleCtrl.text}'
                            : 'Upload failed (${response.statusCode})',
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
