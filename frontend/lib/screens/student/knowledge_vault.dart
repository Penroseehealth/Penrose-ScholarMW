import 'dart:convert';
import 'dart:js_interop';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/services.dart';
import 'vault_video_player_screen.dart';

class KnowledgeVaultScreen extends StatefulWidget {
  const KnowledgeVaultScreen({super.key});

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

  static String _fileName(dynamic doc) => (doc['file_name'] as String?) ?? (doc['title'] as String?) ?? 'document';

  static String _mimeType(dynamic doc) => (doc['mime_type'] as String?) ?? 'application/octet-stream';

  /// Opens a protected file by fetching its bytes with the bearer token.
  ///
  /// Videos play inline through a dedicated player (a bare Blob URL opened in a
  /// new tab would just show a blank/download). Everything else streams through
  /// a Blob URL in a new tab so the browser can render PDFs, images, docs, etc.
  /// without leaking the token in the URL.
  Future<void> _openDocument(dynamic doc) async {
    final fileId = doc['id'];
    if (fileId == null) return;
    final bytes = await _api.downloadBytes('/vault/$fileId/download');
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
      return;
    }
    if (!kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Open is available on the web build')),
        );
      }
      return;
    }
    final mime = _mimeType(doc);
    if (_isVideo(mime, _fileName(doc))) {
      _openVideoPlayer(bytes, mime, doc);
      return;
    }
    _openBlobInNewTab(bytes, mime);
  }

  static bool _isVideo(String mime, String filename) {
    if (mime.startsWith('video/')) return true;
    final name = filename.toLowerCase();
    return const ['mp4', 'webm', 'mov', 'mkv', 'avi'].any(name.endsWith);
  }

  /// Creates a Blob URL for the video bytes and opens an inline player.
  void _openVideoPlayer(Uint8List bytes, String mime, dynamic doc) {
    final jsArray = bytes.toJS;
    final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VaultVideoPlayerScreen(
          videoUrl: url,
          title: (doc['title'] ?? 'Video') as String,
        ),
      ),
    );
    // Best-effort cleanup so the blob URL does not linger indefinitely.
    Future.delayed(const Duration(minutes: 10), () {
      web.URL.revokeObjectURL(url);
    });
  }

  /// Opens auth-fetched bytes via a Blob URL in a new tab. Browsers render
  /// PDFs, images and common documents directly from the Blob URL.
  void _openBlobInNewTab(Uint8List bytes, String mime) {
    final jsArray = bytes.toJS;
    final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
    Future.delayed(const Duration(seconds: 30), () {
      web.URL.revokeObjectURL(url);
    });
  }

  Future<void> _deleteDocument(dynamic doc) async {
    final fileId = doc['id'];
    if (fileId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document'),
        content: Text('Delete "${doc['title']}" from your vault?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final response = await _api.delete('/vault/$fileId');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.statusCode == 204 ? 'Deleted' : 'Delete failed (${response.statusCode})',
          ),
        ),
      );
      _loadDocuments();
    }
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
      final matchesSearch =
          _searchQuery.isEmpty || ((d['title'] ?? '') as String).toLowerCase().contains(_searchQuery.toLowerCase());
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
            const Text(
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
            icon: Icon(Icons.document_scanner_rounded, color: context.colors.textSecondary),
            tooltip: 'Scan & analyse a document',
            onPressed: () => context.go('/ocr-scan'),
          ),
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

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDocument(doc),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (doc['title'] ?? '') as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fileName(doc)} ${doc['file_size'] != null ? '\u00B7 ${_formatFileSize(doc['file_size'] as int)}' : ''} ${doc['is_indexed'] == true ? '\u00B7 Indexed' : ''}',
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (doc['is_indexed'] == true) Icon(Icons.check_circle_rounded, color: context.colors.success, size: 18),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Open',
                icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 20),
                onPressed: () => _openDocument(doc),
              ),
              PopupMenuButton<String>(
                color: context.colors.surfaceHighest,
                onSelected: (v) {
                  if (v == 'delete') _deleteDocument(doc);
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 56, color: context.colors.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No documents yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload lecture notes, textbooks, and research papers',
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
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

  Future<void> _uploadDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'docx',
        'txt',
        'pptx',
        'xlsx',
        'csv',
        'jpg',
        'png',
        'mp4',
        'webm',
        'mov',
        'mkv',
        'avi'
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final titleCtrl = TextEditingController(text: picked.name);
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
                style: TextStyle(color: context.colors.textPrimary),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: docType,
                dropdownColor: context.colors.surfaceHighest,
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
                List<int> fileBytes;
                try {
                  fileBytes = picked.bytes ?? await picked.xFile.readAsBytes();
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not read the selected file.')),
                    );
                  }
                  return;
                }
                final response = await _api.uploadFileBytes(
                  '/vault/upload',
                  fileBytes,
                  picked.name,
                  fields: {
                    'title': titleCtrl.text,
                    'doc_type': docType,
                    'file_name': picked.name,
                    'file_size': picked.size.toString(),
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
