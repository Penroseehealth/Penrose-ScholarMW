/// Single structured source of truth for neuron anatomy (Phase 1).
///
/// The AI layer / UI decides WHAT is on screen; this file is the authoritative
/// catalogue of the anatomical structures, their scientifically correct names,
/// their function, their role in signal transmission and a short observation
/// prompt. Both the animated [NeuronPainter] and the static
/// `NeuronDiagramRenderer` (SVG), plus the interactive exploration panel
/// (Phase 4), read from [neuronStructures] so no label string or explanation is
/// duplicated across components.
///
/// Scientific rules baked into the model:
///   * dendrites feed the soma; the axon leaves via the hillock;
///   * electrical signalling (action potential) travels WITHIN the axon, jumping
///     between nodes of Ranvier (saltatory conduction);
///   * chemical signalling (neurotransmitter) happens ONLY at the presynaptic
///     terminal and diffuses across the cleft to receptors on a separate
///     postsynaptic cell's membrane — neurotransmitters never travel down the
///     axon and never pass through the postsynaptic membrane.
///
/// This is a clear educational schematic: real neurons vary widely in shape.
library;

import 'package:flutter/foundation.dart' show immutable;

/// Where a structure sits in the direction of signal flow. Used for grouping,
/// the legend and the "structure list" accessibility view — never as the only
/// way to convey meaning (colour-independent markers are provided too).
enum NeuronRegion {
  receiving('Receiving (dendrites · soma)'),
  conducting('Conducting (axon · myelin · hillock)'),
  transmitting('Transmitting (terminal · cleft)'),
  responding('Responding (postsynaptic membrane · receptors)');

  const NeuronRegion(this.label);
  final String label;
}

/// Electrical vs chemical signalling, as distinguished by the legend.
enum NeuronSignal {
  electrical('Electrical', 'within the neurone'),
  chemical('Chemical', 'across the synapse');

  const NeuronSignal(this.label, this.detail);
  final String label;
  final String detail;
}

/// One anatomical structure with its teaching payload.
///
/// Coordinates [anchorDx]/[anchorDy] and [labelDx]/[labelDy] are on the painter's
/// logical 1200×744 canvas and are shared with the SVG renderer (scaled there).
@immutable
class NeuronStructure {
  const NeuronStructure({
    required this.id,
    required this.name,
    required this.shortName,
    required this.region,
    required this.signal,
    required this.function,
    required this.detail,
    required this.roleInTransmission,
    required this.observe,
    required this.marker,
    required this.anchorDx,
    required this.anchorDy,
    required this.labelDx,
    required this.labelDy,
  });

  /// Stable id (also the `BiologySpec` structure id, e.g. `'axon_hillock'`).
  final String id;

  /// Full display name shown in the info panel (e.g. `'Axon hillock'`).
  final String name;

  /// Compact label drawn on the diagram (may equal [name]).
  final String shortName;

  final NeuronRegion region;

  /// The signal type this structure carries/participates in.
  final NeuronSignal signal;

  /// Plain-language function (one sentence, secondary-school level).
  final String function;

  /// More detailed explanation appropriate for biology students.
  final String detail;

  /// Its role in signal transmission specifically.
  final String roleInTransmission;

  /// Short "what to observe" note.
  final String observe;

  /// Short, colour-independent marker glyph for the legend/structure list.
  final String marker;

  /// Leader-line anchor on the 1200×744 canvas (points at the structure).
  final double anchorDx;
  final double anchorDy;

  /// Label text origin on the 1200×744 canvas.
  final double labelDx;
  final double labelDy;

  /// Label box height used for leader-line start (font baseline offset).
  static const double labelBaseline = 11;
}

/// The canonical neuron structures, in direction-of-signal order.
const List<NeuronStructure> neuronStructures = [
  NeuronStructure(
    id: 'dendrites',
    name: 'Dendrites',
    shortName: 'Dendrites',
    region: NeuronRegion.receiving,
    signal: NeuronSignal.electrical,
    function: 'Short branched fibres that receive signals from other neurones.',
    detail: 'Dendrites are highly branched extensions of the cell body. They carry the '
        'incoming electrical signal toward the soma and give the neurone a large '
        'surface area to connect with many other cells.',
    roleInTransmission: 'Receive graded electrical signals and pass them toward the cell body; the '
        'summed input may start a new action potential at the hillock.',
    observe: 'Notice the branches join smoothly onto the cell body — they are not separate lines.',
    marker: 'Y',
    anchorDx: 92,
    anchorDy: 238,
    labelDx: 20,
    labelDy: 150,
  ),
  NeuronStructure(
    id: 'soma',
    name: 'Cell body (soma)',
    shortName: 'Cell body (soma)',
    region: NeuronRegion.receiving,
    signal: NeuronSignal.electrical,
    function: 'The main body of the neurone that keeps the cell alive and processes inputs.',
    detail: 'The soma contains the nucleus, cytoplasm, mitochondria and other organelles. '
        'It maintains the cell and integrates the signals arriving from the dendrites.',
    roleInTransmission: 'Integrates incoming signals; if the summed depolarisation reaches threshold '
        'at the trigger zone, an action potential is initiated.',
    observe: 'The nucleus sits inside the soma — it is never drawn outside the membrane.',
    marker: 'S',
    anchorDx: 180,
    anchorDy: 468,
    labelDx: 30,
    labelDy: 610,
  ),
  NeuronStructure(
    id: 'nucleus',
    name: 'Nucleus',
    shortName: 'Nucleus',
    region: NeuronRegion.receiving,
    signal: NeuronSignal.electrical,
    function: 'Controls the cell and holds its genetic material.',
    detail: 'The nucleus contains DNA and directs protein synthesis, including the ion '
        'channels and pumps that make the membrane excitable.',
    roleInTransmission: 'Provides the proteins (ion channels, pumps) that create and restore the '
        'resting potential.',
    observe: 'It is drawn as a solid body fully inside the cell body.',
    marker: 'N',
    anchorDx: 255,
    anchorDy: 356,
    labelDx: 320,
    labelDy: 270,
  ),
  NeuronStructure(
    id: 'axon_hillock',
    name: 'Axon hillock (initial segment)',
    shortName: 'Axon hillock',
    region: NeuronRegion.conducting,
    signal: NeuronSignal.electrical,
    function: 'The cone-shaped junction where the axon leaves the cell body.',
    detail: 'The axon hillock is where the axon joins the soma. It has a high density of '
        'voltage-gated sodium channels and acts as the trigger zone that decides '
        'whether an action potential is fired.',
    roleInTransmission: 'The summing junction: if the depolarisation here reaches threshold, the '
        'action potential begins and travels down the axon.',
    observe: 'The axon leaves the soma as a smooth cone here — it does not just snap off.',
    marker: 'H',
    anchorDx: 322,
    anchorDy: 400,
    labelDx: 355,
    labelDy: 560,
  ),
  NeuronStructure(
    id: 'axon',
    name: 'Axon',
    shortName: 'Axon',
    region: NeuronRegion.conducting,
    signal: NeuronSignal.electrical,
    function: 'A long fibre that carries the electrical impulse away from the cell body.',
    detail: 'The axon is a single long extension that conducts the action potential away '
        'from the soma toward the axon terminals. It is continuous from the hillock '
        'to the terminal boutons.',
    roleInTransmission: 'Conducts the action potential (electrical) along its length; it never carries '
        'neurotransmitters.',
    observe: 'The electrical pulse travels along the axon, not the neurotransmitter.',
    marker: 'A',
    anchorDx: 560,
    anchorDy: 420,
    labelDx: 400,
    labelDy: 640,
  ),
  NeuronStructure(
    id: 'myelin_sheath',
    name: 'Myelin sheath',
    shortName: 'Myelin sheath',
    region: NeuronRegion.conducting,
    signal: NeuronSignal.electrical,
    function: 'Fatty insulating segments that speed up the impulse.',
    detail: 'Myelin is formed by Schwann cells (or oligodendrocytes in the CNS) and wraps '
        'the axon in segments, insulating it so the impulse can jump between gaps.',
    roleInTransmission: 'Forces the action potential to jump node to node (saltatory conduction), '
        'making conduction faster and saving energy.',
    observe: 'Each myelin segment is separate, with a bare gap between them.',
    marker: 'M',
    anchorDx: 430,
    anchorDy: 350,
    labelDx: 470,
    labelDy: 230,
  ),
  NeuronStructure(
    id: 'nodes_of_ranvier',
    name: 'Node of Ranvier',
    shortName: 'Node of Ranvier',
    region: NeuronRegion.conducting,
    signal: NeuronSignal.electrical,
    function: 'The exposed gaps between myelin segments where the impulse jumps.',
    detail: 'Nodes of Ranvier are short unmyelinated regions packed with voltage-gated '
        'sodium channels, where the action potential is regenerated.',
    roleInTransmission: 'The action potential leaps from node to node; this is what makes saltatory '
        'conduction fast.',
    observe: 'Look for the bare gaps in the myelin where the impulse seems to jump.',
    marker: 'R',
    anchorDx: 664,
    anchorDy: 350,
    labelDx: 700,
    labelDy: 230,
  ),
  NeuronStructure(
    id: 'axon_terminal',
    name: 'Axon terminal (bouton)',
    shortName: 'Axon terminal',
    region: NeuronRegion.transmitting,
    signal: NeuronSignal.chemical,
    function: 'The swollen end of the axon that stores and releases neurotransmitter.',
    detail: 'The presynaptic terminal (bouton) is an enlargement at the end of the axon. It '
        'contains synaptic vesicles and, when depolarised, releases neurotransmitter.',
    roleInTransmission: 'Converts the electrical impulse into a chemical signal by releasing '
        'neurotransmitter into the cleft.',
    observe: 'The terminal is a smooth swelling of the axon end — not a floating blob.',
    marker: 'T',
    anchorDx: 858,
    anchorDy: 370,
    labelDx: 700,
    labelDy: 90,
  ),
  NeuronStructure(
    id: 'synaptic_vesicles',
    name: 'Synaptic vesicles',
    shortName: 'Synaptic vesicles',
    region: NeuronRegion.transmitting,
    signal: NeuronSignal.chemical,
    function: 'Small membrane-bound sacs that store neurotransmitter.',
    detail: 'Vesicles are tiny spheres inside the presynaptic terminal. They fuse with the '
        'presynaptic membrane and release their neurotransmitter by exocytosis.',
    roleInTransmission: 'Store and release neurotransmitter into the synaptic cleft.',
    observe: 'Vesicles are always inside the terminal, never out in the cleft.',
    marker: 'V',
    anchorDx: 904,
    anchorDy: 344,
    labelDx: 830,
    labelDy: 120,
  ),
  NeuronStructure(
    id: 'synaptic_cleft',
    name: 'Synaptic cleft',
    shortName: 'Synaptic cleft',
    region: NeuronRegion.transmitting,
    signal: NeuronSignal.chemical,
    function: 'The narrow gap between the two neurones.',
    detail: 'The cleft is a real extracellular space of about 20 nm that separates the '
        'presynaptic terminal from the postsynaptic membrane.',
    roleInTransmission: 'Neurotransmitter diffuses across this gap to reach the receptors; the gap '
        'itself cannot conduct electricity.',
    observe: 'It is a true gap — the two cells do not touch.',
    marker: 'C',
    anchorDx: 924,
    anchorDy: 210,
    labelDx: 840,
    labelDy: 40,
  ),
  NeuronStructure(
    id: 'neurotransmitter',
    name: 'Neurotransmitters',
    shortName: 'Neurotransmitters',
    region: NeuronRegion.transmitting,
    signal: NeuronSignal.chemical,
    function: 'Chemical messenger molecules released into the cleft.',
    detail: 'Neurotransmitters are signalling molecules that diffuse across the cleft and '
        'bind to matching receptors — a lock-and-key interaction.',
    roleInTransmission: 'Carry the signal chemically from the presynaptic terminal to the '
        'postsynaptic receptors.',
    observe: 'They travel across the cleft to receptors, not through the postsynaptic membrane.',
    marker: '•',
    anchorDx: 928,
    anchorDy: 520,
    labelDx: 800,
    labelDy: 690,
  ),
  NeuronStructure(
    id: 'postsynaptic_membrane',
    name: 'Postsynaptic membrane',
    shortName: 'Postsynaptic membrane',
    region: NeuronRegion.responding,
    signal: NeuronSignal.chemical,
    function: 'The membrane of the cell that receives the signal.',
    detail: 'The postsynaptic membrane belongs to a separate cell. It carries receptors '
        'that respond to the neurotransmitter, converting the chemical signal back '
        'into an electrical one.',
    roleInTransmission: 'Responds to the neurotransmitter by opening ion channels and changing its '
        'own membrane potential.',
    observe: 'It is the boundary of a different cell, facing across the cleft.',
    marker: 'P',
    anchorDx: 944,
    anchorDy: 452,
    labelDx: 1020,
    labelDy: 648,
  ),
  NeuronStructure(
    id: 'receptors',
    name: 'Receptors',
    shortName: 'Receptors',
    region: NeuronRegion.responding,
    signal: NeuronSignal.chemical,
    function: 'Protein binding sites on the postsynaptic membrane.',
    detail: 'Receptors are membrane proteins shaped to fit a specific neurotransmitter. '
        'Binding opens ion channels and can excite or inhibit the receiving cell.',
    roleInTransmission: 'Detect the neurotransmitter and trigger the postsynaptic response; whether it '
        'excites or inhibits depends on the receptor and cell.',
    observe: 'Receptors sit on the postsynaptic membrane, facing the cleft.',
    marker: 'X',
    anchorDx: 944,
    anchorDy: 384,
    labelDx: 1090,
    labelDy: 470,
  ),
];

/// Fast lookup by id (also matches the legacy `BiologySpec` structure ids).
final Map<String, NeuronStructure> neuronStructureById = {
  for (final s in neuronStructures) s.id: s,
};

/// Colour-independent marker lookup for a structure id.
String neuronMarkerFor(String id) => neuronStructureById[id]?.marker ?? '?';
