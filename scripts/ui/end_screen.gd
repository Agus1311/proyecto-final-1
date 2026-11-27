class_name EndScreen
extends Control
## Resumen de la jornada.

signal go_home

var title_l: Label
var text_l: Label
var ach_l: Label
var reset_b: Button
var _confirm := false


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	var bg := ColorRect.new(); bg.color = Color(0.113, 0.082, 0.125, .95); Kit.full_rect(bg); add_child(bg)
	var cc := CenterContainer.new(); Kit.full_rect(cc); add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 560
	v.add_theme_constant_override("separation", 12)
	cc.add_child(v)
	title_l = Kit.label("", 38, Color.WHITE, true); title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(title_l)
	text_l = Kit.label("", 17, Color(1, 1, 1, .92), false, true); text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(text_l)
	ach_l = Kit.label("", 14, Color(1, 1, 1, .75), false, true); ach_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(ach_l)
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 10); v.add_child(h)
	var gh := Kit.button("Ir a casa", "Warm", 17)
	gh.pressed.connect(func(): visible = false; go_home.emit())
	h.add_child(gh)
	reset_b = Kit.button("Reiniciar progreso", "", 16)
	reset_b.add_theme_stylebox_override("normal", Kit.sb(Color(1, 1, 1, .15), 12, 0, Color.TRANSPARENT, 14))
	reset_b.pressed.connect(_reset)
	h.add_child(reset_b)
	Game.day_finished.connect(show_result)


func show_result(r: Dictionary) -> void:
	title_l.text = r.title
	text_l.text = r.text
	ach_l.text = r.ach
	_confirm = false
	reset_b.text = "Reiniciar progreso"
	visible = true


func _reset() -> void:
	if not _confirm:
		_confirm = true
		reset_b.text = "¿Seguro? Pulsa otra vez"
		return
	Game.reset_progress()
