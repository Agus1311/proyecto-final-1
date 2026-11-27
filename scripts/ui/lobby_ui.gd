class_name LobbyUI
extends Control
## Pantalla de inicio: técnico, vista, editor de avatar (port del lobby v6).

signal enter
signal avatar_changed

const SAVE := "user://caa6.json"
const SKIN := ["f1c9a5","e0a97a","c58f66","9a6a45","6b4429","4a2f1f"]
const HAIR := ["111111","2a1a10","4a3020","8a5a2a","c8a050","cfcfcf","c4302a","2f6f8f"]
const COLOR := ["2f6f8f","4c9a6a","c4503f","8a5fb0","e8a77c","1f2a44","f4f4f4","151515"]
const HS := [["Corto",0],["Rizado",1],["Largo",2],["Moño",3],["Copete",4],["Sin pelo",-1]]
const GL := [["Sin lentes",0],["Redondos",1],["Cuadrados",2]]
const BD := [["Sin barba",0],["Corta",1],["Completa",2]]
const OUT := [["Anime","anime"],["Camiseta TI","plain"],["Formal","suit"],["Abrigo","coat"],["Cyber VR","cyber"],["Armadura","armor"]]

var ST := {"name": "", "view": 1, "av": {"skin": "e0a97a", "hs": 0, "hair": "111111", "gl": 0, "bd": 0, "outfit": "anime", "color": "2f6f8f", "cap": 0}}
var name_in: LineEdit
var ed: VBoxContainer
var view_btns := {}
var mode_btns := {}
var play_btn: Button
signal credits_req
var mp_mode := "solo"
var mp_box: VBoxContainer
var mp_status: Label
var roster: Label


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	if FileAccess.file_exists(SAVE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if d is Dictionary:
			if d.has("name"): ST.name = str(d.name)
			if d.has("view"): ST.view = 3 if int(d.view) == 3 else 1
			if d.get("av") is Dictionary:
				for k in d.av: ST.av[k] = d.av[k]
	var grad := ColorRect.new(); Kit.full_rect(grad); grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gs := Shader.new()
	gs.code = "shader_type canvas_item;\nvoid fragment(){ float a = 1.0 - smoothstep(0.36, 0.7, UV.x); COLOR = vec4(0.07, 0.047, 0.094, mix(0.0, 0.96, a)); }"
	var gm := ShaderMaterial.new(); gm.shader = gs; grad.material = gm
	add_child(grad)
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	sc.offset_right = 500
	sc.offset_bottom = -150
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	# pie fijo con las opciones del menú principal (siempre visibles)
	var foot := MarginContainer.new()
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_top = -150; foot.offset_right = 500; foot.offset_bottom = 0
	for s2 in ["left", "right"]: foot.add_theme_constant_override("margin_" + s2, 24)
	foot.add_theme_constant_override("margin_top", 10); foot.add_theme_constant_override("margin_bottom", 14)
	add_child(foot)
	var fv := VBoxContainer.new(); fv.add_theme_constant_override("separation", 8); foot.add_child(fv)
	var mc := MarginContainer.new(); mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]: mc.add_theme_constant_override("margin_" + s, 24)
	sc.add_child(mc)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); mc.add_child(v)
	v.add_child(Kit.label("CAA CORP · SIMULADOR DE SOPORTE TI", 12, Kit.WARM, true))
	v.add_child(Kit.label("Mesa de Ayuda", 42, Color.WHITE, true))
	v.add_child(Kit.label("Eres técnico de TI en CAA Corp, una oficina de dos pisos llena de empleados con problemas. Atiende tickets en Zoho Desk, repara equipos, administra usuarios en Active Directory, configura el switch Cisco y descubre al infiltrado siguiendo NIST SP 800-61. Cada decisión consume tiempo y afecta la satisfacción y la seguridad de la empresa.", 14, Color("#e9dfe8"), false, true))
	var chips := HFlowContainer.new(); chips.add_theme_constant_override("h_separation", 6); chips.add_theme_constant_override("v_separation", 6); v.add_child(chips)
	for c in ["🎫 Tickets","🛡️ SOC / NIST","🔌 Switch Cisco","🔧 Taller","🏎️ Ciudad de Panamá","👥 Hasta 4 técnicos de TI"]:
		var l := Kit.label(c, 12, Color.WHITE)
		l.add_theme_stylebox_override("normal", Kit.sb(Color(1, 1, 1, .08), 12, 1, Color(1, 1, 1, .14), 6))
		chips.add_child(l)
	var s1 := _section(v, "TU TÉCNICO")
	name_in = LineEdit.new(); name_in.max_length = 14; name_in.placeholder_text = "Escribe tu nombre"; name_in.text = ST.name
	name_in.add_theme_stylebox_override("normal", Kit.sb(Color("#0b0710"), 10, 2, Kit.TEAL, 10))
	name_in.add_theme_stylebox_override("focus", Kit.sb(Color("#0b0710"), 10, 2, Kit.WARM, 10))
	name_in.add_theme_font_size_override("font_size", 16)
	name_in.text_changed.connect(func(t): ST.name = t; _save())
	s1.add_child(name_in)
	s1.add_child(Kit.label("Vista de cámara", 12, Color(1, 1, 1, .7)))
	var vh := HBoxContainer.new(); vh.add_theme_constant_override("separation", 6); s1.add_child(vh)
	for vv in [[1, "👁 Primera persona"], [3, "🧍 Tercera persona"]]:
		var b := Kit.button(vv[1], "", 14); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k: int = vv[0]
		b.pressed.connect(func(): ST.view = k; _save(); _style_view())
		vh.add_child(b); view_btns[k] = b
	_style_view()
	var s2 := _section(v, "EDITAR AVATAR")
	ed = VBoxContainer.new(); ed.add_theme_constant_override("separation", 8); s2.add_child(ed)
	_build_ed()
	var s3 := _section(v, "MULTIJUGADOR (MÁX. 4 DE TI)")
	if OS.has_feature("web"):
		# En el navegador no hay sockets UDP (ENet): el multijugador queda para la versión de escritorio.
		s3.add_child(Kit.label("En la versión web juegas solo. El multijugador en red local (hasta 4 técnicos) está en la versión de escritorio para Windows.", 13, Color(1, 1, 1, .72), false, true))
		mp_box = VBoxContainer.new(); mp_status = Label.new(); roster = Label.new()
	else:
		_build_mp(s3)
	var go := Kit.button("▶ Jugar · entrar a la oficina", "Warm", 18)
	go.custom_minimum_size.y = 56
	go.pressed.connect(_enter)
	go.focus_mode = Control.FOCUS_ALL
	fv.add_child(go)
	play_btn = go
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); fv.add_child(row)
	var cr := Kit.button("🎬 Créditos", "", 15); cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.pressed.connect(func(): credits_req.emit())
	row.add_child(cr)
	var qt := Kit.button("⏻ Salir", "", 15); qt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qt.pressed.connect(func(): get_tree().quit())
	row.add_child(qt)
	qt.visible = not OS.has_feature("web")  # en el navegador se cierra la pestaña
	fv.add_child(Kit.label("WASD mover · Shift correr · E interactuar · V cambiar vista · Enter chat · M mapa · P pausa · Tab menú", 12, Color(1, 1, 1, .6), false, true))


func _build_mp(s3: VBoxContainer) -> void:
	var mh := HBoxContainer.new(); mh.add_theme_constant_override("separation", 6); s3.add_child(mh)
	for mm in [["solo", "Solo"], ["host", "Crear sala"], ["join", "Unirme"]]:
		var b := Kit.button(mm[1], "", 14); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = mm[0]
		b.pressed.connect(func(): _set_mode(key))
		mh.add_child(b); mode_btns[key] = b
	mp_box = VBoxContainer.new(); mp_box.add_theme_constant_override("separation", 6); s3.add_child(mp_box)
	mp_status = Kit.label("", 13, Color(1, 1, 1, .8), false, true); s3.add_child(mp_status)
	roster = Kit.label("", 13, Color(1, 1, 1, .85), false, true); s3.add_child(roster)
	Net.status_changed.connect(func(m, bad): mp_status.text = m; mp_status.modulate = Color("#ff9a8a") if bad else Color.WHITE)
	Net.roster_changed.connect(_roster)
	_set_mode("solo")


func _section(v: VBoxContainer, t: String) -> VBoxContainer:
	var p := Kit.panel(Kit.sb(Color(1, 1, 1, .05), 14, 1, Color(1, 1, 1, .11), 14)); v.add_child(p)
	var s := VBoxContainer.new(); s.add_theme_constant_override("separation", 8); p.add_child(s)
	s.add_child(Kit.label(t, 13, Color("#9fc9de"), true))
	return s


func _style_view() -> void:
	for k in view_btns:
		var on: bool = k == ST.view
		view_btns[k].add_theme_stylebox_override("normal", Kit.sb(Kit.WARM if on else Color(1, 1, 1, .07), 10, 1, Color(1, 1, 1, .16), 10))
		view_btns[k].add_theme_color_override("font_color", Kit.INK if on else Color.WHITE)


func _build_ed() -> void:
	for c in ed.get_children(): c.queue_free()
	_sw("Color de piel", "skin", SKIN)
	_pl("Peinado", "hs", HS)
	_sw("Color de pelo", "hair", HAIR)
	_pl("Lentes", "gl", GL)
	_pl("Barba", "bd", BD)
	_pl("Ropa", "outfit", OUT)
	_sw("Color de ropa", "color", COLOR)
	_pl("Accesorio", "cap", [["🧢 Gorra negra", 1], ["Sin gorra", 0]])


func _sw(lab: String, k: String, arr: Array) -> void:
	ed.add_child(Kit.label(lab, 12, Color(1, 1, 1, .7)))
	var h := HFlowContainer.new(); h.add_theme_constant_override("h_separation", 6); ed.add_child(h)
	for c in arr:
		var b := Button.new(); b.custom_minimum_size = Vector2(30, 30); b.focus_mode = Control.FOCUS_NONE
		var on: bool = ST.av[k] == c
		b.add_theme_stylebox_override("normal", Kit.sb(Color(c), 15, 3 if on else 2, Color.WHITE if on else Color(1, 1, 1, .27), 0))
		b.add_theme_stylebox_override("hover", Kit.sb(Color(c).lightened(.1), 15, 2, Color.WHITE, 0))
		var cc: String = c
		b.pressed.connect(func(): ST.av[k] = cc; _chg())
		h.add_child(b)


func _pl(lab: String, k: String, arr: Array) -> void:
	ed.add_child(Kit.label(lab, 12, Color(1, 1, 1, .7)))
	var h := HFlowContainer.new(); h.add_theme_constant_override("h_separation", 6); h.add_theme_constant_override("v_separation", 6); ed.add_child(h)
	for it in arr:
		var on: bool = ST.av[k] == it[1]
		var b := Kit.button(it[0], "", 13)
		b.add_theme_stylebox_override("normal", Kit.sb(Kit.WARM if on else Color(1, 1, 1, .07), 14, 1, Color(1, 1, 1, .16), 7))
		b.add_theme_color_override("font_color", Kit.INK if on else Color.WHITE)
		var val = it[1]
		b.pressed.connect(func(): ST.av[k] = val; _chg())
		h.add_child(b)


func _chg() -> void:
	_save()
	_build_ed()
	avatar_changed.emit()


func _set_mode(m: String) -> void:
	mp_mode = m
	for k in mode_btns:
		mode_btns[k].theme_type_variation = "Warm" if k == m else ""
	for c in mp_box.get_children(): c.queue_free()
	Net.my_name = player_name(); Net.my_av = ST.av
	if m == "solo":
		Net.leave()
		mp_box.add_child(Kit.label("Juegas tú solo en la oficina. Crea una sala para invitar hasta 3 técnicos más en tu misma red.", 13, Color(1, 1, 1, .72), false, true))
	elif m == "host":
		Net.host()
		if Net.role == "host":
			var cl := Kit.label(Net.code, 34, Kit.WARM, true); cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cl.add_theme_stylebox_override("normal", Kit.sb(Color("#0b0710"), 10, 2, Kit.WARM, 8))
			mp_box.add_child(cl)
			var cp := Kit.button("📋 Copiar código", "", 13)
			cp.pressed.connect(func(): DisplayServer.clipboard_set(Net.code); cp.text = "✔ Copiado")
			mp_box.add_child(cp)
	else:
		Net.leave()
		var hb := HBoxContainer.new(); mp_box.add_child(hb)
		var ji := LineEdit.new(); ji.placeholder_text = "CÓDIGO o IP"; ji.max_length = 21; ji.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ji.add_theme_stylebox_override("normal", Kit.sb(Color("#0b0710"), 10, 2, Kit.TEAL, 8))
		hb.add_child(ji)
		var go := Kit.button("Conectar", "Warm", 13)
		go.pressed.connect(func(): Net.my_name = player_name(); Net.my_av = ST.av; Net.join(ji.text))
		ji.text_submitted.connect(func(t): Net.my_name = player_name(); Net.my_av = ST.av; Net.join(t))
		hb.add_child(go)
	_roster()


func _roster() -> void:
	if Net.role == "solo":
		roster.text = ""; return
	var names := ["⭐ %s (tú)" % player_name()]
	for id in Net.players: names.append("👤 " + str(Net.players[id].get("name", "Técnico")))
	roster.text = "\n".join(names) + "\n%d/%d técnicos conectados" % [names.size(), Net.MAX]


func _save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(ST))


func player_name() -> String:
	var n: String = ST.name.strip_edges()
	return n if n != "" else "Técnico"


## Rig del jugador según el avatar elegido.
func make_rig(nm: String) -> Rig:
	return rig_from(ST.av, nm)


static func rig_from(av: Dictionary, nm: String) -> Rig:
	var a := {"skin": "e0a97a", "hs": 0, "hair": "111111", "gl": 0, "bd": 0, "outfit": "anime", "color": "2f6f8f", "cap": 0}
	for k in a:
		if av.has(k): a[k] = av[k]
	for k in ["skin", "hair", "color"]:
		if not Color.html_is_valid(str(a[k])): a[k] = {"skin": "e0a97a", "hair": "111111", "color": "2f6f8f"}[k]
	if not str(a.outfit) in ["anime", "plain", "suit", "coat", "cyber", "armor"]: a.outfit = "anime"
	var o: String = str(a.outfit)
	var look := {"t": {"hair": int(a.hs), "glasses": int(a.gl), "beard": int(a.bd), "mouth": 1, "tie": false, "badge": false, "pack": false}, "outfit": o, "cap": int(a.cap) == 1}
	if o == "suit": look.pant = Color("#1f2a44")
	elif o != "anime": look.pant = Color("#111111")
	return Rig.create(Color(a.color), Color(a.skin), Color(a.hair), nm, look)


func _enter() -> void:
	if ST.name.strip_edges() == "":
		ST.name = "TI-%d" % randi_range(100, 999)
		name_in.text = ST.name
	_save()
	Net.my_name = player_name(); Net.my_av = ST.av
	visible = false
	enter.emit()
