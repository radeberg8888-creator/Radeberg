"""Haut-/Haarmaske pro Vertex für automatisch geriggte Scan-Figuren (aus autorig.py).
Schreibt TEXCOORD_1 = (Haut, Haar - Behalten) in die Rig-glTF:
  x = Haut 0..1, y > 0: Haar 0..1, y < 0: Originalfarbe behalten (Augen, Lippen, Brauen)
Entscheidung über Körperregion (dominanter Knochen) + Farbvergleich mit der Gesichtshaut, danach über Nachbarn geglättet."""
import json, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from autorig import read_acc

def lum(c): return c @ np.array([0.299, 0.587, 0.114])

def run(path):
    d = os.path.dirname(path); j = json.load(open(path)); binp = os.path.join(d, j['buffers'][0]['uri'])
    binb = open(binp, 'rb').read()
    joints = [j['nodes'][i]['name'].replace('mixamorig:', '') for i in j['skins'][0]['joints']]
    imgs = {}
    def tex_of(mat):
        if mat is None: return None
        m = j['materials'][mat]; pb = m.get('pbrMetallicRoughness', {}); t = pb.get('baseColorTexture')
        if not t: return None
        uri = j['images'][j['textures'][t['index']]['source']]['uri']
        if uri not in imgs: imgs[uri] = np.asarray(Image.open(os.path.join(d, uri)).convert('RGB')).astype(float) / 255
        return imgs[uri]
    prims = j['meshes'][0]['primitives']
    data = []
    for p in prims:
        A = p['attributes']; P = read_acc(j, binb, A['POSITION']); N = read_acc(j, binb, A['NORMAL'])
        J = read_acc(j, binb, A['JOINTS_0']); W = read_acc(j, binb, A['WEIGHTS_0']); I = read_acc(j, binb, p['indices']).reshape(-1, 3)
        T = tex_of(p.get('material'))
        if 'COLOR_0' in A:
            col = read_acc(j, binb, A['COLOR_0'])[:, :3].astype(float)
            col = np.where(col <= 0.0031308, col * 12.92, 1.055 * np.power(np.clip(col, 0, 1), 1 / 2.4) - 0.055)  # linear -> sRGB
            if T is not None:
                UV = read_acc(j, binb, A['TEXCOORD_0']); H, Wd = T.shape[:2]
                col = col * T[np.clip((UV[:, 1] % 1) * (H - 1), 0, H - 1).astype(int), np.clip((UV[:, 0] % 1) * (Wd - 1), 0, Wd - 1).astype(int)]
        elif T is not None:
            UV = read_acc(j, binb, A['TEXCOORD_0']); H, Wd = T.shape[:2]
            # 3x3 Mittel gegen Rauschen
            px = np.clip((UV[:, 0] % 1) * (Wd - 1), 1, Wd - 2).astype(int); py = np.clip((UV[:, 1] % 1) * (H - 1), 1, H - 2).astype(int)
            col = sum(T[py + a, px + b] for a in (-1, 0, 1) for b in (-1, 0, 1)) / 9
        else:
            col = np.full((len(P), 3), 0.6)
        dom = np.array([joints[J[i, np.argmax(W[i])]] for i in range(len(P))])
        data.append(dict(P=P, N=N, I=I, col=col, dom=dom))
    P = np.concatenate([q['P'] for q in data]); N = np.concatenate([q['N'] for q in data]); col = np.concatenate([q['col'] for q in data])
    dom = np.concatenate([q['dom'] for q in data])
    off = np.cumsum([0] + [len(q['P']) for q in data])
    I = np.concatenate([q['I'] + off[k] for k, q in enumerate(data)])
    h = P[:, 1]  # Rig: Höhe 0..1, Blick +Z
    headb = np.isin(dom, ['Head', 'Neck', 'HeadTop_End'])
    handb = np.isin(dom, ['LeftHand', 'RightHand'])
    hz = P[headb][:, 2]; cz = (hz.min() + hz.max()) / 2
    facefront = headb & (N[:, 2] > 0.35) & (P[:, 2] > cz) & (h > 0.86) & (h < 0.945)
    skin = np.median(col[(facefront) & (h > 0.88) & (h < 0.935)], 0)
    def sim(c, ref, tc, tl):
        cc = c / (c.sum(1, keepdims=True) + 1e-4); rc = ref / ref.sum()
        dc = np.linalg.norm(cc - rc, axis=1); lr = lum(c) / max(lum(ref), 1e-3)
        return np.clip(1 - (dc - tc) / tc, 0, 1) * np.clip(1 - np.abs(np.log(np.clip(lr, 1e-3, None))) / tl, 0, 1)
    loose = sim(col, skin, 0.03, 0.9); strict = sim(col, skin, 0.015, 0.6)
    S = strict.copy()
    medium = sim(col, skin, 0.022, 0.75)
    armzone = (np.abs(P[:, 0]) > 0.125) & (h > 0.35) & (h < 0.83) & ~headb
    S[armzone] = np.maximum(S[armzone], medium[armzone])
    S[handb] = np.maximum(loose[handb], 0.6)
    S[headb] = loose[headb]
    S[facefront] = 1.0
    # Gesicht: Augenweiß (hell, ungesättigt) und sehr dunkle Stellen (Pupillen/Brauen) behalten
    L = lum(col); sat = (col.max(1) - col.min(1)) / (col.max(1) + 1e-3)
    keep = facefront & (((L > lum(skin) * 1.45) & (sat < 0.25)) | (L < lum(skin) * 0.35))
    # Haare: Kopf, nicht Gesichtsfront, Farbe anders als Haut
    Hm = np.zeros(len(P)); hairreg = headb & ~facefront & (h > 0.86)
    Hm[hairreg] = 1 - loose[hairreg]
    # Haare, die über Schultern fallen (lange Haare): dunkel/ungleich Haut, oberhalb der Brust, hinten oder seitlich
    hair_ref = np.median(col[hairreg & (Hm > 0.7)], 0) if (hairreg & (Hm > 0.7)).sum() > 30 else None
    if hair_ref is not None:
        hs = sim(col, hair_ref, 0.03, 0.5); long = (h > 0.7) & ~headb & (N[:, 2] < 0.3) & (hs > 0.6) & (strict < 0.3)
        Hm[long] = np.maximum(Hm[long], hs[long] * 0.9)
    # Glätten über Nachbarn (Kanten der Dreiecke)
    nb = np.concatenate([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]]); nb = np.concatenate([nb, nb[:, ::-1]])
    deg = np.bincount(nb[:, 0], minlength=len(P)) + 1
    def smooth(v, it=6):
        for _ in range(it):
            v = (np.bincount(nb[:, 0], weights=v[nb[:, 1]], minlength=len(P)) + v) / deg
        return v
    S = smooth(S); Hm = smooth(Hm); K = smooth(keep.astype(float), 2)
    sm = lambda v, a, b: np.clip((v - a) / (b - a), 0, 1) ** 2 * (3 - 2 * np.clip((v - a) / (b - a), 0, 1))
    S = sm(S, 0.3, 0.65); Hm = sm(Hm, 0.35, 0.7) * (1 - S); K = sm(K, 0.3, 0.6)
    S = S * (1 - K)
    y = np.where(K > Hm, -K, Hm)
    UV2 = np.stack([S, y], 1).astype(np.float32)
    # in den Buffer anhängen
    binv = bytearray(binb)
    for k, p in enumerate(prims):
        part = np.ascontiguousarray(UV2[off[k]:off[k + 1]])
        while len(binv) % 4: binv.append(0)
        o = len(binv); binv.extend(part.tobytes())
        j['bufferViews'].append({'buffer': 0, 'byteOffset': o, 'byteLength': part.nbytes, 'target': 34962})
        j['accessors'].append({'bufferView': len(j['bufferViews']) - 1, 'componentType': 5126, 'count': len(part), 'type': 'VEC2'})
        p['attributes']['TEXCOORD_1'] = len(j['accessors']) - 1
    j['buffers'][0]['byteLength'] = len(binv)
    open(binp, 'wb').write(binv); json.dump(j, open(path, 'w'))
    vj = os.path.splitext(path)[0] + '.variants.json'
    json.dump({'skin': skin.tolist(), 'hair': hair_ref.tolist() if hair_ref is not None else None, 'masks': {}, 'vmask': True}, open(vj, 'w'))
    print('ok', path, 'Haut', np.round(skin, 2), 'Hautanteil', round(float((S > 0.5).mean()), 3), 'Haar', round(float((Hm > 0.5).mean()), 3), 'behalten', round(float((K > 0.5).mean()), 4))

if __name__ == '__main__':
    for p in sys.argv[1:]: run(p)
