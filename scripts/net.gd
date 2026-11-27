extends Node
## Multijugador nativo de Godot (ENet): sala de hasta 4 técnicos de TI.
## El anfitrión crea la sala y comparte un código de 7 letras (codifica su IP de red local)
## o directamente su IP. Se sincroniza nombre, avatar, zona, posición, orientación y, si
## manejan, el superdeportivo. Chat con Enter. Cada técnico juega su propia jornada.

signal roster_changed
signal status_changed(msg: String, bad: bool)
signal chat(who: String, msg: String)
signal player_left(id: int)

const PORT := 24575
const MAX := 4
const ALPHA := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var role := "solo"          # solo | host | client
var code := ""
var my_name := "Técnico"
var my_av := {}
var players := {}           # id -> {name, av, zone, x, z, y, drv, cx, cz, ch}
var peer: ENetMultiplayerPeer
var state_fn: Callable      # devuelve el estado local {zone, x, z, y, drv, cx, cz, ch}
var _t := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer)
	multiplayer.peer_disconnected.connect(_on_gone)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _status("No se pudo conectar. Revisa el código o la IP y que estén en la misma red.", true); leave())
	multiplayer.server_disconnected.connect(func(): _status("Se perdió la conexión con la sala.", true); leave(); chat.emit("Sistema", "El anfitrión cerró la sala"))


func _status(m: String, bad := false) -> void:
	status_changed.emit(m, bad)


# ---------------- código de sala ----------------
static func lan_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31):
			return a
	return "127.0.0.1"


static func ip_to_code(ip: String) -> String:
	var p := ip.split(".")
	if p.size() != 4: return ""
	var n := (int(p[0]) << 24) | (int(p[1]) << 16) | (int(p[2]) << 8) | int(p[3])
	var s := ""
	for i in 7:
		s = ALPHA[n & 31] + s
		n >>= 5
	return s


static func code_to_ip(room: String) -> String:
	room = room.strip_edges().to_upper()
	if room.count(".") == 3: return room.split(":")[0]
	if room.length() != 7: return ""
	var n := 0
	for ch in room:
		var v := ALPHA.find(ch)
		if v < 0: return ""
		n = (n << 5) | v
	return "%d.%d.%d.%d" % [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]


# ---------------- sala ----------------
func host() -> void:
	if OS.has_feature("web"):
		_status("El multijugador solo está en la versión de escritorio.", true); return
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX - 1)
	if err != OK:
		_status("No se pudo crear la sala (puerto %d ocupado)." % PORT, true); peer = null; return
	multiplayer.multiplayer_peer = peer
	role = "host"
	var ip := lan_ip()
	code = ip_to_code(ip)
	players.clear()
	_status("Sala lista. Código %s · IP %s:%d. Compártelo con tus compañeros (misma red)." % [code, ip, PORT])
	roster_changed.emit()


func join(room: String) -> void:
	if OS.has_feature("web"):
		_status("El multijugador solo está en la versión de escritorio.", true); return
	var ip := code_to_ip(room)
	if ip == "":
		_status("Escribe el código de 7 letras o la IP del anfitrión.", true); return
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		_status("No se pudo iniciar la conexión.", true); peer = null; return
	multiplayer.multiplayer_peer = peer
	role = "client"
	code = room.strip_edges().to_upper()
	_status("Conectando a %s…" % ip)


func leave() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	var ids := players.keys()
	players.clear()
	for id in ids: player_left.emit(id)
	role = "solo"; code = ""
	roster_changed.emit()


func is_online() -> bool:
	return role != "solo" and peer != null


func _on_peer(id: int) -> void:
	if role == "host" and players.size() >= MAX - 1:
		peer.disconnect_peer(id); return


func _on_gone(id: int) -> void:
	if players.has(id):
		var n: String = players[id].name
		players.erase(id)
		player_left.emit(id)
		chat.emit("Sistema", n + " salió")
		roster_changed.emit()


func _on_connected() -> void:
	_status("Conectado a la sala %s." % code)
	hello.rpc_id(1, my_name, my_av)


static func clean_name(s: String) -> String:
	var r := RegEx.create_from_string("[<>&\"\\n\\r]")
	return r.sub(s, "", true).strip_edges().substr(0, 14)


@rpc("any_peer", "call_remote", "reliable")
func hello(nm: String, av: Dictionary) -> void:
	if role != "host": return
	var id := multiplayer.get_remote_sender_id()
	players[id] = {"name": clean_name(nm) if clean_name(nm) != "" else "Técnico", "av": av, "zone": 0, "x": -1.0, "z": 2.0, "y": 0.0, "drv": false, "cx": 0.0, "cz": 0.0, "ch": 0.0}
	chat.emit("Sistema", players[id].name + " entró a la sala")
	_relay_chat_all("Sistema", players[id].name + " entró a la sala", id)
	roster_changed.emit()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func s(st: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if role == "host" and players.has(id):
		for k in ["zone", "x", "z", "y", "drv", "cx", "cz", "ch"]:
			if st.has(k): players[id][k] = st[k]


@rpc("authority", "call_remote", "unreliable_ordered")
func w(list: Array) -> void:
	if role != "client": return
	var seen := {}
	for q in list:
		if not (q is Dictionary): continue
		var id := int(q.get("i", 0))
		if id == multiplayer.get_unique_id(): continue
		seen[id] = true
		var known := players.has(id)
		if not known:
			players[id] = {}
		for k in q: players[id][k] = q[k]
		players[id].name = clean_name(str(q.get("name", "Técnico")))
		if not known: roster_changed.emit()
	for id in players.keys():
		if not seen.has(id):
			players.erase(id); player_left.emit(id); roster_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func c(nm: String, msg: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	msg = msg.substr(0, 120)
	if role == "host":
		var who: String = players[id].name if players.has(id) else nm
		chat.emit(who, msg)
		_relay_chat_all(who, msg, id)
	else:
		chat.emit(clean_name(nm), msg)


func _relay_chat_all(who: String, msg: String, except_id: int) -> void:
	for id in players:
		if id != except_id: c.rpc_id(id, who, msg)


func send_chat(msg: String) -> void:
	msg = msg.strip_edges().substr(0, 120)
	if msg == "": return
	chat.emit(my_name, msg)
	if role == "client": c.rpc_id(1, my_name, msg)
	elif role == "host": _relay_chat_all(my_name, msg, 0)


func _process(dt: float) -> void:
	if not is_online(): return
	_t += dt
	if _t < .08: return
	_t = 0
	var me: Dictionary = state_fn.call() if state_fn.is_valid() else {}
	if role == "client" and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		s.rpc_id(1, me)
	elif role == "host":
		var list := [{"i": 1, "name": my_name, "av": my_av}.merged(me)]
		for id in players:
			var p: Dictionary = players[id]
			list.append({"i": id}.merged(p))
		for id in players:
			w.rpc_id(id, list)
