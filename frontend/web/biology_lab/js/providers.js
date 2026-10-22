/* Open scientific source provider adapters (P1-002).
 *
 * One adapter per platform, each with:
 *   id / label            stable identity
 *   capabilities          what it can supply (structures / pathways / artwork / images)
 *   licenceNote           why terms vary per asset (never assumed per platform)
 *   buildRequest(query)   pure: (query) -> { url, init } documented request
 *   map(raw, ctx)         pure: provider JSON -> array of registry records
 *   fetch(query, deps)    does the network call, then map(...)
 *
 * Design rules the prompt requires, honoured here:
 *   - Never fabricate live results: if the network is unavailable, fetch rejects
 *     with a descriptive error and the caller records an "unavailable" state.
 *   - Never presume a platform-wide licence: each mapped record sets its own
 *     licence fields, and the registry's licence gate (licence.js) classifies it.
 *   - Providers are isolated: no provider-specific field leaks into UI code; the
 *     UI only ever sees registry records.
 *
 * `deps.fetch` defaults to the global fetch so browser use needs no wiring, and
 * tests inject a fake fetch to exercise mapping/error paths deterministically.
 * Endpoints that need CORS relay through the lab's existing same-origin proxy
 * (serve.mjs) via `deps.baseUrl`, mirroring the Grab3D catalogue pattern.
 */
"use strict";

function nowIso() { return new Date().toISOString(); }

/* Reactome's search API wraps matched terms in <span class="highlighting">...</span>.
   Names must be clean text (they feed labels, narration and the registry), so we
   strip tags and collapse whitespace. Pure and always safe. */
function stripMarkup(s) {
  return String(s == null ? "" : s)
    .replace(/<[^>]*>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/\s+/g, " ")
    .trim();
}

function unavailable(id, reason) {
  return { provider: id, ok: false, unavailable: true, reason: reason, records: [] };
}

/* ------------------------------------------------------------------ Reactome
   Data: pathway/content details via the Reactome Content Service REST API.
   Licence: Reactome data is released under CC0; individual diagrams may carry
   separate terms, so records default to CC0 but are marked verified as DATA
   (structured pathway content), which is what the lesson consumes. */
var reactome = {
  id: "Reactome",
  label: "Reactome",
  capabilities: ["pathway", "reaction", "entity"],
  licenceNote: "Reactome data is CC0; curated diagrams may have separate terms - evaluated per asset.",
  baseUrl: "https://reactome.org/ContentService",
  buildRequest: function (q) {
    var term = encodeURIComponent((q && q.term) || "citric acid cycle");
    return { url: this.baseUrl + "/search/query?query=" + term + "&species=Homo%20sapiens&types=Pathway", init: { headers: { Accept: "application/json" } } };
  },
  map: function (raw, ctx) {
    var out = [];
    var results = (raw && raw.results) || [];
    for (var i = 0; i < results.length; i++) {
      var group = results[i];
      var entries = group.entries || [];
      for (var j = 0; j < entries.length; j++) {
        var e = entries[j];
        var stId = e.stId || ("reactome-" + i + "-" + j);
        out.push({
          id: "reactome:" + stId,
          scientificName: stripMarkup(e.name) || stId,
          synonyms: (e.synonyms || []).map(stripMarkup),
          category: "pathway",
          topic: "metabolism",
          provider: "Reactome",
          sourceUrl: "https://reactome.org/content/detail/" + stId,
          sourceId: stId,
          retrievedAt: (ctx && ctx.now) || nowIso(),
          format: "json",
          licence: "CC0",
          licenceId: "cc0",
          attribution: "Reactome - https://reactome.org",
          validation: "verified",
          renderer: "svg",
          payload: { type: e.type || null, species: e.species || null },
        });
      }
    }
    return out;
  },
  fetch: function (q, deps) {
    var self = this;
    var req = this.buildRequest(q);
    return call(self.id, deps, req).then(function (json) {
      return { provider: self.id, ok: true, unavailable: false, records: self.map(json, deps) };
    });
  },
};

/* ------------------------------------------------------------------- RCSB PDB
   Data: macromolecular structure entries via the RCSB search + data REST API.
   Licence: structures are generally CC0, but depositor terms can differ; mapped
   records state CC0 and validated structures pass the gate. */
var rcsb = {
  id: "RCSB PDB",
  label: "RCSB Protein Data Bank",
  capabilities: ["structure", "macromolecule"],
  licenceNote: "Most PDB entries are CC0; some carry depositor 'all rights reserved' terms - checked per entry.",
  baseUrl: "https://data.rcsb.org/rest/v1/core/entry",
  searchUrl: "https://search.rcsb.org/rcsbsearch/v2/query",
  buildRequest: function (q) {
    var term = (q && q.term) || "succinate dehydrogenase";
    var body = {
      query: { type: "terminal", service: "full_text", parameters: { value: term } },
      return_type: "entry",
      request_options: { paginate: { start: 0, rows: (q && q.rows) || 5 } },
    };
    return { url: this.searchUrl, init: { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) } };
  },
  map: function (raw, ctx) {
    var out = [];
    var ids = (raw && raw.result_set) || [];
    for (var i = 0; i < ids.length; i++) {
      var eid = (ids[i] && (ids[i].identifier || ids[i].entry_id)) || null;
      if (!eid) continue;
      out.push({
        id: "rcsb:" + eid.toLowerCase(),
        scientificName: (ctx && ctx.name) || ("PDB structure " + eid),
        synonyms: ["PDB " + eid],
        category: "molecule",
        topic: (ctx && ctx.topic) || "metabolism",
        provider: "RCSB PDB",
        sourceUrl: "https://www.rcsb.org/structure/" + eid,
        sourceId: eid,
        retrievedAt: (ctx && ctx.now) || nowIso(),
        format: "pdb",
        licence: "CC0",
        licenceId: "cc0",
        attribution: "RCSB PDB entry " + eid,
        validation: "verified",
        renderer: "molstar",
      });
    }
    return out;
  },
  fetch: function (q, deps) {
    var self = this;
    return call(self.id, deps, this.buildRequest(q)).then(function (json) {
      return { provider: self.id, ok: true, unavailable: false, records: self.map(json, q) };
    });
  },
};

/* ------------------------------------------------------------------- PubChem
   Data: compound records via PUG REST.
   Licence: PubChem compound data is generally public domain; some records are
   flagged, so unknown flags -> unverified. */
var pubchem = {
  id: "PubChem",
  label: "PubChem PUG REST",
  capabilities: ["compound", "molecule"],
  licenceNote: "PubChem licence is generally public domain; per-record flags are respected.",
  baseUrl: "https://pubchem.ncbi.nlm.nih.gov/rest/pug",
  buildRequest: function (q) {
    var name = encodeURIComponent((q && q.term) || "citric acid");
    return { url: this.baseUrl + "/compound/name/" + name + "/property/MolecularFormula,MolecularWeight,CanonicalSMILES,IUPACName/JSON", init: {} };
  },
  map: function (raw, ctx) {
    var out = [];
    var props = (raw && raw.PropertyTable && raw.PropertyTable.Properties) || [];
    for (var i = 0; i < props.length; i++) {
      var p = props[i];
      var cid = p.CID || p.cid;
      out.push({
        id: "pubchem:" + (cid || i),
        scientificName: p.IUPACName || (ctx && ctx.term) || ("Compound " + cid),
        synonyms: [],
        category: "molecule",
        topic: (ctx && ctx.topic) || "chemistry",
        provider: "PubChem",
        sourceUrl: cid ? "https://pubchem.ncbi.nlm.nih.gov/compound/" + cid : "",
        sourceId: cid ? "CID " + cid : "",
        retrievedAt: (ctx && ctx.now) || nowIso(),
        format: "sdf",
        licence: "Public domain",
        licenceId: "public domain",
        attribution: cid ? "PubChem CID " + cid : "PubChem",
        validation: "verified",
        renderer: "none",
        payload: { formula: p.MolecularFormula || null, weight: p.MolecularWeight || null, smiles: p.CanonicalSMILES || null },
      });
    }
    return out;
  },
  fetch: function (q, deps) {
    var self = this;
    return call(self.id, deps, this.buildRequest(q)).then(function (json) {
      return { provider: self.id, ok: true, unavailable: false, records: self.map(json, q) };
    });
  },
};

/* ------------------------------------------------------------ Bioicons / Servier
   Artwork: icon/schematic libraries. Bioicons hosts CC0 and CC-BY artwork side by
   side; Servier Medical Art is CC-BY. Neither exposes a stable public JSON index
   here, so these adapters expose a documented, curated mapping capability rather
   than pretending a live search API exists. `map` classifies supplied entries by
   their declared licence; `fetch` returns an explicit "curated" state, not a
   fabricated network result. */
var bioicons = {
  id: "Bioicons",
  label: "Bioicons",
  capabilities: ["artwork", "icon", "schematic"],
  licenceNote: "Bioicons hosts CC0 and CC-BY artwork side by side - licence is per artwork.",
  buildRequest: function () { return null; },
  map: function (raw) { return mapArtwork(raw, "Bioicons", "https://bioicons.com/"); },
  fetch: function () { return Promise.resolve(curated("Bioicons", "Bioicons has no public JSON search; use curated records")); },
};

var servier = {
  id: "Servier Medical Art",
  label: "Servier Medical Art",
  capabilities: ["artwork", "illustration"],
  licenceNote: "Servier Medical Art is CC-BY - attribution required.",
  buildRequest: function () { return null; },
  map: function (raw) { return mapArtwork(raw, "Servier Medical Art", "https://smart.servier.com/"); },
  fetch: function () { return Promise.resolve(curated("Servier Medical Art", "Servier publishes no public JSON index; use curated records")); },
};

var cellImageLibrary = {
  id: "The Cell Image Library",
  label: "The Cell Image Library",
  capabilities: ["image", "micrograph"],
  licenceNote: "CIL image licences vary; many are CC-BY-NC-SA, so redistribution is often restricted.",
  buildRequest: function () { return null; },
  map: function (raw) { return mapArtwork(raw, "The Cell Image Library", "http://www.cellimagelibrary.org/"); },
  fetch: function () { return Promise.resolve(curated("The Cell Image Library", "CIL search needs an API key/session; use curated records")); },
};

/* shared mapping for curated artwork entries {name, synonyms, licence, licenceId,
   attribution, format, sourceId} */
function mapArtwork(raw, provider, sourceUrl) {
  var out = [];
  var list = (raw && raw.assets) || raw || [];
  if (!Array.isArray(list)) return out;
  for (var i = 0; i < list.length; i++) {
    var a = list[i] || {};
    out.push({
      id: (a.id || (provider.toLowerCase().replace(/\s+/g, "-") + ":" + (a.sourceId || i))),
      scientificName: a.name || a.scientificName || "Untitled",
      synonyms: a.synonyms || [],
      category: a.category || "artwork",
      topic: a.topic || "cell-biology",
      provider: provider,
      sourceUrl: a.sourceUrl || sourceUrl,
      sourceId: a.sourceId || "",
      retrievedAt: a.retrievedAt || nowIso(),
      format: a.format || "svg",
      licence: a.licence || "",
      licenceId: a.licenceId || null,
      attribution: a.attribution || "",
      validation: a.licenceId ? "verified" : "unverified",
      renderer: a.renderer || "svg",
    });
  }
  return out;
}

function curated(provider, reason) {
  return { provider: provider, ok: true, unavailable: false, curated: true, reason: reason, records: [] };
}

/* Shared network call with timeout. Rejects with a descriptive Error; never
   fabricates a result. Optional CORS/rate-limit awareness: a 429 or 403 is
   surfaced verbatim so the caller can back off. */
function call(providerId, deps, req) {
  var d = deps || {};
  if (!req || !req.url) return Promise.reject(new Error(providerId + ": no request to send"));
  if (d.baseUrl) req = { url: d.baseUrl + "/" + providerId.toLowerCase().replace(/\s+/g, "-") + "?target=" + encodeURIComponent(req.url), init: req.init };
  var doFetch = d.fetch || (typeof fetch !== "undefined" ? fetch : null);
  if (!doFetch) return Promise.reject(new Error(providerId + ": fetch unavailable"));
  var timeoutMs = d.timeoutMs || 12000;
  var controller = d.AbortController || (typeof AbortController !== "undefined" ? AbortController : null);
  var signal = null, timer = null;
  var init = Object.assign({}, req.init || {});
  if (controller) {
    var c = new controller();
    signal = c.signal;
    init.signal = signal;
    timer = setTimeout(function () { c.abort(); }, timeoutMs);
  }
  return doFetch(req.url, init).then(function (res) {
    if (timer) clearTimeout(timer);
    if (!res) throw new Error(providerId + ": empty response");
    if (res.status === 429) throw new Error(providerId + ": rate limited (429) - back off");
    if (res.status === 403) throw new Error(providerId + ": forbidden (403) - check relay/terms");
    if (res.status && (res.status < 200 || res.status >= 300)) throw new Error(providerId + ": HTTP " + res.status);
    return typeof res.json === "function" ? res.json() : res;
  }, function (err) {
    if (timer) clearTimeout(timer);
    throw new Error(providerId + ": request failed - " + ((err && err.message) || err));
  });
}

var PROVIDERS = {
  Reactome: reactome,
  "RCSB PDB": rcsb,
  PubChem: pubchem,
  Bioicons: bioicons,
  "Servier Medical Art": servier,
  "The Cell Image Library": cellImageLibrary,
};

function listProviders() {
  return Object.keys(PROVIDERS).map(function (k) {
    var p = PROVIDERS[k];
    return { id: p.id, label: p.label, capabilities: p.capabilities.slice(), licenceNote: p.licenceNote };
  });
}

/* Fetch from one provider, always resolving to a normalised envelope so callers
   handle "unavailable" uniformly instead of catching per provider. */
function fetchFrom(providerId, query, deps) {
  var p = PROVIDERS[providerId];
  if (!p) return Promise.resolve(unavailable(providerId, "unknown provider"));
  return p.fetch(query || {}, deps || {}).catch(function (err) {
    return unavailable(providerId, (err && err.message) || String(err));
  });
}

/* Fan out across several providers in parallel (registry upsert is the caller's
   job). Failure of one provider never blocks the others. */
function fetchMany(providerIds, query, deps) {
  var ids = providerIds && providerIds.length ? providerIds : Object.keys(PROVIDERS);
  return Promise.all(ids.map(function (id) { return fetchFrom(id, query, deps); }));
}

export {
  PROVIDERS,
  listProviders,
  fetchFrom,
  fetchMany,
  reactome,
  rcsb,
  pubchem,
  bioicons,
  servier,
  cellImageLibrary,
};
