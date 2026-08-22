import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/services.dart';

const Color _bioGreen = Color(0xFF10B981);

class BiologySyllabusScreen extends StatefulWidget {
  const BiologySyllabusScreen({super.key});

  @override
  State<BiologySyllabusScreen> createState() => _BiologySyllabusScreenState();
}

class _BiologySyllabusScreenState extends State<BiologySyllabusScreen> {
  int _selectedYear = 0;
  int? _expandedCore;
  int? _expandedTopic;
  String _searchQuery = '';
  bool _loading = true;
  List<_CoreElement> _syllabus = const [];
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadSyllabus();
  }

  Future<void> _loadSyllabus() async {
    try {
      final res = await _api.get('/syllabus/subjects/biology/tree');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final versions = data['versions'] as List? ?? [];
        if (versions.isNotEmpty) {
          final ces = versions[0]['core_elements'] as List? ?? [];
          _syllabus = ces.map((ce) {
            return _CoreElement(
              ce['number'] ?? 0,
              ce['name'] ?? '',
              _coreIcon(ce['number'] ?? 0),
              (ce['topics'] as List? ?? []).map((t) {
                return _SyllabusTopic(
                  t['title'] ?? '',
                  t['year_level'] ?? 3,
                  (t['subtopics'] as List? ?? []).expand((sub) {
                    return (sub['learning_objectives'] as List? ?? []).map((lo) {
                      return _LearningObjective(
                        lo['objective'] ?? '',
                        lo['description'] ?? '',
                        lo['cognitive_level'] ?? 'Knowledge',
                      );
                    });
                  }).toList(),
                  (t['resources'] as List? ?? []).cast<String>(),
                );
              }).toList(),
            );
          }).toList();
        }
      }
    } catch (_) {
      // Fall through to empty state
    }
    if (_syllabus.isEmpty) {
      _syllabus = _fallbackSyllabus;
    }
    if (mounted) setState(() => _loading = false);
  }

  IconData _coreIcon(int n) {
    switch (n) {
      case 1: return Icons.science_rounded;
      case 2: return Icons.eco_rounded;
      case 3: return Icons.local_florist_rounded;
      case 4: return Icons.pets_rounded;
      case 5: return Icons.person_rounded;
      case 6: return Icons.bug_report_rounded;
      case 7: return Icons.science_rounded;
      default: return Icons.book_rounded;
    }
  }

  static const _fallbackSyllabus = [
    _CoreElement(
      1,
      'Research Skills',
      Icons.science_rounded,
      [
        _SyllabusTopic(
          'Scientific Investigation', 1,
          [
            _LearningObjective('Formulate hypotheses from observations', 'Understand the structure of a scientific investigation', 'Knowledge/Comprehension'),
            _LearningObjective('Design controlled experiments with independent, dependent, and controlled variables', 'Apply the scientific method to biology problems', 'Application/Analysis'),
            _LearningObjective('Record observations accurately using tables, graphs, and drawings', 'Develop skills in data collection and presentation', 'Application'),
            _LearningObjective('Interpret experimental data and draw valid conclusions', 'Evaluate the validity of scientific conclusions', 'Analysis/Evaluation'),
            _LearningObjective('Evaluate the reliability and validity of experimental results', 'Understand statistical concepts like mean, range, and standard deviation', 'Evaluation'),
          ],
          ['Beakers, test tubes, thermometer, microscope, stopwatch, ruler, graph paper', 'Laboratory safety goggles, lab coat, gloves'],
        ),
        _SyllabusTopic(
          'Laboratory Techniques', 1,
          [
            _LearningObjective('Use a light microscope correctly to view prepared slides', 'Practical skill: microscopy technique', 'Application/Practical'),
            _LearningObjective('Prepare temporary mounts of plant and animal tissues', 'Practical skill: slide preparation', 'Application/Practical'),
            _LearningObjective('Perform dissections of plant and animal specimens', 'Practical skill: dissection technique', 'Application/Practical'),
            _LearningObjective('Follow laboratory safety rules and procedures', 'Develop responsible laboratory behaviour', 'Knowledge/Comprehension'),
          ],
          ['Light microscope, prepared slides, slides and cover slips, staining reagents', 'Dissection kit (scalpel, scissors, forceps, pins, dissecting board)'],
        ),
      ],
    ),
    _CoreElement(
      2,
      'Environment',
      Icons.eco_rounded,
      [
        _SyllabusTopic(
          'Ecosystems & Biotic Factors', 3,
          [
            _LearningObjective('Define ecosystem as the interaction of living organisms with their environment', 'Understand the concept of an ecosystem', 'Knowledge'),
            _LearningObjective('Identify biotic factors: producers, consumers, decomposers', 'Classify organisms by their role in food chains', 'Comprehension'),
            _LearningObjective('Construct and interpret food chains and food webs', 'Apply knowledge of feeding relationships', 'Application'),
            _LearningObjective('Explain the transfer of energy through trophic levels', 'Understand energy flow and the 10% rule', 'Comprehension/Analysis'),
            _LearningObjective('Describe the carbon, nitrogen, and water cycles', 'Understand nutrient cycling in ecosystems', 'Comprehension/Application'),
          ],
          ['Field study equipment: quadrats, sweep nets, pitfall traps', 'Graph paper, calculator'],
        ),
        _SyllabusTopic(
          'Abiotic Factors & Climate Change', 3,
          [
            _LearningObjective('Identify abiotic factors: temperature, rainfall, light intensity, soil pH', 'Understand how physical factors affect organisms', 'Knowledge'),
            _LearningObjective('Measure and record abiotic factors in a local habitat', 'Practical skill: field measurement techniques', 'Application/Practical'),
            _LearningObjective('Explain the effects of deforestation on local and global climate', 'Understand human impact on ecosystems', 'Analysis'),
            _LearningObjective('Describe the causes and effects of global warming and climate change', 'Appreciate environmental challenges facing Malawi', 'Comprehension/Evaluation'),
            _LearningObjective('Evaluate strategies for sustainable environmental management', 'Develop informed opinions on conservation', 'Evaluation'),
          ],
          ['Rain gauge, thermometer, pH meter, light meter', 'Soil sampling kit'],
        ),
      ],
    ),
    _CoreElement(
      3,
      'Plant Biology',
      Icons.local_florist_rounded,
      [
        _SyllabusTopic(
          'Plant Structure & Organisation', 3,
          [
            _LearningObjective('Identify and draw the structure of a typical plant cell', 'Understand plant cell organisation', 'Knowledge/Application'),
            _LearningObjective('Describe the functions of cell wall, chloroplasts, and large vacuole', 'Relate structure to function in plant cells', 'Comprehension'),
            _LearningObjective('Explain the Organisation of roots, stems, and leaves', 'Understand plant organ systems', 'Comprehension'),
            _LearningObjective('Distinguish between monocot and dicot plants using seed and leaf venation patterns', 'Apply classification skills', 'Application'),
            _LearningObjective('Describe the internal structure of roots (cross-section)', 'Practical skill: microscopy of plant tissues', 'Application/Practical'),
            _LearningObjective('Describe the internal structure of stems (cross-section of dicot stem)', 'Understand vascular tissue arrangement', 'Application/Practical'),
            _LearningObjective('Describe the internal structure of leaves (cross-section)', 'Relate leaf structure to photosynthesis', 'Comprehension/Practical'),
          ],
          ['Microscope, prepared slides of plant tissues', 'Fresh plant specimens (monocot and dicot)'],
        ),
        _SyllabusTopic(
          'Photosynthesis', 3,
          [
            _LearningObjective('State the word equation for photosynthesis', 'Understand the basic process of photosynthesis', 'Knowledge'),
            _LearningObjective('Describe the factors affecting the rate of photosynthesis (light, CO₂, temperature)', 'Understand limiting factors', 'Comprehension'),
            _LearningObjective('Design and carry out an experiment to investigate photosynthesis (e.g. using Elodea)', 'Practical skill: experimental design', 'Application/Practical'),
            _LearningObjective('Test for starch in leaves using iodine solution', 'Practical skill: chemical testing', 'Application/Practical'),
            _LearningObjective('Explain the structure and function of chloroplasts', 'Relate organelle structure to function', 'Comprehension'),
            _LearningObjective('Describe the light-dependent and light-independent reactions', 'Understand the two stages of photosynthesis', 'Comprehension/Analysis'),
          ],
          ['Elodea/aquatic plant, sodium bicarbonate solution, lamp', 'Iodine solution, ethanol, beakers, water bath'],
        ),
        _SyllabusTopic(
          'Transport in Plants', 3,
          [
            _LearningObjective('Describe the structure and function of xylem and phloem', 'Understand vascular tissue', 'Comprehension'),
            _LearningObjective('Explain the mechanism of water transport in xylem (cohesion-tension theory)', 'Understand transpiration stream', 'Comprehension/Analysis'),
            _LearningObjective('Describe the mechanism of translocation in phloem', 'Understand movement of sugars', 'Comprehension'),
            _LearningObjective('Set up and interpret a potometer to measure water uptake', 'Practical skill: potometer use', 'Application/Practical'),
            _LearningObjective('Investigate factors affecting the rate of transpiration using a potometer', 'Experimental design and data analysis', 'Application/Analysis'),
            _LearningObjective('Explain the role of root pressure in water absorption', 'Understand alternative water transport mechanisms', 'Comprehension'),
          ],
          ['Potometer, fresh shoot, water, oil', 'Vaseline, plastic bag, lamp, fan'],
        ),
        _SyllabusTopic(
          'Transpiration & Tropisms', 3,
          [
            _LearningObjective('Define transpiration and explain how it occurs through stomata', 'Understand water loss from plants', 'Knowledge/Comprehension'),
            _LearningObjective('Investigate the effect of environmental factors on transpiration rate', 'Practical skill: cobalt chloride paper experiment', 'Application/Practical'),
            _LearningObjective('Describe phototropism in shoots and roots', 'Understand growth responses to light', 'Comprehension'),
            _LearningObjective('Describe gravitropism (geotropism) in roots and shoots', 'Understand growth responses to gravity', 'Comprehension'),
            _LearningObjective('Explain the role of auxins in plant tropisms', 'Understand hormonal control of growth', 'Analysis'),
            _LearningObjective('Design experiments to investigate tropisms', 'Practical skill: experimental planning', 'Application/Practical'),
          ],
          ['Cobalt chloride paper, plastic bags', 'Auxin solution, filter paper, wool'],
        ),
      ],
    ),
    _CoreElement(
      4,
      'Animal Biology',
      Icons.pets_rounded,
      [
        _SyllabusTopic(
          'Classification & Diversity of Animals', 3,
          [
            _LearningObjective('Classify animals into major phyla (Porifera to Chordata)', 'Understand the basis of animal classification', 'Knowledge'),
            _LearningObjective('Compare the features of invertebrate and vertebrate animals', 'Distinguish between major animal groups', 'Comprehension'),
            _LearningObjective('Describe the characteristics of each vertebrate class', 'Know features of fish, amphibians, reptiles, birds, mammals', 'Knowledge/Comprehension'),
            _LearningObjective('Use identification keys to classify animal specimens', 'Practical skill: using dichotomous keys', 'Application'),
            _LearningObjective('Appreciate the diversity of animal life in Malawi', 'Understand local biodiversity', 'Knowledge'),
          ],
          ['Preserved animal specimens, identification keys', 'Charts, models, field guides'],
        ),
        _SyllabusTopic(
          'Internal Structure of Animals', 3,
          [
            _LearningObjective('Describe the internal structure of a fish (e.g. Tilapia)', 'Practical skill: fish dissection', 'Application/Practical'),
            _LearningObjective('Compare the circulatory systems of fish, amphibians, and mammals', 'Understand evolutionary changes in circulatory systems', 'Analysis'),
            _LearningObjective('Describe the structure and function of the human digestive system', 'Understand the alimentary canal and its organs', 'Comprehension'),
            _LearningObjective('Explain the process of digestion: mechanical and chemical', 'Understand how food is broken down', 'Comprehension/Analysis'),
            _LearningObjective('Describe the structure and function of the human heart', 'Understand the double circulatory system', 'Comprehension'),
            _LearningObjective('Trace the path of blood through the body', 'Apply knowledge of circulation', 'Application'),
          ],
          ['Dissection kit, preserved fish specimens', 'Heart models, diagrams, charts'],
        ),
        _SyllabusTopic(
          'Locomotion in Animals', 3,
          [
            _LearningObjective('Describe the types of movement in animals: locomotion, movement of body parts', 'Understand different types of animal movement', 'Knowledge'),
            _LearningObjective('Explain the role of muscles and skeleton in movement', 'Understand antagonistic muscle pairs', 'Comprehension'),
            _LearningObjective('Compare the skeletal systems of fish, birds, and mammals', 'Understand adaptations for different modes of locomotion', 'Analysis'),
            _LearningObjective('Describe the structure and function of different types of joints', 'Understand joint types: ball-and-socket, hinge, pivot', 'Comprehension'),
          ],
          ['Skeletal models, joint models', 'Charts, diagrams'],
        ),
      ],
    ),
    _CoreElement(
      5,
      'Human Biology',
      Icons.person_rounded,
      [
        _SyllabusTopic(
          'Respiratory System', 3,
          [
            _LearningObjective('Describe the structure and function of the human respiratory system', 'Understand the organs of breathing', 'Knowledge/Comprehension'),
            _LearningObjective('Explain the mechanism of breathing (inhalation and exhalation)', 'Understand the role of the diaphragm and intercostal muscles', 'Comprehension'),
            _LearningObjective('Investigate the effect of exercise on breathing rate and depth', 'Practical skill: pulse and breathing rate measurement', 'Application/Practical'),
            _LearningObjective('Describe gas exchange in the alveoli', 'Understand diffusion across respiratory surfaces', 'Comprehension'),
            _LearningObjective('Discuss the effects of smoking on the respiratory system', 'Appreciate health risks of tobacco use', 'Evaluation'),
          ],
          ['Spirometer, stopwatch, stethoscope', 'Diagrams, models, lung capacity measuring equipment'],
        ),
        _SyllabusTopic(
          'Excretory System', 3,
          [
            _LearningObjective('Identify the organs of the excretory system (kidneys, ureters, bladder, urethra)', 'Know the structure of the urinary system', 'Knowledge'),
            _LearningObjective('Describe the structure of the nephron and its role in urine formation', 'Understand filtration, reabsorption, and secretion', 'Comprehension'),
            _LearningObjective('Explain the role of the kidneys in osmoregulation', 'Understand water balance control', 'Comprehension'),
            _LearningObjective('Describe the role of the skin in excretion (sweat glands)', 'Understand the excretory role of the skin', 'Comprehension'),
            _LearningObjective('Discuss the effects of kidney failure and modern treatments (dialysis, transplant)', 'Appreciate medical applications of biology', 'Evaluation'),
          ],
          ['Kidney models, nephron diagrams', 'Cross-section slides'],
        ),
        _SyllabusTopic(
          'Coordination & Response (Nervous & Endocrine)', 3,
          [
            _LearningObjective('Describe the structure and function of the nervous system (CNS, PNS, SNS)', 'Understand neural organisation', 'Knowledge/Comprehension'),
            _LearningObjective('Explain the reflex arc with examples', 'Understand automatic responses', 'Comprehension'),
            _LearningObjective('Describe the structure and function of a neurone', 'Understand nerve cell structure', 'Comprehension'),
            _LearningObjective('Explain synaptic transmission', 'Understand how nerve impulses cross synapses', 'Analysis'),
            _LearningObjective('Describe the structure and function of the human eye', 'Understand the eye as a receptor organ', 'Comprehension'),
            _LearningObjective('Describe accommodation for near and distant vision', 'Understand lens shape changes', 'Comprehension'),
            _LearningObjective('Explain the role of the endocrine system and major hormones (insulin, adrenaline, thyroxine, FSH, LH, oestrogen, testosterone)', 'Understand hormonal coordination', 'Comprehension'),
            _LearningObjective('Compare the nervous and endocrine systems', 'Understand speed and duration differences', 'Analysis'),
            _LearningObjective('Discuss the effects of drug abuse on the nervous system', 'Appreciate dangers of substance abuse', 'Evaluation'),
          ],
          ['Brain model, eye model', 'Hormone charts, reflex hammer'],
        ),
        _SyllabusTopic(
          'Reproductive System', 3,
          [
            _LearningObjective('Describe the structure and function of the male reproductive system', 'Know the male reproductive organs and their functions', 'Knowledge/Comprehension'),
            _LearningObjective('Describe the structure and function of the female reproductive system', 'Know the female reproductive organs and their functions', 'Knowledge/Comprehension'),
            _LearningObjective('Explain the menstrual cycle and the role of hormones (FSH, LH, oestrogen, progesterone)', 'Understand hormonal regulation of reproduction', 'Comprehension'),
            _LearningObjective('Describe fertilisation and early embryonic development', 'Understand the events from fertilisation to implantation', 'Comprehension'),
            _LearningObjective('Compare asexual and sexual reproduction', 'Understand the advantages and disadvantages of each', 'Analysis'),
            _LearningObjective('Describe methods of contraception and their mechanisms', 'Understand reproductive health', 'Comprehension'),
            _LearningObjective('Discuss sexually transmitted infections (STIs) and their prevention', 'Appreciate the importance of sexual health education', 'Evaluation'),
          ],
          ['Reproductive system models', 'Charts, diagrams, diagrams of menstrual cycle'],
        ),
        _SyllabusTopic(
          'Immunity & Disease', 3,
          [
            _LearningObjective('Distinguish between pathogens: bacteria, viruses, fungi, and parasites', 'Know the types of disease-causing organisms', 'Knowledge'),
            _LearningObjective('Describe how the body defends itself: skin, mucous membranes, phagocytes, lymphocytes', 'Understand non-specific and specific defence', 'Comprehension'),
            _LearningObjective('Explain the immune response: antibodies, antigens, and immunological memory', 'Understand how immunity develops', 'Analysis'),
            _LearningObjective('Describe how vaccines work to provide immunity', 'Understand the principle of vaccination', 'Comprehension'),
            _LearningObjective('Discuss the effects of HIV/AIDS on the immune system', 'Appreciate the impact of HIV/AIDS in Malawi', 'Comprehension/Evaluation'),
            _LearningObjective('Describe the transmission, symptoms, and prevention of malaria', 'Understand malaria as a major disease in Malawi', 'Knowledge/Comprehension'),
            _LearningObjective('Discuss the role of public health measures in disease prevention', 'Appreciate the importance of hygiene and sanitation', 'Evaluation'),
          ],
          ['Microscope, prepared slides of bacteria/viruses', 'Charts of immune system, vaccine vials (demonstration)'],
        ),
        _SyllabusTopic(
          'Blood & Circulatory System', 3,
          [
            _LearningObjective('Describe the composition of blood: plasma, red blood cells, white blood cells, platelets', 'Know the components and functions of blood', 'Knowledge'),
            _LearningObjective('Explain the functions of each blood component', 'Relate structure to function', 'Comprehension'),
            _LearningObjective('Describe the structure and function of arteries, veins, and capillaries', 'Understand blood vessel types', 'Comprehension'),
            _LearningObjective('Describe the structure and function of the human heart', 'Understand the double circulatory system', 'Comprehension'),
            _LearningObjective('Trace the path of blood through the pulmonary and systemic circuits', 'Apply knowledge of circulation', 'Application'),
            _LearningObjective('Discuss blood groups and the importance of blood transfusion', 'Understand ABO and Rh blood groups', 'Comprehension'),
          ],
          ['Blood smear slides, microscope', 'Heart models, blood typing kits'],
        ),
        _SyllabusTopic(
          'Cancer & Organ Transplants', 3,
          [
            _LearningObjective('Explain what cancer is: uncontrolled cell division (tumours)', 'Understand the basic biology of cancer', 'Comprehension'),
            _LearningObjective('Identify risk factors for cancer: smoking, UV radiation, genetic factors', 'Know the major causes of cancer', 'Knowledge'),
            _LearningObjective('Describe methods of cancer treatment: surgery, chemotherapy, radiotherapy', 'Understand treatment options', 'Comprehension'),
            _LearningObjective('Explain the concept of organ transplants and the problem of rejection', 'Understand immune rejection', 'Comprehension'),
            _LearningObjective('Discuss the ethical and social issues surrounding organ transplantation', 'Develop informed opinions on medical ethics', 'Evaluation'),
          ],
          ['Charts, diagrams', 'Videos, case studies'],
        ),
        _SyllabusTopic(
          'Organ Transplants & Ethics', 3,
          [
            _LearningObjective('Discuss the ethical issues of organ donation and transplantation', 'Develop critical thinking about medical ethics', 'Evaluation'),
            _LearningObjective('Evaluate the benefits and risks of organ transplant surgery', 'Consider medical, social, and ethical factors', 'Evaluation'),
            _LearningObjective('Understand the concept of brain death and its relevance to organ donation', 'Know the criteria for organ donation', 'Comprehension'),
          ],
          ['Case studies, debate materials'],
        ),
      ],
    ),
    _CoreElement(
      6,
      'Micro-organisms',
      Icons.bug_report_rounded,
      [
        _SyllabusTopic(
          'Structure & Classification', 3,
          [
            _LearningObjective('Describe the structure of bacteria, viruses, and fungi', 'Know the basic structure of micro-organisms', 'Knowledge'),
            _LearningObjective('Distinguish between bacteria (prokaryotes) and viruses (non-cellular)', 'Compare different types of micro-organisms', 'Comprehension'),
            _LearningObjective('Explain how micro-organisms are classified', 'Understand classification criteria', 'Comprehension'),
            _LearningObjective('Describe beneficial micro-organisms: decomposition, fermentation, nitrogen fixation', 'Appreciate the positive roles of microbes', 'Comprehension'),
            _LearningObjective('Describe harmful micro-organisms: disease causation', 'Understand the pathogenic role of microbes', 'Comprehension'),
          ],
          ['Microscope, prepared slides of bacteria, yeast, mould', 'Agar plates, Petri dishes'],
        ),
        _SyllabusTopic(
          'Micro-organisms in Food & Industry', 3,
          [
            _LearningObjective('Explain the role of micro-organisms in food production (yogurt, bread, beer)', 'Understand fermentation in daily life', 'Comprehension'),
            _LearningObjective('Describe how micro-organisms cause food spoilage', 'Understand food preservation needs', 'Comprehension'),
            _LearningObjective('Discuss methods of food preservation (heating, cooling, drying, canning, salting)', 'Know practical preservation methods', 'Knowledge'),
            _LearningObjective('Investigate the growth of micro-organisms under different conditions', 'Practical skill: aseptic technique', 'Application/Practical'),
          ],
          ['Agar plates, incubator, autoclave', 'Food samples, preservatives'],
        ),
        _SyllabusTopic(
          'Micro-organisms & Disease', 3,
          [
            _LearningObjective('Describe how micro-organisms cause disease', 'Understand the process of infection', 'Comprehension'),
            _LearningObjective('Explain Koch\'s postulates and their role in identifying disease causation', 'Understand historical advances in microbiology', 'Comprehension'),
            _LearningObjective('Discuss methods of controlling the spread of infection (hygiene, sterilisation, disinfection)', 'Know prevention methods', 'Knowledge/Comprehension'),
            _LearningObjective('Discuss the use of antibiotics and the problem of antibiotic resistance', 'Appreciate the challenge of drug resistance', 'Evaluation'),
            _LearningObjective('Describe the role of micro-organisms in the water cycle and sewage treatment', 'Understand environmental microbiology', 'Comprehension'),
          ],
          ['Antibiotic discs, agar plates', 'Microscopy equipment'],
        ),
      ],
    ),
    _CoreElement(
      7,
      'Genetics & Evolution',
      Icons.science_rounded,
      [
        _SyllabusTopic(
          'Cell Division: Mitosis & Meiosis', 3,
          [
            _LearningObjective('Explain the process of mitosis and its significance in growth and repair', 'Understand cell division for growth', 'Comprehension'),
            _LearningObjective('Describe the stages of mitosis (prophase, metaphase, anaphase, telophase)', 'Know the phases of mitosis', 'Knowledge'),
            _LearningObjective('Explain the process of meiosis and its significance in sexual reproduction', 'Understand reduction division', 'Comprehension'),
            _LearningObjective('Compare mitosis and meiosis', 'Distinguish between the two types of cell division', 'Analysis'),
            _LearningObjective('Describe the significance of meiosis in producing genetic variation', 'Understand the basis of variation', 'Comprehension'),
          ],
          ['Microscope, prepared slides of mitosis stages', 'Onion root tip slides'],
        ),
        _SyllabusTopic(
          'Mendelian Genetics', 3,
          [
            _LearningObjective('Define key terms: gene, allele, genotype, phenotype, dominant, recessive, homozygous, heterozygous', 'Know the vocabulary of genetics', 'Knowledge'),
            _LearningObjective('Use Punnett squares to predict the outcomes of monohybrid crosses', 'Apply genetic principles', 'Application'),
            _LearningObjective('Determine the genotypes and phenotypes of offspring', 'Predict genetic outcomes', 'Application'),
            _LearningObjective('Explain codominance and incomplete dominance with examples', 'Understand extensions to Mendelian genetics', 'Comprehension'),
            _LearningObjective('Explain the inheritance of sex-linked traits', 'Understand sex determination and sex-linked conditions', 'Comprehension'),
            _LearningObjective('Solve genetic problems using family pedigree charts', 'Apply genetic analysis skills', 'Application'),
            _LearningObjective('Explain the concepts of multiple alleles using ABO blood groups as an example', 'Understand inheritance of blood groups', 'Application'),
          ],
          ['Punnett square worksheets, pedigree chart examples', 'Genetic case studies'],
        ),
        _SyllabusTopic(
          'DNA & The Genome', 3,
          [
            _LearningObjective('Describe the structure of DNA (double helix, nucleotides, base pairing)', 'Know the molecular basis of heredity', 'Knowledge'),
            _LearningObjective('Explain how genes code for proteins', 'Understand the central dogma of molecular biology', 'Comprehension'),
            _LearningObjective('Describe the process of protein synthesis (transcription and translation)', 'Understand gene expression', 'Comprehension'),
            _LearningObjective('Discuss the structure and function of chromosomes', 'Understand the organisation of genetic material', 'Comprehension'),
            _LearningObjective('Explain the concept of the genome and the Human Genome Project', 'Understand modern genetics', 'Comprehension'),
            _LearningObjective('Describe the role of mutations in changing genetic information', 'Understand the source of new alleles', 'Comprehension'),
          ],
          ['DNA models, diagrams', 'Animations, worksheets'],
        ),
        _SyllabusTopic(
          'Variations & Evolution', 3,
          [
            _LearningObjective('Distinguish between variation and mutation', 'Understand types of variation', 'Comprehension'),
            _LearningObjective('Explain continuous and discontinuous variation with examples', 'Classify types of variation', 'Application'),
            _LearningObjective('Describe the theory of evolution by natural selection (Darwin and Wallace)', 'Understand the mechanism of evolution', 'Comprehension'),
            _LearningObjective('Provide evidence for evolution: fossils, comparative anatomy, biogeography', 'Evaluate evidence for evolution', 'Analysis'),
            _LearningObjective('Discuss the impact of natural selection on populations', 'Understand adaptation and speciation', 'Analysis'),
            _LearningObjective('Discuss the contribution of Malawi\'s biodiversity to evolutionary studies', 'Appreciate local relevance', 'Evaluation'),
          ],
          ['Fossil specimens, charts', 'Field guides, identification keys'],
        ),
        _SyllabusTopic(
          'Biotechnology', 3,
          [
            _LearningObjective('Explain the principles of genetic engineering', 'Understand manipulation of genetic material', 'Comprehension'),
            _LearningObjective('Discuss the applications of genetic engineering in agriculture (GM crops)', 'Evaluate biotechnology in food production', 'Evaluation'),
            _LearningObjective('Describe the use of micro-organisms in biotechnology (fermentation, enzyme production)', 'Understand industrial biotechnology', 'Comprehension'),
            _LearningObjective('Discuss the ethical issues surrounding genetic engineering and GMOs', 'Develop informed opinions on biotechnology', 'Evaluation'),
            _LearningObjective('Explain the role of biotechnology in medicine (insulin production, gene therapy)', 'Understand medical biotechnology', 'Comprehension'),
          ],
          ['Biotechnology case studies', 'Debate materials, ethical scenarios'],
        ),
      ],
    ),
  ];

  List<_TopicWithCore> get _filteredTopics {
    final result = <_TopicWithCore>[];
    for (final core in _syllabus) {
      for (final topic in core.topics) {
        if (_selectedYear != 0 && topic.yearLevel != _selectedYear) continue;
        if (_searchQuery.isEmpty ||
            topic.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
          result.add(_TopicWithCore(core, topic));
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1623),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/biology'),
        ),
        title: const Text('📖 MSCE Biology Syllabus',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _bioGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _bioGreen.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: _bioGreen, size: 16),
                SizedBox(width: 6),
                Text('Malawi MoEST',
                    style: TextStyle(color: _bioGreen, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _bioGreen))
          : Column(
        children: [
          _buildSearchBar(),
          _buildYearTabs(),
          Expanded(
            child: _searchQuery.isNotEmpty ? _buildSearchResults() : _buildCoreElements(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: const Color(0xFF0F1623),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search syllabus topics, objectives...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          prefixIcon: const Icon(Icons.search_rounded, color: _bioGreen),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _bioGreen.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _bioGreen.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _bioGreen),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildYearTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0F1623),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _yearTab(1, 'Form 1'),
            const SizedBox(width: 8),
            _yearTab(2, 'Form 2'),
            const SizedBox(width: 8),
            _yearTab(3, 'Form 3'),
            const SizedBox(width: 8),
            _yearTab(4, 'Form 4'),
            const SizedBox(width: 8),
            _yearTab(0, 'All'),
          ],
        ),
      ),
    );
  }

  Widget _yearTab(int year, String label) {
    final selected = _selectedYear == year;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedYear = year;
        _expandedCore = null;
        _expandedTopic = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _bioGreen : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _bioGreen : _bioGreen.withValues(alpha: 0.2),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _filteredTopics;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text('No results for "$_searchQuery"',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final t = results[i];
        return _topicCard(t.core, t.topic);
      },
    );
  }

  List<_CoreElement> get _filteredCoreElements {
    if (_selectedYear == 0) return _syllabus;
    return _syllabus.map((core) {
      final filteredTopics = core.topics.where((t) => t.yearLevel == _selectedYear).toList();
      return _CoreElement(core.number, core.title, core.icon, filteredTopics);
    }).where((core) => core.topics.isNotEmpty).toList();
  }

  Widget _buildCoreElements() {
    final filtered = _filteredCoreElements;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text('No topics for Form $_selectedYear',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final core = filtered[i];
        final expanded = _expandedCore == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: expanded ? _bioGreen.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() {
                  _expandedCore = expanded ? null : i;
                  _expandedTopic = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _bioGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(core.icon, color: _bioGreen, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Core Element ${core.number}',
                              style: TextStyle(
                                  color: _bioGreen, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              core.title,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _bioGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${core.topics.length} topics',
                            style: TextStyle(
                                color: _bioGreen.withValues(alpha: 0.8), fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded) ...core.topics.asMap().entries.map((entry) {
                return _topicCard(core, entry.value);
              }),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _topicCard(_CoreElement core, _SyllabusTopic topic) {
    final topicKey = '${core.number}-${topic.title}';
    final expanded = _expandedTopic == topicKey.hashCode;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              _expandedTopic = expanded ? null : topicKey.hashCode;
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.bookmark_rounded, color: _bioGreen.withValues(alpha: 0.7), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(topic.title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _bioGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Form ${topic.yearLevel}',
                        style: TextStyle(
                            color: _bioGreen.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${topic.objectives.length} L.O.s',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...topic.objectives.map((lo) => _learningObjectiveTile(lo)),
                  if (topic.resources.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.build_rounded,
                            size: 14, color: Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(width: 6),
                        Text('Resources:',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...topic.resources.map((r) => Padding(
                          padding: const EdgeInsets.only(left: 20, bottom: 2),
                          child: Text('• $r',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _learningObjectiveTile(_LearningObjective lo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _cognitiveColor(lo.cognitiveLevel),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lo.objective,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.3)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(lo.description,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontStyle: FontStyle.italic)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _cognitiveColor(lo.cognitiveLevel).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(lo.cognitiveLevel,
                          style: TextStyle(
                              color: _cognitiveColor(lo.cognitiveLevel),
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _cognitiveColor(String level) {
    if (level.contains('Knowledge')) return Colors.blue;
    if (level.contains('Comprehension')) return Colors.teal;
    if (level.contains('Application')) return _bioGreen;
    if (level.contains('Analysis')) return Colors.orange;
    if (level.contains('Evaluation')) return Colors.purple;
    if (level.contains('Practical')) return Colors.red;
    return Colors.white54;
  }
}

class _CoreElement {
  final int number;
  final String title;
  final IconData icon;
  final List<_SyllabusTopic> topics;

  const _CoreElement(this.number, this.title, this.icon, this.topics);
}

class _SyllabusTopic {
  final String title;
  final int yearLevel;
  final List<_LearningObjective> objectives;
  final List<String> resources;

  const _SyllabusTopic(this.title, this.yearLevel, this.objectives, this.resources);
}

class _LearningObjective {
  final String objective;
  final String description;
  final String cognitiveLevel;

  const _LearningObjective(this.objective, this.description, this.cognitiveLevel);
}

class _TopicWithCore {
  final _CoreElement core;
  final _SyllabusTopic topic;

  const _TopicWithCore(this.core, this.topic);
}
