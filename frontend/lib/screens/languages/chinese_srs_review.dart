import 'package:flutter/material.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class ChineseSrsReview extends StatefulWidget {
  ChineseSrsReview({super.key});
  @override
  State<ChineseSrsReview> createState() => _ChineseSrsReviewState();
}

class _ChineseSrsReviewState extends State<ChineseSrsReview> {
  static const Color accent = Color(0xFF10B981);
  late List<Map<String,dynamic>> _deck;
  int _idx = 0, _reviewed = 0, _mastered = 0;
  bool _flipped = false;
  final Random _r = Random();

  static const List<Map<String,dynamic>> _all = [
    {'word':'大','pinyin':'dà','meaning':'big',
     'example':'今天很大','exTrans':'Today is big','level':1},
    {'word':'你好','pinyin':'nǐ hǎo','meaning':'hello',
     'example':'你好吗','exTrans':'How are you','level':1},
    {'word':'水','pinyin':'shuǐ','meaning':'water',
     'example':'我想喝水','exTrans':'I want water','level':2},
    {'word':'人','pinyin':'rén','meaning':'person',
     'example':'这个人','exTrans':'This person','level':2},
    {'word':'是','pinyin':'shì','meaning':'is',
     'example':'他是学生','exTrans':'He is a student','level':2},
    {'word':'我','pinyin':'wǒ','meaning':'I/me',
     'example':'我是中国人','exTrans':'I am Chinese','level':3},
    {'word':'好','pinyin':'hǎo','meaning':'good',
     'example':'很好','exTrans':'Very good','level':3},
    {'word':'去','pinyin':'qù','meaning':'go',
     'example':'我去学校','exTrans':'I go to school','level':3},
    {'word':'学','pinyin':'xué','meaning':'study',
     'example':'我学中文','exTrans':'I study Chinese','level':4},
    {'word':'喜欢','pinyin':'xǐhuān','meaning':'like',
     'example':'我喜欢你','exTrans':'I like you','level':4},
    {'word':'中国','pinyin':'zhōngguó','meaning':'China',
     'example':'我爱中国','exTrans':'I love China','level':4},
    {'word':'时间','pinyin':'shíjiān','meaning':'time',
     'example':'什么时间','exTrans':'What time','level':4},
    {'word':'工作','pinyin':'gōngzuò','meaning':'work',
     'example':'努力工作','exTrans':'Work hard','level':5},
    {'word':'学习','pinyin':'xuéxí','meaning':'learn',
     'example':'学习汉语','exTrans':'Learn Chinese','level':5},
    {'word':'朋友','pinyin':'péngyou','meaning':'friend',
     'example':'我的朋友','exTrans':'My friend','level':5},
    {'word':'电影','pinyin':'diànyǐng','meaning':'movie',
     'example':'看电影','exTrans':'Watch movie','level':3},
    {'word':'老师','pinyin':'lǎoshī','meaning':'teacher',
     'example':'李老师','exTrans':'Teacher Li','level':2},
    {'word':'学生','pinyin':'xuéshēng','meaning':'student',
     'example':'我是学生','exTrans':'I am a student','level':1},
    {'word':'喝','pinyin':'hē','meaning':'drink',
     'example':'喝茶','exTrans':'Drink tea','level':3},
    {'word':'吃','pinyin':'chī','meaning':'eat',
     'example':'吃饭','exTrans':'Have a meal','level':2},
  ];

  @override
  void initState() { super.initState(); _shuffle(); }

  void _shuffle() {
    _deck = List<Map<String,dynamic>>.from(_all)..shuffle(_r);
    _idx = 0; _reviewed = 0; _mastered = 0; _flipped = false;
  }

  void _rate(int delta) {
    final card = _deck[_idx];
    final newLevel = ((card['level'] as int) + delta).clamp(1, 5);
    card['level'] = newLevel;
    if (newLevel >= 5) _mastered++;
    _reviewed++;
    if (_idx < _deck.length - 1) {
      setState(() { _idx++; _flipped = false; });
    } else {
      setState(() { _flipped = false; });
    }
  }

  bool get _complete => _idx >= _deck.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('SRS Review'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
        actions: [Container(
          margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.style_rounded, size: 16, color: accent), SizedBox(width: 6),
            Text('${_deck.length - _idx} left', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent))]))]),
      body: _complete ? _buildComplete() : _buildCard(),
    );
  }

  Widget _buildCard() {
    final c = _deck[_idx];
    final lv = c['level'] as int;
    final pct = _deck.isNotEmpty ? _reviewed / _deck.length : 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Card ${_idx+1} of ${_deck.length}',
            style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
          Row(children: [
            Text('Mastered: $_mastered',
              style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
          ]),
        ]),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: context.colors.surfaceElevated,
            color: accent,
            minHeight: 4,
          ),
        ),
        SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() { _flipped = !_flipped; }),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 280),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _flipped ? accent.withValues(alpha: 0.08) : context.colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _flipped ? accent.withValues(alpha: 0.3) : context.colors.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_flipped) ...[
                  Text(c['word'] as String,
                    style: TextStyle(fontSize: 72, fontWeight: FontWeight.w400, color: context.colors.textPrimary)),
                  SizedBox(height: 12),
                  Text(c['pinyin'] as String,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
                  SizedBox(height: 8),
                  _levelBadge(lv),
                  SizedBox(height: 16),
                  Text('Tap to reveal',
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted.withValues(alpha: 0.6))),
                ] else ...[
                  Text(c['meaning'] as String,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                  SizedBox(height: 16),
                  Text(c['example'] as String,
                    style: TextStyle(fontSize: 20, color: context.colors.textSecondary)),
                  SizedBox(height: 4),
                  Text(c['exTrans'] as String,
                    style: TextStyle(fontSize: 14, color: context.colors.textMuted)),
                  SizedBox(height: 12),
                  _levelBadge(lv),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        Text('Tap card to flip',
          style: TextStyle(fontSize: 12, color: context.colors.textMuted.withValues(alpha: 0.6))),
        if (_flipped) ...[
          SizedBox(height: 20),
          Row(children: [
            _rateBtn('Again', -1, context.colors.error, Icons.close_rounded),
            SizedBox(width: 8),
            _rateBtn('Hard', 0, Color(0xFFF59E0B), Icons.remove_rounded),
            SizedBox(width: 8),
            _rateBtn('Good', 1, accent, Icons.check_rounded),
            SizedBox(width: 8),
            _rateBtn('Easy', 2, Color(0xFF3B82F6), Icons.bolt_rounded),
          ]),
        ],
      ]),
    );
  }

  Widget _levelBadge(int lv) {
    final labels = {1:'New',2:'Learning',3:'Review',4:'Known',5:'Mastered'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text('Level $lv: ${labels[lv]??""}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent)));
  }

  Widget _rateBtn(String label, int delta, Color c, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _rate(delta),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withValues(alpha: 0.3))),
          child: Column(children: [
            Icon(icon, size: 18, color: c), SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c))]))));
  }

  Widget _buildComplete() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration_rounded, size: 64, color: accent),
            SizedBox(height: 16),
            Text('Session Complete!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
            SizedBox(height: 8),
            Text('Reviewed: $_reviewed | Mastered: $_mastered',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: accent)),
            SizedBox(height: 24),
            GestureDetector(
              onTap: () { setState(() { _shuffle(); }); },
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
                    Text('Start New Session',
                      style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}