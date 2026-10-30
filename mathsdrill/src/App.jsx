import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Rail from './components/Rail';
import Header from './components/Header';
import SolutionPanel from './components/SolutionPanel';
import Stage from './components/Stage';
import DrawingsStrip from './components/DrawingsStrip';
import UploadPanel from './components/UploadPanel';
import AiPanel from './components/AiPanel';
import { IconFocus } from './components/icons';
import { paletteFor } from './lib/palette';
import { loadDoc, nextId, persistDoc } from './state/worksheet';

const DEMO_SOLUTION = {
  status: 'ready',
  demo: true,
  source: 'demo',
  question: 'Find the coordinates of the vertices of the triangle formed by the lines x + y = 20, x = 0 and y = 0.',
  steps: [
    { title: 'Step 1', text: 'Find the intercepts with the axes.' },
    { title: 'Step 2', text: 'When $x = 0$ (y-axis): $y = 20$ → $(0, 20)$.' },
    { title: 'Step 3', text: 'When $y = 0$ (x-axis): $x = 20$ → $(20, 0)$.' },
    { title: 'Step 4', text: 'The third vertex is the origin $(0, 0)$.' },
  ],
  answerLatex: '(0, 0),\\ (20, 0)\\ \\text{ and }\\ (0, 20)',
};

function demoObjects(color) {
  return [
    {
      id: nextId('demo'),
      type: 'polygon',
      points: [
        [500, 150],
        [700, 350],
        [500, 350],
      ],
      color: '#22d3ee',
      weight: 3,
      rotation: 0,
      opacity: 1,
      fill: 'rgba(34, 211, 238, 0.18)',
    },
    {
      id: nextId('demo'),
      type: 'text',
      x: 470,
      y: 138,
      text: '(0, 20)',
      size: 18,
      color,
      weight: 2,
      rotation: 0,
      opacity: 1,
      fill: 'none',
    },
    {
      id: nextId('demo'),
      type: 'text',
      x: 706,
      y: 372,
      text: '(20, 0)',
      size: 18,
      color,
      weight: 2,
      rotation: 0,
      opacity: 1,
      fill: 'none',
    },
  ];
}

export default function App() {
  const [doc, setDoc] = useState(loadDoc);
  const [theme, setTheme] = useState(() => document.documentElement.dataset.theme || 'dark');
  const [focus, setFocus] = useState(false);
  const [tool, setTool] = useState('select');
  const [color, setColor] = useState('#ffd54a');
  const [eraserSize, setEraserSize] = useState(26);
  const [regionMode, setRegionMode] = useState('inside');
  const [selection, setSelection] = useState(null);
  const [dirty, setDirty] = useState(false);
  const [saved, setSaved] = useState(true);
  const [confirmClear, setConfirmClear] = useState(false);
  const [question, setQuestion] = useState('');
  const [aiFocusToken, setAiFocusToken] = useState(0);
  const [solution, setSolution] = useState({ status: 'idle', steps: [] });
  const [, bumpHistory] = useState(0);

  const docRef = useRef(doc);
  const past = useRef([]);
  const future = useRef([]);

  useEffect(() => {
    docRef.current = doc;
  }, [doc]);

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    try {
      localStorage.setItem('mathdrill.theme', theme);
    } catch {
      /* storage blocked */
    }
  }, [theme]);

  useEffect(() => {
    const timer = setTimeout(() => persistDoc(doc), 350);
    return () => clearTimeout(timer);
  }, [doc]);

  useEffect(() => {
    function warn(event) {
      if (!dirty) return;
      event.preventDefault();
      event.returnValue = '';
    }
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [dirty]);

  const beginHistory = useCallback(() => {
    past.current.push(docRef.current);
    if (past.current.length > 80) past.current.shift();
    future.current = [];
    bumpHistory((value) => value + 1);
  }, []);

  const previewObjects = useCallback((updater) => {
    setDoc((previous) => ({
      ...previous,
      objects: typeof updater === 'function' ? updater(previous.objects) : updater,
    }));
    setDirty(true);
    setSaved(false);
  }, []);

  const commitObjects = useCallback(
    (updater) => {
      beginHistory();
      previewObjects(updater);
    },
    [beginHistory, previewObjects],
  );

  const undo = useCallback(() => {
    const previous = past.current.pop();
    if (!previous) return;
    future.current.push(docRef.current);
    setDoc(previous);
    setSelection(null);
    setDirty(true);
    setSaved(false);
    bumpHistory((value) => value + 1);
  }, []);

  const redo = useCallback(() => {
    const next = future.current.pop();
    if (!next) return;
    past.current.push(docRef.current);
    setDoc(next);
    setSelection(null);
    setDirty(true);
    setSaved(false);
    bumpHistory((value) => value + 1);
  }, []);

  const selectedObject = doc.objects.find((object) => object.id === selection) || null;
  const palette = useMemo(() => paletteFor(theme), [theme]);

  const deleteSelection = useCallback(() => {
    if (!selection) return;
    commitObjects((objects) => objects.filter((object) => object.id !== selection));
    setSelection(null);
  }, [commitObjects, selection]);

  const duplicateSelection = useCallback(() => {
    if (!selection) return;
    const source = docRef.current.objects.find((object) => object.id === selection);
    if (!source) return;
    const clone = JSON.parse(JSON.stringify(source));
    clone.id = nextId();
    if (clone.points) clone.points = clone.points.map(([x, y]) => [x + 18, y + 18]);
    if (clone.type === 'line' || clone.type === 'arrow') {
      clone.x1 += 18;
      clone.y1 += 18;
      clone.x2 += 18;
      clone.y2 += 18;
    } else if (clone.type === 'ellipse') {
      clone.cx += 18;
      clone.cy += 18;
    } else {
      clone.x = (clone.x ?? 0) + 18;
      clone.y = (clone.y ?? 0) + 18;
    }
    commitObjects((objects) => [...objects, clone]);
    setSelection(clone.id);
  }, [commitObjects, selection]);

  const changeLayer = useCallback(
    (direction) => {
      if (!selection) return;
      commitObjects((objects) => {
        const index = objects.findIndex((object) => object.id === selection);
        if (index === -1) return objects;
        const next = [...objects];
        const [item] = next.splice(index, 1);
        if (direction === 'front') next.push(item);
        else if (direction === 'back') next.unshift(item);
        else if (direction === 'forward') next.splice(Math.min(index + 1, next.length), 0, item);
        else next.splice(Math.max(index - 1, 0), 0, item);
        return next;
      });
    },
    [commitObjects, selection],
  );

  const applyWeight = useCallback(
    (weight) => {
      if (selectedObject) {
        commitObjects((objects) => objects.map((object) => (object.id === selection ? { ...object, weight } : object)));
      } else {
        setDoc((previous) => ({ ...previous, weight }));
      }
    },
    [commitObjects, selectedObject, selection],
  );

  useEffect(() => {
    function onKey(event) {
      const target = event.target;
      const typing = target instanceof HTMLElement && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName);
      if (typing || target?.isContentEditable) return;

      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z') {
        event.preventDefault();
        if (event.shiftKey) redo();
        else undo();
        return;
      }
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'y') {
        event.preventDefault();
        redo();
        return;
      }
      if (event.key === 'Delete' || event.key === 'Backspace') {
        if (selection) {
          event.preventDefault();
          deleteSelection();
        }
        return;
      }
      if (event.key === 'Escape') setSelection(null);
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [deleteSelection, redo, selection, undo]);

  const loadDemo = useCallback(() => {
    setSolution(DEMO_SOLUTION);
    commitObjects(() => demoObjects(color));
    setSelection(null);
  }, [color, commitObjects]);

  const saveWorksheet = useCallback(() => {
    const ok = persistDoc(docRef.current);
    setDirty(!ok);
    setSaved(ok);
  }, []);

  return (
    <div className="app" data-focus={focus ? 'on' : 'off'}>
      <Rail />

      <div className="shell">
        <Header
          theme={theme}
          onTheme={setTheme}
          weight={selectedObject?.weight ?? doc.weight}
          onWeight={applyWeight}
          onFocus={() => setFocus(true)}
          onGenerate={() => {
            setAiFocusToken((value) => value + 1);
            document.getElementById('mathdrill-question')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }}
        />

        <main className="workspace">
          {focus ? (
            <button type="button" className="focus-exit" onClick={() => setFocus(false)}>
              <IconFocus size={14} /> Exit Focus
            </button>
          ) : null}

          <div className="work-grid">
            <SolutionPanel solution={solution} onDemo={loadDemo} />
            <Stage
              objects={doc.objects}
              palette={palette}
              tool={tool}
              onTool={setTool}
              color={color}
              weight={doc.weight}
              eraserSize={eraserSize}
              onEraserSize={setEraserSize}
              regionMode={regionMode}
              selection={selection}
              onSelect={setSelection}
              beginHistory={beginHistory}
              previewObjects={previewObjects}
              commitObjects={commitObjects}
              onUndo={undo}
              onRedo={redo}
              canUndo={past.current.length > 0}
              canRedo={future.current.length > 0}
              onDelete={deleteSelection}
            />
          </div>

          <DrawingsStrip
            tool={tool}
            onTool={setTool}
            color={color}
            onColor={setColor}
            selection={selection}
            selectedObject={selectedObject}
            weight={doc.weight}
            onWeight={applyWeight}
            onDelete={deleteSelection}
            onDuplicate={duplicateSelection}
            onLayer={changeLayer}
            onClear={() => setConfirmClear(true)}
            onSave={saveWorksheet}
            saved={saved}
            regionMode={regionMode}
            onRegionMode={setRegionMode}
          />

          <div className="bottom-grid">
            <UploadPanel
              onExtractedText={(text) => {
                setQuestion(text);
                setAiFocusToken((value) => value + 1);
              }}
            />
            <AiPanel
              question={question}
              setQuestion={setQuestion}
              focusToken={aiFocusToken}
              onStart={() => setSolution({ status: 'loading', steps: [] })}
              onResult={(payload) => setSolution({ status: 'ready', demo: false, ...payload })}
              onFailure={(message) =>
                setSolution((previous) =>
                  previous.status === 'ready' ? previous : { status: 'error', steps: [], error: message },
                )
              }
            />
          </div>
        </main>
      </div>

      {confirmClear ? (
        <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label="Clear board">
          <div className="modal">
            <h3>Clear the whole board?</h3>
            <p>
              This removes every drawing, label and maths object on the worksheet. Steps and the question stay.
              You can undo this action.
            </p>
            <div className="modal-actions">
              <button type="button" className="btn" onClick={() => setConfirmClear(false)}>
                Cancel
              </button>
              <button
                type="button"
                className="btn danger"
                onClick={() => {
                  commitObjects(() => []);
                  setSelection(null);
                  setConfirmClear(false);
                }}
              >
                Clear board
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
