'use strict';

/* Phase 7b: biological assets - educationally relevant models with checked
   scientific accuracy (sizes, roles, growth rules). Pure data + rules, no
   THREE/DOM: the host builds simple meshes from this state, the teaching
   activities (germination, microscopy, woodlice choice chamber) consume the
   same models the unit tests verify. Sizes are in SI metres; every asset
   carries an `accuracy` note stating the assumption and its tolerance. */

var ORGanelleS = {
  nucleus:      { sizeM: 6e-6,   role: 'stores DNA; controls the cell', stain: 'iodine / methylene blue' },
  vacuole:      { sizeM: 40e-6,  role: 'large central sap vacuole in plant cells; turgor pressure', stain: 'none' },
  cellWall:     { sizeM: 1e-6,   role: 'rigid cellulose wall; support and shape (plants only)', stain: 'none' },
  cellMembrane: { sizeM: 8e-9,   role: 'controls what enters and leaves', stain: 'none' },
  chloroplast:  { sizeM: 5e-6,   role: 'photosynthesis; contains chlorophyll (green tissues only)', stain: 'none' },
  mitochondrion:{ sizeM: 1e-6,   role: 'aerobic respiration; ATP release', stain: 'none (Janus green B)' },
  ribosome:     { sizeM: 25e-9,   role: 'protein synthesis', stain: 'none' },
  cytoplasm:    { sizeM: 0,      role: 'jelly where reactions happen', stain: 'none' },
};

var CELLS = {
  onionEpidermis: {
    id: 'onionEpidermis', label: 'Onion epidermis cell (plant)',
    widthMm: 0.015, parts: ['cellWall', 'cellMembrane', 'cytoplasm', 'nucleus', 'vacuole'],
    chloroplasts: false,
    accuracy: 'typical epidermal cell 15 x 30 um; brick-shaped in rows; no chloroplasts in the bulb scale used in school practicals (tolerance +/-50% between cultivars)',
  },
  cheek: {
    id: 'cheek', label: 'Human cheek cell (animal)',
    widthMm: 0.025, parts: ['cellMembrane', 'cytoplasm', 'nucleus', 'mitochondrion', 'ribosome'],
    chloroplasts: false,
    accuracy: 'irregular ~25 um; no wall, no chloroplasts; organelles beyond the nucleus are below light-microscope resolution in school kit',
  },
  leafMesophyll: {
    id: 'leafMesophyll', label: 'Leaf mesophyll cell (plant, photosynthetic)',
    widthMm: 0.05, parts: ['cellWall', 'cellMembrane', 'cytoplasm', 'nucleus', 'vacuole', 'chloroplast'],
    chloroplasts: true,
    accuracy: 'palisade cells ~50 x 20 um packed with ~50 chloroplasts of ~5 um; only visible in fresh sections, not iodine-stained onion',
  },
};

var TISSUES = {
  epidermis: { role: 'protective outer layer; contains guard cells around stomata', cells: ['onionEpidermis'] },
  mesophyll: { role: 'photosynthesis; palisade + spongy layers with many chloroplasts', cells: ['leafMesophyll'] },
  vascular:  { role: 'xylem transports water/minerals up; phloem transports sugars both ways', cells: ['leafMesophyll'] },
  muscle:    { role: 'voluntary contraction; striped fibres with many mitochondria', cells: ['cheek'] },
};

var ORGANS = {
  leaf:  { tissues: ['epidermis', 'mesophyll', 'vascular'], role: 'gas exchange + photosynthesis' },
  root:  { tissues: ['epidermis', 'vascular'], role: 'water uptake + anchorage' },
  stem:  { tissues: ['epidermis', 'vascular'], role: 'transport + support' },
};

/* scale ladder: organ -> tissue -> cell -> organelle, with the magnification
   needed to resolve each level on a school light microscope (FN 20 mm) */
var SCALE_LADDER = [
  { level: 'organ',    sizeM: 1e-1,   example: 'a whole leaf (~10 cm)',      magnification: 'naked eye / 1x' },
  { level: 'tissue',   sizeM: 1e-3,   example: 'a vein strip (~1 mm)',       magnification: 'scanning 4x' },
  { level: 'cell',     sizeM: 1.5e-5, example: 'one onion cell (~15 um)',    magnification: 'low power 10x' },
  { level: 'organelle',sizeM: 6e-6,   example: 'the nucleus (~6 um)',        magnification: 'high power 40x' },
  { level: 'membrane', sizeM: 8e-9,   example: 'the membrane (~8 nm)',       magnification: 'electron microscope only' },
];

var SPECIES = {
  cress: {
    id: 'cress', label: 'Garden cress (Lepidium sativum)',
    germinationDays: 2, tmin: 5, topt: 22, tmax: 35,
    heightMmAt: { seedling: 12, mature: 60 },
    leavesAt: { seedling: 2, mature: 6 },
    accuracy: 'cress germinates in 2-3 days at 20 C; cotyledons first, then true leaves; typical school height scale 10-80 mm over 14 days',
  },
  bean: {
    id: 'bean', label: 'Broad bean (Vicia faba)',
    germinationDays: 5, tmin: 8, topt: 25, tmax: 38,
    heightMmAt: { seedling: 40, mature: 400 },
    leavesAt: { seedling: 1, mature: 8 },
    accuracy: 'epigeal germination ~5-7 days at 20 C; hypocotyl arch pulls cotyledons up; school height scale 40-400 mm over 6 weeks',
  },
};

var INSECTS = {
  woodlice: {
    id: 'woodlice', label: 'Woodlouse (Oniscus asellus)',
    prefers: { humidityPct: 90, light: 'dark', thigmotaxis: true },
    model: 'choice chamber: 80% of turns keep them in the damp/dark arm within 10 min',
    accuracy: 'isopod crustaceans breathe through pleopodal lungs and dry out fast; classic school choice-chamber preference for damp + dark; sample of 10 gives +/-1 individual noise',
  },
};

function thermalResponse(T, tmin, topt, tmax) {
  if (T <= tmin || T >= tmax) return 0;
  return T <= topt ? (T - tmin) / (topt - tmin) : (tmax - T) / (tmax - topt);
}

function createBiology() {
  /* growth model connected to the teaching activity: same thermal rules as
     the Phase-4 germination module, plus light/water factors and height */
  function growth(speciesId, conditions, days) {
    var sp = SPECIES[speciesId] || SPECIES.cress;
    var c = conditions || {};
    var T = c.tempC == null ? 20 : c.tempC;
    var water = c.waterPresent !== false;
    var light = c.lightMinutesPerDay == null ? 720 : c.lightMinutesPerDay; /* default full day */
    var germDays = c.germinationDays == null ? sp.germinationDays : c.germinationDays;
    var therm = thermalResponse(T, sp.tmin, sp.topt, sp.tmax);
    var waterF = water ? 1 : 0;
    var lightF = Math.min(1, (light / 720) * 1.4);
    var daysGrown = waterF ? Math.max(0, days - germDays * (therm > 0 ? 1 / Math.max(therm, 0.15) : Infinity)) : 0;
    var stage = !waterF || therm === 0 ? 'no growth'
      : (days < germDays / Math.max(therm, 0.15) ? 'imbibing'
        : (daysGrown < 4 ? 'seedling' : (daysGrown < 10 ? 'growing' : 'mature')));
    var frac = stage === 'seedling' ? 0.2 : (stage === 'growing' ? 0.55 : (stage === 'mature' ? 1 : 0));
    var heightMm = +(sp.heightMmAt.mature * frac * therm * (0.6 + 0.4 * lightF)).toFixed(1);
    var leaves = frac === 0 ? 0 : Math.round(sp.leavesAt.seedling + (sp.leavesAt.mature - sp.leavesAt.seedling) * frac);
    return {
      species: sp.id, stage: stage, days: days,
      heightMm: heightMm, leaves: leaves,
      thermalFactor: +therm.toFixed(3), lightFactor: +lightF.toFixed(3), waterFactor: waterF,
      notes: [
        waterF ? 'water provided - imbibition and enzyme activation can proceed' : 'no water - germination blocked (see Phase-4 germination module)',
        therm === 0 ? 'temperature outside ' + sp.tmin + '-' + sp.tmax + ' C - no growth' : 'thermal response ' + therm.toFixed(2) + ' of optimum ' + sp.topt + ' C',
      ],
      accuracy: sp.accuracy,
    };
  }

  function woodliceChoice(n, dampFrac, minutes) {
    /* lightweight choice-chamber model: damp arm share of settled woodlice */
    n = Math.max(0, Math.min(20, Math.round(n) || 10));
    minutes = Math.max(1, minutes || 10);
    var settle = Math.min(1, minutes / 10);           /* 10 min to full preference */
    var damp = Math.round(n * (0.5 + 0.3 * settle));  /* 50% -> 80% in damp arm */
    if (dampFrac === false) damp = n - damp;          /* inverted chamber */
    return {
      total: n, dampArm: Math.max(0, Math.min(n, damp)), dryArm: n - Math.max(0, Math.min(n, damp)),
      interpretation: 'woodlice prefer the damp arm - they lose water across a large surface area and seek humidity',
      accuracy: INSECTS.woodlice.accuracy,
    };
  }

  function describeScale(level) {
    return SCALE_LADDER.filter(function (r) { return r.level === level; })[0] || null;
  }

  function cellParts(cellId) {
    var cell = CELLS[cellId];
    if (!cell) return null;
    return cell.parts.map(function (p) {
      return { id: p, sizeM: ORGanelleS[p] ? ORGanelleS[p].sizeM : 0,
        role: ORGanelleS[p] ? ORGanelleS[p].role : '', present: true };
    });
  }

  /* accuracy audit: the checks the CSV asks us to verify rather than assume */
  function audit() {
    var out = { ok: true, checks: [] };
    function ck(name, ok, detail) {
      out.checks.push({ name: name, ok: !!ok, detail: detail || '' });
      if (!ok) out.ok = false;
    }
    ck('onion cells have no chloroplasts', CELLS.onionEpidermis.chloroplasts === false);
    ck('cheek cells have no cell wall', CELLS.cheek.parts.indexOf('cellWall') < 0);
    ck('leaf mesophyll has chloroplasts', CELLS.leafMesophyll.chloroplasts === true);
    ck('onion cell size matches the Phase-4 microscope model (15 um)',
      Math.abs(CELLS.onionEpidermis.widthMm - 0.015) < 1e-9);
    ck('cheek cells larger than onion', CELLS.cheek.widthMm > CELLS.onionEpidermis.widthMm);
    ck('nucleus resolvable at 40x (>=5 um school rule of thumb)', ORGanelleS.nucleus.sizeM >= 5e-6);
    ck('mitochondrion below comfortable light-microscope resolution',
      ORGanelleS.mitochondrion.sizeM < 2e-6);
    ck('membrane needs an electron microscope', ORGanelleS.cellMembrane.sizeM < 1e-7);
    ck('scale ladder is monotonically decreasing',
      SCALE_LADDER.every(function (r, i, a) { return i === 0 || r.sizeM < a[i - 1].sizeM; }));
    ck('cress germinates before the bean', SPECIES.cress.germinationDays < SPECIES.bean.germinationDays);
    ck('growth blocked without water', growth('cress', { waterPresent: false }, 10).heightMm === 0);
    ck('growth blocked outside the thermal range', growth('cress', { tempC: 2 }, 10).heightMm === 0);
    ck('mature cress near the documented height',
      Math.abs(growth('cress', { tempC: 22 }, 30).heightMm - SPECIES.cress.heightMmAt.mature) < 25,
      growth('cress', { tempC: 22 }, 30).heightMm + ' mm');
    ck('woodlice prefer damp', woodliceChoice(10, true, 10).dampArm === 8);
    return out;
  }

  return {
    organelles: ORGanelleS,
    cells: CELLS,
    tissues: TISSUES,
    organs: ORGANS,
    scaleLadder: SCALE_LADDER,
    species: SPECIES,
    insects: INSECTS,
    growth: growth,
    woodliceChoice: woodliceChoice,
    describeScale: describeScale,
    cellParts: cellParts,
    audit: audit,
  };
}

export { createBiology, ORGanelleS, CELLS, TISSUES, ORGANS, SCALE_LADDER, SPECIES, INSECTS };
