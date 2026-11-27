class_name CiscoSwitch
extends RefCounted
## Emulador Cisco IOS (Catalyst 2960) — port 1:1 del original.

signal output(text: String)
signal job_completed(all_done: bool)

var PN: Array[String] = []
var SW := {}
var startup := ""
var wrote := false
var cm := "user"
var ctx = null
var hist: Array[String] = []
var hi := 0
var pend := 0
var ji := 0
var jobs: Array = []
var log_text := ""

const BAD := "% Invalid input detected at '^' marker."
const INC := "% Incomplete command."


func _init() -> void:
	for i in range(1, 25):
		PN.append("Fa0/%d" % i)
	PN.append("Gi0/1"); PN.append("Gi0/2")
	reset_day(1)


func reset_day(day: int) -> void:
	SW = {"host":"Switch","secret":"","vlans":{1:"default"},"ports":{},"svi":{}}
	for k in PN:
		SW.ports[k] = {"mode":"access","vlan":1,"shut":false,"desc":""}
	startup = cfg()
	wrote = false; cm = "user"; ctx = null; pend = 0; ji = 0
	jobs = mk_jobs(day)
	log_text = ""


func full(k: String) -> String:
	return ("FastEthernet" if k[0] == "F" else "GigabitEthernet") + k.substr(2)

func cfg() -> String:
	return JSON.stringify({"h":SW.host,"s":SW.secret,"v":SW.vlans,"p":SW.ports,"i":SW.svi})

func saved() -> bool:
	return wrote and startup == cfg()

func P(k: String) -> Dictionary:
	return SW.svi[int(k.substr(1))] if k[0] == "V" else SW.ports[k]

func pd(x, n: int) -> String:
	return str(x).rpad(n)

func pick(w, l: Array):
	if w == null or str(w) == "":
		return null
	w = str(w).to_lower()
	if l.has(w):
		return w
	var m := l.filter(func(x): return str(x).begins_with(w))
	return m[0] if m.size() == 1 else ("?" if m.size() > 1 else null)

func ipok(x) -> bool:
	if x == null:
		return false
	var rx := RegEx.create_from_string("^(\\d{1,3}\\.){3}\\d{1,3}$")
	if rx.search(str(x)) == null:
		return false
	for n in str(x).split("."):
		if int(n) >= 256:
			return false
	return true

func say(t: String) -> void:
	log_text += t + "\n"
	output.emit(t + "\n")

func ps() -> String:
	var suf := {"user":">","priv":"#","cfg":"(config)#","vlan":"(config-vlan)#",
		"if":"(config-if-range)#" if (ctx is Array and ctx.size() > 1) else "(config-if)#"}
	return SW.host + suf[cm]

func vname(n: int) -> String:
	return "VLAN%04d" % n

func _hit(a: int, b: int, m: String) -> void:
	Game.st.sat = max(0, Game.st.sat + a)
	Game.st.sec = max(0, Game.st.sec + b)
	Game.hud()
	say(m)


func parse_if(a: Array):
	var s := "".join(a).to_lower()
	var m: RegExMatch
	m = RegEx.create_from_string("^range(?:f|fa|fastethernet)0/(\\d+)-(?:(?:f|fa|fastethernet)0/)?(\\d+)$").search(s)
	if m:
		var r: Array = []
		for n in range(int(m.get_string(1)), int(m.get_string(2)) + 1):
			if not SW.ports.has("Fa0/%d" % n):
				return null
			r.append("Fa0/%d" % n)
		return r
	m = RegEx.create_from_string("^(?:f|fa|fastethernet)0/(\\d+)$").search(s)
	if m:
		return ["Fa0/" + m.get_string(1)] if SW.ports.has("Fa0/" + m.get_string(1)) else null
	m = RegEx.create_from_string("^(?:g|gi|gigabitethernet)0/(\\d+)$").search(s)
	if m:
		return ["Gi0/" + m.get_string(1)] if SW.ports.has("Gi0/" + m.get_string(1)) else null
	m = RegEx.create_from_string("^vlan(\\d+)$").search(s)
	if m:
		var n := int(m.get_string(1))
		if n < 1 or n > 4094:
			return null
		if not SW.svi.has(n):
			SW.svi[n] = {"ip":"","mask":"","shut":true}
		return ["V%d" % n]
	return null


func run_cfg() -> String:
	var t := "Building configuration...\n\nCurrent configuration : %d bytes\n!\nversion 15.0\n!\nhostname %s\n!\n" % [cfg().length(), SW.host]
	if SW.secret != "":
		t += "enable secret 5 $1$mERr$hx5rVt7rPNoS4wqbXKX7m0\n!\n"
	for n in _vlan_ids():
		if n != 1:
			t += "vlan %d\n name %s\n!\n" % [n, SW.vlans[n]]
	for k in PN:
		var p: Dictionary = SW.ports[k]
		t += "interface %s\n" % full(k)
		if p.desc != "": t += " description %s\n" % p.desc
		if p.mode == "trunk": t += " switchport mode trunk\n"
		elif p.vlan != 1: t += " switchport access vlan %d\n switchport mode access\n" % p.vlan
		if p.shut: t += " shutdown\n"
		t += "!\n"
	for n in SW.svi:
		var v: Dictionary = SW.svi[n]
		t += "interface Vlan%d\n %s\n%s!\n" % [n, ("ip address %s %s" % [v.ip, v.mask]) if v.ip != "" else "no ip address", " shutdown\n" if v.shut else ""]
	return t + "end"


func _vlan_ids() -> Array:
	var ids: Array = []
	for k in SW.vlans:
		ids.append(int(k))
	ids.sort()
	return ids


func sh(a: Array, priv: bool) -> String:
	var w = pick(a[0] if a.size() > 0 else null, ["running-config","vlan","ip","version","interfaces","logging"])
	if w == null or w == "?":
		return BAD
	match w:
		"running-config":
			if not priv: return BAD
			say(run_cfg())
		"logging":
			say((Engine.get_main_loop() as SceneTree).root.get_node("Soc").swlog())
		"vlan":
			var t := "VLAN Name                             Status    Ports\n---- -------------------------------- --------- -------------------------------\n"
			for n in _vlan_ids():
				var pl: Array = PN.filter(func(k): return SW.ports[k].mode == "access" and int(SW.ports[k].vlan) == n)
				t += pd(n, 5) + pd(SW.vlans[n], 33) + pd("active", 10) + ", ".join(pl) + "\n"
			say(t)
		"ip":
			if pick(a[1] if a.size() > 1 else null, ["interface"]) != "interface": return BAD
			var t := "Interface              IP-Address      OK? Method Status                Protocol\n"
			for k in PN:
				var p: Dictionary = SW.ports[k]
				t += pd(full(k), 23) + pd("unassigned", 16) + "YES unset  " + (pd("administratively down", 22) + "down" if p.shut else pd("up", 22) + "up") + "\n"
			for n in SW.svi:
				var v: Dictionary = SW.svi[n]
				t += pd("Vlan%d" % n, 23) + pd(v.ip if v.ip != "" else "unassigned", 16) + "YES " + ("manual " if v.ip != "" else "unset  ") + (pd("administratively down", 22) + "down" if v.shut else pd("up", 22) + "up") + "\n"
			say(t)
		"interfaces":
			var t := "Port      Name               Status       Vlan       Duplex  Speed Type\n"
			for k in PN:
				var p: Dictionary = SW.ports[k]
				t += pd(k, 10) + pd(p.desc.substr(0, 18), 19) + pd("disabled" if p.shut else "connected", 13) + pd("trunk" if p.mode == "trunk" else str(p.vlan), 11) + "a-full  a-100 10/100BaseTX\n"
			say(t)
		_:
			say("Cisco IOS Software, C2960 Software (C2960-LANBASEK9-M), Version 15.0(2)SE4\n%s uptime is 2 hours, 14 minutes" % SW.host)
	return ""


func wr() -> void:
	startup = cfg()
	wrote = true
	say("Building configuration...\n[OK]")


func restore() -> void:
	var o: Dictionary = JSON.parse_string(startup)
	SW.host = o.h; SW.secret = o.s
	SW.vlans = {}; for k in o.v: SW.vlans[int(k)] = o.v[k]
	SW.ports = {}
	for k in o.p:
		var p: Dictionary = o.p[k]
		SW.ports[k] = {"mode":p.mode,"vlan":int(p.vlan),"shut":p.shut,"desc":p.desc}
	SW.svi = {}; for k in o.i: SW.svi[int(k)] = o.i[k]


func _table() -> Dictionary:
	var user := {
		"enable": func(_a):
			if SW.secret != "":
				pend = 1; say("Password:"); return ""
			cm = "priv"; return "",
		"show": func(a): return sh(a, false),
		"exit": func(_a): return ""}
	var priv := {
		"disable": func(_a): cm = "user"; return "",
		"exit": func(_a): cm = "user"; return "",
		"show": func(a): return sh(a, true),
		"write": func(_a): wr(); return "",
		"configure": func(a):
			if a.size() > 0 and not "terminal".begins_with(a[0]): return BAD
			cm = "cfg"; say("Enter configuration commands, one per line.  End with CNTL/Z."); return "",
		"copy": func(a):
			if a.size() < 2: return INC
			wr(); return "",
		"erase": func(a):
			if a.size() == 0: return INC
			var ports := {}
			for k in PN: ports[k] = {"mode":"access","vlan":1,"shut":false,"desc":""}
			startup = JSON.stringify({"h":"Switch","s":"","v":{1:"default"},"p":ports,"i":{}})
			wrote = false
			_hit(-15, -8, "[OK] Erase of nvram: complete\n¡Borraste la configuración de arranque! Al reiniciar se perderá todo.")
			return "",
		"reload": func(_a):
			var lost := cfg() != startup
			restore(); cm = "user"; say("Reloading...\n")
			if lost: _hit(-4, 0, "La configuración sin guardar se perdió. Usa write memory antes de reiniciar.")
			return ""}
	var cfgt := {
		"hostname": func(a):
			if a.size() == 0: return INC
			SW.host = a[0]; return "",
		"vlan": func(a):
			var n := int(a[0]) if a.size() > 0 and str(a[0]).is_valid_int() else 0
			if n < 1 or n > 4094: return BAD
			if not SW.vlans.has(n): SW.vlans[n] = vname(n)
			cm = "vlan"; ctx = n; return "",
		"interface": func(a):
			var r = parse_if(a)
			if r == null: return BAD
			ctx = r; cm = "if"; return "",
		"enable": func(a):
			if pick(a[0] if a.size() > 0 else null, ["secret"]) != "secret": return BAD
			if a.size() < 2: return INC
			SW.secret = " ".join(a.slice(1)); return "",
		"no": func(a):
			if pick(a[0] if a.size() > 0 else null, ["vlan"]) != "vlan": return BAD
			var n := int(a[1]) if a.size() > 1 and str(a[1]).is_valid_int() else -1
			if n == 1: say("% Default VLAN 1 may not be deleted.")
			else: SW.vlans.erase(n)
			return "",
		"do": func(a):
			var c = pick(a[0] if a.size() > 0 else null, ["show","write","copy"])
			if c == null or c == "?": return BAD
			return priv[c].call(a.slice(1)),
		"exit": func(_a): cm = "priv"; return "",
		"end": func(_a): cm = "priv"; return ""}
	var vlant := {
		"name": func(a):
			if a.size() == 0: return INC
			SW.vlans[ctx] = "_".join(a); return "",
		"exit": func(_a): cm = "cfg"; return "",
		"end": func(_a): cm = "priv"; return ""}
	var ift := {
		"shutdown": func(_a):
			for k in ctx: P(k).shut = true
			return "",
		"no": func(a):
			var w = pick(a[0] if a.size() > 0 else null, ["shutdown","description"])
			if w == null or w == "?": return BAD
			for k in ctx:
				if w == "shutdown": P(k).shut = false
				else: P(k).desc = ""
			return "",
		"description": func(a):
			if a.size() == 0: return INC
			for k in ctx: P(k).desc = " ".join(a)
			return "",
		"switchport": func(a):
			for k in ctx:
				if str(k)[0] == "V": return BAD
			var w = pick(a[0] if a.size() > 0 else null, ["mode","access"])
			if w == "mode":
				var m = pick(a[1] if a.size() > 1 else null, ["access","trunk"])
				if m == null or m == "?": return BAD
				for k in ctx: P(k).mode = m
			elif w == "access":
				if pick(a[1] if a.size() > 1 else null, ["vlan"]) != "vlan": return BAD
				var n := int(a[2]) if a.size() > 2 and str(a[2]).is_valid_int() else 0
				if n == 0 or n > 4094: return BAD
				if not SW.vlans.has(n):
					SW.vlans[n] = vname(n); say("% Access VLAN does not exist. Creating vlan %d" % n)
				for k in ctx:
					P(k).vlan = n; P(k).mode = "access"
			else:
				return BAD
			return "",
		"ip": func(a):
			if not str(ctx[0]).begins_with("V"): return BAD
			if pick(a[0] if a.size() > 0 else null, ["address"]) != "address": return BAD
			if not ipok(a[1] if a.size() > 1 else null) or not ipok(a[2] if a.size() > 2 else null): return BAD
			P(ctx[0]).ip = a[1]; P(ctx[0]).mask = a[2]; return "",
		"exit": func(_a): cm = "cfg"; return "",
		"end": func(_a): cm = "priv"; return ""}
	match cm:
		"user": return user
		"priv": return priv
		"cfg": return cfgt
		"vlan": return _merge(cfgt, vlant)
		_: return _merge(cfgt, ift)


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var r := a.duplicate()
	for k in b: r[k] = b[k]
	return r


func exec(line: String) -> void:
	if pend:
		pend = 0
		say("")
		if line == SW.secret: cm = "priv"
		else: say("% Bad secrets")
		return
	say(ps() + " " + line)
	var t: Array = Array(line.strip_edges().split(" ", false))
	if t.is_empty():
		return
	var tb := _table()
	if t[0] == "?" or t[t.size() - 1] == "?":
		say("  ".join(tb.keys()))
		return
	var c = pick(t[0], tb.keys())
	if c == "?":
		say('% Ambiguous command:  "' + line.strip_edges() + '"')
		return
	if c == null:
		say("% Invalid input detected at '^' marker.")
		return
	var r = tb[c].call(t.slice(1))
	if r is String and r != "":
		say(r)


func submit(v: String) -> void:
	if pend == 0 and v.strip_edges() != "":
		hist.append(v)
	hi = hist.size()
	exec(v)
	chk()


# ---------------- Trabajos del data center ----------------
func mk_jobs(d: int) -> Array:
	var V: int = 20 if d < 2 else [30,40,50,60,70,80][randi() % 6]
	var N: String = "VENTAS" if d < 2 else ["RRHH","TI","VOZ","CCTV","INVITADOS","ALMACEN"][randi() % 6]
	var port: int = 5 if d < 2 else 2 + randi() % 16
	var H: String = "DC-SW1" if d < 2 else "SUC%d-SW1" % d
	var a: int = 20 if d < 2 else 6 + randi() % 10
	var b: int = a + (4 if d < 2 else 3)
	var g: int = 99 if d < 2 else [99,88,77][randi() % 3]
	var ip := "192.168.%d.2" % g
	return [
		{"t":"Segmentar la red de %s" % N, "s":8,
		 "h":"vlan %d → name %s · interface fa0/%d → switchport mode access → switchport access vlan %d · write memory" % [V, N, port, V],
		 "g":[["Crear la VLAN %d con el nombre %s" % [V, N], func(): return SW.vlans.get(V) == N],
			  ["Fa0/%d en modo access dentro de la VLAN %d" % [port, V], func(): var p: Dictionary = SW.ports["Fa0/%d" % port]; return p.mode == "access" and int(p.vlan) == V],
			  ["Guardar la configuración en NVRAM", func(): return saved()]]},
		{"t":"Endurecer el switch", "s":12,
		 "h":"configure terminal → hostname %s · enable secret <clave> · interface range fa0/%d - %d → shutdown · write memory" % [H, a, b],
		 "g":[["Cambiar el hostname a %s" % H, func(): return SW.host == H],
			  ["Definir una clave con enable secret", func(): return SW.secret != ""],
			  ["Apagar los puertos sin uso Fa0/%d a Fa0/%d" % [a, b], func():
					for n in range(a, b + 1):
						if not SW.ports["Fa0/%d" % n].shut: return false
					return true],
			  ["Guardar la configuración", func(): return saved()]]},
		{"t":"Troncal y gestión", "s":8,
		 "h":"interface gi0/1 → switchport mode trunk · interface vlan %d → ip address %s 255.255.255.0 → no shutdown · write memory" % [g, ip],
		 "g":[["Gi0/1 como troncal (trunk)", func(): return SW.ports["Gi0/1"].mode == "trunk"],
			  ["Interfaz VLAN %d con IP %s/24 activa" % [g, ip], func(): var v = SW.svi.get(g); return v != null and v.ip == ip and v.mask == "255.255.255.0" and not v.shut],
			  ["Guardar la configuración", func(): return saved()]]}]


func goal_state() -> Array:
	if ji >= jobs.size():
		return []
	return jobs[ji].g.map(func(g): return bool(g[1].call()))


func chk() -> void:
	if ji >= jobs.size():
		return
	var ok := goal_state()
	for v in ok:
		if not v:
			return
	var J: Dictionary = jobs[ji]
	ji += 1
	Game.st.net += 1
	Game.st.earn += 40
	if Game.st.net >= 3:
		Game.ach("cli")
	Game.st.time += max(8, (15 if Game.ups("ccna") else 25) - Game.sk("cli") * 3)
	Game.st.sat = min(100, Game.st.sat + 8)
	Game.st.sec = min(100, Game.st.sec + int(J.s))
	wrote = false
	Game.hud()
	Game.screens_changed.emit()
	say("\n*** Trabajo completado: " + J.t + " ***")
	if ji >= 3:
		say("Mantenimiento del data center terminado. Cerrando consola...")
	else:
		say("Siguiente trabajo: " + jobs[ji].t)
	job_completed.emit(ji >= 3 or Game.st.time >= Data.END)
