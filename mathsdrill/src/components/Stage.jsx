import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import katex from 'katex';
import {
  VIEW_H,
  VIEW_W,
  bbox,
  centerOf,
  clamp,
  degBetween,
  eraseStroke,
  hitTest,
  interiorPoints,
  moveObject,
  outlinePoints,
  pointInPolygon,
  rotatePoint,
  scaleObject,
  toLocal,
} from '../lib/geometry';
import { nextId, presetFor } from '../state/worksheet';
import {
  IconEraser,
  IconFocus,
  IconLasso,
  IconMath,
  IconPen,
  IconRedo,
  IconSelect,
  IconText,
  IconTrash,
  IconUndo,
  IconZoomIn,
  IconZoomOut,
} from './icons';

const SHAPE_TOOLS = new Set(['line', 'arrow', 'rect', 'ellipse', 'triangle']);

const TOOL_LABEL = {
  select: 'Select',
  draw: 'Draw',
  line: 'Line',
  arrow: 'Arrow',
  rect: 'Rectangle',
  ellipse: 'Circle',
  triangle: 'Triangle',
  polygon: 'Polygon',
  text: 'Text',
  math: 'Maths label',
  eraser: 'Duster',
  lasso: 'Region eraser',
};

function dist(a, b) {
  return Math.hypot(a[0] - b[0], a[1] - b[1]);
}

function rotateHandles(obj) {
  const b = bbox(obj);
  const c = [b.x + b.w / 2, b.y + b.h / 2];
  const rot = obj.rotation || 0;
  const corners = [
    [b.x, b.y],
    [b.x + b.w, b.y],
    [b.x + b.w, b.y + b.h],
    [b.x, b.y + b.h],
  ].map((point) => rotatePoint(point, c, rot));
  return { corners, rotate: rotatePoint([c[0], b.y - 30], c, rot), center: c, box: b };
}

function objectFromDrag(tool, start, current, style) {
  const [ax, ay] = start;
  const [bx, by] = current;
  const x = Math.min(ax, bx);
  const y = Math.min(ay, by);
  const w = Math.abs(bx - ax);
  const h = Math.abs(by - ay);
  const base = {
    id: nextId(),
    rotation: 0,
    fill: 'none',
    opacity: 1,
    weight: style.weight,
    color: style.color,
  };
  if (tool === 'line' || tool === 'arrow') {
    return { ...base, type: tool, x1: ax, y1: ay, x2: bx, y2: by };
  }
  if (tool === 'ellipse') {
    return { ...base, type: 'ellipse', cx: x + w / 2, cy: y + h / 2, rx: Math.max(w / 2, 4), ry: Math.max(h / 2, 4) };
  }
  return { ...base, type: tool, x, y, w: Math.max(w, 6), h: Math.max(h, 6) };
}

function ArrowHead({ obj }) {
  const angle = Math.atan2(obj.y2 - obj.y1, obj.x2 - obj.x1);
  const size = 8 + obj.weight * 1.6;
  const p1 = [obj.x2 - Math.cos(angle - 0.4) * size, obj.y2 - Math.sin(angle - 0.4) * size];
  const p2 = [obj.x2 - Math.cos(angle + 0.4) * size, obj.y2 - Math.sin(angle + 0.4) * size];
  return <polygon points={`${obj.x2},${obj.y2} ${p1[0]},${p1[1]} ${p2[0]},${p2[1]}`} fill={obj.color} />;
}

function eraseAt(baseObjects, path, radius) {
  const result = [];
  for (const object of baseObjects) {
    if (object.type === 'stroke') {
      result.push(...eraseStroke(object, path, radius));
      continue;
    }
    const points = outlinePoints(object);
    const covered = points.every(([x, y]) => path.some(([px, py]) => Math.hypot(x - px, y - py) <= radius));
    if (!covered) result.push(object);
  }
  return result;
}

function eraseRegion(baseObjects, polygon, mode) {
  return baseObjects.filter((object) => {
    if (object.type === 'stroke') {
      const inside = object.points.filter((point) => pointInPolygon(point, polygon)).length;
      if (!inside) return true;
      const total = object.points.length;
      return mode === 'inside' ? inside < total : false;
    }
    const points = interiorPoints(object);
    const inside = points.filter((point) => pointInPolygon(point, polygon)).length;
    if (mode === 'inside') return inside !== points.length;
    return inside === 0;
  });
}

export default function Stage({
  objects,
  palette,
  tool,
  onTool,
  color,
  weight,
  eraserSize,
  onEraserSize,
  regionMode,
  selection,
  onSelect,
  beginHistory,
  previewObjects,
  onUndo,
  onRedo,
  canUndo,
  canRedo,
  onDelete,
  focus,
  onFocus,
}) {
  const svgRef = useRef(null);
  const gesture = useRef(null);
  const [zoom, setZoom] = useState(1);
  const [draft, setDraft] = useState(null);
  const [polygonPoints, setPolygonPoints] = useState([]);
  const [cursor, setCursor] = useState(null);
  const [editing, setEditing] = useState(null);

  const view = useMemo(() => {
    const width = VIEW_W / zoom;
    const height = VIEW_H / zoom;
    return { x: (VIEW_W - width) / 2, y: (VIEW_H - height) / 2, width, height };
  }, [zoom]);

  const toPoint = useCallback(
    (event) => {
      const rect = svgRef.current.getBoundingClientRect();
      const x = view.x + ((event.clientX - rect.left) / rect.width) * view.width;
      const y = view.y + ((event.clientY - rect.top) / rect.height) * view.height;
      return [clamp(x, 0, VIEW_W), clamp(y, 0, VIEW_H)];
    },
    [view],
  );

  const selected = objects.find((object) => object.id === selection) || null;

  const startTextEditor = useCallback(
    (point, kind) => {
      beginHistory();
      const isMath = kind === 'math';
      const object = {
        id: nextId(isMath ? 'm' : 't'),
        type: isMath ? 'math' : 'text',
        x: point[0],
        y: point[1],
        text: isMath ? 'x^2 + y^2 = r^2' : 'Label',
        size: isMath ? 26 : 22,
        color,
        weight,
        rotation: 0,
        opacity: 1,
        fill: 'none',
      };
      previewObjects((previous) => [...previous, object]);
      onSelect(object.id);
      setEditing({ id: object.id, value: object.text, kind: object.type, isNew: true });
    },
    [beginHistory, color, onSelect, previewObjects, weight],
  );

  const onPointerDown = (event) => {
    if (event.button !== 0 && event.pointerType === 'mouse') return;
    if (editing) return;
    const point = toPoint(event);
    svgRef.current.setPointerCapture?.(event.pointerId);

    if (tool === 'select') {
      if (selected) {
        const handles = rotateHandles(selected);
        const tolerance = 11 / zoom;
        if (dist(point, handles.rotate) <= tolerance) {
          beginHistory();
          gesture.current = {
            mode: 'rotate',
            id: selected.id,
            base: objects,
            center: centerOf(selected),
            offset: degBetween(centerOf(selected), point) - (selected.rotation || 0),
          };
          return;
        }
        const corner = handles.corners.findIndex((handle) => dist(point, handle) <= tolerance);
        if (corner >= 0) {
          beginHistory();
          gesture.current = { mode: 'resize', id: selected.id, base: objects, corner };
          return;
        }
      }
      const hit = [...objects].reverse().find((object) => hitTest(object, point));
      if (!hit) {
        onSelect(null);
        return;
      }
      onSelect(hit.id);
      beginHistory();
      gesture.current = { mode: 'move', id: hit.id, base: objects, start: point };
      return;
    }

    if (tool === 'draw') {
      beginHistory();
      gesture.current = { mode: 'draw', base: objects, points: [point] };
      setDraft({ kind: 'stroke', points: [point] });
      return;
    }

    if (SHAPE_TOOLS.has(tool)) {
      beginHistory();
      gesture.current = { mode: 'shape', base: objects, tool, start: point };
      setDraft({ kind: 'shape', tool, start: point, current: point });
      return;
    }

    if (tool === 'polygon') {
      if (!polygonPoints.length) beginHistory();
      setPolygonPoints((points) => [...points, point]);
      return;
    }

    if (tool === 'text' || tool === 'math') {
      startTextEditor(point, tool);
      return;
    }

    if (tool === 'eraser') {
      beginHistory();
      const radius = eraserSize / 2;
      gesture.current = { mode: 'erase', base: objects, path: [point] };
      setDraft({ kind: 'eraser', path: [point] });
      previewObjects(() => eraseAt(objects, [point], radius));
      return;
    }

    if (tool === 'lasso') {
      gesture.current = { mode: 'lasso', path: [point] };
      setDraft({ kind: 'lasso', path: [point] });
    }
  };

  const onPointerMove = (event) => {
    const point = toPoint(event);
    if (tool === 'eraser' || tool === 'lasso') setCursor(point);
    const active = gesture.current;
    if (!active) return;

    if (active.mode === 'move') {
      const dx = point[0] - active.start[0];
      const dy = point[1] - active.start[1];
      const base = active.base.find((object) => object.id === active.id);
      previewObjects((previous) =>
        previous.map((object) => (object.id === active.id ? moveObject(base, dx, dy) : object)),
      );
      return;
    }

    if (active.mode === 'rotate') {
      const angle = degBetween(active.center, point) - active.offset;
      const base = active.base.find((object) => object.id === active.id);
      previewObjects((previous) =>
        previous.map((object) => (object.id === active.id ? { ...base, rotation: angle } : object)),
      );
      return;
    }

    if (active.mode === 'resize') {
      const base = active.base.find((object) => object.id === active.id);
      const box = bbox(base);
      const corners = [
        [box.x, box.y],
        [box.x + box.w, box.y],
        [box.x + box.w, box.y + box.h],
        [box.x, box.y + box.h],
      ];
      const corner = corners[active.corner];
      const anchor = corners[(active.corner + 2) % 4];
      const local = toLocal(point, base);
      const sxRaw = Math.abs(corner[0] - anchor[0]) < 1 ? 1 : (local[0] - anchor[0]) / (corner[0] - anchor[0]);
      const syRaw = Math.abs(corner[1] - anchor[1]) < 1 ? 1 : (local[1] - anchor[1]) / (corner[1] - anchor[1]);
      const sx = Math.max(0.08, Math.abs(sxRaw));
      const sy = Math.max(0.08, Math.abs(syRaw));
      const scaled = scaleObject(base, sx, sy);
      const shift = [anchor[0] - (box.x + (anchor[0] - box.x) * sx), anchor[1] - (box.y + (anchor[1] - box.y) * sy)];
      const moved = moveObject(scaled, shift[0], shift[1]);
      previewObjects((previous) => previous.map((object) => (object.id === active.id ? moved : object)));
      return;
    }

    if (active.mode === 'draw') {
      active.points.push(point);
      setDraft({ kind: 'stroke', points: [...active.points] });
      return;
    }

    if (active.mode === 'shape') {
      setDraft({ kind: 'shape', tool: active.tool, start: active.start, current: point });
      return;
    }

    if (active.mode === 'erase') {
      active.path.push(point);
      setDraft({ kind: 'eraser', path: [...active.path] });
      previewObjects(() => eraseAt(active.base, active.path, eraserSize / 2));
      return;
    }

    if (active.mode === 'lasso') {
      active.path.push(point);
      setDraft({ kind: 'lasso', path: [...active.path] });
    }
  };

  const finishGesture = () => {
    const active = gesture.current;
    gesture.current = null;
    if (!active) return;

    if (active.mode === 'draw') {
      if (active.points.length > 1) {
        const stroke = {
          id: nextId('s'),
          type: 'stroke',
          points: active.points,
          color,
          weight,
          rotation: 0,
          opacity: 1,
          fill: 'none',
        };
        previewObjects((previous) => [...previous, stroke]);
        onSelect(stroke.id);
      }
      setDraft(null);
      return;
    }

    if (active.mode === 'shape') {
      const { start } = active;
      const end = draft?.current || start;
      if (dist(start, end) > 4) {
        const object = objectFromDrag(active.tool, start, end, { color, weight });
        previewObjects((previous) => [...previous, object]);
        onSelect(object.id);
        onTool('select');
      }
      setDraft(null);
      return;
    }

    if (active.mode === 'lasso') {
      const polygon = active.path;
      if (polygon.length > 3) {
        beginHistory();
        previewObjects(() => eraseRegion(objects, polygon, regionMode));
      }
      setDraft(null);
      return;
    }

    setDraft(null);
  };

  const finishPolygon = useCallback(() => {
    if (polygonPoints.length < 3) {
      setPolygonPoints([]);
      return;
    }
    const object = {
      id: nextId('p'),
      type: 'polygon',
      points: polygonPoints,
      color,
      weight,
      rotation: 0,
      opacity: 1,
      fill: 'none',
    };
    previewObjects((previous) => [...previous, object]);
    onSelect(object.id);
    setPolygonPoints([]);
    onTool('select');
  }, [color, onSelect, onTool, polygonPoints, previewObjects, weight]);

  useEffect(() => {
    function onKey(event) {
      if (editing) return;
      if (event.key === 'Escape') {
        setPolygonPoints([]);
        setDraft(null);
        gesture.current = null;
      }
      if (event.key === 'Enter' && polygonPoints.length >= 3) {
        event.preventDefault();
        finishPolygon();
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [editing, finishPolygon, polygonPoints.length]);

  const openEditor = (object) => {
    if (object.type !== 'text' && object.type !== 'math') return;
    beginHistory();
    setEditing({ id: object.id, value: object.text, kind: object.type, isNew: false });
  };

  const saveEditing = () => {
    if (!editing) return;
    previewObjects((previous) =>
      previous.map((object) => (object.id === editing.id ? { ...object, text: editing.value } : object)),
    );
    setEditing(null);
  };

  const renderObject = (object) => {
    const rot = object.rotation || 0;
    const center = centerOf(object);
    const transform = rot ? `rotate(${rot} ${center[0]} ${center[1]})` : undefined;
    const stroke = object.color;
    const common = {
      stroke,
      strokeWidth: object.weight,
      fill: object.fill || 'none',
      opacity: object.opacity ?? 1,
      strokeLinecap: 'round',
      strokeLinejoin: 'round',
      transform,
      key: object.id,
    };

    switch (object.type) {
      case 'stroke':
        return (
          <polyline
            {...common}
            points={object.points.map((point) => point.join(',')).join(' ')}
            fill="none"
            pointerEvents="none"
          />
        );
      case 'line':
        return <line {...common} x1={object.x1} y1={object.y1} x2={object.x2} y2={object.y2} pointerEvents="none" />;
      case 'arrow':
        return (
          <g {...common} pointerEvents="none">
            <line x1={object.x1} y1={object.y1} x2={object.x2} y2={object.y2} stroke={stroke} strokeWidth={object.weight} />
            <ArrowHead obj={object} />
          </g>
        );
      case 'rect':
        return <rect {...common} x={object.x} y={object.y} width={object.w} height={object.h} rx={3} pointerEvents="none" />;
      case 'ellipse':
        return <ellipse {...common} cx={object.cx} cy={object.cy} rx={object.rx} ry={object.ry} pointerEvents="none" />;
      case 'triangle':
        return (
          <polygon
            {...common}
            points={`${object.x + object.w / 2},${object.y} ${object.x + object.w},${object.y + object.h} ${object.x},${object.y + object.h}`}
            pointerEvents="none"
          />
        );
      case 'polygon':
        return (
          <polygon {...common} points={object.points.map((point) => point.join(',')).join(' ')} pointerEvents="none" />
        );
      case 'text':
        return (
          <text
            {...common}
            x={object.x}
            y={object.y}
            fontSize={object.size}
            fontFamily="Inter, system-ui, sans-serif"
            fontWeight={600}
            fill={object.color}
            stroke="none"
            onDoubleClick={() => openEditor(object)}
            style={{ cursor: 'move' }}
          >
            {object.text}
          </text>
        );
      case 'math': {
        const box = bbox(object);
        return (
          <foreignObject
            key={object.id}
            x={box.x}
            y={box.y}
            width={box.w + 30}
            height={box.h + 16}
            transform={transform}
            onDoubleClick={() => openEditor(object)}
            style={{ overflow: 'visible', cursor: 'move' }}
          >
            <div
              xmlns="http://www.w3.org/1999/xhtml"
              style={{ color: object.color, fontSize: `${object.size}px`, lineHeight: 1.35, whiteSpace: 'nowrap' }}
              dangerouslySetInnerHTML={{
                __html: katex.renderToString(object.text || '\\;', { throwOnError: false }),
              }}
            />
          </foreignObject>
        );
      }
      default:
        return null;
    }
  };

  const gridLines = [];
  for (let x = 0; x <= VIEW_W; x += 25) {
    const major = x % 100 === 0;
    gridLines.push(
      <line
        key={`v${x}`}
        x1={x}
        y1={0}
        x2={x}
        y2={VIEW_H}
        stroke={major ? palette.gridMajor : palette.grid}
        strokeWidth={major ? 1 : 0.6}
      />,
    );
  }
  for (let y = 0; y <= VIEW_H; y += 25) {
    const major = y % 100 === 0;
    gridLines.push(
      <line
        key={`h${y}`}
        x1={0}
        y1={y}
        x2={VIEW_W}
        y2={y}
        stroke={major ? palette.gridMajor : palette.grid}
        strokeWidth={major ? 1 : 0.6}
      />,
    );
  }

  const originX = 500;
  const originY = 350;
  const ticks = [];
  for (let i = -4; i <= 4; i += 1) {
    if (!i) continue;
    ticks.push(
      <g key={`tx${i}`}>
        <line x1={originX + i * 50} y1={originY - 4} x2={originX + i * 50} y2={originY + 4} stroke={palette.axis} strokeWidth={1.4} />
        <text x={originX + i * 50} y={originY + 18} fill={palette.tick} fontSize={10} textAnchor="middle" stroke="none">
          {i > 0 ? i * 5 : i * 5}
        </text>
      </g>,
    );
    ticks.push(
      <g key={`ty${i}`}>
        <line x1={originX - 4} y1={originY - i * 50} x2={originX + 4} y2={originY - i * 50} stroke={palette.axis} strokeWidth={1.4} />
        <text x={originX - 10} y={originY - i * 50 + 3} fill={palette.tick} fontSize={10} textAnchor="end" stroke="none">
          {i * 5}
        </text>
      </g>,
    );
  }

  const handles = selected ? rotateHandles(selected) : null;

  return (
    <section className="card stage-card" aria-label="Diagram">
      <div className="stage-head">
        <h2 style={{ margin: 0, fontSize: 14, fontWeight: 600 }}>{TOOL_LABEL[tool] || 'Select'}</h2>
        <span className="badge">{objects.length} object{objects.length === 1 ? '' : 's'}</span>
        <div className="zoom-group">
          <button type="button" className="icon-btn" onClick={onUndo} disabled={!canUndo} aria-label="Undo" title="Undo (Ctrl+Z)">
            <IconUndo size={16} />
          </button>
          <button type="button" className="icon-btn" onClick={onRedo} disabled={!canRedo} aria-label="Redo" title="Redo (Ctrl+Y)">
            <IconRedo size={16} />
          </button>
        </div>
        <div className="zoom-group">
          <button type="button" className="icon-btn" onClick={() => setZoom((z) => clamp(z / 1.25, 0.5, 3))} aria-label="Zoom out">
            <IconZoomOut size={16} />
          </button>
          <button type="button" className="icon-btn" onClick={() => setZoom((z) => clamp(z * 1.25, 0.5, 3))} aria-label="Zoom in">
            <IconZoomIn size={16} />
          </button>
          <button type="button" className="icon-btn" onClick={() => setZoom(1)} aria-label="Fit to screen" title="Reset zoom">
            <IconFocus size={15} />
          </button>
        </div>
      </div>

      <div className="stage-body">
        <div className="stage-inner">
          <svg
            ref={svgRef}
            className={`stage-svg${tool === 'eraser' || tool === 'lasso' ? ' eraser-tool' : ''}`}
            viewBox={`${view.x} ${view.y} ${view.width} ${view.height}`}
            role="application"
            aria-label="Editable diagram canvas"
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={finishGesture}
            onPointerCancel={finishGesture}
            onPointerLeave={() => setCursor(null)}
            onDoubleClick={() => (polygonPoints.length >= 3 ? finishPolygon() : null)}
          >
            <rect x={0} y={0} width={VIEW_W} height={VIEW_H} fill={palette.canvas} rx={10} />
            <g opacity={0.9}>{gridLines}</g>
            <line x1={0} y1={originY} x2={VIEW_W} y2={originY} stroke={palette.axis} strokeWidth={2} />
            <line x1={originX} y1={0} x2={originX} y2={VIEW_H} stroke={palette.axis} strokeWidth={2} />
            {ticks}
            <text x={VIEW_W - 16} y={originY - 10} fill={palette.axisLabel} fontSize={13} fontStyle="italic" stroke="none">
              x
            </text>
            <text x={originX + 12} y={16} fill={palette.axisLabel} fontSize={13} fontStyle="italic" stroke="none">
              y
            </text>

            {objects.map(renderObject)}

            {draft?.kind === 'stroke' ? (
              <polyline
                points={draft.points.map((point) => point.join(',')).join(' ')}
                fill="none"
                stroke={color}
                strokeWidth={weight}
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            ) : null}

            {draft?.kind === 'shape' ? renderObject(objectFromDrag(draft.tool, draft.start, draft.current, { color, weight })) : null}

            {draft?.kind === 'eraser' ? (
              <g>
                {draft.path.map((point, index) => (
                  <circle key={index} cx={point[0]} cy={point[1]} r={eraserSize / 2} fill="rgba(239,68,68,0.14)" stroke="rgba(239,68,68,0.4)" strokeWidth={1} />
                ))}
              </g>
            ) : null}

            {draft?.kind === 'lasso' && draft.path.length > 1 ? (
              <polygon
                points={draft.path.map((point) => point.join(',')).join(' ')}
                fill="rgba(34,211,238,0.12)"
                stroke={palette.selection}
                strokeWidth={1.6}
                strokeDasharray="6 5"
              />
            ) : null}

            {polygonPoints.length ? (
              <g>
                <polyline
                  points={polygonPoints.map((point) => point.join(',')).join(' ')}
                  fill="rgba(34,211,238,0.08)"
                  stroke={color}
                  strokeWidth={weight}
                  strokeDasharray="7 5"
                />
                {polygonPoints.map((point, index) => (
                  <circle key={index} cx={point[0]} cy={point[1]} r={5} fill={palette.canvas} stroke={color} strokeWidth={2} />
                ))}
              </g>
            ) : null}

            {handles ? (
              <g>
                <polygon
                  points={handles.corners.map((point) => point.join(',')).join(' ')}
                  fill="none"
                  stroke={palette.selection}
                  strokeWidth={1.4 / zoom}
                  strokeDasharray="5 4"
                />
                <line
                  x1={handles.center[0]}
                  y1={handles.corners[0][1] * 0.5 + handles.corners[3][1] * 0.5}
                  x2={handles.rotate[0]}
                  y2={handles.rotate[1]}
                  stroke={palette.selection}
                  strokeWidth={1}
                />
                <circle cx={handles.rotate[0]} cy={handles.rotate[1]} r={5 / zoom} fill={palette.canvas} stroke={palette.selection} strokeWidth={1.6} />
                {handles.corners.map((point, index) => (
                  <rect
                    key={index}
                    x={point[0] - 5 / zoom}
                    y={point[1] - 5 / zoom}
                    width={10 / zoom}
                    height={10 / zoom}
                    fill={palette.handle}
                    stroke={palette.selection}
                    strokeWidth={1.5}
                  />
                ))}
              </g>
            ) : null}

            {cursor && (tool === 'eraser' || tool === 'lasso') ? (
              <circle
                cx={cursor[0]}
                cy={cursor[1]}
                r={tool === 'eraser' ? eraserSize / 2 : 14}
                fill="none"
                stroke={tool === 'eraser' ? '#ef4444' : palette.selection}
                strokeWidth={1.5 / zoom}
                strokeDasharray={tool === 'lasso' ? '4 4' : undefined}
              />
            ) : null}
          </svg>

          {editing ? (
            <div className="editor-pop">
              <label htmlFor="mathdrill-editor">
                {editing.kind === 'math' ? 'LaTeX expression' : 'Label text'}
              </label>
              <textarea
                id="mathdrill-editor"
                value={editing.value}
                autoFocus
                onChange={(event) => setEditing((current) => ({ ...current, value: event.target.value }))}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) saveEditing();
                  if (event.key === 'Escape') setEditing(null);
                }}
              />
              <div className="editor-actions">
                <button type="button" className="btn" onClick={() => setEditing(null)}>
                  Cancel
                </button>
                <button type="button" className="btn primary" onClick={saveEditing}>
                  Apply
                </button>
              </div>
            </div>
          ) : null}
        </div>

        <div className="stage-toolbar" role="toolbar" aria-label="Canvas tools">
          {[
            { id: 'select', Icon: IconSelect, label: 'Select and move' },
            { id: 'draw', Icon: IconPen, label: 'Freehand draw' },
            { id: 'line', Icon: IconPen, label: 'Straight line' },
            { id: 'ellipse', Icon: IconSelect, label: 'Circle' },
            { id: 'rect', Icon: IconSelect, label: 'Rectangle' },
            { id: 'text', Icon: IconText, label: 'Text' },
            { id: 'math', Icon: IconMath, label: 'Maths label' },
            { id: 'eraser', Icon: IconEraser, label: 'Duster' },
            { id: 'lasso', Icon: IconLasso, label: 'Region eraser' },
          ].map(({ id, Icon, label }) => (
            <button
              key={id}
              type="button"
              className="icon-btn"
              aria-pressed={tool === id}
              title={label}
              aria-label={label}
              onClick={() => onTool(id)}
            >
              <Icon size={17} />
            </button>
          ))}
          <div className="divider" />
          <button
            type="button"
            className="icon-btn"
            title="Delete selected object"
            aria-label="Delete selected object"
            onClick={onDelete}
            disabled={!selected}
          >
            <IconTrash size={17} />
          </button>
          <button
            type="button"
            className="icon-btn"
            title={presetFor(weight) === 'thick' ? 'Thick duster' : 'Duster size'}
            aria-label="Cycle duster size"
            onClick={() => onEraserSize(eraserSize >= 48 ? 16 : eraserSize + 16)}
            disabled={tool !== 'eraser'}
          >
            {Math.round(eraserSize)}
          </button>
        </div>
      </div>

      {focus ? null : null}
    </section>
  );
}
