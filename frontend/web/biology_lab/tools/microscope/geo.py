"""Tiny 3D toolkit: primitives -> scene graph -> software preview renderer -> GLB writer.  Units: metres, +Y up, +Z toward the user."""
import numpy as np, math, json, struct, io
from PIL import Image
F = np.float32
def nrm(v): v = np.asarray(v, float); return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-12)

class Geo:
    def __init__(s, P, N, I, UV=None):
        s.P = np.asarray(P, F).reshape(-1, 3); s.N = np.asarray(N, F).reshape(-1, 3); s.I = np.asarray(I, np.int32).reshape(-1, 3)
        s.UV = None if UV is None else np.asarray(UV, F).reshape(-1, 2)
    def fix(s):
        a, b, c = s.P[s.I[:, 0]], s.P[s.I[:, 1]], s.P[s.I[:, 2]]
        fn = np.cross(b - a, c - a); vn = s.N[s.I[:, 0]] + s.N[s.I[:, 1]] + s.N[s.I[:, 2]]
        flip = (fn * vn).sum(1) < 0; s.I[flip] = s.I[flip][:, [0, 2, 1]]; return s
    def tf(s, M):
        M = np.asarray(M, float); P = (np.c_[s.P, np.ones(len(s.P))] @ M.T)[:, :3]
        N = nrm(s.N @ np.linalg.inv(M[:3, :3]))   # inverse-transpose
        return Geo(P, N, s.I.copy(), s.UV)

def merge(gs):
    gs = [g for g in gs if g is not None]; off = 0; P = []; N = []; I = []; UV = []
    uv = all(g.UV is not None for g in gs)
    for g in gs: P.append(g.P); N.append(g.N); I.append(g.I + off); off += len(g.P); uv and UV.append(g.UV)
    return Geo(np.vstack(P), np.vstack(N), np.vstack(I), np.vstack(UV) if uv else None)

# ---------- transforms ----------
def T(x=0, y=0, z=0): M = np.eye(4); M[:3, 3] = (x, y, z); return M
def Rx(a): c, s = math.cos(a), math.sin(a); M = np.eye(4); M[1:3, 1:3] = [[c, -s], [s, c]]; return M
def Ry(a): c, s = math.cos(a), math.sin(a); M = np.eye(4); M[0, 0] = c; M[0, 2] = s; M[2, 0] = -s; M[2, 2] = c; return M
def Rz(a): c, s = math.cos(a), math.sin(a); M = np.eye(4); M[0:2, 0:2] = [[c, -s], [s, c]]; return M
def S(x, y=None, z=None): y = x if y is None else y; z = x if z is None else z; return np.diag([x, y, z, 1.0])
def from_to(a, b):
    a, b = nrm(a), nrm(b); v = np.cross(a, b); c = float(a @ b)
    if np.linalg.norm(v) < 1e-9: return np.eye(4) if c > 0 else Rx(math.pi)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]]); R = np.eye(3) + k + k @ k * (1 / (1 + c)); M = np.eye(4); M[:3, :3] = R; return M

# ---------- primitives ----------
def lathe(profile, seg=64, thr=38, uvmap=False):
    """profile: [(r,y),...] going bottom->top along the outside (closed paths for solids end on the axis)."""
    pr = np.asarray(profile, float); n = len(pr)
    tang = nrm(pr[1:] - pr[:-1]); segn = np.c_[tang[:, 1], -tang[:, 0]]            # 2D outward normal per profile segment
    P = []; N = []; I = []; UV = []; ang = np.linspace(0, 2 * math.pi, seg + 1)
    for k in range(n - 1):
        for e, (pt, nn) in enumerate(((pr[k], None), (pr[k + 1], None))):
            idx = k + e; cand = []
            if idx > 0: cand.append(segn[idx - 1])
            if idx < n - 1: cand.append(segn[idx])
            nk = segn[k]
            if len(cand) == 2:
                cosang = float(cand[0] @ cand[1])
                if cosang > math.cos(math.radians(thr)): nk = nrm(cand[0] + cand[1])
            r, y = pt
            for t in ang:
                P.append((r * math.cos(t), y, r * math.sin(t))); N.append((nk[0] * math.cos(t), nk[1], nk[0] * math.sin(t))); UV.append((t / (2 * math.pi), 0.0))
    base = 0; cnt = seg + 1
    for k in range(n - 1):
        a0 = base + (2 * k) * cnt; b0 = a0 + cnt
        for i in range(seg):
            I += [(a0 + i, b0 + i, a0 + i + 1), (a0 + i + 1, b0 + i, b0 + i + 1)]
    return Geo(P, N, I, UV if uvmap else None).fix()

def cyl(r, h, seg=48, y0=0.0, caps=True):
    return lathe([(0, y0), (r, y0), (r, y0 + h), (0, y0 + h)] if caps else [(r, y0), (r, y0 + h)], seg)

def grid(Pg, flip=False):
    nu, nv, _ = Pg.shape; P = Pg.reshape(-1, 3); I = []
    for i in range(nu - 1):
        for j in range(nv - 1):
            a = i * nv + j; b = a + 1; c = a + nv; d = c + 1; I += [(a, c, b), (b, c, d)]
    I = np.asarray(I)
    N = np.zeros_like(P); a, b, c = P[I[:, 0]], P[I[:, 1]], P[I[:, 2]]; fn = np.cross(b - a, c - a)
    for k in range(3): np.add.at(N, I[:, k], fn)
    return Geo(P, nrm(N), I).fix()

def _axis(h, r, maxe):
    """sample positions along [-h,h] with r-radius rounded ends (tangent-spaced)"""
    if r < 1e-6: m = max(1, int(math.ceil(2 * h / maxe))); return np.linspace(-h, h, m + 1)
    ph = np.linspace(math.pi / 4, 0, 5) if r > 0 else []
    left = [-h + r - r * math.tan(p) for p in ph]; core = max(1, int(math.ceil((2 * h - 2 * r) / maxe)))
    mid = list(np.linspace(-h + r, h - r, core + 1))[1:-1]; right = [h - r + r * math.tan(p) for p in ph[::-1]]
    return np.array(left + mid + right)

def rbox(sx, sy, sz, r=0.0, maxe=0.014):
    hx, hy, hz = sx / 2, sy / 2, sz / 2; r = min(r, hx, hy, hz) if r > 0 else 0
    ax, ay, az = _axis(hx, r, maxe), _axis(hy, r, maxe), _axis(hz, r, maxe); parts = []
    def face(u, v, w_const, order):
        U, V = np.meshgrid(u, v, indexing='ij'); W = np.full_like(U, w_const)
        pts = {0: (W, U, V), 1: (U, W, V), 2: (U, V, W)}[order]; return np.stack(pts, -1)
    for sgn in (-1, 1):
        for g in (face(ay, az, sgn * hx, 0), face(ax, az, sgn * hy, 1), face(ax, ay, sgn * hz, 2)):
            q = np.clip(g, [-(hx - r), -(hy - r), -(hz - r)], [hx - r, hy - r, hz - r]); d = g - q
            nn = nrm(d.reshape(-1, 3)).reshape(g.shape) if r > 0 else None
            if r > 0: P = q + nn * r; Nn = nn
            else: P = g; Nn = np.zeros_like(g); Nn[..., {0: 0, 1: 1, 2: 2}[0]] = 0
            gg = grid(P)
            if r > 0: gg.N = Nn.reshape(-1, 3).astype(F)
            else:
                nflat = np.zeros(3); idx = [i for i in range(3) if abs(abs(g.reshape(-1, 3)[0][i]) - [hx, hy, hz][i]) < 1e-9][0]; nflat[idx] = np.sign(g.reshape(-1, 3)[0][idx]); gg.N = np.tile(nflat, (len(gg.P), 1)).astype(F)
            parts.append(gg.fix())
    return merge(parts)

def knurl(r, h, ridges=48, depth=0.0008, seg_per=3, cap=True, y0=0.0):
    n = ridges * seg_per; t = np.linspace(0, 2 * math.pi, n + 1)
    rad = r - depth * (0.5 - 0.5 * np.cos(ridges * t)) ** 0.6
    ring = lambda y, rr: np.c_[rr * np.cos(t), np.full_like(t, y), rr * np.sin(t)]
    side = grid(np.stack([ring(y0, rad), ring(y0 + h, rad)], 0)); parts = [side]
    if cap:
        for y, up in ((y0 + h, 1), (y0, -1)):
            c = np.array([[0, y, 0]]); P = np.vstack([c, ring(y, rad)]); I = [(0, i + 1, i + 2) for i in range(n)]
            g = Geo(P, np.tile([0, up, 0], (len(P), 1)), I).fix(); parts.append(g)
    return merge(parts)

def torus(R, r, sR=48, sr=16):
    u = np.linspace(0, 2 * math.pi, sR + 1); v = np.linspace(0, 2 * math.pi, sr + 1); U, V = np.meshgrid(u, v, indexing='ij')
    P = np.stack([(R + r * np.cos(V)) * np.cos(U), r * np.sin(V), (R + r * np.cos(V)) * np.sin(U)], -1); return grid(P)

def sphere(rx, ry=None, rz=None, seg=32, rings=16):
    ry = rx if ry is None else ry; rz = rx if rz is None else rz
    u = np.linspace(0, 2 * math.pi, seg + 1); v = np.linspace(0, math.pi, rings + 1); U, V = np.meshgrid(u, v, indexing='ij')
    P = np.stack([rx * np.sin(V) * np.cos(U), ry * np.cos(V), rz * np.sin(V) * np.sin(U)], -1); g = grid(P)
    g.N = nrm(g.P / np.array([rx, ry, rz]) ** 2).astype(F); return g.fix()

def sweep(path, width, thick, ex=4.0, seg=24):
    """path: Nx3 (x=0 plane curve); width(t)/thick(t) -> sizes; rounded-rect (superellipse) section; width axis = +X."""
    from scipy.interpolate import CubicSpline
    path = np.asarray(path, float); s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))]; cs = CubicSpline(s, path)
    n = 60; ts = np.linspace(0, s[-1], n); pts = cs(ts); tg = nrm(cs(ts, 1)); X = np.array([1.0, 0, 0]); rings = []
    th = np.linspace(0, 2 * math.pi, seg + 1)
    for k in range(n):
        t = k / (n - 1); N = nrm(np.cross(X, tg[k])); w, d = width(t) / 2, thick(t) / 2
        c, sn = np.cos(th), np.sin(th); sx = np.sign(c) * np.abs(c) ** (2 / ex); sy = np.sign(sn) * np.abs(sn) ** (2 / ex)
        rings.append(pts[k] + np.outer(sx * w, X) + np.outer(sy * d, N))
    g = grid(np.stack(rings, 0))
    cap = []
    for end, o in ((0, -1), (n - 1, 1)):
        c = pts[end]; P = np.vstack([c, rings[end]]); I = [(0, i + 1, i + 2) for i in range(seg)]; cap.append(Geo(P, np.tile(o * tg[end], (len(P), 1)), I).fix())
    return merge([g] + cap)

def plate_hole(sx, sz, thick, hole_r, ex=8.0, rings=4, seg=96, hole_off=(0, 0)):
    """flat plate (rounded-rect via superellipse) with a circular hole; top at y=0, thickness downward; centred on origin."""
    a, b = sx / 2, sz / 2; th = np.linspace(0, 2 * math.pi, seg + 1)
    rho = 1.0 / ((np.abs(np.cos(th) / a) ** ex + np.abs(np.sin(th) / b) ** ex) ** (1 / ex))
    ox, oz = hole_off
    outer = np.c_[rho * np.cos(th), rho * np.sin(th)]; hole = np.c_[ox + hole_r * np.cos(th), oz + hole_r * np.sin(th)]
    def surf(y, up):
        lv = [hole * (1 - t) + outer * t for t in np.linspace(0, 1, rings + 1)]
        Pg = np.stack([np.c_[l[:, 0], np.full(len(l), y), l[:, 1]] for l in lv], 0)
        g = grid(Pg); g.N = np.tile([0, up, 0], (len(g.P), 1)).astype(F); return g.fix()
    top = surf(0, 1); bot = surf(-thick, -1)
    def wall(pts, y0, y1, out):
        Pg = np.stack([np.c_[pts[:, 0], np.full(len(pts), y0), pts[:, 1]], np.c_[pts[:, 0], np.full(len(pts), y1), pts[:, 1]]], 0); g = grid(Pg)
        c = np.array([ox, oz]) if not out else np.array([0, 0]); d = np.c_[g.P[:, 0] - c[0], np.zeros(len(g.P)), g.P[:, 2] - c[1]]; nn = nrm(d)
        g.N = (nn if out else -nn).astype(F); return g.fix()
    return merge([top, bot, wall(outer, 0, -thick, True), wall(hole, 0, -thick, False)])

def quad(w, h, uv=True, nz=1):
    P = [(-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0)]; return Geo(P, [(0, 0, nz)] * 4, [(0, 1, 2), (0, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)] if uv else None).fix()

def cyl_patch(r, h, th0, th1, seg=24):
    """cylindrical label decal facing +Z, centred on +Z axis; angles measured about Y from +Z."""
    t = np.linspace(th0, th1, seg + 1); y = np.array([-h / 2, h / 2]); T_, Y_ = np.meshgrid(t, y, indexing='ij')
    P = np.stack([r * np.sin(T_), Y_, r * np.cos(T_)], -1); UV = np.stack([(T_ - th0) / (th1 - th0), (Y_ + h / 2) / h], -1)
    g = grid(P); g.UV = UV.reshape(-1, 2).astype(F); g.N = nrm(np.c_[g.P[:, 0], 0 * g.P[:, 1], g.P[:, 2]]).astype(F); return g.fix()

# ---------- scene graph ----------
class Node:
    def __init__(s, name, M=None, parent=None):
        s.name = name; s.M = np.eye(4) if M is None else np.asarray(M, float); s.meshes = []; s.children = []; s.extras = {}
        if parent is not None: parent.children.append(s)
    def add(s, geo, mat, name=None): s.meshes.append((geo, mat, name)); return s
    def node(s, name, M=None): return Node(name, M, s)
    def walk(s, W=None):
        W = np.eye(4) if W is None else W; Wn = W @ s.M
        yield s, Wn
        for c in s.children: yield from c.walk(Wn)
    def find(s, name):
        for n, _ in s.walk():
            if n.name == name: return n

MATS = {}   # name -> dict(color, metal, rough, emissive, alpha, clearcoat, tex)
def mat(name, color, metal=0.0, rough=0.5, emissive=None, alpha=1.0, clearcoat=0.0, tex=None, double=False):
    MATS[name] = dict(color=color, metal=metal, rough=rough, emissive=emissive, alpha=alpha, clearcoat=clearcoat, tex=tex, double=double); return name
