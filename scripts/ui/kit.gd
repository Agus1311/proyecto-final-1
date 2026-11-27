class_name Kit
extends RefCounted
## Utilidades de interfaz: tema, estilos y fábricas de controles.

const INK := Color("#2a2230")
const PAPER := Color("#f6e7d8")
const TEAL := Color("#2f6f8f")
const WARM := Color("#e8a77c")
const OK := Color("#4c9a6a")
const BAD := Color("#c4503f")
const BG := Color("#1d1520")
const PANEL := Color("#101923")

static var _theme: Theme
static var _mono: FontFile
static var _bold: Font
static var _reg: Font


static func bold() -> Font:
	if _bold == null:
		_bold = CanvasTex.font(true)
	return _bold

static func reg() -> Font:
	if _reg == null:
		_reg = CanvasTex.font(false)
	return _reg

static func mono() -> Font:
	if _mono == null:
		_mono = load("res://assets/fonts/jetbrains-mono-latin-400-normal.woff2")
	return _mono


static func sb(bg: Color, radius := 10, border := 0, bc := Color.TRANSPARENT, margin := 10.0, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = bc
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, .45)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * .4)
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = reg()
	t.default_font_size = 16
	t.set_color("font_color", "Label", Color.WHITE)
	# Botón base
	t.set_stylebox("normal", "Button", sb(Color(1, 1, 1, .15), 8, 0, Color.TRANSPARENT, 8))
	t.set_stylebox("hover", "Button", sb(Color(1, 1, 1, .26), 8, 0, Color.TRANSPARENT, 8))
	t.set_stylebox("pressed", "Button", sb(Color(1, 1, 1, .34), 8, 0, Color.TRANSPARENT, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", sb(Color(1, 1, 1, .06), 8, 0, Color.TRANSPARENT, 8))
	t.set_font("font", "Button", bold())
	t.set_font_size("font_size", "Button", 15)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, .4))
	# Botón cálido (CTA)
	t.add_type("Warm"); t.set_type_variation("Warm", "Button")
	t.set_stylebox("normal", "Warm", sb(WARM, 12, 0, Color.TRANSPARENT, 14, 6))
	t.set_stylebox("hover", "Warm", sb(WARM.lightened(.12), 12, 0, Color.TRANSPARENT, 14, 8))
	t.set_stylebox("pressed", "Warm", sb(WARM.darkened(.1), 12, 0, Color.TRANSPARENT, 14, 4))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(k, "Warm", INK)
	t.set_font_size("font_size", "Warm", 17)
	# Opción de ticket (borde teal, fondo blanco)
	t.add_type("Opt"); t.set_type_variation("Opt", "Button")
	t.set_stylebox("normal", "Opt", sb(Color.WHITE, 8, 2, TEAL, 12))
	t.set_stylebox("hover", "Opt", sb(TEAL, 8, 2, TEAL, 12))
	t.set_stylebox("pressed", "Opt", sb(TEAL.darkened(.15), 8, 2, TEAL, 12))
	t.set_color("font_color", "Opt", INK)
	t.set_color("font_focus_color", "Opt", INK)
	t.set_color("font_hover_color", "Opt", Color.WHITE)
	t.set_color("font_pressed_color", "Opt", Color.WHITE)
	t.set_font("font", "Opt", reg())
	# Ítem de lista de tickets
	t.add_type("Tk"); t.set_type_variation("Tk", "Button")
	var tkn := sb(Color(0, 0, 0, 0), 0, 0, Color.TRANSPARENT, 12)
	tkn.border_width_bottom = 1; tkn.border_color = Color("#e5d2bf")
	t.set_stylebox("normal", "Tk", tkn)
	var tkh: StyleBoxFlat = tkn.duplicate(); tkh.bg_color = Color("#ecd4bd")
	t.set_stylebox("hover", "Tk", tkh)
	t.set_stylebox("pressed", "Tk", tkh)
	t.set_color("font_color", "Tk", INK)
	# LineEdit
	t.set_stylebox("normal", "LineEdit", sb(Color(1, 1, 1, .12), 8, 0, Color.TRANSPARENT, 8))
	t.set_stylebox("focus", "LineEdit", sb(Color(1, 1, 1, .0), 8, 0, Color.TRANSPARENT, 8))
	t.set_color("font_color", "LineEdit", Color.WHITE)
	t.set_color("caret_color", "LineEdit", Color("#cfe8d5"))
	# Tooltip
	t.set_stylebox("panel", "TooltipPanel", sb(PANEL, 8, 1, WARM, 8))
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	# Barras de scroll finas
	var grab := sb(Color(0, 0, 0, .25), 6, 0, Color.TRANSPARENT, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(Color(0, 0, 0, .4), 6, 0, Color.TRANSPARENT, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", sb(Color(0, 0, 0, .5), 6, 0, Color.TRANSPARENT, 0))
	var sc := StyleBoxEmpty.new(); sc.content_margin_left = 6; sc.content_margin_right = 2
	t.set_stylebox("scroll", "VScrollBar", sc)
	_theme = t
	return t


static func label(txt: String, size := 16, col := Color.WHITE, b := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", bold() if b else reg())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(txt: String, variation := "", size := 15) -> Button:
	var b := Button.new()
	b.text = txt
	if variation != "":
		b.theme_type_variation = variation
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): Game.beep(600, .04))
	return b


static func panel(style: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	return p


static func bar(col: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(96, 6)
	p.max_value = 100
	p.add_theme_stylebox_override("background", sb(Color(1, 1, 1, .12), 3, 0, Color.TRANSPARENT, 0))
	p.add_theme_stylebox_override("fill", sb(col, 3, 0, Color.TRANSPARENT, 0))
	return p


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
