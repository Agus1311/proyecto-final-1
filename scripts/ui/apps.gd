class_name Apps
extends RefCounted
## Aplicaciones del escritorio (port de AP.* del original).

static var connect_cb: Callable    # connect_cb(i) -> abre el escritorio remoto
static var vp := {"i": -1, "t": 0.0, "on": false, "who": "", "rw": false}


static func mount(k: String, body: Control, ctx, desk: Desktop) -> void:
	match k:
		"browser": browser(body, ctx)
		"connect": connect_app(body)
		"cmd": cmd(body, ctx)
		"tasks": tasks(body, ctx, desk)
		"mail": mail(body, ctx, desk)
		"files": files(body, ctx, desk)
		"vpn": vpn(body, ctx, desk)
		"notes": notes(body, ctx)
		"calc": calc(body)
		"sys": sys(body, ctx)
		"chat": chat(body, desk)
		"snake": snake(body)


# ---------------- utilidades ----------------
static func pc(ctx):
	return Game.st.pc[ctx] if ctx is int else null


static func scroll(body: Control, margin := 14) -> VBoxContainer:
	var sc := ScrollContainer.new()
	Kit.full_rect(sc)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, margin)
	sc.add_child(mc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	mc.add_child(v)
	return v


static func scroll_bottom(sc: ScrollContainer) -> void:
	await sc.get_tree().process_frame
	await sc.get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_vertical = 100000


static func lt(txt: String, size := 14, col := Color("#222222"), b := false) -> Label:
	return Kit.label(txt, size, col, b, true)


static func cell(txt: String, size := 13, col := Color("#222222"), b := false) -> Label:
	return Kit.label(txt, size, col, b, false)


static func btn(txt: String, size := 13) -> Button:
	var b := Kit.button(txt, "", size)
	b.add_theme_stylebox_override("normal", Kit.sb(Color("#f4f5f8"), 6, 1, Color("#99aaaa"), 6))
	b.add_theme_stylebox_override("hover", Kit.sb(Color("#dfe6f2"), 6, 1, Color("#99aaaa"), 6))
	b.add_theme_stylebox_override("pressed", Kit.sb(Color("#c9d6ef"), 6, 1, Color("#99aaaa"), 6))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("#222222"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


static func link(txt: String, cb: Callable, size := 16) -> Button:
	var b := Button.new()
	b.text = txt
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Kit.reg())
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("#1a5fc8"))
	b.add_theme_color_override("font_hover_color", Color("#0b3f9a"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	return b


static func table(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6)
	return g


static func mm(n: float) -> String:
	return "%d:%02d" % [int(n) / 60, int(n) % 60]


static func gid(id) -> String:
	var s := str(id)
	var out := ""
	for i in s.length():
		if i > 0 and i % 3 == 0: out += " "
		out += s[i]
	return out


static func term_box(body: Control, text_get: Callable, text_set: Callable, prompt: String, on_cmd: Callable) -> void:
	var v := VBoxContainer.new(); Kit.full_rect(v); v.add_theme_constant_override("separation", 0); body.add_child(v)
	var bgp := Kit.panel(Kit.sb(Color("#05080c"), 0, 0, Color.TRANSPARENT, 10))
	bgp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(bgp)
	var out := RichTextLabel.new()
	out.scroll_following = true
	out.selection_enabled = true
	out.add_theme_font_override("normal_font", Kit.mono())
	out.add_theme_font_size_override("normal_font_size", 13)
	out.add_theme_color_override("default_color", Color("#cfe8d5"))
	out.text = text_get.call()
	bgp.add_child(out)
	var lp := Kit.panel(Kit.sb(Color("#05080c"), 0, 0, Color.TRANSPARENT, 8))
	v.add_child(lp)
	var h := HBoxContainer.new(); lp.add_child(h)
	var pl := Label.new(); pl.text = prompt
	pl.add_theme_font_override("font", Kit.mono()); pl.add_theme_font_size_override("font_size", 13); pl.add_theme_color_override("font_color", Color("#cfe8d5"))
	h.add_child(pl)
	var inp := LineEdit.new()
	inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inp.add_theme_font_override("font", Kit.mono())
	inp.add_theme_font_size_override("font_size", 14)
	inp.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	inp.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	h.add_child(inp)
	inp.text_submitted.connect(func(val: String):
		inp.text = ""
		var r: String = on_cmd.call(val)
		if r == "\f":
			text_set.call(""); out.text = ""
		else:
			text_set.call(text_get.call() + prompt + val + "\n" + r + "\n")
			out.text = text_get.call()
		inp.grab_focus())
	inp.call_deferred("grab_focus")


# ---------------- Navegador ----------------
static func browser(body: Control, ctx) -> void:
	var key := str(ctx)
	if not Game.br.has(key):
		Game.br[key] = {"u": "home", "h": []}
	var b: Dictionary = Game.br[key]
	var v := VBoxContainer.new(); Kit.full_rect(v); v.add_theme_constant_override("separation", 0); body.add_child(v)
	var bar := Kit.panel(Kit.sb(Color("#e4e6ec"), 0, 0, Color.TRANSPARENT, 8))
	v.add_child(bar)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); bar.add_child(h)
	var page := Kit.panel(Kit.sb(Color.WHITE, 0, 0, Color.TRANSPARENT, 0))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(page)
	var addr := LineEdit.new()
	var go := func(u: String):
		b.h.append(b.u); b.u = u
		_render_page(page, ctx, b, addr)
	var back := btn("◀"); back.pressed.connect(func(): b.u = b.h.pop_back() if b.h.size() else "home"; _render_page(page, ctx, b, addr))
	var home := btn("⌂"); home.pressed.connect(func(): go.call("home"))
	h.add_child(back); h.add_child(home)
	addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	addr.placeholder_text = "Escribe una dirección o busca"
	addr.add_theme_stylebox_override("normal", Kit.sb(Color.WHITE, 14, 1, Color("#bbbbbb"), 6))
	addr.add_theme_stylebox_override("focus", Kit.sb(Color.WHITE, 14, 1, Kit.TEAL, 6))
	addr.add_theme_color_override("font_color", Color("#222222"))
	var submit := func():
		var val := addr.text.strip_edges()
		if val != "":
			go.call(val if (val.contains(".") and not val.contains(" ")) else "buscar:" + val)
	addr.text_submitted.connect(func(_t): submit.call())
	h.add_child(addr)
	var gb := btn("Ir"); gb.pressed.connect(submit); h.add_child(gb)
	page.set_meta("go", go)
	_render_page(page, ctx, b, addr)


static func _render_page(page: Control, ctx, b: Dictionary, addr: LineEdit) -> void:
	for c in page.get_children(): c.queue_free()
	addr.text = "" if b.u == "home" else b.u
	var go: Callable = page.get_meta("go")
	var v := scroll(page, 16)
	var u: String = str(b.u).strip_edges().to_lower().trim_prefix("https://").trim_prefix("http://")
	var nf := func(): v.add_child(lt("No se puede acceder a este sitio", 20, Color("#222222"), true)); v.add_child(lt(u + " no responde."))
	var res := func(t: String, url: String, d := ""):
		v.add_child(link(t, func(): go.call(url), 17))
		v.add_child(lt(url, 12, Color("#2a7a3a")))
		if d != "": v.add_child(lt(d, 13))
	if u == "home" or u == "":
		v.add_child(lt("Buscador", 26, Color("#222222"), true))
		var h := HBoxContainer.new(); v.add_child(h)
		var q := LineEdit.new(); q.custom_minimum_size.x = 340; q.placeholder_text = "Buscar en la web..."
		q.add_theme_stylebox_override("normal", Kit.sb(Color.WHITE, 8, 1, Color("#bbbbbb"), 8)); q.add_theme_color_override("font_color", Color("#222222"))
		q.text_submitted.connect(func(t): if t.strip_edges() != "": go.call("buscar:" + t.strip_edges()))
		h.add_child(q)
		var sb := btn("Buscar"); sb.pressed.connect(func(): if q.text.strip_edges() != "": go.call("buscar:" + q.text.strip_edges()))
		h.add_child(sb)
		var qk := HFlowContainer.new(); v.add_child(qk)
		for x in [["▶ YouTube","youtube.com"],["📰 Noticias","noticias.pa"],["📚 Wiki CAA","wiki.caacorp.com"],["🌦️ Clima","clima.pa"],["📘 Guías TI","guias.caacorp.com"],["💬 Foro IT","foro.soporte.pa"]]:
			var bb := btn(x[0]); var url: String = x[1]; bb.pressed.connect(func(): go.call(url)); qk.add_child(bb)
		return
	if u.begins_with("buscar:"):
		var q := u.substr(7)
		v.add_child(lt("Resultados para “%s”" % q, 15, Color("#222222"), true))
		var n := 0
		var rx := func(p: String): return RegEx.create_from_string(p).search(q) != null
		if rx.call("youtube|video|musica|lofi|gato"): res.call("YouTube — Videos populares", "youtube.com", "Tutoriales, música y más."); n += 1
		if rx.call("cisco|vlan|ccna|switch"): res.call("Tutorial: VLANs en Cisco en 10 minutos", "youtube.com/watch?v=0", "Video · Redes Academy"); res.call("Wiki CAA: guía del switch core", "wiki.caacorp.com"); n += 1
		if rx.call("phishing|correo|seguridad"): res.call("Cómo detectar un correo de phishing", "youtube.com/watch?v=2", "Video · Ciberseguridad PA"); n += 1
		if rx.call("respaldo|backup"): res.call("Regla de respaldo 3-2-1", "youtube.com/watch?v=6", "Video · Backup Pro"); res.call("Guía: respaldos 3-2-1", "guias.caacorp.com/2"); n += 1
		if rx.call("mfa|autentic|contrase"): res.call("MFA: por qué importa", "youtube.com/watch?v=7", "Video · Ciberseguridad PA"); res.call("Guía: política de contraseñas", "guias.caacorp.com/0"); n += 1
		if rx.call("dns|dhcp|red"): res.call("DHCP y DNS explicados", "youtube.com/watch?v=8", "Video · Redes Academy"); n += 1
		if rx.call("bios|hardware|pc"): res.call("Cómo armar y diagnosticar una PC", "youtube.com/watch?v=9", "Video · Hardware Lab"); n += 1
		if rx.call("foro|ayuda|error"): res.call("Foro de soporte IT", "foro.soporte.pa"); n += 1
		if rx.call("guia|guía|buenas|practica|prácticas"): res.call("Guías técnicas de CAA Corp", "guias.caacorp.com"); n += 1
		if rx.call("noticia|ciber|tecnolog"): res.call("Noticias de tecnología", "noticias.pa"); n += 1
		if rx.call("clima|lluvia"): res.call("Clima en Panamá", "clima.pa"); n += 1
		if n == 0: v.add_child(lt("Sin resultados. Prueba con: youtube, cisco, phishing, noticias, clima."))
		return
	if u == "youtube.com":
		v.add_child(lt("▶ YouTube  (versión simulada del juego)", 20, Color("#222222"), true))
		var g := HFlowContainer.new(); g.add_theme_constant_override("h_separation", 10); g.add_theme_constant_override("v_separation", 10); v.add_child(g)
		for i in Data.VIDS.size():
			var vd: Array = Data.VIDS[i]
			var card := Button.new(); card.focus_mode = Control.FOCUS_NONE
			card.custom_minimum_size = Vector2(170, 150)
			card.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			card.add_theme_stylebox_override("hover", Kit.sb(Color(0, 0, 0, .06), 8, 0, Color.TRANSPARENT, 0))
			var cv := VBoxContainer.new(); cv.mouse_filter = Control.MOUSE_FILTER_IGNORE; Kit.full_rect(cv); card.add_child(cv)
			var th := Kit.panel(Kit.sb(Color("#222222"), 8, 0, Color.TRANSPARENT, 12)); th.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ic := Kit.label(vd[1], 36, Color.WHITE); ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; th.add_child(ic); cv.add_child(th)
			var tl := lt(vd[0], 13, Color("#222222"), true); tl.mouse_filter = Control.MOUSE_FILTER_IGNORE; cv.add_child(tl)
			var sm := lt(vd[4] + " · " + mm(vd[2]), 11, Color("#555555")); sm.mouse_filter = Control.MOUSE_FILTER_IGNORE; cv.add_child(sm)
			var url := "youtube.com/watch?v=%d" % i
			card.pressed.connect(func(): go.call(url))
			g.add_child(card)
		return
	var m := RegEx.create_from_string("^youtube\\.com/watch\\?v=(\\d+)$").search(u)
	if m:
		var i := int(m.get_string(1))
		if i >= Data.VIDS.size(): nf.call(); return
		var view := VideoView.new()
		view.vid = i
		view.who = str(ctx)
		v.add_child(view)
		var vd: Array = Data.VIDS[i]
		v.add_child(lt(vd[0], 18, Color("#222222"), true))
		v.add_child(lt(vd[4], 12, Color("#555555")))
		v.add_child(link("← Más videos", func(): go.call("youtube.com"), 14))
		return
	if u == "guias.caacorp.com":
		v.add_child(lt("📘 Guías técnicas de CAA Corp", 20, Color("#222222"), true))
		for i in Data.GU.size(): res.call(Data.GU[i][0], "guias.caacorp.com/%d" % i, "Buenas prácticas de TI")
		return
	var gm := RegEx.create_from_string("^guias\\.caacorp\\.com/(\\d+)$").search(u)
	if gm and int(gm.get_string(1)) < Data.GU.size():
		var gi := int(gm.get_string(1))
		v.add_child(lt("📘 " + Data.GU[gi][0], 20, Color("#222222"), true))
		v.add_child(lt(Data.GU[gi][1], 15))
		v.add_child(link("← Todas las guías", func(): go.call("guias.caacorp.com"), 14))
		if ctx is String: Game.guide_read(gi)
		return
	if u == "foro.soporte.pa":
		v.add_child(lt("💬 Foro de soporte IT", 20, Color("#222222"), true))
		for f in Data.FO:
			var ans := lt(f[1], 14); ans.visible = false
			var q := link("▸ " + f[0], func(): ans.visible = not ans.visible, 15)
			v.add_child(q); v.add_child(ans)
		return
	if u == "noticias.pa":
		v.add_child(lt("📰 Noticias", 20, Color("#222222"), true))
		for n2 in [["Aumentan los ataques de phishing en la región","Expertos recomiendan activar MFA en todas las cuentas."],["Nuevo parche crítico para servidores Windows","Se pide aplicarlo en ventanas de mantenimiento."],["Empresas apuestan por respaldos inmutables","Una defensa clave contra el ransomware."]]:
			v.add_child(lt(n2[0], 16, Color("#222222"), true)); v.add_child(lt(n2[1], 14))
		return
	if u == "clima.pa":
		v.add_child(lt("🌦️ Clima en Ciudad de Panamá", 20, Color("#222222"), true))
		v.add_child(lt("31 °C · Parcialmente nublado", 32, Color("#222222"), true))
		v.add_child(lt("Probabilidad de lluvia por la tarde: 60%", 14))
		return
	if u == "wiki.caacorp.com":
		if ctx is String or Game.st.pc[ctx].vpn:
			v.add_child(lt("📚 Wiki de CAA Corp", 20, Color("#222222"), true))
			for it in ["Alta y baja de empleados","Procedimiento de VPN","Configuración de switches Cisco","Política de contraseñas"]: v.add_child(lt("•  " + it, 15))
		else:
			v.add_child(lt("🔒 Acceso restringido", 20, Color("#222222"), true))
			v.add_child(lt("Conéctate a la VPN CAA OneConnect para ver la wiki interna.", 15))
		return
	nf.call()


# ---------------- Reproductor de video ----------------
class VideoView:
	extends VBoxContainer
	var vid := 0
	var who := ""
	var canvas: Control
	var bar: ProgressBar
	var play_b: Button
	var time_l: Label
	var _note_t := 0.0
	var _n := 0

	func _ready() -> void:
		var st: Dictionary = Apps.vp
		if st.i != vid or st.who != who:
			Apps.vp = {"i": vid, "t": 0.0, "on": false, "who": who, "rw": false}
		canvas = Control.new()
		canvas.custom_minimum_size = Vector2(520, 292)
		canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		canvas.draw.connect(_draw_video)
		add_child(canvas)
		bar = Kit.bar(Color("#dd2222")); bar.custom_minimum_size = Vector2(520, 5); bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		add_child(bar)
		var h := HBoxContainer.new(); add_child(h)
		play_b = Apps.btn("▶ Reproducir"); play_b.pressed.connect(_toggle); h.add_child(play_b)
		time_l = Apps.cell("", 13, Color("#333333")); h.add_child(time_l)
		_ui()

	func _toggle() -> void:
		Apps.vp.on = not Apps.vp.on
		_ui()

	func _ui() -> void:
		var d: float = Data.VIDS[vid][2]
		time_l.text = Apps.mm(Apps.vp.t) + " / " + Apps.mm(d)
		bar.value = Apps.vp.t / d * 100
		play_b.text = "⏸ Pausar" if Apps.vp.on else "▶ Reproducir"

	func _exit_tree() -> void:
		Apps.vp.on = false

	func _process(dt: float) -> void:
		if not is_visible_in_tree():
			Apps.vp.on = false
			return
		var vp: Dictionary = Apps.vp
		if vp.on:
			vp.t += dt
			var d: float = Data.VIDS[vid][2]
			if vp.t >= d: vp.t = d; vp.on = false
			if who == "me" and vp.t >= 15 and not vp.rw:
				vp.rw = true
				Game.vid_reward(vid)
			_note_t += dt
			if _note_t > .42:
				_note_t = 0
				var sc := [220, 247, 277, 330, 370, 440, 495]
				Game.beep(sc[(_n * 3 + vid) % 7] * (.5 if _n % 4 == 0 else 1.0), .6, "sine")
				_n += 1
		canvas.queue_redraw()
		_ui()

	func _draw_video() -> void:
		var w := 520.0
		var h := 292.0
		var ti := Time.get_ticks_msec() / 1000.0
		var on: bool = Apps.vp.on
		var hue := fmod(vid * 55 + ti * 8, 360) / 360.0
		var c0 := Color.from_hsv(hue, .7, .3)
		var c1 := Color.from_hsv(fmod(hue + .166, 1.0), .75, .16)
		canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([c0, c0.lerp(c1, .5), c1, c0.lerp(c1, .5)]))
		for k in 3:
			var pts := PackedVector2Array()
			for px in range(0, int(w) + 1, 8):
				pts.append(Vector2(px, h * .72 + sin(px / 40.0 + ti * (2.0 if on else .3) + k) * 14 * (k + 1) / 2.0))
			canvas.draw_polyline(pts, Color(1, 1, 1, .33), 2, true)
		var vd: Array = Data.VIDS[vid]
		CanvasTex.text(canvas, vd[1], Vector2(w / 2, h * .45 + (sin(ti * 3) * 12 if on else 0.0)), 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		CanvasTex.text(canvas, vd[0], Vector2(w / 2, h - 14), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		var cp: Array = vd[5]
		var ci := mini(cp.size() - 1, int(floor(Apps.vp.t / 6.0)))
		canvas.draw_rect(Rect2(0, h - 64, w, 26), Color(0, 0, 0, .55))
		CanvasTex.text(canvas, cp[ci], Vector2(w / 2, h - 46), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, -1, false)
		if not on:
			canvas.draw_circle(Vector2(w / 2, h / 2), 32, Color(0, 0, 0, .53))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(w / 2 - 10, h / 2 - 16), Vector2(w / 2 + 16, h / 2), Vector2(w / 2 - 10, h / 2 + 16)]), Color.WHITE)


# ---------------- CAA Connect ----------------
static func connect_app(body: Control) -> void:
	var v := scroll(body)
	v.add_child(lt("CAA Connect — Acceso remoto", 18, Color("#222222"), true))
	var idp := Kit.panel(Kit.sb(Color.WHITE, 8, 0, Color.TRANSPARENT, 10)); v.add_child(idp)
	idp.add_child(lt("Tu ID: 482 913 057 · PC-SOPORTE01", 14, Color("#222222"), true))
	var h := HBoxContainer.new(); v.add_child(h)
	h.add_child(lt("Conectar con ID remoto:", 14))
	var rid := LineEdit.new(); rid.placeholder_text = "123 456 789"; rid.custom_minimum_size.x = 150
	rid.add_theme_stylebox_override("normal", Kit.sb(Color.WHITE, 6, 1, Color("#bbbbbb"), 6)); rid.add_theme_color_override("font_color", Color("#222222"))
	h.add_child(rid)
	var cb := btn("Conectar"); h.add_child(cb)
	cb.pressed.connect(func():
		var val := RegEx.create_from_string("\\D").sub(rid.text, "", true)
		for i in Game.st.pc.size():
			if str(Game.st.pc[i].id) == val:
				connect_rd(i); return
		Game.toast("ID remoto no encontrado"))
	var t := table(5); v.add_child(t)
	for hd in ["Usuario", "Equipo", "ID", "Estado", ""]:
		t.add_child(cell(hd, 13, Color("#222222"), true))
	for i in Data.USERS.size():
		var u: Array = Data.USERS[i]
		var p: Dictionary = Game.st.pc[i]
		t.add_child(cell(u[1] + "\n" + u[2], 13))
		t.add_child(cell(p.name + "\n" + p.ip, 13))
		t.add_child(cell(gid(p.id), 13))
		t.add_child(cell("● En línea" if p.online else "○ Apagado", 13, Kit.OK if p.online else Color("#888888")))
		var b := btn("Conectar"); var ii: int = i
		b.pressed.connect(func(): connect_rd(ii))
		t.add_child(b)


static func connect_rd(i: int) -> void:
	var p: Dictionary = Game.st.pc[i]
	var n: String = Data.USERS[i][1]
	if not p.online:
		Game.toast(n + ": equipo apagado o sin conexión"); return
	Game.toast("Solicitando conexión a " + n + "…")
	await (Engine.get_main_loop() as SceneTree).create_timer(.9).timeout
	Game.toast("✔ " + n + " aceptó la conexión")
	if connect_cb.is_valid():
		connect_cb.call(i, false)


# ---------------- Símbolo del sistema ----------------
static func cmd(body: Control, ctx) -> void:
	var p = pc(ctx)
	var pr: String = "C:\\Users\\" + (Data.USERS[ctx][0] if p else "soporte") + ">"
	var intro := "Microsoft Windows [Versión 10.0.19045]\n(c) Microsoft Corporation. Todos los derechos reservados.\nEscribe help para ver los comandos.\n"
	var holder: Dictionary = p if p else Game.st
	var kk := "cmd" if p else "cmd_me"
	if str(holder.get(kk, "")) == "":
		holder[kk] = intro
	term_box(body, func(): return holder[kk], func(t): holder[kk] = t, pr, func(val): return Game.cmd_exec(val, ctx))


# ---------------- Administrador de tareas ----------------
static func tasks(body: Control, ctx, desk: Desktop) -> void:
	var p = pc(ctx)
	var L: Array = p.procs if p else Data.LOCALPROCS
	var v := scroll(body)
	var t := table(5); v.add_child(t)
	for hd in ["Nombre", "CPU", "Memoria", "Estado", ""]:
		t.add_child(cell(hd, 13, Color("#222222"), true))
	for k in L.size():
		var x: Dictionary = L[k]
		var hot: bool = x.get("frozen", false) or x.get("mal", false)
		var col := Color("#b03030") if hot else Color("#222222")
		t.add_child(cell(x.n, 13, col, hot))
		t.add_child(cell(str(x.cpu) + "%", 13, col))
		t.add_child(cell(str(x.mem) + " MB", 13, col))
		t.add_child(cell("No responde" if x.get("frozen", false) else ("Sospechoso" if x.get("mal", false) else "En ejecución"), 13, col))
		if p:
			var b := btn("Finalizar tarea", 12)
			var nm: String = x.n
			b.pressed.connect(func(): Game.kill_proc(ctx, nm); desk.refresh(["tasks"]))
			t.add_child(b)
		else:
			t.add_child(Control.new())


# ---------------- Correo del usuario remoto ----------------
static func mail(body: Control, ctx, desk: Desktop) -> void:
	var p: Dictionary = pc(ctx)
	var h := HBoxContainer.new(); Kit.full_rect(h); h.add_theme_constant_override("separation", 0); body.add_child(h)
	var side := Kit.panel(Kit.sb(Color("#f4f5f8"), 0, 0, Color.TRANSPARENT, 8)); side.custom_minimum_size.x = 180; h.add_child(side)
	var sv := VBoxContainer.new(); side.add_child(sv)
	var cnt := func(f): return p.mail.filter(func(m): return m.f == f).size()
	var sbtn := func(a: Array):
		var b := Button.new(); b.flat = p.mf != a[0]; b.focus_mode = Control.FOCUS_NONE
		b.text = "%s %s  (%d)" % [a[2], a[1], cnt.call(a[0])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", Color("#222222")); b.add_theme_color_override("font_hover_color", Color("#222222"))
		b.add_theme_stylebox_override("normal", Kit.sb(Color("#c9d6ef"), 6, 0, Color.TRANSPARENT, 6))
		var f: String = a[0]
		b.pressed.connect(func(): p.mf = f; p.mm = -1; desk.refresh(["mail"]))
		sv.add_child(b)
	for a in [["general","General","⭐"],["important","Important","❗"],["deleted","Deleted","❌"]]: sbtn.call(a)
	sv.add_child(lt("Category", 12, Color("#777777")))
	for a in [["task","Task","🖥️"],["jobs","Job offers","💼"],["spam","Spam","⚠️"]]: sbtn.call(a)
	var main := Control.new(); main.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(main)
	var v := scroll(main)
	if p.mm >= 0:
		var sel: Dictionary = p.mail[p.mm]
		var bk := btn("◀ Volver"); bk.pressed.connect(func(): p.mm = -1; desk.refresh(["mail"])); v.add_child(bk)
		var hh := HBoxContainer.new(); v.add_child(hh)
		hh.add_child(Kit.label("👩🏽", 34))
		hh.add_child(lt("%s\nFrom: %s\nTo: %s" % [sel.n, sel.a, p.addr], 13))
		v.add_child(HSeparator.new())
		v.add_child(lt(sel.s, 18, Color("#222222"), true))
		var rt := RichTextLabel.new(); rt.bbcode_enabled = true; rt.fit_content = true
		rt.add_theme_color_override("default_color", Color("#222222")); rt.add_theme_font_size_override("normal_font_size", 14)
		rt.text = sel.b
		v.add_child(rt)
		if sel.att != "":
			var ab := btn("📄 Descargar " + sel.att); ab.pressed.connect(func(): Game.toast("Descargando archivo adjunto…")); v.add_child(ab)
	else:
		var any := false
		for k in p.mail.size():
			var m: Dictionary = p.mail[k]
			if m.f != p.mf: continue
			any = true
			var b := btn(m.s + "\n" + m.n, 13); b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var kk: int = k
			b.pressed.connect(func(): p.mm = kk; desk.refresh(["mail"]))
			v.add_child(b)
		if not any: v.add_child(lt("Carpeta vacía"))


# ---------------- Descargas ----------------
static func files(body: Control, ctx, desk: Desktop) -> void:
	var p: Dictionary = pc(ctx)
	var v := scroll(body, 16)
	v.add_child(lt("📁 Descargas", 18, Color("#222222"), true))
	for k in p.files.size():
		var h := HBoxContainer.new(); v.add_child(h)
		var l := lt("📄 " + p.files[k], 14); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		var b := btn("Eliminar"); var kk: int = k
		b.pressed.connect(func():
			var f: String = p.files[kk]
			p.files.remove_at(kk)
			if kk == p.bad:
				p.bad = -1; Game.st.earn += 15; Game.bump(0, 6, "✔ Archivo malicioso eliminado: " + f)
			else:
				if p.bad > kk: p.bad -= 1
				Game.bump(-4, 0, "Eliminaste un archivo legítimo del usuario")
			Game.adv(5)
			desk.refresh(["files"]))
		h.add_child(b)
		v.add_child(HSeparator.new())
	if p.files.is_empty(): v.add_child(lt("Sin archivos."))
	v.add_child(lt("Revisa los archivos descargados en busca de software sospechoso.", 12, Color("#666666")))


# ---------------- VPN ----------------
static func vpn(body: Control, ctx, desk: Desktop) -> void:
	var p: Dictionary = pc(ctx)
	var v := scroll(body, 16)
	v.add_child(lt("🛡️ CAA OneConnect", 18, Color("#222222"), true))
	v.add_child(lt("Estado: " + ("Conectado" if p.vpn else "Desconectado"), 15, Kit.OK if p.vpn else Color("#222222"), true))
	var b := btn("Desconectar" if p.vpn else "Conectar a la VPN")
	b.pressed.connect(func(): p.vpn = not p.vpn; Game.adv(2); desk.refresh(["vpn", "browser"]))
	v.add_child(b)
	v.add_child(lt("Necesaria para abrir la wiki interna.", 12, Color("#666666")))


# ---------------- Notas ----------------
static func notes(body: Control, ctx) -> void:
	var p = pc(ctx)
	var t := TextEdit.new()
	Kit.full_rect(t)
	t.placeholder_text = "Anota IPs, usuarios, pendientes…"
	t.add_theme_font_override("font", Kit.mono())
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_stylebox_override("normal", Kit.sb(Color("#fffef6"), 0, 0, Color.TRANSPARENT, 12))
	t.add_theme_stylebox_override("focus", Kit.sb(Color("#fffef6"), 0, 0, Color.TRANSPARENT, 12))
	t.add_theme_color_override("font_color", Color("#222222"))
	t.add_theme_color_override("caret_color", Color("#222222"))
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.text = p.note if p else str(Game.G.get("note", ""))
	t.text_changed.connect(func():
		if p: p.note = t.text
		else:
			Game.G.note = t.text; Game.save())
	body.add_child(t)


# ---------------- Calculadora ----------------
static func calc_eval(s: String) -> float:
	var rx := RegEx.create_from_string("\\d+\\.?\\d*|[()+\\-*/]")
	var toks: Array = rx.search_all(s).map(func(m): return m.get_string())
	var o: Array = []
	var v: Array = []
	var pr := {"+": 1, "-": 1, "*": 2, "/": 2}
	var ap := func():
		var op: String = o.pop_back(); var b: float = v.pop_back() if v.size() else 0.0; var a: float = v.pop_back() if v.size() else 0.0
		v.append(a + b if op == "+" else (a - b if op == "-" else (a * b if op == "*" else (a / b if b != 0 else INF))))
	var prev := ""
	for k in toks:
		if k[0] >= "0" and k[0] <= "9":
			v.append(float(k))
		elif k == "(":
			o.append(k)
		elif k == ")":
			while o.size() and o.back() != "(": ap.call()
			if o.size(): o.pop_back()
		else:
			if k == "-" and (prev == "" or "(+-*/".contains(prev)): v.append(0.0)
			while o.size() and o.back() != "(" and pr[o.back()] >= pr[k]: ap.call()
			o.append(k)
		prev = k
	while o.size():
		if o.back() == "(": o.pop_back()
		else: ap.call()
	return v[0] if v.size() else 0.0


static func calc(body: Control) -> void:
	var v := VBoxContainer.new(); Kit.full_rect(v); body.add_child(v)
	var mc := MarginContainer.new(); mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]: mc.add_theme_constant_override("margin_" + s, 10)
	v.add_child(mc)
	var vv := VBoxContainer.new(); mc.add_child(vv)
	var disp := LineEdit.new(); disp.editable = false; disp.text = "0"; disp.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	disp.add_theme_font_size_override("font_size", 24)
	disp.add_theme_stylebox_override("read_only", Kit.sb(Color.WHITE, 6, 1, Color("#bbbbbb"), 10))
	disp.add_theme_color_override("font_uneditable_color", Color("#222222"))
	vv.add_child(disp)
	var g := GridContainer.new(); g.columns = 4; g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 6); g.add_theme_constant_override("v_separation", 6)
	vv.add_child(g)
	var state := {"s": ""}
	for k in "7 8 9 / 4 5 6 * 1 2 3 - 0 . = + C".split(" "):
		var b := btn(k, 18); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var key: String = k
		b.pressed.connect(func():
			if key == "C": state.s = ""
			elif key == "=":
				var r := calc_eval(state.s)
				state.s = ("%.6f" % r).rstrip("0").rstrip(".") if is_finite(r) else "Error"
			else:
				state.s = ("" if state.s == "Error" else state.s) + key
			disp.text = state.s if state.s != "" else "0")
		g.add_child(b)


# ---------------- Este equipo ----------------
static func sys(body: Control, ctx) -> void:
	var p = pc(ctx)
	var disk := 97 if p and p.iss.has("temp") else 46
	var cpu := 12
	if p and p.procs.any(func(x): return x.get("frozen", false)): cpu = 97
	elif p and p.procs.any(func(x): return x.get("mal", false)): cpu = 64
	var v := scroll(body, 16)
	v.add_child(lt("💻 Este equipo", 18, Color("#222222"), true))
	v.add_child(lt("Nombre: %s\nSistema: Windows 10 Pro 22H2 (simulado)\nProcesador: Intel Core i5 · 16 GB RAM\nIPv4: %s\nDominio: caacorp.local" % [p.name if p else "PC-SOPORTE01", p.ip if p else "192.168.10.55"], 14))
	for a in [["CPU", cpu], ["Disco C:", disk], ["Memoria", 58 if p else 34]]:
		v.add_child(lt("%s %d%%" % [a[0], a[1]], 13))
		var b := Kit.bar(Color("#dd2222") if a[1] > 90 else Color("#2a8fe0")); b.value = a[1]; b.custom_minimum_size = Vector2(380, 6)
		v.add_child(b)


# ---------------- Chat del equipo ----------------
static func chat(body: Control, desk: Desktop) -> void:
	var v := VBoxContainer.new(); Kit.full_rect(v); v.add_theme_constant_override("separation", 0); body.add_child(v)
	var lp := Control.new(); lp.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(lp)
	var lv := scroll(lp, 10)
	for m in Game.chat:
		var pnl := Kit.panel(Kit.sb(Color.WHITE, 8, 0, Color.TRANSPARENT, 8)); lv.add_child(pnl)
		pnl.add_child(lt("%s  ·  %s\n%s" % [m.n, m.t, m.x], 13))
	scroll_bottom(lv.get_parent().get_parent())
	var bar := Kit.panel(Kit.sb(Color("#e4e6ec"), 0, 0, Color.TRANSPARENT, 8)); v.add_child(bar)
	var h := HBoxContainer.new(); bar.add_child(h)
	var inp := LineEdit.new(); inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; inp.placeholder_text = "Escribe un mensaje…"
	inp.add_theme_stylebox_override("normal", Kit.sb(Color.WHITE, 14, 1, Color("#bbbbbb"), 7)); inp.add_theme_color_override("font_color", Color("#222222"))
	h.add_child(inp)
	var send := func():
		var val := inp.text.strip_edges()
		if val == "": return
		Game.chat.append({"n": "Yo (TI)", "t": Game.clock_str(), "x": val})
		desk.refresh(["chat"])
		await (Engine.get_main_loop() as SceneTree).create_timer(1.2).timeout
		var rep: String = "Te lo dejé en Zoho, gracias 🙏" if RegEx.create_from_string("(?i)ticket|ayuda|pc|compu").search(val) else ["Jajaja 😄", "Ok, gracias", "Recibido 👍", "Ahora no puedo, estoy en el café ☕"].pick_random()
		Game.chat.append({"n": Data.CHAT_NAMES.pick_random(), "t": Game.clock_str(), "x": rep})
		if is_instance_valid(desk): desk.refresh(["chat"])
	inp.text_submitted.connect(func(_t): send.call())
	var sb := Kit.button("Enviar", "", 13); sb.add_theme_stylebox_override("normal", Kit.sb(Kit.TEAL, 14, 0, Color.TRANSPARENT, 7)); sb.pressed.connect(send)
	h.add_child(sb)
	inp.call_deferred("grab_focus")


# ---------------- Snake ----------------
static func snake(body: Control) -> void:
	var g := SnakeGame.new()
	Kit.full_rect(g)
	body.add_child(g)


class SnakeGame:
	extends Control
	var sn: Array = [Vector2i(8, 8)]
	var d := Vector2i(1, 0)
	var f := Vector2i(12, 8)
	var pts := 0
	var _t := 0.0

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		call_deferred("grab_focus")
		gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: grab_focus())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed:
			var m := Vector2i.ZERO
			match e.physical_keycode:
				KEY_UP, KEY_W: m = Vector2i(0, -1)
				KEY_DOWN, KEY_S: m = Vector2i(0, 1)
				KEY_LEFT, KEY_A: m = Vector2i(-1, 0)
				KEY_RIGHT, KEY_D: m = Vector2i(1, 0)
			if m != Vector2i.ZERO and m != -d:
				d = m
			accept_event()

	func _process(dt: float) -> void:
		_t += dt
		if _t < .13: return
		_t = 0
		var hd: Vector2i = sn[0] + d
		if hd.x < 0 or hd.y < 0 or hd.x > 15 or hd.y > 15 or sn.has(hd):
			sn = [Vector2i(8, 8)]; d = Vector2i(1, 0); pts = 0
		else:
			sn.push_front(hd)
			if hd == f:
				pts += 1
				if pts == 5 and not Game.st.get("snake", false):
					Game.st.snake = true; Game.G.xp = int(Game.G.xp) + 2; Game.toast("🐍 +2 XP por despejar la mente")
				f = Vector2i(randi() % 16, randi() % 16)
			else:
				sn.pop_back()
		queue_redraw()

	func _draw() -> void:
		var cell := floorf(minf(size.x, size.y - 30) / 16.0)
		var o := Vector2((size.x - cell * 16) / 2, 8)
		draw_rect(Rect2(o, Vector2(cell * 16, cell * 16)), Color("#0b1118"))
		draw_rect(Rect2(o + Vector2(f) * cell, Vector2(cell - 2, cell - 2)), Color("#e8a77c"))
		for s in sn:
			draw_rect(Rect2(o + Vector2(s) * cell, Vector2(cell - 2, cell - 2)), Color("#4c9a6a"))
		draw_string(Kit.reg(), Vector2(o.x, o.y + cell * 16 + 20), "Flechas / WASD · Puntos: %d" % pts, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#222222"))
