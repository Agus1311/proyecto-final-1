extends Node
## Amenaza interna «El Infiltrado» (port 1:1 del módulo INF del original).

signal changed
signal trunk_marker(on: bool)

const TYPES := {
	"trunk": {"ico":"🔌","name":"Cable troncal desconectado","sat":-8,"sec":-4,"mins":90,"lesson":"Bitácora del switch: un login SSH desde la IP de un PC de usuario es anómalo. El acceso administrativo debe restringirse a la VLAN de gestión."},
	"usb": {"ico":"💾","name":"Troyano desde USB","sat":0,"sec":-10,"mins":100,"lesson":"USBSTOR: el mismo número de serie en dos equipos vincula los incidentes. Captura la evidencia volátil ANTES de contener (orden de volatilidad)."},
	"dns": {"ico":"🌐","name":"Alteración de DNS","sat":-4,"sec":-8,"mins":90,"lesson":"Credenciales robadas ≠ identidad: compara el usuario con la estación de origen del evento 5136; el usuario puede ser una falsa bandera."},
	"nas": {"ico":"🗄️","name":"Respaldos borrados (NAS)","sat":-4,"sec":-10,"mins":120,"lesson":"Auditoría del NAS: revisa usuario y origen. La regla 3-2-1 y los snapshots offsite permiten restaurar."}}
const SHIRT := {"d05a7a":"rosa","4c7ad0":"azul","6a9a4c":"verde","8a5ac0":"morado","e8a03a":"naranja"}
const SPARE := ["gris","roja","blanca","negra","beige","celeste"]
const MOTIVES := ["resentido por una evaluación de desempeño","vendió acceso a un competidor","busca extorsionar a la empresa","quiere encubrir un fraude interno"]
const HOWTO := {
	"trunk":"Contención: reconecta el cable en el rack del Data Center (parpadea en rojo). Evidencia: show logging en el switch.",
	"usb":"Contención: CAA Connect → av-scan.ps1, o elimina el archivo y el proceso. Evidencia: doskey /history y reg query HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USBSTOR.",
	"dns":"Contención: ipconfig /flushdns (o flush-dns.bat) en cada equipo afectado. Evidencia: nslookup google.com y eventos 5136 de AD.",
	"nas":"Contención: restaura el snapshot offsite. Evidencia: auditoría del NAS."}
const HINT := {
	"AD":"Registro de seguridad de AD (4624/4625/5136) y estado de sesiones. Compara usuario, estación (IP) y quién tenía sesión activa.",
	"CCTV":"Las cámaras muestran color de camisa y credencial; la foto del carnet de cada empleado está en el Directorio.",
	"SW":"Syslog del switch core. También puedes escribir show logging en la consola Cisco del Data Center.",
	"EQ":"Telemetría de endpoints. En CAA Connect → Símbolo del sistema prueba: doskey /history · reg query HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USBSTOR · nslookup google.com",
	"NAS":"Auditoría del NAS01: quién borró qué y desde dónde."}
const COST_CTL := 80
const FN := ["GV","ID","PR","DE","RS","RC"]
const FNN := {"GV":"Gobernar","ID":"Identificar","PR":"Proteger","DE":"Detectar","RS":"Responder","RC":"Recuperar"}
const FW := {
	"trunk": {"nist":"NIST CSF DE.CM-01 · RS.MI-01 · PR.IR-01","iso":"ISO 27001 A.7.2 · A.8.20 · A.8.15","cobit":"DSS05.02 · DSS05.05","att":"T1078 · T1498","ctl":"ACL de gestión + 802.1X / port-security",
		"q":"¿Qué control corrige la causa raíz (acceso administrativo por SSH desde un PC de usuario y puertos troncales desprotegidos)?",
		"o":["ACL en la VTY solo desde la VLAN de gestión + 802.1X / port-security","Cambiar el color de los cables para identificarlos","Reiniciar el switch cada noche"]},
	"usb": {"nist":"NIST CSF DE.AE-02 · RS.AN-03 · PR.PS-01","iso":"ISO 27001 A.7.10 · A.8.7 · A.8.16","cobit":"DSS05.01 · DSS05.03","att":"T1091 · T1053.005","ctl":"Bloqueo de USB por GPO + EDR",
		"q":"¿Qué control previene la reincidencia de malware por medios extraíbles?",
		"o":["GPO que bloquea USB no autorizadas + EDR con control de dispositivos","Pedir a los usuarios que no usen USB","Desinstalar el antivirus para ganar rendimiento"]},
	"dns": {"nist":"NIST CSF DE.CM-09 · PR.AA-05 · RS.MI-02","iso":"ISO 27001 A.8.2 · A.8.9 · A.8.16","cobit":"DSS05.04 · DSS05.02","att":"T1584.002 · T1078","ctl":"PAM + MFA para administración DNS",
		"q":"¿Qué control reduce el riesgo de que una cuenta robada modifique registros DNS?",
		"o":["Mínimo privilegio, MFA y cuentas administrativas separadas (PAM)","Compartir la cuenta de administrador entre todo TI","Desactivar los eventos 5136 para reducir el ruido"]},
	"nas": {"nist":"NIST CSF PR.DS-11 · RC.RP-01 · RS.MI-01","iso":"ISO 27001 A.8.13 · A.5.30 · A.8.3","cobit":"DSS04.07 · DSS02.04","att":"T1490 · T1485","ctl":"Respaldos inmutables 3-2-1-1-0",
		"q":"¿Qué control garantiza recuperar respaldos aunque un interno los borre?",
		"o":["Respaldos inmutables y offsite (3-2-1-1-0) con permisos separados","Guardar los respaldos en la misma carpeta compartida","Dar permiso de borrado a todo el equipo de TI"]}}

var X := {}


func _ready() -> void:
	reset()
	Game.day_started.connect(_on_day)
	Game.pre_finish.append(end_day)


func R(n: int) -> int: return randi() % n
func hm(t: int) -> String: return "%02d:%02d" % [t / 60, t % 60]
func ip_of(i: int) -> String: return "192.168.10.%d" % (101 + i)
func other(n: int, ex: int) -> int:
	var k := ex
	while k == ex: k = R(n)
	return k


func reset() -> void:
	X = {"on": false, "C": -1, "motive": "", "lv": {}, "sched": [], "inc": [], "clues": [], "pins": [], "ros": [], "meet": 0, "caught": 0, "view": "al", "sel": -1, "ser": "", "trunk": -1, "nas": -1, "qt": "", "qe": "", "qr": [], "qc": [], "idp": 0}
	trunk_marker.emit(false)


func inf() -> Dictionary:
	if not Game.G.has("inf") or not (Game.G.inf is Dictionary):
		Game.G.inf = {"w": 0, "l": 0, "n": 0}
	var I: Dictionary = Game.G.inf
	if not I.has("fw"): I.fw = {}
	if not I.has("ctl"): I.ctl = {}
	return I


func level(day: int) -> Dictionary:
	var d := mini(3, int(ceil(day / 2.0)))
	return {"n": mini(5, 2 + ((day - 1) >> 1)), "ff": [0.0, .35, .6][d - 1], "noise": 2 if d > 2 else 1, "locked": [2, 3, 4][d - 1], "badge": d == 1}


func _on_day() -> void:
	reset()
	inf()
	X.on = true
	X.lv = level(int(Game.G.day))
	_assign()
	X.sched = _plan(X.lv.n)
	changed.emit()
	await get_tree().create_timer(5.6).timeout
	Game.toast("🕵️ Auditoría interna: hay un infiltrado entre los empleados. Sigue NIST SP 800-61: detecta, preserva evidencia, contén, recupera y cierra con lecciones aprendidas (pestaña SOC).", 6500)


func pts(f: String, n: int) -> void:
	var I := inf()
	I.fw[f] = clampi(int(I.fw.get(f, 0)) + n, 0, 100)
	if FN.all(func(k): return int(I.fw.get(k, 0)) >= 50):
		Game.ach("nist")


func phases(n: Dictionary) -> String:
	return "NIST SP 800-61 — %s Preparación · ✔ Detección y análisis · %s Contención, erradicación y recuperación · %s Post-incidente" % ["✔" if inf().ctl.has(n.type) else "○", "✔" if n.ph >= 2 else "○", "✔" if n.q else "○"]


func implement(t: String) -> void:
	inf().ctl[t] = 1
	pts("PR", 10)
	Game.toast("🛡️ Control implementado: " + FW[t].ctl + " (" + FW[t].iso + ")")
	Game.save(); Game.hud()


func _roster() -> Array:
	var col := {}
	for d in Data.ZD:
		if d[0] in ["Andrea","Marta","Luis","Carlos","Patricia","Jorge"]:
			col[d[0]] = SHIRT.get(d[4], "")
	var out: Array = []
	for i in Data.USERS.size():
		var u: Array = Data.USERS[i]
		var f: String = u[1].split(" ")[0]
		out.append({"i": i, "u": u[0], "name": u[1], "dept": u[2], "ip": ip_of(i), "pc": Game.st.pc[i].name, "shirt": col.get(f, "") if col.get(f, "") != "" else SPARE[i % 6]})
	return out


func _assign() -> void:
	X.ros = _roster()
	X.C = R(X.ros.size())
	X.motive = MOTIVES.pick_random()
	X.ser = "4C530001" + str(100000 + R(899999))


func _add(inc: Dictionary, o: Dictionary) -> Dictionary:
	var c := {"id": X.clues.size(), "inc": inc.id, "t": inc.t, "who": [], "decoy": [], "firm": false, "vol": false, "open": false, "kind": "", "pc": -2, "src": "", "text": "", "usb": false, "cmds": []}
	for k in o: c[k] = o[k]
	X.clues.append(c)
	return c


func _gen_clues(inc: Dictionary) -> void:
	var ros: Array = X.ros
	var c0: int = X.C
	var T: int = inc.t
	var ty: String = inc.type
	var lv: Dictionary = X.lv
	var ff: bool = (ty == "dns" or ty == "nas") and randf() < lv.ff
	var D := other(ros.size(), c0)
	inc.ff = D if ff else -1
	var usr: String = ros[D if ff else c0].u
	var dec: Array = [D] if ff else []
	var pc: Array = Game.st.pc
	match ty:
		"trunk":
			_add(inc, {"src":"SW","t":T - 1,"firm":true,"who":[c0],"text":"%s %%SEC_LOGIN-5-LOGIN_SUCCESS: Login Success [user: admin] [Source: %s] [localport: 22]" % [hm(T - 1), ip_of(c0)]})
			_add(inc, {"src":"SW","text":"%s %%LINK-3-UPDOWN: Interface GigabitEthernet0/1, changed state to down" % hm(T)})
		"usb":
			_add(inc, {"src":"EQ","usb":true,"pc":inc.v,"text":"USBSTOR · Kingston DataTraveler, serie %s, conectada en %s (%s) a las %s" % [X.ser, pc[inc.v].name, ip_of(inc.v), hm(T - 2)]})
			_add(inc, {"src":"EQ","usb":true,"firm":true,"who":[c0],"pc":c0,"text":"USBSTOR · la misma memoria (serie %s) fue registrada en %s (%s) a las %s" % [X.ser, pc[c0].name, ip_of(c0), hm(500 + R(30))]})
			_add(inc, {"src":"EQ","vol":true,"text":"Historial CMD de %s: E:\\update_flash.exe · whoami /all · schtasks /create /tn Updater /tr C:\\Users\\Public\\svch0st.exe" % pc[inc.v].name,
				"cmds":["E:\\update_flash.exe","whoami /all","schtasks /create /tn Updater /tr C:\\Users\\Public\\svch0st.exe"]})
		"dns":
			_add(inc, {"src":"AD","firm":true,"who":[c0],"decoy":dec,"text":"%s Evento 5136 (cambio en el servicio de directorio): registro A \"google.com\" → 185.220.101.77 · Usuario: %s · Estación: %s" % [hm(T), usr, ip_of(c0)]})
			_add(inc, {"src":"EQ","text":"nslookup google.com en los equipos afectados devuelve 185.220.101.77 (esperado: 142.250.78.14)"})
		_:
			_add(inc, {"src":"NAS","firm":true,"who":[c0],"decoy":dec,"text":"%s NAS01 audit · DELETE /backup/diario/*.bak (23 archivos) · Usuario: %s · Origen: %s" % [hm(T), usr, ip_of(c0)]})
	var me: Dictionary = ros[c0]
	var cam: String = {"trunk":"Pasillo Data Center","usb":"Pasillo piso 5","dns":"Oficina TI","nas":"Pasillo Data Center"}[ty]
	var who: Array = ros.filter(func(r): return r.shirt == me.shirt and (not lv.badge or r.dept == me.dept)).map(func(r): return r.i)
	_add(inc, {"src":"CCTV","t":T - 3,"who":who,"text":"%s Cámara «%s»: figura con camisa %s%s se aleja del área" % [hm(T - 3), cam, me.shirt, (" y credencial de " + me.dept) if lv.badge else ""]})
	var others: Array = ros.map(func(r): return r.i).filter(func(i): return i != c0)
	others.shuffle()
	var locked: Array = [c0] + others.slice(0, lv.locked - 1)
	var nm := func(l: Array) -> String: return ", ".join(l.map(func(i): return ros[i].u))
	var active: Array = ros.map(func(r): return r.i).filter(func(i): return not locked.has(i))
	_add(inc, {"src":"AD","kind":"alibi","t":T - 2,"who":locked,"text":"%s Sesiones — Activas: %s. Bloqueadas o sin actividad: %s." % [hm(T - 2), nm.call(active), nm.call(locked)]})
	for k in lv.noise:
		var r := other(ros.size(), c0)
		var u: String = ros[r].u
		var txt: String = ["%s %s inició sesión en dc01 — coincide con la ventana de mantenimiento aprobada (CHG-%d)" % [hm(T - 8 + R(6)), u, 100 + R(900)],
			"%s %s conectó una memoria USB personal — autorizada por TI (EXC-%d)" % [hm(T - 15 + R(8)), u, 10 + R(90)],
			"%s %s: 3 fallos de inicio de sesión (4625) por contraseña vencida y luego acceso correcto" % [hm(T - 6), u]].pick_random()
		_add(inc, {"src": ["AD","EQ"].pick_random(), "decoy": [r], "text": txt})


func alert_text(n: Dictionary) -> String:
	var pc: Array = Game.st.pc
	match n.type:
		"trunk": return "NOC · Pérdida de enlace troncal Gi0/1 en SW-CORE: dc01, nas01 y vpn no responden."
		"usb": return "EDR · svch0st.exe lanzado desde unidad extraíble en %s (%s)." % [pc[n.v].name, X.ros[n.v].dept]
		"dns": return "SIEM · google.com resuelve a 185.220.101.77 en %s." % ", ".join(n.vs.map(func(k): return pc[k].name))
		_: return "NAS01 · Integridad: el job /backup/diario ya no existe. Último snapshot offsite: ayer 23:00."


func _plan(n: int) -> Array:
	var ty: Array = TYPES.keys(); ty.shuffle()
	var t0: int = max(Game.st.time + 90, 570)
	var span: int = max(200, 930 - t0)
	var out: Array = []
	for k in n:
		out.append({"t": t0 + int(floor(k * span / float(n))) + R(24), "type": ty[k % ty.size()]})
	return out


func _fire(s: Dictionary) -> void:
	var st: Dictionary = Game.st
	var inc := {"id": X.inc.size(), "type": s.type, "t": st.time, "dl": st.time + TYPES[s.type].mins, "st": "new", "imaged": 0, "esc": 0, "v": -1, "vs": [], "ff": -1, "ph": 1, "q": 0, "red": 0, "hash": "", "pr": {}}
	if inf().ctl.has(s.type):
		inc.dl += 45; inc.red = 1
	var idx: Array = range(st.pc.size()).filter(func(i): return i != X.C)
	if s.type == "trunk":
		X.trunk = inc.id; trunk_marker.emit(true)
	if s.type == "nas":
		X.nas = inc.id
	if s.type == "usb":
		var clean: Array = idx.filter(func(i): return not Game.av_issue(st.pc[i]))
		inc.v = (clean if clean.size() else idx).pick_random()
		var p: Dictionary = st.pc[inc.v]
		p.online = true
		p.procs.append({"n":"svch0st.exe","cpu":71,"mem":288,"mal":true})
		p.bad = p.files.size()
		p.files.append("update_flash.exe")
	if s.type == "dns":
		var sh := idx.duplicate(); sh.shuffle()
		inc.vs = sh.slice(0, 3)
		for i in inc.vs:
			var p: Dictionary = st.pc[i]
			p.online = true
			if not p.iss.has("dns"): p.iss.append("dns")
	X.inc.append(inc)
	_gen_clues(inc)
	Game.toast("🚨 " + alert_text(inc), 6500)
	Game.beep(220, .35, "sawtooth")
	var spk: String = ["Tomás","Mónica","Irene","Rafael","Sofía"].pick_random()
	var tshirt: String = X.ros[X.C].shirt if randf() < .6 else SPARE.pick_random()
	Game.chat.append({"n": spk, "t": Game.clock_str(), "x": "Vi a alguien con camisa %s apurado por el pasillo hace un rato…" % tshirt})


func _done(inc: Dictionary, msg: String) -> void:
	inc.st = "fixed"
	if X.trunk == inc.id:
		X.trunk = -1; trunk_marker.emit(false)
	if X.nas == inc.id: X.nas = -1
	inc.ph = 2
	pts("RS", 6)
	if inc.type == "nas": pts("RC", 8)
	if Game.st.time <= inc.dl: pts("DE", 3)
	Game.st.earn += 25
	Game.bump(2, 6, "✔ " + TYPES[inc.type].name + ": " + msg)


func _poll(inc: Dictionary) -> void:
	var pc: Array = Game.st.pc
	if inc.type == "usb" and not Game.av_issue(pc[inc.v]):
		_done(inc, "troyano eliminado")
	elif inc.type == "dns" and inc.vs.all(func(i): return not pc[i].iss.has("dns")):
		_done(inc, "DNS saneado")


var _busy := false
func tick() -> void:
	if X.is_empty() or not X.on or _busy or Game.st.get("over", false):
		return
	_busy = true
	while X.sched.size() and Game.st.time >= X.sched[0].t:
		_fire(X.sched.pop_front())
	for inc in X.inc:
		if inc.st == "fixed": continue
		_poll(inc)
		if inc.st != "fixed" and not inc.esc and Game.st.time > inc.dl:
			inc.esc = 1
			var T: Dictionary = TYPES[inc.type]
			pts("DE", -4)
			Game.bump(int(round(T.sat * (.5 if inc.red else 1.0))), int(round(T.sec * (.5 if inc.red else 1.0))), "⏰ Sin contener a tiempo: " + T.name + " escaló")
	_busy = false
	changed.emit()


func open_count() -> int:
	if X.is_empty() or not X.on: return 0
	return X.inc.filter(func(i): return i.st != "fixed").size()


func pill() -> String:
	if X.is_empty() or not X.on: return ""
	return "🛡️ Amenaza interna neutralizada" if X.caught else "🛡️ SOC · %d abiertas" % open_count()


# ---- interacción física: rack del data center ----
func rack_label() -> String:
	return "🔌 Reconectar el cable troncal del rack (E)" if X.get("on", false) and X.trunk >= 0 and not Game.st.over else ""


func rack_interact() -> void:
	if rack_label() == "": return
	var inc: Dictionary = X.inc[X.trunk]
	Game.adv(15)
	_done(inc, "cable reconectado en el rack")


# ---- comandos que revelan evidencia ----
func cmd(v: String, ctx):
	if X.is_empty() or not X.on: return null
	var p = Game.st.pc[ctx] if ctx is int else null
	var w := Array(v.strip_edges().split(" ", false))
	var c: String = (w[0] if w.size() else "").to_lower()
	var a := " ".join(w.slice(1)).to_lower()
	if c == "ping" and X.trunk >= 0 and w.size() > 1 and Data.HOSTS.has(str(w[1]).to_lower()):
		var h: String = str(w[1]).to_lower()
		return "Haciendo ping a %s [%s] con 32 bytes de datos:\n" % [w[1], Data.HOSTS[h][0]] + "Tiempo de espera agotado.\n".repeat(4) + "\nPaquetes: enviados=4, recibidos=0, perdidos=4 (100% perdidos)"
	if c == "doskey" and a.contains("/history"):
		if p == null: return "No hay historial en este equipo."
		var cs: Array = X.clues.filter(func(k): return k.vol and X.inc[k.inc].v == ctx)
		var ok: Array = cs.filter(func(k): return X.inc[k.inc].st != "fixed" or X.inc[k.inc].imaged)
		var lines: Array = ["ipconfig /all", "whoami", "ping google.com"]
		for k in ok:
			k.open = true
			lines += k.cmds
		return "\n".join(lines) + ("\n(historial purgado al contener el incidente sin captura forense)" if cs.size() and ok.is_empty() else "")
	if c == "reg" and a.contains("usbstor"):
		var hits: Array = X.clues.filter(func(k): return k.usb and k.pc == ctx) if p else []
		if hits.is_empty(): return "ERROR: el sistema no pudo encontrar la clave o el valor especificado."
		for k in hits: k.open = true
		return "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\USBSTOR\\Disk&Ven_Kingston&Prod_DataTraveler_3.0&Rev_PMAP\n    " + X.ser + "&0\n        FriendlyName    REG_SZ    Kingston DataTraveler 3.0 USB Device"
	if c == "nslookup" and p and a.contains("google.com") and X.inc.any(func(n): return n.type == "dns" and n.st != "fixed" and n.vs.has(ctx)):
		for k in X.clues:
			if k.src == "EQ" and not k.vol and X.inc[k.inc].type == "dns": k.open = true
		return "Servidor: dc01\nAddress: 192.168.10.10\n\nNombre: google.com\nAddress: 185.220.101.77"
	return null


func swlog() -> String:
	if X.is_empty() or not X.on: return ""
	var lines: Array = ["08:00 %SYS-5-RESTART: System restarted", "%s %%LINK-3-UPDOWN: Interface FastEthernet0/%d, changed state to up" % [hm(500 + R(60)), 1 + R(24)]]
	for c in X.clues:
		if c.src == "SW":
			c.open = true
			lines.append(c.text)
	lines.sort()
	return "\n".join(lines.map(func(l: String): return "*Jan 21 " + l.substr(0, 5) + ":00:" + l.substr(5)))


# ---- acciones de la pestaña SOC ----
func crc32(s: String) -> String:
	var c := 0xFFFFFFFF
	for x in s.to_utf8_buffer():
		c ^= x
		for k in 8:
			c = (c >> 1) ^ (0xEDB88320 & (-(c & 1) & 0xFFFFFFFF))
	return "%08X" % ((~c) & 0xFFFFFFFF)


func ext(src: String, id: int) -> void:
	var n: Dictionary = X.inc[id]
	Game.adv(10)
	for c in X.clues:
		if c.inc == n.id and c.src == src and (not c.vol or n.st != "fixed" or n.imaged): c.open = true
	if not n.pr.has(src):
		n.pr[src] = 1; pts("DE", 3)
	changed.emit()


func image(id: int) -> void:
	var n: Dictionary = X.inc[id]
	Game.adv(8)
	n.imaged = 1
	n.hash = crc32("|".join(X.clues.filter(func(c): return c.inc == n.id).map(func(c): return c.text)))
	pts("RS", 4)
	for c in X.clues:
		if c.inc == n.id and c.vol: c.open = true
	Game.toast("📷 Imagen forense creada · CRC32 " + n.hash + " (GDScript) · cadena de custodia")
	changed.emit()


func restore(id: int) -> void:
	Game.adv(30)
	_done(X.inc[id], "snapshot restaurado")
	changed.emit()


func pin(id: int) -> void:
	var k: int = X.pins.find(id)
	if k >= 0: X.pins.remove_at(k)
	elif X.pins.size() < 4: X.pins.append(id)
	else: Game.toast("Máximo 4 pruebas")
	changed.emit()


func buy_ctl(t: String) -> void:
	if inf().ctl.has(t): return
	if int(Game.G.money) < COST_CTL:
		Game.toast("Presupuesto insuficiente ($%d)" % COST_CTL); return
	Game.G.money = int(Game.G.money) - COST_CTL
	implement(t)
	changed.emit()


func view(v: String) -> void:
	X.view = v
	if v == "dir" and not X.idp:
		X.idp = 1; pts("ID", 3)
	changed.emit()


## Post-incidente: k = índice original de la opción (0 = correcta).
func post_answer(id: int, k: int) -> Dictionary:
	var n: Dictionary = X.inc[id]
	var t: String = n.type
	n.q = 1
	var res: Dictionary
	if k == 0:
		if not inf().ctl.has(t): implement(t)
		pts("GV", 4); Game.G.xp = int(Game.G.xp) + 15
		res = {"h": "✅ Causa raíz correcta", "p": "Implementaste %s sin costo adicional. %s" % [FW[t].ctl, TYPES[t].lesson]}
	else:
		res = {"h": "❌ Control inadecuado", "p": "La causa raíz se corrige con %s (%s)." % [FW[t].ctl, FW[t].iso], "buy": "" if inf().ctl.has(t) else t}
	Game.save(); Game.hud(); changed.emit()
	return res


# ---- SQL del SIEM ----
func sql(q: String) -> Dictionary:
	var rx := RegEx.create_from_string("(?i)^select\\s+(.+?)\\s+from\\s+logs(?:\\s+where\\s+(.+?))?(?:\\s+order\\s+by\\s+(\\w+)(?:\\s+(asc|desc))?)?(?:\\s+limit\\s+(\\d+))?$")
	var m := rx.search(q.strip_edges().trim_suffix(";"))
	if m == null: return {"err": "Sintaxis: SELECT cols FROM logs WHERE ... [ORDER BY col [DESC]] [LIMIT n]"}
	if m.get_string(2) == "": return {"err": "Se requiere WHERE: el SIEM no permite volcar toda la tabla."}
	var all := ["t","src","inc","type","text"]
	var cols: Array = all if m.get_string(1).strip_edges() == "*" else Array(m.get_string(1).split(",")).map(func(x): return x.strip_edges().to_lower())
	for c in cols:
		if not all.has(c): return {"err": "Columna desconocida: " + c}
	var conds: Array = []
	var crx := RegEx.create_from_string("(?i)^(\\w+)\\s*(=|!=|<|>|like)\\s*('([^']*)'|(\\d+))$")
	for c in RegEx.create_from_string("(?i)\\s+and\\s+").sub(m.get_string(2), "\u0001", true).split("\u0001"):
		var k := crx.search(c.strip_edges())
		if k == null or not all.has(k.get_string(1).to_lower()): return {"err": "Condición no válida: " + c}
		conds.append({"f": k.get_string(1).to_lower(), "o": k.get_string(2).to_lower(), "v": k.get_string(4) if k.get_string(3).begins_with("'") else k.get_string(5)})
	var rows: Array = []
	for c in X.clues:
		var n: Dictionary = X.inc[c.inc]
		if c.vol and n.st == "fixed" and not n.imaged: continue
		rows.append({"c": c, "t": hm(c.t), "src": c.src, "inc": str(c.inc + 1), "type": n.type, "text": c.text})
	rows = rows.filter(func(r): return conds.all(func(k): return _cond_ok(r, k)))
	if m.get_string(3) != "":
		var f := m.get_string(3).to_lower()
		if not all.has(f): return {"err": "Columna desconocida: " + f}
		var desc := m.get_string(4).to_lower() == "desc"
		rows.sort_custom(func(a, b): return (str(a[f]) > str(b[f])) if desc else (str(a[f]) < str(b[f])))
	var lim := mini(5, int(m.get_string(5)) if m.get_string(5) != "" else 5)
	rows = rows.slice(0, lim)
	for r in rows: r.c.open = true
	return {"cols": cols, "rows": rows}


func _cond_ok(r: Dictionary, k: Dictionary) -> bool:
	var x: String = str(r[k.f])
	var vv: String = str(k.v)
	match k.o:
		"=":
			return x.to_lower() == vv.to_lower()
		"!=":
			return x.to_lower() != vv.to_lower()
		"<":
			return x < vv
		">":
			return x > vv
	var pat := "(?i)^" + _rx_escape(vv).replace("%", ".*") + "$"
	return RegEx.create_from_string(pat).search(x) != null


func _rx_escape(s: String) -> String:
	var out := ""
	for ch in s:
		if ".*+?^${}()|[]\\".contains(ch): out += "\\" + ch
		else: out += ch
	return out


func run_query(q: String) -> void:
	X.qt = q; X.qe = ""; X.qr = []
	var r := sql(q)
	if r.has("err"):
		X.qe = r.err
	else:
		X.qc = r.cols; X.qr = r.rows
		if r.rows.size(): pts("DE", 2)
		Game.adv(6)
	changed.emit()


# ---- reunión de emergencia ----
func stmt(i: int) -> Dictionary:
	var al = null
	var clr = null
	for c in X.clues:
		if c.kind == "alibi" and c.open:
			if c.who.has(i) and al == null: al = c
			if not c.who.has(i) and clr == null: clr = c
	if i == X.C:
		return {"t": ['"Estuve en mi puesto toda la mañana, no me moví."', '"Yo ni sé configurar un switch."'].pick_random(),
			"n": ("⚠ Contradicción: AD marca su sesión bloqueada o sin actividad a las %s." % hm(al.t)) if al else "ℹ Aún no consultaste el estado de sesiones en AD."}
	if clr:
		return {"t": '"Mi sesión estaba activa, revisa el log de AD."', "n": "✔ Verificado: sesión activa en AD a las " + hm(clr.t)}
	return {"t": ['"Estaba en una reunión con un cliente."', '"Salí a almorzar y dejé el equipo bloqueado."', '"Estaba en el piso de Operaciones."'].pick_random(),
		"n": ("ℹ Su sesión estuvo bloqueada a las %s: coherente con su relato, pero no prueba nada." % hm(al.t)) if al else "ℹ No verificable con los datos actuales."}


func report() -> String:
	var s: Dictionary = X.ros[X.C]
	var t := "Informe forense final\n🕵️ %s (%s) · %s." % [s.name, s.dept, X.motive]
	for n in X.inc:
		t += "\n%s %s %s" % [TYPES[n.type].ico, hm(n.t), TYPES[n.type].name]
		if n.ff >= 0: t += " — falsa bandera: usó la cuenta de %s desde su propia estación" % X.ros[n.ff].u
		t += "\n   📘 " + TYPES[n.type].lesson + "\n   🏷 %s · %s · COBIT %s · ATT&CK %s" % [FW[n.type].nist, FW[n.type].iso, FW[n.type].cobit, FW[n.type].att]
	return t


func meet() -> void:
	X.meet = 1
	Game.adv(45)


func accuse(i: int) -> Dictionary:
	var pins: Array = X.pins.map(func(id): return X.clues[id])
	if pins.is_empty():
		Game.toast("El comité exige presentar al menos una prueba")
		return {}
	var f := pins.filter(func(c): return c.firm and c.who.has(i)).size()
	var w := pins.filter(func(c): return not c.firm and c.who.has(i)).size()
	var d := pins.filter(func(c): return c.decoy.has(i)).size()
	var g := 2 if (f >= 2 or (f and w)) else (1 if f + w else 0)
	var s: Dictionary = X.ros[i]
	var I := inf()
	var res: Dictionary
	var st: Dictionary = Game.st
	if i == X.C and g:
		X.caught = 1; X.sched = []; st.ad[i].off = true
		if g == 2:
			pts("GV", 8); Game.G.money = int(Game.G.money) + 250; Game.G.xp = int(Game.G.xp) + 40; st.earn += 60; I.w = int(I.w) + 1
			Game.bump(10, 15, "✔ Infiltrado neutralizado: " + s.name); Game.ach("inf")
			res = {"h": "✅ Infiltrado neutralizado", "p": "%s fue despedido y su acceso revocado. Las pruebas fueron sólidas: +$250 de presupuesto y la empresa recupera la confianza." % s.name}
		else:
			pts("GV", 3); Game.G.money = int(Game.G.money) + 100; Game.G.xp = int(Game.G.xp) + 15; I.w = int(I.w) + 1
			Game.bump(4, 8, "Infiltrado despedido con pruebas circunstanciales"); Game.ach("inf")
			res = {"h": "⚠ Acierto con pruebas débiles", "p": "%s era el infiltrado, pero tu evidencia era circunstancial: RR. HH. teme una impugnación. +$100." % s.name}
		res.r = report()
	elif i == X.C:
		Game.bump(-4, -4, "Acusación desestimada por falta de pruebas")
		res = {"h": "⚖️ Acusación desestimada", "p": "Las pruebas que presentaste no vinculan a esa persona con los incidentes. Sin evidencia pertinente el comité no puede actuar."}
	else:
		pts("GV", -10); Game.G.money = max(0, int(Game.G.money) - 200); I.l = int(I.l) + 1; st.ad[i].off = true; st.pc[i].online = false
		if st.time < 900:
			X.sched.append({"t": st.time + 35, "type": TYPES.keys().pick_random()})
			X.sched.append({"t": st.time + 85, "type": TYPES.keys().pick_random()})
			X.sched.sort_custom(func(a, b): return a.t < b.t)
		Game.bump(-20, -12, "✘ Despido improcedente de " + s.name)
		res = {"h": "❌ Acusación falsa", "p": "%s NO era el infiltrado. Pierdes $200 por la demanda laboral, el personal pierde confianza y el verdadero infiltrado sigue activo (más sabotajes en camino).%s" % [s.name, " Una de tus pruebas era una pista engañosa: coincidencia explicable o falsa bandera." if d else ""],
			"r": "La identidad del infiltrado se revelará al cierre de la jornada."}
	X.pins = []
	Game.save(); Game.hud(); changed.emit()
	return res


func end_day() -> String:
	if X.is_empty() or not X.on: return ""
	var s: Dictionary = X.ros[X.C]
	var I := inf()
	if not X.caught and X.inc.size():
		Game.st.sec = max(0, Game.st.sec - 8); I.n = int(I.n) + 1
	var t := " 🕵️ El infiltrado era %s (%s), %s. " % [s.name, s.dept, X.motive]
	t += "Fue neutralizado." if X.caught else ("Escapó sin ser identificado: −8 de seguridad." if X.inc.size() else "Hoy no alcanzó a actuar.")
	t += " Madurez NIST CSF 2.0 — " + " · ".join(FN.map(func(k): return k + " " + str(int(I.fw.get(k, 0))))) + "."
	X.on = false
	trunk_marker.emit(false)
	changed.emit()
	return t
