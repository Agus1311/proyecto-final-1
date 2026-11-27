class_name MenuUI
extends Control
## Menú lateral (Tab) y pausa (P) con ajustes persistentes.

signal closed
signal settings_changed
signal quit_to_lobby
signal show_cert

const SAVE := "user://caa5.json"
var S := {"master": .8, "music": .55, "sfx": .9, "sens": 1.0, "quality": "high", "shadows": true, "minimap": true, "fps": true, "music_on": true}
var side: PanelContainer
var tab := "mis"
var body: VBoxContainer
var pause: Control
var music: Music
var tabs_box: HBoxContainer


func _ready() -> void:
	if OS.has_feature("web"):
		S.quality = "med"  # en el navegador: resolución 3D al 77 % para mantener los FPS
	Kit.full_rect(self)
	theme = Kit.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if FileAccess.file_exists(SAVE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if d is Dictionary:
			for k in d: S[k] = d[k]
	side = Kit.panel(Kit.sb(Color(0.08, 0.1, 0.14, .97), 0, 1, Color(1, 1, 1, .13), 14, 30))
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -440
	side.visible = false
	add_child(side)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); side.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h)
	var t := Kit.label("Menú del juego", 18, Color.WHITE, true); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(t)
	var x := Kit.button("✕", "", 18); x.flat = true; x.pressed.connect(func(): toggle(false)); h.add_child(x)
	tabs_box = HBoxContainer.new(); tabs_box.add_theme_constant_override("separation", 6); v.add_child(tabs_box)
	for tt in [["mus","🎵 Música"],["mis","🎯 Misiones"],["aj","⚙ Ajustes"],["ay","❓ Ayuda"]]:
		var b := Kit.button(tt[1], "", 13)
		var k: String = tt[0]
		b.pressed.connect(func(): tab = k; render())
		b.set_meta("k", k)
		tabs_box.add_child(b)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 6); sc.add_child(body)
	_build_pause()


func save_settings() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(S))
	settings_changed.emit()


func is_open() -> bool:
	return side.visible or pause.visible


func toggle(o = null) -> void:
	side.visible = (not side.visible) if o == null else o
	if side.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		render()
	else:
		closed.emit()


func h4(t: String) -> void:
	var l := Kit.label(t.to_upper(), 12, Color("#9fc9de"), true); body.add_child(l)


func row(t: String, sub := "", btn_t := "", cb := Callable(), on := false) -> void:
	var p := Kit.panel(Kit.sb(Color(1, 1, 1, .1 if on else .05), 12, 1 if on else 0, Kit.WARM, 9))
	body.add_child(p)
	var h := HBoxContainer.new(); p.add_child(h)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 0); h.add_child(v)
	v.add_child(Kit.label(t, 14, Color.WHITE, true, true))
	if sub != "": v.add_child(Kit.label(sub, 12, Color(1, 1, 1, .65), false, true))
	if btn_t != "":
		var b := Kit.button(btn_t, "Warm", 13); b.pressed.connect(cb); h.add_child(b)


func slider(t: String, key: String, mn: float, mx: float, step: float) -> void:
	var h := HBoxContainer.new(); body.add_child(h)
	var l := Kit.label(t, 13, Color.WHITE); l.custom_minimum_size.x = 170; h.add_child(l)
	var s := HSlider.new(); s.min_value = mn; s.max_value = mx; s.step = step; s.value = float(S[key]); s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(val): S[key] = val; save_settings())
	h.add_child(s)


func check(t: String, key: String) -> void:
	var c := CheckButton.new(); c.text = t; c.button_pressed = bool(S[key])
	c.toggled.connect(func(on): S[key] = on; save_settings())
	body.add_child(c)


func bar(t: String, val: int, mx: int) -> void:
	var h := HBoxContainer.new(); body.add_child(h)
	var l := Kit.label(t, 13, Color.WHITE); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
	h.add_child(Kit.label("%d / %d" % [mini(val, 999), mx], 13, Color.WHITE, true))
	var b := Kit.bar(Kit.OK if val >= mx else Color("#d0a030")); b.value = minf(100, val * 100.0 / maxf(1, mx)); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size.y = 7
	body.add_child(b)


func render() -> void:
	for b in tabs_box.get_children():
		var on: bool = b.get_meta("k") == tab
		b.add_theme_stylebox_override("normal", Kit.sb(Kit.WARM if on else Color(1, 1, 1, .08), 14, 0, Color.TRANSPARENT, 7))
		b.add_theme_color_override("font_color", Kit.INK if on else Color.WHITE)
	for c in body.get_children(): c.queue_free()
	match tab:
		"mus": _mus()
		"mis": _mis()
		"aj": _aj()
		_: _ay()


func _mus() -> void:
	row("🎶 Notas de tensión", "Notas suaves cuando hay alertas abiertas en el SOC.", "Apagar" if S.music_on else "Encender", func(): S.music_on = not S.music_on; save_settings(); render(), S.music_on)
	slider("🔊 Volumen de música", "music", 0, 1, .05)
	h4("Linkin Park")
	for t in Data.TRACKS:
		if t[1] == "Linkin Park": _track(t)
	h4("Evanescence")
	for t in Data.TRACKS:
		if t[1] == "Evanescence": _track(t)
	body.add_child(Kit.label("Las canciones se abren en YouTube o Spotify en tu navegador (Godot no incrusta el reproductor de YouTube).", 12, Color(1, 1, 1, .6), false, true))


func _track(t: Array) -> void:
	var p := Kit.panel(Kit.sb(Color(1, 1, 1, .05), 12, 0, Color.TRANSPARENT, 7)); body.add_child(p)
	var h := HBoxContainer.new(); p.add_child(h)
	var l := Kit.label(t[0], 14, Color.WHITE, true); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
	var q: String = (t[1] + " " + t[0] + " official").uri_encode()
	var yt := Kit.button("YT", "", 12); yt.pressed.connect(func(): OS.shell_open("https://www.youtube.com/results?search_query=" + q)); h.add_child(yt)
	var sp := Kit.button("♫", "", 12); sp.pressed.connect(func(): OS.shell_open("https://open.spotify.com/search/" + (t[0] + " " + t[1]).uri_encode())); h.add_child(sp)


func _mis() -> void:
	var L := mini(5, int(Game.G.get("lvl", 1)))
	if int(Game.G.get("lvl", 1)) > 5:
		row("🏅 ¡Completaste los 5 niveles!", "Eres Soporte Técnico IT Nivel 2", "Ver certificado", func(): show_cert.emit(), true)
	elif Game.st.has("done"):
		var g: Dictionary = Data.GOALS[L]
		h4("Nivel %d/5 · %s" % [L, Data.LVN[L]])
		bar("Tickets resueltos", Game.st.done, g.done)
		bar("Satisfacción", Game.st.sat, g.sat)
		if g.has("net"): bar("Trabajos de red", Game.st.net, g.net)
		if g.has("rep"): bar("Reparaciones en el taller", Game.st.rep, g.rep)
		if g.has("sec"): bar("Seguridad", Game.st.sec, g.sec)
		if g.has("spy"):
			var ol = get_tree().get_first_node_in_group("office")
			bar("Espías atrapados hoy", ol.spy_caught if ol else 0, maxi(1, mini(g.spy, ol.spies.size() if ol else g.spy)))
		body.add_child(Kit.label("Cumple la meta al terminar la jornada para pasar al siguiente nivel.", 12, Color(1, 1, 1, .6), false, true))
	h4("Ruta de carrera")
	for i in range(1, 6):
		var d: bool = int(Game.G.get("lvl", 1)) > i
		row(("✅" if d else ("🎯" if i == int(Game.G.get("lvl", 1)) else "🔒")) + " Nivel %d · %s" % [i, Data.LVN[i]], Game.lvl_goal_txt(i), "", Callable(), i == int(Game.G.get("lvl", 1)))
	h4("Consejos")
	row("Sube al piso 2 por el ascensor para el taller y el almacén. Sírvete un café o abre la nevera para mantener la satisfacción alta. Imprime documentos en la sala de copiado y entrégalos con F.")


func _aj() -> void:
	h4("Pantalla")
	row("⛶ Pantalla completa", "F11 también alterna", "Alternar", func():
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN)
	check("🗺 Minimapa visible", "minimap")
	check("📈 Mostrar FPS", "fps")
	h4("Audio y gráficos")
	row("⚙ Ajustes avanzados", "Sensibilidad, volumen, calidad y sombras", "Abrir (P)", func(): toggle(false); set_pause(true))
	if int(Game.G.get("lvl", 1)) > 5:
		h4("Logros")
		row("🏅 Certificado", "", "Ver", func(): show_cert.emit())


func _ay() -> void:
	h4("Teclado y mouse")
	row("WASD mover · Shift correr · Clic para mirar con el mouse · E interactuar · F usar objeto en mano · Q soltarlo · X confrontar a un sospechoso · V primera / tercera persona · P pausa y ajustes · Tab este menú · F11 pantalla completa")
	h4("Cómo se juega")
	row("Atiende tickets sentándote en una PC, resuelve la red en el switch Cisco, repara equipos en el taller del piso 2 y vigila la seguridad. Cumple la meta de cada nivel al final de la jornada para llegar al nivel 5 y ganar tu certificado.")


# ---------------- pausa ----------------
func _build_pause() -> void:
	pause = Control.new()
	Kit.full_rect(pause)
	pause.visible = false
	add_child(pause)
	var bg := ColorRect.new(); bg.color = Color(0.03, 0.04, 0.07, .78); Kit.full_rect(bg); pause.add_child(bg)
	var cc := CenterContainer.new(); Kit.full_rect(cc); pause.add_child(cc)
	var p := Kit.panel(Kit.sb(Color("#1c2438"), 18, 1, Color(1, 1, 1, .14), 22, 30)); p.custom_minimum_size.x = 460; cc.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); p.add_child(v)
	v.add_child(Kit.label("⏸ Pausa", 26, Color.WHITE, true))
	var mk := func(t: String, key: String, mn: float, mx: float, st: float):
		var h := HBoxContainer.new(); v.add_child(h)
		var l := Kit.label(t, 14, Color.WHITE); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		var s := HSlider.new(); s.min_value = mn; s.max_value = mx; s.step = st; s.custom_minimum_size.x = 170
		s.value = float(S[key]); s.value_changed.connect(func(val): S[key] = val; save_settings())
		h.add_child(s)
	mk.call("Volumen general", "master", 0, 1, .05)
	mk.call("Música", "music", 0, 1, .05)
	mk.call("Efectos", "sfx", 0, 1, .05)
	mk.call("Sensibilidad del mouse", "sens", .3, 2, .1)
	var qh := HBoxContainer.new(); v.add_child(qh)
	var ql := Kit.label("Calidad de render", 14, Color.WHITE); ql.size_flags_horizontal = Control.SIZE_EXPAND_FILL; qh.add_child(ql)
	var ob := OptionButton.new()
	for q in [["high","Alta"],["med","Media"],["low","Baja"]]: ob.add_item(q[1])
	ob.selected = ["high","med","low"].find(S.quality) if ["high","med","low"].has(S.quality) else 0
	ob.item_selected.connect(func(i): S.quality = ["high","med","low"][i]; save_settings())
	qh.add_child(ob)
	var sh := CheckButton.new(); sh.text = "Sombras dinámicas"; sh.button_pressed = bool(S.shadows); sh.toggled.connect(func(on): S.shadows = on; save_settings()); v.add_child(sh)
	var bh := HBoxContainer.new(); bh.add_theme_constant_override("separation", 8); v.add_child(bh)
	var r := Kit.button("Reanudar (P)", "Warm", 16); r.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r.pressed.connect(func(): set_pause(false)); bh.add_child(r)
	var q := Kit.button("Guardar y salir al inicio", "", 15); q.size_flags_horizontal = Control.SIZE_EXPAND_FILL; q.pressed.connect(func(): set_pause(false); Game.save(); quit_to_lobby.emit()); bh.add_child(q)
	v.add_child(Kit.label("Guardado automático activo", 12, Color(1, 1, 1, .6)))


func set_pause(on: bool) -> void:
	pause.visible = on
	get_tree().paused = on
	if on: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else: closed.emit()
