class_name CertUI
extends Control
## Certificado «Soporte Técnico IT Nivel 2» (drawCert del original).

var paper: Control
var player_name := "Técnico"


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	var bg := ColorRect.new(); bg.color = Color(0.04, 0.03, 0.06, .94); Kit.full_rect(bg); add_child(bg)
	var v := VBoxContainer.new(); Kit.full_rect(v); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 12); add_child(v)
	var ar := AspectRatioContainer.new(); ar.ratio = 1600.0 / 1130.0; ar.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(ar)
	paper = Control.new(); paper.draw.connect(_draw_cert); ar.add_child(paper)
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 10); v.add_child(h)
	var d := Kit.button("⬇ Guardar PNG", "Warm", 15); d.pressed.connect(_save); h.add_child(d)
	var x := Kit.button("Cerrar", "Warm", 15); x.pressed.connect(func(): visible = false); h.add_child(x)
	var pad := Control.new(); pad.custom_minimum_size.y = 16; v.add_child(pad)


func open(nm: String) -> void:
	player_name = nm if nm != "" else "Técnico"
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	paper.queue_redraw()


func _draw_cert() -> void:
	var s := paper.size.x / 1600.0
	var W := 1600.0; var H := 1130.0
	paper.draw_set_transform(Vector2.ZERO, 0, Vector2(s, s))
	paper.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(W, 0), Vector2(W, H), Vector2(0, H)]), PackedColorArray([Color("#fff8e8"), Color("#f8ecd0"), Color("#f3e2c0"), Color("#f8ecd0")]))
	paper.draw_rect(Rect2(40, 40, W - 80, H - 80), Color("#b8862a"), false, 14)
	paper.draw_rect(Rect2(70, 70, W - 140, H - 140), Color("#b8862a"), false, 3)
	paper.draw_rect(Rect2(70, 70, W - 140, 150), Color("#0b2a4a"))
	var B := Kit.bold(); var R := Kit.reg()
	var c := func(t: String, y: float, f: Font, sz: int, col: Color):
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		paper.draw_string(f, Vector2(W / 2 - w / 2, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
	c.call("CAA CORP  ·  MESA DE AYUDA", 165, B, 64, Color("#ff9a1f"))
	c.call("¡CONGRATULATIONS!", 380, B, 100, Color("#0b2a4a"))
	c.call("Este certificado se otorga a", 470, R, 40, Color("#5a4a2a"))
	c.call(player_name.substr(0, 30), 610, B, 110, Color("#8a3a1a"))
	paper.draw_rect(Rect2(W / 2 - 420, 640, 840, 5), Color("#b8862a"))
	c.call("Eres Soporte Técnico IT Nivel 2", 760, B, 74, Color("#0b2a4a"))
	c.call("por completar con éxito los 5 niveles: tickets, Active Directory, red Cisco,", 840, R, 34, Color("#4a3a1a"))
	c.call("taller de hardware y respuesta a incidentes (NIST SP 800-61).", 886, R, 34, Color("#4a3a1a"))
	var d := Time.get_datetime_dict_from_unix_time(int(Game.G.get("cert", Time.get_unix_time_from_system())))
	var meses := ["enero","febrero","marzo","abril","mayo","junio","julio","agosto","septiembre","octubre","noviembre","diciembre"]
	c.call("%d de %s de %d" % [d.day, meses[d.month - 1], d.year], 945, R, 32, Color("#4a3a1a"))
	paper.draw_line(Vector2(180, 1020), Vector2(520, 1020), Color("#4a3a1a"), 2)
	paper.draw_line(Vector2(W - 520, 1020), Vector2(W - 180, 1020), Color("#4a3a1a"), 2)
	paper.draw_string(R, Vector2(270, 1055), "Gerencia de TI", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#4a3a1a"))
	paper.draw_string(R, Vector2(W - 450, 1055), "Firma del técnico", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#4a3a1a"))
	paper.draw_circle(Vector2(W / 2, 1040), 54, Color("#b8862a"))
	paper.draw_circle(Vector2(W / 2, 1040), 43, Color("#fff3c8"))
	c.call("★", 1060, B, 52, Color("#b8862a"))


func _save() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 1130)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var p := Control.new(); p.size = Vector2(1600, 1130)
	var me := self
	p.draw.connect(func():
		var old := me.paper
		me.paper = p
		me._draw_cert()
		me.paper = old)
	vp.add_child(p)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/Certificado_Soporte_Tecnico_IT_Nivel_2.png"
	if img.save_png(path) != OK:
		path = ProjectSettings.globalize_path("user://Certificado_Soporte_Tecnico_IT_Nivel_2.png")
		img.save_png(path)
	vp.queue_free()
	Game.toast("🏅 Certificado guardado en " + path, 6000)
