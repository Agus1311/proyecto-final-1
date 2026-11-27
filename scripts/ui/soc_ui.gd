class_name SocUI
extends RefCounted
## Pestaña SOC de Zoho Desk (V.al/src/dir/pr/q/fw del original).

static var overlay: SocOverlay
const SUB := [["al","🚨 Alertas"],["AD","🪪 Active Directory"],["CCTV","🎥 Cámaras"],["SW","🔌 Switch"],["EQ","💻 Equipos"],["NAS","🗄️ NAS"],["dir","📇 Directorio"],["pr","📌 Pruebas"],["fw","📊 Cumplimiento"],["q","🔎 SIEM (SQL)"]]


static func tx(t: String, size := 14, b := false, col := Kit.INK) -> Label:
	return Kit.label(t, size, col, b, true)

static func sm(t: String) -> Label:
	var l := Kit.label(t, 12, Kit.INK, false, true); l.modulate.a = .75; return l

static func btn(t: String, cb: Callable, col := Kit.TEAL) -> Button:
	var b := Kit.button(t, "Opt", 13)
	b.add_theme_stylebox_override("normal", Kit.sb(Color.WHITE, 6, 2, col, 6))
	b.add_theme_stylebox_override("hover", Kit.sb(col, 6, 2, col, 6))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	return b

static func card(v: VBoxContainer) -> VBoxContainer:
	var p := Kit.panel(Kit.sb(Color.WHITE, 8, 0, Color.TRANSPARENT, 12)); v.add_child(p)
	var c := VBoxContainer.new(); c.add_theme_constant_override("separation", 4); p.add_child(c)
	return c


static func build(v: VBoxContainer, redraw: Callable) -> void:
	var S := Soc
	var X: Dictionary = S.X
	v.add_child(tx("🛡️ SOC · Centro de operaciones de seguridad", 20, true))
	if X.is_empty() or not X.on:
		v.add_child(tx("Sin datos.")); return
	var fl := HFlowContainer.new(); fl.add_theme_constant_override("h_separation", 4); fl.add_theme_constant_override("v_separation", 4); v.add_child(fl)
	for s in SUB:
		var key: String = s[0]
		var b := btn(s[1], func(): S.view(key); redraw.call())
		if X.view == key:
			b.add_theme_stylebox_override("normal", Kit.sb(Kit.TEAL, 6, 2, Kit.TEAL, 6)); b.add_theme_color_override("font_color", Color.WHITE)
		fl.add_child(b)
	fl.add_child(btn("⚖️ Reunión de emergencia", func(): overlay.audit(), Kit.BAD))
	v.add_child(HSeparator.new())
	match X.view:
		"AD", "CCTV", "SW", "EQ", "NAS": _src(v, X.view, redraw)
		"dir": _dir(v)
		"pr": _pr(v, redraw)
		"q": _q(v, redraw)
		"fw": _fw(v, redraw)
		_: _al(v, redraw)


static func pin_btn(c: Dictionary, redraw: Callable) -> Button:
	return btn("📌 Quitar" if Soc.X.pins.has(c.id) else "📌 Fijar", func(): Soc.pin(c.id); redraw.call())


static func _al(v: VBoxContainer, redraw: Callable) -> void:
	var S := Soc
	var X: Dictionary = S.X
	if X.inc.is_empty():
		v.add_child(tx("Sin alertas por ahora. El SIEM y el NOC te avisarán. Hoy hay una amenaza interna en CAA Corp.")); return
	for n in X.inc:
		var T: Dictionary = S.TYPES[n.type]
		var fx: bool = n.st == "fixed"
		var c := card(v)
		c.add_child(tx("%s #%d %s" % [T.ico, n.id + 1, T.name], 15, true))
		c.add_child(sm("%s · límite %s · %s" % [S.hm(n.t), S.hm(n.dl), "✔ contenido" if fx else ("⏰ escalado" if n.esc else "⚠ activo")]))
		c.add_child(tx(S.alert_text(n)))
		c.add_child(sm(S.HOWTO[n.type]))
		var fw: Dictionary = S.FW[n.type]
		c.add_child(sm("🏷 %s · %s · COBIT %s · ATT&CK %s" % [fw.nist, fw.iso, fw.cobit, fw.att]))
		c.add_child(sm(S.phases(n)))
		var h := HFlowContainer.new(); c.add_child(h)
		var id: int = n.id
		if n.type == "nas" and not fx: h.add_child(btn("Restaurar snapshot (−30 min)", func(): S.restore(id); redraw.call()))
		if not n.imaged: h.add_child(btn("📷 Imagen forense (−8 min)", func(): S.image(id); redraw.call()))
		else: c.add_child(sm("📷 Imagen forense capturada (ISO/IEC 27037) · CRC32 %s · GDScript" % n.hash))
		if fx and not n.q: h.add_child(btn("📝 Post-incidente: lecciones aprendidas", func(): overlay.post(id)))


static func _src(v: VBoxContainer, s: String, redraw: Callable) -> void:
	var S := Soc
	var X: Dictionary = S.X
	v.add_child(sm(S.HINT[s] + " · Marco: ISO/IEC 27037 y NIST SP 800-86 (preservar la cadena de custodia)."))
	var L: Array = X.inc.filter(func(n): return X.clues.any(func(c): return c.inc == n.id and c.src == s))
	if L.is_empty():
		v.add_child(tx("Sin registros relevantes todavía.")); return
	for n in L:
		var cs: Array = X.clues.filter(func(c): return c.inc == n.id and c.src == s)
		var blk := func(c): return c.vol and n.st == "fixed" and not n.imaged
		var c0 := card(v)
		c0.add_child(tx("%s #%d %s" % [S.TYPES[n.type].ico, n.id + 1, S.TYPES[n.type].name], 15, true))
		c0.add_child(sm(S.hm(n.t)))
		for c in cs:
			if c.open:
				var h := HBoxContainer.new(); c0.add_child(h)
				var l := tx(c.text, 13); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
				h.add_child(pin_btn(c, redraw))
		var id: int = n.id
		if cs.any(func(c): return not c.open and not blk.call(c)):
			c0.add_child(btn("🔍 Consultar registros (−10 min)", func(): S.ext(s, id); redraw.call()))
		if cs.any(func(c): return not c.open and blk.call(c)):
			c0.add_child(tx("🔒 Evidencia volátil perdida: contuviste sin captura forense.", 13, true, Kit.BAD))


static func _dir(v: VBoxContainer) -> void:
	v.add_child(sm("Directorio de RR. HH.: la foto del carnet muestra el color de camisa."))
	var g := GridContainer.new(); g.columns = 5; g.add_theme_constant_override("h_separation", 16); g.add_theme_constant_override("v_separation", 6); v.add_child(g)
	for hd in ["Empleado","Depto.","Usuario","IP / equipo","Camisa"]: g.add_child(Kit.label(hd, 13, Kit.INK, true))
	for r in Soc.X.ros:
		for val in [r.name, r.dept, r.u, r.ip + "\n" + r.pc, r.shirt]:
			g.add_child(Kit.label(val, 13, Kit.INK))


static func _pr(v: VBoxContainer, redraw: Callable) -> void:
	var X: Dictionary = Soc.X
	v.add_child(tx("Pruebas fijadas: %d/4. Se presentan en la reunión de emergencia." % X.pins.size(), 15, true))
	var op: Array = X.clues.filter(func(c): return c.open)
	if op.is_empty(): v.add_child(tx("Aún no has extraído pruebas.")); return
	for c in op:
		var cc := card(v)
		cc.add_child(sm("[%s] %s" % [c.src, Soc.hm(c.t)]))
		cc.add_child(tx(c.text, 13))
		cc.add_child(pin_btn(c, redraw))


static func _q(v: VBoxContainer, redraw: Callable) -> void:
	var X: Dictionary = Soc.X
	v.add_child(sm("Consola SIEM con SQL. Tabla logs(t, src, inc, type, text). Sin WHERE no hay consulta; máx. 5 filas y cada consulta cuesta 6 min. Ej.: SELECT t, text FROM logs WHERE src = 'AD' AND text LIKE '%5136%' ORDER BY t"))
	var h := HBoxContainer.new(); v.add_child(h)
	var inp := LineEdit.new(); inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inp.text = X.qt; inp.placeholder_text = "SELECT * FROM logs WHERE ..."
	inp.add_theme_font_override("font", Kit.mono()); inp.add_theme_color_override("font_color", Kit.INK)
	inp.add_theme_stylebox_override("normal", Kit.sb(Color.WHITE, 6, 1, Color("#bbbbbb"), 8))
	h.add_child(inp)
	var run := func(): Soc.run_query(inp.text); redraw.call()
	inp.text_submitted.connect(func(_t): run.call())
	h.add_child(btn("▶ Ejecutar", run))
	if X.qe != "": v.add_child(tx(X.qe, 14, true, Kit.BAD))
	if X.qr.size():
		var g := GridContainer.new(); g.columns = X.qc.size(); g.add_theme_constant_override("h_separation", 14); v.add_child(g)
		for c in X.qc: g.add_child(Kit.label(c, 13, Kit.INK, true))
		for r in X.qr:
			for c in X.qc:
				var l := Kit.label(str(r[c]), 12, Kit.INK)
				if c == "text": l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = 380
				g.add_child(l)
		v.add_child(sm("Las filas devueltas quedaron registradas como evidencia."))
	elif X.qt != "" and X.qe == "":
		v.add_child(tx("0 filas."))


static func _fw(v: VBoxContainer, redraw: Callable) -> void:
	var S := Soc
	var I: Dictionary = S.inf()
	var f := func(k): return int(I.fw.get(k, 0))
	v.add_child(sm("NIST CSF 2.0 · COBIT 2019 · ISO/IEC 27001:2022 Anexo A · NIST SP 800-61 · MITRE ATT&CK. Mapeo didáctico; tu progreso se conserva entre jornadas."))
	var c := card(v)
	c.add_child(tx("NIST CSF 2.0 — madurez por función", 15, true))
	for k in S.FN:
		var h := HBoxContainer.new(); c.add_child(h)
		var l := Kit.label("%s %s" % [k, S.FNN[k]], 13, Kit.INK, true); l.custom_minimum_size.x = 130; h.add_child(l)
		var b := Kit.bar(Kit.TEAL); b.value = f.call(k); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size.y = 12
		(b.get_theme_stylebox("background") as StyleBoxFlat).bg_color = Color("#d9c3ae")
		h.add_child(b)
		h.add_child(Kit.label(str(f.call(k)), 13, Kit.INK))
	var LV := ["0 Incompleto","1 Realizado","2 Gestionado","3 Establecido","4 Predecible","5 Optimizado"]
	var avg := func(ks: Array) -> float:
		var s := 0.0
		for k in ks: s += f.call(k)
		return s / ks.size()
	var c2 := card(v)
	c2.add_child(tx("COBIT 2019 — nivel de capacidad", 15, true))
	for row in [["APO12 Gestión del riesgo", ["ID"]], ["DSS02 Incidentes y solicitudes", ["DE","RS"]], ["DSS04 Continuidad", ["RC"]], ["DSS05 Servicios de seguridad", ["PR"]], ["EDM03 / APO13 Gobierno de seguridad", ["GV"]]]:
		c2.add_child(tx("%s — %s" % [row[0], LV[mini(5, int(floor(avg.call(row[1]) / 20)))]], 13))
	var c3 := card(v)
	c3.add_child(tx("Controles correctivos (ISO 27001 Anexo A)", 15, true))
	for t in S.FW:
		c3.add_child(tx("%s %s" % [S.TYPES[t].ico, S.FW[t].ctl], 13, true))
		c3.add_child(sm(S.FW[t].iso))
		if I.ctl.has(t): c3.add_child(tx("✔ implementado: los incidentes de este tipo escalan 45 min más tarde con la mitad de impacto", 12, false, Kit.OK))
		else:
			var tt: String = t
			c3.add_child(btn("Implementar ($%d)" % S.COST_CTL, func(): S.buy_ctl(tt); redraw.call()))


# =====================================================================
class SocOverlay:
	extends Control
	var box: VBoxContainer
	var redraw: Callable

	func _ready() -> void:
		Kit.full_rect(self)
		theme = Kit.theme()
		visible = false
		var bg := ColorRect.new(); bg.color = Color(0.043, 0.067, 0.094, .96); Kit.full_rect(bg); add_child(bg)
		var sc := ScrollContainer.new(); Kit.full_rect(sc); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(sc)
		var cc := CenterContainer.new(); cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(cc)
		var mc := MarginContainer.new(); mc.custom_minimum_size.x = 920
		for s in ["top", "bottom"]: mc.add_theme_constant_override("margin_" + s, 16)
		cc.add_child(mc)
		box = VBoxContainer.new(); box.add_theme_constant_override("separation", 8); mc.add_child(box)

	func _clear() -> void:
		for c in box.get_children(): c.queue_free()

	func L(t: String, size := 15, b := false, col := Color("#e8eaf0")) -> Label:
		var l := Kit.label(t, size, col, b, true); box.add_child(l); return l

	func B(t: String, cb: Callable, col := Kit.TEAL, parent: Control = null) -> Button:
		var b := Kit.button(t, "", 14)
		b.add_theme_stylebox_override("normal", Kit.sb(col, 8, 0, Color.TRANSPARENT, 9))
		b.add_theme_stylebox_override("hover", Kit.sb(col.lightened(.15), 8, 0, Color.TRANSPARENT, 9))
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(cb)
		(parent if parent else box).add_child(b)
		return b

	func close() -> void:
		visible = false
		if redraw.is_valid(): redraw.call()

	func _unhandled_key_input(e: InputEvent) -> void:
		if visible and e.pressed and e.keycode == KEY_ESCAPE:
			close(); get_viewport().set_input_as_handled()

	func audit() -> void:
		if Soc.X.meet:
			Game.toast("Ya usaste la reunión de emergencia de hoy"); return
		visible = true
		_clear()
		if not Soc.X.meet:
			L("⚖️ Reunión de emergencia", 26, true, Color.WHITE)
			L("Convocar la auditoría cuesta 45 minutos y solo puedes hacerlo una vez por jornada. Presentarás hasta 4 pruebas y acusarás a un empleado. Si te equivocas: despido improcedente, demanda y pérdida de confianza.")
			L("Pruebas recolectadas: %d" % Soc.X.clues.filter(func(c): return c.open).size(), 15, true)
			var h := HBoxContainer.new(); box.add_child(h)
			B("Convocar (−45 min)", func():
				Soc.meet()
				if Game.st.over: close()
				else: _meeting(), Kit.TEAL, h)
			B("Cancelar", close, Color("#3a4a5a"), h)
			return
		_meeting()

	func _meeting() -> void:
		visible = true
		_clear()
		var X: Dictionary = Soc.X
		L("⚖️ Auditoría de seguridad", 26, true, Color.WHITE)
		var g := HBoxContainer.new(); g.add_theme_constant_override("separation", 14); box.add_child(g)
		var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; g.add_child(left)
		var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; g.add_child(right)
		left.add_child(Kit.label("📌 Pruebas (%d/4)" % X.pins.size(), 18, Color.WHITE, true))
		var op: Array = X.clues.filter(func(c): return c.open)
		if op.is_empty(): left.add_child(Kit.label("No extrajiste pruebas.", 14, Color.WHITE))
		for c in op:
			var p := Kit.panel(Kit.sb(Color("#1b2735"), 10, 1, Color("#2f4357"), 10)); left.add_child(p)
			var v := VBoxContainer.new(); p.add_child(v)
			v.add_child(Kit.label("[%s] %s" % [c.src, c.text], 13, Color("#e8eaf0"), false, true))
			var id: int = c.id
			B("✅ Presentada" if X.pins.has(id) else "Presentar", func(): Soc.pin(id); _meeting(), Kit.TEAL, v)
		right.add_child(Kit.label("👥 Empleados", 18, Color.WHITE, true))
		for s in X.ros:
			var p := Kit.panel(Kit.sb(Color("#1b2735"), 10, 1, Color("#2f4357"), 10)); right.add_child(p)
			var v := VBoxContainer.new(); p.add_child(v)
			v.add_child(Kit.label("%s  ·  %s · %s" % [s.name, s.dept, s.u], 14, Color.WHITE, true))
			var h := HBoxContainer.new(); v.add_child(h)
			var i: int = s.i
			B("🎤 Interrogar", func(): X.sel = i; _meeting(), Kit.TEAL, h)
			B("⚖️ Acusar", func(): _result(Soc.accuse(i)), Color("#a63b2f"), h)
			if X.sel == i:
				var t := Soc.stmt(i)
				v.add_child(Kit.label(t.t, 13, Color("#e8eaf0"), false, true))
				v.add_child(Kit.label(t.n, 12, Color(1, 1, 1, .7), false, true))
		B("Cerrar sin acusar", close, Color("#3a4a5a"))

	func _result(res: Dictionary) -> void:
		if res.is_empty(): return
		_clear()
		L(res.h, 26, true, Color.WHITE)
		L(res.p)
		if res.has("r"):
			var p := Kit.panel(Kit.sb(Color("#1b2735"), 10, 1, Color("#2f4357"), 12)); box.add_child(p)
			p.add_child(Kit.label(res.r, 13, Color("#e8eaf0"), false, true))
		if res.get("buy", "") != "":
			var t: String = res.buy
			B("Implementarlo ($%d)" % Soc.COST_CTL, func(): Soc.buy_ctl(t); close())
		B("Volver al trabajo", close)

	func post(id: int) -> void:
		visible = true
		_clear()
		var n: Dictionary = Soc.X.inc[id]
		var q: Dictionary = Soc.FW[n.type]
		if not n.has("qo"):
			var o := [0, 1, 2]; o.shuffle(); n.qo = o
		L("📝 Post-incidente · " + Soc.TYPES[n.type].name, 24, true, Color.WHITE)
		L("NIST SP 800-61: lecciones aprendidas · " + q.nist, 12, false, Color(1, 1, 1, .7))
		L(q.q, 16, true)
		for k in n.qo:
			var kk: int = k
			var b := B(q.o[k], func(): _result(Soc.post_answer(id, kk)))
			b.size_flags_horizontal = Control.SIZE_FILL
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		B("Más tarde", close, Color("#3a4a5a"))
