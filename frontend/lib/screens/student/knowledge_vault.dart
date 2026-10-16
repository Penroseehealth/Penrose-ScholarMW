import 'dart:async';
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

/// Pipeline states a vault document moves through after upload.
enum TaskStatus { uploading, uploaded, extracting, ocrProcessing, indexing, ready, failed }

/// In-flight upload/extraction task for a single picked file.
class _UploadTask {
  final String name;
  final int size;
  List<int> bytes;
  String title;
  String docType;
  TaskStatus status;
  int sent;
  int total;
  double progress;
  int? docId;
  String? error;
  bool cancelled;
  bool processing;

  _UploadTask({required this.name, required this.size, required this.bytes, this.title = ''})
      : docType = 'lecture_notes',
        status = TaskStatus.uploading,
        sent = 0,
        total = size,
        progress = 0,
        cancelled = false,
        processing = false;
}

class KnowledgeVaultScreen extends StatefulWidget {
  const KnowledgeVaultScreen({super.key});

  @override
  State<KnowledgeVaultScreen> createState() => _KnowledgeVaultScreenState();
}

class _KnowledgeVaultScreenState extends State<KnowledgeVaultScreen> {
  final ApiService _api = ApiService();
  final VaultService _vault = VaultService();
  List<dynamic> _documents = [];
  List<_UploadTask> _tasks = [];
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
            onPressed: _pickAndUpload,
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
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      if (_tasks.isNotEmpty) ...[
                        _buildUploadPanelTitle(),
                        ..._tasks.map((t) => _buildUploadTaskCard(t)),
                        const SizedBox(height: 12),
                      ],
                      if (filtered.isEmpty) _buildEmptyState() else ...filtered.map((d) => _buildDocumentCard(d)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPanelTitle() {
    final active = _tasks.where((t) => !t.cancelled && (t.processing || t.status == TaskStatus.uploading)).length;
    final label = active > 0 ? 'Uploading $active of ${_tasks.length}...' : 'Recent uploads';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.colors.textSecondary),
          ),
          const Spacer(),
          if (active > 0)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadTaskCard(_UploadTask task) {
    final isIdle = task.cancelled;
    final (color, statusLabel) = _taskStatusAppearance(task);
    final leadingIcon = isIdle ? Icons.cancel_outlined : _taskLeadingIcon(task);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isIdle ? context.colors.borderLight : color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(leadingIcon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title.isEmpty ? task.name : task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(task.size),
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                    ),
                  ],
                ),
              ),
              _TaskStatusChip(statusLabel: statusLabel, color: color),
              const SizedBox(width: 4),
              if (task.cancelled) ...[
                TextButton(
                  onPressed: () => _removeTask(task),
                  child: const Text('Remove'),
                ),
              ] else ...[
                PopupMenuButton<String>(
                  color: context.colors.surfaceHighest,
                  onSelected: (v) {
                    if (v == 'cancel') _cancelTask(task);
                    if (v == 'ocr') _retryOcr(task);
                    if (v == 'remove') _removeTask(task);
                  },
                  itemBuilder: (ctx) => [
                    if (task.processing) const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                    if (task.status == TaskStatus.failed || task.status == TaskStatus.extracting)
                      const PopupMenuItem(value: 'ocr', child: Text('Retry with OCR')),
                    const PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (task.processing && task.total > 0 && task.sent > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 6,
                backgroundColor: context.colors.surfaceHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          if (task.error != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error_outline, size: 15, color: context.colors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.error!,
                    style: TextStyle(fontSize: 12, color: context.colors.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (Color, String) _taskStatusAppearance(_UploadTask task) {
    if (task.cancelled) return (context.colors.textMuted, 'Cancelled');
    switch (task.status) {
      case TaskStatus.uploading:
        return (context.colors.info, 'Uploading');
      case TaskStatus.uploaded:
        return (context.colors.info, 'Uploaded');
      case TaskStatus.extracting:
        return (context.colors.warning, 'Extracting');
      case TaskStatus.ocrProcessing:
        return (context.colors.warning, 'OCR scanning');
      case TaskStatus.indexing:
        return (context.colors.warning, 'Indexing');
      case TaskStatus.ready:
        return (context.colors.success, 'Ready');
      case TaskStatus.failed:
        return (context.colors.error, 'Failed');
    }
  }

  IconData _taskLeadingIcon(_UploadTask task) {
    switch (task.status) {
      case TaskStatus.uploading:
      case TaskStatus.uploaded:
        return Icons.cloud_upload_outlined;
      case TaskStatus.extracting:
        return Icons.find_in_page_outlined;
      case TaskStatus.ocrProcessing:
        return Icons.document_scanner_outlined;
      case TaskStatus.indexing:
        return Icons.storage_outlined;
      case TaskStatus.ready:
        return Icons.check_circle_outline;
      case TaskStatus.failed:
        return Icons.error_outline;
    }
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
    final status = (doc['processing_status'] as String?) ?? '';
    final isReady = status == 'ready';
    final isFailed = status == 'failed';

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${_fileName(doc)}${doc['file_size'] != null ? ' · ${_formatFileSize(doc['file_size'] as int)}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                          ),
                        ),
                      ],
                    ),
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _docStatusBadge(status),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isReady) Icon(Icons.check_circle_rounded, color: context.colors.success, size: 18),
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
                  if (v == 'ocr') _retryOcr(doc);
                },
                itemBuilder: (ctx) => [
                  if (isFailed || !isReady) const PopupMenuItem(value: 'ocr', child: Text('Retry with OCR')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docStatusBadge(String status) {
    final (color, label) = switch (status) {
      'uploaded' => (context.colors.info, 'Uploaded'),
      'validating' => (context.colors.info, 'Validating'),
      'extracting' => (context.colors.warning, 'Extracting'),
      'ocr_processing' => (context.colors.warning, 'OCR scanning'),
      'indexing' => (context.colors.warning, 'Indexing'),
      'ready' => (context.colors.success, 'Ready for ScholarAI'),
      'failed' => (context.colors.error, 'Failed'),
      _ => (context.colors.textMuted, 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_dot(status), size: 10, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  IconData _dot(String status) => status == 'ready'
      ? Icons.check_circle_rounded
      : status == 'failed'
          ? Icons.error_rounded
          : Icons.circle;

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
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
                onPressed: _pickAndUpload,
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Upload Document'),
              ),
            ],
          ),
        ),
      );

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const [
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

    final tasks = <_UploadTask>[];
    for (final f in result.files) {
      List<int> bytes;
      try {
        bytes = f.bytes ?? await f.xFile.readAsBytes();
      } catch (_) {
        continue;
      }
      tasks.add(_UploadTask(
        name: f.name,
        size: bytes.length,
        bytes: bytes,
        title: f.name,
      ));
    }
    if (tasks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected file(s).')),
        );
      }
      return;
    }

    setState(() => _tasks = [..._tasks, ...tasks]);
    _assignDocTypes(tasks);
    for (final task in tasks) {
      unawaited(_startUpload(task));
    }
  }

  Future<void> _startUpload(_UploadTask task) async {
    setState(() {
      task.processing = true;
      task.sent = 0;
      task.progress = 0;
    });
    final result = await _vault.upload(
      bytes: task.bytes,
      filename: task.name,
      title: task.title,
      docType: task.docType,
      onProgress: (sent, total) {
        if (task.cancelled) return;
        setState(() {
          task.sent = sent;
          task.total = total;
          task.progress = total > 0 ? sent / total : 0;
        });
      },
    );

    if (task.cancelled) {
      if (result['success'] == true) {
        final id = (result['data'] as Map<String, dynamic>)['id'];
        if (id != null) unawaited(_api.delete('/vault/$id'));
      }
      _loadDocuments();
      return;
    }

    if (result['success'] != true) {
      setState(() {
        task.status = TaskStatus.failed;
        task.error = (result['error'] as String?) ?? 'Upload failed';
        task.processing = false;
      });
      return;
    }

    final docId = (result['data'] as Map<String, dynamic>)['id'] as int?;
    setState(() {
      task.docId = docId;
      task.status = TaskStatus.extracting;
      task.sent = task.total;
      task.progress = 1.0;
    });
    _loadDocuments();
    if (docId != null) await _runPipeline(task, docId);
  }

  Future<void> _runPipeline(_UploadTask task, int docId) async {
    setState(() => task.status = TaskStatus.extracting);
    final result = await _vault.process(docId);
    if (task.cancelled || !mounted) return;
    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      final serverStatus = (data['status'] as String?) ?? '';
      if (serverStatus == 'ready' || serverStatus == 'failed') {
        setState(() {
          task.status = serverStatus == 'ready' ? TaskStatus.ready : TaskStatus.failed;
          task.error = (data['error'] as String?) ?? (serverStatus == 'failed' ? 'Processing failed' : null);
          task.processing = false;
        });
        _loadDocuments();
        return;
      }
    } else {
      setState(() {
        task.status = TaskStatus.failed;
        task.error = (result['error'] as String?) ?? 'Processing failed';
        task.processing = false;
      });
      return;
    }
    await _pollStatus(task, docId);
  }

  Future<void> _retryOcr(dynamic source) async {
    final isTask = source is _UploadTask;
    final docId = isTask ? source.docId : (source['id'] as int?);
    if (docId == null) return;
    if (isTask) {
      final task = source;
      setState(() {
        task.status = TaskStatus.ocrProcessing;
        task.error = null;
        task.processing = true;
      });
      final result = await _vault.process(docId, forceOcr: true);
      if (task.cancelled) return;
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          task.status = data['status'] == 'ready' ? TaskStatus.ready : TaskStatus.extracting;
          task.processing = false;
        });
        if (data['error'] != null) task.error = data['error'] as String;
        _loadDocuments();
      } else {
        setState(() {
          task.status = TaskStatus.failed;
          task.error = (result['error'] as String?) ?? 'OCR retry failed';
          task.processing = false;
        });
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Re-processing with OCR...')),
    );
    final result = await _vault.process(docId, forceOcr: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['success'] == true ? 'OCR processing complete' : result['error'] as String)),
      );
      _loadDocuments();
    }
  }

  Future<void> _pollStatus(_UploadTask task, int docId) async {
    if (task.cancelled) return;
    // Small delay so the "+extract_token" job has a moment to land before we read.
    await Future.delayed(const Duration(seconds: 3));
    for (var i = 0; i < 8; i++) {
      if (task.cancelled || !mounted) return;
      final result = await _vault.status(docId);
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final serverStatus = (data['status'] as String?) ?? '';
        TaskStatus mapped;
        switch (serverStatus) {
          case 'ready':
            mapped = TaskStatus.ready;
            break;
          case 'failed':
            mapped = TaskStatus.failed;
            break;
          case 'ocr_processing':
            mapped = TaskStatus.ocrProcessing;
            break;
          case 'indexing':
            mapped = TaskStatus.indexing;
            break;
          case 'uploaded':
          case 'validating':
            mapped = TaskStatus.uploaded;
            break;
          default:
            mapped = TaskStatus.extracting;
        }
        if (mounted) {
          setState(() {
            task.status = mapped;
            if (mapped == TaskStatus.failed) {
              task.error = (data['error'] as String?) ?? 'Processing failed';
            }
            if (mapped == TaskStatus.ready || mapped == TaskStatus.failed) {
              task.processing = false;
            }
          });
        }
        if (mapped == TaskStatus.ready || mapped == TaskStatus.failed) {
          _loadDocuments();
          return;
        }
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  void _cancelTask(_UploadTask task) {
    setState(() {
      task.cancelled = true;
      task.processing = false;
    });
  }

  void _removeTask(_UploadTask task) {
    setState(() => _tasks = _tasks.where((t) => t != task).toList());
  }

  Future<void> _assignDocTypes(List<_UploadTask> tasks) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final names = tasks.map((t) => t.name).take(8).join(', ');
          var docType = tasks.first.docType;
          var title = tasks.first.title;
          return AlertDialog(
            title: const Text('Upload'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tasks.length} file${tasks.length == 1 ? '' : 's'}: $names${tasks.length > 8 ? '…' : ''}',
                    style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: TextEditingController(text: title),
                    style: TextStyle(color: context.colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Title'),
                    onChanged: (v) => title = v,
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  for (final t in tasks) {
                    t.title = title.isEmpty ? t.name : title;
                    t.docType = docType;
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Start Upload'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  final String statusLabel;
  final Color color;
  const _TaskStatusChip({required this.statusLabel, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          statusLabel,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
        ),
      );
}
