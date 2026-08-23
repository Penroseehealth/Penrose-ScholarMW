import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

const Color _bioGreen = Color(0xFF10B981);
const Color _bioGreenDark = Color(0xFF059669);
const Color _bioGreenGlow = Color(0x2210B981);

class BiologyVirtualLabScreen extends StatefulWidget {
  BiologyVirtualLabScreen({super.key});

  @override
  State<BiologyVirtualLabScreen> createState() => _BiologyVirtualLabScreenState();
}

class _BiologyVirtualLabScreenState extends State<BiologyVirtualLabScreen> {
  int? _expandedLab;

  static final _experiments = [
    _VirtualLab(
      'Osmosis in Potato Strips',
      'Investigate how concentration affects water movement in plant cells',
      Icons.water_drop_rounded,
      ['Beaker', 'Potato strips', 'Salt solution (various concentrations)', 'Ruler', 'Knife', 'Weighing balance'],
      ['Cut potato into equal-sized strips', 'Weigh each strip', 'Place in different salt solutions (0%, 5%, 10%, 15%, 20%)', 'Leave for 30 minutes', 'Remove and blot dry', 'Reweigh each strip'],
      {'0% distilled water': 'Strip gains mass — water enters cells by osmosis', '5% salt solution': 'Slight gain — less water potential difference', '10% salt solution': 'Little change — isotonic', '15% salt solution': 'Slight mass loss — water leaves cells', '20% salt solution': 'Significant mass loss — cells become plasmolysed'},
      'Higher salt concentration causes more water to leave potato cells by osmosis, resulting in greater mass loss.',
      'Osmosis',
    ),
    _VirtualLab(
      'Photosynthesis — Light Intensity',
      'How does light intensity affect the rate of photosynthesis?',
      Icons.light_mode_rounded,
      ['Aquatic plant (Elodea)', 'Test tube', 'Bicarbonate solution', 'Lamp', 'Ruler', 'Stopwatch'],
      ['Place Elodea in test tube with bicarbonate solution', 'Position lamp at 10 cm from test tube', 'Count oxygen bubbles for 5 minutes', 'Move lamp to 20 cm, repeat', 'Move lamp to 30 cm, repeat', 'Record results in table'],
      {'10 cm': 'Highest bubble count — maximum light intensity', '20 cm': 'Moderate bubble count — reduced light intensity', '30 cm': 'Lowest bubble count — lowest light intensity'},
      'Rate of photosynthesis increases with light intensity. Doubling light intensity approximately doubles the rate.',
      'Photosynthesis',
    ),
    _VirtualLab(
      'Enzyme Activity — Temperature',
      'How does temperature affect enzyme-controlled reactions?',
      Icons.thermostat_rounded,
      ['Amylase solution', 'Starch solution', 'Iodine solution', 'Test tubes', 'Water baths', 'Stopwatch', 'Spotting tile'],
      ['Set up water baths at 0°C, 20°C, 40°C, 60°C, 80°C', 'Mix amylase + starch at each temperature', 'Test for starch every 30 seconds using iodine', 'Record time for starch to disappear', 'Graph time vs temperature'],
      {'0°C': 'Very slow — enzymes have low kinetic energy', '20°C': 'Moderate — enzyme activity increasing', '40°C': 'Fastest — near optimal temperature (37°C for human amylase)', '60°C': 'Very slow — enzymes beginning to denature', '80°C': 'No activity — enzymes completely denatured'},
      'Enzyme activity increases with temperature up to an optimum, then rapidly decreases as enzymes denature.',
      'Enzymes',
    ),
    _VirtualLab(
      'Virtual Microscope — Cell Observation',
      'Observe plant and animal cells under different magnifications',
      Icons.science_rounded,
      ['Virtual microscope', 'Prepared slides (onion epidermis, cheek cells)', 'Staining solution'],
      ['Select onion epidermis slide', 'Start with low power (×40)', 'Focus using coarse then fine adjustment', 'Switch to medium power (×100)', 'Switch to high power (×400)', 'Observe and draw cell structures', 'Repeat with cheek cell slide'],
      {'×40 (low power)': 'Shows general cell layout and tissue arrangement', '×100 (medium power)': 'Individual cells visible, nucleus and cell wall clear', '×400 (high power)': 'Detailed organelles visible — nucleus, cell wall, cytoplasm'},
      'Plant cells (onion) have rigid cell walls, large vacuoles, and regular shapes. Animal cells (cheek) are irregular, smaller, and lack cell walls.',
      'Microscopy',
    ),
    _VirtualLab(
      'Diffusion — Potassium Permanganate',
      'Observe diffusion in water at different temperatures',
      Icons.science_rounded,
      ['Beakers of water', 'Potassium permanganate crystals', 'Thermometer', 'Stopwatch'],
      ['Set up 3 beakers: cold, room temp, hot water', 'Drop one crystal in each beaker simultaneously', 'Time how long for colour to spread', 'Record distance of colour spread every 2 minutes', 'Compare rates across temperatures'],
      {'Cold water': 'Slow spread — low kinetic energy, slow diffusion', 'Room temperature': 'Moderate spread — medium kinetic energy', 'Hot water': 'Fast spread — high kinetic energy, rapid diffusion'},
      'Diffusion rate increases with temperature because molecules have more kinetic energy and move faster.',
      'Diffusion',
    ),
    _VirtualLab(
      'Respiration in Germinating Seeds',
      'Demonstrate that germinating seeds respire by producing CO₂',
      Icons.air_rounded,
      ['Germinating seeds', 'Dry seeds (control)', 'Conical flasks', 'Lime water', 'Vaseline', 'Delivery tube'],
      ['Place germinating seeds in flask A, dry seeds in flask B', 'Connect each flask to test tube of lime water via delivery tube', 'Seal flask connections with Vaseline', 'Leave for 24 hours', 'Observe lime water in each test tube'],
      {'Flask A (germinating)': 'Lime water turns milky — CO₂ produced by respiration', 'Flask B (dry seeds)': 'Lime water stays clear — no significant respiration'},
      'Germinating seeds respire actively, releasing CO₂. Dry seeds respire very slowly because they are dormant.',
      'Respiration',
    ),
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
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16, vertical: 20),
              itemCount: _experiments.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) return _buildIntroBanner();
                return _buildExperimentCard(_experiments[i - 1], i - 1);
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
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
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
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.border),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: context.colors.textSecondary),
              ),
            ),
            SizedBox(width: 14),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _bioGreenGlow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.science_rounded, color: _bioGreen, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Virtual Biology Lab',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                          letterSpacing: -0.3)),
                  Text('Interactive experiments',
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          _bioGreen.withValues(alpha: 0.1),
          _bioGreenDark.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bioGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _bioGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.science_rounded, color: _bioGreen, size: 26),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Virtual Experiments',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary)),
                SizedBox(height: 4),
                Text(
                    '${_experiments.length} experiments covering diffusion, osmosis, photosynthesis, enzymes, and more.',
                    style: TextStyle(
                        fontSize: 12, color: context.colors.textMuted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperimentCard(_VirtualLab lab, int index) {
    final isExpanded = _expandedLab == index;
    final topicColors = {
      'Osmosis': context.colors.info,
      'Photosynthesis': context.colors.success,
      'Enzymes': context.colors.warning,
      'Microscopy': context.colors.secondary,
      'Diffusion': context.colors.accent,
      'Respiration': context.colors.error,
    };
    final accentColor = topicColors[lab.topic] ?? _bioGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? accentColor.withValues(alpha: 0.3) : context.colors.border,
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandedLab = isExpanded ? null : index),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(lab.icon, color: accentColor, size: 22),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lab.title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary)),
                        SizedBox(height: 3),
                        Text(lab.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: context.colors.textMuted)),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(lab.topic,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: accentColor)),
                  ),
                  SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: context.colors.textMuted, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildLabDetail(lab, accentColor),
            crossFadeState:
                isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildLabDetail(_VirtualLab lab, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabSection('Apparatus Required', lab.apparatus, Icons.build_rounded, accent),
          SizedBox(height: 14),
          _buildLabSection('Method', lab.method, Icons.format_list_numbered_rounded, accent),
          SizedBox(height: 14),
          _buildResultsSection(lab.results, accent),
          SizedBox(height: 14),
          _buildLabSection('Observations', [lab.observations], Icons.insights_rounded, accent),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.play_arrow_rounded, size: 20),
              label: Text('Start Simulation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabSection(String title, List<String> items, IconData icon, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accent),
            SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent)),
          ],
        ),
        SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(
                        color: context.colors.textMuted, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(item,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                            height: 1.4)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildResultsSection(Map<String, String> results, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.table_chart_rounded, size: 14, color: accent),
            SizedBox(width: 6),
            Text('Results',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent)),
          ],
        ),
        SizedBox(height: 8),
        ...results.entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(e.key,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary)),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(e.value,
                        style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textSecondary)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _VirtualLab {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> apparatus;
  final List<String> method;
  final Map<String, String> results;
  final String observations;
  final String topic;
  const _VirtualLab(this.title, this.subtitle, this.icon, this.apparatus,
      this.method, this.results, this.observations, this.topic);
}
