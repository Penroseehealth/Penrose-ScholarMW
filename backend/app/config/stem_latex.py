STEM_LATEX_INSTRUCTION = (
    "\n\nCRITICAL — Mathematical & Scientific Notation:\n"
    "ALL mathematical expressions, equations, formulas, and scientific notation "
    "MUST be wrapped in LaTeX delimiters:\n"
    "- Inline math: wrap with \\( and \\) → e.g. \\(x^2 + 5x + 6 = 0\\)\n"
    "- Block equations (standalone, centered): wrap with \\[ and \\] → "
    "e.g. \\[\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\\]\n"
    "NEVER write LaTeX commands (like \\frac, \\sqrt, \\rightarrow, \\text) "
    "without wrapping them in \\(...\\) or \\[...\\] delimiters.\n\n"
    "Chemical formulas and equations — CRITICAL FORMATTING:\n"
    "- Chemical formulas MUST use LaTeX with subscripts/superscripts inside delimiters:\n"
    "  \\(H_2O\\), \\(CO_2\\), \\(C_6H_{12}O_6\\), \\(H_2SO_4\\), \\(Na^+\\), \\(SO_4^{2-}\\)\n"
    "- Chemical equations MUST use \\rightarrow for reaction arrows:\n"
    "  \\(6CO_2 + 6H_2O \\xrightarrow{\\text{light}} C_6H_{12}O_6 + 6O_2\\)\n"
    "- Equilibrium arrows: \\(\\rightleftharpoons\\)\n"
    "- State symbols: \\((aq)\\), \\((s)\\), \\((l)\\), \\((g)\\)\n"
    "- Stoichiometric coefficients go BEFORE the formula: \\(2H_2 + O_2 \\rightarrow 2H_2O\\)\n\n"
    "Other LaTeX notation:\n"
    "- Fractions: \\(\\frac{a}{b}\\), roots: \\(\\sqrt{x}\\), \\(\\sqrt[n]{x}\\)\n"
    "- Integrals: \\(\\int\\), summations: \\(\\sum\\), limits: \\(\\lim\\)\n"
    "- Greek letters: \\(\\alpha\\), \\(\\beta\\), \\(\\pi\\), \\(\\theta\\)\n"
    "- Vectors: \\(\\vec{F}\\), matrices: \\(\\begin{bmatrix}...\\end{bmatrix}\\)\n"
    "- Units inside text: \\(\\text{m/s}\\), \\(\\text{kg}\\), \\(\\text{mol}\\)\n"
    "- Comparison: \\(=\\), \\(\\neq\\), \\(\\approx\\), \\(\\leq\\), \\(\\geq\\)\n"
    "- Arrows: \\(\\rightarrow\\), \\(\\leftarrow\\), \\(\\leftrightarrow\\)\n\n"
    "NEVER write important mathematical expressions as plain text. "
    "Every equation, formula, and scientific expression must be in LaTeX delimiters. "
    "The app renders them as properly typeset mathematical notation."
    "\n\nVISUAL REPRESENTATIONS — ALWAYS include a visual when the topic involves "
    "data, graphs, charts, geometry, functions, statistics, or any visual concept. "
    "Append a JSON visual block at the end of your response:\n"
    "Format: <!--visual:{...}-->\n"
    "Supported types — pick the BEST fit for the data:\n"
    '  - graph: for functions/plots → {"type":"graph","expression":"x^2","title":"Parabola","xMin":-5,"xMax":5,"yMin":-5,"yMax":5}\n'
    '  - bar_chart: for comparing categories → {"type":"bar_chart","title":"Scores","labels":["A","B","C"],"values":[10,20,15]}\n'
    '  - pie_chart: for proportions/percentages → {"type":"pie_chart","title":"Distribution","labels":["X","Y"],"values":[40,60]}\n'
    '  - histogram: for frequency distributions → {"type":"histogram","title":"Frequency","values":[5,12,8,3]}\n'
    '  - line_chart: for trends over time → {"type":"line_chart","title":"Trend","values":[2,5,8,4,9]}\n'
    '  - frequency_polygon: for grouped frequency data → {"type":"frequency_polygon","title":"FP","values":[3,8,15,10,5]}\n'
    '  - cumulative_frequency: for cumulative distributions → {"type":"cumulative_frequency","title":"CF","values":[10,25,45,70,90]}\n'
    '  - shape: for geometry → {"type":"shape","shape":"triangle"} (or circle, quadrilateral, parallelogram, trapezium, right_triangle)\n'
    '  - angle: → {"type":"shape","shape":"angle","points":[[1,1],[0,0],[-1,0.5]]}\n'
    '  - tangent: → {"type":"shape","shape":"tangent","title":"Tangent line"}\n'
    "You may include multiple <!--visual:...--> blocks. ALWAYS use visuals when "
    "the student asks to see data, compare values, analyze statistics, plot functions, "
    "or draw shapes. The app renders them automatically with interactive editable grids."
)
