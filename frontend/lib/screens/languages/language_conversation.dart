import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

const Color _langTeal = Color(0xFF2DD4BF);
const Color _langTealDark = Color(0xFF14B8A6);
const Color _langTealGlow = Color(0x222DD4BF);

class LanguageConversationScreen extends StatefulWidget {
  final String slug;

  const LanguageConversationScreen({super.key, required this.slug});

  @override
  State<LanguageConversationScreen> createState() =>
      _LanguageConversationScreenState();
}

class _LanguageConversationScreenState
    extends State<LanguageConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;
  int _selectedMode = 1;
  int? _activeScenario;

  static const _modes = [
    ('Beginner', Icons.wb_sunny_rounded,
        'Simple phrases with hints and translations'),
    ('Guided', Icons.map_rounded, 'Step-by-step dialogue with prompts'),
    ('Role Play', Icons.theater_comedy_rounded,
        'Immersive scenario conversations'),
    ('Free Conversation', Icons.forum_rounded,
        'Open-ended chat on any topic'),
  ];

  static const _scenarios = [
    ('School', Icons.school_rounded, 'Classroom & campus life'),
    ('Restaurant', Icons.restaurant_rounded, 'Ordering food & drinks'),
    ('Shopping', Icons.shopping_bag_rounded, 'Prices & bargaining'),
    ('Travel', Icons.flight_takeoff_rounded, 'Directions & transport'),
    ('Hospital', Icons.local_hospital_rounded, 'Health & symptoms'),
    ('Business', Icons.work_rounded, 'Meetings & emails'),
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      'Welcome to Conversation Practice! Pick a mode above, choose a scenario, and start chatting. '
      'I will reply in your target language and gently correct mistakes as we go.',
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

  void _selectScenario(int index) {
    setState(() => _activeScenario = index);
    final scenario = _scenarios[index];
    _messages.add(_ChatMessage(
      'Great! Let\'s role play: ${scenario.$1}. ${scenario.$3}. '
      'You start — try greeting me and telling me why you are here.',
      false,
      DateTime.now(),
    ));
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(text.trim(), true, DateTime.now()));
      _sending = true;
      _messageController.clear();
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 900));

    final modeLabel = _modes[_selectedMode].$1;
    final response =
        _generateResponse(text, modeLabel, _activeScenario != null ? _scenarios[_activeScenario!].$1 : null);

    setState(() {
      _messages.add(_ChatMessage(response, false, DateTime.now()));
      _sending = false;
    });
    _scrollToBottom();
  }

  String _generateResponse(String userText, String mode, String? scenario) {
    final q = userText.toLowerCase();
    final ctx = scenario ?? 'general conversation';

    if (mode == 'Beginner') {
      return '[Beginner mode] Nice try! Here is a simpler way to say it:\n\n'
          '"${_simplify(userText)}"\n\n'
          '💡 Tip: In $ctx contexts, short sentences are perfectly natural. Try repeating it once more.';
    }
    if (q.contains('hello') || q.contains('hi') || q.contains('greet')) {
      return 'Hello! Lovely to meet you. 😊\n\n'
          '✅ Correction check: your greeting was spot on.\n'
          '➡️ Follow-up: Tell me how your day has been so far.';
    }
    if (q.contains('order') || q.contains('menu') || q.contains('food')) {
      return 'Excellent ordering phrase! 🍽️\n\n'
          'In this role play I am the waiter: "Certainly — would you like anything to drink with that?"\n\n'
          'Try responding with a drink of your choice.';
    }
    if (q.contains('price') || q.contains('cost') || q.contains('how much')) {
      return 'That\'s the polite way to ask about price! 👏\n\n'
          'The seller answers: "That will be 5,000 — but for you, 4,500."\n\n'
          'Practice countering politely to negotiate.';
    }
    if (userText.trim().split(' ').length < 3) {
      return 'Good start! Let\'s expand that.\n\n'
          'Try a full sentence, e.g. describe what you can see around you in the $ctx setting.';
    }
    return 'Well expressed! Here is some light feedback:\n\n'
        '✅ Your sentence structure is clear.\n'
        '✨ Vocabulary upgrade: swap one common word for a more precise one.\n'
        '➡️ Keep going — ask me a question back to continue the $ctx dialogue.';
  }

  String _simplify(String text) {
    final words = text.trim().split(' ');
    if (words.length <= 4) return text;
    return '${words.take(4).join(' ')}… (keep it short!)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildModeSelector(),
          Expanded(child: _buildChatArea()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border:
            Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
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
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: context.colors.textSecondary),
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
              child: const Icon(Icons.record_voice_over_rounded,
                  color: _langTeal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_languageTitle(widget.slug)} Conversation',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary)),
                  Text('AI Conversation Practice',
                      style: TextStyle(
                          fontSize: 12, color: context.colors.textMuted)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _langTealGlow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_messages.length} msgs',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _langTeal)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      height: 52,
      color: context.colors.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _modes.length,
        itemBuilder: (_, i) {
          final m = _modes[i];
          final selected = _selectedMode == i;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedMode = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? _langTeal.withValues(alpha: 0.15)
                      : context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? _langTeal : context.colors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(m.$2,
                        size: 15,
                        color: selected ? _langTeal : context.colors.textMuted),
                    const SizedBox(width: 6),
                    Text(m.$1,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? _langTeal
                                : context.colors.textSecondary)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatArea() {
    return Column(
      children: [
        if (_activeScenario == null) _buildScenarioCards(),
        Expanded(child: _buildMessageList()),
      ],
    );
  }

  Widget _buildScenarioCards() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose a Scenario',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textSecondary)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
            children: [
              for (var i = 0; i < _scenarios.length; i++)
                _buildScenarioCard(i),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(int index) {
    final s = _scenarios[index];
    final active = _activeScenario == index;
    return GestureDetector(
      onTap: () => _selectScenario(index),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active
              ? _langTeal.withValues(alpha: 0.12)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? _langTeal : context.colors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(s.$2,
                color: active ? _langTeal : context.colors.textSecondary,
                size: 22),
            const SizedBox(height: 6),
            Text(s.$1,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? _langTeal
                        : context.colors.textPrimary)),
            Text(s.$3,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9, color: context.colors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
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
          color:
              isUser ? null : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          border: Border.all(
            color: isUser
                ? _langTeal.withValues(alpha: 0.3)
                : AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser
                      ? Icons.person_rounded
                      : Icons.smart_toy_rounded,
                  size: 13,
                  color: isUser ? _langTeal : AppColors.primaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  isUser ? 'You' : 'AI Partner',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          isUser ? _langTeal : AppColors.primaryLight),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              msg.text,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 6),
            Text(
              '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                  color: context.colors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16)
              .copyWith(bottomLeft: const Radius.circular(4)),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_rounded,
                color: AppColors.primaryLight, size: 14),
            const SizedBox(width: 8),
            ...List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.circle,
                    size: 6,
                    color: AppColors.primaryLight.withValues(alpha: 0.5)),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
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
                  hintText: _activeScenario != null
                      ? 'Reply in the scenario...'
                      : 'Type a message...',
                  hintStyle: TextStyle(
                      color: context.colors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: context.colors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _langTeal.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _langTeal.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _langTeal),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration:
                  BoxDecoration(color: _langTeal, borderRadius: BorderRadius.circular(12)),
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
}

String _languageTitle(String slug) {
  if (slug.isEmpty) return 'Language';
  return slug[0].toUpperCase() + slug.substring(1);
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  const _ChatMessage(this.text, this.isUser, this.time);
}
