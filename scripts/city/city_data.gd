class_name CityData
extends RefCounted
## Datos de la ciudad (Fase 4): trazado de la Av. Balboa / Cinta Costera, destinos,
## departamentos y misiones de los bancos (port fiel del v8 del original).
##
## Orientación real: mirando al mar (−Z), Punta Paitilla queda a la izquierda (−X, este)
## y el Casco Antiguo / Cerro Ancón a la derecha (+X, oeste). Se maneja por la derecha.

const XA := 260.0          # fin del tramo original de la Av. Balboa (hacia el Casco Antiguo)
const XA_EXT := 2350.0     # fin de la Calzada de Amador (Isla Flamenco): ver west.gd
const NORTH_X := 330.0     # ramal norte hacia la Plaza 5 de Mayo y Curundú
const NORTH_Z := 335.0
const XB := -820.0         # extremo este (hacia Punta Paitilla)
const SEAWALL := -45.4
# carriles: calzada norte (+X, hacia el Casco) y calzada sur (−X, hacia Paitilla)
const BUS_LANE := -7.3
const LANES_W := [-10.7, -14.1]            # +X (hacia el oeste) · el carril -7.3 es «SOLO BUS»
const LANES_E := [-20.1, -23.5, -26.9]     # −X (hacia Paitilla)
const MEDIAN := [-15.8, -18.4]
const PARK_Z := -3.4
# intersecciones semaforizadas: [x, nombre de la calle]
const IX := [[12.0, "Calle 29 Este"], [-150.0, "Av. Federico Boyd"], [-420.0, "Calle Uruguay"]]
const BSTOPS := [40.0, -232.0, -482.0]
const CAA_X := 6.0

const DEST := [
	{"id": "bank1", "name": "Banco del Istmo", "icon": "🏦", "x": -190.0, "col": Color("#123a6e"), "acc": Color("#d0a030"), "sub": "Banca personal y empresarial", "ox": 5000.0, "tall": 0, "sign": "bank1_sign"},
	{"id": "bank2", "name": "Banca Canal Pacífico", "icon": "🏦", "x": -340.0, "col": Color("#0f5a46"), "acc": Color("#e8c050"), "sub": "Tu banco del Canal", "ox": 5200.0, "tall": 1, "sign": "bank2_sign"},
	{"id": "home", "name": "Mi casa · Punto de guardado", "icon": "🏠", "x": -545.0, "col": Color("#7a5a3a"), "acc": Color("#38e0ff")},
]
const CAA_DEST := {"id": "caa", "name": "CAA Corp (tu oficina)", "icon": "🏢", "x": 6.0, "acc": Color("#ff9a1f")}

const TRAVEL := [
	["🏢 Salida de CAA Corp · Av. Balboa", 6.0, 8.2, 0.0],
	["🌊 Cinta Costera (mirador)", -4.0, -41.0, 0.0],
	["🗿 Monumento a Balboa", -96.0, -38.0, 0.0],
	["🏦 Banco del Istmo", -190.0, 6.8, PI],
	["🏦 Banca Canal Pacífico", -340.0, 6.8, PI],
	["🏠 Mi casa · punto de guardado", -545.0, 6.8, PI],
	["🦐 Mercado de Mariscos y muelle de lanchas", 400.0, -27.0, PI],
	["🗽 Plaza 5 de Mayo", 318.0, 150.0, PI],
	["🏘️ Curundú · Infocentro", 318.0, 300.0, PI],
	["🌉 Cinta Costera 3 (viaducto)", 700.0, -32.0, -PI / 2],
	["🌴 Calzada de Amador · Museo", 1200.0, 4.0, PI],
	["🏝️ Isla Flamenco", 2250.0, -120.0, 0.0],
]

const DEPT := {
	"cs": {"n": "Atención al Cliente", "ic": "🧑‍💼", "role": "Ejecutivo de atención al cliente", "col": Color("#4aa0ff")},
	"it": {"n": "Departamento de TI", "ic": "🖧", "role": "Técnico de TI de sucursal", "col": Color("#40ff9a")},
	"soc": {"n": "SOC · Ciberseguridad", "ic": "🛡️", "role": "Analista SOC junior", "col": Color("#ff8aa8")},
}

const MIS := [
	{"id": "cs1", "dept": "cs", "t": "Cobro duplicado", "who": "Sra. Beatriz Mendoza", "money": 45, "xp": 25, "steps": [
		{"q": "La clienta reclama: «Me cobraron dos veces en el supermercado y nadie me ayuda». ¿Qué haces primero?", "ev": "09:14 SUPERMERCADO EL REY  $48.20  APROBADO\n09:14 SUPERMERCADO EL REY  $48.20  APROBADO", "o": [
			["Decirle que es normal y que espere al cierre del mes", 0.0, "Ignorar un doble cargo daña la confianza y puede ser un error real."],
			["Verificar su identidad, confirmar el doble cargo y abrir una disputa con número de caso", 1.0, "Correcto: validar, evidenciar y dar trazabilidad."],
			["Devolverle el dinero de tu bolsillo", 0.0, "No es un proceso válido ni auditable."],
			["Pedirle que vuelva mañana con el recibo", .3, "Se necesita evidencia, pero puedes iniciar la disputa hoy."]]},
		{"q": "Sigue molesta. ¿Cómo cierras la atención?", "o": [
			["Prometer devolución inmediata sin validar nada", 0.0, "No prometas lo que no controlas."],
			["Empatizar, explicar el plazo (5-10 días hábiles), dar el número de caso y confirmar su contacto", 1.0, "Expectativas claras y seguimiento: así se recupera la confianza."],
			["Transferirla a otra ventanilla", .2, "Evita el rebote: resuelve o escala con contexto."]]}]},
	{"id": "cs2", "dept": "cs", "t": "Tarjeta bloqueada", "who": "Sr. Ricardo Arosemena", "money": 50, "xp": 28, "steps": [
		{"q": "Un cliente dice que su tarjeta fue bloqueada en el extranjero y pide desbloquearla ya. No trae documentos.", "ev": "Estado: BLOQUEO PREVENTIVO (antifraude)\nIntento: compra USD 900 · País: distinto al habitual", "o": [
			["Desbloquearla porque el cliente lo pide", 0.0, "Sin validar identidad podrías habilitar un fraude."],
			["Validar identidad con dos factores (documento + código OTP al celular registrado) y luego desbloquear", 1.0, "Correcto: verificación multifactor antes de actuar."],
			["Pedirle su PIN para confirmar que es él", 0.0, "Nunca se solicita el PIN ni claves."],
			["Negarte a ayudar", .2, "Hay un proceso seguro para ayudarle."]]},
		{"q": "Ya desbloqueada, ¿qué consejo final le das?", "o": [
			["Que comparta el código OTP con quien lo llame del banco", 0.0, "El banco nunca pide el OTP."],
			["Activar avisos de viaje y no compartir jamás OTP, PIN ni claves", 1.0, "Educación al cliente = menos fraude."],
			["Ninguno, ya terminó", .3, "Una buena atención incluye prevención."]]}]},
	{"id": "cs3", "dept": "cs", "t": "Banca móvil para el abuelo", "who": "Don Anselmo (78 años)", "money": 40, "xp": 22, "steps": [
		{"q": "Don Anselmo no logra usar la app. Te ofrece su clave para que lo hagas tú.", "ev": "Cliente: sin experiencia digital\nSolicita: consultar saldo y pagar luz", "o": [
			["Aceptar su clave y hacerlo rápido", 0.0, "Nunca recibas ni uses claves de clientes."],
			["Guiarlo paso a paso en su teléfono con paciencia y ofrecer el modo asistido/cajero", 1.0, "Empatía y seguridad: él mantiene el control de su clave."],
			["Decirle que use solo ventanilla siempre", .3, "Válido, pero pierdes la oportunidad de enseñar."]]}]},
	{"id": "it1", "dept": "it", "t": "Cajero ATM sin conexión", "who": "Operaciones sucursal", "money": 60, "xp": 32, "steps": [
		{"q": "El ATM-04 muestra «fuera de servicio». ¿Qué revisas primero?", "ev": "C:\\> ping 10.20.5.1\nRequest timed out.\nSW-AGENCIA# show ip int brief\nGi0/12   unassigned   down   down", "o": [
			["Reiniciar el servidor central del banco", 0.0, "Medida desproporcionada: afecta a todos."],
			["Revisar el puerto Gi0/12 del switch y el cable hacia el ATM", 1.0, "Capa 1 primero: enlace down/down apunta a cable o puerto."],
			["Reinstalar el sistema del ATM", .1, "No hay evidencia de falla de software."]]},
		{"q": "El puerto aparece «err-disabled». ¿Qué haces?", "ev": "SW-AGENCIA# show interfaces status err-disabled\nGi0/12  err-disabled  psecure-violation", "o": [
			["Borrar la VLAN del ATM", 0.0, "Rompes la red de otros equipos."],
			["Verificar seguridad de puerto, corregir la MAC autorizada y hacer shutdown / no shutdown", 1.0, "Correcto: causa raíz y recuperación controlada."],
			["Desactivar la seguridad de puertos en todo el switch", .1, "Bajas la guardia de toda la red."]]}]},
	{"id": "it2", "dept": "it", "t": "Caja lenta en hora pico", "who": "Cajera Lía", "money": 50, "xp": 26, "steps": [
		{"q": "La terminal de caja va lentísima a las 9:30, con fila de clientes.", "ev": "CPU 98%  Disco 100%\nProceso: AVScan.exe (análisis completo programado 09:30)", "o": [
			["Desinstalar el antivirus", 0.0, "Dejas el equipo expuesto."],
			["Reprogramar el análisis fuera de horario y ajustar exclusiones aprobadas", 1.0, "Seguridad y rendimiento a la vez."],
			["Pedir que esperen a que termine", .2, "No resuelve la causa."]]}]},
	{"id": "it3", "dept": "it", "t": "Parches en ventana de mantenimiento", "who": "Jefatura de TI", "money": 70, "xp": 36, "steps": [
		{"q": "Hay parches críticos para el servidor de agencia. ¿Cómo procedes?", "ev": "Ventana de mantenimiento: sábado 22:00\nServicio: core de sucursal (alta criticidad)", "o": [
			["Instalar ya, en horario laboral, para ir rápido", 0.0, "Riesgo de caída en pleno servicio."],
			["Respaldo/snapshot, probar en pruebas, aprobar cambio y aplicar en la ventana con plan de reversa", 1.0, "Gestión de cambios y recuperación."],
			["Ignorar los parches para no arriesgar", .1, "Dejar vulnerabilidades críticas abiertas es peor."]]}]},
	{"id": "soc1", "dept": "soc", "t": "Phishing a cajeros", "who": "Alerta SIEM #4471", "money": 65, "xp": 34, "steps": [
		{"q": "Llegó un correo a 12 cajeros. ¿Cómo lo clasificas?", "ev": "From: soporte@banco-seguridad-ayuda.com\nAsunto: URGENTE: verifica tu usuario hoy\nLink: http://login-istmo.verifica-ya.ru/auth\nSPF: fail  · Adjunto: factura.zip", "o": [
			["Falso positivo: parece correo normal", 0.0, "Dominio externo, SPF fail y link .ru: señales claras de phishing."],
			["Verdadero positivo: phishing con credenciales y adjunto malicioso", 1.0, "Correcto: múltiples indicadores de compromiso."]]},
		{"q": "¿Qué acción de contención tomas?", "o": [
			["Borrarlo de tu buzón y seguir", .2, "Los otros 11 siguen expuestos."],
			["Bloquear dominio/URL, retirar el correo de todos los buzones, avisar a los usuarios y revisar quién hizo clic", 1.0, "Contención + erradicación + comunicación (NIST: Responder)."],
			["Esperar a que alguien reporte daños", 0.0, "Respuesta tardía = incidente mayor."]]}]},
	{"id": "soc2", "dept": "soc", "t": "Fuerza bruta en banca en línea", "who": "Alerta SIEM #4502", "money": 75, "xp": 38, "steps": [
		{"q": "Detectas esto en el portal de banca en línea. ¿Prioridad?", "ev": "02:11:05  FAIL  jlopez  185.220.x.x\n02:11:06  FAIL  jlopez  185.220.x.x\n... (480 intentos en 2 min)\n02:13:42  OK    jlopez  185.220.x.x", "o": [
			["Baja: son solo intentos fallidos", 0.0, "Hubo un inicio exitoso tras la ráfaga: posible compromiso."],
			["Alta: posible cuenta comprometida (éxito tras fuerza bruta)", 1.0, "Correcto: priorizar por impacto."]]},
		{"q": "¿Cómo contienes?", "o": [
			["Solo bloquear la IP", .5, "Ayuda, pero la cuenta ya pudo ser tomada."],
			["Bloquear IP, cerrar sesiones, forzar restablecimiento + MFA y revisar movimientos de la cuenta", 1.0, "Contención completa y verificación de impacto."],
			["Esperar al horario de oficina", 0.0, "Cada minuto cuenta en un compromiso activo."]]}]},
	{"id": "soc3", "dept": "soc", "t": "Transferencias fuera de horario", "who": "Caso interno #77", "money": 85, "xp": 42, "steps": [
		{"q": "Un empleado hizo transferencias inusuales a las 23:40. ¿Qué haces?", "ev": "USER: ops_mrojas  23:40  4 transferencias  USD 9,900 c/u\nDestino: cuentas nuevas · Sin ticket asociado", "o": [
			["Confrontar al empleado de inmediato", 0.0, "Podrías alertarle y perder evidencia."],
			["Preservar logs y evidencia, mantener cadena de custodia y escalar a Fraude, RRHH y Legal con discreción", 1.0, "Respuesta a incidentes interna: evidencia primero, sin alertar."],
			["Borrar los registros para evitar escándalo", 0.0, "Destruir evidencia es grave."],
			["Comentarlo con compañeros", 0.0, "Rompe la confidencialidad."]]}]},
]


static func mission(id: String) -> Dictionary:
	for m in MIS:
		if m.id == id: return m
	return {}


static func dest(id: String) -> Dictionary:
	for d in DEST:
		if d.id == id: return d
	return CAA_DEST if id == "caa" else {}
