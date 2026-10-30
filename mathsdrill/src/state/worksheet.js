const STORAGE_KEY = 'mathdrill.worksheet.v1';

export const WEIGHT_PRESETS = { thin: 1.5, normal: 3, thick: 6 };
export const WEIGHT_MIN = 1;
export const WEIGHT_MAX = 10;

export const DEFAULT_PALETTE_COLORS = [
  '#ffd54a',
  '#ef4444',
  '#3b82f6',
  '#22c55e',
  '#a855f7',
  '#e2e8f5',
];

let idCounter = 0;
export function nextId(prefix = 'o') {
  idCounter += 1;
  return `${prefix}${Date.now().toString(36)}${idCounter}`;
}

export function emptyDoc() {
  return { objects: [], weight: WEIGHT_PRESETS.normal, preset: 'normal' };
}

export function loadDoc() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return emptyDoc();
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.objects)) return emptyDoc();
    return {
      objects: parsed.objects,
      weight: Number(parsed.weight) || WEIGHT_PRESETS.normal,
      preset: parsed.preset || 'normal',
    };
  } catch {
    return emptyDoc();
  }
}

export function persistDoc(doc) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(doc));
    return true;
  } catch {
    return false;
  }
}

export function presetFor(weight) {
  if (weight <= 2.2) return 'thin';
  if (weight <= 4.6) return 'normal';
  return 'thick';
}
