extends Node
## Estado y reglas del juego (port 1:1 de la lógica del HTML).

signal hud_changed
signal toast_requested(text: String, ms: int)
signal day_started
signal day_finished(res: Dictionary)
signal screens_changed
signal remote_changed(i: int)
signal call_ringing(i: int)
signal level_changed

const SAVE_PATH := "user://itg1.json"

var G := {}          # progreso persistente
var st := {}         # estado de la jornada
var tickets: Array = []
var onsite := 0
var at_home := false
var muted := false
var notes: Array = []  # notificaciones (toast) recientes

# Colisiones 2D del mundo (mismo sistema que el original):
var dk: Array = []   # obstáculos [x, z, medio_ancho, medio_fondo]
var wk: Array = []   # zonas caminables [x0, x1, z0, z1]

var sw: CiscoSwitch
var acts: Array = []
var br := {}          # estado del navegador por contexto
var chat: Array = []
var pre_finish: Array[Callable] = []   # devuelven texto extra para el resumen
var call_open := false
var _snd_cache := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	randomize()
	if "test=1" in OS.get_cmdline_user_args():
		seed(20261118)  # pruebas reproducibles: mismos tickets del día en cada corrida
	G = {"day":1,"money":100,"xp":0,"ups":{},"ach":{},"job":0,"eve":0,"sk":{},"sp":0,"lv":1,
		"parts":{"ram":1,"psu":1,"ssd":1,"fan":1,"cmos":2,"paste":3},"note":"","nt":{},"lvl":1}
	_load()
	sw = CiscoSwitch.new()
	acts = Data.ACT.duplicate(true)
	for p in Data.PCUSE.slice(3):
		acts.append({"x": p[0], "z": p[1], "r": 1.4, "pcuse": p[2]})
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)


# ---------------- Guardado ----------------
func _load() -> void:
	if "test=1" in OS.get_cmdline_user_args():
		return  # las pruebas automáticas arrancan siempre con progreso limpio
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for k in data:
			G[k] = data[k]
	G.day = int(G.day); G.money = int(G.money); G.xp = int(G.xp); G.job = int(G.job)
	G.sp = int(G.sp); G.lv = int(G.lv)


func save() -> void:
	if "test=1" in OS.get_cmdline_user_args():
		return  # y no tocan el guardado del jugador
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(G))


func reset_progress() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()
	_ready_reset()


func _ready_reset() -> void:
	G = {"day":1,"money":100,"xp":0,"ups":{},"ach":{},"job":0,"eve":0,"sk":{},"sp":0,"lv":1,
		"parts":{"ram":1,"psu":1,"ssd":1,"fan":1,"cmos":2,"paste":3},"note":"","nt":{}}
	dk.clear(); wk.clear(); at_home = false; onsite = 0


# ---------------- Utilidades ----------------
func ups(k: String) -> bool:
	return G.ups.has(k) and G.ups[k]

func sk(k: String) -> int:
	return int(G.sk.get(k, 0))

func lvl() -> int:
	return int(floor(G.xp / 120.0)) + 1

func ri() -> int:
	var r := 0
	for i in Data.TH.size():
		if G.xp >= Data.TH[i]:
			r = i
	return r

func rank() -> String:
	return Data.RANKS[ri()]

func hhmm(n: int) -> String:
	return "%02d:%02d" % [n / 60, n % 60]

func fmt() -> String:
	return "21/01/2025  " + hhmm(st.time)

func clock_str() -> String:
	return hhmm(st.time)

func sla_dl(k: Dictionary) -> int:
	return [960, 780, 660][k.p - 1]

func sla_txt(i: int) -> String:
	if st.state[i] != null:
		return ""
	var dl := sla_dl(tickets[i])
	return " · SLA vencido" if st.time > dl else " · SLA " + hhmm(dl)

func pending_count() -> int:
	return st.state.count(null)

func alerts() -> int:
	if not st.has("ev"):
		return 0
	var soc := 0
	var s = get_node_or_null("/root/Soc")
	if s: soc = s.open_count()
	return st.ev.filter(func(e): return e.fired and not e.done).size() + soc

func pending_at(loc) -> bool:
	if loc == null:
		return false
	if st.has("bios") and st.bios.loc == loc and not st.bios.done:
		return true
	for i in tickets.size():
		if tickets[i].loc == loc and st.state[i] == null:
			return true
	return false

func clampi100(v: int) -> int:
	return clampi(v, 0, 100)


func toast(t: String, ms := 3200) -> void:
	notes.push_front({"t": t, "h": clock_str() if st.has("time") else ""})
	if notes.size() > 20:
		notes.pop_back()
	toast_requested.emit(t, ms)


func ach(k: String) -> void:
	if G.ach.has(k) and G.ach[k]:
		return
	G.ach[k] = 1
	save()
	toast("🏆 Logro: " + Data.ACH[k])
	beep(990, .2)


func bump(a: int, b: int, m: String) -> void:
	st.sat = clampi100(st.sat + a)
	st.sec = clampi100(st.sec + b)
	hud()
	toast(m)


func adv(m: int) -> void:
	st.time += m
	hud()
	screens_changed.emit()
	if st.time >= Data.END:
		finish()


func hud() -> void:
	lv_check()
	ev_check()
	hud_changed.emit()


func lv_check() -> void:
	var L := lvl()
	if L > int(G.lv):
		G.sp = int(G.sp) + L - int(G.lv)
		G.lv = L
		save()
		toast("⭐ ¡Nivel %d! +1 punto de habilidad" % L)
		beep(990, .2)
		if L >= 5:
			ach("lv5")


# ---------------- Jornada ----------------
func new_day() -> void:
	G.comm = {}   # misiones comunitarias: se pueden repetir cada día
	st = {"over":false,"cur":-1,"done":0,"net":0,"time":480,"sec":50,"earn":0,
		"slaB":0,"slaK":0,"cs":[],"rep":0}
	var nt: Dictionary = G.get("nt", {})
	st.sat = 50 + (10 if ups("coffee") else 0) + int(nt.get("cook", 0)) * 5 + int(nt.get("tv", 0)) * 5
	G.eve = 0
	# Selección de 8 tickets: siempre uno de la copiadora + 7 al azar
	var all: Array = []
	for k in Data.POOL:
		var d: Dictionary = k.duplicate(true)
		d.from0 = d.from
		all.append(d)
	all.shuffle()
	var cp = null
	for k in all:
		if k.has("copy"):
			cp = k
			break
	var sel: Array = [cp]
	for k in all:
		if not k.has("copy"):
			sel.append(k)
	tickets = sel.slice(0, 8)
	tickets.shuffle()
	for k in tickets:
		k.loc = 5 if k.has("copy") else 0
	var rx := RegEx.create_from_string("Seguridad|\\bTI\\b|Teletrabajo|Soporte|Mesa")
	var cand: Array = tickets.filter(func(k): return not k.has("copy") and rx.search(k.from0) == null)
	var pool: Array = (cand if cand.size() >= 3 else tickets).duplicate()
	pool.shuffle()
	for n in 3:
		var l := n + 1
		pool[n].loc = l
		pool[n].from = Data.STN[l].name + " · " + Data.STN[l].dept
	var wn: Array = Data.WN.duplicate()
	wn.shuffle()
	var drx := RegEx.create_from_string("^.*\\((.*)\\)$")
	for n in 2:
		if 3 + n >= pool.size():
			break
		var k: Dictionary = pool[3 + n]
		if k.loc:
			continue
		k.loc = 4
		k.who = wn[n]
		k.col = Data.SEEK_COL[randi() % 6]
		var m := drx.search(k.from0)
		k.from = k.who + " · " + (m.get_string(1) if m else k.from0)
	st.state = []
	st.state.resize(tickets.size())
	st.state.fill(null)
	_new_day_office()
	onsite = 0
	hud()
	screens_changed.emit()
	day_started.emit()
	toast("Bienvenido a CAA Corp. Los usuarios te buscarán para pedir ayuda; también puedes visitar RRHH, Copiado, Contabilidad, Ventas, Operaciones y Gerencia." if int(G.day) == 1 else "Día %d en una nueva sucursal. ¡Suerte!" % int(G.day), 5000)


func resolve(i: int, j: int) -> Dictionary:
	var o: Array = tickets[i].o[j]
	st.state[i] = j
	st.done += 1
	var a: int = o[1]
	var b: int = o[2]
	st.sat = clampi100(st.sat + a + (sk("comm") if a > 0 else 0))
	st.sec = clampi100(st.sec + b + ((2 if ups("sec") else 0) + sk("hard") if b > 0 else 0))
	var dl := sla_dl(tickets[i])
	if st.time > dl:
		st.slaB += 1
		st.sat = max(0, st.sat - 4)
		toast("⏰ SLA incumplido: −4 de satisfacción")
	else:
		st.slaK += 1
	st.time += max(10, (20 if ups("chair") else 25) - sk("time") * 2)
	st.earn += 30 if a + b >= 8 else (15 if a + b >= 0 else 0)
	ach("first")
	beep(880 if a + b >= 0 else 180, .15)
	hud()
	screens_changed.emit()
	var sc2 := a + b
	var stars := 5 if sc2 >= 12 else (4 if sc2 >= 6 else (3 if sc2 >= 0 else (2 if sc2 >= -8 else 1)))
	st.cs.append(stars)
	return {"text": o[3], "stars": stars, "sat": a, "sec": b, "good": sc2 >= 8}


func finish() -> void:
	if st.over:
		return
	st.over = true
	var pnd := pending_count()
	var down := alerts()
	st.sat = max(0, st.sat - pnd * 5)
	var inv_open: bool = st.has("inv") and not st.inv.done
	st.sec = max(0, st.sec - down * 5 - (8 if inv_open else 0))
	var extra := ""
	for h in pre_finish:
		extra += str(h.call())
	var t: float = (st.sat + st.sec) / 2.0
	var bonus := 100 if t >= 80 else (40 if t >= 60 else 0)
	var pay := int(round(max(0, 100 + st.earn + bonus - down * 30 - pnd * 20) * float(Data.JB[int(G.job)][3])))
	var xp := int(round(t + st.done * 5 + st.net * 10))
	var r0 := rank()
	G.money = max(0, int(G.money) + pay - Data.COST)
	G.xp = int(G.xp) + xp
	if st.done:
		ach("first")
	if t >= 85:
		ach("perfect")
	if int(G.day) >= 5:
		ach("week")
	save()
	var r1 := rank()
	hud()
	var title := "Analista estrella" if t >= 80 else ("Buen desempeño" if t >= 60 else ("Necesitas práctica" if t >= 40 else "Día para el olvido"))
	var txt := "Día %d: %d/%d tickets, %d/3 trabajos de red. Satisfacción %d · Seguridad %d. Cobras $%d (+%d XP). Saldo: $%d." % [int(G.day), st.done, tickets.size(), st.net, st.sat, st.sec, pay, xp, int(G.money)]
	txt += (" ¡Ascenso a %s!" % r1) if r1 != r0 else (" Rango: %s." % r1)
	if pnd: txt += " Tickets sin atender: %d." % pnd
	if down: txt += " Alertas sin resolver: %d." % down
	if inv_open: txt += " Ataque sin investigar."
	txt += " Gastos de vida: $%d. SLA cumplidos: %d/%d." % [Data.COST, st.slaK, st.slaK + st.slaB]
	if st.rep: txt += " Reparaciones: %d." % st.rep
	txt += extra
	txt += _level_check()
	if st.cs.size():
		var s := 0.0
		for v in st.cs: s += v
		txt += " Valoración media: %.1f★." % (s / st.cs.size())
	var achs: Array = []
	for k in Data.ACH:
		achs.append(("🏆 " if G.ach.has(k) else "🔒 ") + Data.ACH[k])
	day_finished.emit({"title": title, "text": txt, "ach": "  ·  ".join(achs)})


func go_home() -> void:
	at_home = true
	G.nt = {"study":0,"cook":0,"tv":0}
	toast("Llegaste a casa. Estudia, cocina, mira TV y duerme para empezar un nuevo día.", 5000)


func home_label_ok(k: String) -> bool:
	if not at_home:
		return false
	return k == "sleep" or not int(G.nt.get(k, 0))


func home_act(k: String) -> void:
	match k:
		"study":
			G.nt.study = 1; G.xp = int(G.xp) + 25; toast("Estudiaste para tu certificación: +25 XP"); beep(880, .1)
		"cook":
			G.nt.cook = 1; G.money = max(0, int(G.money) - 5); toast("Cocinaste una buena cena: +5 de satisfacción mañana (−$5)")
		"tv":
			G.nt.tv = 1; toast("Un rato de TV para despejarte: +5 de satisfacción mañana")
		_:
			at_home = false
			G.day = int(G.day) + 1
			save()
			new_day()
	hud()


# ================== FASE 2: oficina, apps y escritorio remoto ==================
func rn(n: int) -> int:
	return randi() % n

func pad2(n: int) -> String:
	return "%02d" % n


func _new_day_office() -> void:
	var U: Array = Data.USERS
	var ids: Array = range(U.size()); ids.shuffle()
	st.ad = []
	for i in U.size(): st.ad.append({"lock":false,"off":false,"ex":false})
	st.ad[ids[0]].lock = true; st.ad[ids[1]].lock = true; st.ad[ids[2]].ex = true
	st.adt = []
	for p in [[ids[0],"unlock"],[ids[1],"unlock"],[ids[2],"disable"]]:
		st.adt.append({"u":p[0],"k":p[1],"done":false,"txt":("Desbloquear la cuenta de " if p[1] == "unlock" else "Deshabilitar la cuenta del ex empleado ") + U[p[0]][1]})
	var mt: Array = Data.MT.duplicate(); mt.shuffle()
	st.mail = []
	for m in mt.slice(0, 5): st.mail.append({"m": m, "a": null})
	st.rma = {}
	st.vid = {}
	br.clear()
	st.pc = []
	for i in U.size(): st.pc.append(mk_pc(U[i], i))
	for i in U.size(): st.pc[i].online = tk_for(i) >= 0 or randf() < .8
	st.mfa = 0
	st.bios = {"loc": 1 + rn(3), "done": false, "page": "Main", "cfg": {"boot":"USB Drive","sb":"Disabled","tpm":"Disabled"}}
	# registro de seguridad con un ataque de fuerza bruta
	var atk := "185.220.101.%d" % (10 + rn(80))
	var au: String = U[rn(8)][0]
	var L: Array = []
	var BN := [[4624,"Auditoría correcta"],[4672,"Información"],[7036,"Información"],[4625,"Auditoría de errores"]]
	for i in 5: L.append({"t":"03:12:" + pad2(i * 2 + 1),"lv":"Auditoría de errores","id":4625,"u":au,"ip":atk})
	L.append({"t":"03:12:14","lv":"Auditoría correcta","id":4624,"u":au,"ip":atk})
	for i in 9:
		var b: Array = BN[rn(3 if i < 2 else 4)]
		L.append({"t":"%s:%s:%s" % [pad2(7 + rn(9)), pad2(rn(60)), pad2(rn(60))],"lv":b[1],"id":b[0],"u":U[rn(8)][0],"ip":"10.0.0.%d" % (10 + rn(40))})
	L.sort_custom(func(a, b): return a.t < b.t)
	st.evl = L
	st.inv = {"ip": atk, "done": false}
	var dv: Array = range(Data.DEV.size()); dv.shuffle()
	st.dev = []
	for i in Data.DEV.size(): st.dev.append("ok")
	st.ev = []
	for i in 3: st.ev.append({"t": 540 + i * 120 + rn(60), "d": dv[i], "fired": false, "done": false})
	st.rep = 0; st.rma = {}; st.bn = {"tab":"ord","o":0}
	var fi: Array = range(Data.FAULTS.size()).filter(func(i): return int(G.day) >= 2 or Data.FAULTS[i].c != "gpu")
	fi.shuffle()
	var ux: Array = range(U.size()); ux.shuffle()
	var ci: Array = range(Data.CALLS.size()); ci.shuffle()
	st.rq = []
	for k in (3 if int(G.day) >= 3 else 2):
		st.rq.append({"f": fi[k], "own": U[ux[k]][1], "mod": Data.MODELS[rn(4)], "fixed": false, "sel": "", "log": [], "inst": {}, "out": []})
	st.calls = []
	for k in 3: st.calls.append({"t": 570 + k * 170 + rn(40), "fired": false, "i": ci[k]})
	call_open = false
	chat = [{"n":"Sistema","t":"08:00","x":"Canal #oficina · CAA Corp · Día %d" % int(G.day)}]


func ev_check() -> void:
	if not st.has("ev"):
		return
	for e in st.ev:
		if not e.fired and st.time >= e.t:
			e.fired = true
			st.dev[e.d] = "down"
			toast("⚠ ALERTA: " + Data.DEV[e.d][0] + " sin respuesta")
			beep(220, .3, "sawtooth")
	if st.has("calls") and not call_open and not st.over:
		for c in st.calls:
			if not c.fired and st.time >= c.t:
				c.fired = true
				call_open = true
				beep(520, .2); beep(660, .2)
				call_ringing.emit(c.i)
				break
	var s = get_node_or_null("/root/Soc")
	if s: s.tick()


# ---- Active Directory ----
func ad_act(i: int, a: String) -> void:
	var u: Dictionary = st.ad[i]
	var n: String = Data.USERS[i][1]
	match a:
		"unlock":
			if not u.lock:
				toast(n + " no estaba bloqueada"); return
			u.lock = false; bump(1, 1, "Cuenta de " + n + " desbloqueada"); adv(10)
		"reset":
			if u.ex: bump(0, -6, "Restableciste la clave de un ex empleado: riesgo de acceso indebido")
			else: toast("Clave temporal enviada a " + n + " por canal verificado")
			adv(5)
		"off":
			u.off = true
			if u.ex: bump(0, 6, n + " deshabilitado")
			else: bump(-10, 0, "¡Deshabilitaste a un empleado activo!")
			adv(10)
		"on":
			u.off = false; toast("Cuenta habilitada de nuevo"); adv(5)
	for t in st.adt:
		if t.u == i and not t.done and ((t.k == "unlock" and not u.lock) or (t.k == "disable" and u.off)):
			t.done = true; st.earn += 20; beep(880, .1)
			if st.adt.all(func(x): return x.done): ach("ad")
			break


# ---- Correo / phishing ----
func mail_act(i: int, v: String) -> void:
	var x: Dictionary = st.mail[i]
	if x.a != null: return
	x.a = v == "p"
	if x.a == x.m[3]:
		bump(0, 3, "✔ Correcto"); st.earn += 5
	elif x.m[3]:
		bump(0, -8, "✘ Era phishing: un usuario podría hacer clic")
	else:
		bump(-3, 0, "✘ Era legítimo: bloqueaste un correo válido")
	adv(5)
	if st.mail.all(func(y): return y.a == y.m[3]): ach("mail")


# ---- Monitor de red ----
func mon_act(i: int, a: int) -> void:
	var e = null
	for x in st.ev:
		if x.d == i and x.fired and not x.done: e = x; break
	if e == null: return
	if a == Data.DEV[i][2]:
		e.done = true; st.dev[i] = "ok"; st.earn += 25; bump(0, 5, "✔ " + Data.DEV[i][0] + " restablecido")
	else:
		bump(-3, 0, "Esa acción no resolvió el problema")
	adv(15)


# ---- Tienda, empleos, habilidades ----
func buy(k: String) -> void:
	var s = null
	for x in Data.SHOP:
		if x[0] == k: s = x
	if s == null or ups(k): return
	if int(G.money) < s[3]:
		toast("Saldo insuficiente"); return
	G.money = int(G.money) - s[3]; G.ups[k] = 1; save(); ach("shop"); hud(); toast("Compraste: " + s[1])


func job_act(i: int) -> void:
	G.job = i; save(); hud(); toast("¡Nuevo puesto: " + Data.JB[i][0] + "!"); beep(990, .2)


func sk_act(k: String) -> void:
	var s = null
	for x in Data.SK:
		if x[0] == k: s = x
	var v := sk(k)
	if s == null or v >= s[3]: return
	if int(G.sp) < v + 1:
		toast("Puntos insuficientes"); return
	G.sp = int(G.sp) - (v + 1); G.sk[k] = v + 1; save(); toast("⭐ %s nivel %d" % [s[1], v + 1])


# ---- Visor de eventos ----
func ev_act(i: int) -> void:
	var e: Dictionary = st.evl[i]
	if st.inv.done: return
	if e.ip == st.inv.ip:
		st.inv.done = true; st.earn += 40; bump(2, 10, "✔ IP atacante " + e.ip + " bloqueada; fuerza bruta detenida"); ach("soc")
	else:
		bump(-10, -2, "Bloqueaste una IP interna legítima: " + e.ip)
	adv(10)


# ---- MFA (TOTP de 15 s como el original) ----
func mfa_code(o := 0) -> String:
	var slot := int(floor(Time.get_unix_time_from_system() / 15.0)) - o
	var h := (slot * 2654435761) & 0xffffffff
	return str(100000 + h % 900000)


func mfa_act(v: String) -> void:
	if st.mfa >= 3:
		toast("No hay más inicios pendientes"); return
	if v.strip_edges() == mfa_code(0) or v.strip_edges() == mfa_code(1):
		st.mfa += 1; st.earn += 10; bump(1, 3, "✔ Acceso verificado con MFA"); adv(5)
	else:
		bump(0, -3, "✘ Código incorrecto o caducado")


# ---- BIOS ----
func bios_act(x: String, y: String) -> void:
	var b: Dictionary = st.bios
	if b.done: return
	if x == "p":
		b.page = y
	elif x == "t":
		var o: Array = {"boot":["USB Drive","Network","SSD"],"sb":["Disabled","Enabled"],"tpm":["Disabled","Enabled"]}[y]
		b.cfg[y] = o[(o.find(b.cfg[y]) + 1) % o.size()]
	elif x == "s":
		if y == "1":
			var c: Dictionary = b.cfg
			if c.boot == "SSD" and c.sb == "Enabled" and c.tpm == "Enabled":
				b.done = true; st.earn += 40; bump(8, 8, "✔ La PC arrancó con Secure Boot y TPM activos"); ach("bios"); adv(20)
			else:
				bump(-3, 0, "La PC sigue sin arrancar: revisa Boot, Secure Boot y TPM"); adv(10)
		else:
			b.cfg = {"boot":"USB Drive","sb":"Disabled","tpm":"Disabled"}; toast("Cambios descartados")


# ---- PCs de los usuarios ----
func mk_mail(i: int) -> Array:
	var u: Array = Data.USERS[i]
	var fn: String = u[1].split(" ")[0]
	var r: Array = [{"f":"general","n":"Mailer Turles (RRHH)","a":"mailer.turles@caacorp.com.pa","s":"Recordatorio: capacitación de seguridad","b":"Hola %s:\nSoy Mailer, del departamento de Recursos Humanos. Recuerda completar la capacitación de seguridad de este mes. Los procedimientos internos están en la wiki; para entrar debes conectarte por la VPN [b]CAA OneConnect[/b].\nSaludos cordiales." % fn,"att":"guia_seguridad.pdf"}]
	var mt: Array = Data.MT.duplicate(); mt.shuffle()
	for m in mt.slice(0, 4):
		r.append({"f":"spam" if m[3] else ("important" if randf() < .4 else "general"),"n":m[0].split("@")[0],"a":m[0],"s":m[1],"b":m[2],"att":""})
	r.append({"f":"task","n":"Gerencia","a":"gerencia@caacorp.com.pa","s":"Cierre de trimestre","b":"Recuerda entregar tu reporte antes del viernes.","att":""})
	r.append({"f":"jobs","n":"Reclutamiento","a":"jobs@talento.pa","s":"Oferta: Analista de datos","b":"Tenemos una vacante que podría interesarte.","att":""})
	return r


func mk_pc(u: Array, i: int) -> Dictionary:
	var p := {"id": 100000000 + rn(899999999), "name": "PC_" + u[2].to_upper() + "_%d" % (i % 3 + 1), "ip": "192.168.10.%d" % (101 + i),
		"online": true, "mf": "general", "mm": -1, "addr": u[0] + "@caacorp.com.pa", "vpn": false, "tube": randf() < .35, "bad": -1, "note": "", "cmd": ""}
	p.files = ["Informe_mensual.xlsx", "Presentacion_equipo.pptx", "foto_oficina.jpg", "Contrato_borrador.docx"]
	if randf() < .45:
		p.bad = rn(5)
		p.files.insert(p.bad, ["crack_office_2021.exe", "factura_urgente.pdf.exe", "keygen_antivirus.zip"][rn(3)])
	p.procs = []
	for q in [["explorer.exe",2,95],["chrome.exe",6,480],["outlook.exe",3,210],["teams.exe",4,320],["lsass.exe",1,40],["csrss.exe",0,12]]:
		p.procs.append({"n": q[0], "cpu": q[1], "mem": q[2]})
	if randf() < .5: p.procs.append({"n":"excel.exe","cpu":97,"mem":1210,"frozen":true})
	if randf() < .35: p.procs.append({"n":"svch0st.exe","cpu":64,"mem":310,"mal":true})
	p.iss = ["dns","spooler","temp","gpo"].filter(func(_k): return randf() < .25)
	p.mail = mk_mail(i)
	return p


func tk_for(i: int) -> int:
	var nm: String = Data.USERS[i][1].split(" ")[0]
	for j in tickets.size():
		var k: Dictionary = tickets[j]
		if st.state[j] == null and ((k.loc >= 1 and k.loc <= 3 and Data.STN[k.loc].name == nm) or (k.loc == 4 and k.get("who", "") == nm)):
			return j
	return -1


func av_issue(p: Dictionary) -> bool:
	return p.procs.any(func(x): return x.get("mal", false)) or p.bad >= 0


func symptoms(p: Dictionary) -> Array:
	var r: Array = p.iss.map(func(k): return Data.SYM[k])
	if p.procs.any(func(x): return x.get("frozen", false)): r.append("Un programa no responde y consume el 97% de CPU")
	if av_issue(p): r.append("El antivirus reporta actividad sospechosa")
	return r


func fix_issue(i: int, key: String) -> bool:
	var p: Dictionary = st.pc[i]
	if key == "av":
		if not av_issue(p): return false
		p.procs = p.procs.filter(func(x): return not x.get("mal", false))
		if p.bad >= 0:
			p.files.remove_at(p.bad); p.bad = -1
	else:
		var k: int = p.iss.find(key)
		if k < 0: return false
		p.iss.remove_at(k)
	st.earn += 15
	bump(2, 8 if key == "av" else 3, "✔ " + p.name + ": " + Data.SYM.get(key, "amenaza eliminada") + " — resuelto")
	ach("remoto")
	adv(3 if sk("ps") else 5)
	remote_changed.emit(i)
	return true


func run_script(i: int, key: String) -> void:
	var s = null
	for x in Data.SCRIPTS:
		if x[2] == key: s = x
	if not fix_issue(i, key):
		toast("Sin cambios: " + s[0] + " no encontró ese problema en " + st.pc[i].name)
		adv(3)


func kill_proc(i: int, nm: String) -> String:
	var p: Dictionary = st.pc[i]
	var k := -1
	for j in p.procs.size():
		if p.procs[j].n.to_lower() == nm.to_lower(): k = j; break
	if k < 0: return 'ERROR: no se encontró el proceso "%s".' % nm
	var x: Dictionary = p.procs[k]
	if x.n.to_lower() in ["lsass.exe", "csrss.exe", "winlogon.exe"]:
		bump(-15, -2, "💥 Cerraste un proceso crítico: el equipo se reinició"); adv(10)
		return 'ÉXITO: se terminó "%s". ¡El equipo se reinició por un fallo crítico!' % x.n
	p.procs.remove_at(k)
	if x.get("frozen", false):
		st.earn += 15; bump(3, 2, "✔ Proceso congelado cerrado: " + x.n); ach("remoto")
	elif x.get("mal", false):
		st.earn += 20; bump(0, 8, "✔ Proceso malicioso eliminado: " + x.n); ach("remoto")
	else:
		bump(-2, 0, "El usuario perdió trabajo sin guardar (" + x.n + ")")
	adv(3)
	remote_changed.emit(i)
	return 'ÉXITO: se terminó el proceso "%s".' % x.n


## Símbolo del sistema (cmdExec del original). ctx = "me" o índice de usuario.
func cmd_exec(v: String, ctx) -> String:
	var hook = get_node("/root/Soc").cmd(v, ctx)
	if hook != null:
		return hook
	var p = st.pc[ctx] if ctx is int else null
	var ip: String = p.ip if p else "192.168.10.55"
	var w := Array(v.strip_edges().split(" ", false))
	var c: String = (w[0] if w.size() else "").to_lower()
	var a := " ".join(w.slice(1)).to_lower()
	var me: bool = p == null
	var P: Array = p.procs if p else Data.LOCALPROCS
	match c:
		"help":
			return "Comandos: help, cls, ipconfig [/flushdns], ping <host>, nslookup <host>, whoami, hostname, netstat, tasklist, taskkill /im <proceso>, net stop|start spooler, gpupdate /force, cleanmgr, ver\nHosts: dc01, zoho.local, nas01, vpn.caacorp.com, firewall, google.com o una IP"
		"cls":
			return "\f"
		"ipconfig":
			if a.contains("/flushdns"):
				if p: fix_issue(ctx, "dns")
				return "Se vació correctamente la caché de resolución de DNS."
			return "Adaptador Ethernet:\n   Dirección IPv4. . . . : %s\n   Máscara de subred . . : 255.255.255.0\n   Puerta de enlace . . : 192.168.10.1" % ip
		"whoami":
			return "caacorp\\soporte" if me else "caacorp\\" + Data.USERS[ctx][0]
		"hostname":
			return "PC-SOPORTE01" if me else p.name
		"ver":
			return "Microsoft Windows [Versión 10.0.19045]"
		"netstat":
			return "  Proto  Local                 Remoto                Estado\n  TCP    %s:50321   192.168.10.20:443     ESTABLISHED\n  TCP    %s:50788   192.168.10.10:389     ESTABLISHED" % [ip, ip]
		"tasklist":
			var t := "Nombre de imagen         PID   CPU   Memoria\n" + "=".repeat(48)
			for k in P.size():
				var x: Dictionary = P[k]
				t += "\n" + str(x.n).rpad(24) + str(1000 + k * 37).rpad(6) + (str(x.cpu) + "%").rpad(6) + str(x.mem) + " MB" + ("  (No responde)" if x.get("frozen", false) else "")
			return t
		"taskkill":
			var m := RegEx.create_from_string("/im\\s+(\\S+)").search(a)
			if m == null: return "Uso: taskkill /f /im <proceso.exe>"
			if me: return "ERROR: Acceso denegado en este equipo."
			return kill_proc(ctx, m.get_string(1))
		"net":
			var m := RegEx.create_from_string("^(stop|start)\\s+spooler").search(a)
			if m == null: return "Uso: net stop|start spooler"
			if p and m.get_string(1) == "start": fix_issue(ctx, "spooler")
			return "El servicio Cola de impresión se %s correctamente." % ("detuvo" if m.get_string(1) == "stop" else "inició")
		"gpupdate":
			if p: fix_issue(ctx, "gpo")
			return "Actualizando directivas...\nLa actualización de la directiva de equipo se completó correctamente."
		"cleanmgr", "del":
			if p: fix_issue(ctx, "temp")
			return "Se liberaron 4.2 GB de archivos temporales."
		"nslookup", "ping":
			var h: String = (w[1] if w.size() > 1 else "").to_lower()
			if h == "": return "Uso: " + c + " <host>"
			var e = Data.HOSTS.get(h)
			var is_ip := RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+\\.\\d+$").search(h) != null
			var ipx = e[0] if e else (h if is_ip else null)
			var no_dns: bool = p != null and p.iss.has("dns") and not is_ip
			if ipx == null or no_dns:
				return ("La solicitud de ping no pudo encontrar el host " + h + ". Compruebe el nombre e intente nuevamente.") if c == "ping" else "*** No se encontró " + h + ": Server failed"
			if c == "nslookup":
				return "Servidor: dc01\nAddress: 192.168.10.10\n\nNombre: %s\nAddress: %s" % [h, ipx]
			var dn: bool = e != null and e[1] >= 0 and st.dev[e[1]] == "down"
			var sv := false
			for n in sw.SW.svi:
				if sw.SW.svi[n].ip == ipx and not sw.SW.svi[n].shut: sv = true
			var ok: bool = not dn and (e != null or sv)
			var t := "Haciendo ping a %s [%s] con 32 bytes de datos:\n" % [h, ipx]
			if ok:
				for k in 4: t += "Respuesta desde %s: bytes=32 tiempo=%dms TTL=64\n" % [ipx, 1 + rn(8)]
				t += "\nPaquetes: enviados=4, recibidos=4, perdidos=0 (0% perdidos)"
			else:
				for k in 4: t += "Tiempo de espera agotado.\n"
				t += "\nPaquetes: enviados=4, recibidos=0, perdidos=4 (100% perdidos)"
			return t
	return ("'%s' no se reconoce como un comando interno o externo." % c) if c != "" else ""


func vid_reward(i: int) -> void:
	var key := "v%d" % i
	if st.vid.has(key): return
	st.vid[key] = 1
	var k: int = Data.VIDS[i][3]
	if k == 0:
		G.xp = int(G.xp) + 5; toast("📚 Capacitación completada: +5 XP"); beep(880, .1); adv(5)
	elif k == 1:
		bump(2, 0, "☕ Un descanso: +2 de satisfacción"); adv(5)


func guide_read(i: int) -> void:
	var key := "g%d" % i
	if st.vid.has(key): return
	st.vid[key] = 1
	G.xp = int(G.xp) + 3; toast("📘 Guía leída: +3 XP"); adv(3)


# ================== FASE 3 ==================
func call_answer(i: int, k: int) -> void:
	var o: Array = Data.CALLS[i][2][k]
	call_open = false
	G.xp = int(G.xp) + o[3]
	bump(o[1], o[2], o[4])
	adv(3)
	if o[3]: ach("call")


func price(k: String) -> int:
	return int(round(Data.PARTS[k][1] * (1 - .1 * sk("inv"))))


func comp_name(k: String) -> String:
	for c in Data.COMP:
		if c[0] == k: return c[1]
	return k


## Taller de reparación (bnAct del original). Devuelve el componente reemplazado o "".
func bn_act(v: String) -> String:
	var b: Dictionary = st.bn
	var p := v.split(":")
	var k := p[0]
	var x := p[1] if p.size() > 1 else ""
	var o = st.rq[b.o] if b.o < st.rq.size() else null
	var f = Data.FAULTS[o.f] if o else null
	match k:
		"tab": b.tab = x
		"open": b.o = int(x); b.tab = "bench"
		"sel":
			if o and not o.fixed: o.sel = x
		"test":
			if o == null or o.sel == "" or o.fixed: return ""
			var ap = Data.TAP.get(x)
			var txt := ""
			var ok := true
			if x == "post" and o.sel == "mb":
				txt = ("⚠ " + f.r.post) if f.r.has("post") else Data.NORM.post
			elif ap != null and not ap.has(o.sel):
				txt = "Esta prueba no aplica a este componente."; ok = false
			elif o.sel == f.c and f.r.has(x):
				txt = "⚠ " + f.r[x]
			else:
				txt = Data.NORM[x]
			var tn := ""
			for t in Data.TOOLS:
				if t[0] == x: tn = t[1]
			o.log.append(comp_name(o.sel) + " · " + tn + ": " + txt)
			if ok: adv(0 if sk("diag") >= 2 else 2)
		"rep":
			if o == null or o.sel == "" or o.fixed:
				toast("Selecciona el componente a reemplazar"); return ""
			if int(G.parts.get(x, 0)) < 1:
				toast("No tienes esa pieza en stock"); return ""
			G.parts[x] = int(G.parts[x]) - 1; save()
			var sel: String = o.sel
			o.inst[sel] = 1; o.out.append(sel)
			if o.sel == f.c and x == f.p:
				o.fixed = true; st.rep += 1; st.earn += 40 + sk("diag") * 5; G.xp = int(G.xp) + 10
				bump(6, 2, "✔ Reparación completada: la PC de " + o.own + " arrancó correctamente"); ach("rep"); adv(20); beep(880, .2)
			else:
				bump(-3, 0, "Esa pieza no resolvió el problema (se desperdició)"); adv(10)
			return sel
		"buy":
			if int(G.money) < price(x):
				toast("Saldo insuficiente"); return ""
			G.money = int(G.money) - price(x); G.parts[x] = int(G.parts.get(x, 0)) + 1; save(); hud(); toast("Compraste: " + Data.PARTS[x][0])
		"rma":
			if st.rma.has(x):
				toast("Ya pediste esa pieza hoy por garantía"); return ""
			st.rma[x] = 1; G.parts[x] = int(G.parts.get(x, 0)) + 1; save(); adv(40); toast("📦 Pieza por garantía recibida: " + Data.PARTS[x][0])
	return ""


## Niveles de carrera (afterFinish del original).
var spy_ok: Callable  # spy_ok(need) -> bool

func lvl_goal_txt(l: int) -> String:
	var g: Dictionary = Data.GOALS[l]
	var t := "%d tickets · satisfacción %d" % [g.done, g.sat]
	if g.has("net"): t += " · red %d" % g.net
	if g.has("rep"): t += " · taller %d" % g.rep
	if g.has("sec"): t += " · seguridad %d" % g.sec
	if g.has("spy"): t += " · espías %d" % g.spy
	return t


func _level_check() -> String:
	if not G.has("lvl"): G.lvl = 1
	var l := int(G.lvl)
	if l > 5:
		return " 🏅 Ya completaste los 5 niveles."
	var g: Dictionary = Data.GOALS[l]
	var ok: bool = st.done >= g.done and st.sat >= g.sat and st.net >= g.get("net", 0) and st.rep >= g.get("rep", 0) and st.sec >= g.get("sec", 0)
	if ok and spy_ok.is_valid(): ok = spy_ok.call(int(g.get("spy", 0)))
	var r := ""
	if ok:
		G.lvl = l + 1
		if int(G.lvl) > 5: G.cert = Time.get_unix_time_from_system()
		save()
		r = " 🎯 ¡Nivel %d/5 superado! " % l + ("Completaste toda la carrera de soporte técnico." if int(G.lvl) > 5 else "Siguiente: Nivel %d (%s) — %s." % [int(G.lvl), Data.LVN[int(G.lvl)], lvl_goal_txt(int(G.lvl))])
	else:
		r = " 🎯 Nivel %d/5 no superado. Meta: %s. Repite el nivel mañana." % [l, lvl_goal_txt(l)]
	level_changed.emit()
	return r


# ---------------- Sonido (síntesis como el WebAudio original) ----------------
func beep(f := 520.0, d := .08, ty := "square") -> void:
	if muted:
		return
	var key := "%d_%d_%s" % [int(f), int(d * 1000), ty]
	var s: AudioStreamWAV = _snd_cache.get(key)
	if s == null:
		s = _synth(f, d, ty)
		_snd_cache[key] = s
	for p in _players:
		if not p.playing:
			p.stream = s
			p.play()
			return
	_players[0].stream = s
	_players[0].play()


func _synth(f: float, d: float, ty: String) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * d)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var ph := fmod(t * f, 1.0)
		var v: float
		match ty:
			"sine": v = sin(ph * TAU)
			"sawtooth": v = ph * 2.0 - 1.0
			_: v = 1.0 if ph < .5 else -1.0
		var env := 0.04 * pow(0.0001 / 0.04, t / d)  # rampa exponencial como gain.exponentialRampToValueAtTime
		var sample := int(clampf(v * env * 6.0, -1, 1) * 32767)
		data.encode_s16(i * 2, sample)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
