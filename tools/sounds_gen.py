#!/usr/bin/env python3
# Erzeugt alle Spielgeräusche synthetisch (keine fremden Aufnahmen):
#  Motor-Schleifen je Fahrzeugklasse (niedrige + hohe Drehzahl), Schüsse, Stadt-Umgebung.
# Ausgabe: assets/sounds/*.wav (Spiel) und /home/claude/work/hoer/*.mp3 (Hörproben)
import numpy as np, os, subprocess, sys
from scipy.signal import butter, sosfilt, sosfiltfilt
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
HOER = "/home/claude/work/hoer"
os.makedirs(OUT, exist_ok=True); os.makedirs(HOER, exist_ok=True)
rng = np.random.default_rng(5)

def bp(x, lo, hi, o=2):
    return sosfilt(butter(o, [lo, hi], btype="band", fs=SR, output="sos"), x)
def lp(x, f, o=2):
    return sosfilt(butter(o, f, btype="low", fs=SR, output="sos"), x)
def hp(x, f, o=2):
    return sosfilt(butter(o, f, btype="high", fs=SR, output="sos"), x)
def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak
def wav(name, x):
    import wave
    x = np.clip(x, -1, 1); d = (x * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d)
def mp3(name, x):
    p = os.path.join(HOER, name + ".wav"); import wave
    x = np.clip(x, -1, 1)
    with wave.open(p, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", p, "-b:a", "160k", p[:-4] + ".mp3"], check=True); os.remove(p)

def per_rausch(n, lo, hi):
    # periodisches (nahtlos schleifbares) Bandrauschen
    f = np.fft.rfftfreq(n, 1 / SR); m = ((f > lo) & (f < hi)).astype(float)
    return np.fft.irfft(m * np.exp(2j * np.pi * rng.random(len(f))), n) * np.sqrt(n)
def circ_conv(x, h):
    n = len(x); H = np.fft.rfft(h, n); return np.fft.irfft(np.fft.rfft(x) * H, n)

# ---------------- Motoren ----------------
# Klassen: Zündungen pro Kurbelumdrehung, Zylinder-Versatz (ungleichmäßig = Blubbern), Resonanzen, Rauheit
KLASSEN = {
    # Zweitakt-Zweizylinder: hell, knatternd, "Rängdängdäng"
    "trabant": dict(zuend=2, cyl=2, versatz=[0.0, 0.5], res=[(420, 0.9), (1300, 0.6), (2900, 0.35)], dauer=0.004, rau=0.35, tief=0.15, zisch=0.25, lpf=3200, leer=900, hoch=4500),
    # Zweitakt-Dreizylinder: etwas voller
    "wartburg": dict(zuend=3, cyl=3, versatz=[0.0, 0.333, 0.667], res=[(300, 1.0), (950, 0.6), (2300, 0.3)], dauer=0.005, rau=0.28, tief=0.25, zisch=0.2, lpf=2600, leer=850, hoch=4800),
    # Viertakt-Vierzylinder: ruhig, rund (Taxi/Polizei)
    "vier": dict(zuend=2, cyl=4, versatz=[0.0, 0.5, 0.5, 0.0], res=[(160, 1.0), (520, 0.5), (1400, 0.15)], dauer=0.007, rau=0.1, tief=0.5, zisch=0.08, lpf=1400, leer=800, hoch=6000),
    # V8 Kreuzebene: tiefes Blubbern, ungleichmäßige Zündfolge
    "v8": dict(zuend=4, cyl=8, versatz=[0.0, 0.09, 0.25, 0.41, 0.5, 0.59, 0.75, 0.91], res=[(95, 1.0), (240, 0.8), (700, 0.35), (1800, 0.18)], dauer=0.009, rau=0.18, tief=1.0, zisch=0.12, lpf=1800, leer=850, hoch=7500),
    # Diesel-Sechszylinder (Feuerwehr, RTW): nageln
    # Reihensechser mit Turbo (japanisches Sportcoupé): gleichmäßig, seidig, hell
    "turbo6": dict(zuend=3, cyl=6, versatz=[0, 1/6, 2/6, 3/6, 4/6, 5/6], res=[(210, 1.0), (620, 0.6), (1700, 0.3)], dauer=0.006, rau=0.08, tief=0.45, zisch=0.1, lpf=2400, leer=900, hoch=7800),
    # Reihensechser Sauger (deutsche Sportlimousine): kernig, sonor
    "reihe6": dict(zuend=3, cyl=6, versatz=[0, 1/6, 2/6, 3/6, 4/6, 5/6], res=[(170, 1.0), (480, 0.7), (1300, 0.25)], dauer=0.007, rau=0.1, tief=0.55, zisch=0.08, lpf=1900, leer=850, hoch=7000),
    # kleiner Vierzylinder (Kompakter): rau, brummig, Sportauspuff
    "kompakt4": dict(zuend=2, cyl=4, versatz=[0.0, 0.5, 0.5, 0.0], res=[(190, 1.0), (560, 0.7), (1500, 0.3)], dauer=0.006, rau=0.2, tief=0.5, zisch=0.12, lpf=2000, leer=900, hoch=6800),
    # leiser V8 (Luxuslimousine): tief, gedämpft
    "v8leise": dict(zuend=4, cyl=8, versatz=[0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875], res=[(80, 1.0), (200, 0.6), (520, 0.2)], dauer=0.009, rau=0.06, tief=0.9, zisch=0.04, lpf=900, leer=650, hoch=6000),
    # großer V8 (Muscle-Car): sehr tief, unruhiger Leerlauf, laut
    "v8gross": dict(zuend=4, cyl=8, versatz=[0.0, 0.07, 0.25, 0.43, 0.5, 0.57, 0.75, 0.93], res=[(70, 1.0), (180, 0.9), (560, 0.4), (1500, 0.2)], dauer=0.011, rau=0.3, tief=1.0, zisch=0.15, lpf=1600, leer=750, hoch=6500),
    # V6-Diesel (Geländewagen)
    "v6diesel": dict(zuend=3, cyl=6, versatz=[0, 1/6, 2/6, 3/6, 4/6, 5/6], res=[(120, 1.0), (400, 0.5), (2800, 0.2)], dauer=0.006, rau=0.18, tief=0.7, zisch=0.08, lpf=2000, leer=700, hoch=4500),
    "diesel": dict(zuend=3, cyl=6, versatz=[0, 1/6, 2/6, 3/6, 4/6, 5/6], res=[(110, 1.0), (380, 0.6), (3200, 0.25)], dauer=0.006, rau=0.25, tief=0.7, zisch=0.1, lpf=2400, leer=650, hoch=2600),
}

# Motor v2: Verbrennungsstöße -> Auspuffrohr (Kammfilter mit Rohrlänge) -> Schalldämpfer,
# dazu Ansaugrauschen im Takt der Zündungen und Mechanik (Zweitakt-Klingeln, Diesel-Nageln).
ROHR = {"trabant": (1.6, 0.55, 2200, 0.004, "klingel"), "wartburg": (1.9, 0.6, 1800, 0.005, "klingel"),
        "vier": (2.6, 0.5, 1100, 0.006, ""), "turbo6": (2.8, 0.5, 1700, 0.005, "turbo"), "reihe6": (2.6, 0.55, 1400, 0.006, ""),
        "kompakt4": (2.2, 0.62, 1500, 0.005, "blubber"), "v8leise": (3.2, 0.4, 700, 0.009, ""), "v8gross": (2.0, 0.75, 1300, 0.01, "blubber"), "v6diesel": (3.0, 0.55, 1300, 0.005, "nageln"), "v8": (2.2, 0.72, 1500, 0.008, "blubber"), "diesel": (3.0, 0.55, 1300, 0.005, "nageln")}
def motor_schleife(k, rpm, last=1.0, zyklen=None):
    c = KLASSEN[k]; L, g, lpf, puls, art = ROHR[k]
    zweitakt = k in ("trabant", "wartburg")
    umdr = rpm / 60.0
    spiel = (1.0 if zweitakt else 2.0) / umdr
    if zyklen is None: zyklen = max(10, int(round(1.8 / spiel)))
    n = int(round(spiel * zyklen * SR)); x = np.zeros(n); env = np.zeros(n)
    pw = int(puls * SR); tp = np.arange(pw) / pw
    form = (tp ** 0.6) * np.exp(-tp * 5.0)          # schneller Anstieg, langes Abklingen
    form /= form.max()
    for z in range(zyklen):
        for ci, v in enumerate(c["versatz"]):
            t = (z + v + rng.normal(0, 0.004)) * spiel
            i = int(t * SR) % n
            amp = (1.0 + rng.normal(0, 0.07 + 0.08 * c["rau"])) * (0.6 + 0.4 * last) * (1.0 + 0.1 * np.sin(ci * 2.3))
            idx = (i + np.arange(pw)) % n
            x[idx] += amp * form; env[idx] += amp * form
    # Rohr: Kammfilter (Resonanzen bei c/2L) über FFT, nahtlos
    f = np.fft.rfftfreq(n, 1 / SR); X = np.fft.rfft(x)
    D = 2 * L / 343.0
    H = 1.0 / (1.0 - g * np.exp(-2j * np.pi * f * D))
    H2 = 1.0 / (1.0 - g * 0.8 * np.exp(-2j * np.pi * f * D * 0.63))
    y = np.fft.irfft(X * (H + 0.6 * H2), n)
    # Schalldämpfer: weicher Tiefpass + Karosserie-Dröhnen (Resonanz 70–130 Hz)
    y = np.concatenate([y, y]); y = lp(y, lpf, 2)[n:]
    dr = np.concatenate([y, y]); dr = bp(dr, 60, 140, 2)[n:]; y = y + dr * (0.8 if k in ("v8", "diesel") else 0.4)
    # Ansaugen: Rauschen im Takt der Zündungen
    no = per_rausch(n, 500, 3000)
    envs = np.convolve(np.concatenate([env, env]), np.ones(int(0.004 * SR)) / int(0.004 * SR), mode="same")[n:]
    y = y / (np.max(np.abs(y)) or 1) + no * envs / (envs.max() or 1) * (0.04 + 0.06 * last)
    # Mechanik je Motorart
    if art == "klingel":   # Zweitakt: metallisches "Ring-ding" nach jedem Stoß
        L2 = int(0.03 * SR); t2 = np.arange(L2) / SR; ir = np.sin(2 * np.pi * 1650 * t2) * np.exp(-t2 / 0.006) + 0.6 * np.sin(2 * np.pi * 2700 * t2) * np.exp(-t2 / 0.004)
        y += circ_conv(x, ir) / (np.max(np.abs(circ_conv(x, ir))) or 1) * 0.22
    if art == "nageln":    # Diesel: harter Klick
        L2 = int(0.01 * SR); ir = rng.normal(0, 1, L2) * np.exp(-np.arange(L2) / SR / 0.0012); ir = hp(ir, 2500)
        y += circ_conv(x, ir) / (np.max(np.abs(circ_conv(x, ir))) or 1) * 0.14
    if art == "turbo":     # Turbolader: leises Pfeifen, steigt mit der Drehzahl
        tt = np.arange(n) / SR; fpf = 2200 + rpm * 0.45; fpf = round(fpf * n / SR) / (n / SR)
        y = y / (np.max(np.abs(y)) or 1) + np.sin(2 * np.pi * fpf * tt) * 0.03 * (rpm / 6000.0)
    if art == "blubber":   # V8: leichtes Sägen bei hoher Drehzahl
        y = np.tanh(y * (1.1 + rpm / 8000.0))
    y = np.tanh(y * 1.1)
    return norm(y, 0.8)

def demo_hochdrehen(k, sek=7.0):
    # Hörprobe: Leerlauf -> Vollgas mit Gangwechseln -> Gas weg, aus den Schleifen per Tonhöhenänderung (wie im Spiel)
    c = KLASSEN[k]
    lo = motor_schleife(k, c["leer"]); hi = motor_schleife(k, c["hoch"] * 0.65)
    n = int(sek * SR); out = np.zeros(n); pl = 0.0; ph = 0.0
    t = np.arange(n) / SR
    rpm = np.zeros(n)
    gaenge = 4 if k != "v8" else 5
    for i in range(n):
        s = t[i] / sek
        if s < 0.12: r = c["leer"]
        elif s < 0.85:
            g = (s - 0.12) / 0.73 * gaenge; gi = int(g); f = g - gi
            r = c["leer"] * 1.6 + (c["hoch"] - c["leer"] * 1.6) * (0.35 + 0.65 * f) * (0.75 + 0.25 * gi / gaenge)
        else: r = c["leer"] + (c["hoch"] * 0.4 - c["leer"]) * (1 - (s - 0.85) / 0.15)
        rpm[i] = r
    rpm = np.convolve(rpm, np.ones(800) / 800, mode="same")
    for i in range(n):
        r = rpm[i]
        pl += r / c["leer"]; ph += r / (c["hoch"] * 0.65)
        a = lo[int(pl) % len(lo)]; b = hi[int(ph) % len(hi)]
        m = np.clip((r - c["leer"]) / (c["hoch"] * 0.65 - c["leer"]), 0, 1)
        out[i] = a * (1 - m) + b * m
    return norm(out, 0.85)

# ---------------- Schüsse ----------------
def schuss(art):
    d = {"pistole": (0.55, 2200, 160, 0.06, 0.35), "mp": (0.3, 3000, 190, 0.035, 0.25), "schrot": (0.9, 1500, 90, 0.11, 0.6),
         "gewehr": (0.75, 2600, 130, 0.07, 0.5), "sniper": (1.4, 3400, 110, 0.09, 1.2)}[art]
    dauer, hell, tief, kd, hall = d
    n = int(dauer * SR); t = np.arange(n) / SR
    knall = hp(rng.normal(0, 1, n), hell) * np.exp(-t / 0.004) * 1.4
    koerper = lp(rng.normal(0, 1, n), hell * 0.6) * np.exp(-t / kd)
    wumms = np.sin(2 * np.pi * tief * t * (1 - 0.35 * t / dauer)) * np.exp(-t / (kd * 1.4)) * 1.2
    nachhall = bp(rng.normal(0, 1, n), 200, 2500) * np.exp(-t / (hall * 0.35)) * 0.25
    # Echo (Häuserwand)
    e = int(0.11 * SR); echo = np.zeros(n); echo[e:] = (koerper + wumms)[:n - e] * 0.3
    y = knall + koerper + wumms + nachhall + lp(echo, 1800)
    y[:int(0.0006 * SR)] *= np.linspace(0, 1, int(0.0006 * SR))
    return norm(y, 0.95)

def nachladen():
    n = int(0.5 * SR); y = np.zeros(n); t = np.arange(int(0.03 * SR)) / SR
    for pos, f in [(0.05, 2500), (0.32, 1800), (0.36, 3200)]:
        i = int(pos * SR); k = hp(rng.normal(0, 1, len(t)), f) * np.exp(-t / 0.004); y[i:i + len(t)] += k
    return norm(y, 0.7)

# ---------------- Umgebung: Stadt ----------------
def stadt(sek=60.0):
    n = int(sek * SR); t = np.arange(n) / SR
    braun = np.cumsum(rng.normal(0, 1, n)); braun -= np.convolve(braun, np.ones(4410) / 4410, mode="same")
    y = lp(braun, 260) * 0.015            # fernes Verkehrsrauschen
    y += bp(rng.normal(0, 1, n), 200, 1200) * 0.012 * (1 + 0.3 * np.sin(2 * np.pi * t / 13.0))
    # vorbeifahrende Autos (Anschwellen, leichtes Absinken der Tonhöhe)
    for k in range(int(sek / 4.5)):
        mitte = rng.uniform(4, sek - 4); breite = rng.uniform(1.5, 3.5); laut = rng.uniform(0.3, 1.0)
        a = int((mitte - breite) * SR); b = int((mitte + breite) * SR); m = b - a; tt = np.arange(m) / SR
        env = np.exp(-((tt - breite) / (breite * 0.4)) ** 2) * laut
        f0 = rng.uniform(70, 140); f = f0 * (1.06 - 0.12 * (tt / (2 * breite)))
        ton = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.4 + np.sin(2 * np.pi * np.cumsum(f * 2) / SR) * 0.2
        rausch = bp(rng.normal(0, 1, m), 400, 3000) * 0.6
        y[a:b] += (ton + rausch) * env * 0.05
    # gelegentlich Hupe in der Ferne, Vögel
    for k in range(3):
        i = int(rng.uniform(5, sek - 5) * SR); m = int(rng.uniform(0.25, 0.6) * SR); tt = np.arange(m) / SR
        f = rng.choice([350, 410, 470]); h = np.sign(np.sin(2 * np.pi * f * tt)) * 0.5 + np.sign(np.sin(2 * np.pi * f * 1.26 * tt)) * 0.5
        y[i:i + m] += lp(h, 1500) * np.minimum(1, np.minimum(tt, tt[::-1]) / 0.02) * 0.012
    for k in range(10):
        i = int(rng.uniform(1, sek - 2) * SR)
        for z in range(rng.integers(2, 5)):
            m = int(0.07 * SR); tt = np.arange(m) / SR; f = rng.uniform(3000, 4500) * (1 + 0.3 * tt / 0.07)
            j = i + int(z * 0.11 * SR); y[j:j + m] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.07) * 0.006
    # nahtlose Schleife: Ende in den Anfang überblenden
    x = int(2.0 * SR); w = np.linspace(0, 1, x)
    y[:x] = y[:x] * w + y[-x:] * (1 - w); y = y[:-x]
    return norm(y, 0.5)

if __name__ == "__main__":
    for k, c in KLASSEN.items():
        wav("motor_%s_leer" % k, motor_schleife(k, c["leer"]))
        wav("motor_%s_hoch" % k, motor_schleife(k, c["hoch"] * 0.65))
    probe2 = [("turbo6", "9_motor_sportcoupe_turbo6"), ("reihe6", "10_motor_sportlimousine_reihe6"), ("kompakt4", "11_motor_kompakter"), ("v8leise", "12_motor_luxuslimousine_v8"), ("v8gross", "13_motor_musclecar_v8"), ("v6diesel", "14_motor_gelaendewagen_diesel")]
    for k, nm in probe2: mp3(nm, demo_hochdrehen(k))
    probe = [("trabant", "1_motor_trabant"), ("wartburg", "2_motor_wartburg"), ("vier", "3_motor_taxi_polizei"), ("v8", "4_motor_sportwagen"), ("diesel", "5_motor_feuerwehr_rtw")]
    for k, nm in probe: mp3(nm, demo_hochdrehen(k))
    salve = {}
    for a in ["pistole", "mp", "schrot", "gewehr", "sniper"]:
        s = schuss(a); wav("schuss_" + a, s); salve[a] = s
    wav("nachladen", nachladen())
    # Hörprobe Waffen: Pistole x3, MP-Salve, Schrot x2, Gewehr-Salve, Sniper
    pause = lambda sec: np.zeros(int(sec * SR))
    def folge(s, n, abst):
        o = np.zeros(int((abst * (n - 1)) * SR) + len(s))
        for i in range(n): j = int(i * abst * SR); o[j:j + len(s)] += s
        return o
    w = np.concatenate([folge(salve["pistole"], 3, 0.45), pause(0.6), folge(salve["mp"], 10, 0.075), pause(0.8), folge(salve["schrot"], 2, 0.9), pause(0.6), folge(salve["gewehr"], 6, 0.11), pause(0.8), salve["sniper"]])
    mp3("6_waffen_pistole_mp_schrot_gewehr_sniper", norm(w, 0.95))
    # Vorbeifahrt (Doppler + Entfernung), wie man Autos im Spiel an sich vorbeifahren hört
    def vorbei(k, rpm, v=16.0, sek=5.0, abstand=4.0):
        lo = motor_schleife(k, rpm); n = int(sek * SR); out = np.zeros(n); ph = 0.0
        for i in range(n):
            t = i / SR - sek / 2; xpos = v * t; r = np.hypot(xpos, abstand); vr = v * xpos / r
            ph += 343.0 / (343.0 + vr); out[i] = lo[int(ph) % len(lo)] / (1 + r * 0.35)
        return norm(lp(out, 6000), 0.85)
    mp3("8_vorbeifahrt_trabant_taxi_sportwagen", np.concatenate([vorbei("trabant", 3200, 13), np.zeros(SR // 3), vorbei("vier", 2600, 15), np.zeros(SR // 3), vorbei("v8", 5200, 30)]))
    u = stadt(); wav("umgebung_stadt", u); mp3("7_umgebung_stadt", u[:int(30 * SR)])
    print("FERTIG")
