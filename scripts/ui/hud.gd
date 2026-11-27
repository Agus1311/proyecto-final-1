class_name Hud
extends Control
## HUD: tarjetas de estado, barras, toast, cruz, botón de interacción y minimapa.

signal use_pressed
signal sound_toggled

var clock_l: Label
var day_l: Label
var sat_v: Label
var sec_v: Label
var sat_b: ProgressBar
var sec_b: ProgressBar
var tk_l: Label
var tk_s: Label
var money_l: Label
var rank_l: Label
var goal_l: Label
var soc_l: Label
var snd_b: Button
var toast_p: PanelContainer
var toast_l: Label
var use_b: Button
var hint_l: Label
var fps_l: Label
var cross: Control
var minimap: Minimap
var _toast_t := 0.0
var _hint_i := 0
var _hint_t := 0.0

const HINTS := ["Clic = mirar con el mouse (Esc lo libera) · WASD mover · Shift correr · Rueda zoom · E interactuar",
	"💡 E = interactuar con lo que tengas delante",
	"💡 Los usuarios con ⚠ en su pantalla necesitan visita en sitio",
	"💡 Atiende primero los tickets de prioridad alta (rojo): su SLA vence antes",
	"💡 En el data center configuras el switch Cisco: escribe ? para ver comandos"]


func _ready() -> void:
	Kit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Kit.theme()
	var top := HBoxContainer.new()
	top.position = Vector2(14, 12)
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	# reloj
	var c1 := _card(top)
	var v1 := VBoxContainer.new(); v1.add_theme_constant_override("separation", -2); c1.add_child(v1)
	clock_l = Kit.label("08:00", 22, Color.WHITE, true); v1.add_child(clock_l)
	day_l = Kit.label("Día 1", 12, Color(1, 1, 1, .75)); v1.add_child(day_l)
	# satisfacción / seguridad
	var r := _stat(top, "Satisfacción", Color("#e8b04c")); sat_v = r[0]; sat_b = r[1]
	r = _stat(top, "Seguridad", Color("#e8b04c")); sec_v = r[0]; sec_b = r[1]
	# tickets
	var c4 := _card(top)
	var v4 := VBoxContainer.new(); v4.add_theme_constant_override("separation", -2); c4.add_child(v4)
	tk_l = Kit.label("0/8 🎫", 20, Color.WHITE, true); v4.add_child(tk_l)
	tk_s = Kit.label("Red 0/3", 12, Color(1, 1, 1, .75)); v4.add_child(tk_s)
	# objetivo
	var gp := Kit.panel(Kit.sb(Color(0.18, 0.43, 0.56, .85), 12, 1, Color(1, 1, 1, .18), 10, 4))
	gp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_l = Kit.label("", 14, Color.WHITE, true)
	gp.add_child(goal_l)
	top.add_child(gp)
	var spn := Kit.panel(Kit.sb(Color(0.06, 0.1, 0.14, .82), 12, 1, Color(1, 1, 1, .14), 10, 4))
	spn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soc_l = Kit.label("", 14, Color.WHITE, true)
	spn.add_child(soc_l)
	spn.visible = false
	top.add_child(spn)
	# derecha: dinero + sonido
	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-14, 12)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	var cm := _card(right)
	var vm := VBoxContainer.new(); vm.add_theme_constant_override("separation", -2); cm.add_child(vm)
	money_l = Kit.label("$100 💰", 18, Color.WHITE, true); vm.add_child(money_l)
	rank_l = Kit.label("Becario", 12, Color(1, 1, 1, .75)); vm.add_child(rank_l)
	snd_b = Kit.button("🔊", "", 18)
	snd_b.custom_minimum_size = Vector2(46, 46)
	snd_b.add_theme_stylebox_override("normal", Kit.sb(Color(0.06, 0.1, 0.14, .82), 23, 1, Color(1, 1, 1, .14), 8))
	snd_b.add_theme_stylebox_override("hover", Kit.sb(Color(0.12, 0.18, 0.24, .9), 23, 1, Color(1, 1, 1, .2), 8))
	snd_b.pressed.connect(func(): sound_toggled.emit())
	right.add_child(snd_b)
	# minimapa
	minimap = Minimap.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-14 - 132, 72)
	minimap.size = Vector2(132, 132)
	add_child(minimap)
	# cruz central
	cross = Control.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(func(): cross.draw_circle(Vector2.ZERO, 3.5, Color(1, 1, 1, .7)); cross.draw_arc(Vector2.ZERO, 3.5, 0, TAU, 16, Color(0, 0, 0, .35), 1.0, true))
	add_child(cross)
	# toast
	toast_p = Kit.panel(Kit.sb(Color(0.06, 0.1, 0.14, .95), 10, 2, Kit.WARM, 12, 8))
	toast_p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_p.position.y = 72
	toast_p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_l = Kit.label("", 15, Color.WHITE, true, true)
	toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_l.custom_minimum_size.x = 260
	toast_p.add_child(toast_l)
	toast_p.visible = false
	add_child(toast_p)
	# botón de interacción
	use_b = Kit.button("Sentarse en la PC (E)", "Warm", 17)
	use_b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	use_b.grow_horizontal = Control.GROW_DIRECTION_BOTH
	use_b.position.y = -110
	use_b.visible = false
	use_b.pressed.connect(func(): use_pressed.emit())
	add_child(use_b)
	hint_l = Kit.label(HINTS[0], 14, Color(1, 1, 1, .85))
	hint_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_l.position.y = -34
	hint_l.add_theme_constant_override("outline_size", 6)
	hint_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, .5))
	add_child(hint_l)
	fps_l = Kit.label("", 12, Color(1, 1, 1, .6))
	fps_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	fps_l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fps_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fps_l.position += Vector2(-12, -10)
	add_child(fps_l)
	Game.hud_changed.connect(refresh)
	Game.toast_requested.connect(show_toast)


func _card(parent: Control) -> PanelContainer:
	var p := Kit.panel(Kit.sb(Color(0.06, 0.1, 0.14, .82), 12, 1, Color(1, 1, 1, .12), 10, 6))
	p.add_theme_stylebox_override("panel", _card_style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _card_style() -> StyleBoxFlat:
	var s := Kit.sb(Color(0.06, 0.1, 0.14, .82), 12, 1, Color(1, 1, 1, .12), 10, 6)
	s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 6; s.content_margin_bottom = 7
	return s


func _stat(parent: Control, title: String, col: Color) -> Array:
	var c := _card(parent)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); c.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h)
	var t := Kit.label(title, 12, Color(1, 1, 1, .8)); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(t)
	var val := Kit.label("50", 12, Color(1, 1, 1, .9), true); h.add_child(val)
	var b := Kit.bar(col); v.add_child(b)
	return [val, b]


func refresh() -> void:
	if not Game.st.has("time"):
		return
	var st: Dictionary = Game.st
	clock_l.text = Game.clock_str()
	day_l.text = "Día %d · Hab. %d" % [int(Game.G.day), Game.lvl()]
	sat_v.text = str(st.sat); sat_b.value = st.sat
	sec_v.text = str(st.sec); sec_b.value = st.sec
	_bar_col(sat_b, st.sat); _bar_col(sec_b, st.sec)
	tk_l.text = "%d/%d 🎫" % [st.done, Game.tickets.size()]
	tk_s.text = "Red %d/3 · BIOS %d/1 · Taller %d/%d" % [st.net, 1 if st.bios.done else 0, st.rep, st.rq.size()]
	var al := Game.alerts()
	if al: tk_s.text += " · ⚠ %d" % al
	money_l.text = "$%d 💰" % int(Game.G.money)
	rank_l.text = Game.rank()
	var lv := int(Game.G.get("lvl", 1))
	goal_l.text = ("🏅 5/5 completado · ver certificado" if lv > 5 else "🎯 Nivel %d/5 · %s" % [lv, Game.lvl_goal_txt(lv)])
	minimap.queue_redraw()


func _bar_col(b: ProgressBar, v: int) -> void:
	var c := Kit.OK if v >= 70 else (Color("#e8b04c") if v >= 40 else Kit.BAD)
	(b.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = c


func show_toast(t: String, ms: int) -> void:
	toast_l.text = t
	toast_p.visible = true
	toast_p.reset_size()
	toast_p.position.x = (size.x - toast_p.size.x) / 2
	toast_p.modulate.a = 1
	_toast_t = ms / 1000.0


func set_use(txt: String) -> void:
	use_b.visible = txt != ""
	if txt != "" and use_b.text != txt:
		use_b.text = txt
		use_b.reset_size()
		use_b.position.x = (size.x - use_b.size.x) / 2


func _process(dt: float) -> void:
	if _toast_t > 0:
		_toast_t -= dt
		toast_p.position.x = (size.x - toast_p.size.x) / 2
		toast_p.position.y = 72
		if _toast_t < .25:
			toast_p.modulate.a = maxf(0, _toast_t / .25)
		if _toast_t <= 0:
			toast_p.visible = false
	_hint_t += dt
	if _hint_t > 9:
		_hint_t = 0
		_hint_i = (_hint_i + 1) % HINTS.size()
		hint_l.text = HINTS[_hint_i]
		hint_l.reset_size()
	hint_l.position.x = (size.x - hint_l.size.x) / 2
	use_b.position.x = (size.x - use_b.size.x) / 2
