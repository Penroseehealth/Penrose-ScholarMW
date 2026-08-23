import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

const Color _bioGreen = Color(0xFF10B981);
const Color _bioGreenDark = Color(0xFF059669);
const Color _bioGreenGlow = Color(0x2210B981);

class BiologyMockExamScreen extends StatefulWidget {
  BiologyMockExamScreen({super.key});

  @override
  State<BiologyMockExamScreen> createState() => _BiologyMockExamScreenState();
}

class _BiologyMockExamScreenState extends State<BiologyMockExamScreen> {
  static const int _secondsPerQuestion = 60;

  bool _examActive = false;
  _MockExam? _currentExam;
  List<_MQ> _questions = [];
  int _currentQuestion = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  int _timeLeft = _secondsPerQuestion;
  Timer? _timer;
  List<_ExamResult> _results = [];

  static const List<_MockExam> _mockExams = [
    _MockExam('Cell Biology & Transport',
        'Covers introduction to biology, cell structure, movement of substances, transport systems and practical skills.', [
      _MQ('Which life process involves the removal of metabolic waste products such as urea and carbon dioxide from the body?',
          ['Nutrition', 'Respiration', 'Excretion', 'Reproduction'], 2, 'Easy',
          'Excretion is the removal of toxic waste products of metabolism, such as carbon dioxide from the lungs and urea from the kidneys.'),
      _MQ('A young maize seedling grows taller over several weeks. Which characteristic of living things does this demonstrate?',
          ['Sensitivity', 'Excretion', 'Respiration', 'Growth'], 3, 'Easy',
          'Growth is a permanent increase in size and dry mass of an organism, brought about by cell division and cell enlargement.'),
      _MQ('Which sequence shows the correct order of biological organisation from smallest to largest?',
          ['Cell â†’ Tissue â†’ Organ â†’ Organ system', 'Organ â†’ Tissue â†’ Cell â†’ Organism', 'Tissue â†’ Cell â†’ Organ â†’ Organism', 'Cell â†’ Organ â†’ Tissue â†’ Organism'], 0, 'Easy',
          'Cells group together to form tissues, tissues cooperate to form organs, organs form organ systems, and organ systems make up the whole organism.'),
      _MQ('In an investigation on the effect of light intensity on plant growth, the independent variable is:',
          ['Plant height', 'Amount of water', 'Light intensity', 'Type of soil'], 2, 'Medium',
          'The independent variable is the factor deliberately changed by the investigator, which here is light intensity. Plant height is the dependent variable being measured.'),
      _MQ('A student records observations and analyses collected data. The final step of the scientific method is:',
          ['Forming a hypothesis', 'Drawing a conclusion', 'Asking a question', 'Collecting equipment'], 1, 'Medium',
          'After collecting and analysing data, conclusions are drawn to support or reject the original hypothesis, completing the investigation.'),
      _MQ('Why should an experiment be repeated several times before drawing conclusions?',
          ['To use up spare materials', 'To guarantee the hypothesis is correct', 'To improve reliability by reducing random errors', 'To make the experiment take longer'], 2, 'Hard',
          'Repeating an experiment and averaging the results reduces the influence of random errors and anomalies, making the conclusions far more reliable.'),
      _MQ('Which organelle releases energy from glucose during aerobic respiration?',
          ['Nucleus', 'Mitochondrion', 'Ribosome', 'Vacuole'], 1, 'Easy',
          'Mitochondria are the sites of aerobic respiration, transferring energy from glucose into ATP that powers cellular activities.'),
      _MQ('Which structure controls the activities of the cell and contains chromosomes?',
          ['Cell wall', 'Cytoplasm', 'Nucleus', 'Cell membrane'], 2, 'Easy',
          'The nucleus contains DNA organised into chromosomes, which direct all cell activities and carry the genetic information passed to daughter cells.'),
      _MQ('Which pigment inside chloroplasts absorbs light energy for photosynthesis?',
          ['Haemoglobin', 'Melanin', 'Carotene', 'Chlorophyll'], 3, 'Easy',
          'Chlorophyll is the green pigment that absorbs light energy and converts it into chemical energy during photosynthesis.'),
      _MQ('A cell viewed under the microscope lacks a true nucleus and has its DNA free in the cytoplasm. It is most likely a:',
          ['Plant cell', 'Animal cell', 'Bacterial cell', 'Fungal cell'], 2, 'Medium',
          'Prokaryotic cells such as bacteria have no membrane-bound nucleus; their DNA lies free in the cytoplasm as a single circular chromosome.'),
      _MQ('Fully grown plant cells do not burst when placed in pure water mainly because:',
          ['They have no cell membrane', 'Their cellulose cell wall prevents excessive swelling', 'They actively pump water out', 'Their vacuoles disappear'], 1, 'Medium',
          'The rigid cellulose cell wall resists the inward osmotic flow, building turgor pressure that stops further water entry and prevents the cell from bursting.'),
      _MQ('Which organelle modifies, packages and secretes proteins made by ribosomes?',
          ['Golgi apparatus', 'Lysosome', 'Smooth endoplasmic reticulum', 'Nucleolus'], 0, 'Hard',
          'The Golgi apparatus receives proteins from the rough endoplasmic reticulum, modifies and packages them into vesicles, and exports them from the cell.'),
      _MQ('Which process moves particles from a region of higher concentration to a region of lower concentration?',
          ['Active transport', 'Diffusion', 'Osmosis', 'Pinocytosis'], 1, 'Easy',
          'Diffusion is the net passive movement of particles down a concentration gradient, continuing until equilibrium is reached.'),
      _MQ('Root hair cells absorb nitrate ions from dilute soil solutions using:',
          ['Osmosis', 'Diffusion', 'Active transport', 'Evaporation'], 2, 'Medium',
          'Nitrate ions are more concentrated inside root hair cells than in soil water, so they are absorbed against the gradient using energy from respiration.'),
      _MQ('The rate of diffusion increases when:',
          ['The temperature decreases', 'The diffusion distance increases', 'The concentration gradient becomes steeper', 'The molecules become larger'], 2, 'Easy',
          'A steeper concentration gradient, a higher temperature, a shorter diffusion distance and a larger surface area all increase the rate of diffusion.'),
      _MQ('A red blood cell placed in a concentrated salt solution will:',
          ['Swell and burst', 'Remain unchanged', 'Shrink and become crenated', 'Divide into two'], 2, 'Medium',
          'The concentrated salt solution is hypertonic, so water leaves the cell by osmosis, causing it to shrink and become crenated.'),
      _MQ('Which statement about osmosis is correct?',
          ['Osmosis requires energy from ATP', 'Osmosis moves solute particles across a membrane', 'Osmosis moves water from high to low water potential through a partially permeable membrane', 'Osmosis only occurs in animal cells'], 2, 'Medium',
          'Osmosis is the passive net movement of water molecules from a region of higher water potential to a region of lower water potential through a partially permeable membrane.'),
      _MQ('During strenuous exercise, muscle cells absorb glucose against its concentration gradient. The process and energy source are:',
          ['Diffusion using heat energy', 'Osmosis using light energy', 'Active transport using ATP from respiration', 'Evaporation using kinetic energy'], 2, 'Hard',
          'Uptake against a concentration gradient is active transport, powered directly by ATP released during cellular respiration in the mitochondria.'),
      _MQ('Which vessels carry blood away from the heart under high pressure?',
          ['Veins', 'Capillaries', 'Arteries', 'Venules'], 2, 'Easy',
          'Arteries have thick, elastic, muscular walls that withstand and maintain the high pressure of blood pumped out of the heart.'),
      _MQ('Which tissue transports sucrose and amino acids from leaves to growing regions?',
          ['Xylem', 'Phloem', 'Cambium', 'Cuticle'], 1, 'Easy',
          'Phloem sieve tubes carry the organic products of photosynthesis from sources such as mature leaves to sinks such as roots and fruits in a process called translocation.'),
      _MQ('Transpiration is best defined as:',
          ['Loss of water as liquid from roots', 'Loss of water vapour from aerial parts of a plant, mainly through stomata', 'Uptake of mineral salts by roots', 'Movement of food in the phloem'], 1, 'Easy',
          'Transpiration is the evaporation of water from moist mesophyll surfaces inside leaves and its loss as vapour through the stomata, which drives the transpiration stream.'),
      _MQ('The valve between the left atrium and the left ventricle is the:',
          ['Tricuspid valve', 'Semilunar valve', 'Bicuspid (mitral) valve', 'Pulmonary valve'], 2, 'Medium',
          'The bicuspid (mitral) valve separates the left atrium from the left ventricle and prevents blood flowing backwards when the ventricle contracts.'),
      _MQ('Stomata open in daylight because guard cells:',
          ['Become flaccid and shrink', 'Become turgid as they accumulate potassium ions and water', 'Lose all of their water', 'Are covered by a thick cuticle'], 1, 'Hard',
          'In light, guard cells actively accumulate potassium ions, lowering their water potential so water enters by osmosis; the turgid guard cells bow apart and open the pore.'),
      _MQ('In humans, double circulation means that:',
          ['Blood flows twice through each capillary', 'Blood passes through the heart twice in one complete circuit of the body', 'The heart has two chambers only', 'Blood travels only to the lungs'], 1, 'Medium',
          'The pulmonary circuit carries blood from the heart to the lungs and back, while the systemic circuit carries it around the body, so blood passes through the heart twice per complete circuit.'),
      _MQ('Which reagent turns blue-black in the presence of starch?',
          ["Benedict's solution", 'Biuret reagent', 'Iodine solution', 'Ethanol'], 2, 'Easy',
          'Iodine solution changes from brown to blue-black when starch is present, making it the standard laboratory test for starch.'),
      _MQ("Benedict's solution produces a brick-red precipitate when boiled with:",
          ['Proteins', 'Fats', 'Non-reducing starch', 'Reducing sugars such as glucose'], 3, 'Easy',
          "Reducing sugars reduce the blue copper(II) ions in Benedict's solution to form an orange-red precipitate of copper(I) oxide on heating."),
      _MQ('A cell appears 2 mm long under a total magnification of Ã—400. Its actual length is:',
          ['0.005 mm', '0.02 mm', '0.5 mm', '800 mm'], 0, 'Hard',
          'Actual size = image size Ã· magnification = 2 mm Ã· 400 = 0.005 mm.'),
      _MQ('When making a biological drawing, label lines should:',
          ['Cross over each other neatly', 'Be drawn freehand in any direction', 'Touch the specimen directly', 'Be ruled horizontal lines ending exactly on the labelled part'], 3, 'Medium',
          'Labels are written on the right-hand side and joined to the exact structure by straight, horizontal lines drawn with a sharp pencil and ruler, never crossing one another.'),
      _MQ('The white emulsion formed in the ethanol emulsion test indicates the presence of:',
          ['Starch', 'Lipids', 'Vitamin C', 'Protein'], 1, 'Medium',
          'Lipids dissolve in ethanol; when the solution is poured into water, the lipid comes out of solution as a cloudy white emulsion, confirming the presence of fats or oils.'),
      _MQ('In a fair test investigating enzyme activity, all factors except temperature are kept constant. Temperature is therefore the:',
          ['Dependent variable', 'Control variable', 'Independent variable', 'Standardised variable'], 2, 'Medium',
          'The single factor deliberately varied in a fair test is the independent variable; the enzyme activity measured in response is the dependent variable.'),
    ]),
    _MockExam('Nutrition, Health & Disease',
        'Covers nutrition, gaseous exchange and respiration, excretion and homeostasis, microorganisms, and disease and immunity.', [
      _MQ('Which food class provides about 37 kJ per gram, the most concentrated source of energy?',
          ['Carbohydrates', 'Proteins', 'Fats (lipids)', 'Vitamins'], 2, 'Easy',
          'Fats provide roughly 37 kJ per gram, more than twice the energy supplied by carbohydrates or proteins, which provide about 17 kJ per gram.'),
      _MQ('Prolonged deficiency of vitamin C leads to:',
          ['Rickets', 'Scurvy', 'Night blindness', 'Goitre'], 1, 'Easy',
          'Vitamin C is needed for healthy connective tissue; its deficiency causes scurvy, with bleeding gums, joint pain and poor wound healing.'),
      _MQ('Kwashiorkor differs from marasmus because kwashiorkor is specifically caused by:',
          ['Total starvation', 'Severe protein deficiency despite some energy intake', 'Excess vitamin A', 'Iron overload'], 1, 'Medium',
          'Kwashiorkor arises from a lack of protein in the diet, causing oedema and a swollen abdomen, whereas marasmus results from a general shortage of food energy.'),
      _MQ('Most absorption of digested food nutrients occurs in the:',
          ['Stomach', 'Large intestine', 'Ileum of the small intestine', 'Oesophagus'], 2, 'Easy',
          'The ileum is long, thin-walled and lined with villi and microvilli, and is richly supplied with blood capillaries and lacteals for efficient absorption.'),
      _MQ('Bile aids fat digestion by:',
          ['Chemically breaking triglycerides into glycerol', 'Emulsifying large fat droplets into smaller ones, increasing surface area for lipase', 'Neutralising stomach enzymes', 'Absorbing fatty acids directly'], 1, 'Medium',
          'Bile salts emulsify fats physically rather than chemically, breaking large droplets into tiny ones so lipase has a much larger surface area to digest the fat efficiently.'),
      _MQ('An enlarged thyroid gland (goitre) commonly results from a diet lacking:',
          ['Iron', 'Fluorine', 'Iodine', 'Calcium'], 2, 'Medium',
          'Without iodine the thyroid cannot manufacture thyroxine; the gland enlarges as it works harder, producing goitre, which is common where soil and water lack iodine.'),
      _MQ('The flap that stops food entering the trachea during swallowing is the:',
          ['Epiglottis', 'Larynx', 'Bronchus', 'Diaphragm'], 0, 'Easy',
          'The epiglottis folds down over the opening of the trachea during swallowing so that food passes safely into the oesophagus instead of the airway.'),
      _MQ('Which equation represents anaerobic respiration in yeast?',
          ['Glucose â†’ Lactic acid + Energy', 'Glucose + Oxygen â†’ Carbon dioxide + Water', 'Glucose â†’ Ethanol + Carbon dioxide + Energy', 'Carbon dioxide + Water â†’ Glucose + Oxygen'], 2, 'Medium',
          'Yeast ferments sugar anaerobically into ethanol and carbon dioxide, releasing a small amount of energy. This is the basis of brewing and bread making.'),
      _MQ('Exhaled air differs from inhaled air because it contains:',
          ['More oxygen and less carbon dioxide', 'About 16% oxygen and 4% carbon dioxide', 'No nitrogen at all', 'Only carbon dioxide'], 1, 'Medium',
          'Exhaled air still contains about 16% oxygen, but gains roughly 4% carbon dioxide and extra water vapour produced by respiration in the tissues.'),
      _MQ('After a 400 m sprint, breathing remains deep and fast for several minutes because:',
          ['The lungs need rest', 'Extra oxygen is required to oxidise the lactic acid built up in the muscles', 'The heart has stopped pumping', 'Carbon dioxide levels fall sharply'], 1, 'Hard',
          'The oxygen debt is repaid as extra oxygen breaks down the lactic acid produced during anaerobic respiration in the muscles, converting it back to glucose in the liver.'),
      _MQ('Cilia lining the trachea help to:',
          ['Exchange gases directly', 'Trap and sweep dust-laden mucus away from the lungs', 'Produce red blood cells', 'Increase lung volume'], 1, 'Medium',
          'Ciliated cells waft mucus containing trapped dust and microbes upward to the throat, where it is swallowed, protecting the delicate alveoli from infection.'),
      _MQ('Gas exchange in the alveoli is efficient because alveolar walls:',
          ['Are thick and cartilaginous', 'Are one cell thick and moist, with a dense network of capillaries', 'Contain cilia and mucus', 'Store oxygen for later use'], 1, 'Easy',
          'Thin, moist walls and a rich capillary network give a short diffusion distance and steep concentration gradients, greatly speeding up gas exchange.'),
      _MQ('Urea is removed from the blood mainly by the:',
          ['Liver', 'Skin', 'Kidneys', 'Lungs'], 2, 'Easy',
          'The kidneys filter urea from the blood and excrete it in urine; only a small amount of waste is lost through the skin in sweat.'),
      _MQ('Deamination of excess amino acids, producing urea, takes place in the:',
          ['Pancreas', 'Liver', 'Kidney', 'Spleen'], 1, 'Medium',
          'Liver cells remove the amino group from surplus amino acids, forming ammonia, which is quickly converted into the less toxic urea and transported to the kidneys.'),
      _MQ('Antidiuretic hormone (ADH) conserves water by increasing reabsorption in the:',
          ['Glomerulus', 'Collecting duct and kidney tubules', 'Bladder wall', 'Ureter'], 1, 'Medium',
          'ADH released by the pituitary gland makes the collecting duct more permeable to water, so more water is reabsorbed into the blood and concentrated urine is produced.'),
      _MQ('On a hot day, the body loses heat mainly by:',
          ['Vasoconstriction of skin arterioles', 'Shivering', 'Vasodilation of skin arterioles and sweating', 'Decreasing sweat production'], 2, 'Medium',
          'Vasodilation brings more blood close to the skin surface while sweat evaporates, both increasing heat loss so the core temperature stays constant.'),
      _MQ('Body temperature must be kept near 37 Â°C because:',
          ['Enzymes denature outside narrow optimum ranges, slowing vital reactions', 'Blood would freeze below 40 Â°C', 'Cells store heat as energy', 'Breathing stops when the body is warm'], 0, 'Hard',
          'Metabolic enzymes have narrow optimal temperature ranges; deviations either slow reactions or denature the enzymes, disrupting homeostasis and threatening life.'),
      _MQ('Insulin lowers blood glucose by:',
          ['Converting glycogen into glucose in the liver', 'Promoting glucose uptake by cells and conversion to glycogen in the liver', 'Increasing absorption of glucose in the gut', 'Blocking glucose filtration in the kidney'], 1, 'Medium',
          'Insulin from the pancreas enables cells to take up glucose and stimulates the liver to store the excess as glycogen, lowering the blood glucose level.'),
      _MQ('Yeast makes dough rise by releasing:',
          ['Oxygen', 'Ethanol vapour', 'Carbon dioxide from fermentation', 'Nitrogen'], 2, 'Easy',
          'Yeast respires sugar anaerobically, and the trapped carbon dioxide bubbles expand the dough, making the bread light and spongy.'),
      _MQ('Malaria is transmitted by the bite of the:',
          ['Housefly', 'Female Anopheles mosquito', 'Tsetse fly', 'Black ant'], 1, 'Easy',
          'The female Anopheles mosquito transmits Plasmodium protozoa when taking a blood meal, making malaria a major health challenge in Malawi.'),
      _MQ('Antibiotics such as penicillin are useless against influenza because:',
          ['Viruses lack the metabolic machinery and structures that antibiotics target', 'Viruses are too large', 'Antibiotics cannot enter the nose', 'The body destroys antibiotics'], 0, 'Medium',
          'Antibiotics attack bacterial cell walls or bacterial metabolism; viruses hijack host cells and possess none of these targets, so they are completely unaffected.'),
      _MQ('Penicillin was first discovered in a mould by:',
          ['Louis Pasteur', 'Edward Jenner', 'Alexander Fleming', 'Robert Koch'], 2, 'Medium',
          'In 1928 Alexander Fleming noticed that Penicillium mould killed Staphylococcus bacteria on his plates, leading to the first widely used antibiotic.'),
      _MQ('Bacteria reproduce asexually by:',
          ['Binary fission', 'Budding only', 'Meiosis', 'Spore formation only'], 0, 'Medium',
          'Most bacteria multiply rapidly by binary fission, splitting into two identical daughter cells, sometimes every twenty minutes under ideal conditions.'),
      _MQ('Pasteurisation of milk involves:',
          ['Boiling it for several hours', 'Heating it to about 72 Â°C for 15 seconds then cooling it rapidly', 'Freezing it solid', 'Adding strong chemical preservatives'], 1, 'Hard',
          'Brief heating to about 72 Â°C kills pathogenic bacteria while preserving the flavour and nutrients of the milk, and rapid cooling afterwards prevents regrowth.'),
      _MQ('Cholera spreads chiefly through:',
          ['Droplet infection', 'Contaminated drinking water and food', 'Mosquito bites', 'Direct skin contact'], 1, 'Easy',
          'Vibrio cholerae leaves the body in faeces and contaminates water and food; safe drinking water, sanitation and hygiene are the key defences.'),
      _MQ('Which action does NOT transmit HIV?',
          ['Unprotected sexual intercourse', 'Sharing needles', 'Mother to child during birth', 'Shaking hands with an infected person'], 3, 'Easy',
          'HIV passes only through certain body fluids such as blood and sexual secretions; everyday contact such as handshakes, hugs or sharing utensils carries no risk.'),
      _MQ('Tuberculosis most commonly damages the:',
          ['Liver', 'Lungs', 'Kidneys', 'Skin'], 1, 'Easy',
          'Mycobacterium tuberculosis usually infects the lungs, causing a persistent cough, chest pain, night sweats and coughing of blood.'),
      _MQ('Immunity a baby receives through antibodies in breast milk is described as:',
          ['Natural passive immunity', 'Artificial active immunity', 'Natural active immunity', 'Artificial passive immunity'], 0, 'Medium',
          'The antibodies are ready-made and acquired naturally across the placenta or in milk, giving short-lived passive protection until the baby makes its own antibodies.'),
      _MQ('Vaccination protects a person by:',
          ['Providing ready-made antibodies immediately', 'Introducing antigens that stimulate the production of antibodies and memory cells', 'Replacing damaged white blood cells', 'Killing all bacteria in the body'], 1, 'Medium',
          'Weakened or harmless antigen preparations trigger active immunity, so memory cells stand ready to respond rapidly if the real pathogen invades later.'),
      _MQ('Immunity against influenza does not last long mainly because flu viruses:',
          ['Are destroyed instantly by antibodies', 'Mutate rapidly, changing their surface antigens', 'Live only in birds', 'Cannot survive outside water'], 1, 'Hard',
          'Constant mutation alters the viral surface antigens, so memory cells from earlier infections or vaccines may no longer recognise the new strains.'),
    ]),
    _MockExam('Genetics, Ecology & Environment',
        'Covers coordination and response, reproduction, genetics and inheritance, ecology, and environment and conservation.', [
      _MQ('The central nervous system consists of the:',
          ['Nerves and muscles', 'Brain and spinal cord', 'Sense organs only', 'Reflex arcs only'], 1, 'Easy',
          'The brain and spinal cord form the central nervous system, which coordinates information arriving from receptors and issues instructions to effectors.'),
      _MQ('Pulling your hand away from a hot plate is an example of:',
          ['A voluntary action', 'A conditioned reflex', 'A simple spinal reflex', 'Hormonal coordination'], 2, 'Easy',
          'The withdrawal reflex is rapid and involuntary: sensory neurons relay through the spinal cord, bypassing the brain to save precious time.'),
      _MQ('Which hormone raises blood glucose by stimulating the liver to convert glycogen into glucose?',
          ['Insulin', 'Glucagon', 'Adrenaline', 'Thyroxine'], 1, 'Medium',
          'Glucagon from the pancreas acts opposite to insulin, mobilising stored glycogen as glucose whenever the blood sugar level falls too low.'),
      _MQ('Auxin causes a shoot to bend towards light because:',
          ['Auxin destroys cells on the lit side', 'Auxin accumulates on the shaded side, causing faster elongation there', 'Light makes cells shrink', 'Auxin produces sugar in the tip'], 1, 'Medium',
          'Light breaks down auxin on the illuminated side; the shaded side elongates more, curving the shoot towards the light in positive phototropism.'),
      _MQ('In very bright light the pupil becomes smaller because:',
          ['Radial muscles of the iris contract', 'Circular muscles of the iris contract, reducing the light entering the eye', 'The lens becomes thinner', 'The optic nerve shortens'], 1, 'Hard',
          'Bright light triggers contraction of the circular iris muscles while the radial muscles relax, constricting the pupil to protect the retina from damage.'),
      _MQ('At a synapse, impulses cross the gap by:',
          ['Electrical sparks jumping the gap', 'Neurotransmitter chemicals diffusing across', 'The neurons touching directly', 'Red blood cells carrying signals'], 1, 'Medium',
          'Arriving impulses release neurotransmitters that diffuse across the synaptic cleft and trigger a new impulse in the next neuron, ensuring one-way transmission.'),
      _MQ('Fertilisation is best defined as:',
          ['Division of somatic cells', 'Fusion of the nuclei of male and female gametes', 'Release of an egg from the ovary', 'Attachment of the embryo to the uterus wall'], 1, 'Easy',
          'At fertilisation the sperm nucleus fuses with the egg nucleus, restoring the diploid chromosome number and forming a zygote.'),
      _MQ('Insect-pollinated flowers typically have:',
          ['Small dull petals and dry light pollen', 'Bright petals, scent, nectar and sticky pollen', 'Feathery stigmas hanging outside the flower', 'Very long stamens exposed to wind'], 1, 'Easy',
          'Bright petals, scent and nectar attract insects, while sticky or spiky pollen grains cling to their bodies and are carried between flowers.'),
      _MQ('The placenta:',
          ['Surrounds the fetus with protective fluid', 'Allows exchange of nutrients, oxygen and wastes between maternal and fetal blood', 'Stores eggs in the ovary', 'Produces milk after birth'], 1, 'Medium',
          'In the placenta, fetal and maternal blood flow very close together, exchanging substances by diffusion without ever mixing directly.'),
      _MQ('Amniotic fluid functions to:',
          ['Feed the developing fetus', 'Protect the embryo from physical shock and drying out', 'Carry oxygen from the mother', 'Remove sperm from the uterus'], 1, 'Medium',
          'The amniotic fluid cushions the embryo against mechanical injury and keeps temperature and moisture constant throughout development.'),
      _MQ('Sexual reproduction is advantageous over asexual reproduction because it:',
          ['Is always faster', 'Needs only one parent', 'Produces genetically varied offspring that can survive changing environments', 'Guarantees identical offspring'], 2, 'Medium',
          'Mixing genes from two parents creates variation, giving the population a better chance of surviving diseases and environmental changes.'),
      _MQ('Ovulation in the menstrual cycle is triggered by a surge of:',
          ['Progesterone', 'Oestrogen only', 'Luteinising hormone (LH)', 'Adrenaline'], 2, 'Hard',
          'Around day fourteen of the cycle, a peak of luteinising hormone from the pituitary ruptures the mature follicle, releasing the egg from the ovary.'),
      _MQ('Meiosis differs from mitosis because meiosis:',
          ['Produces diploid body cells', 'Produces four haploid, genetically different gametes', 'Occurs in all body tissues', 'Produces identical daughter cells'], 1, 'Medium',
          'Two divisions in meiosis halve the chromosome number and reshuffle genes, producing genetically varied haploid gametes for sexual reproduction.'),
      _MQ('A cross between a homozygous tall pea plant (TT) and a dwarf plant (tt) gives offspring that are:',
          ['All tall (Tt)', 'All dwarf (tt)', 'Half tall and half dwarf', 'Three-quarters tall'], 0, 'Medium',
          'Every offspring inherits one T allele and one t allele; since tallness is dominant, all the Tt plants are tall.'),
      _MQ('The sex of a human child is determined by:',
          ["The mother's egg only", 'Whether the sperm carries an X or a Y chromosome', 'The temperature of the womb', 'Nutrition during pregnancy'], 1, 'Easy',
          'Eggs carry only X chromosomes; a Y-bearing sperm produces a male (XY) and an X-bearing sperm produces a female (XX), each with equal probability.'),
      _MQ('The physical appearance produced by a genotype is called the:',
          ['Phenotype', 'Genome', 'Allele', 'Karyotype'], 0, 'Easy',
          'The phenotype is the observable expression of the genes, shaped by the genotype acting together with environmental influences.'),
      _MQ('In malaria-prone regions, the sickle-cell allele (HbS) remains common because:',
          ['It makes people taller', 'Heterozygous carriers (HbA HbS) have some resistance to malaria', 'It improves eyesight', 'Malaria mutates the allele'], 1, 'Hard',
          'Carriers of one sickle-cell allele suffer only mild anaemia but resist malaria, so the allele persists where malaria is endemic, such as in tropical Africa.'),
      _MQ('Which of the following can cause mutations in DNA?',
          ['Drinking clean water', 'Ultraviolet radiation and certain chemicals', 'Regular exercise', 'Eating vegetables'], 1, 'Medium',
          'Mutagens such as ultraviolet light, X-rays and some chemicals alter DNA bases, producing mutations that may be inherited by daughter cells.'),
      _MQ('In the food chain grass â†’ grasshopper â†’ lizard â†’ snake, the snake is the:',
          ['Producer', 'Primary consumer', 'Secondary consumer', 'Tertiary consumer'], 3, 'Easy',
          'Snakes feed on secondary consumers (lizards), placing them at the fourth trophic level as tertiary consumers.'),
      _MQ('Green plants are called producers because they:',
          ['Consume other organisms', 'Manufacture organic matter from inorganic substances using sunlight', 'Decompose dead material', 'Reproduce fastest'], 1, 'Easy',
          'Through photosynthesis, producers convert light energy into chemical energy stored in organic compounds, feeding every other level of the ecosystem.'),
      _MQ('Only about 10% of energy passes between trophic levels because:',
          ['Plants refuse to grow', 'Energy is lost through respiration, excretion and uneaten parts', 'Consumers photosynthesise', 'Sunlight is unlimited'], 1, 'Medium',
          'Much of the energy is released as heat during respiration or lost in excreted waste and uneaten material, so food chains rarely exceed four or five levels.'),
      _MQ('Decomposers such as bacteria and fungi are essential because they:',
          ['Photosynthesise in darkness', 'Recycle nutrients locked in dead matter back into the soil', 'Prevent all disease', 'Fix carbon dioxide in rocks'], 1, 'Medium',
          'By breaking down dead organisms and waste, decomposers release nutrients for reuse by producers, keeping the nutrient cycles turning.'),
      _MQ('Which measure would most help restore declining chambo fish stocks in Lake Malawi?',
          ['Increasing unregulated fishing', 'Enforcing closed seasons and mesh-size limits to protect breeding fish', 'Draining shallow breeding bays', 'Introducing predatory species'], 1, 'Medium',
          'Closed seasons and legal mesh sizes allow fish to breed and juveniles to mature, giving overfished stocks such as chambo the chance to recover.'),
      _MQ('The process that removes carbon dioxide from the atmosphere is:',
          ['Combustion', 'Photosynthesis', 'Respiration', 'Decomposition'], 1, 'Easy',
          'Photosynthesis absorbs carbon dioxide and fixes its carbon into glucose, balancing the carbon dioxide added by respiration and combustion.'),
      _MQ('Widespread deforestation on Malawian hillsides most directly leads to:',
          ['Increased soil fertility', 'Soil erosion, flash floods and reduced river flows', 'A cooler local climate', 'Thicker topsoil'], 1, 'Medium',
          'Tree roots bind the soil and the canopy intercepts rain; removing forests exposes soil to erosion, silting rivers such as the Shire and worsening floods.'),
      _MQ('The enhanced greenhouse effect is caused mainly by:',
          ['Ozone holes letting in moonlight', 'Rising atmospheric carbon dioxide and methane from burning fuels and agriculture', 'Strong winds', 'Volcanic winters'], 1, 'Medium',
          'Human activities raise the concentration of greenhouse gases, trapping more outgoing heat radiation and driving global warming and climate change.'),
      _MQ('Acid rain forms when rainwater combines with:',
          ['Sulphur dioxide and nitrogen oxides from burning fossil fuels', 'Pure oxygen', 'Common salt dust', 'Water vapour alone'], 0, 'Medium',
          'Industrial emissions dissolve in cloud droplets to form sulphuric and nitric acids, which acidify lakes and soils far downwind of the source.'),
      _MQ('Eutrophication of a lake begins when:',
          ['Fish numbers explode', 'Fertiliser runoff feeds an algal bloom whose later decay strips oxygen from the water', 'The lake freezes over', 'Herbivores graze the algae'], 1, 'Hard',
          'Excess nitrates and phosphates trigger algal blooms; when the algae die, decomposers consume the dissolved oxygen, suffocating fish and other aquatic life.'),
      _MQ('Which of these is a renewable source of energy suitable for rural Malawi?',
          ['Coal', 'Diesel generators', 'Solar power', 'Firewood from cleared forest'], 2, 'Easy',
          'Solar energy is abundant, non-polluting and inexhaustible, unlike fossil fuels or unsustainable firewood harvesting.'),
      _MQ('Establishing protected areas such as Liwonde National Park helps conservation mainly by:',
          ['Allowing unlimited tourism', 'Preserving habitats so native species can breed safely', 'Removing predators', 'Encouraging poaching'], 1, 'Easy',
          'Protected areas safeguard whole ecosystems from exploitation, maintaining biodiversity and allowing threatened species to recover.'),
    ]),
  ];

  String get _headerTitle {
    if (_examActive) return 'Question ${_currentQuestion + 1} of ${_questions.length}';
    if (_results.isNotEmpty) return 'Examination Complete';
    return 'MSCE Mock Examinations';
  }

  String get _headerSubtitle {
    if (_examActive || _results.isNotEmpty) return _currentExam?.title ?? 'MSCE Biology';
    return 'MSCE Biology Mock Exams';
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startExam(_MockExam exam) {
    setState(() {
      _currentExam = exam;
      _questions = exam.questions;
      _examActive = true;
      _currentQuestion = 0;
      _selectedAnswer = null;
      _answered = false;
      _score = 0;
      _results = [];
      _timeLeft = _secondsPerQuestion;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_timeLeft <= 1) {
        t.cancel();
        _handleTimeout();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _handleTimeout() {
    final q = _questions[_currentQuestion];
    setState(() {
      _results.add(_ExamResult(q, -1, false, _secondsPerQuestion));
    });
    _advance();
  }

  void _submitAnswer() {
    if (_selectedAnswer == null || _answered) return;
    _timer?.cancel();
    final q = _questions[_currentQuestion];
    final correct = _selectedAnswer == q.correctIndex;
    final timeTaken = _secondsPerQuestion - _timeLeft;
    if (correct) _score++;
    setState(() {
      _answered = true;
      _results.add(_ExamResult(q, _selectedAnswer!, correct, timeTaken));
    });
  }

  void _advance() {
    if (_currentQuestion >= _questions.length - 1) {
      _finishExam();
      return;
    }
    setState(() {
      _currentQuestion++;
      _selectedAnswer = null;
      _answered = false;
      _timeLeft = _secondsPerQuestion;
    });
    _startTimer();
  }

  void _finishExam() {
    _timer?.cancel();
    setState(() => _examActive = false);
  }

  void _retryExam() {
    if (_currentExam != null) _startExam(_currentExam!);
  }

  void _resetToSelection() {
    _timer?.cancel();
    setState(() {
      _examActive = false;
      _currentExam = null;
      _questions = [];
      _results = [];
      _score = 0;
      _currentQuestion = 0;
      _selectedAnswer = null;
      _answered = false;
      _timeLeft = _secondsPerQuestion;
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
                : _results.isNotEmpty && _currentExam != null
                    ? _buildResultsView(isDesktop)
                    : _buildSelectionView(isDesktop),
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
              child: Icon(Icons.fact_check_rounded, color: _bioGreen, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_headerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                  SizedBox(height: 2),
                  Text(_headerSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                ],
              ),
            ),
            if (_examActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _timeLeft <= 15
                      ? context.colors.error.withValues(alpha: 0.15)
                      : _bioGreenGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_timeLeft s',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _timeLeft <= 15 ? context.colors.error : _bioGreen)),
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionView(bool isDesktop) {
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
                  child: Icon(Icons.assignment_rounded, color: _bioGreen, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MSCE Biology Mock Exams',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                      SizedBox(height: 4),
                      Text('Three full-length mock examinations covering all 15 syllabus chapters. Each exam has 30 timed multiple choice questions worth 100 marks.',
                          style: TextStyle(fontSize: 12, color: context.colors.textMuted, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          _buildSectionTitle('Select Your Exam'),
          SizedBox(height: 12),
          for (var i = 0; i < _mockExams.length; i++) _buildExamCard(i),
          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildExamCard(int index) {
    final exam = _mockExams[index];
    return GestureDetector(
      onTap: () => _startExam(exam),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: _bioGreenGlow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: _bioGreen)),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MOCK EXAM ${index + 1}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: _bioGreen)),
                      SizedBox(height: 2),
                      Text(exam.title,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                      SizedBox(height: 2),
                      Text('100 Marks Â· 2 Hours Â· ${exam.questions.length} Questions',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: context.colors.textMuted),
              ],
            ),
            SizedBox(height: 12),
            Text(exam.description,
                style: TextStyle(
                    fontSize: 12, color: context.colors.textSecondary, height: 1.45)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaChip(Icons.stars_rounded, 'MSCE Standard'),
                _buildMetaChip(Icons.grade_rounded, '100 Marks'),
                _buildMetaChip(Icons.schedule_rounded, '2 Hours'),
                _buildMetaChip(Icons.help_outline_rounded, '${exam.questions.length} MCQs'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _bioGreen),
          SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildExamView(bool isDesktop) {
    if (_questions.isEmpty) return const SizedBox.shrink();
    final q = _questions[_currentQuestion];
    final progress = min(1.0, max(0.0, (_currentQuestion + 1) / _questions.length));

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
            SizedBox(height: 12),
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
                      ? _currentQuestion >= _questions.length - 1
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
                    : 'F';
    final gradeColor = pct >= 70
        ? context.colors.success
        : pct >= 50
            ? context.colors.warning
            : context.colors.error;

    var easyTotal = 0, easyCorrect = 0;
    var mediumTotal = 0, mediumCorrect = 0;
    var hardTotal = 0, hardCorrect = 0;
    for (final r in _results) {
      if (r.question.difficulty == 'Easy') {
        easyTotal++;
        if (r.correct) easyCorrect++;
      } else if (r.question.difficulty == 'Medium') {
        mediumTotal++;
        if (r.correct) mediumCorrect++;
      } else {
        hardTotal++;
        if (r.correct) hardCorrect++;
      }
    }

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
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gradeColor.withValues(alpha: 0.15),
                    border: Border.all(color: gradeColor.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(grade,
                        style: TextStyle(
                            fontSize: 48, fontWeight: FontWeight.w800, color: gradeColor)),
                  ),
                ),
                SizedBox(height: 16),
                Text('$_score / $total',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                Text('$pct% â€” Grade $grade',
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
                    _buildResultStat('Time Taken', _formatTotalTime(), context.colors.info),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          _buildSectionTitle('Performance by Difficulty'),
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              children: [
                _buildDifficultyRow('Easy', easyCorrect, easyTotal, context.colors.success),
                _buildDifficultyRow('Medium', mediumCorrect, mediumTotal, context.colors.warning),
                _buildDifficultyRow('Hard', hardCorrect, hardTotal, context.colors.error),
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
                  onPressed: _resetToSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.surface,
                    foregroundColor: context.colors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: context.colors.border)),
                  ),
                  child: Text('New Exam',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _retryExam,
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

  Widget _buildDifficultyRow(String label, int correct, int total, Color color) {
    final pct = total > 0 ? (correct / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              Spacer(),
              Text('$correct/$total ($pct%)',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? correct / total : 0,
              backgroundColor: context.colors.surfaceHighest,
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTotalTime() {
    final totalSeconds = _results.fold<int>(0, (a, r) => a + r.timeTaken);
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m}m ${s}s';
  }

  Widget _buildReviewCard(int index, _ExamResult r) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
          SizedBox(height: 8),
          Text(
              r.selected >= 0
                  ? 'Your answer: ${r.question.options[r.selected]}'
                  : 'Your answer: Not answered',
              style: TextStyle(
                  fontSize: 12,
                  color: r.correct ? context.colors.textSecondary : context.colors.error)),
          Text('Correct answer: ${r.question.options[r.question.correctIndex]}',
              style: TextStyle(fontSize: 12, color: context.colors.success)),
          SizedBox(height: 6),
          Text(r.question.explanation,
              style: TextStyle(fontSize: 11, color: context.colors.textMuted, height: 1.4)),
          SizedBox(height: 6),
          Text('Time taken: ${r.timeTaken}s',
              style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
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

class _MockExam {
  final String title;
  final String description;
  final List<_MQ> questions;
  const _MockExam(this.title, this.description, this.questions);
}

class _MQ {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String difficulty;
  final String explanation;
  const _MQ(this.question, this.options, this.correctIndex, this.difficulty, this.explanation);
}

class _ExamResult {
  final _MQ question;
  final int selected;
  final bool correct;
  final int timeTaken;
  const _ExamResult(this.question, this.selected, this.correct, this.timeTaken);
}
