/// Physical state of a laboratory reagent.
enum PhysicalState { solid, liquid, aqueous, gas }

/// Concentration unit used in the school laboratory model.
enum ConcentrationUnit { molPerLitre, percentWV, none }

/// Shared reagent record used by experiments. Behaviour is not hard-coded
/// onto individual 3D meshes.
class Reagent {
  final String id;
  final String name;
  final String formula;
  final PhysicalState physicalState;
  final double? concentration;
  final ConcentrationUnit concentrationUnit;
  final double availableQuantity;
  final String quantityUnit;
  final double? solutionVolumeMl;
  final String appearance;
  final int colorRgb;
  final double colorOpacity;
  final String hazardInformation;
  final List<String> reactionRuleIds;
  final List<String> compatibleExperimentIds;

  const Reagent({
    required this.id,
    required this.name,
    required this.formula,
    required this.physicalState,
    this.concentration,
    this.concentrationUnit = ConcentrationUnit.none,
    required this.availableQuantity,
    required this.quantityUnit,
    this.solutionVolumeMl,
    required this.appearance,
    required this.colorRgb,
    this.colorOpacity = 0.72,
    required this.hazardInformation,
    this.reactionRuleIds = const [],
    this.compatibleExperimentIds = const [],
  });

  String get concentrationLabel {
    if (concentration == null || concentrationUnit == ConcentrationUnit.none) {
      return 'not specified';
    }
    if (concentrationUnit == ConcentrationUnit.molPerLitre) {
      return '${concentration!.toStringAsFixed(3)} mol/L';
    }
    return '${concentration!.toStringAsFixed(1)} % w/v';
  }
}
