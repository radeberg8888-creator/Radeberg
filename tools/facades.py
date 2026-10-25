"""Erzeugt kachelbare Fassadentexturen: je Bild 4 Fensterachsen x 4 Geschosse (Altbau, Plattenbau, Büro, Glasturm, Backstein-Halle)
und ein Erdgeschoss-Band mit Läden. Ausgabe nach assets/textures/facades/."""
import os, numpy as np
from PIL import Image, ImageDraw, ImageFilter
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'textures', 'facades'); os.makedirs(OUT, exist_ok=True)
S = 1024; rng = np.random.default_rng(5)

def noise(s, amp, blur=1.5, seed=0):
    r = np.random.default_rng(seed); n = r.normal(0, 1, (s // 4, s // 4))
    im = Image.fromarray(((n - n.min()) / (n.max() - n.min()) * 255).astype(np.uint8)).resize((s, s), Image.BICUBIC).filter(ImageFilter.GaussianBlur(blur))
    fine = r.normal(0, 1, (s, s))
    return (np.asarray(im) / 255.0 - 0.5) * amp + fine * amp * 0.25

def wall(col, amp=18, seed=0):
    a = np.zeros((S, S, 3)) + np.array(col, float)
    a += noise(S, amp, 3, seed)[..., None]
    return a

def window(d, x0, y0, x1, y1, frame=(235, 232, 225), glass_top=(120, 150, 175), glass_bot=(40, 55, 70), cross=True, curtain=None):
    d.rectangle([x0, y0, x1, y1], fill=frame)
    fx = max(3, (x1 - x0) // 14)
    gx0, gy0, gx1, gy1 = x0 + fx, y0 + fx, x1 - fx, y1 - fx
    h = gy1 - gy0
    for k in range(h):
        t = k / max(h - 1, 1); c = tuple(int(glass_top[i] * (1 - t) + glass_bot[i] * t) for i in range(3))
        d.line([gx0, gy0 + k, gx1, gy0 + k], fill=c)
    # Spiegelung (Himmel) schräg
    d.polygon([(gx0, gy0), (gx0 + (gx1 - gx0) * 0.35, gy0), (gx0, gy0 + h * 0.5)], fill=tuple(min(255, int(c * 1.25)) for c in glass_top))
    if curtain is not None:
        cw = int((gx1 - gx0) * curtain[1]); d.rectangle([gx0, gy0, gx0 + cw, gy1], fill=curtain[0])
    if cross:
        mx = (x0 + x1) // 2; d.rectangle([mx - fx // 2, gy0, mx + fx // 2, gy1], fill=frame)
        ty = gy0 + int(h * 0.3); d.rectangle([gx0, ty - fx // 2, gx1, ty + fx // 2], fill=frame)

def save(a, name):
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name), quality=92)

# --- Altbau (Gründerzeit): Putz, Gesimse, Fenster mit Faschen und Verdachung
def altbau(col, name, seed):
    a = wall(col, 14, seed); im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    fh = S // 4; bw = S // 4; light = tuple(min(255, c + 28) for c in col); dark = tuple(max(0, c - 40) for c in col)
    for f in range(4):
        y0 = f * fh
        d.rectangle([0, y0 + fh - 10, S, y0 + fh], fill=light)            # Gurtgesims
        d.rectangle([0, y0 + fh - 3, S, y0 + fh], fill=dark)
        for b in range(4):
            cx = b * bw + bw // 2; w = int(bw * 0.42); x0, x1 = cx - w // 2, cx + w // 2; wy0, wy1 = y0 + int(fh * 0.22), y0 + int(fh * 0.8)
            d.rectangle([x0 - 10, wy0 - 10, x1 + 10, wy1 + 6], fill=light)  # Fasche
            d.rectangle([x0 - 16, wy0 - 26, x1 + 16, wy0 - 12], fill=light); d.rectangle([x0 - 16, wy0 - 14, x1 + 16, wy0 - 12], fill=dark)  # Verdachung
            cur = ((235, 230, 215), rng.uniform(0.15, 0.45)) if rng.random() < 0.5 else None
            window(d, x0, wy0, x1, wy1, curtain=cur)
            d.rectangle([x0 - 14, wy1 + 2, x1 + 14, wy1 + 10], fill=light); d.rectangle([x0 - 14, wy1 + 9, x1 + 14, wy1 + 12], fill=dark)  # Sohlbank
    save(np.asarray(im).astype(float), name)

# --- Plattenbau: Betonplatten mit Fugen, breite Fenster, Balkone angedeutet
def platte(col, name, seed):
    a = wall(col, 10, seed); im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    fh = S // 4; bw = S // 4
    for f in range(4):
        y0 = f * fh; d.line([0, y0, S, y0], fill=(110, 110, 105), width=3)
        for b in range(4):
            x = b * bw; d.line([x, y0, x, y0 + fh], fill=(120, 120, 115), width=3)
            window(d, x + 40, y0 + 55, x + bw - 40, y0 + fh - 55, frame=(240, 240, 238), cross=True, curtain=((220, 215, 200), rng.uniform(0.1, 0.4)) if rng.random() < 0.6 else None)
    save(np.asarray(im).astype(float), name)

# --- Büro: Bandfassade (Brüstung hell, Fensterband dunkel)
def office(name, seed, band=(205, 205, 200), glass=((140, 170, 195), (45, 60, 80))):
    a = wall(band, 8, seed); im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    fh = S // 4
    for f in range(4):
        y0 = f * fh; gy0, gy1 = y0 + int(fh * 0.28), y0 + int(fh * 0.92)
        for k in range(gy1 - gy0):
            t = k / (gy1 - gy0); c = tuple(int(glass[0][i] * (1 - t) + glass[1][i] * t) for i in range(3)); d.line([0, gy0 + k, S, gy0 + k], fill=c)
        for x in range(0, S, S // 8): d.rectangle([x - 3, gy0, x + 3, gy1], fill=(70, 72, 76))
    save(np.asarray(im).astype(float), name)

# --- Glasturm: Vorhangfassade, Spiegelung, feines Raster
def tower(name, seed, tint):
    im = Image.new('RGB', (S, S)); d = ImageDraw.Draw(im)
    for y in range(S):
        t = y / S; c = tuple(int(tint[0][i] * (1 - t) + tint[1][i] * t) for i in range(3)); d.line([0, y, S, y], fill=c)
    a = np.asarray(im).astype(float) + noise(S, 25, 8, seed)[..., None]
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    for y in range(0, S, S // 4): d.rectangle([0, y, S, y + 6], fill=(60, 65, 72))
    for x in range(0, S, S // 8): d.rectangle([x, 0, x + 4, S], fill=(70, 75, 82))
    for k in range(6):   # einzelne beleuchtete/abgedunkelte Felder
        x = int(rng.integers(0, 8)) * S // 8; y = int(rng.integers(0, 4)) * S // 4
        d.rectangle([x + 5, y + 7, x + S // 8 - 1, y + S // 4 - 1], fill=tuple(int(c * 0.75) for c in tint[1]))
    save(np.asarray(im).astype(float), name)

# --- Backsteinhalle (Industrie): Ziegel, hohe Sprossenfenster
def brick(name, seed):
    a = np.zeros((S, S, 3)); r = np.random.default_rng(seed)
    bh = 16; bw = 48
    for row in range(S // bh):
        off = (row % 2) * bw // 2
        for col in range(-1, S // bw + 1):
            c = np.array([130, 62, 45]) * r.uniform(0.75, 1.15); x0 = col * bw + off
            a[row * bh:row * bh + bh - 3, max(0, x0):max(0, min(S, x0 + bw - 3))] = c
    a[a.sum(-1) == 0] = (170, 160, 150); a += noise(S, 14, 2, seed)[..., None]
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    for b in range(4):
        cx = b * S // 4 + S // 8; window(d, cx - 70, 120, cx + 70, S - 140, frame=(55, 60, 58), glass_top=(150, 165, 170), glass_bot=(70, 80, 85), cross=True)
        for k in range(1, 6): d.rectangle([cx - 70, 120 + k * (S - 260) // 6, cx + 70, 124 + k * (S - 260) // 6], fill=(55, 60, 58))
        d.rectangle([cx - 82, 100, cx + 82, 120], fill=(150, 140, 130))
    save(np.asarray(im).astype(float), name)

# --- Erdgeschoss mit Läden: 4 Schaufenster mit Markisen-Kante und Schildband
def shops(name, seed, col):
    a = wall(col, 10, seed); im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    bw = S // 4; sign_cols = [(150, 30, 25), (25, 70, 45), (30, 50, 110), (180, 130, 30), (40, 40, 45)]
    for b in range(4):
        x0 = b * bw + 18; x1 = (b + 1) * bw - 18
        d.rectangle([x0, 150, x1, 230], fill=sign_cols[int(rng.integers(0, 5))])
        window(d, x0, 260, x1, S - 40, frame=(35, 35, 38), glass_top=(185, 175, 150), glass_bot=(95, 85, 70), cross=False)
        for k in range(3): d.rectangle([x0 + 20, 420 + k * 170, x1 - 20, 428 + k * 170], fill=(90, 70, 50))
    save(np.asarray(im).astype(float), name)

altbau((222, 205, 170), 'altbau_creme.jpg', 1); altbau((205, 170, 120), 'altbau_ocker.jpg', 2)
altbau((185, 190, 192), 'altbau_grau.jpg', 3); altbau((200, 150, 140), 'altbau_rose.jpg', 4); altbau((175, 190, 200), 'altbau_blau.jpg', 5)
platte((190, 188, 180), 'platte_grau.jpg', 6); platte((215, 200, 165), 'platte_gelb.jpg', 7)
office('buero_hell.jpg', 8); office('buero_dunkel.jpg', 9, band=(70, 72, 76), glass=((120, 150, 175), (30, 40, 55)))
tower('turm_blau.jpg', 10, ((120, 160, 200), (35, 55, 85))); tower('turm_gruen.jpg', 11, ((120, 175, 170), (30, 65, 65))); tower('turm_bronze.jpg', 12, ((175, 150, 115), (60, 45, 30)))
brick('halle_ziegel.jpg', 13)
shops('laden_creme.jpg', 14, (200, 190, 170)); shops('laden_grau.jpg', 15, (150, 150, 150))
print('ok', sorted(os.listdir(OUT)))
