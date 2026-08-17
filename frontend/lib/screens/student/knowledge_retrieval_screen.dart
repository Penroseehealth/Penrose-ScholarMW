import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

class KnowledgeRetrievalScreen extends StatefulWidget {
  const KnowledgeRetrievalScreen({super.key});

  @override
  State<KnowledgeRetrievalScreen> createState() =>
      _KnowledgeRetrievalScreenState();
}

class _KnowledgeRetrievalScreenState extends State<KnowledgeRetrievalScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _questionCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      text:
          'Hello! I am ScholarAI Knowledge Retrieval. Ask me anything '
          'from your vault and knowledge documents, and I will find '
          'the most relevant sources for you.',
      isUser: false,
      sources: [],
      confidence: null,
    ));
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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

  Future<void> _sendQuestion() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMessage(
        text: question,
        isUser: true,
        sources: [],
        confidence: null,
      ));
      _loading = true;
      _questionCtrl.clear();
    });
    _scrollToBottom();

    try {
      final response =
          await _api.post('/api/v1/knowledge/rag-query', body: {
        'question': question,
        'max_sources': 5,
      });

      if (response.statusCode == 200) {
        final decoded = _decodeResponse(response.body);
        final answer = decoded['answer'] ?? decoded['response'] ?? 'No answer found.';
        final sources = List<Map<String, dynamic>>.from(
          (decoded['sources'] ?? decoded['citations'] ?? []).map(
            (s) => Map<String, dynamic>.from(s),
          ),
        );
        final confidence =
            (decoded['confidence'] ?? 'medium').toString().toLowerCase();

        setState(() {
          _messages.add(_ChatMessage(
            text: answer.toString(),
            isUser: false,
            sources: sources,
            confidence: confidence,
          ));
          _loading = false;
        });
      } else {
        setState(() {
          _messages.add(_ChatMessage(
            text: 'Sorry, I could not process your request. Please try again.',
            isUser: false,
            sources: [],
            confidence: null,
          ));
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Connection error. Please check your network and try again.',
          isUser: false,
          sources: [],
          confidence: null,
        ));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  Map<String, dynamic> _decodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _voiceInput() async {
    if (_recording) return;

    final textCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Voice Input (Section 23)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic,
              size: 48,
              color: _recording ? AppColors.error : AppColors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Speak your question, or type below:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              decoration: InputDecoration(
                hintText: 'Type what you would say...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (textCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              } else {
                try {
                  final response = await _api.post(
                    '/api/v1/knowledge/voice-transcribe',
                    body: {'audio_text': '(simulated voice input)'},
                  );
                  if (response.statusCode == 200) {
                    final decoded = _decodeResponse(response.body);
                    textCtrl.text =
                        decoded['text'] ?? decoded['transcription'] ?? '';
                  }
                } catch (_) {}
                if (textCtrl.text.trim().isNotEmpty) {
                  if (ctx.mounted) Navigator.pop(ctx, true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && textCtrl.text.trim().isNotEmpty) {
      _questionCtrl.text = textCtrl.text.trim();
      _sendQuestion();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Retrieval'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _buildMessage(_messages[i]),
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage msg) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'ScholarAI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: isUser
                    ? null
                    : Border.all(
                        color: AppColors.divider,
                        width: 1,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isUser ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            if (!isUser && msg.confidence != null) ...[
              const SizedBox(height: 6),
              _buildConfidenceBadge(msg.confidence!),
            ],
            if (!isUser && msg.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...msg.sources.map((s) => _buildSourceCard(s)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(String confidence) {
    Color color;
    IconData icon;
    String label;

    switch (confidence) {
      case 'high':
        color = AppColors.success;
        icon = Icons.check_circle_outline;
        label = 'High Confidence';
        break;
      case 'low':
        color = AppColors.error;
        icon = Icons.warning_amber_outlined;
        label = 'Low Confidence';
        break;
      default:
        color = AppColors.warning;
        icon = Icons.info_outline;
        label = 'Medium Confidence';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(Map<String, dynamic> source) {
    final title = source['title'] ?? source['document'] ?? 'Unknown Source';
    final snippet = source['snippet'] ?? source['excerpt'] ?? '';
    final page = source['page'];
    final score = source['score'] ?? source['relevance'];

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (score != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(score is num ? (score * 100).round() : score)}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            if (snippet.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                snippet,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (page != null) ...[
              const SizedBox(height: 4),
              Text(
                'Page $page',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _recording ? null : _voiceInput,
              icon: Icon(
                _recording ? Icons.mic : Icons.mic_none,
                color: _recording ? AppColors.error : AppColors.primary,
              ),
              tooltip: 'Voice Input',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _questionCtrl,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Ask ScholarAI anything...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (_) => _sendQuestion(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _loading ? AppColors.textSecondary : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _loading ? null : _sendQuestion,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
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
  final List<Map<String, dynamic>> sources;
  final String? confidence;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.sources,
    required this.confidence,
  });
}
