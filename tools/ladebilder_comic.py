#!/usr/bin/env python3
# Ladebildschirm-Artworks: Freisteller (Grün) -> Comic-Look (Posterisierung, schwarze Konturen, Raster)
# auf gemaltem Hintergrund (Verlaufshimmel, Sonne, Skyline/Palmen/Kräne als Silhouetten, Lichtstrahlen).
import sys, math, random
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

SRC = "/home/claude/work/lade/"
DST = sys.argv[1] if len(sys.argv) > 1 else "/home/claude/work/lade/fertig/"
W, H = 1920, 1080

def freistellen(pfad):
    im = np.array(Image.open(pfad).convert("RGB")).astype(np.float32) / 255
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    gruen = (g - np.maximum(r, b))
    a = np.clip(1.0 - (gruen - 0.15) / 0.35, 0, 1)
    # Grünstich entfernen
    im[..., 1] = np.minimum(g, np.maximum(r, b) * 1.02)
    ys, xs = np.where(a > 0.5)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    pad = 12
    y0, x0 = max(0, y0 - pad), max(0, x0 - pad)
    y1, x1 = min(im.shape[0], y1 + pad), min(im.shape[1], x1 + pad)
    return im[y0:y1, x0:x1], a[y0:y1, x0:x1]

def comic(rgb, a, sat=1.35):
    u8 = (rgb * 255).astype(np.uint8)
    u8 = cv2.bilateralFilter(u8, 9, 60, 9)
    hsv = cv2.cvtColor(u8, cv2.COLOR_RGB2HSV).astype(np.float32)
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 255)
    v = hsv[..., 2] / 255
    stufen = np.array([0.18, 0.42, 0.68, 0.9, 1.0])
    v2 = np.interp(v, [0, .25, .5, .75, 1.0], [0.12, 0.38, 0.66, 0.88, 1.0])
    v2 = np.round(v2 * 6) / 6
    hsv[..., 2] = np.clip(v2 * 255, 0, 255)
    out = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB).astype(np.float32) / 255
    # innere Linien
    gray = cv2.cvtColor(u8, cv2.COLOR_RGB2GRAY)
    kanten = cv2.Canny(cv2.GaussianBlur(gray, (3, 3), 0), 40, 110)
    kanten = cv2.dilate(kanten, np.ones((2, 2), np.uint8))
    out[kanten > 0] *= 0.08
    # Raster in den Schatten
    hh, ww = v.shape
    yy, xx = np.mgrid[0:hh, 0:ww]
    raster = ((np.sin(xx * 0.55) * np.sin(yy * 0.55)) > 0.35) & (v < 0.35)
    out[raster] *= 0.55
    # dicke Außenkontur
    m = (a > 0.5).astype(np.uint8)
    rand = cv2.dilate(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13))) - m
    rgba = np.dstack([out, a])
    rgba[rand > 0] = [0.03, 0.03, 0.05, 1.0]
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")

def verlauf(oben, unten, mitte=None):
    img = Image.new("RGB", (W, H))
    px = img.load()
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        if mitte:
            if t < 0.55: c = [oben[i] + (mitte[i] - oben[i]) * t / 0.55 for i in range(3)]
            else: c = [mitte[i] + (unten[i] - mitte[i]) * (t - 0.55) / 0.45 for i in range(3)]
        else: c = [oben[i] + (unten[i] - oben[i]) * t for i in range(3)]
        d.line([(0, y), (W, y)], fill=tuple(int(v) for v in c))
    return img

def strahlen(img, cx, cy, farbe, n=18, alpha=40):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    for i in range(n):
        a0 = i / n * 2 * math.pi; a1 = a0 + math.pi / n * 0.6
        d.polygon([(cx, cy), (cx + math.cos(a0) * 3000, cy + math.sin(a0) * 3000), (cx + math.cos(a1) * 3000, cy + math.sin(a1) * 3000)], fill=farbe + (alpha,))
    img.paste(lay, (0, 0), lay)

def sonne(img, cx, cy, r, farbe):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    for k in range(6, 0, -1):
        rr = r * (1 + k * 0.18); d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=farbe + (18,))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=farbe + (255,))
    # Streifen wie Retro-Sonne
    for k in range(5):
        y = cy + r * (0.25 + k * 0.16); d.rectangle([cx - r, y, cx + r, y + 6 + k * 3], fill=(0, 0, 0, 0))
    img.paste(lay, (0, 0), lay)

def skyline(img, y0, farbe, rnd, hoch=(80, 420), breit=(40, 140), fenster=None):
    d = ImageDraw.Draw(img); x = -20
    while x < W:
        w = rnd.randint(*breit); h = rnd.randint(*hoch)
        d.rectangle([x, y0 - h, x + w, H], fill=farbe)
        if rnd.random() < 0.3: d.rectangle([x + w * 0.4, y0 - h - rnd.randint(20, 70), x + w * 0.45, y0 - h], fill=farbe)
        if fenster:
            for fy in range(y0 - h + 14, y0 - 10, 22):
                for fx in range(x + 8, x + w - 10, 16):
                    if rnd.random() < 0.35: d.rectangle([fx, fy, fx + 6, fy + 9], fill=fenster)
        x += w + rnd.randint(-10, 6)

def palme(d, x, y, h, farbe, rnd):
    pts = []; bend = rnd.uniform(-0.25, 0.25)
    for i in range(12):
        t = i / 11; pts.append((x + math.sin(t * 1.4) * h * bend, y - t * h))
    for i in range(len(pts) - 1): d.line([pts[i], pts[i + 1]], fill=farbe, width=int(16 - i))
    tx, ty = pts[-1]
    for k in range(9):
        a = -math.pi * 0.95 + k * math.pi * 0.95 / 8 + rnd.uniform(-0.1, 0.1)
        L = h * rnd.uniform(0.35, 0.5)
        ex, ey = tx + math.cos(a) * L, ty + math.sin(a) * L * 0.55 + L * 0.35
        mx, my = (tx + ex) / 2, (ty + ey) / 2 - L * 0.18
        d.polygon([(tx, ty), (mx, my - 14), (ex, ey), (mx, my + 10)], fill=farbe)

def kran(d, x, y, farbe):
    d.rectangle([x, y - 420, x + 14, y], fill=farbe); d.rectangle([x + 120, y - 420, x + 134, y], fill=farbe)
    d.rectangle([x - 260, y - 440, x + 420, y - 418], fill=farbe)
    for k in range(10): d.line([(x - 250 + k * 66, y - 418), (x - 216 + k * 66, y - 440)], fill=farbe, width=4)
    d.line([(x + 67, y - 520), (x - 260, y - 440)], fill=farbe, width=4); d.line([(x + 67, y - 520), (x + 420, y - 440)], fill=farbe, width=4)
    d.rectangle([x + 60, y - 520, x + 74, y - 420], fill=farbe)

def raster_overlay(img, farbe, staerke=40, ab=0.55):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    for y in range(int(H * ab), H, 14):
        t = (y - H * ab) / (H * (1 - ab))
        r = 1.5 + t * 5
        for x in range((y // 14) % 2 * 7, W, 14): d.ellipse([x - r, y - r, x + r, y + r], fill=farbe + (staerke,))
    img.paste(lay, (0, 0), lay)

def tempo_linien(img, rnd, farbe):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    for i in range(40):
        y = rnd.randint(200, H - 100); x = rnd.randint(-200, W); L = rnd.randint(200, 700)
        d.line([(x, y), (x + L, y - L * 0.08)], fill=farbe + (rnd.randint(60, 140),), width=rnd.randint(2, 6))
    img.paste(lay, (0, 0), lay)

def vignette(img):
    v = Image.new("L", (W, H), 0); d = ImageDraw.Draw(v)
    for k in range(40):
        d.rectangle([k * 14, k * 9, W - k * 14, H - k * 9], outline=int(min(1.0, 0.35 + k / 12) * 255), width=14)
    d.rectangle([40 * 14, 40 * 9, W - 40 * 14, H - 40 * 9], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(80))
    schwarz = Image.new("RGB", (W, H), (10, 5, 20))
    return Image.composite(img, schwarz, v)

def setze(bg, subj, hoehe, x, y_unten):
    s = hoehe / subj.height; subj = subj.resize((int(subj.width * s), int(subj.height * s)), Image.LANCZOS)
    bg.paste(subj, (int(x - subj.width / 2), int(y_unten - subj.height)), subj)

def szene(name, rnd):
    rgb, a = freistellen(SRC + "roh_" + name + ".png")
    subj = comic(rgb, a)
    if name == "grove":
        bg = verlauf((60, 30, 110), (255, 150, 60), (240, 80, 90)); sonne(bg, 1350, 700, 260, (255, 210, 90)); strahlen(bg, 1350, 700, (255, 230, 150))
        skyline(bg, 900, (45, 20, 60), rnd, (60, 260), (60, 160), fenster=(255, 190, 80))
        d = ImageDraw.Draw(bg); [palme(d, x, 900, rnd.randint(380, 520), (30, 12, 40), rnd) for x in (220, 1700, 1850)]
        d.rectangle([0, 880, W, H], fill=(40, 18, 50)); raster_overlay(bg, (255, 120, 80), 35, 0.8)
        setze(bg, subj, 900, 930, 1060)
    elif name == "jagd":
        bg = verlauf((10, 10, 40), (40, 20, 90), (20, 30, 90)); strahlen(bg, 300, 300, (60, 90, 255), 14, 30)
        skyline(bg, 860, (8, 8, 25), rnd, (200, 640), (70, 180), fenster=(255, 230, 140))
        d = ImageDraw.Draw(bg); d.rectangle([0, 860, W, H], fill=(15, 12, 35))
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dl = ImageDraw.Draw(lay)
        dl.ellipse([1300, 250, 1900, 850], fill=(255, 30, 40, 70)); dl.ellipse([0, 300, 700, 1000], fill=(40, 80, 255, 80)); bg.paste(lay, (0, 0), lay)
        tempo_linien(bg, rnd, (255, 255, 255)); setze(bg, subj, 560, 1050, 1000)
    elif name == "lauf":
        bg = verlauf((255, 200, 70), (240, 80, 40), (255, 140, 50)); strahlen(bg, 960, 520, (255, 240, 180), 22, 55)
        tempo_linien(bg, rnd, (120, 20, 10)); raster_overlay(bg, (140, 30, 10), 60, 0.0)
        setze(bg, subj, 1020, 980, 1075)
    elif name == "strand":
        bg = verlauf((40, 150, 240), (255, 220, 160), (130, 210, 250)); sonne(bg, 500, 300, 150, (255, 250, 200))
        d = ImageDraw.Draw(bg); d.rectangle([0, 700, W, 790], fill=(30, 160, 210)); d.rectangle([0, 790, W, H], fill=(245, 215, 150))
        for k in range(8): d.line([(0, 712 + k * 10), (W, 712 + k * 10 + rnd.randint(-3, 3))], fill=(180, 235, 250), width=2)
        [palme(d, x, 820 + rnd.randint(0, 60), rnd.randint(480, 640), (20, 90, 80), rnd) for x in (120, 360, 1650, 1820)]
        raster_overlay(bg, (200, 140, 80), 40, 0.75); setze(bg, subj, 860, 1030, 1060)
    elif name == "boss":
        bg = verlauf((20, 5, 30), (120, 20, 80), (70, 10, 70)); strahlen(bg, 960, 1200, (255, 60, 200), 16, 40)
        skyline(bg, 1000, (15, 3, 20), rnd, (300, 800), (90, 220), fenster=(255, 80, 220))
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dl = ImageDraw.Draw(lay); dl.rectangle([0, 0, W, H], fill=(0, 0, 0, 70)); bg.paste(lay, (0, 0), lay)
        setze(bg, subj, 980, 960, 1070)
    elif name == "tuning":
        bg = verlauf((10, 30, 40), (0, 150, 150), (10, 70, 90)); strahlen(bg, 960, 1300, (0, 255, 220), 20, 45)
        d = ImageDraw.Draw(bg)
        for k in range(7): d.rectangle([k * 300 - 40, 60, k * 300 + 160, 90], fill=(220, 255, 250))   # Hallenlampen
        d.rectangle([0, 850, W, H], fill=(20, 40, 45)); raster_overlay(bg, (0, 255, 220), 30, 0.78)
        setze(bg, subj, 700, 960, 1030)
    else:
        bg = verlauf((60, 60, 120), (200, 120, 90)); setze(bg, subj, 900, 960, 1060)
    bg = vignette(bg)
    bg = ImageEnhance.Contrast(bg).enhance(1.08)
    return bg

if __name__ == "__main__":
    import os; os.makedirs(DST, exist_ok=True)
    rnd = random.Random(7)
    for n in ["grove", "jagd", "lauf", "strand", "boss", "tuning"]:
        szene(n, rnd).save(DST + "lade_" + n + ".jpg", quality=86); print("fertig", n)
