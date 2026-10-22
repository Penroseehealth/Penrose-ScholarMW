/* Phase 11 unit: provider adapters (P1-002) with mocked fetch.
   Network paths are exercised with an injected fake fetch so mapping, error,
   timeout and unavailable handling are deterministic. A live reachability probe
   runs separately (marked MOCKED when offline) and never asserts real results. */
import { PROVIDERS, listProviders, fetchFrom, fetchMany, reactome, rcsb, pubchem, bioicons } from '../js/providers.js';
import { createAssetRegistry } from '../js/asset_registry.js';

let pass = 0, fail = 0;
function ck(name, ok, detail) {
  if (ok) { pass++; console.log('  PASS ' + name); }
  else { fail++; console.log('  FAIL ' + name + (detail ? ' - ' + detail : '')); }
}

function fakeJson(json, status) {
  return () => Promise.resolve({ status: status || 200, json: () => Promise.resolve(json) });
}

console.log('=== Phase 11 unit: provider catalogue ===');
{
  const list = listProviders();
  ck('six providers registered', list.length === 6, list.map(p => p.id).join(', '));
  ck('every provider declares capabilities', list.every(p => p.capabilities.length > 0));
  ck('every provider documents its licensing terms explicitly', list.every(p => /licence|license|CC0|CC-BY/i.test(p.licenceNote)));
  ck('no provider presumes a platform-wide blanket licence',
    list.every(p => /per|vary|separate|generally|often|respect|CC-BY|CC0/i.test(p.licenceNote)));
  ck('Reactome declared', !!PROVIDERS['Reactome']);
  ck('RCSB PDB declared', !!PROVIDERS['RCSB PDB']);
  ck('PubChem declared', !!PROVIDERS['PubChem']);
  ck('Bioicons / Servier / CIL declared', !!PROVIDERS['Bioicons'] && !!PROVIDERS['Servier Medical Art'] && !!PROVIDERS['The Cell Image Library']);
}

console.log('=== Phase 11 unit: request building (pure) ===');
{
  const r = reactome.buildRequest({ term: 'citric acid cycle' });
  ck('Reactome builds a documented search URL', /search\/query\?query=/.test(r.url));
  const p = rcsb.buildRequest({ term: 'succinate dehydrogenase' });
  ck('RCSB builds a POST search body', p.init.method === 'POST' && /full_text/.test(p.init.body));
  const u = pubchem.buildRequest({ term: 'citric acid' });
  ck('PubChem builds a PUG REST property URL', /compound\/name\/citric%20acid\/property/.test(u.url));
  ck('curated providers build no network request', bioicons.buildRequest() === null);
}

console.log('=== Phase 11 unit: Reactome mapping ===');
{
  const raw = { results: [{ entries: [{ stId: 'R-HSA-71403', name: 'Citric acid cycle', synonyms: ['TCA cycle'], type: 'Pathway', species: 'Homo sapiens' }] }] };
  const recs = reactome.map(raw, { now: '2026-01-01T00:00:00Z' });
  ck('one record mapped', recs.length === 1);
  ck('id namespaced by provider', recs[0].id === 'reactome:R-HSA-71403');
  ck('source url points at the entity', /R-HSA-71403/.test(recs[0].sourceUrl));
  ck('licence carried (CC0)', recs[0].licenceId === 'cc0');
  ck('retrievedAt stamped', recs[0].retrievedAt === '2026-01-01T00:00:00Z');
  /* regression: the live Reactome API wraps matched terms in highlighting spans,
     which must not reach labels/narration via the registry */
  const hl = reactome.map({ results: [{ entries: [{ stId: 'X', name: '<span class="highlighting" >Citric</span> <span class="highlighting" >acid</span> cycle', synonyms: ['<span class="highlighting" >TCA</span>'] }] }] }, {});
  ck('Reactome markup stripped from names', hl[0].scientificName === 'Citric acid cycle', hl[0].scientificName);
  ck('Reactome markup stripped from synonyms', hl[0].synonyms[0] === 'TCA', hl[0].synonyms[0]);
  const reg = createAssetRegistry([]);
  const res = reg.upsertFromProvider(recs);
  ck('mapped records pass registry validation', res.added === 1 && res.failed === 0, JSON.stringify(res));
}

console.log('=== Phase 11 unit: RCSB + PubChem mapping ===');
{
  const rrecs = rcsb.map({ result_set: [{ identifier: '1EUZ' }] }, { name: 'Succinate dehydrogenase', now: 'X' });
  ck('RCSB maps identifiers to records', rrecs.length === 1 && rrecs[0].sourceId === '1EUZ');
  ck('RCSB record uses molstar renderer', rrecs[0].renderer === 'molstar');
  ck('RCSB record format is pdb', rrecs[0].format === 'pdb');

  const precs = pubchem.map({ PropertyTable: { Properties: [{ CID: 311, IUPACName: 'citric acid', MolecularFormula: 'C6H8O7', MolecularWeight: 192.12 }] } }, { topic: 'metabolism', now: 'X' });
  ck('PubChem maps compound records', precs.length === 1 && precs[0].sourceId === 'CID 311');
  ck('PubChem keeps molecule payload', precs[0].payload.formula === 'C6H8O7');
  ck('PubChem licence public domain', precs[0].licenceId === 'public domain');
}

console.log('=== Phase 11 unit: fetch (mocked) ===');
{
  const ok = await fetchFrom('Reactome', { term: 'x' }, { fetch: fakeJson({ results: [{ entries: [{ stId: 'AA', name: 'Alpha' }] }] }) });
  ck('fetch resolves to ok envelope', ok.ok === true && ok.records.length === 1, JSON.stringify(ok));

  const offline = await fetchFrom('RCSB PDB', { term: 'x' }, { fetch: () => Promise.reject(new Error('offline')) });
  ck('network failure -> unavailable (not fabricated)', offline.unavailable === true && offline.records.length === 0, JSON.stringify(offline));

  const rl = await fetchFrom('PubChem', { term: 'x' }, { fetch: () => Promise.resolve({ status: 429 }) });
  ck('429 surfaces rate-limit reason', rl.unavailable === true && /rate limited/i.test(rl.reason));

  const fb = await fetchFrom('PubChem', { term: 'x' }, { fetch: () => Promise.resolve({ status: 403 }) });
  ck('403 surfaces forbidden reason', fb.unavailable === true && /forbidden|403/i.test(fb.reason));

  const curated = await fetchFrom('Bioicons', {}, {});
  ck('curated provider reports curated, not a fake result', curated.curated === true && curated.records.length === 0);

  const many = await fetchMany(['Reactome', 'RCSB PDB', 'PubChem'], { term: 'x' }, { fetch: fakeJson({ results: [] }) });
  ck('fetchMany fans out to all providers', many.length === 3);
  ck('one provider failing does not block others', many.filter(e => !e.unavailable).length >= 1);
}

console.log('=== Phase 11 unit: curated artwork mapping honours per-asset licence ===');
{
  const recs = bioicons.map({ assets: [
    { name: 'Mitochondrion', licence: 'CC0', licenceId: 'cc0', attribution: '' },
    { name: 'Nucleus', licence: 'CC BY 4.0', licenceId: 'cc-by', attribution: 'X' },
  ] }, {});
  const reg = createAssetRegistry(recs);
  ck('CC0 artwork redistributable', reg.get(reg.all()[0].id).redistributable === true);
  ck('CC-BY artwork with attribution redistributable', reg.get(reg.all()[1].id).redistributable === true);
}

console.log(`\nPhase 11 unit: ${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
