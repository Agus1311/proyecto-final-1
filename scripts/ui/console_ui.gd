class_name ConsoleUI
extends Control
## Consola del switch core (Cisco Catalyst 2960).

signal closed

var sw: CiscoSwitch
var goals_l: RichTextLabel
var ports_g: GridContainer
var term: RichTextLabel
var ps_l: Label
var input: LineEdit
var _closing := false


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	var bg := ColorRect.new(); bg.color = Color(0.043, 0.067, 0.094, .95); Kit.full_rect(bg); add_child(bg)
	var sc := ScrollContainer.new(); Kit.full_rect(sc); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(sc)
	var cc := CenterContainer.new(); cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.add_child(cc)
	var p := Kit.panel(Kit.sb(Color("#16202b"), 10, 2, Kit.TEAL, 16, 18))
	p.custom_minimum_size.x = 820
	cc.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); p.add_child(v)
	v.add_child(Kit.label("Consola del switch core — Cisco Catalyst 2960", 22, Color.WHITE, true))
	var gp := Kit.panel(Kit.sb(Color("#101923"), 8, 0, Color.TRANSPARENT, 12))
	v.add_child(gp)
	goals_l = RichTextLabel.new()
	goals_l.bbcode_enabled = true
	goals_l.fit_content = true
	goals_l.add_theme_font_override("normal_font", Kit.reg())
	goals_l.add_theme_font_override("bold_font", Kit.bold())
	goals_l.add_theme_font_size_override("normal_font_size", 15)
	goals_l.add_theme_font_size_override("bold_font_size", 15)
	goals_l.add_theme_constant_override("line_separation", 4)
	gp.add_child(goals_l)
	ports_g = GridContainer.new()
	ports_g.columns = 13
	ports_g.add_theme_constant_override("h_separation", 6)
	ports_g.add_theme_constant_override("v_separation", 6)
	v.add_child(ports_g)
	var tp := Kit.panel(Kit.sb(Color("#05080c"), 6, 0, Color.TRANSPARENT, 10))
	v.add_child(tp)
	var tv := VBoxContainer.new(); tp.add_child(tv)
	term = RichTextLabel.new()
	term.custom_minimum_size.y = 300
	term.scroll_following = true
	term.selection_enabled = true
	term.add_theme_font_override("normal_font", Kit.mono())
	term.add_theme_font_size_override("normal_font_size", 13)
	term.add_theme_color_override("default_color", Color("#cfe8d5"))
	tv.add_child(term)
	var line := HBoxContainer.new(); tv.add_child(line)
	var sep := ColorRect.new(); sep.color = Color("#1d2a36"); sep.custom_minimum_size.y = 1
	tv.add_child(sep); tv.move_child(sep, 1)
	ps_l = Label.new(); ps_l.add_theme_font_override("font", Kit.mono()); ps_l.add_theme_font_size_override("font_size", 14); ps_l.add_theme_color_override("font_color", Color("#cfe8d5"))
	line.add_child(ps_l)
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_font_override("font", Kit.mono())
	input.add_theme_font_size_override("font_size", 15)
	input.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	input.context_menu_enabled = false
	input.text_submitted.connect(_submit)
	input.gui_input.connect(_input_keys)
	line.add_child(input)
	var lg := Kit.label("Rojo = puerto apagado · Azul = access en VLAN distinta de 1 · Verde = troncal. Toca un puerto para escribir su interfaz.", 13, Color(1, 1, 1, .7), false, true)
	v.add_child(lg)
	var bx := Kit.button("Salir (Esc)", "", 15)
	bx.add_theme_stylebox_override("normal", Kit.sb(Kit.TEAL, 8, 0, Color.TRANSPARENT, 10))
	bx.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bx.pressed.connect(close)
	v.add_child(bx)


func bind(s: CiscoSwitch) -> void:
	sw = s
	sw.output.connect(func(t: String): term.add_text(t))
	sw.job_completed.connect(_on_job)


func open() -> void:
	visible = true
	_closing = false
	if sw.log_text == "":
		sw.say("Cisco IOS Software, C2960 Software (C2960-LANBASEK9-M), Version 15.0(2)SE4\nCatalyst 2960-24TT · Switch core del data center\nEscribe ? para ver los comandos disponibles.\n")
	_refresh()
	input.grab_focus()


func reset_term() -> void:
	term.clear()


func close() -> void:
	visible = false
	input.release_focus()
	closed.emit()


func _submit(v: String) -> void:
	input.text = ""
	sw.submit(v)
	_refresh()
	input.grab_focus()


func _input_keys(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_UP:
			sw.hi = max(0, sw.hi - 1)
			input.text = sw.hist[sw.hi] if sw.hi < sw.hist.size() else ""
			input.caret_column = input.text.length()
			accept_event()
		elif e.keycode == KEY_DOWN:
			sw.hi = min(sw.hist.size(), sw.hi + 1)
			input.text = sw.hist[sw.hi] if sw.hi < sw.hist.size() else ""
			input.caret_column = input.text.length()
			accept_event()
		elif e.keycode == KEY_ESCAPE:
			close()
			accept_event()


func _refresh() -> void:
	ps_l.text = "Password:" if sw.pend else sw.ps()
	input.secret = sw.pend != 0
	# objetivos
	if sw.ji >= sw.jobs.size():
		goals_l.text = "[b]Mantenimiento completado.[/b]"
	else:
		var J: Dictionary = sw.jobs[sw.ji]
		var ok := sw.goal_state()
		var t := "[b]Trabajo %d de 3: %s[/b]\n" % [sw.ji + 1, J.t]
		for i in J.g.size():
			t += ("[color=#7ddc6a]✔[/color] " if ok[i] else "○ ") + J.g[i][0] + "\n"
		t += "[color=#ffffffaa][font_size=13]Pista: %s[/font_size][/color]" % J.h
		goals_l.text = t
	# puertos
	for c in ports_g.get_children():
		c.queue_free()
	for k in sw.PN:
		var p: Dictionary = sw.SW.ports[k]
		var b := Button.new()
		b.text = ("G" + k.substr(k.length() - 1)) if k[0] == "G" else k.substr(4)
		b.tooltip_text = sw.full(k)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 44)
		var bg := Color("#0a0f14"); var bb := Color("#3a4b5a"); var fc := Color("#9fb3c4")
		if p.shut: bg = Color("#a63b2f"); bb = Color("#e8786a"); fc = Color.WHITE
		elif p.mode == "trunk": bg = Color("#4c9a6a"); bb = Color("#9fe0b4"); fc = Color.WHITE
		elif int(p.vlan) != 1: bg = Color("#2a4fd0"); bb = Color("#7da0ff"); fc = Color.WHITE
		var s := Kit.sb(bg, 4, 0, Color.TRANSPARENT, 0); s.border_width_bottom = 3; s.border_color = bb
		b.add_theme_stylebox_override("normal", s)
		var sh: StyleBoxFlat = s.duplicate(); sh.bg_color = bg.lightened(.12)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_color_override("font_color", fc)
		b.add_theme_color_override("font_hover_color", fc)
		b.add_theme_font_size_override("font_size", 12)
		var kk := k
		b.pressed.connect(func(): input.text = "interface " + kk.to_lower(); input.grab_focus(); input.caret_column = input.text.length())
		ports_g.add_child(b)


func _on_job(all_done: bool) -> void:
	_refresh()
	if all_done and not _closing:
		_closing = true
		await get_tree().create_timer(1.8).timeout
		close()
		if Game.st.time >= Data.END:
			Game.finish()
