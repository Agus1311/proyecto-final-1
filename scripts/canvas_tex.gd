class_name CanvasTex
extends Node2D
## Textura dinámica dibujada con la API 2D de Godot dentro de un SubViewport
## (equivalente a los <canvas> del original: pantallas, TV, reloj).

var painter: Callable
var vp: SubViewport

static var _font: FontFile
static var _fontr: FontFile
static var _wall: Texture2D


static func font(bold := true) -> Font:
	if _font == null:
		_font = load("res://assets/fonts/space-grotesk-latin-700-normal.woff2")
		_fontr = load("res://assets/fonts/space-grotesk-latin-400-normal.woff2")
		# Fuentes de respaldo empaquetadas (subconjuntos con solo los símbolos que usa el juego):
		# así los emojis y flechas se ven igual en Windows, Linux y en el navegador (versión web).
		var fb: Array[Font] = []
		for f in ["emoji-subset.ttf", "symbols-subset.ttf", "extra1-subset.ttf", "extra2-subset.otf", "extra3-subset.otf"]:
			var ff: Font = load("res://assets/fonts/" + f)
			if ff: fb.append(ff)
		var emoji := SystemFont.new()
		emoji.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji", "Segoe UI Symbol", "DejaVu Sans"])
		fb.append(emoji)
		_font.fallbacks = fb
		_fontr.fallbacks = fb
	return _font if bold else _fontr


static func wallpaper() -> Texture2D:
	if _wall == null:
		_wall = load("res://assets/textures/wallpaper.png")
	return _wall


static func make(parent: Node, size: Vector2i, p: Callable, continuous := false) -> CanvasTex:
	var v := SubViewport.new()
	v.size = size
	v.disable_3d = true
	v.transparent_bg = false
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS if continuous else SubViewport.UPDATE_ONCE
	var c := CanvasTex.new()
	c.painter = p
	c.vp = v
	v.add_child(c)
	parent.add_child(v)
	return c


func texture() -> ViewportTexture:
	return vp.get_texture()


func refresh() -> void:
	queue_redraw()
	if vp.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw() -> void:
	if painter.is_valid():
		painter.call(self, Vector2(vp.size))


# ---------------- utilidades de dibujo ----------------
static func grad_rect(ci: CanvasItem, r: Rect2, c0: Color, c1: Color, vertical := true) -> void:
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cols := PackedColorArray([c0, c0, c1, c1]) if vertical else PackedColorArray([c0, c1, c1, c0])
	ci.draw_polygon(p, cols)


static func text(ci: CanvasItem, s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, bold := true) -> void:
	var f := font(bold)
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, width, size, col)


## Escritorio de Windows simulado (paintDesk del original).
static func paint_desk(ci: CanvasItem, sz: Vector2, o: Dictionary) -> void:
	var w := sz.x
	var h := sz.y
	ci.draw_texture_rect(wallpaper(), Rect2(Vector2.ZERO, sz), false)
	var icons := ["🗑️", "💻", "🌐"]
	for i in 3:
		text(ci, icons[i], Vector2(w * .02, h * .1 + i * h * .12), int(h * .05), Color.WHITE)
	if o.has("win"):
		var ww := w * .52
		var wh := h * .5
		var wx := w * .24
		var wy := h * .12
		ci.draw_rect(Rect2(wx + 4, wy + 6, ww, wh), Color(0, 0, 0, .25))
		ci.draw_rect(Rect2(wx, wy, ww, wh), Color("#f4f6fa"))
		ci.draw_rect(Rect2(wx, wy, ww, h * .075), o.get("col", Color("#2f6f8f")))
		text(ci, o.win, Vector2(wx + w * .015, wy + h * .053), int(h * .045), Color.WHITE)
		var lines: Array = o.get("lines", [])
		for i in lines.size():
			text(ci, lines[i], Vector2(wx + w * .02, wy + h * .16 + i * h * .075), int(h * .042), Color("#222222"), HORIZONTAL_ALIGNMENT_LEFT, -1, false)
	ci.draw_rect(Rect2(0, h * .92, w, h * .08), Color(15 / 255.0, 22 / 255.0, 40 / 255.0, .66))
	var q := h * .026
	var bx := w * .012
	var by := h * .935
	var cols := [[Color("#4cc2ff"), 0, 0], [Color("#2a8fe0"), 1, 0], [Color("#2a8fe0"), 0, 1], [Color("#1a62b8"), 1, 1]]
	for c in cols:
		ci.draw_rect(Rect2(bx + c[1] * (q + 2), by + c[2] * (q + 2), q, q), c[0])
	text(ci, o.get("clk", ""), Vector2(w * .985, h * .975), int(h * .04), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)


const ADS := [["CAA CORP", "Tecnología que conecta", "🌐", "#0b2a4a", "#1f7fd0"],
	["SOPORTE IT 24/7", "Rápido, humano y seguro", "🛠️", "#2a1b4a", "#8a3fa0"],
	["CIBERSEGURIDAD", "Protegemos tu información", "🔐", "#0b3a2a", "#2f9a5a"],
	["REDES CISCO", "Conectividad de alto rendimiento", "🖧", "#3a1f0b", "#e8861a"],
	["ÚNETE A CAA CORP", "Vacantes en RRHH · Piso 1", "🤝", "#0b2a4a", "#ff9a1f"]]


## Anuncios animados de las TV (drawAd del original). t en milisegundos.
static func draw_ad(ci: CanvasItem, sz: Vector2, t: float) -> void:
	var w := sz.x
	var h := sz.y
	var s := int(floor(t / 4000.0)) % ADS.size()
	var p := fmod(t, 4000.0) / 4000.0
	var a: Array = ADS[s]
	var c0 := Color(a[3])
	var c1 := Color(a[4])
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), sz, Vector2(0, h)]), PackedColorArray([c0, c0.lerp(c1, .5), c1, c0.lerp(c1, .5)]))
	for i in 6:
		ci.draw_circle(Vector2(w * (.1 + i * .18) + sin(t / 1500.0 + i) * 20, h * .3 + cos(t / 1800.0 + i) * 18), 40 + i * 8, Color(1, 1, 1, .08))
	var e := minf(1.0, p * 4)
	var yy := (1 - e) * 30
	var col := Color(1, 1, 1, e)
	text(ci, a[2], Vector2(w / 2, h * .38 + yy), 64, col, HORIZONTAL_ALIGNMENT_CENTER)
	text(ci, a[0], Vector2(w / 2, h * .6 + yy), 44, col, HORIZONTAL_ALIGNMENT_CENTER)
	text(ci, a[1], Vector2(w / 2, h * .72 + yy), 22, col, HORIZONTAL_ALIGNMENT_CENTER, -1, false)
	ci.draw_rect(Rect2(0, h - 34, w, 34), Color(0, 0, 0, .45))
	var tk := "CAA CORP · Innovación · Seguridad · Servicio · Soporte 24/7 · Tecnología que conecta    "
	var off := fmod(t / 30.0, tk.length() * 8.0)
	text(ci, tk + tk + tk, Vector2(-off, h - 12), 16, Color("#ff9a1f"))
	ci.draw_rect(Rect2(0, h - 4, w * p, 4), Color("#ff9a1f"))


## Reloj de pared analógico (drawClk).
static func draw_clock(ci: CanvasItem, sz: Vector2, minutes: int) -> void:
	var c := sz / 2
	var r := sz.x * .45
	ci.draw_circle(c, r, Color("#fbf3ea"))
	ci.draw_arc(c, r, 0, TAU, 64, Color("#2a2230"), sz.x * .05, true)
	for i in 12:
		var a := i * TAU / 12
		ci.draw_line(c + Vector2(cos(a), sin(a)) * r * .82, c + Vector2(cos(a), sin(a)) * r * .92, Color("#2a2230"), sz.x * .02, true)
	var hh := minutes / 60.0
	var mm := minutes % 60
	for hand in [[fmod(hh, 12.0) * 30.0, r * .5, sz.x * .05], [mm * 6.0, r * .8, sz.x * .033]]:
		var ang := deg_to_rad(hand[0] - 90)
		ci.draw_line(c, c + Vector2(cos(ang), sin(ang)) * hand[1], Color("#2a2230"), hand[2], true)
	ci.draw_circle(c, sz.x * .04, Color("#c4503f"))
