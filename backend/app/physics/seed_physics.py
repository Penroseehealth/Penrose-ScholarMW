"""Malawi Physics Syllabus (Forms 1-4) — seed data and population.

Matches the official MoEST scope and sequence chart.
CEs 1-3 are from the provided syllabus table; CEs 4-6 are from the
standard MSCE Physics curriculum.
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

PHYSICS_SYLLABUS = {
    "subject": {
        "name": "Physics",
        "slug": "physics",
        "description": (
            "The study of matter, energy, and their interactions. Physics develops "
            "scientific inquiry skills and deep understanding of natural phenomena "
            "through observation, experimentation, and mathematical reasoning. "
            "This syllabus follows the Malawi Ministry of Education Science and "
            "Technology (MoEST) MSCE Physics curriculum covering Scientific "
            "Investigations and Skills, Properties of Matter, Mechanics, Electricity "
            "and Magnetism, Oscillation and Waves, and Nuclear Physics."
        ),
        "icon": "bolt_rounded",
        "color": "#3B82F6",
    },
    "version": {
        "version_name": "Malawi MSCE Physics 2024",
        "year_effective": 2024,
        "examination_board": "Malawi National Examinations Board (MANEB)",
        "description": "Current MSCE Physics syllabus for Forms 1-4",
    },
    "core_elements": [
        # ═══════════════════════════════════════════════════════════════
        # CE 1 — Scientific Investigations and Skills
        # ═══════════════════════════════════════════════════════════════
        {
            "number": 1,
            "name": "Scientific Investigations and Skills",
            "description": (
                "Develops learners' ability to plan, conduct, analyse, and report "
                "scientific investigations. Emphasises safety, measurement accuracy, "
                "graphical analysis, and the use of basic laboratory equipment."
            ),
            "topics": [
                # ── Form 1 ──────────────────────────────────────────
                {
                    "title": "Introduction",
                    "description": "Physics as a science and its scope.",
                    "year_level": 1,
                    "periods": 6,
                    "subtopics": [
                        {"title": "Physics as a science"},
                        {"title": "Scientific investigations"},
                        {"title": "Laboratory and safety rules"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define Physics as the study of matter, energy, and their interactions",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Describe what a scientific investigation involves",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "List and explain laboratory safety rules",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Demonstrate safe handling of laboratory equipment and chemicals",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical demonstration",
                        },
                    ],
                    "resources": [
                        {"text": "Physics textbook", "type": "reference"},
                        {"text": "Safety signage", "type": "reference"},
                        {"text": "First aid kit", "type": "equipment"},
                        {"text": "Safety goggles and gloves", "type": "equipment"},
                    ],
                },
                {
                    "title": "Measurements I",
                    "description": "Fundamental quantities, SI units, and basic instruments.",
                    "year_level": 1,
                    "periods": 4,
                    "subtopics": [
                        {"title": "Fundamental quantities"},
                        {"title": "SI units and symbols"},
                        {"title": "Prefixes for SI units"},
                        {"title": "Conversion of units"},
                        {"title": "Basic measuring instruments (scale reading)"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "State the fundamental quantities and their SI units: length (m), mass (kg), time (s), current (A), temperature (K)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "State SI prefixes: milli, centi, kilo, mega, giga and their factors",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, exercises",
                        },
                        {
                            "objective": "Convert between units using SI prefixes",
                            "cognitive_level": "Application",
                            "teaching_method": "Exercises",
                        },
                        {
                            "objective": "Read measurements from rulers, metre rules, and other basic instruments",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {"text": "Rulers and metre rules", "type": "equipment"},
                        {"text": "Measuring cylinders", "type": "equipment"},
                        {"text": "Stop-watches", "type": "equipment"},
                    ],
                },
                # ── Form 2 ──────────────────────────────────────────
                {
                    "title": "Conducting a Scientific Investigation",
                    "description": "Basic scientific investigation processes.",
                    "year_level": 2,
                    "periods": 4,
                    "subtopics": [
                        {"title": "Basic scientific investigation processes"},
                        {"title": "Investigation from any topic covered in Form 1"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the steps of a scientific investigation: observation, hypothesis, experiment, conclusion",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Carry out a scientific investigation using the correct process",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Write up an investigation following scientific conventions",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided writing",
                        },
                    ],
                    "resources": [
                        {"text": "Laboratory notebooks", "type": "reference"},
                        {"text": "Graph paper", "type": "reference"},
                        {"text": "Basic laboratory equipment", "type": "equipment"},
                    ],
                },
                # ── Form 3 ──────────────────────────────────────────
                {
                    "title": "Measurements II",
                    "description": "Advanced measuring instruments, standard notation, and unit conversion.",
                    "year_level": 3,
                    "periods": 3,
                    "subtopics": [
                        {"title": "Measuring instruments and units"},
                        {"title": "Quantities and SI units"},
                        {"title": "Standard notation"},
                        {"title": "Prefixes for SI units"},
                        {"title": "Unit conversion"},
                        {"title": "Scale reading"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Read measurements from vernier callipers, micrometre screw gauge, and other precision instruments",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Express quantities in standard (scientific) notation",
                            "cognitive_level": "Application",
                            "teaching_method": "Exercises",
                        },
                        {
                            "objective": "Convert between derived SI units accurately",
                            "cognitive_level": "Application",
                            "teaching_method": "Exercises",
                        },
                    ],
                    "resources": [
                        {"text": "Vernier callipers", "type": "equipment"},
                        {"text": "Micrometre screw gauge", "type": "equipment"},
                        {"text": "Electronic balances", "type": "equipment"},
                    ],
                },
                {
                    "title": "Scientific Investigations",
                    "description": "Designing, carrying out, and analysing investigations.",
                    "year_level": 3,
                    "periods": 8,
                    "subtopics": [
                        {
                            "title": "Designing a scientific investigation",
                            "description": "identifying a problem, hypothesising, deciding data type, identifying variables",
                        },
                        {
                            "title": "Carrying out investigation",
                            "description": "collecting and organising scientific data",
                        },
                        {
                            "title": "Analysing data of the investigation",
                            "description": "identifying errors and their sources, classifying errors",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Identify a problem, formulate a hypothesis, and decide the type of data to collect",
                            "cognitive_level": "Application",
                            "teaching_method": "Group work",
                        },
                        {
                            "objective": "Identify independent variables, dependent variables, controlled variables, and methods of controlling variables",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Collect and organise scientific data systematically",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Identify errors and their sources in an experiment",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Classify errors as systematic, random, or zero errors",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, examples",
                        },
                    ],
                    "resources": [
                        {"text": "Laboratory notebooks", "type": "reference"},
                        {"text": "Data recording sheets", "type": "reference"},
                        {"text": "Various laboratory apparatus", "type": "equipment"},
                    ],
                },
                # ── Form 4 ──────────────────────────────────────────
                {
                    "title": "Graphical Analysis and Communication",
                    "description": "Graph plotting, analysis, error reduction, and reporting.",
                    "year_level": 4,
                    "periods": 10,
                    "subtopics": [
                        {"title": "Selecting suitable scales in graph plotting"},
                        {"title": "Graph plotting"},
                        {"title": "Using a graph to analyse scientific data"},
                        {"title": "Using a graph to even out errors"},
                        {
                            "title": "Drawing conclusions and generalisations from results"
                        },
                        {
                            "title": "Communicating results from experimentations",
                            "description": "organising results, oral and poster presentations, writing a lab report",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Select appropriate scales for axes when plotting graphs",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided practice",
                        },
                        {
                            "objective": "Plot accurate graphs with correct scales, labels, and titles",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Use graphs to analyse scientific data and extract meaningful information",
                            "cognitive_level": "Analysis",
                            "teaching_method": "Guided exercises",
                        },
                        {
                            "objective": "Use a line of best fit to even out random errors in experimental data",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Draw valid conclusions and generalisations from experimental results",
                            "cognitive_level": "Analysis",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Organise experimental results into clear tables and figures",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided writing",
                        },
                        {
                            "objective": "Make oral and poster presentations of experimental findings",
                            "cognitive_level": "Application",
                            "teaching_method": "Presentation",
                        },
                        {
                            "objective": "Write a complete laboratory report with introduction, method, results, and conclusion",
                            "cognitive_level": "Synthesis",
                            "teaching_method": "Independent writing",
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "reference"},
                        {"text": "Report writing templates", "type": "reference"},
                        {"text": "Presentation equipment", "type": "digital"},
                    ],
                },
                {
                    "title": "Evaluating Scientific Investigations",
                    "description": "Relating conclusions to hypotheses and assessing accuracy.",
                    "year_level": 4,
                    "periods": 6,
                    "subtopics": [
                        {
                            "title": "Evaluating the scientific investigation",
                            "description": "relating conclusion to hypothesis and/or logic or published data",
                        },
                        {
                            "title": "Factors affecting accuracy of an investigation",
                            "description": "identifying factors and how to address them",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Relate the conclusion of an investigation back to the hypothesis, logic, or published data",
                            "cognitive_level": "Evaluation",
                            "teaching_method": "Discussion, exercises",
                        },
                        {
                            "objective": "Identify factors that may affect the accuracy of an investigation",
                            "cognitive_level": "Analysis",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Suggest ways to address factors that reduce accuracy in experiments",
                            "cognitive_level": "Evaluation",
                            "teaching_method": "Group work",
                        },
                    ],
                    "resources": [
                        {"text": "Sample research reports", "type": "reference"},
                        {"text": "Peer review worksheets", "type": "reference"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════
        # CE 2 — Properties of Matter
        # ═══════════════════════════════════════════════════════════════
        {
            "number": 2,
            "name": "Properties of Matter",
            "description": (
                "Explores the structure, states, and physical properties of matter "
                "including density, pressure, thermal behaviour, and the kinetic theory."
            ),
            "topics": [
                # ── Form 1 ──────────────────────────────────────────
                {
                    "title": "Particulate Nature of Matter",
                    "description": "States of matter and particle arrangement.",
                    "year_level": 1,
                    "periods": 6,
                    "subtopics": [
                        {"title": "Meaning of matter"},
                        {"title": "States of matter"},
                        {"title": "Composition of matter"},
                        {"title": "Evidence of existence of particles in matter"},
                        {
                            "title": "Arrangement of particles in different states of matter"
                        },
                        {"title": "Properties of three states of matter"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define matter as anything that has mass and occupies space",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Name the three states of matter and give examples of each",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, examples",
                        },
                        {
                            "objective": "Describe the composition of matter in terms of atoms and molecules",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, diagrams",
                        },
                        {
                            "objective": "Give evidence for the existence of particles in matter (diffusion, Brownian motion)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Draw particle diagrams showing the arrangement of particles in solids, liquids, and gases",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Compare the properties of the three states of matter: shape, volume, compressibility",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, comparison table",
                        },
                    ],
                    "resources": [
                        {"text": "Particle model charts", "type": "reference"},
                        {"text": "Smoke cell for Brownian motion", "type": "equipment"},
                        {"text": "Samples of solids, liquids, gases", "type": "sample"},
                    ],
                },
                {
                    "title": "Changes in States of Matter",
                    "description": "Melting, boiling, and factors affecting change points.",
                    "year_level": 1,
                    "periods": 10,
                    "subtopics": [
                        {"title": "Properties of the three states of matter"},
                        {"title": "Meaning of heat"},
                        {"title": "Meaning of temperature"},
                        {"title": "Heat and temperature"},
                        {"title": "Melting and boiling points"},
                        {
                            "title": "Factors affecting melting and boiling points (altitude, impurities)"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "State the properties of solids, liquids, and gases",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Define heat as energy transferred due to temperature difference",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Define temperature as a measure of the average kinetic energy of particles",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Distinguish between heat and temperature",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, examples",
                        },
                        {
                            "objective": "Define melting point and boiling point and identify them from heating curves",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, graph analysis",
                        },
                        {
                            "objective": "Explain how altitude and impurities affect melting and boiling points",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, examples",
                        },
                    ],
                    "resources": [
                        {"text": "Heating curve apparatus", "type": "equipment"},
                        {
                            "text": "Ice, water, steam demonstration",
                            "type": "equipment",
                        },
                        {"text": "Thermometers", "type": "equipment"},
                        {"text": "Bunsen burners", "type": "equipment"},
                    ],
                },
                # ── Form 2 ──────────────────────────────────────────
                {
                    "title": "Thermal Expansion of Solids, Liquids and Gases",
                    "description": "Effect of heat on dimensions and volume.",
                    "year_level": 2,
                    "periods": 8,
                    "subtopics": [
                        {"title": "Effect of heat on solids, liquids and gases"},
                        {"title": "Rate of expansion"},
                        {"title": "Application of expansion"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe how heating affects the dimensions and volume of solids, liquids, and gases",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration, discussion",
                        },
                        {
                            "objective": "Compare the rate of expansion of different materials",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Give practical applications of thermal expansion (railway gaps, bimetallic strips, thermometers)",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion, examples",
                        },
                    ],
                    "resources": [
                        {"text": "Ball and ring apparatus", "type": "equipment"},
                        {"text": "Bimetallic strip", "type": "equipment"},
                        {
                            "text": "Glass flask with narrow tube for liquid expansion",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Density",
                    "description": "Definition, calculation, and applications of density.",
                    "year_level": 2,
                    "periods": 9,
                    "subtopics": [
                        {"title": "Meaning of density"},
                        {"title": "Calculations on density"},
                        {"title": "Density and states of matter"},
                        {"title": "Density and temperature"},
                        {"title": "Sinking and floating"},
                        {"title": "Applications of density"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define density as mass per unit volume (rho = m/V) and state its SI unit (kg/m^3)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Calculate density of solids, liquids, and gases from experimental data",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation, practical",
                        },
                        {
                            "objective": "Explain how density varies with state of matter and temperature",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Explain sinking and floating in terms of relative density",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Give real-life applications of density (shipbuilding, hot air balloons, hydrometers)",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Electronic balances", "type": "equipment"},
                        {"text": "Measuring cylinders", "type": "equipment"},
                        {"text": "Various solids and liquids", "type": "sample"},
                        {"text": "Hydrometer", "type": "equipment"},
                    ],
                },
                # ── Form 3 ──────────────────────────────────────────
                {
                    "title": "Kinetic Theory of Matter",
                    "description": "Particle model and gas pressure.",
                    "year_level": 3,
                    "periods": 6,
                    "subtopics": [
                        {
                            "title": "Kinetic theory of solids, liquids and gases",
                            "description": "experiment to demonstrate the kinetic theory of matter, relation to different states",
                        },
                        {
                            "title": "Gas pressure",
                            "description": "cause of gas pressure, demonstration of gas pressure",
                        },
                        {
                            "title": "Temperature",
                            "description": "internal energy and temperature, relationship between average molecular speed and temperature",
                        },
                        {"title": "Absolute temperature"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "State the postulates of the kinetic theory of matter",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Describe an experiment to demonstrate the kinetic theory of matter",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Explain the kinetic theory in relation to solids, liquids, and gases",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Explain the cause of gas pressure in terms of molecular collisions",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, simulation",
                        },
                        {
                            "objective": "Demonstrate gas pressure experimentally",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Define internal energy and relate it to temperature",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Explain the relationship between average molecular speed and temperature",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Define absolute temperature and its relationship to the Kelvin scale",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Kinetic theory models/simulations",
                            "type": "digital",
                        },
                        {
                            "text": "Piston and cylinder for gas pressure demo",
                            "type": "equipment",
                        },
                        {
                            "text": "Copper spheres and wax for molecular motion demo",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Thermal Expansion",
                    "description": "Expansion in terms of particle behaviour.",
                    "year_level": 3,
                    "periods": 5,
                    "subtopics": [
                        {"title": "Thermal expansion in solids, liquids and gases"},
                        {
                            "title": "Expansion and particle behaviour",
                            "description": "illustration of particle behaviour in the expansion of matter, expansion in terms of particle behaviour",
                        },
                        {
                            "title": "Expansion of water and its effects",
                            "description": "expansion of water in frozen state",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe thermal expansion of solids, liquids, and gases with examples",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Explain thermal expansion in terms of particle behaviour (increased vibration, increased spacing)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, diagrams",
                        },
                        {
                            "objective": "Describe the anomalous expansion of water and its effects on aquatic life",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Water expansion demonstration apparatus",
                            "type": "equipment",
                        },
                        {"text": "Particle model diagrams", "type": "reference"},
                    ],
                },
                {
                    "title": "Specific Heat Capacity",
                    "description": "Heat capacity, specific heat capacity, and applications.",
                    "year_level": 3,
                    "periods": 4,
                    "subtopics": [
                        {"title": "Meaning of heat capacity"},
                        {"title": "Calculations on heat capacity"},
                        {"title": "Meaning of specific heat capacity"},
                        {
                            "title": "Difference between heat capacity and specific heat capacity"
                        },
                        {"title": "Calculations on specific heat capacity"},
                        {"title": "Applications of specific heat capacity"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define heat capacity as the energy needed to raise the temperature of a body by 1 K",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Calculate heat energy using Q = C x delta-T",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Define specific heat capacity (c) as the energy needed to raise 1 kg by 1 K",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Distinguish between heat capacity (C) and specific heat capacity (c)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Calculate heat energy using Q = mc x delta-T",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Explain applications of specific heat capacity (climate, cooling systems, storage heaters)",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Calorimeters", "type": "equipment"},
                        {"text": "Heaters and thermometers", "type": "equipment"},
                        {
                            "text": "Specific heat capacity data sheets",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Heat Transfer",
                    "description": "Conduction, convection, and radiation.",
                    "year_level": 3,
                    "periods": 6,
                    "subtopics": [
                        {"title": "Conduction"},
                        {"title": "Convection"},
                        {"title": "Radiation"},
                        {"title": "Application of heat transfer"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe heat conduction in solids, liquids, and gases and identify conductors and insulators",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration, discussion",
                        },
                        {
                            "objective": "Describe convection in fluids with examples (sea breezes, heating systems)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Describe heat radiation and its properties (does not require a medium, travels at speed of light)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "Give practical applications of heat transfer (insulation, solar panels, cooling fins)",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Conduction bars (copper, iron, aluminium)",
                            "type": "equipment",
                        },
                        {
                            "text": "Ink in water for convection demo",
                            "type": "equipment",
                        },
                        {"text": "Leslie's cube for radiation", "type": "equipment"},
                    ],
                },
                # ── Form 4 ──────────────────────────────────────────
                {
                    "title": "Thermometry",
                    "description": "Temperature scales, thermometer types, and measurement.",
                    "year_level": 4,
                    "periods": 6,
                    "subtopics": [
                        {"title": "Types of temperature scales"},
                        {"title": "Differences among temperature scales"},
                        {"title": "Converting scales"},
                        {"title": "Thermometers and how they function"},
                        {
                            "title": "Various types of thermometers",
                            "description": "liquid-in-glass, thermocouple, constant-volume gas, resistance thermometers",
                        },
                        {"title": "How thermometers work"},
                        {"title": "Temperature measurements using thermometers"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Name the common temperature scales: Celsius, Fahrenheit, Kelvin",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Compare the Celsius, Fahrenheit, and Kelvin scales",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Convert temperatures between Celsius, Fahrenheit, and Kelvin scales",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Describe how a liquid-in-glass thermometer works",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "Describe the working principles of thermocouple, constant-volume gas, and resistance thermometers",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, diagrams",
                        },
                        {
                            "objective": "Measure temperature accurately using appropriate thermometers",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {"text": "Liquid-in-glass thermometers", "type": "equipment"},
                        {"text": "Thermocouple thermometer", "type": "equipment"},
                        {"text": "Resistance thermometer", "type": "equipment"},
                        {
                            "text": "Ice and boiling water for calibration",
                            "type": "sample",
                        },
                    ],
                },
                {
                    "title": "Pressure",
                    "description": "Pressure in solids, liquids, and atmosphere.",
                    "year_level": 4,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Meaning of pressure (definition, SI units)"},
                        {
                            "title": "Pressure exerted by solids",
                            "description": "pressure in solids, factors affecting pressure in solids",
                        },
                        {
                            "title": "Factors affecting pressure in liquids",
                            "description": "investigating factors, deriving p = rho x g x h, problems involving p = rho x g x h",
                        },
                        {
                            "title": "Pascal's principle of transmission of pressure in fluids",
                            "description": "demonstration, stating Pascal's principle",
                        },
                        {
                            "title": "Atmospheric pressure",
                            "description": "collapsing can experiment, drinking straws, card on bottle experiments, effects, measuring",
                        },
                        {
                            "title": "Applications of pressure in fluids",
                            "description": "examples of applications, liquid pressure in everyday activities, problems",
                        },
                        {
                            "title": "Archimedes' principle",
                            "description": "stating, verifying, law of floatation, applications and relative density, problems",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define pressure as force per unit area (P = F/A) and state its SI unit (Pascal, Pa)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Explain how the pressure exerted by a solid depends on force and contact area",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, experiment",
                        },
                        {
                            "objective": "Investigate factors affecting pressure in liquids (depth, density)",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Derive and apply the formula P = rho x g x h for liquid pressure",
                            "cognitive_level": "Application",
                            "teaching_method": "Guided derivation, calculation",
                        },
                        {
                            "objective": "State Pascal's principle and demonstrate it experimentally",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Describe and explain atmospheric pressure using collapsing can, drinking straw, and card-on-bottle experiments",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Explain the effects of atmospheric pressure and how to measure it",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "Give examples of applications of liquid pressure in everyday life",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Solve problems involving liquid pressure and Pascal's principle",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "State Archimedes' principle and verify it experimentally",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "State the law of floatation and relate it to Archimedes' principle",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Solve problems involving Archimedes' principle and relative density",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Beakers, thistle funnels, and rubber membranes for liquid pressure",
                            "type": "equipment",
                        },
                        {"text": "Collapsing can apparatus", "type": "equipment"},
                        {
                            "text": "Drinking straws and cards for atmospheric pressure",
                            "type": "equipment",
                        },
                        {
                            "text": "Eureka can for Archimedes' principle",
                            "type": "equipment",
                        },
                        {
                            "text": "Spring balances and overflow cans",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Gas Laws",
                    "description": "Boyle's law, Charles' law, and pressure law.",
                    "year_level": 4,
                    "periods": 8,
                    "subtopics": [
                        {
                            "title": "The gas laws",
                            "description": "Boyle's law (PV = const), Charles' law (V/T = const), Pressure law (P/T = const)",
                        },
                        {"title": "Gas laws and the kinetic theory of gases"},
                        {
                            "title": "Applications of the gas laws",
                            "description": "everyday applications, problems, making a manometer, measuring lung pressure",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "State Boyle's law and verify it experimentally",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, practical",
                        },
                        {
                            "objective": "State Charles' law and verify it experimentally",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, practical",
                        },
                        {
                            "objective": "State the pressure law and verify it experimentally",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, practical",
                        },
                        {
                            "objective": "Explain each gas law using the kinetic theory of gases",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Give everyday applications of the gas laws",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Solve problems involving the gas laws",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Construct a simple manometer and use it to measure pressure",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Measure lung pressure using a manometer",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {"text": "Boyle's law apparatus (J-tube)", "type": "equipment"},
                        {"text": "Charles' law apparatus", "type": "equipment"},
                        {
                            "text": "Manometer construction materials",
                            "type": "equipment",
                        },
                        {"text": "Gas syringes", "type": "equipment"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════
        # CE 3 — Mechanics
        # ═══════════════════════════════════════════════════════════════
        {
            "number": 3,
            "name": "Mechanics",
            "description": (
                "Covers forces, motion, energy, machines, and moments. "
                "Forms the foundation for understanding how objects move and interact."
            ),
            "topics": [
                # ── Form 1 ──────────────────────────────────────────
                {
                    "title": "Force",
                    "description": "Definition, effects, measurement, friction, mass and weight.",
                    "year_level": 1,
                    "periods": 13,
                    "subtopics": [
                        {"title": "Definition of force"},
                        {"title": "SI units of force"},
                        {"title": "Examples of where force is used"},
                        {"title": "Effects of force on various objects"},
                        {"title": "Measuring force"},
                        {"title": "Frictional force"},
                        {"title": "Mass and weight"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define force as a push or pull that changes the state of motion of an object",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "State the SI unit of force as the newton (N)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Give examples of where force is used in everyday life and industry",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe the effects of force: changing shape, starting/stopping motion, changing speed/direction",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Measure force using a spring balance",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Describe frictional force and its effects on moving objects",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, experiment",
                        },
                        {
                            "objective": "Distinguish between mass (kg) and weight (N) and state W = mg",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, calculation",
                        },
                    ],
                    "resources": [
                        {"text": "Spring balances", "type": "equipment"},
                        {"text": "Trolleys and ramps", "type": "equipment"},
                        {
                            "text": "Blocks and surfaces for friction",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Work",
                    "description": "Definition, SI units, and calculations.",
                    "year_level": 1,
                    "periods": 3,
                    "subtopics": [
                        {"title": "Meaning of work"},
                        {"title": "SI units of work"},
                        {"title": "Relating force to work"},
                        {"title": "Calculations on work"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define work as force times distance in the direction of the force (W = Fd)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "State the SI unit of work as the joule (J)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Explain the relationship between force, displacement, and work done",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Calculate work done in various situations",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Spring balances and metre rules",
                            "type": "equipment",
                        },
                        {"text": "Work calculation worksheets", "type": "reference"},
                    ],
                },
                {
                    "title": "Energy",
                    "description": "Forms, transfer, and sources of energy.",
                    "year_level": 1,
                    "periods": 9,
                    "subtopics": [
                        {"title": "Meaning/definition of energy"},
                        {"title": "Forms of energy"},
                        {"title": "Energy transfer/changes"},
                        {"title": "Calculations on energy changes"},
                        {"title": "Sources of energy (renewable and non-renewable)"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define energy as the capacity to do work and state its SI unit (joule)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Name and describe forms of energy: kinetic, potential, chemical, electrical, heat, light, sound, nuclear",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, examples",
                        },
                        {
                            "objective": "Explain energy transfer and conservation of energy with examples",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Calculate energy changes in various physical situations",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Classify energy sources as renewable (solar, wind, hydro) and non-renewable (fossil fuels, nuclear)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, research",
                        },
                    ],
                    "resources": [
                        {"text": "Energy conversion kits", "type": "equipment"},
                        {"text": "Energy sources charts", "type": "reference"},
                        {"text": "Renewable energy models", "type": "digital"},
                    ],
                },
                # ── Form 2 ──────────────────────────────────────────
                {
                    "title": "Power",
                    "description": "Rate of doing work.",
                    "year_level": 2,
                    "periods": 3,
                    "subtopics": [
                        {"title": "Meaning of power"},
                        {"title": "SI units of power"},
                        {"title": "Calculations on power"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define power as the rate of doing work (P = W/t)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "State the SI unit of power as the watt (W)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Calculate power in various situations using P = W/t and P = Fv",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Stop-watches and spring balances",
                            "type": "equipment",
                        },
                        {"text": "Power calculation worksheets", "type": "reference"},
                    ],
                },
                {
                    "title": "Machines",
                    "description": "Simple machines, levers, inclined planes, pulleys, mechanical advantage.",
                    "year_level": 2,
                    "periods": 19,
                    "subtopics": [
                        {"title": "Definition of a machine"},
                        {"title": "Examples of simple machines"},
                        {"title": "Levers"},
                        {"title": "Inclined planes"},
                        {"title": "Pulleys"},
                        {"title": "Advantages of using machines"},
                        {"title": "Mechanical advantage"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define a machine as a device that makes work easier by changing the magnitude or direction of a force",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Name and give examples of simple machines: levers, inclined planes, pulleys, wheel and axle, wedges, screws",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Explain how levers work and classify levers into first, second, and third class",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, practical",
                        },
                        {
                            "objective": "Explain how inclined planes reduce the effort needed to raise objects",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Explain how pulley systems work (single, compound, block and tackle)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "State the advantages of using machines (force reduction, direction change, distance gain)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Define mechanical advantage as load/effort and calculate it for simple machines",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {"text": "Levers of all three classes", "type": "equipment"},
                        {"text": "Inclined plane with trolley", "type": "equipment"},
                        {
                            "text": "Pulley systems (single and compound)",
                            "type": "equipment",
                        },
                        {"text": "Spring balances", "type": "equipment"},
                    ],
                },
                # ── Form 3 ──────────────────────────────────────────
                {
                    "title": "Scalar and Vector Quantities",
                    "description": "Defining, representing, and resolving vectors.",
                    "year_level": 3,
                    "periods": 8,
                    "subtopics": [
                        {
                            "title": "Scalar and vector quantities",
                            "description": "defining scalar and vector quantities, distance and displacement",
                        },
                        {
                            "title": "Representing vectors",
                            "description": "magnitude and direction",
                        },
                        {
                            "title": "Vector addition and subtraction",
                            "description": "resultant, adding vectors using parallelogram and triangle rules",
                        },
                        {"title": "Resolving vectors"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define scalar quantities (magnitude only) and vector quantities (magnitude and direction)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Give examples of scalar quantities (distance, speed, mass, energy) and vector quantities (displacement, velocity, force, momentum)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Represent vectors using arrows showing magnitude and direction",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Find the resultant of two vectors using the parallelogram rule and the triangle rule",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical, drawing",
                        },
                        {
                            "objective": "Resolve a vector into its perpendicular components",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {"text": "Force board and pulleys", "type": "equipment"},
                        {"text": "Rulers and protractors", "type": "equipment"},
                        {"text": "Graph paper", "type": "reference"},
                    ],
                },
                {
                    "title": "Linear Motion",
                    "description": "Distance, displacement, speed, velocity, acceleration, and graphs.",
                    "year_level": 3,
                    "periods": 18,
                    "subtopics": [
                        {
                            "title": "Distance, displacement, speed, velocity and acceleration",
                            "description": "comparison of distance and displacement, comparison of speed and velocity, definition of acceleration",
                        },
                        {
                            "title": "Experiment to determine velocity and acceleration",
                            "description": "plot graphs of displacement against time",
                        },
                        {
                            "title": "Acceleration due to gravity",
                            "description": "free fall experiment, determination of g by simple pendulum",
                        },
                        {
                            "title": "Motion-time graphs",
                            "description": "distance-time graphs, average speed, speed-time graphs",
                        },
                        {
                            "title": "Equations of uniformly accelerated motion",
                            "description": "equations and numerical problems",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Distinguish between distance (scalar) and displacement (vector)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Distinguish between speed (scalar) and velocity (vector)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Define acceleration as the rate of change of velocity",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Plot and interpret displacement-time graphs",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical, graph analysis",
                        },
                        {
                            "objective": "Determine acceleration due to gravity (g) using a simple free-fall experiment",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Determine g using a simple pendulum method",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Plot and interpret distance-time and speed-time graphs",
                            "cognitive_level": "Application",
                            "teaching_method": "Graph analysis",
                        },
                        {
                            "objective": "Calculate average speed from distance-time data",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "State and apply the equations of uniformly accelerated motion: v = u + at, s = ut + 1/2 at^2, v^2 = u^2 + 2as",
                            "cognitive_level": "Application",
                            "teaching_method": "Lecture, calculation",
                        },
                        {
                            "objective": "Solve numerical problems involving uniformly accelerated motion",
                            "cognitive_level": "Application",
                            "teaching_method": "Exercises",
                        },
                    ],
                    "resources": [
                        {"text": "Ticker-timers", "type": "equipment"},
                        {"text": "Trolley and ramp", "type": "equipment"},
                        {"text": "Stop-watches", "type": "equipment"},
                        {"text": "Pendulum bob and stand", "type": "equipment"},
                        {"text": "Graph paper", "type": "reference"},
                    ],
                },
                # ── Form 4 ──────────────────────────────────────────
                {
                    "title": "Newton's Laws of Motion",
                    "description": "Three laws, applications, inertia, and momentum.",
                    "year_level": 4,
                    "periods": 10,
                    "subtopics": [
                        {
                            "title": "Newton's laws of motion",
                            "description": "the three laws, applications of the laws of motion",
                        },
                        {
                            "title": "Simple experimentations to illustrate inertia",
                            "description": "meaning of inertia, experiment on inertia",
                        },
                        {
                            "title": "Linear momentum",
                            "description": "law of conservation of linear momentum, collisions, problems involving collisions",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "State Newton's first law (law of inertia) and give real-life examples",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "State Newton's second law (F = ma) and apply it to solve problems",
                            "cognitive_level": "Application",
                            "teaching_method": "Lecture, calculation",
                        },
                        {
                            "objective": "State Newton's third law (action-reaction) and identify action-reaction pairs",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Describe simple experiments to illustrate inertia",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Define linear momentum (p = mv) and state the law of conservation of momentum",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Apply conservation of momentum to solve collision problems",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Trolleys and collision apparatus",
                            "type": "equipment",
                        },
                        {
                            "text": "Cards and coins for inertia demos",
                            "type": "equipment",
                        },
                        {"text": "Spring balances", "type": "equipment"},
                    ],
                },
                {
                    "title": "Frictional Force",
                    "description": "Applications, coefficient of friction, and calculations.",
                    "year_level": 4,
                    "periods": 4,
                    "subtopics": [
                        {
                            "title": "Applications of frictional force",
                            "description": "coefficient of friction, calculations using F = mu x N",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe practical applications of frictional force (walking, braking, grip)",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Define the coefficient of friction (mu) and explain its significance",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Calculate frictional force using F = mu x N",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Blocks and surfaces of varying roughness",
                            "type": "equipment",
                        },
                        {"text": "Spring balances", "type": "equipment"},
                    ],
                },
                {
                    "title": "Law of Conservation of Energy",
                    "description": "Interpreting energy graphs and energy conservation.",
                    "year_level": 4,
                    "periods": 4,
                    "subtopics": [
                        {"title": "Law of conservation of energy"},
                        {
                            "title": "Interpretation of graphs relating to energy conservation"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "State the law of conservation of energy: energy cannot be created or destroyed, only transformed",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Interpret graphs showing energy transformations in physical systems",
                            "cognitive_level": "Analysis",
                            "teaching_method": "Graph analysis",
                        },
                        {
                            "objective": "Apply the conservation of energy to solve problems involving mechanical energy",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Energy conversion demonstration kits",
                            "type": "equipment",
                        },
                        {"text": "Graph analysis worksheets", "type": "reference"},
                    ],
                },
                {
                    "title": "Terminal Velocity",
                    "description": "Falling objects and factors affecting terminal velocity.",
                    "year_level": 4,
                    "periods": 3,
                    "subtopics": [
                        {
                            "title": "Meaning of terminal velocity",
                            "description": "falling of objects in a vacuum and in fluids, factors affecting falling objects",
                        },
                        {"title": "Investigation of terminal velocity"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define terminal velocity as the constant speed reached when drag equals weight",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Compare the falling of objects in a vacuum (free fall) and in fluids (with drag)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, simulation",
                        },
                        {
                            "objective": "Identify factors affecting terminal velocity (shape, surface area, mass, fluid density)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Investigate terminal velocity experimentally using falling objects",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Spheres of different sizes and materials",
                            "type": "sample",
                        },
                        {"text": "Stop-watches and metre rules", "type": "equipment"},
                        {"text": "Viscous fluid (oil or glycerine)", "type": "sample"},
                    ],
                },
                {
                    "title": "Hooke's Law",
                    "description": "Effects of force, verification, and applications.",
                    "year_level": 4,
                    "periods": 8,
                    "subtopics": [
                        {
                            "title": "The effects of force",
                            "description": "effects of forces on various objects, demonstration of effects of force",
                        },
                        {
                            "title": "Verification of Hooke's law",
                            "description": "experiment on Hooke's law, extension-load graphs within elastic limit",
                        },
                        {
                            "title": "Limit of proportionality for an elastic solid",
                            "description": "stretching beyond elastic limit, extension-load graphs beyond elastic limit",
                        },
                        {
                            "title": "Application of Hooke's law",
                            "description": "spring balance construction, springs in parallel and series, spring constant, problems",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Demonstrate and describe the effects of force on various objects (compression, extension, bending, torsion)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Verify Hooke's law experimentally by plotting extension-load graphs",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Identify the limit of proportionality and elastic limit from an extension-load graph",
                            "cognitive_level": "Analysis",
                            "teaching_method": "Graph analysis",
                        },
                        {
                            "objective": "Describe what happens when an elastic material is stretched beyond its elastic limit",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, experiment",
                        },
                        {
                            "objective": "Explain the construction and calibration of a spring balance using Hooke's law",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, practical",
                        },
                        {
                            "objective": "Calculate the equivalent spring constant for springs in parallel and in series",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Solve problems involving Hooke's law (F = ke)",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {"text": "Springs of different stiffness", "type": "equipment"},
                        {"text": "Weights and hangers", "type": "equipment"},
                        {"text": "Metre rules", "type": "equipment"},
                        {"text": "Retort stands and clamps", "type": "equipment"},
                    ],
                },
                {
                    "title": "Work, Energy, Power and Machines",
                    "description": "Work at angles, conservation of mechanical energy, and machine efficiency.",
                    "year_level": 4,
                    "periods": 12,
                    "subtopics": [
                        {
                            "title": "Work",
                            "description": "meaning (W = Fd), SI units, work done at an angle (W = F cos theta x d), problems",
                        },
                        {
                            "title": "Energy",
                            "description": "conservation of mechanical energy, energy-work theorem, solving problems",
                        },
                        {
                            "title": "Machines",
                            "description": "meaning of machine, efficiency, mechanical advantage, velocity ratio, calculations, problems",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Calculate work done by a force acting in the direction of motion (W = Fd)",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Calculate work done by a force at an angle to the direction of motion (W = F cos theta x d)",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Solve mathematical problems involving work at angles",
                            "cognitive_level": "Application",
                            "teaching_method": "Exercises",
                        },
                        {
                            "objective": "State the principle of conservation of mechanical energy",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Apply the energy-work theorem to solve problems",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Define efficiency as useful work output / total work input and calculate it",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Define mechanical advantage (load/effort) and velocity ratio (distance moved by effort / distance moved by load)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Calculate efficiency, mechanical advantage, and velocity ratio for machines",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Solve problems involving machines and energy conservation",
                            "cognitive_level": "Application",
                            "teaching_method": "Exercises",
                        },
                    ],
                    "resources": [
                        {"text": "Inclined planes", "type": "equipment"},
                        {"text": "Pulley systems", "type": "equipment"},
                        {"text": "Spring balances", "type": "equipment"},
                        {"text": "Scientific calculators", "type": "equipment"},
                    ],
                },
                {
                    "title": "Uniform Circular Motion",
                    "description": "Angular motion, centripetal force, and applications.",
                    "year_level": 4,
                    "periods": 8,
                    "subtopics": [
                        {
                            "title": "Angular displacement and angular velocity",
                            "description": "difference between angular displacement and velocity, circular motion, relationship between tangential and angular velocity",
                        },
                        {
                            "title": "Centripetal force",
                            "description": "simple experimentations, objects in circular motion",
                        },
                        {
                            "title": "Principles of uniform circular motion",
                            "description": "problems, applications in everyday life",
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define angular displacement and angular velocity",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Explain circular motion and relate tangential velocity to angular velocity (v = r x omega)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Describe experiments to demonstrate centripetal force",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Calculate centripetal force using F = mv^2/r",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Give applications of circular motion in everyday life (satellites, cars on bends, washing machine spinners)",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Balls on strings for centripetal force demo",
                            "type": "equipment",
                        },
                        {"text": "Centripetal force apparatus", "type": "equipment"},
                        {"text": "Satellite orbit simulations", "type": "digital"},
                    ],
                },
                {
                    "title": "Moments of Forces",
                    "description": "Torque, principle of moments, and equilibrium.",
                    "year_level": 4,
                    "periods": 6,
                    "subtopics": [
                        {
                            "title": "Describing moment of a force",
                            "description": "meaning of moments of a force, relationship between force and torque, principle of moments for equilibrium",
                        },
                        {
                            "title": "Verifying the principle of moments using pivots and objects"
                        },
                        {"title": "Applying principle of moments in everyday life"},
                        {"title": "Problems using the principle of moments"},
                        {"title": "Systems involving moments"},
                        {"title": "Centre of mass in lamina and uniform rods"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define the moment of a force as force x perpendicular distance from the pivot (M = Fd)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Explain the relationship between force and torque (turning effect)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "State the principle of moments: sum of clockwise moments equals sum of anticlockwise moments for equilibrium",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Verify the principle of moments experimentally using a pivoted rule",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Apply the principle of moments to solve problems involving beams, levers, and balanced systems",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Give everyday applications of moments (spanners, door handles, balance scales)",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Determine the centre of mass of a lamina and a uniform rod experimentally",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {"text": "Metre rules and pivots", "type": "equipment"},
                        {"text": "Laminas and plumb lines", "type": "equipment"},
                        {"text": "Weights and hangers", "type": "equipment"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════
        # CE 4 — Electricity and Magnetism
        # ═══════════════════════════════════════════════════════════════
        {
            "number": 4,
            "name": "Electricity and Magnetism",
            "description": (
                "Covers electric circuits, electrostatics, and magnetism. "
                "Emphasises practical circuit analysis and real-world applications."
            ),
            "topics": [
                {
                    "title": "Static Electricity",
                    "description": "Electric charge and electrostatic forces.",
                    "year_level": 2,
                    "periods": 10,
                    "subtopics": [
                        {"title": "Electric charge and charging by friction"},
                        {"title": "Conductors and insulators"},
                        {"title": "Electric fields (introduction)"},
                        {"title": "Lightning and electrostatic precipitators"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe charging by friction and identify materials that become positively or negatively charged",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Classify materials as conductors or insulators of electricity",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Draw electric field lines around charged objects",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Explain lightning and the working of an electrostatic precipitator",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, video",
                        },
                    ],
                    "resources": [
                        {"text": "Van de Graaff generator", "type": "equipment"},
                        {"text": "Electroscope", "type": "equipment"},
                        {"text": "Various charged materials", "type": "sample"},
                    ],
                },
                {
                    "title": "Electric Circuits: Basics",
                    "description": "Current, voltage, resistance, and circuit diagrams.",
                    "year_level": 2,
                    "periods": 16,
                    "subtopics": [
                        {"title": "Electric current and the ampere"},
                        {"title": "Potential difference and the volt"},
                        {"title": "Resistance and the ohm"},
                        {"title": "Circuit symbols and diagrams"},
                        {"title": "Series and parallel circuits"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define electric current as the rate of flow of charge (I = Q/t)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Define potential difference as work done per unit charge (V = W/Q)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Define resistance as R = V/I and state its unit (ohm)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Draw and interpret circuit diagrams using standard symbols",
                            "cognitive_level": "Application",
                            "teaching_method": "Practice",
                        },
                        {
                            "objective": "Distinguish between series and parallel connections and calculate total resistance",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation, practical",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Batteries, wires, bulbs, switches",
                            "type": "equipment",
                        },
                        {"text": "Ammeters and voltmeters", "type": "equipment"},
                        {"text": "Circuit board kits", "type": "equipment"},
                    ],
                },
                {
                    "title": "Ohm's Law",
                    "description": "The relationship V = IR and I-V characteristics.",
                    "year_level": 2,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Ohm's law: V = IR"},
                        {"title": "Verifying Ohm's law experimentally"},
                        {"title": "I-V characteristics of resistors"},
                        {"title": "Non-ohmic conductors (filament lamp, diode)"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "State Ohm's law (V = IR) and use it to calculate current, voltage, or resistance",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Verify Ohm's law experimentally by plotting an I-V graph for a resistor",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Describe and explain the I-V characteristics of a filament lamp and diode",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, experiment",
                        },
                    ],
                    "resources": [
                        {"text": "Resistors of different values", "type": "equipment"},
                        {"text": "Filament lamps and diodes", "type": "equipment"},
                        {"text": "Ammeters and voltmeters", "type": "equipment"},
                        {"text": "Rheostats", "type": "equipment"},
                    ],
                },
                {
                    "title": "Electrical Energy and Power",
                    "description": "Energy in circuits, power, and domestic wiring.",
                    "year_level": 3,
                    "periods": 14,
                    "subtopics": [
                        {"title": "Electrical energy: E = VIt"},
                        {"title": "Electrical power: P = VI = I^2 R = V^2 / R"},
                        {"title": "Energy cost calculations"},
                        {"title": "Domestic wiring and safety"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Calculate electrical energy using E = VIt",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Calculate electrical power using P = VI, P = I^2 R, and P = V^2 / R",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Calculate the cost of electricity using energy meter readings and tariff rates",
                            "cognitive_level": "Application",
                            "teaching_method": "Real-life exercise",
                        },
                        {
                            "objective": "Explain domestic circuit wiring (live, neutral, earth) and safety devices (fuses, circuit breakers)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, diagrams",
                        },
                    ],
                    "resources": [
                        {"text": "Electricity meters", "type": "equipment"},
                        {"text": "Tariff information from ESCOM", "type": "reference"},
                        {"text": "Domestic wiring diagrams", "type": "reference"},
                    ],
                },
                {
                    "title": "Electromagnetism",
                    "description": "Magnetic effects of electric current.",
                    "year_level": 3,
                    "periods": 14,
                    "subtopics": [
                        {"title": "Magnetic fields around a straight wire"},
                        {"title": "Right-hand grip rule"},
                        {"title": "Electromagnets and factors affecting strength"},
                        {
                            "title": "Force on a current-carrying conductor in a magnetic field: F = BIL"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the magnetic field pattern around a straight current-carrying wire",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Use the right-hand grip rule to determine the direction of the magnetic field",
                            "cognitive_level": "Application",
                            "teaching_method": "Practice",
                        },
                        {
                            "objective": "Describe how to make an electromagnet and explain factors affecting its strength",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Calculate the force on a conductor using F = BIL",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {"text": "Iron filings and bar magnets", "type": "equipment"},
                        {"text": "Solenoid and iron core", "type": "equipment"},
                        {
                            "text": "Battery, wire, and magnetic field apparatus",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Electromagnetic Induction",
                    "description": "Generating electricity from magnetism.",
                    "year_level": 3,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Faraday's law of electromagnetic induction"},
                        {"title": "Lenz's law"},
                        {"title": "Induced EMF: epsilon = -N x delta-Phi / delta-t"},
                        {"title": "Factors affecting induced EMF"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "State Faraday's law and explain how moving a magnet near a coil induces EMF",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "State Lenz's law and explain the direction of induced current",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Calculate induced EMF using epsilon = -N x delta-Phi / delta-t",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Investigate factors affecting the magnitude of induced EMF",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {"text": "Coils and magnets", "type": "equipment"},
                        {"text": "Galvanometer", "type": "equipment"},
                        {"text": "Iron core", "type": "equipment"},
                    ],
                },
                {
                    "title": "The Transformer",
                    "description": "Changing voltage levels in AC circuits.",
                    "year_level": 4,
                    "periods": 10,
                    "subtopics": [
                        {"title": "Construction of a transformer"},
                        {"title": "Voltage ratio: Vp/Vs = Np/Ns"},
                        {"title": "Step-up and step-down transformers"},
                        {"title": "Power transmission and energy losses"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the construction of a simple transformer using soft iron core and coils",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Apply the transformer equation Vp/Vs = Np/Ns to solve problems",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Distinguish between step-up and step-down transformers and their uses",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Explain energy losses in transformers and why high voltage is used for transmission",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Demo transformers", "type": "equipment"},
                        {"text": "Power transmission diagrams", "type": "reference"},
                    ],
                },
                {
                    "title": "Electric Motors and Generators",
                    "description": "Conversion between electrical and mechanical energy.",
                    "year_level": 4,
                    "periods": 12,
                    "subtopics": [
                        {"title": "DC motor: construction and principle"},
                        {"title": "AC generator: construction and principle"},
                        {"title": "Back EMF in motors"},
                        {"title": "Applications in Malawi"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the construction and working principle of a DC motor",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Explain how an AC generator converts mechanical energy to electrical energy",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Explain back EMF and its effect on motor current",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Discuss applications of motors and generators in Malawi (water pumps, maize mills)",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "DC motor kit", "type": "equipment"},
                        {"text": "Hand-cranked generator", "type": "equipment"},
                        {
                            "text": "Videos of motors and generators in use",
                            "type": "digital",
                        },
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════
        # CE 5 — Oscillation and Waves
        # ═══════════════════════════════════════════════════════════════
        {
            "number": 5,
            "name": "Oscillation and Waves",
            "description": (
                "Covers wave phenomena including sound, light, and the electromagnetic "
                "spectrum. Links wave theory to practical applications."
            ),
            "topics": [
                {
                    "title": "Wave Properties",
                    "description": "Transverse and longitudinal waves.",
                    "year_level": 2,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Transverse waves: water, light, S-waves"},
                        {"title": "Longitudinal waves: sound, P-waves"},
                        {
                            "title": "Wave terminology: amplitude, wavelength, frequency, period"
                        },
                        {"title": "Wave equation: v = f x lambda"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Distinguish between transverse and longitudinal waves with examples",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Define amplitude, wavelength, frequency, and period of a wave",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Apply the wave equation v = f x lambda to solve problems",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Determine the frequency and wavelength of waves using a ripple tank",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {"text": "Ripple tank", "type": "equipment"},
                        {"text": "Slinky springs", "type": "equipment"},
                        {"text": "Tuning forks", "type": "equipment"},
                    ],
                },
                {
                    "title": "Reflection and Refraction of Light",
                    "description": "Behaviour of light at boundaries.",
                    "year_level": 3,
                    "periods": 14,
                    "subtopics": [
                        {"title": "Laws of reflection"},
                        {"title": "Plane and curved mirrors"},
                        {
                            "title": "Refraction and Snell's law: n1 x sin(theta1) = n2 x sin(theta2)"
                        },
                        {"title": "Total internal reflection"},
                        {"title": "Optical fibres"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "State the laws of reflection and verify them experimentally",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Locate images formed by plane and curved mirrors using ray diagrams",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Apply Snell's law to solve refraction problems",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Explain total internal reflection and its application in optical fibres",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                    ],
                    "resources": [
                        {"text": "Plane and curved mirrors", "type": "equipment"},
                        {
                            "text": "Glass blocks and semicircular blocks",
                            "type": "equipment",
                        },
                        {"text": "Light ray boxes", "type": "equipment"},
                        {
                            "text": "Optical fibre demonstration kit",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Sound Waves",
                    "description": "Properties and applications of sound.",
                    "year_level": 3,
                    "periods": 10,
                    "subtopics": [
                        {"title": "Production and propagation of sound"},
                        {"title": "Speed of sound in different media"},
                        {"title": "Echoes and reverberation"},
                        {"title": "Applications: ultrasound, sonar"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Explain how sound is produced by vibration and travels through media",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Measure the speed of sound in air using an echo method",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Distinguish between echoes and reverberation",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe applications of ultrasound in medicine and sonar in navigation",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion, video",
                        },
                    ],
                    "resources": [
                        {"text": "Tuning forks", "type": "equipment"},
                        {"text": "Stop-watches", "type": "equipment"},
                        {"text": "Ultrasonic sensor kit", "type": "equipment"},
                    ],
                },
                {
                    "title": "Electromagnetic Spectrum",
                    "description": "Types of electromagnetic radiation.",
                    "year_level": 3,
                    "periods": 12,
                    "subtopics": [
                        {
                            "title": "The EM spectrum: radio, microwave, IR, visible, UV, X-ray, gamma"
                        },
                        {"title": "Properties and uses of each region"},
                        {"title": "Dangers of UV, X-rays, and gamma rays"},
                        {
                            "title": "Malawi context: radio communication, medical X-rays"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "List the regions of the EM spectrum in order of increasing frequency",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "State the properties and uses of each region of the EM spectrum",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, research",
                        },
                        {
                            "objective": "Explain the dangers of overexposure to UV, X-rays, and gamma rays",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Discuss uses of EM waves in Malawi: radio broadcasting, mobile phones, medical imaging",
                            "cognitive_level": "Application",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "EM spectrum chart", "type": "reference"},
                        {"text": "UV lamp demonstration", "type": "equipment"},
                        {"text": "X-ray images (medical)", "type": "reference"},
                    ],
                },
                {
                    "title": "Wave Phenomena",
                    "description": "Diffraction, interference, and polarisation.",
                    "year_level": 4,
                    "periods": 14,
                    "subtopics": [
                        {"title": "Diffraction of waves"},
                        {"title": "Superposition and interference"},
                        {"title": "Young's double slit experiment"},
                        {"title": "Diffraction gratings"},
                        {"title": "Polarisation of light"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Explain diffraction and describe how wavelength affects diffraction",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Explain the principle of superposition and constructive/destructive interference",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Apply Young's double slit formula lambda = ax/D to calculate wavelength",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Explain how a diffraction grating works and use n x lambda = d x sin(theta)",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical, calculation",
                        },
                        {
                            "objective": "Demonstrate polarisation using two polarising filters",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {"text": "Young's double slit apparatus", "type": "equipment"},
                        {"text": "Diffraction gratings", "type": "equipment"},
                        {"text": "Polarising filters", "type": "equipment"},
                        {"text": "Laser pointer (low power)", "type": "equipment"},
                    ],
                },
                {
                    "title": "Optical Instruments",
                    "description": "Lenses and optical devices.",
                    "year_level": 4,
                    "periods": 10,
                    "subtopics": [
                        {"title": "Converging and diverging lenses"},
                        {"title": "Thin lens formula: 1/f = 1/v - 1/u"},
                        {"title": "Magnifying glass and microscope"},
                        {"title": "The eye and vision defects"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Distinguish between converging (convex) and diverging (concave) lenses",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Apply the thin lens formula 1/f = 1/v - 1/u to locate images",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Explain the construction and magnification of a microscope",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, diagram",
                        },
                        {
                            "objective": "Describe how the eye forms images and explain myopia and hypermetropia with corrections",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Converging and diverging lenses",
                            "type": "equipment",
                        },
                        {"text": "Optical bench", "type": "equipment"},
                        {"text": "Eye model diagram", "type": "reference"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════
        # CE 6 — Nuclear Physics
        # ═══════════════════════════════════════════════════════════════
        {
            "number": 6,
            "name": "Nuclear Physics",
            "description": (
                "Introduction to atomic structure, radioactivity, and nuclear "
                "energy. Covers the structure of the atom and applications "
                "of nuclear physics."
            ),
            "topics": [
                {
                    "title": "Atomic Structure",
                    "description": "Models of the atom.",
                    "year_level": 2,
                    "periods": 10,
                    "subtopics": [
                        {"title": "Thomson's plum pudding model"},
                        {"title": "Rutherford's alpha scattering experiment"},
                        {"title": "Bohr model of the atom"},
                        {"title": "Nucleus: protons, neutrons, and electrons"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe Thomson's plum pudding model and its limitations",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Explain Rutherford's alpha scattering experiment and its conclusions",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, simulation",
                        },
                        {
                            "objective": "Describe the Bohr model and its significance",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Identify protons, neutrons, and electrons and state their relative charges and masses",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                    ],
                    "resources": [
                        {"text": "Atomic model diagrams", "type": "reference"},
                        {"text": "Alpha scattering simulation", "type": "digital"},
                        {"text": "Ball models of atoms", "type": "equipment"},
                    ],
                },
                {
                    "title": "Radioactivity",
                    "description": "Types of radioactive decay.",
                    "year_level": 3,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Alpha, beta, and gamma radiation"},
                        {"title": "Properties and penetrating power of each type"},
                        {"title": "Detection using Geiger-Muller counter"},
                        {"title": "Background radiation"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the properties of alpha, beta, and gamma radiation",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "Compare the penetrating power of alpha, beta, and gamma rays",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Use a Geiger-Muller counter to detect radiation",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Describe sources of background radiation",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Geiger-Muller counter", "type": "equipment"},
                        {"text": "Sealed radioactive sources", "type": "equipment"},
                        {"text": "Aluminium foil, paper, lead sheet", "type": "sample"},
                    ],
                },
                {
                    "title": "Nuclear Reactions",
                    "description": "Nuclear equations and reactions.",
                    "year_level": 4,
                    "periods": 14,
                    "subtopics": [
                        {"title": "Alpha decay equations"},
                        {"title": "Beta decay equations"},
                        {"title": "Gamma emission"},
                        {"title": "Nuclear fission"},
                        {"title": "Nuclear fusion"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Write balanced nuclear equations for alpha decay",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Write balanced nuclear equations for beta decay",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Explain gamma emission and its use in medicine and industry",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe nuclear fission and its use in nuclear power stations",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, video",
                        },
                        {
                            "objective": "Explain nuclear fusion and its occurrence in the Sun",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Nuclear decay equation worksheets",
                            "type": "reference",
                        },
                        {"text": "Nuclear power station videos", "type": "digital"},
                        {"text": "Fusion and fission diagrams", "type": "reference"},
                    ],
                },
                {
                    "title": "Radioactivity: Half-Life and Applications",
                    "description": "Radioactive decay calculations and uses.",
                    "year_level": 4,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Radioactive decay law and half-life"},
                        {"title": "Calculating remaining activity"},
                        {"title": "Carbon-14 dating"},
                        {"title": "Medical applications: radiotherapy, tracers"},
                        {"title": "Nuclear waste and safety"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define half-life and explain the exponential decay of radioactive substances",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Calculate the remaining activity of a radioactive source after a given number of half-lives",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Explain how carbon-14 dating is used to determine the age of archaeological specimens",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe medical applications of radioactivity: radiotherapy for cancer, radioactive tracers in diagnosis",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, video",
                        },
                        {
                            "objective": "Discuss the issues of nuclear waste disposal and radiation safety",
                            "cognitive_level": "Evaluation",
                            "teaching_method": "Discussion, debate",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Half-life calculation worksheets",
                            "type": "reference",
                        },
                        {"text": "Carbon dating information", "type": "reference"},
                        {"text": "Medical imaging videos", "type": "digital"},
                    ],
                },
            ],
        },
    ],
}


async def seed_physics_syllabus():
    """Seed the Malawi Physics syllabus. Idempotent — skips if already seeded."""
    async with async_session() as db:
        existing = await db.execute(
            select(SyllabusSubject).where(SyllabusSubject.slug == "physics")
        )
        if existing.scalar_one_or_none():
            return

        data = PHYSICS_SYLLABUS
        subject_data = data["subject"]
        subject = SyllabusSubject(
            name=subject_data["name"],
            slug=subject_data["slug"],
            description=subject_data.get("description", ""),
            icon=subject_data.get("icon", "bolt_rounded"),
            color=subject_data.get("color", "#3B82F6"),
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

                subtopic_los = topic_data.get("learning_objectives", [])
                sub_list = topic_data.get("subtopics", [])

                subs = []
                for s_idx, sub_data in enumerate(sub_list):
                    sub = SyllabusSubtopic(
                        topic_id=topic.id,
                        title=sub_data["title"]
                        if isinstance(sub_data, dict)
                        else sub_data,
                        description=sub_data.get("description", "")
                        if isinstance(sub_data, dict)
                        else "",
                        order_index=s_idx,
                    )
                    db.add(sub)
                    await db.flush()
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
