export const PALETTE = {
  dark: {
    canvas: '#0a1226',
    grid: '#1c2b52',
    gridMajor: '#243560',
    axis: '#5bd7f0',
    axisLabel: '#e9edff',
    tick: '#9fb0d6',
    ink: '#f2f5ff',
    selection: '#22d3ee',
    handle: '#0b1730',
  },
  light: {
    canvas: '#ffffff',
    grid: '#e4e9f4',
    gridMajor: '#d3dbea',
    axis: '#111827',
    axisLabel: '#0f172a',
    tick: '#475569',
    ink: '#0f172a',
    selection: '#0284c7',
    handle: '#ffffff',
  },
};

export function paletteFor(theme) {
  return PALETTE[theme] || PALETTE.dark;
}

export const INK_COLORS = ['#ffd54a', '#ef4444', '#3b82f6', '#22c55e', '#a855f7', '#e2e8f5'];
