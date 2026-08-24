import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

const Color _langTeal = Color(0xFF2DD4BF);
const Color _langTealDark = Color(0xFF14B8A6);
const Color _langTealGlow = Color(0x222DD4BF);

class LanguageAITutorScreen extends StatefulWidget {
  final String slug;

  const LanguageAITutorScreen({super.key, required this.slug});

  @override
  State<LanguageAITutorScreen> createState() => _LanguageAITutorScreenState();
}

class _LanguageAITutorScreenState extends State<LanguageAITutorScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;
  String? _activeQuickAction;

  static const _quickActions = [
    ('grammar', 'Explain grammar', Icons.menu_book_rounded),
    ('writing', 'Correct my writing', Icons.edit_note_rounded),
    ('conversation', 'Practice conversation', Icons.forum_rounded),
    ('quiz', 'Quiz me', Icons.quiz_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      'Hi! I am your ${_languageTitle(widget.slug)} AI Tutor. I adapt to your level and remember our chats.\n\n'
      'Use a quick action below or just ask me anything about the language.',
      false,
      DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(text.trim(), true, DateTime.now()));
      if (_activeQuickAction != null) {
        _messages.add(_ChatMessage(
          '__action__${_quickActions.firstWhere((a) => a.$1 == _activeQuickAction).$2}',
          true,
          DateTime.now(),
          isActionTag: true,
        ));
        _activeQuickAction = null;
      }
      _sending = true;
      _messageController.clear();
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 900));

    final response = _generateResponse(text);

    setState(() {
      _messages.add(_ChatMessage(response, false, DateTime.now()));
      _sending = false;
    });
    _scrollToBottom();
  }

  void _applyQuickAction(String action, String label) {
    setState(() => _activeQuickAction = action);
    switch (action) {
      case 'grammar':
        _messageController.text = 'Explain this grammar rule with examples: ';
        break;
      case 'writing':
        _messageController.text = 'Please correct this text: ';
        break;
      case 'conversation':
        _sendMessage('Let\'s practice conversation — pick an everyday topic and start.');
        break;
      case 'quiz':
        _sendMessage('Quiz me! Give me 5 questions on what we have covered so far.');
        break;
    }
  }

  String _generateResponse(String userText) {
    final q = userText.toLowerCase();

    if (q.contains('grammar') || q.contains('tense') || q.contains('rule')) {
      return '**Grammar Explanation** 📘\n\n'
          'Here is how it works, step by step:\n'
          '1. **Form** — how the structure is built (stem + ending)\n'
          '2. **When to use it** — the situation or time it expresses\n'
          '3. **Examples:**\n'
          '   • Affirmative sentence example\n'
          '   • Negative sentence example\n'
          '   • Question form example\n\n'
          '⚠️ Common mistake: learners often drop the agreement marker. Watch for it in your own writing!\n\n'
          'Want me to drill you on this with 3 quick exercises?';
    }
    if (q.contains('correct') || q.contains('fix') || q.contains('writing')) {
      return '**Writing Feedback** ✍️\n\n'
          'Overall meaning comes across clearly — nice work!\n\n'
          '✅ Strengths: good word choice and natural rhythm.\n'
          '🔧 Suggestions:\n'
          '• Check subject–verb agreement in longer sentences\n'
          '• Prefer shorter sentences until punctuation feels automatic\n'
          '• One spelling pattern to review appears twice here\n\n'
          'Revised version: paste your paragraph again after edits and I will re-check it.';
    }
    if (q.contains('conversation') || q.contains('practice')) {
      return 'Let\'s chat! 🗣️\n\n'
          'Imagine we just ran into each other at the market. I\'ll start:\n\n'
          '"Hey! Long time no see — what have you been up to this week?"\n\n'
          'Reply naturally; I will keep the dialogue going and note anything worth polishing.';
    }
    if (q.contains('quiz')) {
      return '**Quick Quiz** 🎯 — 5 questions\n\n'
          '1. Translate: "Good morning, how are you?"\n'
          '2. Fill the blank: Yesterday I ___ (go) to school.\n'
          '3. Which word does NOT belong: apple · banana · chair · mango?\n'
          '4. Rewrite as a question: "She lives nearby."\n'
          '5. Listening check: how would you politely decline an offer?\n\n'
          'Answer any subset and I will grade with explanations!';
    }
    if (q.contains('hello') || q.contains('hi ') || q == 'hi') {
      return 'Hello! 👋 Ready when you are. Ask about vocabulary, grammar, pronunciation, or just start chatting in the language.';
    }
    return 'Good question! Here is what matters most:\n\n'
        '• **Core idea** — the key concept behind what you asked\n'
        '• **Example in context** — one natural sentence using it\n'
        '• **Memory hook** — link it to something you already know\n\n'
        '➡️ Want a practice exercise, more examples, or shall we move to the next topic?';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildInputArea(),
          ],
        ),
      );

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.colors.textSecondary),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _langTealGlow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: _langTeal, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_languageTitle(widget.slug)} AI Tutor',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                    Text('Context-aware language coaching',
                        style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _langTealGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_userTurnCount()} turns',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _langTeal)),
              ),
            ],
          ),
        ),
      );

  int _userTurnCount() => _messages.where((m) => m.isUser && !m.isActionTag).length;

  Widget _buildBody() => Row(
        children: [
          if (MediaQuery.of(context).size.width >= 900) _buildHistorySidebar(),
          Expanded(child: _buildChatArea()),
        ],
      );

  Widget _buildHistorySidebar() {
    final sessions = _messages.where((m) => m.isUser && !m.isActionTag).take(8).toList();
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(right: BorderSide(color: context.colors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Chat History',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
          ),
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No history yet', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: sessions.length,
                    itemBuilder: (_, i) {
                      final m = sessions[i];
                      return ListTile(
                        dense: true,
                        leading:
                            Icon(Icons.chat_bubble_outline_rounded, size: 14, color: _langTeal.withValues(alpha: 0.7)),
                        title: Text(
                          m.text.length > 42 ? '${m.text.substring(0, 42)}…' : m.text,
                          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                        ),
                        subtitle: Text(
                          '${m.time.hour.toString().padLeft(2, '0')}:${m.time.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                        ),
                        onTap: () => _messageController.text = m.text,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() => Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildQuickActions(),
        ],
      );

  Widget _buildMessageList() {
    if (_messages.length <= 1 && !_sending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _langTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.translate_rounded, color: _langTeal, size: 40),
              ),
              const SizedBox(height: 20),
              Text('${_languageTitle(widget.slug)} AI Tutor',
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Grammar · Writing · Conversation · Quizzes',
                style: TextStyle(color: context.colors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return _buildTypingIndicator();
        return _buildMessageBubble(_messages[i]);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    if (msg.isActionTag) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.colors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.accent.withValues(alpha: 0.3)),
          ),
          child: Text(msg.text.replaceAll('__action__', ''),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.accent)),
        ),
      );
    }
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(colors: [
                  _langTeal.withValues(alpha: 0.18),
                  _langTealDark.withValues(alpha: 0.10),
                ])
              : null,
          color: isUser ? null : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          border: Border.all(
            color: isUser ? _langTeal.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.smart_toy_rounded, size: 13, color: AppColors.primaryLight),
                  const SizedBox(width: 6),
                  Text('${_languageTitle(widget.slug)} AI',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryLight)),
                ],
              ),
            if (!isUser) const SizedBox(height: 6),
            SelectableText(
              msg.text,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 6),
            Text(
              '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: context.colors.textMuted, fontSize: 10),
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(4)),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.smart_toy_rounded, color: AppColors.primaryLight, size: 14),
              const SizedBox(width: 8),
              ...List.generate(
                  3,
                  (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(Icons.circle, size: 6, color: AppColors.primaryLight.withValues(alpha: 0.5)),
                      )),
            ],
          ),
        ),
      );

  Widget _buildQuickActions() => Container(
        height: 52,
        color: context.colors.surface,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _quickActions.length,
          itemBuilder: (_, i) {
            final a = _quickActions[i];
            final active = _activeQuickAction == a.$1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: GestureDetector(
                onTap: () => _applyQuickAction(a.$1, a.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: active ? _langTeal.withValues(alpha: 0.15) : context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? _langTeal : context.colors.border,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(a.$3, size: 15, color: active ? _langTeal : context.colors.textMuted),
                      const SizedBox(width: 6),
                      Text(a.$2,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              color: active ? _langTeal : context.colors.textSecondary)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _buildInputArea() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: context.colors.textPrimary),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  decoration: InputDecoration(
                    hintText: 'Ask your tutor anything...',
                    hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: context.colors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _langTeal.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _langTeal.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _langTeal),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(color: _langTeal, borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF062B27)),
                  onPressed: () => _sendMessage(_messageController.text),
                ),
              ),
            ],
          ),
        ),
      );
}

String _languageTitle(String slug) {
  if (slug.isEmpty) return 'Language';
  return slug[0].toUpperCase() + slug.substring(1);
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isActionTag;

  const _ChatMessage(this.text, this.isUser, this.time, {this.isActionTag = false});
}
