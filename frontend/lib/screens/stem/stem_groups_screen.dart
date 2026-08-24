import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/shimmer_loading.dart';

class StemGroupsScreen extends StatefulWidget {
  const StemGroupsScreen({super.key});

  @override
  State<StemGroupsScreen> createState() => _StemGroupsScreenState();
}

class _StemGroupsScreenState extends State<StemGroupsScreen> with SingleTickerProviderStateMixin {
  final StemService _stemService = StemService();
  late TabController _tabController;

  List<dynamic> _myGroups = [];
  List<dynamic> _allGroups = [];
  List<dynamic> _subjects = [];
  bool _loading = true;
  String _selectedSubject = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subjects = await _stemService.getSubjects();
      final myGroups = await _stemService.getMyGroups();
      final allGroups = await _stemService.getStudyGroups(
        subjectSlug: _selectedSubject.isNotEmpty ? _selectedSubject : null,
      );
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _myGroups = myGroups;
          _allGroups = allGroups;
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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 90,
                pinned: true,
                backgroundColor: AppColors.primaryDark,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Study Groups',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primaryMuted],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primaryLight,
                  labelColor: context.colors.textPrimary,
                  unselectedLabelColor: context.colors.textMuted,
                  tabs: const [
                    Tab(text: 'My Groups'),
                    Tab(text: 'All Groups'),
                  ],
                ),
              ),
              if (_error != null && !_loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ErrorState(message: _error!, onRetry: _loadData),
                  ),
                )
              else if (_loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ShimmerLoading.list(),
                  ),
                )
              else
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMyGroupsTab(),
                      _buildAllGroupsTab(),
                    ],
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateGroupDialog,
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      );

  Widget _buildMyGroupsTab() {
    if (_myGroups.isEmpty) {
      return const EmptyState(
          icon: Icons.groups_rounded, title: 'No groups yet', subtitle: 'Join or create a study group to get started');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _myGroups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildGroupCard(_myGroups[index], isMyGroup: true),
    );
  }

  Widget _buildAllGroupsTab() => Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _subjects.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final selected = _selectedSubject.isEmpty;
                  return ChoiceChip(
                    label: const Text('All', style: TextStyle(fontSize: 12)),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    backgroundColor: context.colors.surface,
                    side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
                    onSelected: (_) {
                      setState(() => _selectedSubject = '');
                      _loadData();
                    },
                  );
                }
                final s = _subjects[index - 1];
                final selected = _selectedSubject == s['slug'];
                return ChoiceChip(
                  label: Text(
                    (s['name'] ?? '') as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : context.colors.textSecondary,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  backgroundColor: context.colors.surface,
                  side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
                  onSelected: (_) {
                    setState(() => _selectedSubject = (s['slug'] ?? '') as String);
                    _loadData();
                  },
                );
              },
            ),
          ),
          Expanded(
            child: _allGroups.isEmpty
                ? const EmptyState(
                    icon: Icons.groups_rounded, title: 'No groups found', subtitle: 'Try a different subject filter')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _allGroups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildGroupCard(_allGroups[index]),
                  ),
          ),
        ],
      );

  Widget _buildGroupCard(dynamic group, {bool isMyGroup = false}) {
    final memberCount = group['member_count'] ?? 0;
    final maxMembers = group['max_members'];
    final memberText = maxMembers != null ? '$memberCount / $maxMembers members' : '$memberCount members';

    return GestureDetector(
      onTap: () => _openGroupDetail(group),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (group['name'] ?? '') as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (group['subject_name'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.primaryGlow,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      group['subject_name'] as String,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.people_rounded, size: 14, color: context.colors.textMuted),
                const SizedBox(width: 4),
                Text(
                  memberText,
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                ),
              ],
            ),
            if (group['description'] != null && (group['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                group['description'] as String,
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (!isMyGroup) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _stemService.joinGroup(group['id'] as int);
                    _loadData();
                  },
                  icon: const Icon(Icons.login_rounded, size: 14),
                  label: const Text('Join', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openGroupDetail(dynamic group) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _GroupDetailPage(groupId: group['id'] as int, group: group),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String? selectedSubject;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          'Create Study Group',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
        ),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Group name',
                  hintStyle: TextStyle(color: context.colors.textMuted),
                  filled: true,
                  fillColor: context.colors.surfaceHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                style: TextStyle(color: context.colors.textPrimary),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  hintStyle: TextStyle(color: context.colors.textMuted),
                  filled: true,
                  fillColor: context.colors.surfaceHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedSubject,
                dropdownColor: context.colors.surface,
                style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Subject (optional)',
                  hintStyle: TextStyle(color: context.colors.textMuted),
                  filled: true,
                  fillColor: context.colors.surfaceHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _subjects
                    .map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                          value: s['slug'] as String?,
                          child: Text((s['name'] ?? '') as String),
                        ))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedSubject = val),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.colors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await _stemService.createStudyGroup(
                nameController.text.trim(),
                descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                selectedSubject,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _GroupDetailPage extends StatefulWidget {
  final int groupId;
  final dynamic group;

  const _GroupDetailPage({required this.groupId, required this.group});

  @override
  State<_GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<_GroupDetailPage> {
  final StemService _stemService = StemService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _detail;
  List<dynamic> _messages = [];
  List<dynamic> _sessions = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _stemService.getGroupDetail(widget.groupId);
      final messages = await _stemService.getGroupMessages(widget.groupId);
      final sessions = await _stemService.getGroupSessions(widget.groupId);
      final stats = await _stemService.getGroupSessionStats(widget.groupId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _messages = messages;
          _sessions = sessions;
          _stats = stats;
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

  Future<void> _startSession() async {
    final titleController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Start Study Session',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
        content: TextField(
          controller: titleController,
          style: TextStyle(color: context.colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Session title',
            hintStyle: TextStyle(color: context.colors.textMuted),
            filled: true,
            fillColor: context.colors.surfaceHighest,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, titleController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await _stemService.startGroupSession(widget.groupId, result);
      _loadDetail();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Widget _buildSessionsSection() {
    final totalSessions = _stats?['total_sessions'] ?? _sessions.length;
    final totalMinutes = _stats?['total_duration_minutes'] ?? 0;
    final uniqueConcepts = _stats?['unique_concepts'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Study Sessions',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSessionStat('Sessions', '$totalSessions', AppColors.primary),
              const SizedBox(width: 12),
              _buildSessionStat('Hours', '${(totalMinutes / 60).toStringAsFixed(1)}', context.colors.teal),
              const SizedBox(width: 12),
              _buildSessionStat('Concepts', '$uniqueConcepts', context.colors.lavender),
            ],
          ),
          if (_sessions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: context.colors.border, height: 1),
            const SizedBox(height: 10),
            ..._sessions.take(3).map((s) => _buildSessionItem(s)),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionStat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
            ],
          ),
        ),
      );

  Widget _buildSessionItem(dynamic session) {
    final isActive = session['ended_at'] == null;
    final duration = session['duration_minutes'];
    final concepts = (session['concepts'] as List<dynamic>?) ?? [];
    final title = (session['title'] ?? 'Untitled Session') as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? context.colors.success.withValues(alpha: 0.08) : context.colors.surfaceHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? context.colors.success.withValues(alpha: 0.3) : context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? context.colors.success : context.colors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  duration != null ? '$duration min' : (isActive ? 'In progress' : 'Ended'),
                  style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                ),
              ],
            ),
          ),
          if (concepts.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.primaryGlow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${concepts.length} concept${concepts.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await _stemService.sendGroupMessage(widget.groupId, text);
    final messages = await _stemService.getGroupMessages(widget.groupId);
    if (mounted) {
      setState(() => _messages = messages);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _detail?['members'] as List<dynamic>? ?? [];
    final groupName = (widget.group['name'] ?? '') as String;
    final subjectName = (widget.group['subject_name'] ?? '') as String;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: Text(
          groupName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.live_tv_rounded, color: context.colors.success),
            tooltip: 'Live Chat',
            onPressed: () => context.push('/collab-chat/${widget.groupId}?name=${Uri.encodeComponent(groupName)}'),
          ),
        ],
      ),
      body: _error != null && !_loading
          ? Center(child: ErrorState(message: _error!, onRetry: _loadDetail))
          : _loading
              ? Center(child: ShimmerLoading.list(count: 3))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        border: Border(bottom: BorderSide(color: context.colors.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subjectName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.colors.primaryGlow,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                subjectName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 60,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: members.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final member = members[index];
                                final isAdmin = member['role'] == 'admin';
                                return Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isAdmin ? AppColors.primary : context.colors.surfaceHighest,
                                      child: Text(
                                        (member['name'] ?? member['username'] ?? '?')[0].toString().toUpperCase(),
                                        style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          (member['name'] ?? member['username'] ?? '') as String,
                                          style: TextStyle(fontSize: 9, color: context.colors.textMuted),
                                        ),
                                        if (isAdmin) ...[
                                          const SizedBox(width: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: const Text(
                                              'ADMIN',
                                              style: TextStyle(
                                                  fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Text(
                                'No messages yet. Say hello!',
                                style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              controller: _scrollController,
                              children: [
                                if (_sessions.isNotEmpty || _stats != null) ...[
                                  _buildSessionsSection(),
                                  const SizedBox(height: 16),
                                ],
                                ..._messages.map((msg) => Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: context.colors.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: context.colors.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                (msg['sender_name'] ?? msg['sender'] ?? 'Unknown') as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: context.colors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                (msg['created_at'] ?? '') as String,
                                                style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            (msg['message'] ?? msg['content'] ?? '') as String,
                                            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        border: Border(top: BorderSide(color: context.colors.border)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: context.colors.primaryGlow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: _startSession,
                              icon: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primary, size: 22),
                              tooltip: 'Start Session',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: TextStyle(color: context.colors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(color: context.colors.textMuted),
                                filled: true,
                                fillColor: context.colors.surfaceHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: context.colors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: context.colors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.primary),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
