import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/stem_service.dart';

class StemConceptScreen extends StatefulWidget {
  final int conceptId;
  final String title;

  const StemConceptScreen({
    super.key,
    required this.conceptId,
    required this.title,
  });

  @override
  State<StemConceptScreen> createState() => _StemConceptScreenState();
}

class _StemConceptScreenState extends State<StemConceptScreen> with SingleTickerProviderStateMixin {
  final StemService _stemService = StemService();
  late TabController _tabController;

  List<dynamic> _materials = [];
  List<dynamic> _objectives = [];
  List<dynamic> _practices = [];

  bool _loadingMaterials = true;
  bool _loadingObjectives = true;
  bool _loadingPractices = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _loadTabData(_tabController.index);
    });
    _loadTabData(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTabData(int index) async {
    switch (index) {
      case 0:
        if (_materials.isEmpty && _loadingMaterials) {
          final materials = await _stemService.getMaterials(widget.conceptId);
          if (mounted) {
            setState(() {
              _materials = materials;
              _loadingMaterials = false;
            });
          }
        }
        break;
      case 1:
        if (_objectives.isEmpty && _loadingObjectives) {
          final objectives = await _stemService.getObjectives(widget.conceptId);
          if (mounted) {
            setState(() {
              _objectives = objectives;
              _loadingObjectives = false;
            });
          }
        }
        break;
      case 2:
        if (_practices.isEmpty && _loadingPractices) {
          final practices = await _stemService.getPractices(widget.conceptId);
          if (mounted) {
            setState(() {
              _practices = practices;
              _loadingPractices = false;
            });
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.surface,
          elevation: 0,
          title: Text(
            widget.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Container(
              color: context.colors.surface,
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: context.colors.textMuted,
                    indicatorColor: AppColors.primary,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(text: 'Learn'),
                      Tab(text: 'Objectives'),
                      Tab(text: 'Practice'),
                    ],
                  ),
                  Container(color: context.colors.border, height: 1),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildLearnTab(),
            _buildObjectivesTab(),
            _buildPracticeTab(),
          ],
        ),
      );

  Widget _buildLearnTab() {
    if (_loadingMaterials) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_materials.isEmpty) {
      return _buildEmptyTab('No learning materials', 'Materials will appear here');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _materials.length,
      itemBuilder: (context, index) => _buildMaterialCard(_materials[index]),
    );
  }

  Widget _buildObjectivesTab() {
    if (_loadingObjectives) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_objectives.isEmpty) {
      return _buildEmptyTab('No objectives', 'Objectives will appear here');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _objectives.length,
      itemBuilder: (context, index) => _buildObjectiveCard(_objectives[index]),
    );
  }

  Widget _buildPracticeTab() {
    if (_loadingPractices) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_practices.isEmpty) {
      return _buildEmptyTab('No practice questions', 'Questions will appear here');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _practices.length,
      itemBuilder: (context, index) => _PracticeQuestionCard(
        question: _practices[index],
        index: index,
        stemService: _stemService,
        conceptId: widget.conceptId,
      ),
    );
  }

  Widget _buildMaterialCard(dynamic material) {
    IconData icon;
    switch (material['material_type']) {
      case 'video':
        icon = Icons.play_circle_outline_rounded;
        break;
      case 'article':
        icon = Icons.article_outlined;
        break;
      case 'interactive':
        icon = Icons.touch_app_outlined;
        break;
      case 'diagram':
        icon = Icons.analytics_outlined;
        break;
      default:
        icon = Icons.menu_book_outlined;
    }

    return _ExpandableMaterialCard(
      material: material,
      icon: icon,
    );
  }

  Widget _buildObjectiveCard(dynamic objective) {
    final bloomLevel = (objective['bloom_level'] ?? '') as String;
    final bloomColor = _getBloomColor(bloomLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bloomColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bloomLevel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: bloomColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (objective['title'] ?? '') as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (objective['description'] != null && (objective['description'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              objective['description'] as String,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBloomColor(String level) {
    switch (level.toLowerCase()) {
      case 'remember':
        return context.colors.info;
      case 'understand':
        return context.colors.teal;
      case 'apply':
        return context.colors.success;
      case 'analyze':
        return context.colors.warning;
      case 'evaluate':
        return AppColors.primary;
      case 'create':
        return context.colors.error;
      default:
        return context.colors.textMuted;
    }
  }

  Widget _buildEmptyTab(String title, String subtitle) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 44, color: context.colors.textMuted.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: context.colors.textMuted),
              ),
            ],
          ),
        ),
      );
}

class _ExpandableMaterialCard extends StatefulWidget {
  final dynamic material;
  final IconData icon;

  const _ExpandableMaterialCard({
    required this.material,
    required this.icon,
  });

  @override
  State<_ExpandableMaterialCard> createState() => _ExpandableMaterialCardState();
}

class _ExpandableMaterialCardState extends State<_ExpandableMaterialCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.colors.primaryGlow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (widget.material['title'] ?? '') as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (widget.material['material_type'] ?? 'text') as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: context.colors.textMuted,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              Divider(height: 1, color: context.colors.border),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  (widget.material['content'] ?? '') as String,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _PracticeQuestionCard extends StatefulWidget {
  final dynamic question;
  final int index;
  final StemService stemService;
  final int conceptId;

  const _PracticeQuestionCard({
    required this.question,
    required this.index,
    required this.stemService,
    required this.conceptId,
  });

  @override
  State<_PracticeQuestionCard> createState() => _PracticeQuestionCardState();
}

class _PracticeQuestionCardState extends State<_PracticeQuestionCard> {
  String? _selectedOption;
  final TextEditingController _answerController = TextEditingController();
  bool _answerRevealed = false;
  bool _masterySubmitted = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  bool get _isCorrect {
    if (widget.question['question_type'] == 'mcq') {
      return _selectedOption == widget.question['correct_answer'];
    }
    final answer = _answerController.text.trim().toLowerCase();
    final correct = (widget.question['correct_answer'] ?? '').toString().trim().toLowerCase();
    return answer == correct;
  }

  Future<void> _checkAnswer() async {
    setState(() => _answerRevealed = true);
  }

  Future<void> _submitMastery(bool correct) async {
    await widget.stemService.submitMastery(widget.conceptId, correct);
    if (mounted) {
      setState(() => _masterySubmitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionType = widget.question['question_type'] ?? 'mcq';
    final isMCQ = questionType == 'mcq';
    final options = isMCQ ? (widget.question['options'] as List<dynamic>?) ?? [] : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _answerRevealed
              ? (_isCorrect
                  ? context.colors.success.withValues(alpha: 0.3)
                  : context.colors.error.withValues(alpha: 0.3))
              : context.colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: context.colors.primaryGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (widget.question['title'] ?? '') as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (widget.question['question_text'] ?? '') as String,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          if (isMCQ)
            ...List.generate(options.length, (i) {
              final option = options[i] as String;
              final isSelected = _selectedOption == option;
              return GestureDetector(
                onTap: _answerRevealed
                    ? null
                    : () {
                        setState(() => _selectedOption = option);
                      },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : context.colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : context.colors.textMuted,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? context.colors.textPrimary : context.colors.textSecondary,
                          ),
                        ),
                      ),
                      if (_answerRevealed && option == widget.question['correct_answer'])
                        Icon(Icons.check_circle_rounded, color: context.colors.success, size: 18),
                      if (_answerRevealed && isSelected && option != widget.question['correct_answer'])
                        Icon(Icons.cancel_rounded, color: context.colors.error, size: 18),
                    ],
                  ),
                ),
              );
            })
          else
            TextField(
              controller: _answerController,
              enabled: !_answerRevealed,
              style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: TextStyle(color: context.colors.textMuted),
                filled: true,
                fillColor: context.colors.surfaceElevated,
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
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.colors.border),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (!_answerRevealed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (isMCQ ? _selectedOption != null : _answerController.text.trim().isNotEmpty) ? _checkAnswer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  disabledBackgroundColor: context.colors.surfaceHighest,
                  disabledForegroundColor: context.colors.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'Check Answer',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (_answerRevealed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isCorrect ? context.colors.successMuted : context.colors.errorMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _isCorrect ? context.colors.success : context.colors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isCorrect ? 'Correct!' : 'Incorrect',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isCorrect ? context.colors.success : context.colors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.question['explanation'] != null && (widget.question['explanation'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.infoMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.question['explanation'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (!_masterySubmitted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _submitMastery(true),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Got it right'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.success,
                        side: BorderSide(color: context.colors.success.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _submitMastery(false),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Got it wrong'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.error,
                        side: BorderSide(color: context.colors.error.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_masterySubmitted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Mastery recorded',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
