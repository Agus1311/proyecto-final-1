class_name Intruder
extends Node3D
## Enemigo del piso 1: un «técnico falso» que se coló al edificio (ingeniería social) y
## busca clonar la credencial del técnico de TI. Máquina de estados finita (FSM):
##   PATRULLA → PERSECUCION (te ve dentro del radio y del cono de visión, sin paredes)
##   PERSECUCION → BUSQUEDA (te pierde de vista más de «tiempo_perder_vista» segundos)
##   BUSQUEDA → PATRULLA (no te encuentra en la última posición conocida)
##   PERSECUCION → HUIDA (te alcanza: te clona la credencial y te quita «dano» de seguridad)
##   cualquier estado → FUERA (lo confrontas con X: seguridad lo escolta fuera)
## Todos los valores de detección y velocidad se ajustan desde el Inspector (scenes/intruso.tscn).

signal state_changed(new_state: String)
signal caught_player(damage: int)

enum S { PATRULLA, PERSECUCION, BUSQUEDA, HUIDA, FUERA }

@export_group("Detección")
@export_range(1.0, 20.0, 0.5) var radio_deteccion := 7.0
@export_range(30.0, 360.0, 5.0) var angulo_vision := 110.0
@export_range(0.5, 10.0, 0.5) var tiempo_perder_vista := 3.0
@export_range(0.3, 3.0, 0.1) var distancia_atrapar := 0.9
@export_group("Movimiento")
@export_range(0.5, 4.0, 0.1) var velocidad_patrulla := 1.3
@export_range(1.0, 6.0, 0.1) var velocidad_persecucion := 3.1
@export var puntos_patrulla: Array[Vector3] = [Vector3(6, 0, -0.5), Vector3(6, 0, 6), Vector3(14.5, 0, 6), Vector3(6, 0, 6), Vector3(6, 0, 12), Vector3(-2, 0, 12), Vector3(6, 0, 12), Vector3(6, 0, 18)]
@export_group("Daño y tiempos")
@export_range(1, 50) var dano := 12
@export_range(10, 240) var minutos_fuera := 90
@export_range(0, 1020) var hora_aparicion := 600

var state: int = S.FUERA
var rig: Rig
var tag: Label3D
var main: Node
var path: Array = []
var pi := 0
var last_seen := Vector3.ZERO
var unseen := 0.0
var repath := 0.0
var wait := 0.0
var back_at := 0
var ph := 0.0
var yaw := 0.0
var frozen := false        # solo para capturas: congela la IA y deja la animación


func setup(m: Node) -> void:
	main = m
	rig = Rig.create(Color("#2b2f3a"), Color("#c58f66"), Color("#111111"), "Técnico de mantenimiento", {"outfit": "cyber", "cap": true, "t": {"hair": -1, "glasses": 1, "beard": 1, "mouth": 0, "tie": false, "badge": false, "pack": true}})
	add_child(rig)
	tag = Label3D.new()
	tag.font = Kit.bold(); tag.font_size = 120; tag.pixel_size = .006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED; tag.no_depth_test = true
	tag.outline_size = 22; tag.outline_modulate = Color(0, 0, 0, .85)
	tag.position.y = 2.45
	rig.add_child(tag)
	reset_day()


func reset_day() -> void:
	back_at = hora_aparicion
	_to(S.FUERA)
	visible = false


func state_name() -> String:
	return ["PATRULLA", "PERSECUCION", "BUSQUEDA", "HUIDA", "FUERA"][state]


func _to(s: int) -> void:
	if s == state and s != S.PATRULLA: return
	state = s
	path.clear(); unseen = 0.0; repath = 0.0
	match s:
		S.PATRULLA: tag.text = ""; _go_patrol_nearest()
		S.PERSECUCION: tag.text = "!"; tag.modulate = Color("#ff3b30")
		S.BUSQUEDA: tag.text = "?"; tag.modulate = Color("#ffcc00"); _go(last_seen)
		S.HUIDA: tag.text = "🪪"; tag.modulate = Color.WHITE; _go(Vector3(6, 0, -1.8))
		S.FUERA: tag.text = ""
	state_changed.emit(state_name())


func _go_patrol_nearest() -> void:
	var best := 0; var bd := INF
	for i in puntos_patrulla.size():
		var d := position.distance_to(puntos_patrulla[i])
		if d < bd: bd = d; best = i
	pi = best
	_go(puntos_patrulla[pi])


func _go(p: Vector3) -> void:
	var raw: Array = main.office.path(Vector2(position.x, position.z), Vector2(p.x, p.z), false, true)
	path = raw


## El jugador está dentro del radio, dentro del cono de visión y sin paredes de por medio.
func sees_player() -> bool:
	if main.zone != 0 or main.sitting or main.cam.position.x > 30 or main.cam.position.x < -12: return false
	var pp := Vector2(main.cam.position.x, main.cam.position.z)
	var me := Vector2(position.x, position.z)
	var d := pp.distance_to(me)
	if d > radio_deteccion: return false
	var fwd := Vector2(sin(yaw), cos(yaw))
	var to := (pp - me).normalized()
	if d > 1.6 and rad_to_deg(acos(clampf(fwd.dot(to), -1, 1))) > angulo_vision / 2.0: return false
	var steps := int(d / .3)
	for i in range(1, steps):
		var q := me.lerp(pp, float(i) / steps)
		if not main.free_at(q.x, q.y): return false
	return true


func confront() -> bool:
	if state == S.FUERA or not visible: return false
	var d := Vector2(main.cam.position.x - position.x, main.cam.position.z - position.z).length()
	if d > 2.4: return false
	Game.G.xp = int(Game.G.xp) + 15
	Game.st.sec = mini(100, int(Game.st.sec) + 6)
	Game.save(); Game.hud()
	rig.say("¡Solo venía a revisar la impresora!", 3.0)
	Game.toast("🛂 Le pediste identificación al «técnico de mantenimiento»: no tenía orden de trabajo. Seguridad lo escoltó fuera (+15 XP, +6 seguridad).", 6000)
	Game.ach("soc")
	back_at = int(Game.st.time) + minutos_fuera
	get_tree().create_timer(1.2).timeout.connect(func(): visible = false)
	_to(S.FUERA)
	return true


func _move(dt: float, sp: float) -> bool:
	if path.is_empty(): return true
	var p: Vector2 = path[0]
	var me := Vector2(position.x, position.z)
	var dv := p - me
	if dv.length() < .15:
		path.pop_front()
		return path.is_empty()
	var step := dv.normalized() * minf(dv.length(), sp * dt)
	position.x += step.x; position.z += step.y
	var ty := atan2(dv.x, dv.y)
	yaw = lerp_angle(yaw, ty, minf(1, dt * 10))
	ph += dt * sp * 3.4
	return false


func tick(dt: float, t: float) -> void:
	if frozen:
		ph += dt * 4.0
		rotation.y = yaw
		rig.animate(dt, t, 0, true, ph)
		return
	if Game.st.get("over", false) or main.zone != 0:
		if state != S.FUERA and Game.st.get("over", false): visible = false; _to(S.FUERA)
		return
	match state:
		S.FUERA:
			if int(Game.st.time) >= back_at and int(Game.st.time) < 990:
				position = Vector3(6, 0, -1.6); visible = true
				Game.toast("👷 Alguien con chaleco de «mantenimiento» salió del ascensor… ¿tiene orden de trabajo?", 5000)
				_to(S.PATRULLA)
		S.PATRULLA:
			if wait > 0: wait -= dt
			elif _move(dt, velocidad_patrulla):
				pi = (pi + 1) % puntos_patrulla.size(); wait = 1.2
				_go(puntos_patrulla[pi])
			if sees_player():
				last_seen = main.cam.position; _to(S.PERSECUCION)
				Game.toast("❗ El falso técnico te vio y viene por tu credencial: aléjate corriendo (Shift) o confróntalo (X).", 4500)
		S.PERSECUCION:
			var pp: Vector3 = main.cam.position
			if sees_player():
				unseen = 0.0; last_seen = pp
			else:
				unseen += dt
				if unseen > tiempo_perder_vista: _to(S.BUSQUEDA); return
			repath -= dt
			if repath <= 0 or path.is_empty():
				repath = .45; _go(last_seen)
			_move(dt, velocidad_persecucion)
			if Vector2(pp.x - position.x, pp.z - position.z).length() < distancia_atrapar:
				Game.st.sec = maxi(0, int(Game.st.sec) - dano); Game.hud()
				main.shake = 14.0
				Game.toast("🪪 ¡Te clonó la credencial! −%d de seguridad. Reporta el incidente y cuida tu tarjeta." % dano, 5000)
				Game.beep(140, .2)
				caught_player.emit(dano)
				_to(S.HUIDA)
		S.BUSQUEDA:
			if sees_player():
				last_seen = main.cam.position; _to(S.PERSECUCION); return
			if _move(dt, velocidad_patrulla * 1.3):
				wait += dt
				yaw += dt * 2.2
				if wait > 2.5: wait = 0; _to(S.PATRULLA)
		S.HUIDA:
			if _move(dt, velocidad_persecucion):
				visible = false
				back_at = int(Game.st.time) + minutos_fuera
				_to(S.FUERA)
	rig.position = Vector3.ZERO
	rotation.y = yaw
	rig.animate(dt, t, 0, state != S.FUERA and not path.is_empty() and wait <= 0, ph)
