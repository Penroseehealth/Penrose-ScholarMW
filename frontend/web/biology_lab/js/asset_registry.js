/* Scientific Asset Registry (P1-001).
 *
 * A reusable registry + search interface for scientific assets. It is the single
 * place the visualisation engine asks "give me a validated, licensed asset for
 * this concept". Scientific provenance is stored as structured data (P2-002):
 * every record carries its source, licence, and validation status, and visual
 * styling can never change those fields.
 *
 * Pure JS: no THREE / no DOM. The registry itself does no network I/O; provider
 * adapters (providers.js) fetch and map records into this schema, and the
 * registry validates and stores them.
 *
 * Canonical asset schema (fields marked * are required):
 *   id*              stable registry id (string)
 *   scientificName*  canonical scientific name / concept
 *   synonyms         array of alternative names
 *   category         e.g. 'pathway', 'molecule', 'anatomy', 'cell'
 *   topic            subject area, e.g. 'metabolism'
 *   provider*        source platform (e.g. 'Reactome')
 *   sourceUrl        canonical page/URL for the asset
 *   sourceId         provider-native identifier (e.g. R-HSA-71403)
 *   retrievedAt      ISO timestamp when the record was fetched
 *   format           'svg' | 'png' | 'glb' | 'json' | 'pdb' | ...
 *   licence          human licence string (e.g. 'CC0')
 *   licenceId        normalised licence id (see licence.js)
 *   attribution      required attribution text
 *   redistribution   'open' | 'attribution' | 'restricted' | 'unverified'
 *   validation       'verified' | 'unverified' | 'review'
 *   preview          thumbnail/preview URL
 *   renderer         'svg' | 'three' | 'molstar' | 'none'
 */
"use strict";

import { evaluateLicence, provenanceLine } from "./licence.js";

var REQUIRED = ["id", "scientificName", "provider"];

var KNOWN_RENDERERS = ["svg", "three", "molstar", "none"];
var KNOWN_FORMATS = ["svg", "png", "jpg", "jpeg", "glb", "gltf", "json", "pdb", "cif", "mol", "sdf", "webp"];

function isStr(v) { return typeof v === "string" && v.trim().length > 0; }

/* Validate a raw record against the schema. Returns { ok, errors, record }.
   The record is normalised: arrays default to [], string fields to '' and the
   licence gate is applied. Validation never throws. */
function validateRecord(raw) {
  var errors = [];
  var r = raw || {};
  for (var i = 0; i < REQUIRED.length; i++) {
    var f = REQUIRED[i];
    if (!isStr(r[f])) errors.push("missing required field: " + f);
  }
  var record = {
    id: isStr(r.id) ? String(r.id).trim() : "",
    scientificName: isStr(r.scientificName) ? String(r.scientificName).trim() : "",
    synonyms: Array.isArray(r.synonyms) ? r.synonyms.slice() : [],
    category: isStr(r.category) ? String(r.category).trim() : "",
    topic: isStr(r.topic) ? String(r.topic).trim() : "",
    provider: isStr(r.provider) ? String(r.provider).trim() : "",
    sourceUrl: isStr(r.sourceUrl) ? String(r.sourceUrl).trim() : "",
    sourceId: isStr(r.sourceId) ? String(r.sourceId).trim() : "",
    retrievedAt: isStr(r.retrievedAt) ? String(r.retrievedAt) : "",
    format: isStr(r.format) ? String(r.format).toLowerCase().trim() : "",
    licence: isStr(r.licence) ? String(r.licence).trim() : "",
    licenceId: r.licenceId || null,
    attribution: isStr(r.attribution) ? String(r.attribution).trim() : "",
    validation: isStr(r.validation) ? String(r.validation).trim() : "unverified",
    preview: isStr(r.preview) ? String(r.preview).trim() : "",
    renderer: isStr(r.renderer) ? String(r.renderer).toLowerCase().trim() : "svg",
    needsReview: r.needsReview === true,
    payload: r.payload || null,
  };
  if (record.format && KNOWN_FORMATS.indexOf(record.format) < 0) {
    /* unknown formats are allowed but flagged so the UI can decide */
    record.formatUnknown = true;
  }
  if (KNOWN_RENDERERS.indexOf(record.renderer) < 0) {
    errors.push("unknown renderer: " + record.renderer);
  }
  var ev = evaluateLicence(record);
  record.redistribution = ev.class;
  record.licenceLabel = ev.label;
  record.redistributable = ev.redistributable;
  record.provenance = provenanceLine(record);
  record.licenceReason = ev.reason;
  return { ok: errors.length === 0, errors: errors, record: record };
}

/* Build a registry from seed records. Records that fail validation are kept but
   marked invalid, so a broken provider record never silently disappears. */
function createAssetRegistry(seed) {
  var records = [];
  var byId = {};
  var rejected = [];

  function add(raw, opts) {
    var v = validateRecord(raw);
    if (!v.ok && !(opts && opts.keepInvalid)) {
      rejected.push({ raw: raw, errors: v.errors });
      return { ok: false, errors: v.errors, record: null };
    }
    var rec = v.record;
    if (byId[rec.id]) {
      /* last write wins but note the collision */
      var idx = records.indexOf(byId[rec.id]);
      if (idx >= 0) records.splice(idx, 1);
      rejected.push({ raw: raw, errors: ["duplicate id replaced: " + rec.id] });
    }
    records.push(rec);
    byId[rec.id] = rec;
    return { ok: true, errors: v.errors, record: rec };
  }

  function addAll(list, opts) {
    var out = { added: 0, failed: 0 };
    (list || []).forEach(function (r) {
      var res = add(r, opts);
      if (res.ok) out.added++; else out.failed++;
    });
    return out;
  }

  function get(id) { return byId[id] || null; }

  function all() { return records.slice(); }

  function lower(s) { return String(s == null ? "" : s).toLowerCase(); }

  /* Search by free text across name/synonyms/category/topic/provider, with
     optional filters. Mirrors the keyword-scoring style used by the existing
     model catalogue so behaviour is familiar. */
  function search(query, options) {
    var o = options || {};
    var q = lower(query).trim();
    var terms = q ? q.split(/\s+/) : [];
    var out = [];
    for (var i = 0; i < records.length; i++) {
      var r = records[i];
      if (o.category && r.category !== o.category) continue;
      if (o.topic && r.topic !== o.topic) continue;
      if (o.provider && r.provider !== o.provider) continue;
      if (o.renderer && r.renderer !== o.renderer) continue;
      if (o.redistributableOnly && !r.redistributable) continue;
      if (o.validation && r.validation !== o.validation) continue;
      var score = 0;
      if (terms.length) {
        var name = lower(r.scientificName);
        var syn = lower(r.synonyms.join(" "));
        var hay = name + " " + syn + " " + lower(r.category) + " " + lower(r.topic) + " " + lower(r.provider);
        for (var t = 0; t < terms.length; t++) {
          var term = terms[t];
          if (hay.indexOf(term) < 0) { score = 0; break; }
          if (name.indexOf(term) >= 0) score += 8;
          if (syn.indexOf(term) >= 0) score += 5;
          if (lower(r.topic).indexOf(term) >= 0) score += 3;
          if (lower(r.category).indexOf(term) >= 0) score += 3;
          score += 1;
        }
      } else score = 1;
      if (score > 0) out.push({ record: r, score: score });
    }
    out.sort(function (a, b) { return b.score - a.score || a.record.scientificName.localeCompare(b.record.scientificName); });
    var hits = out.map(function (x) { return x.record; });
    if (o.limit) hits = hits.slice(0, o.limit);
    return hits;
  }

  function facets() {
    var cats = {}, topics = {}, providers = {}, rends = {};
    records.forEach(function (r) {
      if (r.category) cats[r.category] = (cats[r.category] || 0) + 1;
      if (r.topic) topics[r.topic] = (topics[r.topic] || 0) + 1;
      if (r.provider) providers[r.provider] = (providers[r.provider] || 0) + 1;
      if (r.renderer) rends[r.renderer] = (rends[r.renderer] || 0) + 1;
    });
    return { categories: cats, topics: topics, providers: providers, renderers: rends };
  }

  /* Assets safe to package for redistribution (open, or attribution provided). */
  function redistributable() { return records.filter(function (r) { return r.redistributable; }); }

  /* Assets that need a human before they can be shipped. */
  function needsReview() {
    return records.filter(function (r) { return r.redistribution === "unverified" || r.validation === "review"; });
  }

  function stats() {
    var ev = {};
    records.forEach(function (r) { ev[r.redistribution] = (ev[r.redistribution] || 0) + 1; });
    return { count: records.length, byRedistribution: ev, rejected: rejected.length, facets: facets() };
  }

  function upsertFromProvider(providerRecords) {
    return addAll(providerRecords, { keepInvalid: false });
  }

  if (seed) addAll(seed, { keepInvalid: true });

  return {
    add: add,
    addAll: addAll,
    upsertFromProvider: upsertFromProvider,
    get: get,
    all: all,
    search: search,
    facets: facets,
    redistributable: redistributable,
    needsReview: needsReview,
    stats: stats,
    rejected: function () { return rejected.slice(); },
  };
}

export { createAssetRegistry, validateRecord, REQUIRED, KNOWN_RENDERERS, KNOWN_FORMATS };
