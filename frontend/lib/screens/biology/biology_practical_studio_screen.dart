import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/theme_colors.dart';
import '../../services/practical_simulation_service.dart';

/// Cyan accent used alongside the purple theme in the practical studio.
const Color _studioCyan = Color(0xFF22D3EE);
const Color _studioCyanGlow = Color(0x2222D3EE);

class BiologyPracticalStudioScreen extends StatefulWidget {
  final int? simulationId;
  const BiologyPracticalStudioScreen({super.key, this.simulationId});

  @override
  State<BiologyPracticalStudioScreen> createState() => _BiologyPracticalStudioScreenState();
}

class _BiologyPracticalStudioScreenState extends State<BiologyPracticalStudioScreen> {
  final PracticalSimulationService _service = PracticalSimulationService();

  bool _loading = true;
  String? _error;
  bool _syllabusMapped = false;
  PracticalSimulationSpec? _spec;
  int? _simulationId;
  String? _savedKey;
  String? _savedTitle;

  // Generation state.
  bool _generationEnabled = false;
  List<String> _configuredProviders = const [];
  bool _generating = false;
  GenerationJob? _job;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _simulationId = widget.simulationId;
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Check generation capability first.
    Map<String, dynamic> providers;
    try {
      providers = await _service.providersStatus();
      _generationEnabled = providers['generation_enabled'] as bool? ?? false;
      _configuredProviders = List<String>.from(providers['configured'] as List? ?? const []);
    } catch (_) {
      _generationEnabled = false;
      _configuredProviders = const [];
    }

    try {
      int simId;
      if (_simulationId != null) {
        simId = _simulationId!;
      } else {
        // Creating an existing simulation returns 409; if so, fetch it.
        try {
          final created = await _service.createSimulation();
          simId = created.simulationId!;
        } catch (e) {
          // 409 already exists -> find it by listing.
          final list = await _service.listSimulations(subject: 'biology');
          if (list.isEmpty) rethrow;
          simId = list.first.id;
        }
        _simulationId = simId;
      }

      final spec = await _service.getSimulation(simId);
      final storyboard = await _service.storyboard(simId);
      final mapped = storyboard['syllabus_mapped'] as bool? ?? spec.syllabusMapped;
      setState(() {
        _simulationId = simId;
        _syllabusMapped = mapped;
        _spec = PracticalSimulationSpec.fromJson(storyboard);
        _savedKey = storyboard['spec']?['practical_id'] as String?;
        _savedTitle = storyboard['spec']?['title'] as String? ?? 'Practical Simulation';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startGeneration() async {
    final simId = _simulationId;
    if (simId == null || !_syllabusMapped || !_generationEnabled) return;
    setState(() {
      _generating = true;
      _job = null;
    });
    try {
      final job = await _service.generate(simId);
      setState(() => _job = job);
      _poll(job.jobId);
    } catch (e) {
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  void _poll(int jobId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final simId = _simulationId;
      if (simId == null) return;
      try {
        final job = await _service.generationStatus(simId, jobId);
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _job = job);
        if (job.isFinished) {
          timer.cancel();
          setState(() => _generating = false);
        }
      } catch (_) {
        // transient poll error — keep polling
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Practical Simulation Studio'),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _buildContent(colors),
    );
  }

  Widget _buildContent(ThemeColors colors) {
    final spec = _spec;
    if (!_syllabusMapped) {
      return _buildSyllabusGuidance(colors);
    }
    final scenes = spec?.scenes ?? const <PracticalScene>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(colors),
          const SizedBox(height: 20),
          if (spec?.learningObjectives.isNotEmpty ?? false)
            _section(
              colors: colors,
              title: 'Learning Objectives',
              icon: Icons.school_rounded,
              color: colors.primaryLight,
              children: [
                for (final lo in spec!.learningObjectives) _bullet(colors, lo, Icons.flag_rounded),
              ],
            ),
          if (spec?.equipment.isNotEmpty ?? false)
            _section(
              colors: colors,
              title: 'Apparatus',
              icon: Icons.build_rounded,
              color: _studioCyan,
              children: [
                for (final item in spec!.equipment) _bullet(colors, item, Icons.check_circle_outline_rounded),
              ],
            ),
          const SizedBox(height: 16),
          _section(
            colors: colors,
            title: 'Storyboard (${scenes.length} scenes)',
            icon: Icons.videocam_rounded,
            color: colors.primary,
            children: [
              for (var i = 0; i < scenes.length; i++) _sceneCard(colors, i, scenes[i]),
            ],
          ),
          const SizedBox(height: 20),
          _buildGenerationPanel(colors),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _header(ThemeColors colors) {
    final titles = _savedTitle ?? 'Practical Simulation';
    final subtitle = _savedKey ?? '';
    const totalSecs = 180; // 10 x 18s scenes from the syllabus-mapped plan
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [colors.primaryMuted, colors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: _studioCyan, size: 22),
              const SizedBox(width: 8),
              Text(
                'Biology · Practical',
                style: TextStyle(
                  color: colors.primaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            titles,
            style: TextStyle(
              color: colors.textOnPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: colors.textOnPrimary.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(colors, '${(_spec?.scenes ?? const <PracticalScene>[]).length} scenes', Icons.view_agenda_rounded),
              const SizedBox(width: 8),
              _chip(colors, '~${totalSecs ~/ 60} min', Icons.timer_outlined),
              const SizedBox(width: 8),
              _chip(colors, _syllabusMapped ? 'Syllabus mapped' : 'Draft', Icons.verified_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(ThemeColors colors, String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.textOnPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _studioCyan),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: colors.textOnPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _section({
    required ThemeColors colors,
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      );

  Widget _bullet(ThemeColors colors, String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: _studioCyan),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _sceneCard(ThemeColors colors, int index, PracticalScene scene) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _studioCyanGlow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: _studioCyan,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    scene.purpose.isNotEmpty ? scene.purpose : 'Scene',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${scene.duration}s',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
            if (scene.camera.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.videocam_outlined, size: 14, color: _studioCyan),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      scene.camera,
                      style: TextStyle(color: colors.primaryLight, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (scene.action.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                scene.action,
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
            if (scene.safetyNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      scene.safetyNote,
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _buildGenerationPanel(ThemeColors colors) {
    final job = _job;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded, color: _studioCyan, size: 22),
              const SizedBox(width: 8),
              Text(
                'Generate Video',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_generationEnabled)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.warningMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Video generation is not configured yet. Add a Runway or Luma API key on the backend to enable AI generation. The syllabus-mapped storyboard above is ready above once a provider is configured.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_rounded, size: 18),
                  label: const Text('Generation disabled · configure provider'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surfaceHighest,
                    foregroundColor: colors.textMuted,
                  ),
                ),
              ],
            )
          else if (job != null && !job.isFinished)
            Column(
              children: [
                LinearProgressIndicator(
                  value: job.progress > 0 && job.progress < 1 ? job.progress : null,
                  backgroundColor: colors.surfaceHighest,
                  color: _studioCyan,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 10),
                Text(
                  'Status: ${job.status}${job.error != null ? ' — ${job.error}' : ''}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            )
          else if (job != null && job.status == 'COMPLETED' && job.videoUrl != null)
            _completionCard(colors, job)
          else
            FilledButton.icon(
              onPressed: _generating ? null : _startGeneration,
              icon: const Icon(Icons.movie_creation_rounded, size: 18),
              label: Text(_generating ? 'Starting…' : 'Generate video'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          if (_configuredProviders.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Providers: ${_configuredProviders.join(', ')}',
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _completionCard(ThemeColors colors, GenerationJob job) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Generation complete',
                style: TextStyle(
                  color: colors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play video'),
            style: FilledButton.styleFrom(
              backgroundColor: _studioCyan,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      );

  Widget _buildSyllabusGuidance(ThemeColors colors) {
    final msg = _spec?.message ??
        'Practical simulation is ready for syllabus mapping. Seed the Biology syllabus/practical objectives before enabling curriculum-validated generation.';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryGlow,
              ),
              child: Icon(Icons.map_outlined, color: colors.primaryLight, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              'Ready for syllabus mapping',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
            const SizedBox(height: 12),
            Text(
              'Could not load the practical simulation',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
