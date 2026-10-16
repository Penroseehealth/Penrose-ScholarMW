"""Offline preview: render the built microscope with the software renderer.

Usage: python compare.py az=38 el=9 d=1.05 fov=24 out=preview.png

If a reference photo is available (env REF_PHOTO or the original upload path), the render is
written side by side with it as cmp.png; otherwise the render is written on its own.
"""
import sys, math, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, cv2
from scope import *
from render import *
def eye_at(az, el, d, tgt): a, e = az * D2R, el * D2R; return np.array(tgt) + d * np.array([math.sin(a) * math.cos(e), math.sin(e), math.cos(a) * math.cos(e)])
def main(az=38, el=9, d=1.05, fov=24, tgt=(0, 0.235, 0), out='/tmp/cmp.png', P=None, W=760, H=760, hide=()):
    root, p = build(P); img = render(root, eye_at(az, el, d, tgt), tgt, fov, W, H, ss=2, hide=hide)
    ref = os.environ.get('REF_PHOTO', '/mnt/user-data/uploads/1001290972.jpg')
    ph = cv2.imread(ref) if os.path.exists(ref) else None
    if ph is None: cv2.imwrite(out, img); return root, p
    ph = cv2.resize(ph, (int(ph.shape[1] * H / ph.shape[0]), H))
    cv2.imwrite(out, np.hstack([ph, img])); return root, p
if __name__ == '__main__':
    kw = {k: float(v) for k, v in (a.split('=') for a in sys.argv[1:])}; main(**kw); print('saved')
