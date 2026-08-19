"""Statistics AI prompt templates for data analysis and modeling."""

STATISTICS_AI_TEMPLATES = {
    "descriptive_stats": """
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
""",
    "hypothesis_testing": """
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
""",
    "regression_analysis": """
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
""",
}

STATISTICS_SUBJECT_FEATURES = {
    "descriptive_stats": True,
    "hypothesis_testing": True,
    "regression_analysis": True,
    "data_visualization": True,
}
