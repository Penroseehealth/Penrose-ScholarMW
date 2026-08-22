import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../widgets/ai_governance_widgets.dart';
import '../../widgets/ai_thinking_indicator.dart';
import '../../widgets/attachment_picker.dart';
import '../../widgets/attachment_preview_card.dart';
import '../../widgets/data_table_chart.dart';
import '../../widgets/stem_text.dart';
import '../../widgets/typewriter_renderer.dart';
import '../../widgets/voice_recorder.dart';
import '../../widgets/voice_training_center.dart';
import '../../widgets/speech_to_text_view.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final MultimodalService _mmService = MultimodalService();
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _messages = [];
  int? _sessionId;
  bool _isLoading = false;
  String _agentType = 'tutor';
  ThinkingState _thinkingState = ThinkingState.analyzing;

  final List<Map<String, dynamic>> _attachments = [];
  bool _showVoiceRecorder = false;
  String _selectedVoiceId = 'en-us-academic-female-1';
  double _playbackSpeed = 1.0;
  bool _autoRead = false;
  int? _typewriterMessageIndex;

  final Map<String, String> _agentLabels = {
    'tutor': 'Penrose Learning Assistant',
    'study_coach': 'Study Coach',
    'writer': 'Academic Writer',
    'research': 'Penrose Research Assistant',
    'assessment': 'Assessment AI',
  };

  ThinkingState _detectThinkingState(String message) {
    final lower = message.toLowerCase();
    if (RegExp(r'x\^|\\frac|\\int|\\sum|\\sqrt|calculus|algebra|derivative|integral')
        .hasMatch(lower)) {
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: VoiceTrainingCenter(
        selectedVoiceId: _selectedVoiceId,
        onVoiceSelected: (id) => setState(() => _selectedVoiceId = id),
        playbackSpeed: _playbackSpeed,
        onSpeedChanged: (s) => setState(() => _playbackSpeed = s),
        autoRead: _autoRead,
        onAutoReadChanged: (v) => setState(() => _autoRead = v),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
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
            const SizedBox(width: 10),
            Text(
              _agentLabels[_agentType] ?? 'ScholarAI',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.record_voice_over_rounded, size: 22),
            color: AppColors.textSecondary,
            tooltip: 'Voice Training Center',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            itemBuilder: (ctx) => [
              ..._agentLabels.entries.map((e) => PopupMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(color: AppColors.textPrimary)),
                  )),
            ],
            onSelected: (value) => setState(() => _agentType = value),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_messages.isEmpty && _attachments.isEmpty) _buildWelcomeScreen(),
          if (_messages.isNotEmpty || _attachments.isNotEmpty)
            Expanded(child: _buildChatArea()),
          if (_attachments.isNotEmpty) _buildAttachmentBar(),
          if (_showVoiceRecorder) _buildVoiceRecorder(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 28),
            const Text(
              'What would you like to learn?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'ScholarAI is your multimodal academic assistant',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 32),
            _suggestionChip(Icons.lightbulb_outline, 'Explain a concept'),
            _suggestionChip(Icons.quiz_outlined, 'Quiz me'),
            _suggestionChip(Icons.image_rounded, 'Analyze an image'),
            _suggestionChip(Icons.picture_as_pdf_rounded, 'Summarize a PDF'),
            _suggestionChip(Icons.mic_rounded, 'Ask by voice'),
            _suggestionChip(Icons.functions_rounded, 'Solve an equation'),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (text == 'Analyze an image' || text == 'Summarize a PDF') {
              _showAttachmentPicker();
            } else if (text == 'Ask by voice') {
              setState(() => _showVoiceRecorder = true);
            } else {
              _messageCtrl.text = text;
              _sendMessage();
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatArea() {
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
                if (msg['attachments'] != null && (msg['attachments'] as List).isNotEmpty)
                  _buildAttachedFiles(msg['attachments']),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isUser ? const Radius.circular(4) : null,
                      bottomLeft: !isUser ? const Radius.circular(4) : null,
                    ),
                    border: isUser ? null : Border.all(color: AppColors.border),
                  ),
                  child: isUser
                      ? Text(msg['content'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5))
                      : _buildAssistantMessage(msg, isTypewriting),
                ),
                if (!isUser && !isTypewriting)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: AiGovernanceBar(sourcesJson: msg['sources']),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssistantMessage(Map<String, dynamic> msg, bool isTypewriting) {
    final content = msg['content'] ?? '';

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
        _renderResponseContent(content),
        const SizedBox(height: 8),
        _buildResponseActions(content),
      ],
    );
  }

  Widget _renderResponseContent(String content) {
    final parts = _splitContentParts(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        if (part['type'] == 'table') {
          final parsed = DataTableRenderer.fromMarkdown(part['content']!);
          return DataTableRenderer(
            headers: parsed.headers,
            rows: parsed.rows,
          );
        }
        if (part['type'] == 'bar_chart') {
          return SimpleBarChart.fromMap('Data', _parseBarChartMap(part['content']!));
        }
        return StemText(
          part['content']!,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
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
    var tableBuffer = StringBuffer();

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

  Widget _buildResponseActions(String content) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _actionBtn(Icons.volume_up_rounded, 'Listen', () => _showTTS(content)),
        _actionBtn(Icons.copy_rounded, 'Copy', () {}),
        _actionBtn(Icons.refresh_rounded, 'Regenerate', () {}),
        _actionBtn(Icons.bookmark_add_rounded, 'Save', () {}),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachedFiles(List attachments) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: attachments.map<Widget>((a) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_fileIcon(a['file_type']), size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(a['filename'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _fileIcon(String? type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'image': return Icons.image_rounded;
      case 'document': return Icons.article_rounded;
      case 'spreadsheet': return Icons.table_chart_rounded;
      case 'audio': return Icons.audio_file_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildAttachmentBar() {
    return Container(
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
                filename: a['filename'] ?? '',
                sizeBytes: a['size_bytes'],
                status: status,
                onRemove: () => setState(() => _attachments.remove(a)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVoiceRecorder() {
    return VoiceRecorder(
      onRecordingComplete: (path) {
        setState(() {
          _showVoiceRecorder = false;
          _isLoading = true;
          _thinkingState = ThinkingState.transcribing;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSpeechToText(
              'I need help understanding photosynthesis and its role in energy transfer in plants.',
            );
          }
        });
      },
      onCancel: () => setState(() => _showVoiceRecorder = false),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _inputBtn(Icons.attach_file_rounded, _showAttachmentPicker),
            const SizedBox(width: 4),
            _inputBtn(
              _showVoiceRecorder ? Icons.close_rounded : Icons.mic_rounded,
              () => setState(() => _showVoiceRecorder = !_showVoiceRecorder),
              color: _showVoiceRecorder ? AppColors.error : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask ScholarAI...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                shape: BoxShape.circle,
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

  Widget _inputBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (color ?? AppColors.textSecondary).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
      ),
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

  void _showSpeechToText(String transcript) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SpeechToTextView(
        initialTranscript: transcript,
        onSend: (text) {
          Navigator.pop(context);
          _messageCtrl.text = text;
          _sendMessage();
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _showTTS(String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Listen to Response',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  content.length > 200 ? '${content.substring(0, 200)}...' : content,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              _ttsPlayerRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ttsPlayerRow() {
    bool playing = false;
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Row(
          children: [
            GestureDetector(
              onTap: () => setModalState(() => playing = !playing),
              child: Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  shape: BoxShape.circle,
                ),
                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: playing ? 0.5 : 0,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 4,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playing ? 'Playing at ${_playbackSpeed}x' : 'Tap play to listen',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

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
      if (att['file_id'] != null) fileIds.add(att['file_id']);
    }

    final result = await _mmService.chatWithFiles(
      message: text.isNotEmpty ? text : 'Analyze the uploaded file(s)',
      sessionId: _sessionId,
      agentType: _agentType,
      fileIds: fileIds,
    );

    if (mounted) {
      final msgIndex = _messages.length;
      setState(() {
        _isLoading = false;
        if (result['success']) {
          final data = result['data'];
          _sessionId = data['session_id'] ?? _sessionId;
          _messages.add({
            'role': 'assistant',
            'content': data['content'] ?? 'No response',
            'sources': data['sources'],
          });
          _typewriterMessageIndex = msgIndex;
        } else {
          _messages.add({
            'role': 'assistant',
            'content': result['error'] ?? 'Sorry, I encountered an error. Please try again.',
          });
        }
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
