import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_colors.dart';
import '../../services/services.dart';
import '../../widgets/ai_thinking_indicator.dart';
import '../../widgets/stem_text.dart';
import '../../widgets/typewriter_renderer.dart';

const Color _agriGreen = Color(0xFF22C55E);
const Color _agriGreenDark = Color(0xFF16A34A);
const Color _agriGreenGlow = Color(0x2222C55E);

class _ModeDef {
  final String key;
  final String label;
  final String icon;
  const _ModeDef(this.key, this.label, this.icon);
}

class AgricultureAiTutorScreen extends StatefulWidget {
  const AgricultureAiTutorScreen({super.key});

  @override
  State<AgricultureAiTutorScreen> createState() => _AgricultureAiTutorScreenState();
}

class _AgricultureAiTutorScreenState extends State<AgricultureAiTutorScreen> {
  final MultimodalService _mmService = MultimodalService();
  final StreamingChatService _streamingService = StreamingChatService();
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  int? _sessionId;
  bool _isLoading = false;
  bool _isStreaming = false;
  String _streamedContent = '';
  int? _streamedMessageIndex;
  int? _typewriterMessageIndex;
  ThinkingState _thinkingState = ThinkingState.analyzing;

  String _selectedMode = 'teach';

  static const _modes = [
    _ModeDef('teach', 'Teach', '🌱'),
    _ModeDef('practical', 'Practical Guide', '🔬'),
    _ModeDef('field', 'Field Scenario', '🌾'),
    _ModeDef('diagnose', 'Diagnose', '🧪'),
    _ModeDef('quiz', 'Quiz Me', '📝'),
    _ModeDef('revise', 'Revise', '🔄'),
    _ModeDef('analyze', 'Analyze', '📊'),
    _ModeDef('prepare', 'Prepare Me', '🎓'),
  ];

  bool get _showWelcome => _messages.isEmpty;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _modePrefix() {
    final mode = _modes.firstWhere((m) => m.key == _selectedMode);
    return '[MODE: ${mode.label}] ';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          _buildTopBar(colors),
          _buildModeBar(colors),
          if (_showWelcome) Expanded(child: _buildWelcomeScreen(colors)),
          if (!_showWelcome) Expanded(child: _buildChatArea(colors)),
          _buildInputArea(colors),
        ],
      ),
    );
  }

  Widget _buildTopBar(ThemeColors colors) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF10111C),
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/stem-subject/agriculture'),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_agriGreen, _agriGreenDark]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🌱', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          Text(
            'Agriculture AI Tutor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _agriGreenGlow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_messages.where((m) => m['role'] == 'user').length} msgs',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _agriGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBar(ThemeColors colors) {
    return Container(
      height: 52,
      color: const Color(0xFF0D0E18),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _modes.length,
        itemBuilder: (_, i) {
          final m = _modes[i];
          final selected = _selectedMode == m.key;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedMode = m.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _agriGreen : colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? _agriGreen : colors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.icon, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeScreen(ThemeColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _agriGreenGlow,
              shape: BoxShape.circle,
            ),
            child: const Text('🌱', style: TextStyle(fontSize: 40), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 20),
          Text(
            'Agriculture AI Tutor',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your AI-powered guide for agriculture learning',
            style: TextStyle(fontSize: 14, color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildWelcomeModes(colors),
          const SizedBox(height: 24),
          _buildWelcomeTips(colors),
        ],
      ),
    );
  }

  Widget _buildWelcomeModes(ThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF141522), _agriGreen.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _agriGreen.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a Learning Mode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _modes.map((m) {
              return GestureDetector(
                onTap: () => setState(() => _selectedMode = m.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedMode == m.key ? _agriGreen.withValues(alpha: 0.15) : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedMode == m.key ? _agriGreen.withValues(alpha: 0.4) : colors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _selectedMode == m.key ? _agriGreen : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeTips(ThemeColors colors) {
    final tips = [
      'Select a mode above, then ask a question to get started.',
      'Try "Teach" for concept explanations or "Quiz Me" for practice.',
      'Use "Diagnose" to identify crop issues or "Field Scenario" for practicals.',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: _agriGreen),
              const SizedBox(width: 8),
              Text('How to begin',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $t', style: TextStyle(fontSize: 12, color: colors.textMuted, height: 1.4)),
              )),
        ],
      ),
    );
  }

  Widget _buildChatArea(ThemeColors colors) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _messages.length) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AIThinkingIndicator(state: _thinkingState),
            ),
          );
        }
        final msg = _messages[i];
        final isUser = msg['role'] == 'user';
        final isTypewriting = _typewriterMessageIndex == i;
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser ? _agriGreen : colors.surface,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isUser ? const Radius.circular(4) : null,
                      bottomLeft: !isUser ? const Radius.circular(4) : null,
                    ),
                    border: isUser ? null : Border.all(color: colors.border),
                  ),
                  child: isUser
                      ? StemText(
                          msg['content'] as String? ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                        )
                      : _buildAssistantMessage(msg, isTypewriting, colors),
                ),
                if (!isUser && !isTypewriting)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 12, color: colors.textMuted),
                        const SizedBox(width: 4),
                        Icon(Icons.volume_up_rounded, size: 12, color: colors.textMuted),
                        const SizedBox(width: 4),
                        Icon(Icons.bookmark_add_rounded, size: 12, color: colors.textMuted),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssistantMessage(Map<String, dynamic> msg, bool isTypewriting, ThemeColors colors) {
    final content = (msg['content'] ?? '') as String;

    if (isTypewriting) {
      return TypewriterRenderer(
        content: content,
        onComplete: () {
          setState(() => _typewriterMessageIndex = null);
          _scrollToBottom();
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              'Agri AI',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _agriGreen.withValues(alpha: 0.8)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        StemText(
          content,
          style: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.6),
          selectable: true,
        ),
      ],
    );
  }

  Widget _buildInputArea(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141522),
        border: Border(top: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mic_rounded, size: 20, color: colors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageCtrl,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask about Agriculture...',
                  hintStyle: TextStyle(color: colors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: _agriGreen),
                  ),
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_agriGreen, _agriGreenDark]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _agriGreen.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final prefixedMessage = '${_modePrefix()}$text';

    setState(() {
      _thinkingState = _detectThinkingState(text);
      _isLoading = true;
      _messages.add({'role': 'user', 'content': text});
    });
    _messageCtrl.clear();
    _scrollToBottom();

    final msgIndex = _messages.length;
    bool usedStreaming = false;

    try {
      setState(() {
        _isStreaming = true;
        _streamedContent = '';
        _streamedMessageIndex = msgIndex;
        _messages.add({'role': 'assistant', 'content': '', 'is_streaming': true});
      });
      _scrollToBottom();

      await for (final chunk in _streamingService.streamChat(
        message: prefixedMessage,
        sessionId: _sessionId,
        agentType: 'tutor',
      )) {
        if (chunk.type == 'chunk') {
          setState(() {
            _streamedContent += chunk.content;
            _messages[msgIndex] = {'role': 'assistant', 'content': _streamedContent, 'is_streaming': true};
          });
          _scrollToBottom();
          usedStreaming = true;
        } else if (chunk.type == 'done') {
          setState(() {
            _messages[msgIndex] = {
              'role': 'assistant',
              'content': _streamedContent,
              'sources': chunk.sources,
            };
            _typewriterMessageIndex = msgIndex;
          });
        } else if (chunk.type == 'error') {
          setState(() {
            _messages.removeAt(msgIndex);
            _isStreaming = false;
            _streamedContent = '';
            _streamedMessageIndex = null;
          });
          usedStreaming = false;
          break;
        }
      }
    } catch (e) {
      usedStreaming = false;
    }

    if (!usedStreaming) {
      if (_isStreaming && _streamedMessageIndex != null) {
        setState(() {
          final idx = _streamedMessageIndex!;
          if (idx < _messages.length && _messages[idx]['is_streaming'] == true) {
            _messages.removeAt(idx);
          }
          _isStreaming = false;
          _streamedContent = '';
          _streamedMessageIndex = null;
        });
      }

      final result = await _mmService.chatWithFiles(
        message: prefixedMessage,
        sessionId: _sessionId,
        agentType: 'tutor',
      );

      if (mounted) {
        final fallbackIndex = _messages.length;
        setState(() {
          _isLoading = false;
          if (result['success'] == true) {
            final data = result['data'];
            _sessionId = (data['session_id'] ?? _sessionId) as int?;
            _messages.add({
              'role': 'assistant',
              'content': data['content'] ?? 'No response',
              'sources': data['sources'],
            });
            _typewriterMessageIndex = fallbackIndex;
          } else {
            _messages.add({
              'role': 'assistant',
              'content': result['error'] ?? 'Sorry, I encountered an error. Please try again.',
            });
          }
        });
        _scrollToBottom();
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
          _streamedContent = '';
          _streamedMessageIndex = null;
        });
      }
    }
  }

  ThinkingState _detectThinkingState(String message) {
    final lower = message.toLowerCase();
    if (RegExp(r'crop|plant|soil|fertilizer|irrig|harvest|pest').hasMatch(lower)) {
      return ThinkingState.analyzing;
    }
    if (RegExp(r'diagnos|disease|pest|wilt|yellow|blight').hasMatch(lower)) {
      return ThinkingState.reading;
    }
    return ThinkingState.analyzing;
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _streamingService.cancelCurrentStream();
    super.dispose();
  }
}
