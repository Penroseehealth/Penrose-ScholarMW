import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/services.dart';

class OcrScanScreen extends StatefulWidget {
  const OcrScanScreen({super.key});

  @override
  State<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends State<OcrScanScreen> {
  final OcrService _ocr = OcrService();

  PlatformFile? _file;
  bool _scanning = false;
  bool _analyzing = false;
  Map<String, dynamic>? _scanData;
  String? _scanError;
  String? _analysis;
  String? _analysisError;
  final TextEditingController _questionCtrl = TextEditingController();
  bool _autoAnalyze = true;

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf', 'txt', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    List<int> bytes;
    try {
      bytes = file.bytes ?? await file.xFile.readAsBytes();
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanError = 'Could not read the selected file.';
        });
      }
      return;
    }

    setState(() {
      _file = file;
      _scanData = null;
      _scanError = null;
      _analysis = null;
      _analysisError = null;
      _scanning = true;
    });

    final res = await _ocr.scanFile(bytes, file.name);
    if (!mounted) return;
    setState(() {
      _scanning = false;
      if (res['success'] == true) {
        _scanData = res['data'] as Map<String, dynamic>;
      } else {
        _scanError = res['error'] as String;
      }
    });

    if (_autoAnalyze && res['success'] == true) {
      await _runAnalysis();
    }
  }

  Future<void> _runAnalysis() async {
    final data = _scanData;
    if (data == null) return;
    final text = (data['text'] as String?) ?? '';
    if (text.trim().isEmpty) return;

    setState(() {
      _analyzing = true;
      _analysis = null;
      _analysisError = null;
    });

    final res = await _ocr.analyzeText(
      text,
      filename: (data['filename'] as String?) ?? 'document',
      question: _questionCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      if (res['success'] == true) {
        _analysis = (res['data'] as Map<String, dynamic>)['analysis'] as String?;
      } else {
        _analysisError = res['error'] as String;
      }
    });
  }

  Future<void> _copyText() async {
    final data = _scanData;
    final text = (data?['text'] as String?) ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Extracted text copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: const Text('Scan & Analyse', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: 'Scan a new file',
            onPressed: _scanning ? null : _pickFile,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _uploadCard(),
            const SizedBox(height: 14),
            if (_scanning) _scanningCard(),
            if (_scanError != null) _errorCard(_scanError!),
            if (_scanData != null) ...[
              _extractedTextCard(),
              const SizedBox(height: 14),
              _analysisCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _uploadCard() => Container(
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload a scan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Scans images and PDFs to read the text, then explains it with AI.',
              style: TextStyle(fontSize: 12, color: context.colors.textMuted),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _scanning ? null : _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: context.colors.surfaceHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border, style: BorderStyle.solid),
                ),
                child: Center(
                  child: _file == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded, size: 30, color: context.colors.textSecondary),
                            const SizedBox(height: 8),
                            Text('Tap to choose image, PDF, or document',
                                style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.document_scanner_rounded, size: 30, color: context.colors.textSecondary),
                            const SizedBox(height: 8),
                            Text(_file!.name,
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                            const SizedBox(height: 2),
                            Text('${(_file!.size / 1024).toStringAsFixed(1)} KB — tap to change',
                                style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                          ],
                        ),
                ),
              ),
            ),
            if (_scanData != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionCtrl,
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ask a question about this document (optional)',
                        prefixIcon: Icon(Icons.question_answer_rounded, color: context.colors.textMuted),
                      ),
                      onSubmitted: (_) => _runAnalysis(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _analyzing || _scanning ? null : _runAnalysis,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('Analyse'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _scanningCard() => ProgressCard(label: 'Scanning and extracting text…');

  Widget _errorCard(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.error),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: context.colors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
              ),
            ),
          ],
        ),
      );

  Widget _extractedTextCard() => Container(
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Extracted text',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                        const SizedBox(height: 2),
                        _metaLine(),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 18, color: context.colors.textSecondary),
                    tooltip: 'Copy text',
                    onPressed: _copyText,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                ((_scanData?['text'] as String?) ?? 'No text found.').trim(),
                style: TextStyle(fontSize: 14, height: 1.5, color: context.colors.textPrimary),
              ),
            ),
          ],
        ),
      );

  Widget _metaLine() {
    final data = _scanData;
    final method = (data?['method'] as String?) ?? 'ocr';
    final wordCount = (data?['word_count'] as int?) ?? 0;
    final pageCount = (data?['page_count'] as int?) ?? 1;
    final methodLabel = switch (method) {
      'text-layer' => 'from document text',
      'ocr-pdf' => 'scanned PDF',
      _ => 'via OCR',
    };
    return Text(
      '$wordCount words · $pageCount page(s) · $methodLabel',
      style: TextStyle(fontSize: 11, color: context.colors.textMuted),
    );
  }

  Widget _analysisCard() {
    if (_analyzing) {
      return const ProgressCard(label: 'Analysing document with AI…');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('AI analysis',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          if (_analysis != null)
            SelectableText(
              _analysis!,
              style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white),
            )
          else if (_analysisError != null)
            Text(
              _analysisError!,
              style: const TextStyle(fontSize: 13, color: Colors.deepOrangeAccent),
            )
          else
            Text(
              'Press Analyse to get a summary, key points and an answer to your question.',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

class ProgressCard extends StatelessWidget {
  final String label;
  const ProgressCard({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 13, color: context.colors.textPrimary)),
            ),
          ],
        ),
      );
}
