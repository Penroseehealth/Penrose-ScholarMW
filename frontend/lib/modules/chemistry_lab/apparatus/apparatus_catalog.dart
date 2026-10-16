class ApparatusItem {
  final String id;
  final String name;
  final String category;
  final String description;
  final bool onMainTitrationBench;

  const ApparatusItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.onMainTitrationBench = false,
  });
}

/// Identities recognised by the interaction system and 3D scene.
class ApparatusCatalog {
  static const List<ApparatusItem> all = [
    ApparatusItem(
      id: 'beaker',
      name: 'Beaker',
      category: 'Glassware',
      description: 'Cylindrical glass vessel for holding and mixing solutions.',
    ),
    ApparatusItem(
      id: 'test-tube-rack',
      name: 'Test tubes and rack',
      category: 'Glassware',
      description: 'Small glass tubes supported in a wooden or plastic rack.',
    ),
    ApparatusItem(
      id: 'measuring-cylinder',
      name: 'Measuring cylinder',
      category: 'Glassware',
      description: 'Graduated cylinder for approximate volume measurement.',
    ),
    ApparatusItem(
      id: 'conical-flask',
      name: 'Conical flask',
      category: 'Glassware',
      description: 'Erlenmeyer flask used as the titration receiving vessel.',
      onMainTitrationBench: true,
    ),
    ApparatusItem(
      id: 'burette',
      name: 'Burette',
      category: 'Volumetric',
      description: 'Graduated glass tube with a stopcock for controlled delivery.',
      onMainTitrationBench: true,
    ),
    ApparatusItem(
      id: 'burette-stopcock',
      name: 'Burette stopcock',
      category: 'Volumetric',
      description: 'Tap that starts, slows or stops titrant flow.',
      onMainTitrationBench: true,
    ),
    ApparatusItem(
      id: 'volumetric-pipette',
      name: 'Volumetric pipette',
      category: 'Volumetric',
      description: 'Delivers a fixed aliquot of acid into the conical flask.',
      onMainTitrationBench: true,
    ),
    ApparatusItem(
      id: 'filter-funnel',
      name: 'Filter funnel',
      category: 'Separation',
      description: 'Glass funnel used with filter paper.',
    ),
    ApparatusItem(
      id: 'bunsen-burner',
      name: 'Bunsen burner',
      category: 'Heating',
      description: 'Gas burner with an adjustable air collar.',
    ),
    ApparatusItem(
      id: 'tripod-gauze',
      name: 'Tripod and wire gauze',
      category: 'Heating',
      description: 'Supports vessels over a Bunsen flame.',
    ),
    ApparatusItem(
      id: 'retort-stand',
      name: 'Retort stand and clamp',
      category: 'Support',
      description: 'Holds the burette vertically above the flask.',
      onMainTitrationBench: true,
    ),
    ApparatusItem(
      id: 'stirring-rod',
      name: 'Glass stirring rod',
      category: 'Glassware',
      description: 'Solid glass rod for mixing.',
    ),
    ApparatusItem(
      id: 'evaporating-basin',
      name: 'Evaporating basin',
      category: 'Ceramic',
      description: 'Shallow porcelain basin for evaporation.',
    ),
    ApparatusItem(
      id: 'thermometer',
      name: 'Thermometer',
      category: 'Measurement',
      description: 'Laboratory thermometer for temperature measurement.',
    ),
    ApparatusItem(
      id: 'balance',
      name: 'Laboratory balance',
      category: 'Measurement',
      description: 'Electronic balance for mass measurement.',
    ),
    ApparatusItem(
      id: 'reagent-bottle',
      name: 'Reagent bottle',
      category: 'Storage',
      description: 'Stoppered bottle for stock solutions.',
      onMainTitrationBench: true,
    ),
    ApparatusItem(
      id: 'hot-plate',
      name: 'Electric hot plate',
      category: 'Heating',
      description: 'Electrically heated ceramic plate.',
    ),
    ApparatusItem(
      id: 'wash-bottle',
      name: 'Wash bottle',
      category: 'Glassware',
      description: 'Plastic bottle of distilled water for rinsing.',
      onMainTitrationBench: true,
    ),
    ApparatusItem(
      id: 'spatula',
      name: 'Spatula',
      category: 'Tools',
      description: 'Metal spatula for transferring solids.',
    ),
    ApparatusItem(
      id: 'weighing-boat',
      name: 'Weighing boat',
      category: 'Tools',
      description: 'Disposable boat for weighing solids.',
    ),
    ApparatusItem(
      id: 'watch-glass',
      name: 'Watch glass',
      category: 'Glassware',
      description: 'Concave glass dish used as a cover or for small masses.',
    ),
    ApparatusItem(
      id: 'crucible',
      name: 'Crucible with lid',
      category: 'Ceramic',
      description: 'Porcelain crucible for strong heating.',
    ),
    ApparatusItem(
      id: 'delivery-tube',
      name: 'Glass delivery tube',
      category: 'Gas',
      description: 'Bent glass tube for transferring gases.',
    ),
    ApparatusItem(
      id: 'rubber-bung',
      name: 'Rubber stopper',
      category: 'Fittings',
      description: 'Rubber bung used to seal flasks and tubes.',
    ),
    ApparatusItem(
      id: 'gas-jar',
      name: 'Gas jar',
      category: 'Gas',
      description: 'Tall jar for collecting gases over water.',
    ),
    ApparatusItem(
      id: 'filtration-set',
      name: 'Filtration equipment',
      category: 'Separation',
      description: 'Funnel, stand and conical flask for gravity filtration.',
    ),
    ApparatusItem(
      id: 'distillation-set',
      name: 'Simple distillation apparatus',
      category: 'Separation',
      description: 'Flask, condenser and receiver for distillation.',
    ),
    ApparatusItem(
      id: 'separating-funnel',
      name: 'Separating funnel',
      category: 'Separation',
      description: 'Pear-shaped funnel for immiscible liquids.',
    ),
    ApparatusItem(
      id: 'mortar-pestle',
      name: 'Mortar and pestle',
      category: 'Tools',
      description: 'Porcelain mortar for grinding solids.',
    ),
    ApparatusItem(
      id: 'pipette-filler',
      name: 'Pipette filler',
      category: 'Volumetric',
      description: 'Safety filler used with the volumetric pipette.',
      onMainTitrationBench: true,
    ),
    ApparatusItem(
      id: 'white-tile',
      name: 'White titration tile',
      category: 'Titration',
      description: 'White ceramic tile beneath the flask to show indicator colour.',
      onMainTitrationBench: true,
    ),
    ApparatusItem(
      id: 'sink',
      name: 'Sink and tap',
      category: 'Room',
      description: 'Laboratory sink with a water tap.',
    ),
    ApparatusItem(
      id: 'fume-hood',
      name: 'Fume hood',
      category: 'Safety',
      description: 'Ventilated cupboard for vapours.',
    ),
    ApparatusItem(
      id: 'eyewash',
      name: 'Eyewash station',
      category: 'Safety',
      description: 'Emergency eyewash bowl.',
    ),
    ApparatusItem(
      id: 'extinguisher',
      name: 'Fire extinguisher',
      category: 'Safety',
      description: 'Wall-mounted fire extinguisher.',
    ),
    ApparatusItem(
      id: 'first-aid',
      name: 'First-aid station',
      category: 'Safety',
      description: 'First-aid cabinet and signage.',
    ),
  ];

  static ApparatusItem? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}
