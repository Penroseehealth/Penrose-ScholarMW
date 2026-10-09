import 'experiment_definition.dart';
import 'titration_acid_base.dart';

/// Registry of experiments shipped with the module.
///
/// Every entry must satisfy [ExperimentDefinition.isComplete] and have an
/// atom-balanced `balancedEquation` — enforced by
/// `test/experiment_catalogue_test.dart`, so an incomplete or chemically
/// wrong experiment cannot ship.
class ExperimentCatalogue {
  ExperimentCatalogue._();

  static const List<ExperimentDefinition> all = [
    AcidBaseTitration.definition,
  ];

  static ExperimentDefinition? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }
}
