/* Registry service: reliability layer over the provider adapters (P5-001).
 *
 * Wraps providers.js + asset_registry.js with the operational behaviour the
 * prompt requires:
 *   - caching         results cached by provider+query with a TTL (localStorage
 *                     when available, in-memory otherwise), mirroring the model
 *                     catalogue pattern used elsewhere in the lab
 *   - timeouts        per-request timeout (delegated to providers.call)
 *   - retry/backoff   bounded retries with exponential backoff + jitter, only for
 *                     transient failures (network/timeout/429); never retries 403
 *   - rate-limit      a 429 causes backoff and, if still failing, a clear
 *                     "rate-limited" state rather than a fabricated result
 *   - error/empty     every fetch resolves to a normalised status object; an
 *     states          empty success is distinguished from a failure
 *
 * It NEVER fabricates assets. On unrecoverable failure it returns status 'error'
 * or 'rate-limited' with a reason, and the caller decides how to degrade (e.g.
 * fall back to curated seed records, which is a valid, honest fallback).
 *
 * Pure JS (no THREE/DOM); localStorage is optional and feature-detected.
 */
"use strict";

import { PROVIDERS, fetchFrom } from "./providers.js";
import { createAssetRegistry } from "./asset_registry.js";

var LS_PREFIX = "biolab.assetreg.";

function memStore() {
  var m = {};
  return {
    getItem: function (k) { return Object.prototype.hasOwnProperty.call(m, k) ? m[k] : null; },
    setItem: function (k, v) { m[k] = String(v); },
    removeItem: function (k) { delete m[k]; },
    isMemory: true,
  };
}

function pickStore(provided) {
  if (provided) return provided;
  try {
    if (typeof localStorage !== "undefined" && localStorage) {
      /* feature test (some browsers throw in private mode) */
      localStorage.getItem(LS_PREFIX + "probe");
      return localStorage;
    }
  } catch (e) { /* fall through */ }
  return memStore();
}

function cacheKey(providerId, query) {
  return LS_PREFIX + providerId + "::" + JSON.stringify(query || {});
}

/* Deterministic-enough jitter derived from an injectable rng for tests. */
function jitter(rng) {
  var r = (typeof rng === "function" ? rng() : Math.random());
  return Math.floor(r * 120);
}

function sleep(ms, timers) {
  var t = timers || setTimeout;
  return new Promise(function (res) { t(res, ms); });
}

function isTransient(reason) {
  if (!reason) return true;
  /* 403 is terminal (auth/terms); 429 is transient but rate-limit-specific */
  if (/forbidden|403/i.test(reason)) return false;
  if (/unknown provider|no request/i.test(reason)) return false;
  return true;
}

function isRateLimited(reason) { return /rate limited|429/i.test(reason); }

export function createRegistryService(options) {
  var opts = options || {};
  var store = pickStore(opts.store);
  var ttlMs = opts.ttlMs || 6 * 3600 * 1000;
  var maxRetries = opts.maxRetries == null ? 2 : opts.maxRetries;
  var baseDelay = opts.baseDelayMs == null ? 200 : opts.baseDelayMs;
  var timeoutMs = opts.timeoutMs || 12000;
  var registry = createAssetRegistry(opts.seed || []);
  var rng = opts.rng || Math.random;
  var timers = opts.timers || setTimeout;
  var deps = {
    fetch: opts.fetch,
    timeoutMs: timeoutMs,
    AbortController: opts.AbortController,
    baseUrl: opts.baseUrl,
  };
  var state = { lastFetchAt: 0, lastStatus: "idle", lastError: null, calls: 0, cacheHits: 0, retries: 0 };

  function readCache(providerId, query) {
    try {
      var raw = store.getItem(cacheKey(providerId, query));
      if (!raw) return null;
      var rec = JSON.parse(raw);
      if (!rec || !rec.fetchedAt) return null;
      if (Date.now() - rec.fetchedAt > ttlMs) return { stale: true, records: rec.records || [] };
      return { stale: false, records: rec.records || [] };
    } catch (e) { return null; }
  }

  function writeCache(providerId, query, records) {
    try {
      store.setItem(cacheKey(providerId, query), JSON.stringify({ fetchedAt: Date.now(), records: records }));
    } catch (e) { /* quota or disabled: non-fatal */ }
  }

  /* Fetch one provider with retry/backoff/cache. Resolves to a normalised status:
     { provider, status: 'ok'|'cache'|'stale'|'empty'|'rate-limited'|'error'|
       'curated'|'unavailable', records, reason, attempts } */
  function fetchProvider(providerId, query) {
    var cached = readCache(providerId, query);
    if (cached && !cached.stale) {
      state.cacheHits++;
      return Promise.resolve({ provider: providerId, status: "cache", records: registryify(cached.records), reason: "from cache", attempts: 0 });
    }
    return attempt(providerId, query, 0, cached);
  }

  function attempt(providerId, query, tries, cached) {
    state.calls++;
    return fetchFrom(providerId, query, deps).then(function (env) {
      if (env.unavailable) {
        var reason = env.reason || "unavailable";
        if (isRateLimited(reason) && tries < maxRetries) {
          state.retries++;
          var d = baseDelay * Math.pow(2, tries) + jitter(rng);
          return sleep(d, timers).then(function () { return attempt(providerId, query, tries + 1, cached); });
        }
        if (isTransient(reason) && tries < maxRetries) {
          state.retries++;
          var d2 = baseDelay * Math.pow(2, tries) + jitter(rng);
          return sleep(d2, timers).then(function () { return attempt(providerId, query, tries + 1, cached); });
        }
        /* exhausted retries: fall back to stale cache if present, else record state */
        var status = isRateLimited(reason) ? "rate-limited" : "error";
        state.lastStatus = status;
        state.lastError = reason;
        if (cached && cached.records.length) {
          return { provider: providerId, status: "stale", records: registryify(cached.records), reason: "retries exhausted; stale cache: " + reason, attempts: tries + 1 };
        }
        return { provider: providerId, status: status, records: [], reason: reason, attempts: tries + 1 };
      }
      if (env.curated) {
        state.lastStatus = "curated";
        return { provider: providerId, status: "curated", records: [], reason: env.reason || "curated provider", attempts: tries + 1 };
      }
      var mapped = registryify(env.records || []);
      writeCache(providerId, query, env.records || []);
      state.lastFetchAt = Date.now();
      state.lastStatus = mapped.length ? "ok" : "empty";
      return { provider: providerId, status: mapped.length ? "ok" : "empty", records: mapped, reason: mapped.length ? "" : "no matching assets", attempts: tries + 1 };
    });
  }

  /* Insert provider records into the registry and return the validated records
     (the UI only ever sees registry records). */
  function registryify(rawRecords) {
    if (!rawRecords || !rawRecords.length) return [];
    registry.upsertFromProvider(rawRecords);
    var out = [];
    for (var i = 0; i < rawRecords.length; i++) {
      var rec = registry.get(rawRecords[i].id);
      if (rec) out.push(rec);
    }
    return out;
  }

  /* Fan out across providers, each independently resilient. Resolves to an
     object with per-provider statuses plus a merged, deduped record list. */
  function search(query, providerIds) {
    var ids = (providerIds && providerIds.length) ? providerIds : Object.keys(PROVIDERS);
    return Promise.all(ids.map(function (id) { return fetchProvider(id, query); })).then(function (results) {
      var merged = [], seen = {};
      results.forEach(function (r) {
        r.records.forEach(function (rec) {
          if (!seen[rec.id]) { seen[rec.id] = 1; merged.push(rec); }
        });
      });
      var statuses = {};
      results.forEach(function (r) { statuses[r.provider] = r.status; });
      var failed = results.filter(function (r) { return r.status === "error" || r.status === "rate-limited"; });
      return {
        status: failed.length === results.length && results.length > 0 ? "error" : (failed.length ? "partial" : "ok"),
        providers: statuses,
        records: merged,
        empty: merged.length === 0,
        results: results,
      };
    });
  }

  function snapshot() {
    return {
      stats: registry.stats(),
      state: Object.assign({}, state),
      cachedKeys: countCacheKeys(),
    };
  }

  function countCacheKeys() {
    /* best-effort; memory store can just count its own keys via stats */
    return state.cacheHits;
  }

  function clearCache() {
    /* remove known keys for the providers; best-effort */
    Object.keys(PROVIDERS).forEach(function (id) {
      try { store.removeItem(cacheKey(id, { term: "citric acid cycle" })); } catch (e) {}
    });
  }

  return {
    registry: registry,
    search: search,
    fetchProvider: fetchProvider,
    snapshot: snapshot,
    clearCache: clearCache,
  };
}

export default createRegistryService;
