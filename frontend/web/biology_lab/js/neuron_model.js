'use strict';

/* Phase 9: neurone (neuron) model - a biologically accurate, educationally
   honest model of a myelinated sensory/motor neurone and its chemical synapse.

   Pure data + rules only: no THREE, no DOM. The host (js/neuron_viewer.js)
   turns `buildNeuronGeometry()` into meshes and animates them with the frame
   state from `frameAt(stage, progress)`. `neuronTimeline` mirrors the Flutter
   engine's 9-stage process so the 2D and 3D views tell the same story.

   Scientific notes (also surfaced as `accuracy` strings so the UI can show
   "simplified model" disclaimers rather than implying false precision):
   - A real neurone has thousands of synapses; this model shows one of each
     terminal type (one incoming contact on the soma, one outgoing terminal).
   - Myelin internodes and the nodes of Ranvier are drawn to scale-length but
     their true count along an axon is far higher.
   - Ion channels, pumps and the ~ -70 mV resting potential are represented by
     gated glyphs, not by simulated ion flux.
   - Neurotransmitter molecules are drawn as a representative handful, not the
     ~10^3-10^4 released per vesicle. */

var SCHEMA = 'neuron/1';

/* Anatomical structures, ids kept identical to the Flutter catalogue
   (neuron_anatomy.dart) so labels/explanations match across both engines. */
var NEURON_STRUCTURES = [
  { id: 'dendrites', region: 'input', label: 'Dendrites', short: 'Dendrites',
    marker: 'branching-brush',
    role: 'receive signals and carry them toward the cell body',
    detail: 'Highly branched to collect input from many other neurones.' },
  { id: 'soma', region: 'input', label: 'Cell body (soma)', short: 'Soma',
    marker: 'round-hub',
    role: 'contains the nucleus and organelles; sums incoming signals',
    detail: 'Metabolic centre: proteins and organelles needed by the axon are made here.' },
  { id: 'nucleus', region: 'input', label: 'Nucleus', short: 'Nucleus',
    marker: 'dotted-circle',
    role: 'stores genetic material and directs protein synthesis',
    detail: 'Controls the neurone\u2019s long-term structure and biochemistry.' },
  { id: 'axon_hillock', region: 'input', label: 'Axon hillock', short: 'Hillock',
    marker: 'cone',
    role: 'trigger zone where the action potential starts',
    detail: 'Has the highest density of voltage-gated Na+ channels, so summation crossing threshold fires here first.' },
  { id: 'axon', region: 'conduction', label: 'Axon', short: 'Axon',
    marker: 'long-line',
    role: 'conducts the action potential away from the cell body',
    detail: 'A single long fibre; its length is why myelination matters for speed.' },
  { id: 'myelin', region: 'conduction', label: 'Myelin sheath', short: 'Myelin',
    marker: 'segmented-sleeve',
    role: 'insulates the axon and speeds conduction',
    detail: 'Formed by Schwann cells; electrical insulation lets the impulse jump between nodes.' },
  { id: 'node_of_ranvier', region: 'conduction', label: 'Nodes of Ranvier', short: 'Node',
    marker: 'bare-gap',
    role: 'gaps where the impulse is regenerated (saltatory conduction)',
    detail: 'Clustered voltage-gated Na+ channels regenerate the impulse at each node.' },
  { id: 'axon_terminal', region: 'output', label: 'Axon terminal (bouton)', short: 'Terminal',
    marker: 'bulb',
    role: 'releases neurotransmitter onto the next cell',
    detail: 'Swollen ending packed with vesicles; largely Ca2+ triggered.' },
  { id: 'vesicles', region: 'output', label: 'Synaptic vesicles', short: 'Vesicles',
    marker: 'small-bubbles',
    role: 'store neurotransmitter packaged ready for release',
    detail: 'Each vesicle holds several thousand molecules of neurotransmitter.' },
  { id: 'synaptic_cleft', region: 'output', label: 'Synaptic cleft', short: 'Cleft',
    marker: 'narrow-channel',
    role: 'the gap the neurotransmitter diffuses across',
    detail: 'About 20 nm wide; diffusion across it takes milliseconds.' },
  { id: 'neurotransmitter', region: 'output', label: 'Neurotransmitter', short: 'NT',
    marker: 'dots',
    role: 'the chemical signal carrying the message to the next cell',
    detail: 'Released into the cleft, it diffuses to the opposite membrane.' },
  { id: 'postsynaptic', region: 'output', label: 'Postsynaptic membrane', short: 'Postsynaptic',
    marker: 'thick-wall',
    role: 'the next neurone\u2019s membrane that receives the signal',
    detail: 'Belongs to the next cell in the chain, not to this neurone.' },
  { id: 'receptors', region: 'output', label: 'Receptors', short: 'Receptors',
    marker: 'cup',
    role: 'bind neurotransmitter to trigger the next cell',
    detail: 'On the postsynaptic side; binding opens ion channels that may excite or inhibit.' },
];

/* The nine-stage story, identical to the Flutter timeline. `mode` tags each
   stage for the Phase-5 teaching modes: 'A' electrical, 'B' chemical. */
var NEURON_TIMELINE = [
  { id: 0, mode: 'A', title: 'Resting neurone', summary: 'The neurone is polarised: inside negative relative to outside.' },
  { id: 1, mode: 'A', title: 'Threshold reached', summary: 'Summed input at the hillock crosses threshold.' },
  { id: 2, mode: 'A', title: 'Action potential fires', summary: 'Voltage-gated Na+ channels open; the membrane depolarises.' },
  { id: 3, mode: 'A', title: 'Impulse travels down axon', summary: 'The action potential sweeps along the axon.' },
  { id: 4, mode: 'A', title: 'Saltatory conduction', summary: 'The impulse jumps node to node between myelin segments.' },
  { id: 5, mode: 'B', title: 'Ca2+ enters terminal', summary: 'Depolarisation opens Ca2+ channels at the axon terminal.' },
  { id: 6, mode: 'B', title: 'Vesicles release neurotransmitter', summary: 'Vesicles fuse with the membrane and empty into the cleft.' },
  { id: 7, mode: 'B', title: 'Diffusion across the cleft', summary: 'Neurotransmitter crosses the ~20 nm cleft by diffusion.' },
  { id: 8, mode: 'B', title: 'Receptor binding', summary: 'Neurotransmitter binds receptors and triggers the next cell.' },
];

/* Teaching modes for the 3D host toolbar, matching the Flutter screen. */
var NEURON_MODES = [
  { id: 'full', title: 'Full process', first: 0, last: 8, simplified: false },
  { id: 'A', title: 'A - Electrical impulse', first: 0, last: 4, simplified: false },
  { id: 'B', title: 'B - Chemical transmission', first: 3, last: 8, simplified: true },
];

var ACCURACY = {
  dendrites: 'branch count illustrative (a real neurone may have 1000s of synapses)',
  myelin: 'internode count reduced; true myelinated axons have many more segments',
  vesicles: 'representative handful of vesicles and molecules drawn',
  ions: 'membrane potential shown by gated glyphs, not simulated ion flux',
  cleft: 'cleft width exaggerated for visibility (true width ~20 nm)',
};

/* --- geometry specification (host builds meshes from this) --------------- */

/* Layout is in "model units": the soma sits near the origin, the axon runs
   along +x, dendrites fan out on -x, the synapse crosses a cleft at the far
   +x end. Deterministic so tests can assert exact structure counts. */
function buildNeuronGeometry(opts) {
  var o = opts || {};
  var somaRadius = o.somaRadius != null ? o.somaRadius : 0.55;
  var dendriteCount = o.dendriteCount != null ? o.dendriteCount : 7;
  var internodeCount = o.internodeCount != null ? o.internodeCount : 5;
  var nodeGap = o.nodeGap != null ? o.nodeGap : 0.18;
  var internodeLength = o.internodeLength != null ? o.internodeLength : 0.72;
  var axonRadius = o.axonRadius != null ? o.axonRadius : 0.075;

  var dendrites = [];
  var fanMin = Math.PI * 0.62;
  var fanMax = Math.PI * 1.38;
  for (var i = 0; i < dendriteCount; i++) {
    var t = dendriteCount === 1 ? 0.5 : i / (dendriteCount - 1);
    var angle = fanMin + (fanMax - fanMin) * t;
    var len = 1.35 + 0.35 * Math.sin(t * Math.PI);
    dendrites.push({
      id: 'dendrite-' + i,
      origin: { x: -somaRadius * 0.7, y: 0.1 * (t - 0.5), z: 0 },
      angle: angle,
      length: len,
      radius: 0.045,
    });
  }

  /* Axon: alternating myelin internodes (sleeves) and bare nodes. Each
     internode is a thick sleeve; each gap between sleeves is a node. */
  var axonStartX = somaRadius * 0.9;
  var internodes = [];
  var nodes = [];
  var x = axonStartX;
  for (var k = 0; k < internodeCount; k++) {
    internodes.push({
      id: 'internode-' + k,
      x0: x + nodeGap * 0.5,
      x1: x + internodeLength - nodeGap * 0.5,
      y: 0,
      z: 0,
      radius: axonRadius * 2.1,
    });
    x += internodeLength;
    if (k < internodeCount - 1) {
      nodes.push({ id: 'node-' + k, x: x, y: 0, z: 0, radius: axonRadius });
    }
  }
  var axonEndX = x;

  return {
    schema: SCHEMA,
    soma: { x: 0, y: 0, z: 0, radius: somaRadius },
    nucleus: { x: 0, y: 0, z: 0, radius: somaRadius * 0.5 },
    hillock: { x: somaRadius * 0.75, y: 0, z: 0, radius: axonRadius * 1.6 },
    dendrites: dendrites,
    axon: {
      startX: axonStartX,
      endX: axonEndX,
      y: 0,
      z: 0,
      radius: axonRadius,
    },
    internodes: internodes,
    nodes: nodes,
    terminal: { x: axonEndX + 0.32, y: 0, z: 0, radius: 0.26 },
    cleft: { x: axonEndX + 0.62, y: 0, z: 0, width: 0.09 },
    postsynaptic: { x: axonEndX + 0.75, y: 0, z: 0, radius: 0.42 },
    receptorCount: 6,
    vesicleCount: 8,
    neurotransmitterCount: 12,
  };
}

/* --- animation ----------------------------------------------------------- */

/* Map a global stage + 0..1 progress to a frame state describing how much of
   the impulse has travelled and which glyph groups are active. Deterministic
   and side-effect free so it is unit-testable without a renderer. */
function frameAt(stage, progress) {
  var s = Math.max(0, Math.min(NEURON_TIMELINE.length - 1, Math.round(stage)));
  var p = Math.max(0, Math.min(1, progress == null ? 0 : progress));

  /* impulse position as a fraction along the axon (0 at hillock, 1 at node end) */
  var impulse = 0;
  if (s <= 0) impulse = 0;
  else if (s === 1) impulse = 0.05 * p;
  else if (s === 2) impulse = 0.06 + 0.06 * p;
  else if (s === 3) impulse = 0.12 + 0.55 * p;
  else if (s === 4) impulse = 0.67 + 0.28 * p;
  else impulse = 1;

  var calcium = s >= 5;
  var release = s >= 6;
  var diffusion = s >= 7;
  var binding = s >= 8;

  /* pulsed release strength ramps in during its stage */
  var releaseAmount = release ? (s === 6 ? p : 1) : 0;
  var diffusionAmount = diffusion ? (s === 7 ? p : 1) : 0;
  var bindingAmount = binding ? (s === 8 ? p : 1) : 0;

  return {
    stage: s,
    progress: p,
    mode: NEURON_TIMELINE[s].mode,
    impulse: impulse,
    depolarised: s === 2 || s === 3 || s === 4 ? (s === 2 ? p : 1) : 0,
    calcium: calcium,
    release: release,
    releaseAmount: releaseAmount,
    diffusion: diffusion,
    diffusionAmount: diffusionAmount,
    binding: binding,
    bindingAmount: bindingAmount,
  };
}

var neuronStructureById = {};
NEURON_STRUCTURES.forEach(function (n) { neuronStructureById[n.id] = n; });

/* Expected mesh counts per structure id for a built geometry. Shared by the
   host viewer (to sanity-check its build) and the unit test so the two can
   never silently drift. Singletons are 1; variable parts report their count. */
function expectedMeshCounts(geometry) {
  var g = geometry || buildNeuronGeometry();
  return {
    soma: 1,
    nucleus: 1,
    axon_hillock: 1,
    axon: 1,
    axon_terminal: 1,
    synaptic_cleft: 1,
    postsynaptic: 1,
    dendrites: g.dendrites.length,
    myelin: g.internodes.length,
    node_of_ranvier: g.nodes.length,
    vesicles: g.vesicleCount,
    neurotransmitter: g.neurotransmitterCount,
    receptors: g.receptorCount,
  };
}

function neuronTimelineForMode(modeId) {
  var m = NEURON_MODES.filter(function (x) { return x.id === modeId; })[0] || NEURON_MODES[0];
  return NEURON_TIMELINE.slice(m.first, m.last + 1);
}

export {
  SCHEMA,
  NEURON_STRUCTURES,
  NEURON_TIMELINE,
  NEURON_MODES,
  ACCURACY,
  neuronStructureById,
  neuronTimelineForMode,
  buildNeuronGeometry,
  frameAt,
  expectedMeshCounts,
};
