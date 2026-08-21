"""Seed the official Malawi MSCE Biology syllabus (MoEST, Forms 3 & 4).

Run from lifespan in main.py. Idempotent — skips if subject already exists.
"""

from sqlalchemy import select

from app.database.engine import async_session
from app.models.stem import (
    SyllabusCoreElement,
    SyllabusLearningObjective,
    SyllabusResource,
    SyllabusSubject,
    SyllabusSubtopic,
    SyllabusTopic,
    SyllabusVersion,
)

BIOLOGY_SYLLABUS = {
    "subject": {
        "name": "Biology",
        "slug": "biology",
        "description": "Malawi MSCE Biology Syllabus — MoEST Forms 3 & 4",
        "icon": "science_rounded",
        "color": "#10B981",
    },
    "version": {
        "version_name": "MoEST Forms 3 & 4 (2013)",
        "year_effective": 2013,
        "examination_board": "Malawi National Examinations Board (MANEB)",
        "description": "Official Biology syllabus for Malawi School Certificate of Education (MSCE), covering Forms 3 and 4.",
    },
    "core_elements": [
        {
            "number": 1,
            "name": "Research Skills",
            "description": "Scientific investigation, laboratory techniques, data collection, and evaluation.",
            "topics": [
                {
                    "title": "Scientific Investigation",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Formulating Hypotheses & Designing Experiments",
                            "learning_objectives": [
                                {
                                    "objective": "Formulate hypotheses from observations",
                                    "description": "Understand the structure of a scientific investigation",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_activity": "Observe natural phenomena and generate testable hypotheses",
                                    "teaching_method": "Group discussion, guided inquiry",
                                },
                                {
                                    "objective": "Design controlled experiments with independent, dependent, and controlled variables",
                                    "description": "Apply the scientific method to biology problems",
                                    "cognitive_level": "Application/Analysis",
                                    "teaching_activity": "Design experiments to test plant growth under different light conditions",
                                    "teaching_method": "Practical work, planning",
                                },
                                {
                                    "objective": "Record observations accurately using tables, graphs, and drawings",
                                    "description": "Develop skills in data collection and presentation",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Record and present experimental data in standard scientific format",
                                    "teaching_method": "Practical work",
                                },
                                {
                                    "objective": "Interpret experimental data and draw valid conclusions",
                                    "description": "Evaluate the validity of scientific conclusions",
                                    "cognitive_level": "Analysis/Evaluation",
                                    "teaching_activity": "Analyse provided data sets and identify trends",
                                    "teaching_method": "Data analysis exercises",
                                },
                                {
                                    "objective": "Evaluate the reliability and validity of experimental results",
                                    "description": "Understand statistical concepts like mean, range, and standard deviation",
                                    "cognitive_level": "Evaluation",
                                    "teaching_activity": "Calculate means and ranges from experimental data",
                                    "teaching_method": "Mathematical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Beakers, test tubes, thermometer, microscope, stopwatch, ruler, graph paper",
                        "Laboratory safety goggles, lab coat, gloves",
                    ],
                },
                {
                    "title": "Laboratory Techniques",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Microscopy, Slide Preparation & Dissection",
                            "learning_objectives": [
                                {
                                    "objective": "Use a light microscope correctly to view prepared slides",
                                    "description": "Practical skill: microscopy technique",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_activity": "View onion cells under microscope",
                                    "teaching_method": "Practical demonstration",
                                },
                                {
                                    "objective": "Prepare temporary mounts of plant and animal tissues",
                                    "description": "Practical skill: slide preparation",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_activity": "Prepare cheek cell and onion epidermis mounts",
                                    "teaching_method": "Hands-on practical",
                                },
                                {
                                    "objective": "Perform dissections of plant and animal specimens",
                                    "description": "Practical skill: dissection technique",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_activity": "Dissect a flower and a fish",
                                    "teaching_method": "Guided practical",
                                },
                                {
                                    "objective": "Follow laboratory safety rules and procedures",
                                    "description": "Develop responsible laboratory behaviour",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_activity": "Discuss and follow lab safety protocols",
                                    "teaching_method": "Discussion, role play",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Light microscope, prepared slides, slides and cover slips, staining reagents",
                        "Dissection kit (scalpel, scissors, forceps, pins, dissecting board)",
                    ],
                },
            ],
        },
        {
            "number": 2,
            "name": "Environment",
            "description": "Ecosystems, biotic and abiotic factors, food chains, nutrient cycles, and climate change.",
            "topics": [
                {
                    "title": "Ecosystems & Biotic Factors",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Ecosystem Components & Energy Flow",
                            "learning_objectives": [
                                {
                                    "objective": "Define ecosystem as the interaction of living organisms with their environment",
                                    "description": "Understand the concept of an ecosystem",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Identify biotic factors: producers, consumers, decomposers",
                                    "description": "Classify organisms by their role in food chains",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Construct and interpret food chains and food webs",
                                    "description": "Apply knowledge of feeding relationships",
                                    "cognitive_level": "Application",
                                },
                                {
                                    "objective": "Explain the transfer of energy through trophic levels",
                                    "description": "Understand energy flow and the 10% rule",
                                    "cognitive_level": "Comprehension/Analysis",
                                },
                                {
                                    "objective": "Describe the carbon, nitrogen, and water cycles",
                                    "description": "Understand nutrient cycling in ecosystems",
                                    "cognitive_level": "Comprehension/Application",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Field study equipment: quadrats, sweep nets, pitfall traps",
                        "Graph paper, calculator",
                    ],
                },
                {
                    "title": "Abiotic Factors & Climate Change",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Abiotic Factors & Environmental Impact",
                            "learning_objectives": [
                                {
                                    "objective": "Identify abiotic factors: temperature, rainfall, light intensity, soil pH",
                                    "description": "Understand how physical factors affect organisms",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Measure and record abiotic factors in a local habitat",
                                    "description": "Practical skill: field measurement techniques",
                                    "cognitive_level": "Application/Practical",
                                },
                                {
                                    "objective": "Explain the effects of deforestation on local and global climate",
                                    "description": "Understand human impact on ecosystems",
                                    "cognitive_level": "Analysis",
                                },
                                {
                                    "objective": "Describe the causes and effects of global warming and climate change",
                                    "description": "Appreciate environmental challenges facing Malawi",
                                    "cognitive_level": "Comprehension/Evaluation",
                                },
                                {
                                    "objective": "Evaluate strategies for sustainable environmental management",
                                    "description": "Develop informed opinions on conservation",
                                    "cognitive_level": "Evaluation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Rain gauge, thermometer, pH meter, light meter",
                        "Soil sampling kit",
                    ],
                },
            ],
        },
        {
            "number": 3,
            "name": "Plant Biology",
            "description": "Plant structure, photosynthesis, transport, transpiration, and tropisms.",
            "topics": [
                {
                    "title": "Plant Structure & Organisation",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Plant Cells, Organs & Tissues",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and draw the structure of a typical plant cell",
                                    "description": "Understand plant cell organisation",
                                    "cognitive_level": "Knowledge/Application",
                                },
                                {
                                    "objective": "Describe the functions of cell wall, chloroplasts, and large vacuole",
                                    "description": "Relate structure to function in plant cells",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain the organisation of roots, stems, and leaves",
                                    "description": "Understand plant organ systems",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Distinguish between monocot and dicot plants using seed and leaf venation patterns",
                                    "description": "Apply classification skills",
                                    "cognitive_level": "Application",
                                },
                                {
                                    "objective": "Describe the internal structure of roots (cross-section)",
                                    "description": "Practical skill: microscopy of plant tissues",
                                    "cognitive_level": "Application/Practical",
                                },
                                {
                                    "objective": "Describe the internal structure of stems (cross-section of dicot stem)",
                                    "description": "Understand vascular tissue arrangement",
                                    "cognitive_level": "Application/Practical",
                                },
                                {
                                    "objective": "Describe the internal structure of leaves (cross-section)",
                                    "description": "Relate leaf structure to photosynthesis",
                                    "cognitive_level": "Comprehension/Practical",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Microscope, prepared slides of plant tissues",
                        "Fresh plant specimens (monocot and dicot)",
                    ],
                },
                {
                    "title": "Photosynthesis",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "The Photosynthesis Process & Investigations",
                            "learning_objectives": [
                                {
                                    "objective": "State the word equation for photosynthesis",
                                    "description": "Understand the basic process of photosynthesis",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Describe the factors affecting the rate of photosynthesis (light, CO2, temperature)",
                                    "description": "Understand limiting factors",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Design and carry out an experiment to investigate photosynthesis using Elodea",
                                    "description": "Practical skill: experimental design",
                                    "cognitive_level": "Application/Practical",
                                },
                                {
                                    "objective": "Test for starch in leaves using iodine solution",
                                    "description": "Practical skill: chemical testing",
                                    "cognitive_level": "Application/Practical",
                                },
                                {
                                    "objective": "Explain the structure and function of chloroplasts",
                                    "description": "Relate organelle structure to function",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe the light-dependent and light-independent reactions",
                                    "description": "Understand the two stages of photosynthesis",
                                    "cognitive_level": "Comprehension/Analysis",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Elodea/aquatic plant, sodium bicarbonate solution, lamp",
                        "Iodine solution, ethanol, beakers, water bath",
                    ],
                },
                {
                    "title": "Transport in Plants",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Vascular Tissue & Translocation",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure and function of xylem and phloem",
                                    "description": "Understand vascular tissue",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain the mechanism of water transport in xylem (cohesion-tension theory)",
                                    "description": "Understand transpiration stream",
                                    "cognitive_level": "Comprehension/Analysis",
                                },
                                {
                                    "objective": "Describe the mechanism of translocation in phloem",
                                    "description": "Understand movement of sugars",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Set up and interpret a potometer to measure water uptake",
                                    "description": "Practical skill: potometer use",
                                    "cognitive_level": "Application/Practical",
                                },
                                {
                                    "objective": "Investigate factors affecting the rate of transpiration using a potometer",
                                    "description": "Experimental design and data analysis",
                                    "cognitive_level": "Application/Analysis",
                                },
                                {
                                    "objective": "Explain the role of root pressure in water absorption",
                                    "description": "Understand alternative water transport mechanisms",
                                    "cognitive_level": "Comprehension",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Potometer, fresh shoot, water, oil",
                        "Vaseline, plastic bag, lamp, fan",
                    ],
                },
                {
                    "title": "Transpiration & Tropisms",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Transpiration and Plant Growth Responses",
                            "learning_objectives": [
                                {
                                    "objective": "Define transpiration and explain how it occurs through stomata",
                                    "description": "Understand water loss from plants",
                                    "cognitive_level": "Knowledge/Comprehension",
                                },
                                {
                                    "objective": "Investigate the effect of environmental factors on transpiration rate",
                                    "description": "Practical skill: cobalt chloride paper experiment",
                                    "cognitive_level": "Application/Practical",
                                },
                                {
                                    "objective": "Describe phototropism in shoots and roots",
                                    "description": "Understand growth responses to light",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe gravitropism (geotropism) in roots and shoots",
                                    "description": "Understand growth responses to gravity",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain the role of auxins in plant tropisms",
                                    "description": "Understand hormonal control of growth",
                                    "cognitive_level": "Analysis",
                                },
                                {
                                    "objective": "Design experiments to investigate tropisms",
                                    "description": "Practical skill: experimental planning",
                                    "cognitive_level": "Application/Practical",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Cobalt chloride paper, plastic bags",
                        "Auxin solution, filter paper, wool",
                    ],
                },
            ],
        },
        {
            "number": 4,
            "name": "Animal Biology",
            "description": "Animal classification, internal structure, and locomotion.",
            "topics": [
                {
                    "title": "Classification & Diversity of Animals",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Animal Phyla & Classification",
                            "learning_objectives": [
                                {
                                    "objective": "Classify animals into major phyla (Porifera to Chordata)",
                                    "description": "Understand the basis of animal classification",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Compare the features of invertebrate and vertebrate animals",
                                    "description": "Distinguish between major animal groups",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe the characteristics of each vertebrate class",
                                    "description": "Know features of fish, amphibians, reptiles, birds, mammals",
                                    "cognitive_level": "Knowledge/Comprehension",
                                },
                                {
                                    "objective": "Use identification keys to classify animal specimens",
                                    "description": "Practical skill: using dichotomous keys",
                                    "cognitive_level": "Application",
                                },
                                {
                                    "objective": "Appreciate the diversity of animal life in Malawi",
                                    "description": "Understand local biodiversity",
                                    "cognitive_level": "Knowledge",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Preserved animal specimens, identification keys",
                        "Charts, models, field guides",
                    ],
                },
                {
                    "title": "Internal Structure of Animals",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Fish Dissection, Circulatory & Digestive Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the internal structure of a fish (e.g. Tilapia)",
                                    "description": "Practical skill: fish dissection",
                                    "cognitive_level": "Application/Practical",
                                },
                                {
                                    "objective": "Compare the circulatory systems of fish, amphibians, and mammals",
                                    "description": "Understand evolutionary changes in circulatory systems",
                                    "cognitive_level": "Analysis",
                                },
                                {
                                    "objective": "Describe the structure and function of the human digestive system",
                                    "description": "Understand the alimentary canal and its organs",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain the process of digestion: mechanical and chemical",
                                    "description": "Understand how food is broken down",
                                    "cognitive_level": "Comprehension/Analysis",
                                },
                                {
                                    "objective": "Describe the structure and function of the human heart",
                                    "description": "Understand the double circulatory system",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Trace the path of blood through the body",
                                    "description": "Apply knowledge of circulation",
                                    "cognitive_level": "Application",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Dissection kit, preserved fish specimens",
                        "Heart models, diagrams, charts",
                    ],
                },
                {
                    "title": "Locomotion in Animals",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Types of Movement & Skeletal Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the types of movement in animals: locomotion, movement of body parts",
                                    "description": "Understand different types of animal movement",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Explain the role of muscles and skeleton in movement",
                                    "description": "Understand antagonistic muscle pairs",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Compare the skeletal systems of fish, birds, and mammals",
                                    "description": "Understand adaptations for different modes of locomotion",
                                    "cognitive_level": "Analysis",
                                },
                                {
                                    "objective": "Describe the structure and function of different types of joints",
                                    "description": "Understand joint types: ball-and-socket, hinge, pivot",
                                    "cognitive_level": "Comprehension",
                                },
                            ],
                        },
                    ],
                    "resources": ["Skeletal models, joint models", "Charts, diagrams"],
                },
            ],
        },
        {
            "number": 5,
            "name": "Human Biology",
            "description": "Respiratory, excretory, nervous, endocrine, reproductive, circulatory, and immune systems.",
            "topics": [
                {
                    "title": "Respiratory System",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Breathing Mechanism & Gas Exchange",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure and function of the human respiratory system",
                                    "description": "Understand the organs of breathing",
                                    "cognitive_level": "Knowledge/Comprehension",
                                },
                                {
                                    "objective": "Explain the mechanism of breathing (inhalation and exhalation)",
                                    "description": "Understand the role of the diaphragm and intercostal muscles",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Investigate the effect of exercise on breathing rate and depth",
                                    "description": "Practical skill: pulse and breathing rate measurement",
                                    "cognitive_level": "Application/Practical",
                                },
                                {
                                    "objective": "Describe gas exchange in the alveoli",
                                    "description": "Understand diffusion across respiratory surfaces",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Discuss the effects of smoking on the respiratory system",
                                    "description": "Appreciate health risks of tobacco use",
                                    "cognitive_level": "Evaluation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Spirometer, stopwatch, stethoscope",
                        "Diagrams, models, lung capacity measuring equipment",
                    ],
                },
                {
                    "title": "Excretory System",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Kidneys, Nephrons & Osmoregulation",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the organs of the excretory system (kidneys, ureters, bladder, urethra)",
                                    "description": "Know the structure of the urinary system",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Describe the structure of the nephron and its role in urine formation",
                                    "description": "Understand filtration, reabsorption, and secretion",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain the role of the kidneys in osmoregulation",
                                    "description": "Understand water balance control",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe the role of the skin in excretion (sweat glands)",
                                    "description": "Understand the excretory role of the skin",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Discuss the effects of kidney failure and modern treatments (dialysis, transplant)",
                                    "description": "Appreciate medical applications of biology",
                                    "cognitive_level": "Evaluation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Kidney models, nephron diagrams",
                        "Cross-section slides",
                    ],
                },
                {
                    "title": "Coordination & Response",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Nervous System, Reflex Arc & Synapses",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure and function of the nervous system (CNS, PNS, SNS)",
                                    "description": "Understand neural organisation",
                                    "cognitive_level": "Knowledge/Comprehension",
                                },
                                {
                                    "objective": "Explain the reflex arc with examples",
                                    "description": "Understand automatic responses",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe the structure and function of a neurone",
                                    "description": "Understand nerve cell structure",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain synaptic transmission",
                                    "description": "Understand how nerve impulses cross synapses",
                                    "cognitive_level": "Analysis",
                                },
                            ],
                        },
                        {
                            "title": "Human Eye, Endocrine System & Hormones",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure and function of the human eye",
                                    "description": "Understand the eye as a receptor organ",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe accommodation for near and distant vision",
                                    "description": "Understand lens shape changes",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain the role of the endocrine system and major hormones (insulin, adrenaline, thyroxine, FSH, LH, oestrogen, testosterone)",
                                    "description": "Understand hormonal coordination",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Compare the nervous and endocrine systems",
                                    "description": "Understand speed and duration differences",
                                    "cognitive_level": "Analysis",
                                },
                                {
                                    "objective": "Discuss the effects of drug abuse on the nervous system",
                                    "description": "Appreciate dangers of substance abuse",
                                    "cognitive_level": "Evaluation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Brain model, eye model",
                        "Hormone charts, reflex hammer",
                    ],
                },
                {
                    "title": "Reproductive System",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Male & Female Reproduction, Menstrual Cycle",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure and function of the male reproductive system",
                                    "description": "Know the male reproductive organs and their functions",
                                    "cognitive_level": "Knowledge/Comprehension",
                                },
                                {
                                    "objective": "Describe the structure and function of the female reproductive system",
                                    "description": "Know the female reproductive organs and their functions",
                                    "cognitive_level": "Knowledge/Comprehension",
                                },
                                {
                                    "objective": "Explain the menstrual cycle and the role of hormones (FSH, LH, oestrogen, progesterone)",
                                    "description": "Understand hormonal regulation of reproduction",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe fertilisation and early embryonic development",
                                    "description": "Understand the events from fertilisation to implantation",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Compare asexual and sexual reproduction",
                                    "description": "Understand the advantages and disadvantages of each",
                                    "cognitive_level": "Analysis",
                                },
                                {
                                    "objective": "Describe methods of contraception and their mechanisms",
                                    "description": "Understand reproductive health",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Discuss sexually transmitted infections (STIs) and their prevention",
                                    "description": "Appreciate the importance of sexual health education",
                                    "cognitive_level": "Evaluation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Reproductive system models",
                        "Charts, diagrams of menstrual cycle",
                    ],
                },
                {
                    "title": "Immunity & Disease",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Pathogens, Immune Response & Vaccines",
                            "learning_objectives": [
                                {
                                    "objective": "Distinguish between pathogens: bacteria, viruses, fungi, and parasites",
                                    "description": "Know the types of disease-causing organisms",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Describe how the body defends itself: skin, mucous membranes, phagocytes, lymphocytes",
                                    "description": "Understand non-specific and specific defence",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain the immune response: antibodies, antigens, and immunological memory",
                                    "description": "Understand how immunity develops",
                                    "cognitive_level": "Analysis",
                                },
                                {
                                    "objective": "Describe how vaccines work to provide immunity",
                                    "description": "Understand the principle of vaccination",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Discuss the effects of HIV/AIDS on the immune system",
                                    "description": "Appreciate the impact of HIV/AIDS in Malawi",
                                    "cognitive_level": "Comprehension/Evaluation",
                                },
                                {
                                    "objective": "Describe the transmission, symptoms, and prevention of malaria",
                                    "description": "Understand malaria as a major disease in Malawi",
                                    "cognitive_level": "Knowledge/Comprehension",
                                },
                                {
                                    "objective": "Discuss the role of public health measures in disease prevention",
                                    "description": "Appreciate the importance of hygiene and sanitation",
                                    "cognitive_level": "Evaluation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Microscope, prepared slides of bacteria/viruses",
                        "Charts of immune system, vaccine vials (demonstration)",
                    ],
                },
                {
                    "title": "Blood & Circulatory System",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Blood Composition, Heart & Blood Vessels",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the composition of blood: plasma, red blood cells, white blood cells, platelets",
                                    "description": "Know the components and functions of blood",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Explain the functions of each blood component",
                                    "description": "Relate structure to function",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe the structure and function of arteries, veins, and capillaries",
                                    "description": "Understand blood vessel types",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe the structure and function of the human heart",
                                    "description": "Understand the double circulatory system",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Trace the path of blood through the pulmonary and systemic circuits",
                                    "description": "Apply knowledge of circulation",
                                    "cognitive_level": "Application",
                                },
                                {
                                    "objective": "Discuss blood groups and the importance of blood transfusion",
                                    "description": "Understand ABO and Rh blood groups",
                                    "cognitive_level": "Comprehension",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Blood smear slides, microscope",
                        "Heart models, blood typing kits",
                    ],
                },
                {
                    "title": "Cancer & Organ Transplants",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Cancer Biology & Transplant Ethics",
                            "learning_objectives": [
                                {
                                    "objective": "Explain what cancer is: uncontrolled cell division (tumours)",
                                    "description": "Understand the basic biology of cancer",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Identify risk factors for cancer: smoking, UV radiation, genetic factors",
                                    "description": "Know the major causes of cancer",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Describe methods of cancer treatment: surgery, chemotherapy, radiotherapy",
                                    "description": "Understand treatment options",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain the concept of organ transplants and the problem of rejection",
                                    "description": "Understand immune rejection",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Discuss the ethical and social issues surrounding organ transplantation",
                                    "description": "Develop informed opinions on medical ethics",
                                    "cognitive_level": "Evaluation",
                                },
                            ],
                        },
                    ],
                    "resources": ["Charts, diagrams", "Videos, case studies"],
                },
            ],
        },
        {
            "number": 6,
            "name": "Micro-organisms",
            "description": "Structure, classification, beneficial and harmful roles of micro-organisms.",
            "topics": [
                {
                    "title": "Structure & Classification",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Bacteria, Viruses & Fungi",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure of bacteria, viruses, and fungi",
                                    "description": "Know the basic structure of micro-organisms",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Distinguish between bacteria (prokaryotes) and viruses (non-cellular)",
                                    "description": "Compare different types of micro-organisms",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain how micro-organisms are classified",
                                    "description": "Understand classification criteria",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe beneficial micro-organisms: decomposition, fermentation, nitrogen fixation",
                                    "description": "Appreciate the positive roles of microbes",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe harmful micro-organisms: disease causation",
                                    "description": "Understand the pathogenic role of microbes",
                                    "cognitive_level": "Comprehension",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Microscope, prepared slides of bacteria, yeast, mould",
                        "Agar plates, Petri dishes",
                    ],
                },
                {
                    "title": "Micro-organisms in Food & Industry",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Fermentation, Food Preservation & Aseptic Technique",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the role of micro-organisms in food production (yogurt, bread, beer)",
                                    "description": "Understand fermentation in daily life",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe how micro-organisms cause food spoilage",
                                    "description": "Understand food preservation needs",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Discuss methods of food preservation (heating, cooling, drying, canning, salting)",
                                    "description": "Know practical preservation methods",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Investigate the growth of micro-organisms under different conditions",
                                    "description": "Practical skill: aseptic technique",
                                    "cognitive_level": "Application/Practical",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Agar plates, incubator, autoclave",
                        "Food samples, preservatives",
                    ],
                },
                {
                    "title": "Micro-organisms & Disease",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Koch's Postulates, Antibiotics & Water Treatment",
                            "learning_objectives": [
                                {
                                    "objective": "Describe how micro-organisms cause disease",
                                    "description": "Understand the process of infection",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain Koch's postulates and their role in identifying disease causation",
                                    "description": "Understand historical advances in microbiology",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Discuss methods of controlling the spread of infection (hygiene, sterilisation, disinfection)",
                                    "description": "Know prevention methods",
                                    "cognitive_level": "Knowledge/Comprehension",
                                },
                                {
                                    "objective": "Discuss the use of antibiotics and the problem of antibiotic resistance",
                                    "description": "Appreciate the challenge of drug resistance",
                                    "cognitive_level": "Evaluation",
                                },
                                {
                                    "objective": "Describe the role of micro-organisms in the water cycle and sewage treatment",
                                    "description": "Understand environmental microbiology",
                                    "cognitive_level": "Comprehension",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Antibiotic discs, agar plates",
                        "Microscopy equipment",
                    ],
                },
            ],
        },
        {
            "number": 7,
            "name": "Genetics & Evolution",
            "description": "Cell division, Mendelian genetics, DNA, variation, evolution, and biotechnology.",
            "topics": [
                {
                    "title": "Cell Division: Mitosis & Meiosis",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Mitosis, Meiosis & Significance",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the process of mitosis and its significance in growth and repair",
                                    "description": "Understand cell division for growth",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe the stages of mitosis (prophase, metaphase, anaphase, telophase)",
                                    "description": "Know the phases of mitosis",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Explain the process of meiosis and its significance in sexual reproduction",
                                    "description": "Understand reduction division",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Compare mitosis and meiosis",
                                    "description": "Distinguish between the two types of cell division",
                                    "cognitive_level": "Analysis",
                                },
                                {
                                    "objective": "Describe the significance of meiosis in producing genetic variation",
                                    "description": "Understand the basis of variation",
                                    "cognitive_level": "Comprehension",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Microscope, prepared slides of mitosis stages",
                        "Onion root tip slides",
                    ],
                },
                {
                    "title": "Mendelian Genetics",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Genes, Alleles & Genetic Crosses",
                            "learning_objectives": [
                                {
                                    "objective": "Define key terms: gene, allele, genotype, phenotype, dominant, recessive, homozygous, heterozygous",
                                    "description": "Know the vocabulary of genetics",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Use Punnett squares to predict the outcomes of monohybrid crosses",
                                    "description": "Apply genetic principles",
                                    "cognitive_level": "Application",
                                },
                                {
                                    "objective": "Determine the genotypes and phenotypes of offspring",
                                    "description": "Predict genetic outcomes",
                                    "cognitive_level": "Application",
                                },
                                {
                                    "objective": "Explain codominance and incomplete dominance with examples",
                                    "description": "Understand extensions to Mendelian genetics",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain the inheritance of sex-linked traits",
                                    "description": "Understand sex determination and sex-linked conditions",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Solve genetic problems using family pedigree charts",
                                    "description": "Apply genetic analysis skills",
                                    "cognitive_level": "Application",
                                },
                                {
                                    "objective": "Explain the concepts of multiple alleles using ABO blood groups as an example",
                                    "description": "Understand inheritance of blood groups",
                                    "cognitive_level": "Application",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Punnett square worksheets, pedigree chart examples",
                        "Genetic case studies",
                    ],
                },
                {
                    "title": "DNA & The Genome",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "DNA Structure, Protein Synthesis & Mutations",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure of DNA (double helix, nucleotides, base pairing)",
                                    "description": "Know the molecular basis of heredity",
                                    "cognitive_level": "Knowledge",
                                },
                                {
                                    "objective": "Explain how genes code for proteins",
                                    "description": "Understand the central dogma of molecular biology",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe the process of protein synthesis (transcription and translation)",
                                    "description": "Understand gene expression",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Discuss the structure and function of chromosomes",
                                    "description": "Understand the organisation of genetic material",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain the concept of the genome and the Human Genome Project",
                                    "description": "Understand modern genetics",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Describe the role of mutations in changing genetic information",
                                    "description": "Understand the source of new alleles",
                                    "cognitive_level": "Comprehension",
                                },
                            ],
                        },
                    ],
                    "resources": ["DNA models, diagrams", "Animations, worksheets"],
                },
                {
                    "title": "Variations & Evolution",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Natural Selection, Evidence & Speciation",
                            "learning_objectives": [
                                {
                                    "objective": "Distinguish between variation and mutation",
                                    "description": "Understand types of variation",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Explain continuous and discontinuous variation with examples",
                                    "description": "Classify types of variation",
                                    "cognitive_level": "Application",
                                },
                                {
                                    "objective": "Describe the theory of evolution by natural selection (Darwin and Wallace)",
                                    "description": "Understand the mechanism of evolution",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Provide evidence for evolution: fossils, comparative anatomy, biogeography",
                                    "description": "Evaluate evidence for evolution",
                                    "cognitive_level": "Analysis",
                                },
                                {
                                    "objective": "Discuss the impact of natural selection on populations",
                                    "description": "Understand adaptation and speciation",
                                    "cognitive_level": "Analysis",
                                },
                                {
                                    "objective": "Discuss the contribution of Malawi's biodiversity to evolutionary studies",
                                    "description": "Appreciate local relevance",
                                    "cognitive_level": "Evaluation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Fossil specimens, charts",
                        "Field guides, identification keys",
                    ],
                },
                {
                    "title": "Biotechnology",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Genetic Engineering & GMOs",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the principles of genetic engineering",
                                    "description": "Understand manipulation of genetic material",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Discuss the applications of genetic engineering in agriculture (GM crops)",
                                    "description": "Evaluate biotechnology in food production",
                                    "cognitive_level": "Evaluation",
                                },
                                {
                                    "objective": "Describe the use of micro-organisms in biotechnology (fermentation, enzyme production)",
                                    "description": "Understand industrial biotechnology",
                                    "cognitive_level": "Comprehension",
                                },
                                {
                                    "objective": "Discuss the ethical issues surrounding genetic engineering and GMOs",
                                    "description": "Develop informed opinions on biotechnology",
                                    "cognitive_level": "Evaluation",
                                },
                                {
                                    "objective": "Explain the role of biotechnology in medicine (insulin production, gene therapy)",
                                    "description": "Understand medical biotechnology",
                                    "cognitive_level": "Comprehension",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Biotechnology case studies",
                        "Debate materials, ethical scenarios",
                    ],
                },
            ],
        },
    ],
}


async def seed_syllabus():
    """Seed the Biology MSCE syllabus. Idempotent."""
    async with async_session() as db:
        existing = (
            await db.execute(
                select(SyllabusSubject).where(SyllabusSubject.slug == "biology")
            )
        ).scalar_one_or_none()
        if existing:
            return

        data = BIOLOGY_SYLLABUS

        subject = SyllabusSubject(**data["subject"])
        db.add(subject)
        await db.commit()
        await db.refresh(subject)

        version = SyllabusVersion(subject_id=subject.id, **data["version"])
        db.add(version)
        await db.commit()
        await db.refresh(version)

        for ce_data in data["core_elements"]:
            topics_data = ce_data.pop("topics", [])
            ce = SyllabusCoreElement(version_id=version.id, **ce_data)
            db.add(ce)
            await db.commit()
            await db.refresh(ce)

            for t_data in topics_data:
                subtopics_data = t_data.pop("subtopics", [])
                resources_data = t_data.pop("resources", [])
                topic = SyllabusTopic(core_element_id=ce.id, **t_data)
                db.add(topic)
                await db.commit()
                await db.refresh(topic)

                for res_text in resources_data:
                    db.add(SyllabusResource(topic_id=topic.id, resource_text=res_text))
                await db.commit()

                for s_data in subtopics_data:
                    los_data = s_data.pop("learning_objectives", [])
                    sub = SyllabusSubtopic(topic_id=topic.id, **s_data)
                    db.add(sub)
                    await db.commit()
                    await db.refresh(sub)

                    for lo_data in los_data:
                        db.add(SyllabusLearningObjective(subtopic_id=sub.id, **lo_data))
                    await db.commit()
