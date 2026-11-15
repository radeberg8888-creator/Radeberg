#!/usr/bin/env python3
# Erzeugt kachelbare "gemalte" Detailtexturen (Graustufen, Mittelwert ~0.82) für den Comic-Stil.
# Sie werden im Shader mit der Materialfarbe multipliziert: Linien = Tusche, Flächen = Pinselstruktur.
# Alles selbst erzeugt (keine fremden Grafiken). Ausgabe: assets/stil/*.png
import os, numpy as np
from PIL import Image, ImageFilter
N = 512
rng = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "stil")
os.makedirs(OUT, exist_ok=True)

def rauschen(skala, okt=4, seed=0):
    # kachelbares Wertrauschen (Summe periodischer Sinus-/Gitter-Interpolation)
    r = np.random.default_rng(seed); out = np.zeros((N, N)); amp = 1.0; s = skala; tot = 0
    for o in range(okt):
        g = r.random((s, s))
        y = np.linspace(0, s, N, endpoint=False); x = y
        x0 = np.floor(x).astype(int); fx = x - x0; fx = fx * fx * (3 - 2 * fx)
        a = g[np.ix_(x0 % s, x0 % s)]; b = g[np.ix_(x0 % s, (x0 + 1) % s)]
        c = g[np.ix_((x0 + 1) % s, x0 % s)]; d = g[np.ix_((x0 + 1) % s, (x0 + 1) % s)]
        fy = fx[:, None]; fxx = fx[None, :]
        v = (a * (1 - fxx) + b * fxx) * (1 - fy) + (c * (1 - fxx) + d * fxx) * fy
        out += v * amp; tot += amp; amp *= 0.5; s *= 2
    return out / tot

def pinsel(img, staerke=0.08, seed=1):
    # Pinselstruktur: gerichtetes Rauschen, leicht verwischt
    r = rauschen(16, 4, seed); r2 = rauschen(64, 2, seed + 9)
    return img * (1 - staerke + staerke * 2 * (0.6 * r + 0.4 * r2))

def linie_h(img, y, dicke, wert, wobble=0.0, seed=0):
    r = np.random.default_rng(seed)
    xs = np.arange(N); off = (np.sin(xs / N * 2 * np.pi * r.integers(1, 4) + r.random() * 6) * wobble).astype(int)
    for i, x in enumerate(xs):
        for t in range(dicke):
            img[(y + off[i] + t) % N, x] = min(img[(y + off[i] + t) % N, x], wert)

def linie_v(img, x, y0, y1, dicke, wert):
    for y in range(y0, y1):
        for t in range(dicke):
            img[y % N, (x + t) % N] = min(img[y % N, (x + t) % N], wert)

def speichern(name, img, mittel=0.82):
    img = np.clip(img, 0, 1)
    img = img * (mittel / max(img.mean(), 1e-3))
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "L")
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(OUT, name + ".png")); print("ok", name, round(float(img.mean()), 3))

# Holzverschalung (Siding): 8 waagrechte Bretter, Schattenkante unter jedem Brett, Maserung
img = np.full((N, N), 0.9)
img = pinsel(img, 0.06, 2)
mas = rauschen(4, 3, 11)[:, :] ; img *= 0.94 + 0.08 * np.roll(mas, 0, 0)
for k in range(8):
    y = k * N // 8
    img[y:y + 10, :] *= 0.78          # Schatten der Überlappung
    linie_h(img, y, 3, 0.25, 0.0, k)  # Tuschekante
    for j in range(3):                # Stoßfugen
        x = int(rng.integers(0, N)); linie_v(img, x, y, y + N // 8, 2, 0.45)
speichern("holz", img)

# Dachschindeln: versetzte Reihen, jede Schindel leicht anders hell, Tuschekanten
img = np.zeros((N, N)); rows = 10; cols = 8
for r in range(rows):
    y0 = r * N // rows; off = (N // cols // 2) if r % 2 else 0
    for c in range(cols + 1):
        x0 = (c * N // cols + off) % N
        v = 0.78 + rng.random() * 0.2
        for y in range(y0, y0 + N // rows):
            for x in range(x0, x0 + N // cols):
                img[y % N, x % N] = v * (1 - 0.18 * ((y - y0) / (N / rows)))   # unten dunkler (Schatten)
        linie_v(img, x0, y0, y0 + N // rows, 3, 0.22)
    linie_h(img, y0, 3, 0.2, 0.0, r + 50)
img = pinsel(img, 0.08, 3)
speichern("schindel", img)

# Backstein: 16 Reihen, versetzt, Mörtelfugen hell, Steine gesprenkelt
img = np.zeros((N, N)); rows = 16; cols = 10
for r in range(rows):
    y0 = r * N // rows; off = (N // cols // 2) if r % 2 else 0
    for c in range(cols + 1):
        x0 = (c * N // cols + off) % N; v = 0.72 + rng.random() * 0.22
        img[y0:y0 + N // rows, :] = img[y0:y0 + N // rows, :]
        for x in range(x0, x0 + N // cols):
            img[y0:y0 + N // rows, x % N] = v
        linie_v(img, x0, y0, y0 + N // rows, 4, 1.15 if False else 0.95)
    img[y0:y0 + 4, :] = 0.98
    img[y0 + 4:y0 + 6, :] *= 0.6
img = pinsel(img, 0.12, 4)
speichern("backstein", img, 0.8)

# Asphalt: feines Korn, dunkle Flicken, Risse
img = 0.85 + 0.1 * (rauschen(64, 3, 5) - 0.5) + 0.06 * (rauschen(8, 3, 6) - 0.5)
for k in range(3):   # Flicken
    cx, cy = rng.integers(0, N, 2); rx, ry = rng.integers(30, 90, 2)
    yy, xx = np.ogrid[:N, :N]; dx = ((xx - cx + N // 2) % N - N // 2) / rx; dy = ((yy - cy + N // 2) % N - N // 2) / ry
    img[(np.abs(dx) < 1) & (np.abs(dy) < 0.6)] *= 0.9   # rechteckige Ausbesserung
for k in range(5):   # Risse (Zufallsweg)
    x, y = rng.integers(0, N, 2).astype(float); a = rng.random() * 6.28
    for s in range(int(rng.integers(60, 180))):
        a += rng.normal(0, 0.35); x += np.cos(a) * 2; y += np.sin(a) * 2
        img[int(y) % N, int(x) % N] = 0.3; img[int(y + 1) % N, int(x) % N] = 0.45
speichern("asphalt", img, 0.85)

# Gehwegplatten: 4x4 Platten, Fugen, einzelne Risse, Flecken
img = 0.88 + 0.07 * (rauschen(16, 3, 8) - 0.5)
for k in range(4):
    linie_h(img, k * N // 4, 4, 0.35, 0.0, k + 70)
    linie_v(img, k * N // 4, 0, N, 4, 0.35)
for k in range(4):
    x, y = rng.integers(0, N, 2).astype(float); a = rng.random() * 6.28
    for s in range(int(rng.integers(20, 60))):
        a += rng.normal(0, 0.4); x += np.cos(a) * 2; y += np.sin(a) * 2
        img[int(y) % N, int(x) % N] = 0.4
for k in range(3):
    cx, cy = rng.integers(0, N, 2); yy, xx = np.ogrid[:N, :N]
    d = (((xx - cx + N // 2) % N - N // 2) ** 2 + ((yy - cy + N // 2) % N - N // 2) ** 2)
    img[d < int(rng.integers(200, 900))] *= 0.92
speichern("platten", img, 0.86)

# Gras: viele kurze Halmstriche in hell/dunkel
img = 0.82 + 0.12 * (rauschen(8, 3, 12) - 0.5)
for k in range(5000):
    x, y = rng.integers(0, N, 2); l = int(rng.integers(4, 12)); v = 0.62 if rng.random() < 0.6 else 1.0
    sx = rng.normal(0, 0.3)
    for t in range(l):
        img[(y - t) % N, int(x + sx * t) % N] = v
speichern("gras", img, 0.82)

# Putz/Beton: weiche Flecken, feine Körnung
img = 0.85 + 0.12 * (rauschen(6, 4, 14) - 0.5) + 0.05 * (rauschen(128, 1, 15) - 0.5)
speichern("putz", img, 0.85)
