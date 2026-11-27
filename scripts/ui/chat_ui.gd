class_name ChatUI
extends VBoxContainer
## Chat de la sala (Enter para escribir). Los mensajes se desvanecen a los 9,5 s.

var input: LineEdit
signal typing_changed(on: bool)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	position = Vector2(16, -260)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(420, 0)
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Kit.theme()
	input = LineEdit.new()
	input.max_length = 120
	input.placeholder_text = "Mensaje y Enter…"
	input.add_theme_stylebox_override("normal", Kit.sb(Color(0, 0, 0, .65), 8, 1, Kit.WARM, 8))
	input.visible = false
	input.text_submitted.connect(_send)
	add_child(input)
	Net.chat.connect(add)


func open() -> void:
	input.visible = true
	input.grab_focus()
	typing_changed.emit(true)


func close() -> void:
	input.text = ""
	input.visible = false
	input.release_focus()
	typing_changed.emit(false)


func _send(t: String) -> void:
	if t.strip_edges() != "":
		if Net.is_online(): Net.send_chat(t)
		else: add(Net.my_name, t)
	close()


func _input(e: InputEvent) -> void:
	if input.visible and e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		close(); get_viewport().set_input_as_handled()


func add(who: String, msg: String) -> void:
	var p := Kit.panel(Kit.sb(Color(0, 0, 0, .58), 8, 0, Color.TRANSPARENT, 8, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := RichTextLabel.new(); l.bbcode_enabled = true; l.fit_content = true; l.scroll_active = false
	l.custom_minimum_size = Vector2(400, 0); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("normal_font", Kit.reg()); l.add_theme_font_override("bold_font", Kit.bold())
	l.add_theme_font_size_override("normal_font_size", 14); l.add_theme_font_size_override("bold_font_size", 14)
	l.text = "[b][color=#e8a77c]%s:[/color][/b] %s" % [who.replace("[", "("), msg.replace("[", "(")]
	p.add_child(l)
	add_child(p)
	move_child(input, get_child_count() - 1)
	while get_child_count() > 8: get_child(0).queue_free(); break
	var tw := create_tween()
	tw.tween_interval(8.5)
	tw.tween_property(p, "modulate:a", 0.0, 1.0)
	tw.tween_callback(p.queue_free)
