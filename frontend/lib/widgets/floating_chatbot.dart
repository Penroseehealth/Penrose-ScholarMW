import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';
import '../services/api_service.dart';
import '../services/web_speech_service.dart';
import '../voice/tts_service.dart';
import '../voice/voice_session_manager.dart';
import 'stem_text.dart';

/// A global floating chatbot that can be opened from anywhere in the app.
///
/// Mounted once by [MaterialApp.router]'s builder so every route (dashboards,
/// labs, tutor, maths drill, ...) gets the same ScholarAI assistant without
/// each screen wiring its own. It talks to the backend `/ai/chat` endpoint,
/// which is served by the same AI chain as the tutor (Cloudflare -> HF -> Groq).
class FloatingChatbot extends StatefulWidget {
  const FloatingChatbot({super.key});

  /// Wrap [child] with the floating button + chat panel overlay.
  ///
  /// Mounted from [MaterialApp.router]'s `builder`, which sits *above* the
  /// router's [Navigator]. The panel contains a `TextField` and `SelectableText`
  /// that resolve selection handles/toolbars through the root [Overlay]
  /// (`Overlay.of(context, rootOverlay: true)`), so an [Overlay] MUST exist
  /// above this widget or those lookups return null and throw at runtime
  /// (the release build has no asserts to catch it). We therefore provide our
  /// own [Overlay] here rather than relying on the one inside the router.
  ///
  /// The button is a direct [Positioned] child of the [Stack] so Flutter honours
  /// the positioning (a `Positioned` returned by a nested widget's `build` is
  /// treated as a plain, unpositioned Stack child).
  static Widget wrap(BuildContext context, Widget? child) => Overlay(
        initialEntries: <OverlayEntry>[
          OverlayEntry(
            builder: (context) => Stack(
              fit: StackFit.expand,
              textDirection: TextDirection.ltr,
              children: [
                if (child != null) child,
                const Positioned(
                  right: 20,
                  bottom: 20,
                  child: FloatingChatbot(),
                ),
              ],
            ),
          ),
        ],
      );

  @override
  State<FloatingChatbot> createState() => _FloatingChatbotState();
}

class _FloatingChatbotState extends State<FloatingChatbot> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // Unified voice stack: the same TTS service and speech recogniser the AI
  // Tutor screen uses, so the floating bot speaks with identical behaviour
  // (server Edge/ElevenLabs voices, markdown/notation cleanup, sentence
  // streaming). It keeps its own lightweight session for TTS bookkeeping rather
  // than running the full PIVE conversation state machine.
  final VoiceSessionManager _voiceSession = VoiceSessionManager();
  late final PenroseTtsService _tts = PenroseTtsService(session: _voiceSession);
  final WebSpeechService _speech = WebSpeechService();

  bool _open = false;
  bool _sending = false;
  bool _speakReplies = false;
  bool _listening = false;
  final List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _voiceSession.createSession();
    _tts.initialize();
  }

  @override
  void dispose() {
    _speech.stopListening();
    _speech.dispose();
    _tts.dispose();
    _voiceSession.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toggleMic() {
    if (_listening) {
      _speech.stopListening();
      setState(() => _listening = false);
      return;
    }
    if (!_speech.isSupported) return;
    setState(() => _listening = true);
    _speech.startListening(
      lang: _voiceSession.language,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _controller.text = text);
        if (isFinal) {
          _speech.stopListening();
          setState(() => _listening = false);
        }
      },
      onEnd: () {
        if (mounted) setState(() => _listening = false);
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  void _speak(String text) {
    if (text.isEmpty) return;
    _tts.speak(text, lang: _voiceSession.language);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _api.post(
        '/ai/chat',
        body: <String, dynamic>{
          'message': text,
          'agent_type': 'tutor',
        },
      ).timeout(const Duration(seconds: 45));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // `jsonDecode` yields `Map<String, Object?>` on the web, which is not a
        // `Map<String, dynamic>`; matching on that type silently dropped every
        // successful reply. Accept any JSON object and read the field defensively.
        final decoded = jsonDecode(response.body);
        final content = decoded is Map ? decoded['content'] : null;
        final reply = (content as String?)?.trim() ?? 'No response';
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': reply,
            'sources': decoded is Map ? decoded['sources'] : null,
          });
        });
        if (_speakReplies) _speak(reply);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // FastAPI's HTTPBearer answers a missing Authorization header with 403
        // ("Not authenticated") and an expired/invalid one with 401, so both
        // mean the same thing here: the session is not usable.
        setState(() {
          _messages.add({'role': 'assistant', 'content': 'Please sign in to chat with ScholarAI.'});
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'ScholarAI could not answer that right now. Please try again.',
          });
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'ScholarAI is unreachable. Check your connection and try again.',
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_open) ...[
            _buildPanel(context),
            const SizedBox(height: 12),
          ],
          _buildButton(context),
        ],
      );

  Widget _buildButton(BuildContext context) => Semantics(
        button: true,
        label: _open ? 'Close ScholarAI Assistant' : 'Open ScholarAI Assistant',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => setState(() => _open = !_open),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                _open ? Icons.close_rounded : Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      );

  Widget _buildPanel(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.vertical - 120;
    final maxWidth = media.size.width - 40;
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight < 320 ? 320 : maxHeight,
          maxWidth: maxWidth < 260 ? 260 : maxWidth,
        ),
        child: SizedBox(
          width: 360,
          height: maxHeight < 480 ? maxHeight : 480,
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildMessages(context)),
                _buildComposer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        ),
        child: Row(
          children: [
            const Icon(Icons.school_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'ScholarAI Assistant',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            InkWell(
              onTap: () {
                setState(() => _speakReplies = !_speakReplies);
                if (!_speakReplies) _tts.stop();
              },
              child: Icon(
                _speakReplies ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => setState(() => _open = false),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      );

  Widget _buildMessages(BuildContext context) {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ask me anything about your studies.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _messages.length) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Thinking...', style: TextStyle(fontSize: 13)),
              ],
            ),
          );
        }
        final msg = _messages[i];
        final isUser = msg['role'] == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primary : context.colors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isUser
                ? Text(
                    msg['content'] as String? ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  )
                : StemText(
                    msg['content'] as String? ?? '',
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 14, height: 1.5),
                    selectable: true,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildComposer(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: Row(
          children: [
            if (_speech.isSupported)
              IconButton(
                onPressed: _sending ? null : _toggleMic,
                icon: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded),
                color: _listening ? context.colors.error : null,
                tooltip: _listening ? 'Stop listening' : 'Ask by voice',
              ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Type your question...',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded),
              color: AppColors.primary,
            ),
          ],
        ),
      );
}
