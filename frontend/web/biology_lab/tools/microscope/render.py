import numpy as np, cv2, math
from geo import *
def look(eye, target, up=(0, 1, 0)):
    f = nrm(np.asarray(target, float) - eye); r = nrm(np.cross(f, up)); u = np.cross(r, f); return f, r, u
def smooth(a, b, x): t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
LIGHTS = [(nrm([-0.45, 0.8, 0.7]), np.array([1.0, 0.98, 0.95]) * 1.5), (nrm([0.8, 0.35, 0.45]), np.array([0.85, 0.9, 1.0]) * 0.55), (nrm([0.0, 0.5, -1.0]), np.array([1, 1, 1.0]) * 0.55)]
def shade(Pw, Nw, m, eye):
    V = nrm(eye - Pw); col = np.array(m['color'][:3], float); metal, rough = m['metal'], max(m['rough'], 0.05)
    ndv = np.clip((Nw * V).sum(1), 0, 1)[:, None]
    hemi = 0.5 + 0.5 * Nw[:, 1:2]; amb = (0.32 + 0.55 * hemi)
    diff = amb * np.ones((len(Pw), 3)); spec = np.zeros((len(Pw), 3)); sh = 2 / (rough ** 2 + 1e-3) - 2
    for L, c in LIGHTS:
        ndl = np.clip((Nw * L).sum(1), 0, 1)[:, None]; diff += c[None] * ndl
        H = nrm(V + L); ndh = np.clip((Nw * H).sum(1), 0, 1)[:, None]; spec += c[None] * (ndh ** min(sh, 400)) * ndl * (1.0 if metal < 0.5 else 0.7)
    R = nrm(2 * ndv * Nw - V)
    env = 0.22 + 0.95 * smooth(-0.25, 0.55, R[:, 1:2]) + 1.4 * np.clip((R * LIGHTS[0][0]).sum(1)[:, None], 0, 1) ** 10
    out = col[None] * (1 - metal) * diff * 0.62 + (spec * (0.04 + 0.5 * (1 - rough)) * (1 - metal) if metal < 0.5 else 0)
    if metal > 0.01: out = out + col[None] * env * metal * (0.85 - 0.3 * rough) + spec * 0.25 * metal * col[None]
    if m.get('clearcoat'): out = out + spec * 0.18 * m['clearcoat'] + 0.05 * m['clearcoat'] * env * (1 - ndv) ** 3
    if m.get('emissive') is not None: out = out + np.array(m['emissive'], float)[None]
    return np.clip(out, 0, 1.6)

def raster(P, Z, C, zbuf, cbuf, alpha=None, write_z=True):
    """P (n,3,2) screen px, Z (n,3) view depth, C (n,3,3) vertex colours (linear). z-buffered, perspective-correct colour."""
    H, W = zbuf.shape
    for k in range(len(P)):
        p = P[k]; x0 = int(max(0, math.floor(p[:, 0].min()))); x1 = int(min(W - 1, math.ceil(p[:, 0].max()))); y0 = int(max(0, math.floor(p[:, 1].min()))); y1 = int(min(H - 1, math.ceil(p[:, 1].max())))
        if x1 < x0 or y1 < y0: continue
        d = (p[1, 0] - p[0, 0]) * (p[2, 1] - p[0, 1]) - (p[2, 0] - p[0, 0]) * (p[1, 1] - p[0, 1])
        if abs(d) < 1e-9: continue
        xs = np.arange(x0, x1 + 1) + 0.5; ys = np.arange(y0, y1 + 1)[:, None] + 0.5
        w0 = ((p[1, 0] - xs) * (p[2, 1] - ys) - (p[2, 0] - xs) * (p[1, 1] - ys)) / d
        w1 = ((p[2, 0] - xs) * (p[0, 1] - ys) - (p[0, 0] - xs) * (p[2, 1] - ys)) / d
        w2 = 1 - w0 - w1; m = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not m.any(): continue
        iz = w0 / Z[k, 0] + w1 / Z[k, 1] + w2 / Z[k, 2]; z = 1 / iz
        sub = zbuf[y0:y1 + 1, x0:x1 + 1]; m &= z < sub - 1e-5 if write_z else (z < sub + 1e-5)
        if not m.any(): continue
        a0 = w0 / Z[k, 0] * z; a1 = w1 / Z[k, 1] * z; a2 = 1 - a0 - a1
        col = a0[..., None] * C[k, 0] + a1[..., None] * C[k, 1] + a2[..., None] * C[k, 2]
        cs = cbuf[y0:y1 + 1, x0:x1 + 1]
        if alpha is None: cs[m] = col[m]; sub[m] = z[m]
        else: cs[m] = cs[m] * (1 - alpha) + col[m] * alpha
    return

def render(root, eye, target, fov, W, H, ss=2, bg=(1, 1, 1), hide=()):
    eye = np.asarray(eye, float); f, r, u = look(eye, target); focal = 0.5 * H * ss / math.tan(math.radians(fov) / 2)
    opaque = []; trans = []
    for node, Wm in root.walk():
        if node.name in hide: continue
        for geo, mn, _ in node.meshes:
            m = MATS[mn]
            if m.get('decal'): continue
            g = geo.tf(Wm); col = shade(g.P, g.N, m, eye)
            rel = g.P - eye; z = rel @ f; x = rel @ r; y = rel @ u
            sx = W * ss / 2 + focal * x / z; sy = H * ss / 2 - focal * y / z
            tri = g.I; p = np.stack([sx[tri], sy[tri]], -1)
            area = (p[:, 1, 0] - p[:, 0, 0]) * (p[:, 2, 1] - p[:, 0, 1]) - (p[:, 2, 0] - p[:, 0, 0]) * (p[:, 1, 1] - p[:, 0, 1])
            vis = (area < 0) if not m.get('double') else np.ones(len(tri), bool); vis &= (z[tri] > 0.01).all(1)
            item = (p[vis], z[tri][vis], col[tri][vis], m)
            (trans if m['alpha'] < 1 else opaque).append(item)
    zbuf = np.full((H * ss, W * ss), 1e9); cbuf = np.ones((H * ss, W * ss, 3)) * np.array(bg[::-1], float) ** 2.2
    for p, z, c, m in opaque: raster(p, z, c, zbuf, cbuf)
    for p, z, c, m in trans:
        o = np.argsort(-z.mean(1)); raster(p[o], z[o], c[o], zbuf, cbuf, alpha=m['alpha'], write_z=False)
    img = (np.clip(cbuf, 0, 1) ** (1 / 2.2) * 255).astype(np.uint8)[..., ::-1].copy()   # RGB -> BGR for OpenCV
    return cv2.resize(img, (W, H), interpolation=cv2.INTER_AREA)
