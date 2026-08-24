import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme_colors.dart';

class ChineseRadicalLab extends StatefulWidget {
  const ChineseRadicalLab({super.key});
  @override
  State<ChineseRadicalLab> createState() => _ChineseRadicalLabState();
}

class _ChineseRadicalLabState extends State<ChineseRadicalLab> {
  static const Color accent = Color(0xFFEC4899);
  int? _selected;
  String _search = '';

  static const List<Map<String, dynamic>> _radicals = [
    {
      'r': '亻',
      'name': 'ren2',
      'meaning': 'person',
      'strokes': 2,
      'pos': 'left',
      'etymology': 'Derived from a standing person figure',
      'chars': [
        {'c': '他', 'p': 'tā', 'm': 'he', 'b': '亻+也'},
        {'c': '你', 'p': 'nǐ', 'm': 'you', 'b': '亻+尔'},
        {'c': '做', 'p': 'zuò', 'm': 'do', 'b': '亻+故'},
        {'c': '住', 'p': 'zhù', 'm': 'live', 'b': '亻+主'},
        {'c': '体', 'p': 'tǐ', 'm': 'body', 'b': '亻+本'}
      ]
    },
    {
      'r': '氵',
      'name': 'shui3',
      'meaning': 'water',
      'strokes': 3,
      'pos': 'left',
      'etymology': 'Three drops representing flowing water',
      'chars': [
        {'c': '河', 'p': 'hé', 'm': 'river', 'b': '氵+可'},
        {'c': '湖', 'p': 'hú', 'm': 'lake', 'b': '氵+胡'},
        {'c': '海', 'p': 'hǎi', 'm': 'sea', 'b': '氵+每'},
        {'c': '洗', 'p': 'xǐ', 'm': 'wash', 'b': '氵+先'}
      ]
    },
    {
      'r': '口',
      'name': 'kou3',
      'meaning': 'mouth',
      'strokes': 3,
      'pos': 'left',
      'etymology': 'Open mouth shape',
      'chars': [
        {'c': '吃', 'p': 'chī', 'm': 'eat', 'b': '口+乞'},
        {'c': '吗', 'p': 'ma', 'm': 'question', 'b': '口+马'},
        {'c': '喝', 'p': 'hē', 'm': 'drink', 'b': '口+曷'},
        {'c': '听', 'p': 'tīn', 'm': 'listen', 'b': '口+斤'}
      ]
    },
    {
      'r': '木',
      'name': 'mu4',
      'meaning': 'wood',
      'strokes': 4,
      'pos': 'left',
      'etymology': 'Tree with branches',
      'chars': [
        {'c': '林', 'p': 'lín', 'm': 'forest', 'b': '木+木'},
        {'c': '树', 'p': 'shù', 'm': 'tree', 'b': '木+对'},
        {'c': '桌', 'p': 'zhuō', 'm': 'table', 'b': '日+木'},
        {'c': '椅', 'p': 'yǐ', 'm': 'chair', 'b': '木+奇'}
      ]
    },
    {
      'r': '女',
      'name': 'nv3',
      'meaning': 'woman',
      'strokes': 3,
      'pos': 'left',
      'etymology': 'Kneeling woman figure',
      'chars': [
        {'c': '妈', 'p': 'mā', 'm': 'mother', 'b': '女+马'},
        {'c': '好', 'p': 'hǎo', 'm': 'good', 'b': '女+子'},
        {'c': '姐', 'p': 'jiē', 'm': 'sister', 'b': '女+且'},
        {'c': '妹', 'p': 'mèi', 'm': 'sister', 'b': '女+未'}
      ]
    },
    {
      'r': '讠',
      'name': 'yan2',
      'meaning': 'speech',
      'strokes': 2,
      'pos': 'left',
      'etymology': 'Simplified speech radical',
      'chars': [
        {'c': '说', 'p': 'shuō', 'm': 'say', 'b': '讠+兑'},
        {'c': '话', 'p': 'huà', 'm': 'words', 'b': '讠+舌'},
        {'c': '语', 'p': 'yǐ', 'm': 'language', 'b': '讠+吾'},
        {'c': '读', 'p': 'dú', 'm': 'read', 'b': '讠+卖'}
      ]
    },
    {
      'r': '月',
      'name': 'yue4',
      'meaning': 'moon/flesh',
      'strokes': 4,
      'pos': 'left',
      'etymology': 'Moon or flesh radical',
      'chars': [
        {'c': '朋', 'p': 'péng', 'm': 'friend', 'b': '月+月'},
        {'c': '腿', 'p': 'tuǐ', 'm': 'leg', 'b': '月+退'},
        {'c': '脸', 'p': 'liǎn', 'm': 'face', 'b': '月+佥'},
        {'c': '肚', 'p': 'dù', 'm': 'belly', 'b': '月+土'}
      ]
    },
    {
      'r': '火',
      'name': 'huo3',
      'meaning': 'fire',
      'strokes': 4,
      'pos': 'left',
      'etymology': 'Flames rising',
      'chars': [
        {'c': '灯', 'p': 'dēng', 'm': 'light', 'b': '火+丁'},
        {'c': '炒', 'p': 'chǎo', 'm': 'fry', 'b': '火+少'},
        {'c': '烧', 'p': 'shāo', 'm': 'burn', 'b': '火+尧'},
        {'c': '烟', 'p': 'yān', 'm': 'smoke', 'b': '火+因'}
      ]
    },
    {
      'r': '土',
      'name': 'tu3',
      'meaning': 'earth',
      'strokes': 3,
      'pos': 'left',
      'etymology': 'Lump of earth',
      'chars': [
        {'c': '地', 'p': 'dì', 'm': 'ground', 'b': '土+也'},
        {'c': '场', 'p': 'chǎng', 'm': 'place', 'b': '土+扬'},
        {'c': '城', 'p': 'chéng', 'm': 'city', 'b': '土+成'},
        {'c': '坐', 'p': 'zuò', 'm': 'sit', 'b': '土+土+人'}
      ]
    },
    {
      'r': '金',
      'name': 'jin1',
      'meaning': 'gold/metal',
      'strokes': 8,
      'pos': 'left',
      'etymology': 'Metal/gold radical',
      'chars': [
        {'c': '银', 'p': 'yín', 'm': 'silver', 'b': '金+艮'},
        {'c': '铁', 'p': 'tiě', 'm': 'iron', 'b': '金+失'},
        {'c': '钱', 'p': 'qián', 'm': 'money', 'b': '金+戋'},
        {'c': '钟', 'p': 'zhōng', 'm': 'clock', 'b': '金+中'}
      ]
    },
    {
      'r': '纟',
      'name': 'si1',
      'meaning': 'silk',
      'strokes': 3,
      'pos': 'left',
      'etymology': 'Simplified silk radical',
      'chars': [
        {'c': '红', 'p': 'hóng', 'm': 'red', 'b': '纟+工'},
        {'c': '绿', 'p': 'lù', 'm': 'green', 'b': '纟+录'},
        {'c': '线', 'p': 'xiàn', 'm': 'line', 'b': '纟+戋'},
        {'c': '纸', 'p': 'zhǐ', 'm': 'paper', 'b': '纟+氏'}
      ]
    },
    {
      'r': '忄',
      'name': 'xin1',
      'meaning': 'heart',
      'strokes': 3,
      'pos': 'left',
      'etymology': 'Heart radical side form',
      'chars': [
        {'c': '快', 'p': 'kuài', 'm': 'fast', 'b': '忄+夬'},
        {'c': '慢', 'p': 'màn', 'm': 'slow', 'b': '忄+曼'},
        {'c': '情', 'p': 'qíng', 'm': 'feeling', 'b': '忄+青'},
        {'c': '忙', 'p': 'máng', 'm': 'busy', 'b': '忄+亡'}
      ]
    },
    {
      'r': '辶',
      'name': 'chuo4',
      'meaning': 'walk',
      'strokes': 3,
      'pos': 'bottom',
      'etymology': 'Walking/movement radical',
      'chars': [
        {'c': '远', 'p': 'yuǎn', 'm': 'far', 'b': '辶+元'},
        {'c': '近', 'p': 'jìn', 'm': 'near', 'b': '辶+斤'},
        {'c': '进', 'p': 'jìn', 'm': 'enter', 'b': '辶+井'},
        {'c': '道', 'p': 'dào', 'm': 'road', 'b': '辶+首'}
      ]
    },
    {
      'r': '艹',
      'name': 'cao3',
      'meaning': 'grass',
      'strokes': 3,
      'pos': 'top',
      'etymology': 'Grass/plant radical',
      'chars': [
        {'c': '花', 'p': 'huā', 'm': 'flower', 'b': '艹+化'},
        {'c': '草', 'p': 'cǎo', 'm': 'grass', 'b': '艹+早'},
        {'c': '茶', 'p': 'chá', 'm': 'tea', 'b': '艹+木+人'},
        {'c': '药', 'p': 'yào', 'm': 'medicine', 'b': '艹+约'}
      ]
    },
    {
      'r': '日',
      'name': 'ri4',
      'meaning': 'sun',
      'strokes': 4,
      'pos': 'left',
      'etymology': 'Sun radical',
      'chars': [
        {'c': '明', 'p': 'míng', 'm': 'bright', 'b': '日+月'},
        {'c': '时', 'p': 'shí', 'm': 'time', 'b': '日+寸'},
        {'c': '早', 'p': 'zǎo', 'm': 'early', 'b': '日+十'},
        {'c': '晚', 'p': 'wǎn', 'm': 'evening', 'b': '日+免'}
      ]
    },
    {
      'r': '目',
      'name': 'mu4b',
      'meaning': 'eye',
      'strokes': 5,
      'pos': 'left',
      'etymology': 'Eye radical',
      'chars': [
        {'c': '看', 'p': 'kàn', 'm': 'look', 'b': '手+目'},
        {'c': '眼', 'p': 'yǎn', 'm': 'eye', 'b': '目+艮'},
        {'c': '睛', 'p': 'jīng', 'm': 'pupil', 'b': '目+青'},
        {'c': '睡', 'p': 'shuì', 'm': 'sleep', 'b': '目+垂'}
      ]
    },
    {
      'r': '足',
      'name': 'zu2',
      'meaning': 'foot',
      'strokes': 7,
      'pos': 'left',
      'etymology': 'Foot radical',
      'chars': [
        {'c': '跑', 'p': 'pǎo', 'm': 'run', 'b': '足+包'},
        {'c': '跳', 'p': 'tiào', 'm': 'jump', 'b': '足+兆'},
        {'c': '路', 'p': 'lù', 'm': 'road', 'b': '足+各'},
        {'c': '踢', 'p': 'tī', 'm': 'kick', 'b': '足+易'}
      ]
    },
    {
      'r': '禾',
      'name': 'he2',
      'meaning': 'grain',
      'strokes': 5,
      'pos': 'left',
      'etymology': 'Grain radical',
      'chars': [
        {'c': '和', 'p': 'hé', 'm': 'harmony', 'b': '禾+口'},
        {'c': '种', 'p': 'zhǒng', 'm': 'seed', 'b': '禾+中'},
        {'c': '秋', 'p': 'qiū', 'm': 'autumn', 'b': '禾+火'},
        {'c': '科', 'p': 'kē', 'm': 'science', 'b': '禾+斗'}
      ]
    },
    {
      'r': '⺮',
      'name': 'zhu2',
      'meaning': 'bamboo',
      'strokes': 6,
      'pos': 'top',
      'etymology': 'Bamboo radical',
      'chars': [
        {'c': '笔', 'p': 'bǐ', 'm': 'pen', 'b': '⺮+毛'},
        {'c': '笑', 'p': 'xiào', 'm': 'laugh', 'b': '⺮+夭'},
        {'c': '等', 'p': 'dēng', 'm': 'wait', 'b': '⺮+寺'},
        {'c': '筷', 'p': 'kuài', 'm': 'chopsticks', 'b': '⺮+快'}
      ]
    },
    {
      'r': '石',
      'name': 'shi2',
      'meaning': 'stone',
      'strokes': 5,
      'pos': 'left',
      'etymology': 'Rock/stone radical',
      'chars': [
        {'c': '砖', 'p': 'zhuān', 'm': 'brick', 'b': '石+专'},
        {'c': '碗', 'p': 'wǎn', 'm': 'bowl', 'b': '石+宛'},
        {'c': '硬', 'p': 'yìng', 'm': 'hard', 'b': '石+更'}
      ]
    },
    {
      'r': '鸟',
      'name': 'niao3',
      'meaning': 'bird',
      'strokes': 5,
      'pos': 'right',
      'etymology': 'Bird radical',
      'chars': [
        {'c': '鸡', 'p': 'jī', 'm': 'chicken', 'b': '又+鸟'},
        {'c': '鸭', 'p': 'yā', 'm': 'duck', 'b': '甲+鸟'},
        {'c': '鹅', 'p': 'é', 'm': 'goose', 'b': '我+鸟'}
      ]
    },
    {
      'r': '鱼',
      'name': 'yu2',
      'meaning': 'fish',
      'strokes': 8,
      'pos': 'left',
      'etymology': 'Fish radical',
      'chars': [
        {'c': '鲜', 'p': 'xiān', 'm': 'fresh', 'b': '鱼+羊'},
        {'c': '鲸', 'p': 'jīng', 'm': 'whale', 'b': '鱼+京'},
        {'c': '鲨', 'p': 'shā', 'm': 'shark', 'b': '鱼+沙'}
      ]
    },
    {
      'r': '马',
      'name': 'ma3',
      'meaning': 'horse',
      'strokes': 3,
      'pos': 'left',
      'etymology': 'Horse radical',
      'chars': [
        {'c': '骑', 'p': 'qí', 'm': 'ride', 'b': '马+奇'},
        {'c': '驾', 'p': 'jià', 'm': 'drive', 'b': '加+马'},
        {'c': '驻', 'p': 'zhù', 'm': 'station', 'b': '马+主'}
      ]
    },
    {
      'r': '牛',
      'name': 'niu2',
      'meaning': 'cow',
      'strokes': 4,
      'pos': 'left',
      'etymology': 'Ox/cow radical',
      'chars': [
        {'c': '物', 'p': 'wù', 'm': 'thing', 'b': '牛+勿'},
        {'c': '特', 'p': 'tè', 'm': 'special', 'b': '牛+寺'},
        {'c': '牺', 'p': 'xī', 'm': 'sacrifice', 'b': '牛+西'}
      ]
    },
    {
      'r': '犬',
      'name': 'quan3',
      'meaning': 'dog',
      'strokes': 4,
      'pos': 'left',
      'etymology': 'Dog radical',
      'chars': [
        {'c': '猫', 'p': 'māo', 'm': 'cat', 'b': '犭+苗'},
        {'c': '狗', 'p': 'gǒu', 'm': 'dog', 'b': '犭+句'},
        {'c': '猪', 'p': 'zhū', 'm': 'pig', 'b': '犭+者'}
      ]
    },
    {
      'r': '虫',
      'name': 'chong2',
      'meaning': 'insect',
      'strokes': 6,
      'pos': 'left',
      'etymology': 'Insect/bug radical',
      'chars': [
        {'c': '蛇', 'p': 'shé', 'm': 'snake', 'b': '虫+它'},
        {'c': '蝶', 'p': 'dié', 'm': 'butterfly', 'b': '虫+枼'},
        {'c': '蚂', 'p': 'mǎ', 'm': 'ant', 'b': '虫+马'}
      ]
    },
    {
      'r': '雨',
      'name': 'yu3',
      'meaning': 'rain',
      'strokes': 8,
      'pos': 'top',
      'etymology': 'Rain from clouds',
      'chars': [
        {'c': '雪', 'p': 'xuě', 'm': 'snow', 'b': '雨+彐'},
        {'c': '雷', 'p': 'léi', 'm': 'thunder', 'b': '雨+田'},
        {'c': '雾', 'p': 'wù', 'm': 'fog', 'b': '雨+务'}
      ]
    },
    {
      'r': '门',
      'name': 'men2',
      'meaning': 'door',
      'strokes': 3,
      'pos': 'enclosure',
      'etymology': 'Door/gate radical',
      'chars': [
        {'c': '问', 'p': 'wèn', 'm': 'ask', 'b': '门+口'},
        {'c': '间', 'p': 'jiān', 'm': 'between', 'b': '门+日'},
        {'c': '开', 'p': 'kāi', 'm': 'open', 'b': '一+廾'}
      ]
    },
    {
      'r': '车',
      'name': 'che1',
      'meaning': 'vehicle',
      'strokes': 4,
      'pos': 'left',
      'etymology': 'Vehicle/cart radical',
      'chars': [
        {'c': '转', 'p': 'zhuǎn', 'm': 'turn', 'b': '车+专'},
        {'c': '轮', 'p': 'lún', 'm': 'wheel', 'b': '车+仑'},
        {'c': '轻', 'p': 'qīng', 'm': 'light', 'b': '车+圣'}
      ]
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _radicals;
    return _radicals
        .where((r) =>
            (r['meaning'] as String).toLowerCase().contains(_search.toLowerCase()) ||
            (r['r'] as String).contains(_search) ||
            (r['name'] as String).toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: const Text('Radical Lab'),
          backgroundColor: context.colors.surface,
          foregroundColor: context.colors.textPrimary,
          elevation: 0,
          leading:
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
        ),
        body: _selected != null ? _buildDetail() : _buildGrid(),
      );

  Widget _buildGrid() {
    final list = _filtered;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
                hintText: 'Search radicals...',
                hintStyle: TextStyle(color: context.colors.textMuted.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search_rounded, color: context.colors.textMuted, size: 20),
                filled: true,
                fillColor: context.colors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
      ),
      Expanded(
          child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.85),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final r = list[i];
                return GestureDetector(
                    onTap: () {
                      final idx = _radicals.indexWhere((x) => x['r'] == r['r']);
                      setState(() => _selected = idx);
                    },
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.colors.border)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(r['r'] as String,
                              style: TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w400, color: context.colors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(r['meaning'] as String,
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
                          const SizedBox(height: 2),
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                              child: Text('${r['strokes']}st',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: accent))),
                        ])));
              }))
    ]);
  }

  Widget _buildDetail() {
    final r = _radicals[_selected!];
    final chars = r['chars'] as List;
    return Column(children: [
      Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: context.colors.surface, border: Border(bottom: BorderSide(color: context.colors.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  child: const Icon(Icons.arrow_back_rounded, color: accent, size: 20)),
              const SizedBox(width: 12),
              Text(r['r'] as String,
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w400, color: context.colors.textPrimary)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['meaning'] as String,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                Text('${r['name']} | ${r['strokes']} strokes | ${r['pos']}',
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              ]))
            ]),
            const SizedBox(height: 12),
            Text(r['etymology'] as String, style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
          ])),
      Expanded(
          child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6),
              itemCount: chars.length,
              itemBuilder: (_, i) {
                final c = chars[i] as Map<String, dynamic>;
                return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.colors.border)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(c['c'] as String,
                          style:
                              TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: context.colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(c['p'] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                      Text(c['m'] as String, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                      const SizedBox(height: 2),
                      Text(c['b'] as String, style: TextStyle(fontSize: 9, color: context.colors.textMuted)),
                    ]));
              }))
    ]);
  }
}
