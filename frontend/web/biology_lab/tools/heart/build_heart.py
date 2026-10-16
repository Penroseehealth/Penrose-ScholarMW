"""Bake the Z-Anatomy heart specimen used by the lab scene.

Source model
------------
The 3D heart on the plinth (assets/heart.obj) and the wall chart
(assets/heart-zanatomy.png) are both derived from the Z-Anatomy cardiovascular
model. It is not committed here (60 MB+); download it first:

    curl -L -o CardioVascular41.fbx \
      https://raw.githubusercontent.com/LluisV/Z-Anatomy/PC-Version/Resources/Models/FBX/CardioVascular41.fbx

That repo (github.com/LluisV/Z-Anatomy) reworks the BodyParts3D dataset.
Licence: Z-Anatomy CC BY-SA 4.0; source meshes BodyParts3D CC BY-SA 2.1 Japan.
Attribution + share-alike are required. Do not use commercially without
clearing the mixed-licence parts.

What this does
--------------
Imports the FBX, keeps the 34 heart meshes (chambers, valve leaflets, papillary
muscles, coronaries, coronary sinus and the roots of the great vessels), tints
them by anatomical group, exports OBJ+MTL and renders the wall chart PNG.

Usage (Blender 4.x/5.x, headless)
---------------------------------
    blender --background --factory-startup --python tools/heart/build_heart.py -- \
        /path/to/CardioVascular41.fbx \
        assets/heart.obj \
        assets/heart-zanatomy.png \
        /tmp/heart_report.txt

Note: this build of Blender has a broken bundled glTF addon
(`ModuleNotFoundError: io_scene_gltf2.blender.exp.cache`), so the asset is
exported as OBJ (loaded in the scene with three's OBJLoader) rather than GLB.
"""

import bpy, sys, os, math, re, mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
src, obj_out, png_out, report = argv[0], argv[1], argv[2], argv[3]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)

KEEP = set([
    "Left atrium", "Right atrium", "Left ventricle", "Right ventricle",
    "Anterior semilunar leaflet of pulmonary valve",
    "Left semilunar leaflet of pulmonary valve",
    "Right semilunar leaflet of pulmonary valve",
    "Inferior leaflet of right atrioventricular valve",
    "Septal leaflet of right atrioventricular valve",
    "Posterior leaflet of left atrioventricular valve",
    "Left coronary leaflet", "Right coronary leaflet", "Non-coronary leaflet",
    "Anterior papillary muscle of right ventricle",
    "Inferior papillary muscle of left ventricle",
    "Inferior papillary muscle of right ventricle",
    "Septal papillary muscle of right ventricle",
    "Left coronary artery", "Right coronary artery",
    "Right inferolateral branch of right coronary artery",
    "Circumflex artery of heart", "Anterior interventricular artery",
    "Coronary sinus",
    "Inferior vein of left ventricle",
    "Inferior vein of left ventricle (//Posterior '')",
    "Septal branches of anterior interventricular artery",
    "Ascending aorta", "Aortic arch",
    "Pulmonary trunk", "Bifurcation of pulmonary trunk",
    "Left pulmonary artery", "Right pulmonary artery",
    "Superior vena cava", "Inferior vena cava (thoracic part)",
])


def base(n):
    return re.sub(r'\.\d{3}$', '', n)


def cat(n):
    n = n.lower()
    if 'leaflet' in n or 'valve' in n:
        return 'Valve'
    if 'vein' in n or 'vena cava' in n or 'sinus' in n:
        return 'Vein'
    if 'pulmonary' in n and ('trunk' in n or 'artery' in n):
        return 'Vein'
    if 'aort' in n or 'arter' in n or 'pulmonary' in n:
        return 'Artery'
    return 'Muscle'


COL = {
    'Artery': (0.70, 0.11, 0.11, 1.0),
    'Vein': (0.16, 0.32, 0.74, 1.0),
    'Muscle': (0.62, 0.18, 0.20, 1.0),
    'Valve': (0.93, 0.87, 0.76, 1.0),
}
mats = {}


def getmat(name):
    if name in mats:
        return mats[name]
    m = bpy.data.materials.new('ZaHeart_' + name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = COL[name]
    bsdf.inputs['Roughness'].default_value = 0.55
    m.diffuse_color = COL[name]
    mats[name] = m
    return m


meshes = [o for o in bpy.data.objects if o.type == 'MESH']
keep = [o for o in meshes if base(o.name) in KEEP]

for o in keep:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw

rep = ["keep %d of %d meshes" % (len(keep), len(meshes))]
found = set(base(o.name) for o in keep)
rep.append("MISSING: %s" % sorted(KEEP - found))

counts = {}
for o in keep:
    c = cat(base(o.name))
    counts[c] = counts.get(c, 0) + 1
    o.data.materials.clear()
    o.data.materials.append(getmat(c))
    for p in o.data.polygons:
        p.use_smooth = True
rep.append("category counts %s" % counts)

mn = [1e9] * 3
mx = [-1e9] * 3
for o in keep:
    for c in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(c)
        for i in range(3):
            mn[i] = min(mn[i], w[i])
            mx[i] = max(mx[i], w[i])
size = [mx[i] - mn[i] for i in range(3)]
center = mathutils.Vector([(mn[i] + mx[i]) / 2 for i in range(3)])
rep.append("bbox size=%s" % [round(v, 3) for v in size])

bpy.ops.object.select_all(action='DESELECT')
for o in list(bpy.data.objects):
    if o not in keep:
        o.select_set(True)
bpy.ops.object.delete()

bpy.ops.object.select_all(action='DESELECT')
for o in keep:
    o.select_set(True)
bpy.ops.wm.obj_export(filepath=obj_out, export_selected_objects=True,
                      export_materials=True, export_uv=True, export_normals=True)
rep.append("wrote %s (%d bytes)" % (obj_out, os.path.getsize(obj_out)))

# ---- render the wall chart ----
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'

world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
bgn = world.node_tree.nodes.get("Background")
bgn.inputs[0].default_value = (0.90, 0.91, 0.93, 1.0)
bgn.inputs[1].default_value = 1.0

r = max(size) / 2.0
cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 78
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
fov = 2 * math.atan(36.0 / (2 * 78))
dist = r / math.tan(fov / 2) * 1.40
look = mathutils.Vector((0.5, -1.0, 0.22)).normalized()
cam.location = center + look * dist

tgt = bpy.data.objects.new("Tgt", None)
scene.collection.objects.link(tgt)
tgt.location = center
con = cam.constraints.new('TRACK_TO')
con.target = tgt
con.track_axis = 'TRACK_NEGATIVE_Z'
con.up_axis = 'UP_Y'


def area_light(name, loc_dir, energy_scale, sz):
    ld = bpy.data.lights.new(name, 'AREA')
    ld.shape = 'DISK'
    ld.size = sz
    ld.energy = energy_scale * (dist ** 2)
    ob = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(ob)
    ob.location = center + loc_dir.normalized() * dist
    c2 = ob.constraints.new('TRACK_TO')
    c2.target = tgt
    c2.track_axis = 'TRACK_NEGATIVE_Z'
    c2.up_axis = 'UP_Y'


area_light("Key", mathutils.Vector((0.7, -0.9, 0.7)), 24.0, r * 1.6)
area_light("Fill", mathutils.Vector((-1.0, -0.8, 0.1)), 8.0, r * 2.4)
area_light("Rim", mathutils.Vector((-0.3, 0.8, 0.6)), 11.0, r * 1.8)

scene.render.filepath = png_out
bpy.ops.render.render(write_still=True)
rep.append("wrote %s (%d bytes)" % (png_out, os.path.getsize(png_out)))

try:
    img = bpy.data.images.load(png_out)
    px = list(img.pixels)
    w, h = img.size
    bg = (0.90, 0.91, 0.93)
    cnt = 0
    mnx, mny, mxx, mxy = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            if abs(px[i] - bg[0]) > 0.06 or abs(px[i + 1] - bg[1]) > 0.06 or abs(px[i + 2] - bg[2]) > 0.06:
                cnt += 1
                mnx = min(mnx, x); mxx = max(mxx, x); mny = min(mny, y); mxy = max(mxy, y)
    rep.append("MODELPIX %d frac %.3f bbox x%d..%d y%d..%d" % (cnt, cnt / (w * h), mnx, mxx, mny, mxy))
except Exception as e:
    rep.append("analysis err %s" % e)

open(report, "w", encoding="utf-8").write("\n".join(rep))
print("BUILD_DONE")
print("\n".join(rep))
