"""Malawi Physics Syllabus (Forms 1-4) — seed data and population.

Matches the official MoEST scope and sequence chart.
CEs 1-3 are from the provided syllabus table; CEs 4-6 are from the
official MoEST scope & sequence chart.
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
        # ════════════════════════════════════════════════════════════════════
        # CE 1 ΓÇö Scientific Investigations and Skills
        # ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
        {
            "number": 1,
            "name": "Scientific Investigations and Skills",
            "description": (
                "Develops learners' ability to plan, conduct, analyse, and report "
                "scientific investigations. Emphasises safety, measurement accuracy, "
                "graphical analysis, and the use of basic laboratory equipment."
            ),
            "topics": [
                # ΓöÇΓöÇ Form 1 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
                # ΓöÇΓöÇ Form 2 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
                # ΓöÇΓöÇ Form 3 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
                # ΓöÇΓöÇ Form 4 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
        # ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
        # CE 2 ΓÇö Properties of Matter
        # ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
        {
            "number": 2,
            "name": "Properties of Matter",
            "description": (
                "Explores the structure, states, and physical properties of matter "
                "including density, pressure, thermal behaviour, and the kinetic theory."
            ),
            "topics": [
                # ΓöÇΓöÇ Form 1 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
                # ΓöÇΓöÇ Form 2 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
                # ΓöÇΓöÇ Form 3 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
                # ΓöÇΓöÇ Form 4 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
        # ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
        # CE 3 ΓÇö Mechanics
        # ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
        {
            "number": 3,
            "name": "Mechanics",
            "description": (
                "Covers forces, motion, energy, machines, and moments. "
                "Forms the foundation for understanding how objects move and interact."
            ),
            "topics": [
                # ΓöÇΓöÇ Form 1 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
                # ΓöÇΓöÇ Form 2 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
                # ΓöÇΓöÇ Form 3 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
                # ΓöÇΓöÇ Form 4 ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
        # ════════════════════════════════════════════════════════════════════
        # CE 4 -- Electricity and Magnetism (MoEST official scope & sequence)
        # ════════════════════════════════════════════════════════════════════
        {
            "number": 4,
            "name": "Electricity and Magnetism",
            "description": "Covers electric current, circuits, electrostatics, magnetism, electromagnetism, electromagnetic induction, resistance, digital electronics, and domestic electricity.",
            "topics": [
                {
                    "title": "Electric Current",
                    "description": "Fundamentals of electric current and simple circuits.",
                    "year_level": 1,
                    "periods": 11,
                    "subtopics": [
                        {"title": "Meaning of electric current and its units"},
                        {"title": "Simple electric circuits"},
                        {
                            "title": "Components of electric circuits (cell, ammeter, voltmeter, resistor, connecting wires, bulb, switches)"
                        },
                        {"title": "Basic circuit symbols"},
                        {"title": "Measuring electric current"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define electric current as the rate of flow of charge",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "State the SI unit of electric current (ampere)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Draw simple electric circuits using standard symbols",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Identify components of electric circuits",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Measure electric current using an ammeter",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {"text": "Cells and connecting wires", "type": "equipment"},
                        {"text": "Ammeters", "type": "equipment"},
                        {"text": "Circuit symbol chart", "type": "reference"},
                    ],
                },
                {
                    "title": "Voltage",
                    "description": "Potential difference in series and parallel circuits.",
                    "year_level": 1,
                    "periods": 6,
                    "subtopics": [
                        {"title": "Measuring voltage"},
                        {"title": "Voltage in series and parallel circuits"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define voltage/potential difference",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Measure voltage using a voltmeter",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Compare voltage in series and parallel circuits",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment, discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Voltmeters", "type": "equipment"},
                        {"text": "Cells, wires, bulbs", "type": "equipment"},
                        {"text": "Circuit board kits", "type": "equipment"},
                    ],
                },
                {
                    "title": "Electrical Resistance",
                    "description": "Definition and factors affecting resistance.",
                    "year_level": 1,
                    "periods": 7,
                    "subtopics": [
                        {"title": "Definition of electrical resistance"},
                        {"title": "Factors affecting electrical resistance"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define electrical resistance and state its SI unit (ohm)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Describe factors affecting electrical resistance (length, cross-sectional area, material, temperature)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment, discussion",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Resistance wire samples of different lengths and gauges",
                            "type": "equipment",
                        },
                        {"text": "Rheostats", "type": "equipment"},
                        {"text": "Ammeters and voltmeters", "type": "equipment"},
                    ],
                },
                {
                    "title": "Effects of Electric Current",
                    "description": "Heating, magnetic, and chemical effects; cells and batteries.",
                    "year_level": 1,
                    "periods": 9,
                    "subtopics": [
                        {"title": "Heating effect"},
                        {"title": "Magnetic effect"},
                        {"title": "Chemical effect"},
                        {"title": "Cells and batteries (types, care and maintenance)"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the heating effect of electric current",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Describe the magnetic effect of electric current",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Describe the chemical effect of electric current",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Distinguish between wet and dry cells",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "Describe care and maintenance of cells/batteries",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Wet and dry cells", "type": "equipment"},
                        {"text": "Heating element and ammeter", "type": "equipment"},
                        {"text": "Magnetic compass", "type": "equipment"},
                    ],
                },
                {
                    "title": "Magnets",
                    "description": "Properties, laws, poles, and field patterns of magnets.",
                    "year_level": 1,
                    "periods": 6,
                    "subtopics": [
                        {"title": "Properties of magnets"},
                        {"title": "Basic law of magnetism"},
                        {"title": "Poles of magnets"},
                        {"title": "Magnetic field patterns"},
                        {"title": "Care and uses of magnets"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "State the properties of magnets",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "State the basic law of magnetism (like poles repel, unlike poles attract)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Identify poles of magnets",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Draw magnetic field patterns around magnets",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Describe proper care of magnets",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Give everyday uses of magnets",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Bar magnets", "type": "equipment"},
                        {"text": "Iron filings", "type": "equipment"},
                        {"text": "Magnetic field diagram sheets", "type": "reference"},
                    ],
                },
                {
                    "title": "Electrostatics",
                    "description": "Principles of electrostatics, charging methods, and Coulomb's law.",
                    "year_level": 2,
                    "periods": 6,
                    "subtopics": [
                        {"title": "Structure of the atom (charged particles)"},
                        {"title": "Description of electrostatics"},
                        {"title": "Charging by friction"},
                        {"title": "Electric field"},
                        {"title": "Insulators and conductors"},
                        {"title": "Earthing"},
                        {"title": "Detection of charge using an electroscope"},
                        {"title": "Charging by induction"},
                        {"title": "Charging by contact"},
                        {"title": "Coulomb's law (descriptive only)"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the structure of the atom in terms of charged particles",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Explain electrostatics as the study of stationary electric charges",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Demonstrate charging by friction",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Draw electric field lines around charged objects",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Distinguish between insulators and conductors in terms of charging",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment, discussion",
                        },
                        {
                            "objective": "Explain earthing and its purpose",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Detect electric charge using an electroscope",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Demonstrate charging by induction",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Demonstrate charging by contact",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Describe Coulomb's law qualitatively (force between charges depends on magnitude and distance)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Van de Graaff generator", "type": "equipment"},
                        {"text": "Gold-leaf electroscope", "type": "equipment"},
                        {"text": "Charged rods (glass, ebonite)", "type": "equipment"},
                    ],
                },
                {
                    "title": "Role of Electrostatics in Everyday Life",
                    "description": "Dangers and applications of electrostatics.",
                    "year_level": 2,
                    "periods": 0,
                    "subtopics": [
                        {"title": "Dangers of electrostatics"},
                        {
                            "title": "Applications of electrostatics (precipitators, photocopiers, spray painting)"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe dangers of electrostatics (sparks near flammable materials)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Give applications of electrostatics (electrostatic precipitators, photocopiers, spray painting)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, video",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Electrostatics application diagrams",
                            "type": "reference",
                        },
                        {
                            "text": "Video: electrostatic precipitator",
                            "type": "digital",
                        },
                        {
                            "text": "Spray painting demonstration kit",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Current Electricity",
                    "description": "Electric current, units, direction, and circuit diagrams.",
                    "year_level": 3,
                    "periods": 2,
                    "subtopics": [
                        {"title": "Definition of electric current"},
                        {"title": "Units of electric current"},
                        {"title": "Direction of electric current"},
                        {"title": "Using the equation I = Q/t"},
                        {"title": "Circuit symbols and circuit diagrams"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define electric current as the rate of flow of charge",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "State the units of electric current",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Distinguish between conventional current and electron flow",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, diagram",
                        },
                        {
                            "objective": "Calculate current using I = Q/t",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Draw circuit diagrams using standard symbols",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                    ],
                    "resources": [
                        {"text": "Circuit diagram worksheets", "type": "reference"},
                        {"text": "Ammeters and cells", "type": "equipment"},
                        {"text": "Circuit symbol chart", "type": "reference"},
                    ],
                },
                {
                    "title": "Electrical Potential Difference",
                    "description": "Potential difference, EMF, and measurements.",
                    "year_level": 3,
                    "periods": 2,
                    "subtopics": [
                        {"title": "Definition of potential difference"},
                        {"title": "SI units of potential difference"},
                        {"title": "Definition of electromotive force"},
                        {"title": "Potential difference measurements"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define potential difference",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "State SI units of potential difference (volt)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Define electromotive force (EMF)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Measure potential difference in circuits",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {"text": "Voltmeters", "type": "equipment"},
                        {"text": "Cells, wires, bulbs", "type": "equipment"},
                        {"text": "Potential difference worksheet", "type": "reference"},
                    ],
                },
                {
                    "title": "Magnetism",
                    "description": "Magnetisation, demagnetisation, and domains.",
                    "year_level": 3,
                    "periods": 2,
                    "subtopics": [
                        {"title": "Magnetisation and demagnetisation"},
                        {"title": "Domains"},
                        {
                            "title": "Experiments to illustrate magnetisation and demagnetisation"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Explain magnetisation in terms of domain alignment",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Explain demagnetisation methods",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Conduct experiments to illustrate magnetisation and demagnetisation",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                    ],
                    "resources": [
                        {"text": "Bar magnets and steel rods", "type": "equipment"},
                        {"text": "Hammer", "type": "equipment"},
                        {"text": "Domain model diagrams", "type": "reference"},
                    ],
                },
                {
                    "title": "Electromagnetism",
                    "description": "Electromagnets, field patterns, and Fleming's left-hand rule.",
                    "year_level": 3,
                    "periods": 12,
                    "subtopics": [
                        {"title": "Investigation of electromagnetism"},
                        {"title": "Field patterns of electromagnets"},
                        {"title": "Magnetic fields of current-carrying conductors"},
                        {
                            "title": "Force on current-carrying conductor in a magnetic field (descriptive)"
                        },
                        {"title": "Fleming's left-hand rule"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Investigate electromagnetism experimentally",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Draw field patterns of electromagnets",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Describe magnetic fields around current-carrying conductors",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration, diagram",
                        },
                        {
                            "objective": "Describe the force on a current-carrying conductor in a magnetic field",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Apply Fleming's left-hand rule to determine force direction",
                            "cognitive_level": "Application",
                            "teaching_method": "Practice",
                        },
                    ],
                    "resources": [
                        {"text": "Solenoid and iron core", "type": "equipment"},
                        {"text": "Bar magnets and iron filings", "type": "equipment"},
                        {
                            "text": "Battery, wire, and magnetic field apparatus",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Uses of Electromagnetism",
                    "description": "Electromagnetic induction, Faraday's and Lenz's laws, generators and motors.",
                    "year_level": 3,
                    "periods": 0,
                    "subtopics": [
                        {"title": "Electromagnetic induction (experiments)"},
                        {
                            "title": "Factors affecting magnitude and direction of induced EMF"
                        },
                        {"title": "Faraday's and Lenz's laws (descriptive)"},
                        {"title": "AC and DC generators"},
                        {"title": "DC motor"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Demonstrate electromagnetic induction experimentally",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Describe factors affecting the magnitude and direction of induced EMF",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment, discussion",
                        },
                        {
                            "objective": "State Faraday's law of electromagnetic induction qualitatively",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "State Lenz's law qualitatively",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Distinguish between AC and DC generators",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, diagram",
                        },
                        {
                            "objective": "Describe the working principle of a DC motor",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Coils and magnets for induction",
                            "type": "equipment",
                        },
                        {"text": "Galvanometer", "type": "equipment"},
                        {"text": "DC motor and generator models", "type": "equipment"},
                    ],
                },
                {
                    "title": "Resistance",
                    "description": "Ohm's law, resistance measurements, colour codes, and internal resistance.",
                    "year_level": 4,
                    "periods": 8,
                    "subtopics": [
                        {
                            "title": "Definition of electrical resistance and its SI units"
                        },
                        {"title": "Factors affecting electrical resistance"},
                        {"title": "Ohm's law"},
                        {"title": "Verification of Ohm's law"},
                        {"title": "Electrical resistance measurements"},
                        {"title": "Calculation of resistance using Ohm's law"},
                        {"title": "Resistor colour codes and standard notation"},
                        {"title": "Internal resistance of a cell"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define resistance and state its SI unit (ohm)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Describe factors affecting resistance",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment, discussion",
                        },
                        {
                            "objective": "State Ohm's law (V = IR)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Verify Ohm's law experimentally",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Measure resistance in circuits",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Calculate resistance using Ohm's law",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Read resistor colour codes",
                            "cognitive_level": "Application",
                            "teaching_method": "Practice",
                        },
                        {
                            "objective": "Explain internal resistance of a cell",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, experiment",
                        },
                    ],
                    "resources": [
                        {"text": "Resistors of different values", "type": "equipment"},
                        {"text": "Resistor colour code chart", "type": "reference"},
                        {
                            "text": "Ammeters, voltmeters, and rheostats",
                            "type": "equipment",
                        },
                        {
                            "text": "Cells for internal resistance experiment",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Electric Circuits, Power and Energy",
                    "description": "Series/parallel circuits, power, energy, domestic electricity.",
                    "year_level": 4,
                    "periods": 8,
                    "subtopics": [
                        {"title": "Circuit symbols and circuit diagrams"},
                        {"title": "Resistors in series and parallel"},
                        {"title": "Net effect of resistors in series and parallel"},
                        {
                            "title": "Electric currents and voltages in series and parallel"
                        },
                        {"title": "Electric power (power ratings, derived equations)"},
                        {"title": "Electric energy (kWh, cost, ESCOM bills)"},
                        {"title": "Experiment on heating effect"},
                        {"title": "Electrical hazards and safety"},
                        {"title": "Three-pin plugs"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Draw circuit diagrams using standard symbols",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Calculate net resistance in series circuits",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Calculate net resistance in parallel circuits",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Calculate currents and voltages in series and parallel circuits",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation, practical",
                        },
                        {
                            "objective": "Calculate electrical power using P = VI, P = I^2R, P = V^2/R",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Calculate electric energy in kilowatt-hours",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Calculate cost of electric energy",
                            "cognitive_level": "Application",
                            "teaching_method": "Real-life exercise",
                        },
                        {
                            "objective": "Interpret ESCOM electric energy bills",
                            "cognitive_level": "Application",
                            "teaching_method": "Real-life exercise",
                        },
                        {
                            "objective": "Describe the heating effect of electric current experimentally",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Identify electrical hazards and safety measures",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe the function of a three-pin plug",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration",
                        },
                    ],
                    "resources": [
                        {"text": "Resistors, cells, wires, bulbs", "type": "equipment"},
                        {"text": "Electricity meter", "type": "equipment"},
                        {"text": "ESCOM tariff information", "type": "reference"},
                        {
                            "text": "Three-pin plug and wiring diagram",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Introduction to Digital Electronics",
                    "description": "Semiconductors, diodes, transistors, and logic gates.",
                    "year_level": 4,
                    "periods": 15,
                    "subtopics": [
                        {"title": "Meaning of digital electronics"},
                        {
                            "title": "Differences between conductors/semiconductors/insulators (Band Theory)"
                        },
                        {"title": "Intrinsic vs extrinsic semiconductors"},
                        {"title": "Doping (N-type and P-type)"},
                        {"title": "Operation of P-N junction diode"},
                        {"title": "I-V characteristics of forward biased diode"},
                        {"title": "Half-wave and full-wave rectification"},
                        {"title": "Bipolar transistor (N-P-N)"},
                        {"title": "Light operated switch"},
                        {"title": "Electronic components and their uses"},
                        {"title": "Symbols for electronic devices"},
                        {"title": "Difference between analogue and digital circuits"},
                        {"title": "Characteristics of analogue and digital signals"},
                        {
                            "title": "Basic logic gates (operations, truth tables, symbols)"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define digital electronics",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Explain differences between conductors, semiconductors and insulators using band theory",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Distinguish between intrinsic and extrinsic semiconductors",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Explain doping and distinguish N-type and P-type",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Describe the operation of a P-N junction diode",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "Sketch I-V characteristics of a forward biased diode",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise, practical",
                        },
                        {
                            "objective": "Explain half-wave and full-wave rectification using diodes",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "Describe the basic structure and operation of a bipolar transistor",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Explain the working of a light operated switch",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Identify common electronic components and their symbols",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Distinguish between analogue and digital circuits",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe characteristics of analogue and digital signals",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, diagram",
                        },
                        {
                            "objective": "State the operations of AND, OR, NOT, NAND, NOR gates",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, practice",
                        },
                        {
                            "objective": "Construct truth tables for basic logic gates",
                            "cognitive_level": "Application",
                            "teaching_method": "Practice",
                        },
                        {
                            "objective": "Draw symbols for basic logic gates",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                    ],
                    "resources": [
                        {"text": "P-N junction diodes", "type": "equipment"},
                        {"text": "Bipolar transistors", "type": "equipment"},
                        {"text": "Logic gate ICs (74 series)", "type": "equipment"},
                        {
                            "text": "Breadboard and connecting wires",
                            "type": "equipment",
                        },
                        {"text": "Band theory diagram", "type": "reference"},
                    ],
                },
            ],
        },
        {
            "number": 5,
            "name": "Oscillation and Waves",
            "description": "Covers light, sound, oscillations, waves, the electromagnetic spectrum, and lenses. Links wave theory to practical applications including optical instruments and the human eye.",
            "topics": [
                {
                    "title": "Light",
                    "description": "Rectilinear propagation, reflection, and refraction of light.",
                    "year_level": 2,
                    "periods": 20,
                    "subtopics": [
                        {"title": "Rectilinear propagation of light"},
                        {
                            "title": "Formation of shadows and eclipses (umbra and penumbra)"
                        },
                        {"title": "Pin-hole camera"},
                        {"title": "Image formation and magnification"},
                        {"title": "Reflection"},
                        {
                            "title": "Images formed by plane mirrors (ray diagrams, parallel and inclined mirrors)"
                        },
                        {"title": "Periscope"},
                        {
                            "title": "Problems on pin-hole camera and mirrors inclined at an angle"
                        },
                        {"title": "Refraction"},
                        {
                            "title": "Effects of refraction (apparent depth, dispersion, bending of immersed object)"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe rectilinear propagation of light with examples",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Explain the formation of shadows and eclipses including umbra and penumbra",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, diagram",
                        },
                        {
                            "objective": "Describe the principle of a pin-hole camera",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Calculate magnification for pin-hole camera images",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "State the laws of reflection",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Draw ray diagrams for images formed by plane mirrors",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Explain image formation by plane mirrors",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, diagram",
                        },
                        {
                            "objective": "Describe a periscope and its working principle",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Solve problems involving pin-hole cameras",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Describe refraction of light at boundaries",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment, discussion",
                        },
                        {
                            "objective": "Explain apparent depth due to refraction",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Describe dispersion of white light through a prism",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Explain the bending shape of an immersed object due to refraction",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                    ],
                    "resources": [
                        {"text": "Pin-hole camera kit", "type": "equipment"},
                        {
                            "text": "Plane mirrors (rectangular and inclined)",
                            "type": "equipment",
                        },
                        {"text": "Glass prism", "type": "equipment"},
                        {"text": "Light ray box", "type": "equipment"},
                    ],
                },
                {
                    "title": "Sound",
                    "description": "Production, transmission, and properties of sound.",
                    "year_level": 2,
                    "periods": 7,
                    "subtopics": [
                        {"title": "Production of sound by vibrating objects"},
                        {"title": "Loudness and pitch of sound"},
                        {"title": "Free and forced vibrations and resonance"},
                        {"title": "Transmission of sound (matter and vacuum)"},
                        {
                            "title": "Nature of sound waves (compressions and rarefactions)"
                        },
                        {"title": "Determination of speed of sound in air"},
                        {"title": "Sound transmission in gases, liquids and solids"},
                        {"title": "Factors affecting speed of sound"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Explain how sound is produced by vibrating objects",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Distinguish between loudness and pitch of sound",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration, discussion",
                        },
                        {
                            "objective": "Explain free and forced vibrations, natural frequency and resonance",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment, discussion",
                        },
                        {
                            "objective": "Describe how sound requires a medium for transmission",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Describe sound waves in terms of compressions and rarefactions",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Determine the speed of sound in air experimentally",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Compare sound transmission in gases, liquids and solids",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Solve problems involving velocity of sound",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Describe factors affecting the speed of sound",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Tuning forks", "type": "equipment"},
                        {
                            "text": "Slinky springs (longitudinal wave model)",
                            "type": "equipment",
                        },
                        {
                            "text": "Stop-watches and measuring tape",
                            "type": "equipment",
                        },
                        {"text": "Vacuum jar demonstration set", "type": "equipment"},
                    ],
                },
                {
                    "title": "Oscillations",
                    "description": "Pendulum and spring oscillations, period, and frequency.",
                    "year_level": 3,
                    "periods": 4,
                    "subtopics": [
                        {"title": "Oscillations in a pendulum and loaded spring"},
                        {"title": "Amplitude, displacement, period and frequency"},
                        {
                            "title": "Factors affecting frequency of an oscillating system"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe oscillations in a simple pendulum and loaded spring",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Define amplitude, displacement, period and frequency of oscillation",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Describe factors affecting frequency of a pendulum (length, mass)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Describe factors affecting frequency of a loaded spring (spring constant, load)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Simple pendulum (string, bob, stand)",
                            "type": "equipment",
                        },
                        {"text": "Springs and masses", "type": "equipment"},
                        {"text": "Stop-watches", "type": "equipment"},
                    ],
                },
                {
                    "title": "Waves",
                    "description": "Wave description, types, and wave properties.",
                    "year_level": 3,
                    "periods": 8,
                    "subtopics": [
                        {"title": "Description of a wave"},
                        {"title": "Meaning of a wave"},
                        {"title": "Characteristics of a wave"},
                        {"title": "Transverse and longitudinal waves"},
                        {
                            "title": "Differences between transverse and longitudinal waves"
                        },
                        {
                            "title": "Wave properties (reflection, refraction, diffraction, interference)"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define a wave as a disturbance that transfers energy",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Describe the characteristics of a wave (amplitude, wavelength, frequency, period)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Distinguish between transverse and longitudinal waves with examples",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, demonstration",
                        },
                        {
                            "objective": "Give examples of transverse and longitudinal waves",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe reflection of waves",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Describe refraction of waves",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                        {
                            "objective": "Describe diffraction of waves",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment, demonstration",
                        },
                        {
                            "objective": "Describe interference of waves",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Experiment",
                        },
                    ],
                    "resources": [
                        {"text": "Ripple tank", "type": "equipment"},
                        {"text": "Slinky springs", "type": "equipment"},
                        {"text": "Wave diagram charts", "type": "reference"},
                    ],
                },
                {
                    "title": "Electromagnetic Waves",
                    "description": "EM spectrum, properties, sources, and applications.",
                    "year_level": 3,
                    "periods": 6,
                    "subtopics": [
                        {
                            "title": "Electromagnetic spectrum (energy, frequency, wavelength, sources)"
                        },
                        {"title": "Properties of electromagnetic waves"},
                        {"title": "Methods of detecting EM waves"},
                        {"title": "Applications of EM waves"},
                        {"title": "Problems using c = f x lambda"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "List the regions of the EM spectrum",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Describe the relationship between energy, frequency and wavelength",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Identify sources of electromagnetic waves",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "State properties of electromagnetic waves",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Describe methods of detecting electromagnetic waves",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Give applications of electromagnetic waves",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion, research",
                        },
                        {
                            "objective": "Solve problems using c = f x lambda",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                    ],
                    "resources": [
                        {"text": "EM spectrum chart", "type": "reference"},
                        {"text": "UV lamp", "type": "equipment"},
                        {"text": "Radio receiver", "type": "equipment"},
                    ],
                },
                {
                    "title": "Light and Lenses",
                    "description": "Converging and diverging lenses, optical devices, and the human eye.",
                    "year_level": 4,
                    "periods": 19,
                    "subtopics": [
                        {
                            "title": "Converging and diverging lenses (characteristics, ray diagrams)"
                        },
                        {
                            "title": "Focal length of a converging lens (experimental determination, graphs)"
                        },
                        {
                            "title": "Image formation by converging lenses (position, size, nature)"
                        },
                        {
                            "title": "Image formation using ray diagrams (drawing, determination, magnification)"
                        },
                        {
                            "title": "Lens and magnification formulae (derivation, problems)"
                        },
                        {
                            "title": "Application of lenses in optical devices (camera, projector, telescope)"
                        },
                        {
                            "title": "Image formation in the human eye (parts, ray diagrams, comparison with camera)"
                        },
                        {
                            "title": "Visual defects (short sightedness and correction, long sightedness and correction)"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Distinguish between converging and diverging lenses",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Draw ray diagrams for converging lenses",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Define focal length of a converging lens",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Determine focal length experimentally",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical",
                        },
                        {
                            "objective": "Plot and interpret graphs to find focal length",
                            "cognitive_level": "Application",
                            "teaching_method": "Practical, calculation",
                        },
                        {
                            "objective": "Describe image formation by converging lenses (position, size, nature)",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration, diagram",
                        },
                        {
                            "objective": "Draw ray diagrams to determine image position and size",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Calculate magnification using the magnification formula",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Derive the lens formula 1/f = 1/v - 1/u",
                            "cognitive_level": "Synthesis",
                            "teaching_method": "Lecture, derivation",
                        },
                        {
                            "objective": "Solve problems involving lenses and magnification",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Describe parts of a simple camera and their functions",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration, diagram",
                        },
                        {
                            "objective": "Describe parts of a slide/film projector and their functions",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Demonstration, diagram",
                        },
                        {
                            "objective": "Draw ray diagrams for camera and projector",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Describe parts of a telescope and their functions",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "Describe the structure of the human eye and image formation",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Compare a camera and the human eye",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Explain short sightedness and its correction using lenses",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Explain long sightedness and its correction using lenses",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, diagram",
                        },
                    ],
                    "resources": [
                        {
                            "text": "Converging and diverging lenses",
                            "type": "equipment",
                        },
                        {
                            "text": "Optical bench with lens holders",
                            "type": "equipment",
                        },
                        {"text": "Light source and screen", "type": "equipment"},
                        {"text": "Eye model diagrams", "type": "reference"},
                    ],
                },
            ],
        },
        {
            "number": 6,
            "name": "Nuclear Physics",
            "description": "Covers atomic structure, isotopes, radioactivity, nuclear reactions, half-life, and applications of nuclear physics. Emphasises safety and real-world applications.",
            "topics": [
                {
                    "title": "Introduction to Nuclear Physics",
                    "description": "Atomic structure, isotopes, radiation types, and radiation safety.",
                    "year_level": 3,
                    "periods": 5,
                    "subtopics": [
                        {"title": "Structure of an atom"},
                        {"title": "Meaning of isotopes"},
                        {"title": "Radioactive isotopes"},
                        {"title": "Types of radiation (alpha, beta, gamma)"},
                        {"title": "Properties of different types of radiations"},
                        {"title": "Uses of radiation"},
                        {"title": "Dangers of radiation"},
                        {"title": "Safety measures against radiation exposure"},
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Describe the structure of the atom (protons, neutrons, electrons)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Explain the meaning of isotopes",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Give examples of radioactive isotopes",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Identify types of radiation (alpha, beta, gamma)",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "Compare the properties of alpha, beta and gamma radiation",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, experiment",
                        },
                        {
                            "objective": "Give uses of radioactive isotopes",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe dangers of radiation",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe safety measures against radiation exposure",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Atomic model diagrams", "type": "reference"},
                        {
                            "text": "Sealed radioactive sources (demonstration)",
                            "type": "equipment",
                        },
                        {"text": "Geiger-Muller counter", "type": "equipment"},
                    ],
                },
                {
                    "title": "Isotopes",
                    "description": "Nuclear structure, nuclide notation, and isotope examples.",
                    "year_level": 3,
                    "periods": 2,
                    "subtopics": [
                        {
                            "title": "Nuclear structure of an atom (constituent particles, diagrams, nuclear notation)"
                        },
                        {
                            "title": "Description of isotopes (definition, examples, nuclide notation)"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Identify constituent particles of the nucleus",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, diagram",
                        },
                        {
                            "objective": "Draw diagrams of atomic nuclei",
                            "cognitive_level": "Application",
                            "teaching_method": "Drawing exercise",
                        },
                        {
                            "objective": "Express atoms using nuclear notation (nuclide notation)",
                            "cognitive_level": "Application",
                            "teaching_method": "Practice",
                        },
                        {
                            "objective": "Define isotopes",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Give examples of isotopes",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Explain how one element can have multiple isotopes using nuclide notation",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, practice",
                        },
                    ],
                    "resources": [
                        {"text": "Nuclear notation worksheets", "type": "reference"},
                        {"text": "Isotope charts", "type": "reference"},
                        {"text": "Ball models of nuclei", "type": "equipment"},
                    ],
                },
                {
                    "title": "Radioactivity",
                    "description": "Radioactive decay, half-life, nuclear equations, and applications.",
                    "year_level": 4,
                    "periods": 10,
                    "subtopics": [
                        {"title": "Explanation and definition of radioactivity"},
                        {"title": "Natural and induced radioactivity"},
                        {"title": "Radioactive emissions"},
                        {"title": "Half-life of isotopes"},
                        {"title": "Detection of radioactive emissions"},
                        {"title": "Nuclear fission and fusion (definitions)"},
                        {"title": "Balanced nuclear equations (fission and fusion)"},
                        {"title": "Half-life problems"},
                        {"title": "Dangers of radioactive emissions"},
                        {"title": "Safe handling and storage of radioactive materials"},
                        {
                            "title": "Applications of radioactivity (nuclear power, agricultural, industrial, medical, radiocarbon dating)"
                        },
                    ],
                    "learning_objectives": [
                        {
                            "objective": "Define radioactivity as the spontaneous emission of radiation",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Distinguish between natural and induced radioactivity",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Describe the emissions from radioactive decay",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, demonstration",
                        },
                        {
                            "objective": "Define half-life and explain its significance",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture",
                        },
                        {
                            "objective": "Describe methods of detecting radioactive emissions",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Demonstration",
                        },
                        {
                            "objective": "Define nuclear fission and nuclear fusion",
                            "cognitive_level": "Knowledge",
                            "teaching_method": "Lecture, discussion",
                        },
                        {
                            "objective": "Write balanced nuclear equations for fission and fusion",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation, practice",
                        },
                        {
                            "objective": "Calculate remaining activity after a given number of half-lives",
                            "cognitive_level": "Application",
                            "teaching_method": "Calculation",
                        },
                        {
                            "objective": "Describe dangers of radioactive emissions",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe safe handling and storage of radioactive materials",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe applications of radioactivity in nuclear power generation",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, video",
                        },
                        {
                            "objective": "Describe applications of radioactivity in agriculture",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe applications of radioactivity in industry",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion",
                        },
                        {
                            "objective": "Describe applications of radioactivity in medicine",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Discussion, video",
                        },
                        {
                            "objective": "Explain radiocarbon dating",
                            "cognitive_level": "Comprehension",
                            "teaching_method": "Lecture, discussion",
                        },
                    ],
                    "resources": [
                        {"text": "Geiger-Muller counter", "type": "equipment"},
                        {"text": "Sealed radioactive sources", "type": "equipment"},
                        {"text": "Nuclear equation worksheets", "type": "reference"},
                        {
                            "text": "Half-life calculation worksheets",
                            "type": "reference",
                        },
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
