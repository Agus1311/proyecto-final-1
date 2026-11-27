class_name Minimap
extends Control
## Minimapa: zonas caminables, puestos con tickets pendientes, usuario que te busca y tu posición.

var player_pos := Vector2.ZERO
var player_yaw := 0.0
var seek_pos = null
var zone := 0
var city: Node3D
const SCALE := 4.2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _to_map(p: Vector2) -> Vector2:
	return size / 2 + (p - player_pos) * SCALE


func _city_pt(p: Vector2, sc: float) -> Vector2:
	return size / 2 + (p - player_pos) * sc


func _city_rect(x0: float, x1: float, z0: float, z1: float, c: Color, sc: float) -> void:
	var a := _city_pt(Vector2(x0, z0), sc)
	var b := _city_pt(Vector2(x1, z1), sc)
	draw_rect(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()), c)


func _draw_city() -> void:
	var sc := 1.1
	var D := CityData
	_city_rect(D.XB - 400, D.XA + 400, D.SEAWALL, -2000, Color("#1d4a5a"), sc)
	_city_rect(D.XB, D.XA, -45.2, -28.6, Color("#3f6a3a"), sc)
	_city_rect(D.XB, D.XA, -42.0, -38.0, Color("#b8ad96"), sc)
	_city_rect(D.XB, D.XA, -28.6, -1.3, Color("#3a3d44"), sc)
	_city_rect(D.XB, D.XA, -18.4, -15.8, Color("#4a7a3a"), sc)
	_city_rect(D.XB, D.XA, -1.3, 12.0, Color("#8a8478"), sc)
	_city_rect(D.XB, D.XA, 12.0, 400, Color("#2a2730"), sc)
	for ix in D.IX:
		_city_rect(float(ix[0]) - 5.2, float(ix[0]) + 5.2, -1.3, 200, Color("#3a3d44"), sc)
	if city and city.get("west"):
		for r in city.west.minimap_rects():
			_city_rect(r[0], r[1], r[2], r[3], r[4], sc)
	if city and "traffic" in city:
		for c in city.traffic:
			draw_circle(_city_pt(Vector2(c.x, c.z), sc), 1.8, Color("#e8e8e8") if not c.bus else Color("#38a0ff"))
		var cp: Vector3 = city.car.position
		draw_circle(_city_pt(Vector2(cp.x, cp.z), sc), 3.2, Color("#f2c200"))
	for d in D.DEST + [D.CAA_DEST]:
		var p := _city_pt(Vector2(d.x, 6), sc)
		draw_circle(p, 5, d.acc)
		draw_arc(p, 6.5, 0, TAU, 16, Color(1, 1, 1, .8), 1.2, true)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(Kit.sb(Color(0.11, 0.08, 0.13, .82), 14, 2, Kit.TEAL, 0), r)
	if zone == 2:
		_draw_city()
		var c1 := size / 2
		var fw := Vector2(-sin(player_yaw), -cos(player_yaw)); var sd := Vector2(fw.y, -fw.x)
		draw_colored_polygon(PackedVector2Array([c1 + fw * 9, c1 - fw * 5 + sd * 5.5, c1 - fw * 2, c1 - fw * 5 - sd * 5.5]), Color.WHITE)
		draw_string(Kit.bold(), Vector2(8, 16), "Ciudad de Panamá", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, .85))
		return
	if zone == 3:
		draw_string(Kit.bold(), Vector2(8, 16), "Sucursal bancaria", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, .85))
		var c2 := size / 2
		var fw2 := Vector2(-sin(player_yaw), -cos(player_yaw)); var sd2 := Vector2(fw2.y, -fw2.x)
		draw_colored_polygon(PackedVector2Array([c2 + fw2 * 9, c2 - fw2 * 5 + sd2 * 5.5, c2 - fw2 * 2, c2 - fw2 * 5 - sd2 * 5.5]), Color.WHITE)
		return
	var f2 := player_pos.x > 30
	for w in Game.wk:
		if (w[0] > 30) != f2:
			continue
		var a := _to_map(Vector2(w[0], w[2]))
		var b := _to_map(Vector2(w[1], w[3]))
		draw_rect(Rect2(a, b - a), Color("#2f6f8f") * Color(1, 1, 1, .55))
	for d in Game.dk:
		if (d[0] > 30) != f2:
			continue
		var c := _to_map(Vector2(d[0], d[1]))
		var e := Vector2(d[2], d[3]) * SCALE
		draw_rect(Rect2(c - e * .7, e * 1.4), Color(0, 0, 0, .35))
	# puestos con tickets pendientes
	if Game.st.has("state") and not f2:
		for a in Data.ACT:
			if a.has("loc") and Game.pending_at(a.loc) and a.loc != 0:
				draw_circle(_to_map(Vector2(a.x, a.z)), 4, Kit.BAD)
				draw_arc(_to_map(Vector2(a.x, a.z)), 6, 0, TAU, 16, Color(1, 1, 1, .7), 1.2, true)
	if seek_pos != null:
		draw_circle(_to_map(seek_pos), 4.5, Kit.WARM)
	# jugador (flecha)
	var c0 := size / 2
	var fwd := Vector2(-sin(player_yaw), -cos(player_yaw))
	var side := Vector2(fwd.y, -fwd.x)
	draw_colored_polygon(PackedVector2Array([c0 + fwd * 9, c0 - fwd * 5 + side * 5.5, c0 - fwd * 2, c0 - fwd * 5 - side * 5.5]), Color.WHITE)
	draw_string(Kit.bold(), Vector2(8, 16), "Piso 2" if f2 else "Piso 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, .85))
