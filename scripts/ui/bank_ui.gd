class_name BankUI
extends Control
## Ventana de misiones de los bancos (tablero, departamentos y misión paso a paso).

signal closed

const CD = preload("res://scripts/city/city_data.gd")
var box: PanelContainer
var body: VBoxContainer
var bank_name := ""
var _m: Dictionary
var _i := 0
var _sc: Array = []
var _fb: Array = []


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new(); dim.color = Color(.02, .04, .07, .72); Kit.full_rect(dim); add_child(dim)
	var cc := CenterContainer.new(); Kit.full_rect(cc); add_child(cc)
	box = Kit.panel(Kit.sb(Color("#101a26"), 14, 1, Color("#2c4358"), 20, 18))
	box.custom_minimum_size = Vector2(680, 0)
	cc.add_child(box)
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(660, 0); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sc)
	body = VBoxContainer.new(); body.add_theme_constant_override("separation", 8); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)


static func bk() -> Dictionary:
	if not Game.G.has("bk") or not (Game.G.bk is Dictionary):
		Game.G.bk = {"role": null, "act": null, "done": {}, "total": 0, "earn": 0}
	return Game.G.bk


static func done_today(m: Dictionary) -> bool:
	return int(bk().done.get(m.id, -1)) == int(Game.G.day)


func _clear() -> void:
	for c in body.get_children(): c.queue_free()


func _open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var h: float = minf(get_viewport_rect().size.y * .86, 760)
	box.get_child(0).custom_minimum_size.y = h


func close() -> void:
	visible = false
	closed.emit()


func _h(t: String) -> void: body.add_child(Kit.label(t, 22, Color.WHITE, true, true))
func _s(t: String) -> void: body.add_child(Kit.label(t, 13, Color("#9db3c8"), false, true))
func _p(t: String) -> void: body.add_child(Kit.label(t, 15, Color("#e8eef5"), false, true))


func _btn(t: String, cb: Callable, variation := "", full := false) -> Button:
	var b := Kit.button(t, variation, 14)
	b.pressed.connect(cb)
	if full:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(620, 0)
	return b


func _footer() -> void:
	var f := HBoxContainer.new(); f.alignment = BoxContainer.ALIGNMENT_END
	f.add_child(_btn("Cerrar", close, "Warm"))
	body.add_child(f)


func _row(m: Dictionary, here: bool) -> void:
	var dn: Dictionary = CD.DEPT[m.dept]
	var r := HBoxContainer.new(); r.add_theme_constant_override("separation", 10)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.label("%s %s" % [dn.ic, m.t], 15, Color.WHITE, true))
	v.add_child(Kit.label("%s · %s · $%d · %d XP" % [dn.n, m.who, m.money, m.xp], 12, Color("#8aa2b8")))
	r.add_child(v)
	if done_today(m):
		r.add_child(Kit.label("✔ Hecha hoy", 13, Color("#40ff9a"), true))
	else:
		var a: bool = bk().act == m.id
		var mm := m
		r.add_child(_btn("Comenzar" if here else ("✅ Aceptada" if a else "Aceptar"), func(): _go(mm) if here else _accept(mm), "Warm" if a else ""))
	body.add_child(r)
	var sep := HSeparator.new(); body.add_child(sep)


func board(bname: String) -> void:
	bank_name = bname
	_clear(); _open()
	var k := bk()
	var act := CD.mission(str(k.act)) if k.act != null else {}
	_h("📋 Tablero de misiones")
	_s("%s · Elige tu área (cambia tu experiencia) y acepta una misión. Una misión por vez, una vez al día cada una." % bname)
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8)
	for q in CD.DEPT:
		var qq: String = q
		tabs.add_child(_btn("%s %s" % [CD.DEPT[q].ic, CD.DEPT[q].n], func(): bk().role = qq; Game.save(); board(bname), "Warm" if k.role == q else ""))
	body.add_child(tabs)
	var info := ("Tu puesto: %s (+20%% de pago en tu área)" % CD.DEPT[k.role].role) if k.role != null else "Aún no tienes área: elige una arriba."
	if act.size(): info += "\n▶ Misión activa: %s → %s" % [act.t, CD.DEPT[act.dept].n]
	_s(info)
	for m in CD.MIS:
		if k.role == null or m.dept == k.role: _row(m, false)
	_s("Misiones completadas: %d · Ganado en el banco: $%d" % [int(k.total), int(k.earn)])
	_footer()


func dept(dp: String, bname: String) -> void:
	bank_name = bname
	var k := bk()
	var act := CD.mission(str(k.act)) if k.act != null else {}
	if act.size() and act.dept == dp and not done_today(act):
		_go(act); return
	_clear(); _open()
	_h("%s %s" % [CD.DEPT[dp].ic, CD.DEPT[dp].n])
	_s(("Tu misión activa es de otra área (%s). Puedes cambiarla aquí:" % CD.DEPT[act.dept].n) if act.size() else "Misiones disponibles en esta área:")
	for m in CD.MIS:
		if m.dept == dp: _row(m, true)
	_footer()


func _accept(m: Dictionary) -> void:
	bk().act = m.id; Game.save()
	close()
	Game.toast("📋 Misión aceptada: %s → ve a %s" % [m.t, CD.DEPT[m.dept].n])


func _go(m: Dictionary) -> void:
	_m = m; _i = 0; _sc = []; _fb = []
	bk().act = m.id
	_open()
	_step()


func _step() -> void:
	_clear()
	var s: Dictionary = _m.steps[_i]
	_h("%s %s" % [CD.DEPT[_m.dept].ic, _m.t])
	_s("%s · Paso %d/%d" % [_m.who, _i + 1, _m.steps.size()])
	_p(s.q)
	if s.has("ev"):
		var ev := Kit.label(s.ev, 13, Color("#7fe0b0"), false, true)
		ev.add_theme_font_override("font", Kit.mono())
		var pn := Kit.panel(Kit.sb(Color("#06101a"), 8, 1, Color("#1d3347"), 10))
		pn.add_child(ev); body.add_child(pn)
	for j in s.o.size():
		var jj = j
		body.add_child(_btn(s.o[j][0], func(): _pick(jj), "", true))


func _pick(j: int) -> void:
	var o: Array = _m.steps[_i].o[j]
	_sc.append(float(o[1])); _fb.append(o[2])
	var last = _i >= _m.steps.size() - 1
	_clear()
	_h("%s %s" % [CD.DEPT[_m.dept].ic, _m.t])
	var ok: float = o[1]
	body.add_child(Kit.label("✔ Correcto" if ok >= 1 else ("◐ Parcial" if ok > 0 else "✘ Incorrecto"), 18, Kit.OK if ok >= 1 else (Kit.WARM if ok > 0 else Kit.BAD), true))
	_p(o[2])
	Game.beep(660 if ok >= 1 else 220, .08)
	var f := HBoxContainer.new(); f.alignment = BoxContainer.ALIGNMENT_END
	f.add_child(_btn("Ver resultado" if last else "Siguiente", func(): _next(), "Warm"))
	body.add_child(f)


func _next() -> void:
	_i += 1
	if _i >= _m.steps.size(): _result()
	else: _step()


func _result() -> void:
	var k := bk()
	var avg := 0.0
	for v in _sc: avg += v
	avg /= maxf(1, _sc.size())
	var bonus := 1.2 if k.role == _m.dept else 1.0
	var mo := int(round(_m.money * avg * bonus))
	var xp := int(round(_m.xp * avg * bonus))
	Game.G.money = int(Game.G.money) + mo
	Game.G.xp = int(Game.G.xp) + xp
	k.done[_m.id] = int(Game.G.day); k.act = null; k.total = int(k.total) + 1; k.earn = int(k.earn) + mo
	if k.role == null: k.role = _m.dept
	if Game.st.has("sat") and not Game.st.get("over", false):
		if _m.dept != "soc": Game.st.sat = clampi(int(Game.st.sat) + (5 if avg >= .6 else -4), 0, 100)
		if _m.dept != "cs": Game.st.sec = clampi(int(Game.st.sec) + (5 if avg >= .6 else -4), 0, 100)
	Game.save(); Game.hud()
	Game.toast(("✅ Misión cumplida: " if avg >= .6 else "⚠ Misión con fallas: ") + _m.t)
	_clear()
	_h("¡Excelente!" if avg >= .9 else ("Bien hecho" if avg >= .6 else "Necesitas repasar"))
	_p("Resultado: %d%% · +$%d · +%d XP%s" % [int(avg * 100), mo, xp, " (bono de tu área)" if bonus > 1 else ""])
	for f in _fb: _s("• " + str(f))
	_footer()
