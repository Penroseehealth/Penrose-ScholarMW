import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class CollaborationChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  const CollaborationChatScreen({super.key, required this.groupId, required this.groupName});
  @override
  State<CollaborationChatScreen> createState() => _CollaborationChatScreenState();
}

class _CollaborationChatScreenState extends State<CollaborationChatScreen> {
  static const _secureStorage = FlutterSecureStorage();
  WebSocketChannel? _channel;
  final _msgCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  final _messages = <Map<String, dynamic>>[];
  final _onlineUserIds = <int>{};
  bool _connected = false;
  bool _connecting = true;
  bool _isTyping = false;
  String? _typingUser;
  String? _error;
  Timer? _typingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _msgCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  String _buildWsUrl(String token) {
    final base = apiBaseUrl;
    final host = base.startsWith('http') ? base.replaceFirst('http', 'ws') : 'ws://localhost:8000';
    return '$host/api/v1/stem/ws/groups/${widget.groupId}?token=$token';
  }

  Future<void> _connect() async {
    setState(() { _connecting = true; _error = null; });
    final token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
      setState(() { _connecting = false; _error = 'Not authenticated. Please log in again.'; });
      return;
    }
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_buildWsUrl(token)));
      _channel!.stream.listen(_onMessage, onDone: _onDisconnected, onError: (_) => _onDisconnected());
      setState(() { _connecting = false; _connected = true; _reconnectAttempts = 0; });
    } catch (_) {
      setState(() { _connecting = false; _error = 'Connection failed. Tap to retry.'; });
      _scheduleReconnect();
    }
  }

  void _onDisconnected() {
    if (!mounted) return;
    setState(() { _connected = false; _connecting = false; });
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= 5) {
      if (mounted) setState(() => _error = 'Unable to connect. Tap to retry.');
      return;
    }
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 16));
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () { if (mounted && !_connected) _connect(); });
  }

  void _onMessage(dynamic raw) {
    if (!mounted) return;
    try {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      switch (data['type'] as String?) {
        case 'connected':
          _onlineUserIds.clear();
          for (final u in (data['online_users'] as List? ?? [])) {
            final id = u is Map ? (u['user_id'] ?? u['id']) : u;
            if (id is int) _onlineUserIds.add(id);
          }
          _messages.clear();
          for (final h in (data['history'] as List? ?? [])) {
            _messages.add(Map<String, dynamic>.from(h as Map));
          }
          setState(() {});
          _scrollToBottom();
        case 'chat':
          setState(() {
            _messages.add(Map<String, dynamic>.from(data));
            _typingUser = null;
            _isTyping = false;
          });
          _scrollToBottom();
        case 'typing':
          final isT = data['is_typing'] as bool? ?? true;
          setState(() { _isTyping = isT; _typingUser = isT ? data['user_name'] as String? : null; });
        case 'presence':
          final uid = data['user_id'] as int?;
          if (uid != null) {
            setState(() {
              data['status'] == 'online' ? _onlineUserIds.add(uid) : _onlineUserIds.remove(uid);
            });
          }
        case 'error':
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(data['detail'] as String? ?? 'Unknown error'),
              backgroundColor: AppColors.error,
            ));
          }
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtl.hasClients) {
        _scrollCtl.animateTo(_scrollCtl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _send() {
    final text = _msgCtl.text.trim();
    if (text.isEmpty || !_connected) return;
    _channel?.sink.add(jsonEncode({'type': 'chat', 'content': text}));
    _msgCtl.clear();
    _typingTimer?.cancel();
  }

  void _onTextChanged(String text) {
    _typingTimer?.cancel();
    if (text.isNotEmpty && _connected) {
      _channel?.sink.add(jsonEncode({'type': 'typing', 'content': ''}));
      _typingTimer = Timer(const Duration(seconds: 1), () {});
    }
  }

  String _fmtTime(dynamic ts) {
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts.toString());
    if (dt == null) return '';
    final now = DateTime.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return '$hh:$mm';
    return '${dt.day}/${dt.month} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?['id'] as int?;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(children: [
        Expanded(child: _buildBody(currentUserId)),
        _buildTypingIndicator(),
        _buildInputBar(),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
        onPressed: () => context.pop(),
      ),
      title: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(
            widget.groupName.isNotEmpty ? widget.groupName[0].toUpperCase() : '#',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              _connected ? '${_onlineUserIds.length} online' : _connecting ? 'Connecting...' : 'Disconnected',
              style: TextStyle(fontSize: 12, color: _connected ? AppColors.success : _connecting ? AppColors.warning : AppColors.error),
            ),
          ],
        )),
      ]),
      actions: [
        if (_onlineUserIds.isNotEmpty)
          Padding(padding: const EdgeInsets.only(right: 16), child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${_onlineUserIds.length}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ],
          )),
      ],
    );
  }

  Widget _buildBody(int? currentUserId) {
    if (_error != null && !_connected && !_connecting) {
      return GestureDetector(onTap: () { _reconnectAttempts = 0; _connect(); }, child: Center(
        child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.error.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            child: const Text('Retry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ])),
      ));
    }
    if (_connecting) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: AppColors.primary),
        SizedBox(height: 16),
        Text('Connecting to chat...', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
      ]));
    }
    if (_messages.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.forum_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        const Text('No messages yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        const Text('Start the conversation!', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ]));
    }
    return ListView.builder(
      controller: _scrollCtl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        return _buildBubble(msg, (msg['user_id'] as int?) == currentUserId);
      },
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, bool isMe) {
    final content = msg['content'] as String? ?? '';
    final name = msg['user_name'] as String? ?? 'Unknown';
    final time = _fmtTime(msg['timestamp']);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final maxW = MediaQuery.of(context).size.width * 0.78;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(initial,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.surfaceElevated,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(color: isMe ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!isMe) Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryLight)),
                ),
                Text(content, style: TextStyle(fontSize: 14, color: isMe ? Colors.white : AppColors.textPrimary)),
                const SizedBox(height: 4),
                Align(alignment: Alignment.bottomRight, child: Text(time,
                    style: TextStyle(fontSize: 11, color: isMe ? Colors.white.withValues(alpha: 0.6) : AppColors.textMuted))),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (!_isTyping || _typingUser == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ...List.generate(3, (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
        )),
        const SizedBox(width: 8),
        Flexible(child: Text('$_typingUser is typing...',
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textMuted),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
      child: SafeArea(top: false, child: Row(children: [
        Expanded(child: Container(
          decoration: BoxDecoration(color: AppColors.surfaceHighest, borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: _msgCtl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            maxLines: null,
            textInputAction: TextInputAction.send,
            enabled: _connected,
            onChanged: _onTextChanged,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: _connected ? 'Type a message...' : 'Reconnecting...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        )),
        const SizedBox(width: 8),
        Container(
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: IconButton(
            onPressed: _connected ? _send : null,
            icon: Icon(Icons.send_rounded,
                color: _connected ? Colors.white : Colors.white.withValues(alpha: 0.4), size: 18),
          ),
        ),
      ])),
    );
  }
}
