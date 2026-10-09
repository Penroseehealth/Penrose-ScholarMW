import 'package:flutter/material.dart';

/// Biological organisation levels, coarsest to finest.
///
/// The Biology Lab's multiscale navigation walks DOWN this ladder
/// (organism → molecule) using the links in [BioLabAsset.children] /
/// [BioLabAsset.parent].
enum BioLevel {
  organism('Organism', Icons.person_rounded),
  system('Organ system', Icons.all_inclusive_rounded),
  organ('Organ', Icons.favorite_rounded),
  tissue('Tissue', Icons.layers_rounded),
  cell('Cell', Icons.blur_circular_rounded),
  organelle('Organelle', Icons.circle_outlined),
  molecule('Molecule', Icons.hexagon_rounded);

  const BioLevel(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Label shown during multiscale transitions, e.g. "×10,000".
  String get magnification {
    switch (this) {
      case BioLevel.organism:
        return '×1';
      case BioLevel.system:
        return '×1';
      case BioLevel.organ:
        return '×1';
      case BioLevel.tissue:
        return '×100';
      case BioLevel.cell:
        return '×2,000';
      case BioLevel.organelle:
        return '×10,000';
      case BioLevel.molecule:
        return '×10,000,000';
    }
  }
}

/// How scientifically grounded a model is. Displayed on every asset card —
/// the lab never presents a schematic as experimental data.
enum BioVerification {
  /// Atoms/experimental coordinates from a public repository (e.g. RCSB PDB).
  validatedStructure('Validated structure', Icons.verified_rounded),

  /// Built from textbook morphology; correct topology, schematic geometry.
  educationalReconstruction('Educational reconstruction', Icons.architecture_rounded),

  /// Metadata/lesson content only — no 3D model exists yet.
  metadataOnly('Catalogued only — no 3D model yet', Icons.bookmark_rounded);

  const BioVerification(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// One component (part) of a scene that the learner can click and inspect.
@immutable
class BioComponent {
  final String id;
  final String name;
  final String description;

  const BioComponent({
    required this.id,
    required this.name,
    required this.description,
  });
}

/// One teaching animation available inside a scene.
@immutable
class BioAnimation {
  final String id;
  final String title;
  final String summary;

  const BioAnimation({required this.id, required this.title, required this.summary});
}

/// A registered biological model/lesson in the Biology 3D Laboratory.
@immutable
class BioLabAsset {
  final String id;
  final String title;
  final String subtitle;
  final BioLevel level;
  final BioVerification verification;

  /// Scale presentation, e.g. "~1 µm, shown ×500,000".
  final String scaleLabel;

  /// Scene builder id understood by [BioSceneSpecs] (`null` for metadata
  /// assets that have no 3D model yet).
  final String? sceneId;

  /// Relative path (from `frontend/web/`) to a local structure file for the
  /// Mol* molecular viewer.
  final String? moleculePdb;

  /// Where the model or data comes from. Never fabricated.
  final String source;

  /// License of the model/data as recorded at import time.
  final String license;

  /// Known simplifications or uncertainties, shown to the learner.
  final String? simplifications;

  final List<String> learningObjectives;
  final List<BioComponent> components;
  final List<BioAnimation> animations;

  /// Multiscale links: asset ids reachable one level deeper.
  final List<String> children;

  /// Parent asset id (one level coarser).
  final String? parent;

  const BioLabAsset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.verification,
    required this.scaleLabel,
    required this.source,
    required this.license,
    this.sceneId,
    this.moleculePdb,
    this.simplifications,
    this.learningObjectives = const [],
    this.components = const [],
    this.animations = const [],
    this.children = const [],
    this.parent,
  });
}

/// The registry of every biological asset in the laboratory.
///
/// **Provenance rule:** [BioLabAsset.source] and [license] are recorded per
/// asset at import time and never invented — assets built in code are marked
/// `Educational reconstruction …`.
class BioLabRegistry {
  const BioLabRegistry._();

  /// All assets, ordered by biological level (coarse → fine).
  static const List<BioLabAsset> assets = [
    // ── Level 7: organism ────────────────────────────────────────────────
    BioLabAsset(
      id: 'human-organism',
      title: 'Human organism',
      subtitle: 'Whole-body overview and organ-system map',
      level: BioLevel.organism,
      verification: BioVerification.educationalReconstruction,
      scaleLabel: '~1.7 m ×1',
      sceneId: 'human-organism',
      source: 'Educational reconstruction (procedural, built in code) from '
          'standard human anatomy (e.g. Gray’s Anatomy, public domain, 1918 ed.)',
      license: 'Code-authored (MIT, part of Penrose ScholarMW)',
      simplifications: 'Silhouette-level body with simplified organ placement; '
          'not for medical use.',
      learningObjectives: [
        'Locate the major organs on a whole-body map',
        'Identify the organ systems and one function each',
        'Follow a multiscale path from organism to molecule',
      ],
      components: [
        BioComponent(id: 'brain', name: 'Brain', description: 'Control centre of the nervous system.'),
        BioComponent(id: 'heart', name: 'Heart', description: 'Pumps blood through the double circulation.'),
        BioComponent(id: 'lungs', name: 'Lungs', description: 'Gas exchange with the air.'),
        BioComponent(id: 'stomach', name: 'Stomach', description: 'Muscular food reservoir; begins protein digestion.'),
        BioComponent(id: 'liver', name: 'Liver', description: 'Metabolism, bile production, detoxification.'),
        BioComponent(id: 'kidneys', name: 'Kidneys', description: 'Filter blood, form urine.'),
      ],
      children: ['circulatory-system'],
    ),

    // ── Level 6: systems ─────────────────────────────────────────────────
    BioLabAsset(
      id: 'circulatory-system',
      title: 'Circulatory system',
      subtitle: 'Heart, vessels and blood — double circulation',
      level: BioLevel.system,
      verification: BioVerification.educationalReconstruction,
      scaleLabel: '~0.3 m ×1',
      sceneId: null,
      source: 'Educational reconstruction (procedural) from standard anatomy',
      license: 'Code-authored (MIT)',
      simplifications: 'Only the heart is interactive so far; vessels are '
          'catalogued only.',
      learningObjectives: [
        'Trace the pulmonary and systemic circuits',
        'Name the chambers of the heart in order of blood flow',
      ],
      components: [
        BioComponent(id: 'heart-component', name: 'Heart', description: 'The pump — interactive in this laboratory.'),
        BioComponent(id: 'arteries', name: 'Arteries', description: 'Vessels carrying blood away from the heart.'),
        BioComponent(id: 'veins', name: 'Veins', description: 'Vessels returning blood to the heart.'),
        BioComponent(
            id: 'capillaries', name: 'Capillaries', description: 'Microvessels where exchange with tissues happens.'),
      ],
      children: ['human-heart'],
      parent: 'human-organism',
    ),

    // ── Level 5: organs ──────────────────────────────────────────────────
    BioLabAsset(
      id: 'human-heart',
      title: 'Human heart',
      subtitle: 'Four chambers, valves and the great vessels',
      level: BioLevel.organ,
      verification: BioVerification.educationalReconstruction,
      scaleLabel: '~12 cm ×1',
      sceneId: 'human-heart',
      source: 'Educational reconstruction (procedural, built in code) from '
          'standard cardiac anatomy',
      license: 'Code-authored (MIT)',
      simplifications: 'Simplified chamber geometry; valve leaflets are schematic; '
          'coronary vessels not modelled. Not for medical use.',
      learningObjectives: [
        'Identify the four chambers and their order of blood flow',
        'Name the great vessels entering and leaving the heart',
        'Trace the circulation animation through both circuits',
      ],
      components: [
        BioComponent(
            id: 'right-atrium',
            name: 'Right atrium',
            description: 'Receives deoxygenated blood from the body via the venae cavae.'),
        BioComponent(
            id: 'right-ventricle',
            name: 'Right ventricle',
            description: 'Pumps deoxygenated blood to the lungs via the pulmonary artery.'),
        BioComponent(
            id: 'left-atrium',
            name: 'Left atrium',
            description: 'Receives oxygenated blood from the lungs via pulmonary veins.'),
        BioComponent(
            id: 'left-ventricle',
            name: 'Left ventricle',
            description: 'Thickest-walled chamber; pumps oxygenated blood to the whole body '
                'through the aorta.'),
        BioComponent(
            id: 'tricuspid-valve',
            name: 'Tricuspid valve',
            description: 'Prevents backflow from right ventricle to right atrium.'),
        BioComponent(
            id: 'mitral-valve',
            name: 'Mitral (bicuspid) valve',
            description: 'Prevents backflow from left ventricle to left atrium.'),
        BioComponent(
            id: 'aorta', name: 'Aorta', description: 'Largest artery; carries oxygenated blood away from the heart.'),
        BioComponent(
            id: 'pulmonary-artery',
            name: 'Pulmonary artery',
            description: 'Carries deoxygenated blood from the right ventricle to the lungs.'),
        BioComponent(
            id: 'vena-cava',
            name: 'Venae cavae',
            description: 'Return deoxygenated blood from the body to the right atrium.'),
        BioComponent(
            id: 'cardiac-fiber',
            name: 'Cardiac muscle fibre',
            description: 'Striated, involuntary muscle with intercalated discs — zoom in to '
                'the cellular level.'),
      ],
      animations: [
        BioAnimation(
          id: 'circulation',
          title: 'Blood circulation (schematic)',
          summary: 'Body → vena cava → right atrium → right ventricle → pulmonary '
              'artery → lungs → pulmonary veins → left atrium → left ventricle → '
              'aorta → body.',
        ),
        BioAnimation(
          id: 'heartbeat',
          title: 'Heartbeat (schematic)',
          summary: 'Atrial systole then ventricular systole; valves open and close '
              'in sequence.',
        ),
      ],
      children: ['cardiac-muscle-tissue'],
      parent: 'circulatory-system',
    ),

    // ── Level 4: tissue ──────────────────────────────────────────────────
    BioLabAsset(
      id: 'cardiac-muscle-tissue',
      title: 'Cardiac muscle tissue',
      subtitle: 'Branching striated fibres with intercalated discs',
      level: BioLevel.tissue,
      verification: BioVerification.educationalReconstruction,
      scaleLabel: '~0.1 mm ×100',
      sceneId: null,
      source: 'Catalogued from standard histology (descriptive metadata only)',
      license: 'Code-authored (MIT)',
      simplifications: 'No 3D model yet — the practical cardia tissue view is '
          'handled inside the heart scene’s cardiac fibre component.',
      learningObjectives: [
        'Recognise the features that distinguish cardiac muscle '
            '(branching fibres, single central nucleus, intercalated discs)',
      ],
      components: [
        BioComponent(
            id: 'cardiac-fibre',
            name: 'Cardiac muscle fibre',
            description: 'Branching striated fibre — explore its cell in the next level.'),
        BioComponent(
            id: 'intercalated-disc',
            name: 'Intercalated disc',
            description: 'Junction joining fibres electrically so the heart beats as one.'),
        BioComponent(
            id: 'capillary-bed', name: 'Capillary bed', description: 'Dense blood supply surrounding every fibre.'),
      ],
      children: ['cardiac-muscle-cell'],
      parent: 'human-heart',
    ),

    // ── Level 3: cells ───────────────────────────────────────────────────
    BioLabAsset(
      id: 'cardiac-muscle-cell',
      title: 'Cardiac muscle cell (cardiomyocyte)',
      subtitle: 'Striated contractile cell rich in mitochondria',
      level: BioLevel.cell,
      verification: BioVerification.educationalReconstruction,
      scaleLabel: '~100 µm ×2,000',
      sceneId: 'cardiac-muscle-cell',
      source: 'Educational reconstruction (procedural, built in code) from '
          'standard cell biology',
      license: 'Code-authored (MIT)',
      simplifications: 'Sarcomere banding and T-tubules are schematic.',
      learningObjectives: [
        'Identify the nucleus, sarcomere region and mitochondria of a '
            'cardiomyocyte',
        'Explain why cardiomyocytes contain many mitochondria',
      ],
      components: [
        BioComponent(id: 'sarcolemma', name: 'Sarcolemma', description: 'The muscle cell membrane.'),
        BioComponent(
            id: 'nucleus-cell',
            name: 'Nucleus',
            description: 'Single, centrally placed nucleus (unlike skeletal muscle).'),
        BioComponent(
            id: 'myofibril', name: 'Myofibril', description: 'Bundles of contractile filaments (actin and myosin).'),
        BioComponent(
            id: 'mitochondrion-a',
            name: 'Mitochondrion',
            description: 'ATP factory — ~30–40% of cardiomyocyte volume. Zoom in further.'),
      ],
      children: ['mitochondrion'],
      parent: 'cardiac-muscle-tissue',
    ),
    BioLabAsset(
      id: 'bacterial-cell',
      title: 'Bacterial cell',
      subtitle: 'Rod-shaped bacterium (schematic Gram-negative type)',
      level: BioLevel.cell,
      verification: BioVerification.educationalReconstruction,
      scaleLabel: '~2 µm ×500,000',
      sceneId: 'bacterial-cell',
      source: 'Educational reconstruction (procedural, built in code) from '
          'standard bacteriology (e.g. Prescott, Microbiology)',
      license: 'Code-authored (MIT)',
      simplifications: 'Single generic rod shape; periplasm and outer-membrane '
          'folded into one wall layer; nucleoid shown as an irregular coil '
          'rather than real genomic data.',
      learningObjectives: [
        'Identify the cell wall, membrane, nucleoid, ribosomes and flagellum',
        'Describe what plasmids are and why they matter in medicine',
        'Contrast prokaryotic with eukaryotic cells',
      ],
      components: [
        BioComponent(
            id: 'cell-wall',
            name: 'Cell wall',
            description: 'Rigid peptidoglycan layer that maintains shape and protects '
                'against osmotic lysis.'),
        BioComponent(
            id: 'membrane',
            name: 'Plasma membrane',
            description: 'Phospholipid bilayer controlling what enters and leaves the cell.'),
        BioComponent(
            id: 'cytoplasm',
            name: 'Cytoplasm',
            description: 'Semi-fluid contents where ribosomes float and reactions occur.'),
        BioComponent(
            id: 'nucleoid',
            name: 'Nucleoid',
            description: 'Region containing the circular DNA chromosome — not enclosed '
                'by a membrane (prokaryote!).'),
        BioComponent(
            id: 'plasmid',
            name: 'Plasmid',
            description: 'Small extra DNA ring, often carrying genes such as antibiotic '
                'resistance.'),
        BioComponent(
            id: 'ribosome-0',
            name: 'Ribosomes (70S)',
            description: 'Sites of protein synthesis. Target of many antibiotics '
                '(e.g. tetracycline).'),
        BioComponent(
            id: 'flagellum',
            name: 'Flagellum',
            description: 'Rotating protein filament driven by a basal motor — the bacterium '
                'swims.'),
        BioComponent(
            id: 'pilus-0',
            name: 'Pili',
            description: 'Short protein hairs for attachment and DNA transfer '
                '(conjugation).'),
      ],
      animations: [
        BioAnimation(
          id: 'flagellar-motion',
          title: 'Flagellar swimming (schematic)',
          summary: 'The basal motor spins the flagellum; the cell moves forward — '
              'rotation is represented schematically, not from molecular data.',
        ),
        BioAnimation(
          id: 'binary-fission',
          title: 'Binary fission (schematic)',
          summary: 'The chromosome replicates, the cell elongates and divides into '
              'two daughter cells.',
        ),
      ],
      parent: null,
    ),

    // ── Level 2: organelles ──────────────────────────────────────────────
    BioLabAsset(
      id: 'mitochondrion',
      title: 'Mitochondrion',
      subtitle: 'Double-membrane organelle with folded cristae',
      level: BioLevel.organelle,
      verification: BioVerification.educationalReconstruction,
      scaleLabel: '~2 µm ×10,000',
      sceneId: 'mitochondrion',
      source: 'Educational reconstruction (procedural, built in code) from '
          'standard cell biology',
      license: 'Code-authored (MIT)',
      simplifications: 'Cristae simplified to a few folds; electron-transport '
          'proteins not individually shown.',
      learningObjectives: [
        'Identify the outer and inner membranes and the matrix',
        'Explain how cristae increase the surface area for ATP production',
      ],
      components: [
        BioComponent(id: 'outer-membrane', name: 'Outer membrane', description: 'Smooth boundary of the organelle.'),
        BioComponent(
            id: 'inner-membrane',
            name: 'Inner membrane',
            description: 'Folded into cristae; hosts the electron transport chain and '
                'ATP synthase.'),
        BioComponent(
            id: 'matrix',
            name: 'Matrix',
            description: 'Site of the Krebs cycle; contains mitochondrial DNA and '
                'ribosomes.'),
        BioComponent(id: 'cristae', name: 'Cristae', description: 'Shelf-like folds of the inner membrane.'),
      ],
      animations: [
        BioAnimation(
          id: 'atp-production',
          title: 'ATP production (schematic)',
          summary: 'Electrons pass along the transport chain; protons are pumped '
              'across the inner membrane and ATP synthase converts the flow '
              'into ATP. Schematic — individual complexes are not modelled.',
        ),
      ],
      parent: 'cardiac-muscle-cell',
    ),

    // ── Level 1: molecules ───────────────────────────────────────────────
    BioLabAsset(
      id: 'dna-1bna',
      title: 'B-DNA dodecamer',
      subtitle: 'Double helix — experimental structure 1BNA',
      level: BioLevel.molecule,
      verification: BioVerification.validatedStructure,
      scaleLabel: '~2 nm ×10,000,000',
      sceneId: null,
      moleculePdb: 'biology_lab/data/1bna.pdb',
      source: 'RCSB PDB entry 1BNA — Drew, H.R. et al. (1981) "Structure of a '
          'B-DNA dodecamer", Proc. Natl. Acad. Sci. USA 78, 2179. '
          'https://doi.org/10.1073/pnas.78.4.2179',
      license: 'PDB data are free for use in the public interest '
          '(wwPDB policy); rendered with Mol* (MIT).',
      simplifications: 'The dodecamer is a 12-base-pair fragment, not a whole chromosome; '
          'hydrogens are omitted in the entry.',
      learningObjectives: [
        'Describe the double-helical backbone and base pairing',
        'Explain complementary base pairing (A–T, G–C)',
        'Select residues and inspect the atomic detail in Mol*',
      ],
      parent: null,
    ),
    BioLabAsset(
      id: 'hemoglobin-1hho',
      title: 'Deoxyhemoglobin',
      subtitle: 'Oxygen-carrying blood protein — experimental structure 1HHO',
      level: BioLevel.molecule,
      verification: BioVerification.validatedStructure,
      scaleLabel: '~5.5 nm ×10,000,000',
      sceneId: null,
      moleculePdb: 'biology_lab/data/1hho.pdb',
      source: 'RCSB PDB entry 1HHO — Fermi, G. & Perutz, M.F. (1984) '
          '"The crystal structure of human deoxyhaemoglobin at 1.74 Å resolution", '
          'J. Mol. Biol. 175, 159. https://doi.org/10.1016/0022-2836(84)90472-8',
      license: 'PDB data are free for use in the public interest '
          '(wwPDB policy); rendered with Mol* (MIT).',
      simplifications: 'Crystal structure of the T (deoxy) state; the R (oxy) state '
          'conformational shift is not shown.',
      learningObjectives: [
        'Identify the four globin chains and the haem groups',
        'Explain how haemoglobin carries oxygen in the blood',
      ],
      parent: null,
    ),
  ];

  /// Fast id → asset lookup.
  static final Map<String, BioLabAsset> _byId = {
    for (final a in assets) a.id: a,
  };

  static BioLabAsset? byId(String? id) => id == null ? null : _byId[id];

  /// Assets grouped by level, for the hierarchy navigator.
  static Map<BioLevel, List<BioLabAsset>> byLevel() {
    final map = <BioLevel, List<BioLabAsset>>{};
    for (final level in BioLevel.values) {
      map[level] = assets.where((a) => a.level == level).toList();
    }
    return map;
  }

  /// Case-insensitive search over title, subtitle and level label.
  static List<BioLabAsset> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(assets);
    return assets
        .where((a) =>
            a.title.toLowerCase().contains(q) ||
            a.subtitle.toLowerCase().contains(q) ||
            a.level.label.toLowerCase().contains(q))
        .toList();
  }

  /// Validates registry integrity: every multiscale link must resolve and
  /// parent/children must agree both ways. Used by the unit tests.
  static List<String> validate() {
    final problems = <String>[];
    for (final a in assets) {
      if (_byId[a.id] == null || a.id.isEmpty) {
        problems.add('asset with empty id');
        continue;
      }
      for (final child in a.children) {
        final c = byId(child);
        if (c == null) {
          problems.add('${a.id}: unknown child "$child"');
        } else if (c.level.index != a.level.index + 1) {
          problems.add('${a.id}: child "$child" must be exactly one level deeper');
        } else if (c.parent != a.id) {
          problems.add('${a.id}: child "$child" does not point back');
        }
      }
      if (a.parent != null) {
        final p = byId(a.parent);
        if (p == null) {
          problems.add('${a.id}: unknown parent "${a.parent}"');
        } else if (!p.children.contains(a.id)) {
          problems.add('${a.id}: parent "${a.parent}" does not list it');
        }
      }
      if (a.moleculePdb != null && a.sceneId != null) {
        problems.add('${a.id}: cannot have both a scene and a PDB molecule');
      }
      if (a.components.isEmpty && a.sceneId == null && a.moleculePdb == null) {
        problems.add('${a.id}: metadata-only assets need components');
      }
      for (final c in a.components) {
        if (c.id.isEmpty || c.name.isEmpty || c.description.isEmpty) {
          problems.add('${a.id}: incomplete component ${c.id}');
        }
      }
    }
    return problems;
  }
}
