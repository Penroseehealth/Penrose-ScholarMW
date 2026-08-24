import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final StemService _svc = StemService();
  List<dynamic> _announcements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getAnnouncements();
      if (mounted)
        setState(() {
          _announcements = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'urgent':
        return context.colors.error;
      case 'high':
        return context.colors.warning;
      case 'normal':
        return context.colors.info;
      case 'low':
        return context.colors.textMuted;
      default:
        return context.colors.info;
    }
  }

  Color _priorityMuted(String? priority) {
    switch (priority) {
      case 'urgent':
        return context.colors.errorMuted;
      case 'high':
        return context.colors.warningMuted;
      case 'normal':
        return context.colors.infoMuted;
      case 'low':
        return context.colors.surfaceHighest;
      default:
        return context.colors.infoMuted;
    }
  }

  void _showDetail(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AnnouncementDetail(announcement: a),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          backgroundColor: context.colors.surface,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 90,
                pinned: true,
                backgroundColor: AppColors.primaryDark,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => context.go('/'),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text('Announcements',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                    ),
                  ),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                    child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ))
              else if (_error != null)
                SliverToBoxAdapter(child: ErrorState(message: 'Failed to load announcements', onRetry: _load))
              else if (_announcements.isEmpty)
                const SliverToBoxAdapter(
                    child: EmptyState(
                  icon: Icons.campaign_rounded,
                  title: 'No announcements',
                  subtitle: 'There are no announcements at this time',
                ))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  sliver: SliverList.separated(
                    itemCount: _announcements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _card(_announcements[i] as Map<String, dynamic>),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _card(Map<String, dynamic> a) {
    final title = a['title'] ?? '';
    final body = (a['body'] ?? a['content'] ?? '').toString();
    final excerpt = body.length > 140 ? '${body.substring(0, 140)}...' : body;
    final priority = a['priority'] ?? 'normal';
    final subject = a['subject_name'] ?? a['subject'] ?? '';
    final pinned = a['pinned'] == true;
    final author = a['author_name'] ?? a['author'] ?? '';
    final ago = _timeAgo(a['created_at']);

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(a),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _priorityColor(priority.toString()).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration:
                      BoxDecoration(color: _priorityMuted(priority.toString()), borderRadius: BorderRadius.circular(6)),
                  child: Text(priority.toString().toUpperCase(),
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _priorityColor(priority.toString()))),
                ),
                if (pinned) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.push_pin_rounded, size: 14, color: context.colors.warning),
                ],
                if (subject.toString().isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: context.colors.infoMuted, borderRadius: BorderRadius.circular(6)),
                    child: Text(subject.toString(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.info)),
                  ),
                ],
              ]),
              const SizedBox(height: 10),
              Text(title.toString(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 6),
              Text(excerpt,
                  style: TextStyle(fontSize: 13, color: context.colors.textMuted, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Row(children: [
                if (author.toString().isNotEmpty)
                  Text(author.toString(), style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                if (author.toString().isNotEmpty && ago.isNotEmpty)
                  Text(' \u00b7 ', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                if (ago.isNotEmpty) Text(ago, style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textMuted),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementDetail extends StatelessWidget {
  final Map<String, dynamic> announcement;
  const _AnnouncementDetail({required this.announcement});

  Color _priorityColor(String? p) {
    switch (p) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'normal':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }

  Color _priorityMuted(String? p) {
    switch (p) {
      case 'urgent':
        return AppColors.errorMuted;
      case 'high':
        return AppColors.warningMuted;
      case 'normal':
        return AppColors.infoMuted;
      default:
        return AppColors.surfaceHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = announcement['title'] ?? '';
    final body = announcement['body'] ?? announcement['content'] ?? '';
    final priority = announcement['priority'] ?? 'normal';
    final subject = announcement['subject_name'] ?? announcement['subject'] ?? '';
    final pinned = announcement['pinned'] == true;
    final author = announcement['author_name'] ?? announcement['author'] ?? '';
    final created = announcement['created_at'] ?? '';

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration:
                    BoxDecoration(color: _priorityMuted(priority.toString()), borderRadius: BorderRadius.circular(6)),
                child: Text(priority.toString().toUpperCase(),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _priorityColor(priority.toString()))),
              ),
              if (pinned) ...[
                const SizedBox(width: 6),
                Icon(Icons.push_pin_rounded, size: 14, color: context.colors.warning),
              ],
              if (subject.toString().isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: context.colors.infoMuted, borderRadius: BorderRadius.circular(6)),
                  child: Text(subject.toString(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.info)),
                ),
              ],
            ]),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Text(title.toString(),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                const SizedBox(height: 12),
                if (author.toString().isNotEmpty || created.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${author.toString().isNotEmpty ? author : ''}${author.toString().isNotEmpty && created.toString().isNotEmpty ? ' \u00b7 ' : ''}${created.toString().isNotEmpty ? created : ''}',
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                    ),
                  ),
                Text(body.toString(), style: TextStyle(fontSize: 14, color: context.colors.textSecondary, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
