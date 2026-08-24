import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

const Color _bioGreen = Color(0xFF10B981);
const Color _bioGreenDark = Color(0xFF059669);
const Color _bioGreenGlow = Color(0x2210B981);

class BiologyPracticeCentreScreen extends StatefulWidget {
  const BiologyPracticeCentreScreen({super.key});

  @override
  State<BiologyPracticeCentreScreen> createState() =>
      _BiologyPracticeCentreScreenState();
}

class _BiologyPracticeCentreScreenState
    extends State<BiologyPracticeCentreScreen> {
  bool _quizActive = false;
  int _selectedChapter = -1;
  String _difficulty = 'All';
  int _questionCount = 10;

  List<_Question> _quizQuestions = [];
  int _currentQuestion = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  int _timeLeft = 30;
  Timer? _timer;
  List<_QuizResult> _results = [];

  static const _chapters = [
    'Introduction to Biology',
    'Cell Biology',
    'Movement of Substances',
    'Nutrition',
    'Transport in Plants & Animals',
    'Gaseous Exchange & Respiration',
    'Excretion & Homeostasis',
    'Coordination & Response',
    'Reproduction',
    'Genetics & Inheritance',
    'Ecology',
    'Microorganisms',
    'Disease & Immunity',
    'Environment & Conservation',
    'Practical Skills',
  ];

  static final _allQuestions = [
    const _QBank(
      1,
      'Introduction to Biology',
      [
        _Question('What is the smallest unit of life?', ['Atom', 'Cell', 'Tissue', 'Organ'], 1, 'Easy',
            'The cell is the basic structural and functional unit of all living organisms.'),
        _Question('Which branch of biology deals with the classification of organisms?', ['Ecology', 'Taxonomy', 'Genetics', 'Anatomy'], 1, 'Easy',
            'Taxonomy is the science of classification, naming, and identification of organisms.'),
        _Question('Which of these is NOT a characteristic of living things?', ['Growth', 'Reproduction', 'Conducting electricity', 'Response to stimuli'], 2, 'Easy',
            'Living things grow, reproduce, respond to stimuli, and need energy. Conducting electricity is not a defining characteristic.'),
        _Question('What does the term "hypothesis" mean in scientific investigation?', ['A proven fact', 'A tentative explanation', 'A final conclusion', 'An observation'], 1, 'Medium',
            'A hypothesis is a testable, tentative explanation for an observation that can be investigated further.'),
        _Question('The process of classifying living organisms into groups is called:', ['Experimentation', 'Classification', 'Observation', 'Inference'], 1, 'Easy',
            'Classification groups organisms based on shared characteristics into a systematic hierarchy.'),
        _Question('Which kingdom includes organisms that are multicellular and photosynthetic?', ['Fungi', 'Animalia', 'Plantae', 'Monera'], 2, 'Medium',
            'Kingdom Plantae includes multicellular, photosynthetic organisms with cell walls made of cellulose.'),
      ],
    ),
    const _QBank(
      2,
      'Cell Biology',
      [
        _Question('Which organelle is the powerhouse of the cell?', ['Nucleus', 'Ribosome', 'Mitochondrion', 'Golgi apparatus'], 2, 'Easy',
            'Mitochondria are the sites of aerobic respiration, producing most of the cell\'s ATP.'),
        _Question('What is the function of the cell membrane?', ['Cell division', 'Controls what enters and leaves the cell', 'Produces proteins', 'Stores genetic material'], 1, 'Easy',
            'The cell membrane is selectively permeable, controlling the movement of substances in and out of the cell.'),
        _Question('Which structure is found in plant cells but NOT in animal cells?', ['Mitochondrion', 'Ribosome', 'Cell wall', 'Cell membrane'], 2, 'Easy',
            'Plant cells have a rigid cell wall made of cellulose, a large central vacuole, and chloroplasts — none of which are found in animal cells.'),
        _Question('The process by which cells divide to form two identical daughter cells is:', ['Meiosis', 'Mitosis', 'Osmosis', 'Diffusion'], 1, 'Medium',
            'Mitosis produces two genetically identical daughter cells, used for growth and repair.'),
        _Question('Which cell structure contains the genetic material (DNA)?', ['Cytoplasm', 'Cell membrane', 'Nucleus', 'Mitochondrion'], 2, 'Easy',
            'The nucleus contains the cell\'s DNA organised into chromosomes.'),
        _Question('What is the function of ribosomes?', ['Energy production', 'Protein synthesis', 'Cell division', 'Waste removal'], 1, 'Medium',
            'Ribosomes are the sites of protein synthesis, reading mRNA to assemble amino acids into polypeptide chains.'),
        _Question('The endoplasmic reticulum involved in protein synthesis is called:', ['Smooth ER', 'Rough ER', 'Golgi body', 'Lysosome'], 1, 'Medium',
            'Rough ER has ribosomes attached to its surface and is involved in protein synthesis and transport.'),
        _Question('Which of the following is a prokaryotic cell?', ['Plant cell', 'Animal cell', 'Bacterial cell', 'Fungal cell'], 2, 'Medium',
            'Bacteria are prokaryotes — they lack a membrane-bound nucleus and other membrane-bound organelles.'),
      ],
    ),
    const _QBank(
      3,
      'Movement of Substances',
      [
        _Question('What is osmosis?', ['Movement of solute particles', 'Movement of water through a partially permeable membrane', 'Active transport of ions', 'Diffusion of gases'], 1, 'Easy',
            'Osmosis is the net movement of water molecules from a region of higher water potential to a region of lower water potential through a partially permeable membrane.'),
        _Question('In which direction does active transport move substances?', ['Down the concentration gradient', 'Against the concentration gradient', 'Randomly', 'Only in plant cells'], 1, 'Medium',
            'Active transport moves substances against the concentration gradient, requiring energy (ATP).'),
        _Question('A cell placed in a hypertonic solution will:', ['Gain water and swell', 'Lose water and shrink', 'Stay the same size', 'Divide'], 1, 'Medium',
            'In a hypertonic solution, water potential outside is lower, so water leaves the cell by osmosis, causing it to shrink.'),
        _Question('Which process involves the movement of particles from high to low concentration?', ['Active transport', 'Osmosis', 'Diffusion', 'Endocytosis'], 2, 'Easy',
            'Diffusion is the net movement of particles from a region of higher concentration to a region of lower concentration.'),
        _Question('Root hair cells absorb mineral ions by:', ['Osmosis', 'Diffusion', 'Active transport', 'Phagocytosis'], 2, 'Medium',
            'Mineral ions are absorbed against their concentration gradient by active transport, requiring energy from respiration.'),
        _Question('What happens to a red blood cell in distilled water?', ['It shrinks', 'It swells and bursts (haemolysis)', 'Nothing happens', 'It becomes crenated'], 1, 'Medium',
            'Distilled water is hypotonic to red blood cells. Water enters by osmosis, causing the cell to swell and burst.'),
        _Question('The partially permeable membrane allows passage of:', ['All molecules', 'Only water molecules', 'Only large molecules', 'Water and small solute molecules'], 3, 'Medium',
            'Partially permeable membranes allow water and small molecules through but block larger solute molecules.'),
      ],
    ),
    const _QBank(
      4,
      'Nutrition',
      [
        _Question('Which vitamin is produced when human skin is exposed to sunlight?', ['Vitamin A', 'Vitamin B', 'Vitamin C', 'Vitamin D'], 3, 'Easy',
            'Vitamin D is synthesised in the skin when exposed to UV light. It is essential for calcium absorption.'),
        _Question('Which food test uses iodine solution?', ['Protein test', 'Lipid test', 'Starch test', 'Sugar test'], 2, 'Easy',
            'Iodine solution turns blue-black in the presence of starch.'),
        _Question('What is the main function of roughage in the diet?', ['Provides energy', 'Aids digestion and prevents constipation', 'Builds muscle tissue', 'Produces hormones'], 1, 'Easy',
            'Roughage (dietary fibre) adds bulk to food and aids the movement of food through the digestive system.'),
        _Question('Which organ produces bile?', ['Stomach', 'Pancreas', 'Liver', 'Small intestine'], 2, 'Easy',
            'The liver produces bile, which is stored in the gall bladder and released into the small intestine to emulsify fats.'),
        _Question('The enzyme that breaks down starch in the mouth is:', ['Pepsin', 'Amylase (salivary)', 'Lipase', 'Trypsin'], 1, 'Medium',
            'Salivary amylase (ptyalin) begins the breakdown of starch into maltose in the mouth.'),
        _Question('Which type of malnutrition is caused by protein deficiency?', ['Obesity', 'Kwashiorkor', 'Scurvy', 'Rickets'], 1, 'Medium',
            'Kwashiorkor is caused by protein deficiency, leading to oedema, thinning hair, and skin problems.'),
        _Question('Pellagra is caused by deficiency of which vitamin?', ['Vitamin A', 'Vitamin B3 (Niacin)', 'Vitamin C', 'Vitamin D'], 2, 'Medium',
            'Pellagra is caused by niacin (vitamin B3) deficiency, causing dermatitis, diarrhoea, and dementia.'),
        _Question('Which mineral is essential for the formation of haemoglobin?', ['Calcium', 'Iron', 'Sodium', 'Potassium'], 1, 'Easy',
            'Iron is a key component of haemoglobin, the oxygen-carrying protein in red blood cells.'),
      ],
    ),
    const _QBank(
      5,
      'Transport in Plants & Animals',
      [
        _Question('Which tissue transports water and minerals upward in plants?', ['Phloem', 'Xylem', 'Cambium', 'Epidermis'], 1, 'Easy',
            'Xylem tissue transports water and dissolved minerals from roots to leaves.'),
        _Question('What is the function of the heart\'s valves?', ['Pump blood', 'Prevent backflow of blood', 'Produce blood cells', 'Filter blood'], 1, 'Easy',
            'Heart valves ensure blood flows in one direction by preventing backflow.'),
        _Question('Which blood vessel carries blood AWAY from the heart?', ['Vein', 'Capillary', 'Artery', 'Vena cava'], 2, 'Easy',
            'Arteries carry oxygenated blood away from the heart under high pressure.'),
        _Question('The process by which water moves up through xylem against gravity is explained by:', ['Capillary action only', 'Transpiration pull and cohesion-tension theory', 'Active transport only', 'Root pressure only'], 1, 'Hard',
            'The cohesion-tension theory explains water movement through xylem via transpiration pull, cohesion, and adhesion of water molecules.'),
        _Question('Which component of blood fights infections?', ['Red blood cells', 'White blood cells', 'Platelets', 'Plasma'], 1, 'Easy',
            'White blood cells are part of the immune system and fight pathogens.'),
        _Question('What is the role of platelets in blood clotting?', ['Carry oxygen', 'Clump at wound site to form clot', 'Produce antibodies', 'Transport nutrients'], 1, 'Medium',
            'Platelets aggregate at wound sites and release chemicals that initiate the clotting cascade.'),
        _Question('Which blood group is known as the universal donor?', ['A', 'B', 'AB', 'O'], 3, 'Medium',
            'Blood group O has no A or B antigens, so it can be transfused to patients of any blood group.'),
      ],
    ),
    const _QBank(
      6,
      'Gaseous Exchange & Respiration',
      [
        _Question('What is the gas exchange surface in human lungs?', ['Trachea', 'Bronchioles', 'Alveoli', 'Bronchi'], 2, 'Easy',
            'Alveoli are tiny air sacs with thin walls and large surface area for efficient gas exchange.'),
        _Question('What is the equation for aerobic respiration?', ['Glucose + Oxygen → Carbon dioxide + Water + Energy', 'Glucose → Ethanol + CO₂ + Energy', 'Carbon dioxide + Water → Glucose + Oxygen', 'Glucose → Lactic acid + Energy'], 0, 'Easy',
            'Aerobic respiration: C₆H₁₂O₆ + 6O₂ → 6CO₂ + 6H₂O + ATP (energy).'),
        _Question('Which process produces lactic acid in muscles?', ['Aerobic respiration', 'Anaerobic respiration in animals', 'Fermentation in yeast', 'Photosynthesis'], 1, 'Medium',
            'Anaerobic respiration in animal muscles produces lactic acid, causing muscle fatigue.'),
        _Question('What is the role of the diaphragm in breathing?', ['Pumps blood', 'Contracts to increase thoracic volume during inhalation', 'Filters air', 'Produces mucus'], 1, 'Medium',
            'The diaphragm contracts and flattens during inhalation, increasing thoracic volume and decreasing pressure.'),
        _Question('Why are alveoli described as having a large surface area?', ['They are very thick', 'There are millions of tiny sacs', 'They are lined with muscle', 'They have no blood supply'], 1, 'Easy',
            'There are approximately 300 million alveoli in the lungs, providing a combined surface area of about 70 m².'),
        _Question('In plants, gas exchange occurs through:', ['Stomata', 'Alveoli', 'Gills', 'Spiracles'], 0, 'Easy',
            'Stomata are tiny pores, mainly on the underside of leaves, that allow gas exchange.'),
        _Question('Which gas is exhaled in higher concentration than inhaled?', ['Oxygen', 'Nitrogen', 'Carbon dioxide', 'Hydrogen'], 2, 'Easy',
            'Exhaled air contains more CO₂ (~4%) than inhaled air (~0.04%) due to cellular respiration.'),
      ],
    ),
    const _QBank(
      7,
      'Excretion & Homeostasis',
      [
        _Question('What is the functional unit of the kidney?', ['Neuron', 'Nephron', 'Alveolus', 'Villus'], 1, 'Easy',
            'Each kidney contains about 1 million nephrons that filter blood and produce urine.'),
        _Question('Which hormone controls blood sugar levels by promoting glucose uptake?', ['Adrenaline', 'Thyroxine', 'Insulin', 'Growth hormone'], 2, 'Easy',
            'Insulin is produced by the pancreas and promotes the uptake of glucose by cells, lowering blood sugar.'),
        _Question('What is the process by which the kidney filters blood?', ['Excretion only', 'Ultrafiltration and selective reabsorption', 'Diffusion only', 'Active transport only'], 1, 'Medium',
            'Kidney filtration involves ultrafiltration at the glomerulus and selective reabsorption in the renal tubule.'),
        _Question('Sweating helps regulate body temperature by:', ['Producing heat', 'Evaporative cooling', 'Insulation', 'Generating energy'], 1, 'Easy',
            'Evaporation of sweat from the skin surface removes heat energy, cooling the body.'),
        _Question('Which condition results from insufficient insulin production?', ['Diabetes insipidus', 'Diabetes mellitus', 'Goitre', 'Anaemia'], 1, 'Medium',
            'Diabetes mellitus results from insufficient insulin production (Type 1) or insulin resistance (Type 2).'),
        _Question('What is the role of the hypothalamus in homeostasis?', ['Produces insulin', 'Acts as the body\'s thermostat', 'Filters blood', 'Produces bile'], 1, 'Medium',
            'The hypothalamus monitors blood temperature and triggers responses to maintain a constant body temperature.'),
      ],
    ),
    const _QBank(
      8,
      'Coordination & Response',
      [
        _Question('Which part of the brain controls voluntary actions?', ['Cerebellum', 'Medulla oblongata', 'Cerebrum', 'Hypothalamus'], 2, 'Easy',
            'The cerebrum controls voluntary actions, intelligence, memory, and sensory perception.'),
        _Question('What is the function of a reflex arc?', ['Speed up thought processes', 'Provide rapid, automatic response to stimuli', 'Store memories', 'Control breathing'], 1, 'Medium',
            'Reflex arcs allow rapid involuntary responses, bypassing the brain for faster reaction times.'),
        _Question('Which sense organ detects changes in light intensity?', ['Cochlea', 'Retina', 'Olfactory bulb', 'Taste buds'], 1, 'Easy',
            'The retina contains photoreceptor cells (rods and cones) that detect light.'),
        _Question('The myelin sheath around nerve fibres:', ['Carries impulses slowly', 'Insulates and speeds up nerve impulses', 'Produces neurotransmitters', 'Connects to muscles'], 1, 'Medium',
            'The myelin sheath insulates nerve fibres and allows saltatory conduction, speeding up impulse transmission.'),
        _Question('Which hormone is responsible for the fight-or-flight response?', ['Insulin', 'Adrenaline', 'Thyroxine', 'Oestrogen'], 1, 'Easy',
            'Adrenaline increases heart rate, blood pressure, and glucose availability during stress.'),
        _Question('What happens at a synapse?', ['Bones grow', 'Chemical neurotransmitters pass between neurons', 'Blood is filtered', 'Oxygen is absorbed'], 1, 'Medium',
            'At a synapse, electrical signals are converted to chemical signals (neurotransmitters) that cross the gap between neurons.'),
      ],
    ),
    const _QBank(
      9,
      'Reproduction',
      [
        _Question('What is the difference between asexual and sexual reproduction?', ['Both involve gametes', 'Asexual involves one parent; sexual involves two', 'Asexual requires fertilisation', 'Both produce identical offspring'], 1, 'Easy',
            'Asexual reproduction involves one parent producing genetically identical offspring. Sexual reproduction involves two parents and genetic variation.'),
        _Question('In flowering plants, fertilisation occurs in the:', ['Anther', 'Ovary', 'Stigma', 'Ovule'], 3, 'Medium',
            'The ovule contains the female gamete. After pollination, the pollen tube grows down to the ovule for fertilisation.'),
        _Question('Which process produces genetically identical cells?', ['Meiosis', 'Mitosis', 'Fertilisation', 'Pollination'], 1, 'Easy',
            'Mitosis produces two genetically identical daughter cells.'),
        _Question('What is the function of the placenta in mammals?', ['Produces eggs', 'Provides nutrition and gas exchange between mother and fetus', 'Stores food', 'Produces sperm'], 1, 'Medium',
            'The placenta allows exchange of nutrients, oxygen, and waste between the mother\'s blood and the fetus\'s blood.'),
        _Question('Sperm cells have a tail (flagellum) for:', ['Protection', 'Swimming to the egg', 'Absorbing nutrients', 'Recognising the egg'], 1, 'Easy',
            'The flagellum propels the sperm cell through the female reproductive tract to reach the egg.'),
        _Question('What is the role of pollen in plant reproduction?', ['Produces roots', 'Contains male gametes for fertilisation', 'Produces food', 'Attracts insects only'], 1, 'Medium',
            'Pollen grains contain the male gametes (sperm cells) needed for fertilisation of the ovule.'),
      ],
    ),
    const _QBank(
      10,
      'Genetics & Inheritance',
      [
        _Question('What is the genotype of an organism?', ['Its physical appearance', 'Its genetic makeup', 'Its behaviour', 'Its habitat'], 1, 'Easy',
            'Genotype refers to the genetic composition (alleles) of an organism.'),
        _Question('In a cross between Tt × Tt, what proportion of offspring are homozygous?', ['1/4', '1/2', '3/4', 'All'], 0, 'Medium',
            'Tt × Tt produces: TT (1/4), Tt (2/4), tt (1/4). Homozygous = TT + tt = 1/2.'),
        _Question('Which structure carries genes?', ['Mitochondria', 'Chromosomes', 'Ribosomes', 'Cell membrane'], 1, 'Easy',
            'Genes are segments of DNA located on chromosomes in the nucleus.'),
        _Question('What is a dominant allele?', ['An allele only expressed in homozygous state', 'An allele always expressed when present', 'An allele that skips generations', 'An allele found only in males'], 1, 'Medium',
            'A dominant allele is expressed (shows its trait) even when only one copy is present (heterozygous).'),
        _Question('Sickle cell anaemia is an example of:', ['Sex-linked inheritance', 'Co-dominance', 'Incomplete dominance', 'Environmental variation'], 1, 'Hard',
            'Sickle cell anaemia shows co-dominance: HbA HbS individuals have some normal and some sickle-shaped red blood cells.'),
        _Question('Which type of variation is acquired during an organism\'s lifetime?', ['Genetic variation', 'Environmental variation', 'Mutation', 'Meiosis'], 1, 'Medium',
            'Environmental (acquired) variation develops during life — e.g., language, scars, fitness — and is not inherited.'),
      ],
    ),
    const _QBank(
      11,
      'Ecology',
      [
        _Question('What is a community in ecology?', ['A single species', 'All organisms of different species in an area', 'The non-living environment', 'A food chain'], 1, 'Easy',
            'A community consists of all the living organisms of different species in a particular area.'),
        _Question('Which factor is density-dependent?', ['Temperature', 'Rainfall', 'Competition for food', 'Natural disasters'], 2, 'Medium',
            'Density-dependent factors (competition, predation, disease) have greater effect as population density increases.'),
        _Question('What is a food chain?', ['A series of habitats', 'A pathway showing transfer of energy from one organism to another', 'A group of the same species', 'A type of ecosystem'], 1, 'Easy',
            'A food chain shows the linear transfer of energy and nutrients from one organism to the next.'),
        _Question('Which of these is a producer?', ['Lion', 'Grass', 'Eagle', 'Frog'], 1, 'Easy',
            'Producers (autotrophs) make their own food through photosynthesis. Grass is a producer.'),
        _Question('Biodegradable waste is broken down by:', ['Plants', 'Decomposers (bacteria and fungi)', 'Sunlight only', 'Water only'], 1, 'Medium',
            'Decomposers (bacteria and fungi) break down dead organic matter, recycling nutrients back into the soil.'),
        _Question('An ecosystem includes:', ['Only living organisms', 'Only non-living factors', 'Both living organisms and their physical environment', 'Only predators'], 2, 'Easy',
            'An ecosystem consists of all living organisms (biotic) in an area and their physical environment (abiotic).'),
      ],
    ),
    const _QBank(
      12,
      'Microorganisms',
      [
        _Question('Which microorganism causes malaria?', ['Bacteria', 'Virus', 'Plasmodium (protozoan)', 'Fungus'], 2, 'Easy',
            'Malaria is caused by Plasmodium protozoa, transmitted by female Anopheles mosquitoes.'),
        _Question('What is the role of bacteria in the nitrogen cycle?', ['Absorb nitrogen from air', 'Convert nitrogen into nitrates (nitrification)', 'Produce oxygen', 'Decompose rocks'], 1, 'Medium',
            'Nitrifying bacteria convert ammonia into nitrates that plants can absorb from the soil.'),
        _Question('Which method is used to preserve food by killing microorganisms?', ['Freezing', 'Sterilisation (heat treatment)', 'Dilution', 'Evaporation only'], 1, 'Medium',
            'Sterilisation (e.g., pasteurisation, canning) kills microorganisms to prevent food spoilage.'),
        _Question('Viruses differ from bacteria because viruses:', ['Have cell walls', 'Can reproduce independently', 'Are much smaller and need a host cell to multiply', 'Are multicellular'], 2, 'Medium',
            'Viruses are acellular and can only reproduce inside a living host cell.'),
        _Question('Antibiotics are effective against:', ['Viruses', 'Bacteria', 'Fungi only', 'All microorganisms'], 1, 'Medium',
            'Antibiotics kill or inhibit the growth of bacteria. They are NOT effective against viruses.'),
        _Question('Which of these is a beneficial use of microorganisms?', ['Causing disease only', 'Making yoghurt and cheese (fermentation)', 'Producing pollutants', 'Destroying crops'], 1, 'Easy',
            'Microorganisms are used in food production (yoghurt, cheese, bread), medicine (antibiotics), and waste treatment.'),
      ],
    ),
    const _QBank(
      13,
      'Disease & Immunity',
      [
        _Question('What is a pathogen?', ['A type of nutrient', 'A disease-causing organism', 'An antibody', 'A white blood cell'], 1, 'Easy',
            'A pathogen is any organism that causes disease (bacteria, viruses, fungi, protozoa).'),
        _Question('Which white blood cell produces antibodies?', ['Phagocyte', 'Lymphocyte (B-cell)', 'Platelet', 'Red blood cell'], 1, 'Medium',
            'B-lymphocytes produce antibodies that specifically target and neutralise antigens.'),
        _Question('What is the difference between active and passive immunity?', ['There is no difference', 'Active immunity produces antibodies; passive immunity receives antibodies', 'Passive is permanent; active is temporary', 'Both require vaccination'], 1, 'Medium',
            'Active immunity: body produces its own antibodies (e.g., after infection or vaccination). Passive immunity: antibodies received from another source (e.g., mother\'s milk).'),
        _Question('Vaccination works by:', ['Killing all bacteria in the body', 'Stimulating the immune system to produce antibodies against a specific pathogen', 'Replacing damaged cells', 'Increasing body temperature'], 1, 'Medium',
            'Vaccines introduce weakened or dead pathogens (or their antigens), triggering the immune system to produce antibodies and memory cells.'),
        _Question('Which disease is caused by a virus?', ['Tuberculosis', 'Cholera', 'AIDS (HIV)', 'Typhoid'], 2, 'Easy',
            'HIV/AIDS is caused by the Human Immunodeficiency Virus, which attacks the immune system.'),
        _Question('What is herd immunity?', ['Immunity of a single person', 'Protection of a population when a high proportion is immune', 'Immunity only in herds of animals', 'Immunity from food'], 1, 'Medium',
            'Herd immunity occurs when enough people are immune to a disease, making its spread unlikely and protecting those who are not immune.'),
      ],
    ),
    const _QBank(
      14,
      'Environment & Conservation',
      [
        _Question('What is deforestation?', ['Planting new trees', 'Clearing of forest areas permanently', 'Natural forest growth', 'Forest fire recovery'], 1, 'Easy',
            'Deforestation is the permanent removal of forest cover for agriculture, urbanisation, or logging.'),
        _Question('Which greenhouse gas is produced most by human activities?', ['Methane', 'Carbon dioxide', 'Nitrous oxide', 'Ozone'], 1, 'Medium',
            'CO₂ is the primary greenhouse gas from burning fossil fuels, deforestation, and industrial processes.'),
        _Question('What is an endangered species?', ['A species that is common', 'A species at risk of extinction', 'A newly discovered species', 'A species only found in zoos'], 1, 'Easy',
            'An endangered species is one whose population has declined to a level that it is at risk of extinction.'),
        _Question('Which of these is a method of conservation?', ['Overfishing', 'Establishment of national parks', 'Burning fossil fuels', 'Using pesticides'], 1, 'Medium',
            'National parks, reserves, and protected areas preserve natural habitats and biodiversity.'),
        _Question('The greenhouse effect causes:', ['Cooling of the Earth', 'Warming of the Earth\'s atmosphere', 'Depletion of the ozone layer', 'Acid rain only'], 1, 'Medium',
            'Greenhouse gases trap heat in the atmosphere, causing global warming and climate change.'),
        _Question('Which practice helps conserve soil?', ['Overgrazing', 'Terracing and crop rotation', 'Monoculture', 'Deforestation'], 1, 'Medium',
            'Terracing reduces water erosion on slopes; crop rotation maintains soil fertility and reduces erosion.'),
      ],
    ),
    const _QBank(
      15,
      'Practical Skills',
      [
        _Question('In a biological drawing, labels should be placed:', ['On the left side only', 'On the right side with horizontal lines', 'Anywhere randomly', 'Below the drawing only'], 1, 'Easy',
            'Labels should be on the right side, connected with straight horizontal lines drawn with a ruler.'),
        _Question('What is the first step when using a light microscope?', ['Switch to high power', 'Place slide on stage and start on lowest power', 'Add oil immersion', 'Look through high power lens'], 1, 'Easy',
            'Always start with the lowest power objective lens to locate the specimen before increasing magnification.'),
        _Question('To test for starch, which reagent is used?', ["Benedict's solution", 'Iodine solution', 'Biuret reagent', 'Ethanol'], 1, 'Easy',
            'Iodine solution turns blue-black in the presence of starch.'),
        _Question('A fair test changes:', ['All variables', 'Only one variable (independent variable)', 'No variables', 'Only the dependent variable'], 1, 'Easy',
            'A fair test changes only the independent variable while keeping all other variables constant.'),
        _Question('What does a line of best fit show on a graph?', ['The exact data points', 'The general trend in the data', 'The maximum value', 'The average'], 1, 'Medium',
            'A line of best fit shows the general trend in the data, smoothing out random variations.'),
        _Question('How many times should an experiment be repeated for reliability?', ['Once', 'At least 3 times', '100 times', 'Only twice'], 1, 'Medium',
            'Repeating an experiment at least 3 times allows calculation of a mean and identification of anomalous results.'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startQuiz() {
    final pool = _selectedChapter == -1
        ? _allQuestions.expand((b) => b.questions).toList()
        : _allQuestions
            .where((b) => b.chapter == _selectedChapter + 1)
            .expand((b) => b.questions)
            .toList();

    var filtered = _difficulty == 'All'
        ? pool
        : pool.where((q) => q.difficulty == _difficulty).toList();

    if (filtered.length < _questionCount) _questionCount = filtered.length;
    filtered.shuffle(Random());
    final picked = filtered.take(_questionCount).toList();

    setState(() {
      _quizActive = true;
      _quizQuestions = picked;
      _currentQuestion = 0;
      _selectedAnswer = null;
      _answered = false;
      _score = 0;
      _results = [];
      _timeLeft = 30;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 1) {
        t.cancel();
        _autoAnswer();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _autoAnswer() {
    setState(() {
      _answered = true;
      _results.add(_QuizResult(
          _quizQuestions[_currentQuestion], -1, false, 0));
    });
    _nextQuestion();
  }

  void _submitAnswer() {
    if (_selectedAnswer == null || _answered) return;
    _timer?.cancel();
    final q = _quizQuestions[_currentQuestion];
    final correct = _selectedAnswer == q.correctIndex;
    final timeTaken = 30 - _timeLeft;
    if (correct) _score++;
    setState(() {
      _answered = true;
      _results.add(_QuizResult(q, _selectedAnswer!, correct, timeTaken));
    });
  }

  void _nextQuestion() {
    if (_currentQuestion >= _quizQuestions.length - 1) {
      _finishQuiz();
      return;
    }
    setState(() {
      _currentQuestion++;
      _selectedAnswer = null;
      _answered = false;
      _timeLeft = 30;
    });
    _startTimer();
  }

  void _finishQuiz() {
    _timer?.cancel();
    setState(() => _quizActive = false);
  }

  void _resetQuiz() {
    setState(() {
      _quizActive = false;
      _quizQuestions = [];
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
            child: _quizActive
                ? _buildQuizView(isDesktop)
                : _results.isNotEmpty
                    ? _buildResultsView(isDesktop)
                    : _buildSetupView(isDesktop),
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
            const SizedBox(width: 14),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _bioGreenGlow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.quiz_rounded, color: _bioGreen, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_quizActive
                      ? 'Question ${_currentQuestion + 1} of ${_quizQuestions.length}'
                      : 'Practice Centre'),
                  Text('MSCE Biology Quiz Engine',
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                ],
              ),
            ),
            if (_quizActive) ...[
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
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _bioGreenGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_score/${_results.length}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _bioGreen)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSetupView(bool isDesktop) {
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
                  child: const Icon(Icons.quiz_rounded, color: _bioGreen, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MSCE Biology Practice',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('200+ MSCE-style questions across 15 chapters. Choose your chapter, difficulty, and number of questions.',
                          style: TextStyle(fontSize: 12, color: context.colors.textMuted, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Select Chapter'),
          const SizedBox(height: 12),
          _buildChapterDropdown(),
          const SizedBox(height: 20),
          _buildSectionTitle('Difficulty'),
          const SizedBox(height: 12),
          _buildDifficultySelector(),
          const SizedBox(height: 20),
          _buildSectionTitle('Number of Questions'),
          const SizedBox(height: 12),
          _buildCountSelector(),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startQuiz,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Start Quiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _bioGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Quick Start by Chapter'),
          const SizedBox(height: 12),
          _buildChapterCards(isDesktop),
        ],
      ),
    );
  }

  Widget _buildChapterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: DropdownButton<int>(
        value: _selectedChapter,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: context.colors.surface,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
        items: [
          const DropdownMenuItem(value: -1, child: Text('All Chapters')),
          for (var i = 0; i < _chapters.length; i++)
            DropdownMenuItem(value: i, child: Text(_chapters[i])),
        ],
        onChanged: (v) => setState(() => _selectedChapter = v ?? -1),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    final diffs = ['All', 'Easy', 'Medium', 'Hard'];
    return Row(
      children: diffs.map((d) {
        final selected = _difficulty == d;
        final color = d == 'Easy'
            ? context.colors.success
            : d == 'Medium'
                ? context.colors.warning
                : d == 'Hard'
                    ? context.colors.error
                    : _bioGreen;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _difficulty = d),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.15) : context.colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? color : context.colors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(d,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? color : context.colors.textSecondary)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCountSelector() {
    final counts = [5, 10, 15, 20];
    return Row(
      children: counts.map((c) {
        final selected = _questionCount == c;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _questionCount = c),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? _bioGreenGlow : context.colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? _bioGreen : context.colors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text('$c',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected ? _bioGreen : context.colors.textSecondary)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChapterCards(bool isDesktop) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < _chapters.length; i++)
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedChapter = i;
                _questionCount = 10;
              });
              _startQuiz();
            },
            child: Container(
              width: isDesktop ? 200 : (MediaQuery.of(context).size.width / 2 - 22),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _bioGreenGlow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: _bioGreen)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_chapters[i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuizView(bool isDesktop) {
    if (_quizQuestions.isEmpty) return const SizedBox.shrink();
    final q = _quizQuestions[_currentQuestion];
    final progress = (_currentQuestion + 1) / _quizQuestions.length;

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
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: q.difficulty == 'Easy'
                      ? context.colors.success.withValues(alpha: 0.15)
                      : q.difficulty == 'Medium'
                          ? context.colors.warning.withValues(alpha: 0.15)
                          : context.colors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(q.difficulty,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: q.difficulty == 'Easy'
                            ? context.colors.success
                            : q.difficulty == 'Medium'
                                ? context.colors.warning
                                : context.colors.error)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_quizQuestions[_currentQuestion].question,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                        height: 1.3)),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                      border: Border.all(color: borderColor, width: isSelected || (_answered && isCorrect) ? 1.5 : 1),
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
                        const SizedBox(width: 14),
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
              child: Text(q.explanation,
                  style: TextStyle(
                      fontSize: 12, color: context.colors.textSecondary, height: 1.5)),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _answered
                  ? _nextQuestion
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
                      ? _currentQuestion >= _quizQuestions.length - 1
                          ? 'View Results'
                          : 'Next Question'
                      : 'Submit Answer',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(bool isDesktop) {
    final total = _quizQuestions.length;
    final pct = total > 0 ? (_score / total * 100).round() : 0;
    final grade = pct >= 80
        ? 'A'
        : pct >= 70
            ? 'B'
            : pct >= 60
                ? 'C'
                : pct >= 50
                    ? 'D'
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
                const SizedBox(height: 16),
                Text('$_score / $total',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                Text('$pct% — $grade',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: gradeColor)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildResultStat('Correct', '$_score', context.colors.success),
                    const SizedBox(width: 24),
                    _buildResultStat('Wrong', '${total - _score}', context.colors.error),
                    const SizedBox(width: 24),
                    _buildResultStat('Time', _formatTotalTime(), context.colors.info),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Question Review'),
          const SizedBox(height: 12),
          for (var i = 0; i < _results.length; i++)
            _buildReviewCard(i, _results[i]),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _resetQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.surface,
                    foregroundColor: context.colors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: context.colors.border)),
                  ),
                  child: const Text('New Quiz',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _startQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bioGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Retry Same Settings',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
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
        const SizedBox(height: 4),
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

  Widget _buildReviewCard(int index, _QuizResult r) {
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
              const SizedBox(width: 10),
              Expanded(
                child: Text('${index + 1}. ${r.question.question}',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
              ),
            ],
          ),
          if (!r.correct) ...[
            const SizedBox(height: 8),
            Text(
                'Your answer: ${r.selected >= 0 ? r.question.options[r.selected] : 'No answer'}',
                style: TextStyle(fontSize: 12, color: context.colors.error)),
            Text('Correct answer: ${r.question.options[r.question.correctIndex]}',
                style: TextStyle(fontSize: 12, color: context.colors.success)),
            const SizedBox(height: 6),
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
            gradient: const LinearGradient(colors: [_bioGreen, _bioGreenDark]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary, letterSpacing: -0.3)),
      ],
    );
  }
}

class _QBank {
  final int chapter;
  final String chapterName;
  final List<_Question> questions;
  const _QBank(this.chapter, this.chapterName, this.questions);
}

class _Question {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String difficulty;
  final String explanation;
  const _Question(this.question, this.options, this.correctIndex,
      this.difficulty, this.explanation);
}

class _QuizResult {
  final _Question question;
  final int selected;
  final bool correct;
  final int timeTaken;
  const _QuizResult(this.question, this.selected, this.correct, this.timeTaken);
}
