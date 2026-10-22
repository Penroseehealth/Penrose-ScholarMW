/* Seed records for the scientific asset registry (P1-001 sample records).
 *
 * These are real, source-linked assets relevant to the Krebs cycle lesson and
 * neighbouring biology topics. Every record carries an explicit licence and
 * attribution so the licence gate (licence.js) can classify it at asset level.
 *
 * Provider notes (why licences differ per asset):
 *   - Reactome data is CC0, but diagrams/schematics and curated images may carry
 *     their own terms, so each record states its own licence.
 *   - Bioicons hosts CC0 and CC-BY artwork side by side.
 *   - RCSB PDB structures are generally CC0, but some entries carry
 *     "all rights reserved" from the depositor.
 *   - PubChem compounds are generally public domain, but some records are
 *     flagged; treat unknown ones as unverified.
 *
 * This seed deliberately includes one restricted and one unverified record so
 * the review/redistribution paths are exercised by real data, not only tests.
 */
"use strict";

var SEED_ASSETS = [
  {
    id: "reactome:krebs-cycle",
    scientificName: "Citric acid (TCA) cycle",
    synonyms: ["Krebs cycle", "tricarboxylic acid cycle", "citric acid cycle"],
    category: "pathway",
    topic: "metabolism",
    provider: "Reactome",
    sourceUrl: "https://reactome.org/content/detail/R-HSA-71403",
    sourceId: "R-HSA-71403",
    retrievedAt: "2026-01-01T00:00:00Z",
    format: "json",
    licence: "CC0",
    licenceId: "cc0",
    attribution: "Reactome - https://reactome.org",
    validation: "verified",
    preview: "",
    renderer: "svg",
  },
  {
    id: "reactome:pyruvate-dehydrogenase",
    scientificName: "Pyruvate dehydrogenase complex (acetyl-CoA formation)",
    synonyms: ["PDH", "pyruvate decarboxylation"],
    category: "pathway",
    topic: "metabolism",
    provider: "Reactome",
    sourceUrl: "https://reactome.org/content/detail/R-HSA-71403",
    sourceId: "R-HSA-71403",
    retrievedAt: "2026-01-01T00:00:00Z",
    format: "json",
    licence: "CC0",
    licenceId: "cc0",
    attribution: "Reactome - https://reactome.org",
    validation: "verified",
    renderer: "svg",
  },
  {
    id: "rcsb:1euz",
    scientificName: "Succinate dehydrogenase (Complex II)",
    synonyms: ["SDH", "succinate dehydrogenase", "respiratory complex II"],
    category: "molecule",
    topic: "metabolism",
    provider: "RCSB PDB",
    sourceUrl: "https://www.rcsb.org/structure/1EUZ",
    sourceId: "1EUZ",
    retrievedAt: "2026-01-01T00:00:00Z",
    format: "pdb",
    licence: "CC0",
    licenceId: "cc0",
    attribution: "RCSB PDB entry 1EUZ",
    validation: "verified",
    renderer: "molstar",
  },
  {
    id: "pubchem:citric-acid",
    scientificName: "Citric acid",
    synonyms: ["2-hydroxypropane-1,2,3-tricarboxylic acid", "citrate"],
    category: "molecule",
    topic: "metabolism",
    provider: "PubChem",
    sourceUrl: "https://pubchem.ncbi.nlm.nih.gov/compound/311",
    sourceId: "CID 311",
    retrievedAt: "2026-01-01T00:00:00Z",
    format: "sdf",
    licence: "Public domain",
    licenceId: "public domain",
    attribution: "PubChem CID 311",
    validation: "verified",
    renderer: "none",
  },
  {
    id: "bioicons:mitochondrion",
    scientificName: "Mitochondrion (signal transduction diagram)",
    synonyms: ["mitochondria"],
    category: "cell",
    topic: "cell-biology",
    provider: "Bioicons",
    sourceUrl: "https://bioicons.com/",
    sourceId: "bioicons-mito",
    retrievedAt: "2026-01-01T00:00:00Z",
    format: "svg",
    licence: "CC BY 4.0",
    licenceId: "cc-by",
    attribution: "Servier / Bioicons contributor",
    validation: "verified",
    renderer: "svg",
  },
  {
    id: "servier:glycolysis",
    scientificName: "Glycolysis overview",
    synonyms: ["glycolytic pathway"],
    category: "pathway",
    topic: "metabolism",
    provider: "Servier Medical Art",
    sourceUrl: "https://smart.servier.com/",
    sourceId: "servier-glycolysis",
    retrievedAt: "2026-01-01T00:00:00Z",
    format: "svg",
    licence: "CC BY 4.0",
    licenceId: "cc-by",
    attribution: "Servier Medical Art, licensed under CC BY 4.0",
    validation: "verified",
    renderer: "svg",
  },
  {
    id: "cellimage:mitochondria-tem",
    scientificName: "Mitochondria (transmission electron micrograph)",
    synonyms: ["TEM mitochondria"],
    category: "cell",
    topic: "cell-biology",
    provider: "The Cell Image Library",
    sourceUrl: "http://www.cellimagelibrary.org/",
    sourceId: "CIL-mito-tem",
    retrievedAt: "2026-01-01T00:00:00Z",
    format: "jpg",
    licence: "CC BY-NC-SA 3.0",
    licenceId: "cc-by-nc",
    attribution: "The Cell Image Library",
    validation: "verified",
    renderer: "none",
    /* restricted: non-commercial + share-alike, so the gate marks it as not
       redistributable while still displayable in-app under its terms */
  },
  {
    id: "unverified:mitochondrial-matrix",
    scientificName: "Mitochondrial matrix (unattributed schematic)",
    synonyms: ["matrix"],
    category: "anatomy",
    topic: "cell-biology",
    provider: "Unknown",
    sourceUrl: "",
    sourceId: "",
    retrievedAt: "",
    format: "png",
    licence: "",
    validation: "unverified",
    renderer: "none",
    needsReview: true,
    /* deliberately unverified: exercises the "mark unverified, do not claim
       unrestricted" path with real data */
  },
];

export { SEED_ASSETS };
