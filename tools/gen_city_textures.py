"""Texturas PBR de la Fase 4 (ciudad de Panamá, vías y vehículos).
Uso: python3 gen_city_textures.py <carpeta_salida>
Genera mapas tileables (albedo / normal / roughness) y texturas con alfa
para palmeras, rótulos, placas y calcomanías viales (marcas de la ATTT).
"""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
FONT_B = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT_C = '/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'
for f in [FONT_B, FONT_C]:
    assert os.path.exists(f), f


def font(sz, cond=False):
    return ImageFont.truetype(FONT_C if cond else FONT_B, sz)


def fnoise(n, beta=2.0, seed=0, aniso=(1.0, 1.0)):
    r = np.random.default_rng(seed)
    w = r.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None] * aniso[0]
    fx = np.fft.fftfreq(n)[None, :] * aniso[1]
    f = np.sqrt(fx * fx + fy * fy); f[0, 0] = 1
    s = np.fft.fft2(w) / f ** (beta / 2); s[0, 0] = 0
    o = np.real(np.fft.ifft2(s)); o -= o.min(); o /= o.max()
    return o


def normal_from_height(h, strength=4.0):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    l = np.sqrt(gx * gx + gy * gy + 1)
    return np.stack([(-gx / l + 1) / 2, (gy / l + 1) / 2, (1 / l + 1) / 2], -1)


def save(name, arr):
    a = (np.clip(arr, 0, 1) * 255 + .5).astype(np.uint8)
    Image.fromarray(a).save(os.path.join(OUT, name + '.png'), optimize=True)
    print('ok', name)


def save_set(name, alb, h, rough, ns=4.0):
    save(name + '_albedo', alb)
    save(name + '_normal', normal_from_height(h, ns))
    save(name + '_rough', rough)


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def tint(g, rgb):
    return g[..., None] * (np.array(rgb, float) / 255)[None, None, :]


def stones(n, count, rmin, rmax, seed):
    """Áridos: discos aleatorios tileables -> (altura, id de color)."""
    r = np.random.default_rng(seed)
    h = np.zeros((n, n)); col = np.zeros((n, n))
    yy, xx = np.mgrid[0:n, 0:n]
    for _ in range(count):
        cx, cy = r.uniform(0, n, 2)
        rad = r.uniform(rmin, rmax)
        c = r.uniform(0, 1)
        x0, x1 = int(cx - rad - 1), int(cx + rad + 2)
        y0, y1 = int(cy - rad - 1), int(cy + rad + 2)
        ys = np.arange(y0, y1) % n; xs = np.arange(x0, x1) % n
        dy = (np.arange(y0, y1) - cy)[:, None]; dx = (np.arange(x0, x1) - cx)[None, :]
        e = 1 - (dx * dx + dy * dy * r.uniform(.6, 1.6)) / (rad * rad)
        m = np.clip(e, 0, 1) ** .5
        sub = h[np.ix_(ys, xs)]
        upd = m > sub
        sub[upd] = m[upd]; h[np.ix_(ys, xs)] = sub
        cs = col[np.ix_(ys, xs)]; cs[upd] = c; col[np.ix_(ys, xs)] = cs
    return h, col


N = 1024

# ---------- asfalto (mezcla densa con árido gris claro, típico de las vías de Panamá) ----------
h1, c1 = stones(N, 14000, .8, 2.6, 11)
fine = fnoise(N, 1.0, 12)
big = fnoise(N, 3.2, 13)
mid = fnoise(N, 2.2, 14)
base = .16 + .04 * big + .025 * mid
agg = np.where(h1 > .05, .15 + .09 * c1, base)
agg = agg * (.92 + .14 * fine)
# parches de reparación y manchas de aceite
patch = sstep(.72, .76, fnoise(N, 3.6, 15))
oil = sstep(.8, .86, fnoise(N, 2.8, 16)) * .5
val = agg * (1 - .18 * patch) * (1 - .35 * oil)
alb = np.stack([val * 1.0, val * 1.0, val * 1.04], -1)
height = h1 * .6 + fine * .25 + (1 - patch) * .05
rough = np.clip(.88 - .12 * (h1 > .05) * c1 - .35 * oil + .06 * fine, .35, .98)
save_set('asphalt', alb, height, rough, 6.0)

# ---------- asfalto rojo de la ciclovía ----------
v2 = (.42 + .2 * c1 * (h1 > .05) + .08 * fine) * (.92 + .1 * big)
save_set('bikelane', np.stack([v2 * 1.05, v2 * .42, v2 * .32], -1), height, np.clip(rough + .02, 0, 1), 5.0)

# ---------- adoquines de concreto (aceras) ----------
yy, xx = np.mgrid[0:N, 0:N] / N
# losetas 4x8 en espiga simple (rectángulos 0.2 x 0.1 m dentro de 1 m)
bx = (xx * 5) % 1; by = (yy * 10) % 1
row = np.floor(yy * 10)
bx = (xx * 5 + .5 * (row % 2)) % 1
joint = np.minimum(np.minimum(bx, 1 - bx) * 5 * 2, np.minimum(by, 1 - by) * 10 * 2)
jm = sstep(0, .06, joint)
tile_id = np.floor(xx * 5 + .5 * (row % 2)) + 37 * row
r = np.random.default_rng(3)
lut = r.uniform(.88, 1.08, 400)
tv = lut[(tile_id.astype(int)) % 400]
fn2 = fnoise(N, 1.4, 21)
sv = (.66 * tv + .06 * fn2) * (.55 + .45 * jm) * (.93 + .1 * fnoise(N, 3, 22))
save_set('pavers', np.stack([sv * 1.02, sv * .98, sv * .9], -1), jm * .7 + fn2 * .2, np.clip(.8 + .15 * (1 - jm) - .05 * fn2, 0, 1), 5.0)

# ---------- concreto de bordillos / malecón ----------
cn = fnoise(N, 1.6, 31); cb = fnoise(N, 3, 32)
pores = (fnoise(N, .6, 33) > .86) * .25
cv = (.6 + .12 * cn + .08 * cb - pores * .5)
save_set('curb', np.stack([cv, cv * .98, cv * .94], -1), cn * .5 - pores, np.clip(.86 + .1 * cn, 0, 1), 3.0)

# ---------- losas de piedra del paseo marítimo ----------
gx = (xx * 2) % 1; gy = (yy * 2) % 1
jj = sstep(0, .02, np.minimum(np.minimum(gx, 1 - gx), np.minimum(gy, 1 - gy)))
sid = (np.floor(xx * 2) + 3 * np.floor(yy * 2)).astype(int)
lut2 = r.uniform(.85, 1.1, 16)
st_v = (.74 * lut2[sid % 16] + .08 * fnoise(N, 1.2, 41)) * (.6 + .4 * jj)
save_set('promenade', np.stack([st_v * 1.03, st_v, st_v * .9], -1), jj * .6 + fnoise(N, 1.2, 41) * .2, np.clip(.75 + .15 * (1 - jj), 0, 1), 4.0)

# ---------- césped tropical ----------
gr = fnoise(N, 1.0, 51); gb = fnoise(N, 2.8, 52)
blades = np.zeros((N, N))
rr = np.random.default_rng(53)
img = Image.new('L', (N, N), 0); d = ImageDraw.Draw(img)
for _ in range(26000):
    x, y = rr.uniform(0, N, 2); a = rr.uniform(-.5, .5) - math.pi / 2; L = rr.uniform(6, 16)
    d.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=int(rr.uniform(90, 255)), width=1)
blades = np.asarray(img, float) / 255
gv = .45 * gb + .35 * blades + .2 * gr
dry = sstep(.7, .9, fnoise(N, 3.4, 54)) * .5
galb = np.stack([.16 + .22 * gv + .2 * dry, .32 + .36 * gv + .08 * dry, .1 + .12 * gv], -1)
save_set('grass', galb, blades * .6 + gr * .4, np.clip(.9 - .1 * blades, 0, 1), 3.0)

# ---------- normal del mar (oleaje tileable de varias escalas) ----------
w = np.zeros((N, N))
for i, (k, a) in enumerate([(3, 1.0), (5, .6), (9, .35), (17, .18), (29, .1)]):
    ph = np.random.default_rng(60 + i).uniform(0, 6.28, 6)
    for j in range(6):
        ang = ph[j]
        kx, ky = round(math.cos(ang) * k), round(math.sin(ang) * k)
        w += a * np.sin(2 * math.pi * (kx * xx + ky * yy) + ph[(j + 1) % 6]) / 6
w += fnoise(N, 2.4, 66) * .6
w = (w - w.min()) / (w.max() - w.min())
save('sea_normal', normal_from_height(w, 10.0))

# ---------- corteza de palma (anillos) ----------
yy2, xx2 = np.mgrid[0:512, 0:512] / 512
rings = (np.sin(yy2 * 2 * math.pi * 14 + fnoise(512, 2.4, 71) * 3) * .5 + .5) ** 3
fibers = fnoise(512, .8, 72, (1, 8))
bark = .35 + .25 * fibers - .18 * rings
Nb = 512
img = Image.fromarray((np.clip(np.stack([bark * 1.0, bark * .86, bark * .7], -1), 0, 1) * 255).astype(np.uint8))
img.save(os.path.join(OUT, 'palm_bark_albedo.png')); print('ok palm_bark_albedo')
save('palm_bark_normal', normal_from_height(fibers * .4 - rings * .8, 5))

# ---------- hoja de palma (frondas con folíolos, con alfa) ----------
W, H = 256, 1024
im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
rr = np.random.default_rng(80)
for i in range(80):
    t = i / 80
    y = 20 + t * (H - 60)
    L = (W / 2 - 4) * math.sin(math.pi * min(1, .15 + t * .95)) ** .7
    for s in (-1, 1):
        ang = s * (.9 + rr.uniform(-.08, .08))
        x2 = W / 2 + s * L; y2 = y + L * .55 + rr.uniform(-4, 4)
        g = int(rr.uniform(95, 140)); col = (int(g * .42), g, int(g * .3), 255)
        d.polygon([(W / 2, y - 2), (x2, y2 - 3), (x2 + s * 2, y2 + 1), (W / 2, y + 5)], fill=col)
        d.line([(W / 2, y), (x2, y2)], fill=(int(g * .6), int(g * 1.1), int(g * .4), 255), width=1)
d.line([(W / 2, 0), (W / 2, H)], fill=(120, 140, 70, 255), width=5)
im = im.filter(ImageFilter.GaussianBlur(.6))
im.save(os.path.join(OUT, 'palm_frond.png')); print('ok palm_frond')

# ---------- follaje de árbol (guayacán verde con flores amarillas) ----------
for nm, fl in [('leaves_green', 0.0), ('leaves_guayacan', .75)]:
    im = Image.new('RGBA', (512, 512), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    rr = np.random.default_rng(90 if fl == 0 else 91)
    for _ in range(1500):
        x, y = rr.uniform(0, 512, 2); s = rr.uniform(5, 13); a = rr.uniform(0, 6.28)
        if rr.uniform() < fl:
            c = (int(rr.uniform(220, 255)), int(rr.uniform(170, 210)), int(rr.uniform(10, 40)), 255)
        else:
            g = int(rr.uniform(70, 130)); c = (int(g * .45), g, int(g * .3), 255)
        pts = [(x + math.cos(a + k * 2.1) * s * (1 if k % 2 == 0 else .45), y + math.sin(a + k * 2.1) * s * (1 if k % 2 == 0 else .45)) for k in range(3)]
        d.polygon(pts, fill=c)
    # contorno de copa
    mask = Image.new('L', (512, 512), 0); md = ImageDraw.Draw(mask)
    for _ in range(40):
        x, y = rr.normal(256, 90, 2); rad = rr.uniform(50, 110)
        md.ellipse([x - rad, y - rad, x + rad, y + rad], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(3))
    a = np.minimum(np.asarray(im)[..., 3], np.asarray(mask))
    arr = np.asarray(im).copy(); arr[..., 3] = (a > 128) * 255
    Image.fromarray(arr).save(os.path.join(OUT, nm + '.png')); print('ok', nm)

# ---------- neumático, rin y fibra de carbono ----------
n = 512
yy3, xx3 = np.mgrid[0:n, 0:n] / n
tread = ((np.sin(xx3 * 2 * math.pi * 24 + np.abs(yy3 - .5) * 30) > .3) * (np.abs(yy3 - .5) < .42)).astype(float)
groove = (np.abs(((yy3 * 4) % 1) - .5) < .04).astype(float)
th = .5 + .4 * tread - .5 * groove + .05 * fnoise(n, 1, 101)
tv_ = .07 + .03 * fnoise(n, 1, 102)
save_set('tire', np.stack([tv_, tv_, tv_ * 1.05], -1), th, np.clip(.82 + .1 * fnoise(n, 1, 103), 0, 1), 6)
brushed = fnoise(n, 1.0, 110, (1, 30))
save_set('alu', np.stack([.72 + .1 * brushed] * 3, -1), brushed * .3, np.clip(.25 + .2 * brushed, 0, 1), 1.5)
cw = (((np.floor(xx3 * 32) + np.floor(yy3 * 32)) % 2) * 2 - 1)
wv = np.where(cw > 0, (np.sin(xx3 * 32 * math.pi * 2) * .5 + .5), (np.sin(yy3 * 32 * math.pi * 2) * .5 + .5))
cbv = .06 + .07 * wv
save_set('carbon', np.stack([cbv, cbv, cbv * 1.1], -1), wv * .5, np.clip(.28 + .12 * wv, 0, 1), 2.5)
flake = fnoise(n, .2, 120)
save('flake_normal', normal_from_height(flake, 2.0))
lea = fnoise(n, 1.2, 130); grain = fnoise(n, .5, 131)
save_set('leather', np.stack([.08 + .04 * lea] * 3, -1), grain * .5 + lea * .2, np.clip(.55 + .2 * grain, 0, 1), 3)


# ================= texturas con texto y señales (RGBA) =================
def rgba(w, h, bg=(0, 0, 0, 0)):
    im = Image.new('RGBA', (w, h), bg)
    return im, ImageDraw.Draw(im)


def ctext(d, cx, cy, txt, f, fill, stroke=0, sfill=None):
    bb = d.textbbox((0, 0), txt, font=f, stroke_width=stroke)
    d.text((cx - (bb[2] - bb[0]) / 2 - bb[0], cy - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f, fill=fill, stroke_width=stroke, stroke_fill=sfill)


def worn(im, amt=.25, seed=0):
    a = np.asarray(im).astype(float)
    nz = fnoise(max(im.size[0], im.size[1]) if im.size[0] == im.size[1] else 1024, 1.0, seed)
    nz = np.asarray(Image.fromarray((nz * 255).astype(np.uint8)).resize(im.size)) / 255.0
    a[..., 3] *= np.clip(1 - amt * sstep(.55, .9, nz), 0, 1)
    return Image.fromarray(a.astype(np.uint8))


def sv(im, name):
    im.save(os.path.join(OUT, name + '.png')); print('ok', name)


# Rótulo pintado "SOLO BUS" (carril exclusivo, letras alargadas para leerse en perspectiva)
im, d = rgba(512, 1024)
f = font(250, True)
for i, wd in enumerate(['SOLO', 'BUS']):
    tmp, td = rgba(1100, 330); ctext(td, 550, 165, wd, f, (245, 245, 240, 255))
    tmp = tmp.resize((470, 470))
    im.alpha_composite(tmp, (21, 30 + i * 500))
sv(worn(im, .45, 201), 'decal_solo_bus')

# Flechas de carril
for nm, kind in [('decal_arrow', 0), ('decal_arrow_right', 1)]:
    im, d = rgba(256, 1024)
    d.rectangle([108, 330, 148, 1000], fill=(245, 245, 240, 255))
    d.polygon([(40, 360), (128, 30), (216, 360)], fill=(245, 245, 240, 255))
    if kind:
        d.rectangle([148, 560, 236, 600], fill=(245, 245, 240, 255))
        d.polygon([(200, 500), (250, 580), (200, 660)], fill=(245, 245, 240, 255))
    sv(worn(im, .4, 210 + kind), nm)

# Palabra PARE pintada en la vía
im, d = rgba(1024, 512)
tmp, td = rgba(1024, 300); ctext(td, 512, 150, 'PARE', font(250, True), (245, 245, 240, 255))
im.alpha_composite(tmp.resize((1000, 480)), (12, 16))
sv(worn(im, .4, 220), 'decal_pare')

# Manchas de aceite / grietas
for k in range(3):
    im, d = rgba(512, 512)
    rr = np.random.default_rng(230 + k)
    m = fnoise(512, 2.6, 230 + k)
    yy4, xx4 = np.mgrid[0:512, 0:512]
    rad = np.sqrt((xx4 - 256) ** 2 + (yy4 - 256) ** 2) / 256
    a = np.clip((m - .35) * 2.2 - rad * 1.1, 0, 1) * .75
    arr = np.zeros((512, 512, 4)); arr[..., :3] = .03; arr[..., 3] = a
    sv(Image.fromarray((arr * 255).astype(np.uint8)), 'decal_oil%d' % k)
im, d = rgba(512, 512)
rr = np.random.default_rng(240)
for _ in range(7):
    x, y = 256, 256; a = rr.uniform(0, 6.28)
    for s in range(30):
        a += rr.uniform(-.5, .5); nx_, ny_ = x + math.cos(a) * 9, y + math.sin(a) * 9
        d.line([(x, y), (nx_, ny_)], fill=(10, 10, 10, 210), width=max(1, 4 - s // 8)); x, y = nx_, ny_
sv(im.filter(ImageFilter.GaussianBlur(.7)), 'decal_crack')

# Tapa de alcantarilla
im, d = rgba(256, 256)
d.ellipse([8, 8, 248, 248], fill=(48, 48, 50, 255), outline=(30, 30, 30, 255), width=6)
for i in range(-5, 6):
    d.line([(128 + i * 20, 30), (128 + i * 20, 226)], fill=(70, 70, 72, 255), width=6)
ctext(d, 128, 128, 'IDAAN', font(30), (90, 90, 92, 255))
sv(im, 'decal_manhole')

# Señal PARE (octógono rojo, borde blanco)
im, d = rgba(512, 512)
pts = [(256 + 250 * math.cos(math.pi / 8 + k * math.pi / 4), 256 + 250 * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)]
d.polygon(pts, fill=(255, 255, 255, 255))
pts2 = [(256 + 226 * math.cos(math.pi / 8 + k * math.pi / 4), 256 + 226 * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)]
d.polygon(pts2, fill=(196, 22, 28, 255))
ctext(d, 256, 262, 'PARE', font(140), (255, 255, 255, 255))
sv(im, 'sign_pare')

# Señal de velocidad máxima
im, d = rgba(400, 520, (255, 255, 255, 255))
d.rectangle([6, 6, 393, 513], outline=(20, 20, 20, 255), width=10)
ctext(d, 200, 95, 'VELOCIDAD', font(54, True), (20, 20, 20, 255))
ctext(d, 200, 160, 'MÁXIMA', font(54, True), (20, 20, 20, 255))
ctext(d, 200, 320, '50', font(190), (20, 20, 20, 255))
ctext(d, 200, 455, 'km/h', font(60), (20, 20, 20, 255))
sv(im, 'sign_speed')

# Señal informativa verde (elevada) con destinos reales de la vía
def guide(name, rows):
    im, d = rgba(1600, 560, (0, 104, 62, 255))
    d.rounded_rectangle([10, 10, 1589, 549], 30, outline=(255, 255, 255, 255), width=10)
    y = 120
    for arrow, txt in rows:
        if arrow == 'L':
            d.polygon([(70, y), (170, y - 60), (170, y - 25), (270, y - 25), (270, y + 25), (170, y + 25), (170, y + 60)], fill=(255, 255, 255, 255))
            d.text((310, y - 62), txt, font=font(108, True), fill=(255, 255, 255, 255))
        elif arrow == 'R':
            d.polygon([(1530, y), (1430, y - 60), (1430, y - 25), (1330, y - 25), (1330, y + 25), (1430, y + 25), (1430, y + 60)], fill=(255, 255, 255, 255))
            bb = d.textbbox((0, 0), txt, font=font(108, True))
            d.text((1290 - bb[2], y - 62), txt, font=font(108, True), fill=(255, 255, 255, 255))
        else:
            d.polygon([(110, y - 70), (170, y + 10), (135, y + 10), (135, y + 70), (85, y + 70), (85, y + 10), (50, y + 10)], fill=(255, 255, 255, 255))
            d.text((310, y - 62), txt, font=font(108, True), fill=(255, 255, 255, 255))
        y += 170
    sv(im, name)


guide('sign_guide_e', [('U', 'Punta Paitilla'), ('U', 'Corredor Sur'), ('R', 'Vía España')])
guide('sign_guide_w', [('U', 'Casco Antiguo'), ('U', 'Cinta Costera 3'), ('L', 'Av. de los Poetas')])

# Letreros de nombre de calle (azules)
for nm, txt in [('street_balboa', 'AV. BALBOA'), ('street_boyd', 'AV. FEDERICO BOYD'), ('street_uruguay', 'CALLE URUGUAY'), ('street_29', 'CALLE 29 ESTE')]:
    im, d = rgba(1024, 200, (20, 70, 150, 255))
    d.rectangle([6, 6, 1017, 193], outline=(255, 255, 255, 255), width=8)
    ctext(d, 512, 102, txt, font(104, True), (255, 255, 255, 255))
    sv(im, nm)

# Placas (diseño 2026-2030: «PANAMÁ» en rojo y azul con dos estrellas)
rr = np.random.default_rng(300)
LET = 'ABCDEFGHJKLMNPRSTUVWXYZ'
for k in range(12):
    im, d = rgba(600, 300, (250, 250, 250, 255))
    d.rounded_rectangle([3, 3, 596, 296], 24, outline=(30, 30, 30, 255), width=6)
    f2 = font(54)
    d.text((170, 14), 'PANA', font=f2, fill=(200, 20, 40, 255)); d.text((336, 14), 'MÁ', font=f2, fill=(10, 60, 150, 255))

    def star(cx, cy, c, rr_=18):
        pts = [(cx + math.cos(-math.pi / 2 + i * math.pi / 5) * (rr_ if i % 2 == 0 else rr_ * .42), cy + math.sin(-math.pi / 2 + i * math.pi / 5) * (rr_ if i % 2 == 0 else rr_ * .42)) for i in range(10)]
        d.polygon(pts, fill=c)
    star(135, 44, (10, 60, 150, 255)); star(465, 44, (200, 20, 40, 255))
    plate = rr.choice(list(LET)) + rr.choice(list(LET)) + str(rr.integers(1000, 9999))
    ctext(d, 300, 182, plate, font(150, True), (20, 20, 25, 255))
    sv(im, 'plate%d' % k)

# Rótulo de techo de taxi
im, d = rgba(512, 128, (250, 210, 30, 255))
ctext(d, 256, 66, 'TAXI', font(96), (20, 20, 20, 255))
sv(im, 'taxi_sign')

# Librea MiBus (lateral) y frente
im, d = rgba(2048, 512, (244, 246, 248, 255))
d.rectangle([0, 0, 2048, 22], fill=(0, 84, 160, 255))
for i in range(10):
    d.rectangle([120 + i * 190, 60, 290 + i * 190, 250], fill=(28, 40, 52, 255))
d.rectangle([0, 330, 2048, 380], fill=(0, 140, 210, 255))
d.rectangle([0, 380, 2048, 420], fill=(0, 84, 160, 255))
d.text((760, 270), 'MiBus', font=font(70), fill=(0, 84, 160, 255))
d.text((1060, 285), 'Transporte Masivo de Panamá', font=font(40), fill=(60, 70, 80, 255))
d.rectangle([1700, 60, 1860, 420], fill=(40, 52, 64, 255))
sv(im, 'bus_mibus_side')
im, d = rgba(512, 512, (244, 246, 248, 255))
d.rectangle([30, 40, 482, 300], fill=(22, 32, 42, 255))
d.rectangle([60, 50, 452, 110], fill=(0, 0, 0, 255))
ctext(d, 256, 80, 'ALBROOK  ⇄  PAITILLA', font(30), (255, 176, 32, 255))
d.rectangle([0, 360, 512, 410], fill=(0, 140, 210, 255))
d.rectangle([40, 430, 120, 470], fill=(255, 248, 210, 255)); d.rectangle([392, 430, 472, 470], fill=(255, 248, 210, 255))
sv(im, 'bus_mibus_front')

# Librea de diablo rojo (arte popular panameño, llamas y franjas)
im, d = rgba(2048, 512, (200, 22, 32, 255))
rr = np.random.default_rng(400)
cols = [(242, 194, 0), (47, 111, 208), (76, 154, 58), (255, 255, 255), (255, 120, 20), (150, 40, 160)]
for i, c in enumerate(cols):
    pts = []
    for x in range(0, 2049, 32):
        pts.append((x, 120 + i * 34 + 40 * math.sin(x / 180 + i)))
    for x in range(2048, -1, -32):
        pts.append((x, 140 + i * 34 + 40 * math.sin(x / 180 + i) + 12))
    d.polygon(pts, fill=c + (255,))
for _ in range(14):
    x = rr.uniform(0, 2048); y = rr.uniform(330, 480)
    d.polygon([(x, y), (x + 40, y - 120), (x + 70, y - 30), (x + 110, y - 150), (x + 130, y)], fill=(255, 150, 20, 255))
for i in range(9):
    d.rectangle([140 + i * 200, 40, 300 + i * 200, 110], fill=(25, 25, 30, 255))
d.text((560, 380), '★ EL REY DE LA VÍA ★', font=font(72), fill=(255, 230, 40, 255), stroke_width=4, stroke_fill=(0, 0, 0, 255))
sv(im, 'bus_diablo_side')

# Rótulo de parada de bus
im, d = rgba(1024, 256, (0, 84, 160, 255))
ctext(d, 512, 90, 'PARADA', font(96), (255, 255, 255, 255))
ctext(d, 512, 190, 'Av. Balboa · Cinta Costera', font(54, True), (255, 255, 255, 255))
sv(im, 'busstop_sign')

# Bandera de Panamá
im, d = rgba(600, 400, (255, 255, 255, 255))
d.rectangle([300, 0, 600, 200], fill=(210, 16, 52, 255)); d.rectangle([0, 200, 300, 400], fill=(0, 82, 147, 255))


def star2(cx, cy, c, r_=58):
    pts = [(cx + math.cos(-math.pi / 2 + i * math.pi / 5) * (r_ if i % 2 == 0 else r_ * .4), cy + math.sin(-math.pi / 2 + i * math.pi / 5) * (r_ if i % 2 == 0 else r_ * .4)) for i in range(10)]
    d.polygon(pts, fill=c)


star2(150, 100, (0, 82, 147, 255)); star2(450, 300, (210, 16, 52, 255))
sv(im, 'flag_panama')

# Fachadas de bancos y casa
for nm, t1, t2, bg, ac in [('bank1_sign', 'BANCO DEL ISTMO', 'Banca personal y empresarial', (18, 58, 110), (208, 160, 48)),
                           ('bank2_sign', 'BANCA CANAL', 'PACÍFICO · Tu banco del Canal', (15, 90, 70), (232, 192, 80))]:
    im, d = rgba(2048, 512, bg + (255,))
    d.rectangle([14, 14, 2033, 497], outline=ac + (255,), width=14)
    d.ellipse([60, 96, 380, 416], fill=ac + (255,)); ctext(d, 220, 256, '$', font(220), bg + (255,))
    d.text((440, 120), t1, font=font(136), fill=(255, 255, 255, 255))
    d.text((446, 330), t2, font=font(80, True), fill=ac + (255,))
    sv(im, nm)
im, d = rgba(1536, 384, (16, 32, 44, 255))
d.rectangle([10, 10, 1525, 373], outline=(56, 224, 255, 255), width=12)
ctext(d, 768, 140, 'MI CASA', font(150), (255, 255, 255, 255))
ctext(d, 768, 290, 'Punto de guardado', font(90, True), (56, 224, 255, 255))
sv(im, 'home_sign')
im, d = rgba(1024, 320, (11, 42, 74, 255))
ctext(d, 340, 160, 'CAA', font(190), (255, 154, 31, 255)); ctext(d, 730, 160, 'CORP', font(190), (255, 255, 255, 255))
sv(im, 'caa_sign')

# Tablero de misiones (corcho)
im, d = rgba(1024, 768, (90, 58, 26, 255))
d.rectangle([28, 28, 996, 740], fill=(201, 167, 122, 255))
ctext(d, 512, 100, 'TABLERO DE MISIONES', font(70), (16, 32, 44, 255))
for c, x, y in [((255, 246, 176), 80, 180), ((191, 232, 255), 380, 210), ((255, 208, 224), 680, 190), ((216, 255, 208), 120, 460), ((255, 246, 176), 440, 490), ((191, 232, 255), 700, 470)]:
    d.rectangle([x, y, x + 240, y + 200], fill=c + (255,)); d.ellipse([x + 110, y + 6, x + 130, y + 26], fill=(196, 48, 42, 255))
    for i in range(4): d.rectangle([x + 24, y + 60 + i * 32, x + 200 - i * 20, y + 70 + i * 32], fill=(68, 68, 68, 255))
sv(im, 'mission_board')
print('listo')
