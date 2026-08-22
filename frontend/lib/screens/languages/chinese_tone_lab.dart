import 'package:flutter/material.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class ChineseToneLab extends StatefulWidget {
  const ChineseToneLab({super.key});
  @override
  State<ChineseToneLab> createState() => _ChineseToneLabState();
}

class _ChineseToneLabState extends State<ChineseToneLab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  static const Color _accent = Color(0xFFF59E0B);
  static const Color _c1 = Color(0xFF60A5FA);
  static const Color _c2 = Color(0xFF22C55E);
  static const Color _c4 = Color(0xFFEF4444);
  static const Color _cn = Color(0xFF94A3B8);

  final Random _rand = Random();
  final Set<int> _expandedGroups = {};

  int _quizScore = 0;
  int _quizTotal = 0;
  int _currentIdx = 0;
  bool _answered = false;
  bool _wasCorrect = false;
  int _pickedTone = -1;
  late List<Map<String, dynamic>> _deck;

  int _listenScore = 0;
  int _listenTotal = 0;
  late List<int?> _listenPicks;

  static const List<Map<String, String>> _toneInfo = [
    {
      'name': '1st Tone',
      'char': '妈',
      'pinyin': 'mā',
      'meaning': 'mother',
      'desc': 'High and flat, like holding a steady note',
      'contour': '─────',
    },
    {
      'name': '2nd Tone',
      'char': '麻',
      'pinyin': 'má',
      'meaning': 'hemp',
      'desc': 'Rising, like a questioning huh?',
      'contour': '↗↗↗↗↗',
    },
    {
      'name': '3rd Tone',
      'char': '马',
      'pinyin': 'mǎ',
      'meaning': 'horse',
      'desc': 'Dips down low, then rises back up',
      'contour': '↘↗',
    },
    {
      'name': '4th Tone',
      'char': '骂',
      'pinyin': 'mà',
      'meaning': 'scold',
      'desc': 'Sharp falling, like a firm no!',
      'contour': '↘↘↘↘↘',
    },
    {
      'name': 'Neutral',
      'char': '吗',
      'pinyin': 'ma',
      'meaning': '(question particle)',
      'desc': 'Light and short, no fixed pitch',
      'contour': '·',
    },
  ];

  static const List<Map<String, String>> _toneRules = [
    {
      'name': 'Third Tone Sandhi',
      'rule': '3rd + 3rd → 2nd + 3rd',
      'example': '你好 nǐ hǎo → ní hǎo',
      'desc': 'When two third tones meet, the first one changes to second tone.',
    },
    {
      'name': '一 (yī) Tone Change',
      'rule': 'before 4th → yí · before 1st/2nd/3rd → yì',
      'example': '一个 yí gè · 一天 yì tiān',
      'desc': 'Alone or at the end of a phrase, 一 keeps its original first tone.',
    },
    {
      'name': '不 (bù) Tone Change',
      'rule': '4th → 2nd before another 4th tone',
      'example': '不是 bù shì → bú shì',
      'desc': '不 only becomes bú before a fourth tone; everywhere else it stays bù.',
    },
    {
      'name': 'Half Third Tone',
      'rule': '3rd tone dips only, no rise at the end',
      'example': '好人 hǎorén · 水果 shuǐguǒ',
      'desc': 'Before non-third tones, the dip stops low without rising back up.',
    },
    {
      'name': 'Neutral Tone Pitch',
      'rule': 'pitch height follows the preceding tone',
      'example': '妈妈 māma (low) · 爸爸 bàba (low)',
      'desc': 'After 1st or 4th it sits low, after 2nd mid-level, after 3rd relatively high.',
    },
  ];

  static const List<Map<String, dynamic>> _allWords = [
    {'char': '妈', 'pinyin': 'mā', 'meaning': 'mother', 'tone': 1},
    {'char': '花', 'pinyin': 'huā', 'meaning': 'flower', 'tone': 1},
    {'char': '一', 'pinyin': 'yī', 'meaning': 'one', 'tone': 1},
    {'char': '中', 'pinyin': 'zhōng', 'meaning': 'middle', 'tone': 1},
    {'char': '吃', 'pinyin': 'chī', 'meaning': 'eat', 'tone': 1},
    {'char': '天', 'pinyin': 'tiān', 'meaning': 'sky', 'tone': 1},
    {'char': '他', 'pinyin': 'tā', 'meaning': 'he', 'tone': 1},
    {'char': '麻', 'pinyin': 'má', 'meaning': 'hemp', 'tone': 2},
    {'char': '人', 'pinyin': 'rén', 'meaning': 'person', 'tone': 2},
    {'char': '来', 'pinyin': 'lái', 'meaning': 'come', 'tone': 2},
    {'char': '学', 'pinyin': 'xué', 'meaning': 'study', 'tone': 2},
    {'char': '读', 'pinyin': 'dú', 'meaning': 'read', 'tone': 2},
    {'char': '还', 'pinyin': 'hái', 'meaning': 'still', 'tone': 2},
    {'char': '鱼', 'pinyin': 'yú', 'meaning': 'fish', 'tone': 2},
    {'char': '马', 'pinyin': 'mǎ', 'meaning': 'horse', 'tone': 3},
    {'char': '你', 'pinyin': 'nǐ', 'meaning': 'you', 'tone': 3},
    {'char': '好', 'pinyin': 'hǎo', 'meaning': 'good', 'tone': 3},
    {'char': '水', 'pinyin': 'shuǐ', 'meaning': 'water', 'tone': 3},
    {'char': '小', 'pinyin': 'xiǎo', 'meaning': 'small', 'tone': 3},
    {'char': '我', 'pinyin': 'wǒ', 'meaning': 'I/me', 'tone': 3},
    {'char': '九', 'pinyin': 'jiǔ', 'meaning': 'nine', 'tone': 3},
    {'char': '骂', 'pinyin': 'mà', 'meaning': 'scold', 'tone': 4},
    {'char': '是', 'pinyin': 'shì', 'meaning': 'is', 'tone': 4},
    {'char': '大', 'pinyin': 'dà', 'meaning': 'big', 'tone': 4},
    {'char': '去', 'pinyin': 'qù', 'meaning': 'go', 'tone': 4},
    {'char': '快', 'pinyin': 'kuài', 'meaning': 'fast', 'tone': 4},
    {'char': '对', 'pinyin': 'duì', 'meaning': 'correct', 'tone': 4},
    {'char': '谢', 'pinyin': 'xiè', 'meaning': 'thank', 'tone': 4},
    {'char': '吗', 'pinyin': 'ma', 'meaning': '(question)', 'tone': 5},
    {'char': '的', 'pinyin': 'de', 'meaning': '(possessive)', 'tone': 5},
    {'char': '了', 'pinyin': 'le', 'meaning': '(completed)', 'tone': 5},
    {'char': '呢', 'pinyin': 'ne', 'meaning': '(particle)', 'tone': 5},
    {'char': '们', 'pinyin': 'men', 'meaning': '(plural)', 'tone': 5},
    {'char': '子', 'pinyin': 'zi', 'meaning': '(suffix)', 'tone': 5},
    {'char': '啊', 'pinyin': 'a', 'meaning': '(exclamation)', 'tone': 5},
  ];

  static const List<Map<String, dynamic>> _pairGroups = [
    {
      'sound': 'ma',
      'label': 'The classic five-way contrast',
      'items': [
        {'char': '妈', 'pinyin': 'mā', 'tone': '1st', 'meaning': 'mother'},
        {'char': '麻', 'pinyin': 'má', 'tone': '2nd', 'meaning': 'hemp'},
        {'char': '马', 'pinyin': 'mǎ', 'tone': '3rd', 'meaning': 'horse'},
        {'char': '骂', 'pinyin': 'mà', 'tone': '4th', 'meaning': 'scold'},
        {'char': '吗', 'pinyin': 'ma', 'tone': 'Neutral', 'meaning': 'question particle'},
      ],
    },
    {
      'sound': 'shi',
      'label': 'Poem · ten · use · is',
      'items': [
        {'char': '诗', 'pinyin': 'shī', 'tone': '1st', 'meaning': 'poem'},
        {'char': '十', 'pinyin': 'shí', 'tone': '2nd', 'meaning': 'ten'},
        {'char': '使', 'pinyin': 'shǐ', 'tone': '3rd', 'meaning': 'to use'},
        {'char': '是', 'pinyin': 'shì', 'tone': '4th', 'meaning': 'is'},
      ],
    },
    {
      'sound': 'tang',
      'label': 'Soup · sugar · lie · hot',
      'items': [
        {'char': '汤', 'pinyin': 'tāng', 'tone': '1st', 'meaning': 'soup'},
        {'char': '糖', 'pinyin': 'táng', 'tone': '2nd', 'meaning': 'sugar'},
        {'char': '躺', 'pinyin': 'tǎng', 'tone': '3rd', 'meaning': 'to lie down'},
        {'char': '烫', 'pinyin': 'tàng', 'tone': '4th', 'meaning': 'scalding hot'},
      ],
    },
    {
      'sound': 'mai',
      'label': 'Bury · sell',
      'items': [
        {'char': '埋', 'pinyin': 'mái', 'tone': '2nd', 'meaning': 'to bury'},
        {'char': '卖', 'pinyin': 'mài', 'tone': '4th', 'meaning': 'to sell'},
      ],
    },
    {
      'sound': 'wen',
      'label': 'Ask · kiss',
      'items': [
        {'char': '问', 'pinyin': 'wèn', 'tone': '4th', 'meaning': 'to ask'},
        {'char': '吻', 'pinyin': 'wěn', 'tone': '3rd', 'meaning': 'to kiss'},
      ],
    },
  ];

  static const List<Map<String, dynamic>> _listeningExercises = [
    {
      'prompt': 'High level tone on shi',
      'options': ['shī', 'shǐ', 'shí', 'shì'],
      'answer': 0,
      'char': '诗',
      'meaning': 'poem',
    },
    {
      'prompt': 'Rising tone on shi',
      'options': ['shì', 'shí', 'shī', 'shǐ'],
      'answer': 1,
      'char': '十',
      'meaning': 'ten',
    },
    {
      'prompt': 'Dipping tone on shi',
      'options': ['shí', 'shì', 'shǐ', 'shī'],
      'answer': 2,
      'char': '使',
      'meaning': 'to use',
    },
    {
      'prompt': 'Falling tone on shi',
      'options': ['shī', 'shǐ', 'shì', 'shí'],
      'answer': 2,
      'char': '是',
      'meaning': 'is',
    },
    {
      'prompt': 'Rising tone on tang',
      'options': ['tāng', 'táng', 'tǎng', 'tàng'],
      'answer': 1,
      'char': '糖',
      'meaning': 'sugar',
    },
    {
      'prompt': 'Falling tone on mai',
      'options': ['mái', 'māi', 'mài', 'mǎi'],
      'answer': 2,
      'char': '卖',
      'meaning': 'to sell',
    },
    {
      'prompt': 'Dipping tone on wen',
      'options': ['wèn', 'wén', 'wěn', 'wēn'],
      'answer': 2,
      'char': '吻',
      'meaning': 'to kiss',
    },
    {
      'prompt': 'Falling tone on wen',
      'options': ['wēn', 'wèn', 'wén', 'wěn'],
      'answer': 1,
      'char': '问',
      'meaning': 'to ask',
    },
    {
      'prompt': 'High level tone on ma',
      'options': ['mā', 'ma', 'má', 'mà'],
      'answer': 0,
      'char': '妈',
      'meaning': 'mother',
    },
    {
      'prompt': 'Rising tone on mai',
      'options': ['mǎi', 'mài', 'mái', 'māi'],
      'answer': 2,
      'char': '埋',
      'meaning': 'to bury',
    },
  ];

  static const Map<int, String> _toneTips = {
    1: 'First tone stays high and level throughout.',
    2: 'Second tone climbs from mid to high, like a question.',
    3: 'Third tone dips low first, then rises back up.',
    4: 'Fourth tone falls sharply from high to low.',
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _shuffleDeck();
    _resetListening();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _shuffleDeck() {
    _deck = List<Map<String, dynamic>>.from(
      _allWords.where((w) => (w['tone'] as int) <= 4),
    )..shuffle(_rand);
    _currentIdx = 0;
    _quizScore = 0;
    _quizTotal = 0;
    _answered = false;
    _wasCorrect = false;
    _pickedTone = -1;
  }

  void _resetQuiz() {
    setState(_shuffleDeck);
  }

  void _answer(int tone) {
    if (_answered) return;
    final w = _deck[_currentIdx];
    final correct = (w['tone'] as int) == tone;
    setState(() {
      _answered = true;
      _wasCorrect = correct;
      _pickedTone = tone;
      _quizTotal++;
      if (correct) _quizScore++;
    });
  }

  void _nextWord() {
    setState(() {
      _currentIdx = (_currentIdx + 1) % _deck.length;
      _answered = false;
      _pickedTone = -1;
    });
  }

  void _resetListening() {
    _listenScore = 0;
    _listenTotal = 0;
    _listenPicks = List<int?>.filled(_listeningExercises.length, null);
  }

  void _resetListeningTap() {
    setState(_resetListening);
  }

  void _pickListening(int exIdx, int optIdx) {
    if (_listenPicks[exIdx] != null) return;
    setState(() {
      _listenPicks[exIdx] = optIdx;
      _listenTotal++;
      if (optIdx == (_listeningExercises[exIdx]['answer'] as int)) {
        _listenScore++;
      }
    });
  }

  Color _toneColor(String tone) {
    switch (tone) {
      case '1st':
        return _c1;
      case '2nd':
        return _c2;
      case '3rd':
        return _accent;
      case '4th':
        return _c4;
      default:
        return _cn;
    }
  }

  Color _toneNumColor(int tone) {
    switch (tone) {
      case 1:
        return _c1;
      case 2:
        return _c2;
      case 3:
        return _accent;
      default:
        return _c4;
    }
  }

  String get _combinedScore => '${_quizScore + _listenScore}/${_quizTotal + _listenTotal}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tone Lab'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 16, color: _accent),
                const SizedBox(width: 6),
                Text(
                  _combinedScore,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _accent),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _accent,
          indicatorWeight: 3,
          labelColor: _accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Reference'),
            Tab(text: 'Quiz'),
            Tab(text: 'Pairs'),
            Tab(text: 'Listening'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildReferenceTab(),
          _buildQuizTab(),
          _buildPairsTab(),
          _buildListeningTab(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildReferenceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('The Five Tones'),
          const SizedBox(height: 12),
          _buildToneCards(),
          const SizedBox(height: 24),
          _buildSectionHeader('Tone Change Rules'),
          const SizedBox(height: 12),
          ..._toneRules.map(_buildRuleCard),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildToneCards() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 20, color: _accent),
              SizedBox(width: 10),
              Text(
                'Same sound, five meanings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._toneInfo.map((t) {
            final c = _toneColor((t['name'] ?? '').split(' ').first);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        t['char']!,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: c),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              t['pinyin']!,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t['name']!,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t['meaning']} — ${t['desc']}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t['contour']!,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRuleCard(Map<String, String> rule) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.change_circle_rounded, size: 14, color: _accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rule['name']!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rule['rule']!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rule['example']!,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            rule['desc']!,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Tone Quiz'),
          const SizedBox(height: 12),
          _buildQuizCard(),
          const SizedBox(height: 16),
          _buildNeutralReminder(),
          const SizedBox(height: 16),
          _buildResetButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuizCard() {
    if (_deck.isEmpty) return const SizedBox.shrink();
    final w = _deck[_currentIdx];
    final char = w['char'] as String;
    final pinyin = w['pinyin'] as String;
    final meaning = w['meaning'] as String;
    final correctTone = w['tone'] as int;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _answered
              ? (_wasCorrect ? AppColors.success.withValues(alpha: 0.4) : AppColors.error.withValues(alpha: 0.4))
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Text('${_currentIdx + 1} / ${_deck.length}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text(
            char,
            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            pinyin,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          Text(meaning, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 20),
          const Text(
            'Which tone is this?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [1, 2, 3, 4].map((tone) => _quizToneButton(tone, correctTone)).toList(),
          ),
          if (_answered) ...[
            const SizedBox(height: 16),
            Text(
              _wasCorrect
                  ? '✔ Correct!'
                  : '✖ Wrong — $char is tone $correctTone (${_toneTips[correctTone]})',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _wasCorrect ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _nextWord,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Next Word',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _accent),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quizToneButton(int tone, int correctTone) {
    final isCorrect = tone == correctTone;
    final isPicked = tone == _pickedTone;
    Color bg = AppColors.surfaceElevated;
    Color border = AppColors.border;
    Color textColor = AppColors.textPrimary;
    if (_answered && isCorrect) {
      bg = AppColors.success.withValues(alpha: 0.2);
      border = AppColors.success;
      textColor = AppColors.success;
    } else if (_answered && isPicked) {
      bg = AppColors.error.withValues(alpha: 0.2);
      border = AppColors.error;
      textColor = AppColors.error;
    }
    return GestureDetector(
      onTap: () => _answer(tone),
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: isCorrect || isPicked ? 1.5 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tone.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
            Text(
              const ['', '1st', '2nd', '3rd', '4th'][tone],
              style: TextStyle(fontSize: 9, color: _answered && isCorrect ? textColor : AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeutralReminder() {
    final neutrals = _allWords.where((w) => w['tone'] == 5).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_down_rounded, size: 16, color: _cn),
              const SizedBox(width: 8),
              const Text(
                'Neutral tone reminder',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'These words are unstressed and light — they never take tones 1-4.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: neutrals.map((w) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _cn.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${w['char']} ${w['pinyin']} · ${w['meaning']}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return GestureDetector(
      onTap: _resetQuiz,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, size: 18, color: _accent),
            const SizedBox(width: 8),
            Text('Reset Quiz', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _accent)),
          ],
        ),
      ),
    );
  }

  Widget _buildPairsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Tone Pairs'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_rounded, size: 20, color: _accent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'The same syllable with a different tone is a completely different word. Tap a group to explore.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_pairGroups.length, (i) => _buildPairGroup(i)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPairGroup(int gi) {
    final group = _pairGroups[gi];
    final items = group['items'] as List<Map<String, dynamic>>;
    final expanded = _expandedGroups.contains(gi);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: expanded ? _accent.withValues(alpha: 0.35) : AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() {
              if (expanded) {
                _expandedGroups.remove(gi);
              } else {
                _expandedGroups.add(gi);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        group['sound'] as String,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"${group['sound']}" family',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group['label'] as String,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${items.length} ways',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: items.map((item) {
                  final c = _toneColor(item['tone'] as String);
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          item['char'] as String,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['pinyin'] as String,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              Text(
                                item['meaning'] as String,
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['tone'] as String,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListeningTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildSectionHeader('Listening Drills')),
              GestureDetector(
                onTap: _resetListeningTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 14, color: _accent),
                      const SizedBox(width: 4),
                      Text(
                        '$_listenScore/$_listenTotal',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _accent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_listeningExercises.length, (i) => _buildListenCard(i)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildListenCard(int i) {
    final ex = _listeningExercises[i];
    final options = (ex['options'] as List<dynamic>).cast<String>();
    final answerIdx = ex['answer'] as int;
    final pick = _listenPicks[i];
    final answered = pick != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: answered
              ? (pick == answerIdx ? AppColors.success.withValues(alpha: 0.4) : AppColors.error.withValues(alpha: 0.4))
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pick the ${ex['prompt']}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _listenOption(i, options[0], 0, answerIdx)),
              const SizedBox(width: 8),
              Expanded(child: _listenOption(i, options[1], 1, answerIdx)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _listenOption(i, options[2], 2, answerIdx)),
              const SizedBox(width: 8),
              Expanded(child: _listenOption(i, options[3], 3, answerIdx)),
            ],
          ),
          if (answered) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pick == answerIdx
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pick == answerIdx
                        ? '✔ Correct — ${ex['char']} ${options[answerIdx]} means "${ex['meaning']}"'
                        : '✖ It is ${ex['char']} ${options[answerIdx]} ("${ex['meaning']}")',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: pick == answerIdx ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _toneTips[_toneNumberFromPinyin(options[answerIdx])] ?? '',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _toneNumberFromPinyin(String py) {
    const marks = ['āēīōūǖ', 'áéíóúǘ', 'ǎěǐǒǔǚ', 'àèìòùǜ'];
    for (var t = 0; t < marks.length; t++) {
      for (final m in marks[t].split('')) {
        if (py.contains(m)) return t + 1;
      }
    }
    return 1;
  }

  Widget _listenOption(int exIdx, String label, int optIdx, int answerIdx) {
    final pick = _listenPicks[exIdx];
    final answered = pick != null;
    final isAnswer = optIdx == answerIdx;
    final isPick = pick == optIdx;
    Color bg = AppColors.surfaceElevated;
    Color border = AppColors.border;
    Color textColor = AppColors.textPrimary;
    if (answered && isAnswer) {
      bg = AppColors.success.withValues(alpha: 0.18);
      border = AppColors.success;
      textColor = AppColors.success;
    } else if (answered && isPick) {
      bg = AppColors.error.withValues(alpha: 0.18);
      border = AppColors.error;
      textColor = AppColors.error;
    }
    return GestureDetector(
      onTap: () => _pickListening(exIdx, optIdx),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: answered && (isAnswer || isPick) ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
        ),
      ),
    );
  }
}
