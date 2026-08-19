import 'package:flutter/material.dart';

enum SubjectModule {
  mathematics,
  biology,
  chemistry,
  physics,
  computerScience,
  agriculture,
  environmentalScience,
  statistics,
  earthScience,
  engineeringTechnology;

  String get slug {
    switch (this) {
      case SubjectModule.mathematics:
        return 'mathematics';
      case SubjectModule.biology:
        return 'biology';
      case SubjectModule.chemistry:
        return 'chemistry';
      case SubjectModule.physics:
        return 'physics';
      case SubjectModule.computerScience:
        return 'computer-science';
      case SubjectModule.agriculture:
        return 'agriculture';
      case SubjectModule.environmentalScience:
        return 'environmental-science';
      case SubjectModule.statistics:
        return 'statistics';
      case SubjectModule.earthScience:
        return 'earth-science';
      case SubjectModule.engineeringTechnology:
        return 'engineering-technology';
    }
  }

  String get title {
    switch (this) {
      case SubjectModule.mathematics:
        return 'Mathematics';
      case SubjectModule.biology:
        return 'Biology';
      case SubjectModule.chemistry:
        return 'Chemistry';
      case SubjectModule.physics:
        return 'Physics';
      case SubjectModule.computerScience:
        return 'Computer Science';
      case SubjectModule.agriculture:
        return 'Agriculture';
      case SubjectModule.environmentalScience:
        return 'Environmental Science';
      case SubjectModule.statistics:
        return 'Statistics';
      case SubjectModule.earthScience:
        return 'Earth & Geosciences';
      case SubjectModule.engineeringTechnology:
        return 'Engineering & Technology';
    }
  }

  IconData get icon {
    switch (this) {
      case SubjectModule.mathematics:
        return Icons.calculate;
      case SubjectModule.biology:
        return Icons.biotech;
      case SubjectModule.chemistry:
        return Icons.science;
      case SubjectModule.physics:
        return Icons.bolt;
      case SubjectModule.computerScience:
        return Icons.computer;
      case SubjectModule.agriculture:
        return Icons.agriculture;
      case SubjectModule.environmentalScience:
        return Icons.eco;
      case SubjectModule.statistics:
        return Icons.bar_chart;
      case SubjectModule.earthScience:
        return Icons.public;
      case SubjectModule.engineeringTechnology:
        return Icons.precision_manufacturing;
    }
  }

  Color get color {
    switch (this) {
      case SubjectModule.mathematics:
        return const Color(0xFF8B5CF6);
      case SubjectModule.biology:
        return const Color(0xFF10B981);
      case SubjectModule.chemistry:
        return const Color(0xFFF59E0B);
      case SubjectModule.physics:
        return const Color(0xFF3B82F6);
      case SubjectModule.computerScience:
        return const Color(0xFF6366F1);
      case SubjectModule.agriculture:
        return const Color(0xFF22C55E);
      case SubjectModule.environmentalScience:
        return const Color(0xFF059669);
      case SubjectModule.statistics:
        return const Color(0xFF0EA5E9);
      case SubjectModule.earthScience:
        return const Color(0xFFA855F7);
      case SubjectModule.engineeringTechnology:
        return const Color(0xFF6366F1);
    }
  }

  List<String> get features {
    switch (this) {
      case SubjectModule.mathematics:
        return ['graphing', 'equation_solver', 'symbolic_reasoning', 'step_verification', 'mathematical_modelling'];
      case SubjectModule.biology:
        return ['virtual_laboratory', 'diagram_labeling', 'terminology', 'physiological_process'];
      case SubjectModule.chemistry:
        return ['periodic_table', 'reaction_simulator', 'molecular_visualization', 'stoichiometry_solver'];
      case SubjectModule.physics:
        return ['formula_reference', 'problem_solver', 'simulation_engine', 'lab_simulator'];
      case SubjectModule.computerScience:
        return ['coding_laboratory', 'algorithm_visualizer', 'compiler_debugger', 'execution_environment'];
      case SubjectModule.agriculture:
        return ['crop_modelling', 'soil_analysis', 'irrigation_calculator', 'agricultural_biotelemetry'];
      case SubjectModule.environmentalScience:
        return ['ecosystem_modelling', 'climate_analysis', 'pollution_tracking', 'conservation_planning'];
      case SubjectModule.statistics:
        return ['descriptive_stats', 'hypothesis_testing', 'regression_analysis', 'data_visualization'];
      case SubjectModule.earthScience:
        return ['geological_map', 'plate_tectonics', 'mineral_identification', 'gis_integration'];
      case SubjectModule.engineeringTechnology:
        return ['circuit_simulator', 'structures_analyzer', 'renewable_energy_calculator', 'robotics_simulator'];
    }
  }

  static SubjectModule? fromSlug(String slug) {
    for (final s in values) {
      if (s.slug == slug) return s;
    }
    return null;
  }
}
