/* Live provider reachability probe (P1-002 evidence).
 *
 * This does NOT assert scientific content and it does NOT fail the suite when
 * offline. It only records, per provider, whether the documented endpoint was
 * reachable right now, so the evidence report can distinguish IMPLEMENTED (code)
 * from LIVE (network actually reachable) from MOCKED/BLOCKED (offline).
 *
 * Live network results are never trusted as scientific ground truth; they only
 * prove the adapter can talk to the endpoint. If unreachable we still exit 0 and
 * print a clearly-marked note.
 *
 * Run: node scripts/providers_live_probe.mjs   (optional; not part of `npm test`)
 */
import { PROVIDERS } from '../js/providers.js';

const QUERY = { Reactome: { term: 'citric acid cycle' }, 'RCSB PDB': { term: 'succinate dehydrogenase' }, PubChem: { term: 'citric acid' } };

async function probe(id) {
  const p = PROVIDERS[id];
  const req = p.buildRequest(QUERY[id] || {});
  if (!req) {
    return { provider: id, live: 'CURATED', detail: 'no public JSON endpoint; curated records only' };
  }
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 10000);
    const res = await fetch(req.url, Object.assign({}, req.init, { signal: controller.signal }));
    clearTimeout(t);
    return { provider: id, live: res.ok ? 'REACHABLE' : 'HTTP ' + res.status, detail: req.url };
  } catch (err) {
    return { provider: id, live: 'MOCKED/BLOCKED', detail: (err && err.message) || String(err) };
  }
}

console.log('provider live-reachability probe (non-asserting):');
const results = await Promise.all(Object.keys(PROVIDERS).map(probe));
for (const r of results) console.log('  ' + r.provider.padEnd(26) + r.live.padEnd(16) + r.detail);
console.log('\nNOTE: REACHABLE proves transport only, not scientific correctness. MOCKED/BLOCKED = offline here; adapter mapping is still covered by phase11_unit.mjs with a fake fetch.');
process.exit(0);
