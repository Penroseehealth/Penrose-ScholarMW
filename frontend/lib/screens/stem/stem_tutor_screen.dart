import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/context_service.dart';
import '../../services/stem_service.dart';
import '../../widgets/error_state.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _concepts = [];
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  bool _sending = false;
  int _selectedConceptId = 0;
  String _selectedMode = 'explain';
  String? _error;

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
    _loadData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
    if (text.isEmpty || _selectedConceptId == 0) return;

    // Classify intent
    _contextService.classifyIntent(text);

    // Update workspace with current STEM context
    _contextService.updateWorkspacePartial(
      screen: 'stem_tutor',
      currentObjective: 'STEM Tutor - concept $_selectedConceptId',
    );

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => !m.isError)
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();
      final response = await _stemService.chatWithStemTutor(
        _selectedConceptId,
        text,
        _selectedMode,
        history: history,
      );
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: (response['response'] ?? response['message'] ?? 'No response received.') as String,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
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
  }

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
              _buildModeSelector(),
              Expanded(child: _buildChatArea()),
              MathToolsPanel(onToolSelected: _onToolSelected),
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
          child: Center(
            child: Text(
              'STEM Tutor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ),
      );

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

  Widget _buildModeSelector() => SizedBox(
        height: 44,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: _modes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final mode = _modes[index];
            final selected = _selectedMode == mode;
            return ChoiceChip(
              label: Text(
                _modeLabels[mode] ?? mode,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : context.colors.textSecondary,
                ),
              ),
              selected: selected,
              selectedColor: AppColors.primary,
              backgroundColor: context.colors.surface,
              side: BorderSide(
                color: selected ? AppColors.primary : context.colors.border,
              ),
              onSelected: (_) => setState(() => _selectedMode = mode),
            );
          },
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
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    final hasVisuals = !isUser && AIVisualRenderer.hasVisuals(msg.text);
    final isDirectVisual = !isUser && msg.visual != null;
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
        child: isUser
            ? StemText(
                msg.text,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.4,
                ),
              )
            : isDirectVisual
                ? DirectVisualMessage(visual: msg.visual!, description: msg.text)
                : hasVisuals
                    ? InlineVisualMessage(text: msg.text, isUser: false)
                    : StemText(
                        msg.text,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.textSecondary,
                          height: 1.4,
                        ),
                        selectable: true,
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
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !_sending && _selectedConceptId != 0,
                  style: TextStyle(color: context.colors.textPrimary),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: _selectedConceptId == 0 ? 'Select a concept first...' : 'Ask a question...',
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
              GestureDetector(
                onTap: _sending ? null : _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _sending || _selectedConceptId == 0 ? context.colors.surfaceHighest : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final ParsedVisual? visual;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.visual,
  });
}
