class_name ZohoTabs
extends RefCounted
## Pestañas de Zoho Desk (drawAD/drawMail/drawMon/... del original).

static func build(k: String, v: VBoxContainer, redraw: Callable) -> void:
	match k:
		"sk": _skills(v, redraw)
		"ev": _events(v, redraw)
		"ad": _ad(v, redraw)
		"mail": _mail(v, redraw)
		"mon": _mon(v, redraw)
		"mfa": _mfa(v, redraw)
		"jobs": _jobs(v, redraw)
		"shop": _shop(v, redraw)
		"bios": _bios(v, redraw)
		"inf": SocUI.build(v, redraw)


static func h3(t: String) -> Label:
	return Kit.label(t, 20, Kit.INK, true, true)

static func tx(t: String, size := 15, b := false, col := Kit.INK) -> Label:
	return Kit.label(t, size, col, b, true)

static func cell(t: String, size := 13, b := false, col := Kit.INK) -> Label:
	return Kit.label(t, size, col, b, false)

static func card(bg := Color.WHITE) -> VBoxContainer:
	var p := Kit.panel(Kit.sb(bg, 8, 0, Color.TRANSPARENT, 12))
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.set_meta("panel", p)
	return v

static func add_card(parent: Control, bg := Color.WHITE) -> VBoxContainer:
	var c := card(bg)
	parent.add_child(c.get_meta("panel"))
	return c

static func abtn(t: String, cb: Callable) -> Button:
	var b := Kit.button(t, "Opt", 14)
	b.add_theme_stylebox_override("normal", Kit.sb(Color.WHITE, 6, 2, Kit.TEAL, 6))
	b.add_theme_stylebox_override("hover", Kit.sb(Kit.TEAL, 6, 2, Kit.TEAL, 6))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	return b

static func row(parent: Control) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); parent.add_child(h); return h

static func grid(parent: Control) -> HFlowContainer:
	var g := HFlowContainer.new(); g.add_theme_constant_override("h_separation", 10); g.add_theme_constant_override("v_separation", 10); parent.add_child(g); return g


# ---- Habilidades ----
static func _skills(v: VBoxContainer, redraw: Callable) -> void:
	var L := Game.lvl()
	var cur := (L - 1) * 120
	v.add_child(h3("Habilidades"))
	var c := add_card(v)
	c.add_child(tx("Nivel %d · XP %d/%d · Puntos disponibles: %d" % [L, int(Game.G.xp), L * 120, int(Game.G.sp)], 15, true))
	var b := Kit.bar(Color("#d22222")); b.value = (int(Game.G.xp) - cur) / 120.0 * 100; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(b)
	var g := grid(v)
	for s in Data.SK:
		var lv := Game.sk(s[0])
		var cc := card()
		var pnl: Control = cc.get_meta("panel"); pnl.custom_minimum_size.x = 230; g.add_child(pnl)
		cc.add_child(tx("%s %s" % [s[2], s[1]], 15, true))
		cc.add_child(tx("●".repeat(lv) + "○".repeat(s[3] - lv), 16, false, Kit.TEAL))
		var d := tx(s[4], 12); d.custom_minimum_size.x = 206; cc.add_child(d)
		if lv < s[3]:
			var key: String = s[0]
			cc.add_child(abtn("Mejorar (%d pt)" % (lv + 1), func(): Game.sk_act(key); redraw.call()))
		else:
			cc.add_child(tx("Máximo", 13, true, Kit.OK))


# ---- Visor de eventos ----
static func _events(v: VBoxContainer, redraw: Callable) -> void:
	var st: Dictionary = Game.st
	v.add_child(h3("Visor de eventos — Registro de seguridad"))
	var c := add_card(v)
	if st.inv.done:
		c.add_child(tx("✔ Ataque contenido: IP bloqueada en el firewall.", 15, true, Kit.OK))
	else:
		c.add_child(tx("⚠ Alerta del SIEM: intentos de inicio de sesión fallidos fuera de horario. Identifica la IP responsable y bloquéala.", 15))
		if Game.sk("logs") == 1:
			c.add_child(tx("🔎 Pista: busca fallos seguidos de un acceso correcto desde una misma IP externa.", 13))
	var t := GridContainer.new(); t.columns = 6
	t.add_theme_constant_override("h_separation", 16); t.add_theme_constant_override("v_separation", 6)
	v.add_child(t)
	for hd in ["Hora", "Nivel", "Id", "Usuario", "IP origen", ""]:
		t.add_child(cell(hd, 13, true))
	for i in st.evl.size():
		var e: Dictionary = st.evl[i]
		var hl: bool = Game.sk("logs") > 1 and e.ip == st.inv.ip
		var col := Color("#a05a00") if hl else Kit.INK
		for val in [e.t, e.lv, str(e.id), e.u, e.ip]:
			t.add_child(cell(val, 13, hl, col))
		if st.inv.done:
			t.add_child(Control.new())
		else:
			var ii: int = i
			t.add_child(abtn("Bloquear IP", func(): Game.ev_act(ii); redraw.call()))


# ---- Active Directory ----
static func _ad(v: VBoxContainer, redraw: Callable) -> void:
	var st: Dictionary = Game.st
	v.add_child(h3("Active Directory — Usuarios y equipos"))
	var c := add_card(v)
	for t in st.adt:
		c.add_child(tx(("✔ " if t.done else "○ ") + t.txt, 14))
	var g := GridContainer.new(); g.columns = 4
	g.add_theme_constant_override("h_separation", 16); g.add_theme_constant_override("v_separation", 8)
	v.add_child(g)
	for hd in ["Usuario", "Departamento", "Estado", ""]:
		g.add_child(cell(hd, 13, true))
	for i in Data.USERS.size():
		var u: Array = Data.USERS[i]
		var s: Dictionary = st.ad[i]
		g.add_child(cell(u[1] + "\n" + u[0], 13))
		g.add_child(cell(u[2], 13))
		var est := "Deshabilitada" if s.off else ("🔒 Bloqueada" if s.lock else "Activa")
		if s.ex: est += "\nBaja reportada por RRHH"
		g.add_child(cell(est, 13, s.lock or s.ex, Kit.BAD if (s.lock or s.ex) else Kit.INK))
		var h := HBoxContainer.new(); g.add_child(h)
		var ii: int = i
		h.add_child(abtn("Desbloquear", func(): Game.ad_act(ii, "unlock"); redraw.call()))
		h.add_child(abtn("Restablecer clave", func(): Game.ad_act(ii, "reset"); redraw.call()))
		var a2 := "on" if s.off else "off"
		h.add_child(abtn("Habilitar" if s.off else "Deshabilitar", func(): Game.ad_act(ii, a2); redraw.call()))


# ---- Correo (phishing) ----
static func _mail(v: VBoxContainer, redraw: Callable) -> void:
	v.add_child(h3("Bandeja de entrada"))
	for i in Game.st.mail.size():
		var x: Dictionary = Game.st.mail[i]
		var c := add_card(v)
		c.add_child(tx(x.m[1], 16, true))
		c.add_child(tx("De: " + x.m[0], 12))
		if Game.sk("phish") and x.m[3] and x.a == null:
			c.add_child(tx("🔎 " + ("Señales de phishing detectadas" if Game.sk("phish") > 1 else "Algo no cuadra con este remitente"), 12, true, Color("#a05a00")))
		c.add_child(tx(x.m[2], 14))
		if x.a == null:
			var h := row(c)
			var ii: int = i
			h.add_child(abtn("Es legítimo", func(): Game.mail_act(ii, "l"); redraw.call()))
			h.add_child(abtn("Es phishing", func(): Game.mail_act(ii, "p"); redraw.call()))
		else:
			var ok: bool = x.a == x.m[3]
			c.add_child(tx("%s: %s %s" % ["Phishing" if x.m[3] else "Legítimo", x.m[4], "✔" if ok else "✘"], 13, true, Kit.OK if ok else Kit.BAD))


# ---- Monitor de red ----
static func _mon(v: VBoxContainer, redraw: Callable) -> void:
	v.add_child(h3("Monitor de red"))
	var g := grid(v)
	for i in Data.DEV.size():
		var d: Array = Data.DEV[i]
		var dn: bool = Game.st.dev[i] == "down"
		var c := card(Color("#f6d0c9") if dn else Color.WHITE)
		var pnl: Control = c.get_meta("panel"); pnl.custom_minimum_size.x = 230; g.add_child(pnl)
		c.add_child(tx(d[0], 15, true))
		c.add_child(tx("● CAÍDO" if dn else "● En línea", 14, true, Kit.BAD if dn else Kit.OK))
		if dn:
			c.add_child(tx(d[1], 12))
			for k in Data.MA.size():
				var ii: int = i; var kk: int = k
				c.add_child(abtn(Data.MA[k], func(): Game.mon_act(ii, kk); redraw.call()))


# ---- Tablet / MFA ----
static func _mfa(v: VBoxContainer, redraw: Callable) -> void:
	v.add_child(h3("Tablet · Authenticator"))
	var c := add_card(v, Color("#3a3f9a"))
	(c.get_meta("panel") as Control).custom_minimum_size.x = 340
	(c.get_meta("panel") as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.add_child(Kit.label("Administrador VPN · caacorp.com", 12, Color(1, 1, 1, .8)))
	var code := Kit.label(Game.mfa_code(0), 38, Color.WHITE, true)
	code.add_theme_constant_override("letter_spacing", 6)
	c.add_child(code)
	var exp := Kit.label("", 12, Color(1, 1, 1, .8))
	c.add_child(exp)
	var tm := Timer.new(); tm.wait_time = .25; tm.autostart = true
	tm.timeout.connect(func():
		code.text = Game.mfa_code(0)
		exp.text = "Caduca en %d s" % (15 - int(fmod(Time.get_unix_time_from_system(), 15.0))))
	c.add_child(tm)
	v.add_child(h3("Portal VPN — acceso de administrador"))
	v.add_child(tx("Inicios pendientes: %d. Ingresa el código de 6 dígitos de la tablet." % (3 - Game.st.mfa), 15))
	var h := row(v)
	var inp := LineEdit.new(); inp.max_length = 6; inp.custom_minimum_size.x = 150
	inp.add_theme_font_size_override("font_size", 18)
	inp.add_theme_stylebox_override("normal", Kit.sb(Color.WHITE, 6, 1, Color("#bbbbbb"), 8)); inp.add_theme_color_override("font_color", Kit.INK)
	h.add_child(inp)
	var go := func(): Game.mfa_act(inp.text); redraw.call()
	inp.text_submitted.connect(func(_t): go.call())
	h.add_child(abtn("Verificar", go))


# ---- Empleos ----
static func _jobs(v: VBoxContainer, redraw: Callable) -> void:
	v.add_child(h3("Bolsa de empleo"))
	v.add_child(tx("Rango actual: %s · Puesto: %s (sueldo x%s)" % [Game.rank(), Data.JB[int(Game.G.job)][0], str(Data.JB[int(Game.G.job)][3])], 15, true))
	for i in Data.JB.size():
		var j: Array = Data.JB[i]
		var c := add_card(v)
		c.add_child(tx("%s — %s" % [j[0], j[1]], 15, true))
		c.add_child(tx("Requiere rango: %s · Sueldo x%s" % [Data.RANKS[j[2]], str(j[3])], 12))
		if int(Game.G.job) == i:
			c.add_child(tx("Puesto actual ✔", 13, true, Kit.OK))
		elif Game.ri() >= j[2]:
			var ii: int = i
			c.add_child(abtn("Aplicar", func(): Game.job_act(ii); redraw.call()))
		else:
			c.add_child(tx("Rango insuficiente", 13, false, Color("#888888")))


# ---- Tienda ----
static func _shop(v: VBoxContainer, redraw: Callable) -> void:
	v.add_child(h3("Tienda de TI"))
	v.add_child(tx("Saldo: $%d · cobras al terminar cada jornada." % int(Game.G.money), 15, true))
	for s in Data.SHOP:
		var c := add_card(v)
		c.add_child(tx("%s — $%d" % [s[1], s[3]], 15, true))
		c.add_child(tx(s[2], 13))
		if Game.ups(s[0]):
			c.add_child(tx("Comprado ✔", 13, true, Kit.OK))
		else:
			var key: String = s[0]
			c.add_child(abtn("Comprar", func(): Game.buy(key); redraw.call()))


# ---- BIOS ----
static func _bios(v: VBoxContainer, redraw: Callable) -> void:
	var b: Dictionary = Game.st.bios
	if b.loc != Game.onsite:
		v.add_child(h3("BIOS")); v.add_child(tx("Esta estación no reporta problemas de arranque.")); return
	if b.done:
		v.add_child(h3("BIOS")); v.add_child(tx("La PC arrancó correctamente. ✔")); return
	var frame := Kit.panel(Kit.sb(Color("#0a1a8f"), 0, 2, Color("#c0c0c0"), 0))
	v.add_child(frame)
	var fv := VBoxContainer.new(); fv.add_theme_constant_override("separation", 0); frame.add_child(fv)
	var menu := Kit.panel(Kit.sb(Color("#0a7ab0"), 0, 0, Color.TRANSPARENT, 0)); fv.add_child(menu)
	var mh := HBoxContainer.new(); mh.add_theme_constant_override("separation", 0); menu.add_child(mh)
	var bb := func(t: String, on: bool, cb: Callable, border := false) -> Button:
		var x := Button.new(); x.text = t; x.focus_mode = Control.FOCUS_NONE
		x.add_theme_font_override("font", Kit.mono()); x.add_theme_font_size_override("font_size", 15)
		x.add_theme_stylebox_override("normal", Kit.sb(Color("#c0c0c0") if on else Color(0, 0, 0, 0), 0, 1 if border else 0, Color("#c0c0c0"), 8))
		x.add_theme_stylebox_override("hover", Kit.sb(Color("#c0c0c0"), 0, 0, Color.TRANSPARENT, 8))
		x.add_theme_color_override("font_color", Color.BLACK if on else Color.WHITE)
		x.add_theme_color_override("font_hover_color", Color.BLACK)
		x.pressed.connect(cb)
		return x
	for pg in ["Main", "Advanced", "Security", "Boot", "Exit"]:
		var p2: String = pg
		mh.add_child(bb.call(pg, pg == b.page, func(): Game.bios_act("p", p2); redraw.call()))
	var body := MarginContainer.new(); body.custom_minimum_size.y = 220
	for s in ["left", "right", "top", "bottom"]: body.add_theme_constant_override("margin_" + s, 14)
	fv.add_child(body)
	var bv := VBoxContainer.new(); body.add_child(bv)
	var mono := func(t: String) -> Label:
		var l := Label.new(); l.text = t; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", Kit.mono()); l.add_theme_font_size_override("font_size", 15); l.add_theme_color_override("font_color", Color("#e8e8e8"))
		return l
	var opt := func(label: String, val: String, key: String):
		var h := HBoxContainer.new(); h.custom_minimum_size.x = 420; bv.add_child(h)
		var l: Label = mono.call(label); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		h.add_child(bb.call("[%s]" % val, false, func(): Game.bios_act("t", key); redraw.call(), true))
	var c: Dictionary = b.cfg
	match b.page:
		"Main":
			bv.add_child(mono.call("Sistema: equipo de usuario\nBIOS: v1.4.2\nEstado: no arranca el sistema operativo\n"))
			bv.add_child(mono.call("Objetivo: Secure Boot y TPM habilitados y SSD como primer dispositivo de arranque. Guarda y sal (Exit)."))
		"Advanced":
			bv.add_child(mono.call("CPU Configuration\nSATA Configuration\nUSB Configuration\nNetwork Stack Configuration"))
		"Security":
			opt.call("Secure Boot", c.sb, "sb"); opt.call("TPM Device", c.tpm, "tpm")
		"Boot":
			opt.call("Boot Option #1", c.boot, "boot")
		_:
			bv.add_child(bb.call("Save Changes and Exit", false, func(): Game.bios_act("s", "1"); redraw.call(), true))
			bv.add_child(bb.call("Discard Changes and Exit", false, func(): Game.bios_act("s", "0"); redraw.call(), true))
