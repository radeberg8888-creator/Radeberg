# Höhenkarte: Gelände nach Höhe eingefärbt mit Höhenlinien, Straßen nach ihrer Fahrbahnhöhe,
# Brücken (dunkelblau unterlegt) und Tunnel (gestrichelt). Dazu Höhenprofile der Hauptstrecken.
# Aufruf: python3 tools/hoehenkarte.py kartendaten.json ausgabeordner
import json, struct, sys, numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap, LightSource, Normalize
from matplotlib.collections import LineCollection

daten = json.load(open(sys.argv[1])); OUT = sys.argv[2]
d = open('assets/cache/gelaende.bin', 'rb').read()
nx, nz, x0, z0, st = struct.unpack('<iifff', d[4:24]); o = 24
H = np.frombuffer(d, np.float32, nx * nz, o).reshape(nz, nx).astype(float)
ext = [x0, x0 + nx * st, z0 + nz * st, z0]

farben = [(0.0, '#3f8f5a'), (0.04, '#7dbb6a'), (0.12, '#c9d98a'), (0.25, '#e8d48c'), (0.4, '#d9a86a'),
          (0.58, '#b47a52'), (0.75, '#9a8f86'), (0.9, '#e0e0e0'), (1.0, '#ffffff')]
cm = LinearSegmentedColormap.from_list('hoehe', farben)
norm = Normalize(0, 900)
ls = LightSource(azdeg=315, altdeg=40)
land = np.where(H < 0, np.nan, H)
rgb = ls.shade(np.nan_to_num(land, nan=0.0), cmap=cm, norm=norm, blend_mode='soft', vert_exag=2.0, dx=st, dy=st)
wasser = H < 0
rgb[wasser, :3] = np.array([0.55, 0.75, 0.9]) - np.clip(-H[wasser] / 40.0, 0, 0.25)[:, None]

ORTE = [(300, -330, 'Downtown'), (-250, 730, 'Grove'), (250, 1450, 'Südstadt'), (2700, 500, 'Oststadt'), (-1950, -100, 'Strand'),
        (-250, -1750, 'Sonnenhügel'), (-2050, 2150, 'Flughafen'), (-2600, -5650, 'Militärbasis'), (-2150, -8620, 'Nordbucht'),
        (900, -5900, 'Sandufer'), (550, -6650, 'Staubsee'), (-750, -8350, 'Radeberg-Gipfel'), (1750, -7550, 'Kornfeld'),
        (2000, -5340, 'JVA'), (-700, -2550, 'Stausee'), (-1300, -4400, 'Flusstal'), (900, -3100, 'Mittelgebirge'), (300, -5400, 'Staubwüste')]

def karte(datei, bereich=None, breite_zoll=12, lw_scale=1.0, titel='', hmax=900):
    norm = Normalize(0, hmax)
    rgb = ls.shade(np.nan_to_num(land, nan=0.0), cmap=cm, norm=norm, blend_mode='soft', vert_exag=2.0 * 900 / hmax, dx=st, dy=st)
    rgb[wasser, :3] = np.array([0.55, 0.75, 0.9]) - np.clip(-H[wasser] / 40.0, 0, 0.25)[:, None]
    fig, ax = plt.subplots(figsize=(breite_zoll, breite_zoll * (abs(ext[2] - ext[3]) / (ext[1] - ext[0])) if bereich is None
                                    else breite_zoll * (bereich[3] - bereich[2]) / (bereich[1] - bereich[0])), dpi=150)
    ax.imshow(rgb, extent=ext, interpolation='bilinear')
    X = np.linspace(ext[0], ext[1], nx); Z = np.linspace(ext[3], ext[2], nz)
    fein = 10 if hmax <= 200 else 50; grob = 50 if hmax <= 200 else 250
    ax.contour(X, Z, land, levels=np.arange(fein, 900, fein), colors='k', linewidths=0.25 * lw_scale, alpha=0.35)
    cs = ax.contour(X, Z, land, levels=np.arange(grob, 900, grob), colors='k', linewidths=0.7 * lw_scale, alpha=0.55)
    ax.clabel(cs, fmt='%d m', fontsize=6 * lw_scale)
    for r in daten['strassen']:
        p = np.array(r['p']); h = np.array(r['h']); f = np.array(r['f'])
        if len(p) < 2: continue
        typ = r['typ']
        if typ in ('runway', 'taxi'): continue
        w = {'autobahn': 3.4, 'rampe': 1.6, 'allee': 2.0, 'strasse': 1.4, 'gasse': 1.0, 'land': 1.8, 'piste': 1.0, 'schiene': 1.0}.get(typ, 1.0) * lw_scale
        seg = np.stack([p[:-1], p[1:]], axis=1)
        hm = (h[:-1] + h[1:]) * 0.5
        bruecke = (f[:-1] == 1) | (f[1:] == 1); tunnel = (f[:-1] == 2) & (f[1:] == 2)
        if bruecke.any(): ax.add_collection(LineCollection(seg[bruecke], colors='#16306e', linewidths=w + 2.6 * lw_scale, zorder=3))
        ax.add_collection(LineCollection(seg[~tunnel], colors='#3a3a3a', linewidths=w + 0.5 * lw_scale, zorder=4))
        ax.add_collection(LineCollection(seg[~tunnel], array=hm[~tunnel], cmap=cm, norm=norm, linewidths=w, zorder=5))
        if tunnel.any(): ax.add_collection(LineCollection(seg[tunnel], colors='#303030', linewidths=w * 0.8, linestyles=(0, (2, 2)), zorder=5))
    for x, z, t in ORTE:
        if bereich and not (bereich[0] < x < bereich[1] and bereich[2] < z < bereich[3]): continue
        ax.text(x, z, t, fontsize=7 * lw_scale, ha='center', va='center', color='#111', weight='bold',
                bbox=dict(boxstyle='round,pad=0.15', fc=(1, 1, 1, 0.65), ec='none'), zorder=8)
    if bereich: ax.set_xlim(bereich[0], bereich[1]); ax.set_ylim(bereich[3], bereich[2])
    else: ax.set_xlim(ext[0], ext[1]); ax.set_ylim(ext[2], ext[3])
    ax.set_xticks([]); ax.set_yticks([])
    sm = plt.cm.ScalarMappable(cmap=cm, norm=norm)
    cb = fig.colorbar(sm, ax=ax, fraction=0.03, pad=0.01); cb.set_label('Höhe über Meer (m)')
    ax.set_title(titel + '   (Straßenfarbe = Fahrbahnhöhe, dunkelblau unterlegt = Brücke, gestrichelt = Tunnel)', fontsize=9)
    fig.tight_layout(); fig.savefig(datei); plt.close(fig)

karte(OUT + '/hoehe_gesamt.png', None, 11, 0.8, 'Radeberg – Höhenkarte')
karte(OUT + '/hoehe_stadt.png', (-2600, 3400, -2300, 2600), 14, 1.2, 'Hauptstadt und Sonnenhügel (Farbskala 0–180 m)', 180)
karte(OUT + '/hoehe_norden.png', (-3400, 3600, -10200, -4300), 14, 1.1, 'Norden: Gipfel, See, Wüste')

# ---------- Höhenprofile ----------
def profil(r):
    p = np.array(r['p']); s = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(p, axis=0).T))])
    return s / 1000.0, np.array(r['h']), np.array(r['g']), np.array(r['f'])
namen = ['A1', 'A2', 'A3', 'A5', 'Bergpass', 'Gipfelstraße', 'Stauseeweg', 'Seeuferstraße']
fig, axs = plt.subplots(len(namen), 1, figsize=(14, 2.2 * len(namen)), dpi=130)
for ax, n in zip(axs, namen):
    r = next((x for x in daten['strassen'] if x['name'] == n), None)
    if r is None: ax.set_visible(False); continue
    s, h, g, f = profil(r)
    ax.fill_between(s, np.minimum(g, 0), np.maximum(g, 0), color='#9cc6e6', lw=0)
    ax.fill_between(s, 0, np.maximum(g, 0), color='#c9b48a', alpha=0.8, lw=0, label='Gelände')
    ax.plot(s, h, color='#222', lw=1.4, label='Fahrbahn')
    if (f == 1).any(): ax.fill_between(s, g, h, where=(f == 1), color='#16306e', alpha=0.6, lw=0, label='Brücke')
    if (f == 2).any(): ax.fill_between(s, h, g, where=(f == 2), color='#555', alpha=0.45, lw=0, label='Tunnel')
    ax.set_ylabel('m'); ax.set_xlim(0, s[-1]); ax.grid(alpha=0.3)
    ax.set_title('%s  –  Länge %.1f km, Höhe %d–%d m, Brücke %d %%, Tunnel %d %%' % (n, s[-1], h.min(), h.max(), 100 * (f == 1).mean(), 100 * (f == 2).mean()), fontsize=10, loc='left')
    ax.legend(loc='upper right', fontsize=7, ncol=4)
axs[-1].set_xlabel('Strecke (km)')
fig.tight_layout(); fig.savefig(OUT + '/hoehe_profile.png'); plt.close(fig)
print('fertig')
