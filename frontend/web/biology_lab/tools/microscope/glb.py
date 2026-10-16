"""Minimal glTF 2.0 binary (GLB) writer / reader for the Node/Geo scene graph."""
import numpy as np, json, struct, io
from geo import *
from PIL import Image

def write_glb(root, path, tex_images, scale=1.0, extras=None):
    buf = bytearray(); views = []; accs = []; meshes = []; nodes = []; materials = []; textures = []; images = []; samplers = [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 33071, 'wrapT': 33071}]
    def add_view(data, target=None):
        while len(buf) % 4: buf.append(0)
        v = {'buffer': 0, 'byteOffset': len(buf), 'byteLength': len(data)}
        if target: v['target'] = target
        buf.extend(data); views.append(v); return len(views) - 1
    def add_acc(arr, ctype, typ, target=None, minmax=False):
        data = arr.tobytes(); vi = add_view(data, target); a = {'bufferView': vi, 'componentType': ctype, 'count': int(arr.shape[0]), 'type': typ}
        if minmax: a['min'] = arr.min(0).astype(float).tolist(); a['max'] = arr.max(0).astype(float).tolist()
        accs.append(a); return len(accs) - 1
    mat_index = {}; ext_used = set()
    def material(name):
        if name in mat_index: return mat_index[name]
        m = MATS[name]; c = list(m['color'][:3]); a = m['alpha']
        d = {'name': name, 'pbrMetallicRoughness': {'baseColorFactor': c + [a], 'metallicFactor': float(m['metal']), 'roughnessFactor': float(m['rough'])}}
        if m.get('tex'):
            im = tex_images[m['tex']]; b = io.BytesIO(); im.save(b, 'PNG'); vi = add_view(b.getvalue()); images.append({'bufferView': vi, 'mimeType': 'image/png', 'name': m['tex']})
            textures.append({'sampler': 0, 'source': len(images) - 1}); d['pbrMetallicRoughness']['baseColorTexture'] = {'index': len(textures) - 1}
        if a < 1 or m.get('decal') and m.get('blend'): d['alphaMode'] = 'BLEND'
        if m.get('double') or m.get('decal'): d['doubleSided'] = True
        if m.get('emissive') is not None:
            e = np.array(m['emissive'], float); s = max(1.0, e.max()); d['emissiveFactor'] = (e / s).tolist(); d['extensions'] = {'KHR_materials_emissive_strength': {'emissiveStrength': float(s)}}; ext_used.add('KHR_materials_emissive_strength')
        if m.get('clearcoat'): d.setdefault('extensions', {})['KHR_materials_clearcoat'] = {'clearcoatFactor': float(m['clearcoat']), 'clearcoatRoughnessFactor': 0.12}; ext_used.add('KHR_materials_clearcoat')
        materials.append(d); mat_index[name] = len(materials) - 1; return mat_index[name]
    counts = {}
    def emit(n, is_root=False):
        counts[n.name] = counts.get(n.name, 0) + 1; nm = n.name if counts[n.name] == 1 else f'{n.name}_{counts[n.name]}'
        gn = {'name': nm}; M = n.M if not is_root else n.M @ np.diag([scale, scale, scale, 1.0])
        if not np.allclose(M, np.eye(4)): gn['matrix'] = M.T.reshape(-1).astype(float).tolist()
        if n.meshes:
            prims = []
            for geo, mn, _ in n.meshes:
                p = {'attributes': {'POSITION': add_acc(geo.P.astype(np.float32), 5126, 'VEC3', 34962, True), 'NORMAL': add_acc(geo.N.astype(np.float32), 5126, 'VEC3', 34962)}, 'indices': (add_acc(geo.I.astype(np.uint16).reshape(-1), 5123, 'SCALAR', 34963) if len(geo.P) < 65535 else add_acc(geo.I.astype(np.uint32).reshape(-1), 5125, 'SCALAR', 34963)), 'material': material(mn), 'mode': 4}
                if geo.UV is not None: p['attributes']['TEXCOORD_0'] = add_acc(geo.UV.astype(np.float32), 5126, 'VEC2', 34962)
                prims.append(p)
            meshes.append({'name': nm + '_mesh', 'primitives': prims}); gn['mesh'] = len(meshes) - 1
        if n.extras: gn['extras'] = n.extras
        nodes.append(gn); idx = len(nodes) - 1
        ch = [emit(c) for c in n.children]
        if ch: gn['children'] = ch
        return idx
    r = emit(root, True)
    doc = {'asset': {'version': '2.0', 'generator': 'Penrose ScholarMw microscope builder', 'extras': extras or {}}, 'scene': 0, 'scenes': [{'name': 'Scene', 'nodes': [r]}],
           'nodes': nodes, 'meshes': meshes, 'materials': materials, 'accessors': accs, 'bufferViews': views, 'buffers': [{'byteLength': len(buf)}]}
    if textures: doc['textures'] = textures; doc['images'] = images; doc['samplers'] = samplers
    if ext_used: doc['extensionsUsed'] = sorted(ext_used)
    js = json.dumps(doc, separators=(',', ':')).encode(); js += b' ' * (-len(js) % 4); bb = bytes(buf) + b'\0' * (-len(buf) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bb)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bb), 0x004E4942) + bb
    open(path, 'wb').write(out); return len(out), len(nodes), len(meshes), len(materials)

def read_glb(path):
    d = open(path, 'rb').read(); magic, ver, ln = struct.unpack('<III', d[:12]); assert magic == 0x46546C67 and ver == 2
    jl, jt = struct.unpack('<II', d[12:20]); doc = json.loads(d[20:20 + jl]); off = 20 + jl; bl, bt = struct.unpack('<II', d[off:off + 8]); bin_ = d[off + 8: off + 8 + bl]
    def acc(i):
        a = doc['accessors'][i]; v = doc['bufferViews'][a['bufferView']]; ct = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a['componentType']]; nc = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[a['type']]
        arr = np.frombuffer(bin_, ct, a['count'] * nc, v['byteOffset']); return arr.reshape(-1, nc) if nc > 1 else arr
    mats = {}
    for m in doc['materials']:
        p = m['pbrMetallicRoughness']; bc = p['baseColorFactor']; em = m.get('emissiveFactor'); st = m.get('extensions', {}).get('KHR_materials_emissive_strength', {}).get('emissiveStrength', 1)
        MATS[m['name']] = dict(color=tuple(bc[:3]), metal=p['metallicFactor'], rough=p['roughnessFactor'], emissive=None if em is None else tuple(np.array(em) * st), alpha=bc[3], clearcoat=m.get('extensions', {}).get('KHR_materials_clearcoat', {}).get('clearcoatFactor', 0), tex='baseColorTexture' in p, double=m.get('doubleSided', False) and bc[3] < 1, decal='baseColorTexture' in p)
    def build(i):
        gn = doc['nodes'][i]; M = np.eye(4) if 'matrix' not in gn else np.array(gn['matrix']).reshape(4, 4).T
        n = Node(gn['name'], M); n.extras = gn.get('extras', {})
        if 'mesh' in gn:
            for p in doc['meshes'][gn['mesh']]['primitives']:
                at = p['attributes']; n.meshes.append((Geo(acc(at['POSITION']), acc(at['NORMAL']), acc(p['indices']).reshape(-1, 3), acc(at['TEXCOORD_0']) if 'TEXCOORD_0' in at else None), doc['materials'][p['material']]['name'], None))
        for c in gn.get('children', []): n.children.append(build(c))
        return n
    return build(doc['scenes'][0]['nodes'][0]), doc
