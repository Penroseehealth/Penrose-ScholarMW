import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

const Color _bioGreen = Color(0xFF10B981);
const Color _bioGreenDark = Color(0xFF059669);
const Color _bioGreenGlow = Color(0x2210B981);

class BiologyTopicsScreen extends StatefulWidget {
  const BiologyTopicsScreen({super.key});

  @override
  State<BiologyTopicsScreen> createState() => _BiologyTopicsScreenState();
}

class _BiologyTopicsScreenState extends State<BiologyTopicsScreen> {
  int? _expandedChapter;

  static final _chapters = [
    _Chapter(
      1,
      'Introduction to Biology',
      Icons.eco_rounded,
      [
        'What is Biology?',
        'Characteristics of Living Organisms',
        'Classification of Organisms',
        'Scientific Naming (Binomial Nomenclature)',
        'Kingdoms of Organisms',
        'Biodiversity',
        'Adaptations',
        'Scientific Investigation',
        'Laboratory Safety',
      ],
      0.85,
    ),
    _Chapter(
      2,
      'Cell Biology',
      Icons.biotech_rounded,
      [
        'Cell Theory',
        'Plant Cells',
        'Animal Cells',
        'Prokaryotic and Eukaryotic Cells',
        'Cell Organelles',
        'Structure and Function of Organelles',
        'Cell Specialization',
        'Microscopy',
        'Magnification and Calculations',
        'Drawing Biological Specimens',
        'Cell Size',
      ],
      0.72,
    ),
    _Chapter(
      3,
      'Movement of Substances',
      Icons.water_drop_rounded,
      [
        'Diffusion',
        'Osmosis',
        'Active Transport',
        'Concentration Gradients',
        'Partially Permeable Membranes',
        'Effects of Solutions on Cells',
      ],
      0.60,
    ),
    _Chapter(
      4,
      'Nutrition',
      Icons.restaurant_rounded,
      [
        'Nutrients — Carbohydrates, Proteins, Lipids',
        'Vitamins and Minerals',
        'Water and Balanced Diet',
        'Deficiency Diseases',
        'Human Digestive System',
        'Digestion and Enzymes',
        'Absorption and Assimilation',
        'Plant Nutrition — Photosynthesis',
        'Chloroplast Structure',
        'Requirements and Limiting Factors',
        'Leaf Adaptations for Photosynthesis',
        'Mineral Requirements (Nitrogen, Magnesium)',
      ],
      0.45,
    ),
    _Chapter(
      5,
      'Transport',
      Icons.bloodtype_rounded,
      [
        'Blood — Components and Functions',
        'Red Blood Cells, White Blood Cells, Platelets, Plasma',
        'Blood Groups',
        'Heart Structure',
        'Double Circulation',
        'Arteries, Veins, Capillaries',
        'Transport in Plants — Xylem and Phloem',
        'Transpiration and Translocation',
        'Root Hair Cells and Water Uptake',
      ],
      0.30,
    ),
    _Chapter(
      6,
      'Gaseous Exchange & Respiration',
      Icons.air_rounded,
      [
        'Breathing Mechanism',
        'Human Respiratory System',
        'Gas Exchange in Alveoli',
        'Adaptations for Gas Exchange',
        'Aerobic Respiration',
        'Anaerobic Respiration',
        'Energy Release',
        'Word and Chemical Equations',
        'Comparison of Aerobic and Anaerobic Respiration',
      ],
      0.20,
    ),
    _Chapter(
      7,
      'Excretion & Homeostasis',
      Icons.monitor_heart_rounded,
      [
        'Excretory Products',
        'Kidney Structure and Function',
        'The Nephron',
        'Urine Formation',
        'Osmoregulation',
        'Temperature Regulation',
        'Blood Glucose Regulation',
        'Homeostasis Principles',
      ],
      0.10,
    ),
    _Chapter(
      8,
      'Coordination & Response',
      Icons.psychology_rounded,
      [
        'Nervous System Overview',
        'Neurons — Structure and Types',
        'Reflex Actions and Reflex Arc',
        'Synapses',
        'The Brain',
        'The Spinal Cord',
        'Sense Organs — The Eye',
        'Hormones and the Endocrine System',
        'Tropisms in Plants',
      ],
      0.05,
    ),
    _Chapter(
      9,
      'Reproduction',
      Icons.child_care_rounded,
      [
        'Male Reproductive System',
        'Female Reproductive System',
        'Gametes — Sperm and Ovum',
        'Menstrual Cycle',
        'Fertilization and Pregnancy',
        'Development and Birth',
        'Flower Structure',
        'Pollination and Fertilization in Plants',
        'Seed Formation and Dispersal',
        'Germination',
      ],
      0.0,
    ),
    _Chapter(
      10,
      'Genetics & Inheritance',
      Icons.science_rounded,
      [
        'DNA — Structure and Function',
        'Genes and Chromosomes',
        'Alleles — Dominant and Recessive',
        'Genotype and Phenotype',
        'Punnett Squares',
        'Monohybrid Inheritance',
        'Sex Determination',
        'Variation',
        'Mutation',
      ],
      0.0,
    ),
    _Chapter(
      11,
      'Ecology',
      Icons.park_rounded,
      [
        'Organisms and Environment',
        'Habitat, Population, Community, Ecosystem',
        'Food Chains and Food Webs',
        'Trophic Levels and Energy Flow',
        'Carbon Cycle',
        'Nitrogen Cycle',
        'Water Cycle',
        'Population Growth',
        'Competition and Predation',
        'Adaptation',
      ],
      0.0,
    ),
    _Chapter(
      12,
      'Microorganisms',
      Icons.bug_report_rounded,
      [
        'Bacteria — Structure and Types',
        'Viruses',
        'Fungi',
        'Protoctists / Protozoa',
        'Useful Microorganisms',
        'Harmful Microorganisms',
        'Disease Transmission',
        'Prevention of Infection',
        'Food Preservation',
        'Biotechnology Basics',
      ],
      0.0,
    ),
    _Chapter(
      13,
      'Disease & Immunity',
      Icons.vaccines_rounded,
      [
        'Communicable Diseases',
        'Non-communicable Diseases',
        'Pathogens — Bacteria, Viruses, Protozoa, Fungi',
        'Transmission Routes',
        'Prevention Methods',
        'Immune Response',
        'Vaccination and Immunization',
        'Case Study: Malaria in Malawi',
        'Case Study: Cholera',
        'Case Study: Tuberculosis',
        'Case Study: HIV/AIDS',
        'Case Study: Bilharzia',
      ],
      0.0,
    ),
    _Chapter(
      14,
      'Environment & Conservation',
      Icons.forest_rounded,
      [
        'Pollution — Air, Water, Soil',
        'Deforestation',
        'Climate Change',
        'Habitat Destruction',
        'Conservation Strategies',
        'Biodiversity Preservation',
        'Sustainable Resource Use',
        'Lake Malawi Ecosystem',
        'Forest Conservation in Malawi',
        'Soil Erosion and Prevention',
      ],
      0.0,
    ),
    _Chapter(
      15,
      'Practical Skills',
      Icons.science_rounded,
      [
        'Microscope Skills — Use and Care',
        'Biological Drawings — Rules and Standards',
        'Magnification Calculations',
        'Food Tests — Starch, Protein, Lipid, Sugar',
        'Osmosis Experiments',
        'Enzyme Experiments',
        'Photosynthesis Investigations',
        'Respiration Experiments',
        'Transpiration Setup',
        'Ecology Fieldwork — Quadrats and Transects',
        'Sampling Techniques',
        'Experimental Design and Variables',
      ],
      0.15,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16, vertical: 20),
              itemCount: _chapters.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) return _buildOverviewBanner();
                final ch = _chapters[i - 1];
                return _buildChapterCard(ch);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.go('/stem-subject/biology'),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Topics & Syllabus',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3)),
                  Text('MSCE Biology — 15 Chapters',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewBanner() {
    final totalTopics = _chapters.fold<int>(0, (a, ch) => a + ch.topics.length);
    final completedChapters =
        _chapters.where((ch) => ch.progress >= 0.8).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _bioGreen.withValues(alpha: 0.1),
            _bioGreenDark.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bioGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MSCE Biology Syllabus',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(
                    '$totalTopics topics across ${_chapters.length} chapters  •  $completedChapters mastered',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _bioGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('View All',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _bioGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(_Chapter ch) {
    final isExpanded = _expandedChapter == ch.number;
    final color = ch.progress >= 0.8
        ? AppColors.success
        : ch.progress >= 0.4
            ? _bioGreen
            : ch.progress > 0
                ? AppColors.warning
                : AppColors.textMuted;

    return Semantics(
      label: 'Chapter ${ch.number}: ${ch.name}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded ? _bioGreen.withValues(alpha: 0.3) : AppColors.border,
            width: isExpanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _expandedChapter = isExpanded ? null : ch.number;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(ch.icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('${ch.number}.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(ch.name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('${ch.topics.length} topics',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: ch.progress,
                                    backgroundColor: AppColors.surfaceHighest,
                                    color: color,
                                    minHeight: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${(ch.progress * 100).toInt()}%',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildTopicList(ch),
              crossFadeState:
                  isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicList(_Chapter ch) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        children: ch.topics.asMap().entries.map((entry) {
          final i = entry.key;
          final topic = entry.value;
          final topicProgress = ch.progress > 0
              ? (i / ch.topics.length < ch.progress ? 1.0 : 0.0)
              : 0.0;
          final statusColor = topicProgress >= 1.0
              ? AppColors.success
              : topicProgress > 0
                  ? _bioGreen
                  : AppColors.textMuted.withValues(alpha: 0.4);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go(
                    '/stem-topic/${ch.number}-${i + 1}?title=$topic'),
                child: Row(
                  children: [
                    Icon(
                      topicProgress >= 1.0
                          ? Icons.check_circle_rounded
                          : topicProgress > 0
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(topic,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: topicProgress >= 1.0
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary)),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Chapter {
  final int number;
  final String name;
  final IconData icon;
  final List<String> topics;
  final double progress;
  const _Chapter(this.number, this.name, this.icon, this.topics, this.progress);
}
