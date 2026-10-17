/* ModelCatalogueService: Grab3D public CC0 catalogue, read through the same-origin
   /grab3d/api/v1 relay (upstream sends no CORS headers), cached in localStorage. */
export function createModelCatalogue(options) {
  var opts = options || {};
  var base = opts.baseUrl || "/grab3d/api/v1";
  var origin = opts.origin || "/grab3d";
  var upstreamOrigin = opts.upstreamOrigin || "https://grab3d.com";
  var ttlMs = opts.ttlMs || 6 * 3600 * 1000;
  var LS_KEY = "biolab.grab3d.catalogue.v1";
  var models = [];
  var meta = null;
  var fetchedAt = 0;
  var source = "none";
  var loadP = null;

  function lower(s) { return String(s == null ? "" : s).toLowerCase(); }

  function localUrl(abs) {
    if (typeof abs !== "string" || !abs) return null;
    if (abs.indexOf(upstreamOrigin + "/") === 0) return origin + abs.slice(upstreamOrigin.length);
    if (abs.charAt(0) === "/") return origin + abs;
    return null;
  }

  function persist() {
    try {
      localStorage.setItem(LS_KEY, JSON.stringify({ fetchedAt: fetchedAt, meta: meta, models: models }));
    } catch (e) { /* quota: keep in-memory copy */ }
  }

  function restore() {
    try {
      var raw = localStorage.getItem(LS_KEY);
      if (!raw) return false;
      var j = JSON.parse(raw);
      if (!j || !Array.isArray(j.models) || !j.models.length) return false;
      models = j.models;
      meta = j.meta || null;
      fetchedAt = j.fetchedAt || 0;
      source = "cache";
      return true;
    } catch (e) { return false; }
  }

  function snapshot() {
    return { source: source, count: models.length, fetchedAt: fetchedAt, meta: meta };
  }

  function fetchCatalogue(force) {
    if (!force && loadP) return loadP;
    if (!force && models.length && Date.now() - fetchedAt < ttlMs) {
      source = models.length && source !== "network" ? source : (source || "memory");
      return Promise.resolve(snapshot());
    }
    loadP = fetch(base + "/models.json", { cache: "no-store" })
      .then(function (r) {
        if (!r.ok) throw new Error("catalogue HTTP " + r.status);
        return r.json();
      })
      .then(function (j) {
        if (!j || !Array.isArray(j.models) || !j.models.length) throw new Error("catalogue schema");
        models = j.models;
        meta = { api: j.api, version: j.version, license: j.license, count: j.count };
        fetchedAt = Date.now();
        source = "network";
        persist();
        return snapshot();
      })
      .catch(function (e) {
        if (models.length) { source = "stale"; return snapshot(); }
        if (restore()) return snapshot();
        throw e;
      })
      .finally(function () { loadP = null; });
    return loadP;
  }

  function get(slug) {
    for (var i = 0; i < models.length; i++) if (models[i].slug === slug) return models[i];
    return null;
  }

  function glbMap(m) {
    var out = {};
    var files = (m && m.files) || [];
    for (var i = 0; i < files.length; i++) {
      var f = files[i];
      if (f.format !== "glb") continue;
      out[f.variant || "full"] = { url: localUrl(f.url), upstreamUrl: f.url, bytes: f.bytes, file: f.file };
    }
    return out;
  }

  function project(m, score) {
    return {
      slug: m.slug,
      name: (m.name && m.name.en) || m.slug,
      summary: m.summary || "",
      category: m.category,
      categoryName: m.categoryName,
      tier: m.tier,
      style: m.style,
      tags: m.tags || [],
      license: m.license,
      origin: m.origin || null,
      triangles: (m.specs && m.specs.triangles) || null,
      trianglesLight: (m.specs && m.specs.trianglesLight) || null,
      thumbnail: localUrl(m.media && m.media.thumbnail),
      thumbnailSmall: localUrl(m.media && m.media.thumbnailSmall),
      page: m.page,
      glb: glbMap(m),
      score: score == null ? 0 : score
    };
  }

  /* keyword search over name/slug/tags/summary/category; optional category + glb filters */
  function search(query, options2) {
    var o = options2 || {};
    var q = lower(query).trim();
    var terms = q ? q.split(/\s+/) : [];
    var out = [];
    for (var i = 0; i < models.length; i++) {
      var m = models[i];
      if (o.category && m.category !== o.category) continue;
      if (o.format && !(m.files || []).some(function (f) { return f.format === o.format; })) continue;
      var score = 0;
      if (terms.length) {
        var name = lower(m.name && m.name.en);
        var slug = lower(m.slug);
        var tags = lower((m.tags || []).join(" "));
        var hay = name + " " + slug + " " + tags + " " + lower(m.summary) + " " + lower(m.categoryName);
        for (var t = 0; t < terms.length; t++) {
          var term = terms[t];
          if (!hay.includes(term)) { score = 0; break; }
          if (name.includes(term)) score += 6;
          if (slug.includes(term)) score += 4;
          if (tags.includes(term)) score += 3;
          if (lower(m.summary).includes(term)) score += 1;
          score += 1;
        }
      } else score = 1;
      if (score > 0) out.push(project(m, score));
    }
    out.sort(function (a, b) { return b.score - a.score || a.name.localeCompare(b.name); });
    if (o.limit) out = out.slice(0, o.limit);
    return out;
  }

  function getProjected(slug) {
    var m = get(slug);
    return m ? project(m, 0) : null;
  }

  return {
    load: fetchCatalogue,
    search: search,
    get: getProjected,
    localUrl: localUrl,
    stats: snapshot,
    all: function () { return models.slice(); }
  };
}
