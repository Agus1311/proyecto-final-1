class_name BenchUI
extends Control
## Taller de reparación y almacén de piezas (openBN/bnDraw del original + PC desarmada animada).

signal closed

var tabs: HBoxContainer
var body: VBoxContainer
var viz: BenchViz


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	var bg := ColorRect.new(); Kit.full_rect(bg); bg.color = Color("#141e28"); add_child(bg)
	var v := VBoxContainer.new(); Kit.full_rect(v); v.add_theme_constant_override("separation", 0); add_child(v)
	var bar := Kit.panel(Kit.sb(Color("#16202b"), 0, 0, Color.TRANSPARENT, 10)); v.add_child(bar)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); bar.add_child(h)
	h.add_child(Kit.label("🔧 Taller de reparación · CAA Corp", 16, Color.WHITE, true))
	tabs = HBoxContainer.new(); tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_theme_constant_override("separation", 6); h.add_child(tabs)
	var x := Kit.button("Salir (Esc)", "", 14); x.add_theme_stylebox_override("normal", Kit.sb(Color("#a63b2f"), 8, 0, Color.TRANSPARENT, 8)); x.pressed.connect(close); h.add_child(x)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	var cc := CenterContainer.new(); cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(cc)
	var mc := MarginContainer.new(); mc.custom_minimum_size.x = 900
	for s in ["top", "bottom"]: mc.add_theme_constant_override("margin_" + s, 14)
	cc.add_child(mc)
	body = VBoxContainer.new(); body.add_theme_constant_override("separation", 10); mc.add_child(body)
	viz = BenchViz.new()


func open(tab: String) -> void:
	var b: Dictionary = Game.st.bn
	b.tab = "store" if tab == "store" else ("ord" if tab == "bench" else b.tab)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	draw_ui()


func close() -> void:
	visible = false
	closed.emit()


func act(v: String) -> void:
	var sel := Game.bn_act(v)
	if sel != "":
		viz.swap(sel)
	if visible: draw_ui()


func card() -> VBoxContainer:
	var p := Kit.panel(Kit.sb(Color("#1b2735"), 10, 1, Color("#2f4357"), 12))
	body.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); p.add_child(v)
	return v


func bbtn(t: String, v: String, on := false, disabled := false) -> Button:
	var b := Kit.button(t, "", 14)
	b.add_theme_stylebox_override("normal", Kit.sb(Kit.TEAL if on else Color("#14202c"), 8, 2, Kit.TEAL, 8))
	b.add_theme_stylebox_override("hover", Kit.sb(Kit.TEAL, 8, 2, Kit.TEAL, 8))
	b.disabled = disabled
	b.pressed.connect(act.bind(v))
	return b


func draw_ui() -> void:
	var st: Dictionary = Game.st
	var b: Dictionary = st.bn
	for c in tabs.get_children(): c.queue_free()
	for t in [["ord","Órdenes"],["bench","Banco"],["store","Almacén"]]:
		var tb := Kit.button(t[1], "", 14)
		tb.add_theme_stylebox_override("normal", Kit.sb(Kit.WARM if b.tab == t[0] else Kit.TEAL, 8, 0, Color.TRANSPARENT, 8))
		if b.tab == t[0]: tb.add_theme_color_override("font_color", Kit.INK)
		tb.pressed.connect(act.bind("tab:" + t[0]))
		tabs.add_child(tb)
	tabs.add_child(Kit.label("💰 $%d" % int(Game.G.money), 15, Color.WHITE, true))
	if viz.get_parent(): viz.get_parent().remove_child(viz)
	for c in body.get_children(): c.queue_free()
	var o = st.rq[b.o] if b.o < st.rq.size() else null
	if b.tab == "ord":
		body.add_child(Kit.label("Órdenes de reparación de hoy", 20, Color.WHITE, true))
		for i in st.rq.size():
			var q: Dictionary = st.rq[i]
			var c := card()
			c.add_child(Kit.label("#%d · %s — %s" % [101 + i, q.mod, q.own], 15, Color.WHITE, true))
			c.add_child(Kit.label(Data.FAULTS[q.f].sym, 13, Color(1, 1, 1, .75), false, true))
			if q.fixed: c.add_child(Kit.label("✔ Reparado", 14, Kit.OK, true))
			else:
				var ob := bbtn("Abrir en el banco", "open:%d" % i); ob.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; c.add_child(ob)
		return
	if b.tab == "store":
		body.add_child(Kit.label("Almacén de piezas", 20, Color.WHITE, true))
		body.add_child(Kit.label("Saldo: $%d · Cobras al terminar cada jornada." % int(Game.G.money), 14, Color(1, 1, 1, .85)))
		for k in Data.PARTS:
			var c := card()
			c.add_child(Kit.label("%s — $%d · En stock: %d" % [Data.PARTS[k][0], Game.price(k), int(Game.G.parts.get(k, 0))], 15, Color.WHITE, true))
			var h := HBoxContainer.new(); c.add_child(h)
			h.add_child(bbtn("Comprar", "buy:" + k))
			h.add_child(bbtn("Pedir por garantía (40 min)", "rma:" + k))
		return
	if o == null:
		body.add_child(Kit.label("No hay órdenes.", 15)); return
	var f: Dictionary = Data.FAULTS[o.f]
	var dg := Game.sk("diag")
	body.add_child(Kit.label("#%d · %s de %s" % [101 + b.o, o.mod, o.own], 20, Color.WHITE, true))
	viz.order = o
	body.add_child(viz)
	if o.fixed:
		body.add_child(Kit.label("✔ Reparado: la PC de %s arrancó correctamente." % o.own, 15, Kit.OK, true)); return
	body.add_child(Kit.label("🔧 Síntoma: " + f.sym, 15, Color.WHITE, true))
	if dg >= 1: body.add_child(Kit.label("Pista del síntoma: revisa " + f.cat + ".", 13, Color(1, 1, 1, .7)))
	var g := GridContainer.new(); g.columns = 7; g.add_theme_constant_override("h_separation", 6); body.add_child(g)
	for c in Data.COMP:
		var cb := bbtn("%s\n%s%s" % [c[2], c[1], "\n⚠" if dg >= 3 and c[0] == f.c else ""], "sel:" + c[0], o.sel == c[0])
		cb.custom_minimum_size = Vector2(118, 70)
		g.add_child(cb)
	if o.sel != "":
		body.add_child(Kit.label("%s — herramientas %s:" % [Game.comp_name(o.sel), "(pruebas gratis)" if dg >= 2 else "(2 min cada una)"], 14, Color.WHITE, true))
		var th := HFlowContainer.new(); body.add_child(th)
		for t in Data.TOOLS: th.add_child(bbtn(t[1], "test:" + t[0]))
	else:
		body.add_child(Kit.label("Selecciona un componente para probarlo.", 14, Color(1, 1, 1, .8)))
	var lg := Kit.panel(Kit.sb(Color("#05080c"), 8, 0, Color.TRANSPARENT, 10)); body.add_child(lg)
	var lt := Label.new(); lt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lt.add_theme_font_override("font", Kit.mono()); lt.add_theme_font_size_override("font_size", 13); lt.add_theme_color_override("font_color", Color("#cfe8d5"))
	lt.text = "\n".join(o.log) if o.log.size() else "Sin pruebas todavía."
	lg.add_child(lt)
	if o.sel != "":
		body.add_child(Kit.label("Reemplazar el componente con una pieza del inventario:", 14, Color.WHITE, true))
		var ph := HFlowContainer.new(); body.add_child(ph)
		for k in Data.PARTS:
			ph.add_child(bbtn("%s (%d)" % [Data.PARTS[k][0], int(Game.G.parts.get(k, 0))], "rep:" + k, false, int(Game.G.parts.get(k, 0)) < 1))


func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e.pressed and e.keycode == KEY_ESCAPE:
		close(); get_viewport().set_input_as_handled()


class BenchViz:
	extends Control
	const PCL := {"psu":["#3b3f4a",[28,196,150,74]],"mb":["#1f7a4a",[200,34,210,232]],"cpu":["#8a8f99",[262,92,70,70]],"ram":["#2f6fd0",[350,52,20,100]],"ssd":["#6a6f7a",[430,200,86,44]],"gpu":["#7a2f90",[214,226,196,22]],"cmos":["#d0a030",[224,60,22,22]]}
	var order = null
	var _swap := {}
	var _open := 0.0
	var _last = null

	func _ready() -> void:
		custom_minimum_size = Vector2(560, 300)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	func swap(comp: String) -> void:
		_swap = {"comp": comp, "t0": Time.get_ticks_msec(), "o": order}

	func _process(_dt: float) -> void:
		if is_visible_in_tree(): queue_redraw()

	func _part(id: String, d: Vector2, mode: String, alpha: float) -> void:
		var p: Array = PCL[id]
		var col := Color("#2fbf6a") if mode == "new" else Color(p[0])
		col.a = alpha
		var r := Rect2(p[1][0] + d.x, p[1][1] + d.y, p[1][2], p[1][3])
		var ln := Color("#b8ffd0") if mode == "new" else Color(0, 0, 0, .5)
		ln.a *= alpha
		if id == "cpu" or id == "cmos":
			var c := r.get_center(); var rad := minf(r.size.x, r.size.y) / 2
			draw_circle(c, rad, col); draw_arc(c, rad, 0, TAU, 32, ln, 3 if mode == "new" else 2, true)
			if id == "cpu":
				for i in 4: draw_arc(c, 6 + i * 7, 0, TAU, 24, Color(.16, .18, .21, alpha), 1.5, true)
		else:
			draw_style_box(Kit.sb(col, 6, 3 if mode == "new" else 2, ln, 0), r)
			if id == "gpu":
				draw_circle(Vector2(r.position.x + 50, r.get_center().y), 8, Color(.13, .13, .13, alpha))
				draw_circle(Vector2(r.end.x - 50, r.get_center().y), 8, Color(.13, .13, .13, alpha))
			if id == "ram": draw_rect(Rect2(r.position.x + 4, r.position.y + 8, r.size.x - 8, 6), Color(1, 1, 1, .33 * alpha))

	func _draw() -> void:
		var o = order
		if o == null: return
		var t := Time.get_ticks_msec()
		if _last != o: _last = o; _open = t
		var op := minf(1, (t - _open) / 700.0)
		draw_rect(Rect2(0, 0, 560, 300), Color("#14181f"))
		draw_rect(Rect2(14, 14, 532, 272), Color("#4a5568"), false, 4)
		draw_rect(Rect2(18, 18, 524, 264), Color("#1b2029"))
		var sw: Dictionary = _swap if _swap.get("o") == o else {}
		var pr: float = (t - sw.t0) / 1500.0 if sw.size() else 2.0
		for c in Data.COMP:
			var id: String = c[0]
			if not PCL.has(id): continue
			var inst: bool = o.inst.has(id)
			var sel: bool = o.sel == id and not o.fixed
			var lift := -22 + sin(t / 260.0) * 3 if sel else 0.0
			var p: Array = PCL[id][1]
			draw_dashed_line(Vector2(p[0] - 2, p[1] - 2), Vector2(p[0] + p[2] + 2, p[1] - 2), Color(1, 1, 1, .25), 1, 5)
			draw_dashed_line(Vector2(p[0] - 2, p[1] + p[3] + 2), Vector2(p[0] + p[2] + 2, p[1] + p[3] + 2), Color(1, 1, 1, .25), 1, 5)
			if sw.size() and sw.comp == id and pr < 1:
				if pr < .5: _part(id, Vector2(pr / .5 * 180, -pr / .5 * 80), "", 1 - pr / .5)
				else:
					var k: float = (pr - .5) / .5
					_part(id, Vector2((1 - k) * 150, (1 - k) * -70), "new", k)
			else:
				_part(id, Vector2(0, lift), "new" if inst else "", 1)
			if sel:
				CanvasTex.text(self, "⬆ " + c[1] + " desmontado", Vector2(p[0], maxf(30, p[1] + lift - 8)), 13, Color("#ffd27a"))
		CanvasTex.text(self, "Bandeja de piezas retiradas:", Vector2(24, 230), 12, Color(1, 1, 1, .6), HORIZONTAL_ALIGNMENT_LEFT, -1, false)
		for i in o.out.size():
			draw_rect(Rect2(24 + i * 34, 240, 28, 22), Color("#b03a2a"))
			for c in Data.COMP:
				if c[0] == o.out[i]: CanvasTex.text(self, c[2], Vector2(27 + i * 34, 256), 14, Color.WHITE)
		if o.fixed:
			CanvasTex.text(self, "✔ La PC arrancó", Vector2(280, 274), 22, Color("#2fbf6a"), HORIZONTAL_ALIGNMENT_CENTER)
			draw_circle(Vector2(526, 34), 7, Color("#38e08a") if t % 800 < 400 else Color("#1b6a40"))
		elif op < 1:
			draw_rect(Rect2(18 + op * 524, 18, (1 - op) * 524, 264), Color("#8a96a2"))
