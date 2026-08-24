import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/services.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final StemService _stemService = StemService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _conversations = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _stemService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = data;
          _filtered = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _filterConversations(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = _conversations);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filtered = _conversations.where((c) {
        final name = (c['other_user_name'] ?? c['name'] ?? '').toString().toLowerCase();
        final lastMsg = (c['last_message'] ?? '').toString().toLowerCase();
        return name.contains(q) || lastMsg.contains(q);
      }).toList();
    });
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Future<void> _startNewConversation() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _NewConversationDialog(),
    );
    if (result != null && result['user_id'] != null) {
      final conv = await _stemService.createConversation(
        result['user_id'] as int,
        initialMessage: result['message'] as String?,
      );
      if (conv.isNotEmpty && mounted) {
        _loadConversations();
      }
    }
  }

  void _openChat(Map<String, dynamic> conversation) {
    final convId = conversation['id'];
    final name = conversation['other_user_name'] ?? conversation['name'] ?? 'Chat';
    context.push('/messages/chat/$convId', extra: name);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.surface,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.colors.textSecondary),
            onPressed: () => context.go('/'),
          ),
          title: Text(
            'Messages',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadConversations,
          color: AppColors.primary,
          backgroundColor: context.colors.surface,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: context.colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      prefixIcon: Icon(Icons.search_rounded, color: context.colors.textMuted),
                    ),
                    onChanged: _filterConversations,
                  ),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: ErrorState(
                    message: 'Failed to load messages',
                    onRetry: _loadConversations,
                  ),
                )
              else if (_filtered.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No conversations yet',
                    subtitle: 'Start a conversation with someone',
                    buttonText: 'New Message',
                    onButtonPressed: _startNewConversation,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final conv = _filtered[index] as Map<String, dynamic>;
                      return _buildConversationCard(conv);
                    },
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _startNewConversation,
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.edit_rounded, color: Colors.white),
        ),
      );

  Widget _buildConversationCard(Map<String, dynamic> conv) {
    final name = conv['other_user_name'] ?? conv['name'] ?? 'Unknown';
    final lastMsg = conv['last_message'] ?? '';
    final unread = (conv['unread_count'] ?? 0) as int;
    final timestamp = conv['last_message_at'] ?? conv['updated_at'];
    final avatar = name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : '?';

    return Material(
      color: unread > 0 ? context.colors.primaryGlow.withValues(alpha: 0.3) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openChat(conv),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread > 0 ? AppColors.primary.withValues(alpha: 0.3) : context.colors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    avatar,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name.toString(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timestamp != null)
                          Text(
                            _timeAgo(timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: unread > 0 ? AppColors.primary : context.colors.textMuted,
                              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMsg.toString(),
                            style: TextStyle(
                              fontSize: 13,
                              color: unread > 0 ? context.colors.textSecondary : context.colors.textMuted,
                              fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewConversationDialog extends StatefulWidget {
  const _NewConversationDialog();

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  final StemService _stemService = StemService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  List<dynamic> _users = [];
  bool _searching = false;
  int? _selectedUserId;
  String _selectedUserName = '';

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() => _users = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _stemService.searchUsers(query);
    if (mounted) {
      setState(() {
        _users = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: context.colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.colors.border),
        ),
        title: Text('New Conversation', style: TextStyle(color: context.colors.textPrimary)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: Icon(Icons.search_rounded, color: context.colors.textMuted),
                ),
                onChanged: _searchUsers,
              ),
              if (_searching) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ],
              if (_selectedUserId != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colors.primaryGlow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_selectedUserName,
                              style: TextStyle(color: context.colors.textPrimary, fontSize: 14))),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 16, color: context.colors.textMuted),
                        onPressed: () => setState(() {
                          _selectedUserId = null;
                          _selectedUserName = '';
                        }),
                      ),
                    ],
                  ),
                ),
              ],
              if (_users.isNotEmpty && _selectedUserId == null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final name = user['full_name'] ?? user['name'] ?? 'Unknown';
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: context.colors.primaryGlow,
                          child: Text(
                            name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.primary, fontSize: 13),
                          ),
                        ),
                        title: Text(name.toString(), style: TextStyle(color: context.colors.textPrimary, fontSize: 14)),
                        onTap: () {
                          setState(() {
                            _selectedUserId = user['id'] as int?;
                            _selectedUserName = name.toString();
                            _users = [];
                            _searchController.clear();
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                style: TextStyle(color: context.colors.textPrimary),
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'First message (optional)...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: context.colors.textMuted)),
          ),
          TextButton(
            onPressed: _selectedUserId == null
                ? null
                : () {
                    Navigator.of(context).pop({
                      'user_id': _selectedUserId,
                      'message': _messageController.text.isNotEmpty ? _messageController.text : null,
                    });
                  },
            child: const Text('Start', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      );
}
