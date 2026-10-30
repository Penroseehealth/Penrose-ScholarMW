import { useEffect, useRef, useState } from 'react';
import { IconDashboard, IconPractice, IconSolve, IconProgress, IconPapers, IconSettings } from './icons';

const NAV = [
  { id: 'dashboard', label: 'Dashboard', Icon: IconDashboard },
  { id: 'practice', label: 'Practice', Icon: IconPractice },
  { id: 'solve', label: 'Solve', Icon: IconSolve },
  { id: 'progress', label: 'My Progress', Icon: IconProgress },
  { id: 'papers', label: 'Past Papers', Icon: IconPapers },
  { id: 'settings', label: 'Settings', Icon: IconSettings },
];

export default function Rail({ onNavigate }) {
  const [current, setCurrent] = useState('solve');

  function go(id) {
    setCurrent(id);
    onNavigate?.(id);
  }

  return (
    <aside className="rail" aria-label="MathDrill navigation">
      <div className="rail-brand">
        <svg width="30" height="30" viewBox="0 0 32 32" aria-hidden="true">
          <defs>
            <linearGradient id="railMark" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#60a5fa" />
              <stop offset="100%" stopColor="#22d3ee" />
            </linearGradient>
          </defs>
          <path d="M16 3l12 26H4z" fill="none" stroke="url(#railMark)" strokeWidth="2.2" strokeLinejoin="round" />
          <path d="M16 11l6.5 14h-13z" fill="rgba(96,165,250,0.25)" stroke="url(#railMark)" strokeWidth="1.4" />
        </svg>
        <span className="brand-name">
          Math<em>Drill</em>
        </span>
      </div>

      <nav className="rail-nav">
        {NAV.map(({ id, label, Icon }) => (
          <button
            key={id}
            type="button"
            className="rail-item"
            aria-current={current === id ? 'page' : undefined}
            onClick={() => go(id)}
          >
            <Icon size={19} />
            {label}
          </button>
        ))}
      </nav>

      <div className="rail-foot">
        <svg width="42" height="42" viewBox="0 0 32 32" aria-hidden="true">
          <path d="M16 3l12 26H4z" fill="none" stroke="#7c5cff" strokeWidth="2" strokeLinejoin="round" />
          <path d="M16 12l5 13h-10z" fill="rgba(124,92,255,0.25)" stroke="#7c5cff" strokeWidth="1.2" />
        </svg>
        <strong>MathDrill</strong>
        <span>Learn · Practice · Excel</span>
      </div>
    </aside>
  );
}
