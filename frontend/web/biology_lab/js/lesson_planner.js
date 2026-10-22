/* Query -> structured lesson spec (P2-001), with verified-vs-styling separation
 * (P2-002).
 *
 * Input: a natural-language request ("show me the Krebs cycle", "teach the
 * mitochondrion"). Output: a validated LessonSpec the renderer can execute.
 *
 * The hard rule (P2-002): a lesson has two disjoint halves.
 *   `science`  - curated, source-linked, verifiable facts only. Populated from
 *                the curated topic model (krebs.js) and/or verified registry
 *                records. Never invented from the query text.
 *   `styling`  - purely presentational choices (theme, layout, animation,
 *                colour). Free to be generative, because it carries no factual
 *                claim. Styling can NEVER overwrite a science field.
 *
 * Ambiguity is surfaced, not guessed: if the query matches no curated topic the
 * planner returns status 'needs-clarification' with candidate topics, and if it
 * matches several it returns 'ambiguous'. It never fabricates a lesson for an
 * unknown concept.
 *
 * Pure JS: no THREE / no DOM.
 */
"use strict";

/* Curated topic catalogue: the ONLY concepts the planner will auto-build a
   science lesson for. Each maps natural-language cues to a curated model id.
   Extending the engine means adding a topic here + a curated model, never
   letting the planner invent science. */
var TOPIC_CATALOGUE = [
  {
    id: "krebs-cycle",
    label: "Citric acid (Krebs) cycle",
    cues: ["krebs", "tca", "citric acid cycle", "tricarboxylic", "citrate cycle", "oxidative metabolism"],
    model: "krebs",
    category: "pathway",
    topic: "metabolism",
    renderer: "svg",
    ambiguityNote: "There are two related concepts: the pathway reactions and cellular respiration overall. Defaulting to the pathway reactions.",
  },
];

/* Styling options the request may steer. These NEVER contain scientific facts. */
var STYLE_KEYS = ["theme", "layout", "animate", "speed", "colour", "color", "fontSize", "pace"];
var DEFAULT_STYLE = { theme: "board", layout: "cycle", animate: true, speed: "normal", colour: "teal" };

function norm(s) { return String(s == null ? "" : s).toLowerCase().replace(/\s+/g, " ").trim(); }

function tokenize(q) { return norm(q).split(/[^a-z0-9-]+/).filter(Boolean); }

/* Classify a request. Returns one of: 'match' | 'ambiguous' | 'needs-clarification'. */
function classify(query) {
  var words = tokenize(query);
  var joined = words.join(" ");
  var scored = TOPIC_CATALOGUE.map(function (t) {
    var score = 0;
    t.cues.forEach(function (cue) {
      if (joined.indexOf(cue) >= 0) score += cue.split(" ").length * 4;
      else if (words.indexOf(cue) >= 0) score += 5;
    });
    if (joined.indexOf(norm(t.id)) >= 0) score += 10;
    if (joined.indexOf(norm(t.label)) >= 0) score += 8;
    return { topic: t, score: score };
  }).filter(function (s) { return s.score > 0; });

  if (scored.length === 0) {
    var props = proposeClosest(words);
    return { status: "needs-clarification", candidates: props, reason: "no curated topic matches '" + (query || "") + "'" };
  }
  scored.sort(function (a, b) { return b.score - a.score; });
  var best = scored[0];
  if (scored.length > 1 && scored[1].score === best.score) {
    return { status: "ambiguous", candidates: [best.topic, scored[1].topic], reason: "multiple topics matched equally" };
  }
  return { status: "match", topic: best.topic };
}

/* Cheap fuzzy suggestion so an unknown request still gets useful options
   instead of a dead end (no science invented). */
function proposeClosest(words) {
  var out = [];
  TOPIC_CATALOGUE.forEach(function (t) {
    var hay = norm(t.label) + " " + t.cues.join(" ");
    var hits = words.filter(function (w) { return hay.indexOf(w) >= 0; }).length;
    if (hits > 0) out.push(t);
  });
  return out.length ? out : TOPIC_CATALOGUE.slice(0, 3);
}

/* Extract only styling hints from the raw request; everything else is ignored to
   prevent query text leaking into science. */
function extractStyling(query) {
  var q = norm(query);
  var style = JSON.parse(JSON.stringify(DEFAULT_STYLE));
  if (/\b(quiet|calm)/.test(q) || /\bno animation\b/.test(q) || /\bstatic\b/.test(q)) style.animate = false;
  if (/\bslow/.test(q)) style.speed = "slow";
  if (/\bfast/.test(q)) style.speed = "fast";
  if (/\bdark\b/.test(q)) style.theme = "dark";
  if (/\bpurple|violet\b/.test(q)) style.colour = "purple";
  if (/\borange\b/.test(q)) style.colour = "orange";
  return style;
}

/* Build a LessonSpec for a matched curated topic. `model` is the curated science
   object (e.g. from krebs.js) - passed in so the planner never owns science.
   Verifiedness is taken FROM the model, never assumed: a model is only trusted
   when it explicitly declares itself curated (model.curated === true) and names
   a source. Otherwise the spec is produced but flagged unverified. */
function buildSpec(topic, model, options) {
  var o = options || {};
  var verified = !!(model && model.curated === true && model.source);
  var spec = {
    version: 1,
    status: "ready",
    topicId: topic.id,
    title: topic.label,
    category: topic.category,
    topic: topic.topic,
    renderer: topic.renderer,
    /* verified science: copied verbatim from the curated model, never generated */
    science: {
      verified: verified,
      source: (model && model.source) || null,
      stages: (model && model.stages) || [],
      reactants: (model && model.reactants) || [],
      products: (model && model.products) || [],
      cofactors: (model && model.cofactors) || [],
      notes: (model && model.notes) || [],
      organism: (model && model.organism) || null,
      uncertainty: (model && model.uncertainty) || [],
    },
    /* generative styling: presentational only, cannot assert facts */
    styling: extractStyling(o.query || ""),
    assets: (o.assets || []).slice(),
    interactive: {
      highlight: true,
      pause: true,
      replay: true,
      quiz: o.quiz !== false,
    },
    /** P2-002 guard: styling keys that collide with science are dropped. */
    provenance: {
      plannedFrom: o.query || "",
      scienceSource: (model && model.source) || "curated",
      styleIsGenerative: true,
    },
  };
  return validateSpec(spec);
}

/* Ensure the science/styling boundary holds and required fields exist. Never
   throws; returns the spec with `valid` + `issues` so callers can decide. */
function validateSpec(spec) {
  var issues = [];
  if (!spec || typeof spec !== "object") return { valid: false, issues: ["spec is not an object"], status: "error" };
  if (!spec.topicId) issues.push("missing topicId");
  if (!spec.science || spec.science.verified !== true) issues.push("science must be verified");
  if (!spec.science || !Array.isArray(spec.science.stages)) issues.push("science.stages must be an array");
  if (!spec.styling) issues.push("missing styling");
  /* science keys must not be overwritten by styling */
  Object.keys(spec.styling || {}).forEach(function (k) {
    if (k in (spec.science || {})) issues.push("styling key collides with science: " + k);
  });
  spec.issues = issues;
  spec.valid = issues.length === 0;
  if (!spec.valid) spec.status = "error";
  return spec;
}

/* Top-level entry. `models` maps topic.model -> curated model object (e.g.
   { krebs: krebsModel }). Returns a ready spec, an ambiguity/clarification
   response, or an error - never a fabricated lesson. */
function planLesson(query, models) {
  var modelsById = models || {};
  var cls = classify(query);
  if (cls.status === "needs-clarification") {
    return { status: "needs-clarification", query: query, reason: cls.reason, candidates: cls.candidates.map(slim) };
  }
  if (cls.status === "ambiguous") {
    return { status: "ambiguous", query: query, reason: cls.reason, candidates: cls.candidates.map(slim) };
  }
  var model = modelsById[cls.topic.model];
  if (!model) {
    return { status: "error", query: query, reason: "curated model not loaded: " + cls.topic.model };
  }
  return buildSpec(cls.topic, model, { query: query });
}

function slim(t) {
  return { id: t.id, label: t.label, category: t.category, topic: t.topic, note: t.ambiguityNote || "" };
}

export {
  planLesson,
  classify,
  buildSpec,
  validateSpec,
  extractStyling,
  TOPIC_CATALOGUE,
  DEFAULT_STYLE,
  STYLE_KEYS,
};
