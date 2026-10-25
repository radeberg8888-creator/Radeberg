"""Erzeugt kachelbare PBR-Texturen (Farbe, Normalen, Rauheit) für Radeberg.
Alle Muster sind periodisch (FFT-Rauschen), damit sie nahtlos kacheln."""
import numpy as np, os, sys
from PIL import Image
from scipy import ndimage
OUT = sys.argv[1] if len(sys.argv) > 1 else 'assets/textures'
os.makedirs(OUT, exist_ok=True)
R = np.random.default_rng(42)
N = 1024

def fnoise(n=N, beta=2.0, seed=None):
    rng = np.random.default_rng(seed)
    w = rng.standard_normal((n, n))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(n)[:, None]; kx = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(kx**2 + ky**2); k[0, 0] = 1
    f /= k**(beta / 2)
    r = np.real(np.fft.ifft2(f))
    r = (r - r.mean()) / (r.std() + 1e-9)
    return r

def band(n=N, lo=0.0, hi=0.5, seed=None):
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.standard_normal((n, n)))
    ky = np.fft.fftfreq(n)[:, None]; kx = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(kx**2 + ky**2)
    f *= ((k >= lo) & (k <= hi))
    r = np.real(np.fft.ifft2(f)); return (r - r.mean()) / (r.std() + 1e-9)

def normal_from_height(h, strength=4.0):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    nz = np.ones_like(h)
    l = np.sqrt(gx**2 + gy**2 + nz**2)
    n = np.stack([-gx / l, gy / l, nz / l], -1)  # OpenGL-Normalen (Godot)
    return ((n * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)

def save(name, albedo, height, rough, strength=4.0, ao=None):
    a = (np.clip(albedo, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(a, 'RGB').save(f'{OUT}/{name}_albedo.jpg', quality=90)
    Image.fromarray(normal_from_height(height, strength), 'RGB').save(f'{OUT}/{name}_normal.png', optimize=True)
    rg = np.clip(rough, 0, 1)
    if ao is None: ao = np.ones_like(rg)
    orm = np.stack([np.clip(ao, 0, 1), rg, np.zeros_like(rg)], -1)  # AO, Rauheit, Metall
    Image.fromarray((orm * 255).astype(np.uint8), 'RGB').save(f'{OUT}/{name}_orm.png', optimize=True)
    print('ok', name)

def col(*c): return np.array(c, dtype=np.float32) / 255.0

def tile_grid(n, cw, ch, gap, offset_rows=True, jitter=0.0, seed=1):
    """Liefert für jedes Pixel: Abstand zur Fuge (0..), Kachel-ID."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    row = np.floor(yy / ch)
    xo = xx + (row % 2) * cw * 0.5 if offset_rows else xx
    col_ = np.floor(xo / cw)
    lx = xo - col_ * cw; ly = yy - row * ch
    d = np.minimum(np.minimum(lx, cw - lx), np.minimum(ly, ch - ly))
    cols = int(round(n / cw)); rows = int(round(n / ch))
    tid = (np.mod(row, rows) * 1000 + np.mod(col_, cols)).astype(np.int64)
    return d, tid

def per_tile(tid, seed=0):
    rng = np.random.default_rng(seed)
    u, inv = np.unique(tid, return_inverse=True)
    v = rng.random(len(u)).astype(np.float32)
    return v[inv].reshape(tid.shape)

# ---------- Asphalt ----------
def asphalt():
    base = col(84, 85, 88)
    h = 0.6 * fnoise(beta=1.2, seed=1) + 0.4 * fnoise(beta=2.6, seed=2)
    stones = (band(lo=0.18, hi=0.5, seed=3) > 1.6).astype(np.float32)
    big = fnoise(beta=3.0, seed=4)
    a = base[None, None, :] * (1 + 0.10 * h[..., None] + 0.06 * big[..., None])
    a += stones[..., None] * col(40, 40, 40)
    # Risse
    crack = np.abs(fnoise(beta=2.8, seed=5)) < 0.025
    crack = ndimage.binary_dilation(crack, iterations=1) & (fnoise(beta=3.2, seed=6) > 0.6)
    a[crack] *= 0.45
    # Ölflecken
    oil = np.clip(fnoise(beta=3.5, seed=7) - 1.4, 0, 1)
    a *= (1 - 0.35 * oil[..., None])
    rough = 0.82 + 0.08 * h - 0.25 * oil
    height = 0.5 * h + 1.2 * stones - 2.5 * crack
    save('asphalt', a, height, rough, 2.5)

# ---------- Gehwegplatten 30x30 ----------
def pavers():
    n = N; d, tid = tile_grid(n, n / 4, n / 4, 6, offset_rows=False)
    v = per_tile(tid, 11)
    grain = fnoise(beta=1.0, seed=12)
    base = col(150, 146, 138)
    a = base[None, None] * (0.86 + 0.18 * v[..., None] + 0.05 * grain[..., None])
    stain = np.clip(fnoise(beta=3.0, seed=13) - 0.8, 0, 1)
    a *= (1 - 0.25 * stain[..., None])
    gap = d < 5
    a[gap] = col(70, 68, 62) * (0.8 + 0.2 * v[gap][..., None])
    bevel = np.clip(d / 8, 0, 1)
    height = bevel * 2 + 0.25 * grain
    rough = 0.78 + 0.1 * grain * 0.3
    ao = 0.55 + 0.45 * np.clip(d / 6, 0, 1)
    save('pavers', a * ao[..., None] ** 0.5, height, rough, 3.0, ao)

# ---------- Kopfsteinpflaster ----------
def cobble():
    n = N; cw = n / 12; ch = n / 14
    d, tid = tile_grid(n, cw, ch, 5, offset_rows=True)
    v = per_tile(tid, 21); w = per_tile(tid, 22)
    dome = np.clip(d / (ch * 0.42), 0, 1) ** 0.6
    grain = fnoise(beta=1.4, seed=23)
    base = np.where(w[..., None] > 0.5, col(122, 118, 112), col(98, 94, 90))
    a = base * (0.8 + 0.3 * v[..., None] + 0.06 * grain[..., None])
    joint = d < 4
    a[joint] = col(52, 48, 42)
    height = dome * 3 + 0.2 * grain
    rough = 0.55 + 0.25 * (1 - dome)
    ao = 0.45 + 0.55 * dome
    save('cobble', a * ao[..., None] ** 0.6, height, rough, 4.0, ao)

# ---------- Putzfassaden ----------
def plaster(name, c, dirt=0.35):
    h = 0.25 * fnoise(beta=0.9, seed=31) + 0.75 * fnoise(beta=2.2, seed=32)
    a = col(*c)[None, None] * (1 + 0.018 * h[..., None])
    patch = np.clip(fnoise(beta=3.2, seed=33) - 0.7, 0, 1)
    a *= (1 - 0.05 * patch[..., None])
    # Regenspuren: vertikal gestreckt, oben stärker
    streak = ndimage.gaussian_filter(np.random.default_rng(34).random((N, N)), sigma=(60, 2), mode='wrap')
    streak = (streak - streak.mean()) / streak.std()
    a *= (1 - dirt * 0.08 * np.clip(streak, 0, 3)[..., None])
    rough = 0.9 + 0.05 * h
    save(name, a, h, rough, 0.6)

# ---------- Dachziegel (Biberschwanz) ----------
def roof():
    n = N; cw = n / 16; ch = n / 20
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    row = np.floor(yy / ch); xo = xx + (row % 2) * cw * 0.5
    c_ = np.floor(xo / cw); lx = xo - c_ * cw - cw / 2; ly = yy - row * ch
    tid = (np.mod(row, 20) * 100 + np.mod(c_, 16)).astype(np.int64)
    v = per_tile(tid, 41)
    # runder unterer Rand
    edge = ly / ch + 0.25 * (lx / (cw / 2)) ** 2
    shade = np.clip(edge, 0, 1)
    gap = np.abs(lx) > cw / 2 - 2.5
    base = col(150, 62, 40)
    a = base * (0.75 + 0.35 * v[..., None]) * (0.65 + 0.45 * shade[..., None])
    moss = np.clip(fnoise(beta=2.6, seed=42) - 1.0, 0, 1)
    a = a * (1 - 0.5 * moss[..., None]) + moss[..., None] * col(70, 80, 40) * 0.5
    a[gap] *= 0.35
    height = shade * 2 - gap * 2
    rough = 0.7 + 0.1 * v
    save('roof', a, height, rough, 4.0, 0.6 + 0.4 * shade)

# ---------- Beton ----------
def concrete():
    h = 0.7 * fnoise(beta=1.1, seed=51) + 0.3 * fnoise(beta=2.5, seed=52)
    a = col(128, 126, 122)[None, None] * (1 + 0.07 * h[..., None])
    pores = band(lo=0.25, hi=0.5, seed=53) > 2.2
    a[pores] *= 0.6
    rough = 0.88 + 0.04 * h
    save('concrete', a, h - pores * 1.5, rough, 2.0)

# ---------- Rinde ----------
def bark():
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    s = ndimage.gaussian_filter(np.random.default_rng(61).random((N, N)), sigma=(30, 3), mode='wrap')
    s = (s - s.mean()) / s.std()
    ridges = np.abs(np.sin(xx / N * np.pi * 24 + 2.5 * s))
    a = col(84, 70, 58)[None, None] * (0.6 + 0.6 * ridges[..., None])
    save('bark', a, ridges * 2 + 0.3 * s, 0.9 + 0 * s, 4.0)

# ---------- Rasen ----------
def grass():
    h = fnoise(beta=1.0, seed=71); big = fnoise(beta=3.0, seed=72)
    a = col(76, 104, 46)[None, None] * (1 + 0.18 * h[..., None] + 0.12 * big[..., None])
    dry = np.clip(fnoise(beta=2.8, seed=73) - 0.6, 0, 1)
    a = a * (1 - 0.4 * dry[..., None]) + dry[..., None] * col(140, 130, 80) * 0.4
    save('grass', a, h, 0.92 + 0 * h, 2.0)

# ---------- Laub (Alpha) ----------
def leaves():
    n = 512; rng = np.random.default_rng(81)
    img = np.zeros((n, n, 4), np.float32)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    for i in range(260):
        cx, cy = rng.random(2) * n; L = rng.uniform(14, 30); W = L * rng.uniform(0.35, 0.5); ang = rng.uniform(0, np.pi * 2)
        ca, sa = np.cos(ang), np.sin(ang)
        x0, x1 = int(max(cx - L - 2, 0)), int(min(cx + L + 2, n)); y0, y1 = int(max(cy - L - 2, 0)), int(min(cy + L + 2, n))
        if x1 <= x0 or y1 <= y0: continue
        X = xx[y0:y1, x0:x1] - cx; Y = yy[y0:y1, x0:x1] - cy
        u = X * ca + Y * sa; v = -X * sa + Y * ca
        m = (u / L) ** 2 + (v / W) ** 2 < 1
        g = rng.uniform(0.75, 1.15)
        c = np.array([0.24, 0.40, 0.14]) * g * (0.85 + 0.3 * (u[m] / L)[:, None] * 0 + 0.15)
        tone = 0.9 + 0.2 * (v[m] / W)[:, None]
        reg = img[y0:y1, x0:x1]
        reg[m, :3] = c * tone; reg[m, 3] = 1
    Image.fromarray((img * 255).astype(np.uint8), 'RGBA').save(f'{OUT}/leaves_albedo.png', optimize=True)
    print('ok leaves')

asphalt(); pavers(); cobble(); concrete(); roof(); bark(); grass(); leaves()
plaster('plaster_cream', (214, 198, 166)); plaster('plaster_ochre', (198, 160, 104)); plaster('plaster_grey', (176, 178, 172)); plaster('plaster_blue', (150, 168, 176)); plaster('plaster_rose', (196, 150, 136)); plaster('plaster_white', (226, 222, 212))
