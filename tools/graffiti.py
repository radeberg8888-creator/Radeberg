"""Graffiti-Tags erzeugen (eigene Schriftzüge im Bubble-Stil mit Outline, Glanzlichtern, Läufern und Sprühnebel).
Ausgabe: assets/textures/graffiti/tag_XX.png (RGBA 512x256)"""
import random, math, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'textures', 'graffiti')
FONT = '/usr/share/fonts/truetype/google-fonts/Poppins-BoldItalic.ttf'
WORTE = ['LINDENHOF', 'KOBRAS', 'RDB', 'GROVE', 'ZOFF', 'KING', 'STAUB', 'OSTBLOCK', 'RATTEN', 'FUCHS', 'RADEBERG', 'WILD', 'NOIZE', 'BÄM', 'VIBE', 'K-TOWN']
FARB = [[(255, 70, 160), (120, 0, 90)], [(70, 220, 255), (0, 70, 140)], [(255, 220, 40), (200, 70, 0)], [(110, 255, 90), (0, 110, 50)],
        [(255, 90, 40), (140, 0, 0)], [(200, 120, 255), (60, 0, 140)], [(255, 255, 255), (120, 120, 140)], [(255, 150, 0), (120, 40, 0)]]
random.seed(4)
for i, w in enumerate(WORTE):
    W, H = 512, 256
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    size = 150 if len(w) <= 4 else (110 if len(w) <= 6 else 78)
    f = ImageFont.truetype(FONT, size)
    c1, c2 = FARB[i % len(FARB)]
    # Buchstaben einzeln, leicht verdreht und versetzt (Graffiti-Rhythmus)
    layer = Image.new('L', (W, H), 0); d = ImageDraw.Draw(layer)
    x = 30; y0 = H // 2 - size // 2 - 20
    pos = []
    for ch in w:
        bb = f.getbbox(ch); cw = bb[2] - bb[0]
        y = y0 + random.randint(-14, 14)
        pos.append((x, y, ch)); x += cw * 0.86
    scale = min(1.0, (W - 40) / max(x, 1))
    for (px, py, ch) in pos:
        d.text((20 + (px - 30) * scale + 10, py), ch, font=f, fill=255)
    if scale < 1.0:
        layer = layer.resize((int(W * scale), H)).crop((0, 0, W, H)) if False else layer
    fill = layer
    outline = fill.filter(ImageFilter.MaxFilter(15))
    outer = outline.filter(ImageFilter.MaxFilter(9))
    # 3D-Schatten
    shadow = Image.new('L', (W, H), 0); shadow.paste(outline, (9, 9))
    base = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    base.paste((255, 255, 255, 255), mask=outer)
    base.paste((15, 15, 18, 255), mask=shadow)
    base.paste((15, 15, 18, 255), mask=outline)
    # Farbverlauf
    grad = Image.new('RGBA', (W, H))
    gd = ImageDraw.Draw(grad)
    for yy in range(H):
        t = yy / H
        col = tuple(int(c1[k] * (1 - t) + c2[k] * t) for k in range(3)) + (255,)
        gd.line([(0, yy), (W, yy)], fill=col)
    base.paste(grad, mask=fill)
    # Glanzlichter
    hl = fill.filter(ImageFilter.MinFilter(9))
    hd = ImageDraw.Draw(base)
    for (px, py, ch) in pos[::2]:
        hd.ellipse([20 + (px - 30) * scale + 30, py + 40, 20 + (px - 30) * scale + 44, py + 52], fill=(255, 255, 255, 220))
    # Läufer (Drips)
    for k in range(9):
        xx = random.randint(40, W - 40)
        col_y = [yy for yy in range(H - 1, 0, -1) if fill.getpixel((xx, yy)) > 128]
        if not col_y: continue
        yb = col_y[0]; L = random.randint(15, 60)
        hd.line([(xx, yb), (xx, min(H - 4, yb + L))], fill=c2 + (255,), width=4)
        hd.ellipse([xx - 4, min(H - 8, yb + L) - 3, xx + 4, min(H - 8, yb + L) + 5], fill=c2 + (255,))
    # Sprühnebel an den Kanten
    rnd = Image.effect_noise((W, H), 90).point(lambda v: 255 if v > 200 else 0)
    mist = outer.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(4))
    spray = Image.new('RGBA', (W, H), c1 + (0,)); spray.putalpha(Image.composite(mist.point(lambda v: v // 3), Image.new('L', (W, H), 0), rnd))
    out = Image.alpha_composite(spray, base)
    out.save(os.path.join(OUT, 'tag_%02d.png' % i))
print('ok', len(WORTE))
