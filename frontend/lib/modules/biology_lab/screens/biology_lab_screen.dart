import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_colors.dart';
import '../bridge/bio_lab_bridge_factory.dart';
import '../hierarchy/bio_lab_registry.dart';
import '../practicals/bacterial_practical.dart';
import '../state/biology_lab_provider.dart';
import '../viewport/bio_viewport.dart';

/// Main workspace of the Biology 3D Laboratory (`/bio-3d-lab`).
///
/// Layout: left hierarchy navigator · centre 3D viewport + toolbar +
/// timeline · right information panel. Practical mode replaces the info
/// panel with the practical sheet.
class BiologyLabScreen extends StatefulWidget {
  const BiologyLabScreen({super.key});

  @override
  State<BiologyLabScreen> createState() => _BiologyLabScreenState();
}

class _BiologyLabScreenState extends State<BiologyLabScreen> {
  late final BiologyLabProvider _provider;
  final TextEditingController _search = TextEditingController();
  String _searchQuery = '';
  bool _practicalOpen = false;

  @override
  void initState() {
    super.initState();
    _provider = BiologyLabProvider(bridge: createBioLabBridge())..addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    _provider
      ..removeListener(_onProviderChanged)
      ..dispose();
    super.dispose();
  }

  ThemeColors get _t => context.colors;

  @override
  Widget build(BuildContext context) {
    final asset = _provider.currentAsset;
    return Scaffold(
      backgroundColor: _t.background,
      appBar: AppBar(
        backgroundColor: _t.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/stem/biology'),
          tooltip: 'Back to Biology',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.biotech_rounded, color: _t.teal, size: 20),
            const SizedBox(width: 8),
            Text('Biology 3D Laboratory', style: TextStyle(color: _t.textPrimary, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Start the bacterial cell practical',
            icon: const Icon(Icons.assignment_turned_in_rounded),
            onPressed: asset == null || _practicalOpen ? null : () => _startPractical(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        if (isNarrow) {
          // Mobile: viewport on top, panels as tabbed sheet below.
          return Column(
            children: [
              Expanded(flex: 5, child: _buildViewport()),
              SizedBox(
                height: 340,
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        indicatorColor: _t.teal,
                        labelColor: _t.textPrimary,
                        unselectedLabelColor: _t.textMuted,
                        tabs: const [
                          Tab(text: 'Hierarchy'),
                          Tab(text: 'Details'),
                          Tab(text: 'Practical'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildHierarchy(),
                            _buildInfo(),
                            _buildPractical(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 280, child: _buildHierarchy()),
            const VerticalDivider(width: 1, color: Colors.black12),
            Expanded(child: _buildViewport()),
            const VerticalDivider(width: 1, color: Colors.black12),
            SizedBox(
              width: 320,
              child: _practicalOpen ? _buildPractical() : _buildInfo(),
            ),
          ],
        );
      }),
    );
  }

  // ── Left: hierarchy navigator ────────────────────────────────────────────

  Widget _buildHierarchy() {
    final results = _searchQuery.isEmpty ? BioLabRegistry.assets : BioLabRegistry.search(_searchQuery);
    return Container(
      color: _t.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                hintText: 'Search structures…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text('No match for “$_searchQuery”', style: TextStyle(color: _t.textMuted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: results.length,
                    itemBuilder: (_, i) => _buildAssetTile(results[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTile(BioLabAsset asset) {
    final active = _provider.currentAsset?.id == asset.id;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? _t.teal.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            _practicalOpen = false;
            _provider.openAsset(asset.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(asset.level.icon, size: 18, color: active ? _t.teal : _t.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: active ? _t.teal : theme.colorScheme.onSurface)),
                      Text(
                        '${asset.level.label} · ${asset.verification.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: _t.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(asset.verification.icon,
                    size: 14,
                    color: asset.verification == BioVerification.validatedStructure ? _t.success : _t.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Centre: viewport, toolbar, timeline ─────────────────────────────────

  Widget _buildViewport() {
    final asset = _provider.currentAsset;
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          if (_provider.status == BioLabStatus.unsupported || _provider.status == BioLabStatus.error)
            Expanded(child: _buildFallback())
          else if (asset == null)
            Expanded(child: _buildEmptyState())
          else
            Expanded(
              child: Stack(
                children: [
                  BioLabViewport(
                    enabled: true,
                    onHostReady: (hostId) {
                      _provider.onHostReady(hostId);
                      _provider.ensureInitialised();
                    },
                    fallback: _buildFallback(),
                  ),
                  if (_provider.status == BioLabStatus.loading)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          _buildToolbar(),
          if (asset != null) _buildTimeline(asset),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.biotech_rounded, size: 56, color: _t.textMuted),
          const SizedBox(height: 12),
          Text('Choose a structure from the hierarchy', style: TextStyle(color: _t.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _t.teal),
            onPressed: () => _provider.openAsset('bacterial-cell'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start with the bacterial cell'),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    final msg = _provider.errorMessage ?? '';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_rounded, size: 48, color: _t.warning),
            const SizedBox(height: 12),
            Text(
              _provider.status == BioLabStatus.unsupported
                  ? '3D not available on this device'
                  : 'The 3D viewport hit a problem',
              style: TextStyle(color: _t.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (msg.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(msg, style: TextStyle(color: _t.textMuted, fontSize: 12.5), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _provider
                  ..status = BioLabStatus.idle
                  ..errorMessage = null
                  ..ensureInitialised();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final asset = _provider.currentAsset;
    return Container(
      color: _t.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _tool(const Icon(Icons.center_focus_strong_rounded), 'Reset camera', _provider.resetCamera,
              enabled: asset != null),
          _tool(const Icon(Icons.label_rounded), 'Labels', _provider.toggleLabels,
              active: _provider.labelsVisible, enabled: asset != null),
          _tool(const Icon(Icons.blur_on_rounded), 'Ghost mode', _provider.toggleGhost,
              active: _provider.ghostMode, enabled: asset != null),
          if (asset != null && asset.sceneId == 'human-heart')
            _tool(const Icon(Icons.account_tree_rounded), 'Descend to tissue',
                () => _provider.descendTo('cardiac-muscle-tissue')),
          if (asset != null && asset.moleculePdb != null && _provider.molecularMode)
            _tool(const Icon(Icons.threed_rotation), 'Back to 3D scene', _provider.exitMolecularMode),
          if (asset?.parent != null)
            _tool(const Icon(Icons.arrow_upward_rounded), 'Up one level', _provider.ascendToParent),
        ],
      ),
    );
  }

  Widget _tool(Icon icon, String tooltip, VoidCallback onTap, {bool active = false, bool enabled = true}) => IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onTap : null,
        icon: icon,
        color: active ? _t.teal : _t.textSecondary,
        iconSize: 20,
        visualDensity: VisualDensity.compact,
      );

  Widget _buildTimeline(BioLabAsset asset) {
    if (asset.animations.isEmpty) return const SizedBox.shrink();
    final anim = asset.animations.first;
    return Container(
      color: _t.surface,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: _provider.playbackState == 'running' ? 'Pause' : 'Play “${anim.title}”',
                onPressed: () => _provider.playbackState == 'running'
                    ? _provider.pauseAnimation()
                    : _provider.playAnimation(anim.id),
                icon: Icon(
                  _provider.playbackState == 'running' ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _t.teal,
                ),
                iconSize: 22,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Restart',
                onPressed: _provider.restartAnimation,
                icon: const Icon(Icons.replay_rounded),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                color: _t.textSecondary,
              ),
              Expanded(
                child: Slider(
                  value: _provider.timeline,
                  onChanged: _provider.scrubTo,
                  activeColor: _t.teal,
                  label: '${(_provider.timeline * 100).round()}%',
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<double>(
                  value: _provider.speed,
                  items: const [
                    DropdownMenuItem(value: 0.5, child: Text('0.5×', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 1.0, child: Text('1×', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 2.0, child: Text('2×', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => v == null ? null : _provider.setSpeed(v),
                  style: TextStyle(color: _t.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          Text(
            '${anim.title} (schematic) — ${anim.summary}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: _t.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Right: information panel ────────────────────────────────────────────

  Widget _buildInfo() {
    final asset = _provider.currentAsset;
    if (asset == null) {
      return Container(
        color: _t.surface,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Select a structure in the 3D view or from the hierarchy.\n\n'
            'Every model states its source, license and known simplifications.',
            style: TextStyle(color: _t.textMuted, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final selected = _provider.selectedComponent;
    return Container(
      color: _t.surface,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(asset.title, style: TextStyle(color: _t.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(asset.subtitle, style: TextStyle(color: _t.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 10),
          _badge(asset.verification),
          const SizedBox(height: 6),
          Text('Scale: ${asset.scaleLabel}', style: TextStyle(color: _t.textMuted, fontSize: 11.5)),
          if (selected != null) ...[
            const Divider(height: 24),
            Text('Selected: ${selected.name}',
                style: TextStyle(color: _t.teal, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 6),
            Text(selected.description, style: TextStyle(color: _t.textSecondary, fontSize: 12.5, height: 1.5)),
          ],
          const Divider(height: 24),
          Text('Learning objectives',
              style: TextStyle(color: _t.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          for (final o in asset.learningObjectives)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 13, color: _t.teal),
                  const SizedBox(width: 6),
                  Expanded(child: Text(o, style: TextStyle(color: _t.textSecondary, fontSize: 12, height: 1.4))),
                ],
              ),
            ),
          const Divider(height: 24),
          Text('Source & verification',
              style: TextStyle(color: _t.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Text(asset.source, style: TextStyle(color: _t.textMuted, fontSize: 11, height: 1.5)),
          Text('License: ${asset.license}', style: TextStyle(color: _t.textMuted, fontSize: 11)),
          if (asset.simplifications != null) ...[
            const SizedBox(height: 8),
            Icon(Icons.info_outline_rounded, size: 13, color: _t.warning),
            const SizedBox(height: 2),
            Text('Known simplifications: ${asset.simplifications}',
                style: TextStyle(color: _t.textMuted, fontSize: 11, height: 1.5)),
          ],
          if (asset.children.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Zoom deeper', style: TextStyle(color: _t.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            for (final childId in asset.children)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _t.teal,
                    side: BorderSide(color: _t.teal.withValues(alpha: 0.4)),
                  ),
                  onPressed: () => _provider.descendTo(childId),
                  icon: const Icon(Icons.zoom_in_rounded, size: 16),
                  label: Text(BioLabRegistry.byId(childId)?.title ?? childId),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _badge(BioVerification v) {
    final color = switch (v) {
      BioVerification.validatedStructure => _t.success,
      BioVerification.educationalReconstruction => _t.info,
      BioVerification.metadataOnly => _t.warning,
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
          Icon(v.icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(v.label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Right/bottom: practical ─────────────────────────────────────────────

  void _startPractical() {
    _provider.openAsset('bacterial-cell');
    _provider.startPractical(BacterialPracticalState());
    setState(() => _practicalOpen = true);
  }

  Widget _buildPractical() {
    final p = _provider.practical;
    if (p == null) {
      return Container(
        color: _t.surface,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Biology practical',
                style: TextStyle(color: _t.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Exploring a bacterial cell — identify the structures in the 3D '
              'model, then answer a short assessment.',
              style: TextStyle(color: _t.textSecondary, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _t.teal),
              onPressed: _startPractical,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start practical'),
            ),
          ],
        ),
      );
    }
    if (p.isComplete) {
      return Container(
        color: _t.surface,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Practical complete',
                style: TextStyle(color: _t.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Score: ${p.answeredCorrectly.length}/${p.questionCount} '
              '(${p.percentScore.round()}%)',
              style: TextStyle(color: _t.teal, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Progress is stored for this session. Integration with the '
              'existing assessment records is a documented future step '
              '(see practicals/bacterial_practical.dart).',
              style: TextStyle(color: _t.textMuted, fontSize: 11, height: 1.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _t.teal),
                  onPressed: _startPractical,
                  child: const Text('Restart practical'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    _provider.endPractical();
                    setState(() => _practicalOpen = false);
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final step = p.current;
    return Container(
      color: _t.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Step ${p.index + 1} of ${p.stepList.length}'
            '  ·  score ${p.answeredCorrectly.length}/${p.questionCount}',
            style: TextStyle(color: _t.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(step.prompt,
              style: TextStyle(color: _t.textPrimary, fontWeight: FontWeight.w700, fontSize: 14, height: 1.4)),
          if (step.hint.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Hint: ${step.hint}', style: TextStyle(color: _t.textMuted, fontSize: 11.5)),
          ],
          const SizedBox(height: 12),
          if (p.isIdentification)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Click the structure in the 3D view. Selected: '
                  '${_provider.selectedComponentId ?? '—'}',
                  style: TextStyle(color: _t.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _t.teal),
                  onPressed: _provider.selectedComponentId == null
                      ? null
                      : () {
                          final fb = _provider.practical!.answerIdentification(_provider.selectedComponentId);
                          _showFeedback(fb);
                        },
                  child: const Text('Check selection'),
                ),
              ],
            )
          else
            for (var i = 0; i < step.options!.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _t.textPrimary,
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => _showFeedback(_provider.answerPractical(i)),
                  child: Text(step.options![i], style: const TextStyle(fontSize: 12.5)),
                ),
              ),
          const Spacer(),
          OutlinedButton(
            onPressed: () {
              _provider.advancePractical();
              // Identification steps auto-advance on the next selection.
            },
            child: const Text('Next step'),
          ),
        ],
      ),
    );
  }

  void _showFeedback(PracticalFeedback fb) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _t.surfaceElevated,
        title: Row(
          children: [
            Icon(fb.correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: fb.correct ? _t.success : _t.error, size: 22),
            const SizedBox(width: 8),
            Text(fb.correct ? 'Correct' : 'Not quite',
                style: TextStyle(color: fb.correct ? _t.success : _t.error, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(fb.explanation, style: TextStyle(color: _t.textSecondary, fontSize: 12.5, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (fb.correct) _provider.advancePractical();
            },
            child: Text(fb.correct ? 'Continue' : 'Try again'),
          ),
        ],
      ),
    );
  }
}
