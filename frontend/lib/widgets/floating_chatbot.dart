import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';
import '../services/assistant_memory.dart';
import '../services/streaming_chat_service.dart';
import '../services/voice_catalog_service.dart';
import '../services/web_speech_service.dart';
import '../voice/tts_service.dart';
import '../voice/voice_session_manager.dart';
import 'stem_text.dart';
import 'typewriter_renderer.dart';

/// A global floating chatbot that can be opened from anywhere in the app.
///
/// Mounted once by [MaterialApp.router]'s builder so every route (dashboards,
/// labs, tutor, maths drill, ...) gets the same ScholarAI assistant without
/// each screen wiring its own. It streams from `/ai/chat/stream`, which is the
/// same AI chain the tutor uses, types the reply out character by character and
/// speaks it with the voice chosen in the Voice Training Center. The session id
/// and transcript are kept in [AssistantMemory] so closing the panel does not
/// lose the thread of the discussion.
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

class _FloatingChatbotState extends State<FloatingChatbot> with SingleTickerProviderStateMixin {
  final StreamingChatService _streaming = StreamingChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // Drives the layered brand mark: the base portrait plus four staggered
  // sound-wave layers ripple outward continuously so the button reads as a
  // "speaking" assistant rather than a static glyph.
  late final AnimationController _waveCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  static const List<String> _waveLayers = <String>[
    'assets/brand/assistant_base.png',
    'assets/brand/assistant_wave0.png',
    'assets/brand/assistant_wave1.png',
    'assets/brand/assistant_wave2.png',
    'assets/brand/assistant_wave3.png',
  ];

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
  bool _speakReplies = true;
  bool _continuous = true;
  bool _listening = false;

  /// True when the in-flight turn was started by voice, so the reply should be
  /// followed by reopening the mic for a natural back-and-forth conversation.
  bool _voiceTurn = false;
  final List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];

  /// Local continuity: conversation id, transcript and last-topic recap.
  AssistantMemory? _memory;
  int? _sessionId;

  /// Index of the assistant bubble currently being typed out, if any.
  int? _typingIndex;

  /// Index of the live assistant bubble while the reply is streaming.
  int? _replyIndex;

  double _speechSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    unawaited(_startVoiceStack());
  }

  /// Boots the voice stack and the restored conversation.
  ///
  /// These futures are unawaited, so anything that escapes them is reported
  /// outside Flutter's error zones: on web that surfaces as an uncaught
  /// JavaScript error and takes down the route that was building. Each step is
  /// contained on its own, so a missing microphone, an unreachable backend or
  /// blocked browser storage only disables that one feature.
  Future<void> _startVoiceStack() async {
    try {
      _voiceSession.createSession();
    } catch (error) {
      debugPrint('FloatingChatbot: voice session failed to start: $error');
    }
    try {
      await _tts.initialize();
    } catch (error) {
      debugPrint('FloatingChatbot: text-to-speech unavailable: $error');
    }
    try {
      await _restoreMemory();
    } catch (error, stack) {
      debugPrint('FloatingChatbot: could not restore the chat: $error\n$stack');
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _streaming.cancelCurrentStream();
    _speech.stopListening();
    _speech.dispose();
    _tts.dispose();
    _voiceSession.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Load the saved conversation, the chosen voice and the speech speed, then
  /// open the panel on the same thread the student left.
  Future<void> _restoreMemory() async {
    final memory = await AssistantMemory.load();
    final voiceId = await VoiceCatalogService.loadPreferredVoiceId();
    final speed = await VoiceCatalogService.loadPreferredSpeed();
    if (!mounted) return;

    final restored = <Map<String, dynamic>>[];
    if (memory.canResume && memory.transcript.isNotEmpty) {
      final recent = memory.transcript.length > 12
          ? memory.transcript.sublist(memory.transcript.length - 12)
          : memory.transcript;
      for (final entry in recent) {
        restored.add({'role': entry.role, 'content': entry.content, 'restored': true});
      }
    } else {
      // A fresh conversation after a break: show the recap so the previous
      // subject and the date it was discussed are not lost.
      final recap = memory.recap;
      if (recap != null) {
        restored.add({'role': 'assistant', 'content': recap, 'restored': true});
      }
    }

    setState(() {
      _memory = memory;
      _sessionId = memory.resumableSessionId;
      _tts.voiceId = voiceId;
      _speechSpeed = speed;
      _messages
        ..clear()
        ..addAll(restored);
    });
    _scrollToBottom();
  }

  void _toggleMic() {
    if (_listening) {
      _speech.stopListening();
      setState(() => _listening = false);
      return;
    }
    _startListening();
  }

  void _startListening() {
    if (!_speech.isSupported || _listening) return;
    setState(() => _listening = true);
    _speech.startListening(
      lang: _voiceSession.language,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _controller.text = text);
        if (isFinal) {
          _speech.stopListening();
          setState(() {
            _listening = false;
            _voiceTurn = true;
          });
          // A finished voice turn is sent immediately - no Send tap - so the
          // assistant synthesizes its reply as soon as the user stops talking.
          _send();
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

  /// Toggle hands-free conversation: replies are spoken and, once the assistant
  /// finishes, the microphone reopens for the next turn.
  void _toggleContinuous() {
    setState(() => _continuous = !_continuous);
    if (_continuous) {
      _speakReplies = true;
      _startListening();
    } else {
      _speech.stopListening();
      setState(() => _listening = false);
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _tts.speak(text, lang: _voiceSession.language, speed: _speechSpeed);
  }

  /// Start a completely new conversation: drop the local session so the server
  /// opens a fresh one, but keep the old transcript on the server for memory.
  Future<void> _newConversation() async {
    _streaming.cancelCurrentStream();
    _tts.stop();
    await _memory?.clear();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _sessionId = null;
      _typingIndex = null;
      _replyIndex = null;
      _sending = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final memory = _memory;
    final resumed = _sessionId != null;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true;
      _replyIndex = null;
      _typingIndex = null;
    });
    _controller.clear();
    _scrollToBottom();
    unawaited(memory?.remember('user', text, session: _sessionId));

    var reply = '';
    var errorKind = '';

    try {
      await for (final chunk in _streaming.streamChat(
        message: text,
        sessionId: _sessionId,
        agentType: 'tutor',
        resumed: resumed,
      )) {
        if (!mounted) return;

        if (chunk.sessionId != null) {
          _sessionId = chunk.sessionId;
          unawaited(memory?.adoptSession(chunk.sessionId!));
        }

        if (chunk.type == 'chunk') {
          reply += chunk.content;
          setState(() {
            if (_replyIndex == null) {
              _replyIndex = _messages.length;
              // The bubble types itself out as the stream arrives; the same
              // widget keeps revealing from where it is, so text does not pop
              // in word groups.
              _typingIndex = _replyIndex;
              _messages.add({'role': 'assistant', 'content': reply});
            } else {
              _messages[_replyIndex!] = {'role': 'assistant', 'content': reply};
            }
          });
          _scrollToBottom();
        } else if (chunk.type == 'done') {
          if (_replyIndex != null) {
            setState(() {
              _messages[_replyIndex!] = {
                'role': 'assistant',
                'content': reply,
                'sources': chunk.sources,
              };
            });
          }
        } else if (chunk.type == 'error') {
          errorKind = chunk.content;
          break;
        }
      }
    } catch (_) {
      errorKind = 'connection';
    }

    if (!mounted) return;

    if (reply.trim().isEmpty) {
      setState(() {
        _sending = false;
        _replyIndex = null;
        _typingIndex = null;
        _messages.add({
          'role': 'assistant',
          'content': errorKind == 'auth'
              ? 'Please sign in to chat with ScholarAI.'
              : 'ScholarAI could not answer that right now. Check your connection and try again.',
        });
      });
      _scrollToBottom();
      return;
    }

    setState(() => _sending = false);
    _scrollToBottom();
    unawaited(memory?.remember('assistant', reply, session: _sessionId));

    // Speak the finished answer with the voice from the Voice Training Center.
    if (_speakReplies) {
      await _speak(reply);
    }
    if (!mounted) return;

    // Reopen the mic so the conversation continues naturally, turn after turn.
    if (_voiceTurn || _continuous) _startListening();
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
              child: _open
                  ? const Icon(Icons.close_rounded, color: Colors.white, size: 26)
                  : AnimatedBuilder(
                      animation: _waveCtrl,
                      builder: (context, _) => _buildBrandMark(),
                    ),
            ),
          ),
        ),
      );

  /// Clips the layered brand assets into the 56px circle. The base portrait
  /// stays put; each wave layer pulses on a staggered phase so the arcs appear
  /// to ripple outward from the face and dissolve.
  Widget _buildBrandMark() {
    final t = _waveCtrl.value;
    return ClipOval(
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_waveLayers[0], fit: BoxFit.cover, filterQuality: FilterQuality.medium),
            for (int i = 0; i < 4; i++)
              Builder(
                builder: (context) {
                  final phase = (t + i * 0.18) % 1.0;
                  final opacity = (1 - phase) * (1 - phase);
                  return Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1.0 + 0.12 * phase,
                      child: Image.asset(
                        _waveLayers[i + 1],
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

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
                if (!_speakReplies) {
                  _tts.stop();
                  _speech.stopListening();
                  setState(() {
                    _continuous = false;
                    _listening = false;
                  });
                }
              },
              child: Icon(
                _speakReplies ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (_speech.isSupported) ...[
              const SizedBox(width: 12),
              InkWell(
                onTap: _toggleContinuous,
                child: Icon(
                  _continuous ? Icons.forum_rounded : Icons.forum_outlined,
                  color: _continuous ? const Color(0xFF8EF6E4) : Colors.white,
                  size: 20,
                ),
              ),
            ],
            const SizedBox(width: 12),
            InkWell(
              onTap: _newConversation,
              child: const Icon(Icons.add_comment_outlined, color: Colors.white, size: 20),
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
            'Ask me anything about your studies.\nTap the speech-pair icon for hands-free voice chat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length + ((_sending && _replyIndex == null) ? 1 : 0),
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
                : _buildAssistantBubble(context, i, msg),
          ),
        );
      },
    );
  }

  /// Assistant text. Live answers are revealed one character at a time with
  /// grammar-aware pauses; restored history appears instantly because replaying
  /// the animation would be noise.
  Widget _buildAssistantBubble(BuildContext context, int index, Map<String, dynamic> msg) {
    final content = msg['content'] as String? ?? '';
    final style = TextStyle(color: context.colors.textPrimary, fontSize: 14, height: 1.5);
    if (_typingIndex == index) {
      return TypewriterRenderer(
        content: content,
        style: style,
        onComplete: () {
          if (!mounted) return;
          setState(() => _typingIndex = null);
          _scrollToBottom();
        },
      );
    }
    return StemText(content, style: style, selectable: true);
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
                icon: Icon(
                  _continuous ? Icons.mic_rounded : (_listening ? Icons.mic_rounded : Icons.mic_none_rounded),
                ),
                color: _listening ? context.colors.error : null,
                tooltip: _continuous
                    ? 'Conversation mode (auto-listening)'
                    : (_listening ? 'Stop listening' : 'Ask by voice'),
              ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  _voiceTurn = false;
                  _send();
                },
                decoration: const InputDecoration(
                  hintText: 'Type your question...',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              onPressed: _sending
                  ? null
                  : () {
                      _voiceTurn = false;
                      _send();
                    },
              icon: const Icon(Icons.send_rounded),
              color: AppColors.primary,
            ),
          ],
        ),
      );
}
