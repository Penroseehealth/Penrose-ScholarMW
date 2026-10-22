/* Phase 14 unit: registry service reliability (P5-001) - caching, timeouts,
   retry/backoff, rate-limit, error + empty states. Deterministic: fake fetch,
   fake store, fake timers (immediate), fixed rng. */
import { createRegistryService } from '../js/registry_service.js';

let pass = 0, fail = 0;
function ck(name, ok, detail) {
  if (ok) { pass++; console.log('  PASS ' + name); }
  else { fail++; console.log('  FAIL ' + name + (detail ? ' - ' + detail : '')); }
}

/* fake in-memory store */
function fakeStore() {
  var m = {};
  return {
    getItem: function (k) { return Object.prototype.hasOwnProperty.call(m, k) ? m[k] : null; },
    setItem: function (k, v) { m[k] = String(v); },
    removeItem: function (k) { delete m[k]; },
    _size: function () { return Object.keys(m).length; },
  };
}
/* timers that resolve immediately (no real waiting) */
const fastTimers = (fn) => setTimeout(fn, 0);

const REACTOME_JSON = { results: [{ entries: [{ stId: 'R-HSA-71403', name: 'Citric acid cycle' }] }] };
const okFetch = () => Promise.resolve({ status: 200, json: () => Promise.resolve(REACTOME_JSON) });
const seqFetch = (responders) => {
  var i = 0;
  return () => {
    var r = responders[Math.min(i, responders.length - 1)];
    i++;
    if (typeof r === 'function') return r();
    return r;
  };
};

console.log('=== Phase 14 unit: success + cache (ttl) ===');
{
  const store = fakeStore();
  let calls = 0;
  const svc = createRegistryService({ store, timers: fastTimers, rng: () => 0.5, fetch: () => { calls++; return okFetch(); } });
  const r1 = await svc.fetchProvider('Reactome', { term: 'citric acid cycle' });
  ck('success status is ok', r1.status === 'ok', JSON.stringify(r1));
  ck('records returned and validated', r1.records.length === 1 && r1.records[0].id === 'reactome:R-HSA-71403');
  const r2 = await svc.fetchProvider('Reactome', { term: 'citric acid cycle' });
  ck('second call served from cache', r2.status === 'cache' && calls === 1, 'calls=' + calls);
  ck('snapshot reports a cache hit', svc.snapshot().state.cacheHits === 1);
}

console.log('=== Phase 14 unit: empty vs error are distinct ===');
{
  const svc = createRegistryService({ store: fakeStore(), timers: fastTimers, rng: () => 0.5, maxRetries: 0,
    fetch: () => Promise.resolve({ status: 200, json: () => Promise.resolve({ results: [] }) }) });
  const r = await svc.fetchProvider('Reactome', { term: 'nothing' });
  ck('empty success is status empty, not error', r.status === 'empty' && r.records.length === 0, JSON.stringify(r));
}

console.log('=== Phase 14 unit: retry on transient failure then give up ===');
{
  // always network-fails -> status 'error' (not fabricated)
  const svc = createRegistryService({ store: fakeStore(), timers: fastTimers, rng: () => 0.5, maxRetries: 2, baseDelayMs: 1,
    fetch: () => Promise.reject(new Error('offline')) });
  const r = await svc.fetchProvider('Reactome', { term: 'x' });
  ck('unrecoverable network failure -> error', r.status === 'error', JSON.stringify(r));
  ck('error carries a reason', /offline|request failed/i.test(r.reason), r.reason);
  ck('attempts reflect retries', r.attempts === 3, 'attempts=' + r.attempts);
}

console.log('=== Phase 14 unit: transient failure then success ===');
{
  let n = 0;
  const svc = createRegistryService({ store: fakeStore(), timers: fastTimers, rng: () => 0.5, maxRetries: 2, baseDelayMs: 1,
    fetch: () => { n++; if (n < 2) return Promise.reject(new Error('flaky')); return okFetch(); } });
  const r = await svc.fetchProvider('Reactome', { term: 'x' });
  ck('recovers after one transient failure', r.status === 'ok' && r.attempts === 2, JSON.stringify(r));
  ck('retry counted', svc.snapshot().state.retries >= 1);
}

console.log('=== Phase 14 unit: rate limit (429) ===');
{
  const svc = createRegistryService({ store: fakeStore(), timers: fastTimers, rng: () => 0.5, maxRetries: 1, baseDelayMs: 1,
    fetch: () => Promise.resolve({ status: 429 }) });
  const r = await svc.fetchProvider('PubChem', { term: 'x' });
  ck('persistent 429 -> rate-limited status', r.status === 'rate-limited', JSON.stringify(r));
  ck('rate-limit reason surfaced', /rate limited|429/i.test(r.reason), r.reason);
}

console.log('=== Phase 14 unit: 403 is terminal (not retried) ===');
{
  let calls = 0;
  const svc = createRegistryService({ store: fakeStore(), timers: fastTimers, rng: () => 0.5, maxRetries: 3, baseDelayMs: 1,
    fetch: () => { calls++; return Promise.resolve({ status: 403 }); } });
  const r = await svc.fetchProvider('RCSB PDB', { term: 'x' });
  ck('403 -> error without retry', r.status === 'error' && calls === 1, 'calls=' + calls);
}

console.log('=== Phase 14 unit: stale cache fallback on failure ===');
{
  const store = fakeStore();
  let mode = 'ok';
  const svc = createRegistryService({ store, timers: fastTimers, rng: () => 0.5, maxRetries: 0, baseDelayMs: 1,
    fetch: () => mode === 'ok' ? okFetch() : Promise.reject(new Error('now offline')) });
  await svc.fetchProvider('Reactome', { term: 'cycle' });       // populate cache
  // expire the cache by advancing time beyond ttl
  const svc2 = createRegistryService({ store, timers: fastTimers, rng: () => 0.5, maxRetries: 0, baseDelayMs: 1, ttlMs: -1,
    fetch: () => Promise.reject(new Error('now offline')) });
  const r = await svc2.fetchProvider('Reactome', { term: 'cycle' });
  ck('expired cache + failure -> stale fallback', r.status === 'stale' && r.records.length === 1, JSON.stringify(r));
}

console.log('=== Phase 14 unit: curated provider status ===');
{
  const svc = createRegistryService({ store: fakeStore(), timers: fastTimers, rng: () => 0.5, fetch: okFetch });
  const r = await svc.fetchProvider('Bioicons', {});
  ck('curated provider reports curated status', r.status === 'curated', JSON.stringify(r));
}

console.log('=== Phase 14 unit: fan-out aggregation ===');
{
  const svc = createRegistryService({ store: fakeStore(), timers: fastTimers, rng: () => 0.5, maxRetries: 0, baseDelayMs: 1,
    fetch: (url) => {
      if (/rcsbsearch/.test(url)) return Promise.reject(new Error('down'));
      if (/pubchem/.test(url)) return Promise.resolve({ status: 200, json: () => Promise.resolve({ PropertyTable: { Properties: [{ CID: 311, IUPACName: 'citric acid' }] } }) });
      return okFetch();
    } });
  const agg = await svc.search({ term: 'citric acid cycle' }, ['Reactome', 'RCSB PDB', 'PubChem']);
  ck('aggregate is partial when one provider fails', agg.status === 'partial', agg.status);
  ck('per-provider statuses recorded', agg.providers['RCSB PDB'] === 'error' && agg.providers['Reactome'] === 'ok', JSON.stringify(agg.providers));
  ck('records from working providers merged', agg.records.length >= 2, 'n=' + agg.records.length);
  ck('records are deduped by id', new Set(agg.records.map(r => r.id)).size === agg.records.length);
}

console.log(`\nPhase 14 unit: ${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
