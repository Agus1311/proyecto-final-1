class_name RemoteUI
extends Control
## Escritorio remoto / PC de un usuario (openRD del original).

signal closed
signal resolve_ticket(ix: int)

var i := -1
var local := false
var t0 := 0.0
var desk: Desktop
var title_l: Label
var timer_l: Label
var tk_b: Button
var scripts_p: PanelContainer
var holder: Control


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	var bg := ColorRect.new(); bg.color = Color("#0a0d14"); Kit.full_rect(bg); add_child(bg)
	var v := VBoxContainer.new(); Kit.full_rect(v); v.add_theme_constant_override("separation", 0); add_child(v)
	var bar := Kit.panel(Kit.sb(Color("#1b2230"), 0, 0, Color.TRANSPARENT, 8))
	v.add_child(bar)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); bar.add_child(h)
	title_l = Kit.label("", 14, Color("#e8eaf0"))
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(title_l)
	timer_l = Kit.label("0:00", 13, Color(1, 1, 1, .7)); h.add_child(timer_l)
	tk_b = _bb("Resolver ticket", Kit.TEAL); tk_b.pressed.connect(_resolve); h.add_child(tk_b)
	var sc := _bb("Enviar script", Kit.TEAL); sc.pressed.connect(_toggle_scripts); h.add_child(sc)
	var cx := _bb("Cerrar sesión", Color("#a63b2f")); cx.pressed.connect(close); h.add_child(cx)
	holder = Control.new(); holder.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(holder)
	scripts_p = Kit.panel(Kit.sb(Color("#1b2230"), 10, 1, Color("#3a4a66"), 12, 14))
	scripts_p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	scripts_p.position = Vector2(-392, 52)
	scripts_p.custom_minimum_size.x = 380
	scripts_p.visible = false
	add_child(scripts_p)
	Game.remote_changed.connect(_on_remote_changed)


func _on_remote_changed(k: int) -> void:
	if visible and k == i and desk:
		desk.refresh(["tasks", "files", "mail"])


func _bb(t: String, c: Color) -> Button:
	var b := Kit.button(t, "", 13)
	b.add_theme_stylebox_override("normal", Kit.sb(c, 8, 0, Color.TRANSPARENT, 7))
	b.add_theme_stylebox_override("hover", Kit.sb(c.lightened(.12), 8, 0, Color.TRANSPARENT, 7))
	return b


func open(idx: int, is_local: bool) -> void:
	i = idx
	local = is_local
	t0 = Time.get_ticks_msec()
	var p: Dictionary = Game.st.pc[i]
	var u: Array = Data.USERS[i]
	if p.tube and not Game.br.has(str(i)):
		Game.br[str(i)] = {"u": "youtube.com/watch?v=%d" % randi_range(0, 9), "h": []}
	title_l.text = ("Usando la PC de %s (en persona) · %s" % [u[1], p.name]) if local else ("Conectado a %s · %s · ID %s" % [u[1], p.name, Apps.gid(p.id)])
	tk_b.text = ("Resolver ticket de " + u[1].split(" ")[0]) if Game.tk_for(i) >= 0 else "Sin tickets pendientes"
	if desk:
		desk.queue_free()
	desk = Desktop.new()
	desk.setup(i, Desktop.APPS_U)
	holder.add_child(desk)
	desk.power.connect(close)
	visible = true
	scripts_p.visible = false
	Game.adv(3 if local else 5)
	if p.tube and not local:
		Game.toast(u[1].split(" ")[0] + " está viendo videos en horario laboral")
	if visible and desk:
		desk.open_app("browser" if p.tube else "mail")


func close() -> void:
	visible = false
	scripts_p.visible = false
	Apps.vp.on = false
	if desk:
		desk.queue_free()
		desk = null
	closed.emit()


func _resolve() -> void:
	var ix := Game.tk_for(i)
	if ix < 0:
		Game.toast("Este usuario no tiene tickets pendientes")
		return
	close()
	resolve_ticket.emit(ix)


func _toggle_scripts() -> void:
	scripts_p.visible = not scripts_p.visible
	if not scripts_p.visible:
		return
	for c in scripts_p.get_children(): c.queue_free()
	var p: Dictionary = Game.st.pc[i]
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); scripts_p.add_child(v)
	v.add_child(Kit.label("Síntomas detectados", 15, Color.WHITE, true))
	var sy := Game.symptoms(p)
	if sy.is_empty(): sy = ["Sin síntomas"]
	for s in sy:
		var l := Kit.label("•  " + s, 13, Color("#e8eaf0"), false, true); l.custom_minimum_size.x = 350; v.add_child(l)
	v.add_child(Kit.label("Enviar script a " + p.name, 15, Color.WHITE, true))
	for q in Data.SCRIPTS:
		var hint: bool = Game.sk("ps") > 0 and (p.iss.has(q[2]) or (q[2] == "av" and Game.av_issue(p)))
		var b := Kit.button(("⭐ " if hint else "") + q[0] + "\n" + q[1], "", 13)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", Kit.sb(Kit.TEAL, 8, 0, Color.TRANSPARENT, 8))
		var key: String = q[2]
		b.pressed.connect(func(): Game.run_script(i, key); scripts_p.visible = false)
		v.add_child(b)


func _process(_dt: float) -> void:
	if visible:
		timer_l.text = Apps.mm((Time.get_ticks_msec() - t0) / 1000.0)
