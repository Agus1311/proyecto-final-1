class_name Desktop
extends Control
## Escritorio tipo Windows (mountDesk/dkOpen del original): iconos, ventanas
## arrastrables y redimensionables, menú inicio, notificaciones y barra de tareas.

signal power

const AP := {
	"tickets": ["🎫", "Zoho Desk — Tickets", Vector2(980, 600)],
	"browser": ["🌐", "Navegador", Vector2(860, 540)],
	"connect": ["🖥️", "CAA Connect", Vector2(780, 520)],
	"cmd": ["⬛", "Símbolo del sistema", Vector2(700, 430)],
	"tasks": ["📊", "Administrador de tareas", Vector2(660, 420)],
	"mail": ["✉️", "E-mail", Vector2(820, 500)],
	"files": ["📁", "Descargas", Vector2(580, 420)],
	"vpn": ["🛡️", "CAA OneConnect", Vector2(440, 300)],
	"notes": ["🗒️", "Notas", Vector2(440, 380)],
	"calc": ["🧮", "Calculadora", Vector2(310, 400)],
	"sys": ["💻", "Este equipo", Vector2(500, 390)],
	"chat": ["💬", "Chat del equipo", Vector2(470, 470)],
	"snake": ["🐍", "Snake (descanso)", Vector2(370, 440)],
}
const APPS_ME := ["tickets", "browser", "connect", "cmd", "tasks", "chat", "notes", "calc", "snake", "sys"]
const APPS_U := ["mail", "files", "browser", "cmd", "tasks", "vpn", "notes", "calc", "sys"]
const WALLS := [[Color("#3a1c5a"), Color("#c0502a")], [Color("#0b3b2e"), Color("#2f6f8f")], [Color("#222222"), Color("#555566")], []]

var ctx = "me"
var apps: Array = []
var factory: Callable          # factory(key, body, desktop) -> bool (true si lo montó)
var wins := {}                 # key -> DkWin
var bg: TextureRect
var bg_grad: ColorRect
var layer: Control
var taskbar_apps: HBoxContainer
var clock_l: Label
var bell_badge: Label
var start_menu: PanelContainer
var notif: PanelContainer
var ctx_menu: PanelContainer
var _search: LineEdit
var _list: VBoxContainer
var _wall_i := -1
var _z := 0


func setup(context, app_list: Array) -> void:
	ctx = context
	apps = app_list


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	clip_contents = true
	bg = TextureRect.new()
	bg.texture = CanvasTex.wallpaper()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	Kit.full_rect(bg)
	add_child(bg)
	bg_grad = ColorRect.new()
	Kit.full_rect(bg_grad)
	bg_grad.visible = false
	var gs := Shader.new()
	gs.code = "shader_type canvas_item;\nuniform vec4 a : source_color; uniform vec4 b : source_color;\nvoid fragment(){ COLOR = mix(a, b, clamp((UV.x + UV.y) * .5, 0.0, 1.0)); }"
	var gm := ShaderMaterial.new(); gm.shader = gs
	bg_grad.material = gm
	add_child(bg_grad)
	bg.gui_input.connect(_bg_input)
	bg_grad.gui_input.connect(_bg_input)
	# iconos
	var icons := VFlowContainer.new()
	icons.position = Vector2(12, 12)
	icons.size = Vector2(400, 470)
	icons.add_theme_constant_override("v_separation", 4)
	icons.add_theme_constant_override("h_separation", 4)
	icons.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(icons)
	for k in apps:
		var b := Button.new()
		b.text = AP[k][0] + "\n" + AP[k][1].split(" ")[0]
		b.custom_minimum_size = Vector2(84, 74)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", Kit.sb(Color(1, 1, 1, .2), 6, 0, Color.TRANSPARENT, 4))
		b.add_theme_stylebox_override("pressed", Kit.sb(Color(1, 1, 1, .3), 6, 0, Color.TRANSPARENT, 4))
		b.add_theme_constant_override("outline_size", 5)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, .65))
		b.pressed.connect(open_app.bind(k))
		icons.add_child(b)
	layer = Control.new()
	Kit.full_rect(layer)
	layer.offset_bottom = -46
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	_build_taskbar()
	_build_start()
	_build_notif()
	_build_ctx_menu()
	Game.hud_changed.connect(_tick)
	Game.toast_requested.connect(func(_t, _m): _badge())
	_tick()


# ---------------- barra de tareas ----------------
func _build_taskbar() -> void:
	var tb := Kit.panel(Kit.sb(Color(18 / 255.0, 26 / 255.0, 44 / 255.0, .82), 0, 0, Color.TRANSPARENT, 4))
	tb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tb.offset_top = -46
	add_child(tb)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); tb.add_child(h)
	var start := Button.new()
	start.custom_minimum_size = Vector2(38, 38)
	start.focus_mode = Control.FOCUS_NONE
	start.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	start.add_theme_stylebox_override("hover", Kit.sb(Color(1, 1, 1, .15), 8, 0, Color.TRANSPARENT, 0))
	start.draw.connect(func():
		var cols := [Color("#4cc2ff"), Color("#2a8fe0"), Color("#2a8fe0"), Color("#1a62b8")]
		for i in 4:
			start.draw_rect(Rect2(9 + (i % 2) * 11, 9 + (i / 2) * 11, 9.5, 9.5), cols[i]))
	start.pressed.connect(func():
		start_menu.visible = not start_menu.visible
		notif.visible = false
		if start_menu.visible: _fill_list(); _search.grab_focus())
	h.add_child(start)
	taskbar_apps = HBoxContainer.new()
	taskbar_apps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	taskbar_apps.add_theme_constant_override("separation", 4)
	h.add_child(taskbar_apps)
	for item in [["⌃", "up"], ["🛜", "net"], ["🔊", "vol"]]:
		var b := Button.new(); b.text = item[0]; b.focus_mode = Control.FOCUS_NONE; b.flat = true
		b.add_theme_font_size_override("font_size", 15)
		var key: String = item[1]
		b.pressed.connect(_tray.bind(key, b))
		h.add_child(b)
	var bell := Button.new(); bell.text = "🔔"; bell.flat = true; bell.focus_mode = Control.FOCUS_NONE
	bell.add_theme_font_size_override("font_size", 15)
	bell.pressed.connect(_toggle_notif)
	h.add_child(bell)
	bell_badge = Kit.label("", 10, Color.WHITE, true)
	bell_badge.add_theme_stylebox_override("normal", Kit.sb(Color("#e8433f"), 8, 0, Color.TRANSPARENT, 2))
	bell_badge.position = Vector2(20, 0)
	bell.add_child(bell_badge)
	bell_badge.visible = false
	clock_l = Kit.label("", 12, Color.WHITE)
	clock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(clock_l)
	var pad := Control.new(); pad.custom_minimum_size.x = 6; h.add_child(pad)


func _tray(key: String, b: Button) -> void:
	match key:
		"net":
			Game.toast("🛜 Conectado a CAA-Corp · " + ("192.168.10.55" if ctx is String else Game.st.pc[ctx].ip))
		"vol":
			Game.muted = not Game.muted
			b.text = "🔇" if Game.muted else "🔊"


func _tick() -> void:
	if clock_l and Game.st.has("time"):
		clock_l.text = Game.clock_str() + "\n21/01/2025"


func _badge() -> void:
	if ctx is String and bell_badge:
		var n: int = Game.notes.size() - int(Game.st.get("seen", 0))
		bell_badge.text = str(mini(n, 9)) if n > 0 else ""
		bell_badge.visible = n > 0


func _refresh_bar() -> void:
	for c in taskbar_apps.get_children():
		c.queue_free()
	var top := _top_key()
	for k in wins:
		var w: DkWin = wins[k]
		var b := Button.new()
		b.text = AP[k][0] + " " + AP[k][1].split(" ")[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		var on: bool = k == top and w.visible
		var s := Kit.sb(Color(1, 1, 1, .2 if on else .08), 8, 0, Color.TRANSPARENT, 6)
		s.border_width_bottom = 3; s.border_color = Color("#4cc2ff") if on else Color.TRANSPARENT
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", Kit.sb(Color(1, 1, 1, .25), 8, 0, Color.TRANSPARENT, 6))
		b.pressed.connect(_bar_click.bind(k))
		taskbar_apps.add_child(b)


func _bar_click(k: String) -> void:
	var w: DkWin = wins.get(k)
	if w == null: return
	if w.visible and k == _top_key():
		w.visible = false
	else:
		w.visible = true
		focus_win(k)
	_refresh_bar()


func _top_key() -> String:
	var best := ""
	var z := -1
	for k in wins:
		if wins[k].visible and wins[k].get_index() > z:
			z = wins[k].get_index(); best = k
	return best


# ---------------- menú inicio y notificaciones ----------------
func _build_start() -> void:
	start_menu = Kit.panel(Kit.sb(Color(24 / 255.0, 32 / 255.0, 52 / 255.0, .95), 12, 1, Color(1, 1, 1, .16), 12, 12))
	start_menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	start_menu.position = Vector2(8, -54)
	start_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	start_menu.custom_minimum_size = Vector2(340, 0)
	start_menu.visible = false
	add_child(start_menu)
	var v := VBoxContainer.new(); start_menu.add_child(v)
	_search = LineEdit.new(); _search.placeholder_text = "Buscar aplicaciones"
	_search.text_changed.connect(func(_t): _fill_list())
	v.add_child(_search)
	_list = VBoxContainer.new(); v.add_child(_list)
	var sep := HSeparator.new(); v.add_child(sep)
	var f := HBoxContainer.new(); v.add_child(f)
	var who := Kit.label("👤 " + ("soporte" if ctx is String else Data.USERS[ctx][0]), 14)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_child(who)
	var pw := Kit.button("⏻ Apagar pantalla" if ctx is String else "⏻ Cerrar sesión", "", 13)
	pw.pressed.connect(func(): start_menu.visible = false; power.emit())
	f.add_child(pw)


func _fill_list() -> void:
	for c in _list.get_children(): c.queue_free()
	var q := _search.text.to_lower()
	for k in apps:
		if q != "" and not AP[k][1].to_lower().contains(q): continue
		var b := Button.new(); b.text = AP[k][0] + "   " + AP[k][1]; b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): start_menu.visible = false; open_app(k))
		_list.add_child(b)


func _build_notif() -> void:
	notif = Kit.panel(Kit.sb(Color(24 / 255.0, 32 / 255.0, 52 / 255.0, .95), 12, 1, Color(1, 1, 1, .16), 12, 12))
	notif.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	notif.position = Vector2(-330, -54)
	notif.grow_vertical = Control.GROW_DIRECTION_BEGIN
	notif.custom_minimum_size = Vector2(320, 0)
	notif.visible = false
	add_child(notif)


func _toggle_notif() -> void:
	notif.visible = not notif.visible
	start_menu.visible = false
	if not notif.visible: return
	for c in notif.get_children(): c.queue_free()
	var v := VBoxContainer.new(); notif.add_child(v)
	v.add_child(Kit.label("Notificaciones", 15, Color.WHITE, true))
	if ctx is String and Game.notes.size():
		for n in Game.notes:
			var l := Kit.label(n.t, 13, Color.WHITE, false, true); l.custom_minimum_size.x = 290; v.add_child(l)
			var h := Kit.label(n.h, 11, Color(1, 1, 1, .6)); v.add_child(h)
		Game.st.seen = Game.notes.size()
		_badge()
	else:
		v.add_child(Kit.label("Sin notificaciones", 13))


# ---------------- menú contextual (fondo) ----------------
func _build_ctx_menu() -> void:
	ctx_menu = Kit.panel(Kit.sb(Color("#182034f2"), 10, 1, Color(1, 1, 1, .2), 6))
	ctx_menu.visible = false
	add_child(ctx_menu)
	var v := VBoxContainer.new(); ctx_menu.add_child(v)
	var items := [["🎨 Cambiar fondo", "w"], ["🔄 Actualizar", "r"]]
	if ctx is String:
		items = [["🎨 Cambiar fondo", "w"], ["💬 Abrir chat", "c"], ["🗒️ Abrir notas", "n"], ["🔄 Actualizar", "r"]]
	for it in items:
		var b := Button.new(); b.text = it[0]; b.flat = true; b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.focus_mode = Control.FOCUS_NONE
		var a: String = it[1]
		b.pressed.connect(_ctx_action.bind(a))
		v.add_child(b)


func _ctx_action(a: String) -> void:
	ctx_menu.visible = false
	match a:
		"w":
			_wall_i = (_wall_i + 1) % WALLS.size()
			var wl: Array = WALLS[_wall_i]
			bg_grad.visible = wl.size() > 0
			if wl.size():
				(bg_grad.material as ShaderMaterial).set_shader_parameter("a", wl[0])
				(bg_grad.material as ShaderMaterial).set_shader_parameter("b", wl[1])
		"c": open_app("chat")
		"n": open_app("notes")
		_: Game.toast("🔄 Escritorio actualizado")


func _bg_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		start_menu.visible = false
		notif.visible = false
		if e.button_index == MOUSE_BUTTON_RIGHT:
			ctx_menu.visible = true
			ctx_menu.reset_size()
			ctx_menu.position = (e.global_position - global_position).min(size - Vector2(200, 200))
		else:
			ctx_menu.visible = false


# ---------------- ventanas ----------------
func open_app(k: String) -> void:
	start_menu.visible = false
	var w: DkWin = wins.get(k)
	if w:
		w.visible = true
		focus_win(k)
		return
	var a: Array = AP[k]
	w = DkWin.new()
	w.desk = self
	w.key = k
	w.title = a[0] + "  " + a[1]
	layer.add_child(w)
	var n := wins.size()
	var sz: Vector2 = a[2]
	var avail := layer.size if layer.size.x > 10 else get_viewport_rect().size - Vector2(0, 46)
	sz = sz.min(avail * Vector2(.94, .9))
	if k == "tickets":
		sz = avail * Vector2(.86, .9)
	w.size = sz
	w.position = Vector2(36 + n * 26, 24 + n * 22).min(avail - sz).max(Vector2.ZERO)
	if k == "tickets":
		w.position = Vector2((avail.x - sz.x) / 2 + 40, (avail.y - sz.y) / 2)
	wins[k] = w
	mount(k)
	focus_win(k)


func mount(k: String) -> void:
	var w: DkWin = wins.get(k)
	if w == null: return
	for c in w.body.get_children():
		c.queue_free()
	if factory.is_valid() and factory.call(k, w.body, self):
		return
	Apps.mount(k, w.body, ctx, self)


func refresh(keys: Array) -> void:
	for k in keys:
		if wins.has(k): mount(k)


func focus_win(k: String) -> void:
	var w: DkWin = wins.get(k)
	if w:
		layer.move_child(w, -1)
	_refresh_bar()


func close_win(k: String) -> void:
	var w: DkWin = wins.get(k)
	if w == null: return
	if k == "tickets" and factory.is_valid():
		factory.call("close_tickets", w.body, self)
	wins.erase(k)
	w.queue_free()
	_refresh_bar.call_deferred()


func min_win(k: String) -> void:
	var w: DkWin = wins.get(k)
	if w:
		w.visible = false
		_refresh_bar()


# =====================================================================
class DkWin:
	extends PanelContainer
	var desk: Desktop
	var key := ""
	var title := ""
	var body: Control
	var _drag := false
	var _resize := false
	var _off := Vector2.ZERO
	var _max := false
	var _restore := Rect2()

	func _ready() -> void:
		var s := Kit.sb(Color("#eceef2"), 8, 1, Color(0, 0, 0, .25), 0, 18)
		add_theme_stylebox_override("panel", s)
		custom_minimum_size = Vector2(260, 160)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); add_child(v)
		var hb := PanelContainer.new()
		var hs := Kit.sb(Color("#f4f6fa"), 0, 0, Color.TRANSPARENT, 4)
		hs.corner_radius_top_left = 8; hs.corner_radius_top_right = 8; hs.content_margin_left = 10
		hb.add_theme_stylebox_override("panel", hs)
		hb.mouse_default_cursor_shape = Control.CURSOR_MOVE
		hb.gui_input.connect(_head_input)
		v.add_child(hb)
		var h := HBoxContainer.new(); hb.add_child(h)
		var t := Kit.label(title, 14, Color("#222222"), true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(t)
		for s2 in ["—", "▢", "✕"]:
			var b := Button.new(); b.text = s2; b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(32, 26)
			b.add_theme_color_override("font_color", Color("#222222")); b.add_theme_color_override("font_hover_color", Color("#222222") if s2 != "✕" else Color.WHITE)
			b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			b.add_theme_stylebox_override("hover", Kit.sb(Color("#d8dce6") if s2 != "✕" else Color("#e8433f"), 4, 0, Color.TRANSPARENT, 2))
			b.add_theme_stylebox_override("pressed", Kit.sb(Color("#c8ccd6"), 4, 0, Color.TRANSPARENT, 2))
			b.pressed.connect(_btn.bind(s2))
			h.add_child(b)
		body = Control.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.clip_contents = true
		v.add_child(body)
		# La esquina de redimensionar va dentro de una capa que ignora el mouse: como hija directa del
		# PanelContainer, el contenedor la estiraba a toda la ventana y se tragaba todos los clics.
		var over := Control.new()
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(over)
		var grip := Control.new()
		grip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		grip.offset_left = -14; grip.offset_top = -14; grip.offset_right = 0; grip.offset_bottom = 0
		grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
		grip.gui_input.connect(_grip_input)
		grip.draw.connect(func():
			for i in 3:
				grip.draw_line(Vector2(13, 4 + i * 4), Vector2(4 + i * 4, 13), Color(0, 0, 0, .3), 1.0))
		over.add_child(grip)
		gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed: desk.focus_win(key))

	func _btn(s2: String) -> void:
		match s2:
			"—": desk.min_win(key)
			"▢": toggle_max()
			_: desk.close_win(key)

	func toggle_max() -> void:
		_max = not _max
		if _max:
			_restore = Rect2(position, size)
			position = Vector2.ZERO
			size = get_parent().size
		else:
			position = _restore.position
			size = _restore.size

	func _head_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.double_click:
				toggle_max(); return
			_drag = e.pressed and not _max
			_off = e.global_position - global_position
			desk.focus_win(key)
		elif e is InputEventMouseMotion and _drag:
			var p: Vector2 = e.global_position - get_parent().global_position - _off
			var ps: Vector2 = get_parent().size
			position = Vector2(clampf(p.x, 0, ps.x - 80), clampf(p.y, 0, ps.y - 40))

	func _grip_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_resize = e.pressed and not _max
		elif e is InputEventMouseMotion and _resize:
			size = (size + e.relative).max(custom_minimum_size)
