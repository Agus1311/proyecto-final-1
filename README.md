# 🖥️ Mesa de Ayuda — CAA Corp

**Simulador de soporte técnico y ciberseguridad en 3D, hecho en Godot 4.**
Eres el técnico de TI de CAA Corp: atiende tickets, repara equipos, configura la red, detén al intruso y recorre la Ciudad de Panamá antes de que termine tu turno.

![Portada](docs/img/portada.jpg)

[![Godot 4.7.2](https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Licencia: MIT](https://img.shields.io/badge/c%C3%B3digo-MIT-green)](LICENSE)
[![Assets: CC BY 4.0](https://img.shields.io/badge/assets-CC%20BY%204.0-lightgrey)](LICENSE)
![Plataformas](https://img.shields.io/badge/plataformas-Windows%20%C2%B7%20Linux%20%C2%B7%20Web-blue)

Proyecto final del curso **EID1028 — Electiva II** · Escuela de Innovación Digital (Ciberseguridad) · **ITSE**, Panamá · III cuatrimestre 2026.

---

## 🎮 De qué se trata

Tu jornada va de **08:00 a 17:00** en una oficina de dos pisos. Cada decisión consume minutos del reloj y cambia dos indicadores: la **satisfacción** de los usuarios y la **seguridad** de la empresa. Si la seguridad llega a 0, te despiden (**GAME OVER**); si llegas a casa con el turno completado, **¡jornada completada!**

| | |
|---|---|
| ![Oficina](docs/img/oficina.jpg) | ![Zoho Desk](docs/img/zoho.jpg) |
| ![Data Center](docs/img/datacenter.jpg) | ![Consola SOC](docs/img/soc.jpg) |

### En la oficina
- **Tickets en Zoho Desk:** cola diaria con prioridad, SLA y respuestas con consecuencias.
- **Visitas en sitio:** los usuarios te buscan por los pasillos o te piden ir a su puesto.
- **Consola del switch Cisco:** VLAN, hardening y enlace troncal con comandos reales.
- **Active Directory, correo, MFA, BIOS** y escritorio remoto de los usuarios.
- **Taller de reparación:** diagnóstico y cambio de RAM, fuente, SSD o ventilador.
- **Data Center:** dos filas de racks, pasillo frío, CRAC, UPS, extinción FM-200 y la **consola SOC** con videowall.
- **SOC (NIST SP 800-61):** detecta, preserva evidencia, contén, recupera y cierra incidentes.
- **El intruso:** un falso técnico de mantenimiento patrulla el Piso 1 (máquina de estados: patrulla → persecución → búsqueda → huida). Confróntalo con **X**.
- Niveles de **Becario** a **Soporte Técnico IT Nivel 2**, sueldo, habilidades, tienda y certificado.

### En la ciudad
| | |
|---|---|
| ![Manejo](docs/img/manejo.jpg) | ![Mercado de Mariscos](docs/img/mercado.jpg) |
| ![Calzada de Amador](docs/img/calzada.jpg) | ![Competencia de lanchas](docs/img/lancha.jpg) |

- **Av. Balboa y Cinta Costera** con tráfico, semáforos, MiBus, bancos y tu casa (punto de guardado).
- **Superdeportivo** con caja de 7 marchas, derrape y 3 cámaras.
- **Zona oeste:** Mercado de Mariscos, Plaza 5 de Mayo, Curundú, Cinta Costera 3 con el Casco Antiguo al fondo y la Calzada de Amador con las islas Naos, Perico y Flamenco.
- **Lancha:** entregas a las islas, rescate de un pescador y **competencia de lanchas** contra 3 rivales con premios por puesto y récord.
- **Bancos:** misiones de atención al cliente, TI y SOC.
- **Misiones comunitarias:** Infocentro de Curundú, smishing en la Plaza 5 de Mayo y el datáfono del Mercado.
- Más de 60 peatones con rutas propias (vendedores, trotadores, ciclistas, niños en la cancha).

### Multijugador
Sala en **red local para hasta 4 técnicos** (ENet) en la versión de escritorio: código de 7 letras, avatares y chat.

---

## ⌨️ Controles

| Acción | Tecla |
|---|---|
| Moverse / correr | **W A S D** o flechas / **Shift** |
| Mirar | **Clic** + mouse (**Esc** libera el mouse) |
| Interactuar | **E** |
| Confrontar al intruso | **X** |
| Primera / tercera persona | **V** |
| Mapa · viaje rápido en la ciudad | **M** |
| Chat | **Enter** |
| Menú del juego / Pausa y ajustes | **Tab** / **P** |
| Pantalla completa | **F11** |
| **Al volante:** acelerar · frenar · girar · freno de mano · turbo · cámara · bocina | W · S · A/D · Espacio · Shift · C · H |
| **En lancha:** misiones · competencia · volver al muelle | 1 – 3 · 4 · R |

---

## ▶️ Cómo ejecutarlo

### Jugar
- **En el navegador:** abre `MesaDeAyuda_CAA_Corp.html` (versión de un solo archivo) con Chrome, Edge o Firefox actualizados, o la página del juego en itch.io.
- **Windows:** descarga el `.zip` de la última versión en **[Releases](https://github.com/agustin1311/Proyecto_Final/releases)**, descomprime y abre `MesaDeAyuda_CAA_Corp.exe`.

### Abrir el proyecto
1. Instala **[Godot 4.7.2](https://godotengine.org/download)** (versión estándar, no la .NET).
2. Clona el repositorio:
   ```bash
   git clone https://github.com/agustin1311/Proyecto_Final.git
   ```
3. En Godot: **Importar** → selecciona `project.godot` → **Ejecutar** (F5). La escena principal es `scenes/main.tscn`.

### Exportar
- **Windows / Linux:** *Proyecto → Exportar* con los presets incluidos (`export_presets.cfg`).
- **Web (zip para itch.io, HTML único y versión para hosting):**
  ```bash
  GODOT=/ruta/a/godot tools/build_web.sh
  ```
  El script reduce las texturas para la web, exporta con el renderizador Compatibility y empaqueta todo en `build/entrega_web/`.

### Pruebas automáticas
```bash
godot --headless --path . -- test=1
```
Corre más de 120 comprobaciones del juego (movimiento, colisiones, tickets, red, SOC, enemigo, derrota y victoria, ciudad, lancha, misiones…) y termina con `TEST DONE`.

---

## 🗂️ Estructura

```
├── project.godot            Configuración del proyecto (Autoloads: Data, Game, Soc, Net)
├── scenes/                  main.tscn (escena principal) · intruso.tscn (enemigo)
├── scripts/
│   ├── main.gd              Bucle principal, jugador, cámara, zonas y pruebas
│   ├── game.gd              Estado de la jornada, guardado y progreso
│   ├── world.gd             Oficina de dos pisos y Data Center
│   ├── office_life.gd       Empleados, visitas y vida de oficina
│   ├── enemy_intruder.gd    Máquina de estados del intruso
│   ├── soc.gd · cisco.gd    Incidentes NIST y consola del switch
│   ├── city/                Ciudad, zona oeste, manejo, lancha, autos y bancos
│   ├── ui/                  HUD, escritorio, Zoho Desk, menús y pantallas
│   └── audio/               Efectos de sonido
├── shaders/                 Carretera, mar, fachadas y cielo
├── assets/                  Texturas, fuentes y audio
├── tools/                   Generadores de texturas y empaquetado web
└── docs/img/                Capturas para este README
```

Todo el mundo 3D (oficina, ciudad, personajes y vehículos) se genera por código; no hay modelos de terceros.

---

## 👥 Equipo — Firewall Studio

| Integrante | Rol |
|---|---|
| **Agustín Batista** | Scrum Master · lógica de la jornada, estados y guardado · build y releases |
| **Carolina Guevara** | Tickets y Zoho Desk · HUD · taller de reparación · interfaz |
| **Alexis Este** | Jugador y cámara · colisiones · ciudad y manejo |
| **Franklin Hernández** | Red Cisco y SOC · enemigo con máquina de estados · QA y pruebas |

Instructor: **Jahir Agudo**.

**Sprints:** v0.1 núcleo jugable · v0.2 mundo y vida (enemigo, audio, derrota y victoria) · v0.9 beta (ciudad, bancos, multijugador, versión web).

---

## 📜 Licencia y créditos

- **Código:** [MIT](LICENSE).
- **Assets propios** (texturas, modelos generados por código, sonidos y capturas): **CC BY 4.0**.
- **Terceros:** Godot Engine (MIT); fuentes Space Grotesk, JetBrains Mono y Noto Color Emoji (SIL OFL 1.1), DejaVu Sans (licencia DejaVu), GNU FreeSans y GNU Unifont (GPL con excepción para fuentes). Ver el detalle en [LICENSE](LICENSE).
- **Declaración de IA:** el código, las texturas procedurales y la síntesis de audio se desarrollaron con asistencia de IA (Claude, de Anthropic).

*CAA Corp es una empresa ficticia. Las marcas de software mencionadas en el juego (Zoho Desk, Cisco, Active Directory, etc.) pertenecen a sus dueños y se usan solo como referencia educativa.*
