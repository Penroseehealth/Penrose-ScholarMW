import { useMemo, useState } from 'react';
import { INK_COLORS } from '../lib/palette';
import { WEIGHT_MAX, WEIGHT_MIN, presetFor } from '../state/worksheet';
import {
  IconArrow,
  IconCircle,
  IconDuplicate,
  IconEraser,
  IconLabel,
  IconLasso,
  IconLayers,
  IconLine,
  IconMath,
  IconPolygon,
  IconRect,
  IconSave,
  IconText,
  IconTrash,
} from './icons';

const TOOLS = [
  { id: 'line', label: 'Line', Icon: IconLine },
  { id: 'arrow', label: 'Arrow', Icon: IconArrow },
  { id: 'rect', label: 'Rectangle', Icon: IconRect },
  { id: 'ellipse', label: 'Circle', Icon: IconCircle },
  { id: 'triangle', label: 'Triangle', Icon: IconPolygon },
  { id: 'polygon', label: 'Polygon', Icon: IconPolygon },
  { id: 'text', label: 'Text', Icon: IconText },
  { id: 'math', label: 'Label', Icon: IconLabel },
];

export default function DrawingsStrip({
  tool,
  onTool,
  color,
  onColor,
  selection,
  selectedObject,
  weight,
  onWeight,
  onDelete,
  onDuplicate,
  onLayer,
  onClear,
  onSave,
  saved,
  regionMode,
  onRegionMode,
}) {
  const activeWeight = selectedObject?.weight ?? weight;
  const [layerOpen, setLayerOpen] = useState(false);

  const hint = useMemo(() => {
    if (!selectedObject) return 'Select an object to style it individually.';
    return `Selected: ${selectedObject.type} · weight ${activeWeight}`;
  }, [selectedObject, activeWeight]);

  return (
    <section className="strip" aria-label="Drawings and elements">
      <span className="strip-title">Drawings &amp; Elements</span>

      <div className="strip-tools">
        {TOOLS.map(({ id, label, Icon }) => (
          <button
            key={id}
            type="button"
            className="strip-tool"
            aria-pressed={tool === id}
            onClick={() => onTool(id)}
            title={label}
          >
            <Icon size={19} />
            {label}
          </button>
        ))}
      </div>

      <div className="strip-colors">
        <span>Color</span>
        <div className="swatches">
          {INK_COLORS.map((value) => (
            <button
              key={value}
              type="button"
              className="swatch"
              style={{ background: value }}
              aria-pressed={color === value}
              aria-label={`Ink colour ${value}`}
              onClick={() => onColor(value)}
            />
          ))}
        </div>
      </div>

      <div className="strip-actions">
        <label className="weight-select">
          Weight
          <select
            value={presetFor(activeWeight)}
            onChange={(event) => onWeight(Number(event.target.value))}
            aria-label={selectedObject ? 'Line weight for the selected object' : 'Default line weight'}
          >
            <option value={WEIGHT_MIN + 0.5}>Thin (1.5)</option>
            <option value={3}>Normal (3)</option>
            <option value={WEIGHT_MAX - 4}>Thick (6)</option>
          </select>
        </label>

        <label className="weight-select">
          Region
          <select
            value={regionMode}
            onChange={(event) => onRegionMode(event.target.value)}
            aria-label="Region eraser mode"
          >
            <option value="inside">Fully inside</option>
            <option value="touching">Touching</option>
          </select>
        </label>

        <div style={{ position: 'relative' }}>
          <button
            type="button"
            className="ghost-btn"
            onClick={() => setLayerOpen((open) => !open)}
            aria-expanded={layerOpen}
            title="Layer order"
            disabled={!selectedObject}
          >
            <IconLayers size={15} /> Order
          </button>
          {layerOpen && selectedObject ? (
            <div
              className="card"
              style={{ position: 'absolute', right: 0, bottom: 'calc(100% + 6px)', zIndex: 10, padding: 6, gap: 2 }}
            >
              <button type="button" className="ghost-btn" onClick={() => onLayer('front')}>
                Bring to front
              </button>
              <button type="button" className="ghost-btn" onClick={() => onLayer('forward')}>
                Bring forward
              </button>
              <button type="button" className="ghost-btn" onClick={() => onLayer('backward')}>
                Send backward
              </button>
              <button type="button" className="ghost-btn" onClick={() => onLayer('back')}>
                Send to back
              </button>
            </div>
          ) : null}
        </div>

        <button type="button" className="ghost-btn" onClick={onDuplicate} disabled={!selectedObject} title="Duplicate">
          <IconDuplicate size={15} /> Duplicate
        </button>

        <button type="button" className="ghost-btn" onClick={onClear} title="Clear the whole board">
          <IconTrash size={15} /> Clear All
        </button>

        <button type="button" className="btn primary" onClick={onSave} title="Save this worksheet">
          <IconSave size={15} /> {saved ? 'Saved' : 'Save'}
        </button>
      </div>

      <span className="status-line" style={{ flexBasis: '100%' }}>
        {hint} <span aria-hidden="true">·</span> Duster tool: <IconEraser size={12} /> erases stroke portions;
        Lasso <IconLasso size={12} /> erases regions. <IconMath size={12} /> adds editable maths labels.
      </span>
    </section>
  );
}
