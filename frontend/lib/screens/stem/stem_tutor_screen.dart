import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

class StemTutorScreen extends StatefulWidget {
  final int conceptId;
  const StemTutorScreen({super.key, this.conceptId = 0});

  @override
  State<StemTutorScreen> createState() => _StemTutorScreenState();
}

class _StemTutorScreenState extends State<StemTutorScreen> {
  final StemService _stemService = StemService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _subjects = [];
  List<dynamic> _concepts = [];
  List<_ChatMessage> _messages = [];
  bool _loading = false;
  bool _sending = false;
  int _selectedConceptId = 0;
  String _selectedMode = 'explain';
  String? _error;

  static const _modes = [
    'explain',
    'teach_me',
    'give_example',
    'quiz',
    'compare',
    'step_by_step',
    'visualize',
    'simplify',
    'deep_dive',
    'connect',
    'challenge',
  ];

  static const _modeLabels = {
    'explain': 'Explain',
    'teach_me': 'Teach me',
    'give_example': 'Example',
    'quiz': 'Quiz',
    'compare': 'Compare',
    'step_by_step': 'Step by Step',
    'visualize': 'Visualize',
    'simplify': 'Simplify',
    'deep_dive': 'Deep Dive',
    'connect': 'Connect',
    'challenge': 'Challenge',
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
    setState(() { _loading = true; _error = null; });
    try {
      final subjects = await _stemService.getSubjects();
      if (subjects.isNotEmpty) {
        final slug = subjects[0]['slug'] ?? '';
        final disciplines = await _stemService.getDisciplines(slug);
        if (disciplines.isNotEmpty) {
          final topics = await _stemService.getTopics(disciplines[0]['id'] ?? 0);
          if (topics.isNotEmpty) {
            final subtopics = await _stemService.getSubtopics(topics[0]['id'] ?? 0);
            if (subtopics.isNotEmpty) {
              final concepts = await _stemService.getConcepts(subtopics[0]['id'] ?? 0);
              if (mounted) {
                setState(() {
                  _subjects = subjects;
                  _concepts = concepts;
                  _loading = false;
                  if (_selectedConceptId == 0 && concepts.isNotEmpty) {
                    _selectedConceptId = concepts[0]['id'] ?? 0;
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
          _subjects = subjects;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedConceptId == 0) return;

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
      final response = await _stemService.chatWithStemTutor(
        _selectedConceptId,
        text,
        _selectedMode,
      );
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: response['response'] ?? response['message'] ?? 'No response received.',
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
            _buildInputBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primaryMuted],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const SizedBox(
        height: 56,
        child: Center(
          child: Text(
            'STEM Tutor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConceptSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: DropdownButton<int>(
        value: _selectedConceptId != 0 ? _selectedConceptId : null,
        hint: const Text('Select a concept', style: TextStyle(color: AppColors.textMuted)),
        isExpanded: true,
        dropdownColor: AppColors.surfaceElevated,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
        items: _concepts.map<DropdownMenuItem<int>>((c) {
          return DropdownMenuItem(
            value: c['id'] ?? 0,
            child: Text(
              c['title'] ?? c['name'] ?? '',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          );
        }).toList(),
        onChanged: (v) => setState(() => _selectedConceptId = v ?? 0),
      ),
    );
  }

  Widget _buildModeSelector() {
    return SizedBox(
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
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            selected: selected,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            onSelected: (_) => setState(() => _selectedMode = mode),
          );
        },
      ),
    );
  }

  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text(
              'Ask me anything about STEM',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a concept and start chatting',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 14,
            color: isUser ? Colors.white : AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Thinking...',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_sending && _selectedConceptId != 0,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: _selectedConceptId == 0 ? 'Select a concept first...' : 'Ask a question...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
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
                  color: _sending || _selectedConceptId == 0
                      ? AppColors.surfaceHighest
                      : AppColors.primary,
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
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}
