"""Genera texturas PBR tileables (albedo / normal / roughness) para CAA Corp.
Uso: python3 gen_textures.py <carpeta_salida>
"""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
N = 1024
rng = np.random.default_rng(7)


def fnoise(n=N, beta=2.0, seed=None, aniso=(1.0, 1.0)):
    """Ruido fractal tileable (filtro 1/f^beta en frecuencia). Devuelve [0,1]."""
    r = np.random.default_rng(seed)
    w = r.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None] * aniso[0]
    fx = np.fft.fftfreq(n)[None, :] * aniso[1]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    spec = np.fft.fft2(w) / f ** (beta / 2)
    spec[0, 0] = 0
    out = np.real(np.fft.ifft2(spec))
    out -= out.min(); out /= out.max()
    return out


def normal_from_height(h, strength=4.0):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(gx * gx + gy * gy + nz * nz)
    nx, ny, nz = -gx / l, gy / l, nz / l  # convención OpenGL (Y+), la que usa Godot
    return np.stack([(nx + 1) / 2, (ny + 1) / 2, (nz + 1) / 2], -1)


def save(name, arr, mode=None):
    a = np.clip(arr, 0, 1)
    a = (a * 255 + .5).astype(np.uint8)
    Image.fromarray(a, mode).save(os.path.join(OUT, name + '.png'), optimize=True)
    print('ok', name)


def save_set(name, albedo, height, rough, nstr=4.0):
    save(name + '_albedo', albedo)
    save(name + '_normal', normal_from_height(height, nstr))
    save(name + '_rough', rough)


def tint(gray, rgb):
    rgb = np.array(rgb, float) / 255.0
    return gray[..., None] * rgb[None, None, :]


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


yy, xx = np.mgrid[0:N, 0:N] / N

# ---------- 1. Baldosa cerámica ajedrezada (oficina) : 2x2 baldosas por textura ----------
def tiles_checker():
    c1 = np.array([0x2f, 0x6f, 0x8f]) / 255.0
    c2 = np.array([0xf3, 0xe7, 0xcf]) / 255.0
    tx, ty = (xx * 2).astype(int), (yy * 2).astype(int)
    chk = ((tx + ty) % 2 == 0)
    fx, fy = (xx * 2) % 1, (yy * 2) % 1
    edge = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy))
    grout = 1 - smoothstep(0.006, 0.012, edge)
    bevel = smoothstep(0.006, 0.03, edge)
    n1 = fnoise(beta=2.2, seed=1); n2 = fnoise(beta=1.2, seed=2)
    base = np.where(chk[..., None], c2, c1)
    var = (0.94 + 0.08 * n1)[..., None] * (0.97 + 0.05 * n2)[..., None]
    # pequeñas variaciones por baldosa
    per = np.random.default_rng(3).uniform(.95, 1.04, (2, 2))[ty, tx][..., None]
    alb = base * var * per
    gcol = np.array([0.55, 0.53, 0.5])
    alb = alb * (1 - grout[..., None]) + gcol * grout[..., None] * (0.8 + .3 * n1[..., None])
    h = bevel * 0.9 + n2 * 0.04
    rough = 0.28 + 0.12 * n1 + grout * 0.55
    save_set('tile_checker', alb, h, rough, 6)

# ---------- 2. Parqué de madera (apartamento) ----------
def wood_planks():
    rows = 6
    py = (yy * rows)
    row = py.astype(int)
    off = np.random.default_rng(4).uniform(0, 1, rows)[row]
    px = (xx + off) % 1
    plen = 0.5
    seg = (px / plen).astype(int)
    fpx = (px / plen) % 1
    fpy = py % 1
    grain = fnoise(beta=2.0, seed=5, aniso=(1, 14))
    ring = np.sin((grain * 40 + fpy * 3) * 2.0) * .5 + .5
    pid = (row * 7 + seg * 3) % 11
    pv = np.random.default_rng(6).uniform(.82, 1.12, 11)[pid]
    g = (0.55 + 0.25 * grain + 0.12 * ring) * pv
    edge = np.minimum(np.minimum(fpy, 1 - fpy) * 0.5, np.minimum(fpx, 1 - fpx) * plen)
    gap = 1 - smoothstep(0.0015, 0.004, edge)
    g = g * (1 - .6 * gap)
    alb = tint(g, (205, 150, 98))
    h = (1 - gap) * .6 + grain * .15
    rough = 0.42 + 0.18 * (1 - ring) + gap * .3
    save_set('wood_floor', alb, h, rough, 5)

# ---------- 3. Madera para muebles (neutra, se tiñe) ----------
def wood_furniture():
    grain = fnoise(beta=2.3, seed=8, aniso=(1, 18))
    fine = fnoise(beta=1.0, seed=9, aniso=(1, 30))
    ring = np.sin(grain * 60) * .5 + .5
    g = 0.72 + 0.16 * grain + 0.08 * ring + 0.04 * fine
    alb = np.stack([g, g * .97, g * .93], -1)
    h = grain * .3 + fine * .2
    rough = 0.38 + 0.2 * (1 - ring) * .5 + 0.1 * fine
    save_set('wood', alb, h, rough, 2.5)

# ---------- 4. Moqueta / alfombra técnica (neutra) ----------
def carpet():
    n1 = fnoise(beta=0.6, seed=10); n2 = fnoise(beta=2.5, seed=11)
    loops = (np.sin(xx * N * .9) * np.sin(yy * N * .9)) * .5 + .5
    g = 0.78 + 0.1 * n1 + 0.06 * n2 + 0.04 * loops
    alb = np.stack([g, g, g], -1)
    h = n1 * .6 + loops * .3
    rough = 0.92 + 0.06 * n1
    save_set('carpet', alb, h, rough, 3)

# ---------- 5. Hormigón pulido / epoxi (pasillo y data center) ----------
def concrete():
    n1 = fnoise(beta=2.4, seed=12); n2 = fnoise(beta=1.4, seed=13); n3 = fnoise(beta=0.5, seed=14)
    spots = (n3 > .985).astype(float)
    g = 0.8 + 0.12 * n1 + 0.06 * n2 - .15 * spots
    alb = np.stack([g, g, g], -1)
    h = n2 * .3 + n1 * .2
    rough = 0.3 + 0.25 * n1 + 0.1 * n2
    save_set('concrete', alb, h, rough, 2)

# ---------- 6. Yeso pintado (paredes) ----------
def plaster():
    n1 = fnoise(beta=1.6, seed=15); n2 = fnoise(beta=2.8, seed=16)
    g = 0.93 + 0.04 * n1 + 0.03 * n2
    alb = np.stack([g, g, g], -1)
    h = n1 * .5 + n2 * .3
    rough = 0.82 + 0.1 * n1
    save_set('plaster', alb, h, rough, 1.6)

# ---------- 7. Tela tejida (sillas, sofá) ----------
def fabric():
    k = 128
    wx = np.sin(xx * N / 1024 * k * 2 * math.pi) * .5 + .5
    wy = np.sin(yy * N / 1024 * k * 2 * math.pi) * .5 + .5
    over = ((xx * k).astype(int) + (yy * k).astype(int)) % 2
    weave = np.where(over == 0, wx, wy)
    n = fnoise(beta=1.0, seed=17)
    g = 0.75 + 0.18 * weave + 0.07 * n
    alb = np.stack([g, g, g], -1)
    h = weave * .8 + n * .2
    rough = 0.88 + 0.08 * n
    save_set('fabric', alb, h, rough, 3)

# ---------- 8. Metal cepillado ----------
def metal():
    br = fnoise(beta=1.0, seed=18, aniso=(1, 60))
    n = fnoise(beta=2.5, seed=19)
    g = 0.82 + 0.1 * br + 0.06 * n
    alb = np.stack([g, g, g * 1.01], -1)
    h = br * .3
    rough = 0.32 + 0.14 * br + 0.1 * n
    save_set('metal', alb, h, rough, 1.5)

# ---------- 9. Plástico / laminado mate ----------
def plastic():
    n = fnoise(beta=0.8, seed=20); n2 = fnoise(beta=2.6, seed=21)
    g = 0.94 + 0.03 * n + 0.03 * n2
    alb = np.stack([g, g, g], -1)
    h = n * .25
    rough = 0.55 + 0.1 * n2
    save_set('plastic', alb, h, rough, 1.2)

# ---------- 10. Techo de placas acústicas (4x4 por textura) ----------
def ceiling():
    k = 2
    fx, fy = (xx * k) % 1, (yy * k) % 1
    edge = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy))
    rail = 1 - smoothstep(0.008, 0.014, edge)
    pores = (fnoise(beta=0.2, seed=22) > .8).astype(float)
    n = fnoise(beta=2, seed=23)
    g = 0.95 - .12 * pores + 0.03 * n
    g = g * (1 - rail) + 0.85 * rail
    alb = np.stack([g, g, g * .98], -1)
    h = (1 - rail) * .5 - pores * .2
    rough = 0.9 - rail * .5
    save_set('ceiling', alb, h, rough, 3)

# ---------- 11. Alfombra persa simplificada (sala) ----------
def rug():
    u, v = xx * 2 - 1, yy * 2 - 1
    r = np.maximum(np.abs(u), np.abs(v))
    d = np.sqrt(u * u + v * v)
    base = np.array([0xb0, 0x4a, 0x3a]) / 255.0
    dark = np.array([0x5a, 0x1e, 0x22]) / 255.0
    cream = np.array([0xe8, 0xd2, 0xa8]) / 255.0
    navy = np.array([0x1f, 0x2e, 0x4a]) / 255.0
    alb = np.ones((N, N, 3)) * base
    band = (r > .86) & (r < .93)
    alb[band] = dark
    alb[(r > .93) & (r < .96)] = cream
    alb[r >= .96] = navy
    med = (np.abs(u) + np.abs(v) < .55) & (np.abs(u) + np.abs(v) > .45)
    alb[med] = cream
    alb[(np.abs(u) + np.abs(v)) < .3] = navy
    patt = (np.sin(u * 40) * np.sin(v * 40) > .6) & (r < .8) & (r > .62)
    alb[patt] = dark
    fib = fnoise(beta=0.5, seed=24)
    alb = alb * (0.85 + .2 * fib)[..., None]
    h = fib
    rough = 0.95 + 0 * fib
    save_set('rug', alb, h, rough, 2)

# ---------- 12. Rejilla de servidor (frente de rack) ----------
def mesh_grille():
    k = 64
    fx, fy = (xx * k) % 1, (yy * k * 1.5) % 1
    hole = ((fx - .5) ** 2 + (fy - .5) ** 2) < .09
    g = np.where(hole, 0.06, 0.22)
    alb = np.stack([g, g, g * 1.05], -1)
    h = np.where(hole, 0.0, 1.0)
    rough = np.where(hole, .9, .45)
    save_set('grille', alb, h, rough, 3)


# ---------- Fondo de escritorio (port de makeWP) ----------
def wallpaper(w=1920, h=1080):
    img = Image.new('RGB', (w, h))
    px = np.zeros((h, w, 3))
    t = np.clip(np.linspace(0, 1, h) / .7, 0, 1)[:, None]
    stops = [(0, (0x1d, 0x63, 0xc9)), (.6, (0x6f, 0xb4, 0xf0)), (1, (0xcf, 0xe8, 0xff))]
    def grad(t):
        out = np.zeros(t.shape + (3,))
        for (a, ca), (b, cb) in zip(stops, stops[1:]):
            m = (t >= a) & (t <= b)
            k = ((t - a) / (b - a))[..., None]
            out[m[..., 0] if m.ndim == 3 else m] = 0
            out += np.where(m[..., None], np.array(ca) * (1 - k) + np.array(cb) * k, 0)
        return out
    px[:] = grad(np.repeat(t, w, 1))
    Y, X = np.mgrid[0:h, 0:w]
    d = np.sqrt((X - w * .78) ** 2 + (Y - h * .2) ** 2) / (h * .35)
    sun = np.clip(1 - d, 0, 1) ** 1.6
    px = px * (1 - sun[..., None]) + np.array([255, 251, 224]) * sun[..., None]
    img = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))
    dr = ImageDraw.Draw(img, 'RGBA')
    for i in range(9):
        cx, cy, r = w * (.05 + i * .11), h * (.1 + ((i * 37) % 25) / 100), h * (.05 + ((i * 13) % 9) / 200)
        for k in range(6):
            ex, ey = cx + k * r * .7, cy + math.sin(k * 1.7) * r * .25
            rx, ry = r * (1.3 - k * .1), r * .55
            dr.ellipse([ex - rx, ey - ry, ex + rx, ey + ry], fill=(255, 255, 255, 209))
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    dr = ImageDraw.Draw(img, 'RGBA')
    def hill(y0, amp, c1, c2, ph):
        pts = [(0, h)] + [(x, y0 + math.sin(x / w * math.pi * 1.6 + ph) * amp) for x in range(0, w + 10, 10)] + [(w, h)]
        mask = Image.new('L', (w, h), 0); ImageDraw.Draw(mask).polygon(pts, fill=255)
        g = np.linspace(0, 1, h)[:, None, None]
        col = (np.array(c1) * (1 - g) + np.array(c2) * g).repeat(w, 1)
        layer = Image.fromarray(col.astype(np.uint8))
        img.paste(layer, (0, 0), mask)
    hill(h * .62, h * .05, (0x5a, 0xa0, 0x5a), (0x2f, 0x6a, 0x2f), 0)
    hill(h * .72, h * .07, (0x4a, 0x9a, 0x3a), (0x1f, 0x5a, 0x1f), 2.2)
    hill(h * .86, h * .05, (0x3a, 0x8a, 0x2a), (0x14, 0x4a, 0x14), 4.1)
    dr = ImageDraw.Draw(img, 'RGBA')
    r2 = np.random.default_rng(30)
    for i in range(1400):
        x0, y0 = r2.uniform(0, w), h * .66 + r2.uniform(0, h * .34)
        dr.line([(x0, y0), (x0 + r2.uniform(-4, 4), y0 - 8 - r2.uniform(0, 14))], fill=(255, 255, 255, 26), width=1)
    img.save(os.path.join(OUT, 'wallpaper.png'), optimize=True); print('ok wallpaper')

# ---------- Vista exterior de las ventanas (ciudad de Panamá al atardecer) ----------
def outside(w=2048, h=768):
    Y, X = np.mgrid[0:h, 0:w]
    t = Y / h
    sky = np.array([0x4f, 0x8f, 0xd8]) * (1 - t[..., None]) + np.array([0xff, 0xd2, 0xa0]) * t[..., None]
    img = Image.fromarray(np.clip(sky, 0, 255).astype(np.uint8))
    dr = ImageDraw.Draw(img, 'RGBA')
    r = np.random.default_rng(31)
    # nubes suaves
    cl = Image.new('RGBA', (w, h), (0, 0, 0, 0)); cd = ImageDraw.Draw(cl)
    for i in range(40):
        cx, cy = r.uniform(0, w), r.uniform(0, h * .35)
        for k in range(5):
            rx, ry = r.uniform(40, 120), r.uniform(12, 30)
            cd.ellipse([cx + k * 50 - rx, cy - ry, cx + k * 50 + rx, cy + ry], fill=(255, 255, 255, 70))
    img.paste(cl.filter(ImageFilter.GaussianBlur(8)), (0, 0), cl.filter(ImageFilter.GaussianBlur(8)))
    dr = ImageDraw.Draw(img, 'RGBA')
    # rascacielos lejanos
    x = 0
    while x < w:
        bw = r.uniform(40, 110); bh = r.uniform(h * .15, h * .55)
        c = int(r.uniform(90, 130))
        dr.rectangle([x, h * .72 - bh, x + bw, h], fill=(c, c + 10, c + 30, 255))
        for wy in np.arange(h * .72 - bh + 8, h * .72, 14):
            for wx in np.arange(x + 6, x + bw - 6, 12):
                if r.random() < .55:
                    dr.rectangle([wx, wy, wx + 6, wy + 7], fill=(255, 230, 170, int(r.uniform(60, 200))))
        x += bw + r.uniform(4, 30)
    # árboles tropicales en primer plano
    for i in range(70):
        cx, cy, rr = r.uniform(-50, w + 50), h * r.uniform(.78, 1.0), r.uniform(40, 110)
        g = int(r.uniform(80, 140))
        dr.ellipse([cx - rr, cy - rr * .8, cx + rr, cy + rr * .8], fill=(30, g, 50, 255))
        dr.ellipse([cx - rr * .6, cy - rr * .9, cx + rr * .3, cy - rr * .1], fill=(60, g + 40, 70, 160))
    img.save(os.path.join(OUT, 'outside.png'), optimize=True); print('ok outside')


for f in (tiles_checker, wood_planks, wood_furniture, carpet, concrete, plaster, fabric, metal, plastic, ceiling, rug, mesh_grille, wallpaper, outside):
    f()
