/* Phase 12 unit: query -> structured lesson spec (P2-001) + science/styling
   separation (P2-002). */
import { planLesson, classify, buildSpec, validateSpec, extractStyling, TOPIC_CATALOGUE } from '../js/lesson_planner.js';

let pass = 0, fail = 0;
function ck(name, ok, detail) {
  if (ok) { pass++; console.log('  PASS ' + name); }
  else { fail++; console.log('  FAIL ' + name + (detail ? ' - ' + detail : '')); }
}

const KREBS = {
  curated: true,
  source: 'curated:krebs',
  stages: [{ n: 1, name: 'Citrate synthase' }, { n: 2, name: 'Aconitase' }],
  reactants: ['acetyl-CoA', 'oxaloacetate'],
  products: ['citrate', 'CoA-SH'],
  cofactors: ['NADH', 'FADH2', 'GTP'],
  notes: ['8 reactions'],
  organism: 'eukaryote mitochondria (also bacteria/archaea)',
  uncertainty: [],
};

console.log('=== Phase 12 unit: classification ===');
{
  ck('matches "show me the krebs cycle"', classify('show me the krebs cycle').status === 'match');
  ck('matches "TCA cycle"', classify('teach the TCA cycle').status === 'match');
  ck('matches "citric acid cycle"', classify('citric acid cycle please').status === 'match');
  ck('matches by topic id too', classify('krebs-cycle').status === 'match');
  ck('unknown concept -> needs-clarification', classify('photosynthesis light reactions').status === 'needs-clarification');
  ck('empty query -> needs-clarification', classify('').status === 'needs-clarification');
  ck('clarification offers candidates', classify('photosynthesis').candidates.length > 0);
  ck('catalogue has at least the Krebs topic', TOPIC_CATALOGUE.some(t => t.id === 'krebs-cycle'));
}

console.log('=== Phase 12 unit: styling extraction is presentational only ===');
{
  const s1 = extractStyling('show the krebs cycle slowly and quietly');
  ck('slow parsed', s1.speed === 'slow');
  ck('animation disabled by "quietly"', s1.animate === false);
  const s2 = extractStyling('dark purple krebs cycle');
  ck('dark theme parsed', s2.theme === 'dark');
  ck('colour parsed', s2.colour === 'purple');
  const s3 = extractStyling('krebs cycle');
  ck('defaults when no style requested', s3.animate === true && s3.speed === 'normal');
}

console.log('=== Phase 12 unit: spec building + verified science ===');
{
  const spec = planLesson('show me the krebs cycle', { krebs: KREBS });
  ck('returns ready spec', spec.status === 'ready', JSON.stringify(spec.issues || spec));
  ck('spec is valid', spec.valid === true, JSON.stringify(spec.issues));
  ck('science marked verified', spec.science.verified === true);
  ck('science stages copied verbatim', spec.science.stages.length === 2 && spec.science.stages[0].name === 'Citrate synthase');
  ck('cofactors carried', spec.science.cofactors.indexOf('FADH2') >= 0);
  ck('organism note carried', /mitochondria/.test(spec.science.organism));
  ck('science source credited', spec.science.source === 'curated:krebs');
  ck('interactive modes enabled', spec.interactive.highlight && spec.interactive.pause && spec.interactive.replay && spec.interactive.quiz);
  ck('style flagged generative', spec.provenance.styleIsGenerative === true);
  ck('query recorded for provenance, not as science', spec.provenance.plannedFrom === 'show me the krebs cycle');
}

console.log('=== Phase 12 unit: science/styling boundary (P2-002) ===');
{
  const spec = planLesson('slow krebs cycle', { krebs: KREBS });
  ck('styling keys do not appear in science', Object.keys(spec.styling).every(k => !(k in spec.science)));
  /* a malicious/careless styling key must be caught as a collision */
  const bad = buildSpec(TOPIC_CATALOGUE[0], KREBS, {});
  bad.styling.stages = 'hacked';
  const v = validateSpec(bad);
  ck('styling/science collision is detected', v.valid === false && v.issues.some(i => /collides/.test(i)));
  /* unverified model must not be presented as science */
  const unverified = buildSpec(TOPIC_CATALOGUE[0], { stages: [] }, {});
  ck('unverified model fails validation', unverified.valid === false && unverified.science.verified === false);
  const withSourceNoCurated = buildSpec(TOPIC_CATALOGUE[0], { source: 'x', stages: [] }, {});
  ck('source without curated flag is still unverified', withSourceNoCurated.science.verified === false);
}

console.log('=== Phase 12 unit: no fabrication for unknown / missing model ===');
{
  const cl = planLesson('photosynthesis', { krebs: KREBS });
  ck('unknown concept returns clarification, not a lesson', cl.status === 'needs-clarification' && !cl.science, JSON.stringify(cl));
  const err = planLesson('krebs cycle', {});
  ck('missing curated model returns error, not invented science', err.status === 'error' && !err.science);
}

console.log(`\nPhase 12 unit: ${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
