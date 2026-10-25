"""Erzeugt für jede Figurtextur eine Maske (R=Haut, G=Haare), damit Hautfarbe/Haarfarbe/Kleidung
im Spiel per Shader verändert werden können. Referenz-Hautfarbe = Gesicht (vorne, Kinn bis Augen).
Aufruf: skinmask.py <figur.gltf>   -> schreibt <bild>_mask.png neben die Texturen + <figur>.variants.json"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from autorig import read_acc, node_mat

def load(path):
    d = os.path.dirname(path); j = json.load(open(path))
    binb = open(os.path.join(d, j['buffers'][0]['uri']), 'rb').read()
    W = {}
    def walk(i, M):
        W[i] = M @ node_mat(j['nodes'][i])
        for c in j['nodes'][i].get('children', []): walk(c, W[i])
    for r in j['scenes'][j.get('scene', 0)]['nodes']: walk(r, np.eye(4))
    prims = []
    for ni, n in enumerate(j['nodes']):
        if 'mesh' not in n: continue
        M = W[ni] if 'skin' not in n else np.eye(4)
        for p in j['meshes'][n['mesh']]['primitives']:
            if p.get('material') is None or 'TEXCOORD_0' not in p['attributes']: continue
            mat = j['materials'][p['material']]; pb = mat.get('pbrMetallicRoughness', {})
            tex = pb.get('baseColorTexture') or (mat.get('extensions', {}).get('KHR_materials_pbrSpecularGlossiness', {}).get('diffuseTexture'))
            if not tex: continue
            img = j['images'][j['textures'][tex['index']]['source']]['uri']
            P = read_acc(j, binb, p['attributes']['POSITION']).astype(float); P = (M[:3, :3] @ P.T).T + M[:3, 3]
            N = read_acc(j, binb, p['attributes']['NORMAL']).astype(float) if 'NORMAL' in p['attributes'] else np.zeros_like(P)
            N = (M[:3, :3] @ N.T).T
            UV = read_acc(j, binb, p['attributes']['TEXCOORD_0']).astype(float)
            I = read_acc(j, binb, p['indices']).reshape(-1, 3) if 'indices' in p else np.arange(len(P)).reshape(-1, 3)
            prims.append(dict(P=P, N=N, UV=UV, I=I, img=os.path.join(d, img), mat=mat.get('name', '')))
    return j, prims

def run(path):
    j, prims = load(path)
    allP = np.concatenate([q['P'] for q in prims])
    # Hochachse bestimmen (größte Ausdehnung), normieren 0..1
    ext = allP.max(0) - allP.min(0); up = int(np.argmax(ext))
    h = (allP[:, up] - allP[:, up].min()) / ext[up]
    side = [a for a in range(3) if a != up]
    # Gesichtsrichtung: Nase = vorstehender Punkt im Kopfbereich
    k = 0; res = {}
    cols = []; hair_cols = []
    imgs = {}
    for q in prims:
        hv = (q['P'][:, up] - allP[:, up].min()) / ext[up]; q['h'] = hv
        if q['img'] not in imgs: imgs[q['img']] = np.asarray(Image.open(q['img']).convert('RGB')).astype(float) / 255
    # Rig-Dateien: Y oben, Blick nach +Z
    up = 1; head = allP[h > 0.9]; c = head.mean(0); fwd_axis, fwd_sign = 2, 1
    for q in prims:
        T = imgs[q['img']]; H, W = T.shape[:2]
        uv = q['UV']; px = np.clip((uv[:, 0] % 1) * (W - 1), 0, W - 1).astype(int); py = np.clip((uv[:, 1] % 1) * (H - 1), 0, H - 1).astype(int)
        col = T[py, px]
        hv = q['h']; rel = (q['P'][:, fwd_axis] - c[fwd_axis]) * fwd_sign
        nf = q['N'][:, fwd_axis] * fwd_sign
        face = (hv > 0.88) & (hv < 0.945) & (nf > 0.6) & (rel > 0)
        cols.append(col[face])
        top = (hv > 0.96)
        hair_cols.append(col[top])
    fc = np.concatenate(cols) if cols else np.zeros((0, 3))
    if len(fc) < 20: print('zu wenig Gesichtspunkte', path); return
    skin = np.median(fc, 0)
    hc = np.concatenate(hair_cols)
    # Haare: Kopfoberseite, deutlich anders als Haut
    dh = np.linalg.norm(hc - skin, axis=1)
    hair = np.median(hc[dh > 0.2], 0) if (dh > 0.2).sum() > 20 else None
    def chroma(x):
        s = x.sum(-1, keepdims=True) + 1e-4; return x / s, s[..., 0] / 3
    sk_c, sk_l = chroma(skin[None])
    out = {}
    for img, T in imgs.items():
        tc, tl = chroma(T)
        dc = np.linalg.norm(tc - sk_c[0], axis=-1)
        lr = tl / max(sk_l[0], 1e-3)
        lum_ok = np.clip(1 - np.abs(np.log(np.clip(lr, 1e-3, None))) / 0.9, 0, 1)
        loose = np.clip(1 - (dc - 0.025) / 0.03, 0, 1) * lum_ok
        strict = np.clip(1 - (dc - 0.013) / 0.014, 0, 1) * lum_ok
        # Regionen, in denen Haut wahrscheinlich ist: Kopf/Hals und Hände/Unterarme
        reg = Image.new('L', (T.shape[1], T.shape[0]), 0); dr = ImageDraw.Draw(reg)
        for q in prims:
            if q['img'] != img: continue
            uvp = np.stack([(q['UV'][:, 0] % 1) * T.shape[1], (q['UV'][:, 1] % 1) * T.shape[0]], 1)
            hv = q['h'][q['I']].mean(1); xv = np.abs(q['P'][:, 0] - c[0])[q['I']].mean(1) / ext[up]
            sel = (hv > 0.8) | (xv > 0.19) | ((hv > 0.36) & (hv < 0.52) & (xv > 0.11))
            for t in q['I'][sel][:150000]: dr.polygon([tuple(uvp[i]) for i in t], fill=255)
        R = np.asarray(reg.filter(__import__('PIL.ImageFilter', fromlist=['x']).MaxFilter(5))).astype(float) / 255
        m_skin = np.maximum(strict, loose * R)
        m_hair = np.zeros_like(m_skin)
        if hair is not None:
            # Haar nur im Kopfbereich (UV-Raster der Kopf-Dreiecke)
            reg = Image.new('L', (T.shape[1], T.shape[0]), 0); dr = ImageDraw.Draw(reg)
            for q in prims:
                if q['img'] != img: continue
                tri = q['I'][(q['h'][q['I']].min(1) > 0.84)]
                uvp = np.stack([(q['UV'][:, 0] % 1) * T.shape[1], (q['UV'][:, 1] % 1) * T.shape[0]], 1)
                for t in tri[:60000]: dr.polygon([tuple(uvp[i]) for i in t], fill=255)
            R = np.asarray(reg).astype(float) / 255
            dhh = np.linalg.norm(T - hair, axis=-1)
            m_hair = np.clip(1 - (dhh - 0.08) / 0.1, 0, 1) * R * (1 - m_skin)
        M = np.stack([m_skin, m_hair, np.zeros_like(m_skin)], -1)
        mp = os.path.splitext(img)[0] + '_mask.png'
        Image.fromarray((M * 255).astype(np.uint8)).resize((min(512, T.shape[1]), min(512, T.shape[0]))).save(mp)
        out[os.path.basename(img)] = os.path.basename(mp)
    info = {'skin': skin.tolist(), 'hair': hair.tolist() if hair is not None else None, 'masks': out}
    json.dump(info, open(os.path.splitext(path)[0] + '.variants.json', 'w'))
    print('ok', path, 'skin', np.round(skin, 2), 'hair', None if hair is None else np.round(hair, 2), len(out), 'Masken')



def by_material(path):
    """Für Figuren mit getrennten Materialien (Character Creator, Mixamo): Maske je Material."""
    d = os.path.dirname(path); j = json.load(open(path)); out = {}; skins = []
    for mat in j['materials']:
        nm = mat.get('name', '').lower(); pb = mat.get('pbrMetallicRoughness', {})
        tex = pb.get('baseColorTexture') or mat.get('extensions', {}).get('KHR_materials_pbrSpecularGlossiness', {}).get('diffuseTexture')
        if not tex: continue
        img = j['images'][j['textures'][tex['index']]['source']]['uri']
        sk = any(k in nm for k in ('skin', 'bodymat', 'body')) and not any(k in nm for k in ('eye', 'teeth', 'nail', 'lash', 'tongue'))
        hr = any(k in nm for k in ('hair', 'scalp', 'brow', 'beard', 'hawk'))
        if not (sk or hr): continue
        T = Image.open(os.path.join(d, img)).convert('RGB'); w, h = min(256, T.width), min(256, T.height)
        if sk: skins.append(np.median(np.asarray(T.resize((64, 64))).reshape(-1, 3), 0) / 255)
        M = Image.new('RGB', (w, h), (255, 0, 0) if sk else (0, 255, 0))
        mp = os.path.splitext(img)[0] + '_mask.png'; M.save(os.path.join(d, mp)); out[img] = mp
    skin = np.median(np.array(skins), 0) if skins else np.array([0.75, 0.55, 0.45])
    json.dump({'skin': skin.tolist(), 'hair': None, 'masks': out}, open(os.path.splitext(path)[0] + '.variants.json', 'w'))
    print('ok (Material)', path, np.round(skin, 2), list(out))

if __name__ == '__main__':
    for p in sys.argv[1:]:
        if p.startswith('mat:'): by_material(p[4:])
        else: run(p)
