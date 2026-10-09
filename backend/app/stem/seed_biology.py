"""Seed MSCE Biology content: 15 chapters, ~80 sub-topics, concepts, materials, practices."""

import asyncio
from typing import Any

from sqlalchemy import select

from app.database.engine import async_session
from app.models.stem import (
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
    STLearningMaterial,
    STPractice,
)

BIOLOGY_CHAPTERS: list[dict[str, Any]] = [
    {
        "discipline": "Introduction to Biology",
        "description": "Fundamental concepts of biology, classification, and scientific investigation.",
        "topics": [
            {
                "title": "What is Biology?",
                "difficulty": "foundational",
                "subtopics": [
                    {
                        "title": "Definition and Scope of Biology",
                        "concepts": [
                            {
                                "title": "Biology as a Science",
                                "description": "Biology is the scientific study of living organisms and their interactions with the environment.",
                                "material_title": "Introduction to Biology",
                                "material_content": (
                                    "Biology comes from the Greek words 'bios' (life) and 'logos' (study). "
                                    "It is the branch of science that deals with the study of living organisms, "
                                    "their structure, function, growth, origin, evolution, and distribution. "
                                    "Biology encompasses many specialized fields including zoology, botany, "
                                    "microbiology, genetics, ecology, and many more."
                                ),
                                "practices": [
                                    {
                                        "question": "What does the word 'biology' mean?",
                                        "type": "mcq",
                                        "options": '{"options":["A) Study of the earth","B) Study of living organisms","C) Study of chemicals","D) Study of stars"]}',
                                        "answer": "B",
                                        "explanation": "Biology literally means the study of life (bios = life, logos = study).",
                                    },
                                    {
                                        "question": "Name three branches of biology.",
                                        "type": "short_answer",
                                        "answer": "Any three of: zoology, botany, microbiology, genetics, ecology, anatomy, physiology",
                                        "explanation": "Biology has many specialized branches, each focusing on different aspects of life.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Characteristics of Living Organisms",
                "difficulty": "foundational",
                "subtopics": [
                    {
                        "title": "Seven Life Processes",
                        "concepts": [
                            {
                                "title": "MRS GREN",
                                "description": "All living organisms perform seven life processes: Movement, Respiration, Sensitivity, Growth, Reproduction, Excretion, and Nutrition.",
                                "material_title": "The Seven Life Processes",
                                "material_content": (
                                    "All living things share seven basic life processes, remembered by the mnemonic MRS GREN:\n"
                                    "1. Movement — Organisms can move or change position.\n"
                                    "2. Respiration — Breaking down food to release energy.\n"
                                    "3. Sensitivity — Responding to changes in the environment.\n"
                                    "4. Growth — Irreversible increase in size.\n"
                                    "5. Reproduction — Producing offspring.\n"
                                    "6. Excretion — Removing harmful waste products.\n"
                                    "7. Nutrition — Taking in and using food."
                                ),
                                "practices": [
                                    {
                                        "question": "What does the 'S' stand for in MRS GREN?",
                                        "type": "mcq",
                                        "options": '{"options":["A) Speed","B) Sensitivity","C) Strength","D) Size"]}',
                                        "answer": "B",
                                        "explanation": "S stands for Sensitivity — the ability to respond to stimuli.",
                                    },
                                    {
                                        "question": "Give an example of excretion in humans.",
                                        "type": "short_answer",
                                        "answer": "Removal of carbon dioxide through the lungs / removal of urea through kidneys",
                                        "explanation": "Excretion is the removal of metabolic waste products from the body.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Classification of Organisms",
                "difficulty": "foundational",
                "subtopics": [
                    {
                        "title": "The Five Kingdoms",
                        "concepts": [
                            {
                                "title": "Kingdom Classification",
                                "description": "Organisms are classified into five kingdoms based on their characteristics.",
                                "material_title": "The Five Kingdoms of Life",
                                "material_content": (
                                    "Living organisms are classified into five kingdoms:\n"
                                    "1. Kingdom Monera — Unicellular prokaryotes (bacteria).\n"
                                    "2. Kingdom Protoctista — Unicellular eukaryotes (amoeba, algae).\n"
                                    "3. Kingdom Fungi — Multicellular decomposers (mushrooms, mould).\n"
                                    "4. Kingdom Plantae — Multicellular producers (plants).\n"
                                    "5. Kingdom Animalia — Multicellular consumers (animals).\n\n"
                                    "Classification is based on: cell type (prokaryotic/eukaryotic), "
                                    "cell number (unicellular/multicellular), nutrition type, and body organisation."
                                ),
                                "practices": [
                                    {
                                        "question": "Which kingdom do bacteria belong to?",
                                        "type": "mcq",
                                        "options": '{"options":["A) Protoctista","B) Fungi","C) Monera","D) Animalia"]}',
                                        "answer": "C",
                                        "explanation": "Bacteria are prokaryotic organisms classified in Kingdom Monera.",
                                    },
                                    {
                                        "question": "Give two differences between Kingdom Plantae and Kingdom Animalia.",
                                        "type": "short_answer",
                                        "answer": "Plants are autotrophic (make own food) while animals are heterotrophic; plants have cell walls while animals do not",
                                        "explanation": "Key differences include nutrition type and cell wall presence.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Cell Biology",
        "description": "The study of cell structure, function, and specialization.",
        "topics": [
            {
                "title": "Cell Theory",
                "difficulty": "foundational",
                "subtopics": [
                    {
                        "title": "Principles of Cell Theory",
                        "concepts": [
                            {
                                "title": "Cell Theory Statements",
                                "description": "All living organisms are made of cells; the cell is the basic unit of life; all cells arise from pre-existing cells.",
                                "material_title": "Cell Theory",
                                "material_content": (
                                    "Cell theory states three fundamental principles:\n"
                                    "1. All living organisms are composed of one or more cells.\n"
                                    "2. The cell is the basic structural and functional unit of life.\n"
                                    "3. All cells arise from pre-existing cells (cell division).\n\n"
                                    "Cell theory was proposed by Matthias Schleiden (plants, 1838) and "
                                    "Theodor Schwann (animals, 1839), and later refined by Rudolf Virchow (1855)."
                                ),
                                "practices": [
                                    {
                                        "question": "Who proposed that all cells come from pre-existing cells?",
                                        "type": "mcq",
                                        "options": '{"options":["A) Schleiden","B) Schwann","C) Virchow","D) Hooke"]}',
                                        "answer": "C",
                                        "explanation": "Rudolf Virchow proposed that all cells arise from pre-existing cells.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Plant and Animal Cells",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Cell Structure Comparison",
                        "concepts": [
                            {
                                "title": "Organelles and Their Functions",
                                "description": "Plant and animal cells share many organelles but differ in key structures.",
                                "material_title": "Comparing Plant and Animal Cells",
                                "material_content": (
                                    "Both plant and animal cells are eukaryotic and share: nucleus, cell membrane, "
                                    "cytoplasm, mitochondria, ribosomes, endoplasmic reticulum, Golgi apparatus, and vacuoles.\n\n"
                                    "Plant cells additionally have:\n"
                                    "- Cell wall (cellulose) — structural support\n"
                                    "- Chloroplasts — photosynthesis\n"
                                    "- Large central vacuole — stores cell sap\n\n"
                                    "Animal cells have: small temporary vacuoles, centrioles (in some), "
                                    "and lysosomes. They lack cell walls and chloroplasts."
                                ),
                                "practices": [
                                    {
                                        "question": "Name three structures found ONLY in plant cells.",
                                        "type": "short_answer",
                                        "answer": "Cell wall, chloroplasts, large central vacuole",
                                        "explanation": "These three structures distinguish plant cells from animal cells.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Microscopy",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Types of Microscope",
                        "concepts": [
                            {
                                "title": "Light vs Electron Microscope",
                                "description": "Light microscopes use visible light; electron microscopes use electron beams for higher magnification.",
                                "material_title": "Microscopy in Biology",
                                "material_content": (
                                    "A light (optical) microscope uses lenses and visible light to magnify specimens. "
                                    "Maximum magnification is about ×1500. Specimens must be thin and usually stained.\n\n"
                                    "An electron microscope uses a beam of electrons instead of light. "
                                    "It achieves much higher magnification (up to ×1,000,000) and resolution. "
                                    "Two types: Transmission Electron Microscope (TEM) shows internal structures; "
                                    "Scanning Electron Microscope (SEM) shows surface details.\n\n"
                                    "Magnification = Image size ÷ Actual size"
                                ),
                                "practices": [
                                    {
                                        "question": "What is the maximum useful magnification of a light microscope?",
                                        "type": "mcq",
                                        "options": '{"options":["A) ×100","B) ×500","C) ×1500","D) ×10000"]}',
                                        "answer": "C",
                                        "explanation": "A light microscope can magnify up to approximately ×1500.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Movement of Substances",
        "description": "How substances move in and out of cells — diffusion, osmosis, and active transport.",
        "topics": [
            {
                "title": "Diffusion",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Principles of Diffusion",
                        "concepts": [
                            {
                                "title": "Diffusion Explained",
                                "description": "The net movement of particles from a region of higher concentration to lower concentration.",
                                "material_title": "Diffusion",
                                "material_content": (
                                    "Diffusion is the net movement of molecules from an area of higher concentration "
                                    "to an area of lower concentration until equilibrium is reached. It is a passive process "
                                    "requiring no energy.\n\n"
                                    "Factors affecting diffusion rate:\n"
                                    "- Concentration gradient — steeper = faster\n"
                                    "- Temperature — higher = faster\n"
                                    "- Surface area — larger = faster\n"
                                    "- Distance — shorter = faster\n\n"
                                    "Examples in biology: gas exchange in the lungs, oxygen reaching cells, "
                                    "carbon dioxide leaving cells."
                                ),
                                "practices": [
                                    {
                                        "question": "Diffusion is described as a ___ process (active/passive).",
                                        "type": "short_answer",
                                        "answer": "Passive",
                                        "explanation": "Diffusion requires no energy input from the organism.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Osmosis",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Osmosis in Living Cells",
                        "concepts": [
                            {
                                "title": "Osmosis Defined",
                                "description": "The movement of water molecules through a partially permeable membrane from a dilute to a concentrated solution.",
                                "material_title": "Osmosis",
                                "material_content": (
                                    "Osmosis is the diffusion of water molecules through a partially permeable membrane "
                                    "from a region of higher water potential (dilute solution) to a region of lower "
                                    "water potential (concentrated solution).\n\n"
                                    "Key points:\n"
                                    "- Only water molecules move\n"
                                    "- Membrane must be partially permeable\n"
                                    "- No energy required\n\n"
                                    "In plant cells: water enters by osmosis → cell becomes turgid. "
                                    "Water leaves by osmosis → cell becomes plasmolysed.\n\n"
                                    "In animal cells: water enters → cell bursts (lysis). "
                                    "Water leaves → cell shrinks (crenation)."
                                ),
                                "practices": [
                                    {
                                        "question": "What happens to a plant cell placed in pure water?",
                                        "type": "mcq",
                                        "options": '{"options":["A) It shrinks","B) It becomes turgid","C) It bursts","D) Nothing happens"]}',
                                        "answer": "B",
                                        "explanation": "Water enters by osmosis. The cell wall prevents bursting, so the cell becomes turgid.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Active Transport",
                "difficulty": "advanced",
                "subtopics": [
                    {
                        "title": "Active Transport Mechanism",
                        "concepts": [
                            {
                                "title": "Active Transport vs Passive Processes",
                                "description": "Active transport moves substances against the concentration gradient using energy from respiration.",
                                "material_title": "Active Transport",
                                "material_content": (
                                    "Active transport is the movement of molecules from a region of lower concentration "
                                    "to a region of higher concentration (against the concentration gradient) using "
                                    "energy from respiration.\n\n"
                                    "Key differences from diffusion/osmosis:\n"
                                    "- Moves AGAINST the concentration gradient\n"
                                    "- Requires energy (ATP from respiration)\n"
                                    "- Requires carrier proteins in the cell membrane\n\n"
                                    "Examples:\n"
                                    "- Root hair cells absorbing mineral ions from soil\n"
                                    "- Gut lining absorbing glucose from digested food\n"
                                    "- Kidney tubules reabsorbing useful substances"
                                ),
                                "practices": [
                                    {
                                        "question": "What provides the energy for active transport?",
                                        "type": "mcq",
                                        "options": '{"options":["A) Sunlight","B) ATP from respiration","C) Osmosis","D) Diffusion"]}',
                                        "answer": "B",
                                        "explanation": "Energy for active transport comes from ATP produced during cellular respiration.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Nutrition",
        "description": "Human and plant nutrition — nutrients, digestion, and photosynthesis.",
        "topics": [
            {
                "title": "Human Nutrition — Nutrients",
                "difficulty": "foundational",
                "subtopics": [
                    {
                        "title": "Classes of Food and Their Functions",
                        "concepts": [
                            {
                                "title": "The Seven Nutrients",
                                "description": "Food contains carbohydrates, proteins, lipids, vitamins, minerals, water, and roughage (fibre).",
                                "material_title": "Nutrients and Their Functions",
                                "material_content": (
                                    "The seven classes of nutrients:\n"
                                    "1. Carbohydrates — Provide energy (4 kcal/g). Sources: rice, bread, maize.\n"
                                    "2. Proteins — Growth and repair (4 kcal/g). Sources: beans, fish, meat.\n"
                                    "3. Lipids — Energy storage, insulation (9 kcal/g). Sources: groundnuts, cooking oil.\n"
                                    "4. Vitamins — Regulate body processes (needed in small amounts).\n"
                                    "5. Minerals — Build tissues and regulate processes.\n"
                                    "6. Water — Solvent, transport medium, temperature regulation.\n"
                                    "7. Fibre/Roughage — Aids digestion, prevents constipation.\n\n"
                                    "Deficiency diseases: Scurvy (Vit C), Rickets (Vit D), Kwashiorkor (protein), "
                                    "Anaemia (iron), Goitre (iodine)."
                                ),
                                "practices": [
                                    {
                                        "question": "Which nutrient provides the most energy per gram?",
                                        "type": "mcq",
                                        "options": '{"options":["A) Carbohydrates","B) Proteins","C) Lipids","D) Vitamins"]}',
                                        "answer": "C",
                                        "explanation": "Lipids provide 9 kcal/g compared to 4 kcal/g for carbohydrates and proteins.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Photosynthesis",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "The Photosynthesis Process",
                        "concepts": [
                            {
                                "title": "Photosynthesis Equation",
                                "description": "Plants use light energy to convert carbon dioxide and water into glucose and oxygen.",
                                "material_title": "Photosynthesis",
                                "material_content": (
                                    "Word equation:\n"
                                    "Carbon dioxide + Water → (light energy, chlorophyll) → Glucose + Oxygen\n\n"
                                    "Chemical equation:\n"
                                    "6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂\n\n"
                                    "Conditions needed:\n"
                                    "- Light energy (from the sun)\n"
                                    "- Chlorophyll (green pigment in chloroplasts)\n"
                                    "- Carbon dioxide (from air through stomata)\n"
                                    "- Water (absorbed by roots)\n\n"
                                    "Limiting factors:\n"
                                    "- Light intensity\n"
                                    "- Carbon dioxide concentration\n"
                                    "- Temperature\n\n"
                                    "Glucose is used for: respiration, making starch, making cellulose, "
                                    "making amino acids, making fats and oils."
                                ),
                                "practices": [
                                    {
                                        "question": "Write the word equation for photosynthesis.",
                                        "type": "short_answer",
                                        "answer": "Carbon dioxide + Water → (light energy, chlorophyll) → Glucose + Oxygen",
                                        "explanation": "This is the fundamental equation for photosynthesis.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Transport in Humans and Plants",
        "description": "Blood, the heart, double circulation, and transport systems in plants.",
        "topics": [
            {
                "title": "Blood and the Circulatory System",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Components and Functions of Blood",
                        "concepts": [
                            {
                                "title": "Blood Components",
                                "description": "Blood consists of plasma, red blood cells, white blood cells, and platelets.",
                                "material_title": "Composition of Blood",
                                "material_content": (
                                    "Blood has four main components:\n"
                                    "1. Plasma (55%) — Straw-coloured liquid carrying dissolved substances: "
                                    "glucose, amino acids, urea, CO₂, hormones, antibodies.\n"
                                    "2. Red blood cells — Contain haemoglobin which binds oxygen. "
                                    "Biconcave disc shape increases surface area. No nucleus in mammals.\n"
                                    "3. White blood cells — Part of immune system. Two types: "
                                    "phagocytes (engulf pathogens) and lymphocytes (produce antibodies).\n"
                                    "4. Platelets — Tiny cell fragments that help blood clot at wound sites."
                                ),
                                "practices": [
                                    {
                                        "question": "What is the function of haemoglobin in red blood cells?",
                                        "type": "short_answer",
                                        "answer": "Haemoglobin binds oxygen to form oxyhaemoglobin for transport to body cells.",
                                        "explanation": "Haemoglobin's iron content gives it the ability to reversibly bind oxygen.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "The Heart and Double Circulation",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Heart Structure and Blood Flow",
                        "concepts": [
                            {
                                "title": "Double Circulation",
                                "description": "Blood passes through the heart twice in each complete circuit — once for lungs (pulmonary) and once for the body (systemic).",
                                "material_title": "Double Circulation",
                                "material_content": (
                                    "The human heart has four chambers:\n"
                                    "- Right atrium — receives deoxygenated blood from body\n"
                                    "- Right ventricle — pumps blood to lungs (pulmonary artery)\n"
                                    "- Left atrium — receives oxygenated blood from lungs\n"
                                    "- Left ventricle — pumps blood to body (aorta)\n\n"
                                    "Double circulation means blood passes through the heart twice:\n"
                                    "1. Pulmonary circulation: Right ventricle → Lungs → Left atrium\n"
                                    "2. Systemic circulation: Left ventricle → Body → Right atrium\n\n"
                                    "This is more efficient than single circulation because blood is pumped "
                                    "to the body at high pressure."
                                ),
                                "practices": [
                                    {
                                        "question": "Which ventricle has the thicker muscular wall and why?",
                                        "type": "short_answer",
                                        "answer": "Left ventricle — it pumps blood to the entire body, requiring greater force.",
                                        "explanation": "The left ventricle wall is thicker because it needs to generate higher pressure for systemic circulation.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Gaseous Exchange and Respiration",
        "description": "Breathing, gas exchange, aerobic and anaerobic respiration.",
        "topics": [
            {
                "title": "Respiration",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Aerobic and Anaerobic Respiration",
                        "concepts": [
                            {
                                "title": "Respiration Equation",
                                "description": "Respiration is the breakdown of glucose to release energy, occurring in all living cells.",
                                "material_title": "Aerobic vs Anaerobic Respiration",
                                "material_content": (
                                    "Aerobic respiration (with oxygen):\n"
                                    "Glucose + Oxygen → Carbon dioxide + Water + Energy\n"
                                    "C₆H₁₂O₆ + 6O₂ → 6CO₂ + 6H₂O + 38 ATP\n\n"
                                    "Anaerobic respiration in animals (without oxygen):\n"
                                    "Glucose → Lactic acid + Energy (2 ATP)\n\n"
                                    "Anaerobic respiration in plants/yeast:\n"
                                    "Glucose → Ethanol + Carbon dioxide + Energy (2 ATP)\n\n"
                                    "Aerobic releases much more energy (38 ATP vs 2 ATP). "
                                    "Anaerobic in humans causes muscle fatigue due to lactic acid buildup."
                                ),
                                "practices": [
                                    {
                                        "question": "How many ATP molecules are produced by aerobic respiration?",
                                        "type": "mcq",
                                        "options": '{"options":["A) 2","B) 12","C) 38","D) 100"]}',
                                        "answer": "C",
                                        "explanation": "Aerobic respiration produces 38 ATP molecules per glucose molecule.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Excretion and Homeostasis",
        "description": "Removal of waste, kidney function, and maintaining a stable internal environment.",
        "topics": [
            {
                "title": "The Kidney and Excretion",
                "difficulty": "advanced",
                "subtopics": [
                    {
                        "title": "Kidney Structure and Urine Formation",
                        "concepts": [
                            {
                                "title": "The Nephron",
                                "description": "Each kidney contains about 1 million nephrons that filter blood and form urine.",
                                "material_title": "Urine Formation in the Nephron",
                                "material_content": (
                                    "The nephron is the functional unit of the kidney. Urine formation involves:\n\n"
                                    "1. Filtration (in the renal capsule / Bowman's capsule):\n"
                                    "   Blood pressure forces water, glucose, amino acids, urea, and salts "
                                    "out of the blood capillaries into the capsule.\n\n"
                                    "2. Reabsorption (in the proximal convoluted tubule and loop of Henle):\n"
                                    "   All glucose, most water, and some salts are reabsorbed back into blood.\n\n"
                                    "3. Selective reabsorption (in the distal convoluted tubule):\n"
                                    "   Hormones control how much water and salt is reabsorbed.\n\n"
                                    "The remaining fluid is urine: water, urea, and excess salts."
                                ),
                                "practices": [
                                    {
                                        "question": "Name the three stages of urine formation.",
                                        "type": "short_answer",
                                        "answer": "Filtration, reabsorption, selective reabsorption",
                                        "explanation": "These three processes occur in different parts of the nephron.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Coordination and Response",
        "description": "Nervous system, sense organs, hormones, and tropisms.",
        "topics": [
            {
                "title": "The Nervous System",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Neurons and Reflex Actions",
                        "concepts": [
                            {
                                "title": "The Reflex Arc",
                                "description": "A reflex action is an automatic, rapid response to a stimulus that does not involve the brain.",
                                "material_title": "Reflex Actions",
                                "material_content": (
                                    "A reflex action is an automatic, involuntary response to a stimulus. "
                                    "It follows the reflex arc pathway:\n"
                                    "Stimulus → Receptor → Sensory neuron → Relay neuron (in spinal cord) → "
                                    "Motor neuron → Effector (muscle/gland) → Response\n\n"
                                    "Types of neurons:\n"
                                    "- Sensory neurons — carry impulses from receptors to the CNS\n"
                                    "- Relay neurons — connect sensory and motor neurons in the CNS\n"
                                    "- Motor neurons — carry impulses from CNS to effectors\n\n"
                                    "Examples: withdrawing hand from hot object, knee-jerk reflex, blinking."
                                ),
                                "practices": [
                                    {
                                        "question": "Which part of the reflex arc is found in the spinal cord?",
                                        "type": "mcq",
                                        "options": '{"options":["A) Receptor","B) Sensory neuron","C) Relay neuron","D) Effector"]}',
                                        "answer": "C",
                                        "explanation": "The relay neuron is located in the grey matter of the spinal cord.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Reproduction",
        "description": "Human and plant reproduction — structures, processes, and development.",
        "topics": [
            {
                "title": "Human Reproduction",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "The Male and Female Reproductive Systems",
                        "concepts": [
                            {
                                "title": "Reproductive Structures and Functions",
                                "description": "The male system produces sperm; the female system produces ova and supports pregnancy.",
                                "material_title": "Human Reproductive Systems",
                                "material_content": (
                                    "Male reproductive system:\n"
                                    "- Testes — produce sperm and testosterone\n"
                                    "- Epididymis — where sperm mature\n"
                                    "- Vas deferens — tube carrying sperm\n"
                                    "- Penis — delivers sperm\n"
                                    "- Prostate gland — adds fluid to semen\n\n"
                                    "Female reproductive system:\n"
                                    "- Ovaries — produce ova and oestrogen/progesterone\n"
                                    "- Fallopian tubes — where fertilization occurs\n"
                                    "- Uterus — where embryo develops\n"
                                    "- Cervix — opening to uterus\n"
                                    "- Vagina — birth canal"
                                ),
                                "practices": [
                                    {
                                        "question": "Where does fertilization normally occur?",
                                        "type": "mcq",
                                        "options": '{"options":["A) Uterus","B) Ovary","C) Fallopian tube","D) Vagina"]}',
                                        "answer": "C",
                                        "explanation": "Fertilization normally occurs in the fallopian tube (oviduct).",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Genetics and Inheritance",
        "description": "DNA, genes, alleles, and patterns of inheritance.",
        "topics": [
            {
                "title": "DNA and Genes",
                "difficulty": "advanced",
                "subtopics": [
                    {
                        "title": "Genotype and Phenotype",
                        "concepts": [
                            {
                                "title": "Understanding Genotype and Phenotype",
                                "description": "Genotype is the genetic makeup; phenotype is the observable characteristics.",
                                "material_title": "Genotype vs Phenotype",
                                "material_content": (
                                    "Genotype: The genetic constitution of an organism — the alleles it carries. "
                                    "Written as letter pairs (e.g., TT, Tt, tt).\n\n"
                                    "Phenotype: The observable physical characteristics of an organism, "
                                    "determined by genotype and environment (e.g., tall, dwarf).\n\n"
                                    "Key terms:\n"
                                    "- Allele: Different forms of a gene (e.g., T = tall, t = dwarf)\n"
                                    "- Dominant allele: Expressed even when one copy is present (T)\n"
                                    "- Recessive allele: Only expressed when two copies are present (tt)\n"
                                    "- Homozygous: Two identical alleles (TT or tt)\n"
                                    "- Heterozygous: Two different alleles (Tt)\n\n"
                                    "Punnett squares predict offspring genotypes and phenotypes."
                                ),
                                "practices": [
                                    {
                                        "question": "A plant has genotype Tt. What is its phenotype if T (tall) is dominant?",
                                        "type": "mcq",
                                        "options": '{"options":["A) Tall","B) Dwarf","C) Medium","D) Cannot determine"]}',
                                        "answer": "A",
                                        "explanation": "Since T is dominant, the heterozygous genotype Tt produces a tall phenotype.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Ecology",
        "description": "Interactions between organisms and their environment, food chains, and cycles.",
        "topics": [
            {
                "title": "Ecosystems and Energy Flow",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Food Chains and Trophic Levels",
                        "concepts": [
                            {
                                "title": "Energy Flow in Ecosystems",
                                "description": "Energy flows from producers through consumers. Only about 10% transfers between trophic levels.",
                                "material_title": "Food Chains and Webs",
                                "material_content": (
                                    "A food chain shows the transfer of energy from one organism to another:\n"
                                    "Grass → Grasshopper → Frog → Snake → Eagle\n\n"
                                    "Trophic levels:\n"
                                    "1. Producers (plants) — make food by photosynthesis\n"
                                    "2. Primary consumers (herbivores) — eat plants\n"
                                    "3. Secondary consumers (carnivores) — eat herbivores\n"
                                    "4. Tertiary consumers — eat other carnivores\n"
                                    "5. Decomposers — break down dead matter\n\n"
                                    "Only about 10% of energy is passed to the next trophic level. "
                                    "The rest is lost as heat through respiration. This is why food chains "
                                    "rarely have more than 4-5 levels."
                                ),
                                "practices": [
                                    {
                                        "question": "What percentage of energy is typically passed from one trophic level to the next?",
                                        "type": "mcq",
                                        "options": '{"options":["A) 1%","B) 10%","C) 50%","D) 90%"]}',
                                        "answer": "B",
                                        "explanation": "Approximately 10% of energy is transferred between trophic levels.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Microorganisms",
        "description": "Bacteria, viruses, fungi, and their roles in health and industry.",
        "topics": [
            {
                "title": "Types of Microorganisms",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Bacteria, Viruses, and Fungi",
                        "concepts": [
                            {
                                "title": "Microorganism Characteristics",
                                "description": "Microorganisms are too small to see with the naked eye and include bacteria, viruses, fungi, and protozoa.",
                                "material_title": "Microorganisms",
                                "material_content": (
                                    "Types of microorganisms:\n\n"
                                    "1. Bacteria — Unicellular prokaryotes. Some are useful (yoghurt, decomposition), "
                                    "others cause disease (cholera, tuberculosis).\n\n"
                                    "2. Viruses — Not cells; consist of DNA/RNA inside a protein coat. "
                                    "They are parasites that invade host cells to reproduce. "
                                    "Cannot be killed by antibiotics.\n\n"
                                    "3. Fungi — Can be unicellular (yeast) or multicellular (mould, mushrooms). "
                                    "Decomposers; some cause disease (athlete's foot).\n\n"
                                    "4. Protozoa — Unicellular eukaryotes. Some cause disease (Plasmodium causes malaria)."
                                ),
                                "practices": [
                                    {
                                        "question": "Why can't antibiotics kill viruses?",
                                        "type": "short_answer",
                                        "answer": "Antibiotics target bacterial structures/processes that viruses do not have.",
                                        "explanation": "Viruses are not cells and lack the structures that antibiotics target.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Disease and Immunity",
        "description": "Communicable and non-communicable diseases, immune response, and vaccination — with Malawi context.",
        "topics": [
            {
                "title": "Communicable Diseases in Malawi",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Major Diseases Affecting Malawi",
                        "concepts": [
                            {
                                "title": "Malaria and Cholera in Malawi",
                                "description": "Malaria and cholera are major communicable diseases in Malawi with specific prevention strategies.",
                                "material_title": "Diseases in the Malawi Context",
                                "material_content": (
                                    "Malaria in Malawi:\n"
                                    "- Caused by Plasmodium parasites, transmitted by Anopheles mosquitoes\n"
                                    "- Symptoms: fever, chills, headache, vomiting\n"
                                    "- Prevention: insecticide-treated nets (ITNs), indoor residual spraying, "
                                    "eliminating stagnant water\n"
                                    "- Treatment: Artemisinin-based Combination Therapy (ACT)\n\n"
                                    "Cholera in Malawi:\n"
                                    "- Caused by Vibrio cholerae bacterium\n"
                                    "- Transmitted through contaminated water and food\n"
                                    "- Symptoms: severe watery diarrhoea, dehydration\n"
                                    "- Prevention: clean water, proper sanitation, handwashing\n"
                                    "- Treatment: Oral Rehydration Salts (ORS)\n\n"
                                    "Other diseases: Tuberculosis, HIV/AIDS, Bilharzia (schistosomiasis)"
                                ),
                                "practices": [
                                    {
                                        "question": "How is malaria transmitted?",
                                        "type": "short_answer",
                                        "answer": "Through the bite of infected female Anopheles mosquitoes carrying Plasmodium parasites.",
                                        "explanation": "Malaria is vector-borne — the mosquito is the vector that transmits the parasite.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Environment and Conservation",
        "description": "Pollution, deforestation, conservation, and sustainable resource use in Malawi.",
        "topics": [
            {
                "title": "Environmental Issues in Malawi",
                "difficulty": "intermediate",
                "subtopics": [
                    {
                        "title": "Conservation and Sustainability",
                        "concepts": [
                            {
                                "title": "Lake Malawi and Forest Conservation",
                                "description": "Lake Malawi's unique biodiversity and Malawi's forests face threats requiring active conservation.",
                                "material_title": "Conservation in Malawi",
                                "material_content": (
                                    "Lake Malawi:\n"
                                    "- One of Africa's Great Rift Valley lakes\n"
                                    "- Contains over 1,000 species of cichlid fish (most found nowhere else)\n"
                                    "- Threats: overfishing, sedimentation, pollution\n"
                                    "- Conservation: Lake Malawi National Park (UNESCO World Heritage Site)\n\n"
                                    "Forest Conservation:\n"
                                    "- Malawi's forests are being lost to deforestation for agriculture and firewood\n"
                                    "- Consequences: soil erosion, loss of biodiversity, climate change\n"
                                    "- Solutions: tree planting, sustainable charcoal production, agroforestry\n\n"
                                    "Soil Erosion:\n"
                                    "- Caused by deforestation, overgrazing, poor farming practices\n"
                                    "- Prevention: terracing, cover crops, contour ploughing"
                                ),
                                "practices": [
                                    {
                                        "question": "Why is Lake Malawi important for biodiversity?",
                                        "type": "short_answer",
                                        "answer": "It contains over 1,000 endemic cichlid fish species found nowhere else on Earth.",
                                        "explanation": "Lake Malawi has exceptional biodiversity, especially its endemic fish species.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    {
        "discipline": "Practical Skills",
        "description": "Essential laboratory skills, biological drawing, magnification, and fieldwork.",
        "topics": [
            {
                "title": "Microscope Skills",
                "difficulty": "foundational",
                "subtopics": [
                    {
                        "title": "Using and Caring for a Microscope",
                        "concepts": [
                            {
                                "title": "Microscope Use and Magnification",
                                "description": "Proper microscope technique and calculating total magnification.",
                                "material_title": "Microscope Skills",
                                "material_content": (
                                    "Using a light microscope:\n"
                                    "1. Place slide on stage and clip it in position\n"
                                    "2. Start with lowest objective lens\n"
                                    "3. Look through eyepiece and focus using coarse adjustment\n"
                                    "4. Use fine adjustment for sharp focus\n"
                                    "5. Switch to higher magnification if needed\n\n"
                                    "Total magnification = Eyepiece lens × Objective lens\n"
                                    "Example: ×10 eyepiece × ×40 objective = ×400 total magnification\n\n"
                                    "Care:\n"
                                    "- Always carry with both hands\n"
                                    "- Clean lenses with lens paper only\n"
                                    "- Cover when not in use\n"
                                    "- Keep away from water and direct sunlight"
                                ),
                                "practices": [
                                    {
                                        "question": "If the eyepiece is ×10 and the objective is ×40, what is the total magnification?",
                                        "type": "short_answer",
                                        "answer": "×400 (10 × 40 = 400)",
                                        "explanation": "Total magnification is calculated by multiplying eyepiece and objective magnifications.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Biological Drawings",
                "difficulty": "foundational",
                "subtopics": [
                    {
                        "title": "Rules for Biological Drawings",
                        "concepts": [
                            {
                                "title": "Drawing Biological Specimens",
                                "description": "Biological drawings follow specific rules: sharp pencil, clear lines, labels, title.",
                                "material_title": "How to Make Biological Drawings",
                                "material_content": (
                                    "Rules for biological drawings:\n"
                                    "1. Use a sharp, well-sharpened pencil (HB or 2H)\n"
                                    "2. Draw clear, continuous lines — not sketchy or broken\n"
                                    "3. Show detail accurately — don't idealise\n"
                                    "4. Draw what you see, not what you know\n"
                                    "5. Use a title below the drawing\n"
                                    "6. Label with a ruler — horizontal lines\n"
                                    "7. Labels on the RIGHT side\n"
                                    "8. Do NOT shade (use stippling for density)\n"
                                    "9. Include magnification: (Mag = image ÷ actual)\n"
                                    "10. Draw to scale where possible"
                                ),
                                "practices": [
                                    {
                                        "question": "Should biological drawings be shaded or use stippling?",
                                        "type": "short_answer",
                                        "answer": "Use stippling (dots) for shading, not pencil shading.",
                                        "explanation": "Biological drawings use stippling instead of shading to show density and texture.",
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
]


async def seed_biology() -> None:
    """Insert all MSCE Biology content into the database."""
    async with async_session() as session:
        existing = await session.execute(
            select(STEMSubject).where(STEMSubject.subject_slug == "biology")
        )
        bio_subject = existing.scalar_one_or_none()
        if bio_subject is None:
            bio_subject = STEMSubject(
                title="Biology",
                subject_slug="biology",
                description="MSCE Biology — the study of living organisms and their environment.",
                icon="biotech",
                color="#10B981",
            )
            session.add(bio_subject)
            await session.flush()

        existing_disciplines = await session.execute(
            select(STEMDiscipline).where(STEMDiscipline.subject_id == bio_subject.id)
        )
        existing_slugs = {
            d.discipline_slug for d in existing_disciplines.scalars().all()
        }

        for idx, chapter in enumerate(BIOLOGY_CHAPTERS):
            disc_slug = (
                chapter["discipline"].lower().replace(" ", "-").replace("&", "and")
            )
            if disc_slug in existing_slugs:
                continue

            discipline = STEMDiscipline(
                subject_id=bio_subject.id,
                title=chapter["discipline"],
                discipline_slug=disc_slug,
                description=chapter.get("description", ""),
                order_index=idx,
            )
            session.add(discipline)
            await session.flush()

            for t_idx, topic_data in enumerate(chapter.get("topics", [])):
                topic = STEMTopic(
                    discipline_id=discipline.id,
                    title=topic_data["title"],
                    difficulty_level=topic_data.get("difficulty", "foundational"),
                    order_index=t_idx,
                    description=topic_data.get("description", ""),
                )
                session.add(topic)
                await session.flush()

                for s_idx, sub_data in enumerate(topic_data.get("subtopics", [])):
                    subtopic = STEMSubtopic(
                        topic_id=topic.id,
                        title=sub_data["title"],
                        order_index=s_idx,
                        description=sub_data.get("description", ""),
                    )
                    session.add(subtopic)
                    await session.flush()

                    for c_idx, concept_data in enumerate(sub_data.get("concepts", [])):
                        concept = STEMConcept(
                            subtopic_id=subtopic.id,
                            title=concept_data["title"],
                            description=concept_data.get("description", ""),
                            difficulty_level=topic_data.get(
                                "difficulty", "foundational"
                            ),
                            order_index=c_idx,
                        )
                        session.add(concept)
                        await session.flush()

                        if concept_data.get("material_title"):
                            material = STLearningMaterial(
                                concept_id=concept.id,
                                title=concept_data["material_title"],
                                content_type="text",
                                content=concept_data.get("material_content", ""),
                                order_index=0,
                            )
                            session.add(material)

                        for p_idx, prac in enumerate(concept_data.get("practices", [])):
                            practice = STPractice(
                                concept_id=concept.id,
                                question=prac["question"],
                                question_type=prac.get("type", "mcq"),
                                options=prac.get("options"),
                                correct_answer=prac["answer"],
                                explanation=prac.get("explanation", ""),
                                order_index=p_idx,
                            )
                            session.add(practice)

        await session.commit()
        print(f"✓ Biology seeded: {len(BIOLOGY_CHAPTERS)} chapters")


if __name__ == "__main__":
    asyncio.run(seed_biology())
