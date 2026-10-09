/// Builders that produce scene specs (`docs/INTEGRATION.md`) for the
/// Biology Lab's procedural 3D scenes.
///
/// **Honesty rule:** every scene here is an *educational reconstruction*
/// built from textbook morphology. Geometry is schematic — never presented
/// as experimentally determined. Molecular-level scenes use real PDB data
/// through Mol* instead ([BioLabAsset.moleculePdb]).
import 'dart:math' as math;

/// Scene spec builders, keyed by the `sceneId` used in
/// [BioLabRegistry](../hierarchy/bio_lab_registry.dart).
class BioSceneSpecs {
  const BioSceneSpecs._();

  static bool hasScene(String sceneId) => const [
        'bacterial-cell',
        'human-heart',
        'cardiac-muscle-cell',
        'mitochondrion',
        'human-organism'
      ].contains(sceneId);

  /// Returns the scene spec for [sceneId], or null if unknown.
  static Map<String, dynamic>? forScene(String sceneId) {
    switch (sceneId) {
      case 'bacterial-cell':
        return bacterialCell();
      case 'human-heart':
        return humanHeart();
      case 'cardiac-muscle-cell':
        return cardiacMuscleCell();
      case 'mitochondrion':
        return mitochondrion();
      case 'human-organism':
        return humanOrganism();
      default:
        return null;
    }
  }

  static Map<String, dynamic> _camera({
    required List<double> position,
    required List<double> target,
  }) =>
      {
        'position': position,
        'target': target,
        'background': '#0b1220',
      };

  // ────────────────────────────────────────────────────────────────────────
  // Level 3 — bacterial cell
  // ────────────────────────────────────────────────────────────────────────
  static Map<String, dynamic> bacterialCell() {
    final objects = <Map<String, dynamic>>[];

    // Cell wall: hollow open-ended capsule shell.
    objects.add({
      'id': 'cell-wall',
      'name': 'Cell wall',
      'type': 'capsuleShell',
      'group': 'wall',
      'params': {'radius': 1.0, 'length': 2.4, 'thickness': 0.1},
      'position': [0, 0, 0],
      'color': '#9fb4c7',
      'opacity': 0.85,
      'roughness': 0.7,
      'selectable': true,
      'label': 'Cell wall — peptidoglycan',
      'labelOffset': [0, 1.35, 0],
    });

    // Plasma membrane: slightly smaller translucent shell.
    objects.add({
      'id': 'membrane',
      'name': 'Plasma membrane',
      'type': 'capsuleShell',
      'group': 'membrane',
      'params': {'radius': 0.88, 'length': 2.2, 'thickness': 0.05},
      'position': [0, 0, 0],
      'color': '#4fc3f7',
      'opacity': 0.38,
      'roughness': 0.35,
      'selectable': true,
      'label': 'Plasma membrane',
      'labelOffset': [-0.9, -1.05, 0.4],
    });

    // Cytoplasm: soft translucent fill.
    objects.add({
      'id': 'cytoplasm',
      'name': 'Cytoplasm',
      'type': 'capsule',
      'group': 'membrane',
      'params': {'radius': 0.82, 'length': 2.1},
      'position': [0, 0, 0],
      'color': '#1e3a5f',
      'opacity': 0.30,
      'roughness': 0.9,
      'selectable': true,
      'label': 'Cytoplasm',
      'labelOffset': [0.4, -1.1, 0.3],
    });

    // Nucleoid: irregular coiled DNA region (tangled tubes).
    final nucleoidTangles = <Map<String, dynamic>>[];
    final rng = math.Random(7);
    for (var i = 0; i < 7; i++) {
      final points = List<List<double>>.generate(6, (j) {
        final t = j / 5;
        return [
          -0.55 + 1.1 * t + (rng.nextDouble() - 0.5) * 0.25,
          (rng.nextDouble() - 0.5) * 0.65,
          (rng.nextDouble() - 0.5) * 0.65,
        ];
      });
      nucleoidTangles.add({
        'id': 'nucleoid-strand-$i',
        'name': 'Nucleoid (circular DNA)',
        'type': 'tube',
        'group': 'genetic',
        'params': {
          'points': points,
          'radius': 0.055,
        },
        'position': [0, 0, 0],
        'color': '#ffd54f',
        'opacity': 0.95,
        'selectable': true,
      });
    }
    objects
      ..addAll(nucleoidTangles)
      ..add({
        'id': 'nucleoid',
        'name': 'Nucleoid',
        'type': 'sphereBlob',
        'group': 'genetic',
        'params': {
          'radius': 0.62,
          'squash': [0.9, 1.0, 1.05],
          'noise': 0.12
        },
        'position': [0, 0, 0],
        'color': '#c79a2e',
        'opacity': 0.22,
        'roughness': 0.8,
        'selectable': true,
        'label': 'Nucleoid — circular DNA, no nuclear membrane',
        'labelOffset': [0, 0.9, -0.5],
      });

    // Plasmid: small torus ring.
    objects.add({
      'id': 'plasmid',
      'name': 'Plasmid',
      'type': 'torus',
      'group': 'genetic',
      'params': {'radius': 0.22, 'tube': 0.035},
      'position': [-0.75, -0.35, 0.45],
      'rotation': [0.7, 0.4, 0.3],
      'color': '#ff8a65',
      'opacity': 0.95,
      'selectable': true,
      'label': 'Plasmid — extra DNA ring',
      'labelOffset': [0, 0.55, 0],
    });

    // Ribosomes: scattered small spheres.
    final ribRng = math.Random(3);
    for (var i = 0; i < 14; i++) {
      final a = ribRng.nextDouble() * math.pi * 2;
      final b = ribRng.nextDouble() * math.pi - math.pi / 2;
      final r = 0.45 + ribRng.nextDouble() * 0.35;
      objects.add({
        'id': 'ribosome-$i',
        'name': 'Ribosome (70S)',
        'type': 'sphere',
        'group': 'ribosomes',
        'params': {'radius': 0.075},
        'position': [
          r * math.cos(b) * math.cos(a),
          r * math.sin(b),
          r * math.cos(b) * math.sin(a),
        ],
        'color': '#a5d6a7',
        'opacity': 0.95,
        'roughness': 0.5,
        'selectable': i < 3,
        // Only the first three are individually labelled/selectable —
        // the rest are ambience.
        'label': i == 0 ? 'Ribosomes (70S)' : null,
        'labelOffset': [0, 0.3, 0],
      });
    }

    // Flagellum: long tail tube extending from one end.
    objects.add({
      'id': 'flagellum',
      'name': 'Flagellum',
      'type': 'tube',
      'group': 'motility',
      'params': {
        'points': [
          [-2.2, 0.05, 0.2],
          [-2.9, 0.35, 0.55],
          [-3.6, 0.15, -0.35],
          [-4.3, -0.3, 0.15],
          [-4.9, -0.1, -0.4],
        ],
        'radius': 0.05,
      },
      'position': [0, 0, 0],
      'color': '#ce93d8',
      'opacity': 0.95,
      'selectable': true,
      'label': 'Flagellum — rotating motor filament',
      'labelOffset': [-1.1, 0.7, 0],
    });

    // Pili: several short hairs.
    for (var i = 0; i < 8; i++) {
      final ang = (i / 8) * math.pi * 2;
      objects.add({
        'id': 'pilus-$i',
        'name': 'Pili',
        'type': 'tube',
        'group': 'motility',
        'params': {
          'points': [
            [1.15 * math.cos(ang * 0.3), 0.95 * math.sin(ang), 0.3 * math.sin(ang * 0.5)],
            [1.45 * math.cos(ang * 0.3), 1.25 * math.sin(ang), 0.55 * math.sin(ang * 0.5)],
          ],
          'radius': 0.022,
        },
        'position': [0, 0, 0],
        'color': '#b0bec5',
        'opacity': 0.8,
        'selectable': i == 0,
        'label': i == 0 ? 'Pili' : null,
        'labelOffset': [0, 0.45, 0],
      });
    }

    return {
      'sceneId': 'bacterial-cell',
      'camera': _camera(position: [3.4, 2.6, 5.2], target: [-0.3, 0, 0]),
      'scaleInfo': {
        'label': '~2 µm  ·  magnified ≈×500,000',
        'note': 'Educational reconstruction',
      },
      'groups': ['wall', 'membrane', 'genetic', 'motility', 'ribosomes'],
      'objects': objects,
      'animations': [
        {
          'id': 'flagellar-motion',
          'title': 'Flagellar swimming (schematic)',
          'duration': 5.0,
          'tracks': [
            {
              'objectId': 'flagellum',
              'property': 'rotation',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [0, 0, 0]
                },
                {
                  't': 1.0,
                  'value': [0.2, 0, 6.28]
                },
              ],
            },
          ],
        },
        {
          'id': 'binary-fission',
          'title': 'Binary fission (schematic)',
          'duration': 8.0,
          'tracks': [
            // The nucleoid coil constricts while the cell elongates.
            {
              'objectId': 'cytoplasm',
              'property': 'scale',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1, 1, 1]
                },
                {
                  't': 0.5,
                  'value': [1.25, 1, 1]
                },
                {
                  't': 1.0,
                  'value': [1.05, 1, 1]
                },
              ],
            },
            {
              'objectId': 'cell-wall',
              'property': 'scale',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1, 1, 1]
                },
                {
                  't': 0.5,
                  'value': [1.25, 1, 1]
                },
                {
                  't': 1.0,
                  'value': [1.05, 1, 1]
                },
              ],
            },
            {
              'objectId': 'nucleoid',
              'property': 'scale',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1, 1, 1]
                },
                {
                  't': 0.45,
                  'value': [1.18, 0.9, 0.9]
                },
                {
                  't': 0.75,
                  'value': [0.55, 0.55, 0.55]
                },
                {
                  't': 1.0,
                  'value': [1.0, 0.7, 0.7]
                },
              ],
            },
          ],
        },
      ],
    };
  }

  // ────────────────────────────────────────────────────────────────────────
  // Level 5 — human heart
  // ────────────────────────────────────────────────────────────────────────
  static Map<String, dynamic> humanHeart() {
    Map<String, dynamic> chamber(
      String id,
      String label,
      List<double> position,
      List<double> scale,
      String color, {
      double opacity = 0.85,
      String? labelOffset,
    }) =>
        {
          'id': id,
          'name': label,
          'type': 'sphereBlob',
          'group': 'chambers',
          'params': {
            'radius': 1,
            'squash': scale,
            'noise': 0.08,
          },
          'position': position,
          'color': color,
          'opacity': opacity,
          'roughness': 0.45,
          'selectable': true,
          'label': label,
          'labelOffset': labelOffset != null ? [0, 0.85, 0] : null,
        };

    Map<String, dynamic> vessel(
      String id,
      String label,
      List<List<double>> points,
      String color, {
      double radius = 0.22,
      String? group,
    }) =>
        {
          'id': id,
          'name': label,
          'type': 'tube',
          'group': group ?? 'vessels',
          'params': {'points': points, 'radius': radius},
          'position': [0, 0, 0],
          'color': color,
          'opacity': 0.92,
          'roughness': 0.4,
          'selectable': true,
          'label': label,
          'labelOffset': null,
        };

    final objects = <Map<String, dynamic>>[
      // Myocardium: outer muscular bulk (open shell).
      {
        'id': 'myocardium',
        'name': 'Myocardium (heart muscle)',
        'type': 'sphereBlob',
        'group': 'muscle',
        'params': {
          'radius': 1.85,
          'squash': [1.0, 1.15, 0.9],
          'noise': 0.10
        },
        'position': [0, 0, -0.15],
        'color': '#b71c1c',
        'opacity': 0.55,
        'roughness': 0.6,
        'selectable': true,
        'label': 'Myocardium — cardiac muscle',
        'labelOffset': [0, -1.6, -0.9],
      },
      // Cardiac muscle fibre link to deeper levels.
      {
        'id': 'cardiac-fiber',
        'name': 'Cardiac muscle fibre',
        'type': 'tube',
        'group': 'muscle',
        'params': {
          'points': [
            [1.1, -0.9, 0.6],
            [1.5, -0.35, 1.0],
            [1.75, 0.35, 1.05],
            [1.6, 1.0, 0.75],
          ],
          'radius': 0.08,
        },
        'position': [0, 0, 0],
        'color': '#e57373',
        'opacity': 0.95,
        'selectable': true,
        'label': 'Cardiac muscle fibre — zoom to cell level',
        'labelOffset': [0.3, 0.7, 0],
      },
      // Chambers (right side first in flow order).
      chamber('right-atrium', 'Right atrium', [-1.05, 1.05, 0.2], [0.75, 0.7, 0.7], '#37474f'),
      chamber('right-ventricle', 'Right ventricle', [-0.85, -0.5, 0.25], [0.8, 0.95, 0.72], '#546e7a'),
      chamber('left-atrium', 'Left atrium', [1.0, 1.1, -0.35], [0.7, 0.65, 0.65], '#b71c1c'),
      chamber('left-ventricle', 'Left ventricle', [0.75, -0.6, -0.3], [0.95, 1.15, 0.85], '#c62828'),
      // Valves (schematic discs).
      {
        'id': 'tricuspid-valve',
        'name': 'Tricuspid valve',
        'type': 'disc',
        'group': 'valves',
        'params': {'radius': 0.5},
        'position': [-0.95, 0.35, 0.22],
        'rotation': [1.2, 0, 0],
        'color': '#fff8e1',
        'opacity': 0.9,
        'selectable': true,
        'label': 'Tricuspid valve',
        'labelOffset': [0, 0.4, 0],
      },
      {
        'id': 'mitral-valve',
        'name': 'Mitral valve',
        'type': 'disc',
        'group': 'valves',
        'params': {'radius': 0.45},
        'position': [0.9, 0.4, -0.28],
        'rotation': [1.2, 0, 0],
        'color': '#fffde7',
        'opacity': 0.9,
        'selectable': true,
        'label': 'Mitral valve',
        'labelOffset': [0, 0.4, 0],
      },
      // Great vessels.
      vessel(
          'vena-cava',
          'Venae cavae',
          [
            [-1.7, 2.6, 0.2],
            [-1.45, 1.9, 0.2],
            [-1.15, 1.45, 0.2],
          ],
          '#5c6bc0',
          radius: 0.24),
      vessel(
          'pulmonary-artery',
          'Pulmonary artery',
          [
            [-0.7, 0.75, 0.55],
            [-0.45, 1.75, 0.75],
            [-0.1, 2.5, 0.6],
          ],
          '#42a5f5',
          radius: 0.2),
      vessel(
          'aorta',
          'Aorta',
          [
            [0.55, 0.9, -0.15],
            [0.5, 1.7, -0.35],
            [0.15, 2.35, -0.2],
            [0.4, 2.75, 0.35],
          ],
          '#ef5350',
          radius: 0.23),
      vessel(
          'pulmonary-veins',
          'Pulmonary veins',
          [
            [1.9, 1.75, -0.6],
            [1.5, 1.4, -0.45],
            [1.2, 1.25, -0.4],
          ],
          '#c62828',
          radius: 0.16),
      // Blood tracer for the circulation animation.
      {
        'id': 'blood-tracer',
        'name': 'Blood flow',
        'type': 'sphere',
        'group': 'flow',
        'params': {'radius': 0.13},
        'position': [-1.7, 2.6, 0.2],
        'color': '#00e5ff',
        'opacity': 1.0,
        'roughness': 0.2,
        'selectable': false,
      },
    ];

    return {
      'sceneId': 'human-heart',
      'camera': _camera(position: [3.8, 2.2, 5.6], target: [0, 0.3, 0]),
      'scaleInfo': {
        'label': '~12 cm  ·  magnified ≈×1',
        'note': 'Educational reconstruction',
      },
      'groups': ['muscle', 'chambers', 'valves', 'vessels', 'flow'],
      'objects': objects,
      'animations': [
        {
          'id': 'circulation',
          'title': 'Blood circulation (schematic)',
          'duration': 12.0,
          'tracks': [
            {
              'objectId': 'blood-tracer',
              'property': 'position',
              'keyframes': [
                {
                  't': 0.00,
                  'value': [-1.7, 2.6, 0.2]
                }, // vena cava
                {
                  't': 0.10,
                  'value': [-1.05, 1.05, 0.2]
                }, // right atrium
                {
                  't': 0.20,
                  'value': [-0.85, -0.5, 0.25]
                }, // right ventricle
                {
                  't': 0.32,
                  'value': [-0.45, 1.75, 0.75]
                }, // pulmonary artery
                {
                  't': 0.42,
                  'value': [-0.1, 2.5, 0.6]
                }, // to lungs
                {
                  't': 0.55,
                  'value': [1.9, 1.75, -0.6]
                }, // pulmonary veins
                {
                  't': 0.65,
                  'value': [1.0, 1.1, -0.35]
                }, // left atrium
                {
                  't': 0.78,
                  'value': [0.75, -0.6, -0.3]
                }, // left ventricle
                {
                  't': 0.90,
                  'value': [0.5, 1.7, -0.35]
                }, // aorta
                {
                  't': 1.00,
                  'value': [0.4, 2.75, 0.35]
                },
              ],
            },
          ],
        },
        {
          'id': 'heartbeat',
          'title': 'Heartbeat (schematic)',
          'duration': 3.0,
          'tracks': [
            {
              'objectId': 'right-ventricle',
              'property': 'scale',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1, 1, 1]
                },
                {
                  't': 0.45,
                  'value': [0.82, 0.72, 0.82]
                },
                {
                  't': 1.0,
                  'value': [1, 1, 1]
                },
              ],
            },
            {
              'objectId': 'left-ventricle',
              'property': 'scale',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1, 1, 1]
                },
                {
                  't': 0.45,
                  'value': [0.85, 0.75, 0.85]
                },
                {
                  't': 1.0,
                  'value': [1, 1, 1]
                },
              ],
            },
            {
              'objectId': 'tricuspid-valve',
              'property': 'rotation',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1.2, 0, 0]
                },
                {
                  't': 0.35,
                  'value': [1.9, 0, 0]
                },
                {
                  't': 1.0,
                  'value': [1.2, 0, 0]
                },
              ],
            },
            {
              'objectId': 'mitral-valve',
              'property': 'rotation',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1.2, 0, 0]
                },
                {
                  't': 0.35,
                  'value': [1.9, 0, 0]
                },
                {
                  't': 1.0,
                  'value': [1.2, 0, 0]
                },
              ],
            },
          ],
        },
      ],
    };
  }

  // ────────────────────────────────────────────────────────────────────────
  // Level 3 — cardiac muscle cell
  // ────────────────────────────────────────────────────────────────────────
  static Map<String, dynamic> cardiacMuscleCell() {
    final objects = <Map<String, dynamic>>[
      {
        'id': 'sarcolemma',
        'name': 'Sarcolemma',
        'type': 'capsuleShell',
        'group': 'membrane',
        'params': {'radius': 1.0, 'length': 2.6, 'thickness': 0.06},
        'position': [0, 0, 0],
        'color': '#4dd0e1',
        'opacity': 0.4,
        'roughness': 0.35,
        'selectable': true,
        'label': 'Sarcolemma — muscle cell membrane',
        'labelOffset': [0, 1.3, 0],
      },
      {
        'id': 'nucleus-cell',
        'name': 'Nucleus',
        'type': 'sphereBlob',
        'group': 'nucleus',
        'params': {
          'radius': 0.42,
          'squash': [1, 0.85, 0.9],
          'noise': 0.06
        },
        'position': [-0.35, 0.15, 0.25],
        'color': '#7e57c2',
        'opacity': 0.9,
        'roughness': 0.55,
        'selectable': true,
        'label': 'Nucleus (single, central)',
        'labelOffset': [0, 0.75, 0],
      },
      {
        'id': 'myofibril-1',
        'name': 'Myofibril',
        'type': 'tube',
        'group': 'contractile',
        'params': {
          'points': [
            [-1.4, -0.25, -0.15],
            [-0.5, -0.25, -0.15],
            [0.5, -0.25, -0.15],
            [1.5, -0.25, -0.15],
          ],
          'radius': 0.11,
        },
        'position': [0, 0, 0],
        'color': '#ef9a9a',
        'opacity': 0.9,
        'roughness': 0.5,
        'selectable': true,
        'label': 'Myofibril — actin & myosin bundles',
        'labelOffset': [0.4, 0.55, 0],
      },
      {
        'id': 'myofibril-2',
        'name': 'Myofibril',
        'type': 'tube',
        'group': 'contractile',
        'params': {
          'points': [
            [-1.4, 0.35, 0.3],
            [-0.5, 0.35, 0.3],
            [0.5, 0.35, 0.3],
            [1.5, 0.35, 0.3],
          ],
          'radius': 0.11,
        },
        'position': [0, 0, 0],
        'color': '#ef9a9a',
        'opacity': 0.9,
        'roughness': 0.5,
        'selectable': false,
      },
      {
        'id': 'mitochondrion-a',
        'name': 'Mitochondrion',
        'type': 'capsule',
        'group': 'organelles',
        'params': {'radius': 0.22, 'length': 0.55},
        'position': [0.55, 0.75, 0.2],
        'rotation': [0, 0, 0.5],
        'color': '#f06292',
        'opacity': 0.95,
        'roughness': 0.45,
        'selectable': true,
        'label': 'Mitochondrion — ATP production (zoom in)',
        'labelOffset': [0, 0.55, 0],
      },
      {
        'id': 'mitochondrion-b',
        'name': 'Mitochondrion',
        'type': 'capsule',
        'group': 'organelles',
        'params': {'radius': 0.2, 'length': 0.5},
        'position': [-0.9, -0.7, -0.3],
        'rotation': [0.4, 0, 0.9],
        'color': '#f06292',
        'opacity': 0.95,
        'roughness': 0.45,
        'selectable': false,
      },
    ];

    return {
      'sceneId': 'cardiac-muscle-cell',
      'camera': _camera(position: [2.8, 2.2, 4.6], target: [0, 0, 0]),
      'scaleInfo': {
        'label': '~100 µm  ·  magnified ≈×2,000',
        'note': 'Educational reconstruction',
      },
      'groups': ['membrane', 'nucleus', 'contractile', 'organelles'],
      'objects': objects,
      'animations': [
        {
          'id': 'contraction',
          'title': 'Cell contraction (schematic)',
          'duration': 3.0,
          'tracks': [
            {
              'objectId': 'myofibril-1',
              'property': 'scale',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1, 1, 1]
                },
                {
                  't': 0.5,
                  'value': [0.72, 1.25, 1.25]
                },
                {
                  't': 1.0,
                  'value': [1, 1, 1]
                },
              ],
            },
            {
              'objectId': 'sarcolemma',
              'property': 'scale',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1, 1, 1]
                },
                {
                  't': 0.5,
                  'value': [0.92, 1.05, 1.05]
                },
                {
                  't': 1.0,
                  'value': [1, 1, 1]
                },
              ],
            },
          ],
        },
      ],
    };
  }

  // ────────────────────────────────────────────────────────────────────────
  // Level 2 — mitochondrion
  // ────────────────────────────────────────────────────────────────────────
  static Map<String, dynamic> mitochondrion() {
    final objects = <Map<String, dynamic>>[
      {
        'id': 'outer-membrane',
        'name': 'Outer membrane',
        'type': 'capsuleShell',
        'group': 'membranes',
        'params': {'radius': 0.9, 'length': 2.0, 'thickness': 0.05},
        'position': [0, 0, 0],
        'color': '#f48fb1',
        'opacity': 0.5,
        'roughness': 0.4,
        'selectable': true,
        'label': 'Outer membrane',
        'labelOffset': [0, 1.25, 0],
      },
      {
        'id': 'inner-membrane',
        'name': 'Inner membrane',
        'type': 'capsuleShell',
        'group': 'membranes',
        'params': {'radius': 0.7, 'length': 1.75, 'thickness': 0.04},
        'position': [0, 0, 0],
        'color': '#ce93d8',
        'opacity': 0.65,
        'roughness': 0.4,
        'selectable': true,
        'label': 'Inner membrane — electron transport chain',
        'labelOffset': [0, 0.95, 0.4],
      },
    ];

    // Cristae: folded shelf tubes inside.
    for (var i = 0; i < 5; i++) {
      final x = -0.75 + i * 0.36;
      objects.add({
        'id': 'crista-$i',
        'name': 'Cristae',
        'type': 'tube',
        'group': 'cristae',
        'params': {
          'points': [
            [x, 0.0, -0.5],
            [x, 0.45, 0.0],
            [x, 0.05, 0.45],
            [x, -0.4, 0.1],
          ],
          'radius': 0.05,
        },
        'position': [0, 0, 0],
        'color': '#ba68c8',
        'opacity': 0.9,
        'roughness': 0.45,
        'selectable': true,
        'label': i == 2 ? 'Cristae — folds of the inner membrane' : null,
        'labelOffset': [0, 0.75, 0],
      });
    }

    objects.add({
      'id': 'matrix',
      'name': 'Matrix',
      'type': 'capsule',
      'group': 'matrix',
      'params': {'radius': 0.62, 'length': 1.6},
      'position': [0, 0, 0],
      'color': '#4a148c',
      'opacity': 0.35,
      'roughness': 0.8,
      'selectable': true,
      'label': 'Matrix — Krebs cycle, mitochondrial DNA',
      'labelOffset': [-0.6, -1.05, 0.2],
    });

    return {
      'sceneId': 'mitochondrion',
      'camera': _camera(position: [2.6, 2.0, 4.2], target: [0, 0, 0]),
      'scaleInfo': {
        'label': '~2 µm  ·  magnified ≈×10,000',
        'note': 'Educational reconstruction',
      },
      'groups': ['membranes', 'cristae', 'matrix'],
      'objects': objects,
      'animations': [
        {
          'id': 'atp-production',
          'title': 'ATP production (schematic)',
          'duration': 6.0,
          'tracks': [
            {
              // Proton pulse — schematic flow through the cristae.
              'objectId': 'crista-2',
              'property': 'scale',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1, 1, 1]
                },
                {
                  't': 0.5,
                  'value': [1.06, 1.06, 1.06]
                },
                {
                  't': 1.0,
                  'value': [1, 1, 1]
                },
              ],
            },
            {
              'objectId': 'crista-3',
              'property': 'scale',
              'keyframes': [
                {
                  't': 0.0,
                  'value': [1, 1, 1]
                },
                {
                  't': 0.65,
                  'value': [1.06, 1.06, 1.06]
                },
                {
                  't': 1.0,
                  'value': [1, 1, 1]
                },
              ],
            },
          ],
        },
      ],
    };
  }

  // ────────────────────────────────────────────────────────────────────────
  // Level 7 — whole human organism (simplified systems map)
  // ────────────────────────────────────────────────────────────────────────
  static Map<String, dynamic> humanOrganism() {
    Map<String, dynamic> organ(String id, String label, List<double> position, List<double> scale, String color) => {
          'id': id,
          'name': label,
          'type': 'sphereBlob',
          'group': 'organs',
          'params': {'radius': 1, 'squash': scale, 'noise': 0.05},
          'position': position,
          'color': color,
          'opacity': 0.9,
          'roughness': 0.55,
          'selectable': true,
          'label': label,
          'labelOffset': [0, 0.7, 0],
        };

    final objects = <Map<String, dynamic>>[
      // Body silhouette: head + torso + limbs as a soft translucent capsule.
      {
        'id': 'body',
        'name': 'Human body (silhouette)',
        'type': 'capsule',
        'group': 'silhouette',
        'params': {'radius': 1.05, 'length': 3.6},
        'position': [0, 0, 0],
        'color': '#263238',
        'opacity': 0.45,
        'roughness': 0.9,
        'selectable': false,
      },
      {
        'id': 'head',
        'name': 'Head',
        'type': 'sphere',
        'group': 'silhouette',
        'params': {'radius': 0.75},
        'position': [0, 3.3, 0],
        'color': '#37474f',
        'opacity': 0.5,
        'selectable': false,
      },
      organ('brain', 'Brain', [0, 3.35, 0.1], [1, 0.85, 1], '#9575cd'),
      organ('lungs', 'Lungs', [0.55, 1.55, 0], [0.7, 1.0, 0.55], '#e57373'),
      organ('heart', 'Heart', [-0.45, 1.5, 0.15], [0.55, 0.6, 0.5], '#c62828'),
      organ('stomach', 'Stomach', [0.25, 0.15, 0.2], [0.6, 0.45, 0.5], '#ffb74d'),
      organ('liver', 'Liver', [0.8, 0.55, -0.1], [0.75, 0.4, 0.55], '#8d6e63'),
      organ('kidneys', 'Kidneys', [0, -0.65, -0.35], [1.3, 0.35, 0.4], '#a1887f'),
    ];

    return {
      'sceneId': 'human-organism',
      'camera': _camera(position: [0, 2.0, 8.5], target: [0, 1.2, 0]),
      'scaleInfo': {
        'label': '~1.7 m  ·  ×1',
        'note': 'Educational reconstruction — simplified organ placement',
      },
      'groups': ['silhouette', 'organs'],
      'objects': objects,
      'animations': [],
    };
  }
}
