import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Color _bioGreen = Color(0xFF10B981);

class BiologyTopicsScreen extends StatefulWidget {
  const BiologyTopicsScreen({super.key});

  @override
  State<BiologyTopicsScreen> createState() => _BiologyTopicsScreenState();
}

class _BiologyTopicsScreenState extends State<BiologyTopicsScreen> {
  int _selectedForm = 0; // 0 = All

  static const _forms = ['All', 'Form 1', 'Form 2', 'Form 3', 'Form 4'];

  static final _coreElements = [
    const _CoreElement(
      'Research Skills',
      'Scientific Method, Observation & Laboratory Safety',
      Icons.science_rounded,
      Colors.blue,
      6, 3, 2, // total topics, quizzes, practicals
      [
        _TopicData('Biological Skills and Attitudes', 1),
        _TopicData('Use of Biological Laboratory Apparatus', 1),
        _TopicData('Use of Biological Specimens and Prepared Slides', 1),
        _TopicData('Handling and Interpreting Biological Data', 1),
        _TopicData('Biological Concepts and Structures', 1),
        _TopicData('First Aid and Safety in the Field', 3),
      ],
    ),
    const _CoreElement(
      'Environment',
      'Ecosystems, Ecology & Conservation in Malawi',
      Icons.eco_rounded,
      Colors.teal,
      6,
      3,
      2,
      [
        _TopicData('Classification of Living Organisms', 1),
        _TopicData('Ecosystems and Food Chains', 1),
        _TopicData('Ecological Relationships and Interdependence', 1),
        _TopicData('Conservation and Sustainable Use of Resources', 1),
        _TopicData('Pollution and Human Impact on the Environment', 1),
        _TopicData('Mineral Resources and Land Use', 3),
      ],
    ),
    const _CoreElement(
      'Plant Biology',
      'Structure, Nutrition, Transport & Reproduction',
      Icons.local_florist_rounded,
      _bioGreen,
      5,
      3,
      2,
      [
        _TopicData('Introduction to Plant Classification', 1),
        _TopicData('Plant Nutrition and Photosynthesis', 2),
        _TopicData('Transport in Plants', 2),
        _TopicData('Plant Reproduction and Growth', 2),
        _TopicData('Plant Responses and Adaptations', 4),
      ],
    ),
    const _CoreElement(
      'Animal Biology',
      'Classification, Structure, Coordination & Behaviour',
      Icons.pets_rounded,
      Colors.orange,
      4,
      2,
      1,
      [
        _TopicData('Introduction to Animal Classification', 1),
        _TopicData('Animal Cells and Organisation', 1),
        _TopicData('Animal Nutrition and Feeding', 1),
        _TopicData('Animal Coordination and Behaviour', 3),
      ],
    ),
    const _CoreElement(
      'Human Biology',
      'Body Systems, Health, Nutrition & Disease',
      Icons.person_rounded,
      Colors.purple,
      15,
      8,
      4,
      [
        _TopicData('Nutrition and Balanced Diet', 1),
        _TopicData('Deficiency Diseases and Disorders', 1),
        _TopicData('Circulatory System and Blood', 2),
        _TopicData('Respiratory System', 2),
        _TopicData('Excretory System', 2),
        _TopicData('Nervous and Endocrine System', 3),
        _TopicData('Skeletal and Muscular System', 1),
        _TopicData('Reproductive System', 2),
        _TopicData('Immunity and Disease', 2),
        _TopicData('Homeostasis and Coordination', 3),
        _TopicData('Growth and Development', 1),
        _TopicData('Population and Human Ecology', 1),
        _TopicData('Substance Use and Abuse', 1),
        _TopicData('Biotechnology and Human Biology', 4),
        _TopicData('Human Diseases and Health Education', 3),
      ],
    ),
    const _CoreElement(
      'Micro-organisms',
      'Roles in Disease, Food Production & Biotechnology',
      Icons.bug_report_rounded,
      Colors.red,
      4,
      2,
      1,
      [
        _TopicData('Introduction to Micro-organisms', 2),
        _TopicData('Micro-organisms in Disease', 4),
        _TopicData('Micro-organisms in Food Production', 4),
        _TopicData('Micro-organisms and Waste Management', 4),
      ],
    ),
    const _CoreElement(
      'Genetics & Evolution',
      'Inheritance, DNA, Variation & Natural Selection',
      Icons.scatter_plot_rounded,
      Colors.amber,
      6,
      4,
      2,
      [
        _TopicData('Cell Division (Mitosis and Meiosis)', 3),
        _TopicData('Mendelian Genetics', 3),
        _TopicData('DNA and the Genome', 3),
        _TopicData('Variation and Inheritance', 3),
        _TopicData('Evolution and Natural Selection', 4),
        _TopicData('Biotechnology and Genetic Engineering', 4),
      ],
    ),
  ];

  List<_CoreElement> get _filteredElements {
    if (_selectedForm == 0) return _coreElements;
    final formNum = _selectedForm;
    return _coreElements.where((ce) => ce.topics.any((t) => t.formLevel == formNum)).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F1623),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.go('/biology'),
          ),
          title: const Row(
            children: [
              Icon(Icons.book_rounded, color: _bioGreen, size: 22),
              SizedBox(width: 10),
              Text('Biology Topics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _bioGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _bioGreen.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_rounded, color: _bioGreen, size: 14),
                  SizedBox(width: 4),
                  Text('374 Topics', style: TextStyle(color: _bioGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFormTabs(),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredElements.length,
                itemBuilder: (_, i) => _buildCoreElementCard(_filteredElements[i]),
              ),
            ),
          ],
        ),
      );

  Widget _buildFormTabs() => Container(
        height: 48,
        color: const Color(0xFF0F1623),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: _forms.length,
          itemBuilder: (_, i) {
            final selected = _selectedForm == i;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(_forms[i], style: const TextStyle(fontSize: 13)),
                selected: selected,
                onSelected: (_) => setState(() => _selectedForm = i),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                selectedColor: _bioGreen,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          },
        ),
      );

  Widget _buildCoreElementCard(_CoreElement ce) {
    final filteredTopics =
        _selectedForm == 0 ? ce.topics : ce.topics.where((t) => t.formLevel == _selectedForm).toList();
    final completedCount = (filteredTopics.length * 0.4).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ce.color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ce.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(ce.icon, color: ce.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ce.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(ce.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    ],
                  ),
                ),
                _buildProgressRing(completedCount, filteredTopics.length, ce.color),
              ],
            ),
          ),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
              ),
            ),
            child: Row(
              children: [
                _stat('${filteredTopics.length}', 'Topics', ce.color),
                const SizedBox(width: 20),
                _stat('${ce.quizzes}', 'Quizzes', Colors.blue),
                const SizedBox(width: 20),
                _stat('${ce.practicals}', 'Practicals', Colors.orange),
                const Spacer(),
                Text(
                  '${(completedCount / filteredTopics.length * 100).toInt()}% complete',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
              ],
            ),
          ),
          // Topics list
          ...filteredTopics.map((t) => _buildTopicTile(t, ce.color)),
        ],
      ),
    );
  }

  Widget _buildTopicTile(_TopicData topic, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'F${topic.formLevel}',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.2), size: 20),
          ],
        ),
      );

  Widget _buildProgressRing(int completed, int total, Color color) {
    final progress = total > 0 ? completed / total : 0.0;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        ],
      );
}

class _CoreElement {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int totalTopics;
  final int quizzes;
  final int practicals;
  final List<_TopicData> topics;

  const _CoreElement(
    this.name,
    this.description,
    this.icon,
    this.color,
    this.totalTopics,
    this.quizzes,
    this.practicals,
    this.topics,
  );
}

class _TopicData {
  final String name;
  final int formLevel;

  const _TopicData(this.name, this.formLevel);
}
