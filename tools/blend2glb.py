"""Wandelt Poly-Haven-.blend-Modelle (Blender 5) ohne Blender in .glb um.
Aufruf: python3 blend2glb.py <in.blend> <out.glb> <texturordner> [objektfilter-regex]
Texturen: Dateien *_diff_*, *_nor_gl_*, *_rough_*, *_metal_* werden dem passenden Material zugeordnet."""
import sys, os, re, json, struct, math
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from blendread import Blend, owner_maps
from PIL import Image

def cstr(B, blk):
    return B.d[blk['off']:blk['off'] + blk['len']].split(b'\0')[0].decode('utf8', 'replace')

def read_mesh(B, idx, loc):
    b = B.blocks[idx]; M = B.read_struct('Mesh', b['off'], 1)
    attrs = {}
    ab = loc.get(M['attribute_storage']['dna_attributes']) if 'attribute_storage' in M else None
    attrs = {}
    if not ab:
        lsz = B.tlen[B.types.index('CustomDataLayer')]
        for dom, key in ((0, 'vdata'), (1, 'edata'), (2, 'pdata'), (3, 'ldata')):
            CD = M[key]; lb = loc.get(CD['layers'])
            if not lb: continue
            for k in range(CD['totlayer']):
                Ly = B.read_struct('CustomDataLayer', lb['off'] + k * lsz, 1)
                raw = loc.get(Ly['data'])
                if raw: attrs[Ly['name'] or f'_{key}{k}'] = (Ly['type'], dom, B.d[raw['off']:raw['off'] + raw['len']])
    if ab:
        sz = B.tlen[B.types.index('Attribute')]
        for k in range(ab['nr']):
            A = B.read_struct('Attribute', ab['off'] + k * sz, 1)
            nm = loc.get(A['name']);
            if not nm: continue
            name = cstr(B, nm)
            dblk = loc.get(A['data'])
            if not dblk: continue
            arr = B.read_struct('AttributeArray' if A['storage_type'] == 0 else 'AttributeSingle', dblk['off'], 1)
            raw = loc.get(arr['data'])
            if raw: attrs[name] = (A['data_type'], A['domain'], B.d[raw['off']:raw['off'] + raw['len']])
    nv, nf, nc = M['totvert'], M['totpoly'], M['totloop']
    if 'position' not in attrs:   # altes Format (Blender 3.x): MVert/MLoop/MPoly/MLoopUV
        L = {}
        for name, (t, dom, raw) in attrs.items():
            if dom == 0 and len(raw) == nv * 16 and t == 0: L['mvert'] = raw
            if dom == 3 and len(raw) == nc * 8 and t == 26: L['mloop'] = raw
            if dom == 2 and len(raw) == nf * 12 and t == 25: L['mpoly'] = raw
            if dom == 3 and len(raw) == nc * 12 and t == 16 and 'uv' not in L: L['uv'] = raw
            if dom == 1 and t == 3: L['medge'] = raw
        mv = np.frombuffer(L['mvert'], np.uint8).reshape(nv, 16)
        attrs['position'] = (0, 0, mv[:, :12].copy().tobytes())
        ml = np.frombuffer(L['mloop'], np.uint32).reshape(nc, 2)
        attrs['.corner_vert'] = (0, 3, ml[:, 0].astype(np.int32).tobytes()); attrs['.corner_edge'] = (0, 3, ml[:, 1].astype(np.int32).tobytes())
        mp = np.frombuffer(L['mpoly'], np.uint8).reshape(nf, 12)
        ls = mp[:, 0:4].copy().view(np.int32).reshape(-1); tl = mp[:, 4:8].copy().view(np.int32).reshape(-1)
        attrs['_offsets'] = np.concatenate([ls, [ls[-1] + tl[-1]]]).astype(np.int32)
        attrs['material_index'] = (0, 2, mp[:, 8:10].copy().view(np.int16).astype(np.int32).tobytes())
        attrs['sharp_face'] = (0, 2, ((mp[:, 10] & 1) == 0).astype(np.uint8).tobytes())
        if 'uv' in L:
            uvl = np.frombuffer(L['uv'], np.uint8).reshape(nc, 12)[:, :8].copy().tobytes(); attrs['UVMap_legacy'] = (49, 3, uvl)
        if 'medge' in L and len(L['medge']) >= M['totedge'] * 12:
            me = np.frombuffer(L['medge'], np.uint8)[:M['totedge'] * 12].reshape(-1, 12); fl = me[:, 10:12].copy().view(np.uint16).reshape(-1)
            attrs['sharp_edge'] = (0, 1, ((fl & (1 << 9)) != 0).astype(np.uint8).tobytes())
    pos = np.frombuffer(attrs['position'][2], np.float32).reshape(nv, 3)
    cv = np.frombuffer(attrs['.corner_vert'][2], np.int32)[:nc]
    off = attrs['_offsets'] if '_offsets' in attrs else np.frombuffer(B.d, np.int32, nf + 1, loc[M['poly_offset_indices']]['off'])
    uv = None
    for k, v in attrs.items():
        if k == '_offsets': continue
        t, dom, raw = v
        if dom == 3 and len(raw) == nc * 8 and t != 26 and not k.startswith('.') and k not in ('.corner_vert', '.corner_edge'):
            uv = np.frombuffer(raw, np.float32).reshape(nc, 2); break
    mi = None
    if 'material_index' in attrs: mi = np.frombuffer(attrs['material_index'][2], np.int32)[:nf]
    sharp_face = np.frombuffer(attrs['sharp_face'][2], np.uint8)[:nf].astype(bool) if 'sharp_face' in attrs and len(attrs['sharp_face'][2]) >= nf else np.zeros(nf, bool)
    ce = np.frombuffer(attrs['.corner_edge'][2], np.int32)[:nc] if '.corner_edge' in attrs else None
    ne = M['totedge']
    sharp_edge = np.frombuffer(attrs['sharp_edge'][2], np.uint8)[:ne].astype(bool) if 'sharp_edge' in attrs and len(attrs['sharp_edge'][2]) >= ne else np.zeros(ne, bool)
    # Materialliste
    mats = []
    mp = loc.get(M['mat'])
    if mp:
        ptrs = struct.unpack_from('<%dQ' % M['totcol'], B.d, mp['off'])
        for p in ptrs:
            mb = MAT_BY_OLD.get(p); mats.append(B.read_struct('Material', mb['off'], 0)['id'] if mb else None)
    mats = [cstr_id(B, m) for m in mats]
    return dict(name=M['id']['name'][2:], pos=pos, cv=cv, off=off, uv=uv, mi=mi, sharp_face=sharp_face, ce=ce, sharp_edge=sharp_edge, mats=mats)

def cstr_id(B, idv):
    if idv is None: return None
    if isinstance(idv, tuple):
        o = idv[2]; n = B.read_struct('ID', o, 0)['name']; return n[2:]
    return idv['name'][2:]

def corner_normals(m):
    pos, cv, off = m['pos'], m['cv'], m['off']; nf = len(off) - 1; nc = len(cv)
    fid = np.repeat(np.arange(nf), np.diff(off))
    # Flächennormalen (Newell)
    p = pos[cv]; nxt = np.arange(nc) + 1; last = off[1:] - 1; nxt[last] = off[:-1]
    q = pos[cv[nxt]]
    cr = np.stack([(p[:, 1] - q[:, 1]) * (p[:, 2] + q[:, 2]), (p[:, 2] - q[:, 2]) * (p[:, 0] + q[:, 0]), (p[:, 0] - q[:, 0]) * (p[:, 1] + q[:, 1])], 1)
    fn = np.zeros((nf, 3)); np.add.at(fn, fid, cr)
    fl = np.linalg.norm(fn, axis=1, keepdims=True) + 1e-12; fnu = fn / fl
    # Ecken über weiche Kanten zusammenfassen (Union-Find)
    parent = np.arange(nc)
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]; a = parent[a]
        return a
    if m['ce'] is not None:
        ce = m['ce']; edge_corners = {}
        for c in range(nc): edge_corners.setdefault(int(ce[c]), []).append(c)
        sf = m['sharp_face']; se = m['sharp_edge']
        for e, cs in edge_corners.items():
            if len(cs) != 2 or (e < len(se) and se[e]): continue
            a, b = cs; fa, fb = fid[a], fid[b]
            if sf[fa] or sf[fb]: continue
            if np.dot(fnu[fa], fnu[fb]) < math.cos(math.radians(80)): continue
            an, bn = nxt[a], nxt[b]
            for x in (a, an):
                for y in (b, bn):
                    if cv[x] == cv[y]:
                        rx, ry = find(x), find(y)
                        if rx != ry: parent[rx] = ry
    roots = np.array([find(c) for c in range(nc)])
    acc = np.zeros((nc, 3)); np.add.at(acc, roots, fn[fid])
    cn = acc[roots]; cn /= (np.linalg.norm(cn, axis=1, keepdims=True) + 1e-12)
    return cn, fid, nxt

def euler_to_mat(r):
    x, y, z = r
    Rx = np.array([[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]])
    Ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    Rz = np.array([[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]])
    return Rz @ Ry @ Rx

def obj_matrix(B, O, ob_by_old):
    M = np.eye(4); M[:3, :3] = euler_to_mat(O['rot']) * np.array(O['size'])[None, :]; M[:3, 3] = O['loc']
    if O['parent'] and O['parent'] in ob_by_old:
        P = B.read_struct('Object', ob_by_old[O['parent']]['off'], 1)
        pinv = np.array(O['parentinv']).reshape(4, 4).T
        M = obj_matrix(B, P, ob_by_old) @ pinv @ M
    return M

MAT_BY_OLD = {}

def convert(blend, out, texdir, flt=None, center=True, maxtex=1024, origin=False):
    global MAT_BY_OLD
    B = Blend(blend); own = owner_maps(B)
    MAT_BY_OLD = {b['old']: b for b in B.blocks if b['code'] == 'MA'}
    ob_by_old = {b['old']: b for b in B.blocks if b['code'] == 'OB'}
    me_idx = {b['old']: i for i, b in enumerate(B.blocks) if b['code'] == 'ME'}
    prims = {}  # Materialname -> Listen
    for ob in [b for b in B.blocks if b['code'] == 'OB']:
        O = B.read_struct('Object', ob['off'], 1)
        name = O['id']['name'][2:]
        if O['type'] != 1 or O['data'] not in me_idx: continue
        if flt and not re.search(flt, name): continue
        i = me_idx[O['data']]; m = read_mesh(B, i, own[i])
        W = obj_matrix(B, O, ob_by_old)
        cn, fid, nxt = corner_normals(m)
        P = (W[:3, :3] @ m['pos'].T).T + (0 if origin else W[:3, 3])
        N = (np.linalg.inv(W[:3, :3]).T @ cn.T).T; N /= (np.linalg.norm(N, axis=1, keepdims=True) + 1e-12)
        if np.linalg.det(W[:3, :3]) < 0: N = -N
        nf = len(m['off']) - 1
        mi = m['mi'] if m['mi'] is not None else np.zeros(nf, np.int32)
        for f in range(nf):
            pass
        # Dreiecke als Fächer je Fläche
        cnt = np.diff(m['off'])
        tri_f = np.repeat(np.arange(nf), np.maximum(cnt - 2, 0))
        k = np.concatenate([np.arange(c - 2) for c in cnt if c >= 3]) if nf else np.array([], int)
        a = m['off'][:-1][tri_f]; b2 = a + 1 + k; c2 = a + 2 + k
        tris = np.stack([a, b2, c2], 1)
        for mat_i in np.unique(mi):
            sel = tris[mi[tri_f] == mat_i]
            mname = m['mats'][mat_i] if mat_i < len(m['mats']) else 'default'
            L = prims.setdefault(mname or 'default', [[], [], [], [], 0])
            corners = sel.reshape(-1)
            L[0].append(P[m['cv'][corners]]); L[1].append(N[corners])
            L[2].append(m['uv'][corners] if m['uv'] is not None else np.zeros((len(corners), 2), np.float32))
    # Blender Z-oben -> glTF Y-oben
    allp = np.concatenate([np.concatenate(v[0]) for v in prims.values()])
    conv = lambda v: np.stack([v[:, 0], v[:, 2], -v[:, 1]], 1)
    mn = conv(allp).min(0); mx = conv(allp).max(0)
    shift = np.array([-(mn[0] + mx[0]) / 2, -mn[1], -(mn[2] + mx[2]) / 2]) if center else np.zeros(3)
    bin_ = bytearray(); views = []; accs = []; meshes_prims = []; materials = []; images = []; textures = []
    def add_view(arr, target=None):
        nonlocal bin_
        while len(bin_) % 4: bin_ += b'\0'
        o = len(bin_); bb = arr.tobytes(); bin_ += bb
        v = {'buffer': 0, 'byteOffset': o, 'byteLength': len(bb)}
        if target: v['target'] = target
        views.append(v); return len(views) - 1
    def add_acc(arr, typ, comp=5126, mm=False, target=34962):
        v = add_view(arr, target); a = {'bufferView': v, 'componentType': comp, 'count': len(arr), 'type': typ}
        if mm: a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
        accs.append(a); return len(accs) - 1
    texfiles = sorted(os.listdir(texdir)) if texdir and os.path.isdir(texdir) else []
    def find_tex(mname, kind):
        key = re.sub(r'[^a-z0-9]', '', (mname or '').lower())
        cands = [f for f in texfiles if '_' + kind + '_' in f and f.lower().endswith(('.png', '.jpg'))]
        best = None; bs = -1
        for f in cands:
            base = re.sub(r'[^a-z0-9]', '', f.lower().split('_' + kind + '_')[0])
            s = len(os.path.commonprefix([base, key])) + (5 if base == key else 0)
            if s > bs: bs, best = s, f
        return best
    outdir = os.path.dirname(os.path.abspath(out)); stem = os.path.splitext(os.path.basename(out))[0]
    def add_image(path, suffix, kind):
        im = Image.open(path)
        if im.width > maxtex: im = im.resize((maxtex, maxtex * im.height // im.width), Image.LANCZOS)
        fn = f'{stem}_{suffix}.' + ('jpg' if kind == 'diff' else 'png')
        if kind == 'diff':
            im.convert('RGB').save(os.path.join(outdir, fn), quality=90)
        else:
            im.save(os.path.join(outdir, fn))
        images.append({'uri': fn}); textures.append({'source': len(images) - 1}); return len(textures) - 1
    for mi_, (mname, L) in enumerate(prims.items()):
        P = conv(np.concatenate(L[0])) + shift; N = conv(np.concatenate(L[1])); UV = np.concatenate(L[2]).copy(); UV[:, 1] = 1 - UV[:, 1]
        idx = np.arange(len(P), dtype=np.uint32)
        prim = {'attributes': {'POSITION': add_acc(P.astype(np.float32), 'VEC3', mm=True), 'NORMAL': add_acc(N.astype(np.float32), 'VEC3'), 'TEXCOORD_0': add_acc(UV.astype(np.float32), 'VEC2')},
                'indices': add_acc(idx, 'SCALAR', 5125, target=34963), 'material': mi_}
        meshes_prims.append(prim)
        mat = {'name': mname, 'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 1.0, 'roughnessFactor': 1.0}}
        d = find_tex(mname, 'diff'); n = find_tex(mname, 'nor_gl'); r = find_tex(mname, 'rough'); me = find_tex(mname, 'metal'); al = find_tex(mname, 'alpha')
        if al and re.sub(r'[^a-z0-9]', '', al.lower().split('_alpha_')[0]) != re.sub(r'[^a-z0-9]', '', (mname or '').lower()): al = None
        if d:
            if al:
                c = Image.open(os.path.join(texdir, d)).convert('RGB'); a = Image.open(os.path.join(texdir, al)).convert('L').resize(c.size)
                c.putalpha(a); c = c.resize((maxtex, maxtex * c.height // c.width)); tmp = os.path.join(outdir, f'{stem}_m{mi_}_rgba.png'); c.save(tmp)
                mat['pbrMetallicRoughness']['baseColorTexture'] = {'index': add_image(tmp, f'm{mi_}_col', 'png')}; mat['alphaMode'] = 'MASK'
            else:
                mat['pbrMetallicRoughness']['baseColorTexture'] = {'index': add_image(os.path.join(texdir, d), f'm{mi_}_col', 'diff')}
        if n: mat['normalTexture'] = {'index': add_image(os.path.join(texdir, n), f'm{mi_}_nrm', 'nor')}
        if r or me:
            ref = Image.open(os.path.join(texdir, r or me)).convert('L')
            ref = ref.resize((min(maxtex, ref.width), min(maxtex, ref.width) * ref.height // ref.width))
            R = ref if r else Image.new('L', ref.size, 200)
            Mt = Image.open(os.path.join(texdir, me)).convert('L').resize(ref.size) if me else Image.new('L', ref.size, 0)
            orm = Image.merge('RGB', (Image.new('L', ref.size, 255), R, Mt)); p = os.path.join(outdir, f'{stem}_m{mi_}_orm.png'); orm.save(p)
            mat['pbrMetallicRoughness']['metallicRoughnessTexture'] = {'index': add_image(p, f'm{mi_}_orm', 'orm')}
            if not me: mat['pbrMetallicRoughness']['metallicFactor'] = 0.0
        else:
            mat['pbrMetallicRoughness']['metallicFactor'] = 0.0; mat['pbrMetallicRoughness']['roughnessFactor'] = 0.6
        materials.append(mat)
    gltf = {'asset': {'version': '2.0', 'generator': 'radeberg blend2glb'}, 'scene': 0, 'scenes': [{'nodes': [0]}],
            'nodes': [{'name': stem, 'mesh': 0}], 'meshes': [{'name': stem, 'primitives': meshes_prims}],
            'materials': materials, 'accessors': accs, 'bufferViews': views, 'buffers': [{'byteLength': len(bin_)}]}
    if images: gltf['images'] = images; gltf['textures'] = textures
    js = json.dumps(gltf).encode()
    while len(js) % 4: js += b' '
    while len(bin_) % 4: bin_ += b'\0'
    total = 12 + 8 + len(js) + 8 + len(bin_)
    with open(out, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total)); f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(bin_), 0x004E4942)); f.write(bin_)
    size = (mx - mn)
    print('ok', out, 'materials', list(prims.keys()), 'tris', sum(len(np.concatenate(v[0])) // 3 for v in prims.values()), 'size', np.round(size, 3))

if __name__ == '__main__':
    convert(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
