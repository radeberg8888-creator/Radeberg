"""Automatisches Rigging für unbewegliche Figuren (Scan-Modelle von Sketchfab).
Baut ein Mixamo-kompatibles Skelett aus Körperproportionen und berechnet Skin-Gewichte.
Aufruf: autorig.py <in.gltf> <out.gltf> [arms=auto|tpose|down]"""
import json, os, sys, struct
import numpy as np

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}

def read_acc(j, binb, i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    dt = np.dtype(CT[a['componentType']]); n = NC[a['type']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0); stride = bv.get('byteStride', 0)
    if stride and stride != dt.itemsize * n:
        raw = np.frombuffer(binb, np.uint8, a['count'] * stride, off).reshape(a['count'], stride)[:, :dt.itemsize * n]
        arr = raw.copy().view(dt).reshape(a['count'], n)
    else:
        arr = np.frombuffer(binb, dt, a['count'] * n, off).reshape(a['count'], n).copy()
    return arr if n > 1 else arr[:, 0]

def node_mat(n):
    if 'matrix' in n: return np.array(n['matrix'], float).reshape(4, 4).T
    T = np.eye(4); T[:3, 3] = n.get('translation', [0, 0, 0])
    x, y, z, w = n.get('rotation', [0, 0, 0, 1])
    R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    S = np.diag(n.get('scale', [1, 1, 1]) + [1]); M = np.eye(4); M[:3, :3] = R
    return T @ M @ S

def seg_dist(P, a, b):
    ab = b - a; t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-12), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)

def run(src, dst, arms='auto'):
    d = os.path.dirname(src); j = json.load(open(src))
    binb = open(os.path.join(d, j['buffers'][0]['uri']), 'rb').read()
    # Weltmatrizen
    W = {}
    def walk(i, M):
        W[i] = M @ node_mat(j['nodes'][i])
        for c in j['nodes'][i].get('children', []): walk(c, W[i])
    for r in j['scenes'][j.get('scene', 0)]['nodes']: walk(r, np.eye(4))
    prims = []
    for ni, n in enumerate(j['nodes']):
        if 'mesh' not in n: continue
        M = W[ni]; Nm = np.linalg.inv(M[:3, :3]).T
        for p in j['meshes'][n['mesh']]['primitives']:
            P = read_acc(j, binb, p['attributes']['POSITION']).astype(float)
            P = (M[:3, :3] @ P.T).T + M[:3, 3]
            N = read_acc(j, binb, p['attributes']['NORMAL']).astype(float) if 'NORMAL' in p['attributes'] else np.zeros_like(P)
            N = (Nm @ N.T).T; N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
            UV = read_acc(j, binb, p['attributes']['TEXCOORD_0']).astype(np.float32) if 'TEXCOORD_0' in p['attributes'] else np.zeros((len(P), 2), np.float32)
            COL = None
            if 'COLOR_0' in p['attributes']:
                a = j['accessors'][p['attributes']['COLOR_0']]; COL = read_acc(j, binb, p['attributes']['COLOR_0']).astype(np.float32)
                if a['componentType'] == 5121: COL /= 255.0
                elif a['componentType'] == 5123: COL /= 65535.0
                if COL.shape[1] == 3: COL = np.concatenate([COL, np.ones((len(COL), 1), np.float32)], 1)
            I = read_acc(j, binb, p['indices']).astype(np.uint32) if 'indices' in p else np.arange(len(P), dtype=np.uint32)
            prims.append(dict(P=P, N=N, UV=UV, I=I, mat=p.get('material'), COL=COL))
    allP = np.concatenate([q['P'] for q in prims])
    # auf Meter normieren: Füße auf 0, Mitte x/z
    y0 = allP[:, 1].min(); H = allP[:, 1].max() - y0
    cx = (allP[:, 0].min() + allP[:, 0].max()) / 2
    lowz = allP[allP[:, 1] < y0 + 0.5 * H][:, 2]; cz = (lowz.min() + lowz.max()) / 2
    sc = 1.0 / H  # Einheitshöhe 1, später in Godot auf echte Größe
    for q in prims:
        q['P'] = (q['P'] - [cx, y0, cz]) * sc
    V = np.concatenate([q['P'] for q in prims])
    # Blickrichtung: Zehen zeigen nach vorn
    feet = V[V[:, 1] < 0.03]; shins = V[(V[:, 1] > 0.1) & (V[:, 1] < 0.2)]
    fwd = 1.0 if feet[:, 2].mean() > shins[:, 2].mean() else -1.0
    if fwd < 0:  # um 180° drehen, damit +Z vorn ist
        for q in prims: q['P'][:, [0, 2]] *= -1; q['N'][:, [0, 2]] *= -1
        V = np.concatenate([q['P'] for q in prims])
    def zc(y, half=0.02, xw=0.08):
        s = V[(abs(V[:, 1] - y) < half) & (abs(V[:, 0]) < xw)]
        return (s[:, 2].min() + s[:, 2].max()) / 2 if len(s) else 0.0
    span = np.abs(V[:, 0]).max()
    armv = V[np.abs(V[:, 0]) > 0.25]
    print('span', span, 'armv', len(armv))
    tpose = arms == 'tpose' or (arms == 'auto' and span > 0.25 and len(armv) > 200)
    leg = V[(V[:, 1] > 0.44) & (V[:, 1] < 0.47) & (V[:, 0] > 0.01)]
    legx = np.median(leg[:, 0]) if len(leg) else 0.09
    J = {}
    J['Hips'] = (None, [0, 0.53, zc(0.53)])
    J['Spine'] = ('Hips', [0, 0.60, zc(0.60)]); J['Spine1'] = ('Spine', [0, 0.67, zc(0.67)]); J['Spine2'] = ('Spine1', [0, 0.74, zc(0.74)])
    nz = zc(0.835, xw=0.05)
    J['Neck'] = ('Spine2', [0, 0.835, nz]); J['Head'] = ('Neck', [0, 0.875, nz]); J['HeadTop_End'] = ('Head', [0, 1.0, nz])
    if tpose:
        tip = armv[np.argmax(np.abs(armv[:, 0]))]; az = np.median(armv[:, 2])
        S0 = np.array([0.10, 0.80]); T0 = np.array([abs(tip[0]), tip[1]])
        lerp = lambda f: S0 + (T0 - S0) * f
        arm = [lerp(0), lerp(0.42), lerp(0.76), T0]
    else:
        ay, az = 0.81, zc(0.74); arm = [0.10, 0.10, 0.10, 0.10]
    for s, nm in ((1, 'Left'), (-1, 'Right')):
        J[nm + 'Shoulder'] = ('Spine2', [s * 0.03, 0.80, az])
        if tpose:
            J[nm + 'Arm'] = (nm + 'Shoulder', [s * arm[0][0], arm[0][1], az]); J[nm + 'ForeArm'] = (nm + 'Arm', [s * arm[1][0], arm[1][1], az])
            J[nm + 'Hand'] = (nm + 'ForeArm', [s * arm[2][0], arm[2][1], az])
        else:  # Arme hängen: Knochen nach unten
            J[nm + 'Arm'] = (nm + 'Shoulder', [s * 0.10, 0.80, az]); J[nm + 'ForeArm'] = (nm + 'Arm', [s * 0.12, 0.62, az])
            J[nm + 'Hand'] = (nm + 'ForeArm', [s * 0.13, 0.47, az])
        def lx(y, h=0.015):
            sl = V[(abs(V[:, 1] - y) < h) & (V[:, 0] * s > 0.005)]
            return float(np.median(np.abs(sl[:, 0]))) if len(sl) else legx
        kx, fx = lx(0.28), lx(0.06)
        J[nm + 'UpLeg'] = ('Hips', [s * legx, 0.50, zc(0.5, xw=0.2)])
        J[nm + 'Leg'] = (nm + 'UpLeg', [s * kx, 0.28, zc(0.28, xw=0.2) + 0.01])
        J[nm + 'Foot'] = (nm + 'Leg', [s * fx, 0.045, zc(0.05, xw=0.2) - 0.01])
        legx_s = fx
        fz = V[(V[:, 1] < 0.03) & (V[:, 0] * s > 0)][:, 2].max()
        J[nm + 'ToeBase'] = (nm + 'Foot', [s * fx, 0.012, J[nm + 'Foot'][1][2] + (fz - J[nm + 'Foot'][1][2]) * 0.65])
        J[nm + 'Toe_End'] = (nm + 'ToeBase', [s * fx, 0.012, fz])
    names = list(J.keys()); idx = {k: i for i, k in enumerate(names)}
    pos = {k: np.array(v[1], float) for k, v in J.items()}
    child = {}
    for k, (p, _) in J.items():
        if p: child.setdefault(p, k)
    child['LeftHand'] = None; child['RightHand'] = None
    def seg(k):
        a = pos[k]; c = child.get(k)
        if c: return a, pos[c]
        if k.endswith('Hand'): return a, a + (a - pos[J[k][0]]) * 0.6
        return a, a + np.array([0, 0.03, 0])
    # Bereiche
    torso = ['Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head']
    out_prims = []
    for q in prims:
        P = q['P']; n = len(P)
        Jw = np.zeros((n, 4), np.uint16); Ww = np.zeros((n, 4), np.float32)
        D = {k: seg_dist(P, *seg(k)) for k in names if not k.endswith('_End')}
        for vi_side in (1, -1):
            nm = 'Left' if vi_side > 0 else 'Right'
            m_side = (P[:, 0] * vi_side >= 0)
            if tpose:
                dA = np.minimum.reduce([D[nm + b] for b in ('Arm', 'ForeArm', 'Hand')])
                dT = np.minimum.reduce([D[b] for b in ('Spine', 'Spine1', 'Spine2', 'Hips', nm + 'UpLeg')])
                m_arm = m_side & (np.abs(P[:, 0]) > 0.12) & (P[:, 1] > 0.4) & (dA < dT)
            else:
                m_arm = np.zeros(n, bool)
            m_leg = m_side & ~m_arm & (P[:, 1] < 0.50) & (np.abs(P[:, 0]) > 0.005)
            for mask, bones in ((m_arm, ['Spine2', nm + 'Shoulder', nm + 'Arm', nm + 'ForeArm', nm + 'Hand']),
                                (m_leg, ['Hips', nm + 'UpLeg', nm + 'Leg', nm + 'Foot', nm + 'ToeBase'])):
                if not mask.any(): continue
                Dm = np.stack([D[b][mask] for b in bones], 1)
                if bones[0] == 'Hips':
                    Dm[:, 0] += np.clip(0.50 - P[mask, 1], 0, None) * 3  # Hüfte nur ganz oben
                    low = P[mask, 1] < 0.075   # Fuß: nur Fuß- und Zehenknochen (sonst zieht die Ferse mit der Wade)
                    Dm[low, 0:3] += 1.0
                _assign(Jw, Ww, mask, Dm, [idx[b] for b in bones])
                if bones[0] == 'Hips':  # Kleidung (Mantel, Rock) weit weg vom Bein: teilweise an die Hüfte
                    dl = np.minimum.reduce([D[nm + b][mask] for b in ('UpLeg', 'Leg', 'Foot', 'ToeBase')])
                    dl[P[mask, 1] < 0.12] = 0.0   # Füße/Schuhe nie an die Hüfte
                    f = np.clip(1 - (dl - 0.055) / 0.05, 0.25, 1.0)
                    sub = np.where(mask)[0]
                    Wm = Ww[sub] * f[:, None]; Jm = Jw[sub]
                    hips = idx['Hips']; add = 1 - f
                    hit = (Jm == hips) & (Wm > 0)
                    has = hit.any(1)
                    Wm[hit] += np.repeat(add, 4).reshape(-1, 4)[hit]
                    slot = np.argmin(Wm + (Jm == hips) * 9, 1)
                    for r in np.where(~has)[0]: Jm[r, slot[r]] = hips; Wm[r, slot[r]] = add[r]
                    Ww[sub] = Wm / Wm.sum(1, keepdims=True); Jw[sub] = Jm
        rest = ~(Ww.sum(1) > 0)
        bones = torso + ['LeftShoulder', 'RightShoulder', 'LeftUpLeg', 'RightUpLeg']
        if not tpose: bones = bones  # hängende Arme bleiben am Oberkörper
        Dm = np.stack([D[b][rest] for b in bones], 1)
        Dm[:, -2:] += (np.clip(P[rest, 1] - 0.5, 0, None) * 4 + 0.02)[:, None]
        Dm[:, -4:-2] += 0.03
        _assign(Jw, Ww, rest, Dm, [idx[b] for b in bones])
        q['J'] = Jw; q['W'] = Ww
    # glTF schreiben
    out = {'asset': {'version': '2.0', 'generator': 'radeberg autorig'}, 'scene': 0}
    for k in ('materials', 'textures', 'images', 'samplers'):
        if k in j: out[k] = j[k]
    binv = bytearray(); views = []; accs = []
    def add(arr, typ, comp, target=None, mm=False):
        while len(binv) % 4: binv.append(0)
        o = len(binv); binv.extend(arr.tobytes()); v = {'buffer': 0, 'byteOffset': o, 'byteLength': arr.nbytes}
        if target: v['target'] = target
        views.append(v); a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': len(arr), 'type': typ}
        if mm: a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
        accs.append(a); return len(accs) - 1
    mp = []
    for q in prims:
        pr = {'attributes': {'POSITION': add(q['P'].astype(np.float32), 'VEC3', 5126, 34962, True), 'NORMAL': add(q['N'].astype(np.float32), 'VEC3', 5126, 34962),
              'TEXCOORD_0': add(q['UV'], 'VEC2', 5126, 34962), 'JOINTS_0': add(q['J'], 'VEC4', 5123, 34962), 'WEIGHTS_0': add(q['W'], 'VEC4', 5126, 34962)},
              'indices': add(q['I'], 'SCALAR', 5125, 34963), 'mode': 4}
        if q.get('COL') is not None: pr['attributes']['COLOR_0'] = add(np.ascontiguousarray(q['COL']), 'VEC4', 5126, 34962)
        if q['mat'] is not None: pr['material'] = q['mat']
        mp.append(pr)
    nodes = [{'name': 'Character', 'children': [1, 2]}, {'name': 'Body', 'mesh': 0, 'skin': 0}]
    base = len(nodes)
    for k in names:
        p = J[k][0]; t = pos[k] - (pos[p] if p else 0)
        nodes.append({'name': 'mixamorig:' + k, 'translation': t.tolist()})
    for k in names:
        p = J[k][0]
        if p: nodes[base + idx[p]].setdefault('children', []).append(base + idx[k])
    nodes[0]['children'] = [1, base + idx['Hips']]
    ibm = np.stack([np.linalg.inv(np.block([[np.eye(3), pos[k][:, None]], [np.zeros((1, 3)), np.ones((1, 1))]])).T.reshape(-1) for k in names]).astype(np.float32)
    out['nodes'] = nodes; out['meshes'] = [{'name': 'Body', 'primitives': mp}]
    out['skins'] = [{'joints': [base + i for i in range(len(names))], 'skeleton': base + idx['Hips'], 'inverseBindMatrices': add(ibm, 'MAT4', 5126)}]
    out['scenes'] = [{'nodes': [0]}]
    stem = os.path.splitext(os.path.basename(dst))[0]
    out['buffers'] = [{'uri': stem + '.bin', 'byteLength': len(binv)}]; out['bufferViews'] = views; out['accessors'] = accs
    open(os.path.join(os.path.dirname(dst), stem + '.bin'), 'wb').write(binv)
    json.dump(out, open(dst, 'w'))
    print('ok', dst, 'tpose' if tpose else 'arms-down', 'verts', sum(len(q['P']) for q in prims))

def _assign(Jw, Ww, mask, Dm, ids, k=3, p=6.0):
    o = np.argsort(Dm, 1)[:, :k]; d = np.take_along_axis(Dm, o, 1) + 1e-4
    w = (d[:, :1] / d) ** p; w /= w.sum(1, keepdims=True)
    ids = np.array(ids)
    J = np.zeros((len(o), 4), np.uint16); W = np.zeros((len(o), 4), np.float32)
    J[:, :k] = ids[o]; W[:, :k] = w
    Jw[mask] = J; Ww[mask] = W

if __name__ == '__main__':
    run(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'auto')
