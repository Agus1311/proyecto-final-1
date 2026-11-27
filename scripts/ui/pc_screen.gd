class_name PcScreen
extends Control
## PC del jugador: escritorio con Zoho Desk (tickets + pestañas) y demás apps.

signal closed
signal ticket_resolved(i: int)
signal end_day

const TABS := [["t","Tickets"],["sk","Habilidades"],["ev","Eventos"],["ad","Active Directory"],["mail","Correo"],["mon","Monitor"],["mfa","Tablet"],["jobs","Empleos"],["shop","Tienda"],["bios","BIOS"],["inf","🛡️ SOC"]]

var desk: Desktop
var list_box: VBoxContainer
var det: VBoxContainer
var split: HBoxContainer
var app_box: VBoxContainer
var app_scroll: ScrollContainer
var endday_b: Button
var tab_btns := {}
var cur_tab := "t"
var _pending_open := -2


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	desk = Desktop.new()
	desk.setup("me", Desktop.APPS_ME)
	desk.factory = _factory
	add_child(desk)
	desk.power.connect(close)


func _factory(k: String, body: Control, _d: Desktop) -> bool:
	if k == "close_tickets":
		list_box = null
		return true
	if k != "tickets":
		return false
	_build_zoho(body)
	return true


# ---------------- Zoho Desk ----------------
func _build_zoho(body: Control) -> void:
	var v := VBoxContainer.new()
	Kit.full_rect(v)
	v.add_theme_constant_override("separation", 0)
	body.add_child(v)
	var bar := Kit.panel(Kit.sb(Kit.TEAL, 0, 0, Color.TRANSPARENT, 8))
	v.add_child(bar)
	var bh := HBoxContainer.new(); bh.add_theme_constant_override("separation", 6); bar.add_child(bh)
	bh.add_child(Kit.label("CAA Corp · Escritorio de TI", 14, Color.WHITE, true))
	var tabs := HFlowContainer.new(); tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("h_separation", 4); tabs.add_theme_constant_override("v_separation", 4)
	bh.add_child(tabs)
	tab_btns.clear()
	for t in TABS:
		var b := Kit.button(t[1], "", 13)
		var key: String = t[0]
		b.pressed.connect(func(): tab(key))
		tabs.add_child(b)
		tab_btns[key] = b
	endday_b = Kit.button("Terminar jornada", "", 13)
	endday_b.pressed.connect(func(): end_day.emit())
	bh.add_child(endday_b)
	var cb := Kit.button("Apagar pantalla (Esc)", "", 13)
	cb.pressed.connect(close)
	bh.add_child(cb)
	var paper := Kit.panel(Kit.sb(Kit.PAPER, 0, 0, Color.TRANSPARENT, 0))
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(paper)
	var stack := Control.new()
	paper.add_child(stack)
	split = HBoxContainer.new()
	Kit.full_rect(split)
	split.add_theme_constant_override("separation", 0)
	stack.add_child(split)
	var ls := ScrollContainer.new()
	ls.custom_minimum_size.x = 290
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(ls)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 0)
	ls.add_child(list_box)
	var sep := ColorRect.new(); sep.color = Color("#d9c3ae"); sep.custom_minimum_size.x = 2; split.add_child(sep)
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(ds)
	det = _margin_box(ds, 20)
	app_scroll = ScrollContainer.new()
	Kit.full_rect(app_scroll)
	app_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	app_scroll.visible = false
	stack.add_child(app_scroll)
	app_box = _margin_box(app_scroll, 18)
	app_box.add_theme_constant_override("separation", 10)
	_tabs_vis()
	_style_tabs()
	endday_b.visible = Game.onsite == 0


func _margin_box(sc: ScrollContainer, m: int) -> VBoxContainer:
	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	sc.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_child(v)
	return v


func _tabs_vis() -> void:
	for k in tab_btns:
		tab_btns[k].visible = (k in ["t", "bios"]) if Game.onsite else k != "bios"


func _style_tabs() -> void:
	for k in tab_btns:
		var b: Button = tab_btns[k]
		if k == cur_tab:
			b.add_theme_stylebox_override("normal", Kit.sb(Color.WHITE, 8, 0, Color.TRANSPARENT, 6))
			b.add_theme_color_override("font_color", Kit.TEAL)
			b.add_theme_color_override("font_hover_color", Kit.TEAL)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_color_override("font_color")
			b.remove_theme_color_override("font_hover_color")


func _ensure_zoho() -> void:
	if not desk.wins.has("tickets") or list_box == null:
		desk.open_app("tickets")
	else:
		desk.open_app("tickets")


func tab(k: String) -> void:
	_ensure_zoho()
	cur_tab = k
	_style_tabs()
	split.visible = k == "t"
	app_scroll.visible = k != "t"
	if k == "t":
		render_list()
		return
	_draw_tab()


func _draw_tab() -> void:
	for c in app_box.get_children():
		c.queue_free()
	ZohoTabs.build(cur_tab, app_box, _draw_tab)


# ---------------- abrir / cerrar ----------------
func open(n: int, start_tab := "t") -> void:
	visible = true
	_ensure_zoho()
	_tabs_vis()
	endday_b.visible = Game.onsite == 0
	if start_tab != "t":
		tab(start_tab)
		return
	tab("t")
	if n >= 0:
		open_ticket(n)
	else:
		_placeholder()


func close() -> void:
	visible = false
	closed.emit()


func _placeholder() -> void:
	_clear(det)
	det.add_child(Kit.label("Selecciona un ticket", 22, Kit.INK, true))
	det.add_child(Kit.label("Atiende cada caso eligiendo la mejor acción. Cada decisión consume tiempo y afecta la satisfacción de los usuarios y la seguridad de la empresa.", 16, Kit.INK, false, true))


func _clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()


func render_list() -> void:
	if list_box == null:
		return
	_clear(list_box)
	var st: Dictionary = Game.st
	for i in Game.tickets.size():
		var k: Dictionary = Game.tickets[i]
		var b := Button.new()
		b.theme_type_variation = "Tk"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 58
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if st.cur == i:
			b.add_theme_stylebox_override("normal", _sel_style())
		var done: bool = st.state[i] != null
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Kit.full_rect(row)
		row.offset_left = 14; row.offset_right = -8
		row.add_theme_constant_override("separation", 8)
		b.add_child(row)
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pc: Color = Data.PRI[k.p - 1]
		dot.draw.connect(func(): dot.draw_circle(Vector2(5, dot.size.y / 2), 4.5, pc))
		row.add_child(dot)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var tl := Kit.label(k.t, 15, Kit.INK, true)
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(tl)
		var where := ""
		if k.loc == 4: where = " · Te buscará"
		elif k.loc: where = " · En sitio"
		var sla := Game.sla_txt(i)
		var sm := Kit.label(k.from + where + sla, 12, Kit.INK)
		sm.modulate.a = .7
		sm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if sla.contains("vencido"):
			sm.add_theme_color_override("font_color", Kit.BAD)
		col.add_child(sm)
		if done:
			b.modulate.a = .45
			var strike := ColorRect.new()
			strike.color = Kit.INK
			strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
			strike.custom_minimum_size = Vector2(0, 1.5)
			tl.add_child(strike)
			strike.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
		var idx: int = i
		b.pressed.connect(func(): open_ticket(idx))
		list_box.add_child(b)


func _sel_style() -> StyleBoxFlat:
	var s := Kit.sb(Color(0.91, 0.65, 0.49, .33), 0, 0, Color.TRANSPARENT, 12)
	s.border_width_left = 4; s.border_color = Kit.WARM
	return s


func open_ticket(i: int) -> void:
	if cur_tab != "t":
		cur_tab = "t"; _style_tabs(); split.visible = true; app_scroll.visible = false
	var st: Dictionary = Game.st
	st.cur = i
	render_list()
	var k: Dictionary = Game.tickets[i]
	_clear(det)
	det.add_child(Kit.label(k.t, 22, Kit.INK, true, true))
	if st.state[i] != null:
		det.add_child(Kit.label("Ticket cerrado.", 16, Kit.INK))
		return
	var fr := Kit.label("De: " + k.from, 13, Kit.INK); fr.modulate.a = .75
	det.add_child(fr)
	det.add_child(Kit.label(k.b, 16, Kit.INK, false, true))
	if k.loc != Game.onsite:
		var msg := ""
		if k.loc:
			msg = "Este usuario vendrá a buscarte en persona. Recorre CAA Corp y atiéndelo cuando te encuentre." if k.loc == 4 else "Este caso requiere visita en sitio: ve al puesto de " + Data.STN[k.loc].name + "."
		else:
			msg = "Este caso se atiende desde tu escritorio."
		det.add_child(Kit.label(msg, 16, Kit.INK, true, true))
		return
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 8)
	det.add_child(opts)
	for j in k.o.size():
		var b := Kit.button(k.o[j][0], "Opt", 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var jj: int = j
		b.pressed.connect(func(): _resolve(i, jj, opts))
		opts.add_child(b)


func _resolve(i: int, j: int, opts: Control) -> void:
	var r := Game.resolve(i, j)
	ticket_resolved.emit(i)
	opts.visible = false
	var fb := Kit.panel(Kit.sb(Color(0.3, 0.6, 0.42, .2) if r.good else Color(0.77, 0.31, 0.25, .2), 8, 0, Color.TRANSPARENT, 14))
	det.add_child(fb)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); fb.add_child(v)
	v.add_child(Kit.label(r.text, 16, Kit.INK, true, true))
	var stars := "★".repeat(r.stars) + "☆".repeat(5 - r.stars)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); v.add_child(h)
	h.add_child(Kit.label(stars, 20, Color("#e8a03a"), true))
	var sm := Kit.label("Satisfacción %s%d · Seguridad %s%d" % ["+" if r.sat >= 0 else "", r.sat, "+" if r.sec >= 0 else "", r.sec], 13, Kit.INK)
	sm.modulate.a = .8
	h.add_child(sm)
	var nx := Kit.button("Siguiente ticket", "Opt", 15)
	nx.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nx.pressed.connect(_next)
	v.add_child(nx)
	render_list()


func _next() -> void:
	render_list()
	var n: int = Game.st.state.find(null)
	if Game.st.time >= Data.END:
		Game.finish()
	elif n < 0:
		Game.toast("Tickets cerrados. Revisa AD, Correo y Monitor o termina la jornada.")
		if Game.onsite:
			close()
		else:
			tab("ad")
	elif Game.onsite:
		close()
	else:
		open_ticket(n)
