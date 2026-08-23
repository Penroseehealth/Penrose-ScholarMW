import 'package:flutter/material.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class ChinesePlacementTest extends StatefulWidget {
  ChinesePlacementTest({super.key});
  @override
  State<ChinesePlacementTest> createState() => _ChinesePlacementTestState();
}

class _ChinesePlacementTestState extends State<ChinesePlacementTest> {
  static const Color accent = Color(0xFF8B5CF6);
  static const Map<int,String> _tn = {1:'Beginner',2:'Elementary',3:'Intermediate',4:'Upper-Int.',5:'Advanced'};
  int _tier=1,_qi=0,_score=0,_cnt=0,_streak=0,_wrong=0,_sel=-1;
  bool _done=false,_ans=false;
  late List<Map<String,dynamic>> _pool;
  final Random _r = Random();

  static const List<Map<String,dynamic>> _qs = [
    {'tier':1,'type':'vocab',
     'q':'What does 大 mean?',
     'opts':['big', 'small', 'good', 'water'],
     'ans':0},
    {'tier':1,'type':'character',
     'q':'Which means person?',
     'opts':['人', '大', '天', '口'],
     'ans':0},
    {'tier':1,'type':'vocab',
     'q':'What is 你好?',
     'opts':['thank you', 'hello', 'goodbye', 'sorry'],
     'ans':1},
    {'tier':1,'type':'grammar',
     'q':'我 ___ 学生 (am)',
     'opts':['是', '有', '在', '要'],
     'ans':0},
    {'tier':1,'type':'sentence',
     'q':'Translate: 我爱你',
     'opts':['I love you', 'I see you', 'I ate', 'I go'],
     'ans':0},
    {'tier':2,'type':'vocab',
     'q':'每天 means:',
     'opts':['every day', 'every week', 'today', 'tomorrow'],
     'ans':0},
    {'tier':2,'type':'grammar',
     'q':'___ 他学习 (and)',
     'opts':['和', '但是', '因为', '所以'],
     'ans':0},
    {'tier':2,'type':'character',
     'q':'Which means want?',
     'opts':['想', '看', '做', '走'],
     'ans':0},
    {'tier':2,'type':'vocab',
     'q':'工作 means:',
     'opts':['work', 'study', 'rest', 'travel'],
     'ans':0},
    {'tier':2,'type':'sentence',
     'q':'我想喝咖啡 means:',
     'opts':['I want coffee', 'I want tea', 'I like coffee', 'I drink water'],
     'ans':0},
    {'tier':3,'type':'grammar',
     'q':'Completed action particle:',
     'opts':['了', '过', '着', '正在'],
     'ans':0},
    {'tier':3,'type':'vocab',
     'q':'经验 means:',
     'opts':['experience', 'experiment', 'expensive', 'example'],
     'ans':0},
    {'tier':3,'type':'grammar',
     'q':'虽然...但是 means:',
     'opts':['although...but', 'because...so', 'if...then', 'when...then'],
     'ans':0},
    {'tier':3,'type':'character',
     'q':'Which means important?',
     'opts':['重要', '简单', '复杂', '有趣'],
     'ans':0},
    {'tier':3,'type':'sentence',
     'q':'我已经学了两年中文了 means:',
     'opts':['Studied 2 years', 'Will study', 'Studied yesterday', 'Chinese is easy'],
     'ans':0},
    {'tier':4,'type':'grammar',
     'q':'把 sentence marks:',
     'opts':['disposal/result', 'questions', 'negation', 'comparisons'],
     'ans':0},
    {'tier':4,'type':'vocab',
     'q':'影响 means:',
     'opts':['influence', 'reflect', 'improve', 'increase'],
     'ans':0},
    {'tier':4,'type':'grammar',
     'q':'被 sentence marks:',
     'opts':['passive voice', 'active voice', 'questions', 'commands'],
     'ans':0},
    {'tier':4,'type':'vocab',
     'q':'竟然 means:',
     'opts':['unexpectedly', 'certainly', 'usually', 'sometimes'],
     'ans':0},
    {'tier':4,'type':'sentence',
     'q':'他把书放在桌子上了 means:',
     'opts':['He put book on table', 'He read book', 'He bought book', 'Book is new'],
     'ans':0},
    {'tier':5,'type':'vocab',
     'q':'尽管 means:',
     'opts':['even though', 'because', 'therefore', 'however'],
     'ans':0},
    {'tier':5,'type':'grammar',
     'q':'与其...不如 means:',
     'opts':['rather...than', 'not only...but', 'both...and', 'neither...nor'],
     'ans':0},
    {'tier':5,'type':'vocab',
     'q':'势必 means:',
     'opts':['inevitably', 'maybe', 'possibly', 'probably'],
     'ans':0},
    {'tier':5,'type':'grammar',
     'q':'Chengyu originate from:',
     'opts':['classical Chinese', 'modern slang', 'English loan', 'Cantonese'],
     'ans':0},
    {'tier':5,'type':'sentence',
     'q':'既然...就 means:',
     'opts':['since...then', 'if...then', 'when...then', 'because...so'],
     'ans':0},
  ];

  @override
  void initState() { super.initState(); _load(); }

  void _load() {
    _pool = _qs.where((q) => q['tier'] == _tier).toList()..shuffle(_r);
    _qi = 0;
  }

  void _pick(int i) {
    if (_ans) return;
    final ok = i == _pool[_qi]['ans'];
    setState(() {
      _sel = i; _ans = true; _cnt++;
      if (ok) { _score++; _streak++; _wrong = 0;
        if (_streak >= 3 && _tier < 5) { _tier++; _streak = 0; _load(); }
      } else { _streak = 0; _wrong++;
        if (_wrong >= 2 && _tier > 1) { _tier--; _wrong = 0; _load(); }
      }
      if (_qi >= _pool.length - 1) _done = true;
    });
  }

  void _next() {
    setState(() { _qi++; _ans = false; _sel = -1;
      if (_qi >= _pool.length) _done = true; });
  }

  void _reset() {
    setState(() { _tier=1; _qi=0; _score=0; _cnt=0;
      _streak=0; _wrong=0; _sel=-1; _ans=false; _done=false; _load(); });
  }

  String get _rec {
    final p = _cnt > 0 ? _score / _cnt : 0.0;
    if (p > 0.8) return 'HSK ${(_tier+1).clamp(1,6)}';
    if (p > 0.6) return 'HSK ${_tier.clamp(1,6)}';
    return 'HSK ${(_tier-1).clamp(1,6)}';
  }

  @override
  Widget build(BuildContext c) {
    if (_done) return _buildResult();
    final q = _pool[_qi];
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Placement Test'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
        actions: [Container(
          margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star_rounded, size: 16, color: accent), SizedBox(width: 6),
            Text('$_score/$_cnt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent))]))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _tierBadge(), SizedBox(height: 12), _progress(), SizedBox(height: 16),
          _qCard(q), SizedBox(height: 16), _opts(q), SizedBox(height: 16),
          if (_ans) ...[_feedback(q), SizedBox(height: 16), _nextBtn()]
        ])),
    );
  }

  Widget _tierBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text('Tier $_tier: ${_tn[_tier]??""}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)));
  }

  Widget _progress() {
    final pct = _pool.isNotEmpty ? (_qi + 1) / _pool.length : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Question ${_qi+1} of ${_pool.length}', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
        Text('${(_pool.isNotEmpty ? (_qi+1)*100~/_pool.length : 0)}%', style: TextStyle(fontSize: 12, color: context.colors.textMuted))]),
      SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
        value: pct, backgroundColor: context.colors.surfaceElevated, color: accent, minHeight: 6))]);
  }

  Widget _qCard(Map<String,dynamic> q) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.colors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Text('${(q['type'] as String).toUpperCase()}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent))),
        SizedBox(height: 12),
        Text(q['q'] as String, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
      ]));
  }

  Widget _opts(Map<String,dynamic> q) {
    final opts = q['opts'] as List;
    final ans = q['ans'] as int;
    return Column(children: List.generate(opts.length, (i) {
      final isCorrect = i == ans;
      final isSel = i == _sel;
      Color bg = AppColors.surfaceElevated;
      Color border = AppColors.border;
      if (_ans && isCorrect) { bg = context.colors.success.withValues(alpha: 0.15); border = context.colors.success; }
      else if (_ans && isSel && !isCorrect) { bg = context.colors.error.withValues(alpha: 0.15); border = context.colors.error; }
      return GestureDetector(
        onTap: () => _pick(i),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          child: Row(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(String.fromCharCode(65 + i), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)))),
            SizedBox(width: 12),
            Expanded(child: Text(opts[i] as String, style: TextStyle(fontSize: 14, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: context.colors.textPrimary))),
            if (_ans && isCorrect) Icon(Icons.check_circle_rounded, size: 18, color: context.colors.success),
            if (_ans && isSel && !isCorrect) Icon(Icons.cancel_rounded, size: 18, color: context.colors.error),
          ])));
    }));
  }

  Widget _feedback(Map<String,dynamic> q) {
    final ok = _sel == q['ans'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? context.colors.success.withValues(alpha: 0.1) : context.colors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ok ? context.colors.success.withValues(alpha: 0.3) : context.colors.error.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.info_rounded, size: 18, color: ok ? context.colors.success : context.colors.error),
        SizedBox(width: 10),
        Expanded(child: Text(ok ? 'Correct!' : 'Wrong!', style: TextStyle(fontWeight: FontWeight.w700, color: ok ? context.colors.success : context.colors.error)))
      ]));
  }

  Widget _nextBtn() {
    return GestureDetector(
      onTap: _next,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text('Next Question', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)))));
  }

  Widget _buildResult() {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Results'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, size: 64, color: accent),
              SizedBox(height: 16),
              Text('Test Complete!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
              SizedBox(height: 8),
              Text('$_score / $_cnt correct',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: accent)),
              SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(children: [
                  Text('Recommended Level',
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                  SizedBox(height: 8),
                  Text(_rec,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: accent)),
                ]),
              ),
              SizedBox(height: 24),
              GestureDetector(
                onTap: _reset,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, size: 18, color: accent),
                      SizedBox(width: 8),
                      Text('Retake Test',
                        style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}