"""Seed the official Malawi MSCE Biology syllabus (MoEST, Forms 1 to 4).

Exact reproduction of the 2013 MoEST Biology Syllabus scope chart (Forms 1–4)
and detailed teaching syllabus (Forms 3 & 4). Run from lifespan in main.py.
Idempotent — skips if subject already exists.
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
        "description": "Malawi MSCE Biology Syllabus — MoEST Forms 1 to 4 (2013)",
        "icon": "science_rounded",
        "color": "#10B981",
    },
    "version": {
        "version_name": "MoEST Forms 1 to 4 (2013)",
        "year_effective": 2013,
        "examination_board": "Malawi National Examinations Board (MANEB)",
        "description": (
            "Official Biology syllabus for Malawi School Certificate of Education "
            "(MSCE), covering Forms 1 to 4. Published by the Ministry of Education, "
            "Science and Technology through the Malawi Institute of Education (MIE)."
        ),
    },
    # ═══════════════════════════════════════════════════════════════════════════
    # CORE ELEMENT 1 — RESEARCH SKILLS (Forms 1–2)
    # ═══════════════════════════════════════════════════════════════════════════
    "core_elements": [
        {
            "number": 1,
            "name": "Research Skills",
            "description": (
                "Scientific investigation skills: safety measures, risk factors, "
                "handling of accidents, laboratory apparatus, drawing diagrams, "
                "recording measurements, study skills (Form 1); planning and "
                "carrying out investigations, recording and analysing data, "
                "using laboratory apparatus, practical methods, and measurement "
                "techniques (Form 2)."
            ),
            "topics": [
                # ── Form 1 topics ────────────────────────────────────────────
                {
                    "title": "Investigative Techniques",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Safety Measures, Risk Factors and Handling of Accidents",
                            "description": (
                                "Safety measures in the laboratory; risk factors; "
                                "handling of accidents."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify safety measures to be observed in the laboratory",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration",
                                },
                                {
                                    "objective": "Identify risk factors in laboratory experiments",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe how to handle common laboratory accidents (burns, cuts, chemical spills, broken glass)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Demonstration, role play",
                                },
                            ],
                        },
                        {
                            "title": "Scientific Apparatus and Their Uses",
                            "description": "Scientific apparatus and their uses.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify common scientific apparatus and describe their uses",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Observation, hands-on",
                                },
                                {
                                    "objective": "Demonstrate correct use of common laboratory apparatus",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical demonstration",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Common laboratory apparatus (beakers, test tubes, measuring cylinders, thermometers, balances, microscopes)",
                        "Safety equipment (fire extinguisher, first aid kit, safety goggles)",
                    ],
                },
                {
                    "title": "Drawing Biological Diagrams",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Observation and Scientific Drawing",
                            "description": (
                                "Observation of specimen and drawing accurate diagrams; "
                                "calculation of magnification."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Observe biological specimens and draw accurate labelled diagrams following scientific conventions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practical",
                                },
                                {
                                    "objective": "Calculate magnification of specimens viewed under a microscope",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Calculation exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Drawing pencils, rulers, graph paper",
                        "Microscopes, prepared slides, biological specimens",
                    ],
                },
                {
                    "title": "Recording Measurements",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Measurement and Calculation",
                            "description": (
                                "Measurements of organisms; calculation of "
                                "variables from measurements."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Measure organisms using appropriate instruments (ruler, calipers, balance)",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Calculate variables (mean, range) from sets of measurements",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Mathematical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Rulers, calipers, balances, measuring cylinders",
                        "Calculators, graph paper",
                    ],
                },
                {
                    "title": "Study Skills",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Summarising and Organising Information",
                            "description": (
                                "Summarising information from books in the form of "
                                "tables, flow diagrams and notes."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Summarise information from textbooks into tables, flow diagrams, and structured notes",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided exercises",
                                },
                                {
                                    "objective": "Organise biological information using appropriate graphic organisers",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practice exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Textbooks, note-taking guides",
                        "Blank paper, rulers for flow diagrams",
                    ],
                },
                # ── Form 2 topics ─────────────────────────────────────────────
                {
                    "title": "Investigative Skills",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Planning and Carrying Out Investigations",
                            "description": (
                                "Planning investigations; carrying out investigations; "
                                "recording and analysing data; drawing conclusions."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Plan a scientific investigation by stating a hypothesis, identifying variables, and describing methods",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Group work",
                                },
                                {
                                    "objective": "Carry out investigations following a planned procedure accurately",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Hands-on practical",
                                },
                                {
                                    "objective": "Record observations and data in appropriate tables and formats",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Analyse data by constructing graphs, calculating means, and identifying patterns",
                                    "cognitive_level": "Application/Analysis",
                                    "teaching_method": "Data analysis",
                                },
                                {
                                    "objective": "Draw valid conclusions from experimental data and relate them to the original hypothesis",
                                    "cognitive_level": "Analysis/Evaluation",
                                    "teaching_method": "Report writing",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Common laboratory apparatus",
                        "Graph paper, calculators",
                    ],
                },
                # ── Form 2 topic ─────────────────────────────────────────────
                {
                    "title": "Research Skills",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Using Laboratory Apparatus and Equipment",
                            "description": (
                                "Name and use laboratory apparatus; draw apparatus; "
                                "record observations; draw; graph work; use word descriptions."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Name and use common laboratory apparatus correctly",
                                    "cognitive_level": "Knowledge/Application",
                                    "teaching_method": "Practical demonstration",
                                },
                                {
                                    "objective": "Draw apparatus and apparatus setups accurately",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided drawing practice",
                                },
                                {
                                    "objective": "Record observations accurately in standard scientific format",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Laboratory exercises",
                                },
                                {
                                    "objective": "Draw specimens to scale using correct scientific drawing conventions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practical",
                                },
                                {
                                    "objective": "Construct graphs from experimental data with correct labels, scales, and titles",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Data analysis exercises",
                                },
                                {
                                    "objective": "Use word descriptions to communicate experimental findings",
                                    "cognitive_level": "Comprehension/Application",
                                    "teaching_method": "Laboratory report writing",
                                },
                            ],
                        },
                        {
                            "title": "Practical Methods",
                            "description": (
                                "Dissolving, decanting, filtration, evaporation, distillation, "
                                "and chromatography techniques."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Carry out dissolving, decanting, and filtration techniques correctly",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Hands-on practical",
                                },
                                {
                                    "objective": "Perform evaporation and crystallisation to obtain solute from solution",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical demonstration",
                                },
                                {
                                    "objective": "Set up and carry out simple distillation",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Guided practical",
                                },
                                {
                                    "objective": "Perform paper chromatography to separate mixtures",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Hands-on practical",
                                },
                            ],
                        },
                        {
                            "title": "Measurement",
                            "description": "Measurement of length, mass, volume, and temperature.",
                            "learning_objectives": [
                                {
                                    "objective": "Measure length accurately using appropriate instruments (ruler, vernier caliper, micrometer)",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Measure mass using a balance (top-pan, beam balance)",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Measure volume of liquids and irregularly shaped solids",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Measure temperature using a thermometer",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Common laboratory apparatus (beakers, test tubes, measuring cylinders, thermometers, balances, rulers, microscopes)",
                        "Filtration equipment, chromatography paper, distillation setup",
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 2 — ENVIRONMENT (Forms 1 & 3)
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 2,
            "name": "Environment",
            "description": (
                "Characteristics of living things, classification, identification, "
                "food chains and feeding structures (Form 1); "
                "organisms and their environment, populations, ecosystems, "
                "energy flow, nutrient cycles, and human impact on the environment "
                "(Form 3)."
            ),
            "topics": [
                # ── Form 1 topics ────────────────────────────────────────────
                {
                    "title": "Organisms and Their Environment",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Characteristics of Living Things",
                            "description": "Characteristics of living things.",
                            "learning_objectives": [
                                {
                                    "objective": "State the characteristics of living things (MRS NERG: Movement, Reproduction, Sensitivity, Nutrition, Excretion, Respiration, Growth)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Charts, textbook diagrams",
                        "Living specimens for observation",
                    ],
                },
                {
                    "title": "Classification of Living Things",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Classification of Organisms",
                            "description": (
                                "Classification of organisms according to: "
                                "similarities and differences, habitats, feeding methods."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Classify organisms according to similarities and differences",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Sorting exercises",
                                },
                                {
                                    "objective": "Classify organisms according to their habitats",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Field observations",
                                },
                                {
                                    "objective": "Classify organisms according to their feeding methods",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": ["Charts, classification keys", "Preserved specimens"],
                },
                {
                    "title": "Identification of Living Things",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Using Identification Methods",
                            "description": (
                                "Identification of living things using: "
                                "dichotomous keys, hierarchy, scientific names."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Use dichotomous keys to identify organisms",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Use hierarchical classification systems to identify organisms",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Diagram work",
                                },
                                {
                                    "objective": "Apply scientific names to identify organisms (binomial nomenclature)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Note-taking",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Dichotomous keys, charts",
                        "Preserved specimens, field guides",
                    ],
                },
                {
                    "title": "Food Chains and Food Webs",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Feeding Relationships in Ecosystems",
                            "description": (
                                "Plants as food producers; animals as food consumers; "
                                "identification of animals according to mode of feeding; "
                                "construction of food chains and food webs."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify plants as food producers and animals as consumers",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Classify animals according to their mode of feeding (herbivores, carnivores, omnivores)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Construct food chains from given organisms in a habitat",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Construct food webs from food chains in a habitat",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Group work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Charts showing food chains and webs",
                        "Field observation of local ecosystems",
                    ],
                },
                {
                    "title": "Feeding Structures in Animals",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Adaptations of Feeding Structures",
                            "description": (
                                "Identification of the feeding structures of animals; "
                                "functions of feeding structures; the relationship between "
                                "feeding structures and the food which the animals eat."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify feeding structures of different animals (teeth, beaks, claws, mouthparts)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Observation",
                                },
                                {
                                    "objective": "Describe the functions of feeding structures in relation to diet",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Explain the relationship between feeding structures and the type of food consumed",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Comparison exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Skull models, jaw specimens",
                        "Charts showing feeding adaptations",
                        "Preserved specimens",
                    ],
                },
                # ── Form 3 topic ─────────────────────────────────────────────
                {
                    "title": "Organisms and Their Environment",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Distribution of Organisms",
                            "description": (
                                "Sampling techniques, quadrats, transects, "
                                "distribution patterns, and effects of abiotic factors."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Use sampling techniques to estimate the distribution and abundance of organisms",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Field study",
                                },
                                {
                                    "objective": "Use quadrats and transects to sample organisms in a habitat",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Field study",
                                },
                                {
                                    "objective": "Describe the distribution of organisms in a given habitat",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Observation and discussion",
                                },
                                {
                                    "objective": "Investigate the effects of abiotic factors on the distribution of organisms",
                                    "cognitive_level": "Application/Analysis",
                                    "teaching_method": "Practical investigation",
                                },
                            ],
                        },
                        {
                            "title": "Populations and Communities",
                            "description": (
                                "Factors affecting population sizes and "
                                "relationships among organisms in a community."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify factors affecting the sizes of populations of organisms in a habitat",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                                {
                                    "objective": "Describe the relationships among organisms in a community (predation, competition, symbiosis)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Observation, field study",
                                },
                            ],
                        },
                        {
                            "title": "Ecosystems",
                            "description": (
                                "Food chains, food webs, trophic levels, ecological "
                                "pyramids, energy flow, and nutrient cycles."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe an ecosystem as the interaction of living organisms with their environment",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Differentiate between a food chain and a food web",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Identify trophic levels in an ecosystem",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Diagram work",
                                },
                                {
                                    "objective": "Construct ecological pyramids (pyramids of numbers, biomass, energy)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Data analysis exercises",
                                },
                                {
                                    "objective": "Explain the transfer of energy in a food chain and the 10% rule",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, calculation exercises",
                                },
                                {
                                    "objective": "Describe nutrient cycles in an ecosystem (carbon, nitrogen, water cycles)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Identify the components of an ecosystem (producers, consumers, decomposers, abiotic factors)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Observation, discussion",
                                },
                                {
                                    "objective": "Explain the effects of physical (abiotic) factors on organisms",
                                    "cognitive_level": "Comprehension/Analysis",
                                    "teaching_method": "Practical investigation",
                                },
                            ],
                        },
                        {
                            "title": "Man's Activities on the Environment",
                            "description": (
                                "Effects of human activities, deforestation, "
                                "pollution, eutrophication, global warming, "
                                "and mitigation strategies."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the effects of human activities on the environment (deforestation, pollution, eutrophication)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Case studies, discussion",
                                },
                                {
                                    "objective": "Explain the effects of deforestation on local and global climate",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Describe the causes and effects of global warming and climate change",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, video presentation",
                                },
                                {
                                    "objective": "Suggest ways of mitigating the effects of human activities on the environment",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Group discussion, debate",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Quadrats, transect lines, pitfall traps, sweep nets",
                        "Thermometer, pH meter, rain gauge, light meter",
                        "Graph paper, calculator",
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 3 — PLANT BIOLOGY (Forms 1–4)
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 3,
            "name": "Plant Biology",
            "description": (
                "Plant diversity (Form 1); plant structures and functions, "
                "photosynthesis (Form 2); plant structure, transport, "
                "photosynthesis, transpiration (Form 3); tropisms (Form 4)."
            ),
            "topics": [
                # ── Form 1 topic ─────────────────────────────────────────────
                {
                    "title": "Plant Diversity",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Flowering and Non-Flowering Plants",
                            "description": (
                                "Flowering and non-flowering plants; monocots and dicots; "
                                "characteristics of non-flowering and flowering plants; "
                                "external features of non-flowering and flowering plants; "
                                "habitats of different groups of plants."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Distinguish between flowering and non-flowering plants",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Observation",
                                },
                                {
                                    "objective": "Distinguish between monocot and dicot plants",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Observation",
                                },
                                {
                                    "objective": "Describe characteristics of non-flowering plants (ferns, mosses, conifers)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work",
                                },
                                {
                                    "objective": "Describe characteristics of flowering plants (angiosperms)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work",
                                },
                                {
                                    "objective": "Identify external features of non-flowering and flowering plants",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Observation, field study",
                                },
                                {
                                    "objective": "Describe the habitats of different groups of plants (aquatic, terrestrial, epiphytic)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Live plant specimens (flowering and non-flowering)",
                        "Charts, pressed plant collections",
                        "Field guide to Malawian plants",
                    ],
                },
                # ── Form 2 topics ────────────────────────────────────────────
                {
                    "title": "Plant Structures and Functions",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Internal Structure of Plants",
                            "description": (
                                "Internal structure of leaves, stems, roots; "
                                "functions of leaves, stems, roots; leaf structures and "
                                "functions; distribution of stomates on the upper and "
                                "lower sides of a leaf."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the internal structure of leaves and identify the functions of each part",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Microscopy practical",
                                },
                                {
                                    "objective": "Describe the internal structure of stems and identify the functions of each part",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Microscopy practical",
                                },
                                {
                                    "objective": "Describe the internal structure of roots and identify the functions of each part",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Microscopy practical",
                                },
                                {
                                    "objective": "Explain the relationship between leaf structure and function",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Investigate the distribution of stomates on the upper and lower surfaces of leaves",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Microscope, prepared slides of leaf, stem, root cross-sections",
                        "Fresh plant specimens",
                        "Iodine solution, chessboard squares for stomatal count",
                    ],
                },
                {
                    "title": "Photosynthesis",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Food Making in Green Plants",
                            "description": (
                                "Raw materials for photosynthesis; conditions necessary "
                                "for photosynthesis; investigations on conditions "
                                "necessary for photosynthesis (light, carbon dioxide, "
                                "chlorophyll)."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify the raw materials needed for photosynthesis (carbon dioxide, water, light, chlorophyll)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe the conditions necessary for photosynthesis",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Investigate the role of light in photosynthesis",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                                {
                                    "objective": "Investigate the role of carbon dioxide in photosynthesis",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                                {
                                    "objective": "Investigate the role of chlorophyll in photosynthesis",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Elodea/aquatic plant, sodium bicarbonate solution",
                        "Lamp, beakers, boiling tubes",
                        "Alcohol, iodine solution, water bath",
                    ],
                },
                # ── Form 3 topics ────────────────────────────────────────────
                {
                    "title": "Plant Structure and Function",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Cell Structure",
                            "description": (
                                "Cell as the basic unit of life; using a microscope; "
                                "observing plant and animal cells."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the cell as the basic structural and functional unit of all living organisms",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, slides",
                                },
                                {
                                    "objective": "Use a microscope correctly to observe plant and animal cells",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical work",
                                },
                                {
                                    "objective": "Observe and draw plant and animal cells as seen under a microscope",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, drawing",
                                },
                                {
                                    "objective": "Describe the functions of the cell wall, cell membrane, cytoplasm, nucleus, chloroplasts, and large vacuole in plant cells",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, diagram work",
                                },
                            ],
                        },
                        {
                            "title": "Levels of Organisation",
                            "description": (
                                "Tissues, plant organs (roots, stems, leaves), "
                                "and monocot vs dicot differences."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Explain how cells are organised into tissues in plants",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, diagram work",
                                },
                                {
                                    "objective": "Describe the internal structure and function of roots (cross-section of a dicot root)",
                                    "cognitive_level": "Comprehension/Practical",
                                    "teaching_method": "Microscopy practical",
                                },
                                {
                                    "objective": "Describe the internal structure and function of stems (cross-section of a dicot stem)",
                                    "cognitive_level": "Comprehension/Practical",
                                    "teaching_method": "Microscopy practical",
                                },
                                {
                                    "objective": "Describe the internal structure and function of leaves (cross-section of a leaf)",
                                    "cognitive_level": "Comprehension/Practical",
                                    "teaching_method": "Microscopy practical",
                                },
                                {
                                    "objective": "Distinguish between monocot and dicot plants using seed and leaf venation patterns",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Observation, comparison exercises",
                                },
                            ],
                        },
                        {
                            "title": "Transport in Plants",
                            "description": (
                                "Absorption, osmosis, root pressure, water and "
                                "mineral transport, and transpiration."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Explain the absorption of water and dissolved mineral salts by plant roots",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, experiment",
                                },
                                {
                                    "objective": "Describe the process of osmosis and its role in water absorption by roots",
                                    "cognitive_level": "Comprehension/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                                {
                                    "objective": "Explain the role of root pressure in the transport of water in plants",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe how water and dissolved mineral salts are transported through xylem",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Define transpiration and explain how it occurs through stomata",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Investigate the factors affecting the rate of transpiration using a potometer",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                            ],
                        },
                        {
                            "title": "Photosynthesis",
                            "description": (
                                "Carbon dioxide/oxygen in air, carbohydrate synthesis, "
                                "factors affecting rate, stomatal experiments, "
                                "leaf and chloroplast structure."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the role of carbon dioxide and oxygen in photosynthesis",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "State the word equation for photosynthesis: carbon dioxide + water → glucose + oxygen (in the presence of light and chlorophyll)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Note-taking, discussion",
                                },
                                {
                                    "objective": "Explain how photosynthesis produces carbohydrates, fats, and proteins",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe the factors affecting the rate of photosynthesis (light intensity, CO₂ concentration, temperature)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, experiment",
                                },
                                {
                                    "objective": "Carry out a stomatal experiment to show that stomata are present on the underside of leaves",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical work",
                                },
                                {
                                    "objective": "Describe the structure and function of stomata in relation to gas exchange",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Microscopy, diagram work",
                                },
                                {
                                    "objective": "Investigate the rate of photosynthesis using an aquatic plant (Elodea) and计数bubbles",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                                {
                                    "objective": "Describe the structure of a leaf as adapted for photosynthesis",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe the structure and function of chloroplasts",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Microscope, prepared slides of plant tissues (root, stem, leaf cross-sections)",
                        "Fresh plant specimens (monocot and dicot seeds/leaves)",
                        "Elodea/aquatic plant, sodium bicarbonate solution, lamp, beakers",
                        "Potometer, fresh shoot, water, oil, Vaseline, plastic bag",
                        "Iodine solution, ethanol, water bath (for starch test)",
                    ],
                },
                # ── Form 4 topic ─────────────────────────────────────────────
                {
                    "title": "Tropisms",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Plant Growth Responses",
                            "description": (
                                "Effects of gravity, light, touch, and water on plant "
                                "growth; tropic and nastic movements; auxins; "
                                "practical applications in farming and horticulture."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the effects of gravity on the growth of roots and shoots (gravitropism/geotropism)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Observation of experiments",
                                },
                                {
                                    "objective": "Describe the effects of light on the growth of shoots and leaves (phototropism)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Observation of experiments",
                                },
                                {
                                    "objective": "Describe the effects of touch/wind on plant growth (thigmotropism)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Observation, discussion",
                                },
                                {
                                    "objective": "Describe the effects of water on root growth (hydrotropism)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Practical investigation",
                                },
                                {
                                    "objective": "Differentiate between tropic and nastic movements",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Comparison, discussion",
                                },
                                {
                                    "objective": "Discuss practical applications of tropisms in farming and horticulture",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case studies, discussion",
                                },
                                {
                                    "objective": "Explain the role of auxins in controlling plant tropisms",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Design experiments to investigate tropisms in plants",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Guided practical planning",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Growing seedlings (beans, maize), dark cupboard, lamp",
                        "Auxin solution, filter paper, wool",
                        "Graph paper, ruler",
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 4 — ANIMAL BIOLOGY (Forms 1 & 3)
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 4,
            "name": "Animal Biology",
            "description": (
                "External features of invertebrates and vertebrates (Form 1); "
                "main groups of animals, internal structure of vertebrates, "
                "and locomotion (Form 3)."
            ),
            "topics": [
                # ── Form 1 topic ─────────────────────────────────────────────
                {
                    "title": "Animal Structures and Functions",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "External Features of Invertebrates and Vertebrates",
                            "description": (
                                "External features of invertebrates (insects, nematodes, "
                                "annelids, crustaceans, arachnids, molluscs) and "
                                "vertebrates (fish, amphibians, reptiles, birds, mammals)."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify the external features of selected invertebrates (insects, worms, crabs, spiders, snails)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Observation",
                                },
                                {
                                    "objective": "Identify the external features of selected vertebrates (fish, frogs, lizards, birds, mammals)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Observation",
                                },
                                {
                                    "objective": "Compare the external features of different animal groups",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Comparison exercises",
                                },
                                {
                                    "objective": "Classify animals as invertebrates or vertebrates based on external features",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Classification exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Preserved animal specimens (invertebrates and vertebrates)",
                        "Charts, models",
                        "Field guide to Malawian animals",
                    ],
                },
                # ── Form 3 topics ────────────────────────────────────────────
                {
                    "title": "Main Groups of Animals",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Classification of Vertebrates and Invertebrates",
                            "description": (
                                "Key features of vertebrates and invertebrates; "
                                "classification using identification keys."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "State the key features that distinguish vertebrates from invertebrates",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, comparison",
                                },
                                {
                                    "objective": "Classify animals into major invertebrate phyla (Porifera to Echinodermata)",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Charts, specimens",
                                },
                                {
                                    "objective": "Classify vertebrates into the five main classes (fish, amphibians, reptiles, birds, mammals) using key features",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Observation, discussion",
                                },
                                {
                                    "objective": "Use identification keys to classify animal specimens",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical classification exercise",
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
                    "title": "Internal Structure of Vertebrates",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Tissue Systems, Organ Systems and Dissection",
                            "description": (
                                "Tissue systems, organ systems and their components, "
                                "interdependence of organ systems, dissection of "
                                "a mammalian heart and eye."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the tissue systems in vertebrates (epithelial, connective, muscle, nervous)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Identify the main organ systems in vertebrates (digestive, circulatory, respiratory, excretory, nervous, reproductive)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Diagram work",
                                },
                                {
                                    "objective": "Describe the components of each organ system and explain their interdependence",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                                {
                                    "objective": "Perform a dissection of a mammalian heart to show its internal structure",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Guided dissection",
                                },
                                {
                                    "objective": "Perform a dissection of a mammalian eye to show its internal structure",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Guided dissection",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Dissection kit (scalpel, scissors, forceps, pins, dissecting board)",
                        "Preserved heart specimens (sheep/pig heart), mammalian eye (cow/sheep eye)",
                        "Charts of organ systems, models",
                    ],
                },
                {
                    "title": "Locomotion in Animals",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Types of Movement and Muscles",
                            "description": (
                                "Types of movement in animals; role of muscles and "
                                "skeleton in movement; antagonistic muscle pairs."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the different types of movement in animals (locomotion, movement of body parts, movement of substances within the body)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Observation, discussion",
                                },
                                {
                                    "objective": "Explain how muscles work in antagonistic pairs to produce movement at joints",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, model demonstration",
                                },
                                {
                                    "objective": "Compare the skeletal systems of fish, birds, and mammals and relate structure to function",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Comparison exercises",
                                },
                                {
                                    "objective": "Describe the structure and function of different types of joints (ball-and-socket, hinge, pivot)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Model demonstration, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Skeletal models, joint models",
                        "Charts, diagrams, video of animal locomotion",
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 5 — HUMAN BIOLOGY (Forms 1–4)
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 5,
            "name": "Human Biology",
            "description": (
                "Nutrition, balanced diet, deficiency diseases, digestive system, "
                "circulatory system, anaemia, worm infestations (Form 1); "
                "blood donation, respiratory system, nervous system, sense organs, "
                "locomotion, injuries to bones and joints, human diseases (Form 2); "
                "digestive system, blood circulatory system, lymphatic system, "
                "reproductive system (Form 3); respiratory system, excretory "
                "system, coordination and response, immunity, cancer, blood "
                "groups, and common infectious diseases (Form 4)."
            ),
            "topics": [
                # ── Form 1 topics ────────────────────────────────────────────
                {
                    "title": "Nutrition in Humans",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Food Nutrients and Substances",
                            "description": (
                                "Food nutrients; food substances; functions of different "
                                "types of food nutrients; food tests; common sources of "
                                "food nutrients."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify food nutrients (carbohydrates, proteins, lipids, vitamins, mineral salts, water, roughage)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Identify food substances in common foods",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe the functions of different types of food nutrients",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Carry out food tests for carbohydrates (iodine test)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical",
                                },
                                {
                                    "objective": "Carry out food tests for proteins (Biuret test)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical",
                                },
                                {
                                    "objective": "Carry out food tests for lipids (Sudan III/Ethanol emulsion test)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical",
                                },
                                {
                                    "objective": "Identify common sources of food nutrients",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Food samples",
                        "Test reagents (iodine, Biuret, Sudan III)",
                        "Charts, diagrams",
                    ],
                },
                {
                    "title": "Balanced Diet",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Meaning and Design of Balanced Diet",
                            "description": "Meaning of balanced diet; designing a balanced diet.",
                            "learning_objectives": [
                                {
                                    "objective": "Define balanced diet",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Design a balanced diet",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Food composition charts",
                        "Diet planning worksheets",
                    ],
                },
                {
                    "title": "Deficiency Diseases",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Examples, Causes and Prevention of Deficiency Diseases",
                            "description": (
                                "Examples; causes; signs and symptoms; prevention; "
                                "treatment; causes of obesity; ways of preventing obesity."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe examples of deficiency diseases",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe causes of deficiency diseases",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe signs and symptoms of deficiency diseases",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe prevention of deficiency diseases",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe treatment of deficiency diseases",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe causes of obesity",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe ways of preventing obesity",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": ["Charts, diagrams", "Textbooks"],
                },
                {
                    "title": "Digestive System",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Parts and Functions of the Digestive Tract",
                            "description": (
                                "Parts of the human digestive tract; functions of parts "
                                "of the human digestive tract; process of digestion; "
                                "physical and chemical digestion; enzymes involved in "
                                "digestion; end products of digestion."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify parts of the human digestive tract",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe functions of parts of the human digestive tract",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe the process of digestion",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Differentiate physical and chemical digestion",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Identify enzymes involved in digestion",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe end products of digestion: amino acids, glucose, fatty acids, glycerol",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": ["Digestive system models", "Charts, diagrams"],
                },
                {
                    "title": "Circulatory System",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Parts and Functions of the Circulatory System",
                            "description": (
                                "Parts of the human circulatory system and their functions; "
                                "the heart; arteries, veins, capillaries; blood circulation; "
                                "composition of blood: plasma, blood cells, platelets; "
                                "functions of components of blood."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify parts of the human circulatory system and their functions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe the heart",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Differentiate arteries, veins, and capillaries",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe blood circulation",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Identify composition of blood: plasma, blood cells, platelets",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe functions of components of blood",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": ["Heart models", "Blood charts", "Microscope slides"],
                },
                {
                    "title": "Anaemia",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Causes, Signs and Prevention of Anaemia",
                            "description": (
                                "Causes (e.g. worms, bleeding, lack of nutrients); "
                                "signs and symptoms; prevention; treatment."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe causes of anaemia (worms, bleeding, lack of nutrients)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe signs and symptoms of anaemia",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe prevention of anaemia",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe treatment of anaemia",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": ["Charts, diagrams", "Textbooks"],
                },
                {
                    "title": "Worm Infestations",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Types, Life Cycles and Prevention of Worm Infestations",
                            "description": (
                                "Roundworms, hookworms, tapeworms, threadworms, "
                                "bilharzia worms; life cycles of worms; modes of "
                                "transmission; signs and symptoms; preventive and "
                                "control measures."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify types of worms: roundworms, hookworms, tapeworms, threadworms, bilharzia worms",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe life cycles of worms",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe modes of transmission of worms",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe signs and symptoms of worm infestations",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe preventive and control measures for worm infestations",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": ["Charts", "Life cycle diagrams", "Textbooks"],
                },
                # ── Form 2 topics ────────────────────────────────────────────
                {
                    "title": "Blood Donation",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Blood Donation and Transfusion",
                            "description": (
                                "Types of blood donors: family replacement donors, voluntary "
                                "non-remunerated donors; process of blood donation; "
                                "role of Malawi Blood Transfusion Service (MBTS)."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify types of blood donors: family replacement and voluntary non-remunerated",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe the process of blood donation",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, video",
                                },
                                {
                                    "objective": "Describe the role of the Malawi Blood Transfusion Service (MBTS)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Charts, diagrams",
                        "MBTS information leaflets",
                        "Video of blood donation process",
                    ],
                },
                {
                    "title": "Respiratory System",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Parts and Functions of the Respiratory System",
                            "description": (
                                "Parts of the respiratory system and their functions; "
                                "breathing mechanism; composition of exhaled air; "
                                "artificial ventilation."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify parts of the respiratory system and their functions",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe the breathing mechanism",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe the composition of exhaled air",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Explain artificial ventilation",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, video",
                                },
                            ],
                        },
                    ],
                    "resources": ["Respiratory system models", "Charts, diagrams"],
                },
                {
                    "title": "Nervous System",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Stimulus and Response",
                            "description": (
                                "Stimulus and response; parts of the nervous system and "
                                "their functions: central nervous system, peripheral, "
                                "autonomic; effects of alcohol and Indian hemp on the "
                                "nervous system."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Define stimulus and response",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Identify parts of the nervous system and their functions (central, peripheral, autonomic)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe the effects of alcohol and Indian hemp on the nervous system",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, research",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Nervous system models",
                        "Charts, diagrams",
                        "Case studies",
                    ],
                },
                {
                    "title": "Sense Organs",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Parts and Functions of Sense Organs",
                            "description": (
                                "Parts of the eye, ear, and skin and their functions; "
                                "defects of the eye and ear and their correction; "
                                "care for eyes, ears and skin."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify parts of the eye, ear, and skin and describe their functions",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe defects of the eye and ear and their correction",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe ways of caring for eyes, ears and skin",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": ["Eye and ear models", "Charts, diagrams"],
                },
                {
                    "title": "Locomotion",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Parts of the Skeleton, Bone Structure and Muscles",
                            "description": (
                                "Parts of the skeleton; bone structure and functions; "
                                "types of muscles and their functions: voluntary, "
                                "involuntary, cardiac; antagonistic muscles."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify parts of the skeleton and describe their functions",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe bone structure and its functions",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work",
                                },
                                {
                                    "objective": "Differentiate types of muscles: voluntary, involuntary, cardiac",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Explain how antagonistic muscles work together",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": ["Skeletal models", "Muscle diagrams", "Charts"],
                },
                {
                    "title": "Injuries to Bones and Joints",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Types of Injuries and First Aid",
                            "description": (
                                "Types of joints; injuries to bones; fractures; "
                                "injuries at joints; sprains; strains; dislocations; "
                                "first aid for injuries to bones and joints."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify types of joints",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion/Practical",
                                },
                                {
                                    "objective": "Describe different types of bone injuries and fractures",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe joint injuries: sprains, strains, dislocations",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe first aid for injuries to bones and joints",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Demonstration, role play",
                                },
                            ],
                        },
                    ],
                    "resources": ["Charts, diagrams", "First aid kits", "Case studies"],
                },
                {
                    "title": "Human Diseases",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Diarrhoeal Diseases and Sexually Transmitted Diseases",
                            "description": (
                                "Diarrhoeal diseases: cholera and dysentery — causative "
                                "agents, signs and symptoms, mode of transmission, "
                                "prevention, treatment. Sexually transmitted diseases: "
                                "gonorrhoea, syphilis, candidiasis, warts, HIV and AIDS "
                                "— causes, modes of transmission, signs and symptoms, "
                                "prevention, treatment; caring for HIV and AIDS patients; "
                                "misconceptions about HIV and AIDS; effects of STIs "
                                "including HIV and AIDS on the individual, the family, "
                                "the nation."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe causative agents, signs, symptoms, transmission, prevention and treatment of cholera and dysentery",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Describe causes, modes of transmission, signs and symptoms, prevention and treatment of STIs (gonorrhoea, syphilis, candidiasis, warts)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Describe causes, modes of transmission, signs and symptoms, prevention and treatment of HIV and AIDS",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Discuss ways of caring for HIV and AIDS patients",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Discussion, guest speaker",
                                },
                                {
                                    "objective": "Discuss misconceptions about HIV and AIDS",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Discussion, debate",
                                },
                                {
                                    "objective": "Discuss the effects of STIs including HIV and AIDS on the individual, the family, and the nation",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, group discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Charts, case studies",
                        "Guest speakers",
                        "Research materials",
                    ],
                },
                # ── Form 3 topics ────────────────────────────────────────────
                {
                    "title": "Human Digestive System",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Nutrition and the Need for Food",
                            "description": (
                                "Types of nutrition; organic and inorganic nutrients; "
                                "accessory food factors (vitamins and roughage); "
                                "the six classes of food and their functions; "
                                "deficiency diseases; diet composition; food combinations."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Define nutrition and distinguish between autotrophic and heterotrophic nutrition",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "State the need for food: source of energy, body building, regulation of body processes",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, note-taking",
                                },
                                {
                                    "objective": "Identify organic nutrients (carbohydrates, proteins, fats) and their functions",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Discussion, food analysis",
                                },
                                {
                                    "objective": "Identify inorganic nutrients (mineral salts: calcium, iron, iodine, sodium, potassium) and their functions",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Explain the role of accessory food factors: vitamins (A, B, C, D) and roughage",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                                {
                                    "objective": "State the six classes of food and describe the function of each in the body",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Note-taking, group work",
                                },
                                {
                                    "objective": "Identify deficiency diseases caused by lack of specific nutrients",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Case studies, research",
                                },
                                {
                                    "objective": "Describe a balanced diet and explain its importance for health",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, food diary analysis",
                                },
                                {
                                    "objective": "Describe the food combinations commonly eaten in Malawi to form balanced meals",
                                    "cognitive_level": "Comprehension/Application",
                                    "teaching_method": "Research, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Digestion, Absorption and Transport",
                            "description": (
                                "Alimentary canal components; teeth and dental problems; "
                                "enzymes; food absorption; liver functions; "
                                "digestive system abnormalities."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "List the components of the alimentary canal and describe the function of each part",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe the structure and types of teeth and their roles in digestion",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, observation",
                                },
                                {
                                    "objective": "Discuss common dental problems and how to maintain healthy teeth",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Discussion, research",
                                },
                                {
                                    "objective": "Explain the roles of digestive enzymes (amylase, pepsin, lipase, maltase, trypsin) in breaking down food",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, enzyme experiments",
                                },
                                {
                                    "objective": "Describe how digested food is absorbed in the small intestine",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe the functions of the liver in relation to digestion (bile production, detoxification, glycogen storage)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Discuss abnormal conditions of the digestive system (constipation, diarrhoea, ulcers, indigestion)",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case studies, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Models of the alimentary canal, teeth models/charts",
                        "Digestive enzyme experiment kits (starch, protein, fat solutions; iodine, Biuret, litmus)",
                        "Charts showing balanced diets, deficiency diseases",
                    ],
                },
                {
                    "title": "Human Blood Circulatory System",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Heart, Blood and Blood Vessels",
                            "description": (
                                "Role of the circulatory system; heart structure and "
                                "function; blood components; blood vessels; heartbeat "
                                "investigations; blood pressure; lifestyle effects; "
                                "blood disorders."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "State the role of the circulatory system in transporting substances around the body",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe the structure and function of the human heart",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Model, diagram work",
                                },
                                {
                                    "objective": "Describe the composition of blood: plasma, red blood cells, white blood cells, and platelets",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Microscopy of blood smears",
                                },
                                {
                                    "objective": "Explain the function of each blood component",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe the structure and function of arteries, veins, and capillaries",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, model",
                                },
                                {
                                    "objective": "Investigate the heartbeat: count pulse rate at rest and after exercise",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                                {
                                    "objective": "Describe what blood pressure is and how it is measured",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Demonstration, discussion",
                                },
                                {
                                    "objective": "Discuss how lifestyle factors (diet, exercise, smoking, alcohol) affect the circulatory system",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Discuss common blood disorders (anaemia, leukaemia, sickle cell disease) and their effects",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case studies",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Heart models, blood typing kits",
                        "Microscope, blood smear slides",
                        "Pulse rate chart, stethoscope",
                    ],
                },
                {
                    "title": "Human Lymphatic System",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Lymphatic Vessels and Nodes",
                            "description": (
                                "Component parts of the lymphatic system and their functions."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify the component parts of the lymphatic system (lymph vessels, lymph nodes, spleen, thymus gland, tonsils)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe the functions of the lymphatic system (drainage, immune defence, fat absorption)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Diagram of the lymphatic system",
                        "Charts, models",
                    ],
                },
                {
                    "title": "Human Reproductive System",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Reproduction",
                            "description": (
                                "Sexual reproduction; male and female reproductive "
                                "systems; sperm and ovum; menstruation; fertilisation "
                                "and conception; the placenta; process of birth; "
                                "contraception; reproductive abnormalities."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Define sexual reproduction and explain the roles of male and female gametes",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe the structure and function of the male reproductive system (testes, vas deferens, prostate gland, penis)",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe the structure and function of the female reproductive system (ovaries, oviducts, uterus, vagina, vulva)",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe the production of sperm and ova (gametogenesis)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work",
                                },
                                {
                                    "objective": "Describe the menstrual cycle and the hormones involved (FSH, LH, oestrogen, progesterone)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Explain fertilisation and how it leads to conception",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe the structure and function of the placenta in nourishing the developing foetus",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe the process of birth (parturition)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Video, discussion",
                                },
                                {
                                    "objective": "Describe methods of contraception and explain how they prevent pregnancy",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Discuss abnormal conditions associated with reproduction (infertility, STIs, cervical cancer, prostate cancer)",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case studies, research",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Reproductive system models (male and female)",
                        "Charts of menstrual cycle, contraception methods",
                        "Video of human reproduction",
                    ],
                },
                # ── Form 4 topics ─────────────────────────────────────────────
                {
                    "title": "Respiratory System",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Breathing Mechanism and Gaseous Exchange",
                            "description": (
                                "Breathing mechanism; breathing capacity; gaseous "
                                "exchange; measurement of breathing; respiratory "
                                "abnormalities."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure and function of the human respiratory system (nose, trachea, bronchi, lungs, alveoli, diaphragm)",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Diagram work, model",
                                },
                                {
                                    "objective": "Explain the mechanism of breathing (inhalation and exhalation) including the role of the diaphragm and intercostal muscles",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, demonstration",
                                },
                                {
                                    "objective": "Investigate breathing capacity using a spirometer or similar equipment",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical measurement",
                                },
                                {
                                    "objective": "Describe gaseous exchange in the alveoli (diffusion of oxygen and carbon dioxide)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Investigate the effect of exercise on breathing rate and depth",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                                {
                                    "objective": "Discuss respiratory abnormalities (asthma, bronchitis, emphysema, lung cancer) and their causes",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case studies, research",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Spirometer, stopwatch, stethoscope",
                        "Respiratory system model, diagrams",
                    ],
                },
                {
                    "title": "Excretory System",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Excretion and Osmoregulation",
                            "description": (
                                "Excretory system (kidneys, ureters, bladder, urethra); "
                                "skin as excretory organ; composition of urine; "
                                "effects of water and salt intake; ADH and "
                                "osmoregulation; artificial kidney (dialysis)."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Define excretion and distinguish it from egestion",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Identify the organs of the excretory system (kidneys, ureters, bladder, urethra) and describe the function of each",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Diagram work, model",
                                },
                                {
                                    "objective": "Describe the role of the skin as an excretory organ (sweat glands)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe the composition of urine (water, urea, mineral salts)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Investigate the effects of water and salt intake on the volume and concentration of urine produced",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                                {
                                    "objective": "Explain the role of ADH (antidiuretic hormone) in osmoregulation",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Explain how a dialysis machine (artificial kidney) works to remove waste products from blood",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, video, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Kidney models, nephron diagrams",
                        "Charts of osmoregulation, dialysis machine diagram",
                    ],
                },
                {
                    "title": "Coordination and Response",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Nervous System and Reflex Actions",
                            "description": (
                                "Functioning of the nervous system; nerve cells; "
                                "structure of neurones; spinal cord; impulse "
                                "transmission; reflex actions; conditioned reflexes; "
                                "diseases of the nervous system."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the functioning of the nervous system: central nervous system (brain and spinal cord) and peripheral nervous system",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe the structure of nerve cells (neurones) and distinguish between sensory, relay, and motor neurones",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work",
                                },
                                {
                                    "objective": "Describe the structure and function of the spinal cord",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, model",
                                },
                                {
                                    "objective": "Explain the transmission of nerve impulses along neurones and across synapses",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Diagram work, animation",
                                },
                                {
                                    "objective": "Describe the reflex arc with examples (e.g. withdrawing hand from a hot object)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Explain conditioned reflexes and give examples",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Discuss common diseases of the nervous system (polio, meningitis, Parkinson's disease, multiple sclerosis)",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, case studies",
                                },
                            ],
                        },
                        {
                            "title": "Endocrine System",
                            "description": (
                                "Endocrine system and glands; factors modifying "
                                "growth and development."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the endocrine system and identify the major endocrine glands (pituitary, thyroid, adrenal, pancreas, ovaries, testes)",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Explain the roles of major hormones: insulin (pancreas), adrenaline (adrenal), thyroxine (thyroid), FSH, LH, oestrogen (ovaries), testosterone (testes)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                                {
                                    "objective": "Compare the nervous and endocrine systems (speed, duration, target, nature of signal)",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Comparison exercises",
                                },
                                {
                                    "objective": "Discuss factors that modify growth and development (nutrition, hormones, environment, genetics)",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Immunity",
                            "description": (
                                "Types of immunity; first line of defence; vaccination; "
                                "HIV and immunity; organ transplants."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Distinguish between natural and artificial immunity, and active and passive immunity",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, diagram work",
                                },
                                {
                                    "objective": "Describe the first line of defence in the body (skin, mucous membranes, stomach acid, tears)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Explain how vaccination provides immunity (role of antigens, antibodies, memory cells)",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, diagram work",
                                },
                                {
                                    "objective": "Discuss how HIV affects the immune system and its impact in Malawi",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, case studies, guest speaker",
                                },
                                {
                                    "objective": "Discuss the challenges and ethical issues of organ transplants (rejection, immunosuppression)",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, debate",
                                },
                            ],
                        },
                        {
                            "title": "Cancer",
                            "description": "Types of cancer; detection and treatment.",
                            "learning_objectives": [
                                {
                                    "objective": "Define cancer as uncontrolled cell division forming tumours (benign and malignant)",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Discussion, diagram work",
                                },
                                {
                                    "objective": "Identify risk factors for cancer (smoking, UV radiation, diet, genetic factors, viruses)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Describe methods of cancer detection (screening, biopsy, X-ray)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                                {
                                    "objective": "Describe methods of cancer treatment (surgery, chemotherapy, radiotherapy)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, video",
                                },
                            ],
                        },
                        {
                            "title": "Blood Groups and Transfusion",
                            "description": (
                                "ABO and rhesus blood groups; blood transfusion; "
                                "blood typing; Rhesus disease."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Explain the ABO blood group system (A, B, AB, O) and how blood groups are determined",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, Punnett squares",
                                },
                                {
                                    "objective": "Explain the Rhesus (Rh) blood group system and its significance",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe the principles of blood transfusion and why blood must be typed before transfusion",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, demonstration",
                                },
                                {
                                    "objective": "Perform blood typing using anti-A and anti-B sera",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical work",
                                },
                                {
                                    "objective": "Explain Rhesus disease and its effects on newborn babies",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                            ],
                        },
                        {
                            "title": "Common Infectious Diseases in Malawi",
                            "description": (
                                "Classification of communicable and non-communicable "
                                "diseases; description and control of major diseases "
                                "found in Malawi."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Classify diseases as communicable or non-communicable and give examples of each",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Discussion, sorting exercises",
                                },
                                {
                                    "objective": "Describe the cause, transmission, symptoms, and control of smallpox, tuberculosis, leprosy, and polio",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Describe the cause, transmission, symptoms, and control of syphilis and gonorrhoea",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Describe the cause, transmission, symptoms, and control of bilharzia (schistosomiasis), hookworm, and elephantiasis (lymphatic filariasis)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion, field studies",
                                },
                                {
                                    "objective": "Describe the cause, transmission, symptoms, and control of malaria (including the life cycle of Plasmodium)",
                                    "cognitive_level": "Comprehension/Analysis",
                                    "teaching_method": "Research, diagram work, discussion",
                                },
                                {
                                    "objective": "Describe the cause, transmission, symptoms, and control of cholera, dysentery, typhoid, and hepatitis",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Describe common eye diseases in Malawi (trachoma, conjunctivitis) and their prevention",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, research",
                                },
                                {
                                    "objective": "Describe sleeping sickness and rabies: causative organisms, vectors, symptoms, and control",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Brain model, eye model, reflex hammer",
                        "Hormone charts, endocrine system diagrams",
                        "Blood typing kits (anti-A, anti-B sera, slides)",
                        "Charts of common Malawian diseases, microscope",
                        "Microscope, prepared slides of pathogens",
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 6 — MICRO-ORGANISMS (Form 2)
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 6,
            "name": "Micro-organisms",
            "description": (
                "Groups, structure, growth and roles of micro-organisms (Form 2); "
                "structure, classification, beneficial and harmful roles "
                "of micro-organisms; their use in food, industry, and "
                "the spread of disease (Form 4)."
            ),
            "topics": [
                # ── Form 2 topic ─────────────────────────────────────────────
                {
                    "title": "Micro-organisms",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Groups, Structure, Growth and Roles of Micro-organisms",
                            "description": (
                                "Groups of micro-organisms (bacteria, viruses, fungi, "
                                "protozoa, algae); culturing micro-organisms; distribution "
                                "of micro-organisms in nature; structure of micro-organisms; "
                                "conditions for the growth of micro-organisms; role of "
                                "micro-organisms: parasites, decomposers, symbionts; "
                                "biotechnology; preservation and storage of food and "
                                "other substances."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Identify groups of micro-organisms: bacteria, viruses, fungi, protozoa, algae",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, slides",
                                },
                                {
                                    "objective": "Describe methods of culturing micro-organisms",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Practical demonstration",
                                },
                                {
                                    "objective": "Describe the distribution of micro-organisms in nature",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, field observation",
                                },
                                {
                                    "objective": "Describe the structure of different micro-organisms",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, microscopy",
                                },
                                {
                                    "objective": "Describe conditions necessary for the growth of micro-organisms",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Explain the roles of micro-organisms as parasites, decomposers, and symbionts",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Explain the role of micro-organisms in biotechnology",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Describe methods of preservation and storage of food and other substances",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, research",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Microscope, prepared slides of micro-organisms",
                        "Agar plates, Petri dishes",
                        "Charts, textbooks",
                    ],
                },
                # ── Form 2 topics ────────────────────────────────────────────
                {
                    "title": "Structure and Classification of Micro-organisms",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Bacteria, Viruses and Fungi",
                            "description": (
                                "Structure of bacteria, viruses, and fungi; "
                                "classification of micro-organisms."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure of bacteria (prokaryotic cell: cell wall, cell membrane, cytoplasm, nucleoid, flagella, pili)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Diagram work, slides",
                                },
                                {
                                    "objective": "Describe the structure of viruses (non-cellular: protein coat, nucleic acid core) and explain why they are not considered living",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe the structure of fungi (unicellular: yeast; multicellular: moulds and mushrooms)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Observation, slides",
                                },
                                {
                                    "objective": "Explain how micro-organisms are classified (bacteria, fungi, protoctists, viruses)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, sorting exercises",
                                },
                            ],
                        },
                        {
                            "title": "Beneficial and Harmful Micro-organisms",
                            "description": (
                                "Roles of micro-organisms in decomposition, "
                                "nitrogen fixation, fermentation, and disease."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe the beneficial roles of micro-organisms: decomposition, nitrogen fixation, sewage treatment",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, field study",
                                },
                                {
                                    "objective": "Explain the role of micro-organisms in fermentation (yogurt, bread, beer, traditional Malawian beverages)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, practical demonstration",
                                },
                                {
                                    "objective": "Describe how micro-organisms cause disease (pathogens, infection, toxins)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Explain Koch's postulates and their role in identifying the causative agents of disease",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, research",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Microscope, prepared slides of bacteria, yeast, mould",
                        "Agar plates, Petri dishes, inoculating loop",
                    ],
                },
                {
                    "title": "Micro-organisms in Food and Industry",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Fermentation, Food Preservation and Aseptic Technique",
                            "description": (
                                "Role of micro-organisms in food production; "
                                "food spoilage; methods of food preservation; "
                                "investigating microbial growth."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Explain the role of yeasts in bread-making and beer fermentation",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Practical, discussion",
                                },
                                {
                                    "objective": "Describe how Lactobacillus bacteria are used in making yogurt and other fermented foods",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, practical",
                                },
                                {
                                    "objective": "Describe how micro-organisms cause food spoilage",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, observation",
                                },
                                {
                                    "objective": "Discuss methods of food preservation: heating (pasteurisation, sterilisation), cooling, drying, canning, salting, sugaring, use of preservatives",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Discussion, research",
                                },
                                {
                                    "objective": "Investigate the growth of micro-organisms under different conditions (temperature, pH, moisture) using aseptic technique",
                                    "cognitive_level": "Application/Practical",
                                    "teaching_method": "Practical investigation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Agar plates, incubator, autoclave/pressure cooker",
                        "Food samples, preservatives, yeast, sugar",
                    ],
                },
                {
                    "title": "Micro-organisms and Disease",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Controlling the Spread of Infection",
                            "description": (
                                "Methods of controlling infection spread; "
                                "antibiotics and antibiotic resistance; "
                                "role of micro-organisms in sewage treatment "
                                "and the water cycle."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Discuss methods of controlling the spread of infection: hygiene, sterilisation, disinfection, quarantine",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Discussion, demonstrations",
                                },
                                {
                                    "objective": "Explain how antibiotics work to kill or inhibit the growth of bacteria",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, diagram work",
                                },
                                {
                                    "objective": "Discuss the problem of antibiotic resistance and its consequences for public health",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, debate",
                                },
                                {
                                    "objective": "Describe the role of micro-organisms in sewage treatment (anaerobic and aerobic digestion)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Explain the role of micro-organisms in the water cycle",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Antibiotic discs, agar plates (Kirby-Bauer test)",
                        "Microscopy equipment, prepared slides",
                        "Diagram of sewage treatment process",
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 7 — GENETICS AND EVOLUTION (Forms 3 & 4)
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 7,
            "name": "Genetics and Evolution",
            "description": (
                "Principles of Mendelian genetics, cell division, genes and "
                "DNA (Form 3); variations, mutations, natural selection, "
                "speciation, and biotechnology (Form 4)."
            ),
            "topics": [
                # ── Form 3 topics ────────────────────────────────────────────
                {
                    "title": "Principles of Mendelian Genetics",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Mendel's Experiments and Genotypes",
                            "description": (
                                "Monohybrid inheritance; traits in organisms; "
                                "Mendel's ideas; homozygous/heterozygous; "
                                "genotypes/phenotypes; predicting outcomes."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe Mendel's monohybrid inheritance experiments with pea plants",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, simulation",
                                },
                                {
                                    "objective": "Define key genetic terms: gene, allele, character, trait, dominant, recessive",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Note-taking, discussion",
                                },
                                {
                                    "objective": "Explain the terms homozygous, heterozygous, genotype, and phenotype",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Discussion, exercises",
                                },
                                {
                                    "objective": "Use Punnett squares to predict the outcomes of monohybrid crosses",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practice exercises",
                                },
                                {
                                    "objective": "Predict the genotypic and phenotypic ratios of offspring from genetic crosses",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practice exercises",
                                },
                            ],
                        },
                        {
                            "title": "Ratios and Patterns of Inheritance",
                            "description": (
                                "Sex determination; sex-linked inheritance; "
                                "genetic linkage; implications of Mendel's laws."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Explain sex determination in humans (XX/XY chromosome system)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Punnett squares, discussion",
                                },
                                {
                                    "objective": "Explain sex-linked inheritance using examples (colour blindness, haemophilia)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Pedigree chart analysis",
                                },
                                {
                                    "objective": "Describe the concept of genetic linkage and crossing over",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Discuss the implications of Mendel's laws of inheritance in agriculture and medicine",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case studies, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Cell Division",
                            "description": (
                                "Chromosomes; mitosis; meiosis; and their significance."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe chromosomes as carriers of genetic information and state the human chromosome number (46)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Diagram work, slides",
                                },
                                {
                                    "objective": "Explain the process of mitosis (prophase, metaphase, anaphase, telophase) and its significance in growth and repair",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, microscope slides",
                                },
                                {
                                    "objective": "Explain the process of meiosis and its significance in sexual reproduction and genetic variation",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, comparison",
                                },
                                {
                                    "objective": "Compare mitosis and meiosis (number of divisions, chromosome number, outcomes)",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Comparison exercises",
                                },
                            ],
                        },
                        {
                            "title": "Genes, DNA and Chromosomes",
                            "description": "DNA and chromosomes; genes and DNA.",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure of DNA as a double helix composed of nucleotides with complementary base pairing (A-T, C-G)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Model building, diagram work",
                                },
                                {
                                    "objective": "Explain how genes are segments of DNA that code for specific proteins",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, diagram work",
                                },
                                {
                                    "objective": "Describe how DNA is organised into chromosomes within the nucleus",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work",
                                },
                                {
                                    "objective": "Describe the process of protein synthesis: transcription (DNA → mRNA) and translation (mRNA → protein)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Punnett square worksheets, pedigree chart examples",
                        "Microscope, prepared slides of mitosis stages (onion root tip)",
                        "DNA model kit, chromosome charts",
                        "Genetic case studies, computer simulations",
                    ],
                },
                # ── Form 4 topics ─────────────────────────────────────────────
                {
                    "title": "Variations Among Organisms",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Variation and Its Causes",
                            "description": (
                                "Definition and causes of variation; individual, "
                                "same-sex, and sexual variations; continuous and "
                                "discontinuous variation; statistical terms (mean, "
                                "median, mode, variance, standard deviation); "
                                "organism-environment interactions."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Define variation as the differences between individuals of the same species",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "State the causes of variation: genetic (alleles, crossing over, independent assortment) and environmental",
                                    "cognitive_level": "Knowledge/Comprehension",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Identify types of variation: individual variation, variation between same sexes, variation between opposite sexes (sexual dimorphism)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Observation, data collection",
                                },
                                {
                                    "objective": "Distinguish between continuous variation (e.g. height, weight) and discontinuous variation (e.g. blood group, eye colour) with examples",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Data analysis, discussion",
                                },
                                {
                                    "objective": "Calculate statistical measures of variation: mean, median, mode, variance, and standard deviation",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Mathematical exercises",
                                },
                                {
                                    "objective": "Discuss how the interaction between organisms and their environment affects variation",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Measuring equipment (rulers, balances)",
                        "Calculation worksheets, graph paper",
                        "Charts showing variation in populations",
                    ],
                },
                {
                    "title": "Mutations",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Types and Effects of Mutations",
                            "description": (
                                "Definition and causes of mutations; gene, "
                                "chromosome, numerical, and structural mutations; "
                                "significance; non-disjunction; induced mutations."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Define mutation as a sudden, heritable change in genetic material",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "State the causes of mutations: radiation, chemicals, viruses, errors in DNA replication",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Describe gene mutations (changes in base sequence: substitution, insertion, deletion) and their effects",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe chromosome mutations (changes in chromosome structure: deletion, duplication, inversion, translocation)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work",
                                },
                                {
                                    "objective": "Describe numerical mutations (changes in chromosome number): aneuploidy, polyploidy, and non-disjunction",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Discuss the significance of mutations: harmful, beneficial, and neutral effects; role in evolution",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Discussion, case studies",
                                },
                                {
                                    "objective": "Explain how mutations can be induced (mutagens: UV, X-rays, chemicals) and discuss applications",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Diagram sets of chromosome mutations",
                        "Case studies (Down syndrome, sickle cell anaemia)",
                        "Research materials on mutagens",
                    ],
                },
                {
                    "title": "Natural Selection",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Evolutionary Theory and Evidence",
                            "description": (
                                "Theory of natural selection (Darwin and Wallace); "
                                "evidence for evolution; changes in populations; "
                                "artificial selection; survival of the fittest."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "State the theory of natural selection as proposed by Darwin and Wallace",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, historical account",
                                },
                                {
                                    "objective": "Explain the process of natural selection: variation, overproduction, competition, survival and reproduction of the fittest",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, simulation",
                                },
                                {
                                    "objective": "Provide evidence for evolution: fossils, comparative anatomy, biogeography, molecular biology",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Discuss how natural selection leads to changes in populations over time (adaptation, speciation)",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Case studies",
                                },
                                {
                                    "objective": "Explain artificial selection (selective breeding) and give examples in agriculture",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Discuss survival of the fittest in the context of Malawi's environment and biodiversity",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, field examples",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Fossil specimens/images, charts",
                        "Case studies of Darwin's finches, peppered moth",
                        "Field guides to Malawian wildlife",
                    ],
                },
                {
                    "title": "Speciation",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Formation of New Species",
                            "description": (
                                "Geographic and reproductive isolation; "
                                "isolation mechanisms; species concept."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Define a species as a group of organisms that can interbreed to produce fertile offspring",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                                {
                                    "objective": "Explain how geographic isolation leads to speciation (allopatric speciation)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, examples",
                                },
                                {
                                    "objective": "Explain how reproductive isolation leads to speciation (sympatric speciation)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Describe mechanisms that maintain species isolation: behavioural, temporal, mechanical, and gametic isolation",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, examples",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Diagram of geographic isolation scenarios",
                        "Case studies (Lake Malawi cichlids as an example of speciation)",
                    ],
                },
                {
                    "title": "Biotechnology",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Genetic Engineering and Applications",
                            "description": (
                                "Plant and animal breeding in Malawi; improvements; "
                                "recombinant DNA technology; insulin production; "
                                "genetic engineering applications; ethical implications."
                            ),
                            "learning_objectives": [
                                {
                                    "objective": "Describe plant and animal breeding programmes in Malawi and how they improve crop and livestock varieties",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Explain the principles of recombinant DNA technology and genetic engineering",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, discussion",
                                },
                                {
                                    "objective": "Describe how genetically engineered bacteria are used to produce human insulin for diabetes treatment",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Diagram work, case study",
                                },
                                {
                                    "objective": "Discuss applications of genetic engineering in agriculture (GM crops: Bt cotton, drought-resistant maize)",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, debate",
                                },
                                {
                                    "objective": "Discuss the ethical implications of genetic engineering and genetically modified organisms (GMOs)",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Debate, research",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        "Biotechnology case studies (GM crops in Malawi)",
                        "Diagram of recombinant DNA technology process",
                        "Debate materials, ethical scenario cards",
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
