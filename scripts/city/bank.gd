class_name Bank
extends Node3D
## Interior de una sucursal bancaria (port del v8): ventanillas con cajeros, atención al
## cliente, gerente con tablero de misiones, cajeros automáticos, bóveda, cola con cuerdas,
## Departamento de TI con racks y SOC con video wall. Clientes que entran, hacen fila,
## pasan a ventanilla o al ATM y se van; guardia que patrulla.

var d: Dictionary
var ox := 0.0
var npcs: Array = []
var leds: Array = []
var win := [null, null, null, null]
var turn := 41
var wall: CanvasTex
var board: CanvasTex
var beacon: StandardMaterial3D
var wk: Array = []
var dk: Array = []
var sts: Array = []
var lights: Array = []
var _wall_t := 0.0
var _last_turn := -1
const WAITS := [[-11.0, -4.1], [-9.0, -4.1], [-7.0, -4.1], [-5.0, -4.1]]


func _m(kind: String, c: Color) -> StandardMaterial3D:
	return Mats.get_mat(kind, c)


func _c(c: Color, rough := .7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m


func _u(c: Color, e := 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = e
	return m


func B(w: float, h: float, dd: float, m: Material, x: float, y: float, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(w, h, dd)
	mi.mesh = bm; mi.material_override = m; mi.position = Vector3(x, y, z)
	add_child(mi)
	return mi


func sgn(t: String, sub: String, x: float, y: float, z: float, ry: float, w: float, h: float, bg: Color, fg: Color) -> void:
	var p := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(w, h)
	p.mesh = qm; p.material_override = _c(bg, .5); p.position = Vector3(x, y, z); p.rotation.y = ry
	add_child(p)
	var fwd := Vector3(sin(ry), 0, cos(ry)) * .02
	var l := Label3D.new(); l.text = t; l.font = Kit.bold(); l.modulate = fg
	l.font_size = int(h * (34.0 if sub != "" else 50.0)); l.pixel_size = .01; l.outline_size = 0
	l.position = Vector3(x, y + (h * .14 if sub != "" else 0.0), z) + fwd; l.rotation.y = ry
	add_child(l)
	if sub != "":
		var l2 := Label3D.new(); l2.text = sub; l2.font = Kit.reg(); l2.modulate = fg
		l2.font_size = int(h * 18.0); l2.pixel_size = .01; l2.outline_size = 0
		l2.position = Vector3(x, y - h * .25, z) + fwd; l2.rotation.y = ry
		add_child(l2)


func build(dd: Dictionary) -> void:
	d = dd
	ox = float(d.ox)
	position = Vector3(ox, 0, 0)
	var col: Color = d.col
	var acc: Color = d.acc
	var wall_m := _m("plaster", Color("#ece6d9"))
	var dark := _c(Color("#2a2e36"), .4, .4)
	var wood := _m("wood", Color("#8a5a2a"))
	var gran := _c(Color("#26292f"), .25, .1)
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(.65, .82, .9, .28); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glass.roughness = .02; glass.metallic_specular = 1
	# piso de mármol pulido y cielo raso con luminarias
	var marble := StandardMaterial3D.new()
	marble.albedo_texture = load("res://assets/textures/city/promenade_albedo.png"); marble.albedo_color = Color(1.02, 1.0, .96)
	marble.normal_enabled = true; marble.normal_texture = load("res://assets/textures/city/promenade_normal.png"); marble.normal_scale = .25
	marble.roughness = .18; marble.uv1_triplanar = true; marble.uv1_world_triplanar = true; marble.uv1_scale = Vector3.ONE / 1.4
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(35, 25); fl.mesh = pm; fl.material_override = marble; add_child(fl)
	var ce := MeshInstance3D.new(); var cm := PlaneMesh.new(); cm.size = Vector2(35, 25); cm.flip_faces = true; ce.mesh = cm
	ce.material_override = _m("ceiling", Color("#f2ede4")); ce.position.y = 4.6; add_child(ce)
	for i in 5:
		for j in 3:
			B(3, .06, .5, _u(Color.WHITE, 2.2), -13 + i * 6.5, 4.56, -8 + j * 8)
	for p in [Vector3(-10, 4.2, -6), Vector3(-10, 4.2, 6), Vector3(0, 4.2, 0), Vector3(11, 4.2, -6), Vector3(11, 4.2, 6), Vector3(-4, 4.2, 9)]:
		var l := OmniLight3D.new(); l.position = p; l.light_color = Color("#fff3e0"); l.light_energy = 1.4; l.omni_range = 11
		l.shadow_enabled = p.x == 0.0
		add_child(l); lights.append(l)
	# paredes
	B(35, 4.6, .4, wall_m, 0, 2.3, -12.2); B(.4, 4.6, 25, wall_m, -17.2, 2.3, 0); B(.4, 4.6, 25, wall_m, 17.2, 2.3, 0)
	B(15.4, 4.6, .4, wall_m, -9.5, 2.3, 12.2); B(15.4, 4.6, .4, wall_m, 9.5, 2.3, 12.2); B(3.6, 1.2, .4, wall_m, 0, 4.0, 12.2)
	B(35, 1.0, .1, _c(col, .4), 0, .5, -11.95); B(35, .14, .12, _c(acc, .3, .7), 0, 1.05, -11.94)
	B(3.6, 3.4, .05, _u(Color("#f6b27a"), 1.0), 0, 1.7, 12.45)
	for x in [-.9, .9]: B(1.7, 3.3, .05, glass, x, 1.65, 12.1)
	B(.1, 3.4, .1, dark, 0, 1.7, 12.1)
	sgn("SALIDA", "Av. Balboa", 0, 3.75, 11.95, PI, 2.4, .6, Color("#0a7a3a"), Color.WHITE)
	# tabique de vidrio hacia TI y SOC
	var seg := func(z0: float, z1: float):
		var L := z1 - z0; var zc := (z0 + z1) / 2
		B(.3, .9, L, wall_m, 5, .45, zc); B(.3, 2.6, L, glass, 5, 2.2, zc); B(.3, 1.1, L, wall_m, 5, 4.05, zc)
	seg.call(-12.0, -7.5); seg.call(-5.5, 7.5); seg.call(9.5, 12.0)
	for p in [[-7.5, -5.5], [7.5, 9.5]]:
		B(.3, 3.6, .2, dark, 5, 1.8, p[0]); B(.3, 3.6, .2, dark, 5, 1.8, p[1]); B(.3, .9, p[1] - p[0], wall_m, 5, 4.05, (p[0] + p[1]) / 2)
	B(12, 4.6, .3, wall_m, 11, 2.3, 0)
	sgn("TI", "Tecnología", 4.8, 3.9, -6.5, -PI / 2, 2.0, .62, Color("#12304a"), Color("#7fd0ff"))
	sgn("SOC", "Ciberseguridad", 4.8, 3.9, 8.5, -PI / 2, 2.0, .62, Color("#3a1226"), Color("#ff8aa8"))
	# ventanillas
	B(14.4, 1.1, 1.5, gran, -8, .55, -8.5); B(14.8, .1, 1.8, _c(Color("#1a1c20"), .2), -8, 1.15, -8.5); B(14.4, 1.3, .05, glass, -8, 1.8, -7.85)
	for i in 5: B(.08, 1.3, .9, dark, -14.3 + i * 3, 1.8, -8.4)
	for i in 4: B(.5, .35, .05, _u(Color("#7fd0ff"), 1.2), -12.5 + i * 3, 1.45, -9.1)
	var sign := MeshInstance3D.new(); var sq := QuadMesh.new(); sq.size = Vector2(9, 2.25); sign.mesh = sq
	var smat := StandardMaterial3D.new(); smat.albedo_texture = load("res://assets/textures/city/%s.png" % d.sign); smat.emission_enabled = true; smat.emission_texture = smat.albedo_texture; smat.emission_energy_multiplier = .4
	sign.material_override = smat; sign.position = Vector3(-8, 3.4, -11.95); add_child(sign)
	# tablero de turnos
	board = CanvasTex.make(self, Vector2i(512, 128), _paint_turns)
	var tm := MeshInstance3D.new(); var tq := QuadMesh.new(); tq.size = Vector2(8, 2); tm.mesh = tq
	tm.material_override = Mats.screen(board.texture(), 1.2); tm.position = Vector3(-8, 3.55, -7.3); add_child(tm)
	# atención al cliente
	B(5, .9, 1.2, wood, 1, .45, -2.5); B(5.2, .08, 1.4, _c(Color("#dcd4c4"), .25), 1, .92, -2.5)
	B(.6, .4, .05, _u(Color("#7fd0ff"), 1.2), -.4, 1.25, -2.7); B(.6, .4, .05, _u(Color("#7fd0ff"), 1.2), 2.4, 1.25, -2.7)
	B(.1, 2.6, .1, dark, -1.4, 1.3, -2.5); B(.1, 2.6, .1, dark, 3.4, 1.3, -2.5)
	sgn("ATENCIÓN AL CLIENTE", "Reclamos · Tarjetas · Consultas", 1, 3.15, -2.45, 0, 4.2, .85, Color("#0b3a6a"), Color.WHITE)
	for x in [-.3, 2.3]: B(.55, .5, .55, _c(Color("#4a4f58"), .5), x, .25, -.6)
	# bóveda
	var vd := MeshInstance3D.new(); var vc := CylinderMesh.new(); vc.top_radius = 1.7; vc.bottom_radius = 1.7; vc.height = .5; vc.radial_segments = 40
	vd.mesh = vc; vd.material_override = _c(Color("#8a9098"), .18, 1.0); vd.rotation.x = PI / 2; vd.position = Vector3(2.6, 2.1, -11.7); add_child(vd)
	for k in 6:
		var a := TAU * k / 6
		B(.08, .9, .08, _c(Color("#c9ced4"), .15, 1.0), 2.6 + cos(a) * .55, 2.1 + sin(a) * .55, -11.4).rotation.z = a
	sgn("BÓVEDA", "Acceso restringido", 2.6, 4.0, -11.9, 0, 2.4, .6, Color("#2a2e36"), Color("#ffd27a"))
	# cajeros automáticos
	for z in [-4.0, -1.8, .4]:
		B(.9, 2.1, 1.0, dark, -16.55, 1.05, z); B(.05, .5, .7, _u(Color("#38e0ff"), 1.4), -16.05, 1.5, z); B(.05, .2, .5, _u(Color("#40ff9a"), 1.2), -16.05, 1.0, z)
		dk.append([ox - 16.5, z, .7, .7])
	sgn("ATM", "24 h", -16.9, 3.0, -1.8, PI / 2, 2.2, .6, Color("#0a2a4a"), Color("#38e0ff"))
	# cola con postes dorados y cordón rojo
	var gold := _c(Color("#c9a227"), .2, 1.0)
	var red := _c(Color("#b0202a"), .5)
	for i in 6:
		for z in [-5.0, -3.0]:
			var pc := MeshInstance3D.new(); var pcm := CylinderMesh.new(); pcm.top_radius = .05; pcm.bottom_radius = .07; pcm.height = 1.0
			pc.mesh = pcm; pc.material_override = gold; pc.position = Vector3(-13 + i * 2, .5, z); add_child(pc)
			if i < 5: B(2, .04, .04, red, -12 + i * 2, .85, z)
	# turnos, bancas y plantas
	B(.7, 1.5, .5, dark, -4, .75, 9.5); B(.5, .3, .05, _u(Color("#40ff9a")), -4, 1.2, 9.22); dk.append([ox - 4, 9.5, .5, .4])
	for z in [5.0, 7.5]:
		B(4, .45, .7, _c(col, .5), -12, .3, z); B(4, .5, .1, _c(col, .5), -12, .7, z + .3); dk.append([ox - 12, z, 2.1, .45])
	for p in [[-16, 11], [16, -11], [-16, -11], [4, 11]]:
		B(.7, .7, .7, _c(Color("#7a5a3a"), .8), p[0], .35, p[1])
		var pl := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = .7; sp.height = 1.3
		pl.mesh = sp; pl.material_override = _c(Color("#2f7a3a"), .8); pl.position = Vector3(p[0], 1.2, p[1]); add_child(pl)
	# gerente y tablero de misiones
	B(1.6, 1.0, .7, wood, 3, .5, 5); B(.4, .1, .3, _u(Color("#ffd27a")), 3, 1.05, 5)
	var bm2 := MeshInstance3D.new(); var bq := QuadMesh.new(); bq.size = Vector2(3.2, 2.4); bm2.mesh = bq
	var bmm := StandardMaterial3D.new(); bmm.albedo_texture = load("res://assets/textures/city/mission_board.png"); bmm.roughness = .8
	bm2.material_override = bmm; bm2.position = Vector3(4.82, 2.1, 3.4); bm2.rotation.y = -PI / 2; add_child(bm2)
	dk.append([ox + 3, 5, 1.0, .55]); dk.append([ox - 8, -8.5, 7.5, 1.0]); dk.append([ox + 1, -2.5, 2.7, .75])
	# TI
	var floor_it := MeshInstance3D.new(); var fp := PlaneMesh.new(); fp.size = Vector2(12, 12); floor_it.mesh = fp
	floor_it.material_override = _m("carpet", Color("#2b3a4c")); floor_it.position = Vector3(11, .012, -6); add_child(floor_it)
	for i in 3:
		B(1.0, 2.3, .9, dark, 16.4, 1.15, -10 + i * 1.4)
		for k in 8:
			var l := B(.08, .05, .02, _u(Color("#40ff9a"), 2.0), 15.9, .4 + k * .25, -10 + i * 1.4 + (.2 if k % 2 else -.2))
			leds.append(l)
		dk.append([ox + 16.4, -10 + i * 1.4, .65, .6])
	for p in [[9, -9], [12.5, -9], [9, -4], [12.5, -4]]:
		B(2.2, .8, 1, wood, p[0], .4, p[1]); B(.7, .45, .05, _u(Color("#4aa0ff"), 1.2), p[0], 1.1, p[1] - .3); B(.5, .5, .5, _c(Color("#4a4f58")), p[0], .25, p[1] + 1.0)
		dk.append([ox + p[0], p[1], 1.3, .65])
	B(2.4, .9, 1.1, _c(Color("#6a6f78"), .5), 14.5, .45, -2.2); B(.9, .4, .6, _c(Color("#c4302a"), .5), 14.2, 1.1, -2.2); dk.append([ox + 14.5, -2.2, 1.3, .7])
	# SOC
	var floor_soc := MeshInstance3D.new(); var fs := PlaneMesh.new(); fs.size = Vector2(12, 12); floor_soc.mesh = fs
	floor_soc.material_override = _m("carpet", Color("#182234")); floor_soc.position = Vector3(11, .012, 6); add_child(floor_soc)
	B(12, .05, .2, _u(Color("#38e0ff"), 2.0), 11, 4.5, .2); B(12, .05, .2, _u(Color("#ff4a7a"), 2.0), 11, 4.5, 11.8)
	wall = CanvasTex.make(self, Vector2i(1024, 384), _paint_wall)
	var vw := MeshInstance3D.new(); var vq := QuadMesh.new(); vq.size = Vector2(10.5, 3.9); vw.mesh = vq
	vw.material_override = Mats.screen(wall.texture(), 1.3); vw.position = Vector3(16.95, 2.6, 6); vw.rotation.y = -PI / 2; add_child(vw)
	for z in [3.0, 6.2, 9.4]:
		B(1.1, .8, 2.2, _c(Color("#20283a"), .4), 11.2, .4, z); B(.06, .5, .9, _u(Color("#38e0ff"), 1.4), 11.9, 1.15, z - .55); B(.06, .5, .9, _u(Color("#40ff9a"), 1.4), 11.9, 1.15, z + .55)
		B(.5, .5, .5, _c(Color("#3a4050")), 10.3, .25, z); dk.append([ox + 11.2, z, .8, 1.3])
	beacon = _u(Color("#ff2a2a"), 3.0)
	B(.4, .25, .4, beacon, 6, 4.4, .5)
	# estaciones
	var mk := func(x: float, z: float, r: float, l: String, kind: String) -> Dictionary:
		return {"x": ox + x, "z": z, "r": r, "l": l, "kind": kind, "bank": self}
	sts = [mk.call(0.0, 10.6, 1.8, "🚪 Salir a la Av. Balboa (E)", "exit"),
		mk.call(3.2, 6.6, 2.0, "📋 Tablero de misiones del banco (E)", "board"),
		mk.call(1.0, -.9, 1.8, "🧑‍💼 Atención al Cliente (E)", "cs"),
		mk.call(10.2, -6.6, 2.6, "🖧 Departamento de TI (E)", "it"),
		mk.call(9.0, 6.2, 2.4, "🛡️ SOC · Centro de operaciones (E)", "soc"),
		mk.call(-15.1, -1.8, 2.2, "🏧 Cajero automático (E)", "atm"),
		mk.call(-4.0, 8.6, 1.4, "🎫 Tomar turno (E)", "ticket"),
		mk.call(-8.0, -5.8, 2.4, "💳 Ventanilla de cajas (E)", "teller")]
	wk = [[ox - 16.5, ox + 4.5, -11.5, 11.5], [ox + 4.4, ox + 5.7, -7.4, -5.6], [ox + 4.4, ox + 5.7, 7.6, 9.4], [ox + 5.6, ox + 16.6, -11.5, -.6], [ox + 5.6, ox + 16.6, .6, 11.5]]
	_spawn()
	visible = false


func _npc(nm: String, shirt: Color, skin: Color, hair: Color, look: Dictionary, x: float, z: float, ry: float, role: String) -> Dictionary:
	var r := Rig.create(shirt, skin, hair, nm, look)
	add_child(r)
	r.position = Vector3(x, 0, z); r.rotation.y = ry
	var n := {"r": r, "role": role, "x": x, "z": z, "ry": ry, "ph": randf() * 6, "st": "", "tm": 0.0, "goal": null, "win": -1}
	npcs.append(n)
	return n


func _spawn() -> void:
	var suit := func(p: Color, t: Dictionary) -> Dictionary:
		var tt := {"hair": 1, "glasses": 0, "beard": 0, "mouth": 1, "tie": true, "badge": false, "pack": false}
		for k in t: tt[k] = t[k]
		return {"outfit": "suit", "pant": p, "t": tt}
	var col: Color = d.col
	var skins := [Color("#f1c9a5"), Color("#d9a47a"), Color("#b07a52"), Color("#8a5a3a")]
	var tn := ["Cajera Lía", "Cajero Omar", "Cajera Dayra", "Cajero Rubén"]
	for i in 4:
		_npc(tn[i], col, skins[i], Color("#1a1410"), suit.call(Color("#1f2a44"), {"hair": i % 2, "glasses": 1 if i == 1 else 0}), -12.5 + i * 3, -10.1, 0, "teller")
	_npc("Ejecutiva Marisol", Color("#c4302a"), Color("#d9a47a"), Color("#3a2616"), suit.call(Color("#2a2a3a"), {"hair": 2, "glasses": 1}), 1, -3.7, 0, "cs")
	_npc("Gerente Vargas", Color("#222a3a"), Color("#f1c9a5"), Color("#6a4a2a"), suit.call(Color("#222a3a"), {"hair": 1, "glasses": 1}), 3, 3.6, PI, "mgr")
	_npc("Téc. Rolando", Color("#2f6fd0"), Color("#b07a52"), Color("#111111"), suit.call(Color("#2a2a3a"), {"hair": 0, "glasses": 1, "tie": false}), 13.8, -6.2, -PI / 2, "it")
	_npc("Analista Karen", Color("#8a3a5a"), Color("#d9a47a"), Color("#1a1410"), suit.call(Color("#2a2a3a"), {"hair": 2, "glasses": 1, "tie": false}), 14.4, 6.2, PI / 2, "soc")
	var gd := _npc("Guardia Omar", Color("#1a1a1a"), Color("#8a5a3a"), Color("#111111"), {"outfit": "coat", "cap": true, "t": {"hair": -1, "glasses": 0, "beard": 0, "mouth": 0, "tie": false, "badge": true, "pack": false}}, -13, 9, PI, "guard")
	gd.route = [[-13.0, 9.0], [-13.0, -3.5], [2.0, -4.6], [3.4, 9.0]]; gd.ri = 0; gd.wait = 0.0
	var sh := [Color("#e84a4a"), Color("#2f6fd0"), Color("#ffd23f"), Color("#4cb87a"), Color("#f2f2f2"), Color("#9a5fd0"), Color("#ff8a3a")]
	var sk := [Color("#f1c9a5"), Color("#d9a47a"), Color("#b07a52"), Color("#8a5a3a"), Color("#5a3a26")]
	for i in 7:
		var n := _npc("Cliente", sh[i], sk[(i * 2) % 5], [Color("#1a1410"), Color("#3a2616"), Color("#6a4a2a")][i % 3], {}, 0, 10.8, PI, "client")
		n.r.name_label.visible = false
		n.st = "out"; n.tm = 1.0 + i * 2.2
		n.r.visible = false


func _move(n: Dictionary, tx: float, tz: float, dt: float, sp := 1.35) -> bool:
	var dv := Vector2(tx - n.x, tz - n.z)
	var dist := dv.length()
	n.r.position = Vector3(n.x, 0, n.z)
	if dist < .12: return true
	var s := minf(dist, sp * dt)
	n.x += dv.x / dist * s; n.z += dv.y / dist * s
	n.r.rotation.y = atan2(dv.x, dv.y)
	n.ph += dt * 6
	n.r.animate(dt, Time.get_ticks_msec(), 0, true, n.ph)
	n.r.position = Vector3(n.x, 0, n.z)
	return false


func _idle(n: Dictionary, dt: float, work: bool) -> void:
	n.ph += dt
	n.r.animate(dt, Time.get_ticks_msec(), 0, false, 0, "chat" if work and int(n.ph) % 7 < 3 else "")


func _client(n: Dictionary, dt: float) -> void:
	match n.st:
		"out":
			n.r.visible = false; n.tm -= dt
			if n.tm <= 0:
				n.x = 0.0; n.z = 10.8; n.r.visible = true; n.st = "in"; n.goal = WAITS[randi() % 4]
		"in":
			if _move(n, n.goal[0], n.goal[1], dt): n.st = "wait"; n.tm = 2 + randf() * 3; n.r.rotation.y = PI
		"wait":
			_idle(n, dt, false); n.tm -= dt
			if n.tm <= 0:
				var fw := win.find(null); var rr := randf()
				if fw >= 0 and rr < .55: win[fw] = n; n.win = fw; n.st = "teller"; n.goal = [-12.5 + fw * 3, -6.7]
				elif rr < .75: n.st = "atm"; n.goal = [-15.2, [-4.0, -1.8, .4][randi() % 3]]
				elif rr < .9: n.st = "csd"; n.goal = [1.0, -.9]
				else: n.st = "leave"
		"teller":
			if _move(n, n.goal[0], n.goal[1], dt): n.r.rotation.y = PI; n.st = "serve"; n.tm = 6 + randf() * 4; turn += 1
		"serve":
			_idle(n, dt, false); n.tm -= dt
			if n.tm <= 0: win[n.win] = null; n.win = -1; n.st = "leave"
		"atm":
			if _move(n, n.goal[0], n.goal[1], dt): n.r.rotation.y = -PI / 2; n.st = "use"; n.tm = 4 + randf() * 3
		"csd":
			if _move(n, n.goal[0], n.goal[1], dt): n.r.rotation.y = PI; n.st = "use"; n.tm = 7 + randf() * 4
		"use":
			_idle(n, dt, false); n.tm -= dt
			if n.tm <= 0: n.st = "leave"
		"leave":
			if _move(n, 0, 10.9, dt): n.st = "out"; n.tm = 5 + randf() * 12; n.r.visible = false


func tick(dt: float, t: float) -> void:
	for n in npcs:
		if n.role == "client": _client(n, dt)
		elif n.role == "guard":
			if n.wait > 0:
				n.wait -= dt; _idle(n, dt, false)
			else:
				var p: Array = n.route[n.ri]
				if _move(n, p[0], p[1], dt, 1.1): n.ri = (n.ri + 1) % n.route.size(); n.wait = 2 + randf() * 3
		else:
			_idle(n, dt, n.role in ["teller", "cs", "it", "soc"])
	if _last_turn != turn:
		_last_turn = turn; board.refresh()
	_wall_t -= dt
	if _wall_t <= 0:
		_wall_t = .35
		wall.refresh()
		for l in leds:
			(l as MeshInstance3D).material_override = _u(Color("#ff9a1f") if randf() < .2 else Color("#40ff9a"), 2.0)
	beacon.emission_energy_multiplier = 3.0 if int(t / 330.0) % 2 == 0 else .2


func _paint_turns(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("#050a10"))
	CanvasTex.text(ci, "TURNO  A-%03d" % turn, Vector2(256, 54), 36, Color("#ffb020"), HORIZONTAL_ALIGNMENT_CENTER)
	for i in 4:
		CanvasTex.text(ci, "V%d %s" % [i + 1, "●" if win[i] != null else "○"], Vector2(64 + i * 128, 104), 24, Color("#40ff9a"), HORIZONTAL_ALIGNMENT_CENTER)


func _paint_wall(ci: CanvasItem, sz: Vector2) -> void:
	var W := sz.x; var H := sz.y
	var t := Time.get_ticks_msec() / 1000.0
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("#07101c"))
	for i in range(0, int(W), 32): ci.draw_line(Vector2(i, 0), Vector2(i, H), Color("#143a5a"), 1)
	ci.draw_rect(Rect2(20, 20, 420, 230), Color("#0f2a44"))
	for i in 46:
		ci.draw_rect(Rect2(30 + randf() * 400, 30 + randf() * 210, 3, 3), Color("#ff4a7a") if randf() < .2 else Color("#38e0ff"))
	var pts := PackedVector2Array()
	for i in 24: pts.append(Vector2(480 + i * 22, 320 - (sin(t * 2 + i * .6) * 30 + randf() * 30 + 40)))
	ci.draw_polyline(pts, Color("#40ff9a"), 2)
	CanvasTex.text(ci, "ALERTAS ACTIVAS: %d" % (3 + int(t * .3) % 5), Vector2(500, 44), 22, Color("#ff8aa8"))
	var ev := ["10:42 phishing bloqueado", "10:44 login anómalo ATM-03", "10:47 escaneo de puertos", "10:51 EDR: sin novedad"]
	for i in ev.size(): CanvasTex.text(ci, ev[i], Vector2(500, 84 + i * 26), 16, Color("#7fd0ff"), HORIZONTAL_ALIGNMENT_LEFT, -1, false)
	CanvasTex.text(ci, "NIST CSF: Identificar · Proteger · Detectar · Responder · Recuperar", Vector2(20, H - 18), 20, Color("#ffd27a"))


func free_at(x: float, z: float) -> bool:
	for o in dk:
		if absf(x - o[0]) < o[2] and absf(z - o[1]) < o[3]: return false
	for r in wk:
		if x > r[0] and x < r[1] and z > r[2] and z < r[3]: return true
	return false
