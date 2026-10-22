/* Curated Krebs (citric acid / TCA) cycle model (P4-001, P4-002).
 *
 * This is the verified-science half of the lesson. Every field here is a factual
 * claim, curated from standard biochemistry references and cited in `source`.
 * The renderer consumes it read-only; generative styling can never mutate it.
 *
 * Curation references (checked for reaction order, enzymes, cofactor balance):
 *   - Berg, Tymoczko & Stryer, "Biochemistry" (citric acid cycle chapter)
 *   - Lodish et al., "Molecular Cell Biology"
 *   - Reactome pathway R-HSA-71403 (citric acid cycle, Homo sapiens)
 *   - NCBI Bookshelf / StatPearls "Biochemistry, Citric Acid Cycle"
 *
 * The cycle proper has EIGHT reactions that regenerate oxaloacetate (OAA). Entry
 * of a two-carbon acetyl group is preceded by the pyruvate dehydrogenase
 * reaction (which is NOT one of the eight) and is modelled separately so the
 * distinction is explicit.
 *
 * Per-turn balance for one acetyl-CoA entering the eight reactions:
 *   3 NADH + 1 FADH2 + 1 GTP (ATP equivalent) + 2 CO2
 *
 * `uncertainty` records genuine caveats (isoform/enzyme naming, organism
 * differences) so the UI never presents a simplification as universal truth.
 */
"use strict";

/* The eight canonical reactions of the cycle, in order. `from` and `to` are the
   organic carbon intermediates; `enzymes` lists catalytic enzyme(s). `cofactors`
   lists molecules produced/released at that step. `carbonCount` is the number of
   carbons in the labelled organic intermediate. */
var STAGES = [
  {
    n: 1,
    name: "Citrate synthesis",
    reaction: "Acetyl-CoA + Oxaloacetate + H2O -> Citrate + CoA-SH",
    from: "oxaloacetate",
    to: "citrate",
    enzymes: ["citrate synthase"],
    cofactors: ["CoA-SH released"],
    carbonCount: 6,
    direction: "irreversible",
    detail: "The two-carbon acetyl group from acetyl-CoA condenses with four-carbon oxaloacetate to form six-carbon citrate. This commits the acetyl group to the cycle and releases coenzyme A.",
  },
  {
    n: 2,
    name: "Isomerisation via aconitase",
    reaction: "Citrate -> Isocitrate (via cis-aconitate)",
    from: "citrate",
    to: "isocitrate",
    enzymes: ["aconitase (aconitate hydratase)"],
    cofactors: [],
    carbonCount: 6,
    direction: "reversible",
    detail: "Aconitase repositions the hydroxyl group, converting citrate to isocitrate through the intermediate cis-aconitate, preparing the molecule for oxidative decarboxylation.",
  },
  {
    n: 3,
    name: "First oxidative decarboxylation",
    reaction: "Isocitrate + NAD+ -> alpha-Ketoglutarate + NADH + CO2",
    from: "isocitrate",
    to: "alpha-ketoglutarate",
    enzymes: ["isocitrate dehydrogenase"],
    cofactors: ["NADH", "CO2"],
    carbonCount: 5,
    direction: "irreversible",
    detail: "Isocitrate dehydrogenase performs the first oxidative decarboxylation: one carbon is lost as CO2, NAD+ is reduced to NADH, and the five-carbon alpha-ketoglutarate is formed. This is a key regulated, rate-limiting step.",
  },
  {
    n: 4,
    name: "Second oxidative decarboxylation",
    reaction: "alpha-Ketoglutarate + NAD+ + CoA-SH -> Succinyl-CoA + NADH + CO2",
    from: "alpha-ketoglutarate",
    to: "succinyl-CoA",
    enzymes: ["alpha-ketoglutarate dehydrogenase complex"],
    cofactors: ["NADH", "CO2"],
    carbonCount: 4,
    direction: "irreversible",
    detail: "The alpha-ketoglutarate dehydrogenase complex releases the second CO2, reduces NAD+ to NADH, and attaches coenzyme A to give the high-energy thioester succinyl-CoA. Like pyruvate dehydrogenase, it requires thiamine pyrophosphate, lipoate, and its own cofactors.",
  },
  {
    n: 5,
    name: "Substrate-level phosphorylation",
    reaction: "Succinyl-CoA + GDP + Pi -> Succinate + GTP + CoA-SH",
    from: "succinyl-CoA",
    to: "succinate",
    enzymes: ["succinyl-CoA synthetase (succinate thiokinase)"],
    cofactors: ["GTP (ATP equivalent)", "CoA-SH released"],
    carbonCount: 4,
    direction: "reversible",
    detail: "The energy stored in the succinyl-CoA thioester drives substrate-level phosphorylation: GDP is phosphorylated to GTP (an ATP equivalent), and succinate is released. In many tissues GTP is readily converted to ATP by nucleoside diphosphate kinase.",
  },
  {
    n: 6,
    name: "Succinate oxidation (FAD-linked)",
    reaction: "Succinate + FAD -> Fumarate + FADH2",
    from: "succinate",
    to: "fumarate",
    enzymes: ["succinate dehydrogenase (Complex II)"],
    cofactors: ["FADH2"],
    carbonCount: 4,
    direction: "reversible",
    detail: "Succinate dehydrogenase oxidises succinate to fumarate, transferring electrons to FAD (not NAD+) because the redox potential is insufficient to reduce NAD+. This enzyme is unique in being both a citric-acid-cycle enzyme and respiratory Complex II; its FADH2 feeds electrons directly to the electron transport chain.",
  },
  {
    n: 7,
    name: "Hydration of fumarate",
    reaction: "Fumarate + H2O -> L-Malate",
    from: "fumarate",
    to: "malate",
    enzymes: ["fumarase (fumarate hydratase)"],
    cofactors: [],
    carbonCount: 4,
    direction: "reversible",
    detail: "Fumarase adds water across the double bond of fumarate to produce L-malate, a stereospecific hydration.",
  },
  {
    n: 8,
    name: "Regeneration of oxaloacetate",
    reaction: "L-Malate + NAD+ -> Oxaloacetate + NADH",
    from: "malate",
    to: "oxaloacetate",
    enzymes: ["malate dehydrogenase"],
    cofactors: ["NADH"],
    carbonCount: 4,
    direction: "reversible",
    detail: "Malate dehydrogenase oxidises malate to oxaloacetate, reducing NAD+ to NADH. Oxaloacetate is thereby regenerated so the cycle can accept another acetyl-CoA, completing the loop.",
  },
];

/* Pyruvate -> acetyl-CoA: the link reaction that feeds the cycle. Modelled
   separately because it is NOT one of the eight cycle reactions. */
var ENTRY = {
  name: "Link reaction (pyruvate -> acetyl-CoA)",
  reaction: "Pyruvate + CoA-SH + NAD+ -> Acetyl-CoA + CO2 + NADH",
  enzymes: ["pyruvate dehydrogenase complex"],
  cofactors: ["NADH", "CO2"],
  detail:
    "Pyruvate from glycolysis is oxidatively decarboxylated by the pyruvate dehydrogenase complex to acetyl-CoA. This links glycolysis to the cycle and is not itself one of the eight citric-acid-cycle reactions. Acetyl-CoA then enters the cycle at stage 1.",
};

var KREBS_MODEL = {
  id: "krebs",
  curated: true,
  title: "Citric acid (Krebs) cycle",
  source: "curated:biochemistry (Berg/Tymoczko/Stryer; Lodish; Reactome R-HSA-71403; NCBI Bookshelf)",
  stageCount: 8,
  stages: STAGES,
  entry: ENTRY,
  /* reactants consumed per turn of the eight reactions */
  reactants: ["acetyl-CoA", "H2O", "NAD+", "FAD", "GDP", "Pi"],
  /* carbon/energy products per turn */
  products: ["CoA-SH", "CO2", "NADH", "FADH2", "GTP", "oxaloacetate (regenerated)"],
  cofactors: ["NADH", "FADH2", "GTP"],
  /* the per-turn energy/cofactor balance, stated explicitly for teaching */
  balance: {
    perAcetylCoA: { NADH: 3, FADH2: 1, GTP: 1, CO2: 2 },
    note: "One acetyl-CoA entering the eight reactions yields 3 NADH, 1 FADH2, 1 GTP (ATP equivalent) and releases 2 CO2. The cycle's organic intermediates are conserved (OAA is regenerated).",
  },
  keyFacts: [
    "Two carbons enter as acetyl-CoA and two carbons leave as CO2 per turn.",
    "Oxaloacetate is regenerated (stage 8), so the cycle is catalytic.",
    "Succinyl-CoA -> succinate (stage 5) produces GTP by substrate-level phosphorylation.",
    "Succinate dehydrogenase (stage 6) is also respiratory Complex II and yields FADH2.",
    "Three irreversible steps act as regulatory checkpoints: citrate synthase, isocitrate dehydrogenase, alpha-ketoglutarate dehydrogenase.",
  ],
  organism:
    "Occurs in the mitochondrial matrix of eukaryotes and in the cytosol of bacteria/archaea; the enzyme set is broadly conserved.",
  uncertainty: [
    "GTP vs ATP at stage 5 depends on tissue/isoform; in many tissues GTP is rapidly converted to ATP by nucleoside diphosphate kinase.",
    "Enzyme names vary between sources (e.g. aconitase vs aconitate hydratase; succinyl-CoA synthetase vs succinate thiokinase); synonymous names are listed.",
    "Some texts fold the link reaction into the cycle diagram; here it is kept separate because it is not one of the eight cycle reactions.",
  ],
  notes: [
    "The cycle is named for Hans Krebs; it is also called the tricarboxylic acid (TCA) or citric acid cycle.",
    "Intermediates are also drawn on for biosynthesis (amphibolic role).",
  ],
};

/* Structural verification of the curated model (P4-002 support). Returns
   { ok, errors }. Used by tests and by the viewer before rendering so a data
   edit can never silently corrupt the taught sequence. */
function verifyModel(model) {
  var m = model || KREBS_MODEL;
  var errors = [];
  if (!Array.isArray(m.stages) || m.stages.length !== 8) errors.push("cycle must have exactly 8 stages");
  (m.stages || []).forEach(function (s, i) {
    if (s.n !== i + 1) errors.push("stage " + (i + 1) + " has wrong index");
    if (!s.enzymes || !s.enzymes.length) errors.push("stage " + s.n + " lacks an enzyme");
    if (!s.from || !s.to) errors.push("stage " + s.n + " lacks from/to intermediates");
  });
  /* chain continuity: each stage's `to` must be the next stage's `from`, and the
     last must regenerate the first's `from` (OAA) */
  for (var i = 0; i < 8; i++) {
    var cur = m.stages[i];
    var next = m.stages[(i + 1) % 8];
    if (cur.to !== next.from) errors.push("stage " + cur.n + " -> " + next.n + " breaks: " + cur.to + " != " + next.from);
  }
  if (m.stages[0].from !== "oxaloacetate") errors.push("cycle must begin from oxaloacetate");
  if (m.stages[7].to !== "oxaloacetate") errors.push("cycle must regenerate oxaloacetate at stage 8");
  if (!m.entry || !/pyruvate/i.test(m.entry.reaction)) errors.push("entry (link) reaction must start from pyruvate");
  /* cofactor balance */
  var b = (m.balance && m.balance.perAcetylCoA) || {};
  if (b.NADH !== 3 || b.FADH2 !== 1 || b.GTP !== 1 || b.CO2 !== 2) errors.push("cofactor balance must be 3 NADH / 1 FADH2 / 1 GTP / 2 CO2");
  return { ok: errors.length === 0, errors: errors };
}

export { KREBS_MODEL, STAGES, ENTRY, verifyModel };
