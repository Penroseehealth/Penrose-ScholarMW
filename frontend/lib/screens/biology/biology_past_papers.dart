import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

const Color _bioGreen = Color(0xFF10B981);
const Color _bioGreenDark = Color(0xFF059669);
const Color _bioGreenGlow = Color(0x2210B981);

class BiologyPastPapersScreen extends StatefulWidget {
  BiologyPastPapersScreen({super.key});

  @override
  State<BiologyPastPapersScreen> createState() =>
      _BiologyPastPapersScreenState();
}

class _BiologyPastPapersScreenState extends State<BiologyPastPapersScreen> {
  bool _examActive = false;
  _PastPaper? _activePaper;
  int _currentQuestion = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  int _timeLeft = 60;
  Timer? _timer;
  List<_PastResult> _results = [];

  static const List<_PastPaper> _papers = [
    _PastPaper(2024, 'MSCE Biology Examination', [
      _PQ('Which organelle releases most of the energy from glucose during aerobic respiration?',
          ['Nucleus', 'Ribosome', 'Mitochondrion', 'Chloroplast'], 2,
          'Mitochondria contain the enzymes for aerobic respiration and release energy from glucose in the form of ATP.'),
      _PQ('Which blood vessels carry blood away from the heart?',
          ['Veins', 'Arteries', 'Capillaries', 'Lymph vessels'], 1,
          'Arteries carry blood away from the heart under high pressure. They have thick, muscular and elastic walls.'),
      _PQ('The basic unit of heredity is the:',
          ['Gene', 'Cell', 'Enzyme', 'Antibody'], 0,
          'Genes are segments of DNA located on chromosomes. They code for characteristics and are passed from parents to offspring.'),
      _PQ('Which gas do plants absorb from the atmosphere during photosynthesis?',
          ['Oxygen', 'Nitrogen', 'Carbon dioxide', 'Hydrogen'], 2,
          'Photosynthesis uses light energy absorbed by chlorophyll to combine carbon dioxide and water into glucose, releasing oxygen.'),
      _PQ('Which disease is caused by a deficiency of vitamin C?',
          ['Rickets', 'Scurvy', 'Kwashiorkor', 'Beri-beri'], 1,
          'Vitamin C is needed for healthy connective tissue. Its deficiency causes bleeding gums and poor wound healing, known as scurvy.'),
      _PQ('Loss of water vapour from the leaves of a plant through the stomata is called:',
          ['Respiration', 'Transpiration', 'Photosynthesis', 'Germination'], 1,
          'Transpiration is the loss of water vapour from aerial parts of a plant, mainly through stomata. It creates transpiration pull that draws water up the xylem.'),
      _PQ('Which part of the human brain controls balance and muscular coordination?',
          ['Cerebrum', 'Medulla oblongata', 'Hypothalamus', 'Cerebellum'], 3,
          'The cerebellum coordinates muscle activity and maintains posture and balance.'),
      _PQ('The malaria parasite is transmitted to humans by the bite of:',
          ['Male Anopheles mosquito', 'Female Anopheles mosquito', 'Tsetse fly', 'Housefly'], 1,
          'Only the female Anopheles mosquito feeds on blood and can inject Plasmodium sporozoites into the bloodstream when biting.'),
      _PQ('Which of the following is a renewable natural resource?',
          ['Coal', 'Petroleum', 'Natural gas', 'Forests'], 3,
          'Forests can regenerate naturally over time if harvested sustainably, unlike fossil fuels which cannot be replaced once used.'),
      _PQ('In the nitrogen cycle, nitrifying bacteria convert:',
          ['Nitrates into nitrogen gas', 'Ammonia into nitrates', 'Nitrogen gas into ammonia', 'Proteins into urea'], 1,
          'Nitrifying bacteria in the soil oxidise ammonia from decaying matter, first to nitrites and then to nitrates, which plants can absorb.'),
    ], [
      _PQ('State two structural differences between a plant cell and an animal cell.', [], 0,
          'Plant cells have a cellulose cell wall and chloroplasts, and usually a large central vacuole; animal cells lack these structures.'),
      _PQ('Define osmosis and state one importance of osmosis in living organisms.', [], 0,
          'Osmosis is the movement of water molecules from a region of higher water potential to a region of lower water potential through a partially permeable membrane. Importance: absorption of water by root hair cells.'),
      _PQ('State three functions of the human liver.', [], 0,
          'Produces bile; stores glycogen; deaminates excess amino acids; detoxifies harmful substances; helps regulate blood sugar level.'),
      _PQ('Distinguish between aerobic and anaerobic respiration.', [], 0,
          'Aerobic respiration uses oxygen and completely breaks down glucose into carbon dioxide and water, releasing much energy. Anaerobic respiration occurs without oxygen and incompletely breaks down glucose into lactic acid in animals or ethanol and carbon dioxide in yeast, releasing little energy.'),
      _PQ('Explain why leguminous plants are useful in crop rotation.', [], 0,
          'Legumes host nitrogen-fixing bacteria in root nodules. These enrich the soil with nitrates, improving fertility for the crops that follow.'),
    ], [
      _PQ('Describe the process of blood clotting and explain its importance to the human body.', [], 0,
          'Damaged tissues and platelets release thrombokinase, which converts prothrombin to thrombin in the presence of calcium ions. Thrombin converts soluble fibrinogen into insoluble fibrin threads that trap blood cells and form a clot. Clotting prevents excessive blood loss and blocks the entry of pathogens.'),
      _PQ('Discuss four effects of deforestation on the environment.', [], 0,
          'Soil erosion; loss of biodiversity and habitats; reduced rainfall and increased risk of drought; raised carbon dioxide levels contributing to global warming; disruption of water catchment systems.'),
      _PQ('Describe how the alveolus is adapted for gaseous exchange.', [], 0,
          'Millions of alveoli provide a large surface area; their walls are one cell thick for a short diffusion distance; a thin moisture film dissolves gases; a dense capillary network maintains a steep concentration gradient.'),
    ]),
    _PastPaper(2023, 'MSCE Biology Examination', [
      _PQ('Which structure controls the movement of substances into and out of a cell?',
          ['Cell wall', 'Nuclear envelope', 'Cell membrane', 'Cytoplasm'], 2,
          'The cell membrane is selectively permeable and controls which substances enter and leave the cell.'),
      _PQ('Salivary amylase digests starch into:',
          ['Glucose', 'Maltose', 'Fatty acids', 'Amino acids'], 1,
          'Salivary amylase breaks starch down into maltose, which is later converted to glucose by maltase in the small intestine.'),
      _PQ('Which chamber of the heart pumps oxygenated blood to all parts of the body?',
          ['Right atrium', 'Right ventricle', 'Left atrium', 'Left ventricle'], 3,
          'The left ventricle has the thickest muscular wall because it pumps oxygenated blood at high pressure through the aorta to the whole body.'),
      _PQ('Gaseous exchange across the alveolar walls takes place by the process of:',
          ['Osmosis', 'Active transport', 'Diffusion', 'Phagocytosis'], 2,
          'Oxygen diffuses from the alveoli into the blood while carbon dioxide diffuses from the blood into the alveoli, each down its own concentration gradient.'),
      _PQ('The functional unit of the kidney is called the:',
          ['Neuron', 'Alveolus', 'Nephron', 'Villus'], 2,
          'Each kidney contains about one million nephrons, which filter blood and produce urine.'),
      _PQ('Which hormone decreases the level of glucose in the blood?',
          ['Adrenaline', 'Glucagon', 'Insulin', 'Thyroxine'], 2,
          'Insulin from the pancreas promotes the uptake of glucose by body cells and its conversion to glycogen, lowering blood glucose level.'),
      _PQ('In flowering plants, the male gametes are found inside the:',
          ['Ovule', 'Stigma', 'Anther', 'Sepal'], 2,
          'The anther produces pollen grains, each of which carries the male gametes needed for fertilisation.'),
      _PQ('A cross between two heterozygous tall pea plants (Tt x Tt) is expected to give a phenotypic ratio of:',
          ['All tall', '1 tall : 1 short', '3 tall : 1 short', '1 tall : 3 short'], 2,
          'Tt x Tt produces TT, Tt, Tt and tt offspring. Three combinations are tall and one is short, giving a 3:1 ratio.'),
      _PQ('Which of the following organisms acts as a decomposer in an ecosystem?',
          ['Maize plant', 'Mushroom', 'Goat', 'Eagle'], 1,
          'Mushrooms are fungi that secrete enzymes onto dead organic matter and absorb the products, recycling nutrients back into the soil.'),
      _PQ('Which of the following practices reduces the spread of HIV?',
          ['Sharing razor blades', 'Unprotected sexual intercourse', 'Using sterilised needles', 'Sleeping under nets'], 2,
          'HIV is transmitted through infected body fluids. Sterilised needles prevent the transfer of infected blood from one person to another.'),
    ], [
      _PQ('State two functions of the cell membrane.', [], 0,
          'Controls the entry and exit of substances; encloses and protects the cell contents; contains receptor sites for cell communication.'),
      _PQ('Name the reagent used to test for starch and the reagent used to test for reducing sugars, stating the positive result in each case.', [], 0,
          'Starch: iodine solution turns blue-black. Reducing sugars: Benedict\'s solution turns from blue through green, yellow and orange to brick-red when heated.'),
      _PQ('State three ways in which the small intestine is adapted for absorption.', [], 0,
          'It is long to provide a large surface area; villi and microvilli further increase the surface area; walls are thin for a short diffusion distance; it has a rich blood supply and lacteals to transport absorbed products.'),
      _PQ('Define excretion and name two excretory organs of humans.', [], 0,
          'Excretion is the removal of toxic waste products of metabolism from the body. Excretory organs include the kidneys, lungs, skin and liver.'),
      _PQ('Explain why water should be boiled before drinking.', [], 0,
          'Boiling kills disease-causing microorganisms such as bacteria and protozoa that cause waterborne diseases like cholera and typhoid.'),
    ], [
      _PQ('Describe the human digestive system and explain how food is digested in the small intestine.', [], 0,
          'The alimentary canal runs from mouth to anus. In the duodenum, bile emulsifies fats and pancreatic juice supplies amylase, trypsin and lipase. Intestinal enzymes complete digestion to glucose, amino acids, fatty acids and glycerol, which are absorbed through the villi into the blood and lacteals.'),
      _PQ('Explain five ways in which the human body defends itself against disease-causing organisms.', [], 0,
          'The skin acts as a physical barrier; mucus and cilia trap pathogens in the airways; stomach acid kills swallowed microbes; blood clotting seals wounds; phagocytes engulf pathogens and lymphocytes produce specific antibodies.'),
      _PQ('Discuss the causes and effects of water pollution in Malawi and suggest control measures.', [], 0,
          'Causes: untreated sewage, industrial effluent, agricultural run-off of fertilisers and careless disposal of litter. Effects: eutrophication, death of aquatic life and spread of waterborne diseases. Control: sewage treatment, enforcement of environmental laws, proper waste disposal and public education.'),
    ]),
    _PastPaper(2022, 'MSCE Biology Examination', [
      _PQ('A seedling shoot growing towards light demonstrates which characteristic of living things?',
          ['Excretion', 'Sensitivity', 'Reproduction', 'Nutrition'], 1,
          'Sensitivity (irritability) is the ability to detect and respond to stimuli. Phototropism is a growth response of a shoot towards light.'),
      _PQ('Chlorophyll is essential for photosynthesis because it:',
          ['Absorbs light energy', 'Stores water', 'Releases carbon dioxide', 'Breaks down glucose'], 0,
          'Chlorophyll pigments absorb light energy, which is used to split water molecules and convert carbon dioxide into glucose.'),
      _PQ('Which sequence shows the correct path of food through the human alimentary canal?',
          ['Mouth, stomach, oesophagus, small intestine, large intestine',
           'Mouth, oesophagus, stomach, small intestine, large intestine',
           'Mouth, oesophagus, small intestine, stomach, large intestine',
           'Mouth, small intestine, stomach, oesophagus, large intestine'], 1,
          'Food passes from the mouth down the oesophagus to the stomach, then to the small intestine where most absorption occurs, and finally to the large intestine.'),
      _PQ('Bile helps in the digestion of fats by:',
          ['Chemically breaking fats into fatty acids', 'Emulsifying fats into tiny droplets', 'Converting fats into proteins', 'Absorbing fats directly into the blood'], 1,
          'Bile salts emulsify fats into small droplets, increasing the surface area for lipase action. Bile does not chemically digest fat itself.'),
      _PQ('Which component of the blood transports oxygen around the body?',
          ['Platelets', 'Plasma', 'White blood cells', 'Haemoglobin in red blood cells'], 3,
          'Haemoglobin in red blood cells combines with oxygen in the lungs to form oxyhaemoglobin, which releases oxygen in the tissues.'),
      _PQ('Anaerobic respiration in yeast cells produces:',
          ['Lactic acid and water', 'Ethanol and carbon dioxide', 'Glucose and oxygen', 'Urea and water'], 1,
          'Yeast respires anaerobically by fermentation, converting glucose into ethanol and carbon dioxide. This is applied in brewing and baking.'),
      _PQ('The skin regulates body temperature mainly by:',
          ['Producing sweat that evaporates', 'Growing more hair', 'Storing melanin', 'Producing vitamin D'], 0,
          'When body temperature rises, sweat glands produce sweat whose evaporation removes heat. Vasodilation of skin capillaries also increases heat loss.'),
      _PQ('Which part of the eye changes its thickness to focus images on the retina?',
          ['Cornea', 'Iris', 'Lens', 'Pupil'], 2,
          'The lens changes shape in accommodation, controlled by the ciliary muscles, so that light rays are focused sharply on the retina.'),
      _PQ('During pregnancy, the placenta:',
          ['Protects the mother from infection', 'Exchanges nutrients and wastes between mother and foetus', 'Produces eggs for future offspring', 'Stores urine for the foetus'], 1,
          'The placenta allows oxygen and nutrients to pass from the maternal blood to the foetus, and carbon dioxide and urea to pass back for removal.'),
      _PQ('Which farming method best conserves soil on steep slopes?',
          ['Overgrazing', 'Terracing', 'Clearing all vegetation', 'Burning crop residues'], 1,
          'Terracing slows down the flow of runoff water down a slope, reducing soil erosion and conserving fertility.'),
    ], [
      _PQ('State two differences between diffusion and osmosis.', [], 0,
          'Diffusion involves the movement of any particles from a region of high concentration to low concentration; osmosis involves only water molecules moving across a partially permeable membrane from higher to lower water potential.'),
      _PQ('Name three types of teeth in humans and state the function of each.', [], 0,
          'Incisors bite and cut food; canines tear food; premolars and molars grind and crush food.'),
      _PQ('State the role of the diaphragm during breathing in and breathing out.', [], 0,
          'During inhalation it contracts and flattens, increasing the volume of the thorax; during exhalation it relaxes and domes upwards, decreasing the volume.'),
      _PQ('What is meant by double circulation?', [], 0,
          'Double circulation is the passage of blood through the heart twice in one complete circuit: pulmonary circulation between the heart and lungs, and systemic circulation between the heart and the rest of the body.'),
      _PQ('Give two reasons why breast milk is considered the best food for a newborn baby.', [], 0,
          'It contains antibodies that protect against infections; it provides nutrients in the correct proportions; it is served at the right temperature and is free from contamination.'),
    ], [
      _PQ('Describe the mechanism of inhalation and exhalation in humans.', [], 0,
          'Inhalation: the external intercostal muscles contract, raising the ribs, while the diaphragm contracts and flattens. Thoracic volume increases, pressure falls and air rushes in. Exhalation: the muscles relax, volume decreases, pressure rises and air is forced out.'),
      _PQ('Explain the importance of photosynthesis to living organisms.', [], 0,
          'Photosynthesis provides food and the initial energy source for almost all ecosystems; it releases oxygen needed for aerobic respiration; it removes carbon dioxide from the atmosphere; it forms the basis of food chains and of fossil fuels.'),
      _PQ('Describe the life cycle of a mosquito and explain methods of controlling malaria in Malawi.', [], 0,
          'Eggs are laid on water and hatch into larvae, which become pupae and then adults. Control: draining stagnant water, applying larvicides, sleeping under insecticide-treated nets, indoor residual spraying, clearing bushes and prompt treatment of patients.'),
    ]),
    _PastPaper(2021, 'MSCE Biology Examination', [
      _PQ('Organisms are placed into kingdoms mainly according to their:',
          ['Colour and size', 'Structure and mode of nutrition', 'Speed of movement', 'Place of residence'], 1,
          'Classification groups organisms using structural features, cell type and modes of nutrition to assign them to kingdoms.'),
      _PQ('Which organelle is the site of protein synthesis in a cell?',
          ['Ribosome', 'Lysosome', 'Vacuole', 'Centriole'], 0,
          'Ribosomes read messenger RNA and assemble amino acids into polypeptide chains, making proteins.'),
      _PQ('Diffusion is best defined as the movement of particles:',
          ['From low to high concentration using energy', 'From high to low concentration without using energy', 'Through a membrane using energy', 'Against the concentration gradient'], 1,
          'Diffusion is the net movement of particles down a concentration gradient, from a region of higher concentration to one of lower concentration, without the use of energy.'),
      _PQ('A balanced diet should contain:',
          ['Carbohydrates only', 'Proteins and vitamins only', 'Carbohydrates, proteins, fats, vitamins, minerals, water and roughage', 'Water and minerals only'], 2,
          'A balanced diet contains all classes of nutrients in the correct proportions to meet the body\'s energy, growth and repair needs.'),
      _PQ('Translocation in plants refers to the movement of:',
          ['Water up the xylem', 'Manufactured food through the phloem', 'Minerals into root hairs', 'Gases through the stomata'], 1,
          'Translocation is the transport of sucrose and other products of photosynthesis from the leaves to other parts of the plant through the phloem.'),
      _PQ('Urea is produced in the human body by the:',
          ['Kidney', 'Liver', 'Skin', 'Lungs'], 1,
          'The liver deaminates excess amino acids, and the ammonia released is combined with carbon dioxide to form urea, which the kidneys excrete.'),
      _PQ('A reflex action differs from a voluntary action because it is:',
          ['Controlled by the cerebrum', 'Slow and deliberate', 'Rapid, automatic and involuntary', 'Always painful'], 2,
          'Reflex actions are rapid, automatic responses to stimuli coordinated by the spinal cord or lower brain, without conscious thought.'),
      _PQ('Growth of a new potato plant from a tuber is an example of:',
          ['Sexual reproduction', 'Pollination', 'Asexual reproduction', 'Fertilisation'], 2,
          'Vegetative propagation from a tuber involves only one parent and produces genetically identical offspring, so it is asexual reproduction.'),
      _PQ('An ecosystem is made up of:',
          ['Living organisms only', 'Non-living factors only', 'Communities of organisms interacting with their physical environment', 'Producers only'], 2,
          'An ecosystem consists of all the biotic communities together with abiotic factors such as soil, water and climate, interacting as a system.'),
      _PQ('Vaccination protects a person against disease by:',
          ['Killing all bacteria in the body', 'Stimulating the production of antibodies', 'Providing ready-made antibodies only', 'Increasing the number of red blood cells'], 1,
          'Vaccines contain weakened or dead pathogens or their antigens, which stimulate the immune system to produce antibodies and memory cells for long-lasting protection.'),
    ], [
      _PQ('State two characteristics of living organisms and give one example of each.', [], 0,
          'Examples: respiration, the release of energy from food; growth, a permanent increase in size; also reproduction, excretion, sensitivity, movement and nutrition.'),
      _PQ('State three external features of a leaf that adapt it for photosynthesis.', [], 0,
          'Broad flat lamina for a large surface area; thin blade for a short diffusion distance; network of veins for transport and support; stomata for gaseous exchange.'),
      _PQ('Define pollination and distinguish between self-pollination and cross-pollination.', [], 0,
          'Pollination is the transfer of pollen grains from the anther to the stigma. Self-pollination: pollen lands on the stigma of the same flower or plant. Cross-pollination: pollen is carried to the stigma of another plant of the same species.'),
      _PQ('State two functions of the skeleton in humans.', [], 0,
          'Supports the body; protects delicate organs; provides attachment for muscles to bring about movement; stores minerals; produces blood cells in the marrow.'),
      _PQ('Explain why the population of predators increases shortly after an increase in the prey population.', [], 0,
          'More prey provides more food, so predators are better fed, survive longer and reproduce more successfully, causing their numbers to rise. This is a density-dependent interaction.'),
    ], [
      _PQ('Describe the structure and functions of the parts of a typical insect-pollinated flower.', [], 0,
          'Sepals protect the flower bud; petals are brightly coloured to attract insects; the stamen consists of anther and filament and produces pollen; the carpel consists of stigma, style and ovary, receives pollen and contains ovules. After fertilisation the ovule becomes the seed and the ovary becomes the fruit.'),
      _PQ('Explain how the kidney produces urine.', [], 0,
          'High blood pressure in the glomerulus causes ultrafiltration of water, glucose, salts and urea into the Bowman\'s capsule. Useful substances, including all the glucose, some salts and most of the water, are selectively reabsorbed in the tubule. The remaining fluid, urine, passes through collecting ducts to the bladder.'),
      _PQ('Discuss the role of forests in environmental conservation in Malawi.', [], 0,
          'Forests prevent soil erosion, regulate rainfall and water cycles, provide habitats for wildlife, absorb carbon dioxide, and supply timber, fuel, fruits and medicines. Sustainable management through afforestation and controlled harvesting preserves these benefits.'),
    ]),
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startExam(_PastPaper paper) {
    setState(() {
      _activePaper = paper;
      _examActive = true;
      _currentQuestion = 0;
      _selectedAnswer = null;
      _answered = false;
      _score = 0;
      _timeLeft = 60;
      _results = [];
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (_timeLeft <= 1) {
        t.cancel();
        _timeoutQuestion();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _timeoutQuestion() {
    final q = _activePaper!.sectionA[_currentQuestion];
    setState(() {
      _answered = true;
      _selectedAnswer = null;
      _results.add(_PastResult(q, -1, false, 60));
    });
    _advance();
  }

  void _submitAnswer() {
    if (_selectedAnswer == null || _answered) return;
    _timer?.cancel();
    final q = _activePaper!.sectionA[_currentQuestion];
    final correct = _selectedAnswer == q.correctIndex;
    final timeTaken = 60 - _timeLeft;
    if (correct) _score++;
    setState(() {
      _answered = true;
      _results.add(_PastResult(q, _selectedAnswer!, correct, timeTaken));
    });
  }

  void _advance() {
    if (_currentQuestion >= _activePaper!.sectionA.length - 1) {
      _finishExam();
      return;
    }
    setState(() {
      _currentQuestion++;
      _selectedAnswer = null;
      _answered = false;
      _timeLeft = 60;
    });
    _startTimer();
  }

  void _finishExam() {
    _timer?.cancel();
    setState(() => _examActive = false);
  }

  void _exitExam() {
    _timer?.cancel();
    setState(() {
      _examActive = false;
      _activePaper = null;
      _results = [];
      _score = 0;
    });
  }

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
            child: _examActive
                ? _buildExamView(isDesktop)
                : _results.isNotEmpty
                    ? _buildResultsView(isDesktop)
                    : _buildPaperList(isDesktop),
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
                width: 38, height: 38,
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
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _bioGreenGlow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.history_edu_rounded, color: _bioGreen, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_examActive
                      ? 'Question ${_currentQuestion + 1} of ${_activePaper!.sectionA.length}'
                      : 'Past Papers',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                  Text('MSCE Biology Past Papers',
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                ],
              ),
            ),
            if (_examActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _timeLeft <= 10
                      ? context.colors.error.withValues(alpha: 0.15)
                      : _bioGreenGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_timeLeft s',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _timeLeft <= 10 ? context.colors.error : _bioGreen)),
              ),
              SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _bioGreenGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_score/${_results.length}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _bioGreen)),
              ),
              SizedBox(width: 10),
              GestureDetector(
                onTap: _exitExam,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: context.colors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaperList(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
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
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _bioGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.history_edu_rounded, color: _bioGreen, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MSCE Biology Past Papers',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                      SizedBox(height: 4),
                      Text('Attempt real examination formats. Sit the timed multiple choice section, then review model answers for every question.',
                          style: TextStyle(fontSize: 12, color: context.colors.textMuted, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          _buildSectionTitle('Available Papers'),
          SizedBox(height: 12),
          for (final paper in _papers) _buildPaperCard(paper),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPaperCard(_PastPaper paper) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _bioGreenGlow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _bioGreen.withValues(alpha: 0.3)),
                ),
                child: Text('${paper.year}',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: _bioGreen)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paper.title,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Malawi School Certificate of Education Examination',
                        style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              _buildCountStat('${paper.sectionA.length}', 'MCQ', _bioGreen),
              _buildCountDivider(),
              _buildCountStat('${paper.sectionB.length}', 'Structured', context.colors.lavender),
              _buildCountDivider(),
              _buildCountStat('${paper.sectionC.length}', 'Essay', context.colors.warning),
            ],
          ),
          SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag('Section A', _bioGreen),
              _buildTag('Section B', context.colors.lavender),
              _buildTag('Section C', context.colors.warning),
            ],
          ),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startExam(paper),
              icon: Icon(Icons.play_arrow_rounded, size: 20),
              label: Text('Start MCQ Section',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _bioGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountStat(String value, String label, Color color) {
    return Row(
      children: [
        Text(value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
      ],
    );
  }

  Widget _buildCountDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text('.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.textMuted)),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildExamView(bool isDesktop) {
    final q = _activePaper!.sectionA[_currentQuestion];
    final progress = (_currentQuestion + 1) / _activePaper!.sectionA.length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.colors.surfaceHighest,
              color: _bioGreen,
              minHeight: 5,
            ),
          ),
          SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _bioGreenGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Section A',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _bioGreen)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(q.question,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                        height: 1.3)),
              ),
            ],
          ),
          SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: q.options.length,
              itemBuilder: (ctx, i) {
                final isSelected = _selectedAnswer == i;
                final isCorrect = i == q.correctIndex;
                Color borderColor = AppColors.border;
                Color bgColor = AppColors.surface;
                if (_answered) {
                  if (isCorrect) {
                    borderColor = context.colors.success;
                    bgColor = context.colors.success.withValues(alpha: 0.08);
                  } else if (isSelected && !isCorrect) {
                    borderColor = context.colors.error;
                    bgColor = context.colors.error.withValues(alpha: 0.08);
                  }
                } else if (isSelected) {
                  borderColor = _bioGreen;
                  bgColor = _bioGreenGlow;
                }

                return GestureDetector(
                  onTap: _answered ? null : () => setState(() => _selectedAnswer = i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: borderColor,
                          width: isSelected || (_answered && isCorrect) ? 1.5 : 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: (isSelected || (_answered && isCorrect))
                                ? borderColor.withValues(alpha: 0.15)
                                : context.colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: _answered && isCorrect
                                ? Icon(Icons.check_rounded, size: 18, color: context.colors.success)
                                : _answered && isSelected && !isCorrect
                                    ? Icon(Icons.close_rounded, size: 18, color: context.colors.error)
                                    : Text(String.fromCharCode(65 + i),
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected ? borderColor : context.colors.textMuted)),
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(q.options[i],
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: context.colors.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_answered) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explanation',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.info)),
                  SizedBox(height: 6),
                  Text(q.explanation,
                      style: TextStyle(
                          fontSize: 12, color: context.colors.textSecondary, height: 1.5)),
                ],
              ),
            ),
            SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _answered
                  ? _advance
                  : _selectedAnswer != null
                      ? _submitAnswer
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _bioGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: context.colors.surfaceHighest,
                disabledForegroundColor: context.colors.textMuted,
              ),
              child: Text(
                  _answered
                      ? _currentQuestion >= _activePaper!.sectionA.length - 1
                          ? 'View Results'
                          : 'Next Question'
                      : 'Submit Answer',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(bool isDesktop) {
    final total = _results.length;
    final pct = total > 0 ? (_score / total * 100).round() : 0;
    final grade = pct >= 80
        ? 'A'
        : pct >= 70
            ? 'B'
            : pct >= 60
                ? 'C'
                : pct >= 50
                    ? 'D'
                    : pct >= 40
                        ? 'E'
                        : 'F';
    final gradeColor = pct >= 70
        ? context.colors.success
        : pct >= 50
            ? context.colors.warning
            : context.colors.error;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16, vertical: 20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                gradeColor.withValues(alpha: 0.1),
                gradeColor.withValues(alpha: 0.03),
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gradeColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text('${_activePaper!.year} Paper — Section A',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
                SizedBox(height: 16),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gradeColor.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Text(grade,
                        style: TextStyle(
                            fontSize: 36, fontWeight: FontWeight.w800, color: gradeColor)),
                  ),
                ),
                SizedBox(height: 16),
                Text('$_score / $total',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                Text('$pct% — Grade $grade',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: gradeColor)),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildResultStat('Correct', '$_score', context.colors.success),
                    SizedBox(width: 24),
                    _buildResultStat('Wrong', '${total - _score}', context.colors.error),
                    SizedBox(width: 24),
                    _buildResultStat('Time', _formatTotalTime(), context.colors.info),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          _buildSectionTitle('Question Review'),
          SizedBox(height: 12),
          for (var i = 0; i < _results.length; i++) _buildReviewCard(i, _results[i]),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _exitExam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.surface,
                    foregroundColor: context.colors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: context.colors.border)),
                  ),
                  child: Text('New Paper',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _startExam(_activePaper!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bioGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Retry',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
      ],
    );
  }

  String _formatTotalTime() {
    final total = _results.fold<int>(0, (a, r) => a + r.timeTaken);
    final m = total ~/ 60;
    final s = total % 60;
    return '${m}m ${s}s';
  }

  Widget _buildReviewCard(int index, _PastResult r) {
    final color = r.correct ? context.colors.success : context.colors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: r.correct
                      ? Icon(Icons.check_rounded, size: 16, color: context.colors.success)
                      : Icon(Icons.close_rounded, size: 16, color: context.colors.error),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('${index + 1}. ${r.question.question}',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
              ),
            ],
          ),
          if (!r.correct) ...[
            SizedBox(height: 8),
            Text(
                'Your answer: ${r.selected >= 0 ? r.question.options[r.selected] : 'No answer'}',
                style: TextStyle(fontSize: 12, color: context.colors.error)),
            Text('Correct answer: ${r.question.options[r.question.correctIndex]}',
                style: TextStyle(fontSize: 12, color: context.colors.success)),
            SizedBox(height: 6),
            Text(r.question.explanation,
                style: TextStyle(fontSize: 11, color: context.colors.textMuted, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_bioGreen, _bioGreenDark]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12),
        Text(title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary, letterSpacing: -0.3)),
      ],
    );
  }
}

class _PastPaper {
  final int year;
  final String title;
  final List<_PQ> sectionA;
  final List<_PQ> sectionB;
  final List<_PQ> sectionC;
  const _PastPaper(this.year, this.title, this.sectionA, this.sectionB, this.sectionC);
}

class _PQ {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  const _PQ(this.question, this.options, this.correctIndex, this.explanation);
}

class _PastResult {
  final _PQ question;
  final int selected;
  final bool correct;
  final int timeTaken;
  const _PastResult(this.question, this.selected, this.correct, this.timeTaken);
}
