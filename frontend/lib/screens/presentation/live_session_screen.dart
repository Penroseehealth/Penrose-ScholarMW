import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/presentation_session_controller.dart';
import '../../services/livekit_service.dart';

/// Presenter cockpit for a live AI presentation session (Phase 5).
///
/// Role-gated by construction: the screen is only reachable with a session
/// whose server-side role is presenter or co_presenter — attendee-only
/// controls (question box, raise hand) are intentionally absent here.
///
/// Realtime: `scholar.session` data-channel events via [onLiveEvent]; the
/// controller detects sequence gaps and recovers by re-fetch (approved 0D).
class PresenterCockpitScreen extends StatefulWidget {
  final String sessionId;
  final PresentationSessionController? controller;
  final LiveKitService? liveKit;

  const PresenterCockpitScreen({
    super.key,
    required this.sessionId,
    this.controller,
    this.liveKit,
  });

  @override
  State<PresenterCockpitScreen> createState() => _PresenterCockpitScreenState();
}

class _PresenterCockpitScreenState extends State<PresenterCockpitScreen> {
  late final PresentationSessionController _session;
  Timer? _heartbeat;
  String? _error;

  @override
  void initState() {
    super.initState();
    _session = widget.controller ?? PresentationSessionController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final ok = await _session.refresh();
    if (!ok) {
      setState(() => _error = 'Session not found or ended');
      return;
    }
    if (!_session.isPresenter && !_session.canInterrupt) {
      setState(() => _error = 'This cockpit is for presenters only');
      return;
    }
    await _session.replayEvents();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) => _session.heartbeat());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Session')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Session — ${_session.roleLabel}'),
        actions: [
          if (_session.isPresenter)
            PopupMenuButton<String>(
              tooltip: 'AI response policy',
              onSelected: (p) => _session.setPolicy(p),
              icon: const Icon(Icons.psychology_alt_outlined),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'auto', child: Text('AI answers automatically')),
                PopupMenuItem(value: 'approval', child: Text('Approve each answer')),
                PopupMenuItem(value: 'presenter_only', child: Text('AI never answers')),
              ],
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _session,
        builder: (context, _) {
          return Column(
            children: [
              _StatusStrip(session: _session),
              if (_session.narrationFallbackReason != null && !_session.narrationSuspended)
                _FallbackBanner(session: _session),
              Expanded(
                child: _SlideStage(session: _session),
              ),
              _PresenterControls(session: _session),
              if (_session.questions.isNotEmpty)
                SizedBox(height: 200, child: _ModerationQueue(session: _session)),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatusStrip extends StatelessWidget {
  final PresentationSessionController session;
  const _StatusStrip({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presLabel = switch (session.presState) {
      'live' => 'PRESENTING',
      'paused' => 'PAUSED',
      'completed' => 'ENDED',
      _ => 'IDLE',
    };
    final aiLabel = switch (session.aiState) {
      'responding' => 'AI RESPONDING',
      'awaiting_approval' => 'QUESTION AWAITING APPROVAL',
      'listening' => 'AI LISTENING',
      'suspended' => 'AI DISABLED',
      _ => 'AI IDLE',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          _Chip(label: presLabel),
          const SizedBox(width: 8),
          _Chip(label: aiLabel),
          const Spacer(),
          Text('Slide ${session.currentSlideIndex + 1}${session.slideCount > 0 ? '/${session.slideCount}' : ''}',
              style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  final PresentationSessionController session;
  const _FallbackBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade100,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.record_voice_over_outlined),
        title: const Text('Cloned voice unavailable — speaking with fallback voice',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(session.narrationFallbackReason ?? ''),
        trailing: Wrap(spacing: 4, children: [
          TextButton(onPressed: () => session.clearFallbackAndContinue(), child: const Text('Continue')),
          TextButton(onPressed: () => session.disableNarration(), child: const Text('Disable narration')),
        ]),
      ),
    );
  }
}

class _SlideStage extends StatelessWidget {
  final PresentationSessionController session;
  const _SlideStage({required this.session});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        session.currentSlideTitle.isEmpty
            ? 'Waiting for slide events…'
            : session.currentSlideTitle,
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PresenterControls extends StatelessWidget {
  final PresentationSessionController session;
  const _PresenterControls({required this.session});

  @override
  Widget build(BuildContext context) {
    final canPauseResume = session.isLive || session.isPaused;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (session.presState == 'idle')
            FilledButton.icon(
              onPressed: session.start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
          if (canPauseResume)
            OutlinedButton.icon(
              onPressed: session.isLive ? session.pause : session.resume,
              icon: Icon(session.isLive ? Icons.pause : Icons.play_arrow),
              label: Text(session.isLive ? 'Pause' : 'Resume'),
            ),
          OutlinedButton.icon(
            onPressed: session.interrupt,
            icon: const Icon(Icons.front_hand),
            label: const Text('Interrupt AI'),
          ),
          OutlinedButton.icon(
            onPressed: session.takeover,
            icon: const Icon(Icons.gavel),
            label: const Text('Take over'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => session.gotoSlide(session.currentSlideIndex + 1),
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next slide'),
          ),
          FilledButton.tonalIcon(
            onPressed: session.currentSlideIndex > 0
                ? () => session.gotoSlide(session.currentSlideIndex - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: session.end,
            icon: const Icon(Icons.stop),
            label: const Text('End session'),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

class _ModerationQueue extends StatelessWidget {
  final PresentationSessionController session;
  const _ModerationQueue({required this.session});

  @override
  Widget build(BuildContext context) {
    final pending = session.questions
        .where((q) => q['status'] == 'raised' || q['status'] == 'approved')
        .toList();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Audience questions (${pending.length})',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Expanded(
            child: pending.isEmpty
                ? const Center(child: Text('No pending questions'))
                : ListView.builder(
                    itemCount: pending.length,
                    itemBuilder: (context, i) {
                      final q = pending[i];
                      return ListTile(
                        dense: true,
                        title: Text('${q['text']}'),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Let AI answer',
                              icon: const Icon(Icons.auto_awesome, size: 20),
                              onPressed: () => session.moderate(q['id'] as int, 'approve'),
                            ),
                            IconButton(
                              tooltip: 'Answer myself',
                              icon: const Icon(Icons.edit_note, size: 20),
                              onPressed: () async {
                                final answer = await _askAnswer(context);
                                if (answer != null && answer.isNotEmpty) {
                                  await session.moderate(q['id'] as int, 'answer', answerText: answer);
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Defer',
                              icon: const Icon(Icons.schedule, size: 20),
                              onPressed: () => session.moderate(q['id'] as int, 'defer'),
                            ),
                            IconButton(
                              tooltip: 'Reject',
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => session.moderate(q['id'] as int, 'reject'),
                            ),
                          ],
                        ),
                      );
                  },
                  ),
          ),
        ],
      ),
    );
  }

  Future<String?> _askAnswer(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your answer'),
        content: TextField(controller: controller, autofocus: true, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Answer'),
          ),
        ],
      ),
    );
  }
}

extension on PresentationSessionController {
  String get roleLabel => switch (role) {
        'presenter' => 'Presenter',
        'co_presenter' => 'Co-presenter',
        _ => 'Attendee',
      };
}
