"""Seed the official Malawi Chemistry syllabus (MoEST, Forms 1 to 4).

Exact reproduction of the official Chemistry Syllabus scope chart (Forms 1–4)
and detailed teaching syllabus. Run from lifespan in main.py.
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

CHEMISTRY_SYLLABUS = {
    "subject": {
        "name": "Chemistry",
        "slug": "chemistry",
        "description": "Malawi MSCE Chemistry Syllabus — MoEST Forms 1 to 4",
        "icon": "science_rounded",
        "color": "#F59E0B",
    },
    "version": {
        "version_name": "MoEST Forms 1 to 4",
        "year_effective": 2018,
        "examination_board": "Malawi National Examinations Board (MANEB)",
        "description": (
            "Official Chemistry syllabus for Malawi School Certificate of Education "
            "(MSCE), covering Forms 1 to 4. Published by the Ministry of Education, "
            "Science and Technology through the Malawi Institute of Education (MIE)."
        ),
    },
    "core_elements": [
        {
            "number": 1,
            "name": "Analytical Skills in Chemistry",
            "description": "Appropriate use of scientific methods, techniques and materials to solve problems in daily life.",
            "topics": [
                {
                    "title": "Introduction to Chemistry",
                    "year_level": 1,
                    "periods": 15,
                    "subtopics": [
                        {"title": "Chemistry and society"},
                        {"title": "Laboratory safety measures"},
                        {"title": "Units of measurements"},
                        {"title": "Basic scientific instruments and apparatus"},
                        {"title": "Scientific method of investigations"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Discuss the relationship between chemistry and society",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe laboratory safety measures and precautions",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify and use appropriate units of measurement in chemistry",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Name and describe basic scientific instruments and apparatus",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Test for the presence of water using anhydrous copper sulphate or anhydrous cobalt chloride",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                    ],
                    "resources": [
                        {"text": "Anhydrous cobalt chloride", "type": "chemical"},
                        {"text": "Gas syringes", "type": "equipment"},
                        {"text": "Thermometers", "type": "equipment"},
                        {"text": "Ink", "type": "chemical"},
                        {"text": "Filter paper/cloth", "type": "equipment"},
                        {"text": "Distilled or deionised water", "type": "chemical"},
                        {"text": "Ethanol", "type": "chemical"},
                        {"text": "Mortars and pestles", "type": "equipment"},
                        {"text": "Sources of heat", "type": "equipment"},
                        {"text": "Centrifuges", "type": "equipment"},
                        {"text": "Computers", "type": "digital"},
                        {"text": "Scientific calculators", "type": "equipment"},
                    ],
                },
                {
                    "title": "Essential Mathematical Skills for Chemistry",
                    "year_level": 1,
                    "periods": 9,
                    "subtopics": [
                        {"title": "Handling numbers"},
                        {"title": "Scientific notation"},
                        {"title": "Significant figures"},
                        {"title": "Accuracy and precision"},
                        {"title": "Presentation and manipulation of numerical data"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Express numbers in scientific notation",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify and apply significant figures in measurements",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Distinguish between accuracy and precision",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Present and manipulate numerical data appropriately",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Experimental Techniques",
                    "year_level": 2,
                    "periods": 12,
                    "subtopics": [
                        {
                            "title": "Ways of disposing chemical wastes in the laboratory"
                        },
                        {
                            "title": "Designing experiments for scientific investigations"
                        },
                        {"title": "Determining the purity of substances"},
                        {"title": "Simple tests for water, ions and gases"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe safe ways of disposing chemical wastes in the laboratory",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify techniques and suitable apparatus for a variety of simple experiments",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Present experimental data from observations and measurements",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Determine the purity of substances using melting and boiling points or paper chromatography",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Interpret paper chromatograms using known samples and relative flow values",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify aqueous cations using aqueous sodium hydroxide and aqueous ammonia",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss tests for identifying aqueous anions (sulphates, halides and nitrates)",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss simple tests for identifying common gases such as ammonia, carbon dioxide, hydrogen, chlorine, oxygen, and sulphur dioxide",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Test for the presence of water using anhydrous copper sulphate or anhydrous cobalt chloride",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Experimental Techniques (Advanced)",
                    "year_level": 3,
                    "description": "Advanced experimental techniques for purification and analysis.",
                    "subtopics": [
                        {"title": "Safe disposal of chemical wastes"},
                        {
                            "title": "Designing and carrying out scientific investigations"
                        },
                        {"title": "Determining purity of substances"},
                        {"title": "Tests for water, ions and gases"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe safe ways of disposing chemical wastes in the laboratory",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify techniques and suitable apparatus for a variety of simple experiments",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Present experimental data from observations and measurements",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Determine the purity of substances using melting and boiling points or paper chromatography",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Interpret paper chromatograms using known samples and relative flow values",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify aqueous cations using aqueous sodium hydroxide and aqueous ammonia",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss tests for identifying aqueous anions (sulphates, halides and nitrates)",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss simple tests for identifying common gases",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Test for the presence of water using anhydrous copper sulphate or anhydrous cobalt chloride",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
            ],
        },
        {
            "number": 2,
            "name": "Chemical Composition of Matter",
            "description": "Composition and properties of various natural and synthetic substances which form the environment.",
            "topics": [
                {
                    "title": "Composition and Classification of Matter",
                    "year_level": 1,
                    "periods": 24,
                    "subtopics": [
                        {"title": "Particulate nature of matter"},
                        {"title": "Atoms, elements and compounds"},
                        {"title": "Chemical symbols and formulae"},
                        {"title": "Pure substances and mixtures"},
                        {"title": "Solutions"},
                        {"title": "Separating mixtures"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Explain the particulate nature of matter",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Distinguish between atoms, elements and compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Use chemical symbols and formulae correctly",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Differentiate between pure substances and mixtures",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe the properties of solutions",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Separate mixtures using chromatography, filtration, distillation, sedimentation, decantation, centrifuge, and crystallization",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Chemical Bonding",
                    "year_level": 2,
                    "periods": 15,
                    "subtopics": [
                        {"title": "Types of bonding: covalent, ionic, metallic"},
                        {"title": "Chemical formulae for ionic and covalent compounds"},
                        {"title": "Cross and dot diagrams"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the three types of chemical bonding: covalent, ionic, and metallic",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Write chemical formulae for ionic and covalent compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Draw cross and dot diagrams to represent bonding in compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Chemical Bonding and Properties of Matter",
                    "year_level": 3,
                    "periods": 20,
                    "subtopics": [
                        {"title": "Properties of ionic and covalent compounds"},
                        {"title": "Bond polarity"},
                        {"title": "Effects of intermolecular forces"},
                        {"title": "Allotropy and allotropes"},
                        {"title": "Properties and uses of allotropes of carbon"},
                        {"title": "Properties and uses of metallic substances"},
                        {"title": "Properties and uses of alloys"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe properties of ionic and covalent compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain structural differences between ionic and covalent compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Differentiate between polar and non-polar covalent bonds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Relate intermolecular forces to properties of covalent compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Define the term allotropy",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Relate the properties of allotropes of carbon to their uses",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain similarities between diamond and silicon dioxide",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe the uses of metals in relation to their properties",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain the physical properties of alloys",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "State the uses of alloys",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Textbooks", "type": "reference"},
                        {"text": "Activity sheets", "type": "reference"},
                        {"text": "Charts", "type": "reference"},
                        {"text": "Posters", "type": "reference"},
                        {"text": "Molecular models", "type": "equipment"},
                        {"text": "Bottle tops", "type": "sample"},
                        {"text": "Circuit boards", "type": "equipment"},
                        {"text": "Bulbs", "type": "equipment"},
                        {"text": "Ammeters", "type": "equipment"},
                        {"text": "Carbon rods", "type": "equipment"},
                        {"text": "Thermometer", "type": "equipment"},
                        {"text": "Tripod stand", "type": "equipment"},
                        {"text": "NaCl", "type": "chemical"},
                        {"text": "MgCl2", "type": "chemical"},
                        {"text": "Glassware", "type": "equipment"},
                        {"text": "CaO", "type": "chemical"},
                        {"text": "Sugar", "type": "chemical"},
                        {"text": "Water", "type": "chemical"},
                        {"text": "Alcohol", "type": "chemical"},
                        {"text": "Dry cells", "type": "equipment"},
                        {"text": "Spatulas", "type": "equipment"},
                        {"text": "Gas burners", "type": "equipment"},
                        {"text": "Crucibles", "type": "equipment"},
                        {"text": "Metals (Al and Cu)", "type": "chemical"},
                        {"text": "Diamond and graphite", "type": "sample"},
                        {"text": "Heating blocks (hot plates)", "type": "equipment"},
                        {"text": "Pieces of cutlery", "type": "sample"},
                    ],
                },
            ],
        },
        {
            "number": 3,
            "name": "Inorganic Chemistry",
            "description": "Properties of various inorganic substances, their uses in manufacturing industry and environmental dangers.",
            "topics": [
                {
                    "title": "Atomic Structure",
                    "year_level": 1,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Atomic structure"},
                        {"title": "Electron configuration"},
                        {"title": "Atomic numbers (A) and mass numbers (Z)"},
                        {"title": "Isotopes"},
                        {"title": "Average atomic masses"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the structure of the atom",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Write electron configurations for elements",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Determine atomic numbers and mass numbers",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain the concept of isotopes",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Calculate average atomic masses from isotopic data",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "The Periodic Table",
                    "year_level": 1,
                    "periods": 9,
                    "subtopics": [
                        {"title": "Definition of periodic table"},
                        {
                            "title": "Arrangement of the first twenty elements in the periodic table"
                        },
                        {"title": "Family of elements"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define the periodic table and its significance",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Arrange the first twenty elements in the periodic table",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify families of elements and their characteristics",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Elements and the Periodic Table",
                    "year_level": 2,
                    "periods": 15,
                    "subtopics": [
                        {"title": "Trends in the periodic table"},
                        {"title": "Properties of groups I, II, VII and VIII"},
                        {"title": "Uses of group I, II, VII and VIII elements"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe trends in the periodic table",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain the properties of groups I, II, VII and VIII",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss the uses of group I, II, VII and VIII elements",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Nitrogen, Sulphur and Phosphorus",
                    "year_level": 3,
                    "periods": 16,
                    "subtopics": [
                        {"title": "Sources of nitrogen"},
                        {"title": "Properties of nitrogen"},
                        {"title": "Uses of nitrogen and its compounds"},
                        {"title": "Sources and properties of sulphur"},
                        {"title": "Uses of sulphur and its compounds"},
                        {"title": "Sources and properties of phosphorus"},
                        {"title": "Uses of phosphorus and its compounds"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe sources of nitrogen",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe properties of nitrogen and explain its inert character",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain uses of nitrogen in providing an inert atmosphere, as a coolant and food packaging",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe the preparation of ammonia and nitric acid",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss uses of ammonia and nitric acid in the manufacture of ammonium nitrate fertilisers",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe sources of sulphur and explain its properties",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss the uses of sulphur including the manufacture of rubber tyres, dyes and matches",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss the preparation of sulphuric acid and its use in the manufacture of inorganic fertilizers",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe sources and properties of phosphorus",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss uses of phosphorus in manufacturing of toothpaste, matches, baking soda and detergents",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss uses of phosphoric acid in the manufacture of inorganic fertilizers and food additives",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "reference"},
                        {"text": "Pictures", "type": "reference"},
                        {"text": "Posters", "type": "reference"},
                        {"text": "Matches", "type": "equipment"},
                        {"text": "Ammonia", "type": "chemical"},
                        {"text": "Nitric acid", "type": "chemical"},
                        {"text": "Textbooks", "type": "reference"},
                        {"text": "Molecular models", "type": "equipment"},
                        {"text": "Tooth paste", "type": "sample"},
                        {"text": "Activity sheets", "type": "reference"},
                        {"text": "Samples of fertilizers", "type": "sample"},
                        {"text": "Sulphur", "type": "chemical"},
                        {"text": "Fire works", "type": "sample"},
                        {"text": "Used tyres", "type": "sample"},
                        {"text": "Sulphuric acid", "type": "chemical"},
                        {"text": "Sugar", "type": "chemical"},
                        {"text": "Students' experiences", "type": "reference"},
                    ],
                },
            ],
        },
        {
            "number": 4,
            "name": "Chemical Reactions",
            "description": "Types of chemical reactions, stoichiometry, rates, energetics, acids, bases, redox and electrolysis.",
            "topics": [
                {
                    "title": "Physical and Chemical Changes",
                    "year_level": 1,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Introduction to physical and chemical changes"},
                        {"title": "Chemical reactions"},
                        {"title": "Balancing chemical equations"},
                        {"title": "Reacting masses"},
                        {"title": "Percentage composition by mass"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Distinguish between physical and chemical changes",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify characteristics of chemical reactions",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Balance chemical equations",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Calculate reacting masses from equations",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Determine percentage composition by mass",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Acids and Bases",
                    "year_level": 2,
                    "periods": 15,
                    "subtopics": [
                        {"title": "Properties of acids and bases"},
                        {"title": "Acid-base indicators"},
                        {"title": "Strength of acids and bases in terms of pH value"},
                        {"title": "Uses of acids and bases"},
                        {"title": "Neutralisation reactions and their applications"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the properties of acids and bases",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Use acid-base indicators to test for acidity and alkalinity",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain the strength of acids and bases in terms of pH value",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss uses of acids and bases in daily life",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe neutralisation reactions and their applications",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Chemical Reactions I: Stoichiometry",
                    "year_level": 3,
                    "periods": 28,
                    "subtopics": [
                        {"title": "Balancing chemical equations"},
                        {"title": "Relative formula masses"},
                        {"title": "The mole concept"},
                        {
                            "title": "Percentage of water in molecular and hydrated ionic compounds"
                        },
                        {"title": "Empirical and molecular formula"},
                        {"title": "Concentration of solutions"},
                        {"title": "Preparation of standard solutions"},
                        {"title": "Titrations"},
                        {"title": "Percentage yield"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Balance chemical equations accurately",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Calculate relative formula masses",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Apply the mole concept to calculations",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Calculate the percentage of water in molecular and hydrated ionic compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Determine empirical and molecular formulae",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Calculate concentration of solutions",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Prepare standard solutions",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Carry out titration calculations",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Calculate percentage yield from reactions",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Chemical Reactions II: Rates of Reactions",
                    "year_level": 3,
                    "periods": 8,
                    "subtopics": [
                        {"title": "Definition of rate of reaction"},
                        {"title": "Factors affecting rate of reaction"},
                        {"title": "Measuring rates of reactions"},
                        {"title": "Interpreting graphs on rates of reactions"},
                        {"title": "Reversible and irreversible reactions"},
                        {"title": "Chemical equilibrium"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define rate of reaction",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe factors affecting rate of reaction",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Measure rates of reactions experimentally",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Interpret graphs on rates of reactions",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Distinguish between reversible and irreversible reactions",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain the concept of chemical equilibrium",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Heats of Reactions",
                    "year_level": 4,
                    "periods": 10,
                    "subtopics": [
                        {"title": "Endothermic and exothermic reactions"},
                        {"title": "Temperature change in chemical reactions"},
                        {"title": "Energy level diagrams"},
                        {"title": "Bond energies"},
                        {"title": "Preparation of soluble and insoluble salts"},
                        {"title": "Separation and purification of salts"},
                        {"title": "Applications of precipitation reactions"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Distinguish between endothermic and exothermic reactions",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Measure temperature changes in chemical reactions",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Draw and interpret energy level diagrams",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Relate bond energies to enthalpy changes",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Prepare soluble and insoluble salts",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Separate and purify salts",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Apply precipitation reactions in practical contexts",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Acids and Bases (Advanced)",
                    "year_level": 4,
                    "periods": 16,
                    "subtopics": [
                        {
                            "title": "Definition of acids and bases according to Bronsted-Lowry theory"
                        },
                        {"title": "Conjugate acid-base pairs"},
                        {"title": "Strength of acids and bases in terms of ionisation"},
                        {"title": "Concentration versus strength of acids and bases"},
                        {"title": "Ways of controlling pH in different environments"},
                        {
                            "title": "Classification of metal oxides and non-metal oxides as acidic and basic"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define acids and bases according to Bronsted-Lowry theory",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify conjugate acid-base pairs",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain the strength of acids and bases in terms of ionisation",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Differentiate between concentration and strength of acids and bases",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe ways of controlling pH in different environments",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Classify metal oxides and non-metal oxides as acidic and basic",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Reduction and Oxidation Reactions",
                    "year_level": 4,
                    "periods": 16,
                    "subtopics": [
                        {"title": "Definition of oxidation and reduction"},
                        {"title": "Oxidation states/numbers"},
                        {"title": "Half and overall equations"},
                        {"title": "Oxidizing and reducing agents"},
                        {"title": "Displacement reactions"},
                        {"title": "Activity series"},
                        {"title": "Voltage series"},
                        {"title": "Corrosion and its prevention"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define oxidation and reduction",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration, discussion",
                        },
                        {
                            "objective": "Assign oxidation states/numbers to elements in compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Identify reducing and oxidizing agents from a given equation",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, examples",
                        },
                        {
                            "objective": "Identify reduced and oxidised species based on changes in oxidation numbers",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Write half equations for reduction and oxidation reactions",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Write and balance overall redox equations",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Conduct an experiment on the reaction of metals with water and hydrochloric acid",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                        {
                            "objective": "Arrange metals in order of their reactivity",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation, discussion",
                        },
                        {
                            "objective": "Explain displacement reaction using reactions of metals with metal ions in solution",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration, discussion",
                        },
                        {
                            "objective": "Discuss the reactivity of metals in terms of the ease with which they lose electrons",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Use the activity series to predict whether a reaction will take place for given reactants",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Explain the potential difference between different metals using voltage series",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, calculation",
                        },
                        {
                            "objective": "Calculate the potential difference between different metals using voltage series",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Explain the process of corrosion as a reduction-oxidation reaction of metals",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss corrosion of iron (rusting) in terms of half reaction equations",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Conduct an experiment on conditions necessary for rusting to take place",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                        {
                            "objective": "Discuss methods of preventing corrosion",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                    ],
                    "resources": [
                        {"text": "Table of reactivity series", "type": "reference"},
                        {
                            "text": "Stopper, glassware, distilled water",
                            "type": "equipment",
                        },
                        {"text": "Silver nitrate", "type": "chemical"},
                        {"text": "Iron oxide", "type": "chemical"},
                        {"text": "Computer simulations", "type": "digital"},
                        {"text": "Scientific calculators", "type": "equipment"},
                        {"text": "Protective wear", "type": "equipment"},
                    ],
                },
                {
                    "title": "Electrolysis",
                    "year_level": 4,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Definition of electrolysis"},
                        {"title": "Uses of electrolysis"},
                        {"title": "Purification of copper"},
                        {"title": "Electroplating and its uses"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define electrolysis and its principles",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration, discussion",
                        },
                        {
                            "objective": "Discuss the process of electrolysis and components of an electrolytic cell",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, experimentation",
                        },
                        {
                            "objective": "Write and balance half equations at the cathode and the anode",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Add cathode and anode half equations to form overall equations",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Predict products of the electrolysis of molten and aqueous ionic compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation, discussion",
                        },
                        {
                            "objective": "Discuss the ions present in the molten state of an electrolyte and products formed at the electrodes",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Discuss the ions present in aqueous solution and the products formed at the electrodes",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Demonstrate preferential discharge using very reactive metals and non-metals",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                        {
                            "objective": "Conduct an experiment on the electrolysis of molten lead bromide and aqueous sodium iodide",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                        {
                            "objective": "Investigate the electrolysis of copper (II) sulphate using inert (graphite) and copper electrodes",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                        {
                            "objective": "Discuss the uses of electrolysis such as extraction and purification of metals, electroplating, production of chemicals and lead batteries",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe the process of the purification of copper",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration, discussion",
                        },
                        {
                            "objective": "Discuss applications of electroplating and its benefits to society",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Design and conduct an experiment to exemplify electroplating",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                    ],
                    "resources": [
                        {"text": "Conductivity apparatus", "type": "equipment"},
                        {"text": "Cotton wool, nails", "type": "equipment"},
                        {"text": "Cooking oil", "type": "chemical"},
                        {"text": "Water", "type": "chemical"},
                        {"text": "Anhydrous calcium chloride", "type": "chemical"},
                        {"text": "Bulbs/ammeter", "type": "equipment"},
                        {"text": "Protective wear", "type": "equipment"},
                        {"text": "Lead bromide", "type": "chemical"},
                        {"text": "Copper(II) sulphate", "type": "chemical"},
                        {"text": "Sodium iodide", "type": "chemical"},
                        {"text": "Graphite electrodes", "type": "equipment"},
                        {"text": "Copper electrodes", "type": "equipment"},
                        {"text": "Sources of heat", "type": "equipment"},
                        {"text": "Glassware", "type": "equipment"},
                    ],
                },
            ],
        },
        {
            "number": 5,
            "name": "Organic Chemistry",
            "description": "Organic compounds, hydrocarbons, functional groups, polymers, and identification of unknown organic compounds.",
            "topics": [
                {
                    "title": "Introduction to Organic Compounds",
                    "year_level": 1,
                    "periods": 9,
                    "subtopics": [
                        {"title": "Historical background of organic compounds"},
                        {"title": "Uses of organic compounds"},
                        {"title": "Fractions of petroleum and their uses"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Discuss the historical background of organic compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify uses of organic compounds in daily life",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe fractions of petroleum and their uses",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Organic Families I: Hydrocarbons",
                    "year_level": 1,
                    "periods": 15,
                    "subtopics": [
                        {"title": "Nomenclature of alkanes and alkenes"},
                        {
                            "title": "Molecular, condensed, structural and skeletal formulae of alkanes and alkenes"
                        },
                        {"title": "Saturated and unsaturated hydrocarbons"},
                        {
                            "title": "Physical and chemical properties of alkanes and alkenes"
                        },
                        {"title": "Uses of alkanes and alkenes"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Name alkanes and alkenes using IUPAC nomenclature",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Draw molecular, condensed, structural and skeletal formulae",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Distinguish between saturated and unsaturated hydrocarbons",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe the physical and chemical properties of alkanes and alkenes",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss uses of alkanes and alkenes",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Organic Families II: Alkanols",
                    "year_level": 2,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Functional group"},
                        {"title": "Structure and nomenclature"},
                        {"title": "Molecular and general formulae"},
                        {"title": "Classification"},
                        {"title": "Preparation"},
                        {"title": "Physical and chemical properties"},
                        {"title": "Uses"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Identify the functional group in alkanols",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Name and draw structures of alkanols",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Write molecular and general formulae for alkanols",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Classify alkanols as primary, secondary or tertiary",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe methods of preparation of alkanols",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe the physical and chemical properties of alkanols",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss uses of alkanols",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Alkanals and Alkanones (Aldehydes and Ketones)",
                    "year_level": 2,
                    "periods": 8,
                    "subtopics": [
                        {"title": "Functional group"},
                        {"title": "Structure and nomenclature"},
                        {"title": "Sources"},
                        {"title": "Tests"},
                        {"title": "Uses"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Identify the functional group in alkanals and alkanones",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Name and draw structures of alkanals and alkanones",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe sources of alkanals and alkanones",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe tests for identifying alkanals and alkanones",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss uses of alkanals and alkanones",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Isomerism",
                    "year_level": 3,
                    "periods": 8,
                    "subtopics": [
                        {"title": "Definition of isomers"},
                        {"title": "Structures and nomenclature of isomers"},
                        {
                            "title": "Effects of branching on physical properties of organic compounds"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define isomers and give examples",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration, discussion",
                        },
                        {
                            "objective": "Discuss isomers as compounds with the same molecular formula but different structures",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, examples",
                        },
                        {
                            "objective": "Discuss structural and position of functional group isomerism",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss and illustrate the difference between isomers and conformers",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, molecular models",
                        },
                        {
                            "objective": "Draw isomers of molecules (of up to five carbon atoms) from the specified families of organic compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice, molecular models",
                        },
                        {
                            "objective": "Discuss and name constituent branches of alkanes using IUPAC naming system",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Name isomers given their structures",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Discuss the polarity of different organic compounds",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Relate the differences in structure of isomers to boiling and melting points and densities",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, experimentation",
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "reference"},
                        {"text": "Textbooks", "type": "reference"},
                        {"text": "Activity sheets", "type": "reference"},
                        {"text": "Molecular models", "type": "equipment"},
                        {"text": "Computer animations", "type": "digital"},
                        {
                            "text": "Samples of different organic compounds",
                            "type": "chemical",
                        },
                    ],
                },
                {
                    "title": "Alkanoic (Carboxylic) Acids",
                    "year_level": 3,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Functional group"},
                        {"title": "Structure and nomenclature"},
                        {"title": "Molecular and general formulae"},
                        {"title": "Sources"},
                        {"title": "Physical and chemical properties"},
                        {"title": "Uses"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Identify the functional group in alkanoic acids",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Name and draw structures of alkanoic acids",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Write molecular and general formulae for alkanoic acids",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe sources of alkanoic acids",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe the physical and chemical properties of alkanoic acids",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss uses of alkanoic acids",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Polymerisation",
                    "year_level": 4,
                    "periods": 8,
                    "subtopics": [
                        {"title": "Definition of polymers"},
                        {"title": "Types of polymers"},
                        {"title": "Types of polymerisation"},
                        {"title": "Properties and uses of polymers"},
                        {"title": "Thermosoftening and thermosetting plastics"},
                        {"title": "Ways of moulding plastics"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define the terms monomers and polymers",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration, discussion",
                        },
                        {
                            "objective": "List examples of natural polymers such as proteins, DNA and carbohydrates",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, examples",
                        },
                        {
                            "objective": "List examples of synthetic polymers such as PVC, nylon and terlyene",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, examples",
                        },
                        {
                            "objective": "Discuss addition and condensation polymerisation",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "List examples of addition and condensation polymerisation",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, examples",
                        },
                        {
                            "objective": "Discuss properties and uses of synthetic polymers",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss the differences between thermosoftening and thermosetting plastics",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, experimentation",
                        },
                        {
                            "objective": "Investigate differences between thermosoftening and thermosetting plastics",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                    ],
                    "resources": [
                        {"text": "Textbooks", "type": "reference"},
                        {"text": "Charts", "type": "reference"},
                        {"text": "Activity sheets", "type": "reference"},
                        {"text": "Videos", "type": "digital"},
                        {"text": "Plastic materials", "type": "equipment"},
                        {"text": "Hair mesh", "type": "equipment"},
                        {"text": "Molecular models", "type": "equipment"},
                        {"text": "Pictures", "type": "reference"},
                        {"text": "Sources of heat", "type": "equipment"},
                        {"text": "Posters", "type": "reference"},
                        {"text": "Computer simulations", "type": "digital"},
                        {"text": "Protective wear", "type": "equipment"},
                    ],
                },
                {
                    "title": "Alkanoates (Esters)",
                    "year_level": 4,
                    "periods": 8,
                    "subtopics": [
                        {"title": "Functional group"},
                        {"title": "Structure and nomenclature"},
                        {"title": "Sources"},
                        {"title": "Properties"},
                        {"title": "Uses"},
                        {"title": "Saponification"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Identify the functional group in alkanoates",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Name and draw structures of alkanoates",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe sources of alkanoates",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe the properties of alkanoates",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss uses of alkanoates",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain the process of saponification",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Identification of Unknown Organic Compounds",
                    "year_level": 4,
                    "periods": 4,
                    "subtopics": [
                        {
                            "title": "Deducing class and formulae of unknown organic compounds"
                        },
                        {"title": "Construction of flow diagrams"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Deduce the class and formulae of unknown organic compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Construct flow diagrams for identification of organic compounds",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
            ],
        },
        {
            "number": 6,
            "name": "Environmental Chemistry",
            "description": "Air, soil, water, greenhouse gases, ozone layer, and waste management in the environment.",
            "topics": [
                {
                    "title": "Air",
                    "year_level": 2,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Composition of dry air"},
                        {"title": "Separation of air into its components"},
                        {"title": "Properties and uses of gases in air"},
                        {"title": "Common pollutants of air"},
                        {"title": "Sources of air pollutants"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the composition of dry air",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain the separation of air into its components",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Describe the properties and uses of gases in air",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify common pollutants of air",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss sources of air pollutants",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Soil",
                    "year_level": 2,
                    "periods": 9,
                    "subtopics": [
                        {"title": "Chemical composition of soil"},
                        {"title": "Chemical properties of soil"},
                        {"title": "Sources and effects of soil pollution"},
                        {"title": "Ways of controlling soil pollution"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the chemical composition of soil",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Explain the chemical properties of soil",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Identify sources and effects of soil pollution",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                        {
                            "objective": "Discuss ways of controlling soil pollution",
                            "cognitive_level": "Application",
                            "teaching_method": "Demonstration, discussion, practical work",
                        },
                    ],
                },
                {
                    "title": "Water",
                    "year_level": 3,
                    "periods": 18,
                    "subtopics": [
                        {"title": "Natural sources of water"},
                        {"title": "Water cycle"},
                        {"title": "Properties of water"},
                        {"title": "Importance of water"},
                        {"title": "Hard and soft water"},
                        {"title": "Water pollutants"},
                        {"title": "Dangers of polluted water"},
                        {"title": "Purification and treatment of water"},
                        {"title": "Prevention of water pollution"},
                        {
                            "title": "International and national standards on water quality"
                        },
                        {"title": "Impact of human activities on the atmosphere"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Identify natural sources of water",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Brainstorming, discussion",
                        },
                        {
                            "objective": "Discuss different natural sources of water (underground, surface and atmospheric)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Explain the water cycle",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, drawing",
                        },
                        {
                            "objective": "Draw the water cycle",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Investigate the physical properties of water (boiling point, density, surface tension)",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                        {
                            "objective": "Explain the importance of water as a reactant, coolant and solvent",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Brainstorm the meaning of hard and soft water",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Brainstorming",
                        },
                        {
                            "objective": "Investigate the hardness and softness of water using soap",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                        {
                            "objective": "Describe the process that results in hard water and name salts that cause hard water",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss the difference between temporary and permanent hardness of water",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss the effects of water hardness",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss physical and chemical processes of softening hard water",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, experimentation",
                        },
                        {
                            "objective": "Conduct experiments on removing water hardness",
                            "cognitive_level": "Application",
                            "teaching_method": "Experimentation",
                        },
                        {
                            "objective": "Define water pollution",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss the sources of water pollution: domestic, industrial and agricultural wastes",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss the effects of water pollution",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss ways of preventing water pollution",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Resource persons", "type": "person"},
                        {
                            "text": "Rain water, river water, tap water, bore hole water, pond water",
                            "type": "sample",
                        },
                        {"text": "Calcium hydroxide", "type": "chemical"},
                        {"text": "Aqueous ammonia", "type": "chemical"},
                        {"text": "Charts", "type": "reference"},
                        {"text": "Sources of heat", "type": "equipment"},
                        {"text": "Distillation apparatus", "type": "equipment"},
                        {"text": "Sodium carbonate", "type": "chemical"},
                        {"text": "Posters", "type": "reference"},
                        {"text": "Textbooks", "type": "reference"},
                        {"text": "Thermometers", "type": "equipment"},
                        {"text": "Glassware", "type": "equipment"},
                        {"text": "Balances", "type": "equipment"},
                        {"text": "Needles", "type": "equipment"},
                        {"text": "Soap", "type": "chemical"},
                        {"text": "Pictures", "type": "reference"},
                        {"text": "Internet", "type": "digital"},
                        {"text": "Activity sheets", "type": "reference"},
                        {"text": "Video", "type": "digital"},
                        {"text": "Mathematical instruments", "type": "equipment"},
                        {"text": "Scientific calculators", "type": "equipment"},
                        {"text": "Radio jingles", "type": "digital"},
                        {"text": "Bottled water", "type": "sample"},
                    ],
                },
                {
                    "title": "Greenhouse Gases and the Ozone Layer",
                    "year_level": 4,
                    "periods": 8,
                    "subtopics": [
                        {"title": "Greenhouse gases"},
                        {"title": "Ozone layer"},
                        {"title": "Standards on air quality"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Explain the effects of natural disasters and human activities on the atmosphere",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, field trips",
                        },
                        {
                            "objective": "Discuss effects of natural disasters such as volcanoes and bush fires",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss the effects of extensive burning of organic fuels and deforestation",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss the effects of using CFCs",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Explain the meaning of greenhouse gases",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss the greenhouse gases and their sources",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss the contribution of carbon dioxide and methane to global warming",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Brainstorm ways of mitigating global warming",
                            "cognitive_level": "Application",
                            "teaching_method": "Brainstorming",
                        },
                        {
                            "objective": "Discuss the role of disaster risk management institutions in mitigating the effects of global warming",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss standards on air quality",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe the position of ozone layer in the atmosphere",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Explain the importance of ozone layer",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss the depletion of ozone layer by action of chlorofluorocarbons (CFCs)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss problems associated with depletion of ozone layer",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Computer simulations", "type": "digital"},
                        {"text": "Resource persons", "type": "person"},
                        {"text": "Videos", "type": "digital"},
                        {"text": "Posters", "type": "reference"},
                        {"text": "Newspapers", "type": "reference"},
                        {"text": "Charts", "type": "reference"},
                        {"text": "Textbooks", "type": "reference"},
                        {"text": "Activity sheets", "type": "reference"},
                        {"text": "Pictures", "type": "reference"},
                        {"text": "Internet", "type": "digital"},
                        {"text": "MBS brochures/booklets", "type": "reference"},
                        {
                            "text": "World Health Organisation (WHO) booklets",
                            "type": "reference",
                        },
                        {"text": "WHO website", "type": "digital"},
                        {"text": "MBS website", "type": "digital"},
                    ],
                },
                {
                    "title": "Waste Management",
                    "year_level": 4,
                    "periods": 8,
                    "subtopics": [
                        {"title": "Types of wastes"},
                        {"title": "Sources of wastes"},
                        {"title": "Treatment and disposal of wastes"},
                        {"title": "Minimization of wastes"},
                        {"title": "Social and economic importance of recycling wastes"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Classify different types of wastes based on physical state and degradability",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion, classification",
                        },
                        {
                            "objective": "State major sources of wastes: domestic, industrial, agricultural, medical, laboratory",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, pictures",
                        },
                        {
                            "objective": "Display pictures of wastes at source",
                            "cognitive_level": "Application",
                            "teaching_method": "Visual aids",
                        },
                        {
                            "objective": "Discuss the physical and chemical characterisation of wastes",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss ways of treating wastes: physical, chemical, biological, thermal (incineration)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe the different ways of waste disposal such as landfills and damp-site",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, field trips",
                        },
                        {
                            "objective": "Discuss the advantages and disadvantages of different ways of waste treatment and disposal",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe ways of waste minimization such as reusing, recycling and reduction at source",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Summarise waste minimisation reports from print media",
                            "cognitive_level": "Application",
                            "teaching_method": "Reading, writing",
                        },
                        {
                            "objective": "Explain the process of recycling metals and plastics",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, field trips",
                        },
                        {
                            "objective": "Discuss the benefits of recycling metals and plastics",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Resource persons", "type": "person"},
                        {"text": "Videos", "type": "digital"},
                        {"text": "Charts", "type": "reference"},
                        {"text": "Textbooks", "type": "reference"},
                        {"text": "Activity sheets", "type": "reference"},
                        {"text": "Pictures", "type": "reference"},
                        {"text": "Computer simulations", "type": "digital"},
                        {"text": "Samples of plastics", "type": "sample"},
                        {"text": "Scrap metals", "type": "sample"},
                    ],
                },
            ],
        },
    ],
}


async def seed_chemistry_syllabus():
    """Seed the Malawi Chemistry syllabus. Idempotent — skips if already seeded."""
    async with async_session() as db:
        existing = await db.execute(
            select(SyllabusSubject).where(SyllabusSubject.slug == "chemistry")
        )
        if existing.scalar_one_or_none():
            return

        data = CHEMISTRY_SYLLABUS
        subject_data = data["subject"]
        subject = SyllabusSubject(
            name=subject_data["name"],
            slug=subject_data["slug"],
            description=subject_data.get("description", ""),
            icon=subject_data.get("icon", "science_rounded"),
            color=subject_data.get("color", "#F59E0B"),
        )
        db.add(subject)
        await db.commit()
        await db.refresh(subject)

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
        await db.commit()
        await db.refresh(version)

        for idx, ce_data in enumerate(data.get("core_elements", [])):
            ce = SyllabusCoreElement(
                version_id=version.id,
                number=ce_data["number"],
                name=ce_data["name"],
                description=ce_data.get("description", ""),
                order_index=idx,
            )
            db.add(ce)
            await db.commit()
            await db.refresh(ce)

            for t_idx, topic_data in enumerate(ce_data.get("topics", [])):
                topic = SyllabusTopic(
                    core_element_id=ce.id,
                    title=topic_data["title"],
                    description=topic_data.get("description", ""),
                    year_level=topic_data.get("year_level", 1),
                    order_index=t_idx,
                )
                db.add(topic)
                await db.commit()
                await db.refresh(topic)

                subtopic_los = topic_data.get("learning_objectives", [])
                sub_list = topic_data.get("subtopics", [])

                subs = []
                for s_idx, sub_data in enumerate(sub_list):
                    sub = SyllabusSubtopic(
                        topic_id=topic.id,
                        title=sub_data["title"],
                        description=sub_data.get("description", ""),
                        order_index=s_idx,
                    )
                    db.add(sub)
                    await db.commit()
                    await db.refresh(sub)
                    subs.append(sub)

                for lo_idx, lo_data in enumerate(subtopic_los):
                    target_sub = subs[min(lo_idx, len(subs) - 1)] if subs else None
                    if not target_sub:
                        break
                    lo = SyllabusLearningObjective(
                        subtopic_id=target_sub.id,
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
