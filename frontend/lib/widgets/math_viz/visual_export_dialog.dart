import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/export_service.dart';
import '../../services/offline_cache_service.dart';
import 'ai_visual_parser.dart';

enum ExportAction { save, export }

class VisualExportDialog extends StatefulWidget {
  final ParsedVisual visual;
  final GlobalKey? visualKey;
  final ExportAction action;
  final String? chatContext;

  const VisualExportDialog({
    super.key,
    required this.visual,
    this.visualKey,
    required this.action,
    this.chatContext,
  });

  @override
  State<VisualExportDialog> createState() => _VisualExportDialogState();
}

class _VisualExportDialogState extends State<VisualExportDialog> {
  String _selectedDestination = 'Notes';
  String _selectedFormat = 'PNG';
  String _fileName = '';
  bool _saving = false;

  static const _destinations = [
    'Notes',
    'Lesson Planner',
    'Whiteboard',
    'Assignment',
    'Practical',
    'Revision',
    'Assessment',
    'Teacher Resources',
    'Student Resources',
    'Portfolio',
    'Custom Project',
  ];

  late List<String> _formats;

  @override
  void initState() {
    super.initState();
    _fileName = _defaultFileName();
    _formats = _availableFormats();
    if (_formats.isNotEmpty) _selectedFormat = _formats.first;
  }

  List<String> _availableFormats() {
    switch (widget.visual.type) {
      case VisualType.barChart:
      case VisualType.pieChart:
      case VisualType.histogram:
      case VisualType.lineChart:
      case VisualType.frequencyPolygon:
      case VisualType.cumulativeFrequency:
        return ['PNG', 'SVG', 'PDF', 'CSV'];
      case VisualType.graph:
        return ['PNG', 'SVG', 'PDF'];
      case VisualType.triangle:
      case VisualType.circle:
      case VisualType.quadrilateral:
      case VisualType.polygon:
      case VisualType.angle:
      case VisualType.tangent:
        return ['PNG', 'SVG', 'PDF'];
      default:
        return ['PNG', 'PDF'];
    }
  }

  String _defaultFileName() {
    final title = widget.visual.title ?? widget.visual.type.name;
    return title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_').toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.action == ExportAction.save ? Icons.save_rounded : Icons.download_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.action == ExportAction.save ? 'Save Visual' : 'Export Visual',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection('File Name', _buildFileNameField(colors), colors),
              const SizedBox(height: 12),
              _buildSection('Destination', _buildDestinationDropdown(colors), colors),
              const SizedBox(height: 12),
              _buildSection('Format', _buildFormatChips(colors), colors),
              if (_visualMetadata() != null) ...[
                const SizedBox(height: 12),
                _buildMetadataPreview(colors),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _performAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(widget.action == ExportAction.save ? 'Save' : 'Export'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String label, Widget child, dynamic colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textMuted),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildFileNameField(dynamic colors) {
    return TextField(
      controller: TextEditingController(text: _fileName),
      onChanged: (v) => _fileName = v,
      style: TextStyle(fontSize: 14, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Enter file name',
        hintStyle: TextStyle(color: colors.textMuted),
        filled: true,
        fillColor: colors.surfaceHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  Widget _buildDestinationDropdown(dynamic colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surfaceHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButton<String>(
        value: _selectedDestination,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: colors.surfaceElevated,
        style: TextStyle(fontSize: 14, color: colors.textPrimary),
        items: _destinations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
        onChanged: (v) => setState(() => _selectedDestination = v ?? _selectedDestination),
      ),
    );
  }

  Widget _buildFormatChips(dynamic colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _formats.map((f) {
        final selected = f == _selectedFormat;
        return GestureDetector(
          onTap: () => setState(() => _selectedFormat = f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withAlpha(30) : colors.surfaceHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.primary : colors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              f,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : colors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetadataPreview(dynamic colors) {
    final meta = _visualMetadata()!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Visual Metadata', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textMuted)),
          const SizedBox(height: 4),
          if (meta['subject'] != null) _metaRow('Subject', meta['subject']!, colors),
          if (meta['topic'] != null) _metaRow('Topic', meta['topic']!, colors),
          if (meta['syllabusObjective'] != null) _metaRow('Objective', meta['syllabusObjective']!, colors),
          _metaRow('Type', meta['type'] ?? '', colors),
          _metaRow('Source', meta['generationSource'] ?? 'ai', colors),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value, dynamic colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 10, color: colors.textMuted),
      ),
    );
  }

  Map<String, dynamic>? _visualMetadata() {
    final map = widget.visual.toMetadataMap();
    if (map['subject'] == null && map['topic'] == null) return null;
    return map;
  }

  Future<void> _performAction() async {
    setState(() => _saving = true);

    try {
      if (_selectedFormat == 'CSV') {
        final csv = _buildCsvData();
        ExportService.exportTextToFile(csv, '$_fileName.csv');
      } else if (_selectedFormat == 'PNG' && widget.visualKey != null) {
        await ExportService.exportWidgetToImage(widget.visualKey!, _fileName);
      } else {
        final html = ExportService.buildVisualHtml(
          title: widget.visual.title ?? 'Visual',
          type: _selectedFormat,
          spec: widget.visual.rawSpec ?? '',
        );
        ExportService.exportHtmlToFile(html, '$_fileName.html');
      }

      await _saveToCache();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedFormat} exported to $_selectedDestination'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _buildCsvData() {
    final buf = StringBuffer();
    if (widget.visual.labels != null && widget.visual.values != null) {
      buf.writeln('Label,Value');
      for (var i = 0; i < widget.visual.values!.length; i++) {
        final label = i < (widget.visual.labels?.length ?? 0) ? widget.visual.labels![i] : 'Item ${i + 1}';
        buf.writeln('$label,${widget.visual.values![i]}');
      }
    } else {
      buf.writeln('Data');
      for (final v in widget.visual.values ?? []) {
        buf.writeln(v);
      }
    }
    return buf.toString();
  }

  Future<void> _saveToCache() async {
    final cache = OfflineCacheService();
    final existing = cache.getJson<List<dynamic>>('saved_visuals') ?? [];
    final visuals = List<Map<String, dynamic>>.from(existing.cast<Map<String, dynamic>>());
    visuals.add({
      ...widget.visual.toMetadataMap(),
      'fileName': _fileName,
      'format': _selectedFormat,
      'destination': _selectedDestination,
      'savedAt': DateTime.now().toIso8601String(),
    });
    await cache.cacheJson('saved_visuals', visuals, ttl: const Duration(days: 365));
  }
}
