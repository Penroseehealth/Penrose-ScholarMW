/* Phase 10 unit: scientific asset registry + licence/provenance gate (P1-001/3). */
import { createAssetRegistry, validateRecord } from '../js/asset_registry.js';
import { evaluateLicence, canRedistribute, provenanceLine, lookupLicence } from '../js/licence.js';
import { SEED_ASSETS } from '../js/asset_seed.js';

let pass = 0, fail = 0;
function ck(name, ok, detail) {
  if (ok) { pass++; console.log('  PASS ' + name); }
  else { fail++; console.log('  FAIL ' + name + (detail ? ' - ' + detail : '')); }
}

console.log('=== Phase 10 unit: licence gate ===');
{
  ck('CC0 is open + redistributable', evaluateLicence({ licenceId: 'cc0' }).redistributable === true);
  ck('CC BY with attribution is redistributable',
    evaluateLicence({ licenceId: 'cc-by', attribution: 'Someone' }).redistributable === true);
  ck('CC BY without attribution is NOT redistributable',
    evaluateLicence({ licenceId: 'cc-by' }).redistributable === false);
  ck('CC BY-NC is restricted', evaluateLicence({ licenceId: 'cc-by-nc' }).class === 'restricted');
  ck('unknown licence is unverified', evaluateLicence({ licence: 'weird-terms' }).class === 'unverified');
  ck('missing licence is unverified', evaluateLicence({}).redistributable === false);
  ck('needsReview forces unverified even if CC0',
    evaluateLicence({ licenceId: 'cc0', needsReview: true }).class === 'unverified');
  ck('canRedistribute mirrors the gate', canRedistribute({ licenceId: 'cc0' }) === true
    && canRedistribute({ licenceId: 'cc-by-nc' }) === false);
  ck('provenance line includes provider, licence, attribution',
    /Reactome.*CC0/.test(provenanceLine({ provider: 'Reactome', licenceId: 'cc0', attribution: 'X' })));
  ck('lookup tolerates suffix forms', lookupLicence('CC BY 4.0 International') != null);
}

console.log('=== Phase 10 unit: registry schema + validation ===');
{
  const good = validateRecord({ id: 'a1', scientificName: 'Water', provider: 'PubChem' });
  ck('minimal valid record passes', good.ok === true, JSON.stringify(good.errors));
  ck('record normalised with defaults', good.record.synonyms.length === 0 && good.record.validation === 'unverified');
  ck('licence gate applied in record', good.record.redistribution === 'unverified');

  const bad = validateRecord({ scientificName: 'No id' });
  ck('missing id fails', bad.ok === false && bad.errors.some(e => /id/.test(e)));
  const badRenderer = validateRecord({ id: 'x', scientificName: 'y', provider: 'z', renderer: 'quantum' });
  ck('unknown renderer fails', badRenderer.ok === false);
}

console.log('=== Phase 10 unit: registry search / facets / review ===');
{
  const reg = createAssetRegistry(SEED_ASSETS);
  const st = reg.stats();
  ck('seed loaded', st.count === SEED_ASSETS.length, st.count + ' vs ' + SEED_ASSETS.length);

  ck('search by name finds the Krebs cycle',
    reg.search('krebs cycle').some(r => r.id === 'reactome:krebs-cycle'));
  ck('search by synonym finds citric acid cycle',
    reg.search('tricarboxylic').length >= 1);
  ck('search scores name above topic',
    reg.search('citric acid')[0].id === 'pubchem:citric-acid'
    || reg.search('citric acid')[0].id === 'reactome:krebs-cycle');
  ck('category filter works',
    reg.search('', { category: 'molecule' }).every(r => r.category === 'molecule'));
  ck('topic filter works',
    reg.search('', { topic: 'metabolism' }).every(r => r.topic === 'metabolism'));
  ck('provider filter works',
    reg.search('', { provider: 'Reactome' }).length === 2);
  ck('redistributableOnly excludes restricted + unverified',
    reg.search('', { redistributableOnly: true }).every(r => r.redistributable === true));
  ck('renderer filter works',
    reg.search('', { renderer: 'molstar' }).every(r => r.renderer === 'molstar'));

  const f = reg.facets();
  ck('facets count categories', (f.categories.pathway || 0) >= 1);
  ck('facets count providers', (f.providers.Reactome || 0) === 2);

  ck('restricted asset is not redistributable',
    reg.get('cellimage:mitochondria-tem').redistributable === false);
  ck('unverified asset is not represented as unrestricted',
    reg.get('unverified:mitochondrial-matrix').redistribution === 'unverified');
  ck('needsReview lists the unverified asset',
    reg.needsReview().some(r => r.id === 'unverified:mitochondrial-matrix'));
  ck('redistributable() excludes restricted + unverified',
    reg.redistributable().every(r => r.redistributable === true));
  ck('every record carries a provenance line',
    reg.all().every(r => typeof r.provenance === 'string' && r.provenance.length > 0));

  /* duplicate handling */
  reg.add({ id: 'reactome:krebs-cycle', scientificName: 'Dup', provider: 'Reactome' });
  ck('duplicate id replaced, not doubled', reg.all().filter(r => r.id === 'reactome:krebs-cycle').length === 1);
}

console.log('=== Phase 10 unit: provider upsert path ===');
{
  const reg = createAssetRegistry([]);
  const res = reg.upsertFromProvider([
    { id: 'p:1', scientificName: 'Thing', provider: 'P' },
    { scientificName: 'no id' },
  ]);
  ck('provider upsert adds valid, rejects invalid', res.added === 1 && res.failed === 1, JSON.stringify(res));
  ck('rejected list records the failure', reg.rejected().length === 1);
}

console.log(`\nPhase 10 unit: ${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
