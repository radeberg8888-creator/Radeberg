"""Gelände von Radeberg County vorberechnen (numpy): natürliche Höhen, Küstenabstand, Bodenarten auf dem 10-m-Raster.
Eigene Insel im Aufbau großer Open-World-Karten: riesige Hauptstadt im Süden mit Flughafen-Halbinsel, Docks und Hafenbecken,
Nobelhügel mit Stausee nördlich davon, Bergketten mit Tälern, ein Fluss mit Sumpf und Militärflugplatz im Westen,
Wüste mit großem See in der Mitte/Norden, langgezogene Küstenstadt im Nordwesten, Farmland im Nordosten.
Ausgabe: assets/cache/gelaende.bin  (Kopf: 'RGEL', nx, nz, x0, z0, step; float32 Höhen, float32 Küstenabstand, uint8 RGBA Boden)"""
import numpy as np, struct, os

X0, X1, Z0, Z1, STEP = -4400.0, 4700.0, -11300.0, 3500.0, 10.0
nx = int((X1 - X0) / STEP) + 1; nz = int((Z1 - Z0) / STEP) + 1
xs = X0 + np.arange(nx) * STEP; zs = Z0 + np.arange(nz) * STEP
X, Z = np.meshgrid(xs, zs)

def perlin(x, y, seed):
    rng = np.random.RandomState(seed); p = rng.permutation(256); p = np.concatenate([p, p])
    xi = np.floor(x).astype(np.int64); yi = np.floor(y).astype(np.int64)
    xf = x - xi; yf = y - yi; xi &= 255; yi &= 255
    def fade(t): return t * t * t * (t * (t * 6 - 15) + 10)
    def grad(h, x, y):
        g = np.array([[1, 1], [-1, 1], [1, -1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]], float)[h & 7]
        return g[..., 0] * x + g[..., 1] * y
    aa = p[p[xi] + yi]; ab = p[p[xi] + yi + 1]; ba = p[p[xi + 1] + yi]; bb = p[p[xi + 1] + yi + 1]
    u = fade(xf); v = fade(yf)
    x1 = grad(aa, xf, yf) * (1 - u) + grad(ba, xf - 1, yf) * u
    x2 = grad(ab, xf, yf - 1) * (1 - u) + grad(bb, xf - 1, yf - 1) * u
    return (x1 * (1 - v) + x2 * v) * 0.95

def fbm(x, y, freq, octaves, seed):
    s = np.zeros_like(x); a = 1.0; f = freq; tot = 0
    for o in range(octaves):
        s += perlin(x * f + 13.7 * o, y * f - 7.3 * o, seed + o) * a; tot += a; a *= 0.5; f *= 2.0
    return s / tot * 1.4

def ridged(x, y, freq, octaves, seed):
    # Grate und Täler: 1-|Rauschen|, je Oktave vom vorigen Grat gewichtet
    s = np.zeros_like(x); a = 1.0; f = freq; w = np.ones_like(x); tot = 0
    for o in range(octaves):
        r = 1.0 - np.abs(perlin(x * f + 31.1 * o, y * f + 17.9 * o, seed + 40 + o))
        r = r * r * w; w = np.clip(r * 1.6, 0, 1)
        s += r * a; tot += a; a *= 0.5; f *= 2.1
    return s / tot

n1 = lambda x, y: fbm(x, y, 0.0016, 5, 7)
n2 = lambda x, y: fbm(x, y, 0.006, 3, 11)
n3 = lambda x, y: fbm(x, y, 0.0006, 4, 23)
def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
def lerp(a, b, t): return a + (b - a) * t
def g(X, Z, c, r): return np.exp(-((X - c[0]) ** 2 + (Z - c[1]) ** 2) / (r * r))
def ell(X, Z, c, rx, rz): return np.hypot((X - c[0]) / rx, (Z - c[1]) / rz)

# Küstenlinie im Uhrzeigersinn (Süden = +z). Hafenbecken als Einschnitt im Süden, Flughafen-Halbinsel im Südwesten.
KUESTE = [(-3150,2650),(-2300,2780),(-1400,2600),(-950,2300),(-300,2300),(400,2320),(1100,2330),(1700,2310),
          (1785,1700),(1785,900),(1775,220),(1860,70),(2060,50),(2160,210),(2165,900),(2160,1700),(2220,2300),
          (2700,2350),(3100,2000),(3300,1400),(3150,900),(3500,400),(3700,-300),(3450,-900),(3800,-1500),(3900,-2400),
          (3600,-3200),(3900,-3900),(3950,-4800),(3650,-5600),(3900,-6500),(3700,-7400),(3900,-8100),(3500,-8900),
          (2800,-9550),(2000,-9850),(1200,-9750),(600,-10100),(-100,-10600),(-500,-10300),(-1100,-10150),(-1700,-9800),
          (-2300,-9500),(-2800,-9100),(-3250,-8500),(-3400,-7800),(-3200,-7100),(-3350,-6400),(-3600,-5700),(-3650,-5150),
          (-3150,-4950),(-3600,-4600),(-3400,-4000),(-3200,-3300),(-3350,-2600),(-3100,-1900),(-2800,-1200),(-2500,-500),
          (-2550,300),(-2700,1000),(-3100,1600),(-3300,2200)]

def kuesten_abstand(X, Z):
    P = np.array(KUESTE, float); n = len(P)
    inside = np.zeros(X.shape, bool); dmin = np.full(X.shape, 1e9)
    for e in range(n):
        ax, az = P[e]; bx, bz = P[(e + 1) % n]
        cond = ((az > Z) != (bz > Z)) & (X < (bx - ax) * (Z - az) / (bz - az + 1e-12) + ax)
        inside ^= cond
        abx, abz = bx - ax, bz - az; L2 = abx * abx + abz * abz
        t = np.clip(((X - ax) * abx + (Z - az) * abz) / L2, 0, 1)
        d = np.hypot(X - (ax + abx * t), Z - (az + abz * t)); dmin = np.minimum(dmin, d)
    d = np.where(inside, dmin, -dmin)
    # Hafenbecken, Flughafen und Docks: gerade, künstliche Ufer (wenig Rauschen)
    kunst = (1.0 - smooth(0.9, 1.2, ell(X, Z, (400, 1900), 2600, 900))) * (Z > 1300)
    kunst = np.maximum(kunst, (1.0 - smooth(250, 450, np.abs(X - 1970))) * (Z > -100))
    kunst = np.maximum(kunst, 1.0 - smooth(0.8, 1.1, ell(X, Z, (2650, 700), 750, 1500)))   # Oststadt: keine Tümpel
    kunst = np.maximum(kunst, 0.7 * (1.0 - smooth(0.8, 1.1, ell(X, Z, (-2350, 0), 400, 1100))))   # Strand: ruhigere Küste
    rausch = n1(X * 0.6, Z * 0.6) * 950.0 + n1(X * 1.8 + 99, Z * 1.8) * 320.0 + n2(X * 0.9, Z * 0.9) * 90.0
    return d + rausch * (1 - np.clip(kunst, 0, 1))

# Fluss: vom Bergland durch ein breites Tal nach Westen ins Meer (mit Sumpf an der Mündung)
FLUSS = [(400,-4200),(-200,-4450),(-800,-4500),(-1400,-4650),(-1900,-4600),(-2400,-4750),(-2900,-4800),(-3600,-4850)]
def fluss_abstand(X, Z):
    P = np.array(FLUSS, float); d = np.full(X.shape, 1e9); tpos = np.zeros(X.shape)
    for e in range(len(P) - 1):
        ax, az = P[e]; bx, bz = P[e + 1]; abx, abz = bx - ax, bz - az; L2 = abx * abx + abz * abz
        t = np.clip(((X - ax) * abx + (Z - az) * abz) / L2, 0, 1)
        dd = np.hypot(X - (ax + abx * t), Z - (az + abz * t))
        tpos = np.where(dd < d, (e + t) / (len(P) - 1), tpos); d = np.minimum(d, dd)
    return d + n2(X * 0.5, Z * 0.5) * 30.0, tpos

def nat(X, Z, kd):
    m = np.clip((kd + 40.0) / 160.0, 0, 1)
    WX = X + n1(X * 0.5 + 300, Z * 0.5) * 380.0; WZ = Z + n1(X * 0.5, Z * 0.5 - 200) * 380.0
    R = ridged(WX, WZ, 0.0011, 6, 5)            # Grate/Täler
    hills = 18.0 + n1(X, Z) * 14.0 + n3(X, Z) * 30.0
    h = hills.copy()
    # --- Bergland: Gewichte je Region (Gipfel im Norden, Westkette, Ostkette, Mittelgebirge, Nobelhügel)
    berg = np.zeros_like(X)
    berg = np.maximum(berg, 720.0 * g(WX, WZ, (-700, -8350), 1150.0))            # Radeberg-Gipfel
    berg = np.maximum(berg, 330.0 * g(WX * 0.7, WZ, (-2200 * 0.7, -7200), 900.0))  # Nordwestkette
    berg = np.maximum(berg, 300.0 * g(WX, WZ * 0.45, (-1900, -3300 * 0.45), 700.0))  # Westkette südl. des Flusses
    berg = np.maximum(berg, 260.0 * g(WX, WZ * 0.45, (-2000, -5900 * 0.45), 650.0))  # Berge um den Militärflugplatz
    berg = np.maximum(berg, 360.0 * g(WX * 1.6, WZ * 0.35, (3150 * 1.6, -4500 * 0.35), 650.0))  # Ostkette entlang der Küste
    berg = np.maximum(berg, 230.0 * g(WX, WZ * 0.6, (900, -3200 * 0.6), 1100.0))     # Mittelgebirge
    berg = np.maximum(berg, 200.0 * g(WX, WZ, (-200, -1900), 720.0))               # Sonnenhügel (Nobelviertel)
    berg = np.maximum(berg, 140.0 * g(WX, WZ, (1900, -1600), 600.0))                # Osthügel
    berg = np.maximum(berg, 170.0 * g(WX, WZ, (2900, -9000), 600.0))
    h += berg * (0.45 + 0.85 * R)
    # --- Hauptstadt: flaches, leicht welliges Becken
    ds = ell(X, Z, (0, 550), 2750, 2050)
    stadt = 1.0 - smooth(0.78, 1.0, ds)
    h = h * (1 - stadt) + (10.0 + n1(X, Z) * 5.0 + 10.0 * g(X, Z, (650, 520), 350.0) - 6.0 * g(X, Z, (-250, 640), 300.0)) * stadt
    h += 50.0 * g(X, Z, (760, -860), 330.0) * stadt                 # Ostvororte am Hang
    h += 45.0 * g(X, Z, (-1080, -820), 260.0) * stadt               # Stadtberg im Nordwesten
    # Flughafen-Halbinsel, Docks: tiefes, ebenes Land
    flach = (1.0 - smooth(0.85, 1.05, ell(X, Z, (-2050, 2050), 1100, 650))) + (1.0 - smooth(0.85, 1.05, ell(X, Z, (800, 2000), 1300, 380)))
    flach = np.clip(flach, 0, 1)
    h = h * (1 - flach) + 4.5 * flach
    # --- Stausee in den Nobelhügeln
    st = ell(X + n2(X, Z) * 60, Z, (-650, -2550), 420, 230)
    h = np.where(st < 1.3, lerp(h, -6.0, 1.0 - smooth(0.75, 1.3, st)), h)
    stausee = st < 1.05
    # --- Wüste (Staubebene) südlich des großen Sees
    dd = ell(WX, WZ, (900, -5700), 2100, 900) + n2(X * 0.3, Z * 0.3) * 0.18 + n1(X * 1.5, Z * 1.5) * 0.1
    w = 1.0 - smooth(0.72, 1.0, dd)
    h = h * (1 - w) + (14.0 + np.abs(n2(X * 1.4, Z * 1.4)) * 7.0 + n3(X, Z) * 6.0) * w
    for c, r, a in [((-300, -5300), 170.0, 60.0), ((2200, -5200), 200.0, 80.0), ((2600, -5900), 150.0, 70.0), ((1300, -5050), 120.0, 45.0)]:
        dist = np.hypot(X - c[0] + n2(X, Z) * r * 0.35, Z - c[1] + n2(Z, X) * r * 0.35) / r
        h += a * smooth(1.0, 0.82, dist) + a * 0.25 * smooth(1.5, 1.0, dist)   # Tafelberge
    # --- Großer See (Staubsee), langgestreckt
    LX = X + n1(X + 50, Z) * 420.0; LZ = Z + n1(X, Z + 70) * 200.0
    ls = ell(LX, LZ, (550, -6650), 1500, 520) + n2(X * 0.5, Z * 0.5) * 0.15 + n1(X * 2, Z * 2) * 0.12
    see = 1.0 - smooth(0.78, 1.25, ls)
    h = np.where(ls < 1.25, h * (1 - see) - 8.0 * see, h)
    # --- Fluss mit Tal und Sumpf
    fd, ft = fluss_abstand(X, Z)
    tal_b = 180.0 + 380.0 * ft                     # Tal wird zur Mündung breiter
    tal = 1.0 - smooth(tal_b * 0.35, tal_b, fd)
    h = h * (1 - tal) + (2.5 + 8.0 * (1 - ft)) * tal
    h = np.where(fd < 28.0 + 40.0 * ft, np.minimum(h, -3.0), h)
    # --- Farmland im Nordosten (Felder, flach)
    df = ell(WX, WZ, (2350, -7700), 800, 650)
    fw = 1.0 - smooth(0.7, 1.0, df)
    h = h * (1 - fw) + (35.0 + n1(X, Z) * 4.0) * fw
    # --- Küstenstadt im Nordwesten: schmaler, flacher Streifen am Meer
    nb = (1.0 - smooth(120.0, 420.0, kd)) * (1.0 - smooth(0.8, 1.1, ell(X, Z, (-2350, -9100), 950, 650)))
    h = h * (1 - nb) + 6.0 * nb
    # --- Küste
    land = np.where(ls >= 1.0, np.maximum(h, np.where(fd < 40, h, 3.0 + np.abs(n2(X, Z)) * 2.0)), h)
    kuest = lerp(-14.0, lerp(1.2, np.maximum(h, 1.5), smooth(0.0, 1.0, m * m)), smooth(0.0, 0.35, m))
    H = np.where(m >= 1.0, land, kuest)
    H = np.where((fd < 28.0 + 40.0 * ft) & (m > 0.2), np.minimum(H, -3.0), H)
    H = np.where(stausee & (m >= 1.0), np.minimum(H, lerp(-6.0, H, smooth(0.75, 1.05, st))), H)
    return H, ls, dd, df, fd, WX, WZ

def boden(X, Z, H, kd, ls, wd, df, fd):
    nn = n2(X * 0.35, Z * 0.35)
    sand = 1.0 - smooth(0.62, 0.85, wd + nn * 0.12)
    sand = np.maximum(sand, 1.0 - smooth(1.0, 1.18, ls))
    isl = np.clip((kd + 40.0) / 160.0, 0, 1)
    sand = np.maximum(sand, 1.0 - smooth(0.12, 0.45, isl))
    gx = np.gradient(H, STEP, axis=1); gz = np.gradient(H, STEP, axis=0)
    slope = 1.0 - 1.0 / np.sqrt(1 + gx * gx + gz * gz)
    stadt = 1.0 - smooth(0.78, 1.0, ell(X, Z, (0, 550), 2750, 2050))
    forest = smooth(45.0, 90.0, H) * (1.0 - smooth(430.0, 520.0, H)) * (0.55 + 0.45 * smooth(-0.1, 0.25, nn))
    forest = np.maximum(forest, (1.0 - smooth(350.0, 650.0, fd)) * 0.7 * smooth(3.0, 8.0, H))   # Auwald am Fluss
    forest *= (1.0 - stadt) * (1.0 - smooth(0.8, 1.0, 1.0 - wd))
    rock = np.clip(smooth(0.28, 0.5, slope) + smooth(480.0, 560.0, H), 0, 1)
    wueste = 1.0 - smooth(0.95, 1.3, wd)                 # Tafelberge in der Wüste: kein Wald/Gras, Fels und Sand
    forest *= 1.0 - wueste
    sand = np.maximum(sand, wueste * 0.6 * (1.0 - smooth(0.35, 0.6, slope)))
    grass = np.clip(1.0 - sand - forest - rock, 0, 1)
    dryp = smooth(0.0, 0.35, n2(X * 0.25 + 400.0, Z * 0.25)) * 0.65 + (1.0 - smooth(0.85, 1.2, wd)) * 0.8 + smooth(60.0, 200.0, H) * 0.35
    felder = (np.floor(X / 70.0) + np.floor(Z / 110.0)) % 2 == 0
    dryp = np.where(df < 1.0, 0.1 + 0.7 * felder, dryp)
    dryp = np.where(fd < 300, dryp * 0.3, dryp)          # grüner Sumpf am Fluss
    grass *= 1.0 - np.clip(dryp, 0, 0.9)
    rgba = np.stack([grass, forest * (1 - rock), sand * (1 - rock), rock], -1)
    return (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)

# Autobahn-Trassen: Täler/Pässe entlang der Autobahnen einschneiden, damit sie über Land laufen statt im Tunnel
def _cr(p0, p1, p2, p3, t):
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
def trassen(H):
    import json
    from scipy import ndimage
    pfad = os.path.join(os.path.dirname(__file__), '..', 'assets', 'cache', 'autobahn_trassen.json')
    if not os.path.exists(pfad): return H
    ziel = np.full(H.shape, np.nan, np.float32); mark = np.zeros(H.shape, bool); ende = np.zeros(H.shape, np.float32)
    def hgrid(x, z):
        j = np.clip(np.round((x - X0) / STEP).astype(int), 0, nx - 1); i = np.clip(np.round((z - Z0) / STEP).astype(int), 0, nz - 1)
        return i, j
    for r in json.load(open(pfad)):
        c = np.array(r['p'], float); n = len(c); pts = []
        for k in range(n - 1):
            p0 = c[k - 1] if k > 0 else 2 * c[0] - c[1]; p3 = c[k + 2] if k + 2 < n else 2 * c[n - 1] - c[n - 2]
            L = np.hypot(*(c[k + 1] - c[k])); m = max(2, int(L / 8))
            for t in np.arange(m) / m: pts.append(_cr(p0, c[k], c[k + 1], p3, t))
        pts.append(c[-1]); P = np.array(pts)
        i, j = hgrid(P[:, 0], P[:, 1]); h = H[i, j].astype(float)
        h = np.maximum(h, 2.0)
        # Talsohle: gleitendes Minimum, geglättet, Steigung <= 4 %
        lo = ndimage.minimum_filter1d(h, 61, mode='nearest')
        lo = ndimage.gaussian_filter1d(lo, 25, mode='nearest')
        ds = 8.0; g = 0.04 * ds
        for k in range(1, len(lo)): lo[k] = min(lo[k], lo[k - 1] + g)
        for k in range(len(lo) - 2, -1, -1): lo[k] = min(lo[k], lo[k + 1] + g)
        lo = np.maximum(lo, 2.0)
        N = len(lo); e = np.clip(np.minimum(np.arange(N), N - 1 - np.arange(N)) / 40.0, 0, 1)
        if r['name'] == 'A1': e[:] = 1.0      # A1 endet am Stadtring (Gelände dort flach)
        for a, b, v, ee in zip(i, j, lo, e):
            if not mark[a, b] or v < ziel[a, b]: ziel[a, b] = v
            ende[a, b] = max(ende[a, b], ee); mark[a, b] = True
    d, idx = ndimage.distance_transform_edt(~mark, return_indices=True)
    d = d * STEP; T = ziel[idx[0], idx[1]]
    w = (1.0 - smooth(70.0, 520.0, d)) * ende[idx[0], idx[1]]
    # nur absenken (nie aufschütten), Wasser bleibt Wasser; Absenkung weichzeichnen (keine Kanten zwischen Trassen)
    delta = np.where(H > T, (H - T) * w, 0.0)
    delta = ndimage.gaussian_filter(delta, 3.0)
    delta = np.minimum(delta, np.maximum(H - 2.0, 0.0))
    return np.where(H < 0, H, H - delta).astype(np.float32)

if __name__ == '__main__':
    kd = kuesten_abstand(X, Z).astype(np.float32)
    H, ls, wd, df, fd, WX, WZ = nat(X, Z, kd)
    H = H.astype(np.float32)
    H = trassen(H)
    B = boden(X, Z, H, kd, ls, wd, df, fd)
    out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'cache', 'gelaende.bin')
    with open(out, 'wb') as f:
        f.write(b'RGEL'); f.write(struct.pack('<iifff', nx, nz, X0, Z0, STEP))
        f.write(H.tobytes()); f.write(kd.tobytes()); f.write(B.tobytes())
    print('ok', nx, nz, 'Höhen', float(H.min()), float(H.max()), 'MB', os.path.getsize(out) // 1000000)
    from PIL import Image
    land = H > 0.3
    c = B.astype(float) / 255.0
    col = (c[..., 0:1] * [90, 140, 60] + c[..., 1:2] * [40, 80, 40] + c[..., 2:3] * [215, 190, 140] + c[..., 3:4] * [120, 115, 110] +
           (1 - c.sum(-1, keepdims=True)).clip(0, 1) * [150, 150, 90])
    shade = np.clip(1.0 + (np.gradient(H, axis=1) - np.gradient(H, axis=0)) * 0.06, 0.55, 1.35)[..., None]
    img = np.where(land[..., None], (col * shade).clip(0, 255), [25, 70, 110]).astype(np.uint8)
    Image.fromarray(img).resize((nx // 2, nz // 2)).save('/home/claude/shots_godot/gelaende_vorschau.png')
