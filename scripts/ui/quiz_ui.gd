class_name QuizUI
extends Control
## Misiones comunitarias de la zona oeste (Curundú, Plaza 5 de Mayo, Mercado de Mariscos):
## casos cortos de soporte y ciberseguridad con 2 decisiones, retroalimentación y pago.
signal closed

const MIS := {
	"info": {"t": "Infocentro de Curundú sin internet", "who": "Profesora Yaneth", "money": 50, "xp": 30, "steps": [
		{"q": "Los niños no pueden hacer las tareas: ninguna PC del Infocentro navega. ¿Qué revisas primero?", "ev": "C:\\> ipconfig\nDirección IPv4 . . : 169.254.12.40\nPuerta de enlace . :", "o": [
			["Reinstalar Windows en todas las PC", 0.0, "Desproporcionado: el problema es de red, no del sistema."],
			["La IP 169.254 indica que no hay DHCP: reviso el router y su conexión", 1.0, "Correcto: sin servidor DHCP las PC se asignan una IP automática inútil."],
			["Cambiar el navegador", 0.0, "El navegador no tiene que ver con no recibir IP."]]},
		{"q": "El router estaba apagado por un breaker. Ya hay internet. ¿Qué dejas configurado para los niños?", "o": [
			["Wi-Fi abierto sin clave para que sea fácil", 0.0, "Cualquiera podría usar la red o atacar los equipos."],
			["WPA2/WPA3 con clave, red de invitados separada y filtro de contenido", 1.0, "Seguridad y protección para menores en una sola medida."],
			["Anotar la clave del router en la pared", .1, "La clave de administración nunca se publica."]]}]},
	"kiosk": {"t": "SMS sospechoso en la Plaza 5 de Mayo", "who": "Señor Abdiel (kiosco de celulares)", "money": 40, "xp": 25, "steps": [
		{"q": "Un cliente le muestra un SMS: «Su cuenta será bloqueada, valide aquí: bit.ly/banco-pa». ¿Qué le recomiendas?", "ev": "De: +507 6xxx-xxxx\n«BANCO: su cuenta será bloqueada hoy. Valide en bit.ly/banco-pa»", "o": [
			["Abrir el enlace para ver si es real", 0.0, "Abrirlo ya expone al usuario a robo de credenciales."],
			["No abrirlo, reportarlo como smishing y llamar al banco al número oficial", 1.0, "Correcto: el banco nunca pide validar por SMS con enlaces acortados."],
			["Responder el SMS con sus datos para evitar el bloqueo", 0.0, "Eso es exactamente lo que busca el atacante."]]},
		{"q": "El cliente ya había escrito su clave en esa página. ¿Qué hace ahora?", "o": [
			["Nada, seguro no pasa nada", 0.0, "Las credenciales robadas se usan en minutos."],
			["Cambiar la clave desde la app oficial, activar 2FA y avisar al banco para bloquear movimientos", 1.0, "Respuesta rápida: contener, recuperar y notificar."],
			["Borrar el SMS y listo", .1, "Borrarlo no deshace el robo de la clave."]]}]},
	"pos": {"t": "Datáfono del Mercado sin conexión", "who": "Doña Lucy (puesto de ceviche)", "money": 35, "xp": 22, "steps": [
		{"q": "El datáfono de Doña Lucy dice «Sin conexión» y hay fila de clientes. ¿Qué revisas primero?", "ev": "POS: ERROR 05 · SIN CONEXIÓN\nWi-Fi: MERCADO_LIBRE (abierta)\nSeñal: 1 barra", "o": [
			["Pedirle a los clientes que paguen en efectivo para siempre", .2, "Es una salida temporal, no una solución."],
			["Conectar el datáfono a la red de datos móviles del equipo o al Wi-Fi privado del puesto", 1.0, "Correcto: una red abierta y débil no sirve para pagos."],
			["Resetear el datáfono de fábrica", 0.0, "Borrarías la configuración del comercio."]]},
		{"q": "¿Qué le aconsejas para que no vuelva a pasar?", "o": [
			["Usar siempre el Wi-Fi abierto del mercado", 0.0, "Las redes abiertas son inseguras para pagos con tarjeta."],
			["Tener un plan de datos de respaldo y nunca anotar el PIN del comercio en el aparato", 1.0, "Disponibilidad y seguridad del punto de venta."],
			["Dejar el datáfono a cargo de cualquier cliente", 0.0, "El terminal debe estar siempre bajo control del comercio."]]}]},
}

var panel: PanelContainer
var box: VBoxContainer
var cur: Dictionary = {}
var step := 0
var score := 0.0


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, .55); Kit.full_rect(dim); add_child(dim)
	panel = Kit.panel(Kit.sb(Color(0.11, 0.08, 0.13, .97), 16, 2, Kit.WARM, 22))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH; panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	box = VBoxContainer.new(); box.add_theme_constant_override("separation", 10); panel.add_child(box)


func open(id: String) -> void:
	if not MIS.has(id): return
	var done: Dictionary = Game.G.get("comm", {})
	cur = (MIS[id] as Dictionary).duplicate(true); cur["id"] = id; step = 0; score = 0.0
	visible = true
	if done.has(id):
		_head()
		_txt("Ya resolviste este caso hoy. ¡Gracias por ayudar a la comunidad! 🙌")
		_btn("Cerrar", close)
		return
	_show_step()


func close() -> void:
	visible = false
	closed.emit()


func _clear() -> void:
	for c in box.get_children(): c.queue_free()


func _head() -> void:
	_clear()
	box.add_child(Kit.label("🤝 " + str(cur.t), 22, Kit.WARM, true, true))
	box.add_child(Kit.label("Pide ayuda: " + str(cur.who), 14, Color(1, 1, 1, .7)))


func _txt(t: String, sz := 16) -> void:
	box.add_child(Kit.label(t, sz, Color.WHITE, false, true))


func _btn(t: String, cb: Callable, v := "") -> void:
	var b := Kit.button(t, v, 15); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(cb); box.add_child(b)


func _show_step() -> void:
	_head()
	var s: Dictionary = cur.steps[step]
	box.add_child(Kit.label("Paso %d de %d" % [step + 1, cur.steps.size()], 13, Color(1, 1, 1, .6)))
	_txt(s.q)
	if s.has("ev"):
		var ev := Kit.panel(Kit.sb(Color(0, 0, 0, .45), 8, 0, Color.TRANSPARENT, 10))
		ev.add_child(Kit.label(s.ev, 13, Color("#9affc0"), false, true))
		(ev.get_child(0) as Label).add_theme_font_override("font", Kit.mono())
		box.add_child(ev)
	for o in s.o:
		var oo: Array = o
		_btn(oo[0], func(): _answer(oo))


func _answer(o: Array) -> void:
	score += float(o[1])
	_head()
	var good := float(o[1]) >= .99
	_txt(("✅ " if good else ("🟡 " if float(o[1]) > 0 else "❌ ")) + str(o[2]))
	step += 1
	if step < cur.steps.size():
		_btn("Siguiente ▶", _show_step, "Warm")
		return
	var f: float = score / float(cur.steps.size())
	var money := int(round(float(cur.money) * f))
	var xp := int(round(float(cur.xp) * maxf(f, .3)))
	Game.G.money = int(Game.G.money) + money
	Game.G.xp = int(Game.G.xp) + xp
	var done: Dictionary = Game.G.get("comm", {})
	done[cur.id] = 1; Game.G.comm = done
	Game.save(); Game.hud(); Game.beep(880 if f > .7 else 440, .1)
	_txt("Caso cerrado · +$%d · +%d XP" % [money, xp], 18)
	_btn("Cerrar", close, "Warm")
