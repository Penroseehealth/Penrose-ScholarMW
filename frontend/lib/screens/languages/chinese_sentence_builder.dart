import 'package:flutter/material.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class ChineseSentenceBuilder extends StatefulWidget {
  ChineseSentenceBuilder({super.key});
  @override
  State<ChineseSentenceBuilder> createState() => _ChineseSentenceBuilderState();
}

class _ChineseSentenceBuilderState extends State<ChineseSentenceBuilder> {
  static const Color accent = Color(0xFF3B82F6);
  int _idx = 0, _score = 0, _total = 0, _hsk = 0;
  bool _answered = false, _correct = false;
  List<String> _bank = [], _built = [];
  late List<Map<String, dynamic>> _ex;
  final Random _r = Random();

  static const List<Map<String, dynamic>> _all = [
    {'hsk': 1, 'sentence': '我是学生', 'pinyin': 'wǒ shì xuéshēng', 'english': 'I am a student', 'words': ['我', '是', '学生']},
    {'hsk': 1, 'sentence': '他有一个猫', 'pinyin': 'tā yǒu yī gè māo', 'english': 'He has a cat', 'words': ['他', '有', '一个', '猫']},
    {'hsk': 1, 'sentence': '这是什么', 'pinyin': 'zhè shì shénme', 'english': 'What is this?', 'words': ['这', '是', '什么']},
    {'hsk': 1, 'sentence': '我喜欢你', 'pinyin': 'wǒ xǐhuān nǐ', 'english': 'I like you', 'words': ['我', '喜欢', '你']},
    {'hsk': 1, 'sentence': '她在家', 'pinyin': 'tā zài jiā', 'english': 'She is at home', 'words': ['她', '在', '家']},
    {'hsk': 2, 'sentence': '我想去中国', 'pinyin': 'wǒ xiǎngng qù zhōngguó', 'english': 'I want to go to China', 'words': ['我', '想', '去', '中国']},
    {'hsk': 2, 'sentence': '他每天运动', 'pinyin': 'tā mēitiān yùndòng', 'english': 'He exercises daily', 'words': ['他', '每天', '运动']},
    {'hsk': 2, 'sentence': '今天天气很好', 'pinyin': 'jīntiān tiānqì hēn hǎo', 'english': 'Today weather is nice', 'words': ['今天', '天气', '很', '好']},
    {'hsk': 2, 'sentence': '你喝茶还是喝水', 'pinyin': 'nǐ hē chá háishì hē shuǐ', 'english': 'Tea or water?', 'words': ['你', '喝', '茶', '还是', '喝', '水']},
    {'hsk': 2, 'sentence': '我学习汉语很努力', 'pinyin': 'wǒ xuéxí hànyǐ hēn nǐlì', 'english': 'I study Chinese hard', 'words': ['我', '学习', '汉语', '很', '努力']},
    {'hsk': 3, 'sentence': '我已经工作了三年', 'pinyin': 'wǒ yǐjīng gōngzuò le sān nián', 'english': 'Worked for 3 years', 'words': ['我', '已经', '工作', '了', '三年']},
    {'hsk': 3, 'sentence': '这个电影非常有意思', 'pinyin': 'zhègè diànyǐng fēicháng yǒu yìsi', 'english': 'This movie is interesting', 'words': ['这个', '电影', '非常', '有意思']},
    {'hsk': 3, 'sentence': '因为下雨所以我没去', 'pinyin': 'yīnwèi xià yǐ suǒyǐ wǒ méi qù', 'english': 'Because rain I did not go', 'words': ['因为', '下雨', '所以', '我', '没', '去']},
    {'hsk': 3, 'sentence': '如果你有时间就来找我', 'pinyin': 'rùguǒ nǐ yǒu shíjiān jiù lái zhǎo wǒ', 'english': 'If time come find me', 'words': ['如果', '你', '有', '时间', '就', '来', '找', '我']},
    {'hsk': 3, 'sentence': '他虽然很忙但还是帮了我', 'pinyin': 'tā suīrán hēn máng dànshì háishì bāng le wǒ', 'english': 'Although busy he helped me', 'words': ['他', '虽然', '很', '忙', '但是', '还是', '帮', '了', '我']},
  ];

  @override
  void initState() {
    super.initState();
    _ex = List<Map<String, dynamic>>.from(_all)..shuffle(_r);
    _prepare();
  }

  void _prepare() {
    final w = List<String>.from(_ex[_idx]['words'] as List)..shuffle(_r);
    setState(() { _bank = w; _built = []; _answered = false; });
  }

  void _toSentence(String word) {
    if (_answered) return;
    setState(() { _bank.remove(word); _built.add(word); });
  }

  void _toBank(String word) {
    if (_answered) return;
    setState(() { _built.remove(word); _bank.add(word); });
  }

  void _check() {
    final target = _ex[_idx]['words'] as List;
    final ok = _built.length == target.length && _built.join() == target.join();
    setState(() { _answered = true; _correct = ok; _total++; if (ok) _score++; });
  }

  void _next() {
    setState(() { _idx = (_idx + 1) % _ex.length; });
    _prepare();
  }

  void _reset() {
    setState(() {
      _ex = List<Map<String, dynamic>>.from(_all)..shuffle(_r);
      _idx = 0; _score = 0; _total = 0; _hsk = 0;
    });
    _prepare();
  }

  List<Map<String, dynamic>> get _filtered =>
      _hsk == 0 ? _ex : _ex.where((e) => e['hsk'] == _hsk).toList();

  @override
  Widget build(BuildContext context) {
    final ex = _ex[_idx];
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Sentence Builder'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star_rounded, size: 16, color: accent),
              SizedBox(width: 6),
              Text('$_score/$_total', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
            ]),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHskFilter(),
          SizedBox(height: 16),
          _buildSentenceCard(ex),
          SizedBox(height: 16),
          _buildSectionHeader('Your Sentence'),
          SizedBox(height: 8),
          _buildSentenceArea(),
          SizedBox(height: 16),
          _buildSectionHeader('Word Bank'),
          SizedBox(height: 8),
          _buildBank(),
          SizedBox(height: 16),
          _buildActions(),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(
        color: accent, borderRadius: BorderRadius.circular(2))),
      SizedBox(width: 12),
      Text(title, style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
    ]);
  }

  Widget _buildHskFilter() {
    return Row(children: [
      _chip('All', 0),
      SizedBox(width: 8),
      _chip('HSK 1', 1),
      SizedBox(width: 8),
      _chip('HSK 2', 2),
      SizedBox(width: 8),
      _chip('HSK 3', 3),
    ]);
  }

  Widget _chip(String label, int val) {
    final sel = _hsk == val;
    return GestureDetector(
      onTap: () { setState(() { _hsk = val; _idx = 0; }); _prepare(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? accent.withValues(alpha: 0.2) : context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? accent : context.colors.border),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: sel ? accent : context.colors.textMuted)),
      ),
    );
  }

  Widget _buildSentenceCard(Map<String, dynamic> ex) {
    final hsk = ex['hsk'] as int;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _answered ? (_correct ? context.colors.success.withValues(alpha: 0.4) : context.colors.error.withValues(alpha: 0.4)) : context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text('HSK $hsk', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
          ),
          Spacer(),
          Text('${_idx + 1}/${_ex.length}', style: TextStyle(
            fontSize: 12, color: context.colors.textMuted)),
        ]),
        SizedBox(height: 16),
        if (_answered) ...[
          Text(ex['sentence'] as String, style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w400, color: context.colors.textPrimary)),
          SizedBox(height: 8),
        ],
        Text(ex['pinyin'] as String, style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
        SizedBox(height: 4),
        Text(ex['english'] as String, style: TextStyle(
          fontSize: 14, color: context.colors.textMuted)),
        if (_answered) ...[
          SizedBox(height: 12),
          Text(_correct ? 'Correct!' : 'Incorrect. Try again!',
            style: TextStyle(fontWeight: FontWeight.w700,
              color: _correct ? context.colors.success : context.colors.error)),
        ],
      ]),
    );
  }

  Widget _buildSentenceArea() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: _built.isEmpty
          ? Center(child: Text('Tap words below to build sentence',
              style: TextStyle(color: context.colors.textMuted, fontSize: 13)))
          : Wrap(
              spacing: 8, runSpacing: 8,
              children: _built.map((w) => GestureDetector(
                onTap: () => _toBank(w),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(w, style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: accent)),
                ),
              )).toList(),
            ),
    );
  }

  Widget _buildBank() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _bank.map((w) => GestureDetector(
        onTap: () => _toSentence(w),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.border),
          ),
          child: Text(w, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
        ),
      )).toList(),
    );
  }

  Widget _buildActions() {
    return Row(children: [
      if (!_answered && _built.isNotEmpty) Expanded(
        child: GestureDetector(
          onTap: _check,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: accent, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('Check',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
          ),
        ),
      ),
      if (_answered) ...[
        Expanded(
          child: GestureDetector(
            onTap: _next,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Next', style: TextStyle(
                  fontWeight: FontWeight.w700, color: accent)),
              ]),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: context.colors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Reset', style: TextStyle(
                  fontWeight: FontWeight.w700, color: context.colors.textMuted)),
              ]),
            ),
          ),
        ),
      ],
    ]);
  }
}