extends Node
## Datos fijos del juego (portados 1:1 del HTML original).

# Ticket: p = prioridad (1..3), from, t = título, b = cuerpo, copy = es de la copiadora,
# o = opciones [texto, satisfacción, seguridad, resultado]
const POOL := [
	{"p":2,"from":"Marta (Contabilidad)","t":"Cuenta bloqueada","b":"No puedo entrar a mi usuario desde esta mañana y tengo cierre de mes. Dice que la cuenta está bloqueada.","o":[
		["Desbloquear en Active Directory y revisar el log de intentos fallidos",8,6,"Revisaste los eventos 4740 y era una contraseña vieja guardada en el celular."],
		["Restablecer la contraseña por chat sin verificar identidad",4,-10,"Alguien pudo suplantarla. Siempre valida la identidad primero."],
		["Pedirle que espere 30 minutos al desbloqueo automático",-8,0,"Marta pierde horas en pleno cierre."]]},
	{"p":3,"from":"Seguridad (alerta automática)","t":"Correo sospechoso reportado","b":"Tres empleados recibieron un correo de 'Microsoft 365' pidiendo verificar su cuenta con un enlace acortado.","o":[
		["Aislar el correo, bloquear el dominio y avisar a los usuarios",5,12,"Contuviste el phishing. Nadie hizo clic."],
		["Responder al remitente para pedir más información",0,-12,"Confirmaste que el buzón está activo. Mala idea."],
		["Ignorarlo, parece spam normal",2,-14,"Un usuario ingresó credenciales. Tocó rotar contraseñas."]]},
	{"p":1,"from":"Luis (Operaciones)","t":"Impresora no imprime","b":"La impresora del segundo piso muestra 'fuera de línea'. Es la única que imprime etiquetas.","o":[
		["Revisar cable de red, cola de impresión y reiniciar el spooler",9,0,"El spooler estaba trabado. Resuelto en 5 minutos."],
		["Reinstalar el driver en todas las PC",2,0,"Funcionó, pero tardaste demasiado para algo simple."],
		["Comprar una impresora nueva",-5,-2,"Gasto innecesario para una cola trabada."]]},
	{"p":3,"from":"Gerencia General","t":"Laptop de ejecutivo sin cifrar","b":"El auditor detectó que la laptop del gerente no tiene BitLocker activo y viaja con frecuencia.","o":[
		["Activar BitLocker, guardar la clave en AD y documentar",6,14,"Cumples con la política y reduces riesgo de fuga."],
		["Posponerlo hasta la próxima auditoría",0,-12,"Una laptop robada expondría datos sensibles."],
		["Activarlo sin respaldar la clave de recuperación",-6,4,"Queda cifrada, pero si falla el TPM perderán los datos."]]},
	{"p":2,"from":"Andrea (RRHH)","t":"Alta de nuevo empleado","b":"Mañana entra un analista. Necesita usuario, correo Microsoft 365, acceso a la carpeta de su área y una laptop.","o":[
		["Crear usuario con mínimo privilegio, grupo del área y licencia M365",8,8,"Alta correcta con permisos justos."],
		["Copiar los permisos de otro analista antiguo",4,-8,"Heredó accesos que no necesita."],
		["Darle administrador local para que 'no moleste'",5,-14,"Violó el principio de mínimo privilegio."]]},
	{"p":2,"from":"Carlos (Ventas)","t":"Computadora muy lenta","b":"Mi PC tarda 10 minutos en arrancar y el ventilador suena fuerte desde hace días.","o":[
		["Revisar programas de inicio, disco, malware y temperatura",9,3,"Había un minero de cripto. Eliminado y reportado."],
		["Formatear sin hacer respaldo",-6,0,"Carlos perdió su carpeta de cotizaciones."],
		["Decirle que reinicie más seguido",-7,-4,"No resolvió nada y el malware siguió."]]},
	{"p":3,"from":"Soporte remoto","t":"Proveedor pide acceso remoto","b":"Un proveedor de software pide conectarse a un servidor por TeamViewer 'urgente' y sin ticket previo.","o":[
		["Verificar con el responsable, acceso temporal y sesión grabada",4,12,"Acceso controlado y auditable."],
		["Darle la clave porque dice que es urgente",5,-16,"Acceso no autorizado a un servidor. Incidente grave."],
		["Negarlo sin explicar nada",-4,2,"Seguro, pero el proveedor quedó molesto."]]},
	{"p":1,"from":"Sofía (Legal)","t":"Outlook no sincroniza","b":"Mi correo dejó de actualizarse en el escritorio, en el celular sí llega.","o":[
		["Recrear el perfil de Outlook y revisar la cuota del buzón",8,0,"El OST estaba corrupto."],
		["Cambiarle el correo a otra cuenta",-6,-3,"Rompiste su historial y firmas."],
		["Reiniciar el servidor de correo",-10,-6,"Afectaste a toda la empresa."]]},
	{"p":2,"from":"Centro de copiado","copy":1,"t":"Copiadora atascada","b":"La copiadora principal marca atasco en la bandeja 2 y hay una cola de trabajos urgentes.","o":[
		["Abrir las puertas, retirar el papel con cuidado y revisar los rodillos",9,2,"Era una hoja arrugada en el rodillo. Cola liberada."],
		["Tirar del papel con fuerza para sacarlo rápido",-8,0,"Rompiste el rodillo. Toca llamar al técnico."],
		["Apagarla y esperar al proveedor sin revisar",-4,0,"Perdiste horas con un atasco simple."]]},
	{"p":2,"from":"Centro de copiado","copy":1,"t":"Escaneo a correo no envía","b":"El escáner de la copiadora marca error de envío al mandar documentos al correo.","o":[
		["Revisar las credenciales SMTP y usar un relay autenticado",8,10,"La clave del buzón de escaneo había cambiado. Corregido con autenticación."],
		["Abrir el relay de correo sin autenticación",6,-16,"Dejaste un relay abierto que se puede usar para spam."],
		["Reiniciar el servidor de correo",-8,-3,"Cortaste el correo a toda la corporación."]]},
	{"p":3,"from":"Centro de copiado","copy":1,"t":"Documentos confidenciales en la bandeja","b":"Alguien dejó contratos y nóminas impresos en la bandeja de salida de la copiadora.","o":[
		["Recogerlos, avisar a RRHH y activar impresión con PIN",6,14,"Evitaste una fuga de información y activaste impresión segura."],
		["Dejarlos ahí hasta que alguien los reclame",2,-12,"Cualquiera pudo leer datos sensibles."],
		["Tirarlos a la basura común",0,-14,"Documentos sensibles sin destrucción segura."]]},
	{"p":2,"from":"Gerencia General","t":"Wi-Fi caído en la sala de juntas","b":"Hay una reunión con un cliente en 20 minutos y nadie logra conectarse a la red inalámbrica.","o":[
		["Revisar el AP, el canal y el servidor DHCP",9,2,"El pool DHCP estaba agotado. Ampliaste el rango."],
		["Dar la clave del Wi-Fi interno a los invitados",4,-10,"Los invitados quedaron en la red corporativa. Usa una red de invitados."],
		["Reiniciar todo el edificio",-8,-2,"Cortaste la red a todos por un problema local."]]},
	{"p":2,"from":"Operaciones","t":"Respaldo nocturno fallido","b":"El job de backup de anoche terminó con error y el último respaldo válido tiene 3 días.","o":[
		["Revisar logs, liberar espacio y relanzar el respaldo",8,10,"Era falta de espacio en el destino. Respaldo completo."],
		["Marcarlo como completado en el reporte",2,-14,"Falsear el reporte deja a la empresa sin respaldo real."],
		["Esperar a la noche para ver si se arregla solo",-4,-8,"Sigues expuesto a pérdida de datos."]]},
	{"p":3,"from":"Seguridad (alerta automática)","t":"Posible ransomware en una PC","b":"El antivirus detectó archivos renombrados con extensión desconocida en un equipo de Ventas.","o":[
		["Aislar el equipo de la red, preservar evidencias y escalar",4,16,"Contuviste la propagación. Buena respuesta a incidentes."],
		["Apagar la PC y seguir con otros tickets",2,-6,"Perdiste evidencia volátil y no revisaste otros equipos."],
		["Pedir al usuario que borre los archivos",-6,-16,"Borrar no elimina el malware ni la propagación."]]},
	{"p":2,"from":"Mesa de Ayuda","t":"Clave olvidada por teléfono","b":"Alguien llama diciendo ser un gerente y pide una clave nueva de inmediato, sin poder ir a la oficina.","o":[
		["Verificar identidad y devolver la llamada al número registrado",6,12,"Era un intento de ingeniería social. Lo detectaste."],
		["Darle la clave por teléfono para no demorar",5,-16,"Entregaste acceso a un posible atacante."],
		["Negarte sin ofrecer alternativa",-6,2,"Seguro, pero dejaste al usuario sin camino claro."]]},
	{"p":1,"from":"Jorge (Ventas)","t":"Pantalla azul en la laptop","b":"La laptop se reinicia con pantalla azul al abrir el ERP. Tengo una demostración hoy.","o":[
		["Revisar el código de error, controladores y memoria",9,2,"Un driver gráfico reciente era el culpable. Revertido."],
		["Reinstalar Windows sin respaldar",-8,0,"Perdió archivos locales."],
		["Prestarle una laptop sin sus políticas de seguridad",2,-6,"Resolvió la demo, pero sin controles."]]},
	{"p":2,"from":"Teletrabajo","t":"La VPN no conecta","b":"Varios usuarios remotos no logran entrar a la VPN desde esta mañana.","o":[
		["Revisar certificado, MFA y logs del portal VPN",9,6,"El certificado había expirado. Renovado."],
		["Desactivar el MFA temporalmente",5,-16,"Quitaste una barrera clave de seguridad."],
		["Pedir que usen datos móviles",-5,0,"No ataca la causa raíz."]]},
	{"p":1,"from":"Contabilidad","t":"Licencia de Office expirada","b":"Varios equipos muestran producto sin licencia en Excel.","o":[
		["Revisar el tenant de Microsoft 365 y reasignar licencias",9,2,"Faltaban licencias asignadas tras un alta."],
		["Instalar una versión pirata",-6,-18,"Riesgo legal y de malware."],
		["Pedirles que trabajen en una hoja personal en línea",-4,-4,"Sacaste datos financieros de la plataforma autorizada."]]},
	{"p":2,"from":"Operaciones","t":"Servidor de archivos sin espacio","b":"El recurso compartido de Operaciones está al 99% y nadie puede guardar.","o":[
		["Analizar el uso, archivar lo antiguo y aplicar cuotas",9,4,"Recuperaste espacio y pusiste cuotas."],
		["Borrar carpetas al azar",-10,-4,"Eliminaste archivos en uso."],
		["Comprar discos sin analizar",-2,0,"Gasto sin atacar el crecimiento."]]},
	{"p":3,"from":"Seguridad (alerta automática)","t":"USB encontrado en el parqueo","b":"Un empleado entregó una memoria USB sin identificar y quiere ver qué contiene.","o":[
		["No conectarla; analizarla en un equipo aislado (sandbox)",6,14,"Evitaste un posible ataque tipo USB drop."],
		["Conectarla a tu PC para revisarla rápido",4,-16,"Podrías haber ejecutado malware en la red."],
		["Devolvérsela al empleado",2,-10,"Trasladaste el riesgo a otra persona."]]},
	{"p":2,"from":"TI","t":"Parche crítico de Windows","b":"Salió una actualización de seguridad crítica para los servidores de la oficina.","o":[
		["Probar en preproducción y programar ventana de mantenimiento",6,12,"Parche aplicado sin interrumpir operaciones."],
		["Instalarlo en producción en horario laboral",-8,6,"Hubo reinicios inesperados en pleno trabajo."],
		["Posponerlo hasta el próximo mes",2,-12,"Dejaste una vulnerabilidad conocida abierta."]]},
	{"p":1,"from":"Legal","t":"Carpeta compartida con todos","b":"Un usuario compartió una carpeta de contratos con permisos para Everyone.","o":[
		["Quitar Everyone, aplicar grupos de AD y auditar accesos",7,12,"Permisos de mínimo privilegio aplicados."],
		["Dejarlo, nadie externo tiene acceso",3,-12,"Los contratos quedaron expuestos a todos los usuarios."],
		["Moverla sin avisar",-5,2,"Rompiste enlaces y no corregiste el permiso."]]},
	{"p":1,"from":"Ventas","t":"Piden acceso sin filtro a Internet","b":"Un vendedor pide que le quites el filtro web porque bloquea páginas de clientes.","o":[
		["Revisar las categorías bloqueadas y permitir solo los sitios legítimos",8,6,"Acceso resuelto sin abrir todo."],
		["Quitarle el filtro por completo",6,-14,"Amplió la superficie de ataque."],
		["Responder que no sin revisar",-5,0,"No evaluaste la necesidad del negocio."]]},
]

const STN := [null, {"name":"Marta","dept":"Contabilidad"}, {"name":"Luis","dept":"Operaciones"}, {"name":"Carlos","dept":"Ventas"}, {"name":"Un usuario"}, {"name":"la copiadora"}]
const PRI := [Color("#4c9a6a"), Color("#e8b04c"), Color("#c4503f")]
const END := 17 * 60
const COST := 60

const RANKS := ["Becario", "Soporte N1", "Soporte N2", "Administrador de sistemas", "Ingeniero de redes", "Jefe de TI"]
const TH := [0, 150, 350, 650, 1000, 1500]
const ACH := {"rep":"Técnico de taller","lv5":"Veterano de TI","f2":"Explorador de pisos","call":"Teléfono rojo","remoto":"Soporte remoto","soc":"Cazador de amenazas","bios":"Técnico de hardware","first":"Primer ticket","mail":"Ojo de halcón","cli":"Maestro del CLI","perfect":"Día perfecto","shop":"Inversión","week":"Semana completa","ad":"Guardián del dominio","inf":"Cazador de infiltrados","nist":"Cumplimiento NIST CSF 2.0"}
const JB := [["Asistente de TI","Oficina local",0,1.0],["Analista de Soporte N2","Banco del Istmo",2,1.25],["Administrador de Sistemas","Logística Canal",3,1.5],["Ingeniero de Redes Cisco","Telecomunicaciones PA",4,1.9],["Analista SOC","Ciberseguridad PA",4,2.0],["Jefe de TI","Corporación Zona Libre",5,2.6]]
const USERS := [["mgarcia","Marta García","Contabilidad"],["lperez","Luis Pérez","Operaciones"],["cruiz","Carlos Ruiz","Ventas"],["sfernandez","Sofía Fernández","Legal"],["arodriguez","Andrea Rodríguez","RRHH"],["jtorres","Jorge Torres","Ventas"],["pmendez","Patricia Méndez","Contabilidad"],["dvega","Daniel Vega","TI"],["mrios","Mónica Ríos","Marketing"],["tsoto","Tomás Soto","Marketing"],["igomez","Irene Gómez","Legal"],["rcastro","Rafael Castro","Capacitación"]]

# Puntos de interacción (x, z, radio). Igual que ACT del original.
const ACT := [
	{"x":2.0,"z":-1.2,"r":2.2,"loc":0,"l":"Sentarse en la PC (E)"},
	{"x":11.5,"z":5.8,"r":1.5,"loc":1,"pcuse":0},
	{"x":-1.5,"z":17.8,"r":1.5,"loc":2,"pcuse":1},
	{"x":11.5,"z":11.8,"r":1.5,"loc":3,"pcuse":2},
	{"x":-1.9,"z":11.5,"r":1.6,"loc":5,"lc":"Revisar la copiadora (E)"},
	{"x":10.5,"z":1.7,"r":1.4,"home":"tv","l":"Ver TV y relajarte (E)"},
	{"x":12.4,"z":-1.4,"r":1.4,"home":"cook","l":"Cocinar algo (E)"},
	{"x":15.6,"z":1.7,"r":1.4,"home":"study","l":"Estudiar para certificación (E)"},
	{"x":16.3,"z":-0.2,"r":1.5,"home":"sleep","l":"Dormir y empezar un nuevo día (E)"},
	{"x":-5.0,"z":-1.2,"r":1.8,"dc":1,"l":"Abrir consola del switch Cisco (E)"},
	{"x":6.0,"z":-2.2,"r":1.6,"elev":1,"to":1,"l":"⬆ Subir al piso 2 (E)"},
	{"x":46.0,"z":-2.2,"r":1.6,"elev":1,"to":0,"l":"⬇ Bajar al piso 1 (E)"},
]

const WN := ["Sofía", "Andrea", "Jorge", "Patricia", "Daniel"]
const SEEK_COL := [Color("#d05a7a"), Color("#4c7ad0"), Color("#6a9a4c"), Color("#e8a03a"), Color("#8a5ac0"), Color("#3aa7a7")]

# ======================= FASE 2 =======================
# Correos: remitente, asunto, cuerpo, es_phishing, explicación
const MT := [["soporte@micr0soft-365.com","Su cuenta será suspendida","Verifique su cuenta en 24 horas: http://bit.ly/m365-verif",true,"Dominio con un cero y enlace acortado."],
	["rrhh@caacorp.com.pa","Recordatorio de vacaciones","Recuerden registrar sus vacaciones en el portal interno.",false,"Dominio corporativo y sin enlaces sospechosos."],
	["ceo@caa-corp.net","Transferencia urgente","Necesito que pagues $8,500 hoy y no lo comentes con nadie.",true,"Fraude del CEO: urgencia, secreto y dominio distinto."],
	["noreply@zoho.com","Tu ticket fue actualizado","Hay un nuevo comentario en el ticket #4821.",false,"Dominio oficial y notificación esperada."],
	["facturas@proveedor-pa.co","Factura vencida.zip","Adjunto factura. Abra el archivo para ver los detalles.",true,"ZIP inesperado de un remitente desconocido."],
	["it@caacorp.com.pa","Mantenimiento programado","Sábado 10 pm: mantenimiento de servidores. No requiere acción.",false,"Remitente interno y aviso informativo."],
	["seguridad@banco-panama-alerta.com","Actividad inusual en su cuenta","Confirme su clave aquí: https://banco-pa.verify-login.ru",true,"Dominio .ru y pide credenciales."],
	["gerencia@caacorp.com.pa","Agenda de la reunión","Adjunto la agenda; está en el SharePoint de la empresa.",false,"Interno, esperado y sin pedir datos."]]
# Dispositivos: nombre, falla, acción correcta (índice en MA)
const DEV := [["Firewall perimetral","Enlace WAN principal caído",1],["Switch core Cisco","CPU al 99% por un servicio colgado",0],["Controlador de dominio","Servicio Kerberos detenido",0],["Servidor Zoho","Licencia del proveedor expirada",2],["NAS de respaldo","Disco con falla y garantía vigente",2],["Portal VPN","Servicio colgado sin conexiones",0]]
const MA := ["Reiniciar servicio","Cambiar a respaldo","Escalar al proveedor"]
const SHOP := [["chair","Silla ergonómica","Cada ticket cuesta 5 minutos menos.",300],["sec","Curso Security+","+2 de seguridad en decisiones acertadas.",450],["ccna","Curso CCNA","Los trabajos del switch cuestan 10 minutos menos.",600],["coffee","Café de especialidad","Empiezas cada día con +10 de satisfacción.",150]]
const SK := [["cli","Consola Cisco","🖧",3,"Cada nivel: −3 min por trabajo del switch."],["logs","Análisis de logs","🔎",2,"Nv1: pista en el visor de eventos. Nv2: marca la IP atacante."],["phish","Anti-phishing","🎣",2,"Marca los correos sospechosos en la bandeja."],["hard","Hardening","🛡️",3,"+1 de seguridad por nivel en decisiones acertadas."],["comm","Atención al usuario","💬",3,"+1 de satisfacción por nivel y usuarios más pacientes."],["time","Gestión del tiempo","⏱️",3,"−2 min por ticket y nivel."],["ps","Scripting PowerShell","📜",2,"Scripts remotos más rápidos y se sugiere el correcto."],["diag","Diagnóstico de hardware","🧰",3,"Nv1 pista del síntoma · Nv2 pruebas gratis · Nv3 marca el componente."],["inv","Gestión de inventario","📦",2,"Piezas 10% más baratas por nivel."]]
const HOSTS := {"dc01":["192.168.10.10",2],"zoho.local":["192.168.10.20",3],"nas01":["192.168.10.30",4],"vpn.caacorp.com":["192.168.10.40",5],"firewall":["192.168.10.1",0],"google.com":["142.250.78.14",-1]}
const LOCALPROCS := [{"n":"explorer.exe","cpu":2,"mem":96},{"n":"chrome.exe","cpu":5,"mem":420},{"n":"zohodesk.exe","cpu":3,"mem":180},{"n":"teams.exe","cpu":4,"mem":300},{"n":"lsass.exe","cpu":1,"mem":40}]
const SYM := {"dns":"Los sitios no cargan por nombre (DNS)","spooler":"La cola de impresión está atascada","temp":"Disco casi lleno (97%) por archivos temporales","gpo":"Las directivas de grupo están desactualizadas"}
const SCRIPTS := [["flush-dns.bat","Vaciar la caché DNS","dns"],["restart-spooler.ps1","Reiniciar la cola de impresión","spooler"],["clean-temp.ps1","Limpiar archivos temporales","temp"],["gpupdate.cmd","Aplicar directivas de grupo","gpo"],["av-scan.ps1","Escaneo antivirus rápido","av"]]
# Videos: título, icono, duración (s), tipo (0 capacitación, 1 descanso, 2 otro), canal, subtítulos
const VIDS := [["Tutorial: VLANs en Cisco en 10 minutos","🖧",225,0,"Redes Academy",["Una VLAN separa dominios de broadcast","vlan 20 → name VENTAS","switchport mode access","switchport access vlan 20","Guarda con write memory"]],
	["Lo-fi para concentrarte","🌙",3600,1,"Chill Radio",["♪ Respira. Enfócate. Un ticket a la vez."]],
	["Cómo detectar un correo de phishing","🎣",312,0,"Ciberseguridad PA",["Revisa el dominio del remitente","Desconfía de la urgencia y el secreto","No abras adjuntos .zip inesperados","Reporta antes de hacer clic"]],
	["Gatitos graciosos (compilación)","🐱",184,1,"Mundo Animal",["Miau 🐾"]],
	["Tour por la oficina de CAA Corp","🏢",140,2,"CAA Corp TV",["Bienvenidos a CAA Corp","RRHH, Copiado, Contabilidad, Ventas…"]],
	["Active Directory paso a paso","🗂️",540,0,"Sysadmin Latam",["Usuarios, grupos y unidades organizativas","Aplica mínimo privilegio","Deshabilita cuentas de ex empleados","Audita los accesos con frecuencia"]],
	["Regla de respaldo 3-2-1","💾",260,0,"Backup Pro",["3 copias de tus datos","2 medios distintos","1 copia fuera de sitio","Prueba la restauración"]],
	["MFA: por qué importa","🔐",200,0,"Ciberseguridad PA",["Una contraseña no basta","Usa una app autenticadora","Nunca compartas el código","Protege las cuentas de administrador"]],
	["DHCP y DNS explicados","🌐",300,0,"Redes Academy",["DHCP asigna direcciones IP","DNS traduce nombres a IP","Si falla DNS: ipconfig /flushdns","Verifica con nslookup y ping"]],
	["Cómo armar y diagnosticar una PC","🖥️",420,0,"Hardware Lab",["Revisa fuente y memoria RAM","En el BIOS: Secure Boot y TPM","El SSD debe ser el primer arranque","Vigila temperatura y ventiladores"]]]
const GU := [["Política de contraseñas","Usa 12 o más caracteres, frases largas, MFA y un gestor de contraseñas. Cambia las claves tras cualquier incidente."],["Mínimo privilegio en Active Directory","Da solo los permisos necesarios. Revisa los grupos cada trimestre y deshabilita las cuentas inactivas o de ex empleados."],["Respaldos 3-2-1","Mantén 3 copias, en 2 medios distintos y 1 fuera de sitio. Prueba la restauración cada mes."],["Respuesta a incidentes","Contener, preservar evidencia, erradicar, recuperar y documentar. No apagues ni borres nada sin analizarlo."],["Configuración segura de switches Cisco","Una VLAN por departamento, puertos sin uso apagados, enable secret y guardar con write memory."]]
const FO := [["Impresora fuera de línea tras una actualización","Reinicia el servicio Cola de impresión y revisa el puerto TCP/IP. Un script de reinicio del spooler suele bastar."],["La VPN pide código MFA pero no llega","Verifica la hora del dispositivo: los códigos TOTP dependen del reloj. Se renuevan cada 30 segundos."],["¿Cuándo usar taskkill?","Solo en procesos congelados o sospechosos. Nunca en lsass.exe ni csrss.exe: reinician el equipo."],["Sospecho de un correo de phishing, ¿qué hago?","No hagas clic, reporta a TI y aísla el equipo si hubo clic. Revisa el registro de seguridad."]]
const CHAT_NAMES := ["Andrea","Mailer","Marta","Luis","Carlos","Patricia","Jorge","Alexis","Carolina","Jahir","Franklin"]
# Puestos con PC usable (ACT con pcuse): x, z del asiento, índice en USERS
const PCUSE := [[11.5,5.8,0],[-1.5,17.8,1],[11.5,11.8,2],[-2.4,5.9,4],[14.2,6.0,6],[14.2,12.0,5],[37.6,17.9,7],[50.4,5.9,8],[53.6,5.9,9],[50.4,11.9,3],[53.6,11.9,10],[50.4,18.0,11]]

# ======================= FASE 3 =======================
# Llamadas: quien, motivo, opciones [texto, sat, sec, xp, resultado]
const CALLS := [["Marta (Contabilidad)","Olvidó su contraseña y pide que se la digas por teléfono.",[["Verificar su identidad y enviar un enlace de restablecimiento",3,8,3,"Verificación correcta: seguridad primero."],["Dársela de inmediato",4,-10,0,"Podría ser ingeniería social."],["Colgar sin ayudar",-5,0,0,"Mala atención al usuario."]]],
	["Carlos (Ventas)","Internet va lento solo en su PC.",[["Ejecutar ping y tracert, revisar cable y puerto",3,2,3,"Era un cable en mal estado."],["Reiniciar el router de toda la oficina",-6,-2,0,"Afectaste a todos por un problema local."],["Decirle que espere",-3,0,0,"No avanzaste nada."]]],
	["Número desconocido","Dice ser «soporte técnico» y pide un ID de acceso remoto para arreglar tu PC.",[["Negarte y reportar el intento (vishing)",2,10,3,"Excelente: era un intento de fraude."],["Dar el ID de acceso remoto",2,-14,0,"Entregaste acceso a un atacante."],["Dar tu nombre y esperar",0,-8,0,"Revelaste información útil."]]],
	["Andrea (RRHH)","Necesita compartir una carpeta de candidatos de forma segura.",[["Crear un grupo en AD con permisos de solo lectura",3,8,3,"Mínimo privilegio aplicado."],["Compartirla con Everyone",4,-12,0,"Quedó expuesta a todos."],["Enviarla por correo personal",1,-9,0,"Sacaste datos fuera de la plataforma."]]],
	["Luis (Operaciones)","La impresora imprime en blanco.",[["Revisar tóner, cabezal y cola de impresión",4,0,3,"Era el tóner agotado."],["Comprar una impresora nueva",-4,-2,0,"Gasto innecesario."],["Decir que es un virus",-5,-3,0,"Diagnóstico sin fundamento."]]],
	["Sofía (Legal)","Quiere instalar un programa descargado de un sitio desconocido.",[["Evaluar el software y usar solo repositorios autorizados",2,10,3,"Buena práctica de seguridad."],["Instalarlo como administrador",4,-14,0,"Riesgo grave de malware."],["Prohibirlo sin explicar",-4,2,0,"Seguro, pero sin comunicación."]]]]

const PARTS := {"ram":["Memoria RAM",45],"ssd":["SSD",70],"psu":["Fuente de poder",60],"fan":["Ventilador de CPU",20],"cmos":["Batería CMOS",5],"gpu":["Tarjeta gráfica",150],"paste":["Pasta térmica",8]}
const COMP := [["psu","Fuente de poder","🔌"],["mb","Placa base","🧩"],["cpu","CPU y disipador","🌡️"],["ram","Memoria RAM","🧠"],["ssd","SSD","💽"],["gpu","Tarjeta gráfica","🎮"],["cmos","Batería CMOS","🔋"]]
const TOOLS := [["vis","👁️ Inspección visual"],["multi","📟 Multímetro"],["mem","🧪 Memtest"],["smart","💽 SMART"],["term","🌡️ Cámara térmica"],["post","🔊 Tarjeta POST"]]
const TAP := {"multi":["psu","cmos"],"mem":["ram"],"smart":["ssd"],"term":["cpu","gpu"],"post":["mb"]}
const NORM := {"vis":"Sin daños visibles en este componente.","multi":"Voltaje dentro del rango normal.","mem":"Memtest: 0 errores.","smart":"SMART: estado saludable.","term":"Temperatura normal (42 °C).","post":"POST sin pitidos de error."}
const FAULTS := [{"c":"psu","p":"psu","cat":"alimentación","sym":"No enciende: ni luces ni ventiladores","r":{"multi":"Salida de 12 V: 0.4 V (muy por debajo de lo normal)","vis":"Condensadores hinchados en la fuente","post":"Sin señal: la placa no recibe energía"}},
	{"c":"ram","p":"ram","cat":"memoria","sym":"Pantallazos azules y reinicios aleatorios","r":{"mem":"Memtest: 1,284 errores en el módulo 2","post":"Pitidos continuos: error de memoria","vis":"Contactos sucios en un módulo"}},
	{"c":"ssd","p":"ssd","cat":"almacenamiento","sym":"«No se encontró un dispositivo de arranque»","r":{"smart":"SMART: 4,812 sectores reasignados (disco fallando)","post":"POST correcto, pero no se detecta ningún disco"}},
	{"c":"cpu","p":"fan","cat":"temperatura","sym":"Se apaga sola tras unos minutos de uso","r":{"term":"CPU a 98 °C y ventilador detenido","vis":"El ventilador del procesador no gira","post":"POST correcto; apagado por temperatura"}},
	{"c":"cmos","p":"cmos","cat":"batería y BIOS","sym":"Pierde la fecha y la hora y pide pulsar F1 al arrancar","r":{"multi":"Batería CMOS: 1.1 V (agotada)","post":"Aviso: checksum de CMOS inválido"}},
	{"c":"gpu","p":"gpu","cat":"video","sym":"Enciende pero no hay imagen en el monitor","r":{"term":"La GPU no genera calor: sin actividad","post":"1 pitido largo y 3 cortos: error de video","vis":"La tarjeta gráfica tiene marcas de quemado"}}]
const MODELS := ["OptiPlex 7090","ThinkCentre M70","ProDesk 400 G7","Vostro 3910"]

# NPC de la oficina: nombre, depto, x, z, camisa, piel, pelo, loc, consejos, tipo (""=puesto, b=jefe, c=limpieza, s=de pie)
const ZD := [["Andrea","RRHH",-2.4,5.12,"d05a7a","c89a7a","2a1a10",0,["Mínimo privilegio: solo los accesos necesarios."],""],
	["Mailer","RRHH",.4,5.12,"4c7ad0","e0a97a","1a1a1a",0,["Nunca hagas clic en enlaces acortados.","Revisa siempre el dominio del remitente."],""],
	["Marta","Contabilidad",11.5,5.28,"d05a7a","e0a97a","3a2410",1,["Cierre de mes: ¡no me falles, TI!"],""],
	["Luis","Operaciones",-1.5,17.28,"4c7ad0","c58f66","111111",2,["Los respaldos 3-2-1 salvan la vida."],""],
	["Carlos","Ventas",11.5,11.28,"6a9a4c","e0a97a","4a3020",3,["La VPN siempre con MFA, ¿verdad?"],""],
	["Patricia","Contabilidad",14.2,5.22,"8a5ac0","d9a07a","222222",0,["Jamás comparto mi contraseña."],""],
	["Jorge","Ventas",14.2,11.22,"e8a03a","b98060","111111",0,["¿Un USB desconocido? Ni de broma."],""],
	["Gerente Vargas","Gerencia",12.5,18.1,"2a2a3a","e0a97a","888888",0,["Quiero cero incidentes de seguridad hoy."],"b"],
	["Don Pedro","Limpieza",0,0,"3aa7a7","c58f66","555555",0,["Cuidado, piso mojado 🧹"],"c"],
	["Alexis","Operaciones",-1.5,12.5,"2a6fd0","5b3a26","111111",0,["¡Hoy cierro todos mis tickets!"],"s"],
	["Carolina","Marketing",2,10,"8a5ac0","d9a07a","4a2c1a",0,["Paz, amor y contraseñas de 16 caracteres ✌️"],"s"],
	["Jahir","Capacitación",11.5,13.5,"c4302a","c58f66","111111",0,["¡Seré el rey de los tickets resueltos! 🏴‍☠️"],"s"],
	["Jesus","Seguridad",-2,14.5,"151515","c58f66","111111",0,["Todo acceso sospechoso se reporta."],"s"],
	["Martin Lu","Legal",2.5,16.5,"f4f4f4","eac9a0","111111",0,["Sin política firmada no hay acceso."],"s"],
	["Daniel","Capacitación",12.5,7,"8a6a4a","d9a07a","cfcfcf",0,["En mis tiempos las contraseñas eran de papel... ¡y no se perdían!"],"s"],
	["Franklin","Soporte",9.5,10.5,"f5f5f5","e0a97a","1a1a1a",0,["Un parche a tiempo ahorra mil tickets."],"s"],
	["Agustin","Finanzas",14,16.5,"1f2a44","d9a07a","2a1a10",0,["Toda solicitud de TI pasa por aprobación formal."],"s"]]
const ZCONV := [["¿Viste el correo de seguridad?","Sí, nada de enlaces raros","Mejor reportarlo a TI","Buena idea"],["¿Ya cerraste el mes?","Casi, el Excel no coopera","Tómate un café primero ☕","Eso haré"],["¿Viste el partido anoche?","¡Qué golazo!","Increíble 😄","Hoy hay revancha"],["Ayer se trabó la impresora","A mí también","TI nos salvó el día","Siempre lo hacen"],["¿Qué vas a almorzar?","Algo ligero, ensalada","Yo voy por un sándwich","Buen provecho"],["Hoy hay reunión a las 3","¿Otra reunión?","Sí… lleva café ☕","Ni modo 😅"],["¿Cambiaste tu contraseña?","Sí, larga y con MFA","Yo uso una frase","Así se hace 🔐"]]
const ZSOLO := ["Este Excel me odia 😩","Necesito más café ☕","Cierre de mes… otra vez","¿Dónde guardé ese PDF?","Ya casi es hora de comer","¡Qué rápido pasa el día!"]
const ZPH := ["Buenas, CAA Corp, ¿en qué le ayudo?","Le envío la cotización hoy","Déjeme verificar y le llamo","Claro, le confirmo por correo"]
const ZHELLO := ["¡Hola, soporte TI! 👋","¿Cómo va el día?","Gracias por ayudarnos","¡Buen trabajo con los tickets!","Hay café en el pasillo ☕"]
const ZROAM := [[6,5],[6,10],[6,15],[6,19.5],[0,6.5],[0,12.5],[0,18.5],[11,6.8],[11,12.8],[11,19]]
# Puntos de descanso: x, z, yaw, altura de asiento, punto de aproximación
const ZS := {"coffee":[[6.75,8.4,PI/2],[6.75,9.6,PI/2]],"vend":[[5.3,14.4,-PI/2],[5.3,15.6,-PI/2]],"cooler":[[6.8,3.8,PI/2]],"copy":[[-1.9,11.3,PI]],"bench":[[4.7,-1.9,PI/2,.4,[5.55,-1.9]],[7.3,-1.9,-PI/2,.4,[6.45,-1.9]]]}
# Piso 2: NPC con disfraz
const C2 := [{"n":"Valeria","sh":"c4302a","sk":"e0a97a","hr":"111111","g":1},{"n":"Diego","sh":"1f3a2a","sk":"c58f66","hr":"3a8a3a","g":1},{"n":"Mateo","sh":"d0a040","sk":"9a6a45","hr":"111111","g":1},
	{"n":"Camila","sh":"f2f2f2","sk":"f1c9a5","hr":"e8802a"},{"n":"Sebastián","sh":"111111","sk":"f1c9a5","hr":"e8d060"},{"n":"Nicole","sh":"a02a2a","sk":"c58f66","hr":"2a1a10"},{"n":"Ricardo","sh":"c4302a","sk":"6b4429","hr":"111111"}]
const LINES2 := {"Camila":["¡Zarpamos a resolver tickets!","Mi mapa dice: reiniciar el router."],"Sebastián":["La cocina de TI está abierta 🍳","Un café y seguimos navegando."],"Nicole":["¡Capitana del Soporte N2!","Aquí no hay tickets sin dueño."],"Ricardo":["¡Voy a ser el Rey del Soporte!","¿Viste mi sombrero? ¡Es de paja!"]}
const GAMER := ["¡Gané la carrera!","¡Persecución policial!","¡Qué salto!","Dame el control...","¡Misión cumplida!"]
const ANCH2 := [[-1.6,5.6],[1.6,5.6],[2.4,7.6],[0,11.6],[-2.5,12.2],[2.2,10.8],[-2.4,18.1],[.4,18.1],[2,16.6],[10.4,6.1],[13.6,6.1],[12,7.6],[10.4,12.1],[13.6,12.1],[11,18.8],[6,5],[6,10],[6,16],[6,1]]
# Espionaje
const SPOTS := [{"x":-1.9,"z":11.3,"yaw":PI,"n":"Centro de copiado"},{"x":-3.0,"z":6.6,"yaw":-PI/2,"n":"Archivo de RRHH"},{"x":11.4,"z":18.4,"yaw":PI/2,"n":"Gerencia"}]
# Niveles de carrera
const GOALS := [null,{"done":3,"sat":50},{"done":4,"sat":55,"net":1,"spy":1},{"done":5,"sat":60,"net":2,"rep":1,"spy":1},{"done":6,"sat":65,"net":3,"rep":1,"sec":55,"spy":1},{"done":7,"sat":70,"net":3,"rep":2,"sec":65,"spy":2}]
const LVN := ["","Practicante de TI","Soporte N1","Técnico de campo","Especialista de soporte","Soporte Técnico IT Nivel 2"]
const TRACKS := [["In the End","Linkin Park"],["Numb","Linkin Park"],["Faint","Linkin Park"],["Crawling","Linkin Park"],["What I've Done","Linkin Park"],["Somewhere I Belong","Linkin Park"],["Breaking the Habit","Linkin Park"],["Papercut","Linkin Park"],["One Step Closer","Linkin Park"],["Bleed It Out","Linkin Park"],["Given Up","Linkin Park"],["New Divide","Linkin Park"],["Burn It Down","Linkin Park"],["Castle of Glass","Linkin Park"],["The Emptiness Machine","Linkin Park"],["Bring Me to Life","Evanescence"],["My Immortal","Evanescence"],["Going Under","Evanescence"],["Everybody's Fool","Evanescence"],["Call Me When You're Gone","Evanescence"],["Lithium","Evanescence"],["Imaginary","Evanescence"],["Sweet Sacrifice","Evanescence"],["Wake Me Up Inside","Evanescence"]]
