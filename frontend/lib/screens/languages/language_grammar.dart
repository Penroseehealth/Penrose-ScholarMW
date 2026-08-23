import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';
import '../../core/theme/theme_colors.dart';

class LanguageGrammar extends StatefulWidget {
  LanguageGrammar({super.key});

  @override
  State<LanguageGrammar> createState() => _LanguageGrammarState();
}

class _LanguageGrammarState extends State<LanguageGrammar> {
  String? _slug;
  bool _loading = true;
  List<dynamic> _rules = [];
  List<dynamic> _categories = [];
  String? _selectedCategory;
  int? _expandedIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final slug = GoRouterState.of(context).pathParameters['slug'];
    if (slug != _slug) {
      _slug = slug;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_slug == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        LanguageService().getGrammar(_slug!),
        LanguageService().getGrammarCategories(_slug!),
      ]);
      if (mounted) {
        setState(() {
          _rules = results[0] as List<dynamic>? ?? [];
          _categories = results[1] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filteredRules {
    if (_selectedCategory == null) return _rules;
    return _rules.where((r) => r['rule_category'] == _selectedCategory).toList();
  }

  Color _difficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'beginner':
        return context.colors.success;
      case 'intermediate':
        return context.colors.warning;
      case 'advanced':
        return Color(0xFFEF4444);
      default:
        return context.colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryChips(),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredRules.isEmpty
                      ? _buildEmpty()
                      : _buildRulesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios, color: context.colors.textPrimary, size: 20),
          ),
          Icon(Icons.rule, color: AppColors.primary, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text('Grammar', style: TextStyle(
              color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
            )),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${_rules.length} rules', style: TextStyle(
              color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _catChip(null, 'All'),
          ..._categories.map((c) => _catChip(
            c['category']?.toString(), c['category']?.toString() ?? '',
          )),
        ],
      ),
    );
  }

  Widget _catChip(String? cat, String label) {
    final selected = _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = cat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : context.colors.surfaceHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : context.colors.divider),
          ),
          child: Text(label, style: TextStyle(
            color: selected ? Colors.white : context.colors.textSecondary,
            fontSize: 12, fontWeight: FontWeight.w500,
          )),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rule_outlined, size: 48, color: context.colors.textSecondary.withValues(alpha: 0.4)),
          SizedBox(height: 12),
          Text('No grammar rules found', style: TextStyle(
            color: context.colors.textSecondary.withValues(alpha: 0.6), fontSize: 14,
          )),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredRules.length,
        itemBuilder: (ctx, i) => _ruleCard(_filteredRules[i], i),
      ),
    );
  }

  Widget _ruleCard(dynamic rule, int index) {
    final expanded = _expandedIndex == index;
    final name = rule['rule_name'] ?? '';
    final category = rule['rule_category'] ?? '';
    final explanation = rule['explanation'] ?? '';
    final examples = rule['examples'];
    final contrast = rule['contrast'] ?? '';
    final difficulty = rule['difficulty'] ?? 'beginner';

    return GestureDetector(
      onTap: () => setState(() => _expandedIndex = expanded ? null : index),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: expanded ? AppColors.primary.withValues(alpha: 0.4) : context.colors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: TextStyle(
                    color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold,
                  )),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _difficultyColor(difficulty.toString()).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(difficulty.toString(), style: TextStyle(
                    color: _difficultyColor(difficulty.toString()),
                    fontSize: 11, fontWeight: FontWeight.w600,
                  )),
                ),
                SizedBox(width: 6),
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: context.colors.textSecondary, size: 20,
                ),
              ],
            ),
            if (category.toString().isNotEmpty) ...[
              SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(category.toString(), style: TextStyle(
                  color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500,
                )),
              ),
            ],
            if (expanded) ...[
              Divider(color: context.colors.divider, height: 16),
              Text(explanation.toString(), style: TextStyle(
                color: context.colors.textSecondary, fontSize: 14, height: 1.5,
              )),
              if (examples != null) ...[
                SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    examples is List ? examples.join('\n') : examples.toString(),
                    style: TextStyle(
                      color: context.colors.textPrimary, fontSize: 13, fontFamily: 'monospace', height: 1.6,
                    ),
                  ),
                ),
              ],
              if (contrast.toString().isNotEmpty) ...[
                SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.warning.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Compare:', style: TextStyle(
                        color: context.colors.warning.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600,
                      )),
                      SizedBox(height: 4),
                      Text(contrast.toString(), style: TextStyle(
                        color: context.colors.textPrimary, fontSize: 13,
                      )),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
