import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_colors.dart';

const Color _bioGreen = Color(0xFF10B981);
const Color _bioGreenGlow = Color(0x2210B981);

class BiologyDiagramCentreScreen extends StatefulWidget {
  const BiologyDiagramCentreScreen({super.key});

  @override
  State<BiologyDiagramCentreScreen> createState() => _BiologyDiagramCentreScreenState();
}

class _BiologyDiagramCentreScreenState extends State<BiologyDiagramCentreScreen> {
  bool _hideLabels = false;
  bool _testMode = false;
  int? _selectedDiagram;

  static final _diagrams = [
    const _BioDiagram(
        'Plant Cell',
        'cell-plant',
        Icons.grid_view_rounded,
        [
          'Cell wall',
          'Cell membrane',
          'Nucleus',
          'Cytoplasm',
          'Chloroplasts',
          'Vacuole',
          'Mitochondria',
          'Ribosomes',
          'Endoplasmic reticulum',
          'Golgi apparatus'
        ],
        0.85),
    const _BioDiagram(
        'Animal Cell',
        'cell-animal',
        Icons.blur_circular_rounded,
        [
          'Cell membrane',
          'Nucleus',
          'Cytoplasm',
          'Mitochondria',
          'Ribosomes',
          'Endoplasmic reticulum',
          'Golgi apparatus',
          'Lysosomes',
          'Centrioles'
        ],
        0.72),
    const _BioDiagram('Bacterial Cell', 'cell-bacteria', Icons.scatter_plot_rounded,
        ['Cell wall', 'Cell membrane', 'Capsule', 'Nucleoid (DNA)', 'Ribosomes', 'Flagellum', 'Pili', 'Plasmid'], 0.50),
    const _BioDiagram(
        'Human Heart',
        'heart',
        Icons.favorite_rounded,
        [
          'Right atrium',
          'Left atrium',
          'Right ventricle',
          'Left ventricle',
          'Aorta',
          'Pulmonary artery',
          'Vena cava',
          'Pulmonary veins',
          'Septum',
          'Tricuspid valve',
          'Bicuspid valve'
        ],
        0.30),
    const _BioDiagram(
        'Digestive System',
        'digestive',
        Icons.restaurant_rounded,
        [
          'Mouth',
          'Oesophagus',
          'Stomach',
          'Small intestine',
          'Large intestine',
          'Rectum',
          'Liver',
          'Gall bladder',
          'Pancreas',
          'Salivary glands'
        ],
        0.45),
    const _BioDiagram('Respiratory System', 'respiratory', Icons.air_rounded,
        ['Nasal cavity', 'Trachea', 'Bronchi', 'Lungs', 'Alveoli', 'Diaphragm', 'Bronchioles', 'Epiglottis'], 0.20),
    const _BioDiagram(
        'Kidney (Nephron)',
        'nephron',
        Icons.water_drop_rounded,
        [
          'Bowman\'s capsule',
          'Glomerulus',
          'Proximal convoluted tubule',
          'Loop of Henle',
          'Distal convoluted tubule',
          'Collecting duct',
          'Renal artery',
          'Renal vein'
        ],
        0.10),
    const _BioDiagram(
        'Neuron',
        'neuron',
        Icons.psychology_rounded,
        [
          'Cell body (soma)',
          'Dendrites',
          'Axon',
          'Myelin sheath',
          'Node of Ranvier',
          'Schwann cell',
          'Axon terminals',
          'Synapse'
        ],
        0.05),
    const _BioDiagram(
        'Human Eye',
        'eye',
        Icons.visibility_rounded,
        [
          'Cornea',
          'Iris',
          'Pupil',
          'Lens',
          'Retina',
          'Optic nerve',
          'Sclera',
          'Ciliary muscle',
          'Vitreous humour',
          'Blind spot'
        ],
        0.15),
    const _BioDiagram(
        'Flower Structure',
        'flower',
        Icons.local_florist_rounded,
        ['Petal', 'Sepal', 'Stamen (anther + filament)', 'Stigma', 'Style', 'Ovary', 'Ovule', 'Receptacle', 'Pedicel'],
        0.0),
    const _BioDiagram(
        'Leaf Structure',
        'leaf',
        Icons.eco_rounded,
        [
          'Upper epidermis',
          'Palisade mesophyll',
          'Spongy mesophyll',
          'Lower epidermis',
          'Stomata',
          'Guard cells',
          'Xylem',
          'Phloem',
          'Cuticle',
          'Veins'
        ],
        0.0),
    const _BioDiagram(
        'Root Tip',
        'root',
        Icons.vertical_split_rounded,
        [
          'Root cap',
          'Meristematic zone',
          'Zone of elongation',
          'Zone of differentiation',
          'Root hair cells',
          'Vascular bundle',
          'Cortex',
          'Epidermis'
        ],
        0.0),
    const _BioDiagram('Xylem and Phloem', 'vascular', Icons.water_rounded,
        ['Xylem vessels', 'Phloem sieve tubes', 'Companion cells', 'Cambium', 'Vascular bundle', 'Bark'], 0.10),
    const _BioDiagram('Male Reproductive System', 'reproductive-male', Icons.male_rounded,
        ['Testes', 'Epididymis', 'Vas deferens', 'Seminal vesicle', 'Prostate gland', 'Urethra', 'Penis'], 0.0),
    const _BioDiagram('Female Reproductive System', 'reproductive-female', Icons.female_rounded,
        ['Ovaries', 'Fallopian tubes', 'Uterus', 'Cervix', 'Vagina', 'Endometrium', 'Ovum'], 0.0),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          _buildHeader(),
          if (_selectedDiagram != null) _buildDiagramViewer(),
          Expanded(
            child: _selectedDiagram == null ? _buildDiagramGrid(isDesktop) : _buildDiagramDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_selectedDiagram != null) {
                    setState(() => _selectedDiagram = null);
                  } else {
                    context.go('/stem-subject/biology');
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.colors.textSecondary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(_selectedDiagram != null ? _diagrams[_selectedDiagram!].name : 'Diagram Centre',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.3)),
              ),
              if (_selectedDiagram != null) ...[
                _buildModeChip('Labels', !_hideLabels, () {
                  setState(() => _hideLabels = !_hideLabels);
                }),
                const SizedBox(width: 8),
                _buildModeChip('Test', _testMode, () {
                  setState(() => _testMode = !_testMode);
                }),
              ],
            ],
          ),
        ),
      );

  Widget _buildModeChip(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _bioGreen.withValues(alpha: 0.12) : context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? _bioGreen.withValues(alpha: 0.3) : context.colors.border,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: active ? _bioGreen : context.colors.textMuted)),
        ),
      );

  Widget _buildDiagramViewer() {
    final diagram = _diagrams[_selectedDiagram!];
    return Container(
      width: double.infinity,
      height: 280,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(diagram.icon, size: 80, color: _bioGreen.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                if (_testMode)
                  ...diagram.labels.take(3).map((label) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _bioGreenGlow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Tap the position of: $label',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _bioGreen)),
                        ),
                      ))
                else if (!_hideLabels)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: diagram.labels
                        .map((label) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _bioGreenGlow,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(label,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _bioGreen)),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                _buildViewerAction(Icons.zoom_in_rounded, () {}),
                const SizedBox(width: 6),
                _buildViewerAction(Icons.zoom_out_rounded, () {}),
                const SizedBox(width: 6),
                _buildViewerAction(Icons.fullscreen_rounded, () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerAction(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.border),
          ),
          child: Icon(icon, size: 16, color: context.colors.textSecondary),
        ),
      );

  Widget _buildDiagramGrid(bool isDesktop) => GridView.builder(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 4 : 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _diagrams.length,
        itemBuilder: (ctx, i) => _buildDiagramCard(i),
      );

  Widget _buildDiagramCard(int index) {
    final d = _diagrams[index];
    final color = d.progress >= 0.8
        ? context.colors.success
        : d.progress > 0
            ? _bioGreen
            : context.colors.textMuted;

    return Semantics(
      button: true,
      label: d.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _selectedDiagram = index),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(d.icon, size: 32, color: _bioGreen.withValues(alpha: 0.6)),
                const SizedBox(height: 10),
                Text(d.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                const SizedBox(height: 6),
                Text('${d.labels.length} labels', style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: d.progress,
                  backgroundColor: context.colors.surfaceHighest,
                  color: color,
                  minHeight: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagramDetails() {
    final d = _diagrams[_selectedDiagram!];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Labels', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: d.labels
              .map((label) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _bioGreenGlow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(label,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _bioGreen)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _testMode = !_testMode),
                icon: const Icon(Icons.quiz_rounded, size: 18),
                label: const Text('Test Yourself'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _bioGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _hideLabels = !_hideLabels),
                icon: Icon(_hideLabels ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
                label: Text(_hideLabels ? 'Show Labels' : 'Hide Labels'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _bioGreen,
                  side: BorderSide(color: context.colors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mastery Progress',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: d.progress,
                backgroundColor: context.colors.surfaceHighest,
                color: _bioGreen,
                minHeight: 6,
              ),
              const SizedBox(height: 6),
              Text('${(d.progress * 100).toInt()}% of labels mastered',
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BioDiagram {
  final String name;
  final String id;
  final IconData icon;
  final List<String> labels;
  final double progress;
  const _BioDiagram(this.name, this.id, this.icon, this.labels, this.progress);
}
