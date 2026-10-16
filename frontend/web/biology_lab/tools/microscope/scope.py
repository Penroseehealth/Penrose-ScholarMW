"""Binocular compound microscope (student/lab model), matched to the reference photo. Units: metres, +Y up, +Z toward the user."""
import numpy as np, math, os
from geo import *
from PIL import Image, ImageDraw, ImageFont
D2R = math.pi / 180
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(sz):
    try: return ImageFont.truetype(FONT, sz)
    except Exception: return ImageFont.load_default()

def decal_tex(name, draw_fn, size=(256, 128)):
    im = Image.new('RGBA', size, (0, 0, 0, 0)); d = ImageDraw.Draw(im); draw_fn(d, size); return im

def make_materials():
    mat('white', (0.86, 0.86, 0.84), 0, 0.30, clearcoat=0.7)
    mat('black', (0.025, 0.025, 0.028), 0, 0.5)
    mat('blackgrip', (0.018, 0.018, 0.02), 0, 0.62)
    mat('chrome', (0.8, 0.82, 0.85), 1, 0.16)
    mat('steel', (0.45, 0.46, 0.49), 0.95, 0.34)
    mat('rubber', (0.012, 0.012, 0.013), 0, 0.9)
    mat('glass', (0.7, 0.8, 0.9), 0, 0.04, alpha=0.28, double=True)
    mat('lens', (0.12, 0.08, 0.30), 0, 0.04, clearcoat=1.0)
    mat('red', (0.62, 0.02, 0.02), 0, 0.4); mat('yellow', (0.85, 0.55, 0.0), 0, 0.4); mat('blue', (0.02, 0.12, 0.62), 0, 0.4)
    mat('led', (0.8, 0.9, 1.0), 0, 0.2, emissive=(0.55, 0.8, 1.2))
    mat('slidelabel', (0.9, 0.9, 0.88), 0, 0.7); mat('specimen', (0.75, 0.25, 0.45), 0, 0.5, alpha=0.8)
    mat('rocker', (0.04, 0.04, 0.045), 0, 0.35)

def build(P=None):
    """All dimensions measured from the reference photo (proportions) - model is later scaled to real size."""
    make_materials(); p = dict(OZ=0.045, ys=0.262, beta=38, rm=0.032, ipd=0.066, obj=1, focus=0.5, tube=30); p.update(P or {})
    OZ = p['OZ']; ys = p['ys']; root = Node('Microscope')
    # ---------------- BASE ----------------
    base = root.node('Base'); BW, BD, BH = 0.27, 0.31, 0.105
    base.node('BaseShell', T(0, 0.008 + BH / 2, 0)).add(rbox(BW, BH, BD, 0.022), 'white')
    base.node('BaseRear', T(0, 0.113 + 0.025, -0.108)).add(rbox(0.21, 0.062, 0.11, 0.018), 'white')
    for sx in (-1, 1):
        for sz in (-1, 1): base.node('Foot', T(sx * 0.104, 0, sz * 0.135)).add(cyl(0.014, 0.009, 28), 'rubber')
    ill = base.node('Illuminator', T(0, 0.113, OZ))
    ill.add(lathe([(0, 0), (0.046, 0), (0.046, 0.004), (0.043, 0.009), (0.043, 0.0155), (0.036, 0.019), (0, 0.019)], 72), 'black')
    ill.add(lathe([(0.0465, 0.012), (0.0465, 0.0145), (0.0435, 0.0148), (0.0435, 0.012)], 72), 'chrome')
    ill.node('LEDLens', T(0, 0.0192, 0)).add(cyl(0.033, 0.0008, 56), 'led'); ill.node('Lens', T(0, 0.0186, 0)).add(cyl(0.034, 0.0006, 56), 'glass')
    sw = base.node('PowerSwitch', T(0.052, 0.052, BD / 2 + 0.0005)); sw.add(rbox(0.040, 0.027, 0.008, 0.003), 'black')
    sw.node('Rocker', T(0, 0, 0.0055) @ Rx(-0.12)).add(rbox(0.03, 0.019, 0.008, 0.002), 'rocker')
    kn = base.node('LightKnob', T(0.072, 0.113, 0.075)); kn.add(knurl(0.0195, 0.017, 48, 0.0013, 3), 'blackgrip'); kn.add(cyl(0.0135, 0.0006, 32, 0.017), 'steel')
    # ---------------- ARM ----------------
    path = [(0.115, -0.100), (0.19, -0.120), (0.29, -0.126), (0.37, -0.116), (0.412, -0.092), (0.430, -0.055)]
    arm = root.node('Arm'); arm.add(sweep([(0, y, z) for y, z in path], lambda t: 0.120 - 0.020 * t, lambda t: 0.092 - 0.014 * t, 4.0, 32), 'white')
    arm.node('SlideColumn', T(0, 0.200, -0.070)).add(rbox(0.085, 0.160, 0.030, 0.004), 'black')
    for side, nm in ((1, 'FocusKnobR'), (-1, 'FocusKnobL')):
        k = root.node(nm, T(0, 0.190, -0.108)); k.extras['axis'] = 'x'
        g = k.node('Knobs', Rz(-math.pi / 2) if side > 0 else Rz(math.pi / 2))
        g.add(cyl(0.015, 0.016, 32, 0.058), 'steel')
        g.node('Coarse', T(0, 0.060, 0)).add(knurl(0.056, 0.022, 84, 0.0018, 3), 'blackgrip')
        f = g.node('Fine', T(0, 0.082, 0)); f.add(knurl(0.037, 0.020, 60, 0.0015, 3), 'blackgrip'); f.add(cyl(0.021, 0.0007, 32, 0.020), 'steel')
        g.node('FocusScale', T(0, 0.0823, 0)).add(lathe([(0.0375, 0), (0.0545, 0), (0.0545, 0.0004), (0.0375, 0.0004)], 72, uvmap=True), 'scaletex')
    # ---------------- STAGE ASSEMBLY (moves with focus) ----------------
    st = root.node('StageAssembly', T(0, (p['focus'] - 0.5) * 0.03, 0))
    st.node('StagePlate', T(0, ys, OZ)).add(plate_hole(0.215, 0.185, 0.014, 0.014, 8, 4, 96), 'black')
    st.node('StageCarrier', T(0, ys - 0.026, -0.068)).add(rbox(0.120, 0.052, 0.060, 0.006), 'black')
    sh = st.node('SlideHolder', T(0, ys, OZ))
    sh.add(rbox(0.140, 0.0028, 0.007, 0.0008).tf(T(0, 0.0014, -0.0265)), 'chrome'); sh.add(rbox(0.008, 0.005, 0.037, 0.001).tf(T(-0.052, 0.0025, 0.0)), 'chrome')
    sh.add(rbox(0.010, 0.005, 0.037, 0.001).tf(T(0.052, 0.0025, 0.0)), 'chrome'); sh.add(rbox(0.092, 0.0018, 0.004, 0.0006).tf(T(0.0, 0.0019, 0.0245) @ Ry(0.012)), 'chrome')
    slide = st.node('Slide', T(0, ys + 0.0031, OZ)); slide.add(rbox(0.076, 0.0012, 0.026, 0.0002), 'glass')
    slide.add(rbox(0.018, 0.0014, 0.0255, 0.0002).tf(T(-0.029, 0.0001, 0)), 'slidelabel'); slide.add(rbox(0.018, 0.0004, 0.018, 0.0001).tf(T(0.0, 0.0008, 0)), 'glass'); slide.add(sphere(0.0045, 0.0006, 0.0045, 24, 8).tf(T(0, 0.0009, 0)), 'specimen')
    for (x, z, big) in ((-0.080, -0.050, 1), (0.056, -0.056, 1), (0.078, -0.010, 0), (0.074, 0.105, 0), (-0.086, 0.102, 0)):
        st.node('StageScrew', T(x, ys, z + 0.0)).add(cyl(0.0065 if big else 0.0048, 0.009 if big else 0.0045, 24), 'black' if big else 'chrome')
    ms = st.node('MechStage', T(0.095, ys - 0.014, 0.060)); ms.add(rbox(0.040, 0.018, 0.085, 0.004), 'black')
    ms.add(knurl(0.0125, 0.024, 30, 0.001, 3).tf(T(0.014, -0.042, 0.026)), 'blackgrip'); ms.add(knurl(0.0095, 0.018, 26, 0.0009, 3).tf(T(0.014, -0.060, 0.026)), 'blackgrip'); ms.add(cyl(0.004, 0.034, 16).tf(T(0.014, -0.040, 0.026)), 'steel')
    st.node('Rack', T(0.1145, ys + 0.0025, 0.03)).add(rbox(0.006, 0.005, 0.085, 0.0008), 'chrome')
    co = st.node('Condenser', T(0, 0, OZ))
    co.add(lathe([(0, ys - 0.070), (0.020, ys - 0.070), (0.027, ys - 0.063), (0.032, ys - 0.054), (0.032, ys - 0.032), (0.025, ys - 0.022), (0.019, ys - 0.0145), (0, ys - 0.0145)], 72), 'black')
    co.add(knurl(0.0375, 0.008, 44, 0.001, 3).tf(T(0, ys - 0.050, 0)), 'blackgrip')
    co.add(lathe([(0.0145, ys - 0.0150), (0.0205, ys - 0.0150), (0.0205, ys - 0.0100), (0.0145, ys - 0.0100)], 48), 'chrome'); co.add(cyl(0.0138, 0.0004, 32, ys - 0.0108), 'glass')
    co.add(cyl(0.040, 0.005, 56, ys - 0.074), 'blackgrip')
    lever = co.node('IrisLever', T(-0.036, ys - 0.046, 0.016) @ Ry(-0.9)); lever.add(cyl(0.0024, 0.046, 12).tf(Rz(math.pi / 2)), 'chrome'); lever.add(sphere(0.005, seg=16, rings=8).tf(T(0.046, 0, 0)), 'black')
    ck = co.node('CondenserKnob', T(0.0, ys - 0.052, 0.0)); ck.add(cyl(0.0035, 0.114, 12).tf(Rz(math.pi / 2) @ T(0, -0.057, 0)), 'steel')
    for sx in (-1, 1): ck.node('K', T(sx * 0.056, 0, 0) @ (Rz(-math.pi / 2) if sx > 0 else Rz(math.pi / 2))).add(knurl(0.0128, 0.014, 30, 0.001, 3), 'blackgrip')
    co.add(rbox(0.07, 0.010, 0.058, 0.003).tf(T(0, ys - 0.019, -0.058)), 'black')
    # ---------------- NOSEPIECE (tilted turret) + OBJECTIVES ----------------
    beta = p['beta'] * D2R; rm = p['rm']*1.1; tip = ys + 0.0057 + 0.0235; shoulder = tip + 0.047
    pivot = (0, shoulder + 0.0042 * math.cos(beta) + rm * math.sin(beta), OZ - (rm * math.cos(beta) - 0.0042 * math.sin(beta)))
    nm = root.node('NosepieceMount', T(*pivot) @ Rx(beta))
    nm.add(lathe([(0, 0.008), (0.0435, 0.008), (0.0435, 0.034), (0.038, 0.039), (0, 0.039)], 72), 'white')
    nm.add(lathe([(0.0442, 0.007), (0.0442, 0.0098), (0.0437, 0.0098), (0.0437, 0.007)], 72), 'chrome')
    tur = nm.node('NosepieceTurret', Ry(-(p['obj']) * math.pi / 2)); tur.extras['axis'] = 'y'
    tur.add(knurl(0.0505, 0.012, 72, 0.0013, 3, True).tf(T(0, -0.0025, 0)), 'blackgrip')
    tur.add(lathe([(0, -0.0095), (0.0508, -0.0095), (0.0508, -0.0040), (0.034, -0.023), (0.024, -0.029), (0, -0.029)], 72), 'black')
    tur.add(lathe([(0.0512, -0.0065), (0.0512, -0.0035), (0.0506, -0.0035), (0.0506, -0.0065)], 72), 'chrome')
    objs = [('Objective4x', 'red', '4×', 0.0125, 0.0105), ('Objective10x', 'yellow', '10×', 0.0135, 0.0115), ('Objective40x', 'blue', '40×', 0.0138, 0.0118), ('BlankPort', None, None, 0, 0)]
    for i, (nme, ring, label, rb, rb2) in enumerate(objs):
        phi = i * math.pi / 2; rh = np.array([math.sin(phi), 0, math.cos(phi)]); d = math.cos(beta) * np.array([0, -1.0, 0]) + math.sin(beta) * rh
        Yl = -d; Zl = nrm(rh - (rh @ d) * d); Xl = np.cross(Yl, Zl); M = np.eye(4); M[:3, 0] = Xl; M[:3, 1] = Yl; M[:3, 2] = Zl; M[:3, 3] = (rm * rh[0], -0.0042, rm * rh[2])
        o = tur.node(nme, M); o.add(lathe([(0, -0.0045), (0.0105, -0.0045), (0.0105, 0.0), (0, 0.0)], 40), 'chrome')
        if ring is None: o.add(cyl(0.0112, 0.004, 32, -0.0035), 'black'); continue
        L = 0.047; o.add(cyl(0.0112, 0.0005, 24, -0.0005), 'steel')
        o.add(lathe([(0, -L + 0.012), (rb2 * 0.78, -L + 0.012), (rb2, -0.032), (rb2 + 0.0006, -0.026), (rb, -0.0175), (rb, -0.0045), (0, -0.0045)], 56), 'blackgrip')
        o.add(lathe([(rb2 * 0.92 + 0.0005, -0.0345), (rb2 + 0.0008, -0.0285), (rb2 + 0.0008, -0.0255), (rb2 * 0.97, -0.0255)], 56), ring)
        o.add(lathe([(0, -L), (0.0038 if label != '40×' else 0.0030, -L), (0.0048, -L + 0.003), (rb2 * 0.78, -L + 0.012), (0, -L + 0.012)], 48), 'chrome'); o.add(cyl(0.0022, 0.0003, 20, -L - 0.0001), 'lens')
        o.node('Label', T(0, -0.0165, 0)).add(cyl_patch(rb + 0.0004, 0.0105, -0.55, 0.55), 'label_' + label[:-1])
    # ---------------- HEAD (binocular Siedentopf-type, 30 deg inclined tubes) ----------------
    head = root.node('Head')
    head.add(lathe([(0, 0.372), (0.054, 0.372), (0.054, 0.3755), (0.0505, 0.3755), (0.0505, 0.392), (0, 0.392)], 72), 'white'); head.add(lathe([(0.0545, 0.3675 + 0.0035), (0.0545, 0.3725 + 0.0035), (0.0505, 0.3725 + 0.0035), (0.0505, 0.3675 + 0.0035)], 72), 'chrome')
    head.node('HeadLower', T(0, 0.418, 0.002)).add(rbox(0.150, 0.060, 0.125, 0.013), 'white')
    ang = p['tube'] * D2R; top = head.node('HeadTop', T(0, 0.456, 0.016) @ Rx(ang)); top.add(rbox(0.142, 0.048, 0.098, 0.012), 'white')
    head.node('HeadLock', T(0.0675, 0.418, 0.0) @ Rz(-math.pi / 2)).add(knurl(0.0062, 0.010, 18, 0.0007, 3), 'blackgrip')
    head.node('HeadScrew', T(0.0, 0.405, -0.0575) @ Rx(math.pi / 2)).add(cyl(0.0042, 0.0025, 16), 'black')
    base_pt = np.array([0, 0.456 + 0.023 * math.cos(ang), 0.016 + 0.023 * math.sin(ang)])
    for side, nme in ((-1, 'EyepieceL'), (1, 'EyepieceR')):
        e = head.node(nme, T(side * p['ipd'] / 2, base_pt[1], base_pt[2]) @ Rx(ang)); e.extras['ipd'] = side
        e.add(lathe([(0, -0.004), (0.0265, -0.004), (0.0265, 0.012), (0.0225, 0.0175), (0, 0.0175)], 56), 'white')
        e.add(cyl(0.0212, 0.042, 48, 0.010), 'blackgrip')
        e.add(lathe([(0, 0.050), (0.0192, 0.050), (0.0186, 0.0515), (0.0178, 0.053), (0.0173, 0.080), (0.0178, 0.092), (0.0198, 0.094), (0.0198, 0.1025), (0.0188, 0.1035), (0.0156, 0.1035), (0, 0.1035)], 56), 'black')
        e.add(knurl(0.0196, 0.0090, 40, 0.001, 3, True).tf(T(0, 0.056, 0)), 'blackgrip'); e.add(lathe([(0.0176, 0.0825), (0.0176, 0.0855), (0.0183, 0.0855), (0.0183, 0.0825)], 40), 'chrome')
        e.add(cyl(0.0134, 0.0006, 40, 0.1033), 'lens'); e.add(lathe([(0.0156, 0.1015), (0.0202, 0.1015), (0.0202, 0.1075), (0.0168, 0.1075), (0.0156, 0.1050)], 48), 'rubber')
        e.node('EyeLabel', T(0, 0.073, 0)).add(cyl_patch(0.0180, 0.012, -0.6, 0.6), 'label_WF10')
        if side < 0: e.node('DiopterRing', T(0, 0.0665, 0)).add(knurl(0.0203, 0.0075, 36, 0.0009, 3, True), 'blackgrip')
    return root, p

def label_textures():
    tex = {}
    def txt(s, sz=70, col=(255, 255, 255, 255), size=(256, 128)):
        def f(d, S):
            fnt = font(sz); w, h = d.textbbox((0, 0), s, font=fnt)[2:]; d.text(((S[0] - w) / 2, (S[1] - h) / 2 - 6), s, font=fnt, fill=col)
        return decal_tex(s, f, size)
    tex['label_4'] = txt('4×', 78); tex['label_10'] = txt('10×', 78); tex['label_40'] = txt('40×', 78); tex['label_WF10'] = txt('WF10×/18', 44, size=(256, 64))
    def scale(d, S):
        W, H = S; d.rectangle([0, 0, W, H], fill=(235, 235, 225, 255))
        for i in range(0, 100):
            x = i * W / 100; d.line([x, H * 0.55, x, H], fill=(20, 20, 20, 255), width=2 if i % 10 else 4)
        fnt = font(34)
        for i in range(0, 10): d.text((i * W / 10 + 6, 6), str(i), font=fnt, fill=(20, 20, 20, 255))
    tex['scaletex'] = decal_tex('scale', scale, (1024, 96))
    return tex

TEX = label_textures()
for k in ('label_4', 'label_10', 'label_40', 'label_WF10'):
    mat(k, (1, 1, 1), 0, 0.6, alpha=0.99, tex=k) ; MATS[k]['decal'] = True; MATS[k]['blend'] = True
mat('scaletex', (1, 1, 1), 0, 0.6, tex='scaletex'); MATS['scaletex']['decal'] = True
