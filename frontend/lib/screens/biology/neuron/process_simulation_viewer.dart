import 'package:flutter/material.dart';

import '../../../core/theme/app_animations.dart';
import 'process_simulation.dart';

/// Generic animated viewer for biological process simulations.
///
/// Owns the whole player: play/pause, restart, step-by-step, speed (0.5×/1×/2×),
/// labels and explanations toggles, zoom (InteractiveViewer), fullscreen and the
/// progressive Teach Mode. Everything below the player surface (what the stage
/// actually looks like) is delegated to [buildFrame], which receives a
/// [SimulationFrame] each tick and returns the visual (typically a CustomPaint).
///
/// This class intentionally knows nothing about neurons/synapses/mitosis — it
/// is the reusable foundation required by the Biology Visualization module.
class ProcessSimulationViewer extends StatefulWidget {
  const ProcessSimulationViewer({
    super.key,
    required this.stages,
    required this.buildFrame,
    this.title,
    this.subtitle,
    this.accent = const Color(0xFF10B981),
    this.canvasHeight = 520,
    this.painterAspect = 1200 / 744,
  });

  /// Ordered stages of the process.
  final List<SimulationStage> stages;

  /// Builds the visual for a given frame.
  final Widget Function(BuildContext context, SimulationFrame frame) buildFrame;

  final String? title;
  final String? subtitle;
  final Color accent;
  final double canvasHeight;

  /// Logical aspect ratio (width / height) of the caller's painter. The canvas
  /// letterboxes the painter inside [canvasHeight] so text is never distorted.
  final double painterAspect;

  /// Nominal full-loop duration (seconds) at 1× speed.
  static const double baseDurationSeconds = 16.0;

  @override
  State<ProcessSimulationViewer> createState() => _ProcessSimulationViewerState();
}

class _ProcessSimulationViewerState extends State<ProcessSimulationViewer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final List<TeachStep> _teachSteps;

  bool _playing = false;
  bool _stepMode = false;
  bool _teachMode = false;
  bool _labelsOn = true;
  bool _explanationsOn = true;
  double _speed = 1.0;

  /// Teach step currently revealed (valid in teach mode).
  int _teachStep = 0;

  /// Stage that furnishing a step in step mode started on; used to pause at the
  /// next stage boundary.
  int _stepLock = 0;

  bool get _dark => Theme.of(context).brightness == Brightness.dark && !useAmoledPanel();

  @override
  void initState() {
    super.initState();
    _teachSteps = buildTeachSteps(widget.stages);
    _ctl = AnimationController(
      vsync: this,
      duration: _duration(),
    )..addListener(_onTick);
  }

  Duration _duration() => Duration(milliseconds: (ProcessSimulationViewer.baseDurationSeconds * 1000 / _speed).round());

  int get _stageCount => widget.stages.length;

  List<SimulationStage> get _visibleStages => _teachMode ? _teachSteps[_teachStep].stages : widget.stages;

  int get _visibleCount => _visibleStages.length;

  int get _visibleFirstIndex => _teachMode ? _teachSteps[_teachStep].firstStage : 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
    if (!_playing) return;
    if (!_stepMode) return;
    final idx = _currentStageIndex;
    if (idx != _stepLock) {
      _ctl.stop();
      final next = idx == _stageCount - 1 ? 0.0 : idx / _stageCount;
      _ctl.value = next;
      setState(() => _playing = false);
    }
  }

  /// Global (full stage list) index of the stage currently on screen.
  int get _currentStageIndex {
    final t = _ctl.value;
    final raw = (t * _visibleCount).clamp(0.0, _visibleCount - 1e-9);
    return _visibleFirstIndex + raw.floor();
  }

  SimulationFrame get _frame {
    final t = _ctl.value;
    final count = _visibleCount;
    final raw = (t * count).clamp(0.0, count - 1e-9);
    final local = raw.floor();
    final progress = (raw - local).clamp(0.0, 1.0);
    final stageIndex = _visibleFirstIndex + local;
    return SimulationFrame(
      stageIndex: stageIndex,
      stage: widget.stages[stageIndex],
      progress: progress,
      labelsOn: _labelsOn,
      dark: _dark,
    );
  }

  void _setT(double t) => _ctl.value = t.clamp(0.0, 1.0);

  void _togglePlay() {
    if (_playing) {
      _ctl.stop();
      setState(() => _playing = false);
      return;
    }
    if (_stepMode) {
      // Jump to the start of the upcoming stage and run exactly one stage.
      final next = (_currentStageIndex + 1) % _stageCount;
      _setT(next / _stageCount);
      setState(() => _stepLock = next);
    } else {
      setState(() => _stepLock = _currentStageIndex);
    }
    setState(() => _playing = true);
    _ctl.forward();
  }

  void _restart() {
    _ctl.stop();
    _setT(0);
    setState(() {
      _playing = false;
      _stepLock = _visibleFirstIndex;
    });
  }

  void _stepForward() {
    _ctl.stop();
    if (_teachMode) {
      setState(() {
        _teachStep = (_teachStep + 1) % _teachSteps.length;
        _playing = false;
        _ctl.value = 0.0;
        _stepLock = _teachSteps[_teachStep].firstStage;
      });
      return;
    }
    final next = (_currentStageIndex + 1) % _stageCount;
    _setT(next / _stageCount);
    setState(() {
      _playing = false;
      _stepLock = next;
    });
  }

  void _stepBack() {
    _ctl.stop();
    if (_teachMode) {
      setState(() {
        _teachStep = (_teachStep - 1 + _teachSteps.length) % _teachSteps.length;
        _playing = false;
        _ctl.value = 0.0;
        _stepLock = _teachSteps[_teachStep].firstStage;
      });
      return;
    }
    final prev = (_currentStageIndex - 1 + _stageCount) % _stageCount;
    _setT(prev / _stageCount);
    setState(() {
      _playing = false;
      _stepLock = prev;
    });
  }

  void _setSpeed(double s) {
    setState(() => _speed = s);
    _ctl.duration = _duration();
  }

  void _toggleTeachMode() {
    _ctl.stop();
    setState(() {
      _teachMode = !_teachMode;
      if (_teachMode) {
        _teachStep = 0;
      }
      _playing = false;
      _ctl.value = 0.0;
      _stepLock = _visibleFirstIndex;
    });
  }

  void _showFullscreen() {
    if (widget.title == null) return;
    Navigator.of(context).push(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => Scaffold(
        backgroundColor: _canvasPaddingColor(),
        body: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    color: _inkMutedColor(),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Exit fullscreen',
                  ),
                  Expanded(
                    child: Text(
                      widget.title!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _inkColor(),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: RepaintBoundary(
                    child: ProcessSimulationViewer(
                      stages: widget.stages,
                      buildFrame: widget.buildFrame,
                      title: widget.title,
                      subtitle: widget.subtitle,
                      accent: widget.accent,
                      canvasHeight: double.infinity,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  Color _accentColor() => widget.accent;
  Color _inkColor() => _dark ? const Color(0xFFF2F1F8) : const Color(0xFF1E1E2A);
  Color _inkMutedColor() => _dark ? const Color(0xFF9A98AC) : const Color(0xFF6B6B7E);
  Color _panelColor() => _dark ? const Color(0xFF17172A) : const Color(0xFFFFFFFF);
  Color _borderColor() => _dark ? const Color(0xFF2A2A3E) : const Color(0xFFE3E2EA);
  Color _canvasPaddingColor() => _dark ? const Color(0xFF0A0A14) : const Color(0xFFF6F5FA);

  // ── Layout ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(accent),
        const SizedBox(height: 10),
        _canvas(accent),
        const SizedBox(height: 10),
        if (_explanationsOn && _visibleStages.isNotEmpty) _explanationPanel(accent),
        const SizedBox(height: 10),
        _dots(accent),
        const SizedBox(height: 8),
        _controls(accent),
      ],
    );
  }

  Widget _header(Color accent) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.title != null)
                  Text(
                    widget.title!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _inkColor(),
                    ),
                  ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(fontSize: 12, color: _inkMutedColor()),
                  ),
                ],
              ],
            ),
          ),
          _teachToggle(accent),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Fullscreen',
            onPressed: _showFullscreen,
            icon: const Icon(Icons.fullscreen_rounded),
            color: _inkMutedColor(),
          ),
        ],
      );

  Widget _teachToggle(Color accent) => Tooltip(
        message: 'Teach Mode — progressively reveal the process',
        child: GestureDetector(
          onTap: _toggleTeachMode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _teachMode ? accent.withValues(alpha: 0.16) : _panelColor(),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _teachMode ? accent.withValues(alpha: 0.55) : _borderColor(),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _teachMode ? Icons.school_rounded : Icons.school_outlined,
                  size: 16,
                  color: _teachMode ? accent : _inkMutedColor(),
                ),
                const SizedBox(width: 6),
                Text(
                  _teachMode ? 'Teach Mode' : 'Teach Mode',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _teachMode ? accent : _inkMutedColor(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _canvas(Color accent) {
    final frame = _frame;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: widget.canvasHeight,
        decoration: BoxDecoration(
          color: _canvasPaddingColor(),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor()),
        ),
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 10,
          boundaryMargin: const EdgeInsets.all(80),
          child: Center(
            child: AspectRatio(
              aspectRatio: widget.painterAspect,
              child: widget.buildFrame(context, frame),
            ),
          ),
        ),
      ),
    );
  }

  Widget _explanationPanel(Color accent) {
    final frame = _frame;
    final teaching = _teachMode;
    final heading = teaching ? frame.stage.teachGroup : frame.stage.title;
    final explanation = frame.stage.explanation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _dark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              teaching ? Icons.school_rounded : Icons.lightbulb_outline_rounded,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  explanation,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: _inkColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dots(Color accent) {
    final steps = _teachMode ? _teachSteps : null;
    final count = steps?.length ?? _stageCount;
    final active = _teachMode ? _teachStep : _currentStageIndex;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == active;
        return AnimatedContainer(
          duration: AppDurations.fast,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: selected ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? accent : _borderColor(),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _controls(Color accent) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          _roundButton(Icons.play_arrow_rounded, _playing ? Icons.pause_rounded : null, 'Play / Pause', _togglePlay),
          _roundButton(Icons.replay_rounded, null, 'Restart', _restart),
          _roundButton(Icons.skip_previous_rounded, null, 'Previous step', _stepBack),
          _roundButton(Icons.skip_next_rounded, null, 'Next step', _stepForward),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 0.5, label: Text('0.5×')),
              ButtonSegment(value: 1.0, label: Text('1×')),
              ButtonSegment(value: 2.0, label: Text('2×')),
            ],
            selected: {_speed},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _inkColor()),
              ),
            ),
            onSelectionChanged: (s) => _setSpeed(s.first),
          ),
          _toggleChip(
              accent, Icons.label_outline_rounded, 'Labels', _labelsOn, () => setState(() => _labelsOn = !_labelsOn)),
          _toggleChip(accent, Icons.chat_bubble_outline_rounded, 'Explanations', _explanationsOn,
              () => setState(() => _explanationsOn = !_explanationsOn)),
          _toggleChip(accent, _stepMode ? Icons.skip_next_rounded : Icons.auto_stories_outlined, 'Step-by-step',
              _stepMode, () => setState(() => _stepMode = !_stepMode)),
        ],
      );

  Widget _roundButton(IconData idle, IconData? pressed, String tooltip, VoidCallback onTap) {
    final icon = pressed ?? idle;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: pressed != null ? widget.accent.withValues(alpha: 0.18) : _panelColor(),
            shape: BoxShape.circle,
            border: Border.all(
              color: pressed != null ? widget.accent.withValues(alpha: 0.5) : _borderColor(),
            ),
          ),
          child: Icon(icon, size: 24, color: pressed != null ? widget.accent : _inkColor()),
        ),
      ),
    );
  }

  Widget _toggleChip(Color accent, IconData icon, String label, bool on, VoidCallback onTap) => Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: on ? accent.withValues(alpha: 0.16) : _panelColor(),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on ? accent.withValues(alpha: 0.55) : _borderColor(),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: on ? accent : _inkMutedColor()),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: on ? accent : _inkMutedColor(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Guard so the generic viewer stays independent of a fixed dark-mode policy.
bool useAmoledPanel() => false;
