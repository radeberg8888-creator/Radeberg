#!/usr/bin/env python3
# Ladebildschirm-Artworks im Stil gemalter Spiele-Poster:
# Freisteller (Grün) -> Comic-Look (Glättung, Farbstufen, Tusche-Konturen, Raster, Randlicht in Szenenfarbe)
# auf gemalten Hintergründen (Himmel, Silhouetten in Tiefenstaffelung, Licht, Effekte: Mündungsfeuer, Explosion,
# Blaulicht, Suchscheinwerfer, Tempolinien) + Farbangleichung, Vignette, Körnung.
import sys, math, random, json, os
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageChops

SRC = "/home/claude/work/lade/"
DST = sys.argv[1] if len(sys.argv) > 1 else "/home/claude/work/lade/fertig/"
W, H = 1920, 1080
META = json.load(open(SRC + "meta.json"))

# ---------- Freisteller ----------
def freistellen(pfad):
    im = np.array(Image.open(pfad).convert("RGB")).astype(np.float32) / 255
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    gr = g - np.maximum(r, b)
    a = np.clip(1.0 - (gr - 0.12) / 0.3, 0, 1)
    # Schatten auf Grün (dunkel, aber grünstichig) ebenfalls weg
    ratio = g / (np.maximum(r, b) + 0.02)
    a = np.minimum(a, np.clip(1.0 - (ratio - 1.18) / 0.25, 0, 1))
    im[..., 1] = np.minimum(g, np.maximum(r, b) * 1.03)
    ys, xs = np.where(a > 0.5)
    pad = 20
    y0, x0 = max(0, ys.min() - pad), max(0, xs.min() - pad)
    y1, x1 = min(im.shape[0], ys.max() + pad), min(im.shape[1], xs.max() + pad)
    return im[y0:y1, x0:x1], a[y0:y1, x0:x1], (x0, y0)

def comic(rgb, a, rand_farbe, sat=1.45):
    u8 = (rgb * 255).astype(np.uint8)
    u8 = cv2.bilateralFilter(u8, 9, 55, 9)
    u8 = cv2.edgePreservingFilter(u8, flags=1, sigma_s=30, sigma_r=0.3)
    hsv = cv2.cvtColor(u8, cv2.COLOR_RGB2HSV).astype(np.float32)
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 255)
    v = hsv[..., 2] / 255
    v2 = np.interp(v, [0, .2, .45, .7, 1.0], [0.1, 0.32, 0.62, 0.86, 1.0])
    v2 = np.round(v2 * 7) / 7
    hsv[..., 2] = np.clip(v2 * 255, 0, 255)
    out = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB).astype(np.float32) / 255
    gray = cv2.cvtColor(u8, cv2.COLOR_RGB2GRAY)
    kanten = cv2.Canny(cv2.GaussianBlur(gray, (3, 3), 0), 35, 100)
    kanten = cv2.dilate(kanten, np.ones((2, 2), np.uint8))
    out[kanten > 0] *= 0.06
    hh, ww = v.shape
    yy, xx = np.mgrid[0:hh, 0:ww]
    raster = ((np.sin(xx * 0.6 + yy * 0.6) * np.sin(xx * 0.6 - yy * 0.6)) > 0.3) & (v < 0.33)
    out[raster] *= 0.5
    # Randlicht in Szenenfarbe auf der einen Seite (Kante innen)
    m = (a > 0.5).astype(np.uint8)
    innen = m - cv2.erode(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
    verschoben = np.roll(innen, 4, axis=1)
    rf = np.array(rand_farbe, np.float32) / 255
    out[(verschoben > 0) & (m > 0)] = out[(verschoben > 0) & (m > 0)] * 0.3 + rf * 0.7
    rand = cv2.dilate(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))) - m
    rgba = np.dstack([out, a])
    rgba[rand > 0] = [0.02, 0.02, 0.04, 1.0]
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")

# ---------- Malwerkzeuge ----------
def verlauf(stops):
    img = Image.new("RGB", (W, H)); d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                u = (t - stops[i][0]) / max(stops[i + 1][0] - stops[i][0], 1e-6)
                c = [stops[i][1][k] + (stops[i + 1][1][k] - stops[i][1][k]) * u for k in range(3)]
                d.line([(0, y), (W, y)], fill=tuple(int(v) for v in c)); break
    return img
def lay(): return Image.new("RGBA", (W, H), (0, 0, 0, 0))
def auf(img, l, blur=0):
    if blur: l = l.filter(ImageFilter.GaussianBlur(blur))
    img.paste(l, (0, 0), l)
def glow(img, cx, cy, r, farbe, a=120):
    l = lay(); d = ImageDraw.Draw(l)
    for k in range(10, 0, -1):
        rr = r * k / 10; d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=farbe + (int(a * (1 - k / 11) ** 1.5),))
    auf(img, l, r * 0.08)
def strahlen(img, cx, cy, farbe, n=18, a=40, breite=0.6):
    l = lay(); d = ImageDraw.Draw(l)
    for i in range(n):
        a0 = i / n * 2 * math.pi; a1 = a0 + math.pi / n * breite
        d.polygon([(cx, cy), (cx + math.cos(a0) * 4000, cy + math.sin(a0) * 4000), (cx + math.cos(a1) * 4000, cy + math.sin(a1) * 4000)], fill=farbe + (a,))
    auf(img, l, 4)
def sonne(img, cx, cy, r, farbe, streifen=True):
    glow(img, cx, cy, r * 2.6, farbe, 90)
    l = lay(); d = ImageDraw.Draw(l)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=farbe + (255,))
    if streifen:
        for k in range(6):
            y = cy + r * (0.15 + k * 0.15); d.rectangle([cx - r, y, cx + r, y + 5 + k * 3], fill=(0, 0, 0, 0))
    auf(img, l)
def skyline(img, y0, farbe, rnd, hoch, breit, fenster=None, dichte=0.35, a=255):
    l = lay(); d = ImageDraw.Draw(l); x = -30
    while x < W + 30:
        w = rnd.randint(*breit); h = rnd.randint(*hoch)
        d.rectangle([x, y0 - h, x + w, H], fill=farbe + (a,))
        if rnd.random() < 0.35: d.rectangle([x + w * 0.42, y0 - h - rnd.randint(20, 90), x + w * 0.47, y0 - h], fill=farbe + (a,))
        if rnd.random() < 0.2: d.polygon([(x, y0 - h), (x + w / 2, y0 - h - w * 0.5), (x + w, y0 - h)], fill=farbe + (a,))
        if fenster:
            for fy in range(int(y0 - h + 14), int(y0 - 10), 20):
                for fx in range(x + 7, x + w - 9, 14):
                    if rnd.random() < dichte: d.rectangle([fx, fy, fx + 5, fy + 8], fill=fenster + (a,))
        x += w + rnd.randint(-12, 4)
    auf(img, l)
def dunst(img, y, farbe, h=160, a=150):
    l = lay(); d = ImageDraw.Draw(l)
    for k in range(h):
        d.line([(0, y + k - h // 2), (W, y + k - h // 2)], fill=farbe + (int(a * math.sin(math.pi * k / h)),))
    auf(img, l)
def palme(d, x, y, h, farbe, rnd):
    pts = []; bend = rnd.uniform(-0.3, 0.3)
    for i in range(14):
        t = i / 13; pts.append((x + math.sin(t * 1.5) * h * bend, y - t * h))
    for i in range(len(pts) - 1): d.line([pts[i], pts[i + 1]], fill=farbe, width=max(3, int(18 - i)))
    tx, ty = pts[-1]
    for k in range(10):
        a = -math.pi * 1.0 + k * math.pi / 9 + rnd.uniform(-0.1, 0.1)
        L = h * rnd.uniform(0.35, 0.52)
        pts2 = []
        for s in range(9):
            t = s / 8; pts2.append((tx + math.cos(a) * L * t, ty + math.sin(a) * L * t * 0.5 + (L * 0.45) * t * t))
        for s in range(8):
            wv = 14 * (1 - s / 8) + 2
            d.line([pts2[s], pts2[s + 1]], fill=farbe, width=int(wv))
def kaktus(d, x, y, h, farbe):
    w = h * 0.13
    d.rounded_rectangle([x - w / 2, y - h, x + w / 2, y], radius=w / 2, fill=farbe)
    for sx, hh in [(-1, 0.55), (1, 0.4)]:
        ax = x + sx * w * 1.6
        d.rounded_rectangle([min(x, ax) - w * 0.3, y - h * hh - w * 0.4, max(x, ax) + w * 0.3, y - h * hh + w * 0.4], radius=w * 0.4, fill=farbe)
        d.rounded_rectangle([ax - w * 0.4, y - h * hh - h * 0.35, ax + w * 0.4, y - h * hh + w * 0.3], radius=w * 0.4, fill=farbe)
def kran(d, x, y, s, farbe):
    d.rectangle([x, y - 420 * s, x + 16 * s, y], fill=farbe); d.rectangle([x + 130 * s, y - 420 * s, x + 146 * s, y], fill=farbe)
    d.rectangle([x - 280 * s, y - 446 * s, x + 450 * s, y - 420 * s], fill=farbe)
    for k in range(11): d.line([(x - 270 * s + k * 66 * s, y - 420 * s), (x - 236 * s + k * 66 * s, y - 446 * s)], fill=farbe, width=max(2, int(4 * s)))
    d.line([(x + 73 * s, y - 540 * s), (x - 280 * s, y - 446 * s)], fill=farbe, width=max(2, int(4 * s)))
    d.line([(x + 73 * s, y - 540 * s), (x + 450 * s, y - 446 * s)], fill=farbe, width=max(2, int(4 * s)))
    d.rectangle([x + 65 * s, y - 540 * s, x + 81 * s, y - 420 * s], fill=farbe)
def container_reihe(d, y, rnd, farben):
    x = -40
    while x < W:
        w = rnd.randint(160, 260); st = rnd.randint(1, 4)
        for k in range(st):
            c = farben[rnd.randrange(len(farben))]
            d.rectangle([x, y - (k + 1) * 70, x + w, y - k * 70 - 3], fill=c)
            for rx in range(x + 8, x + w - 6, 12): d.line([(rx, y - (k + 1) * 70 + 6), (rx, y - k * 70 - 8)], fill=tuple(max(0, v - 25) for v in c), width=3)
        x += w + rnd.randint(4, 30)
def heli(img, cx, cy, s, farbe, licht=None):
    l = lay(); d = ImageDraw.Draw(l)
    if licht:
        d.polygon([(cx, cy + 20 * s), (cx - 380 * s, H + 50), (cx + 120 * s, H + 50)], fill=licht + (55,))
    d.ellipse([cx - 70 * s, cy - 30 * s, cx + 60 * s, cy + 30 * s], fill=farbe + (255,))
    d.polygon([(cx + 40 * s, cy - 10 * s), (cx + 200 * s, cy - 18 * s), (cx + 200 * s, cy - 4 * s), (cx + 40 * s, cy + 10 * s)], fill=farbe + (255,))
    d.rectangle([cx + 190 * s, cy - 40 * s, cx + 205 * s, cy - 4 * s], fill=farbe + (255,))
    d.line([(cx - 200 * s, cy - 42 * s), (cx + 180 * s, cy - 48 * s)], fill=farbe + (255,), width=int(6 * s))
    d.rectangle([cx - 4 * s, cy - 48 * s, cx + 4 * s, cy - 28 * s], fill=farbe + (255,))
    d.line([(cx - 50 * s, cy + 42 * s), (cx + 50 * s, cy + 42 * s)], fill=farbe + (255,), width=int(5 * s))
    auf(img, l, 1)
def explosion(img, cx, cy, r, rnd):
    glow(img, cx, cy, r * 2.2, (255, 140, 30), 150)
    l = lay(); d = ImageDraw.Draw(l)
    for k in range(40):
        a = rnd.uniform(0, 2 * math.pi); rr = r * rnd.uniform(0.3, 1.0)
        x = cx + math.cos(a) * rr; y = cy + math.sin(a) * rr * 0.75; s = r * rnd.uniform(0.2, 0.45)
        c = rnd.choice([(255, 230, 120), (255, 170, 40), (240, 90, 20), (200, 50, 10)])
        d.ellipse([x - s, y - s, x + s, y + s], fill=c + (230,))
    for k in range(22):
        a = rnd.uniform(-math.pi, 0); rr = r * rnd.uniform(0.9, 1.6)
        x = cx + math.cos(a) * rr; y = cy + math.sin(a) * rr * 0.9 - r * 0.3; s = r * rnd.uniform(0.25, 0.5)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(40, 30, 35, 200))
    d.ellipse([cx - r * 0.35, cy - r * 0.3, cx + r * 0.35, cy + r * 0.3], fill=(255, 250, 220, 255))
    auf(img, l, 2)
    l2 = lay(); d2 = ImageDraw.Draw(l2)
    for k in range(30):
        a = rnd.uniform(0, 2 * math.pi); r1 = r * 0.6; r2 = r * rnd.uniform(1.6, 2.8)
        d2.line([(cx + math.cos(a) * r1, cy + math.sin(a) * r1), (cx + math.cos(a) * r2, cy + math.sin(a) * r2)], fill=(30, 25, 25, 255), width=rnd.randint(3, 8))
    auf(img, l2)
def tempo(img, rnd, farbe, n=50, y0=150, y1=H - 80, schraeg=-0.06, a=(70, 160)):
    l = lay(); d = ImageDraw.Draw(l)
    for i in range(n):
        y = rnd.randint(y0, y1); x = rnd.randint(-300, W); L = rnd.randint(250, 900)
        d.line([(x, y), (x + L, y + L * schraeg)], fill=farbe + (rnd.randint(*a),), width=rnd.randint(2, 7))
    auf(img, l)
def raster(img, farbe, a=40, ab=0.55, schritt=14):
    l = lay(); d = ImageDraw.Draw(l)
    for y in range(int(H * ab), H, schritt):
        t = (y - H * ab) / max(H * (1 - ab), 1); r = 1.2 + t * 5.5
        for x in range((y // schritt) % 2 * (schritt // 2), W, schritt): d.ellipse([x - r, y - r, x + r, y + r], fill=farbe + (a,))
    auf(img, l)
def boden(img, y, farbe, linie=None):
    l = lay(); d = ImageDraw.Draw(l); d.rectangle([0, y, W, H], fill=farbe + (255,))
    if linie:
        for k in range(12):
            yy = y + (k * k) * 3.2; d.line([(0, yy), (W, yy)], fill=linie + (90,), width=2)
        for k in range(-20, 21):
            d.line([(W / 2 + k * 30, y), (W / 2 + k * 260, H)], fill=linie + (60,), width=2)
    auf(img, l)
def muendung(img, punkte, rnd):
    for (x, y) in punkte:
        glow(img, x, y, 120, (255, 200, 80), 200)
        l = lay(); d = ImageDraw.Draw(l)
        for k in range(7):
            a = rnd.uniform(0, 2 * math.pi); L = rnd.uniform(40, 110)
            d.polygon([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L), (x + math.cos(a + 0.25) * L * 0.4, y + math.sin(a + 0.25) * L * 0.4)], fill=(255, 245, 190, 255))
        d.ellipse([x - 16, y - 16, x + 16, y + 16], fill=(255, 255, 230, 255))
        auf(img, l, 1)
def vignette(img, staerke=1.0):
    v = Image.new("L", (W, H), 0); d = ImageDraw.Draw(v)
    for k in range(40):
        d.rectangle([k * 14, k * 9, W - k * 14, H - k * 9], outline=int(min(1.0, 0.25 + k / 14) * 255), width=14)
    d.rectangle([40 * 14, 40 * 9, W - 40 * 14, H - 40 * 9], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(90))
    return Image.composite(img, Image.new("RGB", (W, H), (8, 4, 16)), v)
def koernung(img, s=10):
    n = np.random.default_rng(3).normal(0, s, (H, W, 1))
    a = np.clip(np.array(img).astype(np.float32) + n, 0, 255).astype(np.uint8)
    return Image.fromarray(a)
def farbstich(img, farbe, a=0.12):
    return Image.blend(img, ImageChops.multiply(img, Image.new("RGB", (W, H), farbe)), a)

# ---------- Szene setzen ----------
def setze(bg, name, hoehe, x, y_unten, rand_farbe, schatten=True, kippen=0):
    rgb, a, (ox, oy) = freistellen(SRC + "roh_" + name + ".png")
    subj = comic(rgb, a, rand_farbe)
    s = hoehe / subj.height
    if subj.width * s > W * 0.95: s = W * 0.95 / subj.width
    subj = subj.resize((int(subj.width * s), int(subj.height * s)), Image.LANCZOS)
    px = int(x - subj.width / 2); py = int(y_unten - subj.height)
    if schatten:
        l = lay(); d = ImageDraw.Draw(l)
        d.ellipse([px + subj.width * 0.05, y_unten - 40, px + subj.width * 0.95, y_unten + 30], fill=(0, 0, 0, 150))
        auf(bg, l, 20)
    if kippen: subj = subj.rotate(kippen, resample=Image.BICUBIC, expand=False)
    bg.paste(subj, (px, py), subj)
    # Mündungspunkte umrechnen
    return [((mx - ox) * s + px, (my - oy) * s + py) for mx, my in META.get(name, {}).get("muendung", [])]

def szene(name, rnd):
    if name == "gang":
        bg = verlauf([(0, (40, 20, 90)), (0.45, (230, 70, 110)), (0.75, (255, 160, 70)), (1, (60, 20, 40))])
        sonne(bg, 1300, 640, 230, (255, 220, 110)); strahlen(bg, 1300, 640, (255, 230, 160), 20, 30)
        skyline(bg, 860, (110, 40, 90), rnd, (60, 200), (70, 150), a=170); dunst(bg, 840, (255, 140, 120), 120, 90)
        l = lay(); d = ImageDraw.Draw(l)
        for x in (180, 1650, 1790): palme(d, x, 880, rnd.randint(420, 560), (35, 12, 40, 255), rnd)
        d.line([(0, 470), (W, 520)], fill=(30, 10, 30, 255), width=3); d.line([(0, 500), (W, 545)], fill=(30, 10, 30, 255), width=3)
        for x in (120, 1000, 1880): d.rectangle([x, 440, x + 12, 880], fill=(30, 10, 30, 255))
        auf(bg, l); boden(bg, 870, (45, 15, 45), (255, 120, 140)); raster(bg, (255, 120, 90), 35, 0.82)
        mz = setze(bg, name, 880, 960, 1060, (255, 120, 200)); muendung(bg, mz, rnd)
    elif name == "jagd":
        bg = verlauf([(0, (5, 5, 25)), (0.6, (25, 20, 70)), (1, (10, 8, 30))])
        skyline(bg, 760, (20, 18, 50), rnd, (250, 600), (80, 190), (255, 220, 140), 0.25)
        skyline(bg, 800, (10, 8, 25), rnd, (150, 420), (60, 150), (255, 240, 180), 0.2)
        glow(bg, 1500, 520, 520, (255, 30, 40), 120); glow(bg, 380, 560, 560, (40, 80, 255), 130)
        heli(bg, 1350, 220, 1.1, (12, 10, 20), (220, 230, 255))
        boden(bg, 780, (15, 12, 30), (80, 90, 160)); tempo(bg, rnd, (255, 255, 255), 70, 300, 1050, 0.02)
        setze(bg, name, 800, 980, 1050, (120, 160, 255))
    elif name == "lauf":
        bg = verlauf([(0, (255, 200, 80)), (0.5, (250, 110, 40)), (1, (120, 30, 20))])
        skyline(bg, 900, (70, 25, 15), rnd, (200, 500), (80, 180), a=230)
        explosion(bg, 760, 520, 260, rnd); strahlen(bg, 760, 520, (255, 240, 180), 26, 45)
        tempo(bg, rnd, (90, 20, 10), 50); raster(bg, (120, 20, 0), 55, 0.0, 16)
        setze(bg, name, 1000, 1080, 1075, (255, 200, 80), False)
    elif name == "strand":
        bg = verlauf([(0, (30, 130, 230)), (0.55, (150, 220, 250)), (0.62, (255, 225, 170)), (1, (240, 200, 140))])
        sonne(bg, 420, 290, 140, (255, 250, 210), False)
        l = lay(); d = ImageDraw.Draw(l); d.rectangle([0, 660, W, 760], fill=(20, 150, 210, 255))
        for k in range(10): d.line([(0, 672 + k * 9), (W, 672 + k * 9 + rnd.randint(-3, 3))], fill=(190, 240, 255, 180), width=2)
        d.rectangle([0, 760, W, H], fill=(245, 215, 155, 255))
        for x in (90, 330, 1620, 1820): palme(d, x, 800 + rnd.randint(0, 60), rnd.randint(500, 680), (15, 90, 80, 255), rnd)
        auf(bg, l); skyline(bg, 670, (230, 160, 190), rnd, (60, 200), (60, 140), (255, 255, 255), 0.25, 160)
        raster(bg, (200, 140, 80), 40, 0.78)
        setze(bg, name, 860, 1020, 1060, (80, 230, 255))
    elif name == "boss":
        bg = verlauf([(0, (15, 3, 25)), (0.6, (110, 20, 90)), (1, (20, 5, 25))])
        strahlen(bg, 960, 1250, (255, 60, 200), 18, 35)
        skyline(bg, 1000, (40, 8, 45), rnd, (450, 900), (100, 220), (255, 90, 220), 0.25)
        skyline(bg, 1020, (15, 3, 20), rnd, (250, 600), (90, 200), (255, 200, 120), 0.2)
        glow(bg, 960, 380, 500, (255, 80, 210), 90)
        mz = setze(bg, name, 950, 960, 1070, (255, 80, 220)); muendung(bg, mz[:1], rnd)
    elif name == "tuning":
        bg = verlauf([(0, (5, 20, 30)), (0.65, (0, 110, 120)), (1, (5, 25, 30))])
        strahlen(bg, 960, 1300, (0, 255, 220), 22, 40)
        l = lay(); d = ImageDraw.Draw(l)
        for k in range(7): d.rectangle([k * 300 - 40, 70, k * 300 + 170, 96], fill=(220, 255, 250, 255))
        auf(bg, l); glow(bg, 960, 980, 700, (0, 255, 230), 120)
        boden(bg, 860, (10, 30, 35), (0, 200, 200)); raster(bg, (0, 255, 220), 30, 0.8)
        setze(bg, name, 720, 960, 1010, (0, 255, 220))
    elif name == "deal":
        bg = verlauf([(0, (10, 15, 40)), (0.55, (40, 60, 110)), (1, (10, 12, 25))])
        sonne(bg, 1500, 230, 90, (240, 240, 220), False)
        l = lay(); d = ImageDraw.Draw(l); kran(d, 250, 860, 1.0, (15, 18, 35, 255)); kran(d, 1450, 860, 0.8, (20, 25, 45, 255)); auf(bg, l)
        dunst(bg, 780, (90, 110, 160), 220, 110)
        l = lay(); d = ImageDraw.Draw(l); container_reihe(d, 880, rnd, [(120, 40, 35, 255), (30, 70, 120, 255), (40, 100, 60, 255), (150, 110, 30, 255)]); auf(bg, l)
        glow(bg, 960, 760, 380, (255, 160, 60), 110); boden(bg, 870, (18, 20, 35))
        mz = setze(bg, name, 760, 960, 1040, (255, 170, 80)); muendung(bg, [], rnd)
    elif name == "schiesserei":
        bg = verlauf([(0, (60, 20, 15)), (0.5, (220, 90, 40)), (1, (40, 15, 10))])
        skyline(bg, 880, (80, 25, 15), rnd, (150, 450), (80, 180), (255, 200, 90), 0.3)
        l = lay(); d = ImageDraw.Draw(l)
        for k in range(14):
            y = rnd.randint(250, 750); x = rnd.randint(1000, 1900); d.line([(x, y), (x - rnd.randint(300, 700), y + rnd.randint(-60, 60))], fill=(255, 230, 140, 220), width=3)
        auf(bg, l, 1); raster(bg, (40, 10, 0), 55, 0.6); tempo(bg, rnd, (255, 200, 120), 30, 200, 900, 0.0, (40, 90))
        mz = setze(bg, name, 980, 900, 1075, (255, 180, 80)); muendung(bg, mz, rnd)
    elif name == "wueste":
        bg = verlauf([(0, (50, 30, 90)), (0.45, (240, 110, 60)), (0.7, (255, 190, 100)), (1, (150, 80, 40))])
        sonne(bg, 1350, 620, 200, (255, 230, 130)); strahlen(bg, 1350, 620, (255, 230, 170), 18, 25)
        l = lay(); d = ImageDraw.Draw(l)
        d.polygon([(0, 760), (180, 560), (420, 560), (520, 700), (760, 640), (900, 760)], fill=(120, 50, 50, 255))
        d.polygon([(1100, 760), (1300, 600), (1560, 620), (1700, 520), (1920, 540), (1920, 760)], fill=(110, 45, 50, 255))
        d.rectangle([0, 760, W, H], fill=(190, 110, 60, 255))
        for x, h in [(140, 330), (1700, 400), (1850, 260), (430, 220)]: kaktus(d, x, 900, h, (40, 25, 30, 255))
        d.rectangle([1150, 790, 1500, 880], fill=(60, 40, 40, 255)); d.ellipse([1130, 790, 1180, 880], fill=(60, 40, 40, 255)); d.ellipse([1470, 790, 1520, 880], fill=(60, 40, 40, 255))
        auf(bg, l); raster(bg, (120, 50, 20), 45, 0.75)
        mz = setze(bg, name, 860, 800, 1060, (255, 160, 80)); muendung(bg, mz, rnd)
    elif name == "flucht":
        bg = verlauf([(0, (5, 8, 20)), (0.6, (20, 30, 60)), (1, (8, 8, 15))])
        l = lay(); d = ImageDraw.Draw(l)
        for cx, ang in [(300, 0.35), (1650, -0.3)]:
            d.polygon([(cx, 280), (cx + math.sin(ang - 0.12) * 1600, 280 + math.cos(ang - 0.12) * 1600), (cx + math.sin(ang + 0.12) * 1600, 280 + math.cos(ang + 0.12) * 1600)], fill=(230, 240, 255, 50))
        auf(bg, l, 6)
        l = lay(); d = ImageDraw.Draw(l)
        d.rectangle([0, 640, W, 900], fill=(25, 28, 40, 255))
        for x in range(0, W, 30): d.line([(x, 600), (x, 640)], fill=(40, 45, 60, 255), width=3)
        d.line([(0, 610), (W, 610)], fill=(50, 55, 70, 255), width=3)
        for cx in (300, 1650):
            d.rectangle([cx - 14, 280, cx + 14, 640], fill=(20, 22, 32, 255)); d.rectangle([cx - 70, 230, cx + 70, 300], fill=(20, 22, 32, 255))
            d.polygon([(cx - 90, 230), (cx, 180), (cx + 90, 230)], fill=(20, 22, 32, 255))
        auf(bg, l); glow(bg, 300, 270, 90, (240, 245, 255), 220); glow(bg, 1650, 270, 90, (240, 245, 255), 220)
        glow(bg, 700, 860, 420, (255, 30, 40), 110); glow(bg, 1200, 860, 420, (40, 80, 255), 110)
        boden(bg, 900, (10, 10, 20))
        setze(bg, name, 800, 1000, 1060, (255, 60, 80))
    elif name == "party":
        bg = verlauf([(0, (20, 0, 40)), (0.6, (80, 10, 110)), (1, (10, 0, 20))])
        l = lay(); d = ImageDraw.Draw(l)
        for k in range(16):
            c = rnd.choice([(255, 40, 200), (40, 220, 255), (120, 255, 80), (255, 230, 60)])
            x = rnd.randint(0, W); d.line([(960, 60), (x, H)], fill=c + (120,), width=4)
        auf(bg, l, 2)
        glow(bg, 960, 60, 300, (255, 255, 255), 160)
        l = lay(); d = ImageDraw.Draw(l)
        for k in range(40):
            x = rnd.randint(-40, W); h = rnd.randint(120, 220)
            d.ellipse([x - 22, 1080 - h - 40, x + 22, 1080 - h + 4], fill=(10, 0, 18, 255)); d.rounded_rectangle([x - 40, 1080 - h, x + 40, 1100], radius=20, fill=(10, 0, 18, 255))
        auf(bg, l)
        setze(bg, name, 820, 960, 960, (40, 230, 255))
    elif name == "rennen":
        bg = verlauf([(0, (30, 15, 70)), (0.45, (240, 80, 120)), (0.62, (255, 170, 90)), (1, (25, 10, 30))])
        sonne(bg, 960, 600, 260, (255, 210, 120))
        skyline(bg, 640, (90, 30, 90), rnd, (80, 300), (60, 160), (255, 220, 160), 0.25, 220)
        l = lay(); d = ImageDraw.Draw(l); d.polygon([(0, 640), (W, 640), (W, H), (0, H)], fill=(30, 15, 40, 255))
        for k in range(16): d.polygon([(960 - 12 + k * 0, 650), (960 + 12, 650), (960 + 40 + k * 60, H), (960 - 40 - k * 0, H)], fill=(0, 0, 0, 0))
        auf(bg, l); boden(bg, 640, (30, 15, 40), (255, 120, 200))
        l = lay(); d = ImageDraw.Draw(l)
        for k in range(26):
            y = rnd.randint(660, 1050); x = rnd.randint(-200, W); L = rnd.randint(300, 900)
            d.line([(x, y), (x + L, y - 12)], fill=rnd.choice([(255, 40, 60, 180), (255, 220, 120, 160)]), width=rnd.randint(3, 7))
        auf(bg, l, 1)
        setze(bg, name, 640, 960, 1050, (255, 120, 200))
    bg = vignette(bg)
    bg = ImageEnhance.Contrast(bg).enhance(1.1)
    bg = ImageEnhance.Color(bg).enhance(1.1)
    return koernung(bg, 7)

if __name__ == "__main__":
    os.makedirs(DST, exist_ok=True)
    nur = sys.argv[2] if len(sys.argv) > 2 else None
    for n in ["gang", "jagd", "lauf", "strand", "boss", "tuning", "deal", "schiesserei", "wueste", "flucht", "party", "rennen"]:
        if nur and n != nur: continue
        szene(n, random.Random(hash(n) % 1000)).save(DST + "lade_" + n + ".jpg", quality=86); print("fertig", n)
