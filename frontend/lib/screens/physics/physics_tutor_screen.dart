import 'package:flutter/material.dart';

import '../../services/math_tutor_api.dart';
import '../../services/physics_tutor_api.dart';
import '../../services/tutor_preferences.dart';
import '../../services/voice_catalog_service.dart';
import '../../services/web_speech_service.dart';
import '../../voice/tts_service.dart';
import '../../voice/voice_session_manager.dart';
import '../../widgets/math_tutor/math_solution.dart';
import '../../widgets/math_tutor/math_tutor_audio_bar.dart';
import '../../widgets/math_tutor/math_tutor_player.dart';
import '../../widgets/math_tutor/math_typewriter.dart';
import '../../widgets/math_tutor/math_writing.dart';
import '../../widgets/math_tutor/voice_accent_picker.dart';
import '../../widgets/physics_tutor/physics_solution.dart';

/// AI Visual Physics Tutor.
///
/// The backend solves every problem deterministically against the relevant
/// physical law and verifies the result; this screen typesets the working,
/// shows the given and required quantities, and narrates each step. A
/// conversational panel sits alongside the workspace so the student can ask
/// follow-up questions by voice or text.
class PhysicsTutorScreen extends StatefulWidget {
  const PhysicsTutorScreen({super.key, this.enableRemote = true, this.api, this.player});

  /// When false the screen stays entirely offline. Tests use this to avoid
  /// real network timers.
  final bool enableRemote;

  /// Optional injected client, used by tests to exercise the server path.
  final PhysicsTutorApi? api;

  /// Optional injected narration player. When null the screen owns and
  /// disposes its own player.
  final MathTutorPlayer? player;

  @override
  State<PhysicsTutorScreen> createState() => _PhysicsTutorScreenState();
}

class _PhysicsTutorScreenState extends State<PhysicsTutorScreen> {
  static const List<String> _examples = <String>[
    'A 5 kg box is pushed with a force of 20 N. Find its acceleration.',
    'A car accelerates from 0 to 20 m/s in 5 s. Find its acceleration.',
    'A ball is thrown upward at 30 m/s. Find the maximum height.',
    'A 2 kg mass moving at 4 m/s collides with a stationary 2 kg mass. Find the velocity after.',
    'Calculate the weight of a 10 kg object.',
    'A 3 kg block slides down a rough incline at 25 degrees with a coefficient of friction 0.2. Find the acceleration.',
    'A pendulum of length 0.5 m swings. Find its period.',
    'A spring with extension 0.1 m feels a force of 5 N. Find the spring constant.',
    'A 1000 kg car travels around a circle of radius 40 m at 10 m/s. Find the centripetal force.',
    'Calculate the heat energy needed to raise 2 kg of water by 40 K. The specific heat capacity is 4200 J/(kg K).',
    'A 12 V battery drives a current of 3 A through a resistor. Find the resistance.',
  ];

  final TextEditingController _input = TextEditingController();
  final TextEditingController _question = TextEditingController();
  final VoiceCatalogService _catalog = VoiceCatalogService();
  late final MathTutorPlayer _player = widget.player ?? MathTutorPlayer();
  final PhysicsTutorApi _ownApi = PhysicsTutorApi();
  PhysicsTutorApi get _api => widget.api ?? _ownApi;
  final PenroseTtsService _previewTts = PenroseTtsService(session: VoiceSessionManager());
  final PenroseTtsService _chatTts = PenroseTtsService(session: VoiceSessionManager());
  final WebSpeechService _speech = WebSpeechService();
  final Map<int, GlobalKey> _stepKeys = <int, GlobalKey>{};
  final ScrollController _workspaceScroll = ScrollController();

  TutorPreferences _preferences = TutorPreferences.memoryOnly();

  PhysicsSolution? _solution;
  String? _message;
  String _voiceId = VoiceCatalogService.defaultVoiceId;
  String? _voiceNotice;
  int _solveSeq = 0;
  bool _solving = false;

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
    _loadPreferences();
    _bootstrap();
  }

  Future<void> _loadPreferences() async {
    final TutorPreferences loaded = await TutorPreferences.load();
    if (!mounted) {
      loaded.dispose();
      return;
    }
    _preferences.removeListener(_onPreferencesChanged);
    _preferences.dispose();
    loaded.addListener(_onPreferencesChanged);
    setState(() => _preferences = loaded);
  }

  void _onPreferencesChanged() {
    if (mounted) setState(() {});
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
    final key = id == null ? null : _stepKeys[id];
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

    if (!widget.enableRemote) {
      setState(() => _message = _offlineMessage);
      return;
    }

    final requestId = ++_solveSeq;
    setState(() {
      _message = null;
      _solution = null;
      _solving = true;
      _stepKeys.clear();
      _turns.clear();
      _explainedSteps.clear();
      _lastReply = null;
    });

    final remote = await _api.solve(text);
    if (!mounted || requestId != _solveSeq) return;
    if (remote == null) {
      setState(() {
        _solving = false;
        _message = _offlineMessage;
      });
      return;
    }
    setState(() {
      _solving = false;
      _solution = remote;
      _stepKeys.clear();
    });
    await _player.load(remote.toTutorSolution());
  }

  static const String _offlineMessage =
      'I could not reach the physics tutor service just now. Check your connection and try again, or rephrase the '
      'question with the quantities you were given.';

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
    if (question.isEmpty || _asking || _solution == null) return;

    _question.clear();
    await _player.pause();
    _chatTts.stop();
    setState(() {
      _turns.add(_TutorTurn(text: question, isUser: true));
      _asking = true;
    });

    final problem = _solution?.problem ?? _input.text.trim();

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

  /// Whether the message is a numeric line of the student's own working.
  bool _looksLikeWorking(String text) => !text.endsWith('?') && RegExp(r'=\s*[-+]?\d').hasMatch(text);

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
    _preferences.removeListener(_onPreferencesChanged);
    _preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final solution = _solution;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Physics Tutor'),
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

  List<Widget> _buildMainColumn(BuildContext context, PhysicsSolution? solution) {
    final scheme = Theme.of(context).colorScheme;
    return <Widget>[
      TextField(
        controller: _input,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _solve(),
        decoration: InputDecoration(
          labelText: 'Ask a physics problem',
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
      if (_solving) ...<Widget>[
        const SizedBox(height: 14),
        const LinearProgressIndicator(minHeight: 3),
      ],
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
        _PhysicsProblemCard(solution: solution),
        const SizedBox(height: 14),
        _GivenFindTable(solution: solution),
        const SizedBox(height: 14),
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
          preferences: _preferences,
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
                      preferences: _preferences,
                      onTap: () => _player.seekTo(step.id),
                    ),
                  ),
              if (solution.finalAnswerText.isNotEmpty && _player.isLastStep) ...<Widget>[
                const SizedBox(height: 2),
                Divider(color: scheme.outlineVariant.withAlpha(140)),
                _FinalAnswerBlock(solution: solution, preferences: _preferences),
              ],
            ],
          ),
        ),
      ],
    ];
  }

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
            const SizedBox(height: 18),
            _buildBoardSettings(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardSettings(ColorScheme scheme) {
    final p = _preferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.draw_outlined, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Board & handwriting', style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Show the working as', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.gesture_rounded),
              label: Text('Handwritten'),
              tooltip: 'Write the working out by hand',
            ),
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.keyboard_alt_outlined),
              label: Text('Computer'),
              tooltip: 'Show the working in typed notation',
            ),
          ],
          selected: <bool>{p.showHandwriting},
          showSelectedIcon: false,
          onSelectionChanged: (Set<bool> value) {
            if (value.first) {
              p.setHandwrittenMath(true);
            } else {
              p.setTypedMath(true);
            }
          },
        ),
        const SizedBox(height: 4),
        Text(
          p.showHandwriting ? 'Answers are written out by hand' : 'Answers are shown in typed notation',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: p.animateSteps,
          onChanged: (bool v) => p.setAnimateSteps(v),
          title: const Text('Animate each step'),
          subtitle: const Text('Write the working out stroke by stroke as it is solved'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: p.gridVisible,
          onChanged: (bool v) => p.setGridVisible(v),
          title: const Text('Show grid'),
          subtitle: const Text('Off by default so the board stays plain white'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: p.contextualMemory,
          onChanged: (bool v) => p.setContextualMemory(v),
          title: const Text('Remember context'),
          subtitle: const Text('Keep what you have already covered in this session'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: p.speakReplies,
          onChanged: (bool v) => p.setSpeakReplies(v),
          title: const Text('Read answers aloud'),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            onPressed: () => p.reset(),
            label: const Text('Reset to defaults'),
          ),
        ),
      ],
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

class _PhysicsProblemCard extends StatelessWidget {
  const _PhysicsProblemCard({required this.solution});

  final PhysicsSolution solution;

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
            if (solution.principle.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.lightbulb_outline_rounded, size: 16, color: scheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      solution.principle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            if (solution.verificationDetail.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                solution.verificationDetail,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            for (final warning in solution.warnings) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, size: 15, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.error),
                    ),
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

/// The given quantities and what the problem asks for.
class _GivenFindTable extends StatelessWidget {
  const _GivenFindTable({required this.solution});

  final PhysicsSolution solution;

  @override
  Widget build(BuildContext context) {
    if (solution.given.isEmpty && solution.find.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (solution.given.isNotEmpty) ...<Widget>[
              Text('Given', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final quantity in solution.given)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 44,
                        child: Text(
                          quantity.symbol,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600, color: scheme.primary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          quantity.display.isEmpty ? quantity.latex : quantity.display,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (solution.find.isNotEmpty) ...<Widget>[
              if (solution.given.isNotEmpty) const SizedBox(height: 8),
              Text('Find', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final item in solution.find)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.arrow_right_rounded, size: 18, color: scheme.onSurfaceVariant),
                    Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium)),
                  ],
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

  final PhysicsSolution solution;

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
class _LiveStepTile extends StatefulWidget {
  const _LiveStepTile({
    required this.step,
    required this.active,
    required this.done,
    required this.playing,
    required this.speed,
    required this.preferences,
    required this.onTap,
  });

  final TutorStep step;
  final bool active;
  final bool done;
  final bool playing;
  final double speed;
  final TutorPreferences preferences;
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
                      child: widget.preferences.showHandwriting
                          ? MathWriting(
                              lines[i],
                              preferences: widget.preferences,
                              fontSize: 18,
                              animate: widget.preferences.animateSteps && active && widget.playing,
                              showGrid: false,
                            )
                          : MathTypewriter(
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
  const _FinalAnswerBlock({required this.solution, required this.preferences});

  final PhysicsSolution solution;
  final TutorPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Answer: ${solution.finalAnswerText}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          MathWriting(
            solution.answerLatex,
            preferences: preferences,
            fontSize: 24,
            animate: false,
            showGrid: false,
          ),
        ],
      ),
    );
  }
}

/// The surface the working is written on.
class _BoardSurface extends StatelessWidget {
  const _BoardSurface({required this.child, required this.preferences});

  final Widget child;
  final TutorPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!preferences.plainWhiteboard && !preferences.gridVisible) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: scheme.surfaceContainerLowest,
          padding: const EdgeInsets.fromLTRB(26, 18, 20, 20),
          child: child,
        ),
      );
    }
    if (preferences.gridVisible) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _GridPaperPainter(
            background: Colors.white,
            line: scheme.outlineVariant.withAlpha(70),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 18, 20, 20),
            child: child,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: _RuledLinesPainter(
          background: Colors.white,
          line: const Color(0xFFB0BEC5).withAlpha(90),
          marginLine: const Color(0xFFE53935).withAlpha(70),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 20, 20),
          child: child,
        ),
      ),
    );
  }
}

class _GridPaperPainter extends CustomPainter {
  const _GridPaperPainter({required this.background, required this.line});

  final Color background;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final Paint paint = Paint()
      ..color = line
      ..strokeWidth = 0.7;
    const double step = 20;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPaperPainter oldDelegate) => oldDelegate.background != background || oldDelegate.line != line;
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
