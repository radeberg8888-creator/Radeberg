# Radeberg-Karte im Stil einer Straßenkarte aus Gelände, Straßen und Häusern (ohne 3D-Rendern).
# Aufruf: python3 tools/karte_2d.py kartendaten.json ausgabe.png [px_pro_m]
import numpy as np, struct, json, sys, math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

daten = json.load(open(sys.argv[1])); OUT = sys.argv[2]
S = float(sys.argv[3]) if len(sys.argv) > 3 else 0.4
SAUBER = len(sys.argv) > 4 and sys.argv[4] == 'spiel'   # ohne Symbole (das Spiel zeichnet sie selbst)
d = open('assets/cache/gelaende.bin', 'rb').read()
nx, nz, x0, z0, st = struct.unpack('<iifff', d[4:24]); o = 24
H = np.frombuffer(d, np.float32, nx * nz, o).reshape(nz, nx); o += nx * nz * 4
KD = np.frombuffer(d, np.float32, nx * nz, o).reshape(nz, nx); o += nx * nz * 4
B = np.frombuffer(d, np.uint8, nx * nz * 4, o).reshape(nz, nx, 4).astype(float) / 255.0

W, Hh = int(nx * st * S), int(nz * st * S)
def P(x, z): return ((x - x0) * S, (z - z0) * S)

# ---------- Gelände (Farben wie eine Spielkarte: helle Pastelltöne, weiche Schattierung) ----------
gras = np.array([186, 214, 142]); wald = np.array([150, 188, 112]); sand = np.array([236, 220, 160])
fels = np.array([196, 200, 176]); trocken = np.array([228, 206, 146]); schnee = np.array([236, 238, 232])
rest = np.clip(1 - B[..., 0] - B[..., 1] - B[..., 2] - B[..., 3], 0, 1)
col = B[..., 0, None] * gras + B[..., 1, None] * wald + B[..., 2, None] * sand + B[..., 3, None] * fels + rest[..., None] * trocken
col = col + (schnee - col) * np.clip((H - 650) / 150, 0, 1)[..., None]
gx = np.gradient(H, st, axis=1); gz = np.gradient(H, st, axis=0)
licht = np.clip(1.0 + (-gx * 0.6 - gz * 0.6) * 0.35, 0.8, 1.12)
col = col * licht[..., None]
land = Image.fromarray(((H >= 0.0) * 255).astype(np.uint8))
nah = np.asarray(land.filter(ImageFilter.GaussianBlur(16))).astype(float) / 255.0
tief = (1.0 - np.clip(nah * 3.0, 0, 1))[..., None]
wasser = np.array([168, 212, 238]) * (1 - tief) + np.array([118, 178, 222]) * tief
col = np.where((H < 0.0)[..., None], wasser, col)
img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)).resize((W, Hh), Image.BICUBIC)

# ---------- Stadtflächen (hellgrau unter der Bebauung) ----------
maske = Image.new('L', (W, Hh), 0); dm = ImageDraw.Draw(maske)
for h in daten['haeuser']:
    cx, cz = P(h[0], h[1]); r = max(h[3], h[4]) * S * 1.3 + 5
    dm.ellipse([cx - r, cz - r, cx + r, cz + r], fill=255)
for r in daten['strassen']:
    if r['typ'] in ('strasse', 'allee', 'gasse'):
        dm.line([P(*p) for p in r['p']], fill=255, width=int(max(3, 2 * (r['w'] + r['sw']) * S + 8)))
maske = maske.filter(ImageFilter.GaussianBlur(5)).point(lambda v: 255 if v > 110 else int(v * 2.0))
stadt = Image.new('RGB', (W, Hh), (222, 222, 220))
img = Image.composite(stadt, img, maske.point(lambda v: int(v * 0.92)))
dr = ImageDraw.Draw(img)

# ---------- Häuser (Grundrisse, ohne Rand) ----------
for h in daten['haeuser']:
    cx, cz, yaw, sx, sz = h[0], h[1], h[2], h[3] * 0.49, h[4] * 0.49
    c, s = math.cos(yaw), math.sin(yaw)
    pts = []
    for ex, ez in [(-sx, -sz), (sx, -sz), (sx, sz), (-sx, sz)]:
        pts.append(P(cx + ex * c + ez * s, cz - ex * s + ez * c))
    hh = min(h[5], 150) / 150.0
    g = int(198 - 48 * hh)
    dr.polygon(pts, fill=(g, g, g + 3))

# ---------- Anlagen (Hafen, Docks, Flughafen, Militär, Bahnhof) ----------
def rechteck(xa, za, xb, zb, fill, outline=(90, 90, 95)):
    a = P(xa, za); b = P(xb, zb); dr.rectangle([min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])], fill=fill, outline=outline)
import random
rnd = random.Random(3)
CONT = [(170, 50, 40), (40, 80, 150), (40, 120, 70), (220, 140, 30), (140, 140, 145)]
def terminal(qx0, qx1, zq0, zq1):   # Kaifläche mit Containerreihen
    rechteck(qx0, zq0, qx1, zq1, (205, 205, 205), None)
    for x in range(int(qx0) + 15, int(qx1) - 15, 26):
        for z in range(int(zq0) + 12, int(zq1) - 40, 8):
            if rnd.random() < 0.85: rechteck(x, z, x + 12, z + 2.5, CONT[rnd.randrange(5)], None)
# Docks (drei Terminals am Südkai): Welt x = px - lokal_z, z = 648 + lokal_x
for px in (650, 1450, -150):
    terminal(px - 560, px - 140, 2088, 2300)
    for k in (230, 360, 490): rechteck(px - k - 14, 2270, px - k + 14, 2300, (210, 60, 40))   # Kräne
    rechteck(px - 470, 2304, px - 230, 2338, (40, 50, 80))   # Schiff
# Containerhafen am Hafenbecken
terminal(1573, 1785, 470, 890); rechteck(1789, 560, 1823, 800, (40, 50, 80))
# Flughafen
rechteck(-2450, 1760, -1450, 1935, (225, 225, 225), None); rechteck(-2350, 1680, -1650, 1745, (180, 180, 186), None); rechteck(-2300, 1500, -2050, 1580, (190, 190, 192), None)
for k in range(6):
    x = -2280 + k * 120; rechteck(x - 17, 1815, x + 17, 1835, (245, 245, 248))
# Militärbasis: Zaun, Hangars, Kasernen
mx, mz = -2600, -5450
a = P(mx - 760, mz - 150); b = P(mx + 760, mz + 430); dr.rectangle([a[0], a[1], b[0], b[1]], fill=(200, 205, 190), outline=(150, 150, 140), width=2)
for k in range(4): rechteck(mx - 450 + k * 300 - 22, mz + 270, mx - 450 + k * 300 + 22, mz + 330, (95, 105, 70))
for k in range(5): rechteck(mx + 250 + k * 80, mz + 210, mx + 305 + k * 80, mz + 232, (170, 160, 130))
# Hauptbahnhof
rechteck(615, -115, 765, 295, (180, 172, 170), None)
# Gefängnis: Achteck-Mauer, Zellentrakte
kx, kz = 2000, -5050
acht = [P(kx + 225 * math.cos(math.pi / 8 + k * math.pi / 4), kz + 225 * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)]
dr.polygon(acht, fill=(214, 214, 210), outline=(150, 150, 150), width=3)
for k in range(6):
    a = k * math.pi / 3; q = [P(kx + rr * math.cos(a + o), kz + rr * math.sin(a + o)) for rr, o in ((60, -0.25), (190, -0.08), (190, 0.08), (60, 0.25))]
    dr.polygon(q, fill=(170, 170, 176))
dr.ellipse([P(kx - 45, kz - 45), P(kx + 45, kz + 45)], fill=(160, 160, 166))

# ---------- Straßen ----------
STIL = {  # Füllfarbe, Rand, Mindestbreite px
    'autobahn': ((252, 246, 214), (196, 178, 128), 4.5), 'rampe': ((252, 246, 214), (196, 178, 128), 2.2),
    'allee': ((255, 255, 255), (186, 186, 186), 3), 'strasse': ((255, 255, 255), (196, 196, 196), 2),
    'gasse': ((255, 255, 255), (200, 200, 200), 1.4), 'land': ((255, 255, 255), (170, 170, 160), 2),
    'piste': ((184, 128, 84), (184, 128, 84), 1.4), 'runway': ((250, 250, 250), (200, 200, 200), 6), 'taxi': ((238, 238, 238), (205, 205, 205), 3),
    'schiene': ((120, 110, 110), (120, 110, 110), 1.5)}
ORD = ['schiene', 'piste', 'gasse', 'land', 'strasse', 'allee', 'taxi', 'runway', 'rampe', 'autobahn']
def breite(r): return max(STIL[r['typ']][2], 2 * r['w'] * S * (1.0 if r['typ'] in ('autobahn', 'runway', 'taxi') else 1.25))
def hoehe(x, z):
    i = int(round((z - z0) / st)); j = int(round((x - x0) / st))
    return H[i, j] if 0 <= i < nz and 0 <= j < nx else -50
def stuecke(r, flag):
    cur = []
    for p, f in zip(r['p'], r['f']):
        if f == 0 and hoehe(*p) < 0: f = 1
        if f == flag: cur.append(P(*p))
        elif cur:
            if len(cur) > 1: yield cur
            cur = []
    if len(cur) > 1: yield cur
for phase in ('rand', 'fuell'):
    for t in ORD:
        for r in daten['strassen']:
            if r['typ'] != t: continue
            fill, rand, _ = STIL[t]; w = breite(r)
            pts = [P(*p) for p in r['p']]
            if t == 'schiene':
                if phase == 'fuell':
                    for i in range(0, len(pts) - 1, 4): dr.line(pts[i:i + 3], fill=fill, width=2)
                continue
            if phase == 'rand':
                dr.line(pts, fill=rand, width=int(w + 2.5), joint='curve')
                for seg in stuecke(r, 1): dr.line(seg, fill=(120, 120, 125), width=int(w + 4))   # Brücke: dunkler Rand
            else:
                dr.line(pts, fill=fill, width=int(w), joint='curve')
                for seg in stuecke(r, 2): dr.line(seg, fill=(225, 222, 210), width=int(max(1, w * 0.6)))  # Tunnel: blass, schmal
                if t == 'runway':
                    for i in range(0, len(pts) - 1, 12): dr.line(pts[i:i + 5], fill=(200, 200, 200), width=1)

# ---------- Beschriftung ----------
def font(n, bold=False):
    return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf' % ('-Bold' if bold else ''), n)
def text(x, z, t, n=26, col=(40, 40, 40), bold=True, halo=(255, 255, 255)):
    f = font(int(n * S / 0.4), bold); q = P(x, z)
    dr.text(q, t, font=f, fill=col, anchor='mm', stroke_width=max(2, int(3 * S / 0.4)), stroke_fill=halo)
GEBIETE = [(300, -330, 'DOWNTOWN', 30), (-250, 730, 'GROVE', 22), (-150, 150, 'ALTSTADT', 20), (250, 1450, 'SÜDSTADT', 28), (300, 2200, 'DOCKS', 24),
           (2700, 500, 'OSTSTADT', 30), (2200, -1050, 'OSTVORORTE', 20), (1080, -540, 'STERNVIERTEL', 16), (-1950, -100, 'STRAND', 24),
           (-2050, -1150, 'NEU-KOWLOON', 16), (-250, -1750, 'SONNENHÜGEL', 24), (-2050, 2200, 'FLUGHAFEN', 26), (-1000, -980, 'NORDSTADT', 20),
           (-850, -450, 'WESTSTADT', 22), (-1250, 850, 'KLEIN-SEOUL', 18), (1620, 1200, 'HAFENVIERTEL', 16), (1678, 560, 'CONTAINERHAFEN', 14),
           (-2600, -5650, 'MILITÄRBASIS', 22), (-2150, -8620, 'NORDBUCHT', 26), (1780, -6080, 'STAUBWINKEL', 16), (900, -5900, 'SANDUFER', 26),
           (300, -5400, 'STAUBWÜSTE', 26), (550, -6650, 'STAUBSEE', 32), (-750, -8350, 'RADEBERG-GIPFEL', 26), (1750, -7550, 'KORNFELD', 22),
           (2350, -7900, 'FARMLAND', 18), (-830, -6680, 'FISCHERDORF', 14), (2000, -5340, 'JVA STAUBTAL', 16), (-700, -2550, 'STAUSEE', 16),
           (-1300, -4400, 'FLUSSTAL', 20), (900, -3100, 'MITTELGEBIRGE', 24), (-1300, -6400, 'ESPENWALD', 18), (-250, -5650, 'ROTER CANYON', 16)]
for x, z, t, n in GEBIETE:
    dark = (95, 95, 95) if not t in ('STAUBSEE', 'STAUSEE') else (70, 120, 160)
    text(x, z, t, n, dark, halo=(245, 245, 240))
# Autobahnschilder
for r in daten['strassen']:
    if r['typ'] == 'autobahn' and r['name']:
        for k in range(len(r['p']) // 3, len(r['p']), max(1, len(r['p']) // 3)):
            q = P(*r['p'][k]); f = font(int(20 * S / 0.4), True)
            dr.rounded_rectangle([q[0] - 22 * S / 0.4, q[1] - 13 * S / 0.4, q[0] + 22 * S / 0.4, q[1] + 13 * S / 0.4], 5, fill=(30, 80, 170), outline=(255, 255, 255), width=2)
            dr.text(q, r['name'], font=f, fill=(255, 255, 255), anchor='mm')
# Läden / Symbole
if SAUBER: daten['laeden'] = []; daten['story'] = []
SYM = {'werkstatt': ((230, 120, 20), 'W'), 'lack': ((200, 40, 160), 'L'), 'waffen': ((200, 40, 40), 'G'), 'wueste': ((200, 40, 40), 'G'), 'kleider': ((60, 140, 220), 'K'),
       'zuhause': ((40, 170, 70), 'H'), 'autohaus': ((40, 110, 200), '$'), 'premium': ((180, 150, 30), '$'), 'lager': ((150, 110, 60), 'L')}
for typ, x, z in daten['laeden']:
    if typ not in SYM: continue
    c, b = SYM[typ]; q = P(x, z); r = 13 * S / 0.4
    dr.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=c, outline=(255, 255, 255), width=2)
    dr.text(q, b, font=font(int(16 * S / 0.4), True), fill=(255, 255, 255), anchor='mm')
for x, z, b, c in daten.get('story', []):
    q = P(x + 60, z - 60); r = 16 * S / 0.4
    dr.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=tuple(c), outline=(0, 0, 0), width=3)
    dr.text(q, b, font=font(int(20 * S / 0.4), True), fill=(0, 0, 0), anchor='mm')
img.save(OUT)
if SAUBER:
    json.dump({'x0': x0, 'z0': z0, 'x1': x0 + nx * st, 'z1': z0 + nz * st}, open('assets/ui/karte_bereich.json', 'w'))
print('Karte', img.size)
