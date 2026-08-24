import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme_colors.dart';

class ChinesePinyinLab extends StatefulWidget {
  const ChinesePinyinLab({super.key});
  @override
  State<ChinesePinyinLab> createState() => _ChinesePinyinLabState();
}

class _ChinesePinyinLabState extends State<ChinesePinyinLab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  static const Color _accent = Color(0xFFDC2626);

  static const List<String> _initials = [
    'b',
    'p',
    'm',
    'f',
    'd',
    't',
    'n',
    'l',
    'g',
    'k',
    'h',
    'j',
    'q',
    'x',
    'zh',
    'ch',
    'sh',
    'r',
    'z',
    'c',
    's',
    'y',
    'w',
  ];

  static const List<String> _finals = [
    'a',
    'o',
    'e',
    'i',
    'u',
    'ü',
    'ai',
    'ei',
    'ao',
    'ou',
    'an',
    'en',
    'ang',
    'eng',
    'ong',
    'ia',
    'ie',
    'iao',
    'ian',
    'iang',
    'in',
    'ing',
    'iong',
    'ua',
    'uo',
    'uai',
    'uan',
    'uang',
    'un',
    'üe',
    'üan',
  ];

  static const List<Map<String, String>> _initialGuide = [
    {'pinyin': 'b', 'sound': 'like b in but', 'example': '八 bā (eight)', 'tip': 'Lips close, release with no puff'},
    {'pinyin': 'p', 'sound': 'like p in put', 'example': '拍 pāi (clap)', 'tip': 'Same as b but with air puff'},
    {'pinyin': 'm', 'sound': 'like m in map', 'example': '妈 mā (mother)', 'tip': 'Lips together, hum through nose'},
    {'pinyin': 'f', 'sound': 'like f in fun', 'example': '飞 fēi (fly)', 'tip': 'Upper teeth touch lower lip'},
    {'pinyin': 'd', 'sound': 'like d in day', 'example': '大 dà (big)', 'tip': 'Tongue taps behind upper teeth'},
    {'pinyin': 't', 'sound': 'like t in top', 'example': '他 tā (he)', 'tip': 'Same as d but with puff'},
    {'pinyin': 'n', 'sound': 'like n in no', 'example': '你 nǐ (you)', 'tip': 'Air flows through nose'},
    {'pinyin': 'l', 'sound': 'like l in let', 'example': '六 liù (six)', 'tip': 'Air flows around tongue sides'},
    {'pinyin': 'g', 'sound': 'like g in go', 'example': '狗 gǒu (dog)', 'tip': 'Back of tongue touches soft palate'},
    {'pinyin': 'k', 'sound': 'like k in key', 'example': '开 kāi (open)', 'tip': 'Same as g but with more air'},
    {'pinyin': 'h', 'sound': 'like h in hot', 'example': '好 hǎo (good)', 'tip': 'Breathy sound from throat'},
    {
      'pinyin': 'j',
      'sound': 'like j in jeep',
      'example': '鸡 jī (chicken)',
      'tip': 'Tongue tip down, blade touches hard palate'
    },
    {'pinyin': 'q', 'sound': 'like ch in cheese', 'example': '七 qī (seven)', 'tip': 'Same as j but with air'},
    {
      'pinyin': 'x',
      'sound': 'like sh but forward',
      'example': '西 xī (west)',
      'tip': 'Tongue tip down, blade near hard palate'
    },
    {'pinyin': 'zh', 'sound': 'like j retroflex', 'example': '中 zhōng (middle)', 'tip': 'Curl tongue tip back'},
    {'pinyin': 'ch', 'sound': 'like ch retroflex', 'example': '吃 chī (eat)', 'tip': 'Same as zh but with air puff'},
    {
      'pinyin': 'sh',
      'sound': 'like sh retroflex',
      'example': '是 shì (is)',
      'tip': 'Curl tongue back, air around sides'
    },
    {
      'pinyin': 'r',
      'sound': 'like French r',
      'example': '人 rén (person)',
      'tip': 'Tongue curled back, vocal cords vibrate'
    },
    {
      'pinyin': 'z',
      'sound': 'like ds in reads',
      'example': '字 zì (character)',
      'tip': 'Tongue tip behind teeth, no air'
    },
    {'pinyin': 'c', 'sound': 'like ts in cats', 'example': '词 cí (word)', 'tip': 'Same as z but with air puff'},
    {
      'pinyin': 's',
      'sound': 'like s in sun',
      'example': '三 sān (three)',
      'tip': 'Tongue near teeth, air hisses through'
    },
    {'pinyin': 'y', 'sound': 'like y in yes', 'example': '一 yī (one)', 'tip': 'Glide into the vowel'},
    {'pinyin': 'w', 'sound': 'like w in wow', 'example': '五 wǔ (five)', 'tip': 'Round lips and glide into vowel'},
  ];

  static const List<Map<String, String>> _toneExamples = [
    {'pinyin': 'mā', 'tone': '1st', 'char': '妈', 'meaning': 'mother', 'desc': 'High and level'},
    {'pinyin': 'má', 'tone': '2nd', 'char': '麻', 'meaning': 'hemp', 'desc': 'Rising - like asking huh?'},
    {'pinyin': 'mǎ', 'tone': '3rd', 'char': '马', 'meaning': 'horse', 'desc': 'Dipping down then up'},
    {'pinyin': 'mà', 'tone': '4th', 'char': '骂', 'meaning': 'scold', 'desc': 'Sharp falling'},
    {'pinyin': 'ma', 'tone': 'Neutral', 'char': '吗', 'meaning': '(question particle)', 'desc': 'Light and short'},
  ];

  static const List<Map<String, String>> _finalGuide = [
    {'pinyin': 'a', 'sound': 'like a in father', 'example': '大 dà (big)'},
    {'pinyin': 'o', 'sound': 'like o in or', 'example': '我 wǒ (I)'},
    {'pinyin': 'e', 'sound': 'like e in her (no h)', 'example': '了 le (completed)'},
    {'pinyin': 'i', 'sound': 'like ee in see', 'example': '一 yī (one)'},
    {'pinyin': 'u', 'sound': 'like oo in moon', 'example': '五 wǔ (five)'},
    {'pinyin': 'ü', 'sound': 'like French u', 'example': '绿 lü (green)'},
    {'pinyin': 'ai', 'sound': 'like eye', 'example': '爱 ài (love)'},
    {'pinyin': 'ei', 'sound': 'like ay in say', 'example': '北 bēi (north)'},
    {'pinyin': 'ao', 'sound': 'like ow in cow', 'example': '好 hǎo (good)'},
    {'pinyin': 'ou', 'sound': 'like oh', 'example': '都 dǒu (all)'},
    {'pinyin': 'an', 'sound': 'like ahn', 'example': '三 sān (three)'},
    {'pinyin': 'en', 'sound': 'like en in ten', 'example': '人 rén (person)'},
    {'pinyin': 'ang', 'sound': 'like ahng', 'example': '上 shàng (up)'},
    {'pinyin': 'eng', 'sound': 'like ung in lung', 'example': '风 fēng (wind)'},
    {'pinyin': 'ong', 'sound': 'like oong', 'example': '中 zhōng (middle)'},
    {'pinyin': 'ia', 'sound': 'like ya', 'example': '家 jiā (home)'},
    {'pinyin': 'ie', 'sound': 'like ye', 'example': '写 xiē (write)'},
    {'pinyin': 'iao', 'sound': 'like yow', 'example': '小 xiǎo (small)'},
    {'pinyin': 'ian', 'sound': 'like yen', 'example': '天 tiān (sky)'},
    {'pinyin': 'in', 'sound': 'like een', 'example': '新 xī (new)'},
    {'pinyin': 'ing', 'sound': 'like eeng', 'example': '听 tīng (listen)'},
    {'pinyin': 'ua', 'sound': 'like wa', 'example': '花 huā (flower)'},
    {'pinyin': 'uo', 'sound': 'like wo', 'example': '多 duǒ (many)'},
    {'pinyin': 'uai', 'sound': 'like why', 'example': '快 kuài (fast)'},
    {'pinyin': 'uan', 'sound': 'like wan', 'example': '万 wàn (ten thousand)'},
    {'pinyin': 'üe', 'sound': 'like yue', 'example': '月 yuè (moon)'},
  ];

  String _selectedInitial = '';
  String _selectedFinal = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: const Text('Pinyin Lab'),
          backgroundColor: context.colors.surface,
          foregroundColor: context.colors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(),
          ),
          bottom: TabBar(
            controller: _tabCtrl,
            indicatorColor: _accent,
            indicatorWeight: 3,
            labelColor: _accent,
            unselectedLabelColor: context.colors.textMuted,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: const [Tab(text: 'Chart'), Tab(text: 'Initials'), Tab(text: 'Finals')],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [_buildChartTab(), _buildInitialsTab(), _buildFinalsTab()],
        ),
      );

  Widget _buildChartTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildToneOverview(),
            const SizedBox(height: 24),
            _buildSectionHeader('Pinyin Chart'),
            const SizedBox(height: 12),
            _buildPinyinChart(),
            const SizedBox(height: 24),
            if (_selectedInitial.isNotEmpty && _selectedFinal.isNotEmpty)
              _buildCombinationCard(_selectedInitial, _selectedFinal),
          ],
        ),
      );

  Widget _buildToneOverview() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.graphic_eq_rounded, size: 20, color: _accent),
              const SizedBox(width: 10),
              Text('The Four Tones + Neutral',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
            ]),
            const SizedBox(height: 16),
            ..._toneExamples.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration:
                      BoxDecoration(color: context.colors.surfaceElevated, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration:
                          BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: Text(t['char']!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(t['pinyin']!,
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(t['tone']!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _accent)),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text('${t['meaning']!} \u2014 ${t['desc']!}',
                          style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                    ])),
                  ]),
                )),
          ],
        ),
      );

  Widget _buildSectionHeader(String title) => Row(children: [
        Container(
            width: 4, height: 20, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
      ]);

  Widget _buildPinyinChart() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const SizedBox(width: 60, height: 36),
            ..._finals.map((f) => Container(
                  width: 54,
                  height: 36,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: Text(f, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _accent)),
                )),
          ]),
          ..._initials.map((ini) => Row(children: [
                Container(
                  width: 60,
                  height: 36,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: Text(ini, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _accent)),
                ),
                ..._finals.map((f) {
                  final combo = ini + f;
                  final sel = _selectedInitial == ini && _selectedFinal == f;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedInitial = ini;
                      _selectedFinal = f;
                    }),
                    child: Container(
                      width: 54,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? _accent.withValues(alpha: 0.2) : context.colors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: sel ? _accent : context.colors.border, width: sel ? 1.5 : 0.5),
                      ),
                      child: Text(combo,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? _accent : context.colors.textMuted,
                          )),
                    ),
                  );
                }),
              ])),
        ]),
      );

  Widget _buildCombinationCard(String initial, String final_) {
    final guide = _initialGuide.firstWhere((g) => g['pinyin'] == initial, orElse: () => {});
    final fGuide = _finalGuide.firstWhere((g) => g['pinyin'] == final_, orElse: () => {});
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$initial + $final_ = $initial$final_',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
        const SizedBox(height: 12),
        if (guide.isNotEmpty) ...[
          Text('Initial: ${guide['sound'] ?? ''}', style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
          Text('Tip: ${guide['tip'] ?? ''}', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
          Text('Example: ${guide['example'] ?? ''}', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
        ],
        if (fGuide.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Final: ${fGuide['sound'] ?? ''}', style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
          Text('Example: ${fGuide['example'] ?? ''}', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
        ],
      ]),
    );
  }

  Widget _buildInitialsTab() => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _initialGuide.length,
        itemBuilder: (ctx, i) {
          final g = _initialGuide[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border)),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Center(
                    child: Text(g['pinyin']!,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _accent))),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g['sound']!,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(g['example']!, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                const SizedBox(height: 2),
                Text(g['tip']!, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
              ])),
            ]),
          );
        },
      );

  Widget _buildFinalsTab() => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _finalGuide.length,
        itemBuilder: (ctx, i) {
          final g = _finalGuide[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border)),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Center(
                    child: Text(g['pinyin']!,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _accent))),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g['sound']!,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(g['example']!, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
              ])),
            ]),
          );
        },
      );
}
