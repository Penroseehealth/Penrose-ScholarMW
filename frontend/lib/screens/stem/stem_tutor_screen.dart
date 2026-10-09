import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/services.dart';
import '../../services/tutor_preferences.dart';
import '../../services/web_speech_service.dart';
import '../../widgets/error_state.dart';
import '../../widgets/math_tutor/math_writing.dart';
import '../../widgets/math_viz/ai_visual_parser.dart';
import '../../widgets/math_viz/ai_visual_renderer.dart';
import '../../widgets/math_viz/math_tools_panel.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/stem_text.dart';

class StemTutorScreen extends StatefulWidget {
  final int conceptId;
  const StemTutorScreen({super.key, this.conceptId = 0});

  @override
  State<StemTutorScreen> createState() => _StemTutorScreenState();
}

class _StemTutorScreenState extends State<StemTutorScreen> {
  final StemService _stemService = StemService();
  final ContextService _contextService = ContextService();
  final MultimodalService _multimodalService = MultimodalService();
  final WebSpeechService _speech = WebSpeechService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _concepts = [];
  final List<_ChatMessage> _messages = [];
  final List<_Attachment> _attachments = [];
  bool _loading = false;
  bool _sending = false;
  bool _uploading = false;
  bool _listening = false;
  int? _speakingMessageIndex;
  int _selectedConceptId = 0;
  int _requestSeq = 0;
  String _selectedMode = 'explain';
  String? _error;
  String? _voiceError;
  TutorPreferences _preferences = TutorPreferences.memoryOnly();

  static const _modes = [
    'explain',
    'teach',
    'example',
    'diagram',
    'solve',
    'hint',
    'quiz',
    'practice',
    'challenge',
    'simplify',
    'deepen',
  ];

  static const _modeLabels = {
    'explain': 'Explain',
    'teach': 'Teach',
    'example': 'Example',
    'diagram': 'Diagram',
    'solve': 'Solve',
    'hint': 'Hint',
    'quiz': 'Quiz',
    'practice': 'Practice',
    'challenge': 'Challenge',
    'simplify': 'Simplify',
    'deepen': 'Deepen',
  };

  @override
  void initState() {
    super.initState();
    _selectedConceptId = widget.conceptId;
    _loadPreferences();
    _loadData();
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

  @override
  void dispose() {
    _requestSeq++;
    _speech.cancelSpeech();
    _speech.dispose();
    _preferences.removeListener(_onPreferencesChanged);
    _preferences.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Voice ────────────────────────────────────────────────────────────────

  /// Dictates a question into the composer, showing words as they are heard.
  void _toggleListening() {
    if (_listening) {
      _speech.stopListening();
      setState(() => _listening = false);
      return;
    }
    if (!_speech.isSupported) {
      setState(() => _voiceError = 'Speech input is not available in this browser.');
      return;
    }
    final String existing = _messageController.text;
    setState(() {
      _voiceError = null;
      _listening = true;
    });
    _speech.startListening(
      lang: _preferences.voiceLanguage,
      onResult: (String text, bool isFinal) {
        if (!mounted) return;
        setState(() {
          _messageController.text = existing.isEmpty || existing.endsWith(' ') ? '$existing$text' : '$existing $text';
          _messageController.selection = TextSelection.collapsed(offset: _messageController.text.length);
        });
        if (isFinal) _toggleListening();
      },
      onEnd: () {
        if (mounted && _listening) setState(() => _listening = false);
      },
      onError: (String error) {
        if (!mounted) return;
        setState(() {
          _voiceError = error;
          _listening = false;
        });
      },
    );
  }

  /// Reads a tutor reply aloud, or stops it if this reply is already speaking.
  Future<void> _toggleSpeaking(int index, String text) async {
    if (_speakingMessageIndex == index) {
      _speech.cancelSpeech();
      if (mounted) setState(() => _speakingMessageIndex = null);
      return;
    }
    _speech.cancelSpeech();
    if (mounted) setState(() => _speakingMessageIndex = index);
    await _speech.speak(text, lang: _preferences.voiceLanguage);
    if (mounted && _speakingMessageIndex == index) setState(() => _speakingMessageIndex = null);
  }

  // ── Attachments ──────────────────────────────────────────────────────────

  /// Uploads a picked file so the tutor can reason over its contents.
  Future<void> _pickAttachment() async {
    if (_uploading) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open files: $e');
      return;
    }
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    final Map<String, dynamic> response = await _multimodalService.uploadFileBytes(bytes.toList(), file.name);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        _attachments.add(_Attachment(
          fileId: (data?['file_id'] ?? '') as String,
          filename: file.name,
          preview: (data?['extracted_text'] ?? data?['text_preview'] ?? '') as String,
        ));
      } else {
        _error = (response['error'] ?? 'Upload failed').toString();
      }
    });
  }

  // ── Generation control ───────────────────────────────────────────────────

  /// Abandons the reply in flight without discarding the question.
  ///
  /// The request sequence is bumped so the response that eventually arrives is
  /// recognised as stale and dropped instead of being appended after the stop.
  void _stopGeneration() {
    _requestSeq++;
    _speech.cancelSpeech();
    setState(() {
      _sending = false;
      _speakingMessageIndex = null;
    });
  }

  void _openSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surfaceElevated,
      showDragHandle: true,
      builder: (sheetContext) {
        void refresh() => Navigator.of(sheetContext).pop();
        return SafeArea(
          child: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: _preferences,
              builder: (BuildContext context, Widget? child) {
                final p = _preferences;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Tutor settings',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      _settingToggle(
                        'Handwritten maths',
                        'Write the working out by hand',
                        p.handwrittenMath,
                        (bool v) => p.setHandwrittenMath(v),
                      ),
                      _settingToggle(
                        'Computer typeset maths',
                        'Show answers in typed maths notation',
                        p.typedMath,
                        (bool v) => p.setTypedMath(v),
                      ),
                      _settingToggle(
                        'Animate each step',
                        'Show the working appearing stroke by stroke',
                        p.animateSteps,
                        p.setAnimateSteps,
                      ),
                      _settingToggle(
                        'Show grid',
                        'Off by default so the board stays plain white',
                        p.gridVisible,
                        p.setGridVisible,
                      ),
                      _settingToggle(
                        'Remember context',
                        'Use what you have already covered in this session',
                        p.contextualMemory,
                        p.setContextualMemory,
                      ),
                      _settingToggle(
                        'Read replies aloud',
                        'Speak each answer automatically',
                        p.speakReplies,
                        p.setSpeakReplies,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Voice language',
                        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          for (final (code, label) in _voiceLanguages)
                            ChoiceChip(
                              label: Text(label),
                              selected: p.voiceLanguage == code,
                              onSelected: (bool selected) {
                                if (selected) p.setVoiceLanguage(code);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          TextButton.icon(
                            icon: const Icon(Icons.restart_alt_rounded, size: 18),
                            onPressed: () => p.reset(),
                            label: const Text('Reset to defaults'),
                          ),
                          const Spacer(),
                          FilledButton(onPressed: refresh, child: const Text('Done')),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  static const List<(String, String)> _voiceLanguages = <(String, String)>[
    ('en-US', 'English (US)'),
    ('en-GB', 'English (UK)'),
    ('en-NG', 'English (Nigeria)'),
    ('en-KE', 'English (Kenya)'),
    ('en-ZA', 'English (South Africa)'),
    ('ny-MW', 'Chichewa'),
  ];

  Widget _settingToggle(String title, String subtitle, bool value, Future<void> Function(bool) onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: value,
        onChanged: onChanged,
        title: Text(title, style: TextStyle(fontSize: 14, color: context.colors.textPrimary)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
      );

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subjects = await _stemService.getSubjects();
      if (subjects.isNotEmpty) {
        final slug = (subjects[0]['slug'] ?? '') as String;
        final disciplines = await _stemService.getDisciplines(slug);
        if (disciplines.isNotEmpty) {
          final topics = await _stemService.getTopics((disciplines[0]['id'] ?? 0) as int);
          if (topics.isNotEmpty) {
            final subtopics = await _stemService.getSubtopics((topics[0]['id'] ?? 0) as int);
            if (subtopics.isNotEmpty) {
              final concepts = await _stemService.getConcepts((subtopics[0]['id'] ?? 0) as int);
              if (mounted) {
                setState(() {
                  _concepts = concepts;
                  _loading = false;
                  if (_selectedConceptId == 0 && concepts.isNotEmpty) {
                    _selectedConceptId = (concepts[0]['id'] ?? 0) as int;
                  }
                });
              }
              return;
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final attachments = List<_Attachment>.from(_attachments);
    if ((text.isEmpty && attachments.isEmpty) || _selectedConceptId == 0 || _sending) return;

    // Classify intent
    _contextService.classifyIntent(text);

    // Update workspace with current STEM context
    _contextService.updateWorkspacePartial(
      screen: 'stem_tutor',
      currentObjective: 'STEM Tutor - concept $_selectedConceptId',
    );

    final int requestId = ++_requestSeq;
    setState(() {
      _sending = true;
      _attachments.clear();
      _messages.add(_ChatMessage(
        text: text.isEmpty ? _attachmentSummary(attachments) : text,
        isUser: true,
        timestamp: DateTime.now(),
        attachmentIds: attachments.map((_Attachment a) => a.fileId).toList(),
      ));
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => !m.isError)
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();
      // Attachments reach the tutor as text: the upload endpoint already
      // extracted the readable content, so the model reasons over the actual
      // file contents instead of just the filename.
      final prompt = text.isEmpty ? _attachmentPrompt(attachments) : _withAttachmentContext(text, attachments);
      final response = await _stemService.chatWithStemTutor(
        _selectedConceptId,
        prompt,
        _selectedMode,
        history: history,
        context: _preferences.contextualMemory ? _contextService.currentWorkspace.toJson() : null,
      );
      // A stop request, or a newer question, invalidates this reply.
      if (!mounted || requestId != _requestSeq) return;
      final reply = (response['response'] ?? response['message'] ?? 'No response received.') as String;
      setState(() {
        _messages.add(_ChatMessage(
          text: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _sending = false;
      });
      _scrollToBottom();
      if (_preferences.speakReplies && _speech.isSupported) {
        unawaited(_toggleSpeaking(_messages.length - 1, reply));
      }
    } catch (e) {
      if (!mounted || requestId != _requestSeq) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Sorry, an error occurred. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  /// Whether a reply is pure working, so it belongs on the board rather than in
  /// the chat transcript.
  ///
  /// Deliberately strict: prose answers stay as readable text, because writing
  /// out a paragraph in vector strokes would be slow and hard to read.
  static bool _isMathReply(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 120) return false;
    if (RegExp(r'[A-Za-z]{4,}').hasMatch(trimmed)) return false;
    if (!RegExp(r'[0-9=+\-*/^()]').hasMatch(trimmed)) return false;
    return true;
  }

  static String _attachmentSummary(List<_Attachment> attachments) =>
      attachments.isEmpty ? 'Shared a file' : 'Shared ${attachments.map((_Attachment a) => a.filename).join(', ')}';

  static String _withAttachmentContext(String text, List<_Attachment> attachments) {
    if (attachments.isEmpty) return text;
    final buffer = StringBuffer(text)..writeln();
    buffer.writeln();
    buffer.writeln('The student attached:');
    for (final attachment in attachments) {
      buffer.writeln('- ${attachment.filename}');
      if (attachment.preview.trim().isNotEmpty) {
        buffer.writeln(attachment.preview.trim());
      }
    }
    buffer.write('Use this material when answering.');
    return buffer.toString();
  }

  static String _attachmentPrompt(List<_Attachment> attachments) =>
      _withAttachmentContext('Please look at what I attached and help me with it.', attachments);

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        body: Column(
          children: [
            _buildAppBar(),
            if (_error != null)
              Expanded(child: ErrorState(message: 'Failed to load concepts', details: _error, onRetry: _loadData))
            else if (_loading)
              Expanded(child: Center(child: ShimmerLoading.list(count: 3)))
            else ...[
              _buildConceptSelector(),
              Expanded(child: _buildChatArea()),
              _buildInputBar(),
            ],
          ],
        ),
      );

  Widget _buildAppBar() => Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primaryMuted],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Text(
                'STEM Tutor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const Spacer(),
              _buildModeMenu(),
              IconButton(
                tooltip: 'Tutor settings',
                icon: Icon(Icons.settings_rounded, color: context.colors.textPrimary),
                onPressed: _openSettingsSheet,
              ),
              IconButton(
                tooltip: 'Insert maths tools',
                icon: Icon(Icons.construction_rounded, color: context.colors.textPrimary),
                onPressed: _openToolsSheet,
              ),
            ],
          ),
        ),
      );

  /// Contextual teaching mode: lives in the app bar instead of a permanent row.
  Widget _buildModeMenu() => PopupMenuButton<String>(
        tooltip: 'Teaching mode',
        color: context.colors.surfaceElevated,
        onSelected: (mode) => setState(() => _selectedMode = mode),
        itemBuilder: (context) => _modes
            .map(
              (mode) => PopupMenuItem<String>(
                value: mode,
                child: Row(
                  children: [
                    Icon(
                      _selectedMode == mode ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: _selectedMode == mode ? AppColors.primary : context.colors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(_modeLabels[mode] ?? mode, style: TextStyle(color: context.colors.textSecondary)),
                  ],
                ),
              ),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: context.colors.textPrimary),
              const SizedBox(width: 6),
              Text(
                _modeLabels[_selectedMode] ?? _selectedMode,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
              ),
            ],
          ),
        ),
      );

  /// Draws on demand: the maths tools open in a sheet rather than holding
  /// permanent space above the conversation.
  void _openToolsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surfaceElevated,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Maths tools',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 8),
            MathToolsPanel(
              onToolSelected: (type, params) {
                Navigator.of(sheetContext).pop();
                _onToolSelected(type, params);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConceptSelector() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(bottom: BorderSide(color: context.colors.border)),
        ),
        child: DropdownButton<int>(
          value: _selectedConceptId != 0 ? _selectedConceptId : null,
          hint: Text('Select a concept', style: TextStyle(color: context.colors.textMuted)),
          isExpanded: true,
          dropdownColor: context.colors.surfaceElevated,
          underline: const SizedBox(),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textMuted),
          items: _concepts
              .map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                    value: (c['id'] ?? 0) as int,
                    child: Text(
                      (c['title'] ?? c['name'] ?? '') as String,
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                    ),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedConceptId = v ?? 0),
        ),
      );

  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_rounded, size: 48, color: context.colors.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Ask me anything about STEM',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a concept and start chatting',
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index], index);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    final isUser = msg.isUser;
    final hasVisuals = !isUser && AIVisualRenderer.hasVisuals(msg.text);
    final isDirectVisual = !isUser && msg.visual != null;
    final speaking = !isUser && _speakingMessageIndex == index;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : context.colors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isUser)
              StemText(
                msg.text,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.4,
                ),
              )
            else if (isDirectVisual)
              DirectVisualMessage(visual: msg.visual!, description: msg.text)
            else if (hasVisuals)
              InlineVisualMessage(text: msg.text)
            else if (_isMathReply(msg.text))
              // Maths-only replies are written out on the board instead of
              // typed, so an answer looks the way the student would work it.
              MathWriting(
                msg.text,
                preferences: _preferences,
                fontSize: 16,
                showGrid: false,
              )
            else
              StemText(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textSecondary,
                  height: 1.4,
                ),
                selectable: true,
              ),
            // Read-aloud toggle lives on every tutor reply so a student can
            // replay any answer without asking the chat to repeat itself.
            if (!isUser && !msg.isError && _speech.isSupported)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: speaking ? 'Stop reading' : 'Read aloud',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                    size: 18,
                    color: context.colors.textMuted,
                  ),
                  onPressed: () => _toggleSpeaking(index, msg.text),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Thinking...',
                style: TextStyle(fontSize: 13, color: context.colors.textMuted),
              ),
            ],
          ),
        ),
      );

  void _onToolSelected(String type, Map<String, dynamic> params) {
    final visual = _buildVisualFromTool(type, params);
    final description = _buildToolDescription(type, params);
    setState(() {
      _messages.add(_ChatMessage(
        text: description,
        isUser: false,
        timestamp: DateTime.now(),
        visual: visual,
      ));
    });
    _scrollToBottom();
  }

  ParsedVisual _buildVisualFromTool(String type, Map<String, dynamic> params) {
    final values = (params['values'] as List?)?.map((e) => (e as num).toDouble()).toList();
    final labels = (params['labels'] as List?)?.map((e) => e.toString()).toList();

    switch (type) {
      case 'graph':
        return ParsedVisual(
          type: VisualType.graph,
          expression: params['expression'] as String?,
          title: params['title'] as String?,
          xMin: (params['xMin'] as num?)?.toDouble() ?? -10,
          xMax: (params['xMax'] as num?)?.toDouble() ?? 10,
          yMin: (params['yMin'] as num?)?.toDouble() ?? -10,
          yMax: (params['yMax'] as num?)?.toDouble() ?? 10,
        );
      case 'bar':
        return ParsedVisual(
          type: VisualType.barChart,
          title: params['title'] as String?,
          values: values,
          labels: labels,
        );
      case 'pie':
        return ParsedVisual(
          type: VisualType.pieChart,
          title: params['title'] as String?,
          values: values,
          labels: labels,
        );
      case 'histogram':
        return ParsedVisual(
          type: VisualType.histogram,
          title: params['title'] as String?,
          values: values,
          labels: labels,
        );
      case 'line':
        return ParsedVisual(
          type: VisualType.lineChart,
          title: params['title'] as String?,
          values: values,
          labels: labels,
        );
      case 'shape':
        return ParsedVisual(
          type: VisualType.triangle,
          shapeType: params['shape'] as String?,
          title: params['shape'] as String?,
        );
      case 'equation':
        return ParsedVisual(
          type: VisualType.unknown,
          title: params['latex'] as String?,
        );
      default:
        return ParsedVisual(type: VisualType.unknown, title: type);
    }
  }

  String _buildToolDescription(String type, Map<String, dynamic> params) {
    switch (type) {
      case 'graph':
        return 'y = ${params['expression']}';
      case 'bar':
      case 'pie':
      case 'histogram':
      case 'line':
        return params['title'] as String? ?? '$type chart';
      case 'shape':
        return '${params['shape']} geometry';
      case 'equation':
        return params['latex'] as String? ?? 'Equation';
      default:
        return type;
    }
  }

  Widget _buildInputBar() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_attachments.isNotEmpty || _uploading) _buildAttachmentStrip(),
              if (_voiceError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.mic_off_rounded, size: 16, color: context.colors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _voiceError!,
                          style: TextStyle(fontSize: 12, color: context.colors.error),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.close_rounded, size: 16, color: context.colors.textMuted),
                        onPressed: () => setState(() => _voiceError = null),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  _circleButton(
                    icon: Icons.attach_file_rounded,
                    tooltip: 'Attach a file',
                    color: _uploading ? context.colors.textMuted : context.colors.textSecondary,
                    onPressed: _uploading || _selectedConceptId == 0 ? null : _pickAttachment,
                    busy: _uploading,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_sending && _selectedConceptId != 0,
                      style: TextStyle(color: context.colors.textPrimary),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: _selectedConceptId == 0
                            ? 'Select a concept first...'
                            : _listening
                                ? 'Listening...'
                                : 'Ask a question...',
                        hintStyle: TextStyle(color: context.colors.textMuted),
                        filled: true,
                        fillColor: context.colors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _circleButton(
                    icon: _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    tooltip: _listening ? 'Stop dictation' : 'Dictate your question',
                    color: _listening ? AppColors.primary : context.colors.textSecondary,
                    onPressed: _selectedConceptId == 0 ? null : _toggleListening,
                  ),
                  const SizedBox(width: 8),
                  // Send becomes stop while a reply is being generated, so the
                  // same position always controls the in-flight request.
                  GestureDetector(
                    onTap: _sending ? _stopGeneration : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _sending || _selectedConceptId == 0 ? context.colors.surfaceHighest : AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _sending ? Icons.stop_rounded : Icons.send_rounded,
                        color: _sending || _selectedConceptId == 0 ? context.colors.textSecondary : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  /// Attachment chips with a remove action, shown above the composer.
  Widget _buildAttachmentStrip() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (_uploading)
              const Chip(
                avatar: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: Text('Uploading...'),
                visualDensity: VisualDensity.compact,
              ),
            for (final attachment in _attachments)
              Chip(
                avatar: const Icon(Icons.description_outlined, size: 16),
                label: Text(
                  attachment.filename,
                  overflow: TextOverflow.ellipsis,
                ),
                visualDensity: VisualDensity.compact,
                onDeleted: () => setState(() => _attachments.remove(attachment)),
              ),
          ],
        ),
      );

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onPressed,
    bool busy = false,
  }) =>
      SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: onPressed == null ? context.colors.textMuted : color),
        ),
      );
}

/// A file the student uploaded and attached to the next question.
class _Attachment {
  const _Attachment({required this.fileId, required this.filename, required this.preview});

  final String fileId;
  final String filename;

  /// Text the backend extracted from the file, passed to the tutor so it can
  /// reason over the real contents rather than the filename.
  final String preview;
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final ParsedVisual? visual;

  /// Backend ids of any files sent with this message.
  final List<String> attachmentIds;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.visual,
    this.attachmentIds = const <String>[],
  });
}
