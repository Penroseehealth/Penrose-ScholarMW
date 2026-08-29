"""Seed the official Malawi Agriculture syllabus (MoEST, Forms 1 to 4).

Covers the 5 core elements from the MoEST syllabus scope chart:
  1. Agriculture and the environment
  2. Agricultural research and technology
  3. Agricultural economics and farm business management
  4. Crop production
  5. Livestock production

Run from lifespan in main.py. Idempotent — skips if already seeded.
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

AGRICULTURE_SYLLABUS = {
    "subject": {
        "name": "Agriculture",
        "slug": "agriculture",
        "description": (
            "Malawi MSCE Agriculture Syllabus — MoEST Forms 1 to 4. "
            "Equips students with scientific, analytical, research, technological, "
            "entrepreneurial, critical thinking, vocational and managerial skills "
            "for sustainable crop and animal production, farm business management, "
            "value addition and efficient marketing."
        ),
        "icon": "agriculture_rounded",
        "color": "#22C55E",
    },
    "version": {
        "version_name": "MoEST Forms 1 to 4",
        "year_effective": 2018,
        "examination_board": "Malawi National Examinations Board (MANEB)",
        "description": (
            "Official Agriculture syllabus for Malawi School Certificate of Education "
            "(MSCE), covering Forms 1 to 4. Published by the Ministry of Education, "
            "Science and Technology through the Malawi Institute of Education (MIE)."
        ),
    },
    # ═══════════════════════════════════════════════════════════════════════════
    # CORE ELEMENT 1 — AGRICULTURE AND THE ENVIRONMENT
    # ═══════════════════════════════════════════════════════════════════════════
    "core_elements": [
        {
            "number": 1,
            "name": "Agriculture and the Environment",
            "description": (
                "Demonstrate awareness of environmental and climatic factors "
                "which influence agricultural production, how to modify them to "
                "reduce risks in order to maximize yield, and conserve them for "
                "sustainability."
            ),
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Natural Resources that Influence Agricultural Production",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Definition of Natural Resources",
                            "learning_objectives": [
                                {
                                    "objective": "Define natural resources and give examples relevant to agriculture",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                            ],
                        },
                        {
                            "title": "Importance of Natural Resources",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the importance of natural resources in agricultural production",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                            ],
                        },
                        {
                            "title": "Depletion of Natural Resources",
                            "learning_objectives": [
                                {
                                    "objective": "Describe causes and effects of depletion of natural resources",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, field observation",
                                },
                            ],
                        },
                        {
                            "title": "Conservation of Natural Resources",
                            "learning_objectives": [
                                {
                                    "objective": "Explain methods of conserving natural resources for sustainable agriculture",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, demonstrations",
                                },
                            ],
                        },
                        {
                            "title": "Environmental Factors Influencing Agricultural Production",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and explain environmental factors that affect agricultural production",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Effects of Rapid Population Growth on Natural Resources",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the effects of rapid population growth on natural resources and agriculture",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, data analysis",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Maps of Malawi showing natural resource zones",
                            "type": "reference",
                        },
                        {
                            "text": "Charts on population growth and land use",
                            "type": "reference",
                        },
                        {
                            "text": "Local environmental case studies",
                            "type": "reference",
                        },
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Soil Composition",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Components of soil",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the components of soil (minerals, organic matter, water, air)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Practical demonstration, soil sampling",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Soil samples from different locations",
                            "type": "equipment",
                        },
                        {"text": "Magnifying glasses", "type": "equipment"},
                    ],
                },
                {
                    "title": "Soil Profile",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Characteristics of Soil Profile",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the layers (horizons) of a soil profile and their characteristics",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Field study, soil pit excavation",
                                },
                                {
                                    "objective": "Draw and label a diagram of a soil profile",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Drawing exercise",
                                },
                            ],
                        },
                        {
                            "title": "Effects of Soil Profile on Crop Production",
                            "learning_objectives": [
                                {
                                    "objective": "Explain how different soil profile layers affect crop growth and production",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, field observation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Soil profile diagrams", "type": "reference"},
                        {
                            "text": "Spades and soil augers for pit excavation",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Soil Fertility",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Maintenance of Soil Fertility",
                            "learning_objectives": [
                                {
                                    "objective": "Describe methods of maintaining soil fertility for sustained crop production",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, farm visit",
                                },
                                {
                                    "objective": "Explain the role of crop rotation, fallowing and green manuring in maintaining soil fertility",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Classification of Fertilizers",
                            "learning_objectives": [
                                {
                                    "objective": "Classify fertilizers into organic and inorganic types",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, practical demonstration",
                                },
                            ],
                        },
                        {
                            "title": "Advantages and Disadvantages of Organic and Inorganic Fertilizers",
                            "learning_objectives": [
                                {
                                    "objective": "Compare the advantages and disadvantages of organic and inorganic fertilizers",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, comparison charts",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Samples of organic and inorganic fertilizers",
                            "type": "equipment",
                        },
                        {"text": "Soil testing kits", "type": "equipment"},
                        {
                            "text": "Charts on fertilizer types and uses",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Agriculture and Climate Change",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Causes of Climate Change",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the causes of climate change and their impact on agriculture",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion, video",
                                },
                            ],
                        },
                        {
                            "title": "Effects of Climate Change on Agriculture",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the effects of climate change on agricultural production in Malawi",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Case studies, discussion",
                                },
                                {
                                    "objective": "Suggest adaptation and mitigation strategies for farmers",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Group work, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Climate data charts for Malawi", "type": "reference"},
                        {
                            "text": "Case studies on drought and flooding impacts",
                            "type": "reference",
                        },
                        {
                            "text": "Computers for climate data research",
                            "type": "digital",
                        },
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Physical Properties of Soil",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Soil Structure",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the different types of soil structure (granular, blocky, platy, prismatic) and their effects on crop growth",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Practical examination of soil samples, discussion",
                                },
                                {
                                    "objective": "Analyze the relationship between soil structure and water infiltration",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Experiment, data analysis",
                                },
                            ],
                        },
                        {
                            "title": "Soil Texture",
                            "learning_objectives": [
                                {
                                    "objective": "Classify soils by texture using the feel method and the soil textural triangle",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical, laboratory work",
                                },
                                {
                                    "objective": "Evaluate the suitability of different soil textures for various crops",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Group discussion, case studies",
                                },
                            ],
                        },
                        {
                            "title": "Soil Porosity and Density",
                            "learning_objectives": [
                                {
                                    "objective": "Define and measure soil porosity and bulk density",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Laboratory experiment",
                                },
                                {
                                    "objective": "Explain how porosity and density affect root penetration and water movement",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Demonstration, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Water-Holding Capacity of Soil",
                            "learning_objectives": [
                                {
                                    "objective": "Conduct experiments to compare the water-holding capacity of different soil types",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical experiment",
                                },
                                {
                                    "objective": "Discuss the implications of water-holding capacity for irrigation scheduling",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, brainstorming",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Soil samples of varying textures",
                            "type": "equipment",
                        },
                        {"text": "Soil textural triangle charts", "type": "reference"},
                        {
                            "text": "Measuring cylinders and funnels for porosity experiments",
                            "type": "equipment",
                        },
                        {
                            "text": "Balance for bulk density measurement",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Chemical Properties of Soil",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Cation Exchange Capacity",
                            "learning_objectives": [
                                {
                                    "objective": "Define cation exchange capacity (CEC) and explain its significance in soil fertility",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                                {
                                    "objective": "Relate CEC values to fertilizer recommendation for different soil types",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Case studies, guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Nutrient Status of Soil",
                            "learning_objectives": [
                                {
                                    "objective": "Conduct soil nutrient tests using simple kits and interpret the results",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Laboratory practical",
                                },
                                {
                                    "objective": "Analyze the relationship between nutrient status and crop yield potential",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Data analysis, group work",
                                },
                            ],
                        },
                        {
                            "title": "Soil pH",
                            "learning_objectives": [
                                {
                                    "objective": "Measure soil pH using different methods and classify soils as acidic, neutral or alkaline",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical demonstration, laboratory work",
                                },
                                {
                                    "objective": "Explain the effects of soil pH on nutrient availability and crop production",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, chart analysis",
                                },
                            ],
                        },
                        {
                            "title": "Soil Salinity",
                            "learning_objectives": [
                                {
                                    "objective": "Define soil salinity and describe its causes in agricultural areas",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, field visit",
                                },
                                {
                                    "objective": "Evaluate the effects of soil salinity on crop production and suggest remedial measures",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case study analysis, debate",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Soil pH testing kits", "type": "equipment"},
                        {"text": "Soil nutrient testing kits", "type": "equipment"},
                        {
                            "text": "Charts showing nutrient availability at different pH levels",
                            "type": "reference",
                        },
                        {"text": "Textbook of soil chemistry", "type": "textbook"},
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Soil Degradation",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Types and Causes of Soil Degradation",
                            "learning_objectives": [
                                {
                                    "objective": "Classify soil degradation into physical, chemical and biological types and identify their causes",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Research, presentation",
                                },
                                {
                                    "objective": "Assess the severity of different forms of soil degradation in Malawi",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Field investigation, group analysis",
                                },
                            ],
                        },
                        {
                            "title": "Effects of Soil Degradation on Agricultural Production",
                            "learning_objectives": [
                                {
                                    "objective": "Evaluate the economic and environmental effects of soil degradation on farming communities",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case studies, debate",
                                },
                                {
                                    "objective": "Analyze data on crop yield decline attributable to soil degradation",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Data analysis, group work",
                                },
                            ],
                        },
                        {
                            "title": "Conservation Measures Against Soil Degradation",
                            "learning_objectives": [
                                {
                                    "objective": "Propose integrated soil conservation strategies for different farming systems",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Group project, brainstorming",
                                },
                                {
                                    "objective": "Design a soil conservation plan for a local farming community",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, field planning",
                                },
                            ],
                        },
                        {
                            "title": "Re-afforestation and Integrated Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the role of re-afforestation in preventing soil degradation",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Field visit, research",
                                },
                                {
                                    "objective": "Synthesize the principles of integrated forest-crop-livestock-fish systems for sustainable land use",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Group work, case study analysis",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Soil degradation photographs from Malawi",
                            "type": "reference",
                        },
                        {"text": "Textbook of soil science", "type": "textbook"},
                        {
                            "text": "Computers for research and presentations",
                            "type": "ict",
                        },
                        {
                            "text": "Local degraded land for field investigation",
                            "type": "field trip",
                        },
                    ],
                },
                {
                    "title": "Climate Change Mitigation and Land Drainage",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Climate Change Mitigation in Agriculture",
                            "learning_objectives": [
                                {
                                    "objective": "Evaluate various climate change mitigation strategies applicable to agricultural systems in Malawi",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, debate, presentation",
                                },
                                {
                                    "objective": "Design a farm-level climate change mitigation plan using integrated approaches",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, group planning",
                                },
                            ],
                        },
                        {
                            "title": "Importance of Land Drainage",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze the importance of land drainage for crop production in waterlogged areas",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Field visit, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Methods of Land Drainage",
                            "learning_objectives": [
                                {
                                    "objective": "Describe and compare open drain, tile drain and mole drain systems",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Demonstration, field study",
                                },
                                {
                                    "objective": "Evaluate the suitability of different drainage methods for local farming conditions",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case study, group discussion",
                                },
                            ],
                        },
                        {
                            "title": "Biodrainage",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the concept of biodrainage and its role in managing waterlogged farmland",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, research",
                                },
                                {
                                    "objective": "Synthesize a biodrainage plan incorporating appropriate tree species for local conditions",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, field planning",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Climate change mitigation charts",
                            "type": "reference",
                        },
                        {
                            "text": "Drainage system diagrams and models",
                            "type": "reference",
                        },
                        {
                            "text": "Local waterlogged farmland for field study",
                            "type": "field trip",
                        },
                        {"text": "ICT resources for climate research", "type": "ict"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 2 — AGRICULTURAL RESEARCH AND TECHNOLOGY
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 2,
            "name": "Agricultural Research and Technology",
            "description": (
                "Apply research skills and improved agricultural technology "
                "to increase farm productivity."
            ),
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Agricultural Research",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Agricultural Problems Requiring Research",
                            "learning_objectives": [
                                {
                                    "objective": "Identify agricultural problems that require research investigation",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, problem identification",
                                },
                            ],
                        },
                        {
                            "title": "Scientific Approach to Agricultural Research",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the steps of the scientific method applied to agricultural research",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstration",
                                },
                                {
                                    "objective": "Formulate a hypothesis for a given agricultural problem",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Research methodology handouts", "type": "reference"},
                        {
                            "text": "Notebooks for recording observations",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Meaning and Importance of Agricultural Technology",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Meaning of Agricultural Technology",
                            "learning_objectives": [
                                {
                                    "objective": "Define agricultural technology and give examples",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Importance of Agricultural Technology",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the importance of agricultural technology in improving farm productivity",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Pictures and videos of agricultural technologies",
                            "type": "digital",
                        },
                        {
                            "text": "Examples of improved farm tools",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Farm Structures",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Types of Farm Structures",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and describe different types of farm structures and their uses",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, farm visit",
                                },
                            ],
                        },
                        {
                            "title": "Safety Rules for Utilizing Farm Structures",
                            "learning_objectives": [
                                {
                                    "objective": "State and explain safety rules to observe when using farm structures",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Farm structures diagrams", "type": "reference"},
                        {"text": "Safety equipment samples", "type": "equipment"},
                    ],
                },
                {
                    "title": "Irrigation",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Importance of Irrigation",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the importance of irrigation in agricultural production",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Types of Irrigation Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and describe different types of irrigation systems",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, diagrams, farm visit",
                                },
                            ],
                        },
                        {
                            "title": "Advantages and Limitations of Each Irrigation System",
                            "learning_objectives": [
                                {
                                    "objective": "Compare the advantages and limitations of different irrigation systems",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, comparison charts",
                                },
                            ],
                        },
                        {
                            "title": "Factors Affecting Frequency and Time of Irrigation",
                            "learning_objectives": [
                                {
                                    "objective": "Identify factors that determine how often and when to irrigate crops",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, practical observation",
                                },
                            ],
                        },
                        {
                            "title": "Factors to Consider When Selecting an Irrigation Unit",
                            "learning_objectives": [
                                {
                                    "objective": "List and explain factors to consider when choosing an irrigation system",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, case studies",
                                },
                            ],
                        },
                        {
                            "title": "Procedure for Establishing an Irrigation Unit",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the step-by-step procedure for setting up an irrigation unit",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, practical work",
                                },
                            ],
                        },
                        {
                            "title": "Maintenance of Irrigation Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Explain routine maintenance procedures for irrigation systems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, practical work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Drip irrigation kit for demonstration",
                            "type": "equipment",
                        },
                        {"text": "Sprinkler system components", "type": "equipment"},
                        {
                            "text": "Water measuring tools (flow meters)",
                            "type": "equipment",
                        },
                        {"text": "Furrow irrigation diagrams", "type": "reference"},
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Advanced Agricultural Technology",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Types of Farm Structures",
                            "learning_objectives": [
                                {
                                    "objective": "Describe advanced types of farm structures including stores, pens, and greenhouses",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, farm visit",
                                },
                            ],
                        },
                        {
                            "title": "Safety Rules for Utilizing Farm Structures",
                            "learning_objectives": [
                                {
                                    "objective": "Apply safety rules when using advanced farm structures and equipment",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, role play",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Greenhouse model or photographs",
                            "type": "reference",
                        },
                        {
                            "text": "Safety gear samples (gloves, goggles)",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Advanced Agricultural Research",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Experimental Designs",
                            "learning_objectives": [
                                {
                                    "objective": "Describe different experimental designs used in agricultural research",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Laying Out Experiments",
                            "learning_objectives": [
                                {
                                    "objective": "Demonstrate how to lay out a simple field experiment",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical field work",
                                },
                            ],
                        },
                        {
                            "title": "Conducting an Agricultural Research",
                            "learning_objectives": [
                                {
                                    "objective": "Plan and conduct a simple agricultural research project",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical project work",
                                },
                            ],
                        },
                        {
                            "title": "Importance of Report Writing",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the importance of writing reports after conducting agricultural research",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Format for Report Writing",
                            "learning_objectives": [
                                {
                                    "objective": "Write a simple agricultural research report following the correct format",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice, templates",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Measuring tapes and stakes for field layout",
                            "type": "equipment",
                        },
                        {"text": "Report writing templates", "type": "reference"},
                        {"text": "Graph paper for plot layouts", "type": "equipment"},
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Agricultural Development Agencies and Services",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Agricultural Development Agencies in Malawi",
                            "learning_objectives": [
                                {
                                    "objective": "Identify major agricultural development agencies operating in Malawi (DAAS, FISP, extension services)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Research, guest speaker",
                                },
                                {
                                    "objective": "Describe the mandates and structures of key agricultural agencies",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, ICT research",
                                },
                            ],
                        },
                        {
                            "title": "Services Offered by Agricultural Agencies",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze the range of services provided by agricultural agencies including extension, credit and market information",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Group work, research presentation",
                                },
                                {
                                    "objective": "Evaluate the effectiveness of extension services in reaching smallholder farmers",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Field interview, case study",
                                },
                            ],
                        },
                        {
                            "title": "Importance to Growing Population",
                            "learning_objectives": [
                                {
                                    "objective": "Assess how agricultural agencies contribute to food security for Malawi's growing population",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Debate, data analysis",
                                },
                                {
                                    "objective": "Synthesize recommendations for improving the impact of agricultural agencies",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Group project, brainstorming",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Profiles of Malawian agricultural agencies",
                            "type": "reference",
                        },
                        {"text": "ICT resources for agency research", "type": "ict"},
                        {
                            "text": "Extension officer as resource person",
                            "type": "resource person",
                        },
                        {"text": "Agricultural policy documents", "type": "textbook"},
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Farm Mechanisation",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Types of Farm Machinery",
                            "learning_objectives": [
                                {
                                    "objective": "Classify farm machinery into tillage, planting, harvesting and processing categories",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "ICT research, demonstration",
                                },
                                {
                                    "objective": "Describe the functions and operating principles of key farm machines",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Farm visit, practical demonstration",
                                },
                            ],
                        },
                        {
                            "title": "Factors to Consider When Selecting Farm Machinery",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze factors including farm size, crop type, terrain and budget when selecting machinery",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Case study, group discussion",
                                },
                                {
                                    "objective": "Evaluate the cost-benefit of mechanization for different scales of farming",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Calculations, debate",
                                },
                            ],
                        },
                        {
                            "title": "Advantages and Limitations of Farm Mechanisation",
                            "learning_objectives": [
                                {
                                    "objective": "Compare the advantages and limitations of mechanization in the context of Malawian agriculture",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Debate, group presentation",
                                },
                            ],
                        },
                        {
                            "title": "Maintenance of Farm Machinery",
                            "learning_objectives": [
                                {
                                    "objective": "Apply preventive and corrective maintenance procedures for common farm machines",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical workshop, demonstration",
                                },
                                {
                                    "objective": "Prepare a maintenance schedule for a piece of farm equipment",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercise",
                                },
                            ],
                        },
                        {
                            "title": "Safety Measures When Using Farm Machinery",
                            "learning_objectives": [
                                {
                                    "objective": "Synthesize a comprehensive safety protocol for operating farm machinery",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Group project, demonstration",
                                },
                                {
                                    "objective": "Evaluate the causes of farm machinery accidents and propose prevention strategies",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case study analysis, presentation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Farm machinery catalogues and manuals",
                            "type": "textbook",
                        },
                        {
                            "text": "Farm machinery for demonstration",
                            "type": "equipment",
                        },
                        {"text": "ICT resources for machinery research", "type": "ict"},
                        {
                            "text": "Local farm workshop for field visit",
                            "type": "field trip",
                        },
                    ],
                },
                {
                    "title": "Farm Power",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Sources of Power on a Farm",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and classify sources of farm power (human, animal, mechanical, electrical, solar)",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Research, brainstorming",
                                },
                                {
                                    "objective": "Describe the characteristics and applications of each power source",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion, farm visit",
                                },
                            ],
                        },
                        {
                            "title": "Ways of Improving Output of Each Power Source",
                            "learning_objectives": [
                                {
                                    "objective": "Evaluate methods to improve the efficiency and output of different farm power sources",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Group work, case study analysis",
                                },
                                {
                                    "objective": "Synthesize an integrated farm power plan combining multiple sources for optimal productivity",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, group planning",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts on farm power sources", "type": "reference"},
                        {
                            "text": "Draft animals and equipment for demonstration",
                            "type": "equipment",
                        },
                        {"text": "Solar panel model", "type": "equipment"},
                        {"text": "ICT resources for research", "type": "ict"},
                    ],
                },
                {
                    "title": "Agricultural Technology and Gender",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Role of Gender in Agricultural Technology Adoption",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze how gender norms and roles affect the adoption of agricultural technologies",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Research, discussion, field interviews",
                                },
                                {
                                    "objective": "Evaluate gender-responsive approaches to agricultural technology dissemination",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case studies, debate",
                                },
                                {
                                    "objective": "Synthesize strategies to promote equitable access to agricultural technology for both men and women",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Group project, brainstorming",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Gender analysis frameworks", "type": "reference"},
                        {
                            "text": "Case studies on gender and technology in Malawi",
                            "type": "textbook",
                        },
                        {
                            "text": "Community resource persons for interviews",
                            "type": "resource person",
                        },
                        {"text": "ICT resources for research", "type": "ict"},
                    ],
                },
                {
                    "title": "Improved Farming Technology and Food Security",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "How Improved Farming Technology Affects Food Security",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze the impact of improved seeds, fertilizers and farming techniques on food production",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Data analysis, discussion",
                                },
                                {
                                    "objective": "Evaluate the role of improved farming technology in achieving household and national food security",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case studies, debate",
                                },
                                {
                                    "objective": "Synthesize recommendations for integrating technology to maximize food security outcomes",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Group project, presentation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Food security statistics and charts",
                            "type": "reference",
                        },
                        {"text": "ICT resources for data research", "type": "ict"},
                        {
                            "text": "Agricultural extension officer as resource person",
                            "type": "resource person",
                        },
                        {"text": "Local farmer testimonials", "type": "reference"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 3 — AGRICULTURAL ECONOMICS AND FARM BUSINESS MANAGEMENT
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 3,
            "name": "Agricultural Economics and Farm Business Management",
            "description": (
                "Appreciate how concepts and principles of agricultural economics "
                "and farm business management increase profitability of agricultural "
                "enterprises."
            ),
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Farm Business Management Concepts",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Factors of Agricultural Production",
                            "description": "Main and other factors of agricultural production and solutions to associated challenges.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the main factors of agricultural production (land, labour, capital, management)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion",
                                },
                                {
                                    "objective": "Identify other factors that influence agricultural production",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Propose solutions to challenges associated with factors of agricultural production",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Group work, problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Charts on factors of production",
                            "type": "reference",
                        },
                        {
                            "text": "Case study materials on Malawian farms",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Agricultural Marketing",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Marketing Forces",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the forces that influence agricultural marketing (supply, demand, price)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Marketing Functions",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the functions of marketing in agriculture (transport, storage, processing)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, market visit",
                                },
                            ],
                        },
                        {
                            "title": "Problems and Solutions in Marketing Agricultural Products",
                            "learning_objectives": [
                                {
                                    "objective": "Identify problems associated with marketing agricultural products in Malawi",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, interviews",
                                },
                                {
                                    "objective": "Suggest possible solutions to agricultural marketing problems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Group work, brainstorming",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Local market photographs", "type": "reference"},
                        {
                            "text": "Price lists from agricultural markets",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Agro-based Industries",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Agro-based Industries in Malawi",
                            "learning_objectives": [
                                {
                                    "objective": "Identify major agro-based industries operating in Malawi",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, videos, field trip",
                                },
                            ],
                        },
                        {
                            "title": "Role of Agro-based Industries in Supporting the Growing Population",
                            "learning_objectives": [
                                {
                                    "objective": "Explain how agro-based industries support food security and employment in Malawi",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Videos of agro-processing in Malawi",
                            "type": "digital",
                        },
                        {
                            "text": "Product samples from local agro-industries",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Food Distribution",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Food Security and Food for Self-sufficiency",
                            "learning_objectives": [
                                {
                                    "objective": "Define food security and food self-sufficiency and explain their importance",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Relationship Between Family Size and Food Security",
                            "learning_objectives": [
                                {
                                    "objective": "Explain how family size affects food security at household level",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, data analysis",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Household food security survey data",
                            "type": "reference",
                        },
                        {
                            "text": "Charts on population and food production",
                            "type": "reference",
                        },
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Gender and Agricultural Production",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Gender Roles in Agricultural Production",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the different roles played by men and women in agricultural production",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, interviews",
                                },
                            ],
                        },
                        {
                            "title": "Impact of Gender Roles in Agricultural Production",
                            "learning_objectives": [
                                {
                                    "objective": "Analyse the impact of gender roles on agricultural productivity",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, case studies",
                                },
                            ],
                        },
                        {
                            "title": "Gender Equity in Agricultural Production",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the importance of gender equity in achieving agricultural development",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, group discussion",
                                },
                            ],
                        },
                        {
                            "title": "Role of Women in Decision Making in Agricultural Production",
                            "learning_objectives": [
                                {
                                    "objective": "Discuss the role of women in agricultural decision-making at household and community level",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, role play",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Gender analysis frameworks", "type": "reference"},
                        {
                            "text": "Case studies on women farmers in Malawi",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Farming Systems",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Types of Farming Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and describe different types of farming systems (subsistence, commercial, mixed)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, farm visit",
                                },
                            ],
                        },
                        {
                            "title": "Importance of Farming Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the importance of farming systems in ensuring food security and income",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, comparison",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Farm visit arrangements", "type": "equipment"},
                        {
                            "text": "Photographs of different farming systems",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Financing Agricultural Enterprises",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Sources of Finance",
                            "learning_objectives": [
                                {
                                    "objective": "Identify different sources of finance for agricultural enterprises (loans, savings, grants)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, guest speaker",
                                },
                            ],
                        },
                        {
                            "title": "Calculating Interest on Borrowed Money",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate simple and compound interest on money borrowed for agricultural enterprises",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises, calculations",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Loan application forms from local banks",
                            "type": "reference",
                        },
                        {"text": "Calculators", "type": "equipment"},
                        {"text": "Interest rate charts", "type": "reference"},
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Farm Records",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Types of Farm Records",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and describe different types of farm records (production, financial, inventory, labour)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, samples of real records",
                                },
                                {
                                    "objective": "Classify farm records by their purpose and frequency of use",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Group work, sorting exercise",
                                },
                            ],
                        },
                        {
                            "title": "Importance of Farm Records",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze the importance of keeping accurate farm records for decision-making",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Case study, discussion",
                                },
                                {
                                    "objective": "Evaluate the consequences of poor record-keeping on farm profitability",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Debate, case study analysis",
                                },
                            ],
                        },
                        {
                            "title": "Preparation of Farm Records",
                            "learning_objectives": [
                                {
                                    "objective": "Apply correct procedures for preparing different types of farm records",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercise, templates",
                                },
                                {
                                    "objective": "Design a simple record-keeping system for a smallholder farm",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, group planning",
                                },
                            ],
                        },
                        {
                            "title": "Storage and Retrieval of Farm Records",
                            "learning_objectives": [
                                {
                                    "objective": "Explain proper methods of storing and organizing farm records for easy retrieval",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical demonstration, group work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Sample farm record books and ledger sheets",
                            "type": "equipment",
                        },
                        {"text": "Textbook of farm management", "type": "textbook"},
                        {"text": "Blank recording templates", "type": "equipment"},
                        {
                            "text": "Local farmer as resource person",
                            "type": "resource person",
                        },
                    ],
                },
                {
                    "title": "Farm Budgets",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Types of Farm Budgets",
                            "learning_objectives": [
                                {
                                    "objective": "Distinguish between enterprise budgets, whole-farm budgets and cash flow budgets",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Lecture, discussion, samples",
                                },
                                {
                                    "objective": "Classify budget components into fixed and variable costs",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Group work, classification exercise",
                                },
                            ],
                        },
                        {
                            "title": "Preparation of Farm Budgets",
                            "learning_objectives": [
                                {
                                    "objective": "Apply step-by-step procedures to prepare a simple enterprise budget",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercise, calculations",
                                },
                                {
                                    "objective": "Prepare a whole-farm budget integrating multiple enterprises",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical project work",
                                },
                            ],
                        },
                        {
                            "title": "Importance of Farm Budgets in Farm Planning",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze how farm budgets guide resource allocation and investment decisions",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Case study, discussion",
                                },
                                {
                                    "objective": "Evaluate the role of budgeting in determining farm profitability",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Debate, financial analysis",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Farm budget templates and worksheets",
                            "type": "equipment",
                        },
                        {
                            "text": "Textbook of agricultural economics",
                            "type": "textbook",
                        },
                        {"text": "Calculators", "type": "equipment"},
                        {
                            "text": "Sample farm budgets from local farms",
                            "type": "reference",
                        },
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Agricultural Marketing and Trading",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Marketing Channels",
                            "learning_objectives": [
                                {
                                    "objective": "Map different marketing channels for agricultural commodities from farm to consumer",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Field study, group mapping exercise",
                                },
                                {
                                    "objective": "Evaluate the efficiency of various marketing channels for smallholder farmers in Malawi",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case study, debate",
                                },
                            ],
                        },
                        {
                            "title": "Factors Affecting Agricultural Marketing",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze physical, economic and institutional factors affecting agricultural marketing",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Research, discussion",
                                },
                                {
                                    "objective": "Assess the impact of post-harvest losses on marketing efficiency",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Field survey, data analysis",
                                },
                            ],
                        },
                        {
                            "title": "Trading Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Describe different agricultural trading systems (spot, forward, futures, contract farming)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, case studies",
                                },
                                {
                                    "objective": "Synthesize a marketing strategy for a specific agricultural commodity considering local trading systems",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, group planning",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Local market for field study", "type": "field trip"},
                        {"text": "Marketing channel diagrams", "type": "reference"},
                        {"text": "ICT resources for market research", "type": "ict"},
                        {
                            "text": "Local trader as resource person",
                            "type": "resource person",
                        },
                    ],
                },
                {
                    "title": "Price Elasticity of Demand and Supply",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Concepts of Price Elasticity",
                            "learning_objectives": [
                                {
                                    "objective": "Define and calculate price elasticity of demand and supply for agricultural commodities",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Lecture, calculations, group work",
                                },
                                {
                                    "objective": "Interpret elasticity values and classify goods as elastic, inelastic or unit elastic",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Data analysis, chart work",
                                },
                            ],
                        },
                        {
                            "title": "Implications for Agricultural Commodities",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze how price elasticity affects farmer income and pricing decisions",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Case studies, discussion",
                                },
                                {
                                    "objective": "Evaluate the implications of inelastic demand for food crop marketing strategies",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Debate, group presentation",
                                },
                                {
                                    "objective": "Synthesize policy recommendations to stabilize agricultural commodity prices based on elasticity analysis",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Research, policy analysis, presentation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Textbook of agricultural economics",
                            "type": "textbook",
                        },
                        {
                            "text": "Price data for Malawian agricultural commodities",
                            "type": "reference",
                        },
                        {"text": "Calculators", "type": "equipment"},
                        {"text": "ICT resources for data research", "type": "ict"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 4 — CROP PRODUCTION
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 4,
            "name": "Crop Production",
            "description": (
                "Use scientific knowledge and skills of growing crops using "
                "recommended husbandry practices."
            ),
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Plant Nutrients",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Essential Plant Nutrients",
                            "learning_objectives": [
                                {
                                    "objective": "List the essential plant nutrients required for crop growth",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, demonstration",
                                },
                            ],
                        },
                        {
                            "title": "Classes of Essential Plant Nutrients",
                            "learning_objectives": [
                                {
                                    "objective": "Classify plant nutrients into macro and micro nutrients",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, chart analysis",
                                },
                            ],
                        },
                        {
                            "title": "Role of Essential Plant Nutrients",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the role of each essential plant nutrient in crop growth",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Depletion of Essential Plant Nutrients from the Soil",
                            "learning_objectives": [
                                {
                                    "objective": "Explain how soil nutrients are depleted through cropping and other activities",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, field observation",
                                },
                            ],
                        },
                        {
                            "title": "Deficiency Signs of Essential Plant Nutrients",
                            "learning_objectives": [
                                {
                                    "objective": "Identify visual deficiency signs of major plant nutrients in crops",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Practical observation, photographs",
                                },
                            ],
                        },
                        {
                            "title": "Sources of Essential Plant Nutrients",
                            "learning_objectives": [
                                {
                                    "objective": "Identify natural and artificial sources of plant nutrients",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Soil nutrient deficiency chart", "type": "reference"},
                        {"text": "Fertilizer samples", "type": "equipment"},
                        {
                            "text": "Plant samples showing deficiency symptoms",
                            "type": "equipment",
                        },
                        {"text": "Soil testing kits", "type": "equipment"},
                    ],
                },
                {
                    "title": "Vegetable Production",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Importance of Vegetables",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the nutritional, economic and social importance of vegetables",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, demonstration",
                                },
                            ],
                        },
                        {
                            "title": "Types of Vegetables",
                            "learning_objectives": [
                                {
                                    "objective": "Identify different types of vegetables grown in Malawi",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, garden visit",
                                },
                            ],
                        },
                        {
                            "title": "Advantages of Indigenous Vegetables",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the advantages of growing indigenous vegetables over exotic varieties",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, comparison",
                                },
                            ],
                        },
                        {
                            "title": "Site Selection for Vegetable Growing",
                            "learning_objectives": [
                                {
                                    "objective": "Describe factors to consider when selecting a site for a vegetable garden",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Field study, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Construction of Garden Fence",
                            "learning_objectives": [
                                {
                                    "objective": "Demonstrate how to construct a simple garden fence to protect vegetables",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical construction",
                                },
                            ],
                        },
                        {
                            "title": "Husbandry Practices in Vegetable Growing",
                            "learning_objectives": [
                                {
                                    "objective": "Describe and practise key husbandry practices in vegetable production (planting, watering, weeding, pest control, harvesting)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical garden work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Vegetable seeds (indigenous and exotic)",
                            "type": "equipment",
                        },
                        {
                            "text": "Garden tools (hoes, watering cans, rakes)",
                            "type": "equipment",
                        },
                        {
                            "text": "Fencing materials (sticks, wire)",
                            "type": "equipment",
                        },
                        {"text": "Compost manure", "type": "equipment"},
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Maize Production",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Qualities of Good Maize Seed",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the qualities of good maize seed for planting",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, seed inspection",
                                },
                            ],
                        },
                        {
                            "title": "Husbandry Practices in Maize Production",
                            "learning_objectives": [
                                {
                                    "objective": "Describe recommended husbandry practices for maize production (land preparation, planting, spacing, weeding, pest management, harvesting)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical demonstration, farm visit",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Maize seed varieties (local and improved)",
                            "type": "equipment",
                        },
                        {"text": "Measuring tape for spacing", "type": "equipment"},
                        {
                            "text": "Knapsack sprayer for pest control",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Groundnuts Production",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Qualities of Good Groundnut Seed",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the qualities of good groundnut seed for planting",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, seed inspection",
                                },
                            ],
                        },
                        {
                            "title": "Husbandry Practices in Groundnuts Production",
                            "learning_objectives": [
                                {
                                    "objective": "Describe recommended husbandry practices for groundnuts production (land preparation, planting, spacing, weeding, pest management, harvesting)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical demonstration, farm visit",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Groundnut seed varieties", "type": "equipment"},
                        {"text": "Measuring tools for spacing", "type": "equipment"},
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Vegetative Planting Materials",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Types of Vegetative Propagation",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and describe different types of vegetative propagation (cuttings, grafting, layering, division, budding)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Practical demonstration, field visit",
                                },
                                {
                                    "objective": "Analyze the advantages of vegetative propagation over seed propagation",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, comparison charts",
                                },
                            ],
                        },
                        {
                            "title": "Methods and Procedures of Vegetative Propagation",
                            "learning_objectives": [
                                {
                                    "objective": "Apply correct procedures for preparing and planting vegetative materials (cuttings, grafts, slips)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical nursery work",
                                },
                                {
                                    "objective": "Evaluate the suitability of different vegetative methods for various crop species",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Group discussion, case study",
                                },
                            ],
                        },
                        {
                            "title": "Advantages of Vegetative Planting Materials",
                            "learning_objectives": [
                                {
                                    "objective": "Assess the genetic and agronomic advantages of using vegetative planting materials",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, presentation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Cuttings, scions and rootstocks for practical",
                            "type": "equipment",
                        },
                        {"text": "Grafting and budding knives", "type": "equipment"},
                        {"text": "Nursery beds and potting media", "type": "equipment"},
                        {"text": "Textbook of crop propagation", "type": "textbook"},
                    ],
                },
                {
                    "title": "Cropping Systems",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Intercropping",
                            "learning_objectives": [
                                {
                                    "objective": "Describe intercropping and its principles of compatible crop combination",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, field observation",
                                },
                                {
                                    "objective": "Analyze the advantages and disadvantages of intercropping systems",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Group work, comparison",
                                },
                            ],
                        },
                        {
                            "title": "Relay Cropping",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the concept and benefits of relay cropping in the Malawian farming calendar",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, field visit",
                                },
                            ],
                        },
                        {
                            "title": "Mixed Cropping",
                            "learning_objectives": [
                                {
                                    "objective": "Distinguish between mixed cropping and intercropping and describe their applications",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, field comparison",
                                },
                                {
                                    "objective": "Evaluate the suitability of different cropping systems for various agro-ecological zones in Malawi",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Group research, presentation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Cropping system diagrams and charts",
                            "type": "reference",
                        },
                        {
                            "text": "School farm plots for demonstration",
                            "type": "equipment",
                        },
                        {"text": "Textbook of crop production", "type": "textbook"},
                        {
                            "text": "Local farmer as resource person",
                            "type": "resource person",
                        },
                    ],
                },
                {
                    "title": "Mushroom Production",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Types of Mushrooms",
                            "learning_objectives": [
                                {
                                    "objective": "Identify edible and poisonous mushroom species found in Malawi",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Field collection, identification, discussion",
                                },
                                {
                                    "objective": "Classify mushrooms by their nutritional and economic value",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Group work, research",
                                },
                            ],
                        },
                        {
                            "title": "Cultivation Methods",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the step-by-step process of cultivating oyster mushrooms using local substrates",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical demonstration",
                                },
                                {
                                    "objective": "Apply sterile techniques in mushroom spawn preparation and inoculation",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Laboratory practical",
                                },
                            ],
                        },
                        {
                            "title": "Harvesting and Marketing of Mushrooms",
                            "learning_objectives": [
                                {
                                    "objective": "Describe correct harvesting techniques and post-harvest handling of mushrooms",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical demonstration",
                                },
                                {
                                    "objective": "Analyze the market potential and value addition opportunities for mushroom products",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Market research, group work",
                                },
                            ],
                        },
                        {
                            "title": "Factors to Consider in Mushroom Production",
                            "learning_objectives": [
                                {
                                    "objective": "Evaluate environmental and economic factors affecting successful mushroom farming",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case study, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Mushroom spawn and substrates (straw, sawdust)",
                            "type": "equipment",
                        },
                        {
                            "text": "Polyethylene bags and tying materials",
                            "type": "equipment",
                        },
                        {"text": "Mushroom identification guide", "type": "textbook"},
                        {
                            "text": "Local mushroom farmer as resource person",
                            "type": "resource person",
                        },
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Crop Improvement and Processing",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Methods of Crop Improvement",
                            "learning_objectives": [
                                {
                                    "objective": "Describe conventional and modern methods of crop improvement (selection, hybridization, mutation, tissue culture)",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Lecture, ICT research, discussion",
                                },
                                {
                                    "objective": "Evaluate the effectiveness of different crop improvement methods for Malawian farming conditions",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case studies, debate",
                                },
                            ],
                        },
                        {
                            "title": "Processing Techniques",
                            "learning_objectives": [
                                {
                                    "objective": "Describe various crop processing techniques (drying, milling, fermentation, extraction, packaging)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Practical demonstration, field visit",
                                },
                                {
                                    "objective": "Apply appropriate processing techniques to improve the shelf life and value of crops",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical workshop",
                                },
                            ],
                        },
                        {
                            "title": "Value Addition",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze the economic benefits of value addition to raw agricultural products",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Case study, cost-benefit analysis",
                                },
                                {
                                    "objective": "Synthesize a value addition plan for a specific crop product targeting local and export markets",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, group planning",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Crop processing equipment (mill, dryer, press)",
                            "type": "equipment",
                        },
                        {
                            "text": "Textbook of crop science and technology",
                            "type": "textbook",
                        },
                        {
                            "text": "Agro-processing facility for field visit",
                            "type": "field trip",
                        },
                        {"text": "ICT resources for research", "type": "ict"},
                    ],
                },
                {
                    "title": "Pasture Production and Management",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Types of Pastures",
                            "learning_objectives": [
                                {
                                    "objective": "Classify pastures into natural and artificial types and identify common species grown in Malawi",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Field visit, identification exercise",
                                },
                                {
                                    "objective": "Compare the nutritive value and adaptability of different pasture species",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Research, group discussion",
                                },
                            ],
                        },
                        {
                            "title": "Establishment and Management of Pastures",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the procedures for establishing and managing improved pastures",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical demonstration, farm visit",
                                },
                                {
                                    "objective": "Evaluate the role of pasture management in sustaining livestock productivity",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case study, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Hay and Silage Making",
                            "learning_objectives": [
                                {
                                    "objective": "Apply step-by-step procedures for making hay from dried pasture grasses",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical demonstration",
                                },
                                {
                                    "objective": "Describe the principles and process of silage making and evaluate its importance for year-round livestock feed",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Practical workshop, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Pasture grass and legume seeds", "type": "equipment"},
                        {
                            "text": "Hay-making equipment (rakes, baler)",
                            "type": "equipment",
                        },
                        {
                            "text": "Silage-making materials (plastic sheets, pit)",
                            "type": "equipment",
                        },
                        {"text": "Textbook of pasture science", "type": "textbook"},
                    ],
                },
                {
                    "title": "Mango Production",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Mango Varieties and Propagation",
                            "learning_objectives": [
                                {
                                    "objective": "Identify common mango varieties grown in Malawi and their characteristics",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Field visit, photographs, discussion",
                                },
                                {
                                    "objective": "Describe propagation methods for mango trees (grafting, budding, air-layering)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical nursery demonstration",
                                },
                            ],
                        },
                        {
                            "title": "Planting and Management of Mango Trees",
                            "learning_objectives": [
                                {
                                    "objective": "Apply recommended practices for site selection, spacing and planting of mango trees",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical field work, demonstration",
                                },
                                {
                                    "objective": "Evaluate the importance of pruning, pest control and nutrition in mango management",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Farm visit, group discussion",
                                },
                            ],
                        },
                        {
                            "title": "Harvesting and Marketing of Mangoes",
                            "learning_objectives": [
                                {
                                    "objective": "Describe harvesting techniques and post-harvest handling practices for mangoes",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Practical demonstration",
                                },
                                {
                                    "objective": "Synthesize a marketing and value addition plan for mango products (juice, dried mango, jam)",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, group planning",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Mango nursery and orchard for field study",
                            "type": "field trip",
                        },
                        {"text": "Grafting and budding tools", "type": "equipment"},
                        {
                            "text": "Textbook of tropical fruit production",
                            "type": "textbook",
                        },
                        {
                            "text": "Local mango farmer as resource person",
                            "type": "resource person",
                        },
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 5 — LIVESTOCK PRODUCTION
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 5,
            "name": "Livestock Production",
            "description": (
                "Use scientific knowledge and skills of rearing farm animals "
                "profitably using appropriate husbandry practices."
            ),
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Classes of Livestock",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Digestive Systems of Ruminants and Non-ruminants",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the digestive systems of ruminants (cattle, goats, sheep) and non-ruminants (pigs, poultry)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, diagrams, dissection",
                                },
                            ],
                        },
                        {
                            "title": "Functions of Different Parts of Digestive Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the functions of the rumen, reticulum, omasum and abomasum in ruminant digestion",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, diagrams",
                                },
                                {
                                    "objective": "Compare the digestive processes in ruminants and non-ruminants",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, comparison charts",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Anatomical diagrams of digestive systems",
                            "type": "reference",
                        },
                        {
                            "text": "Models of ruminant stomach chambers",
                            "type": "equipment",
                        },
                        {
                            "text": "Charts comparing ruminant and non-ruminant digestion",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Chicken Production",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Breeds and Breeding",
                            "learning_objectives": [
                                {
                                    "objective": "Identify local and exotic chicken breeds suitable for Malawi",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, photographs, farm visit",
                                },
                                {
                                    "objective": "Describe basic breeding methods for improving chicken production",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Housing",
                            "learning_objectives": [
                                {
                                    "objective": "Describe requirements for proper chicken housing (ventilation, lighting, space, flooring)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, farm visit, construction",
                                },
                            ],
                        },
                        {
                            "title": "Feeds and Feeding",
                            "learning_objectives": [
                                {
                                    "objective": "Identify different types of chicken feeds and their nutritional requirements at various stages",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, feed analysis",
                                },
                            ],
                        },
                        {
                            "title": "Disease and Parasite Control",
                            "learning_objectives": [
                                {
                                    "objective": "Identify common chicken diseases and parasites in Malawi",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, photographs",
                                },
                                {
                                    "objective": "Describe methods of controlling diseases and parasites in chickens",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, demonstration",
                                },
                            ],
                        },
                        {
                            "title": "Predators of Chickens",
                            "learning_objectives": [
                                {
                                    "objective": "Identify common predators of chickens and describe methods of protecting chickens from predators",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chicken breeds photographs", "type": "reference"},
                        {"text": "Poultry feed samples", "type": "equipment"},
                        {"text": "Chicken coop / house model", "type": "equipment"},
                        {"text": "Vaccination equipment", "type": "equipment"},
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Pig Production",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Breeds and Breeding",
                            "learning_objectives": [
                                {
                                    "objective": "Identify common pig breeds raised in Malawi and their characteristics",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, photographs, farm visit",
                                },
                                {
                                    "objective": "Describe breeding methods for improving pig production",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Management Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Describe different pig management systems (intensive, semi-intensive, extensive)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, farm visit",
                                },
                                {
                                    "objective": "Compare the advantages and disadvantages of each management system",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, comparison charts",
                                },
                            ],
                        },
                        {
                            "title": "Housing",
                            "learning_objectives": [
                                {
                                    "objective": "Describe requirements for pig housing (space, ventilation, flooring, waste management)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, farm visit, construction",
                                },
                            ],
                        },
                        {
                            "title": "Feeds and Feeding",
                            "learning_objectives": [
                                {
                                    "objective": "Identify different types of pig feeds and their nutritional requirements at various stages of growth",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, feed analysis",
                                },
                                {
                                    "objective": "Calculate feed rations for pigs at different growth stages",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises, calculations",
                                },
                            ],
                        },
                        {
                            "title": "Disease and Parasite Control",
                            "learning_objectives": [
                                {
                                    "objective": "Identify common pig diseases and parasites in Malawi",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, photographs",
                                },
                                {
                                    "objective": "Describe prevention and control measures for pig diseases and parasites",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, demonstration",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Pig breeds photographs", "type": "reference"},
                        {"text": "Pig feed samples", "type": "equipment"},
                        {"text": "Pig housing design diagrams", "type": "reference"},
                        {
                            "text": "Deworming and vaccination equipment",
                            "type": "equipment",
                        },
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Livestock Feeds and Feeding",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Classes of Feeds",
                            "learning_objectives": [
                                {
                                    "objective": "Classify livestock feeds into energy, protein, mineral, vitamin and roughage feeds",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, feed samples analysis",
                                },
                                {
                                    "objective": "Analyze the nutritional composition and functions of each class of feed",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Practical laboratory work, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Feeding Methods",
                            "learning_objectives": [
                                {
                                    "objective": "Describe different feeding methods (hand feeding, self-feeding, trough feeding, pasture grazing)",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Farm visit, practical demonstration",
                                },
                                {
                                    "objective": "Evaluate the suitability of each feeding method for different livestock species",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Group discussion, case study",
                                },
                            ],
                        },
                        {
                            "title": "Feed Preparation",
                            "learning_objectives": [
                                {
                                    "objective": "Apply techniques for preparing compounded feeds, silage and hay for livestock",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical workshop, demonstration",
                                },
                                {
                                    "objective": "Calculate balanced rations for different classes of livestock using feed formulation principles",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical calculations, exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Samples of different feed classes",
                            "type": "equipment",
                        },
                        {"text": "Feed composition tables", "type": "reference"},
                        {"text": "Feed mixer and weighing scale", "type": "equipment"},
                        {"text": "Textbook of animal nutrition", "type": "textbook"},
                    ],
                },
                {
                    "title": "Sheep and Goat Breeds and Housing",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Local and Exotic Breeds of Sheep and Goats",
                            "learning_objectives": [
                                {
                                    "objective": "Identify common local and exotic breeds of sheep and goats raised in Malawi",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, photographs, farm visit",
                                },
                                {
                                    "objective": "Compare the characteristics and production potential of local and exotic breeds",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, comparison charts",
                                },
                            ],
                        },
                        {
                            "title": "Housing Requirements for Sheep and Goats",
                            "learning_objectives": [
                                {
                                    "objective": "Describe design requirements for sheep and goat housing (ventilation, space, flooring, drainage)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, farm visit",
                                },
                                {
                                    "objective": "Evaluate different housing designs in terms of cost, comfort and animal health",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Group work, design analysis",
                                },
                            ],
                        },
                        {
                            "title": "Construction of Sheep and Goat Housing",
                            "learning_objectives": [
                                {
                                    "objective": "Apply principles of construction to build a simple sheep or goat house using locally available materials",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical construction project",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Sheep and goat breed photographs",
                            "type": "reference",
                        },
                        {
                            "text": "Construction materials and tools",
                            "type": "equipment",
                        },
                        {"text": "Housing design diagrams", "type": "reference"},
                        {
                            "text": "Local small ruminant farmer as resource person",
                            "type": "resource person",
                        },
                    ],
                },
                {
                    "title": "Feeding Behaviour and Nutrition of Sheep and Goats",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Feeding Patterns of Sheep and Goats",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the natural feeding behaviour and browsing patterns of sheep and goats",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Farm observation, discussion",
                                },
                                {
                                    "objective": "Analyze the differences in feeding behaviour between sheep and goats",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Observation, comparison, group work",
                                },
                            ],
                        },
                        {
                            "title": "Nutritional Requirements",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the nutritional requirements of sheep and goats at different production stages",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, feed analysis",
                                },
                                {
                                    "objective": "Apply feed formulation principles to meet the nutritional needs of sheep and goats",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical calculations, exercises",
                                },
                            ],
                        },
                        {
                            "title": "Supplements for Sheep and Goats",
                            "learning_objectives": [
                                {
                                    "objective": "Evaluate the role of mineral licks, protein supplements and vitamin supplements in sheep and goat nutrition",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Discussion, case study",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Feed supplement samples (mineral licks, protein cakes)",
                            "type": "equipment",
                        },
                        {
                            "text": "Nutrient requirement charts for sheep and goats",
                            "type": "reference",
                        },
                        {
                            "text": "Textbook of small ruminant production",
                            "type": "textbook",
                        },
                        {
                            "text": "School flock of sheep or goats for observation",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Diseases and Parasites of Sheep and Goats",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Common Diseases of Sheep and Goats",
                            "learning_objectives": [
                                {
                                    "objective": "Identify common diseases affecting sheep and goats in Malawi (anthrax, heartwater, contagious caprine pleuropneumonia)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, photographs, veterinary officer visit",
                                },
                                {
                                    "objective": "Describe the symptoms, transmission and treatment of major sheep and goat diseases",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, case studies",
                                },
                            ],
                        },
                        {
                            "title": "Parasites of Sheep and Goats",
                            "learning_objectives": [
                                {
                                    "objective": "Identify internal and external parasites of sheep and goats and describe their life cycles",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, microscopic examination, diagrams",
                                },
                                {
                                    "objective": "Analyze the effects of parasites on the productivity of sheep and goats",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Data analysis, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Prevention and Treatment of Diseases and Parasites",
                            "learning_objectives": [
                                {
                                    "objective": "Describe integrated disease and parasite management strategies including vaccination, deworming and hygiene",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, field visit, discussion",
                                },
                                {
                                    "objective": "Evaluate the effectiveness of different control measures and propose a disease prevention calendar",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Group project, calendar design",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Parasite specimens and identification guides",
                            "type": "equipment",
                        },
                        {
                            "text": "Veterinary drug samples (dewormers, vaccines)",
                            "type": "equipment",
                        },
                        {
                            "text": "Veterinary officer as resource person",
                            "type": "resource person",
                        },
                        {"text": "Textbook of veterinary science", "type": "textbook"},
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Cattle Production",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Cattle Breeds",
                            "learning_objectives": [
                                {
                                    "objective": "Identify local and exotic cattle breeds raised in Malawi and their characteristics",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, photographs, farm visit",
                                },
                                {
                                    "objective": "Compare the production characteristics (milk, meat, draft) of different cattle breeds",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, comparison charts",
                                },
                            ],
                        },
                        {
                            "title": "Cattle Management Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Describe extensive, semi-intensive and intensive cattle management systems",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Farm visit, lecture",
                                },
                                {
                                    "objective": "Evaluate the suitability of different management systems for smallholder and commercial farmers in Malawi",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case study, debate",
                                },
                            ],
                        },
                        {
                            "title": "Feeding and Housing of Cattle",
                            "learning_objectives": [
                                {
                                    "objective": "Apply principles of balanced ration formulation for cattle at different production stages",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical calculations, feed analysis",
                                },
                                {
                                    "objective": "Design appropriate cattle housing considering animal comfort, hygiene and local materials",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Design project, group work",
                                },
                            ],
                        },
                        {
                            "title": "Health Management of Cattle",
                            "learning_objectives": [
                                {
                                    "objective": "Describe common cattle diseases, their prevention and treatment protocols",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Veterinary officer visit, demonstration",
                                },
                                {
                                    "objective": "Develop an integrated cattle health management plan for a farm",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, group planning",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Cattle breeds photographs and charts",
                            "type": "reference",
                        },
                        {"text": "Textbook of cattle production", "type": "textbook"},
                        {
                            "text": "Local cattle farm for field visit",
                            "type": "field trip",
                        },
                        {
                            "text": "Veterinary officer as resource person",
                            "type": "resource person",
                        },
                    ],
                },
                {
                    "title": "Reproductive Systems of Cattle and Poultry",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Anatomy of Reproductive Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the anatomy of the male and female reproductive systems of cattle",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, anatomical diagrams, models",
                                },
                                {
                                    "objective": "Describe the anatomy of the male and female reproductive systems of poultry",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, anatomical diagrams",
                                },
                            ],
                        },
                        {
                            "title": "Physiology of Reproduction",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze the physiological processes involved in reproduction including gametogenesis and fertilization",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Lecture, ICT resources, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Reproductive Hormones",
                            "learning_objectives": [
                                {
                                    "objective": "Identify key reproductive hormones and explain their roles in livestock reproduction",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, charts, discussion",
                                },
                                {
                                    "objective": "Evaluate the application of reproductive hormones in managed breeding programs",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case study, debate",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Anatomical models of reproductive systems",
                            "type": "equipment",
                        },
                        {"text": "Reproductive hormone charts", "type": "reference"},
                        {"text": "Textbook of animal reproduction", "type": "textbook"},
                        {
                            "text": "ICT resources for animations and videos",
                            "type": "ict",
                        },
                    ],
                },
                {
                    "title": "Reproductive Cycles and Processes in Livestock",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "The Oestrus Cycle",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the phases of the oestrus cycle in cattle, sheep and goats",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, diagrams, discussion",
                                },
                                {
                                    "objective": "Analyze the hormonal changes during each phase of the oestrus cycle",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "ICT animations, group work",
                                },
                            ],
                        },
                        {
                            "title": "Mating and Fertilization",
                            "learning_objectives": [
                                {
                                    "objective": "Describe natural mating and artificial insemination processes in livestock",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, practical demonstration",
                                },
                                {
                                    "objective": "Evaluate factors affecting conception rates in livestock breeding",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Data analysis, case study",
                                },
                            ],
                        },
                        {
                            "title": "Gestation and Parturition",
                            "learning_objectives": [
                                {
                                    "objective": "State gestation periods for cattle, sheep, goats and pigs and describe signs of approaching parturition",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, farm visit",
                                },
                                {
                                    "objective": "Describe the stages of parturition and appropriate management practices during and after calving or lambing",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, practical workshop",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Reproductive cycle diagrams and charts",
                            "type": "reference",
                        },
                        {
                            "text": "AI kits and equipment for demonstration",
                            "type": "equipment",
                        },
                        {"text": "Textbook of animal breeding", "type": "textbook"},
                        {
                            "text": "Veterinary officer as resource person",
                            "type": "resource person",
                        },
                    ],
                },
                {
                    "title": "Livestock Improvement",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Selective Breeding",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the principles and methods of selective breeding for improving livestock traits",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, case studies",
                                },
                                {
                                    "objective": "Evaluate the effectiveness of selective breeding in improving local livestock in Malawi",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Field study, data analysis",
                                },
                            ],
                        },
                        {
                            "title": "Crossbreeding",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the principles of crossbreeding and hybrid vigour in livestock improvement",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, diagrams, discussion",
                                },
                                {
                                    "objective": "Analyze the advantages and limitations of crossbreeding for different livestock species",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Case study, group debate",
                                },
                            ],
                        },
                        {
                            "title": "Artificial Insemination",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the procedure, advantages and challenges of artificial insemination in livestock",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstration, farm visit",
                                },
                                {
                                    "objective": "Evaluate the role of artificial insemination in improving cattle and poultry production in Malawi",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Case study, debate",
                                },
                            ],
                        },
                        {
                            "title": "Performance Recording",
                            "learning_objectives": [
                                {
                                    "objective": "Describe methods of recording livestock performance data (birth weight, growth rate, milk yield)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercise, farm visit",
                                },
                                {
                                    "objective": "Apply performance data analysis to make informed breeding and management decisions",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Data analysis, project work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Livestock breeding charts and records",
                            "type": "reference",
                        },
                        {
                            "text": "AI equipment and semen straws for demonstration",
                            "type": "equipment",
                        },
                        {
                            "text": "Textbook of animal breeding and genetics",
                            "type": "textbook",
                        },
                        {
                            "text": "AI technician as resource person",
                            "type": "resource person",
                        },
                    ],
                },
            ],
        },
    ],
}


async def seed_agriculture_syllabus():
    """Seed the Malawi Agriculture syllabus. Idempotent — skips if already seeded."""
    async with async_session() as db:
        existing = await db.execute(
            select(SyllabusSubject).where(SyllabusSubject.slug == "agriculture")
        )
        if existing.scalar_one_or_none():
            return

        data = AGRICULTURE_SYLLABUS
        subject_data = data["subject"]
        subject = SyllabusSubject(
            name=subject_data["name"],
            slug=subject_data["slug"],
            description=subject_data.get("description", ""),
            icon=subject_data.get("icon", "agriculture_rounded"),
            color=subject_data.get("color", "#22C55E"),
        )
        db.add(subject)
        await db.flush()

        version_data = data["version"]
        version = SyllabusVersion(
            subject_id=subject.id,
            version_name=version_data["version_name"],
            year_effective=version_data.get("year_effective"),
            examination_board=version_data.get("examination_board"),
            description=version_data.get("description", ""),
            is_current=True,
        )
        db.add(version)
        await db.flush()

        for idx, ce_data in enumerate(data.get("core_elements", [])):
            ce = SyllabusCoreElement(
                version_id=version.id,
                number=ce_data["number"],
                name=ce_data["name"],
                description=ce_data.get("description", ""),
                order_index=idx,
            )
            db.add(ce)
            await db.flush()

            for t_idx, topic_data in enumerate(ce_data.get("topics", [])):
                topic = SyllabusTopic(
                    core_element_id=ce.id,
                    title=topic_data["title"],
                    description=topic_data.get("description", ""),
                    year_level=topic_data.get("year_level", 1),
                    order_index=t_idx,
                )
                db.add(topic)
                await db.flush()

                for sub_data in topic_data.get("subtopics", []):
                    sub = SyllabusSubtopic(
                        topic_id=topic.id,
                        title=sub_data["title"],
                        description=sub_data.get("description", ""),
                        order_index=0,
                    )
                    db.add(sub)
                    await db.flush()

                    for lo_data in sub_data.get("learning_objectives", []):
                        lo = SyllabusLearningObjective(
                            subtopic_id=sub.id,
                            objective=lo_data["objective"],
                            description=lo_data.get("description", ""),
                            cognitive_level=lo_data.get("cognitive_level", "Knowledge"),
                            teaching_activity=lo_data.get("teaching_activity", ""),
                            teaching_method=lo_data.get("teaching_method", ""),
                        )
                        db.add(lo)

                for res_data in topic_data.get("resources", []):
                    res = SyllabusResource(
                        topic_id=topic.id,
                        resource_text=res_data["text"],
                        resource_type=res_data.get("type", "equipment"),
                    )
                    db.add(res)

        await db.commit()
