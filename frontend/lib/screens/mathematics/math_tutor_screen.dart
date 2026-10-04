import 'package:flutter/material.dart';

import '../../services/math_tutor_api.dart';
import '../../services/voice_catalog_service.dart';
import '../../services/web_speech_service.dart';
import '../../voice/tts_service.dart';
import '../../voice/voice_session_manager.dart';
import '../../widgets/math_tutor/math_solution.dart';
import '../../widgets/math_tutor/math_solver.dart';
import '../../widgets/math_tutor/math_tex.dart';
import '../../widgets/math_tutor/math_tutor_audio_bar.dart';
import '../../widgets/math_tutor/math_tutor_player.dart';
import '../../widgets/math_tutor/math_typewriter.dart';
import '../../widgets/math_tutor/tutor_visual.dart';
import '../../widgets/math_tutor/voice_accent_picker.dart';

/// AI Visual Mathematics Tutor.
///
/// The backend solves every problem deterministically with SymPy and verifies
/// the result; this screen typesets the working, draws a contextual picture and
/// narrates each step. A conversational voice panel sits alongside the
/// workspace so the student can ask follow-up questions by voice or text.
class MathTutorScreen extends StatefulWidget {
  const MathTutorScreen({super.key, this.enableRemote = true, this.api, this.player});

  /// When false the screen stays entirely on the deterministic on-device
  /// solver. Tests use this to avoid real network timers.
  final bool enableRemote;

  /// Optional injected client, used by tests to exercise the server path.
  final MathTutorApi? api;

  /// Optional injected narration player, used by tests to hold playback on a
  /// step. When null the screen owns and disposes its own player.
  final MathTutorPlayer? player;

  @override
  State<MathTutorScreen> createState() => _MathTutorScreenState();
}

class _MathTutorScreenState extends State<MathTutorScreen> {
  static const List<String> _examples = <String>[
    'Find the hypotenuse of a right triangle with legs 3 and 4 cm',
    'In a right triangle the opposite side is 6 cm and the angle is 30\u00b0. Find the hypotenuse',
    'Construct a triangle with AB = 5 cm, AC = 7 cm and angle BAC = 60\u00b0',
    'Draw a triangle with sides 5 cm, 6 cm and 7 cm',
    'Find the area and perimeter of a rectangle 12 cm by 5 cm',
    'Find the volume of a cylinder with radius 7 cm and height 10 cm',
    'A circle has radius 6 cm. Find its circumference and area',
    'Maximise P = 3x + 2y subject to x + y \u2264 4, x \u2265 0, y \u2265 0',
    'Plot the line y = 2x + 1 and find where it crosses the x-axis',
    'Sketch the graph of y = x\u00b2 - 4x + 3 and state the turning point',
  ];

  final TextEditingController _input = TextEditingController();
  final TextEditingController _question = TextEditingController();
  final VoiceCatalogService _catalog = VoiceCatalogService();
  late final MathTutorPlayer _player = widget.player ?? MathTutorPlayer();
  final MathTutorApi _ownApi = MathTutorApi();
  MathTutorApi get _api => widget.api ?? _ownApi;
  final PenroseTtsService _previewTts = PenroseTtsService(session: VoiceSessionManager());
  final PenroseTtsService _chatTts = PenroseTtsService(session: VoiceSessionManager());
  final WebSpeechService _speech = WebSpeechService();
  final Map<int, GlobalKey> _stepKeys = <int, GlobalKey>{};
  final GlobalKey _visualKey = GlobalKey();
  final ScrollController _workspaceScroll = ScrollController();

  TutorSolution? _solution;
  String? _message;
  String _voiceId = VoiceCatalogService.defaultVoiceId;
  String? _voiceNotice;
  int _solveSeq = 0;

  final List<_TutorTurn> _turns = <_TutorTurn>[];
  final List<String> _explainedSteps = <String>[];
  bool _asking = false;
  bool _listening = false;
  bool _speechSupported = false;
  String? _lastReply;

  TutorVoice get _voice => _catalog.voiceForId(_voiceId);

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayerChanged);
    _applyVoice(VoiceCatalogService.defaultVoiceId);
    _speechSupported = _speech.isSupported;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _previewTts.initialize();
    _chatTts.initialize();
    await _catalog.load();
    final savedVoice = await VoiceCatalogService.loadPreferredVoiceId();
    final savedSpeed = await VoiceCatalogService.loadPreferredSpeed();
    if (!mounted) return;
    final resolved = _catalog.voiceForId(savedVoice);
    setState(() {
      _voiceId = resolved.id;
      _voiceNotice = _catalog.byId(savedVoice) == null
          ? 'Your saved voice is unavailable, so I am using ${resolved.label}.'
          : null;
    });
    _applyVoice(_voiceId);
    await _player.setSpeed(MathTutorAudioBar.presetFor(savedSpeed).value);
  }

  /// Point every narration pipeline at the chosen catalog voice.
  ///
  /// The player (step narration) and the chat service (explanations) must share
  /// the exact voice id, otherwise the tutor would answer in a different accent
  /// from the one selected.
  void _applyVoice(String id) {
    final voice = _catalog.voiceForId(id);
    _player.lang = voice.locale;
    _player.voiceId = voice.id;
    _chatTts.voiceId = voice.id;
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_player.followVisual || (!_player.isPlaying && !_player.isBusy)) return;
    final id = _player.currentStep?.id;
    final key = id == null ? _visualKey : _stepKeys[id];
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(key));
  }

  void _ensureVisible(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: 0.25,
    );
  }

  Future<void> _solve() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    await _player.stopNarration();
    _chatTts.stop();

    // Solve on device first so the working appears instantly, then upgrade to
    // the richer, verified server solution when it arrives. If the device
    // solver does not recognise the problem we still ask the server, which
    // knows quadratics and other topics the offline engine does not cover.
    final local = TutorSolver.solve(text);
    if (local == null && !widget.enableRemote) {
      setState(() {
        _message = _unsupportedMessage;
        _solution = null;
        _stepKeys.clear();
      });
      return;
    }

    final requestId = ++_solveSeq;
    setState(() {
      _message = null;
      _solution = local;
      _stepKeys.clear();
      _turns.clear();
      _explainedSteps.clear();
      _lastReply = null;
    });
    if (local != null) await _player.load(local);

    if (!widget.enableRemote) return;
    final remote = await _api.solve(text);
    if (!mounted || requestId != _solveSeq) return;
    if (remote == null) {
      if (local == null) {
        setState(() => _message = _unsupportedMessage);
      }
      return;
    }
    setState(() {
      _solution = remote;
      _stepKeys.clear();
    });
    await _player.load(remote);
  }

  static const String _unsupportedMessage = 'I could not recognise that as a maths problem yet. Try a right-angled '
      'triangle, a linear equation like "2x + 9 = 24", a quadratic such as '
      '"x^2 + 5x + 6 = 0", a percentage like "15% of 240", or a calculation like "12 + 6 * 2".';

  Future<void> _selectVoice(String id) async {
    final voice = _catalog.voiceForId(id);
    setState(() {
      _voiceId = voice.id;
      _voiceNotice = _catalog.byId(id) == null ? 'That voice is unavailable, so I am using ${voice.label}.' : null;
    });
    _applyVoice(voice.id);
    await VoiceCatalogService.savePreferredVoiceId(voice.id);
    if (_player.isPlaying || _player.isBusy) await _player.replay();
  }

  Future<void> _previewVoice(String id) async {
    final voice = _catalog.voiceForId(id);
    await VoiceCatalogService.savePreferredVoiceId(voice.id);
    await _player.stopNarration();
    _previewTts.voiceId = voice.id;
    await _previewTts.speakOnce(
      voice.previewText.isEmpty ? 'Let us work through this together, one clear step at a time.' : voice.previewText,
      lang: voice.locale,
      speed: _player.speed,
    );
  }

  Future<void> _useExample(String example) async {
    _input.text = example;
    await _solve();
  }

  Future<void> _ask([String? preset]) async {
    final question = (preset ?? _question.text).trim();
    if (question.isEmpty || _asking) return;

    _question.clear();
    await _player.pause();
    _chatTts.stop();
    setState(() {
      _turns.add(_TutorTurn(text: question, isUser: true));
      _asking = true;
    });

    final problem = _solution?.problem ?? _input.text.trim();

    // If the student typed a line of their own working, inspect it before
    // answering so a wrong operation is named and corrected rather than ignored.
    TutorWorkCheck? work;
    if (widget.enableRemote && _looksLikeWorking(question)) {
      work = await _api.check(problem: problem, studentLine: question);
    }

    TutorReply? reply;
    if (work == null || work.ok) {
      reply = widget.enableRemote
          ? await _api.explain(
              problem: problem,
              question: question,
              solution: _solution,
              stepId: _player.currentStep?.id,
              topic: _solution?.topic,
              currentEquation: _player.currentStep?.displayLines.join(' ; '),
              conceptsExplained: _explainedSteps,
              history: _turns
                  .where((turn) => !turn.pending)
                  .map((turn) => <String, String>{'role': turn.isUser ? 'user' : 'assistant', 'content': turn.text})
                  .toList(),
            )
          : null;
    }

    if (!mounted) return;
    final text = work != null && !work.ok
        ? work.message
        : reply?.text ??
            'I could not reach the tutor service just now, but the worked solution on the left is verified. '
                'Try replaying the step you are stuck on, or ask again in a moment.';
    setState(() {
      _asking = false;
      _lastReply = text;
      _turns.add(_TutorTurn(text: text, isUser: false, pending: reply == null && work == null));
    });

    final stepRef = work?.stepRef ?? reply?.stepRef;
    if (stepRef != null) {
      for (final step in _solution?.steps ?? const <TutorStep>[]) {
        if (step.id == stepRef) {
          if (!_explainedSteps.contains(step.title)) _explainedSteps.add(step.title);
          break;
        }
      }
      await _player.seekTo(stepRef, autoplay: false);
    }
    await _chatTts.speakOnce(text, lang: _voice.locale, speed: _player.speed);
  }

  /// Whether the message is the student's own equation, e.g. "2x = 33".
  bool _looksLikeWorking(String text) =>
      _solution?.topic == 'linear_equation' && text.contains('=') && RegExp('[a-zA-Z]').hasMatch(text);

  Future<void> _replayReply() async {
    final text = _lastReply;
    if (text == null || text.isEmpty) return;
    await _player.pause();
    _chatTts.stop();
    await _chatTts.speakOnce(text, lang: _voice.locale, speed: _player.speed);
  }

  void _toggleListening() {
    if (_listening) {
      _speech.stopListening();
      setState(() => _listening = false);
      return;
    }
    if (!_speech.isSupported) {
      setState(() => _message = 'Voice input is not available in this browser. You can type your question instead.');
      return;
    }
    setState(() => _listening = true);
    _speech.startListening(
      lang: _voice.locale,
      onResult: (text, isFinal) {
        if (isFinal && text.trim().isNotEmpty) {
          if (mounted) setState(() => _listening = false);
          _ask(text);
        }
      },
      onEnd: () {
        if (mounted) setState(() => _listening = false);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _message = 'I could not hear that clearly. Please try again or type your question.';
        });
      },
    );
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    _previewTts.stop();
    _chatTts.dispose();
    _speech.dispose();
    if (widget.player == null) _player.dispose();
    _input.dispose();
    _question.dispose();
    _workspaceScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final solution = _solution;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Mathematics Tutor'),
        actions: <Widget>[
          IconButton(
            tooltip: _player.followVisual ? 'Following narration' : 'Follow narration',
            icon: Icon(_player.followVisual ? Icons.link_rounded : Icons.link_off_rounded),
            onPressed: () => _player.setFollowVisual(!_player.followVisual),
          ),
        ],
      ),
      drawer: _buildSettingsDrawer(context),
      body: Column(
        children: <Widget>[
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1024;
                final main = _buildMainColumn(context, solution);
                final voice = _buildVoicePanel(context);
                if (!wide) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: <Widget>[
                      ...main,
                      const SizedBox(height: 16),
                      voice,
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: ListView(controller: _workspaceScroll, children: main)),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 380,
                        child: SingleChildScrollView(child: voice),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          MathTutorAudioBar(player: _player, voiceLabel: _voice.label),
        ],
      ),
    );
  }

  List<Widget> _buildMainColumn(BuildContext context, TutorSolution? solution) {
    final scheme = Theme.of(context).colorScheme;
    return <Widget>[
      TextField(
        controller: _input,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _solve(),
        decoration: InputDecoration(
          labelText: 'Ask a maths problem',
          hintText: _examples.first,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: IconButton(
            tooltip: 'Solve',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: _solve,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: <Widget>[
          for (final example in _examples)
            ActionChip(
              label: Text(
                example.length > 46 ? '${example.substring(0, 46)}\u2026' : example,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              onPressed: () => _useExample(example),
            ),
        ],
      ),
      if (_message != null) ...<Widget>[
        const SizedBox(height: 14),
        Card(
          color: scheme.errorContainer.withAlpha(120),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.help_outline_rounded, size: 18, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(_message!, style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          ),
        ),
      ],
      if (solution != null) ...<Widget>[
        const SizedBox(height: 16),
        _ProblemCard(solution: solution),
        const SizedBox(height: 14),
        if (solution.visualKind != TutorVisualKind.none &&
            solution.visualKind != TutorVisualKind.expression) ...<Widget>[
          TutorVisualCard(key: _visualKey, solution: solution, stepIndex: _player.index),
          const SizedBox(height: 14),
        ],
        Row(
          children: <Widget>[
            Text('Worked solution', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${solution.stepCount} steps \u00b7 ${solution.topic.replaceAll('_', ' ')}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _BoardSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final step in solution.steps)
                if (step.id <= (_player.currentStep?.id ?? 1) || _player.state == MathTutorPlaybackState.finished)
                  KeyedSubtree(
                    key: _stepKeys.putIfAbsent(step.id, GlobalKey.new),
                    child: _LiveStepTile(
                      step: step,
                      active: step.id == _player.currentStep?.id,
                      done:
                          step.id < (_player.currentStep?.id ?? 1) || _player.state == MathTutorPlaybackState.finished,
                      playing: _player.isPlaying || _player.isBusy,
                      speed: _player.speed,
                      onTap: () => _player.seekTo(step.id),
                    ),
                  ),
              // The answer is only written once the working that earns it is on
              // the board, so the tutor never gives the result away early.
              if (solution.finalAnswer.isNotEmpty && _player.isLastStep) ...<Widget>[
                const SizedBox(height: 2),
                Divider(color: scheme.outlineVariant.withAlpha(140)),
                _FinalAnswerBlock(solution: solution),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  /// Settings live behind the hamburger so the solving board stays uncluttered.
  Widget _buildSettingsDrawer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.tune_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Text('Settings', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 18),
            if (_voiceNotice != null) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline_rounded, size: 16, color: scheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _voiceNotice!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.tertiary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            VoiceAccentPicker(
              catalog: _catalog,
              selectedVoiceId: _voiceId,
              onSelected: _selectVoice,
              onPreview: _previewVoice,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoicePanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.record_voice_over_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Ask the tutor', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  tooltip: 'Replay last answer',
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  onPressed: _lastReply == null ? null : _replayReply,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_turns.isEmpty)
              Text(
                _solution == null
                    ? 'Solve a problem first, then ask me to explain any step.'
                    : 'Ask me why a step works, or to go through it again.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final turn in _turns) _TurnBubble(turn: turn),
                  ],
                ),
              ),
            if (_asking)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_solution == null) ...<Widget>[
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Icon(Icons.touch_app_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Solve a problem on the left to unlock voice questions.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ] else ...<Widget>[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _question,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask(),
                      decoration: InputDecoration(
                        hintText: 'Ask about a step\u2026',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_speechSupported)
                    IconButton.filledTonal(
                      tooltip: _listening ? 'Stop listening' : 'Ask by voice',
                      icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
                      onPressed: _toggleListening,
                    ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: 'Send question',
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _asking ? null : () => _ask(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One bubble in the conversational tutor transcript.
class _TutorTurn {
  final String text;
  final bool isUser;
  final bool pending;

  const _TutorTurn({required this.text, required this.isUser, this.pending = false});
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn});

  final _TutorTurn turn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = turn.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary.withAlpha(28) : scheme.surfaceContainerHighest.withAlpha(140),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: turn.pending ? scheme.outline : scheme.outlineVariant.withAlpha(120)),
        ),
        child: Text(
          turn.text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
        ),
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.solution});

  final TutorSolution solution;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(solution.topic.replaceAll('_', ' ')),
                ),
                _VerificationBadge(solution: solution),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              solution.problem,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (solution.verificationDetail.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                solution.verificationDetail,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.solution});

  final TutorSolution solution;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verified = solution.isVerified;
    final color = verified ? scheme.primary : scheme.tertiary;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(verified ? Icons.verified_rounded : Icons.info_outline_rounded, size: 15, color: color),
      label: Text(verified ? 'Verified' : 'Not verified'),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withAlpha(120)),
      backgroundColor: color.withAlpha(20),
    );
  }
}

/// A worked step that writes itself onto the page while the tutor narrates it.
///
/// Its expressions are revealed one line, then one token, at a time. Finished
/// steps stay on the page as a settled record; future steps stay hidden until
/// the tutor reaches them, so the solution is never dumped in all at once.
class _LiveStepTile extends StatefulWidget {
  const _LiveStepTile({
    required this.step,
    required this.active,
    required this.done,
    required this.playing,
    required this.speed,
    required this.onTap,
  });

  final TutorStep step;
  final bool active;
  final bool done;
  final bool playing;
  final double speed;
  final VoidCallback onTap;

  @override
  State<_LiveStepTile> createState() => _LiveStepTileState();
}

class _LiveStepTileState extends State<_LiveStepTile> {
  int _current = 0;
  bool _complete = false;

  List<String> get _lines => widget.step.displayLines;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final count = _lines.length;
    if (widget.done || count == 0) {
      _current = count;
      _complete = true;
    } else {
      _current = 0;
      _complete = false;
    }
  }

  @override
  void didUpdateWidget(covariant _LiveStepTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id || oldWidget.done != widget.done) {
      _reset();
    }
  }

  void _onLineComplete(int index) {
    if (!mounted) return;
    setState(() {
      if (index >= _lines.length - 1) {
        _complete = true;
      } else {
        _current = index + 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = _lines;
    final active = widget.active;
    final visibleCount = _complete ? lines.length : _current + 1;
    final showExplanation = _complete || widget.done;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 24,
              child: Icon(
                widget.done ? Icons.check_rounded : (active ? Icons.edit_rounded : Icons.circle_outlined),
                size: widget.done ? 18 : 16,
                color: widget.done ? scheme.primary : (active ? scheme.primary : scheme.outline),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${widget.step.id}. ${widget.step.title}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: active ? scheme.primary : scheme.onSurface,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        ),
                  ),
                  for (var i = 0; i < visibleCount && i < lines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: MathTypewriter(
                        key: ValueKey<String>('${widget.step.id}:$i:${lines[i]}'),
                        latex: lines[i],
                        playing: active && widget.playing,
                        complete: widget.done || _complete || i < _current,
                        speed: widget.speed,
                        onCompleted: () => _onLineComplete(i),
                      ),
                    ),
                  if (showExplanation)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        widget.step.explanation.isNotEmpty ? widget.step.explanation : widget.step.narration,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalAnswerBlock extends StatelessWidget {
  const _FinalAnswerBlock({required this.solution});

  final TutorSolution solution;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Answer: ${solution.finalAnswer}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          MathTex(solution.answerLatex, fontSize: 24, color: scheme.primary),
        ],
      ),
    );
  }
}

/// A subtle ruled surface so the worked steps read as writing on a board
/// rather than as a stack of boxed cards.
class _BoardSurface extends StatelessWidget {
  const _BoardSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: _RuledLinesPainter(
          background: scheme.surfaceContainerLowest,
          line: scheme.outlineVariant.withAlpha(40),
          marginLine: scheme.primary.withAlpha(30),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 20, 20),
          child: child,
        ),
      ),
    );
  }
}

class _RuledLinesPainter extends CustomPainter {
  const _RuledLinesPainter({
    required this.background,
    required this.line,
    required this.marginLine,
  });

  final Color background;
  final Color line;
  final Color marginLine;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), Paint()..color = background);

    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    const gap = 30.0;
    for (var y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    canvas.drawLine(
      const Offset(18, 0),
      Offset(18, size.height),
      Paint()
        ..color = marginLine
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_RuledLinesPainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.line != line || oldDelegate.marginLine != marginLine;
}
