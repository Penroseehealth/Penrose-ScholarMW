import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../core/theme/theme_colors.dart';

class KnowledgeVaultScreen extends StatefulWidget {
  KnowledgeVaultScreen({super.key});

  @override
  State<KnowledgeVaultScreen> createState() => _KnowledgeVaultScreenState();
}

class _KnowledgeVaultScreenState extends State<KnowledgeVaultScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _documents = [];
  int _fileCount = 0;
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
          _fileCount = data.length;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _downloadFile(dynamic doc) async {
    final fileId = doc['id'];
    if (fileId == null) return;
    final url = '/api/v1/vault/$fileId/download';
    final uri = Uri.base.resolve(url);
    globalContext.callMethodVarArgs('open'.toJS, [uri.toString().toJS, '_blank'.toJS]);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Knowledge Vault',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              '$_fileCount files',
              style: TextStyle(fontSize: 12, color: context.colors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file_rounded, color: context.colors.textSecondary),
            onPressed: _uploadDocument,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search vault...',
                prefixIcon: Icon(Icons.search_rounded, color: context.colors.textMuted),
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
          SizedBox(height: 8),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
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
            color: selected ? Colors.white : context.colors.textSecondary,
          ),
        ),
        selected: selected,
        selectedColor: AppColors.primary,
        backgroundColor: context.colors.surfaceElevated,
        side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.borderLight),
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
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: context.colors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${doc['file_name'] ?? doc['title'] ?? 'Unknown'} ${doc['file_size'] != null ? '� ${_formatFileSize(doc['file_size'])}' : ''} ${doc['is_indexed'] == true ? '� Indexed' : ''}',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          if (doc['is_indexed'] == true)
            Icon(Icons.check_circle_rounded, color: context.colors.success, size: 18),
          SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.download_rounded, color: AppColors.primary, size: 20),
            onPressed: () => _downloadFile(doc),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 56, color: context.colors.textMuted.withOpacity(0.3)),
          SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
          ),
          SizedBox(height: 6),
          Text(
            'Upload lecture notes, textbooks, and research papers',
            style: TextStyle(fontSize: 13, color: context.colors.textMuted),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _uploadDocument,
            icon: Icon(Icons.upload_rounded),
            label: Text('Upload Document'),
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
          title: Text('Upload Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(labelText: 'Title'),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: docType,
                dropdownColor: context.colors.surfaceHighest,
                decoration: InputDecoration(labelText: 'Type'),
                items: [
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
              child: Text('Cancel'),
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
                    'file_name': result.files.first.name,
                    'file_size': result.files.first.size?.toString() ?? '',
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
              child: Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
