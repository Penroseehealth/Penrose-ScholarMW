import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../core/theme/theme_colors.dart';

String _timeAgo(dynamic timestamp) {
  if (timestamp == null) return '';
  final dt = DateTime.tryParse(timestamp.toString());
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}

class ForumScreen extends StatefulWidget {
  ForumScreen({super.key});
  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen>
    with SingleTickerProviderStateMixin {
  final StemService _svc = StemService();
  late TabController _tab;
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _posts = [];
  List<dynamic> _subjects = [];
  bool _loading = true;
  String? _error;
  String _sort = 'newest';
  String _selectedSubject = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sub = await _svc.getSubjects();
      final posts = await _svc.getForumPosts(
        subjectSlug: _selectedSubject.isNotEmpty ? _selectedSubject : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        sort: _sort,
      );
      if (mounted) {
        setState(() {
          _subjects = sub;
          _posts = posts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<dynamic> _filtered() => _posts.where((p) {
    if (_tab.index == 1) return (p['answer_count'] ?? 0) == 0 && p['resolved'] != true;
    if (_tab.index == 2) return p['is_my_post'] == true || p['my_post'] == true;
    return true;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        backgroundColor: context.colors.surface,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            _buildSearch(),
            _buildSortBar(),
            _buildTabs(),
            if (_loading)
              SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ))
            else if (_error != null)
              SliverToBoxAdapter(child: ErrorState(message: 'Failed to load posts', onRetry: _load))
            else if (filtered.isEmpty)
              SliverToBoxAdapter(child: EmptyState(
                icon: Icons.forum_rounded,
                title: 'No questions found',
                subtitle: 'Be the first to ask a question',
                buttonText: 'Ask Question',
                onButtonPressed: _showCreateSheet,
              ))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _postCard(filtered[i]),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSheet,
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  SliverAppBar _buildAppBar() => SliverAppBar(
    expandedHeight: 90, pinned: true,
    backgroundColor: AppColors.primaryDark,
    leading: IconButton(
      icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
      onPressed: () => context.go('/'),
    ),
    flexibleSpace: FlexibleSpaceBar(
      title: Text('Q&A Forum', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),
    ),
  );

  SliverToBoxAdapter _buildSearch() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(color: context.colors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search questions...',
          prefixIcon: Icon(Icons.search_rounded, color: context.colors.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: context.colors.textMuted, size: 18),
                onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); _load(); },
              )
            : null,
        ),
        onSubmitted: (v) { setState(() => _searchQuery = v); _load(); },
      ),
    ),
  );

  SliverToBoxAdapter _buildSortBar() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          _sortChip('newest', 'Newest'),
          SizedBox(width: 6),
          _sortChip('votes', 'Most Voted'),
          SizedBox(width: 6),
          _sortChip('unanswered', 'Unanswered'),
          Spacer(),
          if (_subjects.isNotEmpty)
            SizedBox(
              height: 32,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSubject.isNotEmpty ? _selectedSubject : null,
                  hint: Text('All Subjects', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                  dropdownColor: context.colors.surfaceElevated,
                  isDense: true,
                  items: [
                    DropdownMenuItem(value: '', child: Text('All Subjects', style: TextStyle(color: context.colors.textPrimary, fontSize: 13))),
                    ..._subjects.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                      value: s['slug'] ?? '',
                      child: Text(s['name'] ?? '', style: TextStyle(color: context.colors.textPrimary, fontSize: 13)),
                    )),
                  ],
                  onChanged: (v) { setState(() => _selectedSubject = v ?? ''); _load(); },
                ),
              ),
            ),
        ],
      ),
    ),
  );

  SliverToBoxAdapter _buildTabs() => SliverToBoxAdapter(
    child: SizedBox(
      height: 44,
      child: TabBar(
        controller: _tab,
        onTap: (_) => setState(() {}),
        labelColor: AppColors.primary,
        unselectedLabelColor: context.colors.textMuted,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: context.colors.border,
        tabs: [Tab(text: 'All Questions'), Tab(text: 'Unanswered'), Tab(text: 'My Posts')],
      ),
    ),
  );

  Widget _sortChip(String value, String label) {
    final sel = _sort == value;
    return GestureDetector(
      onTap: () { setState(() => _sort = value); _load(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? context.colors.primaryGlow : context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppColors.primary.withValues(alpha: 0.4) : context.colors.border),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
          color: sel ? AppColors.primary : context.colors.textMuted,
        )),
      ),
    );
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(subjects: _subjects, onCreated: () { Navigator.of(context).pop(); _load(); }),
    );
  }

  void _openDetail(Map<String, dynamic> post) async {
    final r = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PostDetailScreen(postId: post['id'])));
    if (r == true) _load();
  }

  Widget _postCard(Map<String, dynamic> post) {
    final title = post['title'] ?? '';
    final body = (post['body'] ?? '').toString();
    final excerpt = body.length > 120 ? '${body.substring(0, 120)}...' : body;
    final votes = post['vote_count'] ?? post['votes'] ?? 0;
    final answers = post['answer_count'] ?? post['answers'] ?? 0;
    final resolved = post['resolved'] == true;
    final subject = post['subject_name'] ?? post['subject'] ?? '';
    final author = post['author_name'] ?? post['author'] ?? 'Unknown';
    final ago = _timeAgo(post['created_at']);

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(post),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: context.colors.border)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 54,
                decoration: BoxDecoration(color: context.colors.surfaceHighest, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: votes > 0 ? context.colors.success : context.colors.textMuted),
                    Text('$votes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: votes > 0 ? context.colors.textPrimary : context.colors.textMuted)),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(title.toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.colors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      if (resolved) ...[SizedBox(width: 6), Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: context.colors.successMuted, borderRadius: BorderRadius.circular(6)),
                        child: Text('Resolved', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.colors.success)),
                      )],
                    ]),
                    SizedBox(height: 4),
                    Text(excerpt, style: TextStyle(fontSize: 13, color: context.colors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 8),
                    Row(children: [
                      if (subject.toString().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: context.colors.infoMuted, borderRadius: BorderRadius.circular(6)),
                          child: Text(subject.toString(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.info)),
                        ),
                        SizedBox(width: 8),
                      ],
                      Icon(Icons.chat_bubble_outline_rounded, size: 14, color: context.colors.textMuted),
                      SizedBox(width: 4),
                      Text('$answers', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                      Spacer(),
                      Text('$author \u00b7 $ago', style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                    ]),
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

class _PostDetailScreen extends StatefulWidget {
  final int postId;
  const _PostDetailScreen({required this.postId});
  @override
  State<_PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<_PostDetailScreen> {
  final StemService _svc = StemService();
  final TextEditingController _answerCtrl = TextEditingController();
  Map<String, dynamic> _post = {};
  List<dynamic> _answers = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _answerCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final p = await _svc.getForumPost(widget.postId);
      if (mounted) setState(() { _post = p; _answers = p['answers'] ?? []; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _submitAnswer() async {
    final t = _answerCtrl.text.trim();
    if (t.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try { await _svc.createForumAnswer(widget.postId, t); _answerCtrl.clear(); await _load(); } catch (_) {}
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _votePost(int v) async { try { await _svc.voteForumPost(widget.postId, v); await _load(); } catch (_) {} }
  Future<void> _voteAnswer(int id, int v) async { try { await _svc.voteForumAnswer(id, v); await _load(); } catch (_) {} }
  Future<void> _acceptAnswer(int id) async { try { await _svc.acceptForumAnswer(id); await _load(); } catch (_) {} }
  Future<void> _resolvePost() async { try { await _svc.resolveForumPost(widget.postId); await _load(); } catch (_) {} }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colors.textSecondary),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Text('Question', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
        actions: [
          if (_post['resolved'] != true)
            TextButton(onPressed: _resolvePost, child: Text('Mark Resolved', style: TextStyle(color: context.colors.success, fontWeight: FontWeight.w600))),
        ],
      ),
      body: _loading
        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
        : Column(children: [
            Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
              _buildPost(),
              SizedBox(height: 20),
              Text('${_answers.length} ${_answers.length == 1 ? 'Answer' : 'Answers'}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              SizedBox(height: 12),
              ..._answers.map((a) => _buildAnswer(a)),
            ])),
            _buildInputBar(),
          ]),
    );
  }

  Widget _buildPost() {
    final title = _post['title'] ?? '';
    final body = _post['body'] ?? '';
    final votes = _post['vote_count'] ?? _post['votes'] ?? 0;
    final author = _post['author_name'] ?? _post['author'] ?? 'Unknown';
    final ago = _timeAgo(_post['created_at']);
    final subject = _post['subject_name'] ?? _post['subject'] ?? '';
    final resolved = _post['resolved'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.colors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          GestureDetector(onTap: () => _votePost(1), child: Icon(Icons.keyboard_arrow_up_rounded, size: 28, color: context.colors.textMuted)),
          Text('$votes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
          GestureDetector(onTap: () => _votePost(-1), child: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: context.colors.textMuted)),
        ]),
        SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title.toString(), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.colors.textPrimary))),
            if (resolved) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: context.colors.successMuted, borderRadius: BorderRadius.circular(8)),
              child: Text('Resolved', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.success)),
            ),
          ]),
          SizedBox(height: 8),
          Text(body.toString(), style: TextStyle(fontSize: 14, color: context.colors.textSecondary, height: 1.5)),
          SizedBox(height: 12),
          Row(children: [
            if (subject.toString().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: context.colors.infoMuted, borderRadius: BorderRadius.circular(6)),
                child: Text(subject.toString(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.info)),
              ),
              SizedBox(width: 8),
            ],
            Text('$author \u00b7 $ago', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
          ]),
        ])),
      ]),
    );
  }

  Widget _buildAnswer(Map<String, dynamic> answer) {
    final body = answer['body'] ?? '';
    final votes = answer['vote_count'] ?? answer['votes'] ?? 0;
    final author = answer['author_name'] ?? answer['author'] ?? 'Unknown';
    final ago = _timeAgo(answer['created_at']);
    final accepted = answer['accepted'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accepted ? context.colors.success.withValues(alpha: 0.4) : context.colors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          GestureDetector(onTap: () => _voteAnswer(answer['id'], 1), child: Icon(Icons.keyboard_arrow_up_rounded, size: 24, color: context.colors.textMuted)),
          Text('$votes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
          GestureDetector(onTap: () => _voteAnswer(answer['id'], -1), child: Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: context.colors.textMuted)),
          if (!accepted) ...[SizedBox(height: 4),
            GestureDetector(onTap: () => _acceptAnswer(answer['id']), child: Icon(Icons.check_circle_outline_rounded, size: 22, color: context.colors.textMuted)),
          ],
        ]),
        SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (accepted) Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: context.colors.successMuted, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, size: 12, color: context.colors.success),
              SizedBox(width: 4),
              Text('Accepted Answer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.success)),
            ]),
          ),
          Text(body.toString(), style: TextStyle(fontSize: 14, color: context.colors.textSecondary, height: 1.5)),
          SizedBox(height: 10),
          Text('$author \u00b7 $ago', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
        ])),
      ]),
    );
  }

  Widget _buildInputBar() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    decoration: BoxDecoration(color: context.colors.surface, border: Border(top: BorderSide(color: context.colors.border))),
    child: SafeArea(
      top: false,
      child: Row(children: [
        Expanded(child: Container(
          decoration: BoxDecoration(color: context.colors.surfaceHighest, borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: _answerCtrl,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
            maxLines: null,
            decoration: InputDecoration(hintText: 'Write an answer...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          ),
        )),
        SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: IconButton(
            onPressed: _submitting ? null : _submitAnswer,
            icon: _submitting
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]),
    ),
  );
}

class _CreatePostSheet extends StatefulWidget {
  final List<dynamic> subjects;
  final VoidCallback onCreated;
  const _CreatePostSheet({required this.subjects, required this.onCreated});
  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final StemService _svc = StemService();
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String? _selectedSubject;
  bool _submitting = false;

  @override
  void dispose() { _titleCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _svc.createForumPost(_titleCtrl.text.trim(), _bodyCtrl.text.trim(), subjectSlug: _selectedSubject);
      widget.onCreated();
    } catch (_) {}
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Ask a Question', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.colors.textPrimary))),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close_rounded, color: context.colors.textMuted)),
              ]),
              SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(hintText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _bodyCtrl,
                style: TextStyle(color: context.colors.textPrimary),
                maxLines: 5,
                decoration: InputDecoration(hintText: 'Describe your question...', alignLabelWithHint: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: 12),
              if (widget.subjects.isNotEmpty)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSubject,
                    hint: Text('Select subject (optional)', style: TextStyle(color: context.colors.textMuted, fontSize: 14)),
                    dropdownColor: context.colors.surfaceHighest,
                    isExpanded: true,
                    items: widget.subjects.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                      value: s['slug'] ?? '',
                      child: Text(s['name'] ?? '', style: TextStyle(color: context.colors.textPrimary, fontSize: 14)),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedSubject = v),
                  ),
                ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Post Question', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
