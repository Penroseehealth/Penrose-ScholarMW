import { presetFor } from '../state/worksheet';
import { IconFocus, IconMoon, IconSolve, IconSparkle, IconSun } from './icons';

export default function Header({ theme, onTheme, weight, onWeight, onFocus, onGenerate }) {
  const preset = presetFor(weight);

  return (
    <header className="app-header">
      <div className="brand">
        Math<em>Drill</em>
      </div>

      <div className="solve-pill">
        <i>
          <IconSolve size={20} />
        </i>
        Solve
      </div>

      <div className="header-right">
        <div className="segmented" role="group" aria-label="Colour theme">
          <button type="button" aria-pressed={theme === 'light'} onClick={() => onTheme('light')}>
            <IconSun size={14} />
            Light
          </button>
          <button type="button" aria-pressed={theme === 'dark'} onClick={() => onTheme('dark')}>
            <IconMoon size={14} />
            Dark
          </button>
        </div>

        <div className="control-pill">
          <span>Line Weight</span>
          <input
            type="range"
            min={1}
            max={10}
            step={0.5}
            value={weight}
            onChange={(event) => onWeight(Number(event.target.value))}
            aria-label="Default line weight"
          />
          <output>{preset[0].toUpperCase() + preset.slice(1)}</output>
        </div>

        <button type="button" className="ghost-btn" onClick={onFocus} title="Show only the steps and diagram">
          <IconFocus size={15} /> Focus
        </button>

        <button type="button" className="btn primary" onClick={onGenerate}>
          <IconSparkle size={15} /> AI Generate
        </button>

        <div className="avatar" title="Signed-in student">
          S
        </div>
      </div>
    </header>
  );
}
