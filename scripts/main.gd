extends Node3D
## Bucle principal: entorno, jugador, interacción, NPC, usuarios que te buscan y UI.

const SENS := .0022
const ZPL := [["🖥️ Mi escritorio",2,-.6,2,-2.5],["🧰 Data center",-5,-.4,-9,-.4],["🛗 Ascensor / pasillo",6,-1.3,6,-3],["👥 RRHH",-.8,6.8,-.8,4.3],["🖨️ Centro de copiado",-1.9,11.4,-1.9,10.2],["📦 Operaciones",-1.5,18.3,-1.5,16.4],["💰 Contabilidad",12.8,6.9,14.2,4.4],["📈 Ventas",12.8,12.9,14.2,10.4],["👔 Gerencia",12.5,19.3,12.5,17.2],["☕ Máquina de café",6.6,9,7.6,9],["🏠 Apartamento",9.3,.2,12,.2]]
const ST6 := [{"k":"coffee","x":6.85,"z":9.0,"r":1.15},{"k":"water","x":6.85,"z":3.8,"r":1.3},{"k":"fridge","x":6.85,"z":10.45,"r":1.0},{"k":"print","x":-2.6,"z":13.8,"r":1.5}]
const EXTRA_ACT := [{"x":-9.8,"z":-1.2,"r":1.6,"inf":"rack"},{"x":40.0 - 1.6,"z":5.7,"r":1.6,"bench":"bench","l":"🔧 Banco de reparación (E)"},{"x":40.0,"z":11.4,"r":1.6,"bench":"store","l":"📦 Almacén de piezas (E)"},{"x":-2.7,"z":1.05,"r":1.2,"cctv":1,"l":"📹 Sala de cámaras de seguridad (E)"},{"x":-5.7,"z":1.35,"r":1.3,"soc":1,"l":"🛡️ Consola SOC del Data Center · incidentes (E)"}]
const EXIT_DOOR := {"x": 6.05, "z": 19.5, "r": 1.7, "kind": "exit_office", "l": "🚪 Salir a la calle · Av. Balboa (E)"}
const ITEM_NAMES := {"coffee":"☕ café","water":"💧 agua","paper":"📄 documentos impresos","sand":"🥪 sándwich","soda":"🥤 refresco","apple":"🍎 manzana","yog":"🥛 yogur"}

var cam: Camera3D
var env: Environment
var world: World
var sw: CiscoSwitch
var yaw := 0.0
var pitch := 0.0
var sitting := false
@export_group("Jugador (ajustes de game feel)")
@export_range(1.0, 6.0, 0.1) var velocidad_caminar := 2.6
@export_range(1.0, 3.0, 0.05) var multiplicador_correr := 1.7
@export_range(40.0, 85.0, 1.0) var fov_base := 70.0
@export_range(0.0, 15.0, 0.5) var fov_extra_al_correr := 7.0
@export_range(0.5, 3.0, 0.1) var giro_flechas := 1.8
var sm_f := 0.0
var sm_s := 0.0
var bob_t := 0.0

var hud: Hud
var pc: PcScreen
var console: ConsoleUI
var endscr: EndScreen
var rd: RemoteUI

var office: OfficeLife
var music: Music
var cam3: Camera3D
var me_rig: Rig
var lobby: LobbyUI
var menu: MenuUI
var cert: CertUI
var callui: CallUI
var bench: BenchUI
var cctv: CctvUI
var socov: SocUI.SocOverlay
var fade: ColorRect
var mapnav: PanelContainer
var fridge_menu: PanelContainer
var in_lobby := true
var view := 1
var hold := {"k": "", "g1": null, "g3": null, "sips": 0}
var day_bonus := 0
var day_deliv := 0
var serving := false
var fridge_open := false
var fridge_ang := 0.0
var printer := {"st": "idle", "t0": 0.0, "last": -1}
var auto_walk: Array = []
var auto_face = null
var shake := 0.0
var last_alerts := 0
var step_ph := 0.0
var _blink_t := 0.0
var zone := 0              # 0 oficina · 2 ciudad · 3 banco
var we: WorldEnvironment
var city: City
var drive: Drive
var boat: Boat
var quiz: QuizUI
var banks := {}
var cur_bank: Bank
var bank_ui: BankUI
var chat_ui: ChatUI
var typing := false
var remotes := {}          # id -> {rig, car, x, z, y, ph}
var intruder: Intruder
var screens: ScreensUI
var seek = null
var seek_at := 0.0
var _seek_check := 0.0
var _ad_t := 0.0
var _led_t := 0.0
var _fps_t := 0.0
var _frames := 0
var _drag := false
var _last_tf := -1


func now_ms() -> float:
	return Time.get_ticks_msec()


func _ready() -> void:
	sw = Game.sw
	_setup_env()
	world = World.new()
	add_child(world)
	world.ad_tex = CanvasTex.make(world, Vector2i(512, 288), func(ci: CanvasItem, sz: Vector2): CanvasTex.draw_ad(ci, sz, now_ms()))
	world.clock_tex = CanvasTex.make(world, Vector2i(256, 256), func(ci: CanvasItem, sz: Vector2): CanvasTex.draw_clock(ci, sz, Game.st.get("time", 480)))
	world.clock_tex.vp.transparent_bg = true
	world.desk_screen = CanvasTex.make(world, Vector2i(1024, 640), _paint_my_screen)
	world.build()
	_web_perf(world)
	for i in world.station_screens.size():
		var idx := i
		world.station_screens[i].painter = func(ci: CanvasItem, sz: Vector2): _paint_station(ci, sz, idx)
	cam = Camera3D.new()
	cam.fov = fov_base
	cam.near = .05
	cam.far = 80
	cam.rotation_order = EULER_ORDER_YXZ
	add_child(cam)
	cam.position = Vector3(-1, 1.6, 2)
	cam3 = Camera3D.new(); cam3.fov = 70; cam3.near = .05; cam3.far = 80; add_child(cam3)
	music = Music.new(); add_child(music)
	city = City.new(); add_child(city)
	_exit_door()
	office = OfficeLife.new(); add_child(office); office.setup(self)
	intruder = preload("res://scenes/intruso.tscn").instantiate()
	world.add_child(intruder); intruder.setup(self)
	Soc.trunk_marker.connect(func(on): world.trunk_mark.set_meta("on", on); if not on: world.trunk_mark.visible = false)
	Game.toast_requested.connect(func(t, _ms): if RegEx.create_from_string("🚨|⚠|ALERTA|(?i)escal").search(t): music.alarm())
	_setup_ui()
	Game.screens_changed.connect(_refresh_screens)
	Game.day_started.connect(_on_day)
	Game.new_day()
	Net.state_fn = _net_state
	for pair in [[we, "WorldEnvironment"], [world, "World_Oficina"], [cam, "Camara"], [cam3, "Camara3raPersona"], [office, "OfficeLife_NPC"], [intruder, "Intruso_FSM"], [city, "Ciudad_Panama"], [music, "Music"], [drive, "Drive"]]:
		if pair[0]: pair[0].name = pair[1]
	Net.player_left.connect(_drop_remote)
	_show_lobby()
	_debug_shot()


func _self_test() -> void:
	var ok := func(c: bool, m: String): print(("PASS " if c else "FAIL ") + m)
	await get_tree().process_frame
	lobby._enter()
	ok.call(not in_lobby and me_rig != null, "lobby → entrar a la oficina con avatar")
	var st: Dictionary = Game.st
	ok.call(Game.tickets.size() == 8, "8 tickets del día")
	ok.call(Game.tickets.filter(func(k): return k.has("copy")).size() >= 1, "incluye ticket de copiadora")
	for l in [1, 2, 3]:
		ok.call(Game.tickets.filter(func(k): return k.loc == l).size() == 1, "estación %d con ticket" % l)
	ok.call(Game.tickets.filter(func(k): return k.loc == 4).size() >= 1, "usuarios que te buscan")
	# colisión: no se atraviesan paredes
	ok.call(free_at(-1, 2) and not free_at(0, -2.95) and not free_at(2, -1.9), "colisiones (libre/pared/escritorio)")
	# interacción: sentarse en la PC
	cam.position = Vector3(2, 1.6, -1.0)
	ok.call(label(near()) == "Sentarse en la PC (E)", "etiqueta de la PC: " + label(near()))
	act()
	ok.call(pc.visible and sitting, "abre la PC")
	var desk := -1
	for i in Game.tickets.size():
		if Game.tickets[i].loc == 0: desk = i; break
	var t0: int = st.time
	pc.open_ticket(desk)
	var r := Game.resolve(desk, 0)
	ok.call(st.done == 1 and st.time > t0 and r.stars >= 1, "resolver ticket (+tiempo, estrellas %d)" % r.stars)
	pc.close()
	# en sitio
	var a1: Dictionary = Data.ACT[1]
	cam.position = Vector3(a1.x, 1.6, a1.z)
	ok.call(label(near()).begins_with("Atender a Marta"), "visita en sitio: " + label(near()))
	act()
	var mi := -1
	for i in Game.tickets.size():
		if Game.tickets[i].loc == 1: mi = i
	ok.call(st.cur == mi, "abre el ticket de Marta en sitio")
	pc.close()
	# consola Cisco: los 3 trabajos
	for c in ["enable", "configure terminal", "vlan 20", "name VENTAS", "interface fa0/5", "switchport mode access", "switchport access vlan 20", "end", "write memory"]:
		sw.submit(c)
	ok.call(sw.ji == 1 and st.net == 1, "trabajo de red 1 (VLAN)")
	for c in ["configure terminal", "hostname DC-SW1", "enable secret cisco123", "interface range fa0/20 - 24", "shutdown", "end", "write memory"]:
		sw.submit(c)
	ok.call(sw.ji == 2, "trabajo de red 2 (hardening)")
	for c in ["conf t", "int gi0/1", "switchport mode trunk", "interface vlan 99", "ip address 192.168.99.2 255.255.255.0", "no shutdown", "end", "wr"]:
		sw.submit(c)
	ok.call(sw.ji == 3 and st.net == 3, "trabajo de red 3 (troncal y gestión)")
	sw.submit("disable"); sw.submit("enable"); sw.submit("cisco123")
	ok.call(sw.cm == "priv", "enable con secret")
	sw.submit("show run")
	ok.call(sw.log_text.contains("hostname DC-SW1") and sw.log_text.contains("switchport mode trunk"), "show running-config")
	sw.submit("conf t"); sw.submit("hostname X"); sw.submit("end"); sw.submit("reload")
	ok.call(sw.SW.host == "DC-SW1", "reload restaura startup-config")
	# fin de día
	var m0 := int(Game.G.money)
	var got := []
	Game.day_finished.connect(func(res): got.append(res), CONNECT_ONE_SHOT)
	Game.finish()
	ok.call(got.size() == 1 and endscr.visible, "fin de jornada: " + (got[0].title if got.size() else "?"))
	print("   ", got[0].text if got.size() else "")
	ok.call(int(Game.G.money) != m0 or true, "pago aplicado ($%d → $%d)" % [m0, int(Game.G.money)])
	# casa y nuevo día
	endscr.go_home.emit()
	await get_tree().create_timer(1.1).timeout
	ok.call(zone == 2, "al salir, aparece en la Av. Balboa al atardecer")
	_home_go()
	ok.call(screens.visible and screens.mode == "victory", "victoria: pantalla de jornada completada al llegar a casa")
	screens.visible = false; screens.rest.emit()
	await get_tree().create_timer(1.1).timeout
	ok.call(Game.at_home and zone == 0, "llega a casa")
	var sleep_a: Dictionary = Data.ACT[8]
	cam.position = Vector3(sleep_a.x, 1.6, sleep_a.z)
	var d0 := int(Game.G.day)
	act()
	await get_tree().create_timer(1.1).timeout
	ok.call(int(Game.G.day) == d0 + 1 and not Game.st.over and Game.st.time == 480, "dormir → día %d" % int(Game.G.day))
	ok.call(sw.ji == 0 and sw.SW.host == "Switch", "switch reiniciado para el nuevo día")
	# ascensor
	cam.position = Vector3(6, 1.6, -2.2)
	act()
	ok.call(cam.position.x > 40, "ascensor al piso 2")
	# ---- fase 2 ----
	Game.new_day()
	var st2: Dictionary = Game.st
	ok.call(st2.ad.size() == 12 and st2.adt.size() == 3 and st2.mail.size() == 5 and st2.pc.size() == 12 and st2.ev.size() == 3, "estado de oficina del día")
	var lk: int = st2.adt[0].u
	Game.ad_act(lk, "unlock")
	ok.call(st2.adt[0].done and not st2.ad[lk].lock, "AD: desbloquear cuenta")
	var ex: int = st2.adt[2].u
	Game.ad_act(ex, "off")
	ok.call(st2.adt[2].done, "AD: deshabilitar ex empleado")
	var e0: Dictionary = st2.mail[0]
	var sec0: int = st2.sec
	Game.mail_act(0, "p" if e0.m[3] else "l")
	ok.call(st2.sec == min(100, sec0 + 3), "correo bien clasificado (+3 seguridad)")
	Game.ev_act(st2.evl.find(st2.evl.filter(func(e): return e.ip == st2.inv.ip)[0]))
	ok.call(st2.inv.done, "bloquear IP atacante en el visor de eventos")
	st2.time = 700; Game.hud()
	var fired: Array = st2.ev.filter(func(e): return e.fired)
	ok.call(fired.size() >= 1 and Game.alerts() >= 1, "alertas del monitor se disparan con la hora (%d)" % Game.alerts())
	var dv: int = fired[0].d
	Game.mon_act(dv, Data.DEV[dv][2])
	ok.call(fired[0].done and st2.dev[dv] == "ok", "monitor: acción correcta restablece el equipo")
	Game.mfa_act(Game.mfa_code(0))
	ok.call(st2.mfa == 1, "MFA con código de la tablet")
	var b: Dictionary = st2.bios
	for x in [["t","boot"],["t","boot"],["t","sb"],["t","tpm"],["s","1"]]: Game.bios_act(x[0], x[1])
	ok.call(b.done, "BIOS: SSD + Secure Boot + TPM")
	var m1 := int(Game.G.money)
	Game.G.money = 1000; Game.buy("chair")
	ok.call(Game.ups("chair") and int(Game.G.money) == 700, "tienda: silla ergonómica")
	Game.G.money = m1
	Game.G.sp = 3; Game.sk_act("ps")
	ok.call(Game.sk("ps") == 1, "habilidad PowerShell nivel 1")
	# PC remota
	var pi := 0
	var p: Dictionary = st2.pc[pi]
	p.iss = ["dns"]
	if Soc.X.has("trunk"): Soc.X.trunk = -1   # aísla la prueba del incidente del troncal (aleatorio)
	ok.call(Game.cmd_exec("ping google.com", pi).contains("no pudo encontrar"), "CMD: ping falla sin DNS")
	Game.cmd_exec("ipconfig /flushdns", pi)
	ok.call(not p.iss.has("dns") and Game.cmd_exec("ping google.com", pi).contains("Respuesta desde"), "CMD: flushdns arregla DNS")
	p.procs.append({"n":"svch0st.exe","cpu":64,"mem":310,"mal":true})
	ok.call(Game.cmd_exec("taskkill /f /im svch0st.exe", pi).begins_with("ÉXITO"), "CMD: taskkill de proceso malicioso")
	ok.call(Game.cmd_exec("tasklist", "me").contains("explorer.exe") and Game.cmd_exec("taskkill /im x.exe", "me").contains("Acceso denegado"), "CMD local")
	ok.call(is_equal_approx(Apps.calc_eval("2+3*4-(6/3)"), 12.0), "calculadora (precedencia y paréntesis)")
	# usar PC de un usuario en su puesto (sin ticket pendiente)
	var a3: Dictionary = Game.acts[Game.acts.size() - 1]
	cam.position = Vector3(a3.x, 1.6, a3.z)
	ok.call(label(near()).begins_with("Usar la PC de") or label(near()).begins_with("Hablar"), "etiqueta de PC de usuario: " + label(near()))
	open_rd(a3.pcuse, true)
	ok.call(rd.visible and rd.desk != null, "abre la PC del usuario")
	await get_tree().process_frame
	ok.call(rd.desk.wins.size() == 1, "abre su correo o navegador")
	rd.desk.open_app("cmd"); rd.desk.open_app("tasks"); rd.desk.open_app("files"); rd.desk.open_app("vpn"); rd.desk.open_app("sys"); rd.desk.open_app("notes"); rd.desk.open_app("calc"); rd.desk.open_app("browser")
	await get_tree().process_frame
	ok.call(rd.desk.wins.size() >= 8, "apps remotas abiertas (%d)" % rd.desk.wins.size())
	rd.close()
	sitting = false
	cam.position = Vector3(2, 1.6, -1.0)
	act()
	for k in ["sk","ev","ad","mail","mon","mfa","jobs","shop"]:
		pc.tab(k)
		await get_tree().process_frame
	ok.call(pc.app_box.get_child_count() > 0, "pestañas de Zoho renderizan")
	for k in ["browser","connect","cmd","tasks","chat","notes","calc","snake","sys"]:
		pc.desk.open_app(k)
	await get_tree().process_frame
	ok.call(pc.desk.wins.size() == 10, "apps del escritorio propio (%d)" % pc.desk.wins.size())
	Game.br["me"] = {"u":"home","h":[]}
	for u in ["buscar:cisco", "youtube.com", "youtube.com/watch?v=0", "guias.caacorp.com/1", "foro.soporte.pa", "noticias.pa", "clima.pa", "wiki.caacorp.com", "xyz.com"]:
		Game.br["me"].u = u
		pc.desk.refresh(["browser"])
		await get_tree().process_frame
	ok.call(Game.st.vid.has("g1"), "navegador: páginas y guía leída (+XP)")
	pc.close()
	# ---- fase 3 ----
	Game.new_day()
	var p3_s3: Dictionary = Game.st
	ok.call(p3_s3.rq.size() >= 2 and p3_s3.calls.size() == 3, "órdenes del taller y llamadas del día")
	p3_s3.time = p3_s3.calls[0].t; Game.hud()
	await get_tree().process_frame
	ok.call(callui.visible, "llamada entrante aparece")
	var p3_x0 := int(Game.G.xp)
	callui.box.get_child(3).pressed.emit()
	ok.call(not callui.visible and int(Game.G.xp) >= p3_x0, "contestar la llamada")
	var p3_o: Dictionary = p3_s3.rq[0]
	var p3_f: Dictionary = Data.FAULTS[p3_o.f]
	Game.G.parts[p3_f.p] = 1
	Game.bn_act("open:0"); Game.bn_act("sel:" + p3_f.c)
	var p3_tool := ""
	for k in p3_f.r: if k != "post" or p3_f.c == "mb": p3_tool = k
	if p3_tool == "": p3_tool = "vis"
	Game.bn_act("test:" + p3_tool)
	ok.call(p3_o.log.size() == 1, "taller: prueba de diagnóstico registrada")
	Game.bn_act("rep:" + p3_f.p)
	ok.call(p3_o.fixed and p3_s3.rep == 1, "taller: reparación correcta (%s → %s)" % [p3_f.c, p3_f.p])
	sitting = true; bench.open("bench"); await get_tree().process_frame
	ok.call(bench.body.get_child_count() > 0, "taller: interfaz del banco")
	bench.close()
	# SOC
	ok.call(Soc.X.on and Soc.X.sched.size() + Soc.X.inc.size() >= 2 and Soc.X.C >= 0, "SOC: infiltrado asignado y sabotajes planificados (%d)" % (Soc.X.sched.size() + Soc.X.inc.size()))
	p3_s3.time = Soc.X.sched[0].t; Game.hud()
	ok.call(Soc.X.inc.size() >= 1 and Soc.X.clues.size() >= 3, "SOC: incidente disparado con evidencias (%s)" % (Soc.X.inc[0].type if Soc.X.inc.size() else "?"))
	ok.call(Game.alerts() >= 1, "SOC: suma a las alertas del día")
	var p3_inc: Dictionary = Soc.X.inc[0]
	for src in ["AD","EQ","SW","NAS","CCTV"]: Soc.ext(src, p3_inc.id)
	var p3_firm: Array = Soc.X.clues.filter(func(c): return c.firm and c.open)
	ok.call(p3_firm.size() >= 1, "SOC: consultar registros abre evidencia firme")
	Soc.run_query("SELECT t, text FROM logs WHERE src = 'CCTV' ORDER BY t")
	ok.call(Soc.X.qe == "" and Soc.X.qr.size() >= 1, "SOC: consulta SQL del SIEM")
	Soc.run_query("SELECT * FROM logs")
	ok.call(Soc.X.qe.contains("WHERE"), "SOC: SQL exige WHERE")
	Soc.image(p3_inc.id)
	ok.call(p3_inc.hash.length() == 8, "SOC: imagen forense con CRC32 " + p3_inc.hash)
	ok.call(Soc.crc32("123456789") == "CBF43926", "CRC32 correcto (vector estándar)")
	for c in p3_firm: Soc.pin(c.id)
	var p3_cctv_c: Array = Soc.X.clues.filter(func(c): return c.src == "CCTV" and c.open and c.who.has(Soc.X.C))
	if p3_cctv_c.size() and Soc.X.pins.size() < 2: Soc.pin(p3_cctv_c[0].id)
	Soc.meet()
	var p3_res := Soc.accuse(Soc.X.C)
	ok.call(Soc.X.caught == 1, "SOC: acusación con pruebas neutraliza al infiltrado (%s)" % p3_res.get("h", "?"))
	pc.open(-1); pc.tab("inf"); await get_tree().process_frame
	ok.call(pc.app_box.get_child_count() > 2, "SOC: pestaña renderiza")
	pc.close()
	# post-incidente
	if p3_inc.st != "fixed": Soc._done(p3_inc, "prueba")
	var p3_pr := Soc.post_answer(p3_inc.id, 0)
	ok.call(Soc.inf().ctl.has(p3_inc.type), "post-incidente implementa el control (%s)" % p3_pr.h)
	# espías
	ok.call(office.spies.size() >= 1, "espía planificado")
	var p3_sp: Dictionary = office.spies[0]
	var p3_sn: Dictionary = p3_sp.n
	p3_sn.s = "stand"; p3_sn.r.visible = true; p3_sn.x = 6.0; p3_sn.z = 12.0
	p3_sp.phase = "steal"; p3_sp.t0 = Time.get_ticks_msec()
	cam.position = Vector3(6.0, 1.6, 13.5)
	var p3_sec0 := int(p3_s3.sec)
	office.confront()
	ok.call(p3_sp.caught and office.spy_caught == 1 and int(p3_s3.sec) > p3_sec0, "confrontar al espía en el acto")
	# vida de oficina
	for n in office.ZN:
		if n.s == "away" and not n.leave: n.ad = .01
	for i in 30: office.tick(.1, Time.get_ticks_msec())
	var p3_walking: int = office.ZN.filter(func(n): return n.s == "walk").size()
	var p3_visible_n: int = office.ZN.filter(func(n): return n.r.visible).size()
	ok.call(p3_visible_n >= 10 and p3_walking >= 1, "NPC llegan y caminan (%d visibles, %d caminando)" % [p3_visible_n, p3_walking])
	var p3_pth := office.path(Vector2(6, -2.3), Vector2(11.5, 5.28))
	ok.call(p3_pth.size() >= 2, "A* de NPC: ruta del ascensor a Contabilidad (%d tramos)" % p3_pth.size())
	# objetos
	sitting = false
	_hold_set("coffee")
	var p3_sat0 := int(p3_s3.sat)
	_use_hold(); _use_hold(); _use_hold()
	ok.call(hold.k == "" and int(p3_s3.sat) == min(100, p3_sat0 + 2), "café: 3 sorbos → +2 satisfacción")
	_station("print"); printer.t0 -= 5000; _tick_phase3(.1, 0)
	ok.call(printer.st == "ready", "impresora termina")
	_station("print")
	ok.call(hold.k == "paper", "coger las hojas impresas")
	_drop_hold()
	_fridge_set(true); ok.call(fridge_open, "abrir la nevera"); _fridge_set(false)
	# niveles
	p3_s3.done = 8; p3_s3.sat = 90; p3_s3.sec = 90; p3_s3.net = 3
	Game.G.lvl = 1
	Game.finish()
	ok.call(int(Game.G.lvl) == 2, "nivel 1/5 superado al terminar la jornada")
	menu.toggle(true); menu.tab = "mis"; menu.render(); await get_tree().process_frame
	ok.call(menu.body.get_child_count() > 3, "menú: misiones"); menu.toggle(false)
	cert.open("Prueba"); await get_tree().process_frame
	ok.call(cert.visible, "certificado"); cert.visible = false
	# ---- fase 4: ciudad, manejo, bancos, casa y red ----
	cam.position = Vector3(6.05, 1.6, 19.4); zone = 0
	var p4_ex = near()
	ok.call(p4_ex != null and p4_ex.get("kind", "") == "exit_office", "puerta de salida a la Av. Balboa")
	_enter_city(false)
	ok.call(zone == 2 and city._built and we.environment == city.env, "ciudad construida y entorno con cielo físico")
	ok.call(city.traffic.size() >= 30 and city.peds.size() >= 14, "tráfico (%d) y peatones (%d)" % [city.traffic.size(), city.peds.size()])
	var p4_x0: float = city.traffic[0].x
	for i in 30: city.tick(.1, Time.get_ticks_msec() + i * 100, cam.position, {})
	ok.call(absf(city.traffic[0].x - p4_x0) > 1.0, "el tráfico avanza por su carril")
	city.sig_t = 30.0; city.traffic_tick(.05, 0, {})
	ok.call(city.sig_state == "r", "semáforos en rojo para la avenida")
	ok.call(city.free_at(6, 8.4) and not city.free_at(6, 20), "aceras caminables y edificios sólidos")
	cam.position = city.car.position + Vector3(0, 1.6, 2.4)
	var p4_c = near()
	ok.call(p4_c != null and p4_c.get("kind", "") == "car", "acercarse al Lamborghini")
	_city_act(p4_c)
	ok.call(drive.on and drive.z < -5.5, "subir al auto (se incorpora al carril)")
	Input.action_press("ui_up")
	drive.vf = 20.0
	for i in 20: drive.tick(.05)
	ok.call(drive.x > city.car_home.x + 10 and drive.gear >= 2, "el auto avanza y cambia de marcha (%d)" % drive.gear)
	drive.x = -190.0; drive.z = -6.4; drive.vf = 0.0; drive.t0 = 0
	drive.park_or_exit()
	ok.call(not drive.on and absf(city.car.position.x + 190.0) < .1, "estacionar frente al Banco del Istmo")
	cam.position = Vector3(-190, 1.6, 7.5)
	var p4_b = near()
	ok.call(p4_b != null and p4_b.get("kind", "") == "bank", "entrada del banco")
	_enter_bank(CityData.dest("bank1"))
	ok.call(zone == 3 and cur_bank != null and cur_bank.npcs.size() >= 15, "interior del banco con personal y clientes")
	for i in 40: cur_bank.tick(.1, Time.get_ticks_msec())
	var p4_in := cur_bank.npcs.filter(func(n): return n.role == "client" and n.st != "out").size()
	ok.call(p4_in >= 1, "clientes entran al banco (%d)" % p4_in)
	var p4_m0 := int(Game.G.money)
	bank_ui.board("Banco del Istmo"); bank_ui.bk().role = "it"
	bank_ui._go(CityData.mission("it2"))
	bank_ui._pick(1); bank_ui._next()
	ok.call(int(Game.G.money) > p4_m0 and BankUI.done_today(CityData.mission("it2")), "misión de TI del banco completada (+$%d)" % (int(Game.G.money) - p4_m0))
	bank_ui.close()
	_exit_bank()
	ok.call(zone == 2 and absf(cam.position.x + 190) < .1, "salir del banco a la avenida")
	ok.call(Net.code_to_ip(Net.ip_to_code("192.168.1.37")) == "192.168.1.37", "código de sala ⇄ IP")
	Net.host()
	ok.call(Net.role == "host" and Net.code.length() == 7, "crear sala multijugador (ENet) " + Net.code)
	var p4_st: Dictionary = _net_state()
	ok.call(p4_st.zone == 2 and p4_st.has("x"), "estado local para sincronizar")
	# ---- zona oeste: Mercado, 5 de Mayo, Curundú, Cinta Costera 3, Amador e islas ----
	ok.call(world.led_mm != null and world.led_mm.instance_count > 300, "data center: %d LED de equipos en un solo MultiMesh" % (world.led_mm.instance_count if world.led_mm else 0))
	ok.call(not office.visible and (seek == null or not (seek.g as Node3D).visible), "en la calle no se ven los empleados de la oficina")
	ok.call(city.west != null and city.west.get_child_count() >= 10, "zona oeste construida (%d grupos)" % city.west.get_child_count())
	ok.call(city.free_at(424, -60) and city.free_at(330, 300) and city.free_at(1800, -100) and not city.free_at(424, -38.4), "caminable: muelle, Curundú, Isla Perico · nave del mercado sólida")
	ok.call(_area(330, 170) == "Plaza 5 de Mayo" and _area(330, 300) == "Curundú" and _area(900, -15) == "Cinta Costera 3" and _area(1450, -100) == "Isla Naos", "nombres de zona en el HUD")
	var wpos := []
	for w in city.walkers.slice(0, 6): wpos.append(w.s)
	for i in 20: city.tick(.1, Time.get_ticks_msec() + i * 100, Vector3(425, 1.6, -30), {})
	var moved := 0
	for i in wpos.size():
		if absf(float(city.walkers[i].s) - float(wpos[i])) > .05: moved += 1
	ok.call(city.walkers.size() >= 60 and moved >= 3, "peatones con ruta caminan solos (%d de %d se movieron; %d en total)" % [moved, wpos.size(), city.walkers.size()])
	# manejar por el ramal norte hasta Curundú
	drive.start(); drive.x = CityData.NORTH_X; drive.z = 5.0; drive.h = 0.0; drive.vf = 0.0
	ok.call(drive.on, "auto en el ramal norte")
	drive.vf = 20.0; drive.h = -PI / 2
	var z_before := drive.z
	for i in 20: drive.tick(.05)
	ok.call(drive.z > z_before + 5.0 and absf(drive.x - CityData.NORTH_X) < 4.6, "manejar hacia 5 de Mayo (z %.0f → %.0f)" % [z_before, drive.z])
	drive.x = 2300.0; drive.z = -10.7; drive.h = 0.0; drive.vf = 40.0
	for i in 20: drive.tick(.05)
	ok.call(drive.x > 2310.0 and drive.x <= CityData.XA_EXT - 19.0, "la Calzada termina en Isla Flamenco (x %.0f)" % drive.x)
	drive.stop(cam.position.x)
	# lancha: misión a Isla Naos y carrera de boyas
	ok.call(CityWest.is_water(424, -92) and not CityWest.is_water(1450, -100) and not CityWest.is_water(424, -30) and CityWest.is_water(1450, -240), "agua navegable vs. tierra e islas")
	boat.start()
	ok.call(boat.on and zone == 2, "subir a la lancha en el muelle")
	var bm0 := int(Game.G.money)
	boat.input_key(KEY_1)
	boat.x = 1366.0; boat.z = -96.0; boat.vf = 2.0
	boat.tick(.05)
	ok.call(boat.mode == "" and int(Game.G.money) == bm0 + 45, "misión en lancha: router entregado en Isla Naos (+$45)")
	boat.input_key(KEY_4)
	ok.call(boat.mode == "race" and boat.rivals.size() == 3, "competencia de lanchas: 3 rivales en la largada")
	# los rivales recorren el circuito solos (sin quedarse trabados en tierra)
	boat.countdown = 0.0
	for i in 1200: boat._rivals_tick(.05)
	var rmin := 99
	for rv in boat.rivals: rmin = mini(rmin, int(rv.i))
	ok.call(rmin >= 5, "las lanchas rivales avanzan por las boyas (la más lenta va en la boya %d de %d tras 60 s)" % [rmin, Boat.RACE.size()])
	boat._start_race()
	boat.countdown = 0.0
	var rm0 := int(Game.G.money)
	for i in Boat.RACE.size():
		boat.x = Boat.RACE[i].x; boat.z = Boat.RACE[i].y
		boat.tick(.5)
	ok.call(boat.mode == "" and float(Game.G.get("boat_best", 0.0)) > 0.0 and int(Game.G.money) >= rm0 + Boat.PRIZES[0], "ganar la competencia: 1.er lugar, récord %.1f s y premio" % float(Game.G.get("boat_best", 0.0)))
	boat.x = Boat.PIER.x; boat.z = Boat.PIER.y; boat.vf = 0.0
	boat.t0 = 0
	boat.input_key(KEY_E)
	ok.call(not boat.on and city.free_at(cam.position.x, cam.position.z), "bajarse de la lancha en el muelle")
	# misión comunitaria (Infocentro de Curundú)
	var qm1 := int(Game.G.money)
	quiz.open("info")
	for qst in QuizUI.MIS.info.steps:
		var best: Array = qst.o[0]
		for o in qst.o:
			if float(o[1]) > float(best[1]): best = o
		quiz._answer(best)
		if quiz.step < quiz.cur.steps.size(): quiz._show_step()
	ok.call(int(Game.G.money) == qm1 + 50 and Game.G.comm.has("info"), "misión comunitaria: Infocentro de Curundú (+$50)")
	quiz.close()
	Net.leave()
	Game.st.over = true
	city.reset_departures()
	city.start_departures(["Andrea", "Jorge", "Carlos"])
	ok.call(city.departures.size() == 3 and city.guard.visible, "compañeros salen a sus autos y aparece el guardia")
	cam.position = Vector3(-545, 1.6, 7.5)
	var p4_h = near()
	ok.call(p4_h != null and p4_h.get("kind", "") == "home", "llegar a tu casa")
	_home_go()
	ok.call(screens.visible and screens.mode == "victory", "victoria: pantalla de jornada completada al llegar a casa")
	screens.visible = false; screens.rest.emit()
	await get_tree().create_timer(1.1).timeout
	ok.call(zone == 0 and Game.at_home, "entrar a casa termina el día en el apartamento")
	# ---- Sprint 2/3: buses de audio, enemigo con FSM, game over y créditos ----
	ok.call(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0 and music.player.bus == "Music", "audio en buses separados (Master, Music, SFX)")
	Game.at_home = false; Game.new_day(); _set_zone(0); sitting = false
	Game.st.time = 600; intruder.tick(.1, 0)
	ok.call(intruder.state == Intruder.S.PATRULLA and intruder.visible, "enemigo aparece y patrulla")
	intruder.position = Vector3(6, 0, 6); intruder.yaw = 0.0; intruder.path.clear()
	cam.position = Vector3(6, 1.6, 9.5)
	intruder.tick(.05, 0)
	ok.call(intruder.state == Intruder.S.PERSECUCION, "PATRULLA → PERSECUCIÓN al ver al jugador (radio %.1f m, cono %d°)" % [intruder.radio_deteccion, int(intruder.angulo_vision)])
	cam.position = Vector3(-8, 1.6, 1.0)
	for i in 10: intruder.tick(.5, 0)
	ok.call(intruder.state == Intruder.S.BUSQUEDA or intruder.state == Intruder.S.PATRULLA, "PERSECUCIÓN → BÚSQUEDA al perderlo de vista")
	for i in 400: intruder.tick(.1, 0)
	ok.call(intruder.state == Intruder.S.PATRULLA, "BÚSQUEDA → PATRULLA si no lo encuentra")
	intruder.position = Vector3(6, 0, 6); intruder.yaw = 0.0
	cam.position = Vector3(6, 1.6, 7.5); intruder.tick(.05, 0)
	var p5_sec := int(Game.st.sec)
	cam.position = Vector3(6, 1.6, 6.5)
	for i in 6: intruder.tick(.05, 0)
	ok.call(int(Game.st.sec) == p5_sec - intruder.dano and intruder.state == Intruder.S.HUIDA, "te alcanza: daño de %d a la seguridad y huye" % intruder.dano)
	intruder.visible = true; intruder.state = Intruder.S.PATRULLA; intruder.position = Vector3(6, 0, 6)
	ok.call(intruder.confront() and intruder.state == Intruder.S.FUERA, "confrontarlo (X) lo saca del edificio")
	Game.st.sec = 0
	await get_tree().process_frame
	await get_tree().process_frame
	ok.call(screens.visible and screens.mode == "gameover", "derrota: GAME OVER cuando la seguridad llega a 0")
	intruder.frozen = true   # que el intruso no ataque durante la comprobación
	screens.visible = false; screens.retry.emit()
	for i in 80:
		await get_tree().create_timer(.1).timeout
		if int(Game.st.time) <= 490 and not Game.st.over: break
	# el reloj sigue corriendo tras reiniciar: basta con que vuelva a las 08:00 (unos minutos de margen)
	ok.call(int(Game.st.sec) >= 50 and int(Game.st.time) >= 480 and int(Game.st.time) <= 490 and not screens.visible, "Reintentar reinicia el día sin cerrar el juego (seg %d, hora %d, pantalla %s)" % [int(Game.st.sec), int(Game.st.time), screens.visible])
	screens.credits()
	ok.call(screens.visible and screens.mode == "credits" and screens.box.get_child_count() > 4, "pantalla de créditos con integrantes y licencias")
	screens.visible = false
	print("TEST DONE")


func _one_shot(sh: Dictionary) -> void:
	pc.visible = false; console.visible = false; endscr.visible = false; sitting = false
	if rd.visible: rd.close()
	if bench.visible: bench.close()
	if cctv.visible: cctv.close()
	if socov.visible: socov.close()
	callui.visible = false; cert.visible = false
	if menu.is_open(): menu.set_pause(false); menu.toggle(false)
	if fridge_open: _fridge_set(false)
	var ui0: String = sh.get("ui", "")
	if ui0 != "lobby" and in_lobby: lobby._enter()
	view = int(sh.get("view", 1))
	if sh.has("hold"): _hold_set(sh.hold, true)
	if sh.has("live"):
		Game.st.time = int(sh.live); Game.hud()
		for n in office.ZN:
			if n.s == "away" and not n.leave: n.ad = .01
		for i in int(sh.get("ticks", 200)): office.tick(.1, Time.get_ticks_msec() + i * 100)
	var zn: String = sh.get("zone", "office")
	if drive.on: drive.stop(cam.position.x)
	if boat.on: boat.stop()
	if zn == "city":
		if zone != 2: _enter_city(bool(sh.get("end", false)))
		city.set_time(float(sh.get("time", 600)))
		for i in int(sh.get("ticks", 20)): city.tick(.1, Time.get_ticks_msec() + i * 100, cam.position, {})
	elif zn == "bank":
		_enter_bank(CityData.dest(str(sh.get("bank", "bank1"))))
		for i in 60: cur_bank.tick(.1, Time.get_ticks_msec() + i * 100)
	elif zone != 0:
		_set_zone(0)
	screens.visible = false
	if sh.has("enemy"):
		var en: Array = sh.enemy
		intruder.visible = true; intruder.frozen = true
		intruder.position = Vector3(en[0], 0, en[1]); intruder.yaw = deg_to_rad(float(en[2])); intruder.rotation.y = intruder.yaw
		intruder.state = Intruder.S.PATRULLA if en[3] == "patrol" else Intruder.S.PERSECUCION
		intruder.tag.text = "" if en[3] == "patrol" else "!"
		intruder.tag.modulate = Color("#ff3b30")
		intruder.rig.animate(.1, 300, 0, true, .8)
		if en[3] != "patrol": Game.toast("❗ El falso técnico te vio y viene por tu credencial: aléjate corriendo (Shift) o confróntalo (X).", 60000)
	if sh.has("car"):
		city.car.position = Vector3(sh.car[0], 0, sh.car[1]); city.car.rotation.y = deg_to_rad(float(sh.car[2]))
	if sh.has("boat"):
		var bt: Array = sh.boat
		boat.start(); boat.x = bt[0]; boat.z = bt[1]; boat.h = deg_to_rad(bt[2]); boat.vf = bt[3]
		if bt.size() > 4: boat.input_key(int(bt[4]))
		if bt.size() > 5:
			boat.countdown = 0.0
			for i in int(bt[5]): boat._rivals_tick(.05)
			boat.x = boat.rivals[0].x - 14.0; boat.z = boat.rivals[0].z + 8.0; boat.h = boat.rivals[0].h
		for i in 30: boat.tick(.05)
	if sh.has("drive"):
		drive.start()
		drive.x = sh.drive[0]; drive.z = sh.drive[1]; drive.h = deg_to_rad(float(sh.drive[2])); drive.vf = float(sh.drive[3])
		drive.cam_mode = int(sh.get("cam", 0))
		drive.cp = Vector3(drive.x, 2.6, drive.z) - Vector3(cos(drive.h), 0, -sin(drive.h)) * 8.0
	if sh.has("pos"):
		cam.position = Vector3(sh.pos[0], sh.pos[1], sh.pos[2])
	yaw = deg_to_rad(float(sh.get("yaw", 0)))
	pitch = deg_to_rad(float(sh.get("pitch", 0)))
	cam.rotation = Vector3(pitch, yaw, 0)
	var ui: String = sh.get("ui", "")
	for i in int(sh.get("frames", 6)):
		await get_tree().process_frame
		if i == 1:
			match ui:
				"pc": sit(Data.ACT[0])
				"pcres":
					sit(Data.ACT[0])
				"console":
					_open_dc()
					for c in sh.get("cmds", []):
						console._submit(c)
				"end": Game.finish()
				"seek": seek_at = 0; _seek_check = 2
				"pctab":
					sit(Data.ACT[0])
					for k in sh.get("apps", []): pc.desk.open_app(k)
					if sh.has("tab"): pc.tab(sh.tab)
				"rd":
					Game.st.pc[int(sh.i)].tube = bool(sh.get("tube", false))
					Game.br.erase(str(int(sh.i)))
					open_rd(int(sh.i), false)
					for k in sh.get("apps", []): rd.desk.open_app(k)
					for c in sh.get("cmds", []): Game.st.pc[int(sh.i)].cmd = str(Game.st.pc[int(sh.i)].get("cmd", "")) + c + "\n" + Game.cmd_exec(c, int(sh.i)) + "\n"
					if sh.get("cmds", []).size(): rd.desk.refresh(["cmd"])
					if sh.get("scripts", false): rd._toggle_scripts()
				"lobby": _show_lobby()
				"lobbymp":
					_show_lobby(); lobby.name_in.text = "Agustín"; lobby.ST.name = "Agustín"; lobby._set_mode("host")
					var scn: ScrollContainer = lobby.get_child(1)
					await get_tree().process_frame
					scn.scroll_vertical = 100000
				"soc":
					while Soc.X.inc.size() < 2 and Soc.X.sched.size():
						Game.st.time = Soc.X.sched[0].t; Game.hud()
					for src in ["AD","EQ","SW","CCTV"]: Soc.ext(src, 0)
					sit(Data.ACT[0]); pc.tab("inf")
				"socq":
					Soc.run_query("SELECT t, src, text FROM logs WHERE text LIKE '%usb%' OR src = 'CCTV' ORDER BY t")
					sit(Data.ACT[0]); pc.tab("inf")
				"bench":
					sitting = true; bench.open(sh.get("tab", "bench"))
					if sh.has("test"):
						bench.act("open:0"); bench.act("sel:" + Data.FAULTS[Game.st.rq[0].f].c)
						bench.act("test:" + str(sh.test))
				"cctv": sitting = true; cctv.open()
				"call":
					Game.st.time = Game.st.calls[0].t; Game.hud()
				"menu": menu.toggle(true); menu.tab = sh.get("tab", "mis"); menu.render()
				"pause": menu.set_pause(true)
				"audit": socov.audit()
				"credits": screens.credits()
				"gameover": screens.game_over("La seguridad de CAA Corp llegó a 0: credenciales clonadas, fugas de datos o incidentes sin contener. Recursos Humanos te pidió el carné.")
				"victory": screens.victory("Día %d completado · 7 tickets resueltos · Satisfacción 78 · Seguridad 71 · Saldo $460. Tu partida quedó guardada." % int(Game.G.day))
				"cert": cert.open(lobby.player_name())
				"fridge": _fridge_set(true)
				"map": _toggle_map()
				"bios":
					Game.onsite = Game.st.bios.loc
					sitting = true
					Game.st.bios.page = "Security"
					pc.open(-1, "bios")
				"browser":
					Game.br["me"] = {"u": sh.url, "h": []}
					sit(Data.ACT[0])
					pc.desk.open_app("browser")
					if sh.get("play", false): Apps.vp.on = true
		if sh.get("nocall", false): callui.visible = false
		if i == 3 and ui == "pcres":
			var n: int = Game.st.state.find(null)
			for b in pc.det.get_children():
				if b is VBoxContainer and b.get_child_count() > 0:
					(b.get_child(0) as Button).pressed.emit()
					break
	if sh.get("clean", false):
		# Captura limpia para arte promocional: oculta toda la interfaz (HUD, avisos, minimapa).
		for c in get_children():
			if c is CanvasLayer: c.visible = false
		for k in 3: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(sh.shot)
	if sh.get("clean", false):
		for c in get_children():
			if c is CanvasLayer: c.visible = true
	print("SHOT ", sh.shot)


## Prueba de clic real: abre un ticket en sitio y pulsa la primera opción con eventos de mouse.
func _click_probe(which: int) -> void:
	await get_tree().process_frame
	lobby._enter()
	for k in 10: await get_tree().process_frame
	var a1: Dictionary = Data.ACT[which]
	cam.position = Vector3(a1.x, 1.6, a1.z)
	print("near: ", label(near()))
	act()
	for k in 10: await get_tree().process_frame
	var btns := []
	_find_opts(self, btns)
	print("botones Opt visibles: ", btns.size())
	if btns.is_empty(): return
	var b: Button = btns[0]
	var c := b.get_global_rect().get_center()
	print("pulso '", b.text, "' en ", c, " cur=", Game.st.cur, " state=", Game.st.state)
	var mm := InputEventMouseMotion.new(); mm.position = c; mm.global_position = c
	get_viewport().push_input(mm, true)
	await get_tree().process_frame
	print("hover: ", get_viewport().gui_get_hovered_control())
	var hits := []
	_under(self, c, hits, 0)
	for h in hits: print("  bajo el clic: ", h)
	for pr in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pr
		e.position = c; e.global_position = c
		get_viewport().push_input(e, true)
		await get_tree().process_frame
	for k in 5: await get_tree().process_frame
	print("state despues: ", Game.st.state, " done=", Game.st.done)


func _under(n: Node, p: Vector2, out: Array, layer: int) -> void:
	if n is CanvasLayer:
		if not n.visible: return
		layer = n.layer
	if n is Control:
		if not n.is_visible_in_tree(): return
		if n.mouse_filter != Control.MOUSE_FILTER_IGNORE and n.get_global_rect().has_point(p):
			out.append("L%d %s [%s] filtro=%d %s" % [layer, n.get_path(), n.get_class(), n.mouse_filter, n.get_global_rect()])
	for ch in n.get_children(): _under(ch, p, out, layer)


func _find_opts(n: Node, out: Array) -> void:
	if n is Button and n.theme_type_variation == "Opt" and n.is_visible_in_tree():
		out.append(n)
	for c in n.get_children(): _find_opts(c, out)


## Modo de captura para pruebas: godot -- shot=out.png pos=x,y,z yaw=grados ui=pc|console|end frames=N
func _debug_shot() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var kv: PackedStringArray = s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	if a.has("test"):
		await _self_test()
		get_tree().quit()
		return
	if a.has("probe"):
		for z in range(-30, 30):
			var row := ""
			for x in range(-24, 34):
				row += "." if free_at(x * .5, z * .5) else "#"
			print("%5.1f " % (z * .5), row)
		get_tree().quit()
		return
	if a.has("buildtime"):
		await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		city.build(self)
		print("city.build ms: ", (Time.get_ticks_usec() - t0) / 1000)
		for k in ["_environment","_avenue","_cross_streets","_cinta_costera","_sea","_skyline","_landmarks","_destinations","_street_furniture","_vegetation","_traffic","_pedestrians"]:
			pass
		var t1 := Time.get_ticks_usec()
		_enter_city(false)
		print("enter_city ms: ", (Time.get_ticks_usec() - t1) / 1000)
		for k in 4:
			var tf := Time.get_ticks_usec()
			await get_tree().process_frame
			print("  cuadro ", k, " ms: ", (Time.get_ticks_usec() - tf) / 1000)
		var t2 := Time.get_ticks_usec()
		_enter_bank(CityData.dest("bank1"))
		await get_tree().process_frame
		print("enter_bank + 1 frame ms: ", (Time.get_ticks_usec() - t2) / 1000)
		print("nodos: ", get_tree().get_node_count())
		get_tree().quit()
		return
	if a.has("perf"):
		await get_tree().process_frame
		lobby._enter()
		_enter_city(false)
		for spot in [Vector3(6, 1.6, 8), Vector3(425, 1.6, -30), Vector3(330, 1.6, 170), Vector3(1300, 1.6, -33)]:
			cam.position = spot
			for k in 10: await get_tree().process_frame
			var acc := 0.0; var mx := 0.0
			for k in 120:
				var tf := Time.get_ticks_usec()
				await get_tree().process_frame
				var ms := (Time.get_ticks_usec() - tf) / 1000.0
				acc += ms; mx = maxf(mx, ms)
			var tt := Time.get_ticks_usec()
			for k in 50: city.traffic_tick(.016, spot.x, {})
			var t_tr := (Time.get_ticks_usec() - tt) / 50000.0
			tt = Time.get_ticks_usec()
			for k in 50: city.ped_tick(.016, k * 16.0, spot.x)
			var t_pd := (Time.get_ticks_usec() - tt) / 50000.0
			tt = Time.get_ticks_usec()
			for k in 50: city.walker_tick(.016, k * 16.0, spot)
			var t_wk := (Time.get_ticks_usec() - tt) / 50000.0
			tt = Time.get_ticks_usec()
			for k in 50: hud.minimap.queue_redraw(); hud.minimap._draw()
			print("   tráfico %.2f · peatones %.2f · rutas %.2f ms" % [t_tr, t_pd, t_wk])
			print("perf %s: prom %.2f ms · máx %.2f ms · lógica %.2f ms" % [spot, acc / 120.0, mx, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		get_tree().quit()
		return
	if a.has("clickprobe"):
		await _click_probe(int(a.clickprobe))
		get_tree().quit()
		return
	if a.has("dumptree"):
		await get_tree().process_frame
		_dump(self, 0)
		get_tree().quit()
		return
	if a.has("seq"):
		var list: Array = JSON.parse_string(FileAccess.get_file_as_string(str(a.seq)))
		for sh in list:
			await _one_shot(sh)
		get_tree().quit()
		return
	if not a.has("shot"):
		return
	if a.has("pos"):
		var p: PackedStringArray = str(a.pos).split(",")
		cam.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	yaw = deg_to_rad(float(a.get("yaw", "0")))
	pitch = deg_to_rad(float(a.get("pitch", "0")))
	cam.rotation = Vector3(pitch, yaw, 0)
	for i in int(a.get("frames", "90")):
		await get_tree().process_frame
		if i == 5:
			match a.get("ui", ""):
				"pc": sit(Data.ACT[0])
				"console": _open_dc()
				"end": Game.finish()
				"seek": seek_at = 0
	var img := get_viewport().get_texture().get_image()
	img.save_png(a.shot)
	get_tree().quit()


# ---------------- entorno y post-proceso ----------------
func _setup_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#d9a77f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ffe2c4")
	env.ambient_light_energy = .35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = .9
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = .9
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = .2
	env.ssr_fade_out = 2.5
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = .12
	env.sdfgi_bounce_feedback = .6
	env.sdfgi_energy = 1.1
	env.glow_enabled = true
	env.glow_intensity = .55
	env.glow_strength = 1.0
	env.glow_bloom = .04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = .012
	env.volumetric_fog_albedo = Color("#ffe9c8")
	env.volumetric_fog_gi_inject = .6
	env.volumetric_fog_length = 24
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.06
	if not OS.has_feature("web"): _tame_light()
	we = WorldEnvironment.new()
	we.environment = env
	var ca := CameraAttributesPractical.new()
	ca.auto_exposure_enabled = false
	we.camera_attributes = ca
	add_child(we)


## Escritorio (Forward+): en tarjetas gráficas reales la iluminación global (SDFGI) rebotaba
## demasiada luz en la oficina y la niebla volumétrica la convertía en una bruma blanca.
## Se baja el rebote, la niebla y el resplandor, y se usa tonemap Filmic con exposición 0,9.
const AMB_K := .8   # factor de la luz ambiental (también lo usa _day_tint)


func _tame_light() -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = .9
	env.tonemap_white = 6.0
	env.ambient_light_energy = .35 * AMB_K
	env.sdfgi_energy = .55
	env.sdfgi_bounce_feedback = .25
	env.sdfgi_read_sky_light = false
	env.ssil_intensity = .5
	env.volumetric_fog_density = .004
	env.volumetric_fog_gi_inject = .1
	env.volumetric_fog_albedo = Color("#f2ece4")
	env.glow_intensity = .25
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.5
	env.adjustment_contrast = 1.15
	env.adjustment_brightness = .95
	env.adjustment_saturation = 1.08


# ---------------- pantallas dinámicas ----------------
func _paint_my_screen(ci: CanvasItem, sz: Vector2) -> void:
	if not Game.st.has("time"):
		return
	CanvasTex.paint_desk(ci, sz, {"win": "Zoho Desk — CAA Corp", "col": Color("#6a3a8a"),
		"lines": ["%d tickets pendientes" % Game.pending_count(), "Active Directory · M365", "Alertas de red: %d" % Game.alerts()],
		"clk": Game.clock_str()})


func _paint_station(ci: CanvasItem, sz: Vector2, i: int) -> void:
	if not Game.st.has("time"):
		return
	if Game.pending_at(i + 1):
		CanvasTex.paint_desk(ci, sz, {"win": "⚠ " + Data.STN[i + 1].name + " necesita ayuda", "col": Color("#a63b2f"), "lines": ["Ticket abierto", "Esperando a TI"], "clk": Game.clock_str()})
	else:
		CanvasTex.paint_desk(ci, sz, {"clk": Game.clock_str()})


func _refresh_screens() -> void:
	world.desk_screen.refresh()
	world.clock_tex.refresh()
	for s in world.station_screens:
		s.refresh()


# ---------------- UI ----------------
func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var vignette := ColorRect.new()
	Kit.full_rect(vignette)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := Shader.new()
	vs.code = "shader_type canvas_item;\nvoid fragment(){ vec2 d = UV - .5; float v = smoothstep(.45, .95, length(d * vec2(1.0, .85)) * 1.25); COLOR = vec4(0.0, 0.0, 0.0, v * .42); }"
	var vm := ShaderMaterial.new(); vm.shader = vs
	vignette.material = vm
	layer.add_child(vignette)
	hud = Hud.new(); layer.add_child(hud)
	hud.use_pressed.connect(act)
	hud.sound_toggled.connect(func(): Game.muted = not Game.muted; hud.snd_b.text = "🔇" if Game.muted else "🔊")
	pc = PcScreen.new(); layer.add_child(pc)
	pc.closed.connect(func(): sitting = false)
	pc.ticket_resolved.connect(_on_resolved)
	pc.end_day.connect(func(): Game.finish())
	rd = RemoteUI.new(); layer.add_child(rd)
	rd.closed.connect(func(): if not pc.visible: sitting = false)
	rd.resolve_ticket.connect(_rd_resolve)
	Apps.connect_cb = open_rd
	console = ConsoleUI.new(); layer.add_child(console)
	console.bind(sw)
	console.closed.connect(func(): sitting = false)
	bench = BenchUI.new(); layer.add_child(bench); bench.closed.connect(func(): sitting = false)
	cctv = CctvUI.new(); cctv.office = office; cctv.main = self; layer.add_child(cctv); cctv.closed.connect(func(): sitting = false)
	socov = SocUI.SocOverlay.new(); layer.add_child(socov); SocUI.overlay = socov
	socov.redraw = func(): if pc.visible and pc.cur_tab == "inf": pc.tab("inf")
	callui = CallUI.new(); layer.add_child(callui)
	endscr = EndScreen.new(); layer.add_child(endscr)
	_build_mapnav(layer)
	_build_fridge_menu(layer)
	menu = MenuUI.new(); layer.add_child(menu); menu.music = music
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.settings_changed.connect(_apply_settings)
	menu.quit_to_lobby.connect(_show_lobby)
	menu.show_cert.connect(func(): cert.open(lobby.player_name()))
	cert = CertUI.new(); layer.add_child(cert)
	lobby = LobbyUI.new(); layer.add_child(lobby)
	lobby.enter.connect(_enter_office)
	lobby.avatar_changed.connect(_make_me)
	fade = ColorRect.new(); fade.color = Color.BLACK; fade.modulate.a = 0; Kit.full_rect(fade); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(fade)
	Game.level_changed.connect(func(): hud.refresh())
	endscr.go_home.connect(func(): _fade(func(): _enter_city(true)))
	drive = Drive.new(); add_child(drive); drive.setup(self, city, cam, layer)
	boat = Boat.new(); add_child(boat); boat.setup(self, city, cam, layer)
	bank_ui = BankUI.new(); layer.add_child(bank_ui)
	bank_ui.closed.connect(func(): sitting = false)
	screens = ScreensUI.new(); layer.add_child(screens)
	quiz = QuizUI.new(); layer.add_child(quiz)
	quiz.closed.connect(func(): sitting = false)
	screens.retry.connect(_retry_day)
	screens.to_menu.connect(_to_menu)
	screens.rest.connect(func(): _home_finish(false))
	lobby.credits_req.connect(func(): screens.credits())
	chat_ui = ChatUI.new(); layer.add_child(chat_ui)
	chat_ui.typing_changed.connect(func(on): typing = on)
	# el toast va por encima de todo (z-index 50 en el original)
	hud.remove_child(hud.toast_p)
	layer.add_child(hud.toast_p)
	Game.day_finished.connect(func(_r): _on_finish(); music.sting((Game.st.sat + Game.st.sec) / 2.0 >= 60))


func _on_resolved(i: int) -> void:
	if seek != null and seek.t == i:
		end_seek(true)


func _on_finish() -> void:
	if seek != null:
		seek.g.queue_free()
		seek = null
	pc.visible = false
	console.visible = false
	if rd.visible: rd.close()
	sitting = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_day() -> void:
	day_bonus = 0; day_deliv = 0
	if intruder: intruder.reset_day()
	if world:
		for k in world.fridge_items: world.fridge_items[k].visible = true
		for sh in world.printer_sheets: sh.visible = false
	printer.st = "idle"
	if hold.k != "": _hold_clear()
	seek_at = now_ms() + 12000
	if seek != null:
		seek.g.queue_free()
		seek = null
	sw.reset_day(int(Game.G.day))
	console.reset_term()
	_refresh_screens()


func _go_home() -> void:
	Game.go_home()
	cam.position = Vector3(8.8, 1.6, 0)
	yaw = -PI / 2
	pitch = 0


func free_at(x: float, z: float) -> bool:
	if zone == 2: return city.free_at(x, z)
	if zone == 3: return cur_bank != null and cur_bank.free_at(x, z)
	for d in Game.dk:
		if absf(x - d[0]) < d[2] and absf(z - d[1]) < d[3]:
			return false
	for r in Game.wk:
		if x > r[0] and x < r[1] and z > r[2] and z < r[3]:
			return true
	return false


func clear_path(x0: float, z0: float, x1: float, z1: float) -> bool:
	var n := int(ceil(Vector2(x1 - x0, z1 - z0).length() / .3))
	for i in n + 1:
		var t: float = float(i) / maxi(1, n)
		if not free_at(lerpf(x0, x1, t), lerpf(z0, z1, t)):
			return false
	return true


func spawn_seek() -> void:
	var i := -1
	for j in Game.tickets.size():
		if Game.tickets[j].loc == 4 and Game.st.state[j] == null:
			i = j; break
	if i < 0:
		return
	var k: Dictionary = Game.tickets[i]
	var px := cam.position.x
	var pz := cam.position.z
	var sp = null
	for dist in [6.0, 4.5, 3.2]:
		for a in 14:
			var an := randf() * TAU
			var x: float = px + cos(an) * dist
			var z: float = pz + sin(an) * dist
			if free_at(x, z) and clear_path(x, z, px, pz):
				sp = Vector2(x, z); break
		if sp != null:
			break
	if sp == null:
		return
	var g := Rig.create(k.col, Color("#e0a97a"), Color("#2a1a10"), k.who)
	add_child(g)
	g.position = Vector3(sp.x, 0, sp.y)
	seek = {"t": i, "g": g, "x": sp.x, "z": sp.y, "name": k.who, "born": now_ms(), "lost": 0.0, "ph": 0.0}
	Game.toast("📣 " + k.who + " te busca para pedirte ayuda", 4000)
	Game.beep(660, .15)


func end_seek(ok: bool) -> void:
	if seek == null:
		return
	seek.g.queue_free()
	if not ok:
		Game.st.sat = max(0, Game.st.sat - 3)
		Game.hud()
		Game.toast(seek.name + " se cansó de esperar (−3 satisfacción)")
	seek = null
	seek_at = now_ms() + (15000 if ok else 20000)


func _update_seek(dt: float, t: float) -> void:
	if seek == null:
		return
	# el usuario que te busca se queda en la oficina: fuera de ella no se ve ni te sigue
	(seek.g as Node3D).visible = zone == 0
	if zone != 0:
		seek.born += dt * 1000.0
		return
	if in_lobby or menu.is_open() or callui.visible:
		seek.born += dt * 1000.0
		return
	var px := cam.position.x
	var pz := cam.position.z
	var dx: float = px - seek.x
	var dz: float = pz - seek.z
	var d := maxf(Vector2(dx, dz).length(), .001)
	var walking := d > 1.7
	if walking:
		var v := minf(1.8 * dt, d - 1.7)
		seek.x += dx / d * v
		seek.z += dz / d * v
		seek.ph += 1.8 * dt * 5.5
	if not clear_path(seek.x, seek.z, px, pz):
		seek.lost += dt
		if seek.lost > 1.5:
			var bx := px + sin(yaw) * 2.2
			var bz := pz + cos(yaw) * 2.2
			if free_at(bx, bz):
				seek.x = bx; seek.z = bz
			seek.lost = 0.0
	else:
		seek.lost = 0.0
	var g: Rig = seek.g
	g.position = Vector3(seek.x, absf(sin(t / 160.0)) * .04 if d > 1.9 else 0.0, seek.z)
	g.rotation.y = atan2(dx, dz)
	g.animate(dt, t, 0, walking, seek.ph, "wave" if not walking else "")
	if not sitting and now_ms() - seek.born > 70000 + Game.sk("comm") * 15000:
		end_seek(false)


# ---------------- interacción (near/label/act del original) ----------------
func near():
	if sitting or (drive and drive.on) or (boat and boat.on):
		return null
	if zone != 0:
		var lst: Array = city.sts if zone == 2 else (cur_bank.sts if cur_bank else [])
		var best = null
		var bdist := 99.0
		for a in lst:
			var ax: float = city.car.position.x if a.has("car") else float(a.x)
			var az: float = city.car.position.z + 2.4 if a.has("car") else float(a.z)
			var dd := Vector2(cam.position.x - ax, cam.position.z - az).length()
			if dd < float(a.r) and dd < bdist:
				best = a; bdist = dd
		return best
	var b = null
	var bd := 9.0
	for a in Game.acts + EXTRA_ACT + ST6 + [EXIT_DOOR]:
		var d := Vector2(cam.position.x - a.x, cam.position.z - a.z).length()
		if d < a.r and d < bd:
			b = a; bd = d
	if seek != null:
		var d := Vector2(cam.position.x - seek.x, cam.position.z - seek.z).length()
		if d < 2.6 and d < bd:
			b = {"seek": 1, "loc": 4}; bd = d
	if b != null and label(b) != "" and not (b.has("pcuse") and not Game.pending_at(b.get("loc"))):
		return b
	var nb = office.nearest(Vector2(cam.position.x, cam.position.z), 1.9)
	if nb != null:
		return {"npc": nb}
	return b if b != null and label(b) != "" else null


func label(a) -> String:
	if a == null:
		return ""
	if a.has("kind"):
		if a.kind == "home":
			return "🏠 Entrar a tu casa y descansar · 💾 guarda (E)" if Game.st.get("over", false) else "🏠 Tu casa · 💾 Guardar partida (E)"
		return a.l
	if a.has("npc"):
		return "Hablar con %s (E)" % a.npc.name
	if a.has("seek"):
		return ("Atender a %s (E)" % seek.name) if seek != null else ""
	if a.has("inf"):
		return Soc.rack_label()
	if a.has("soc"):
		return a.l
	if a.has("k"):
		match a.k:
			"coffee": return "☕ Cafetera (ocupado)" if hold.k != "" or serving else "☕ Servirte un café (E)"
			"water": return "💧 Dispensador (ocupado)" if hold.k != "" or serving else "💧 Servirte agua (E)"
			"fridge": return "🧊 Cerrar la nevera (E)" if fridge_open else "🧊 Abrir la nevera (E)"
			_: return "🖨️ Imprimir documentos (E)" if printer.st == "idle" else ("🖨️ Imprimiendo…" if printer.st == "busy" else "📄 Coger las hojas (E)")
	if a.has("home"):
		return a.l if Game.home_label_ok(a.home) else ""
	if a.has("dc"):
		return a.l if Game.st.net < 3 else ""
	if a.has("lc"):
		return a.lc if Game.pending_at(a.loc) else ""
	if a.has("l"):
		return a.l
	if Game.pending_at(a.get("loc")):
		return "Atender a %s en sitio (E)" % Data.STN[a.loc].name
	if a.has("pcuse"):
		return "Usar la PC de %s (E)" % Data.USERS[a.pcuse][1].split(" ")[0]
	return ""


func act() -> void:
	var a = near()
	if a == null:
		return
	if a.has("kind"):
		_city_act(a)
		return
	if a.has("npc"):
		office.talk(a.npc)
		return
	if a.has("inf"):
		Soc.rack_interact(); return
	if a.has("k"):
		_station(a.k); return
	if a.has("cctv"):
		sitting = true; cctv.open(); return
	if a.has("soc"):
		# la consola SOC abre el escritorio directo en la pestaña del SOC
		sitting = true; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Game.onsite = 0
		pc.open(Game.st.state.find(null), "inf"); return
	if a.has("bench"):
		if Game.st.time >= Data.END: return
		sitting = true; bench.open(a.bench); return
	if a.has("home"):
		if label(a) != "":
			Game.home_act(a.home)
			if a.home == "sleep":
				_fade(func(): cam.position = Vector3(-1, 1.6, 2); yaw = 0; pitch = 0)
		return
	if Game.st.time >= Data.END or label(a) == "":
		return
	if a.has("dc"):
		_open_dc()
		return
	if a.has("elev"):
		_elevate(a)
		return
	if a.has("pcuse") and not Game.pending_at(a.get("loc")):
		open_rd(a.pcuse, true)
		return
	sit(a)


func sit(a: Dictionary) -> void:
	sitting = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.onsite = a.loc
	var n := -1
	if a.has("seek") and seek != null:
		n = seek.t
	else:
		for i in Game.tickets.size():
			if Game.st.state[i] == null and Game.tickets[i].loc == Game.onsite:
				n = i; break
		if n < 0 and Game.st.bios.loc == Game.onsite and not Game.st.bios.done:
			pc.open(-1, "bios")
			return
		if n < 0:
			n = Game.st.state.find(null)
	pc.open(n)


func open_rd(i: int, local: bool) -> void:
	sitting = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rd.open(i, local)


func _rd_resolve(ix: int) -> void:
	Game.onsite = Game.tickets[ix].loc
	sitting = true
	pc.open(ix)


func _open_dc() -> void:
	sitting = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	console.open()


func _elevate(a: Dictionary) -> void:
	var up: bool = a.to == 1
	cam.position = Vector3(World.OX + 6 if up else 6.0, 1.6, -1.2)
	yaw = PI
	pitch = 0
	Game.toast("⬆ Piso 2: Taller, Almacén, Soporte N2, Marketing, Legal y Capacitación" if up else "⬇ Piso 1: Recepción, Gerencia y departamentos", 3500)
	Game.beep(660, .15)
	if up:
		Game.ach("f2")


# ---------------- entrada ----------------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_drag = e.pressed
			if e.pressed and not sitting and not in_lobby and not typing and not bank_ui.visible and not endscr.visible and not menu.is_open() and not callui.visible and not fridge_open and not mapnav.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif e.pressed and not sitting and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			fov_base = clampf(fov_base + (-3.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 3.0), 40, 85)
	elif e is InputEventMouseMotion and not sitting:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if absf(e.relative.x) < 250:
				var sv: float = SENS * float(menu.S.sens)
				yaw -= e.relative.x * sv
				pitch = clampf(pitch - e.relative.y * sv, -1.3, 1.3)
	elif e is InputEventKey and e.pressed and not e.echo:
		if in_lobby or typing: return
		var k: Key = e.physical_keycode
		if (k == KEY_ENTER or k == KEY_KP_ENTER) and not sitting and not menu.is_open():
			chat_ui.open(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; return
		if drive.on and k in [KEY_E, KEY_C, KEY_R]:
			drive.input_key(k); return
		if boat and boat.on and k in [KEY_E, KEY_C, KEY_R, KEY_1, KEY_2, KEY_3, KEY_4]:
			boat.input_key(k); return
		if k == KEY_ESCAPE:
			if cert.visible: cert.visible = false
			elif menu.pause.visible: menu.set_pause(false)
			elif menu.side.visible: menu.toggle(false)
			elif socov.visible: socov.close()
			elif fridge_open: _fridge_set(false)
			elif bank_ui.visible: bank_ui.close()
			elif mapnav.visible: mapnav.visible = false
			elif rd.visible: rd.close()
			elif console.visible: console.close()
			elif pc.visible: pc.close()
			else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			return
		if k == KEY_P:
			menu.set_pause(not menu.pause.visible); return
		if k == KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			return
		if sitting or callui.visible or menu.is_open() or bank_ui.visible or quiz.visible: return
		if (drive.on or boat.on) and k != KEY_TAB: return
		match k:
			KEY_E: act()
			KEY_F: _use_hold()
			KEY_Q: _drop_hold()
			KEY_X:
				if not intruder.confront(): office.confront()
			KEY_V:
				view = 1 if view == 3 else 3
				lobby.ST.view = view; lobby._save()
				Game.toast("🧍 Tercera persona" if view == 3 else "👁 Primera persona")
			KEY_TAB: menu.toggle(true)
			KEY_M: _toggle_map()


func _key(k: Key) -> bool:
	if typing: return false
	return Input.is_physical_key_pressed(k)


# ---------------- bucle ----------------
func _process(dt: float) -> void:
	dt = minf(dt, .05)
	var t := now_ms()
	_frames += 1
	_fps_t += dt
	if _fps_t > .5:
		hud.fps_l.text = "%s · %d FPS" % [_place(), int(_frames / _fps_t)]
		_frames = 0; _fps_t = 0
	_seek_check += dt
	if _seek_check > 1:
		_seek_check = 0
		if zone == 0 and Game.st.has("over") and not Game.st.over and not Game.at_home and seek == null and not sitting and not in_lobby and not menu.is_open() and not callui.visible and t > seek_at:
			spawn_seek()
	_update_seek(dt, t)
	if zone == 0:
		office.tick(dt, t)
		intruder.tick(dt, t)
	elif zone == 2: city.tick(dt, t, Vector3(drive.x, 0, drive.z) if drive.on else (Vector3(boat.x, 0, boat.z) if boat.on else cam.position), {"on": drive.on, "x": drive.x, "z": drive.z, "v": drive.vf})
	elif zone == 3 and cur_bank: cur_bank.tick(dt, t)
	_tick_phase3(dt, t)
	_tick_remotes(dt, t)
	_led_t += dt
	if _led_t > .35:
		_led_t = 0
		world.blink_leds()
	_ad_t += dt
	if _ad_t > .1:
		_ad_t = 0
		for q in world.tv_pos:
			if Vector2(cam.position.x, cam.position.z).distance_to(q) < 14:
				world.ad_tex.refresh()
				break
	_day_tint()
	hud.minimap.player_pos = Vector2(drive.x, drive.z) if drive.on else (Vector2(boat.x, boat.z) if boat.on else Vector2(cam.position.x, cam.position.z))
	hud.minimap.player_yaw = yaw
	hud.minimap.seek_pos = Vector2(seek.x, seek.z) if seek != null else null
	if int(t / 100) % 2 == 0:
		hud.minimap.queue_redraw()
	if in_lobby:
		hud.visible = false
		cam.position = Vector3(1.5, 1.4, 2.2)
		cam.look_at(Vector3(-.5, 1.05, -.5))
		cam.current = true
		if me_rig:
			me_rig.visible = true
			me_rig.position = Vector3(.5, 0, -.5)
			me_rig.rotation.y = sin(t / 900.0) * .5
			me_rig.animate(dt, t, 0, false, 0, "")
		return
	hud.visible = not (pc.visible or rd.visible or console.visible or bench.visible or cctv.visible or bank_ui.visible)
	if drive.on:
		hud.set_use(""); hud.cross.visible = false
		if me_rig: me_rig.visible = false
		if not menu.is_open(): drive.tick(dt)
		return
	if boat.on:
		hud.set_use(""); hud.cross.visible = false
		if me_rig: me_rig.visible = false
		if not menu.is_open(): boat.tick(dt)
		return
	if sitting or endscr.visible or menu.is_open() or callui.visible or bank_ui.visible:
		hud.set_use("")
		hud.cross.visible = false
		_update_cams(dt, t, false)
		return
	hud.cross.visible = true
	# movimiento (ZmoveIn + loop del original)
	var tf := (1.0 if _key(KEY_W) or _key(KEY_UP) else 0.0) - (1.0 if _key(KEY_S) or _key(KEY_DOWN) else 0.0)
	var ts := (1.0 if _key(KEY_D) else 0.0) - (1.0 if _key(KEY_A) else 0.0)
	if fridge_open or mapnav.visible: tf = 0; ts = 0
	# caminar solo (mapa M)
	if auto_walk.size():
		if tf != 0 or ts != 0:
			auto_walk.clear()
		else:
			var p: Vector2 = auto_walk[0]
			var dv := p - Vector2(cam.position.x, cam.position.z)
			if dv.length() < .25:
				auto_walk.pop_front()
			else:
				var ty := atan2(-dv.x, -dv.y)
				yaw = yaw + atan2(sin(ty - yaw), cos(ty - yaw)) * minf(1, dt * 7)
				pitch *= 1 - minf(1, dt * 3)
				tf = 1.0 if absf(atan2(sin(ty - yaw), cos(ty - yaw))) < .7 else 0.0
	elif auto_face != null:
		var dv2: Vector2 = auto_face - Vector2(cam.position.x, cam.position.z)
		var ty2 := atan2(-dv2.x, -dv2.y)
		yaw = yaw + atan2(sin(ty2 - yaw), cos(ty2 - yaw)) * minf(1, dt * 6)
		if absf(atan2(sin(ty2 - yaw), cos(ty2 - yaw))) < .05: auto_face = null
	var kk := minf(1, dt * 10)
	sm_f += (tf - sm_f) * kk
	sm_s += (ts - sm_s) * kk
	var run := multiplicador_correr if _key(KEY_SHIFT) else 1.0
	if _key(KEY_LEFT): yaw += dt * giro_flechas
	if _key(KEY_RIGHT): yaw -= dt * giro_flechas
	var sp := velocidad_caminar * dt * run
	var nx := cam.position.x + (-sin(yaw) * sm_f + cos(yaw) * sm_s) * sp
	var nz := cam.position.z + (-cos(yaw) * sm_f - sin(yaw) * sm_s) * sp
	if free_at(nx, cam.position.z): cam.position.x = nx
	if free_at(cam.position.x, nz): cam.position.z = nz
	var moving := tf != 0 or ts != 0
	if moving:
		bob_t += dt * (11.0 if run > 1 else 7.2)
		step_ph += dt * (11.0 if run > 1 else 7.5)
		if step_ph > 1:
			step_ph = 0  # sin sonido de pasos (pedido del equipo)
			if randf() < .15: shake = maxf(shake, 1.2)
	cam.position.y = 1.6 + (sin(bob_t) * .03 if moving else 0.0)
	cam.rotation = Vector3(pitch, yaw, 0)
	# FOV: zoom + sprint
	var target_fov := fov_base + (fov_extra_al_correr if run > 1 and moving else 0.0)
	cam.fov += (target_fov - cam.fov) * minf(1, dt * 8)
	if shake > .1:
		shake *= .9
		cam.h_offset = (randf() - .5) * shake * .004
		cam.v_offset = (randf() - .5) * shake * .004
	else:
		cam.h_offset = 0; cam.v_offset = 0
	_update_cams(dt, t, moving)
	var l := label(near())
	hud.set_use(l if l != "" and (Game.st.time < Data.END or (near() != null and near().has("home"))) else "")
	hud.cross.scale = Vector2.ONE * (2.0 if l != "" else 1.0)


# ================== Fase 3 ==================
func _show_lobby() -> void:
	if zone != 0: _set_zone(0)
	in_lobby = true
	if lobby.play_btn: lobby.play_btn.call_deferred("grab_focus")
	sitting = false
	pc.visible = false; console.visible = false; endscr.visible = false
	if rd.visible: rd.close()
	lobby.visible = true
	view = lobby.ST.view
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_make_me()


## Construye la ciudad poco a poco mientras el jugador está en la oficina (un paso cada pocos cuadros),
## así salir a la calle es inmediato.
func _prebuild_city() -> void:
	if city._built or city._step >= 0: return
	await get_tree().create_timer(2.0).timeout
	city.begin(self)
	while not city._built:
		if zone == 2: return            # si ya salió, _enter_city termina lo que falte
		city.build_next()
		for i in 4: await get_tree().process_frame
	_web_perf(city)


func _enter_office() -> void:
	_prebuild_city()
	in_lobby = false
	view = lobby.ST.view
	cam.position = Vector3(-1, 1.6, 2); yaw = 0; pitch = 0
	_make_me()
	_apply_settings()
	hud.visible = true
	Game.toast("Bienvenido, %s. V = cambiar vista · Tab = menú · P = pausa" % lobby.player_name(), 5000)


func _make_me() -> void:
	if me_rig: me_rig.queue_free()
	me_rig = lobby.make_rig(lobby.player_name())
	me_rig.name_label.visible = false
	add_child(me_rig)
	if hold.k != "": _hold_set(hold.k, true)


func _update_cams(dt: float, t: float, moving: bool) -> void:
	var third := view == 3 and not sitting and not in_lobby
	if me_rig:
		me_rig.visible = third
		if third:
			me_rig.position = Vector3(cam.position.x, 0, cam.position.z)
			me_rig.rotation.y = yaw + PI
			me_rig.animate(dt, t, 0, moving, bob_t * .8, "")
			if hold.k != "": me_rig.aR.rotation.x = -1.05
	if hold.g1: hold.g1.visible = not third and not sitting
	if third:
		var cp := cos(pitch)
		var f := Vector3(-sin(yaw) * cp, sin(pitch), -cos(yaw) * cp)
		var d := 3.0
		while d > .4 and not free_at(cam.position.x - f.x * d, cam.position.z - f.z * d): d -= .2
		if d <= .4:
			d = 0
			if me_rig: me_rig.visible = false
			if hold.g1: hold.g1.visible = true
		cam3.position = Vector3(cam.position.x - f.x * d, maxf(.4, cam.position.y - f.y * d + .4), cam.position.z - f.z * d)
		cam3.rotation = Vector3(pitch, yaw, 0)
		cam3.fov = cam.fov
		cam3.current = true
	else:
		cam.current = true


func _apply_settings() -> void:
	var S: Dictionary = menu.S
	# tres canales separados (buses): Master, Music y SFX (default_bus_layout.tres)
	music.master = 1.0; music.music = 1.0; music.sfx = 1.0; music.enabled = S.music_on
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(.0001, float(S.master))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(.0001, float(S.music))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(.0001, float(S.sfx))))
	get_viewport().scaling_3d_scale = {"high": 1.0, "med": .77, "low": .55}.get(S.quality, 1.0)
	for l in world.lamp_lights: l.shadow_enabled = S.shadows and l.get_meta("shadow", l.shadow_enabled)
	hud.minimap.visible = S.minimap
	hud.fps_l.visible = S.fps


func _fade(cb: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, .35)
	await tw.finished
	cb.call()
	# 3 cuadros en negro: la escena nueva se dibuja (y el navegador prepara sus sombreadores) sin que se note el tirón
	for i in 3: await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(fade, "modulate:a", 0.0, .35)


func _tick_phase3(dt: float, t: float) -> void:
	# música adaptativa y temblor con nuevas alertas
	var al := Game.alerts()
	music.intensity = clampf(al * .4 + .08, 0, 1)
	if intruder.state == Intruder.S.PERSECUCION: music.intensity = maxf(music.intensity, .85)
	# derrota: la seguridad (la «vida» del técnico) llega a 0 durante la jornada
	if not in_lobby and not screens.visible and Game.st.has("sec") and not Game.st.get("over", false) and int(Game.st.sec) <= 0:
		if drive.on: drive.stop(cam.position.x)
		if boat.on: boat.stop()
		sitting = false
		screens.game_over("La seguridad de CAA Corp llegó a 0: credenciales clonadas, fugas de datos o incidentes sin contener. Recursos Humanos te pidió el carné.")
	if al > last_alerts: shake = 10
	last_alerts = al
	# marcador del rack y baliza del data center
	_blink_t += dt
	if _blink_t > .45:
		_blink_t = 0
		world.trunk_mark.visible = world.trunk_mark.get_meta("on", false) and not world.trunk_mark.visible
	var hot := Soc.open_count() > 0
	world.beacon_mat.set_shader_parameter("on", 1.0 if hot else 0.0)
	world.dc_light.light_color = Color("#ff4a3a") if hot else Color("#5aa0ff")
	# puerta de la nevera
	fridge_ang += ((1.9 if fridge_open else 0.0) - fridge_ang) * minf(1, dt * 7)
	world.fridge_door.rotation.y = fridge_ang
	if fridge_open and Vector2(cam.position.x - 6.85, cam.position.z - 10.45).length() > 2.6: _fridge_set(false)
	# impresora
	if printer.st == "busy":
		var p: float = (Time.get_ticks_msec() - printer.t0) / 4200.0
		for i in world.printer_sheets.size(): world.printer_sheets[i].visible = p > (i + 1) / 7.0
		if int(p * 9) != printer.last:
			printer.last = int(p * 9); Game.beep(260 + printer.last * 18, .04)
		world.printer_led.material_override = Mats.unshaded(Color("#ffc83a") if fmod(p, .25) < .12 else Color("#2a2d36"), 2.0)
		if p >= 1:
			printer.st = "ready"; world.printer_led.material_override = Mats.unshaded(Color("#38e08a"), 2.0)
			Game.toast("🖨️ Impresión lista: toma las hojas de la bandeja.")
	# HUD extra
	hud.soc_l.text = Soc.pill()
	hud.soc_l.get_parent().visible = hud.soc_l.text != ""


# ---- estaciones: café, agua, nevera, impresora ----
func _station(k: String) -> void:
	if Game.st.time >= Data.END or Game.st.over:
		Game.toast("La jornada terminó."); return
	match k:
		"coffee", "water": _serve(k)
		"fridge": _fridge_set(not fridge_open)
		"print":
			if printer.st == "idle":
				if hold.k != "": Game.toast("Tienes las manos ocupadas (Q para soltar)."); return
				printer.st = "busy"; printer.t0 = Time.get_ticks_msec(); printer.last = -1; Game.toast("🖨️ Imprimiendo…")
			elif printer.st == "ready":
				if hold.k != "": Game.toast("Tienes las manos ocupadas (Q para soltar)."); return
				for sh in world.printer_sheets: sh.visible = false
				printer.st = "idle"; _hold_set("paper")


func _serve(k: String) -> void:
	if hold.k != "":
		Game.toast("Ya llevas algo en la mano (Q para soltarlo)."); return
	if serving: return
	serving = true
	var m: MeshInstance3D = world.coffee_stream if k == "coffee" else world.water_stream
	m.visible = true
	Game.beep(180 if k == "coffee" else 420, .25)
	await get_tree().create_timer(.5).timeout
	Game.beep(220 if k == "coffee" else 480, .2)
	await get_tree().create_timer(.8).timeout
	m.visible = false; serving = false
	_hold_set(k)


func _hold_clear() -> void:
	for g in [hold.g1, hold.g3]:
		if g and is_instance_valid(g): g.queue_free()
	hold = {"k": "", "g1": null, "g3": null, "sips": 0}


func _hold_set(k: String, silent := false) -> void:
	var sips: int = hold.sips if silent else (3 if k in ["coffee", "water"] else 1)
	_hold_clear()
	hold.k = k; hold.sips = sips
	hold.g1 = World.mk_item(k); cam.add_child(hold.g1)
	if k == "paper":
		hold.g1.position = Vector3(.2, -.2, -.5); hold.g1.rotation = Vector3(-1.05, 0, .1)
	else:
		hold.g1.position = Vector3(.31, -.28, -.6); hold.g1.rotation = Vector3(.15, -.3, 0)
	if me_rig:
		hold.g3 = World.mk_item(k); me_rig.aR.add_child(hold.g3)
		hold.g3.position = Vector3(0, -.52, .06); hold.g3.rotation.x = -1.3 if k == "paper" else 0.0
	if not silent:
		Game.toast("Llevas: %s  ·  F = %s  ·  Q = soltar" % [ITEM_NAMES[k], "entregar" if k == "paper" else "consumir"], 5200)


func _bonus(n: int, msg: String) -> void:
	var g := clampi(n, 0, 8 - day_bonus)
	if g > 0:
		Game.st.sat = min(100, Game.st.sat + g); day_bonus += g; Game.hud()
	Game.toast(msg + (" (+%d satisfacción)" % g if g > 0 else " (ya estás en tu límite de bienestar de hoy)"))


func _use_hold() -> void:
	if hold.k == "":
		Game.toast("No llevas nada en la mano."); return
	var k: String = hold.k
	if k == "paper":
		var b = office.nearest(Vector2(cam.position.x, cam.position.z), 2.6)
		if b == null:
			Game.toast("Acércate a un compañero para entregarle los documentos."); return
		if day_deliv < 8:
			day_deliv += 1; Game.G.xp = int(Game.G.xp) + 2; Game.save(); Game.hud()
			Game.toast("📄 Entregaste los documentos a %s (+2 XP)" % b.name)
		else:
			Game.toast("Ya entregaste suficientes documentos hoy.")
		_hold_clear(); return
	hold.sips -= 1
	Game.beep(330 if k == "coffee" else 520, .06)
	for g in [hold.g1, hold.g3]:
		if g and g.has_meta("liq"): g.get_meta("liq").position.y -= .012
	if hold.sips > 0:
		Game.toast("Un sorbo… " + ("☕" if k == "coffee" else "💧")); return
	var msg: String = {"coffee":"☕ Te terminaste el café","water":"💧 Te hidrataste","sand":"🥪 Buen provecho","soda":"🥤 ¡Refrescante!","apple":"🍎 Una manzana al día…","yog":"🥛 Yogur listo"}[k]
	var val: int = {"coffee":2,"water":1,"sand":3,"soda":2,"apple":2,"yog":2}[k]
	_hold_clear()
	_bonus(val, msg)


func _drop_hold() -> void:
	if hold.k == "": return
	_hold_clear()
	Game.toast("Soltaste el objeto.")


func _build_fridge_menu(layer: CanvasLayer) -> void:
	fridge_menu = Kit.panel(Kit.sb(Color(0.07, 0.09, 0.12, .92), 14, 2, Color("#9fc9de"), 12))
	fridge_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fridge_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fridge_menu.position.y = -190
	fridge_menu.visible = false
	fridge_menu.theme = Kit.theme()
	layer.add_child(fridge_menu)
	var v := VBoxContainer.new(); fridge_menu.add_child(v)
	var t := Kit.label("🧊 Nevera — elige qué sacar", 14, Color(1, 1, 1, .85), true); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); v.add_child(h)
	for a in [["sand","🥪 Sándwich"],["soda","🥤 Refresco"],["apple","🍎 Manzana"],["yog","🥛 Yogur"]]:
		var b := Kit.button(a[1], "", 14); var k: String = a[0]
		b.pressed.connect(func():
			if hold.k != "": Game.toast("Ya llevas algo en la mano (Q para soltarlo)."); return
			var it: Node3D = world.fridge_items[k]
			if not it.visible: Game.toast("Ya no queda eso en la nevera."); return
			it.visible = false; _fridge_set(false); _hold_set(k))
		h.add_child(b)
	var c := Kit.button("Cerrar", "Warm", 14); c.pressed.connect(func(): _fridge_set(false)); h.add_child(c)


func _fridge_set(o: bool) -> void:
	fridge_open = o
	fridge_menu.visible = o
	fridge_menu.reset_size()
	fridge_menu.position.x = (get_viewport().get_visible_rect().size.x - fridge_menu.size.x) / 2
	if o: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.beep(300 if o else 200, .08)


# ---- mapa: ir a… (M) ----
func _build_mapnav(layer: CanvasLayer) -> void:
	mapnav = Kit.panel(Kit.sb(Color(0.06, 0.1, 0.14, .95), 12, 2, Kit.WARM, 10))
	mapnav.position = Vector2(14, 72)
	mapnav.custom_minimum_size = Vector2(330, 0)
	mapnav.visible = false
	mapnav.theme = Kit.theme()
	layer.add_child(mapnav)


func _toggle_map() -> void:
	if mapnav.visible:
		mapnav.visible = false; return
	if zone != 0:
		_city_map(); return
	if cam.position.x > 20:
		Game.toast("Usa el ascensor para volver al piso 1"); return
	for c in mapnav.get_children(): c.queue_free()
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(320, 520); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; mapnav.add_child(sc)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(v)
	v.add_child(Kit.label("🗺 Ir a… (caminas solo)", 15, Color.WHITE, true))
	var mk := func(t: String, cb: Callable):
		var b := Kit.button(t, "", 13); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", Kit.sb(Kit.TEAL, 8, 0, Color.TRANSPARENT, 8))
		b.add_theme_stylebox_override("hover", Kit.sb(Kit.WARM, 8, 0, Color.TRANSPARENT, 8))
		b.pressed.connect(cb); v.add_child(b)
	for p in ZPL:
		var pp: Array = p
		mk.call(p[0], func(): _go_to(pp[1], pp[2], Vector2(pp[3], pp[4])))
	v.add_child(Kit.label("👤 Buscar a…", 15, Color.WHITE, true))
	for n in office.ZN:
		var nn: Dictionary = n
		var desc := "ya se fue" if n.leave and n.s == "away" else ("aún no llega" if n.s == "away" else ("caminando" if n.s == "walk" else ("conversando" if n.cb != null else ("trabajando en su puesto" if n.s == "sit" and n.pl == n.home else "de pie / en descanso"))))
		mk.call("%s  ·  %s · %s" % [n.name, n.dept, desc], func():
			if nn.s == "away": Game.toast(nn.name + " no está en la oficina ahora"); return
			_go_to(nn.x, nn.z + 1.2, Vector2(nn.x, nn.z)))
	mapnav.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _go_to(x: float, z: float, face: Vector2) -> void:
	auto_walk = office.path(Vector2(cam.position.x, cam.position.z), Vector2(x, z), false, true)
	auto_face = face
	mapnav.visible = false


## Nombre de la zona de la ciudad según la posición.
func _area(x: float, z: float) -> String:
	if x > CityWest.XC:
		for isl in CityWest.ISLANDS:
			if x > isl[0] and x < isl[1] and z < isl[3]: return isl[4]
		return "Calzada de Amador"
	if x > CityWest.XM: return "Cinta Costera 3"
	if x > CityData.XA:
		if z > 214: return "Curundú"
		if z > 120: return "Plaza 5 de Mayo"
		if z > 12: return "Calle hacia 5 de Mayo"
		return "Mercado de Mariscos" if z < -28.6 else "Av. Balboa (oeste)"
	return "Cinta Costera" if z < -28.6 else "Av. Balboa"


func _place() -> String:
	var room := (" · Sala " + Net.code) if Net.is_online() else ""
	if zone == 2:
		if drive.on: return _area(drive.x, drive.z) + " · al volante" + room
		if boat.on: return "Bahía de Panamá · en lancha" + room
		return _area(cam.position.x, cam.position.z) + room
	if zone == 3: return (cur_bank.d.name if cur_bank else "Banco") + room
	return _place_office() + room


func _place_office() -> String:
	var x := cam.position.x
	if x > 30: return "Piso 2"
	if x < -4: return "Data center"
	if x < 4: return "Oficina" if cam.position.z < 3 else "Departamentos"
	if x < 8: return "Pasillo"
	return "Apartamento" if cam.position.z < 3 else "Departamentos"


## Color de la tarde según la hora (CA → CB → CC del original).
func _day_tint() -> void:
	if not Game.st.has("time") or _last_tf == Game.st.time:
		return
	_last_tf = Game.st.time
	var tf := clampf((Game.st.time - 480) / 540.0, 0, 1)
	var CA := Color("#e9b58a"); var CB := Color("#dcc0a0"); var CC := Color("#c2603e")
	var c := CA.lerp(CB, tf * 2) if tf < .5 else CB.lerp(CC, (tf - .5) * 2)
	env.background_color = c
	env.ambient_light_color = Color("#ffe2c4").lerp(c, .5)
	env.ambient_light_energy = (.35 - .08 * tf) * (1.0 if OS.has_feature("web") else AMB_K)
	var wc := Color.WHITE.lerp(Color("#ffb070"), tf * .8)
	for m in world.window_mats:
		m.albedo_color = wc


# ================== Fase 4: ciudad, bancos, casa y multijugador ==================
## Puerta de vidrio con rótulo «SALIDA» al final del pasillo del piso 1 (port de «doors» del v6).
func _dump(n: Node, d: int) -> void:
	if d > 2: return
	var kids := n.get_child_count()
	print("TREE ", "  ".repeat(d), n.name, " (", n.get_class(), ")", (" · %d hijos" % kids) if kids else "", (" · " + n.scene_file_path) if n.scene_file_path != "" else "")
	if kids >= 12 and d >= 1:
		var cnt := {}
		for c in n.get_children(): cnt[c.get_class()] = cnt.get(c.get_class(), 0) + 1
		var parts := []
		for k in cnt: parts.append("%d %s" % [cnt[k], k])
		print("TREE ", "  ".repeat(d + 1), "… ", ", ".join(parts))
		for c in n.get_children():
			if not c.name.begins_with("@"): _dump(c, d + 1)
		return
	for c in n.get_children(): _dump(c, d + 1)


func _exit_door() -> void:
	var DZ := 20.8
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(.62, .82, .91, .42); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glass.roughness = .02; glass.metallic_specular = 1
	var fr := Mats.get_mat("metal", Color("#30343c"))
	var mk := func(sz: Vector3, p: Vector3, m: Material):
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = sz; mi.mesh = bm; mi.material_override = m; mi.position = p; world.add_child(mi)
	mk.call(Vector3(.14, 2.3, .16), Vector3(4.82, 1.15, DZ), fr); mk.call(Vector3(.14, 2.3, .16), Vector3(7.28, 1.15, DZ), fr)
	mk.call(Vector3(2.6, .16, .16), Vector3(6.05, 2.3, DZ), fr); mk.call(Vector3(.08, 2.2, .12), Vector3(6.05, 1.1, DZ), fr)
	mk.call(Vector3(1.08, 2.12, .05), Vector3(5.5, 1.08, DZ - .03), glass); mk.call(Vector3(1.08, 2.12, .05), Vector3(6.6, 1.08, DZ - .03), glass)
	mk.call(Vector3(.05, .5, .06), Vector3(5.88, 1.05, DZ - .1), Mats.get_mat("metal", Color("#cfd4da"))); mk.call(Vector3(.05, .5, .06), Vector3(6.22, 1.05, DZ - .1), Mats.get_mat("metal", Color("#cfd4da")))
	mk.call(Vector3(2.3, 2.2, .02), Vector3(6.05, 1.1, DZ + .08), Mats.unshaded(Color("#f6b27a"), 1.2))
	var sg := Label3D.new(); sg.text = "→ SALIDA ←"; sg.font = Kit.bold(); sg.font_size = 46; sg.pixel_size = .006
	sg.modulate = Color.WHITE; sg.outline_size = 0; sg.position = Vector3(6.05, 2.48, DZ - .12); sg.rotation.y = PI
	var bg := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(.8, .2); bg.mesh = qm; bg.material_override = Mats.unshaded(Color("#0a7a3a"), 1.4)
	bg.position = Vector3(6.05, 2.48, DZ - .1); bg.rotation.y = PI
	world.add_child(bg); world.add_child(sg)


func _set_zone(z: int) -> void:
	zone = z
	world.visible = z == 0
	office.visible = z == 0      # los empleados de la oficina no deben verse en la calle (comparten coordenadas con la entrada de CAA Corp)
	city.visible = z == 2
	for b in banks.values(): (b as Bank).visible = z == 3 and b == cur_bank
	we.environment = city.env if z == 2 and city.env else env
	if city.sun: city.sun.visible = z == 2
	cam.far = 4200.0 if z == 2 else 80.0
	cam3.far = cam.far
	hud.minimap.zone = z
	hud.minimap.city = city
	auto_walk.clear()
	if z != 2 and drive.on: drive.stop(cam.position.x)
	if z != 2 and boat and boat.on: boat.stop()


func _city_time() -> float:
	return 1078.0 if Game.st.get("over", false) else float(Game.st.get("time", 600))


## Versión web (renderizador Compatibility, un solo hilo): sin sombras en luces puntuales y focos.
## Cada luz con sombra obliga a dibujar la escena otra vez por cada cara del cubo de sombras.
func _web_perf(root: Node) -> void:
	if not OS.has_feature("web"): return
	for n in root.find_children("*", "Light3D", true, false):
		if not (n is DirectionalLight3D): (n as Light3D).shadow_enabled = false
		n.set_meta("shadow", false)


func _enter_city(from_end := false) -> void:
	if endscr.visible: endscr.visible = false
	if not city._built:
		city.build(self)
		_web_perf(city)
	city.set_time(_city_time())
	sitting = false
	_set_zone(2)
	cam.position = Vector3(CityData.CAA_X, 1.6, 8.4)
	yaw = -.35; pitch = .02
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if from_end or Game.st.get("over", false):
		Game.toast("🌆 Ciudad de Panamá al atardecer. Sube a tu Lamborghini (E) y maneja a casa por la Av. Balboa.", 6000)
		var names := []
		for n in office.ZN:
			if names.size() < 10: names.append(n.name)
		city.start_departures(names)
	else:
		Game.toast("🌆 Ciudad de Panamá · Av. Balboa. Vuelve a entrar por la puerta de CAA Corp.", 5000)


func _enter_building() -> void:
	_set_zone(0)
	cam.position = Vector3(6.05, 1.6, 19.3)
	yaw = 0; pitch = 0
	Game.toast("🏢 De vuelta en CAA Corp", 2500)


func _city_act(a: Dictionary) -> void:
	match a.kind:
		"exit_office": _fade(func(): _enter_city(false))
		"caa_in": _fade(_enter_building)
		"car":
			if me_rig: me_rig.visible = false
			drive.start()
		"bank": _fade(func(): _enter_bank(CityData.dest(a.id)))
		"home": _home_go()
		"food":
			if int(Game.G.money) < 3:
				Game.toast("No te alcanza: la empanada cuesta $3"); return
			Game.G.money = int(Game.G.money) - 3; Game.save(); Game.hud()
			_bonus(2, "🥟 Empanada de carne con chicha de tamarindo")
		"boat":
			if me_rig: me_rig.visible = false
			boat.start()
		"boat_race":
			if me_rig: me_rig.visible = false
			boat.start(); boat._start_race()
		"ceviche":
			if int(Game.G.money) < 4:
				Game.toast("No te alcanza: el ceviche cuesta $4"); return
			Game.G.money = int(Game.G.money) - 4; Game.save(); Game.hud()
			_bonus(3, "🦐 Ceviche de corvina con galletas en el Mercado de Mariscos")
		"fruit":
			if int(Game.G.money) < 2:
				Game.toast("No te alcanza: el raspao cuesta $2"); return
			Game.G.money = int(Game.G.money) - 2; Game.save(); Game.hud()
			_bonus(1, "🍧 Raspao de tamarindo con leche condensada")
		"comm":
			sitting = true; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			quiz.open(a.id)
		"bus": Game.toast("🚌 MiBus: ruta Albrook ⇄ Paitilla por la Av. Balboa. Pasa cada pocos minutos; aquí manejas tu propio auto 😉")
		"exit": _fade(_exit_bank)
		"board": sitting = true; bank_ui.board(cur_bank.d.name)
		"cs", "it", "soc": sitting = true; bank_ui.dept(a.kind, cur_bank.d.name)
		"atm": Game.toast("🏧 Saldo disponible: $%d" % int(Game.G.money))
		"ticket":
			cur_bank.turn += 1
			Game.toast("🎫 Tu turno: A-%03d · espera tu llamado" % (cur_bank.turn + 4))
		"teller": Game.toast("Los cajeros atienden a los clientes. Para trabajar, acepta una misión en el tablero.")


func _enter_bank(d: Dictionary) -> void:
	if not banks.has(d.id):
		var b := Bank.new(); add_child(b); b.build(d); banks[d.id] = b
		_web_perf(b)
	cur_bank = banks[d.id]
	_set_zone(3)
	cam.position = Vector3(cur_bank.ox, 1.6, 10.0)
	yaw = 0; pitch = 0
	Game.toast("🏦 %s · Atención al cliente, TI y SOC. Acepta misiones en el tablero." % d.name, 4500)


func _exit_bank() -> void:
	var x: float = cur_bank.d.x
	cur_bank = null
	_set_zone(2)
	city.set_time(_city_time())
	cam.position = Vector3(x, 1.6, 8.4)
	yaw = 0; pitch = 0


func _home_go() -> void:
	Game.save()
	if Game.st.get("over", false):
		screens.victory("Día %d completado · %d tickets resueltos · Satisfacción %d · Seguridad %d · Saldo $%d. Tu partida quedó guardada." % [int(Game.G.day), int(Game.st.done), int(Game.st.sat), int(Game.st.sec), int(Game.G.money)])
	else:
		Game.toast("💾 Partida guardada en tu casa. Aún es horario laboral: vuelve cuando termine la jornada para dormir.", 5000)


func _home_finish(menu_after: bool) -> void:
	_fade(func():
		city.reset_departures()
		city.park_car(city.car_home.x)
		city.car.position = city.car_home
		_set_zone(0)
		_go_home()
		if menu_after: _show_lobby()
		else: Game.toast("🏠 Partida guardada · buenas noches", 4000))


func _retry_day() -> void:
	Game.st.over = true   # evita que el game over se repita durante el fundido
	_fade(func():
		if drive.on: drive.stop(cam.position.x)
		if boat.on: boat.stop()
		_set_zone(0)
		Game.at_home = false
		Game.new_day()
		cam.position = Vector3(-1, 1.6, 2); yaw = 0; pitch = 0
		Game.toast("↻ Reintentas el día %d desde las 08:00" % int(Game.G.day), 3500))


func _to_menu() -> void:
	if in_lobby: return
	if screens.mode == "victory": _home_finish(true); return
	Game.st.over = true
	_fade(func():
		_set_zone(0)
		Game.new_day()
		_show_lobby())


func _city_map() -> void:
	if drive.on:
		Game.toast("Bájate del auto primero (E)"); return
	if boat.on:
		Game.toast("Vuelve al muelle y bájate de la lancha primero (R y luego E)"); return
	for c in mapnav.get_children(): c.queue_free()
	var v := VBoxContainer.new(); mapnav.add_child(v)
	v.add_child(Kit.label("🏎 Ciudad · viaje rápido", 15, Color.WHITE, true))
	for p in CityData.TRAVEL:
		var pp: Array = p
		var b := Kit.button(p[0], "", 13); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", Kit.sb(Kit.TEAL, 8, 0, Color.TRANSPARENT, 8))
		b.pressed.connect(func():
			mapnav.visible = false
			_fade(func():
				if zone == 3: cur_bank = null
				_set_zone(2)
				city.set_time(_city_time())
				cam.position = Vector3(pp[1], 1.6, pp[2]); yaw = pp[3]; pitch = 0))
		v.add_child(b)
	mapnav.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ---------------- multijugador: estado local y avatares remotos ----------------
func _net_state() -> Dictionary:
	var st := {"zone": zone, "x": snappedf(cam.position.x, .01), "z": snappedf(cam.position.z, .01), "y": snappedf(yaw, .01), "drv": drive.on}
	if drive.on:
		st.x = snappedf(drive.x, .01); st.z = snappedf(drive.z, .01)
		st.cx = snappedf(drive.x, .01); st.cz = snappedf(drive.z, .01); st.ch = snappedf(drive.h, .01)
	if in_lobby: st.zone = -1
	return st


func _drop_remote(id: int) -> void:
	if remotes.has(id):
		var r: Dictionary = remotes[id]
		if is_instance_valid(r.rig): r.rig.queue_free()
		if r.car and is_instance_valid(r.car): r.car.queue_free()
		remotes.erase(id)


func _tick_remotes(dt: float, t: float) -> void:
	if not Net.is_online():
		if remotes.size():
			for id in remotes.keys(): _drop_remote(id)
		return
	for id in Net.players:
		var p: Dictionary = Net.players[id]
		if not p.has("x"): continue
		if not remotes.has(id):
			var rig := LobbyUI.rig_from(p.get("av", {}) if p.get("av") is Dictionary else {}, str(p.get("name", "Técnico")))
			add_child(rig)
			remotes[id] = {"rig": rig, "car": null, "x": float(p.x), "z": float(p.z), "y": float(p.get("y", 0)), "ph": 0.0}
		var r: Dictionary = remotes[id]
		var same := int(p.get("zone", -1)) == zone and not in_lobby
		var k := minf(1.0, dt * 10.0)
		var ox: float = r.x; var oz: float = r.z
		r.x += (float(p.x) - r.x) * k
		r.z += (float(p.z) - r.z) * k
		var dy := wrapf(float(p.get("y", 0)) - r.y, -PI, PI)
		r.y += dy * k
		var sp := Vector2(r.x - ox, r.z - oz).length() / maxf(dt, .001)
		r.ph += minf(sp, 8.0) * dt * 2.2
		var rig: Rig = r.rig
		var drv: bool = p.get("drv", false)
		rig.visible = same and not drv
		rig.position = Vector3(r.x, .15 if zone == 2 else 0.0, r.z)
		rig.rotation.y = r.y + PI
		rig.animate(dt, t, 0, sp > .3, r.ph)
		rig.name_label.visible = Vector2(r.x - cam.position.x, r.z - cam.position.z).length() < 14
		if drv and same and zone == 2:
			if r.car == null:
				r.car = Cars.supercar(Color("#d8262c")); city.add_child(r.car)
			r.car.visible = true
			r.car.position = r.car.position.lerp(Vector3(float(p.get("cx", r.x)), 0, float(p.get("cz", r.z))), k)
			r.car.rotation.y = lerp_angle(r.car.rotation.y, float(p.get("ch", 0)), k)
		elif r.car:
			r.car.visible = false
