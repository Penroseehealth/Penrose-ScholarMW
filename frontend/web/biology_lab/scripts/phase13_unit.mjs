/* Phase 13 unit: curated Krebs cycle science (P4-001) verified against an
   INDEPENDENT reference table (P4-002).

   The reference below is written separately from krebs.js (not imported from it)
   so the test actually checks the data rather than restating it. Order, enzymes,
   cofactors, carbon flow and the non-cycle entry reaction are all asserted. */
import { KREBS_MODEL, STAGES, ENTRY, verifyModel } from '../js/krebs.js';

let pass = 0, fail = 0;
function ck(name, ok, detail) {
  if (ok) { pass++; console.log('  PASS ' + name); }
  else { fail++; console.log('  FAIL ' + name + (detail ? ' - ' + detail : '')); }
}

/* Independent canonical reference: reaction order + enzyme + key product per
   step, taken from standard biochemistry (Berg/Stryer, Lodish, Reactome). */
const REFERENCE = [
  { n: 1, enzyme: 'citrate synthase', to: 'citrate', product: null },
  { n: 2, enzyme: 'aconitase', to: 'isocitrate', product: null },
  { n: 3, enzyme: 'isocitrate dehydrogenase', to: 'alpha-ketoglutarate', product: 'NADH' },
  { n: 4, enzyme: 'alpha-ketoglutarate dehydrogenase', to: 'succinyl-CoA', product: 'NADH' },
  { n: 5, enzyme: 'succinyl-CoA synthetase', to: 'succinate', product: 'GTP' },
  { n: 6, enzyme: 'succinate dehydrogenase', to: 'fumarate', product: 'FADH2' },
  { n: 7, enzyme: 'fumarase', to: 'malate', product: null },
  { n: 8, enzyme: 'malate dehydrogenase', to: 'oxaloacetate', product: 'NADH' },
];

console.log('=== Phase 13 unit: structural integrity ===');
{
  const v = verifyModel(KREBS_MODEL);
  ck('curated model passes self-verification', v.ok === true, JSON.stringify(v.errors));
  ck('exactly 8 cycle reactions (not 9: entry is separate)', KREBS_MODEL.stages.length === 8);
  ck('model marked curated with a source', KREBS_MODEL.curated === true && !!KREBS_MODEL.source);
}

console.log('=== Phase 13 unit: reaction order + enzymes vs reference ===');
{
  REFERENCE.forEach(function (ref) {
    const s = STAGES[ref.n - 1];
    const enzHit = s.enzymes.join(' ').toLowerCase();
    ck('stage ' + ref.n + ' enzyme matches reference (' + ref.enzyme + ')', enzHit.indexOf(ref.enzyme.toLowerCase()) >= 0, s.enzymes.join(','));
    ck('stage ' + ref.n + ' product intermediate is ' + ref.to, s.to === ref.to, s.to);
    if (ref.product) {
      ck('stage ' + ref.n + ' yields ' + ref.product, s.cofactors.some(c => c.indexOf(ref.product) >= 0), s.cofactors.join(','));
    }
  });
}

console.log('=== Phase 13 unit: carbon flow + regeneration ===');
{
  ck('starts from oxaloacetate (4C)', STAGES[0].from === 'oxaloacetate' && STAGES[0].carbonCount === 6);
  ck('chain is continuous (to -> next from)',
    STAGES.every((s, i) => s.to === STAGES[(i + 1) % 8].from));
  ck('oxaloacetate is regenerated at stage 8', STAGES[7].to === 'oxaloacetate');
  ck('citrate is 6C, then two decarboxylations drop to 4C',
    STAGES[1].carbonCount === 6 && STAGES[2].carbonCount === 5 && STAGES[3].carbonCount === 4);
  ck('two CO2 released (stages 3 and 4)',
    STAGES[2].cofactors.indexOf('CO2') >= 0 && STAGES[3].cofactors.indexOf('CO2') >= 0);
}

console.log('=== Phase 13 unit: energy + cofactor balance ===');
{
  const b = KREBS_MODEL.balance.perAcetylCoA;
  ck('3 NADH per acetyl-CoA', b.NADH === 3);
  ck('1 FADH2 per acetyl-CoA', b.FADH2 === 1);
  ck('1 GTP per acetyl-CoA', b.GTP === 1);
  ck('2 CO2 per acetyl-CoA', b.CO2 === 2);
  const nadh = STAGES.filter(s => s.cofactors.some(c => c === 'NADH')).map(s => s.n);
  ck('NADH produced at stages 3,4,8', JSON.stringify(nadh) === JSON.stringify([3, 4, 8]), JSON.stringify(nadh));
  const fadh = STAGES.filter(s => s.cofactors.some(c => c === 'FADH2')).map(s => s.n);
  ck('FADH2 produced only at stage 6 (succinate dehydrogenase)', JSON.stringify(fadh) === JSON.stringify([6]), JSON.stringify(fadh));
  const gtp = STAGES.filter(s => s.cofactors.some(c => /GTP/.test(c))).map(s => s.n);
  ck('GTP produced at stage 5 (substrate-level phosphorylation)', JSON.stringify(gtp) === JSON.stringify([5]), JSON.stringify(gtp));
}

console.log('=== Phase 13 unit: succinyl-CoA -> succinate energy step ===');
{
  const s5 = STAGES[4];
  ck('stage 5 is succinyl-CoA -> succinate', s5.from === 'succinyl-CoA' && s5.to === 'succinate');
  ck('stage 5 is substrate-level phosphorylation producing GTP',
    /substrate-level phosphorylation/i.test(s5.detail) && s5.cofactors.some(c => /GTP/.test(c)));
  ck('succinate dehydrogenase doubles as respiratory Complex II',
    /Complex II/.test(STAGES[5].enzymes.join(' ')) && /Complex II/.test(STAGES[5].detail));
}

console.log('=== Phase 13 unit: link reaction (acetyl-CoA entry) ===');
{
  ck('entry starts from pyruvate', /^Pyruvate/.test(ENTRY.reaction));
  ck('entry produces acetyl-CoA', /Acetyl-CoA/.test(ENTRY.reaction));
  ck('entry uses pyruvate dehydrogenase complex', ENTRY.enzymes.join(' ').toLowerCase().indexOf('pyruvate dehydrogenase') >= 0);
  ck('entry is modelled separately (not stage 9)', !STAGES.some(s => /pyruvate/i.test(s.from)));
}

console.log('=== Phase 13 unit: honesty about uncertainty + organism ===');
{
  ck('organism scope stated', /mitochondrial matrix/i.test(KREBS_MODEL.organism));
  ck('uncertainty notes are present', KREBS_MODEL.uncertainty.length >= 3);
  ck('GTP/ATP nuance flagged', KREBS_MODEL.uncertainty.some(u => /GTP vs ATP/i.test(u)));
  ck('enzyme synonym nuance flagged', KREBS_MODEL.uncertainty.some(u => /synonym/i.test(u)));
  ck('every stage has a teaching detail string', STAGES.every(s => typeof s.detail === 'string' && s.detail.length > 20));
}

console.log(`\nPhase 13 unit: ${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
