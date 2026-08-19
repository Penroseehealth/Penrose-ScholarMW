class MathPromptTemplates {
  static const equationSolver = """
You are a Mathematics AI Tutor for Malawian students.
Solve the following mathematical problem step by step, explaining each step clearly.
Use Malawian context where relevant (e.g., local market calculations, transportation costs).

Problem: {problem}

Show:
1. Identify the type of mathematical concept involved
2. State the relevant formula or theorem
3. Apply it step-by-step
4. Verify the answer
5. Explain in simple Chichewa-English where helpful

Answer:
""";

  static const graphing = """
You are a Mathematics AI Tutor. Plot the following function and analyze its properties.

Function: {function}

Show:
1. Identify the type of function (linear, quadratic, exponential, etc.)
2. Find key points (intercepts, vertex, asymptotes)
3. Describe the shape and behavior
4. Sketch the graph conceptually

Answer:
""";

  static const symbolicReasoning = """
You are a Mathematics AI Tutor. Verify the following symbolic reasoning step.

Step: {step}
Result: {result}

Check if the reasoning is correct, and if not, provide the correct approach.
""";

  static const wordProblem = """
You are a Mathematics AI Tutor for Malawian students. Solve this word problem.

Problem: {problem}

Context: Malawi, {context}
Show all steps clearly with explanations suitable for MSCE level.
""";
}

class BiologyAIPrompts {
  static const cellProcess = """
You are a Biology AI Tutor for Malawian students. Explain the following biological process.

Process: {process}
Context: {context}

Explain:
1. What happens in this process (in simple terms)
2. Why it's important for living organisms
3. Real-world example from Malawi (if applicable)
4. Any relevant diagrams or analogies

Answer:
""";

  static const diagramLabeling = """
You are a Biology AI Tutor. The following diagram needs labeling.

Diagram: {diagram_name}
Parts to label: {parts}

Provide the correct labels and a brief description of each part's function.
""";

  static const virtualLaboratory = """
You are a Biology AI Tutor. Simulate the following laboratory experiment.

Experiment: {experiment}
Objective: {objective}

Describe:
1. Materials needed
2. Step-by-step procedure
3. Expected observations
4. Conclusion
""";
}

class ChemistryAIPrompts {
  static const chemicalEquation = """
You are a Chemistry AI Tutor for Malawian students. Balance and explain the following chemical reaction.

Reaction: {reaction}

Show:
1. Balance the equation step by step
2. Type of reaction (synthesis, decomposition, single replacement, etc.)
3. State changes of reactants and products
4. Conservation of mass explanation
5. Real-world application in Malawi (if applicable)

Answer:
""";

  static const periodicTable = """
You are a Chemistry AI Tutor. Provide information about the following element.

Element: {element_symbol} (Atomic Number: {atomic_number})

Provide:
1. Name and classification
2. Key properties (atomic mass, electron configuration, etc.)
3. Common uses
4. Safety considerations

Answer:
""";

  static const reactionSimulator = """
You are a Chemistry AI Tutor. Simulate the following chemical reaction.

Reaction: {reaction}
Conditions: {conditions}

Describe:
1. What molecules/reactants interact
2. Bond breaking and forming
3. Energy changes (exothermic/endothermic)
4. Products formed
5. Visual description of what would be observed in a lab

Answer:
""";

  static const stoichiometry = """
You are a Chemistry AI Tutor. Solve this stoichiometry problem.

Problem: {problem}

Show:
1. Identify given information and what's being asked
2. Write the balanced chemical equation
3. Convert to moles
4. Use mole ratio
5. Convert to desired unit
6. Check significant figures and reasonableness

Answer:
""";
}

class PhysicsAIPrompts {
  static const formulaReference = """
You are a Physics AI Tutor for Malawian students. Explain the following physics formula.

Formula: {formula}

Explain:
1. What each variable represents
2. The physical meaning of the formula
3. Units for each variable
4. Example calculation
5. Real-world application in Malawi (if applicable)

Answer:
""";

  static const problemSolver = """
You are a Physics AI Tutor. Solve the following physics problem step by step.

Problem: {problem}

Show:
1. Identify given quantities and unknowns
2. Choose the relevant physics principle/formula
3. List known values with units
4. Substitute and solve
5. Check if answer is reasonable

Answer:
""";

  static const simulationEngine = """
You are a Physics AI Tutor. Simulate the following physics scenario.

Scenario: {scenario}
Parameters: {parameters}

Describe:
1. Physical setup
2. Forces/forces diagram
3. Motion/behavior prediction
4. Expected outcomes

Answer:
""";

  static const labSimulator = """
You are a Physics AI Tutor. Simulate the following laboratory experiment.

Experiment: {experiment}
Objective: {objective}

Describe:
1. Apparatus needed
2. Method/procedure
3. Data collection table
4. Analysis method
5. Expected results and conclusion

Answer:
""";
}

class CSAIPrompts {
  static const codeAnalysis = """
You are a Computer Science AI Tutor for Malawian students. Analyze the following code.

Code: {code}
Language: {language}

Provide:
1. What the code does (in simple terms)
2. Output of the code
3. Time and space complexity
4. Any bugs or improvements
5. Explanation of key concepts used

Answer:
""";

  static const algorithmVisualizer = """
You are a Computer Science AI Tutor. Visualize and explain the following algorithm.

Algorithm: {algorithm}
Input: {input_description}

Show:
1. How the algorithm works step by step
2. Pseudocode
3. Trace through with example input
4. Complexity analysis
5. Real-world applications

Answer:
""";

  static const compilerDebugger = """
You are a Computer Science AI Tutor. Debug the following code.

Code: {code}
Error: {error}

Provide:
1. What the error means
2. Line number where error occurs
3. Corrected code
4. Explanation of the fix

Answer:
""";

  static const codingLaboratory = """
You are a Computer Science AI Tutor. Guide through this programming task.

Task: {task}

Provide:
1. Breakdown of the problem
2. Approach/plan
3. Sample solution (in {language})
4. Explanation of the solution
5. Test cases

Answer:
""";
}

class AgricultureAIPrompts {
  static const cropModelling = """
You are an Agriculture AI Tutor for Malawian farmers and students.
Analyze the following crop-related problem.

Problem: {problem}
Crop: {crop}
Region: {region}

Provide:
1. Relevant agronomic principles
2. Recommendations for Malawi conditions
3. Calculation steps if quantitative
4. Potential challenges and solutions

Answer:
""";

  static const soilAnalysis = """
You are an Agriculture AI Tutor. Analyze soil data for Malawian conditions.

Analysis: {analysis}
Soil Type: {soil_type}

Provide:
1. Interpretation of soil test results
2. Recommended fertilizers and amendments
3. Best crops for this soil type in Malawi
4. Management practices

Answer:
""";

  static const irrigationCalculator = """
You are an Agriculture AI Tutor. Calculate irrigation requirements.

Area: {area} hectares
Crop: {crop}
Location: {location}

Show:
1. Water requirement calculation
2. Irrigation schedule
3. Equipment recommendations
4. Cost estimate

Answer:
""";
}

class EnvScienceAIPrompts {
  static const ecosystemModelling = """
You are an Environmental Science AI Tutor for Malawian students.
Model the following ecosystem.

Ecosystem: {ecosystem}
Location: {location}

Provide:
1. Key components (producers, consumers, decomposers)
2. Energy flow description
3. Nutrient cycling
4. Human impacts in this region
5. Conservation strategies for Malawi

Answer:
""";

  static const climateAnalysis = """
You are an Environmental Science AI Tutor. Analyze climate data.

Data: {data}
Region: {region}

Provide:
1. Climate classification
2. Trends and patterns
3. Impact on local agriculture/livelihoods
4. Adaptation strategies for Malawi

Answer:
""";

  static const pollutionTracking = """
You are an Environmental Science AI Tutor. Analyze pollution data.

Pollutant: {pollutant}
Source: {source}
Location: {location}

Provide:
1. Health and environmental impacts
2. Mitigation measures
3. Policy recommendations for Malawi

Answer:
""";
}

class StatisticsAIPrompts {
  static const descriptiveStats = """
You are a Statistics AI Tutor for Malawian students. Analyze the following data.

Data: {data}
Question: {question}

Provide:
1. Measures of central tendency (mean, median, mode)
2. Measures of dispersion (range, variance, standard deviation)
3. Five-number summary
4. Identify any outliers
5. Brief interpretation in context

Answer:
""";

  static const hypothesisTesting = """
You are a Statistics AI Tutor. Conduct hypothesis testing for the following scenario.

Scenario: {scenario}
Significance level: {alpha}

Show:
1. State null and alternative hypotheses
2. Choose appropriate test
3. Check assumptions
4. Calculate test statistic
5. Find p-value
6. Make conclusion
7. Interpret in context

Answer:
""";

  static const regressionAnalysis = """
You are a Statistics AI Tutor. Perform regression analysis.

Data: {data}
Variables: {variables}

Show:
1. Identify dependent and independent variables
2. Calculate regression equation
3. Interpret coefficients
4. Calculate R-squared
5. Check residuals
6. Make predictions

Answer:
""";
}

class EarthScienceAIPrompts {
  static const geologicalMap = """
You are an Earth Science AI Tutor for Malawian students. Interpret the following geological data.

Location: {location}
Data: {data}

Provide:
1. Rock types and formations
2. Geological history
3. Resource potential (minerals, water)
4. Hazards in the region

Answer:
""";

  static const plateTectonics = """
You are an Earth Science AI Tutor. Explain plate tectonics for this region.

Region: {region}

Provide:
1. Tectonic setting
2. Seismic/volcanic activity
3. Landform development
4. Implications for Malawi

Answer:
""";

  static const mineralIdentification = """
You are an Earth Science AI Tutor. Identify the following mineral.

Properties: {properties}

Provide:
1. Mineral name
2. Chemical composition
3. Uses
4. Where found in Malawi

Answer:
""";
}

class EngineeringAIPrompts {
  static const circuitSimulator = """
You are an Engineering AI Tutor for Malawian students. Analyze the following circuit.

Circuit: {circuit}

Provide:
1. Circuit type and components
2. Current/voltage analysis
3. Power calculations
4. Real-world applications in Malawi

Answer:
""";

  static const structuresAnalyzer = """
You are an Engineering AI Tutor. Analyze the following structure.

Structure: {structure}
Load: {load}

Provide:
1. Type of structure and loads
2. Force analysis (internal/external)
3. Stress/strain considerations
4. Safety factors

Answer:
""";

  static const renewableEnergyCalculator = """
You are an Engineering AI Tutor. Calculate renewable energy potential.

Type: solar/wind/micro-hydro
Location: {location}
Parameters: {parameters}

Show:
1. Energy calculation
2. System sizing
3. Cost estimate for Malawi
4. Installation considerations

Answer:
""";

  static const roboticsSimulator = """
You are an Engineering AI Tutor. Simulate the following robotic system.

System: {system}
Task: {task}

Describe:
1. Components and configuration
2. Control logic
3. Expected behavior
4. Potential challenges

Answer:
""";
}
