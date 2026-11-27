class_name CctvUI
extends Control
## Sala de cámaras (openCCTV/cctvDraw del original).

signal closed
var office: OfficeLife
var main: Node3D
var map: Control
var log_l: RichTextLabel


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	var bg := ColorRect.new(); bg.color = Color(0.02, 0.03, 0.05, .96); Kit.full_rect(bg); add_child(bg)
	var cc := CenterContainer.new(); Kit.full_rect(cc); add_child(cc)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); cc.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h)
	var t := Kit.label("📹 Sala de cámaras · CAA Corp", 18, Color("#cfe8d5"), true); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(t)
	var x := Kit.button("Cerrar", "", 14); x.add_theme_stylebox_override("normal", Kit.sb(Color("#a63b2f"), 8, 0, Color.TRANSPARENT, 8)); x.pressed.connect(close); h.add_child(x)
	map = Control.new(); map.custom_minimum_size = Vector2(860, 440); map.draw.connect(_draw_map); v.add_child(map)
	var lp := Kit.panel(Kit.sb(Color("#0a1410"), 8, 1, Color("#1d3a2a"), 10)); lp.custom_minimum_size = Vector2(860, 96); v.add_child(lp)
	log_l = RichTextLabel.new(); log_l.bbcode_enabled = true; log_l.fit_content = true
	log_l.add_theme_font_override("normal_font", Kit.mono()); log_l.add_theme_font_size_override("normal_font_size", 13); log_l.add_theme_color_override("default_color", Color("#cfe8d5"))
	lp.add_child(log_l)


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e.pressed and e.keycode == KEY_ESCAPE:
		close(); get_viewport().set_input_as_handled()


var _t := 0.0
func _process(dt: float) -> void:
	if not visible: return
	_t += dt
	if _t > .1:
		_t = 0; map.queue_redraw(); _log()


func _log() -> void:
	var live: bool = office.spies.any(func(s): return s.phase == "steal" and not s.caught)
	var t := ""
	if live: t += "[color=#ff6a6a][b]⚠ Actividad inusual en curso: corre a esa zona y confronta con la tecla X (a menos de 3 m).[/b][/color]\n"
	if office.spy_log.size(): t += "\n".join(office.spy_log.slice(0, 5).map(func(x): return "• " + x))
	else: t += "• Sin alertas por ahora. El sistema DLP vigila copias de archivos, impresiones y accesos."
	t += "\n[color=#cfe8d599]Atrapados hoy: %d / %d · Acusaciones falsas: %d[/color]" % [office.spy_caught, office.spies.size(), office.spy_fails]
	log_l.text = t


func _draw_map() -> void:
	var W := 860.0; var H := 440.0
	var x0 := -11.5; var x1 := 18.0; var z0 := -2.8; var z1 := 21.2
	var k := minf((W - 40) / (x1 - x0), (H - 40) / (z1 - z0))
	var ox := (W - (x1 - x0) * k) / 2; var oz := (H - (z1 - z0) * k) / 2
	var P := func(x: float, z: float) -> Vector2: return Vector2(ox + (x - x0) * k, oz + (z - z0) * k)
	map.draw_rect(Rect2(0, 0, W, H), Color("#050a08"))
	for i in range(0, int(W), 40): map.draw_line(Vector2(i, 0), Vector2(i, H), Color("#0f2a1c"))
	for j in range(0, int(H), 40): map.draw_line(Vector2(0, j), Vector2(W, j), Color("#0f2a1c"))
	for r in Game.wk:
		if r[1] < 30 and r[0] > -12:
			var a: Vector2 = P.call(r[0], r[2]); var b: Vector2 = P.call(r[1], r[3])
			map.draw_rect(Rect2(a, b - a), Color("#16382a"))
	var t := Time.get_ticks_msec()
	var f := Kit.mono()
	for n in office.ZN:
		if n.s == "away" or not n.r.visible: continue
		var sp: bool = office.spies.any(func(s): return s.n == n and s.phase == "steal" and not s.caught)
		var p: Vector2 = P.call(n.x, n.z)
		if sp:
			map.draw_arc(p, 10 + absf(sin(t / 180.0)) * 8, 0, TAU, 24, Color("#ff4a4a"), 3, true)
			map.draw_string(f, p + Vector2(14, -12), "⚠ ACTIVIDAD SOSPECHOSA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ff6a6a"))
		map.draw_circle(p, 5, Color("#ff4a4a") if sp else Color("#7ad0ff"))
		map.draw_string(f, p + Vector2(8, 4), n.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#cfe8d5"))
	var me: Vector2 = P.call(main.cam.position.x, main.cam.position.z)
	map.draw_circle(me, 6, Color.WHITE)
	map.draw_string(f, me + Vector2(9, 4), "Tú", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	map.draw_circle(Vector2(20, 20), 6, Color("#ff3030") if t % 1000 < 500 else Color("#6a1010"))
	map.draw_string(f, Vector2(32, 25), "REC · CAM 01-04 · " + Game.clock_str(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#cfe8d5"))
