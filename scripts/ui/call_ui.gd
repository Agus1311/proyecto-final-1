class_name CallUI
extends Control
## Llamada entrante (showCall del original).

var _i := -1
var box: VBoxContainer


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	var bg := ColorRect.new(); bg.color = Color(0, 0, 0, .7); Kit.full_rect(bg); add_child(bg)
	var cc := CenterContainer.new(); Kit.full_rect(cc); add_child(cc)
	var p := Kit.panel(Kit.sb(Color("#1b2230"), 14, 2, Kit.WARM, 18, 20))
	p.custom_minimum_size.x = 480
	cc.add_child(p)
	box = VBoxContainer.new(); box.add_theme_constant_override("separation", 8); p.add_child(box)
	Game.call_ringing.connect(show_call)


func show_call(i: int) -> void:
	_i = i
	for c in box.get_children(): c.queue_free()
	var d: Array = Data.CALLS[i]
	box.add_child(Kit.label("📞 Llamada entrante", 20, Color.WHITE, true))
	box.add_child(Kit.label(d[0], 16, Kit.WARM, true))
	box.add_child(Kit.label(d[1], 15, Color(1, 1, 1, .92), false, true))
	for k in d[2].size():
		var b := Kit.button(d[2][k][0], "Opt", 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var kk: int = k
		b.pressed.connect(func(): visible = false; Game.call_answer(_i, kk))
		box.add_child(b)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
