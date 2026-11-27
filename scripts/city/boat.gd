class_name Boat
extends Node
## Lancha del Mercado de Mariscos: manejo en el agua de la bahía y de la Calzada de Amador,
## misiones de entrega (Isla Naos, Isla Flamenco, rescate de un pescador) y una carrera de boyas
## con cronómetro y récord guardado.
##
## Teclas: W/S acelerar y frenar · A/D girar · Shift turbo · C cámara · 1-3 misiones · 4 carrera
##         R volver al muelle · E bajarse en el muelle.

const PIER := Vector2(424.0, -92.0)
const MISSIONS := [
	{"id": "naos", "n": "Llevar un router a la estación científica de Isla Naos", "who": "Laboratorio marino", "p": Vector2(1366.0, -96.0), "money": 45, "xp": 25},
	{"id": "flam", "n": "Entregar un servidor a la marina de Isla Flamenco", "who": "Marina Flamenco", "p": Vector2(2166.0, -118.0), "money": 75, "xp": 40},
	{"id": "fish", "n": "Rescatar a un pescador sin motor frente a la bahía", "who": "Don Chalo", "p": Vector2(820.0, -420.0), "money": 55, "xp": 30},
]
## Recorrido de la carrera (boyas en orden): sale del muelle, rodea Isla Naos y vuelve.
const RACE := [Vector2(424, -130), Vector2(700, -170), Vector2(1000, -160), Vector2(1300, -210), Vector2(1450, -260),
	Vector2(1600, -150), Vector2(1620, -300), Vector2(1250, -320), Vector2(850, -280), Vector2(520, -160), Vector2(424, -112)]
## Competencia del puerto: lanchas rivales de los barrios de la bahía [nombre, color, velocidad m/s]
const RIVALS := [["Tiburones de Boca La Caja", Color("#e8433f"), 24.5], ["Brisa de Taboga", Color("#2f9a5a"), 23.2], ["Relámpago del Chorrillo", Color("#f2c200"), 25.6]]
const PRIZES := [120, 70, 40, 20]
const RACE_R := 16.0
const MIX := 22050

var main: Node
var city: City
var cam: Camera3D
var on := false
var x := 0.0
var z := 0.0
var h := PI
var vf := 0.0
var steer := 0.0
var cam_mode := 0
var cp := Vector3.ZERO
var cl := Vector3.ZERO
var t0 := 0
var t := 0.0
var g: Node3D
var hull: Node3D
var wake: MeshInstance3D
var motor: AudioStreamPlayer
var _pv := 1.0
var _ui_t := 0.0
var _vv := 0.0
# objetivo actual
var mode := ""            # "", "mis", "race"
var mis: Dictionary = {}
var race_i := 0
var race_t := 0.0
var countdown := 0.0
var marker: Node3D
var buoys: Array = []
var fish_boat: Node3D
var rivals: Array = []      # {g, name, sp, i, x, z, h, done, t}
var finish_order: Array = []
# HUD
var hud: PanelContainer
var info_l: Label
var spd_l: Label


func setup(m: Node, c: City, camera: Camera3D, layer: CanvasLayer) -> void:
	main = m; city = c; cam = camera
	motor = AudioStreamPlayer.new(); motor.bus = "SFX"; motor.stream = _motor_wav(); add_child(motor)
	hud = Kit.panel(Kit.sb(Color(0.03, 0.08, 0.12, .88), 16, 1, Color(1, 1, 1, .16), 14))
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.position = Vector2(16, -330)
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.custom_minimum_size = Vector2(340, 0)
	hud.theme = Kit.theme(); hud.visible = false
	layer.add_child(hud)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); hud.add_child(v)
	v.add_child(Kit.label("🚤 Lancha del Mercado", 16, Kit.WARM, true))
	spd_l = Kit.label("", 30, Color.WHITE, true); v.add_child(spd_l)
	info_l = Kit.label("", 13, Color(1, 1, 1, .92), false, true); info_l.custom_minimum_size.x = 320; v.add_child(info_l)
	v.add_child(Kit.label("W/S acelerar · A/D girar · Shift turbo · C cámara · R volver al muelle · E bajarse en el muelle", 11, Color(1, 1, 1, .6), false, true))


func _hull(c: Color, parent: Node3D) -> Node3D:
	var hh := Node3D.new(); parent.add_child(hh)
	var white := city.col_mat(Color("#f8f8f4"), .35)
	city.box(Vector3(2.4, .8, 6.2), Vector3(0, .3, 0), white, hh)
	var bw := city.box(Vector3(1.7, .8, 1.7), Vector3(0, .3, 3.4), white, hh); bw.rotation.y = PI / 4
	city.box(Vector3(2.45, .2, 6.3), Vector3(0, -.05, 0), city.col_mat(c, .4), hh)
	city.box(Vector3(1.6, .1, 1.2), Vector3(0, 1.05, .4), city.col_mat(Color("#203040"), .1), hh)
	city.box(Vector3(.6, 1.0, .5), Vector3(0, .5, -3.3), city.col_mat(Color("#1d1f24"), .4), hh)
	return hh


func _build_rivals() -> void:
	for r in rivals: (r.g as Node3D).queue_free()
	rivals.clear()
	for i in RIVALS.size():
		var rg := Node3D.new(); city.add_child(rg)
		_hull(RIVALS[i][1], rg)
		var pil := Rig.create(RIVALS[i][1], Color("#b07a52"), Color("#1a1410"), RIVALS[i][0])
		pil.position = Vector3(0, .35, -.6); pil.name_label.visible = false; rg.add_child(pil)
		var tag := city.label(RIVALS[i][0], 46, RIVALS[i][1], Vector3(0, 3.2, 0), 0.0, rg)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		City.set_layer(rg)
		rivals.append({"g": rg, "name": RIVALS[i][0], "sp": float(RIVALS[i][2]) * (.95 + randf() * .08), "i": 0,
			"x": PIER.x + (i - 1) * 7.0 - 3.5, "z": PIER.y - 4.0, "h": PI, "done": false, "t": 0.0, "v": 0.0, "ph": randf() * 6})


func _build_boat() -> void:
	g = Node3D.new(); g.name = "Lancha"
	city.add_child(g)
	hull = Node3D.new(); g.add_child(hull)
	var white := city.col_mat(Color("#f8f8f4"), .35)
	var blue := city.col_mat(Color("#1d6fd0"), .4)
	city.box(Vector3(2.4, .8, 6.2), Vector3(0, .3, 0), white, hull)
	var bow := city.box(Vector3(1.7, .8, 1.7), Vector3(0, .3, 3.4), white, hull); bow.rotation.y = PI / 4
	city.box(Vector3(2.45, .2, 6.3), Vector3(0, -.05, 0), blue, hull)
	city.box(Vector3(1.6, .1, 1.2), Vector3(0, 1.05, .4), city.col_mat(Color("#203040"), .1), hull)   # parabrisas
	city.box(Vector3(1.9, .5, 1.6), Vector3(0, .85, -.6), city.col_mat(Color("#e8e2d4"), .6), hull)     # asiento
	city.box(Vector3(.6, 1.0, .5), Vector3(0, .5, -3.3), city.col_mat(Color("#1d1f24"), .4), hull)      # motor fuera de borda
	city.label("CAA", 60, Color("#1d6fd0"), Vector3(1.24, .45, .4), PI / 2, hull)
	wake = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(3.0, 9.0); wake.mesh = pm
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(1, 1, 1, .45); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wake.material_override = wm; wake.position = Vector3(0, .02, -7.5)
	g.add_child(wake)
	City.set_layer(g)
	# marcador del objetivo: columna de luz
	marker = Node3D.new(); city.add_child(marker); marker.visible = false
	var col := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.2; cm.bottom_radius = 2.2; cm.height = 40
	col.mesh = cm; col.position.y = 20
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(1, .75, .2, .28); mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	col.material_override = mm; marker.add_child(col)
	# boyas de la carrera
	for i in RACE.size():
		var b := Node3D.new(); city.add_child(b); b.visible = false
		var bm := MeshInstance3D.new(); var sm := CylinderMesh.new(); sm.top_radius = .2; sm.bottom_radius = 1.0; sm.height = 2.4
		bm.mesh = sm; bm.position.y = .6
		bm.material_override = city.col_mat(Color("#ff6a1a") if i < RACE.size() - 1 else Color("#2fd06a"), .4)
		b.add_child(bm)
		b.position = Vector3(RACE[i].x, -.3, RACE[i].y)
		buoys.append(b)
	# panga del pescador a rescatar
	fish_boat = Node3D.new(); city.add_child(fish_boat); fish_boat.visible = false
	city.box(Vector3(1.8, .7, 5.6), Vector3(0, .25, 0), city.col_mat(Color("#e8e2d4"), .5), fish_boat)
	city.box(Vector3(1.85, .2, 5.7), Vector3(0, -.05, 0), city.col_mat(Color("#c4302a"), .5), fish_boat)
	var r := Rig.create(Color("#f2c200"), Color("#8a5a3a"), Color("#1a1410"), "Don Chalo")
	r.position = Vector3(0, .35, .6); fish_boat.add_child(r)
	fish_boat.position = Vector3(MISSIONS[2].p.x, -.35, MISSIONS[2].p.y)


func start() -> void:
	if g == null: _build_boat()
	x = PIER.x; z = PIER.y; h = PI; vf = 0; steer = 0
	on = true
	t0 = Time.get_ticks_msec()
	g.visible = true
	cp = Vector3(x, 4, z + 8); cl = Vector3(x, 1, z)
	_pv = .7; _vv = 0.0; motor.pitch_scale = .7; motor.volume_db = -60.0
	motor.play()
	hud.visible = true
	_menu_text()
	Game.toast("🚤 ¡A bordo! Elige: 1 Isla Naos · 2 Isla Flamenco · 3 Rescate · 4 Carrera de lanchas", 6000)


func stop() -> void:
	on = false
	motor.stop()
	hud.visible = false
	marker.visible = false
	for b in buoys: b.visible = false
	if mode == "race": Game.toast("🏁 Competencia cancelada")
	for r in rivals: (r.g as Node3D).queue_free()
	rivals.clear()
	mode = ""; mis = {}
	g.position = Vector3(PIER.x - 6.5, -.35, PIER.y + 8); g.rotation = Vector3(0, PI, 0)
	cam.fov = 70
	cam.position = Vector3(PIER.x, 1.6, -80.0)
	main.yaw = PI; main.pitch = 0.0


func input_key(k: Key) -> void:
	match k:
		KEY_E:
			if Time.get_ticks_msec() - t0 < 450: return
			if Vector2(x, z).distance_to(PIER) < 16 and absf(vf) < 6:
				stop(); Game.toast("⚓ Lancha amarrada en el muelle del Mercado")
			else:
				Game.toast("Vuelve al muelle del Mercado para bajarte (R te lleva directo)")
		KEY_C: cam_mode = (cam_mode + 1) % 2
		KEY_R:
			x = PIER.x; z = PIER.y; h = PI; vf = 0
			Game.toast("↩️ De vuelta en el muelle")
		KEY_1, KEY_2, KEY_3: _start_mission(int(k - KEY_1))
		KEY_4: _start_race()


func _start_mission(i: int) -> void:
	mis = MISSIONS[i]; mode = "mis"
	for b in buoys: b.visible = false
	marker.visible = true
	marker.position = Vector3(mis.p.x, 0, mis.p.y)
	fish_boat.visible = mis.id == "fish"
	Game.toast("📍 Misión: %s · sigue la columna de luz" % mis.n, 5000)
	_menu_text()


func _start_race() -> void:
	mode = "race"; mis = {}
	race_i = 0; race_t = 0.0; countdown = 3.0
	x = PIER.x + 10.5; z = PIER.y - 4.0; h = PI; vf = 0
	finish_order.clear()
	_build_rivals()
	for i in buoys.size(): buoys[i].visible = true
	marker.visible = true
	marker.position = Vector3(RACE[0].x, 0, RACE[0].y)
	fish_boat.visible = false
	Game.toast("🏁 Competencia de lanchas del puerto: 4 lanchas, %d boyas alrededor de Isla Naos. ¡3, 2, 1…!" % RACE.size(), 4500)


func _menu_text() -> void:
	var best := float(Game.G.get("boat_best", 0.0))
	var lines := []
	if mode == "mis": lines.append("📍 %s\n   Para: %s · Pago $%d · %d XP" % [mis.n, mis.who, mis.money, mis.xp])
	elif mode == "race":
		lines.append("🏁 Boya %d de %d · %s · Posición %d de %d" % [mini(race_i + 1, RACE.size()), RACE.size(), _fmt(race_t), place(), rivals.size() + 1])
		for r in rivals:
			lines.append("   %s %s" % ["✅" if r.done else "🚤", r.name])
	else:
		lines.append("1 · 📦 Router a Isla Naos ($45)")
		lines.append("2 · 🖥️ Servidor a Isla Flamenco ($75)")
		lines.append("3 · 🛟 Rescatar a Don Chalo ($55)")
		lines.append("4 · 🏁 Competencia de lanchas (vs. 3 rivales)" + (" · récord %s" % _fmt(best) if best > 0 else ""))
	info_l.text = "\n".join(lines)


func _fmt(s: float) -> String:
	return "%d:%04.1f" % [int(s) / 60, fmod(s, 60.0)]


func tick(dt: float) -> void:
	if not on: return
	t += dt
	var up := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var dn := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var l := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var r := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var boost := Input.is_physical_key_pressed(KEY_SHIFT)
	if countdown > 0:
		countdown -= dt; up = false; dn = false
		if countdown <= 0: Game.toast("¡YA! 🏁", 1200)
	var top := 30.0 if boost else 22.0
	if up: vf = minf(top, vf + (9.0 if boost else 6.5) * dt)
	elif dn: vf = maxf(-5.0, vf - 9.0 * dt)
	vf -= vf * .35 * dt                    # el agua frena
	steer = lerpf(steer, (1.0 if l else 0.0) - (1.0 if r else 0.0), minf(1, dt * 4))
	h += steer * dt * (.9 + absf(vf) * .045) * signf(vf if absf(vf) > .5 else 1.0)
	var fwd := Vector2(sin(h), cos(h))
	var nx := x + fwd.x * vf * dt
	var nz := z + fwd.y * vf * dt
	if CityWest.is_water(nx, nz):
		x = nx; z = nz
	else:
		vf *= -.3
		if absf(vf) > 2: main.shake = 6.0; Game.beep(110, .08)
	# oleaje: cabeceo y balanceo
	var bob := sin(t * 1.7) * .08 + sin(t * 2.9) * .04
	g.position = Vector3(x, -.35 + bob, z)
	g.rotation = Vector3(0, h, 0)
	hull.rotation = Vector3(-clampf(vf * .006, -.02, .14) + sin(t * 1.3) * .02, 0, -steer * clampf(vf * .012, 0, .18) + sin(t * 1.1) * .025)
	wake.visible = absf(vf) > 3
	wake.scale = Vector3(1, 1, clampf(absf(vf) / 14.0, .3, 2.0))
	# cámara de persecución
	var f3 := Vector3(fwd.x, 0, fwd.y)
	var tgt := Vector3(x, 3.6, z) - f3 * 10.0 if cam_mode == 0 else Vector3(x, 1.9, z) - f3 * 1.0
	var look := Vector3(x, 1.0, z) + f3 * (6.0 if cam_mode == 0 else 12.0)
	var k := 1.0 - exp(-5.0 * dt)
	cp = cp.lerp(tgt, k); cl = cl.lerp(look, minf(1.0, k * 1.6))
	cam.position = cp; cam.look_at(cl, Vector3.UP)
	cam.fov = 70.0 + absf(vf) * .4
	main.yaw = h + PI
	# motor: tono según la velocidad
	var vol: float = main.music.master * main.music.sfx * (0.0 if Game.muted else 1.0)
	_pv = lerpf(_pv, clampf(.7 + absf(vf) / 18.0, .6, 2.6), minf(1.0, dt * 6.0))
	_vv = lerpf(_vv, vol * (.32 + (.3 if up else 0.0)), minf(1.0, dt * 4.0))
	motor.pitch_scale = _pv
	motor.volume_db = linear_to_db(maxf(.0001, _vv))
	spd_l.text = "%d km/h" % int(absf(vf) * 3.6)
	marker.rotation.y += dt
	if mode == "mis": _mission_tick()
	elif mode == "race": _race_tick(dt)
	elif rivals.size(): _rivals_tick(dt)      # los rivales terminan su vuelta aunque tú ya llegaste
	_ui_t -= dt
	if _ui_t <= 0:
		_ui_t = .25; _menu_text()      # 4 veces por segundo, no en cada cuadro


func _mission_tick() -> void:
	if Vector2(x, z).distance_to(mis.p) < 18 and absf(vf) < 10:
		Game.G.money = int(Game.G.money) + int(mis.money)
		Game.G.xp = int(Game.G.xp) + int(mis.xp)
		Game.save(); Game.hud(); Game.beep(880, .12)
		Game.toast("✅ %s · +$%d · +%d XP" % [("Don Chalo a salvo, remolcado al muelle" if mis.id == "fish" else "Entrega completada"), mis.money, mis.xp], 5000)
		if mis.id == "fish": fish_boat.visible = false
		mode = ""; mis = {}; marker.visible = false
		_menu_text()


## Progreso de una lancha en el recorrido: boyas pasadas y cercanía a la siguiente.
func _progress(i: int, px: float, pz: float) -> float:
	if i >= RACE.size(): return 1e6
	return i * 10000.0 - Vector2(px, pz).distance_to(RACE[i])


func place() -> int:
	var me := _progress(race_i, x, z) if race_i < RACE.size() else 1e6 - finish_order.find("me") 
	var p := 1
	for r in rivals:
		var rp: float = _progress(r.i, r.x, r.z) if not r.done else 1e6 - finish_order.find(r.name)
		if rp > me: p += 1
	return p


func _rivals_tick(dt: float) -> void:
	for r in rivals:
		var g2: Node3D = r.g
		r.ph += dt
		if r.done or countdown > 0:
			r.v = lerpf(r.v, 0.0, dt)
		else:
			r.t += dt
			var tgt: Vector2 = RACE[r.i]
			var want := atan2(tgt.x - r.x, tgt.y - r.z)
			r.h = lerp_angle(r.h, want, minf(1.0, dt * 1.6))
			# arranque progresivo y pequeñas variaciones (oleaje, errores del piloto)
			r.v = lerpf(r.v, r.sp * (.92 + .08 * sin(r.ph * .7)), minf(1.0, dt * .6))
			if Vector2(r.x, r.z).distance_to(tgt) < RACE_R:
				r.i += 1
				if r.i >= RACE.size():
					r.done = true; finish_order.append(r.name)
		var nx: float = r.x + sin(r.h) * r.v * dt
		var nz: float = r.z + cos(r.h) * r.v * dt
		if CityWest.is_water(nx, nz): r.x = nx; r.z = nz
		else: r.h += PI * .5 * dt
		g2.position = Vector3(r.x, -.35 + sin(r.ph * 1.7) * .08, r.z)
		g2.rotation = Vector3(-clampf(r.v * .005, 0, .12), r.h, sin(r.ph * 1.2) * .03)


func _race_tick(dt: float) -> void:
	_rivals_tick(dt)
	if countdown > 0: return
	race_t += dt
	if Vector2(x, z).distance_to(RACE[race_i]) < RACE_R:
		buoys[race_i].visible = false
		Game.beep(660 + race_i * 30, .06)
		race_i += 1
		if race_i >= RACE.size():
			finish_order.append("me")
			var pos := finish_order.find("me") + 1
			var best := float(Game.G.get("boat_best", 0.0))
			var rec := best <= 0 or race_t < best
			if rec: Game.G.boat_best = race_t
			var pay: int = PRIZES[clampi(pos - 1, 0, 3)] + (25 if rec else 0)
			var xp := 40 if pos == 1 else 20
			Game.G.money = int(Game.G.money) + pay; Game.G.xp = int(Game.G.xp) + xp
			if pos == 1: Game.G.boat_wins = int(Game.G.get("boat_wins", 0)) + 1
			Game.save(); Game.hud()
			var medal: String = ["🥇 ¡GANASTE la competencia!", "🥈 Segundo lugar", "🥉 Tercer lugar", "4.º lugar"][clampi(pos - 1, 0, 3)]
			Game.toast("%s · Tiempo %s%s · +$%d · +%d XP" % [medal, _fmt(race_t), " · 🏆 NUEVO RÉCORD" if rec else "", pay, xp], 7000)
			mode = ""; marker.visible = false
			_menu_text()
			return
		marker.position = Vector3(RACE[race_i].x, 0, RACE[race_i].y)


## Bucle de motor fuera de borda (1 s exacto con frecuencias enteras: empalma sin clic).
func _motor_wav() -> AudioStreamWAV:
	var n := MIX
	var b := PackedByteArray(); b.resize(n * 2)
	for i in n:
		var tt := float(i) / MIX
		var s := 0.0
		for kk in range(1, 9): s += sin(TAU * 60.0 * kk * tt + kk) / pow(kk, 1.1)
		s += .4 * sin(TAU * 30.0 * tt)
		b.encode_s16(i * 2, int(clampf(s * .14, -1, 1) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = MIX; w.stereo = false; w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = n
	return w
