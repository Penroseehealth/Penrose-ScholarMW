import re

with open("backend/app/mathematics/seed_math_syllabus.py", "r", encoding="utf-8") as f:
    content = f.read()

# Find the FORM 4 Statistics section and replace it
old_marker = '''                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Statistics",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Correlation and Regression",
                            "description": "Scatter diagrams, line of best fit and correlation.",
                            "learning_objectives": [
                                {
                                    "objective": "Draw scatter diagrams to investigate the relationship between two variables",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Draw and interpret the line of best fit",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Distinguish between positive, negative and no correlation",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                        {
                            "title": "Measures of Location from Grouped Data",
                            "description": "Estimating the mean, median and mode from grouped frequency tables.",
                            "learning_objectives": [
                                {
                                    "objective": "Estimate the mean from a grouped frequency table",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Estimate the median from a grouped frequency table",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                    ],
                },'''

new_block = '''                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Statistics",
                    "year_level": 4,
                    "description": "Outcome: Demonstrate an understanding of basic concepts of data handling procedures and apply them in everyday life.",
                    "subtopics": [
                        {
                            "title": "Organising Data",
                            "description": "Classifying grouped data, forming class intervals, determining class boundaries, finding mid-points, finding frequencies of grouped and non-grouped data.",
                            "learning_objectives": [
                                {
                                    "objective": "Classify grouped data into appropriate categories",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, projects, group work, demonstration",
                                },
                                {
                                    "objective": "Form class intervals for a given data set",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, question and answer",
                                },
                                {
                                    "objective": "Determine class boundaries and find mid-points of class intervals",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, written exercises, group assessment",
                                },
                                {
                                    "objective": "Find frequencies of grouped and non-grouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, written exercises, observation",
                                },
                            ],
                        },
                        {
                            "title": "Presenting Data in Charts and Tables",
                            "description": "Presenting data in the form of frequency tables, histograms, pie charts and frequency polygons.",
                            "learning_objectives": [
                                {
                                    "objective": "Present data in the form of frequency tables",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, projects, group work, demonstration",
                                },
                                {
                                    "objective": "Draw and interpret histograms from grouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, written exercises, question and answer",
                                },
                                {
                                    "objective": "Construct and interpret pie charts",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, group assessment, observation",
                                },
                                {
                                    "objective": "Draw and interpret frequency polygons",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, explanation, group assessment",
                                },
                            ],
                        },
                        {
                            "title": "Measures of Central Tendency and Spread",
                            "description": "Calculating the median of ungrouped data, mean of grouped data, mode of grouped data, and range of data.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the median of ungrouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, question and answer",
                                },
                                {
                                    "objective": "Calculate the mean of grouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, written exercises, group assessment",
                                },
                                {
                                    "objective": "Find the mode of grouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, written exercises, peer assessment",
                                },
                                {
                                    "objective": "Calculate the range of a data set",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Interpreting Data",
                            "description": "Interpreting data using measures of central tendency and spread.",
                            "learning_objectives": [
                                {
                                    "objective": "Interpret data using measures of central tendency and spread",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, group work, projects",
                                },
                            ],
                        },
                        {
                            "title": "Measures of Spread",
                            "description": "Discussing variance, calculating variance, discussing standard deviation, calculating standard deviation of ungrouped data.",
                            "learning_objectives": [
                                {
                                    "objective": "Discuss variance as a measure of spread",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation",
                                },
                                {
                                    "objective": "Calculate variance of ungrouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, practical work, group assessment",
                                },
                                {
                                    "objective": "Discuss standard deviation as a measure of spread",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, question and answer",
                                },
                                {
                                    "objective": "Calculate standard deviation of ungrouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, practical work, peer assessment",
                                },
                            ],
                        },
                        {
                            "title": "Interpreting Data Using Measures of Spread",
                            "description": "Interpreting data using variance and standard deviation.",
                            "learning_objectives": [
                                {
                                    "objective": "Interpret data using variance",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, group work, observation, explanation",
                                },
                                {
                                    "objective": "Interpret data using standard deviation",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, projects, written exercises, group assessment",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                        {"text": "Mathematical instruments", "type": "equipment"},
                        {"text": "Calculators", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },'''

if old_marker in content:
    content = content.replace(old_marker, new_block, 1)
    with open("backend/app/mathematics/seed_math_syllabus.py", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced CE5 Form 4 Statistics successfully")
else:
    print("ERROR: Old marker not found")
