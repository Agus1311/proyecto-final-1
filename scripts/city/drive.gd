class_name Drive
extends Node
## Manejo libre del superdeportivo por la Av. Balboa: física arcade con caja de 7 marchas,
## agarre lateral y derrape con freno de mano, choques con el tráfico, cámara de persecución
## (3 modos), motor V10 sintetizado, chirrido de llantas, bocina y HUD de velocidad.

signal parked(dest: Dictionary)

const D = preload("res://scripts/city/city_data.gd")
const RATE := 22050.0
const GEARS := [0.0, 14.0, 22.0, 30.0, 38.0, 46.0, 54.0, 70.0]   # velocidad (m/s) al final de cada marcha

var main: Node
var city: City
var cam: Camera3D
var on := false
var x := 0.0
var z := 0.0
var h := 0.0
var vf := 0.0          # velocidad longitudinal
var vr := 0.0          # deslizamiento lateral
var steer := 0.0
var gear := 1
var rpm := 1000.0
var cam_mode := 0
var cp := Vector3.ZERO
var cl := Vector3.ZERO
var bump := 0.0
var t0 := 0
var horn := false
var _pitch := 0.0
var _roll := 0.0
var _lastv := 0.0
var _shift_t := 0.0
# audio
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var horn_p: AudioStreamPlayer
static var WEB := OS.has_feature("web")
const ENGINE_BASE_RPM := 1000.0
var _ph := [0.0, 0.0, 0.0, 0.0]
var _lp := 0.0
var _sq := 0.0
var _pop := 0.0
var _hp := 0.0
var _hp2 := 0.0
# HUD
var hud: PanelContainer
var spd_l: Label
var gear_l: Label
var rpm_b: ProgressBar
var dest_l: Label
var prompt: PanelContainer
var prompt_l: Label


func setup(m: Node, c: City, camera: Camera3D, layer: CanvasLayer) -> void:
	main = m; city = c; cam = camera
	player = AudioStreamPlayer.new(); player.bus = "SFX"; add_child(player)
	# Motor y bocina: bucles pregrabados en todas las plataformas. El sintetizador en tiempo real
	# (generador) se cortaba cuando bajaban los FPS y se oían chasquidos al manejar.
	player.stream = _loop_wav(_engine_wave())
	horn_p = AudioStreamPlayer.new(); horn_p.bus = "SFX"; horn_p.stream = _loop_wav(_horn_wave()); add_child(horn_p)
	_build_hud(layer)


func _build_hud(layer: CanvasLayer) -> void:
	hud = Kit.panel(Kit.sb(Color(0.04, 0.07, 0.11, .86), 16, 1, Color(1, 1, 1, .16), 14))
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.position = Vector2(16, -300)
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.custom_minimum_size = Vector2(300, 0)
	hud.theme = Kit.theme()
	hud.visible = false
	layer.add_child(hud)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); hud.add_child(v)
	var row := HBoxContainer.new(); v.add_child(row)
	spd_l = Kit.label("0", 52, Color.WHITE, true); row.add_child(spd_l)
	var u := VBoxContainer.new(); row.add_child(u)
	u.add_child(Kit.label("km/h", 14, Color(1, 1, 1, .7), true))
	gear_l = Kit.label("1", 26, Kit.WARM, true); u.add_child(gear_l)
	rpm_b = Kit.bar(Kit.WARM); rpm_b.max_value = 8500; rpm_b.custom_minimum_size = Vector2(260, 8); v.add_child(rpm_b)
	dest_l = Kit.label("", 13, Color(1, 1, 1, .9), false, true); dest_l.custom_minimum_size.x = 270; v.add_child(dest_l)
	v.add_child(Kit.label("W/S acelerar·frenar · A/D girar · Espacio freno de mano · Shift turbo · C cámara · H bocina · E bajar", 11, Color(1, 1, 1, .6), false, true))
	prompt = Kit.panel(Kit.sb(Color(0.04, 0.07, 0.11, .9), 12, 1, Kit.WARM, 10))
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position.y = -150
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.visible = false
	layer.add_child(prompt)
	prompt_l = Kit.label("", 15, Color.WHITE, true); prompt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; prompt.add_child(prompt_l)


func start() -> void:
	var car: Node3D = city.car
	# si está en el carril de estacionamiento, se incorpora al primer carril
	x = car.position.x; z = car.position.z; h = car.rotation.y
	if z > -5.5 and z < 0.0: z = -6.4
	vf = 0; vr = 0; steer = 0; gear = 1; rpm = 1000
	on = true
	t0 = Time.get_ticks_msec()
	car.set_meta("driving", true)
	cp = Vector3(x - 7, 2.8, z); cl = Vector3(x, 1, z)
	_pv = 1.0; _vv = 0.0
	player.pitch_scale = 1.0; player.volume_db = -60.0
	player.play()
	hud.visible = true
	Game.toast("🏎️ ¡Al volante! W/S acelerar y frenar · A/D girar · Espacio freno de mano · Shift turbo · C cámara · E bajarte", 6000)
	if absf(h) < 1.0:
		Game.toast("Para ir a Paitilla (bancos y tu casa) haz el retorno en el semáforo de la Calle 29.", 7000)


func stop(px: float, pz := .6) -> void:
	on = false
	city.car.set_meta("driving", false)
	player.stop(); playback = null
	if horn_p: horn_p.stop()
	hud.visible = false; prompt.visible = false
	cam.fov = 70
	cam.position = Vector3(px, 1.6, pz)
	main.yaw = 0.0; main.pitch = 0.0


func park_or_exit() -> void:
	if Time.get_ticks_msec() - t0 < 450: return
	if absf(vf) > 7:
		Game.toast("Frena un poco para bajarte (Espacio)"); return
	var d := _near_dest()
	if d.size():
		city.park_car(float(d.x)); stop(float(d.x))
		if d.id == "home":
			Game.save(); Game.toast("💾 Partida guardada en tu casa · camina hasta la puerta para entrar")
		else:
			Game.toast("🅿️ Estacionado frente a %s. Cruza la acera hasta la puerta (E)." % d.name)
		parked.emit(d)
	elif z > -1.9:
		city.car.position = Vector3(x + 2.6, 0, z); city.car.rotation = Vector3(0, h, 0)
		stop(x - 3.2, z)
		Game.toast("🅿️ Lamborghini estacionado a un lado de la calle")
	else:
		city.park_car(x); stop(x)
		Game.toast("🅿️ Lamborghini estacionado en la acera")


func _near_dest() -> Dictionary:
	for d in D.DEST + [D.CAA_DEST]:
		if absf(float(d.x) - x) < 8: return d
	return {}


func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func input_key(k: Key) -> void:
	match k:
		KEY_E: park_or_exit()
		KEY_C: cam_mode = (cam_mode + 1) % 3
		KEY_R:
			z = -10.7 if z > -16.5 else -23.5
			h = 0.0 if z > -16.5 else PI
			vf = 0; vr = 0
			Game.toast("🔄 Auto reubicado en el carril")


func tick(dt: float) -> void:
	if not on: return
	var up := _key(KEY_W) or _key(KEY_UP)
	var dn := _key(KEY_S) or _key(KEY_DOWN)
	var l := _key(KEY_A) or _key(KEY_LEFT)
	var r := _key(KEY_D) or _key(KEY_RIGHT)
	var hb := _key(KEY_SPACE)
	var boost := _key(KEY_SHIFT)
	horn = _key(KEY_H)
	var top := 58.0 if boost else 42.0
	var spd := absf(vf)
	# motor: el par cae con la velocidad
	var acc := (17.0 if boost else 12.5) * (1.0 - clampf(vf / top, 0, 1) * .85)
	if up:
		vf += (30.0 if vf < 0 else acc) * dt
	elif dn:
		vf -= (36.0 if vf > .5 else 10.0) * dt
	else:
		vf -= signf(vf) * minf(absf(vf), (2.2 + spd * .04) * dt)
	if hb:
		vf -= signf(vf) * minf(absf(vf), 14.0 * dt)
	vf = clampf(vf, -10, top)
	# dirección: menos ángulo a alta velocidad
	var s_in := (1.0 if l else 0.0) - (1.0 if r else 0.0)
	steer += (s_in - steer) * minf(1, dt * (6.0 if s_in != 0 else 9.0))
	var max_a := lerpf(.62, .1, clampf(spd / 50.0, 0, 1))
	var yaw_rate := vf * tan(steer * max_a) / 2.65
	# agarre lateral (freno de mano = derrape)
	var grip := 2.0 if hb and spd > 8 else 9.0
	vr += -yaw_rate * vf * .06 * (1.0 if hb else .35) * dt * 10.0
	vr *= exp(-grip * dt)
	h += yaw_rate * dt + (vr * .015 * dt if hb else 0.0)
	var fwd := Vector2(cos(h), -sin(h))
	var right := Vector2(sin(h), cos(h))
	var mv := fwd * vf * dt + right * vr * dt
	var nx := x + mv.x
	var nz := z + mv.y
	# límites: aceras, isleta central (con retornos) y calles transversales
	var cross := false
	for ix in D.IX:
		if absf(nx - float(ix[0])) < 4.4: cross = true
	var gap := false
	for ix in D.IX:
		if absf(nx - float(ix[0])) < 8.0: gap = true
	var north := absf(nx - D.NORTH_X) < 4.6       # ramal hacia 5 de Mayo y Curundú
	var in_corr := (cross and nz < 150) or (north and nz < D.NORTH_Z - 4)
	if nz > -1.9 and not in_corr:
		if z > -1.9:
			nx = x; nz = z                           # dentro de una calle transversal: no atraviesa las aceras
		else:
			nz = -1.9
		vf *= .85; vr *= -.3; _hit()
	if nz < -27.6:
		nz = -27.6; vf *= .85; vr *= -.3; _hit()
	var gap_w := absf(nx - D.NORTH_X) < 8.0 or absf(nx - 424.0) < 8.0 or nx > D.XA_EXT - 34.0   # retornos de la zona oeste
	if not gap and not gap_w and nz < -15.6 and nz > -18.6:
		if z >= -15.6: nz = -15.6
		else: nz = -18.6
		vf *= .8; vr *= -.3; _hit()
	if nx < D.XB + 20: nx = D.XB + 20; vf *= .6
	if nx > D.XA_EXT - 20: nx = D.XA_EXT - 20; vf *= .6
	x = nx; z = nz
	# choques con el tráfico y los estacionados
	bump -= dt
	for c in city.traffic:
		if absf(c.x - x) < float(c.len) / 2 + 2.2 and absf(c.z - z) < 1.85:
			if _collide(c.x, c.z): c.v = 0.0
	for p in city.parked:
		if p.state == "parked" and absf(p.x - x) < 4.4 and absf(-3.4 - z) < 1.8:
			_collide(p.x, -3.4)
	# marchas y revoluciones
	_shift_t -= dt
	var g := 1
	while g < 7 and spd > GEARS[g]: g += 1
	if g != gear and _shift_t <= 0:
		if g < gear: _pop = .35
		gear = g; _shift_t = .25
	var lo: float = GEARS[gear - 1]; var hi: float = GEARS[gear]
	var target_rpm := 1000.0 + clampf((spd - lo) / maxf(1.0, hi - lo), 0, 1) * 7400.0
	if vf < -.2: target_rpm = 1000.0 + spd * 300
	if up and spd < 1.5: target_rpm = 4200.0
	rpm += (target_rpm - rpm) * minf(1, dt * 9)
	# carrocería: cabeceo y balanceo
	var along := (vf - _lastv) / maxf(dt, .001)
	_lastv = vf
	_pitch += (clampf(-along * .004, -.05, .05) - _pitch) * minf(1, dt * 6)
	_roll += (clampf(yaw_rate * vf * .0035, -.06, .06) - _roll) * minf(1, dt * 6)
	var car: Node3D = city.car
	car.position = Vector3(x, 0, z)
	car.rotation = Vector3(0, h, 0)
	car.rotate_object_local(Vector3(0, 0, 1), _pitch)
	car.rotate_object_local(Vector3(1, 0, 0), _roll)
	Cars.roll(car, vf * dt, steer * max_a)
	var sw: Node3D = car.get_meta("steer")
	sw.rotation.x = -steer * 2.2
	# cámara de persecución
	var f3 := Vector3(fwd.x, 0, fwd.y)
	var s3 := Vector3(right.x, 0, right.y)
	var k := 1.0 - exp(-7.0 * dt)
	var tgt: Vector3
	var look: Vector3
	match cam_mode:
		0:
			var dist := 7.4 + spd * .06
			tgt = Vector3(x, 2.6 + spd * .012, z) - f3 * dist - s3 * steer * .8
			look = Vector3(x, 1.0, z) + f3 * 4.0
		1:
			tgt = Vector3(x, 1.9, z) - f3 * 4.6
			look = Vector3(x, .9, z) + f3 * 6.0
		_:
			tgt = Vector3(x, 1.08, z) - f3 * .45 - s3 * .32
			look = tgt + f3 * 10.0 - Vector3(0, .25, 0)
			k = 1.0
	cp = cp.lerp(tgt, k)
	cl = cl.lerp(look, minf(1.0, k * 1.6))
	cam.position = cp + (Vector3(randf() - .5, randf() - .5, 0) * .02 * clampf((spd - 30) / 25, 0, 1))
	cam.look_at(cl, Vector3.UP)
	cam.fov = 68.0 + spd * .5
	main.yaw = h - PI / 2
	_hud_update(fwd)
	_audio(hb and spd > 10 and absf(vr) > 1.0 or (absf(steer) > .8 and spd > 26))


func _hit() -> void:
	if bump <= 0 and absf(vf) > 5:
		bump = 1.0
		main.shake = 8.0
		Game.beep(90, .12)


func _collide(ox: float, oz: float) -> bool:
	if bump <= 0:
		Game.toast("💥 ¡Cuidado con el tráfico!", 1400); bump = 1.4
		main.shake = 12.0
		Game.beep(80, .15)
	vf *= -.35
	x += signf(x - ox if x != ox else 1.0) * .6
	z += signf(z - oz if z != oz else 1.0) * .5
	return true


var _hud_t := 0.0


func _hud_update(fwd: Vector2) -> void:
	_hud_t -= get_process_delta_time()
	if _hud_t > 0: return
	_hud_t = .15
	spd_l.text = str(int(round(absf(vf) * 3.6)))
	gear_l.text = "R" if vf < -.3 else ("N" if absf(vf) < .3 else str(gear))
	rpm_b.value = rpm
	rpm_b.add_theme_stylebox_override("fill", Kit.sb(Kit.BAD if rpm > 7600 else Kit.WARM, 4))
	var lines := []
	for d in D.DEST + [D.CAA_DEST]:
		var dx: float = float(d.x) - x
		var ahead := dx * fwd.x > 0
		lines.append("%s %s   %d m %s" % [d.icon, d.name, int(absf(dx)), "📍" if absf(dx) < 8 else ("▲" if ahead else "▼")])
	dest_l.text = "\n".join(lines)
	var nd := _near_dest()
	prompt.visible = nd.size() > 0
	if nd.size():
		prompt_l.text = "E · Estacionar frente a %s%s" % [nd.name, "\n💾 y guardar partida" if nd.id == "home" else "\ny bajarte del auto"]
		prompt.reset_size()
		prompt.position.x = (prompt.get_viewport_rect().size.x - prompt.size.x) / 2


# ---------------- sonido del motor V10 ----------------
## Versión web: el bucle del motor sube de tono con las RPM y de volumen con el acelerador.
var _pv := 1.0     # tono y volumen suavizados: sin saltos bruscos (los saltos suenan como un «clic»)
var _vv := 0.0


func _audio_web() -> void:
	var dt := get_process_delta_time()
	var vol: float = main.music.master * main.music.sfx * (0.0 if Game.muted else 1.0)
	var load_ := .55 + (.45 if _key(KEY_W) else 0.0)
	_pv = lerpf(_pv, clampf(rpm / ENGINE_BASE_RPM, .6, 6.5), minf(1.0, dt * 10.0))
	_vv = lerpf(_vv, vol * load_ * .7, minf(1.0, dt * 6.0))
	player.pitch_scale = _pv
	player.volume_db = linear_to_db(maxf(.0001, _vv))
	if horn and not horn_p.playing: horn_p.play()
	elif not horn and horn_p.playing: horn_p.stop()
	horn_p.volume_db = linear_to_db(maxf(.0001, vol * .5))


## Un segundo exacto con frecuencias enteras: el bucle empalma sin clic.
func _loop_wav(d: PackedFloat32Array) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = int(RATE); w.stereo = false
	var b := PackedByteArray(); b.resize(d.size() * 2)
	for i in d.size(): b.encode_s16(i * 2, int(clampf(d[i], -1, 1) * 32767))
	w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = d.size()
	return w


func _engine_wave() -> PackedFloat32Array:
	var n := int(RATE); var d := PackedFloat32Array(); d.resize(n)
	var f0 := 42.0     # 1000 RPM · 10 cilindros
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in range(1, 13):
			s += sin(TAU * f0 * k * t + k * .7) / pow(k, 1.25)
		s += .5 * sin(TAU * f0 * .5 * t)
		d[i] = s * .16
	return d


func _horn_wave() -> PackedFloat32Array:
	var n := int(RATE); var d := PackedFloat32Array(); d.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in [1, 3, 5, 7]:
			s += (sin(TAU * 415.0 * k * t) + sin(TAU * 523.0 * k * t)) / k
		d[i] = s * .09
	return d

func _audio(_squeal: bool) -> void:
	_audio_web()

