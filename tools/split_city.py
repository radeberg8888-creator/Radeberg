"""Zerlegt einen Stadt-Chunk (glTF) in einzelne Gebäude.
1) alle Dreiecke in Weltkoordinaten, 2) zusammenhängende Teile (gemeinsame Eckpunkte),
3) Teile, deren Grundrisse sich überlappen, zu Gebäuden gruppieren, 4) Boden/Straßen (flach & groß) verwerfen,
5) jedes Gebäude als eigenes glTF (Boden auf y=0, mittig) mit den Original-Materialien schreiben.
Aufruf: split_city.py <chunk.gltf> <ausgabeordner> <prefix> [skala]"""
import json, os, sys, shutil
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
sys.path.insert(0, os.path.dirname(__file__))
from autorig import read_acc, node_mat

def run(src, outdir, prefix, scale=1.0):
    d = os.path.dirname(src); j = json.load(open(src)); binb = open(os.path.join(d, j['buffers'][0]['uri']), 'rb').read()
    W = {}
    def walk(i, M):
        W[i] = M @ node_mat(j['nodes'][i])
        for c in j['nodes'][i].get('children', []): walk(c, W[i])
    for r in j['scenes'][j.get('scene', 0)]['nodes']: walk(r, np.eye(4))
    parts = []   # (material, P, N, UV, tris)
    for ni, n in enumerate(j['nodes']):
        if 'mesh' not in n: continue
        M = W[ni]; Nm = np.linalg.inv(M[:3, :3]).T
        for p in j['meshes'][n['mesh']]['primitives']:
            if p.get('mode', 4) != 4: continue
            P = read_acc(j, binb, p['attributes']['POSITION']).astype(np.float64); P = (M[:3, :3] @ P.T).T + M[:3, 3]
            N = read_acc(j, binb, p['attributes']['NORMAL']).astype(np.float64) if 'NORMAL' in p['attributes'] else np.zeros_like(P)
            N = (Nm @ N.T).T; N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
            UV = read_acc(j, binb, p['attributes']['TEXCOORD_0']).astype(np.float32) if 'TEXCOORD_0' in p['attributes'] else np.zeros((len(P), 2), np.float32)
            I = read_acc(j, binb, p['indices']).reshape(-1, 3) if 'indices' in p else np.arange(len(P)).reshape(-1, 3)
            parts.append([p.get('material'), P * scale, N, UV, I])
    # Komponenten je Teil
    comps = []   # (part_idx, tri_mask_idx, bbox_min, bbox_max)
    for pi, (mat, P, N, UV, I) in enumerate(parts):
        nv = len(P)
        # gleiche Positionen verschweißen (UV-Nähte)
        key = np.round(P / 0.01).astype(np.int64)
        _, inv = np.unique(key, axis=0, return_inverse=True); inv = inv.reshape(-1)
        a = inv[I[:, 0]]; b = inv[I[:, 1]]; c = inv[I[:, 2]]
        m = inv.max() + 1
        g = coo_matrix((np.ones(len(I) * 2), (np.concatenate([a, b]), np.concatenate([b, c]))), shape=(m, m))
        nc, lab = connected_components(g, directed=False)
        tl = lab[a]
        for k in range(nc):
            sel = np.where(tl == k)[0]
            if len(sel) == 0: continue
            v = P[I[sel].reshape(-1)]
            comps.append((pi, sel, v.min(0), v.max(0)))
    lo = np.min([c[2] for c in comps], 0); hi = np.max([c[3] for c in comps], 0); gy = lo[1]
    span = max(hi[0] - lo[0], hi[2] - lo[2])
    keep = []
    for c in comps:
        sz = c[3] - c[2]
        flat = sz[1] < 0.6 and max(sz[0], sz[2]) > 5.0
        huge = max(sz[0], sz[2]) > 0.6 * span
        low = c[3][1] < gy + 0.35   # Bodenbelag, Bordsteine
        if flat or huge or low: continue
        keep.append(c)
    # Gruppieren: Grundriss-Überlappung
    n = len(keep); par = list(range(n))
    def f(i):
        while par[i] != i: par[i] = par[par[i]]; i = par[i]
        return i
    order = sorted(range(n), key=lambda i: keep[i][2][0])
    for ii, i in enumerate(order):
        a0, a1 = keep[i][2], keep[i][3]
        for j2 in order[ii + 1:]:
            b0, b1 = keep[j2][2], keep[j2][3]
            if b0[0] > a1[0] + 0.1: break
            if b0[2] <= a1[2] + 0.1 and b1[2] >= a0[2] - 0.1:
                x, y = f(i), f(j2)
                if x != y: par[x] = y
    groups = {}
    for i in range(n): groups.setdefault(f(i), []).append(keep[i])
    os.makedirs(outdir, exist_ok=True)
    # Texturen einmal kopieren
    for im in j.get('images', []):
        if 'uri' in im and not os.path.exists(os.path.join(outdir, im['uri'])): shutil.copy(os.path.join(d, im['uri']), os.path.join(outdir, im['uri']))
    out = []
    k = 0
    for g in groups.values():
        b0 = np.min([c[2] for c in g], 0); b1 = np.max([c[3] for c in g], 0); sz = b1 - b0
        h = b1[1] - gy
        if h < 5.0 or sz[0] < 4.0 or sz[2] < 4.0 or max(sz[0], sz[2]) > 110: continue
        ctr = np.array([(b0[0] + b1[0]) / 2, gy, (b0[2] + b1[2]) / 2])
        # je Material sammeln
        bym = {}
        for (pi, sel, _, _) in g:
            mat, P, N, UV, I = parts[pi]
            bym.setdefault(mat, []).append((P, N, UV, I[sel]))
        binv = bytearray(); views = []; accs = []; prims = []
        def add(arr, typ, comp, target=None, mm=False):
            while len(binv) % 4: binv.append(0)
            o = len(binv); binv.extend(arr.tobytes()); v = {'buffer': 0, 'byteOffset': o, 'byteLength': arr.nbytes}
            if target: v['target'] = target
            views.append(v); a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': len(arr), 'type': typ}
            if mm: a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
            accs.append(a); return len(accs) - 1
        for mat, lst in bym.items():
            Ps = []; Ns = []; Us = []; Is = []; off = 0
            for (P, N, UV, T) in lst:
                used, remap = np.unique(T.reshape(-1), return_inverse=True)
                Ps.append(P[used] - ctr); Ns.append(N[used]); Us.append(UV[used]); Is.append(remap.reshape(-1, 3) + off); off += len(used)
            Pa = np.concatenate(Ps).astype(np.float32); Na = np.concatenate(Ns).astype(np.float32); Ua = np.concatenate(Us).astype(np.float32); Ia = np.concatenate(Is).astype(np.uint32)
            pr = {'attributes': {'POSITION': add(Pa, 'VEC3', 5126, 34962, True), 'NORMAL': add(Na, 'VEC3', 5126, 34962), 'TEXCOORD_0': add(Ua, 'VEC2', 5126, 34962)}, 'indices': add(Ia.reshape(-1), 'SCALAR', 5125, 34963), 'mode': 4}
            if mat is not None: pr['material'] = mat
            prims.append(pr)
        name = f'{prefix}_{k:02d}'; k += 1
        g2 = {'asset': {'version': '2.0'}, 'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'name': name, 'mesh': 0}], 'meshes': [{'name': name, 'primitives': prims}],
              'buffers': [{'uri': name + '.bin', 'byteLength': len(binv)}], 'bufferViews': views, 'accessors': accs}
        for kk in ('materials', 'textures', 'images', 'samplers'):
            if kk in j: g2[kk] = j[kk]
        open(os.path.join(outdir, name + '.bin'), 'wb').write(binv); json.dump(g2, open(os.path.join(outdir, name + '.gltf'), 'w'))
        out.append({'file': name + '.gltf', 'w': float(sz[0]), 'd': float(sz[2]), 'h': float(h)})
    json.dump(out, open(os.path.join(outdir, prefix + '_index.json'), 'w'))
    print('ok', src, 'Gebäude', len(out), 'Höhen', sorted(int(o['h']) for o in out))

if __name__ == '__main__':
    run(sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]) if len(sys.argv) > 4 else 1.0)
