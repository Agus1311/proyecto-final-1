"""Genera «Turno de Oficina», la música de fondo del juego (pieza original, CC BY 4.0, Firewall Studio).

Música tranquila de oficina a 72 BPM en Fa mayor: piano eléctrico (FM), bajo suave, colchón de cuerdas
y vibráfono con la melodía, con reverberación de sala. Sin batería ni ruido: solo sonidos tonales limpios. Se renderiza con NumPy y se exporta a OGG en bucle perfecto.
Uso: python3 tools/gen_music_oficina.py  ->  assets/audio/turno_de_oficina.ogg
"""
import numpy as np, subprocess, os, wave
from scipy.signal import lfilter, butter

SR = 44100
BPM = 72
BEAT = 60 / BPM
BAR = 4 * BEAT
rng = np.random.default_rng(7)

def midi(n): return 440.0 * 2 ** ((n - 69) / 12)
NOTE = {'C': 0, 'Db': 1, 'D': 2, 'Eb': 3, 'E': 4, 'F': 5, 'Gb': 6, 'G': 7, 'Ab': 8, 'A': 9, 'Bb': 10, 'B': 11}

# Acordes: (raíz, tipo) por medio compás. Forma A A B A (32 compases), dos vueltas con variaciones.
Q = {'maj7': [0, 4, 7, 11, 14], 'm7': [0, 3, 7, 10, 14], '7': [0, 4, 7, 10, 14], 'm6': [0, 3, 7, 9, 14], '7b9': [0, 4, 7, 10, 13]}
A = [('F', 'maj7'), ('F', 'maj7'), ('E', 'm7'), ('A', '7'), ('D', 'm7'), ('D', 'm7'), ('C', 'm7'), ('F', '7'),
     ('Bb', 'maj7'), ('Bb', 'maj7'), ('Bb', 'm6'), ('Eb', '7'), ('A', 'm7'), ('D', '7'), ('G', 'm7'), ('C', '7')]
B = [('Bb', 'maj7'), ('Bb', 'maj7'), ('A', 'm7'), ('D', '7'), ('G', 'm7'), ('G', 'm7'), ('C', '7'), ('C', '7b9'),
     ('A', 'm7'), ('A', 'm7'), ('D', '7'), ('D', '7'), ('G', 'm7'), ('G', 'm7'), ('C', '7'), ('C', '7')]
FORM = A + A + B + A
FORM = FORM + FORM
BARS = len(FORM) // 2
N = int(BARS * BAR * SR)
TAIL = int(4 * SR)
L = np.zeros(N + TAIL); R = np.zeros(N + TAIL)

def add(sig, t, pan=0.0, gain=1.0):
    i = int(t * SR)
    if i >= len(L): return
    sig = sig[:len(L) - i] * gain
    L[i:i + len(sig)] += sig * np.sqrt((1 - pan) / 2)
    R[i:i + len(sig)] += sig * np.sqrt((1 + pan) / 2)

def env(n, a, d, s, r_frac=0.15):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4)) * (s + (1 - s) * np.exp(-t / d))
    k = int(n * r_frac); e[-k:] *= np.linspace(1, 0, k) if k else 1
    return e

def rhodes(f, dur, vel):
    n = int((dur + .6) * SR); t = np.arange(n) / SR
    idx = 2.2 * vel * np.exp(-t * 3.5) + .25
    mod = np.sin(2 * np.pi * f * t) * idx
    tone = np.sin(2 * np.pi * f * t + mod) + .18 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 6)
    bell = .05 * np.sin(2 * np.pi * 14 * f * t) * np.exp(-t * 22)   # golpe del martillo
    e = env(n, .004, .9, .25); e[int(dur * SR):] *= np.exp(-np.arange(n - int(dur * SR)) / SR / .15)
    return (tone + bell) * e * vel

def vibes(f, dur, vel):
    n = int((dur + 1.2) * SR); t = np.arange(n) / SR
    trem = 1 + .25 * np.sin(2 * np.pi * 5.2 * t)
    tone = np.sin(2 * np.pi * f * t) + .25 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t * 5)
    return tone * env(n, .003, 1.1, 0.0, .3) * trem * vel

def bass(f, dur, vel):
    n = int((dur + .1) * SR); t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * f * t) + .35 * np.sin(2 * np.pi * 2 * f * t) + .12 * np.sin(2 * np.pi * 3 * f * t)
    pluck = np.exp(-t * 2.2) * .7 + .3
    e = env(n, .006, .5, .5, .25)
    return np.tanh(tone * 1.2) * e * pluck * vel

def chord_tones(root, q, low=52):
    r = NOTE[root]
    base = low + ((r - low) % 12)
    iv = Q[q]
    # voicing sin raíz: 3, 7, 9 y 5 cerca del Do central
    pcs = [iv[1], iv[3], iv[4], iv[2]]
    notes = sorted(base + p for p in pcs)
    while notes[0] < 52: notes = [x + 12 for x in notes]
    while notes[-1] > 74: notes = [x - 12 for x in notes]
    return notes

swing = lambda beat8: beat8 * BEAT / 2 + (BEAT * .16 if beat8 % 2 else 0)   # corcheas con swing suave

# --------- Acompañamiento ----------
for h, (root, q) in enumerate(FORM):
    bar, half = divmod(h, 2)
    t0 = bar * BAR + half * 2 * BEAT
    notes = chord_tones(root, q)
    # piano eléctrico: «charleston» (1 y el «y» de 2) con dinámica humana
    for k, (pos, dur) in enumerate([(0, BEAT * 1.3), (BEAT * 1.5 + BEAT * .08, BEAT * .45)]):
        vel = .13 if k == 0 else .09
        vel *= .9 + .2 * rng.random()
        for j, n in enumerate(notes):
            add(rhodes(midi(n), dur, vel), t0 + pos + j * .006, pan=-.25 + .15 * j)
    # bajo: raíz y quinta, con nota de aproximación al siguiente acorde
    r = NOTE[root]; lo = 33 + ((r - 33) % 12)
    nxt = FORM[(h + 1) % len(FORM)][0]; nl = 33 + ((NOTE[nxt] - 33) % 12)
    approach = nl - 1 if rng.random() < .6 else nl + 2
    for pos, n in [(0, lo), (BEAT, lo + 7 if q != 'm6' else lo + 7), (BEAT * 1.5 + BEAT * .16, approach)][: 3 if half else 2] + ([] if half else [(BEAT * 1.5 + BEAT * .16, lo + 12)]):
        add(bass(midi(n), BEAT * .9, .24), t0 + pos, pan=0)

# --------- Colchón de cuerdas (pad) ----------
def pad(f, dur, vel):
    n = int((dur + 1.5) * SR); t = np.arange(n) / SR
    tone = sum(np.sin(2 * np.pi * f * d * t + ph) for d, ph in [(1, 0), (1.003, 1.3), (.997, 2.1)]) / 3
    tone += .2 * np.sin(2 * np.pi * 2 * f * t)
    a = np.minimum(1, t / .9); r = np.ones(n); k = int(dur * SR); r[k:] = np.exp(-np.arange(n - k) / SR / .5)
    return tone * a * r * vel

for bar in range(BARS):
    root, q = FORM[bar * 2]
    for j, n in enumerate(chord_tones(root, q)[:3]):
        add(pad(midi(n - 12 if n > 64 else n), BAR, .05), bar * BAR, pan=(-.5, 0, .5)[j])

# --------- Melodía (vibráfono) ----------
# motivos en Fa pentatónica; (compás relativo, corchea, nota MIDI, duración en corcheas)
MOT_A = [(0, 2, 72, 2), (0, 4, 74, 2), (0, 6, 77, 4), (1, 4, 76, 2), (1, 6, 74, 2),
         (2, 0, 72, 3), (2, 4, 69, 2), (2, 6, 72, 2), (3, 0, 70, 6),
         (4, 2, 74, 2), (4, 4, 77, 2), (4, 6, 79, 4), (5, 4, 77, 2), (5, 6, 74, 2),
         (6, 0, 72, 2), (6, 2, 74, 2), (6, 4, 69, 4), (7, 0, 72, 7)]
MOT_B = [(0, 0, 74, 4), (0, 4, 72, 2), (0, 6, 70, 2), (1, 0, 69, 6),
         (2, 2, 67, 2), (2, 4, 70, 2), (2, 6, 74, 4), (3, 4, 72, 4),
         (4, 0, 72, 4), (4, 4, 70, 2), (4, 6, 69, 2), (5, 0, 67, 6),
         (6, 2, 69, 2), (6, 4, 70, 2), (6, 6, 72, 2), (7, 0, 76, 6)]
sections = ['A', 'A', 'B', 'A', 'A', 'A', 'B', 'A']
for s_i, sec in enumerate(sections):
    if s_i == 0: continue                       # la primera vuelta entra solo el grupo
    base_bar = s_i * 8
    mot = MOT_B if sec == 'B' else MOT_A
    for (b, e8, n, d8) in mot:
        if s_i == 1 and b >= 4 and rng.random() < .3: continue
        t = (base_bar + b) * BAR + swing(e8)
        add(vibes(midi(n), d8 * BEAT / 2, .10), t, pan=.3)

# --------- Mezcla: reverberación de sala, bucle perfecto y limitador ----------
def reverb(x):
    out = np.zeros_like(x)
    for d, g in [(1557, .80), (1617, .79), (1491, .81), (1422, .80)]:
        out += lfilter([1], np.r_[1, np.zeros(d - 1), -g], x)
    for d in (225, 556):
        out = lfilter(np.r_[-.5, np.zeros(d - 1), 1], np.r_[1, np.zeros(d - 1), -.5], out)
    return out * .06

lp = butter(2, 6500 / (SR / 2), 'low')
L2 = lfilter(*lp, L); R2 = lfilter(*lp, R)
L2 = L2 + reverb(L2); R2 = R2 + reverb(np.roll(R2, 300))
# la cola del final se suma al principio: el bucle no tiene corte
L3 = L2[:N].copy(); R3 = R2[:N].copy()
L3[:TAIL] += L2[N:]; R3[:TAIL] += R2[N:]
st = np.stack([L3, R3], 1)
st /= np.max(np.abs(st)) / .85
st = np.tanh(st * 1.1) / np.tanh(1.1)

os.makedirs('assets/audio', exist_ok=True)
wav = '/tmp/turno_de_oficina.wav'
with wave.open(wav, 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((st * 32767).astype('<i2').tobytes())
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4', 'assets/audio/turno_de_oficina.ogg'], check=True)
print('ok', round(N / SR, 1), 's', os.path.getsize('assets/audio/turno_de_oficina.ogg') // 1024, 'KB')
