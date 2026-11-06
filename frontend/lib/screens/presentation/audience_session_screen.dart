import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/presentation_session_controller.dart';

/// Attendee view of a live AI presentation session (Phase 5).
///
/// Reachable two ways: an authenticated user joining with a session id, or
/// an anonymous guest with a join code + display name. Server-side role
/// assignment decides what this screen can do — presenter-only controls are
/// not present, not just hidden.
class AudienceSessionScreen extends StatefulWidget {
  final String? sessionId;
  final String? joinCode;
  final PresentationSessionController? controller;

  const AudienceSessionScreen({
    super.key,
    this.sessionId,
    this.joinCode,
    this.controller,
  });

  @override
  State<AudienceSessionScreen> createState() => _AudienceSessionScreenState();
}

class _AudienceSessionScreenState extends State<AudienceSessionScreen> {
  late final PresentationSessionController _session;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _questionController = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _session = widget.controller ?? PresentationSessionController();
    if (widget.sessionId != null) {
      _join();
    }
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    bool ok;
    if (_session.sessionId == null && widget.joinCode != null) {
      ok = false; // guest path needs a name first — gate below
    } else {
      ok = await _session.joinAsUser(sessionIdOrCode: widget.sessionId!);
    }
    if (ok) {
      await _session.refresh();
      await _session.replayEvents();
    } else {
      setState(() => _error = 'Could not join that session');
    }
    if (mounted) setState(() => _joining = false);
  }

  Future<void> _joinAsGuest() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) {
      setState(() => _error = 'Display name and join code are required');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    final ok = await _session.joinAsGuest(joinCode: code, displayName: name);
    if (ok) {
      await _session.refresh();
      await _session.replayEvents();
    } else {
      setState(() => _error = 'Join failed — check the code');
    }
    if (mounted) setState(() => _joining = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Live Presentation')),
      body: AnimatedBuilder(
        animation: _session,
        builder: (context, _) {
          if (_session.sessionId == null) {
            return _JoinForm(
              nameController: _nameController,
              codeController: _codeController,
              joining: _joining,
              error: _error,
              onJoinGuest: _joinAsGuest,
              theme: theme,
            );
          }
          if (_session.isCompleted) {
            return const Center(child: Text('This session has ended.'));
          }
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(children: [
                  Text('Slide ${_session.currentSlideIndex + 1}',
                      style: theme.textTheme.labelLarge),
                  const Spacer(),
                  Text(_session.isPaused ? 'PAUSED' : 'LIVE',
                      style: TextStyle(
                          color: _session.isPaused ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _session.currentSlideTitle.isEmpty
                        ? 'Waiting for the presenter…'
                        : _session.currentSlideTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              _AskQuestionBar(session: _session, controller: _questionController),
            ],
          );
        },
      ),
    );
  }
}

class _JoinForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController codeController;
  final bool joining;
  final String? error;
  final VoidCallback onJoinGuest;
  final ThemeData theme;

  const _JoinForm({
    required this.nameController,
    required this.codeController,
    required this.joining,
    required this.error,
    required this.onJoinGuest,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Join the presentation', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Join code',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: joining ? null : onJoinGuest,
              child: Text(joining ? 'Joining…' : 'Join session'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AskQuestionBar extends StatelessWidget {
  final PresentationSessionController session;
  final TextEditingController controller;
  const _AskQuestionBar({required this.session, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Ask a question…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLength: 2000,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                final ok = await session.askQuestion(text);
                if (ok) controller.clear();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Question sent' : 'Could not send (rate limited?)'),
                  ));
                }
              },
              child: const Text('Ask'),
            ),
          ],
        ),
      ),
    );
  }
}
