import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/audio_input/stt/speech_input.dart';
import '../../../services/services.dart';
import '../state/smart_board_controller.dart';

class _AskTurn {
  const _AskTurn({required this.fromStudent, required this.text});

  final bool fromStudent;
  final String text;
}

/// Student Ask/Input panel, attached to the right edge of the smart board.
class AskPanel extends StatefulWidget {
  const AskPanel({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onToggle,
    this.topic,
  });

  final SmartBoardController controller;
  final bool expanded;
  final VoidCallback onToggle;

  /// Lesson/topic context handed over by the chemistry dashboard, when a
  /// concept was selected there. Sent along with each question so the tutor
  /// answers inside the right topic.
  final String? topic;

  @override
  State<AskPanel> createState() => _AskPanelState();
}

class _AskPanelState extends State<AskPanel> {
  static const List<String> _quickQuestions = <String>[
    'How many electrons are in the last orbit?',
    'Explain electron configuration.',
    'Draw the Mg²⁺ ion diagram.',
    'Balance: Mg + O₂ → MgO.',
  ];

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_AskTurn> _turns = <_AskTurn>[];

  int _mode = 0;
  bool _busy = false;
  String? _error;
  String _lastQuestion = '';
  String _voiceStatus = '';
  bool _listening = false;
  SpeechRecognitionEngine? _speech;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    _speech?.dispose();
    super.dispose();
  }

  void _onInputChanged() => setState(() {});

  bool get _canSend => _input.text.trim().isNotEmpty && !_busy;

  String get _contextLabel => (widget.topic ?? '').trim();

  Future<void> _ask([String? question]) async {
    final String text = (question ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    final String context = _contextLabel;
    final String payload = context.isEmpty ? text : 'Topic context: $context\n\n$text';

    setState(() {
      _busy = true;
      _error = null;
      _lastQuestion = text;
      _turns.add(_AskTurn(fromStudent: true, text: text));
      _input.clear();
    });
    _scrollToEnd();

    try {
      final Map<String, dynamic> result = await AiService().chat(message: payload, agentType: 'tutor');
      if (!mounted) return;
      if (result['success'] == true) {
        final String answer = _extractAnswer(result['data']);
        setState(() => _turns.add(_AskTurn(fromStudent: false, text: answer)));
        _scrollToEnd();
      } else {
        setState(() => _error = (result['error'] ?? 'The tutor could not answer that.').toString());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach ScholarAI: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The API returns `{id, role, content, sources, created_at}`; older payloads
  /// used different keys, so read defensively rather than assume.
  String _extractAnswer(Object? data) {
    if (data is Map) {
      for (final String key in <String>['content', 'response', 'message', 'answer', 'reply']) {
        final Object? value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return 'The tutor returned an empty answer. Try rephrasing the question.';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      final String text = data?.text?.trim() ?? '';
      if (!mounted) return;
      if (text.isEmpty) {
        setState(() => _error = 'The clipboard is empty or access was denied. You can still type your question.');
        return;
      }
      setState(() {
        _input.text = text;
        _input.selection = TextSelection.collapsed(offset: text.length);
        _error = null;
        _mode = 0;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Paste was blocked by the browser (${error.code}). Type the question instead.');
    }
  }

  void _toggleListening() {
    if (_listening) {
      _speech?.stop();
      setState(() => _listening = false);
      return;
    }
    final SpeechRecognitionEngine engine =
        _speech ?? SpeechInput.create(onResult: _onSpeechResult, onStatus: _onSpeechStatus);
    _speech = engine;
    if (!engine.supported) {
      setState(() => _voiceStatus = 'Voice input is not available in this build. Type or paste instead.');
      return;
    }
    setState(() {
      _voiceStatus = 'Listening…';
      _listening = true;
    });
    engine.start();
  }

  void _onSpeechResult(String interim, String committed) {
    if (!mounted) return;
    final String spoken = '$committed$interim'.trim();
    setState(() {
      _mode = 0;
      _input.text = spoken;
      _input.selection = TextSelection.collapsed(offset: spoken.length);
    });
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    setState(() {
      _listening = status == 'listening';
      if (status.startsWith('error:')) {
        _voiceStatus = 'Microphone error (${status.substring(6)}). Type or paste instead.';
      } else if (status == 'listening') {
        _voiceStatus = 'Listening…';
      } else if (status == 'idle') {
        _voiceStatus = 'Microphone stopped.';
      }
    });
  }

  void _writeOnBoard(String answer) {
    widget.controller.addAnswerToBoard(answer);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Answer added to the board — drag it with Select.')),
    );
  }

  Future<void> _openExpandedChat() => showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => Dialog(
          child: SizedBox(
            width: 620,
            height: 560,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.forum_outlined, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('ScholarAI — full conversation',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Back to board'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _turns.isEmpty
                      ? const Center(child: Text('Ask a question to start the conversation.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _turns.length,
                          itemBuilder: (BuildContext context, int index) {
                            final _AskTurn turn = _turns[index];
                            return _bubble(turn);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _bubble(_AskTurn turn) {
    final bool student = turn.fromStudent;
    return Align(
      alignment: student ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 330),
        decoration: BoxDecoration(
          color: student ? const Color(0xFF12294A).withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E9F1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${student ? 'You' : 'ScholarAI'}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7F95))),
            const SizedBox(height: 4),
            SelectableText(turn.text, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF1B2A3B))),
            if (!student)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _writeOnBoard(turn.text),
                  icon: const Icon(Icons.drive_file_move_outline, size: 15),
                  label: const Text('Add to board', style: TextStyle(fontSize: 11)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.expanded) {
      return Material(
        color: const Color(0xFF1B2027),
        child: InkWell(
          onTap: widget.onToggle,
          child: Semantics(
            label: 'Open Ask / Input panel',
            button: true,
            child: SizedBox(
              width: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const <Widget>[
                  Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 20),
                  SizedBox(height: 10),
                  Icon(Icons.forum_outlined, color: Colors.white, size: 20),
                  SizedBox(height: 10),
                  RotatedBox(
                    quarterTurns: 3,
                    child:
                        Text('Ask / Input', style: TextStyle(fontSize: 11, color: Colors.white70, letterSpacing: 0.6)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: const Color(0xFFF7FAFD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 6),
            child: Row(
              children: <Widget>[
                const Icon(Icons.forum_outlined, size: 17, color: Color(0xFF12294A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Ask / Input',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF12294A))),
                ),
                IconButton(
                  tooltip: 'Expand conversation',
                  onPressed: _openExpandedChat,
                  icon: const Icon(Icons.open_in_full_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Collapse panel',
                  onPressed: widget.onToggle,
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_contextLabel.isNotEmpty)
            Tooltip(
              message: 'Lesson context handed over by the chemistry dashboard',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                color: const Color(0xFFEDF3F9),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.menu_book_outlined, size: 13, color: Color(0xFF6B7F95)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _contextLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF3F5570)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _modeTabs(),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _input,
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _canSend ? _ask() : null,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _mode == 2 ? 'Speak, then edit the transcript…' : 'Ask a chemistry question…',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Enter sends · Shift+Enter adds a line',
                      style: TextStyle(fontSize: 10, color: Color(0xFF7B8DA1))),
                  const SizedBox(height: 8),
                  if (_mode == 1)
                    OutlinedButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste_rounded, size: 16),
                      label: const Text('Paste from clipboard', style: TextStyle(fontSize: 12)),
                    ),
                  if (_mode == 2) ...<Widget>[
                    OutlinedButton.icon(
                      onPressed: _toggleListening,
                      icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded, size: 16),
                      label: Text(_listening ? 'Stop listening' : 'Start microphone',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    if (_voiceStatus.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_voiceStatus, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7F95))),
                      ),
                  ],
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _canSend ? () => _ask() : null,
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(_busy ? 'Thinking…' : 'Ask'),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF3C2BC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFF8A1F14))),
                          if (_lastQuestion.isNotEmpty)
                            TextButton(
                              onPressed: _busy ? null : () => _ask(_lastQuestion),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                              child: const Text('Retry', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text('Quick questions',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7F95))),
                  const SizedBox(height: 6),
                  ..._quickQuestions.map(
                    (String question) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () {
                                _input.text = question;
                                _input.selection = TextSelection.collapsed(offset: question.length);
                                _ask(question);
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          alignment: Alignment.centerLeft,
                          side: const BorderSide(color: Color(0xFFDCE4ED)),
                        ),
                        child: Text(question,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF1B2A3B))),
                      ),
                    ),
                  ),
                  if (_turns.isNotEmpty) ...<Widget>[
                    const Divider(height: 22),
                    const Text('Conversation',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7F95))),
                    const SizedBox(height: 8),
                    ..._turns.map(_bubble),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTabs() => Row(
        children: <Widget>[
          _tab('Type', 0, Icons.keyboard_outlined),
          _tab('Paste', 1, Icons.content_paste_rounded),
          _tab('Voice', 2, Icons.mic_none_rounded),
        ],
      );

  Widget _tab(String label, int index, IconData icon) {
    final bool selected = _mode == index;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: '$label input mode',
        child: InkWell(
          onTap: () => setState(() => _mode = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: selected ? const Color(0xFF12294A) : Colors.transparent, width: 2)),
            ),
            child: Column(
              children: <Widget>[
                Icon(icon, size: 15, color: selected ? const Color(0xFF12294A) : const Color(0xFF7B8DA1)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? const Color(0xFF12294A) : const Color(0xFF7B8DA1))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
