/// Reusable experiment contract. Titration is the first implemented practical;
/// later practicals reuse the same fields without duplicating scene code.
class ExperimentDefinition {
  final String id;
  final String title;
  final String description;
  final List<String> requiredApparatusIds;
  final List<String> requiredReagentIds;
  final List<String> learningOutcomes;
  final bool implemented;

  const ExperimentDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredApparatusIds,
    required this.requiredReagentIds,
    required this.learningOutcomes,
    this.implemented = false,
  });
}

class ExperimentCatalog {
  static const acidBaseTitration = ExperimentDefinition(
    id: 'acid-base-titration',
    title: 'Acid–base titration (HCl / NaOH)',
    description:
        'Determine the volume of sodium hydroxide needed to neutralise a measured aliquot of hydrochloric acid using phenolphthalein.',
    requiredApparatusIds: [
      'burette',
      'burette-stopcock',
      'conical-flask',
      'volumetric-pipette',
      'pipette-filler',
      'retort-stand',
      'white-tile',
      'wash-bottle',
    ],
    requiredReagentIds: ['hcl', 'naoh', 'phenolphthalein', 'water'],
    learningOutcomes: [
      'Read a burette to 0.05 mL.',
      'Transfer a 25.00 mL aliquot with a volumetric pipette.',
      'Recognise the phenolphthalein end point.',
      'Calculate mean concordant titres.',
    ],
    implemented: true,
  );

  static const List<ExperimentDefinition> all = [
    acidBaseTitration,
    ExperimentDefinition(
      id: 'filtration',
      title: 'Filtration',
      description: 'Separate an insoluble solid from a liquid using filter paper.',
      requiredApparatusIds: ['filtration-set', 'beaker', 'filter-funnel'],
      requiredReagentIds: ['water'],
      learningOutcomes: ['Set up gravity filtration safely.'],
    ),
    ExperimentDefinition(
      id: 'crystallisation',
      title: 'Evaporation and crystallisation',
      description: 'Recover a soluble salt by evaporation and crystallisation.',
      requiredApparatusIds: ['evaporating-basin', 'tripod-gauze', 'bunsen-burner'],
      requiredReagentIds: ['cuso4', 'water'],
      learningOutcomes: ['Obtain crystals from a solution.'],
    ),
    ExperimentDefinition(
      id: 'gas-tests',
      title: 'Preparation and testing of gases',
      description: 'Collect and test common laboratory gases.',
      requiredApparatusIds: ['gas-jar', 'delivery-tube', 'rubber-bung'],
      requiredReagentIds: ['limewater'],
      learningOutcomes: ['Identify carbon dioxide with limewater.'],
    ),
    ExperimentDefinition(
      id: 'acid-carbonate',
      title: 'Acid–carbonate reactions',
      description: 'Observe carbon dioxide from acid and a carbonate.',
      requiredApparatusIds: ['conical-flask', 'delivery-tube'],
      requiredReagentIds: ['hcl', 'na2co3', 'limewater'],
      learningOutcomes: ['Link fizzing and limewater milkiness to CO₂.'],
    ),
    ExperimentDefinition(
      id: 'separating-funnel',
      title: 'Separation of immiscible liquids',
      description: 'Use a separating funnel to isolate two layers.',
      requiredApparatusIds: ['separating-funnel', 'beaker'],
      requiredReagentIds: ['water'],
      learningOutcomes: ['Run off the lower layer carefully.'],
    ),
    ExperimentDefinition(
      id: 'distillation',
      title: 'Simple distillation',
      description: 'Separate a liquid by boiling and condensation.',
      requiredApparatusIds: ['distillation-set', 'thermometer', 'bunsen-burner'],
      requiredReagentIds: ['water'],
      learningOutcomes: ['Collect a distillate at a steady boiling point.'],
    ),
    ExperimentDefinition(
      id: 'acid-base-identification',
      title: 'Identification of acids, bases and salts',
      description: 'Use indicators and simple tests to classify unknowns.',
      requiredApparatusIds: ['test-tube-rack', 'beaker'],
      requiredReagentIds: ['universal-indicator', 'hcl', 'naoh'],
      learningOutcomes: ['Classify solutions using indicator colour.'],
    ),
    ExperimentDefinition(
      id: 'metal-displacement',
      title: 'Metal displacement reactions',
      description: 'Place metals in salt solutions and observe displacement.',
      requiredApparatusIds: ['test-tube-rack', 'beaker'],
      requiredReagentIds: ['cuso4'],
      learningOutcomes: ['Order metals by reactivity.'],
    ),
    ExperimentDefinition(
      id: 'reaction-temperature',
      title: 'Measurement of reaction temperature',
      description: 'Follow temperature change during a reaction.',
      requiredApparatusIds: ['thermometer', 'beaker', 'stirring-rod'],
      requiredReagentIds: ['hcl', 'naoh'],
      learningOutcomes: ['Record temperature against time.'],
    ),
    ExperimentDefinition(
      id: 'salt-identification',
      title: 'Qualitative analysis of unknown salts',
      description: 'Use flame tests and precipitation tests on unknown salts.',
      requiredApparatusIds: ['test-tube-rack', 'bunsen-burner'],
      requiredReagentIds: ['agno3', 'bacl2', 'hcl', 'naoh'],
      learningOutcomes: ['Identify common anions and cations.'],
    ),
  ];

  static ExperimentDefinition byId(String id) {
    return all.firstWhere((item) => item.id == id);
  }
}
