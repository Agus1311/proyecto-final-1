class_name ScreensUI
extends Control
## Pantallas del flujo del juego: GAME OVER (la seguridad llega a 0), VICTORIA (llegas a
## casa al final de la jornada) y CRÉDITOS (integrantes, roles y licencias de los assets).

signal retry
signal to_menu
signal rest

var box: VBoxContainer
var mode := ""

const TEAM := [
	["Agustín Batista", "Scrum Master · GameManager (jornada, estados, guardado) · build y releases"],
	["Carolina Guevara", "Tickets y Zoho Desk · HUD · taller de reparación · interfaz"],
	["Alexis Este", "Jugador y cámara (1.ª/3.ª persona) · colisiones · ciudad y manejo"],
	["Franklin Hernández", "Red Cisco y SOC · enemigo con FSM · QA y pruebas en otra PC"],
]
const ASSETS := [
	["Godot Engine 4.7.2", "Godot Engine contributors", "MIT"],
	["Space Grotesk (tipografía)", "Florian Karsten", "SIL Open Font License 1.1"],
	["JetBrains Mono (tipografía)", "JetBrains", "SIL Open Font License 1.1"],
	["DejaVu Sans (texto en señales y placas)", "DejaVu fonts team", "Licencia libre DejaVu (Bitstream Vera)"],
	["Texturas PBR, señales, placas y libreas", "Firewall Studio (procedurales, tools/*.py)", "Propias · CC BY 4.0"],
	["Modelos 3D, personajes y vehículos", "Firewall Studio (generados por código)", "Propios · CC BY 4.0"],
	["Efectos de sonido", "Firewall Studio (síntesis procedural)", "Propios · CC BY 4.0"],
	["Noto Color Emoji (emojis de la interfaz)", "Google", "SIL Open Font License 1.1"],
	["GNU FreeSans y GNU Unifont (símbolos)", "GNU FreeFont · Unifoundry", "GPL con excepción para fuentes"],
]


func _ready() -> void:
	Kit.full_rect(self)
	theme = Kit.theme()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color(0.06, 0.05, 0.09, .95); Kit.full_rect(bg); add_child(bg)
	var cc := CenterContainer.new(); Kit.full_rect(cc); add_child(cc)
	var pn := Kit.panel(Kit.sb(Color("#141019"), 18, 2, Kit.WARM, 28, 22))
	pn.custom_minimum_size = Vector2(720, 0)
	cc.add_child(pn)
	box = VBoxContainer.new(); box.add_theme_constant_override("separation", 12); pn.add_child(box)


func _clear() -> void:
	for c in box.get_children(): c.queue_free()


func _title(t: String, c: Color) -> void:
	var l := Kit.label(t, 40, c, true); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(l)


func _text(t: String, sz := 16, c := Color(1, 1, 1, .9)) -> void:
	var l := Kit.label(t, sz, c, false, true); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 660; box.add_child(l)


func _buttons(list: Array) -> void:
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	var first: Button
	for it in list:
		var b := Kit.button(it[0], "Warm" if first == null else "", 18)
		b.pressed.connect(it[1])
		b.focus_mode = Control.FOCUS_ALL
		h.add_child(b)
		if first == null: first = b
	first.call_deferred("grab_focus")


func _open(m: String) -> void:
	mode = m
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func game_over(reason: String) -> void:
	_clear(); _open("gameover")
	_title("GAME OVER", Kit.BAD)
	_text("❌ Despedido por brecha de seguridad", 22, Color.WHITE)
	_text(reason)
	_text("Día %d · %d tickets resueltos · Satisfacción %d · Seguridad %d" % [int(Game.G.day), int(Game.st.done), int(Game.st.sat), int(Game.st.sec)], 14, Color(1, 1, 1, .7))
	_buttons([["↻ Reintentar el día", func(): visible = false; retry.emit()], ["Menú principal", func(): visible = false; to_menu.emit()]])


func victory(text: String) -> void:
	_clear(); _open("victory")
	_title("¡JORNADA COMPLETADA!", Kit.OK)
	_text("🏁 Llegaste a casa: la meta del día", 22, Color.WHITE)
	_text(text)
	_buttons([["🛏 Descansar (siguiente día)", func(): visible = false; rest.emit()], ["Menú principal", func(): visible = false; to_menu.emit()]])


func credits() -> void:
	_clear(); _open("credits")
	_title("CRÉDITOS", Kit.WARM)
	_text("Mesa de Ayuda — CAA Corp · Firewall Studio · EID1028 Electiva II · Instructor: Jahir Agudo", 15)
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 18); g.add_theme_constant_override("v_separation", 6)
	box.add_child(g)
	for m in TEAM:
		g.add_child(Kit.label(m[0], 15, Color.WHITE, true))
		var r := Kit.label(m[1], 13, Color(1, 1, 1, .78), false, true); r.custom_minimum_size.x = 440; g.add_child(r)
	box.add_child(Kit.label("Assets y licencias", 17, Kit.WARM, true))
	var a := GridContainer.new(); a.columns = 3; a.add_theme_constant_override("h_separation", 14); a.add_theme_constant_override("v_separation", 4)
	box.add_child(a)
	for it in ASSETS:
		for k in 3:
			var l := Kit.label(it[k], 12, Color(1, 1, 1, .85) if k else Color.WHITE, k == 0, true)
			l.custom_minimum_size.x = [230.0, 230.0, 190.0][k]
			a.add_child(l)
	_text("Declaración de IA: el código, las texturas procedurales y la síntesis de audio se desarrollaron con asistencia de IA (Claude, de Anthropic). Ningún asset es de terceros salvo los indicados arriba.", 12, Color(1, 1, 1, .65))
	_buttons([["Volver al menú", func(): visible = false; to_menu.emit()]])
