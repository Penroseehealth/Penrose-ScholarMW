import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/services.dart';
import '../../services/web_speech_service.dart';
import '../../voice/voice.dart';
import '../../widgets/ai_governance_widgets.dart';
import '../../widgets/ai_thinking_indicator.dart';
import '../../widgets/attachment_picker.dart';
import '../../widgets/attachment_preview_card.dart';
import '../../widgets/data_table_chart.dart';
import '../../widgets/math_viz/ai_visual_parser.dart';
import '../../widgets/math_viz/ai_visual_renderer.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/offline_notices.dart';
import '../../widgets/pending_request_queue.dart';
import '../../widgets/stem_text.dart';
import '../../widgets/typewriter_renderer.dart';
import '../../widgets/visual_pipeline/raw_code_sanitizer.dart';
import '../../widgets/visual_pipeline/visual_response_renderer.dart';
import '../../widgets/voice_conversation_panel.dart';
import '../../widgets/voice_training_center.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final MultimodalService _mmService = MultimodalService();
  final ContextService _contextService = ContextService();
  final StreamingChatService _streamingService = StreamingChatService();
  final VoiceConversationService _voiceService = VoiceConversationService();
  final WebSpeechService _speechService = WebSpeechService();
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _messages = [];
  int? _sessionId;
  bool _isLoading = false;
  String _agentType = 'tutor';
  ThinkingState _thinkingState = ThinkingState.analyzing;

  final List<Map<String, dynamic>> _attachments = [];
  String _selectedVoiceId = 'en-us-academic-female-1';
  double _playbackSpeed = 1.0;
  bool _autoRead = false;
  int? _typewriterMessageIndex;

  PenroseVoiceEngine? _voiceEngine;
  bool _showVoicePanel = false;
  final FocusNode _composerFocus = FocusNode();

  bool _isStreaming = false;
  String _streamedContent = '';
  int? _streamedMessageIndex;

  bool get _showWelcome => _messages.isEmpty && _attachments.isEmpty;

  @override
  void initState() {
    super.initState();
    _composerFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  final Map<String, String> _agentLabels = {
    'tutor': 'Penrose Learning Assistant',
    'study_coach': 'Study Coach',
    'writer': 'Academic Writer',
    'research': 'Penrose Research Assistant',
    'assessment': 'Assessment AI',
  };

  ThinkingState _detectThinkingState(String message) {
    final lower = message.toLowerCase();
    if (RegExp(r'x\^|\\frac|\\int|\\sum|\\sqrt|calculus|algebra|derivative|integral').hasMatch(lower)) {
      return ThinkingState.solving;
    }
    if (_attachments.any((a) => a['file_type'] == 'pdf')) {
      return ThinkingState.reading;
    }
    return ThinkingState.analyzing;
  }

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

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityManager>();
    final colors = context.colors;

    return OfflineBanner(
      connectivity: connectivity,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: colors.background,
        endDrawer: VoiceTrainingCenter(
          selectedVoiceId: _selectedVoiceId,
          onVoiceSelected: (id) => setState(() => _selectedVoiceId = id),
          playbackSpeed: _playbackSpeed,
          onSpeedChanged: (s) => setState(() => _playbackSpeed = s),
          autoRead: _autoRead,
          onAutoReadChanged: (v) => setState(() => _autoRead = v),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(colors),
                if (_showWelcome) Expanded(child: _buildWelcomeScreen(colors)),
                if (!_showWelcome) Expanded(child: _buildChatArea()),
                if (_attachments.isNotEmpty) _buildAttachmentBar(),
                if (!_showWelcome) _buildInputArea(colors),
                PendingRequestQueue(
                  connectivity: connectivity,
                  onRetry: _retryPendingQuestion,
                ),
              ],
            ),
            if (_showVoicePanel && _voiceEngine != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    color: Colors.black54,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: VoiceConversationPanel(
                        engine: _voiceEngine!,
                        onClose: () {
                          _voiceEngine?.stopSpeaking();
                          _voiceEngine?.stopListening();
                          setState(() => _showVoicePanel = false);
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────

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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            _agentLabels[_agentType] ?? 'ScholarAI',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.record_voice_over_rounded, size: 20),
            color: colors.textSecondary,
            tooltip: 'Voice Training Center',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 20),
            itemBuilder: (ctx) => [
              ..._agentLabels.entries.map(
                (e) => PopupMenuItem(
                  value: e.key,
                  child: Text(e.value, style: TextStyle(color: colors.textPrimary)),
                ),
              ),
            ],
            onSelected: (value) => setState(() => _agentType = value),
          ),
        ],
      ),
    );
  }

  // ── Welcome Screen ─────────────────────────────────────────────

  Widget _buildWelcomeScreen(ThemeColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildWelcomePanel(colors),
          const SizedBox(height: 32),
          Text(
            'What would you like to learn?',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'ScholarAI is your multimodal academic assistant',
            style: TextStyle(fontSize: 15, color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _buildActionCards(colors),
          const SizedBox(height: 28),
          _buildScholarComposer(colors),
        ],
      ),
    );
  }

  Widget _buildActionCards(ThemeColors colors) {
    final cards = [
      _CardDef(Icons.lightbulb_outline, 'Explain a concept'),
      _CardDef(Icons.quiz_outlined, 'Quiz me'),
      _CardDef(Icons.image_rounded, 'Analyze an image'),
      _CardDef(Icons.picture_as_pdf_rounded, 'Summarize a PDF'),
      _CardDef(Icons.mic_rounded, 'Ask by voice'),
    ];

    return Column(
      children: cards.map((card) => _actionCard(card, colors)).toList(),
    );
  }

  Widget _actionCard(_CardDef card, ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF141522),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleCardTap(card.label),
          hoverColor: AppColors.primary.withValues(alpha: 0.06),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Icon(card.icon, size: 22, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    card.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScholarComposer(ThemeColors colors) {
    final focused = _composerFocus.hasFocus;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF141522),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: focused ? AppColors.primary : colors.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: focused ? 0.22 : 0.12),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _messageCtrl,
              focusNode: _composerFocus,
              minLines: 1,
              maxLines: 5,
              style: TextStyle(color: colors.textPrimary, fontSize: 15, height: 1.4),
              decoration: const InputDecoration(
                hintText: 'Ask anything about your learning...',
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.newline,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                _composerBtn(Icons.attach_file_rounded, 'Attach', _showAttachmentPicker, colors),
                const SizedBox(width: 4),
                _composerBtn(Icons.mic_rounded, 'Voice', _togglePiveVoice, colors),
                const Spacer(),
                _composerSendBtn(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composerBtn(IconData icon, String label, VoidCallback onTap, ThemeColors colors) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceElevated.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _composerSendBtn() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        onPressed: _sendMessage,
      ),
    );
  }

  Widget _buildWelcomePanel(ThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF141522),
            AppColors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          if (isNarrow) {
            return Column(
              children: [
                _welcomeText(colors),
                const SizedBox(height: 24),
                _welcomeIllustration(),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: _welcomeText(colors)),
              const SizedBox(width: 32),
              Expanded(flex: 6, child: _welcomeIllustration()),
            ],
          );
        },
      ),
    );
  }

  Widget _welcomeText(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to ScholarAI ✨',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [AppColors.primary, Color(0xFFC084FC)],
              ).createShader(const Rect.fromLTWH(0, 0, 250, 30)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your intelligent academic partner for\nlearning, research, and problem solving.',
          style: TextStyle(
            fontSize: 15,
            color: colors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),
        _tipBox(colors),
      ],
    );
  }

  Widget _tipBox(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: You can type, upload, or speak your question. '
              "I'll respond with text, audio, visuals, and more.",
              style: TextStyle(fontSize: 13, color: colors.textMuted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeIllustration() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow background
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primaryDark.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Book
          Positioned(
            bottom: 40,
            child: Column(
              children: [
                Icon(Icons.menu_book_rounded, size: 56, color: AppColors.primaryLight.withValues(alpha: 0.7)),
                const SizedBox(height: 4),
                Container(
                  width: 80,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.primaryDark.withValues(alpha: 0.1)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          // Cap
          Positioned(
            top: 36,
            child: Icon(Icons.school_rounded, size: 44, color: AppColors.primary),
          ),
          // Floating icons
          Positioned(
            top: 30,
            left: 24,
            child: _floatingIcon(Icons.lightbulb_outline),
          ),
          Positioned(
            top: 30,
            right: 24,
            child: _floatingIcon(Icons.bar_chart),
          ),
          Positioned(
            bottom: 80,
            left: 16,
            child: _floatingIcon(Icons.article_outlined),
          ),
          Positioned(
            bottom: 80,
            right: 16,
            child: _floatingIcon(Icons.functions_rounded),
          ),
          // Particles
          ...List.generate(6, (i) {
            final angle = (i * 60.0) * 3.14159 / 180;
            final radius = 90.0;
            return Positioned(
              left: 120 + radius * cos(angle),
              top: 120 + radius * sin(angle),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i.isEven
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : const Color(0xFF38D5E8).withValues(alpha: 0.4),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _floatingIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, size: 18, color: AppColors.primaryLight),
    );
  }

  // ── Chat Area (unchanged) ──────────────────────────────────────

  Widget _buildChatArea() => ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _messages.length + ((_isLoading && !_isStreaming) ? 1 : 0),
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
                  if (msg['attachments'] != null && (msg['attachments'] as List).isNotEmpty)
                    _buildAttachedFiles(msg['attachments'] as List<dynamic>),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : context.colors.surface,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(4) : null,
                        bottomLeft: !isUser ? const Radius.circular(4) : null,
                      ),
                      border: isUser ? null : Border.all(color: context.colors.border),
                    ),
                    child: isUser
                        ? StemText(msg['content'] as String? ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5))
                        : _buildAssistantMessage(msg, isTypewriting),
                  ),
                  if (!isUser && !isTypewriting)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: AiGovernanceBar(sourcesJson: msg['sources'] as String?),
                    ),
                ],
              ),
            ),
          );
        },
      );

  Widget _buildAssistantMessage(Map<String, dynamic> msg, bool isTypewriting) {
    final content = (msg['content'] ?? '') as String;
    final directVisual = msg['visual'] as ParsedVisual?;

    if (isTypewriting) {
      return TypewriterRenderer(
        content: content,
        onComplete: () {
          setState(() => _typewriterMessageIndex = null);
          _scrollToBottom();
        },
      );
    }

    if (directVisual != null) {
      return DirectVisualMessage(visual: directVisual, description: content);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _renderResponseContent(content),
      ],
    );
  }

  Widget _renderResponseContent(String content) {
    if (RawCodeSanitizer.containsRawVisualCode(content) || AIVisualRenderer.hasVisuals(content)) {
      return VisualResponseRenderer(responseText: content);
    }

    final parts = _splitContentParts(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        if (part['type'] == 'table') {
          final parsed = DataTableRenderer.fromMarkdown(part['content']!);
          return DataTableRenderer(headers: parsed.headers, rows: parsed.rows);
        }
        if (part['type'] == 'bar_chart') {
          return SimpleBarChart.fromMap('Data', _parseBarChartMap(part['content']!));
        }
        return StemText(
          part['content']!,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 14, height: 1.6),
          selectable: true,
        );
      }).toList(),
    );
  }

  List<Map<String, String>> _splitContentParts(String content) {
    final parts = <Map<String, String>>[];
    final lines = content.split('\n');
    final buffer = StringBuffer();
    var inTable = false;
    final tableBuffer = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        if (!inTable) {
          inTable = true;
          if (buffer.isNotEmpty) {
            parts.add({'type': 'text', 'content': buffer.toString()});
            buffer.clear();
          }
        }
        tableBuffer.writeln(line);
      } else {
        if (inTable) {
          inTable = false;
          final tableStr = tableBuffer.toString().trim();
          if (tableStr.split('\n').length >= 2) {
            parts.add({'type': 'table', 'content': tableStr});
          } else {
            buffer.writeln(tableStr);
          }
          tableBuffer.clear();
        }
        buffer.writeln(line);
      }
    }

    if (inTable && tableBuffer.isNotEmpty) {
      final tableStr = tableBuffer.toString().trim();
      if (tableStr.split('\n').length >= 2) {
        parts.add({'type': 'table', 'content': tableStr});
      } else {
        buffer.writeln(tableStr);
      }
    }

    if (buffer.isNotEmpty) {
      parts.add({'type': 'text', 'content': buffer.toString()});
    }

    if (parts.isEmpty) {
      parts.add({'type': 'text', 'content': content});
    }

    return parts;
  }

  Map<String, double> _parseBarChartMap(String content) {
    final result = <String, double>{};
    final pattern = RegExp(r'(\d+(?:\.\d+)?)');
    final lines = content.split('\n');
    for (final line in lines) {
      final colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final label = line.substring(0, colonIndex).trim();
        final valueStr = line.substring(colonIndex + 1).trim();
        final match = pattern.firstMatch(valueStr);
        if (match != null) {
          result[label] = double.tryParse(match.group(1) ?? '0') ?? 0;
        }
      }
    }
    return result;
  }

  Widget _buildAttachedFiles(List attachments) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: attachments
              .map<Widget>((a) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_fileIcon(a['file_type'] as String?), size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(a['filename'] as String? ?? '',
                            style: TextStyle(fontSize: 10, color: context.colors.textSecondary)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );

  IconData _fileIcon(String? type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'document':
        return Icons.article_rounded;
      case 'spreadsheet':
        return Icons.table_chart_rounded;
      case 'audio':
        return Icons.audio_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildAttachmentBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _attachments.map((a) {
              final status = a['file_id'] != null
                  ? AttachmentStatus.ready
                  : a['error'] != null
                      ? AttachmentStatus.error
                      : a['uploading'] == true
                          ? AttachmentStatus.uploading
                          : AttachmentStatus.processing;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AttachmentPreviewCard(
                  filename: a['filename'] as String? ?? '',
                  sizeBytes: a['size_bytes'] as int?,
                  status: status,
                  onRemove: () => setState(() => _attachments.remove(a)),
                ),
              );
            }).toList(),
          ),
        ),
      );

  // ── Input Area ─────────────────────────────────────────────────

  Widget _buildInputArea(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141522),
        border: Border(
          top: BorderSide(color: colors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _inputBtn(Icons.attach_file_rounded, _showAttachmentPicker),
            const SizedBox(width: 4),
            _inputBtn(
              _showVoicePanel ? Icons.close_rounded : Icons.mic_rounded,
              () {
                if (_showVoicePanel) {
                  _voiceEngine?.stopSpeaking();
                  _voiceEngine?.stopListening();
                  setState(() => _showVoicePanel = false);
                } else {
                  _togglePiveVoice();
                }
              },
              color: _showVoicePanel ? context.colors.error : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageCtrl,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
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
                    borderSide: const BorderSide(color: AppColors.primary),
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
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
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

  Widget _inputBtn(IconData icon, VoidCallback onTap, {Color? color}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (color ?? context.colors.textSecondary).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color ?? context.colors.textSecondary),
        ),
      );

  // ── Actions ────────────────────────────────────────────────────

  void _handleCardTap(String label) {
    switch (label) {
      case 'Analyze an image':
      case 'Summarize a PDF':
        _showAttachmentPicker();
      case 'Ask by voice':
        _togglePiveVoice();
      default:
        _messageCtrl.text = label;
        _sendMessage();
    }
  }

  void _retryPendingQuestion(Map<String, dynamic> question) {
    final message = question['message'] as String? ?? '';
    if (message.isNotEmpty) {
      _messageCtrl.text = message;
      _sendMessage();
    }
    context.read<ConnectivityManager>().removePendingQuestion(
          context.read<ConnectivityManager>().pendingQuestions.indexOf(question),
        );
  }

  void _showAttachmentPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AttachmentPicker(
        onFileSelected: (file) async {
          final attEntry = <String, dynamic>{
            'filename': file.name,
            'size_bytes': file.size,
            'file_type': _classifyFile(file.name),
            'uploading': true,
          };
          setState(() => _attachments.add(attEntry));

          try {
            final bytes = file.bytes ?? await file.xFile.readAsBytes();
            final result = await _mmService.uploadFileBytes(bytes.toList(), file.name);
            if (result['success'] == true) {
              final data = result['data'];
              attEntry['file_id'] = data['file_id'];
              attEntry['uploading'] = false;
            } else {
              attEntry['error'] = result['error'] ?? 'Upload failed';
              attEntry['uploading'] = false;
            }
          } catch (e) {
            attEntry['error'] = e.toString();
            attEntry['uploading'] = false;
          }
          if (mounted) setState(() {});
        },
      ),
    );
  }

  String _classifyFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return 'pdf';
    if (['png', 'jpg', 'jpeg', 'webp'].contains(ext)) return 'image';
    if (['doc', 'docx'].contains(ext)) return 'document';
    if (['xls', 'xlsx', 'csv'].contains(ext)) return 'spreadsheet';
    if (['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(ext)) return 'audio';
    return 'unknown';
  }

  // ── Send Message (unchanged) ───────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    final connectivity = context.read<ConnectivityManager>();

    if (connectivity.isOffline) {
      connectivity.savePendingQuestion(
        message: text,
        agentType: _agentType,
        sessionId: _sessionId,
      );
      setState(() {
        _messages.add({'role': 'user', 'content': text});
        _messages.add({'role': 'assistant', 'content': OfflineNotices.random()});
      });
      _messageCtrl.clear();
      _scrollToBottom();
      return;
    }

    final currentAttachments = List<Map<String, dynamic>>.from(_attachments);

    setState(() {
      _thinkingState = _detectThinkingState(text);
      _isLoading = true;
      if (text.isNotEmpty || currentAttachments.isNotEmpty) {
        _messages.add({
          'role': 'user',
          'content': text,
          'attachments': currentAttachments.isNotEmpty ? currentAttachments : null,
        });
      }
    });
    _messageCtrl.clear();
    _attachments.clear();
    _scrollToBottom();

    final fileIds = <String>[];
    for (final att in currentAttachments) {
      if (att['file_id'] != null) fileIds.add(att['file_id'] as String);
    }

    if (text.isNotEmpty) {
      _contextService.classifyIntent(text);
    }

    if (_sessionId != null) {
      _contextService.setActiveSession(_sessionId);
    }

    final msgIndex = _messages.length;
    bool usedStreaming = false;

    try {
      setState(() {
        _isStreaming = true;
        _streamedContent = '';
        _streamedMessageIndex = msgIndex;
      });
      _scrollToBottom();

      await for (final chunk in _streamingService.streamChat(
        message: text.isNotEmpty ? text : 'Analyze the uploaded file(s)',
        sessionId: _sessionId,
        agentType: _agentType,
        workspace: _contextService.currentWorkspace,
        fileIds: fileIds,
      )) {
        if (chunk.type == 'chunk') {
          setState(() {
            _streamedContent += chunk.content;
            if (usedStreaming) {
              _messages[msgIndex] = {'role': 'assistant', 'content': _streamedContent, 'is_streaming': true};
            } else {
              // First chunk: create the assistant bubble now (avoids an empty
              // speech bubble sitting on screen while the reply is generated).
              _messages.add({'role': 'assistant', 'content': _streamedContent, 'is_streaming': true});
            }
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
            // The text was already shown live while streaming; replaying it with
            // the typewriter would display the whole answer a second time.
            _typewriterMessageIndex = null;
          });
        } else if (chunk.type == 'error') {
          setState(() {
            if (usedStreaming && msgIndex < _messages.length) _messages.removeAt(msgIndex);
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
          if (usedStreaming && idx < _messages.length && _messages[idx]['is_streaming'] == true) {
            _messages.removeAt(idx);
          }
          _isStreaming = false;
          _streamedContent = '';
          _streamedMessageIndex = null;
        });
      }

      final result = await _mmService.chatWithFiles(
        message: text.isNotEmpty ? text : 'Analyze the uploaded file(s)',
        sessionId: _sessionId,
        agentType: _agentType,
        fileIds: fileIds,
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
            _contextService.setActiveSession(_sessionId);
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

    _contextService.clearTransientSelections();
  }

  // ── PIVE Voice Engine ──────────────────────────────────────────

  Future<void> _togglePiveVoice() async {
    if (_voiceEngine != null && _voiceEngine!.isSessionActive) {
      _voiceEngine?.stopSpeaking();
      _voiceEngine?.stopListening();
      setState(() => _showVoicePanel = !_showVoicePanel);
      return;
    }

    _voiceEngine = PenroseVoiceEngine();
    await _voiceEngine!.initialize(
      agentType: _agentType,
      language: 'en-US',
    );

    _voiceEngine!.session.addListener(() {
      if (mounted) setState(() {});
    });

    _voiceEngine!.conversation.configure(
      onAiResponded: (aiText, {modality = 'combined'}) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': aiText});
        });
        _scrollToBottom();
      },
      onUserSpoke: (transcript) {
        setState(() {
          _messages.add({'role': 'user', 'content': transcript});
        });
        _scrollToBottom();
      },
    );

    setState(() => _showVoicePanel = true);
    _voiceEngine!.startConversation();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _composerFocus.dispose();
    _streamingService.cancelCurrentStream();
    _voiceService.dispose();
    _speechService.dispose();
    _contextService.dispose();
    _voiceEngine?.dispose();
    super.dispose();
  }
}

class _CardDef {
  final IconData icon;
  final String label;
  const _CardDef(this.icon, this.label);
}
