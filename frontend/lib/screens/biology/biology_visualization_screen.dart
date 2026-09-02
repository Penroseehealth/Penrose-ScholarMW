import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/theme_colors.dart';
import '../../models/biology_visualization.dart';
import '../../services/biology_visualization_service.dart';
import '../../services/export_service.dart';
import 'visualization/diagram_renderer.dart';

const Color _bioGreen = Color(0xFF10B981);

/// Functional Biology Visualization Engine.
///
/// Replaces the static diagram mockup: prompt -> syllabus-grounded structured
/// spec (backend) -> deterministic SVG (this client) -> zoom/pan viewer with
/// real save / history / export / print / regenerate controls.
class BiologyVisualizationScreen extends StatefulWidget {
  const BiologyVisualizationScreen({super.key});

  @override
  State<BiologyVisualizationScreen> createState() => _BiologyVisualizationScreenState();
}

class _BiologyVisualizationScreenState extends State<BiologyVisualizationScreen> {
  final BiologyVisualizationService _service = BiologyVisualizationService();
  final TextEditingController _prompt = TextEditingController();
  final GlobalKey _svgKey = GlobalKey();

  int _tab = 0;
  int _form = 1;
  String _app = 'plant_cell';
  String _background = 'white';

  // Generation state.
  bool _generating = false;
  GenerationJob? _job;
  Timer? _pollTimer;
  String? _error;
  String? _promptError;

  // Current diagram state (after generation/open/edit).
  VisualizationDetail? _detail;
  String? _svg;
  bool _busy = false;

  // History.
  List<VisualizationSummary> _history = const [];
  bool _historyLoading = false;

  static const Map<String, String> _apps = {
    'plant_cell': 'Plant Cell',
    'animal_cell': 'Animal Cell',
    'bacterial_cell': 'Bacterial Cell',
    'fungal_cell': 'Fungal Cell',
  };
  static const List<String> _backgrounds = ['white', 'transparent', 'black'];

  @override
  void dispose() {
    _pollTimer?.cancel();
    _prompt.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _startGeneration() async {
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) {
      setState(() => _promptError = 'Please type a description in the box above, then tap Generate.');
      _snack('Enter a prompt, e.g. "Draw a labelled plant cell for Form 1"');
      return;
    }
    setState(() {
      _generating = true;
      _job = null;
      _error = null;
      _promptError = null;
    });
    try {
      final job = await _service.generate(
        prompt: prompt,
        form: _form,
        app: _app,
        background: _background,
      );
      if (!mounted) return;
      setState(() => _job = job);
      _pollJob(job.jobId);
    } catch (e) {
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  void _pollJob(int jobId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final job = await _service.generationStatus(jobId);
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _job = job);
        if (job.status == 'COMPLETED') {
          timer.cancel();
          setState(() => _generating = false);
          if (job.visualizationId != null) {
            await _open(job.visualizationId!);
          }
        } else if (job.status == 'FAILED' || job.status == 'CANCELLED') {
          timer.cancel();
          setState(() {
            _generating = false;
            _error = job.error ?? 'Generation failed';
          });
        }
      } catch (_) {
        // transient poll error — keep polling
      }
    });
  }

  Future<void> _open(int id) async {
    try {
      final detail = await _service.get(id);
      if (!mounted) return;
      final svg = DiagramRenderer.render(detail.spec);
      setState(() {
        _detail = detail;
        _svg = svg;
        _app = detail.spec.app;
        _background = detail.background;
        _form = detail.form;
        _tab = 0;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not open diagram: $e');
    }
  }

  Future<void> _saveDirect() async {
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) {
      setState(() => _promptError = 'Please type a description in the box above, then tap Generate.');
      _snack('Type a prompt before saving');
      return;
    }
    setState(() {
      _busy = true;
      _promptError = null;
    });
    try {
      final detail = await _service.save(
        prompt: prompt,
        form: _form,
        app: _app,
        background: _background,
      );
      if (!mounted) return;
      _snack('Saved to history');
      setState(() {
        _detail = detail;
        _svg = DiagramRenderer.render(detail.spec);
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Save failed: $e');
    }
  }

  Future<void> _regenerate() async {
    final detail = _detail;
    if (detail == null) return;
    setState(() => _generating = true);
    try {
      final job = await _service.generate(
        prompt: detail.prompt,
        form: detail.form,
        app: detail.spec.app,
        background: _background,
      );
      if (!mounted) return;
      setState(() => _job = job);
      _pollJob(job.jobId);
    } catch (e) {
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleLabels() async {
    final detail = _detail;
    if (detail == null) return;
    final next = !detail.spec.labelsShown;
    try {
      await _service.edit(detail.id, labelsShown: next);
      if (!mounted) return;
      setState(() => detail.spec.labelsShown = next);
      _svg = DiagramRenderer.render(detail.spec);
    } catch (e) {
      _snack('Update failed: $e');
    }
  }

  Future<void> _changeBackground(String bg) async {
    final detail = _detail;
    setState(() => _background = bg);
    if (detail == null) return;
    try {
      await _service.edit(detail.id, background: bg);
      if (!mounted) return;
      setState(() {
        detail.background = bg;
        detail.spec.background = bg;
        _svg = DiagramRenderer.render(detail.spec);
      });
    } catch (e) {
      _snack('Background update failed: $e');
    }
  }

  Future<void> _downloadSvg() async {
    final svg = _svg;
    if (svg == null) return;
    final title = (_detail?.title ?? 'biology-diagram').replaceAll(' ', '-');
    await ExportService.exportSvgToFile(svg, '$_form-$title-$_app');
  }

  Future<void> _downloadPng() async {
    final detail = _detail;
    if (detail == null) return;
    final title = detail.title.replaceAll(' ', '-');
    await ExportService.exportWidgetToImage(_svgKey, '$_form-$title-$_app');
  }

  void _print() {
    final svg = _svg;
    if (svg == null) return;
    final title = _detail?.title ?? 'Biology Diagram';
    final doc = '''
<!DOCTYPE html><html><head><title>$title</title>
<style>body{margin:0;display:flex;justify-content:center;align-items:center;min-height:100vh}</style>
<script>window.onload=function(){window.print();}</script>
</head><body>$svg</body></html>''';
    html.window.open(Uri.dataFromString(doc, mimeType: 'text/html').toString(), '_blank');
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final list = await _service.history();
      if (!mounted) return;
      setState(() {
        _history = list;
        _historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _historyLoading = false);
      _snack('Could not load history: $e');
    }
  }

  Future<void> _delete(int id) async {
    try {
      await _service.delete(id);
      if (!mounted) return;
      _snack('Deleted');
      setState(() {
        _history = _history.where((h) => h.id != id).toList();
        if (_detail?.id == id) {
          _detail = null;
          _svg = null;
        }
      });
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Biology Visualization Engine'),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          _tabBar(colors),
          Expanded(
            child: _tab == 0 ? _buildGenerate(colors) : _buildHistory(colors),
          ),
        ],
      ),
    );
  }

  Widget _tabBar(ThemeColors colors) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            _tabChip(colors, 0, 'Generate', Icons.auto_awesome_rounded),
            const SizedBox(width: 8),
            _tabChip(colors, 1, 'History', Icons.history_rounded),
          ],
        ),
      );

  Widget _tabChip(ThemeColors colors, int idx, String label, IconData icon) => GestureDetector(
        onTap: () {
          setState(() => _tab = idx);
          if (idx == 1) _loadHistory();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _tab == idx ? _bioGreen.withValues(alpha: 0.14) : colors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _tab == idx ? _bioGreen.withValues(alpha: 0.4) : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _tab == idx ? _bioGreen : colors.textMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _tab == idx ? _bioGreen : colors.textSecondary)),
            ],
          ),
        ),
      );

  // ── Generate tab ────────────────────────────────────────────────

  Widget _buildGenerate(ThemeColors colors) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_detail == null) ...[
              _promptCard(colors),
              const SizedBox(height: 16),
              _controlsCard(colors),
              const SizedBox(height: 16),
              if (_generating) _progressCard(colors),
              if (_error != null) _errorCard(colors),
            ] else ...[
              _viewerCard(colors),
              const SizedBox(height: 16),
              _actionsCard(colors),
            ],
          ],
        ),
      );

  Widget _promptCard(ThemeColors colors) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _card(colors),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Describe the diagram you want',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
            const SizedBox(height: 10),
            TextField(
              controller: _prompt,
              maxLines: 3,
              onChanged: (_) {
                if (_promptError != null) setState(() => _promptError = null);
              },
              decoration: InputDecoration(
                hintText: 'e.g. Draw a labelled plant cell for Form 1',
                filled: true,
                fillColor: colors.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 15, color: _bioGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Prompt is analysed and grounded in the seeded Malawi Biology syllabus.',
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _controlsCard(ThemeColors colors) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _card(colors),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configuration',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
            const SizedBox(height: 14),
            _label(colors, 'Form'),
            Wrap(
              spacing: 8,
              children: [1, 2, 3, 4]
                  .map((f) => _chip(
                        colors,
                        'Form $f',
                        _form == f,
                        () => setState(() => _form = f),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            _label(colors, 'Cell type'),
            Wrap(
              spacing: 8,
              children: _apps.entries
                  .map((e) => _chip(
                        colors,
                        e.value,
                        _app == e.key,
                        () => setState(() => _app = e.key),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            _label(colors, 'Background'),
            Wrap(
              spacing: 8,
              children: _backgrounds
                  .map((b) => _chip(
                        colors,
                        b,
                        _background == b,
                        () => setState(() => _background = b),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generating ? null : _startGeneration,
                icon: const Icon(Icons.movie_creation_rounded, size: 18),
                label: Text(_generating ? 'Generating…' : 'Generate Diagram'),
                style: FilledButton.styleFrom(
                  backgroundColor: _bioGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_promptError != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Color(0xFFE53935)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _promptError!,
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _saveDirect,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Generate & Save'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _bioGreen,
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _progressCard(ThemeColors colors) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _card(colors),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generating your diagram…', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _job != null && _job!.progress > 0 ? _job!.progress : null,
              backgroundColor: colors.surfaceHighest,
              color: _bioGreen,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Text(
              _job != null ? 'Status: ${_job!.status}' : 'Queued…',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
      );

  Widget _errorCard(ThemeColors colors) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.errorMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.error),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!, style: TextStyle(color: colors.textSecondary, fontSize: 13))),
          ],
        ),
      );

  // ── Viewer ──────────────────────────────────────────────────────

  Widget _viewerCard(ThemeColors colors) {
    final svg = _svg;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _detail?.title ?? 'Diagram',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
              ),
              if (_detail != null)
                Text('Form ${_detail!.form} · ${_apps[_app] ?? _app}',
                    style: TextStyle(fontSize: 12, color: colors.textMuted)),
            ],
          ),
          if (_detail?.syllabusReference != null) ...[
            const SizedBox(height: 4),
            Text(_detail!.syllabusReference!, style: TextStyle(fontSize: 11, color: colors.primaryLight)),
          ],
          const SizedBox(height: 12),
          Container(
            height: 460,
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: svg == null
                ? const Center(child: Text('No diagram yet'))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 8,
                      child: RepaintBoundary(
                        key: _svgKey,
                        child: SvgPicture.string(svg),
                      ),
                    ),
                  ),
          ),
          if (_detail != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _action(colors, Icons.label_outline_rounded, _detail!.spec.labelsShown ? 'Hide Labels' : 'Show Labels',
                    _toggleLabels),
                const SizedBox(width: 8),
                _action(colors, Icons.download_rounded, 'SVG', _downloadSvg),
                const SizedBox(width: 8),
                _action(colors, Icons.image_outlined, 'PNG', _downloadPng),
                const SizedBox(width: 8),
                _action(colors, Icons.print_rounded, 'Print', _print),
                const SizedBox(width: 8),
                _action(colors, Icons.refresh_rounded, 'Regenerate', _regenerate),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _backgrounds
                  .map((b) => _chip(
                        colors,
                        'BG: $b',
                        _background == b,
                        () => _changeBackground(b),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionsCard(ThemeColors colors) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _detail = null;
                  _svg = null;
                  _prompt.clear();
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New diagram'),
            ),
          ),
        ],
      );

  Widget _action(ThemeColors colors, IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _bioGreen),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary)),
            ],
          ),
        ),
      );

  // ── History tab ─────────────────────────────────────────────────

  Widget _buildHistory(ThemeColors colors) {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator(color: _bioGreen));
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 48, color: _bioGreen),
            const SizedBox(height: 12),
            Text('No saved diagrams yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 6),
            Text('Generate a diagram and it will appear here.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final h = _history[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: _card(colors),
          child: Row(
            children: [
              Icon(_apps.containsKey(h.app) ? Icons.circle_outlined : Icons.image_outlined, color: _bioGreen, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                        '${_apps[h.app] ?? h.app} · Form ${h.form}${h.topic.isNotEmpty ? ' · ${h.topic}' : ''} · v${h.version}',
                        style: TextStyle(fontSize: 12, color: colors.textMuted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open',
                icon: const Icon(Icons.open_in_new_rounded, color: _bioGreen),
                onPressed: () {
                  setState(() => _busy = true);
                  _open(h.id);
                },
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                onPressed: () => _delete(h.id),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── helpers ─────────────────────────────────────────────────────

  BoxDecoration _card(ThemeColors colors) => BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      );

  Widget _label(ThemeColors colors, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.textSecondary)),
      );

  Widget _chip(ThemeColors colors, String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? _bioGreen.withValues(alpha: 0.14) : colors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? _bioGreen.withValues(alpha: 0.5) : colors.border,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: active ? _bioGreen : colors.textSecondary)),
        ),
      );
}
