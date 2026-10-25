"""Verkleinert Sketchfab-glTF fürs Handy: Texturen auf max. Kantenlänge, JPG wo kein Alpha nötig."""
import json, os, sys, shutil
from PIL import Image
Image.MAX_IMAGE_PIXELS = None
def run(src, dst, maxs=2048, name='scene'):
    os.makedirs(dst, exist_ok=True)
    j = json.load(open(os.path.join(src, 'scene.gltf')))
    for b in j['buffers']:
        shutil.copy(os.path.join(src, b['uri']), os.path.join(dst, name + '.bin')); b['uri'] = name + '.bin'
    for i, im in enumerate(j.get('images', [])):
        if 'uri' not in im: continue
        p = os.path.join(src, im['uri']); I = Image.open(p)
        if max(I.size) > maxs:
            s = maxs / max(I.size); I = I.resize((max(1, int(I.width * s)), max(1, int(I.height * s))), Image.LANCZOS)
        alpha = I.mode in ('RGBA', 'LA', 'P', 'PA') and I.convert('RGBA').getextrema()[3][0] < 250
        base = f'{name}_{i}'
        if alpha:
            fn = base + '.png'; I.convert('RGBA').save(os.path.join(dst, fn)); im['mimeType'] = 'image/png'
        else:
            fn = base + '.jpg'; I.convert('RGB').save(os.path.join(dst, fn), quality=90); im['mimeType'] = 'image/jpeg'
        im['uri'] = fn
    json.dump(j, open(os.path.join(dst, name + '.gltf'), 'w'))
    print('ok', dst, sum(os.path.getsize(os.path.join(dst, f)) for f in os.listdir(dst)) // 1000000, 'MB')
if __name__ == '__main__':
    run(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 2048, sys.argv[4] if len(sys.argv) > 4 else 'scene')
