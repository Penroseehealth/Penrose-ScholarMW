import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

const Color _bioGreen = Color(0xFF10B981);
const Color _bioGreenDark = Color(0xFF059669);
const Color _bioGreenGlow = Color(0x2210B981);

class BiologyPracticalHubScreen extends StatefulWidget {
  const BiologyPracticalHubScreen({super.key});

  @override
  State<BiologyPracticalHubScreen> createState() =>
      _BiologyPracticalHubScreenState();
}

class _BiologyPracticalHubScreenState extends State<BiologyPracticalHubScreen> {
  int? _expandedPractical;

  static final _practicals = [
    _Practical(
      1,
      'Using a Light Microscope',
      'Microscope Skills',
      'Learn to set up, focus, and care for a light microscope.',
      'To observe onion epidermis cells at different magnifications.',
      'If cells are visible under a light microscope, then magnification reveals structures not visible to the naked eye.',
      ['Light microscope', 'Onion epidermis slide', 'Lens paper', 'Distilled water spray'],
      ['Carry microscope with two hands. Start on lowest power. Use coarse focus first, then fine focus. Never force the focus knobs.'],
      ['Place slide on stage and secure with clips', 'Select lowest objective lens (×4)', 'Look through eyepiece and adjust coarse focus knob', 'Switch to medium power (×10) and refocus with fine adjustment', 'Switch to high power (×40) and fine focus only', 'Observe cell wall, nucleus, cytoplasm'],
      ['Magnification = eyepiece × objective', 'Total magnification at each step: ×40, ×100, ×400'],
      'Onion cells show clear cell walls, nuclei stained with iodine, and cytoplasm. Higher magnification reveals more detail but smaller field of view.',
      'The hypothesis is supported: magnification reveals cellular structures invisible to the naked eye. Mastery of microscope technique is essential for all cell biology practicals.',
      '2/5',
    ),
    _Practical(
      2,
      'Biological Drawing of Cells',
      'Biological Drawings',
      'Follow the rules for making accurate biological drawings.',
      'To produce a labelled biological drawing of an onion cell.',
      'A correctly drawn biological diagram accurately represents the specimen with proper labelling.',
      ['Sharp pencil (HB/2H)', 'Eraser', 'Ruler', 'Onion epidermis slide', 'Microscope'],
      ['Observe specimen carefully before drawing', 'Draw using sharp pencil only', 'Use smooth, continuous lines — never sketch', 'Show true proportions and detail', 'Do NOT shade — use stippling if needed', 'Draw a title below the drawing', 'Label with horizontal lines on the RIGHT side using a ruler'],
      ['Select and focus specimen under microscope', 'Draw what you SEE, not what you know', 'Draw the outline first, then add detail', 'Add labels with ruler — right side only', 'Write title and magnification below'],
      ['Drawing size: at least 8 cm wide', 'Lines must be sharp and continuous', 'All labels must be horizontal and on right', 'Include magnification notation'],
      'A well-labelled biological drawing accurately represents the specimen with correct proportions, smooth lines, and proper labels.',
      'Good biological drawings are accurate, clear, and properly labelled. They differ from artistic drawings.',
      '0/5',
    ),
    _Practical(
      3,
      'Food Tests',
      'Nutrition',
      'Test for the presence of starch, protein, lipids, and reducing sugars.',
      'To identify the nutrient content of various food samples.',
      'Specific chemical reagents produce colour changes that indicate the presence of particular nutrients.',
      ['Test tubes and rack', 'Food samples (bread, egg, oil, sugar)', 'Iodine solution', "Benedict's solution", 'Biuret reagent', 'Ethanol', 'Water bath', 'Spotting tile'],
      ['Starch test: Add iodine solution. Blue-black = starch present.', 'Reducing sugar test: Add Benedict\'s solution and heat in water bath. Brick red = sugar present.', 'Protein test: Add Biuret reagent. Purple = protein present.', 'Lipid test: Dissolve in ethanol, add to water. White emulsion = lipids present.'],
      ['Prepare food samples — mash or dissolve in water', 'Label test tubes clearly', 'Follow each test procedure carefully', 'Record colour changes', 'Compare results with known standards'],
      ['Record results in a table: food sample, test performed, colour change, conclusion', 'Draw a table with columns for each nutrient'],
      'Colour changes confirm the presence of specific nutrients: iodine-black for starch, Benedict\'s-brick red for sugar, Biuret-purple for protein, ethanol emulsion for lipids.',
      'Food tests use simple chemical reactions. Iodine for starch, Benedict\'s for sugar, Biuret for protein, ethanol emulsion test for lipids.',
      '2/5',
    ),
    _Practical(
      4,
      'Osmosis — Potato Strip Investigation',
      'Movement of Substances',
      'Investigate the effect of salt concentration on potato tissue.',
      'To determine the effect of different salt concentrations on potato strips.',
      'Potato strips placed in hypertonic solutions will lose mass by osmosis; those in hypotonic solutions will gain mass.',
      ['Potato', 'Cork borer', 'Ruler', 'Knife', '5 beakers', 'Salt solutions (0-20%)', 'Weighing balance', 'Paper towels'],
      ['Cut 5 equal potato strips using cork borer', 'Measure and record initial mass of each', 'Prepare salt solutions: 0%, 5%, 10%, 15%, 20%', 'Place one strip in each solution', 'Leave for 30 minutes', 'Remove strips, blot dry, reweigh'],
      ['Set up concentration range (0-20%)', 'Ensure fair test — same potato, same size, same time', 'Record initial and final mass', 'Calculate percentage change in mass', 'Plot graph of % mass change vs concentration'],
      ['Tabulate: concentration, initial mass, final mass, mass change, % change', 'Draw graph with concentration on x-axis, % mass change on y-axis', 'Mark the point where line crosses x-axis = isotonic point'],
      'Results show mass gain in dilute solutions and mass loss in concentrated solutions, confirming osmosis across cell membranes.',
      'Osmosis causes water movement across partially permeable membranes. The isotonic point shows where no net movement occurs.',
      '1/5',
    ),
    _Practical(
      5,
      'Enzyme Activity — Effect of Temperature',
      'Enzymes',
      'Investigate how temperature affects the rate of enzyme-controlled reactions.',
      'To determine the optimum temperature for amylase activity.',
      'Amylase works best near body temperature (37°C) and is denatured at high temperatures.',
      ['Amylase solution', 'Starch solution', 'Iodine solution', 'Water baths (0°C, 20°C, 40°C, 60°C, 80°C)', 'Test tubes', 'Spotting tile', 'Stopwatch'],
      ['Set up water baths at 5 different temperatures', 'Mix equal volumes of amylase and starch at each temperature', 'Test for starch every 30 seconds using iodine on spotting tile', 'Record time for starch to completely disappear', 'Repeat at each temperature'],
      ['Independent: temperature', 'Dependent: time for starch to disappear', 'Controlled: volumes, concentrations, same amylase source', 'Repeat 3 times at each temperature for reliability'],
      ['Record time at each temperature', 'Calculate average time', 'Plot graph: rate (1/time) vs temperature', 'Identify optimum temperature', 'Explain denaturation at high temperatures'],
      'The optimum temperature for amylase is near 37°C. At 80°C, denaturation permanently destroys enzyme activity.',
      'Enzymes have an optimum temperature. Below this, molecules move slowly. Above this, the enzyme denatures and loses its shape.',
      '0/5',
    ),
    _Practical(
      6,
      'Photosynthesis — Investigating Light',
      'Photosynthesis',
      'Use aquatic plants to measure photosynthesis rate under different conditions.',
      'To investigate the effect of light intensity on the rate of photosynthesis.',
      'Increasing light intensity increases the rate of photosynthesis (until another factor becomes limiting).',
      ['Elodea (pond weed)', 'Test tube', 'Bicarbonate solution', 'Lamp with variable brightness', 'Ruler', 'Stopwatch', 'Thermometer'],
      ['Place Elodea in test tube with bicarbonate solution', 'Position lamp at measured distances (5cm, 10cm, 15cm, 20cm)', 'Allow 2 minutes to equilibrate', 'Count oxygen bubbles released for 5 minutes at each distance', 'Record and repeat'],
      ['Independent: light intensity (distance of lamp)', 'Dependent: number of bubbles per minute', 'Controlled: temperature, volume of bicarbonate, same plant'],
      ['Record bubble count at each distance', 'Calculate average bubbles per minute', 'Plot graph: bubbles/min vs 1/distance² (relative light intensity)'],
      'Bubble count increases as lamp distance decreases, confirming that higher light intensity increases photosynthesis rate.',
      'Light provides energy for photosynthesis. As light intensity increases, more energy is available and rate increases until CO₂ or temperature becomes limiting.',
      '0/5',
    ),
    _Practical(
      7,
      'Respiration — CO₂ Production in Seeds',
      'Respiration',
      'Show that germinating seeds produce carbon dioxide during respiration.',
      'To demonstrate that germinating seeds respire actively by detecting CO₂ production.',
      'Germinating seeds carry out aerobic respiration, producing CO₂ that turns lime water milky.',
      ['Germinating seeds', 'Dry seeds (control)', 'Two conical flasks', 'Lime water', 'Delivery tubes', 'Vaseline', 'Cotton wool'],
      ['Set up Flask A with germinating seeds, Flask B with dry seeds', 'Connect each to a test tube of lime water via delivery tube', 'Seal all connections with Vaseline', 'Leave for 24-48 hours', 'Observe colour of lime water in each test tube'],
      ['Independent: type of seeds (germinating vs dry)', 'Dependent: cloudiness of lime water', 'Controlled: same volume of seeds, same flask size, same time'],
      ['Record observations for each flask', 'Photograph or sketch results', 'Compare lime water cloudiness'],
      'Lime water turns milky only in the germinating seeds flask, confirming active respiration produces CO₂.',
      'Only germinating seeds produce enough CO₂ to turn lime water milky. Dry seeds are dormant and respire very slowly.',
      '0/5',
    ),
    _Practical(
      8,
      'Transpiration — Potometer Experiment',
      'Transport in Plants',
      'Measure the rate of water loss from a plant shoot.',
      'To investigate factors affecting transpiration rate.',
      'A leafy shoot loses water mainly through transpiration from stomata.',
      ['Potometer', 'Leafy shoot (e.g., Tradescantia)', 'Vaseline', 'Water', 'Ruler', 'Fan', 'Lamp'],
      ['Fill potometer with water, removing air bubbles', 'Insert fresh-cut shoot into potometer', 'Seal with Vaseline', 'Record position of air bubble', 'Set up variables: lamp, fan, plastic bag over leaves', 'Record bubble movement every 5 minutes'],
      ['Keep shoot in water at all times — no air bubbles in cut', 'Ensure airtight seal with Vaseline', 'Allow equilibration time before recording'],
      ['Tabulate: time, bubble position, distance moved', 'Calculate rate of water uptake', 'Compare under different conditions (fan, lamp, bag)'],
      'The bubble moves fastest with the fan (wind), confirming that transpiration rate increases with air movement over stomata.',
      'Most water loss occurs through stomata on leaves. Transpiration is affected by temperature, humidity, wind, and light intensity.',
      '0/5',
    ),
    _Practical(
      9,
      'Microorganism Culture',
      'Microorganisms',
      'Culture bacteria using aseptic technique on agar plates.',
      'To demonstrate the presence of microorganisms using aseptic technique.',
      'Microorganisms are present in the environment and can be cultured on nutrient agar.',
      ['Nutrient agar plates', 'Bacterial samples', 'Inoculating loop', 'Bunsen burner', 'Sterile swabs', 'Incubator'],
      ['Sterilize inoculating loop in Bunsen burner flame', 'Cool loop briefly', 'Pick up bacterial sample', 'Streak across agar surface in zigzag pattern', 'Label and incubate at 25°C for 48 hours', 'Observe colonies'],
      ['Use aseptic technique — work near flame', 'Sterilize loop before and after use', 'Do not open plate unnecessarily', 'Handle with care — potential pathogens'],
      ['Count colonies on each plate', 'Describe colony shape, colour, size', 'Compare different sampling sites'],
      'Visible colonies grow on all plates, confirming microorganisms are widespread in the environment.',
      'Microorganisms form visible colonies on agar. Different organisms produce colonies with distinct characteristics.',
      '0/5',
    ),
    _Practical(
      10,
      'Quadrat Sampling — Ecology',
      'Ecology',
      'Use quadrats to estimate population size in a given area.',
      'To estimate the population density of a plant species in a habitat.',
      'Random sampling with quadrats provides a statistically valid estimate of population size.',
      ['Quadrat (50cm × 50cm)', 'Meter ruler', 'Throwing stick', 'Clipboard and pencil', 'Calculator'],
      ['Throw quadrat randomly within the habitat', 'Count all individuals of target species inside quadrat', 'Record the number', 'Repeat at least 10 times', 'Calculate average per quadrat', 'Estimate total population = average × total area ÷ quadrat area'],
      ['Random throwing is essential — do NOT choose positions', 'Count only species inside the quadrat (use ½ edge rule)', 'Use same quadrat size throughout'],
      ['Table: quadrat number, number of individuals', 'Calculate mean and range', 'Estimate population: mean × (area of habitat ÷ area of quadrat)'],
      'A reliable population estimate requires at least 10 random samples. Randomness prevents bias in the estimate.',
      'Quadrat sampling is a standard ecological method. More samples = more reliable estimate.',
      '0/5',
    ),
    _Practical(
      11,
      'Transect Sampling — Ecology',
      'Ecology',
      'Use a line transect to study distribution of organisms.',
      'To investigate the distribution of organisms across a habitat gradient.',
      'Organism distribution changes across environmental gradients (e.g., light, moisture).',
      ['Meter rope', 'Quadrat', 'Pegs', 'Clipboard and pencil'],
      ['Stretch meter rope across the habitat', 'Place quadrat at regular intervals along the rope', 'Record organisms in each quadrat', 'Note environmental conditions at each point', 'Repeat along multiple transect lines'],
      ['Keep regular intervals', 'Record ALL species, not just the target', 'Note abiotic factors: light, moisture, soil type'],
      ['Table: position, species, count, abiotic factors', 'Plot distribution graph', 'Correlate with environmental gradient'],
      'Species distribution changes systematically along the transect, correlating with abiotic factors such as light and moisture.',
      'Transects reveal how species distribution changes across habitats, often correlating with environmental factors.',
      '0/5',
    ),
    _Practical(
      12,
      'Experimental Design — Fair Test',
      'Scientific Investigation',
      'Plan and carry out a full experimental investigation.',
      'To develop skills in planning a complete scientific investigation.',
      'A fair test changes only one variable while keeping all others constant.',
      ['Varies by experiment', 'Hypothesis, method, variables table', 'Results table', 'Graph paper', 'Calculator'],
      ['1. Write a clear aim/question', '2. State a hypothesis', '3. Identify variables: independent, dependent, controlled', '4. List apparatus', '5. Write step-by-step method', '6. Design results table', '7. Perform experiment', '8. Draw graph', '9. Write conclusion', '10. Evaluate'],
      ['Only ONE variable should change (fair test)', 'Repeat at least 3 times for reliability', 'Include a control where appropriate', 'Record anomalies', 'Use appropriate units and sig figs'],
      ['Independent variable → x-axis', 'Dependent variable → y-axis', 'Include title, labelled axes with units, line of best fit', 'Calculate mean if repeated'],
      'A well-designed experiment isolates one variable, includes appropriate controls, and produces repeatable, analysable results.',
      'Good experimental design follows a logical structure: aim → hypothesis → method → results → conclusion → evaluation.',
      '1/5',
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
              itemCount: _practicals.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) return _buildIntroBanner();
                return _buildPracticalCard(_practicals[i - 1], i - 1);
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _bioGreenGlow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.science_outlined,
                  color: _bioGreen, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Practical Skills Hub',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3)),
                  Text('12 MSCE practicals',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroBanner() {
    final completed = _practicals.where((p) => p.progress.startsWith('2/')).length;
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
            child: const Icon(Icons.science_outlined,
                color: _bioGreen, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MSCE Practical Skills',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    '$completed of ${_practicals.length} practicals completed. Each includes aim, hypothesis, method, results, and evaluation.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticalCard(_Practical p, int index) {
    final isExpanded = _expandedPractical == index;
    final hasProgress = p.progress != '0/5';
    final color = hasProgress ? _bioGreen : AppColors.textMuted;

    return Container(
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
            onTap: () => setState(() => _expandedPractical = isExpanded ? null : index),
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
                    child: Center(
                      child: Text('${p.number}',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: color)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 3),
                        Text(p.category,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(p.progress,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                  const SizedBox(width: 8),
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
            secondChild: _buildPracticalDetail(p),
            crossFadeState:
                isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticalDetail(_Practical p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailSection('Aim', [p.aim], Icons.flag_rounded),
          const SizedBox(height: 12),
          _buildDetailSection('Hypothesis', [p.hypothesis], Icons.lightbulb_rounded),
          const SizedBox(height: 12),
          _buildDetailSection('Apparatus', p.apparatus, Icons.build_rounded),
          const SizedBox(height: 12),
          _buildDetailSection('Safety', p.safety, Icons.shield_rounded),
          const SizedBox(height: 12),
          _buildDetailSection('Method', p.method, Icons.format_list_numbered_rounded),
          const SizedBox(height: 12),
          _buildDetailSection('Key Variables', p.variables, Icons.tune_rounded),
          const SizedBox(height: 12),
          _buildDetailSection('Expected Results', [p.expectedResults], Icons.insights_rounded),
          const SizedBox(height: 12),
          _buildDetailSection('Conclusion', [p.conclusion], Icons.check_circle_outline_rounded),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Start Practical'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _bioGreen,
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

  Widget _buildDetailSection(String title, List<String> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: _bioGreen),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _bioGreen)),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: const BoxDecoration(
                        color: AppColors.textMuted, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _Practical {
  final int number;
  final String title;
  final String category;
  final String subtitle;
  final String aim;
  final String hypothesis;
  final List<String> apparatus;
  final List<String> safety;
  final List<String> method;
  final List<String> variables;
  final String expectedResults;
  final String conclusion;
  final String progress;
  const _Practical(this.number, this.title, this.category, this.subtitle,
      this.aim, this.hypothesis, this.apparatus, this.safety, this.method,
      this.variables, this.expectedResults, this.conclusion, this.progress);
}
