"""Seed the official Malawi Computer Studies syllabus (MoEST, Forms 1 to 4).

Covers the 6 core elements from the MoEST syllabus scope chart:
  1. Computer Fundamentals
  2. Personal Computer Management and Maintenance
  3. Application Software
  4. Networking and Data Communication
  5. Programming Techniques and Logical Methods
  6. Society and ICT

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

COMPUTER_STUDIES_SYLLABUS = {
    "subject": {
        "name": "Computer Studies",
        "slug": "computer-science",
        "description": (
            "Malawi MSCE Computer Studies Syllabus — MoEST Forms 1 to 4. "
            "Equips students with practical skills in computer fundamentals, "
            "personal computer management, application software, networking, "
            "programming and the responsible use of ICT in society."
        ),
        "icon": "computer",
        "color": "#3B82F6",
    },
    "version": {
        "version_name": "MoEST Forms 1 to 4",
        "year_effective": 2018,
        "examination_board": "Malawi National Examinations Board (MANEB)",
        "description": (
            "Official Computer Studies syllabus for Malawi School Certificate "
            "of Education (MSCE), covering Forms 1 to 4. Published by the "
            "Ministry of Education, Science and Technology through the Malawi "
            "Institute of Education (MIE)."
        ),
    },
    # ═══════════════════════════════════════════════════════════════════════════
    # CORE ELEMENT 1 — COMPUTER FUNDAMENTALS
    # ═══════════════════════════════════════════════════════════════════════════
    "core_elements": [
        {
            "number": 1,
            "name": "Computer Fundamentals",
            "description": (
                "Understand the basic concepts of computers, their history, "
                "classification, data and information, and the areas of "
                "computer use."
            ),
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Introduction to Computers",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Definition of a Computer",
                            "learning_objectives": [
                                {
                                    "objective": "Define a computer and describe its basic functions",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "History and Generations of Computers",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the history and the generations of computers",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, timeline charts",
                                },
                            ],
                        },
                        {
                            "title": "Types and Characteristics of Computers",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the types and characteristics of computers",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstrations",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Charts showing computer generations",
                            "type": "reference",
                        },
                        {
                            "text": "Sample computers for demonstration",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Data and Information",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Data vs Information",
                            "learning_objectives": [
                                {
                                    "objective": "Define data and information and distinguish between them",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Explain the difference between data and information with examples",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Group work, class discussion",
                                },
                            ],
                        },
                        {
                            "title": "Number Systems",
                            "learning_objectives": [
                                {
                                    "objective": (
                                        "Convert between binary, decimal, octal and hexadecimal "
                                        "number systems"
                                    ),
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice, worksheets",
                                },
                            ],
                        },
                        {
                            "title": "Storage Units",
                            "learning_objectives": [
                                {
                                    "objective": "Describe storage units from bit to byte, KB, MB, GB and TB",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, charts",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Number system conversion charts",
                            "type": "reference",
                        },
                        {
                            "text": "Computers for demonstrating data concepts",
                            "type": "ict",
                        },
                    ],
                },
                {
                    "title": "Computer Classification",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Classification by Size",
                            "learning_objectives": [
                                {
                                    "objective": (
                                        "Classify computers by size into micro, mini, mainframe "
                                        "and super computers"
                                    ),
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, charts",
                                },
                            ],
                        },
                        {
                            "title": "Classification by Purpose",
                            "learning_objectives": [
                                {
                                    "objective": (
                                        "Classify computers by purpose into general and "
                                        "special purpose computers"
                                    ),
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Pictures of different computer types",
                            "type": "reference",
                        },
                        {
                            "text": "Sample computers for classification activities",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Areas of Computer Use",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Application Areas",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the areas where computers are applied in daily life",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": (
                                        "Explain the advantages and limitations of computer "
                                        "use in different areas"
                                    ),
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Group discussion, case studies",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Charts showing computer application areas",
                            "type": "reference",
                        },
                        {
                            "text": "Computers for demonstrations",
                            "type": "ict",
                        },
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Input and Output Devices",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Input Devices",
                            "learning_objectives": [
                                {
                                    "objective": (
                                        "Identify and describe common input devices including "
                                        "the keyboard, mouse, scanner, barcode reader and "
                                        "microphone"
                                    ),
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Demonstration, hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Output Devices",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and describe common output devices including the monitor, printer, speaker and projector",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Demonstration, hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Keyboard, mouse, scanner and printer",
                            "type": "equipment",
                        },
                        {
                            "text": "Barcode readers and projectors",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Computer Hardware Components",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "The System Unit and Motherboard",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the components of the system unit and the motherboard and describe their functions",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Disassembly demonstration",
                                },
                            ],
                        },
                        {
                            "title": "CPU and Primary Memory",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the components of the CPU and the functions of RAM and ROM",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, diagrams",
                                },
                            ],
                        },
                        {
                            "title": "Secondary Storage",
                            "learning_objectives": [
                                {
                                    "objective": "Describe secondary storage devices and their uses",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, demonstrations",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Open system unit for component identification",
                            "type": "equipment",
                        },
                        {
                            "text": "Charts of CPU and motherboard components",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Computer Software",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "System Software",
                            "learning_objectives": [
                                {
                                    "objective": "Describe system software including operating systems, utilities, drivers and translators",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                            ],
                        },
                        {
                            "title": "Application Software",
                            "learning_objectives": [
                                {
                                    "objective": "Distinguish between general purpose and special purpose application software",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Installed operating systems for demonstration",
                            "type": "ict",
                        },
                        {
                            "text": "Sample application software packages",
                            "type": "ict",
                        },
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Data Representation and Storage",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Binary Arithmetic",
                            "learning_objectives": [
                                {
                                    "objective": "Perform binary arithmetic operations including addition and subtraction",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice, worksheets",
                                },
                                {
                                    "objective": "Apply binary coding systems including ASCII, EBCDIC and Unicode",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Storage Media Comparison",
                            "learning_objectives": [
                                {
                                    "objective": "Compare different storage media in terms of capacity, speed and cost",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Group work, comparison charts",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "ASCII and Unicode code charts",
                            "type": "reference",
                        },
                        {
                            "text": "Sample storage media for comparison",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Operating Systems",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Functions of an Operating System",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the functions of an operating system",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                            ],
                        },
                        {
                            "title": "Types of Operating Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Describe batch, time-sharing, real-time, distributed, mobile and embedded operating systems",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Popular Operating Systems",
                            "learning_objectives": [
                                {
                                    "objective": "Identify popular operating systems including Windows, Linux, macOS, Android and iOS",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Hands-on practice, demonstrations",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Computers with different operating systems",
                            "type": "ict",
                        },
                        {
                            "text": "Operating system screenshots for comparison",
                            "type": "digital",
                        },
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Advanced Computer Architecture",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Von Neumann Architecture",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the Von Neumann architecture and its components",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, diagrams",
                                },
                            ],
                        },
                        {
                            "title": "Fetch-Decode-Execute Cycle",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the fetch-decode-execute cycle of the CPU",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, animated demonstration",
                                },
                            ],
                        },
                        {
                            "title": "Performance Factors",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze the factors that affect computer performance",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, benchmarking exercise",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "CPU architecture diagrams",
                            "type": "reference",
                        },
                        {
                            "text": "Computers for performance demonstration",
                            "type": "ict",
                        },
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 2 — PERSONAL COMPUTER MANAGEMENT AND MAINTENANCE
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 2,
            "name": "Personal Computer Management and Maintenance",
            "description": (
                "Demonstrate the skills required to operate, manage and "
                "maintain a personal computer and to keep it safe and secure."
            ),
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Using a Computer",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Booting a Computer",
                            "learning_objectives": [
                                {
                                    "objective": "Describe cold and warm booting of a computer",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Demonstration, hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Logging In and Out",
                            "learning_objectives": [
                                {
                                    "objective": "Demonstrate how to log in and log out of a computer system",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Shutting Down Correctly",
                            "learning_objectives": [
                                {
                                    "objective": "Demonstrate the correct procedure for shutting down a computer",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Working computers for practice",
                            "type": "equipment",
                        },
                        {
                            "text": "Computer startup and shutdown posters",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Keyboard and Mouse Skills",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Keyboard Layout",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the parts of a keyboard and its layout",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Touch Typing",
                            "learning_objectives": [
                                {
                                    "objective": "Apply touch typing techniques to type text accurately",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Typing exercises, drills",
                                },
                            ],
                        },
                        {
                            "title": "Mouse Operations",
                            "learning_objectives": [
                                {
                                    "objective": "Perform the basic mouse operations of pointing, clicking, double-clicking and dragging",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Keyboards and mice for practice",
                            "type": "equipment",
                        },
                        {
                            "text": "Typing tutor software",
                            "type": "ict",
                        },
                    ],
                },
                {
                    "title": "File and Folder Management",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Files and Folders",
                            "learning_objectives": [
                                {
                                    "objective": "Define files and folders and explain naming conventions",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                            ],
                        },
                        {
                            "title": "Managing Files and Folders",
                            "learning_objectives": [
                                {
                                    "objective": "Create, rename and delete files and folders",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                                {
                                    "objective": "Copy and move files and folders and use the Recycle Bin",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Computers for file management practice",
                            "type": "ict",
                        },
                        {
                            "text": "File management worksheets",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Computer Laboratory Safety",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Safety Rules",
                            "learning_objectives": [
                                {
                                    "objective": "State and explain safety rules to observe in a computer laboratory",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstrations",
                                },
                            ],
                        },
                        {
                            "title": "Ergonomics",
                            "learning_objectives": [
                                {
                                    "objective": "Apply ergonomic principles to maintain a safe working environment",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Computer laboratory safety posters",
                            "type": "reference",
                        },
                        {
                            "text": "Ergonomic charts and guidelines",
                            "type": "reference",
                        },
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Computer Troubleshooting",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Hardware and Software Problems",
                            "learning_objectives": [
                                {
                                    "objective": "Identify common hardware and software problems",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                            ],
                        },
                        {
                            "title": "Troubleshooting Methods",
                            "learning_objectives": [
                                {
                                    "objective": "Apply systematic troubleshooting methods to diagnose and solve common problems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice, case studies",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Computers with simulated faults for practice",
                            "type": "equipment",
                        },
                        {
                            "text": "Troubleshooting checklists",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Installing and Configuring Software",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Installing an Operating System",
                            "learning_objectives": [
                                {
                                    "objective": "Install an operating system on a computer",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Installing Application Software and Drivers",
                            "learning_objectives": [
                                {
                                    "objective": "Install application software and device drivers and configure settings",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice, guided instruction",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Operating system installation media",
                            "type": "digital",
                        },
                        {
                            "text": "Computers for software installation practice",
                            "type": "equipment",
                        },
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Disk Management",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Partitioning and Formatting",
                            "learning_objectives": [
                                {
                                    "objective": "Explain disk partitioning and formatting and the main file systems including FAT, NTFS and ext4",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                            ],
                        },
                        {
                            "title": "Maintenance Utilities",
                            "learning_objectives": [
                                {
                                    "objective": "Use disk maintenance utilities such as disk cleanup, defragmentation and disk checking",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Computers with disk management tools",
                            "type": "ict",
                        },
                        {
                            "text": "File system comparison charts",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "System Backup and Recovery",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Importance of Backup",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the importance of backing up data and systems",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                            ],
                        },
                        {
                            "title": "Backup Methods",
                            "learning_objectives": [
                                {
                                    "objective": "Describe full, incremental and differential backup methods",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                            ],
                        },
                        {
                            "title": "System Restore",
                            "learning_objectives": [
                                {
                                    "objective": "Perform a system restore to recover a computer after failure",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice, demonstration",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "External storage for backup practice",
                            "type": "equipment",
                        },
                        {
                            "text": "Backup software tools",
                            "type": "ict",
                        },
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Computer Security and Protection",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Security Threats",
                            "learning_objectives": [
                                {
                                    "objective": "Describe computer security threats including malware, phishing and social engineering",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, case studies",
                                },
                            ],
                        },
                        {
                            "title": "Prevention Measures",
                            "learning_objectives": [
                                {
                                    "objective": "Apply measures to prevent and protect against computer security threats",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Cybercrime",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze the impact and legal aspects of cybercrime",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Research, class presentation",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Antivirus software for demonstration",
                            "type": "ict",
                        },
                        {
                            "text": "Cybercrime case study articles",
                            "type": "digital",
                        },
                        {
                            "text": "Computer security handouts",
                            "type": "reference",
                        },
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 3 — APPLICATION SOFTWARE
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 3,
            "name": "Application Software",
            "description": (
                "Use common application software such as word processors, "
                "spreadsheets, databases and presentation packages to solve "
                "everyday problems."
            ),
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Introduction to Word Processing",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Word Processing Basics",
                            "learning_objectives": [
                                {
                                    "objective": "Define word processing and identify its features",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                                {
                                    "objective": "Create and edit simple text documents using a word processor",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Word processing software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Sample documents for editing practice",
                            "type": "digital",
                        },
                    ],
                },
                {
                    "title": "Introduction to Spreadsheets",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Spreadsheet Basics",
                            "learning_objectives": [
                                {
                                    "objective": "Define a spreadsheet and explain its purpose and basic concepts",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                                {
                                    "objective": "Enter and manage data in a simple spreadsheet",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Spreadsheet software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Sample spreadsheet data files",
                            "type": "digital",
                        },
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Word Processing",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Formatting Documents",
                            "learning_objectives": [
                                {
                                    "objective": "Apply text and paragraph formatting and page setup options",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Advanced Word Processing Features",
                            "learning_objectives": [
                                {
                                    "objective": "Use tables, mail merge and graphics in a word processing document",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice, guided instruction",
                                },
                            ],
                        },
                        {
                            "title": "Printing Documents",
                            "learning_objectives": [
                                {
                                    "objective": "Prepare and print documents correctly",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Word processing software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Printer for practice printing",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Spreadsheets",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Worksheets and Cell Referencing",
                            "learning_objectives": [
                                {
                                    "objective": "Describe cell data types and apply cell referencing in worksheets",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice, guided instruction",
                                },
                            ],
                        },
                        {
                            "title": "Formulae and Functions",
                            "learning_objectives": [
                                {
                                    "objective": "Use formulae and built-in functions to perform calculations",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Data Management and Charts",
                            "learning_objectives": [
                                {
                                    "objective": "Manage data and create charts and graphs in a spreadsheet",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Spreadsheet software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Sample data for spreadsheet exercises",
                            "type": "digital",
                        },
                    ],
                },
                {
                    "title": "Databases",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Database Concepts",
                            "learning_objectives": [
                                {
                                    "objective": "Define a database and describe its types, models, features and benefits",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Introduction to DBMS",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the functions of a database management system",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Database software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Sample database files for demonstration",
                            "type": "digital",
                        },
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Advanced Spreadsheets",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Sorting and Filtering",
                            "learning_objectives": [
                                {
                                    "objective": "Sort and filter data in a spreadsheet",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Advanced Formulae and Charts",
                            "learning_objectives": [
                                {
                                    "objective": "Use advanced formulae and create complex charts and graphs",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice, guided instruction",
                                },
                            ],
                        },
                        {
                            "title": "Importing and Linking Files",
                            "learning_objectives": [
                                {
                                    "objective": "Import and link external files into a spreadsheet",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Spreadsheet software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "External data files for import practice",
                            "type": "digital",
                        },
                    ],
                },
                {
                    "title": "Database Design",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Tables and Relationships",
                            "learning_objectives": [
                                {
                                    "objective": "Design database tables with fields, records and appropriate data types",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice, design exercises",
                                },
                            ],
                        },
                        {
                            "title": "Keys and Normalization",
                            "learning_objectives": [
                                {
                                    "objective": "Explain primary and foreign keys and the relationships between tables",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, diagrams",
                                },
                            ],
                        },
                        {
                            "title": "Normalization",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the principles of normalization to reduce data redundancy",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice, case studies",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Database software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Database design case studies",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Presentation Software",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Creating Presentations",
                            "learning_objectives": [
                                {
                                    "objective": "Define presentation software and identify its features",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                            ],
                        },
                        {
                            "title": "Enhancing Presentations",
                            "learning_objectives": [
                                {
                                    "objective": "Create and edit slides with animations and transitions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Printing and Presenting",
                            "learning_objectives": [
                                {
                                    "objective": "Print a presentation and deliver it to an audience",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice, presentations",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Presentation software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Projector for presentations",
                            "type": "equipment",
                        },
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Advanced Database Management",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Queries, Forms and Reports",
                            "learning_objectives": [
                                {
                                    "objective": "Create queries, forms and reports in a database",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice, guided instruction",
                                },
                            ],
                        },
                        {
                            "title": "Data Validation",
                            "learning_objectives": [
                                {
                                    "objective": "Apply data validation rules to ensure data integrity",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                        {
                            "title": "Switchboards",
                            "learning_objectives": [
                                {
                                    "objective": "Create a switchboard to navigate a database application",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Database software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Sample database projects for analysis",
                            "type": "digital",
                        },
                    ],
                },
                {
                    "title": "Desktop Publishing",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Layout Design",
                            "learning_objectives": [
                                {
                                    "objective": "Apply layout design and page formatting principles in a desktop publishing document",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice, design exercises",
                                },
                            ],
                        },
                        {
                            "title": "Graphics and Printing",
                            "learning_objectives": [
                                {
                                    "objective": "Integrate graphics into a publication and print it correctly",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Desktop publishing software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Sample publications for reference",
                            "type": "reference",
                        },
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 4 — NETWORKING AND DATA COMMUNICATION
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 4,
            "name": "Networking and Data Communication",
            "description": (
                "Understand networking concepts and be able to use the "
                "internet and related technologies for communication and "
                "data sharing."
            ),
            "topics": [
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Introduction to the Internet and Email",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "The Internet and the World Wide Web",
                            "learning_objectives": [
                                {
                                    "objective": "Define the internet and explain the World Wide Web, browsers and search engines",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, online demonstration",
                                },
                            ],
                        },
                        {
                            "title": "Email Basics",
                            "learning_objectives": [
                                {
                                    "objective": "Create and use an email account to send and receive messages",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Computers with internet access",
                            "type": "ict",
                        },
                        {
                            "text": "Email setup guides",
                            "type": "reference",
                        },
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Networking Fundamentals",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Introduction to Networks",
                            "learning_objectives": [
                                {
                                    "objective": "Define a computer network and explain its benefits",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Network Topologies",
                            "learning_objectives": [
                                {
                                    "objective": "Describe bus, star, ring and mesh network topologies",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, diagrams, group work",
                                },
                            ],
                        },
                        {
                            "title": "LAN, WAN and MAN",
                            "learning_objectives": [
                                {
                                    "objective": "Distinguish between LAN, WAN and MAN networks",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, examples",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Network topology diagrams",
                            "type": "reference",
                        },
                        {
                            "text": "Networking equipment and cables",
                            "type": "equipment",
                        },
                    ],
                },
                {
                    "title": "Network Protocols and Addressing",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Network Protocols",
                            "learning_objectives": [
                                {
                                    "objective": "Explain network protocols and the role of TCP/IP",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "IP and MAC Addressing",
                            "learning_objectives": [
                                {
                                    "objective": "Describe IP addresses, MAC addresses and port numbers",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, hands-on configuration",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Computers to view IP settings",
                            "type": "ict",
                        },
                        {
                            "text": "Instructor network configuration guides",
                            "type": "reference",
                        },
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Internet and Network Applications",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Internet Applications",
                            "learning_objectives": [
                                {
                                    "objective": "Describe internet applications including the World Wide Web, social networks and email",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                            ],
                        },
                        {
                            "title": "Distributed Applications",
                            "learning_objectives": [
                                {
                                    "objective": "Explain distributed applications and their uses",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, online demonstration",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Computers with internet access",
                            "type": "ict",
                        },
                        {
                            "text": "Distributed application case studies",
                            "type": "digital",
                        },
                    ],
                },
                {
                    "title": "Network Security",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Security Technologies",
                            "learning_objectives": [
                                {
                                    "objective": "Describe firewalls, encryption and VPNs and their role in network security",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Safe Browsing",
                            "learning_objectives": [
                                {
                                    "objective": "Apply safe browsing practices to protect personal information online",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Firewall and VPN software for demonstration",
                            "type": "ict",
                        },
                        {
                            "text": "Safe browsing practice guides",
                            "type": "reference",
                        },
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 5 — PROGRAMMING TECHNIQUES AND LOGICAL METHODS
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 5,
            "name": "Programming Techniques and Logical Methods",
            "description": (
                "Develop logical thinking and programming skills to design, "
                "write, test and document computer programs."
            ),
            "topics": [
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Introduction to Programming",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Programming Languages",
                            "learning_objectives": [
                                {
                                    "objective": "Define programming and describe the history of programming languages",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, discussion",
                                },
                                {
                                    "objective": "Distinguish between machine, assembly and high-level languages",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Lecture, comparison charts",
                                },
                            ],
                        },
                        {
                            "title": "Compilers and Interpreters",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the functions of compilers and interpreters",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, demonstrations",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Sample programs in different languages",
                            "type": "digital",
                        },
                        {
                            "text": "Programming language comparison charts",
                            "type": "reference",
                        },
                    ],
                },
                {
                    "title": "Basic Programming Concepts",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Variables and Data Types",
                            "learning_objectives": [
                                {
                                    "objective": "Define variables and data types and use operators and input/output statements",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Control Structures",
                            "learning_objectives": [
                                {
                                    "objective": "Describe sequence, selection and iteration control structures",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, flowcharts, practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Programming software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Flowchart symbols reference charts",
                            "type": "reference",
                        },
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Programming in BASIC",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Program Structure and Statements",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the structure of a BASIC program and its keywords and variables",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Conditionals and Loops",
                            "learning_objectives": [
                                {
                                    "objective": "Use IF-THEN-ELSE conditionals and FOR-NEXT and WHILE-WEND loops",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on programming practice",
                                },
                            ],
                        },
                        {
                            "title": "Input and Output Statements",
                            "learning_objectives": [
                                {
                                    "objective": "Write BASIC programs using input, output and operator statements",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on programming practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "BASIC interpreter or compiler",
                            "type": "ict",
                        },
                        {
                            "text": "BASIC programming reference manuals",
                            "type": "textbook",
                        },
                    ],
                },
                {
                    "title": "Arrays and File Handling",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Arrays",
                            "learning_objectives": [
                                {
                                    "objective": "Use one-dimensional and two-dimensional arrays in programs",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on programming practice",
                                },
                            ],
                        },
                        {
                            "title": "File Operations",
                            "learning_objectives": [
                                {
                                    "objective": "Perform file operations of opening, reading, writing and closing files",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Hands-on programming practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Programming software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Sample array and file handling programs",
                            "type": "digital",
                        },
                    ],
                },
                {
                    "title": "Program Development",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Problem Definition and Algorithm Design",
                            "learning_objectives": [
                                {
                                    "objective": "Define a problem and design an algorithm using flowcharts and pseudocode",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Guided practice, design exercises",
                                },
                            ],
                        },
                        {
                            "title": "Coding, Testing and Documentation",
                            "learning_objectives": [
                                {
                                    "objective": "Write code, test a program and produce documentation",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, hands-on practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Programming software installed on computers",
                            "type": "ict",
                        },
                        {
                            "text": "Software development lifecycle charts",
                            "type": "reference",
                        },
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 6 — SOCIETY AND ICT
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 6,
            "name": "Society and ICT",
            "description": (
                "Understand the ethical, legal and social implications of ICT "
                "and explore careers and emerging technologies in the field."
            ),
            "topics": [
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Ethical Use of Computers",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Responsible Use",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the responsible use of computers and intellectual property",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                                {
                                    "objective": "Describe software piracy and plagiarism and their consequences",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, examples",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Case studies on intellectual property",
                            "type": "reference",
                        },
                        {
                            "text": "Ethics posters and handouts",
                            "type": "reference",
                        },
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "ICT and Society",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Impact of ICT",
                            "learning_objectives": [
                                {
                                    "objective": "Analyze the impact of ICT on education, health, the economy and communication",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Research, discussion",
                                },
                            ],
                        },
                        {
                            "title": "The Digital Divide",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the concept of the digital divide and its effects",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, case studies",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "ICT impact case studies",
                            "type": "reference",
                        },
                        {
                            "text": "Computers for internet research",
                            "type": "ict",
                        },
                    ],
                },
                {
                    "title": "Computer Ethics and Laws",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Copyright and Data Protection",
                            "learning_objectives": [
                                {
                                    "objective": "Explain copyright and data protection laws",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Computer Misuse Laws",
                            "learning_objectives": [
                                {
                                    "objective": "Describe computer misuse laws and their penalties",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Lecture, case studies",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Copyright and data protection law handouts",
                            "type": "reference",
                        },
                        {
                            "text": "Computer misuse case studies",
                            "type": "digital",
                        },
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Career Opportunities in ICT",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "IT Professions and Career Paths",
                            "learning_objectives": [
                                {
                                    "objective": "Identify IT professions and describe the skills required for ICT careers",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, guest speakers",
                                },
                            ],
                        },
                        {
                            "title": "The ICT Industry in Malawi",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the ICT industry and career opportunities in Malawi",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Research, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "ICT career information brochures",
                            "type": "reference",
                        },
                        {
                            "text": "Computers for career research",
                            "type": "ict",
                        },
                    ],
                },
                {
                    "title": "Emerging Technologies",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Overview of Emerging Technologies",
                            "learning_objectives": [
                                {
                                    "objective": "Describe artificial intelligence, cloud computing, IoT, blockchain and robotics",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Lecture, video demonstrations",
                                },
                            ],
                        },
                        {
                            "title": "Applications of Emerging Technologies",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the applications of emerging technologies in daily life",
                                    "cognitive_level": "Comprehension",
                                    "teaching_method": "Discussion, video demonstrations",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Videos on emerging technologies",
                            "type": "digital",
                        },
                        {
                            "text": "Computers with cloud access for demonstrations",
                            "type": "ict",
                        },
                    ],
                },
                {
                    "title": "ICT Project Management",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Project Planning and Implementation",
                            "learning_objectives": [
                                {
                                    "objective": "Plan, implement and evaluate an ICT project to solve a community problem",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Project work, group planning",
                                },
                            ],
                        },
                        {
                            "title": "ICT Solutions for Community Problems",
                            "learning_objectives": [
                                {
                                    "objective": "Propose ICT solutions to address community problems",
                                    "cognitive_level": "Synthesis",
                                    "teaching_method": "Group project, presentations",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "Project management templates",
                            "type": "reference",
                        },
                        {
                            "text": "Computers with access to project tools",
                            "type": "ict",
                        },
                    ],
                },
            ],
        },
    ],
}


async def seed_computer_studies_syllabus():
    """Seed the Malawi Computer Studies syllabus. Idempotent — skips if already seeded."""
    async with async_session() as db:
        existing = await db.execute(
            select(SyllabusSubject).where(SyllabusSubject.slug == "computer-science")
        )
        if existing.scalar_one_or_none():
            return

        data = COMPUTER_STUDIES_SYLLABUS
        subject_data = data["subject"]
        subject = SyllabusSubject(
            name=subject_data["name"],
            slug=subject_data["slug"],
            description=subject_data.get("description", ""),
            icon=subject_data.get("icon", "computer"),
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
