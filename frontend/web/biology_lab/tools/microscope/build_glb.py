"""Build the binocular microscope and export it as a glTF-binary asset for the bio lab.

Usage: python build_glb.py [out=path/to/microscope.glb]

Writes assets/microscope.glb next to the biology-lab root by default.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scope import build, TEX, MATS
from glb import write_glb
import numpy as np

def bbox(root):
    lo = np.array([1e9] * 3); hi = np.array([-1e9] * 3)
    for node, W in root.walk():
        for geo, mn, _ in node.meshes:
            g = geo.tf(W)
            lo = np.minimum(lo, g.P.min(0)); hi = np.maximum(hi, g.P.max(0))
    return lo, hi

def main(out=None, scale=1.0):
    here = os.path.dirname(os.path.abspath(__file__))
    if out is None:
        out = os.path.join(here, '..', '..', 'assets', 'microscope.glb')
    out = os.path.abspath(out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    root, p = build()
    lo, hi = bbox(root)
    size, nodes, meshes, mats = write_glb(root, out, TEX, scale=scale,
                                          extras={'source': 'tools/microscope/scope.py', 'units': 'metres'})
    print('assets/microscope.glb %d bytes, %d nodes, %d meshes, %d materials' % (size, nodes, meshes, mats))
    print('model bbox min=%s max=%s (height %.3f m)' % (np.round(lo, 3).tolist(), np.round(hi, 3).tolist(), hi[1] - lo[1]))

if __name__ == '__main__':
    kw = dict(a.split('=') for a in sys.argv[1:])
    main(kw.get('out'), float(kw.get('scale', 1.0)))
