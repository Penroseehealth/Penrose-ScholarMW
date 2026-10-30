export const VIEW_W = 1000;
export const VIEW_H = 700;

export function clamp(v, min, max) {
  return Math.min(max, Math.max(min, v));
}

export function rotatePoint([x, y], [cx, cy], deg) {
  if (!deg) return [x, y];
  const rad = (deg * Math.PI) / 180;
  const cos = Math.cos(rad);
  const sin = Math.sin(rad);
  const dx = x - cx;
  const dy = y - cy;
  return [cx + dx * cos - dy * sin, cy + dx * sin + dy * cos];
}

export function degBetween(from, to) {
  return (Math.atan2(to[1] - from[1], to[0] - from[0]) * 180) / Math.PI;
}

export function trianglePoints(obj) {
  const { x, y, w, h } = obj;
  return [
    [x + w / 2, y],
    [x + w, y + h],
    [x, y + h],
  ];
}

export function ellipsePoints(obj) {
  const { cx, cy, rx, ry } = obj;
  return [
    [cx - rx, cy - ry],
    [cx + rx, cy + ry],
  ];
}

/** Unrotated bounding box. */
export function bbox(obj) {
  switch (obj.type) {
    case 'stroke': {
      if (!obj.points.length) return { x: obj.x || 0, y: obj.y || 0, w: 0, h: 0 };
      let x1 = Infinity;
      let y1 = Infinity;
      let x2 = -Infinity;
      let y2 = -Infinity;
      for (const [px, py] of obj.points) {
        x1 = Math.min(x1, px);
        y1 = Math.min(y1, py);
        x2 = Math.max(x2, px);
        y2 = Math.max(y2, py);
      }
      const pad = (obj.weight || 3) / 2;
      return { x: x1 - pad, y: y1 - pad, w: x2 - x1 + pad * 2, h: y2 - y1 + pad * 2 };
    }
    case 'line':
    case 'arrow': {
      const x = Math.min(obj.x1, obj.x2);
      const y = Math.min(obj.y1, obj.y2);
      return { x, y, w: Math.abs(obj.x2 - obj.x1), h: Math.abs(obj.y2 - obj.y1) };
    }
    case 'ellipse':
      return { x: obj.cx - obj.rx, y: obj.cy - obj.ry, w: obj.rx * 2, h: obj.ry * 2 };
    case 'polygon': {
      const xs = obj.points.map((p) => p[0]);
      const ys = obj.points.map((p) => p[1]);
      return {
        x: Math.min(...xs),
        y: Math.min(...ys),
        w: Math.max(...xs) - Math.min(...xs),
        h: Math.max(...ys) - Math.min(...ys),
      };
    }
    case 'triangle': {
      const pts = trianglePoints(obj);
      const xs = pts.map((p) => p[0]);
      const ys = pts.map((p) => p[1]);
      return {
        x: Math.min(...xs),
        y: Math.min(...ys),
        w: Math.max(...xs) - Math.min(...xs),
        h: Math.max(...ys) - Math.min(...ys),
      };
    }
    case 'text':
    case 'math': {
      const w = obj.type === 'math' ? Math.max(60, (obj.text.length || 1) * 11) : Math.max(24, obj.text.length * (obj.size || 22) * 0.55);
      const h = (obj.size || 22) * 1.4;
      return { x: obj.x, y: obj.y - h * 0.8, w, h };
    }
    default:
      return { x: 0, y: 0, w: 0, h: 0 };
  }
}

export function centerOf(obj) {
  const b = bbox(obj);
  return [b.x + b.w / 2, b.y + b.h / 2];
}

export function toLocal(point, obj) {
  if (!obj.rotation) return point;
  return rotatePoint(point, centerOf(obj), -obj.rotation);
}

export function pointSegmentDistance(p, a, b) {
  const [px, py] = p;
  const [ax, ay] = a;
  const [bx, by] = b;
  const dx = bx - ax;
  const dy = by - ay;
  const lenSq = dx * dx + dy * dy;
  if (!lenSq) return Math.hypot(px - ax, py - ay);
  let t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
  t = clamp(t, 0, 1);
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

export function pointInPolygon(point, polygon) {
  const [x, y] = point;
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [xi, yi] = polygon[i];
    const [xj, yj] = polygon[j];
    const intersect = yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}

/** Sample points/edges of an object, used by region erasing. */
export function outlinePoints(obj) {
  switch (obj.type) {
    case 'stroke':
      return obj.points;
    case 'line':
    case 'arrow':
      return [
        [obj.x1, obj.y1],
        [obj.x2, obj.y2],
      ];
    case 'rect':
    case 'triangle': {
      const b = bbox(obj);
      return [
        [b.x, b.y],
        [b.x + b.w, b.y],
        [b.x + b.w, b.y + b.h],
        [b.x, b.y + b.h],
      ];
    }
    case 'ellipse': {
      const pts = [];
      for (let i = 0; i < 24; i += 1) {
        const a = (i / 24) * Math.PI * 2;
        pts.push([obj.cx + Math.cos(a) * obj.rx, obj.cy + Math.sin(a) * obj.ry]);
      }
      return pts;
    }
    case 'polygon':
      return obj.points;
    default: {
      const b = bbox(obj);
      return [
        [b.x, b.y],
        [b.x + b.w, b.y],
        [b.x + b.w, b.y + b.h],
        [b.x, b.y + b.h],
      ];
    }
  }
}

export function hitTest(obj, point, tolerance = 9) {
  const local = toLocal(point, obj);
  const [x, y] = local;
  switch (obj.type) {
    case 'stroke': {
      for (let i = 1; i < obj.points.length; i += 1) {
        if (pointSegmentDistance(local, obj.points[i - 1], obj.points[i]) <= tolerance + obj.weight / 2) {
          return true;
        }
      }
      return false;
    }
    case 'line':
    case 'arrow':
      return pointSegmentDistance(local, [obj.x1, obj.y1], [obj.x2, obj.y2]) <= tolerance + obj.weight / 2;
    case 'rect': {
      const b = bbox(obj);
      if (obj.fill && obj.fill !== 'none') {
        return x >= b.x - tolerance && x <= b.x + b.w + tolerance && y >= b.y - tolerance && y <= b.y + b.h + tolerance;
      }
      const nearX = Math.abs(x - b.x) <= tolerance || Math.abs(x - (b.x + b.w)) <= tolerance;
      const nearY = Math.abs(y - b.y) <= tolerance || Math.abs(y - (b.y + b.h)) <= tolerance;
      const insideBand = x >= b.x - tolerance && x <= b.x + b.w + tolerance && y >= b.y - tolerance && y <= b.y + b.h + tolerance;
      return insideBand && (nearX || nearY);
    }
    case 'ellipse': {
      const nx = (x - obj.cx) / (obj.rx || 1);
      const ny = (y - obj.cy) / (obj.ry || 1);
      const value = nx * nx + ny * ny;
      if (obj.fill && obj.fill !== 'none') return value <= 1.12;
      return Math.abs(Math.sqrt(value) - 1) < 0.14;
    }
    case 'triangle':
    case 'polygon': {
      const poly = obj.type === 'triangle' ? trianglePoints(obj) : obj.points;
      if (pointInPolygon(local, poly)) return true;
      const closed = [...poly, poly[0]];
      for (let i = 1; i < closed.length; i += 1) {
        if (pointSegmentDistance(local, closed[i - 1], closed[i]) <= tolerance) return true;
      }
      return false;
    }
    case 'text':
    case 'math': {
      const b = bbox(obj);
      return x >= b.x - tolerance && x <= b.x + b.w + tolerance && y >= b.y - tolerance && y <= b.y + b.h + tolerance;
    }
    default:
      return false;
  }
}

export function moveObject(obj, dx, dy) {
  switch (obj.type) {
    case 'stroke':
      return { ...obj, points: obj.points.map(([x, y]) => [x + dx, y + dy]) };
    case 'line':
    case 'arrow':
      return { ...obj, x1: obj.x1 + dx, y1: obj.y1 + dy, x2: obj.x2 + dx, y2: obj.y2 + dy };
    case 'ellipse':
      return { ...obj, cx: obj.cx + dx, cy: obj.cy + dy };
    case 'polygon':
      return { ...obj, points: obj.points.map(([x, y]) => [x + dx, y + dy]) };
    case 'rect':
    case 'triangle':
    case 'text':
    case 'math':
      return { ...obj, x: obj.x + dx, y: obj.y + dy };
    default:
      return obj;
  }
}

export function scaleObject(obj, sx, sy) {
  const b = bbox(obj);
  const ax = b.x;
  const ay = b.y;
  const map = ([x, y]) => [ax + (x - ax) * sx, ay + (y - ay) * sy];
  switch (obj.type) {
    case 'stroke':
      return { ...obj, points: obj.points.map(map) };
    case 'line':
    case 'arrow': {
      const [x1, y1] = map([obj.x1, obj.y1]);
      const [x2, y2] = map([obj.x2, obj.y2]);
      return { ...obj, x1, y1, x2, y2 };
    }
    case 'ellipse': {
      const [cx, cy] = map([obj.cx, obj.cy]);
      return { ...obj, cx, cy, rx: Math.max(4, obj.rx * sx), ry: Math.max(4, obj.ry * sy) };
    }
    case 'polygon':
      return { ...obj, points: obj.points.map(map) };
    case 'text':
    case 'math':
      return {
        ...obj,
        x: ax + (obj.x - ax) * sx,
        y: ay + (obj.y - ay) * sy,
        size: Math.max(8, (obj.size || 22) * ((sx + sy) / 2)),
      };
    case 'rect':
    case 'triangle':
      return {
        ...obj,
        x: ax + (obj.x - ax) * sx,
        y: ay + (obj.y - ay) * sy,
        w: Math.max(6, obj.w * sx),
        h: Math.max(6, obj.h * sy),
      };
    default:
      return obj;
  }
}

/** Remove the parts of freehand strokes touched by an eraser path. */
export function eraseStroke(stroke, eraserPath, radius) {
  const keep = [];
  let current = [];
  for (const point of stroke.points) {
    const touched = eraserPath.some(([ex, ey]) => Math.hypot(point[0] - ex, point[1] - ey) <= radius);
    if (touched) {
      if (current.length > 1) keep.push(current);
      current = [];
    } else {
      current.push(point);
    }
  }
  if (current.length > 1) keep.push(current);
  const survivors = keep.filter((pts) => pts.length > 1);
  return survivors.map((pts) => ({ ...stroke, id: pts === keep[0] ? stroke.id : `${stroke.id}-${Math.random().toString(36).slice(2, 7)}`, points: pts }));
}

export function interiorPoints(obj) {
  if (obj.type === 'stroke') return obj.points;
  const b = bbox(obj);
  const pts = outlinePoints(obj);
  pts.push([b.x + b.w / 2, b.y + b.h / 2]);
  return pts;
}
