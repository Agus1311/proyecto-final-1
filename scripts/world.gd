class_name World
extends Node3D
## Construye CAA Corp con las mismas coordenadas, medidas y colisiones del original,
## pero con materiales PBR, luces reales y props con más detalle.

const PI_ := PI
const WALL := Color("#f0c9a0")
const HW := Color("#cfd3d9")
const AW := Color("#e8d9c4")
const DW := Color("#2a3441")
const IW := Color("#eee6d8")
const OX := 40.0

var desk_screen: CanvasTex
var station_screens: Array = []   # CanvasTex por estación (loc 1..3)
var ad_tex: CanvasTex
var clock_tex: CanvasTex
var tv_pos: Array = []
var leds: Array = []
var led_mats: Array = []
var led_off: StandardMaterial3D
var window_mats: Array = []
var lamp_lights: Array = []
var dc_light: OmniLight3D
var fridge_door: Node3D
var fridge_items := {}
var printer_sheets: Array = []
var printer_led: MeshInstance3D
var coffee_stream: MeshInstance3D
var water_stream: MeshInstance3D
var trunk_mark: MeshInstance3D
var beacon_mat: ShaderMaterial

# Paleta -> tipo de material
const KIND_BY_COLOR := {
	"2f5fbf":"fabric", "3a7a5a":"fabric", "2f6a4a":"fabric", "e8e4f4":"fabric", "2f6f8f":"plastic",
	"3a3a4a":"fabric", "1a1a1a":"fabric", "ffffff":"plastic",
	"77687a":"wood", "8a7a8e":"wood", "c07a3a":"wood", "8a5a2a":"wood", "5a3a1a":"wood", "5a3a22":"wood",
	"7a5a42":"wood", "8a6a4a":"wood", "3a2a1a":"wood", "2a1a0a":"wood", "6a5a4a":"wood", "7a6a5a":"wood",
	"d8c7b0":"wood", "c9b79c":"wood", "efe6d6":"plastic",
	"15121a":"metal", "1a1620":"metal", "222222":"plastic", "111111":"plastic", "6a6a6a":"metal",
	"14171d":"metal", "2c3440":"grille", "555b66":"metal", "8a9aa8":"metal", "444444":"metal",
	"6a6a72":"metal", "3a3a42":"metal", "555a62":"metal", "9aa3ad":"metal", "333333":"metal",
	"8a8a92":"metal", "cfd4da":"plastic", "dad4c8":"plastic", "b98b5a":"carpet", "c99b6a":"carpet",
}


func build() -> void:
	_init_collisions()
	_office()
	_hall_and_apartment()
	_datacenter()
	_floor1_departments()
	_floor2()
	_phase3()
	_dust()


# ============ utilidades (equivalentes a box/fb/fl/wX/wZ del original) ============
func kind_for(c: Color) -> String:
	return KIND_BY_COLOR.get(c.to_html(false), "plastic")


func box(w: float, h: float, d: float, c, x: float, y: float, z: float, parent: Node3D = null, kind := "") -> MeshInstance3D:
	var col: Color = c if c is Color else Color.hex((int(c) << 8) | 0xff)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	m.mesh = bm
	m.material_override = Mats.get_mat(kind if kind != "" else kind_for(col), col)
	m.position = Vector3(x, y, z)
	(parent if parent else self).add_child(m)
	return m


func fb(w: float, h: float, d: float, c, x: float, y: float, z: float, kind := "") -> MeshInstance3D:
	Game.dk.append([x, z, w / 2 + .25, d / 2 + .25])
	return box(w, h, d, c, x, y, z, null, kind)


## Los pisos y techos se dividen en piezas de hasta 4 m. En el navegador (renderizador
## Compatibility) cada malla recibe como máximo 8 luces: un pasillo de una sola pieza con
## muchas lámparas hacía que se prendieran y apagaran al caminar (la «falla de luz»).
## Las texturas son triplanares en espacio mundo, así que las piezas empalman sin costura.
const TILE := 4.0


func floor_rect(x0: float, x1: float, z0: float, z1: float, c, kind := "carpet", y := 0.0) -> void:
	var col: Color = c if c is Color else Color.hex((int(c) << 8) | 0xff)
	var mat := Mats.get_mat(kind, col)
	var nx := maxi(1, ceili((x1 - x0) / TILE)); var nz := maxi(1, ceili((z1 - z0) / TILE))
	var sx := (x1 - x0) / nx; var sz := (z1 - z0) / nz
	for i in nx:
		for j in nz:
			var m := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(sx, sz)
			m.mesh = pm
			m.material_override = mat
			m.position = Vector3(x0 + sx * (i + .5), y + .005, z0 + sz * (j + .5))
			add_child(m)


func ceiling(w: float, d: float, x: float, z: float, c := Color("#f2ece0")) -> void:
	var nx := maxi(1, ceili(w / TILE)); var nz := maxi(1, ceili(d / TILE))
	var sx := w / nx; var sz := d / nz
	for i in nx:
		for j in nz:
			box(sx, .2, sz, c, x - w / 2 + sx * (i + .5), 3, z - d / 2 + sz * (j + .5), null, "ceiling")


func wall(w: float, h: float, d: float, c: Color, x: float, y: float, z: float) -> void:
	var L := maxf(w, d)
	var n := maxi(1, ceili(L / TILE))
	for i in n:
		var off := -L / 2 + L / n * (i + .5)
		if w > d: box(w / n, h, d, c, x + off, y, z, null, "plaster")
		else: box(w, h, d / n, c, x, y, z + off, null, "plaster")
	# zócalo
	if h >= 2.9:
		if w > d:
			box(w, .1, d + .03, Color("#3a3036"), x, .05, z, null, "wood")
		else:
			box(w + .03, .1, d, Color("#3a3036"), x, .05, z, null, "wood")


func wX(x: float, z0: float, z1: float, gs: Array) -> void:
	var a := z0
	for g in gs + [z1 + 1]:
		var e: float = z1 if g > z1 else g - .9
		if e > a:
			wall(.2, 3, e - a, IW, x, 1.5, (a + e) / 2)
		if g <= z1:
			box(.2, 1, 1.8, IW, x, 2.5, g, null, "plaster")
			_door_frame_x(x, g)
			a = g + .9


func _door_frame_x(x: float, z: float) -> void:
	var fc := Color("#5a4636")
	box(.26, .06, 1.86, fc, x, 2.0, z, null, "wood")
	box(.26, 2.0, .06, fc, x, 1.0, z - .93, null, "wood")
	box(.26, 2.0, .06, fc, x, 1.0, z + .93, null, "wood")


func wZ(z: float, x0: float, x1: float) -> void:
	wall(x1 - x0, 3, .2, IW, (x0 + x1) / 2, 1.5, z)


func lamp(x: float, z: float, col := Color("#fff2d6"), w := 1.0, d := .6, energy := 1.4, rng := 7.0, shadow := false) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, .04, d)
	m.mesh = bm
	m.material_override = Mats.unshaded(col, 3.0)
	m.position = Vector3(x, 2.88, z)
	add_child(m)
	var fr := box(w + .06, .03, d + .06, Color("#d9d9de"), x, 2.9, z, null, "metal")
	fr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.position = Vector3(x, 2.55, z)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadow
	l.light_specular = .4
	add_child(l)
	lamp_lights.append(l)


func label3d(t: String, size: int, col: Color, pos: Vector3, ry: float, parent: Node3D = null, width := 0.0, bold := true) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = CanvasTex.font(bold)
	l.font_size = size
	l.outline_size = 0
	l.modulate = col
	l.pixel_size = .0016
	l.position = pos
	l.rotation.y = ry
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if width > 0:
		l.width = width
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent else self).add_child(l)
	return l


func panel(w: float, h: float, col: Color, pos: Vector3, ry: float) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = ry
	add_child(g)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, .015)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = .45
	m.material_override = mat
	g.add_child(m)
	return g


## Póster (frente hacia +z, como el original).
func poster(x: float, y: float, z: float, l1: String, l2: String, c: String) -> void:
	var g := panel(.5, .62, Color(c), Vector3(x, y, z), 0)
	var f := CanvasTex.font(true)
	var a := label3d(l1, 64, Color.WHITE, Vector3(-.21, .08, .01), 0, g, 0)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.pixel_size = minf(.00135, .42 / maxf(1.0, f.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x))
	var b := label3d(l2, 64, Color.WHITE, Vector3(-.21, -.02, .01), 0, g, 0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pixel_size = minf(.00135, .42 / maxf(1.0, f.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x))
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(.42, .025, .005)
	bar.mesh = bm; bar.material_override = Mats.unshaded(Color.WHITE)
	bar.position = Vector3(0, -.12, .01)
	g.add_child(bar)
	# marco
	var fr := MeshInstance3D.new(); var fm := BoxMesh.new(); fm.size = Vector3(.54, .66, .01)
	fr.mesh = fm; fr.material_override = Mats.get_mat("metal", Color("#2a2a30")); fr.position.z = -.008
	g.add_child(fr)


func sgn(x: float, y: float, z: float, ry: float, t: String, c: String) -> void:
	var g := panel(1.1, .28, Color(c), Vector3(x, y, z), ry)
	label3d(t, 56, Color.WHITE, Vector3(0, -.005, .01), 0, g).pixel_size = .0012


func logo(x: float, y: float, z: float, ry: float, w: float) -> void:
	var g := panel(w, w * .375, Color("#0b2a4a"), Vector3(x, y, z), ry)
	var k := w / 1.6
	var a := label3d("CAA", 120, Color("#ff9a1f"), Vector3(-w * .11, w * .03, .01), 0, g)
	a.pixel_size = .0016 * k
	var b := label3d("CORP", 80, Color.WHITE, Vector3(w * .28, w * .03, .01), 0, g)
	b.pixel_size = .0016 * k
	var bar := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(w * .84, w * .02, .005)
	bar.mesh = bm; bar.material_override = Mats.unshaded(Color.WHITE)
	bar.position = Vector3(0, -w * .11, .01); g.add_child(bar)


func plant(x: float, z: float, pot := .4, h := .7, y0 := 0.0, collide := false) -> void:
	if collide:
		fb(pot, pot, pot, Color("#1c3fc8"), x, y0 + pot / 2, z, "plastic")
	else:
		box(pot, pot, pot, Color("#1c3fc8"), x, y0 + pot / 2, z, null, "plastic")
	box(pot * .9, .02, pot * .9, Color("#3a2a1a"), x, y0 + pot + .005, z, null, "carpet")
	box(.04, h, .04, Color("#2a4a2a"), x, y0 + pot + h / 2, z, null, "wood")
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color("#2e8a4f")
	leaf.roughness = .6
	leaf.subsurf_scatter_enabled = true
	leaf.subsurf_scatter_strength = .3
	var r := RandomNumberGenerator.new()
	r.seed = int(x * 100 + z * 7)
	for i in 7:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var rad := r.randf_range(.12, .2) * (pot / .4)
		sm.radius = rad; sm.height = rad * 1.6; sm.radial_segments = 12; sm.rings = 6
		s.mesh = sm
		s.material_override = leaf
		var a := r.randf() * TAU
		s.position = Vector3(x + cos(a) * r.randf_range(.05, .16), y0 + pot + h * r.randf_range(.6, 1.05), z + sin(a) * r.randf_range(.05, .16))
		s.rotation = Vector3(r.randf(), r.randf(), r.randf())
		add_child(s)


func screen_quad(w: float, h: float, tex: Texture2D, pos: Vector3, ry := 0.0, parent: Node3D = null, energy := 1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	m.mesh = q
	m.material_override = Mats.screen(tex, energy)
	m.position = pos
	m.rotation.y = ry
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(m)
	return m


func tv(x: float, y: float, z: float, ry: float, w: float) -> void:
	var h := w * .5625
	var g := Node3D.new()
	g.position = Vector3(x, y, z)
	g.rotation.y = ry
	add_child(g)
	box(w + .08, h + .08, .06, Color("#0a0a10"), 0, 0, 0, g, "plastic")
	screen_quad(w, h, ad_tex.texture(), Vector3(0, 0, .031), 0, g, 1.0)
	tv_pos.append(Vector2(x, z))


func win(x: float, z: float, ry: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, 1.7, z)
	g.rotation.y = ry
	add_child(g)
	box(3, 1.3, .12, Color("#1d1d22"), 0, 0, 0, g, "metal")
	var view := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(2.7, 1.05)
	view.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = Mats.tex("outside")
	m.uv1_scale = Vector3(.45, 1, 1)
	m.uv1_offset = Vector3(fmod(absf(x * .37 + z * .11), .55), 0, 0)
	m.albedo_color = Color(1, 1, 1)
	view.material_override = m
	view.position.z = .065
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(view)
	window_mats.append(m)
	var gl := MeshInstance3D.new()
	var q2 := QuadMesh.new(); q2.size = Vector2(2.7, 1.05)
	gl.mesh = q2; gl.material_override = Mats.glass(); gl.position.z = .08
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(gl)
	# parteluz y alféizar
	box(.05, 1.05, .05, Color("#1d1d22"), 0, 0, .085, g, "metal")
	box(3.1, .05, .22, Color("#e8e2d8"), 0, -.67, .06, g, "plastic")
	# luz cálida que entra por la ventana
	var sl := SpotLight3D.new()
	sl.position = Vector3(0, .5, .6)
	sl.rotation_degrees = Vector3(-55, 180, 0)
	sl.light_color = Color("#ffd9a8")
	sl.light_energy = 2.2
	sl.spot_range = 5.0
	sl.spot_angle = 50
	sl.spot_attenuation = .8
	sl.shadow_enabled = true
	sl.light_specular = .3
	g.add_child(sl)


# ============ colisiones base (DK / WK del original) ============
func _init_collisions() -> void:
	Game.dk.clear()
	Game.wk.clear()
	for d in [[2,-1.9,1.2,.6],[10.5,.4,1.3,.7],[12.6,.9,.8,.55],[12.4,-2.55,1.05,.65],[13.4,-2.4,.55,.6],[16.9,-1.6,1.25,1],[17.6,1.7,.6,1.1],[15.6,2.6,1.05,.55],[4.7,-1.9,.5,.95],[7.3,-1.9,.5,.95]]:
		Game.dk.append(d)
	for w in [[-11.5,-4.2,-1.7,2.6],[-4.35,-3.6,-.8,.8],[-3.7,3.65,-2.5,2.6],[3.5,4.5,-.8,.8],[4.4,7.7,-2.5,20.6],[7.6,8.5,-.8,.8],[8.4,13.85,-2.5,2.6],[13.6,14.5,-.8,.8],[14.4,17.6,-2.5,2.6]]:
		Game.wk.append(w)


# ============ Oficina de TI ============
func _office() -> void:
	floor_rect(-4, 4, -3, 3, Color.WHITE, "tile", -.005)
	wall(8, 3, .2, WALL, 0, 1.5, -3)
	wall(.2, 3, 2.1, WALL, -4, 1.5, -1.95); wall(.2, 3, 2.1, WALL, -4, 1.5, 1.95); box(.2, 1, 1.8, WALL, -4, 2.5, 0, null, "plaster")
	wall(.2, 3, 2.1, WALL, 4, 1.5, -1.95); wall(.2, 3, 2.1, WALL, 4, 1.5, 1.95); box(.2, 1, 1.8, WALL, 4, 2.5, 0, null, "plaster")
	wall(8, 3, .2, WALL, 0, 1.5, 3)
	box(8, .2, 6, Color("#7a5a48"), 0, 3, 0, null, "wood")
	win(0, -2.88, 0); win(-1.6, 2.88, PI)
	lamp(-1.5, 0, Color("#fff2d6"), 1, .5, 1.6, 7, true)
	lamp(1.5, .3, Color("#fff2d6"), 1, .5, 1.6, 7, true)
	var pcl := OmniLight3D.new()
	pcl.position = Vector3(2, 1.3, -1.6); pcl.light_color = Color("#9a6aff"); pcl.light_energy = .8; pcl.omni_range = 2.5
	add_child(pcl)
	# reloj de pared
	var ck := MeshInstance3D.new()
	var cyl := CylinderMesh.new(); cyl.top_radius = .23; cyl.bottom_radius = .23; cyl.height = .04
	ck.mesh = cyl; ck.rotation_degrees.x = 90; ck.position = Vector3(-2.6, 2.3, -2.9)
	ck.material_override = Mats.get_mat("plastic", Color("#2a2230")); add_child(ck)
	var face := MeshInstance3D.new(); var fq := QuadMesh.new(); fq.size = Vector2(.42, .42); face.mesh = fq
	var fm := StandardMaterial3D.new(); fm.albedo_texture = clock_tex.texture(); fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	fm.roughness = .3
	face.material_override = fm; face.position = Vector3(-2.6, 2.3, -2.875); add_child(face)
	# impresora, dispensador, planta
	box(.45, .22, .35, Color("#dad4c8"), -1.7, .85, -2.7); box(.3, .04, .2, Color.WHITE, -1.7, .99, -2.6)
	box(.35, .9, .35, Color("#cfe3ee"), 3.4, .45, 2.4, null, "plastic"); _bottle(3.4, 1.05, 2.4)
	plant(-3.5, 2.4)
	poster(3.2, 1.7, -2.88, "MFA", "siempre", "#2f6f8f")
	poster(-3.45, 1.6, -2.88, "NO HAGAS", "CLIC", "#a63b2f")
	# escritorio con PC
	var desk := Node3D.new(); desk.position = Vector3(2, 0, -1.9); add_child(desk)
	box(2.2, .07, 1, Color("#77687a"), 0, .76, 0, desk)
	box(.5, .76, .95, Color("#15121a"), -.85, .38, 0, desk); box(.5, .76, .95, Color("#15121a"), .85, .38, 0, desk)
	for i in 3:
		box(.4, .015, .02, Color("#9aa3ad"), -.85, .62 - i * .22, .48, desk, "metal")
		box(.4, .015, .02, Color("#9aa3ad"), .85, .62 - i * .22, .48, desk, "metal")
	box(.1, .3, .05, Color("#222222"), 0, .9, -.15, desk); box(.3, .02, .2, Color("#222222"), 0, .8, -.15, desk)
	_keyboard(0, .8, .2, desk)
	screen_quad(.7, .44, desk_screen.texture(), Vector3(0, 1.18, -.077), 0, desk)
	box(.74, .48, .04, Color("#111111"), 0, 1.18, -.1, desk)
	_mug(.55, .8, .2, Color("#ff4f9a"), desk); box(.1, .1, .1, Color("#2a3a8a"), .7, .82, .1, desk)
	box(.24, .015, .16, Color("#1a1a2a"), -.6, .81, .15, desk); box(.2, .005, .12, Color("#5aa0ff"), -.6, .82, .15, desk, "plastic")
	box(.06, .02, .1, Color("#111111"), -.25, .8, .28, desk)
	box(.07, .07, .01, Color("#e8e04a"), .4, 1.4, -.07, desk, "plastic")
	# silla
	_chair(2.4, -1, -.5)
	# mueble largo
	box(2.6, .7, .5, Color("#efe6d6"), -1.5, .35, -2.7); box(2.6, .05, .5, Color("#c07a3a"), -1.5, .72, -2.7)
	var cols := ["ffffff","4c9a6a","2f6f8f","c4503f","ffffff","4c9a6a"]
	for i in 6:
		box(.5, .04, .35, Color(cols[i]), -2.2, .76 + i * .045, -2.7, null, "plastic")
	plant(-1.1, -2.7, .3, .5, .75)
	box(.25, .2, .15, Color("#2f6fd0"), -.4, .85, -2.7, null, "plastic")
	# CRT
	box(.5, .4, .45, Color("#b8b3a8"), .6, 2, -2.8, null, "plastic"); box(.4, .3, .05, Color("#222222"), .6, 2, -2.55, null, "plastic")
	box(.6, .04, .4, Color("#c07a3a"), .6, 1.75, -2.8)
	# estantería derecha
	box(.15, 2.4, 2, Color("#d8c7b0"), 3.9, 1.2, 2)
	for i in 4:
		box(.18, .04, 2, Color("#6a6a6a"), 3.85, .5 + i * .6, 2)
		_books(3.75, .52 + i * .6 + .12, 2, i)
	box(1.5, .02, .9, Color("#3a2a30"), 1.5, 2.97, -.5, null, "fabric")
	# letrero DATA CENTER
	var g := panel(.9, .22, Color("#1b2430"), Vector3(-3.88, 2.3, 0), PI / 2)
	label3d("DATA CENTER", 64, Color("#6ec1ff"), Vector3(0, 0, .01), 0, g).pixel_size = .0012
	# estaciones de usuarios
	_station(11.5, 4.4); _station(-1.5, 16.4); _station(11.5, 10.4)
	Game.dk.append([11.5, 4.4, 1, .7]); Game.dk.append([-1.5, 16.4, 1, .7]); Game.dk.append([11.5, 10.4, 1, .7])


func _bottle(x: float, y: float, z: float) -> void:
	var m := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = .13; c.bottom_radius = .14; c.height = .35
	m.mesh = c; m.position = Vector3(x, y, z)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.43, 0.76, 1.0, .55); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.roughness = .05
	m.material_override = mat; add_child(m)


func _mug(x: float, y: float, z: float, c: Color, parent: Node3D) -> void:
	var m := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = .045; cy.bottom_radius = .04; cy.height = .1
	m.mesh = cy; m.position = Vector3(x, y + .05, z); m.material_override = Mats.get_mat("plastic", c); parent.add_child(m)


func _keyboard(x: float, y: float, z: float, parent: Node3D, w := .45) -> void:
	box(w, .02, .15, Color("#222222"), x, y, z, parent, "plastic")
	box(w * .94, .006, .13, Color("#3a3a40"), x, y + .012, z, parent, "plastic")


func _books(x: float, y: float, z0: float, row: int) -> void:
	var r := RandomNumberGenerator.new(); r.seed = row * 31 + int(x * 10)
	var cols := ["2f6f8f","c0502a","4c9a6a","e8a03a","8a3fa0","f4f4f4","1f2a44"]
	var z := z0 - .85
	while z < z0 + .85:
		var t := r.randf_range(.04, .08)
		var h := r.randf_range(.18, .26)
		if r.randf() < .85:
			box(.16, h, t, Color(cols[r.randi() % cols.size()]), x, y - .12 + h / 2, z + t / 2, null, "plastic")
		z += t + .005


func _chair(x: float, z: float, ry: float, c := Color("#2f5fbf")) -> void:
	var ch := Node3D.new(); ch.position = Vector3(x, 0, z); ch.rotation.y = ry; add_child(ch)
	box(.6, .08, .6, c, 0, .5, 0, ch); box(.6, .7, .08, c, 0, .9, .3, ch)
	box(.08, .5, .08, Color("#222222"), 0, .25, 0, ch, "metal")
	box(.7, .05, .1, Color("#222222"), 0, .03, 0, ch, "metal"); box(.1, .05, .7, Color("#222222"), 0, .03, 0, ch, "metal")


func _station(x: float, z: float) -> void:
	var g := Node3D.new(); g.position = Vector3(x, 0, z); add_child(g)
	box(1.6, .07, .8, Color("#8a7a8e"), 0, .76, 0, g)
	box(.06, .76, .7, Color("#1a1620"), -.72, .38, 0, g); box(.06, .76, .7, Color("#1a1620"), .72, .38, 0, g)
	var ct := CanvasTex.make(self, Vector2i(512, 256), Callable())
	station_screens.append(ct)
	for dx in [-.38, .38]:
		box(.7, .42, .04, Color("#111111"), dx, 1.1, -.2, g)
		screen_quad(.64, .36, ct.texture(), Vector3(dx, 1.1, -.177), 0, g)
		box(.06, .3, .06, Color("#222222"), dx, .92, -.2, g)
		box(.07, .07, .01, Color("#e8e04a") if dx < 0 else Color("#7ddc6a"), dx + .33, 1.28, -.177, g, "plastic")
	_keyboard(0, .8, .1, g)
	_mug(.6, .8, .15, Color("#ff4f9a"), g)
	box(.5, .08, .5, Color("#2f5fbf"), 0, .5, .9, g); box(.5, .6, .07, Color("#2f5fbf"), 0, .85, 1.18, g)
	box(.08, .46, .08, Color("#222222"), 0, .23, .9, g, "metal")


func _d2(x: float, z: float) -> void:
	box(1.4, .07, .7, Color("#8a7a8e"), x, .76, z)
	box(.05, .76, .6, Color("#1a1620"), x - .65, .38, z); box(.05, .76, .6, Color("#1a1620"), x + .65, .38, z)
	box(.5, .35, .04, Color("#111111"), x, 1.08, z - .2)
	screen_quad(.46, .3, desk_static_tex.texture(), Vector3(x, 1.08, z - .177))
	box(.05, .18, .05, Color("#222222"), x, .88, z - .2, null, "metal")
	_keyboard(x, .8, z + .1, null, .4)
	box(.45, .07, .45, Color("#2f5fbf"), x, .5, z + .85); box(.45, .5, .06, Color("#2f5fbf"), x, .8, z + 1.1)
	box(.06, .46, .06, Color("#222222"), x, .23, z + .85, null, "metal")
	Game.dk.append([x, z, .9, .55])

var desk_static_tex: CanvasTex


# ============ Pasillo y apartamento ============
func _hall_and_apartment() -> void:
	floor_rect(4, 8, -3, 3, Color("#5a6070"), "concrete")
	floor_rect(8, 18, -3, 3, Color.WHITE, "woodfloor")
	wall(4, 3, .2, HW, 6, 1.5, -3); ceiling(4, 6, 6, 0, Color("#b8bcc4"))
	wall(.2, 3, 2.1, AW, 8, 1.5, -1.95); wall(.2, 3, 2.1, AW, 8, 1.5, 1.95); box(.2, 1, 1.8, AW, 8, 2.5, 0, null, "plaster")
	wall(10, 3, .2, AW, 13, 1.5, -3); wall(10, 3, .2, AW, 13, 1.5, 3); wall(.2, 3, 6, AW, 18, 1.5, 0); box(10, .2, 6, Color("#f2ece0"), 13, 3, 0, null, "plaster")
	wall(.2, 3, 2.1, AW, 14, 1.5, -1.95); wall(.2, 3, 2.1, AW, 14, 1.5, 1.95); box(.2, 1, 1.8, AW, 14, 2.5, 0, null, "plaster")
	win(9.6, -2.88, 0); win(16, -2.88, 0)
	lamp(6, 0, Color("#dfe8ff"), .8, .8, 1.8, 8, true)
	lamp(11, 0, Color("#ffe6b8"), .8, .8, 1.8, 8, true)
	lamp(16, 0, Color("#ffe6b8"), .8, .8, 1.6, 8)
	# ascensor
	box(1.8, 2.2, .1, Color("#9aa3ad"), 6, 1.1, -2.88, null, "metal"); box(.03, 2.2, .12, Color("#333333"), 6, 1.1, -2.86)
	box(.3, .12, .05, Color("#6ec1ff"), 6, 2.45, -2.86, null, "plastic")
	var ind := label3d("▲▼", 40, Color("#6ec1ff"), Vector3(6, 2.45, -2.83), 0); ind.pixel_size = .0015
	box(2.0, .1, .14, Color("#7a8088"), 6, 2.25, -2.86, null, "metal")
	box(.12, .2, .03, Color("#2a2a30"), 7.05, 1.2, -2.86, null, "metal")
	# bancas y planta
	box(.5, .4, 1.4, Color("#7a5a42"), 4.7, .2, -1.9); box(.5, .4, 1.4, Color("#7a5a42"), 7.3, .2, -1.9)
	plant(4.4, -2.5, .4, .8)
	poster(7.2, 1.7, -2.88, "PISO 5", "Aptos", "#2f6f8f")
	# sala
	box(2.2, .4, .9, Color("#3a7a5a"), 10.5, .2, .6); box(2.2, .55, .2, Color("#2f6a4a"), 10.5, .65, .15)
	box(.25, .3, .9, Color("#2f6a4a"), 9.35, .55, .6); box(.25, .3, .9, Color("#2f6a4a"), 11.65, .55, .6)
	for cx in [9.9, 10.5, 11.1]:
		box(.55, .12, .7, Color("#468a68"), cx, .46, .65, null, "fabric")
	floor_rect(9, 12, .3, 2.3, Color.WHITE, "rug", .008)
	box(1.6, .9, .08, Color("#0a0a10"), 10.5, 1.2, 2.85)
	screen_quad(1.5, .8, ad_tex.texture(), Vector3(10.5, 1.2, 2.805), PI, null, 1.0)
	tv_pos.append(Vector2(10.5, 2.8))
	box(1.8, .4, .45, Color("#2a2a30"), 10.5, .2, 2.65, null, "wood")
	# cocina
	box(1.8, .9, .7, Color("#efe6d6"), 12.4, .45, -2.6); box(1.9, .05, .75, Color("#555a62"), 12.4, .92, -2.6, null, "concrete")
	box(1.8, .6, .35, Color("#c9b79c"), 12.4, 2.1, -2.8); box(.8, 1.9, .8, Color("#dad4c8"), 13.4, .95, -2.4, null, "metal")
	box(.03, .6, .03, Color("#9aa3ad"), 13.05, 1.3, -1.99, null, "metal")
	box(.5, .04, .5, Color("#333333"), 12, .96, -2.6)
	for i in 4:
		var m := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = .05; t.outer_radius = .08
		m.mesh = t; m.position = Vector3(11.88 + (i % 2) * .24, .985, -2.72 + (i / 2) * .24)
		m.material_override = Mats.get_mat("metal", Color("#1a1a1a")); add_child(m)
	# comedor
	box(1.4, .06, .9, Color("#8a5a2a"), 12.6, .75, .9)
	for o in [[-.6, -.35], [.6, -.35], [-.6, .35], [.6, .35]]:
		box(.06, .72, .06, Color("#5a3a1a"), 12.6 + o[0], .36, .9 + o[1])
	for p in [[12.1, 1.7], [13.1, 1.7], [12.1, .1], [13.1, .1]]:
		box(.4, .05, .4, Color("#c07a3a"), p[0], .48, p[1]); box(.4, .45, .05, Color("#c07a3a"), p[0], .72, p[1] + (.2 if p[1] > .9 else -.2))
		for lx in [-.17, .17]:
			for lz in [-.17, .17]:
				box(.03, .46, .03, Color("#5a3a1a"), p[0] + lx, .23, p[1] + lz)
	var bowl := MeshInstance3D.new(); var bs := SphereMesh.new(); bs.radius = .2; bs.height = .2; bs.is_hemisphere = true
	bowl.mesh = bs; bowl.rotation_degrees.x = 180; bowl.position = Vector3(12.6, .98, .9)
	bowl.material_override = Mats.get_mat("plastic", Color("#f0a020")); add_child(bowl)
	for i in 4:
		var f := MeshInstance3D.new(); var fs := SphereMesh.new(); fs.radius = .06; fs.height = .12
		f.mesh = fs; f.position = Vector3(12.55 + (i % 2) * .1, .86 + .05, .85 + (i / 2) * .1)
		f.material_override = Mats.get_mat("plastic", [Color("#e8302a"), Color("#f0c020"), Color("#7ac040"), Color("#ff8a20")][i]); add_child(f)
	# lámpara de pie y planta
	box(.05, 1.6, .05, Color("#222222"), 8.7, .8, 2.4, null, "metal")
	box(.5, .35, .5, Color("#ffe2a8"), 8.7, 1.7, 2.4, null, "fabric")
	var fl := OmniLight3D.new(); fl.position = Vector3(8.7, 1.6, 2.3); fl.light_color = Color("#ffd29a"); fl.light_energy = .9; fl.omni_range = 3.5; add_child(fl)
	plant(8.6, -2.4, .4, .8)
	# dormitorio
	box(2, .3, 1.6, Color("#5a3a22"), 16.9, .15, -1.6); box(1.9, .25, 1.5, Color("#e8e4f4"), 16.9, .42, -1.6)
	box(.5, .12, .9, Color.WHITE, 17.5, .6, -1.6, null, "fabric"); box(1.2, .1, 1.5, Color("#2f6f8f"), 16.5, .58, -1.6, null, "fabric")
	box(.08, .9, 1.6, Color("#5a3a22"), 17.92, .6, -1.6)
	box(.7, 2.3, 1.6, Color("#7a5a42"), 17.6, 1.15, 1.7)
	box(.02, 2.1, .02, Color("#3a2a1a"), 17.24, 1.15, 1.7)
	box(.5, .5, .5, Color("#8a6a4a"), 15.4, .25, -2.6); box(.2, .3, .2, Color("#ffe2a8"), 15.4, .65, -2.6, null, "fabric")
	var nl := OmniLight3D.new(); nl.position = Vector3(15.4, .9, -2.5); nl.light_color = Color("#ffcf8a"); nl.light_energy = .5; nl.omni_range = 2.5; add_child(nl)
	box(1.6, .06, .7, Color("#6a6a72"), 15.6, .76, 2.6); box(.06, .76, .6, Color("#222222"), 14.85, .38, 2.6); box(.06, .76, .6, Color("#222222"), 16.35, .38, 2.6)
	box(.25, .5, .5, Color("#181820"), 16.1, .3, 2.4, null, "metal"); box(.03, .4, .03, Color("#39ff7a"), 16.2, .3, 2.14, null, "").material_override = Mats.unshaded(Color("#39ff7a"), 2.0)
	box(.7, .42, .04, Color("#111111"), 15.6, 1.1, 2.85)
	var code := CanvasTex.make(self, Vector2i(256, 160), func(ci: CanvasItem, sz: Vector2):
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("#0e1b2e"))
		for i in 12:
			ci.draw_rect(Rect2(16 + (i % 3) * 12, 14 + i * 11, 50 + ((i * 37) % 140), 5), Color("#39ff7a") if i % 4 else Color("#6ec1ff")))
	screen_quad(.64, .36, code.texture(), Vector3(15.6, 1.1, 2.827), PI)
	_keyboard(15.6, .8, 2.45, null, .4)
	box(.5, .05, .5, Color("#2f5fbf"), 15.6, .5, 1.9); box(.5, .5, .07, Color("#2f5fbf"), 15.6, .8, 1.65)


# ============ Data center ============
## Data Center: piso técnico con baldosas perforadas, dos filas de racks (pasillo frío al centro),
## bandejas de fibra, aire de precisión (CRAC), extinción FM-200, UPS, sensores ambientales
## y la consola SOC con 3 monitores y un videowall. Los LED de los equipos son un solo MultiMesh
## (cientos de luces en una llamada de dibujo) y parpadean cambiando el color de cada instancia.
var led_mm: MultiMesh
var led_base: PackedColorArray = []


func _datacenter() -> void:
	# piso técnico elevado: baldosas lisas y perforadas en el pasillo frío
	floor_rect(-12, -4, -3, 3, Color("#2a313c"), "concrete", .01)
	var tiles := MultiMesh.new(); tiles.transform_format = MultiMesh.TRANSFORM_3D
	var tm := BoxMesh.new(); tm.size = Vector3(.58, .01, .58); tiles.mesh = tm
	var xf := []
	for ix in 13:
		for iz in 10:
			xf.append(Transform3D(Basis(), Vector3(-11.7 + ix * .6, .022, -2.7 + iz * .6)))
	tiles.instance_count = xf.size()
	for k in xf.size(): tiles.set_instance_transform(k, xf[k])
	var tmi := MultiMeshInstance3D.new(); tmi.multimesh = tiles; tmi.material_override = Mats.get_mat("metal", Color("#8a929e")); add_child(tmi)
	for ix in 7:   # baldosas perforadas (rejilla) en el pasillo frío
		for iz in 3:
			box(.56, .012, .56, Color("#3a4450"), -11.4 + ix * 1.2, .03, -1.5 + iz * .6, null, "grille")
	wall(8, 3, .2, DW, -8, 1.5, -3); wall(8, 3, .2, DW, -8, 1.5, 3); wall(.2, 3, 6, DW, -12, 1.5, 0)
	ceiling(8, 6, -8, 0, Color("#1a2029"))
	# luz: tiras blancas sobre los pasillos y acento azul
	for z in [-1.0, .2]:
		var m := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(7, .03, .14)
		m.mesh = bm; m.material_override = Mats.unshaded(Color("#e8f4ff"), 3.5); m.position = Vector3(-8, 2.88, z); add_child(m)
	for z in [-1.9, .62]:
		var s2 := MeshInstance3D.new(); var sb := BoxMesh.new(); sb.size = Vector3(6.6, .02, .05)
		s2.mesh = sb; s2.material_override = Mats.unshaded(Color("#3aa0ff"), 3.0); s2.position = Vector3(-8.3, .04, z); add_child(s2)
	dc_light = OmniLight3D.new(); var dl := dc_light; dl.position = Vector3(-8, 2.5, -.6); dl.light_color = Color("#5aa0ff"); dl.light_energy = 1.4; dl.omni_range = 9; dl.shadow_enabled = true; add_child(dl)
	var dl2 := OmniLight3D.new(); dl2.position = Vector3(-8, 2.5, -.6); dl2.light_color = Color("#e8f4ff"); dl2.light_energy = 1.1; dl2.omni_range = 7; add_child(dl2)
	var dl3 := OmniLight3D.new(); dl3.position = Vector3(-5.6, 2.4, 2.0); dl3.light_color = Color("#cfe0ff"); dl3.light_energy = .7; dl3.omni_range = 4; add_child(dl3)
	# racks: fila A (fondo, mira al pasillo frío) y fila B (mira al fondo)
	led_off = Mats.unshaded(Color("#111111"))
	var names := ["Nexus 9300", "UCS C240", "Nexus 9300", "ASR 1001", "Catalyst 9300", "Catalyst 2960 · CORE"]
	var led_xf := []; led_base = PackedColorArray()
	var lc := [Color("#39ff7a"), Color("#ffb03a"), Color("#39ff7a"), Color("#4aa8ff")]
	var racks := []
	for i in 6: racks.append([Vector3(-11 + i * 1.2, 0, -2.4), 0.0, names[i], i == 5])
	for i in 4: racks.append([Vector3(-11 + i * 1.2, 0, 1.2), PI, ["Dell R750", "NetApp AFF", "Dell R750", "Palo Alto PA-3220"][i], false])
	for rk in racks:
		var rg := Node3D.new(); rg.position = rk[0]; rg.rotation.y = rk[1]; add_child(rg)
		box(.9, 2.3, .9, Color("#14171d"), 0, 1.15, 0, rg, "metal")
		box(.84, 2.2, .02, Color("#2c3440"), 0, 1.15, .455, rg, "grille")       # puerta perforada
		box(.06, 2.2, .04, Color("#9aa4b0"), .4, 1.15, .47, rg, "metal")         # manija / marco
		for u in 9:
			var two_u := u % 3 == 0
			box(.8, .19 if two_u else .14, .02, Color("#1a2028") if two_u else Color("#20262e"), 0, .3 + u * .22, .47, rg, "metal")
			for k in 4:
				led_xf.append(rg.transform * Transform3D(Basis(), Vector3(-.3 + k * .08, .3 + u * .22, .485)))
				led_base.append(lc[k])
			if two_u:   # bahías de disco con LED azul
				for k in 6:
					led_xf.append(rg.transform * Transform3D(Basis(), Vector3(.06 + k * .05, .3 + u * .22, .485)))
					led_base.append(Color("#3a8cff"))
		var front: Vector3 = Vector3(0, 2.2, .47).rotated(Vector3.UP, float(rk[1])) + (rk[0] as Vector3)
		var g := panel(.8, .125, Color("#0a5f8f") if rk[3] else Color("#0b2a3d"), front, rk[1])
		var lb3 := label3d(str(rk[2]), 44, Color.WHITE, Vector3(0, 0, .01), 0, g); lb3.pixel_size = .0012
		Game.dk.append([rk[0].x, rk[0].z, .55, .55])
	led_mm = MultiMesh.new(); led_mm.transform_format = MultiMesh.TRANSFORM_3D; led_mm.use_colors = true
	var lm2 := BoxMesh.new(); lm2.size = Vector3(.03, .03, .02); led_mm.mesh = lm2
	led_mm.instance_count = led_xf.size()
	for k in led_xf.size():
		led_mm.set_instance_transform(k, led_xf[k]); led_mm.set_instance_color(k, led_base[k])
	var lmat := StandardMaterial3D.new(); lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lmat.vertex_color_use_as_albedo = true
	var lmi := MultiMeshInstance3D.new(); lmi.multimesh = led_mm; lmi.material_override = lmat
	lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lmi)
	# bandejas de fibra (amarillas) y escalerillas sobre cada fila
	for z in [-2.4, 1.2]:
		box(7.2, .06, .3, Color("#f2c200"), -8.2, 2.55, z, null, "plastic")
		box(7.2, .04, .42, Color("#555b66"), -8.2, 2.66, z, null, "metal")
		for i in 14: box(.03, .1, .42, Color("#555b66"), -11.6 + i * .52, 2.6, z, null, "metal")
	# aire de precisión (CRAC) al final del pasillo frío
	box(.7, 2.3, 1.6, Color("#e8ecef"), -11.6, 1.15, -.65, null, "plastic")
	for k in 6: box(.02, .08, 1.3, Color("#9aa4b0"), -11.24, .5 + k * .25, -.65, null, "metal")
	label3d("CRAC-01 · 18 °C", 40, Color("#1d6fd0"), Vector3(-11.23, 2.0, -.65), PI / 2).pixel_size = .002
	# UPS y baterías junto a la entrada
	box(.6, 1.8, .8, Color("#2a2f38"), -4.6, .9, -2.4, null, "metal")
	box(.5, .25, .02, Color("#0a1a10"), -4.6, 1.4, -1.99, null, "plastic")
	label3d("UPS 20 kVA · 98 %", 36, Color("#39ff7a"), Vector3(-4.6, 1.4, -1.97), 0).pixel_size = .0016
	Game.dk.append([-4.6, -2.4, .45, .55])
	# extinción FM-200: tubería roja y boquillas
	box(7.6, .07, .07, Color("#c4302a"), -8, 2.78, -1.0, null, "metal")
	for k in 3: box(.08, .14, .08, Color("#d8d8d8"), -10.5 + k * 2.5, 2.7, -1.0, null, "metal")
	var fs := panel(.5, .3, Color("#c4302a"), Vector3(-11.88, 2.1, 1.9), PI / 2)
	label3d("FM-200\nEXTINCIÓN", 36, Color.WHITE, Vector3(0, 0, .01), 0, fs).pixel_size = .0012
	# sensor ambiental en la pared
	var env_p := panel(.7, .32, Color("#0b1622"), Vector3(-9.5, 1.7, -2.88), 0)
	label3d("🌡 19.6 °C   💧 45 % HR\nPUE 1.4 · Energía OK", 34, Color("#9affc0"), Vector3(0, 0, .01), 0, env_p).pixel_size = .0011
	# ---- consola SOC: escritorio, 3 monitores, silla y videowall ----
	var socx := -5.7; var socz := 2.25
	box(2.4, .06, .8, Color("#3a3f48"), socx, .76, socz, null, "metal")
	for sx in [-1.1, 1.1]: box(.06, .74, .7, Color("#2a2f38"), socx + sx, .38, socz, null, "metal")
	var soc_tex := CanvasTex.make(self, Vector2i(512, 288), _paint_soc)
	for k in 3:
		var a := (k - 1) * .35
		var mon := Node3D.new(); mon.position = Vector3(socx + (k - 1) * .74, 1.12, socz + .18 + absf(k - 1) * .06); mon.rotation.y = PI - a; add_child(mon)
		box(.68, .4, .03, Color("#111418"), 0, 0, 0, mon, "plastic")
		var scr := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(.64, .36); scr.mesh = qm
		scr.material_override = Mats.screen(soc_tex.texture(), 1.4); scr.position = Vector3(0, 0, .017)   # la pantalla mira a la silla
		mon.add_child(scr)
		box(.05, .3, .05, Color("#2a2f38"), 0, -.32, -.03, mon, "metal")
	box(.5, .5, .5, Color("#1d1f24"), socx, .5, socz - .75, null, "leather")   # silla
	box(.5, .6, .08, Color("#1d1f24"), socx, .95, socz - 1.0, null, "leather")
	var wall_tex := CanvasTex.make(self, Vector2i(768, 300), _paint_videowall)
	var vw := MeshInstance3D.new(); var vq := QuadMesh.new(); vq.size = Vector2(2.3, .9); vw.mesh = vq
	vw.material_override = Mats.screen(wall_tex.texture(), 1.6); vw.position = Vector3(socx, 2.05, 2.86); vw.rotation.y = PI
	add_child(vw)
	box(2.4, 1.0, .05, Color("#111418"), socx, 2.05, 2.89, null, "plastic")
	label3d("🛡️ SOC · Centro de Operaciones de Seguridad", 40, Color("#ff8aa8"), Vector3(socx, 2.68, 2.86), PI).pixel_size = .0014
	Game.dk.append([socx, socz, 1.3, .5])


func _paint_soc(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("#07101a"))
	var f := CanvasTex.font(true); var fr := CanvasTex.font(false)
	ci.draw_string(f, Vector2(14, 30), "SIEM · CAA Corp", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ff8aa8"))
	ci.draw_string(fr, Vector2(330, 30), "NIST SP 800-61", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, .6))
	var vals := [12, 18, 9, 25, 30, 14, 22, 40, 28, 16, 11, 19, 33, 21]
	for i in vals.size():
		var h: float = vals[i] * 3.2
		ci.draw_rect(Rect2(20 + i * 34, 210 - h, 24, h), Color("#3a8cff") if vals[i] < 30 else Color("#ff5a4a"))
	ci.draw_line(Vector2(16, 212), Vector2(sz.x - 16, 212), Color(1, 1, 1, .3), 2)
	var rows := [["CRÍTICA", "Movimiento lateral · PC_RRHH", Color("#ff5a4a")], ["ALTA", "Phishing reportado · Ventas", Color("#ffb03a")], ["MEDIA", "Login fallido x12 · VPN", Color("#f2e05a")]]
	for i in rows.size():
		ci.draw_rect(Rect2(14, 226 + i * 20, 70, 16), rows[i][2])
		ci.draw_string(f, Vector2(18, 239 + i * 20), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
		ci.draw_string(fr, Vector2(92, 239 + i * 20), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _paint_videowall(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("#050b14"))
	var f := CanvasTex.font(true)
	# mapa estilizado con puntos de tráfico de red
	for i in 140:
		var x := 30.0 + fmod(i * 97.13, 470.0); var y := 50.0 + fmod(i * 53.7, 220.0)
		ci.draw_circle(Vector2(x, y), 2.0, Color(.3, .7, 1.0, .55))
	for k in 8:
		var a := Vector2(60 + k * 55, 90 + (k % 3) * 50); var b := Vector2(265, 170)
		ci.draw_line(a, b, Color(1, .4, .5, .5) if k % 3 == 0 else Color(.3, .8, 1, .35), 2)
	ci.draw_circle(Vector2(265, 170), 7, Color("#ffb03a"))
	ci.draw_string(f, Vector2(24, 36), "TRÁFICO GLOBAL · EN VIVO", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#9ad8ff"))
	ci.draw_rect(Rect2(530, 50, 214, 220), Color(1, 1, 1, .06))
	var kpi := [["Alertas abiertas", "3", Color("#ff5a4a")], ["Eventos / min", "1.284", Color("#9affc0")], ["Equipos protegidos", "212", Color("#9ad8ff")], ["Disponibilidad", "99,98 %", Color("#f2e05a")]]
	for i in kpi.size():
		ci.draw_string(CanvasTex.font(false), Vector2(544, 78 + i * 52), kpi[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, .7))
		ci.draw_string(f, Vector2(544, 102 + i * 52), kpi[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, kpi[i][2])


# ============ Piso 1: departamentos ============
const RM := [[-4,4,3,9,"RECURSOS HUMANOS","#b59ac4","#8a3fa0"],[-4,4,9,15,"CENTRO DE COPIADO","#9aa6b0","#1f7f8f"],[-4,4,15,21,"OPERACIONES","#8b7d6a","#8a6a2a"],[8,16,3,9,"CONTABILIDAD","#9ab59a","#2f7a4a"],[8,16,9,15,"VENTAS","#c4a46a","#c0502a"],[8,16,15,21,"GERENCIA","#6a4a3a","#0b2a4a"]]

func _rooms(list: Array, ox: float, corridor_x: float) -> void:
	for r in list:
		var x0: float = r[0] + ox
		var x1: float = r[1] + ox
		var cx := (x0 + x1) / 2
		var cz: float = (r[2] + r[3]) / 2.0
		var w := x0 < corridor_x
		floor_rect(x0, x1, r[2], r[3], Color(r[5]).lightened(.15), "carpet")
		ceiling(8, 6, cx, cz)
		lamp(cx - 1.8, cz, Color("#fff2d6"), 1, .6, 1.3, 6)
		lamp(cx + 1.8, cz, Color("#fff2d6"), 1, .6, 1.3, 6)
		sgn(corridor_x + .11 if w else corridor_x + 3.89, 2.55, cz, PI / 2 if w else -PI / 2, r[4], r[6])


func _floor1_departments() -> void:
	desk_static_tex = CanvasTex.make(self, Vector2i(512, 320), func(ci: CanvasItem, sz: Vector2): CanvasTex.paint_desk(ci, sz, {"clk": "09:00"}))
	floor_rect(4, 8, 3, 21, Color("#5a6070"), "concrete")
	ceiling(4, 18, 6, 12, Color("#b8bcc4"))
	for z in [6.0, 12.0, 18.0]:
		lamp(6, z, Color("#dfe8ff"), 1, .6, 1.5, 8)
	_rooms(RM, 0, 4)
	wX(4, 3, 21, [6, 12, 18]); wX(-4, 3, 21, []); wX(8, 3, 21, [6, 12, 18]); wX(16, 3, 21, [])
	wZ(9, -4, 4); wZ(15, -4, 4); wZ(9, 8, 16); wZ(15, 8, 16); wZ(21, -4, 16)
	for g in [6.0, 12.0, 18.0]:
		Game.wk.append([3.5, 4.5, g - .8, g + .8]); Game.wk.append([7.5, 8.5, g - .8, g + .8])
		Game.wk.append([-3.7, 3.65, g - 2.5, g + 2.5]); Game.wk.append([8.4, 15.6, g - 2.5, g + 2.5])
	logo(6, 2.72, 20.88, PI, .95); logo(7.88, 1.7, -2.1, -PI / 2, 1.6); logo(1.8, 1.8, 2.88, PI, 1.6)
	sgn(-1.2, 2.1, 2.88, PI, "TICKETS PENDIENTES", "#2f6f8f")
	fb(.35, .9, .35, Color("#cfe3ee"), 7.6, .45, 3.8, "plastic"); _bottle(7.6, 1.05, 3.8)
	plant(4.6, 9, .4, .7); plant(7.5, 15, .4, .7)
	fb(1.8, .08, .9, Color("#8a7a8e"), -1.2, .75, .3)
	box(.08, .72, .08, Color("#222222"), -1.2, .36, .3, null, "metal")
	box(.6, .03, .6, Color("#222222"), -1.2, .015, .3, null, "metal")
	for p in [[-1.2, -.6], [-1.2, 1.2], [-2.2, .3]]:
		box(.4, .45, .4, Color("#2f5fbf"), p[0], .25, p[1])
	# RRHH
	_d2(-2.4, 4.3); _d2(.4, 4.3)
	fb(.5, 1.5, .9, Color("#8a9aa8"), -3.6, .75, 5.7); fb(.5, 1.5, .9, Color("#8a9aa8"), -3.6, .75, 6.8)
	for zz in [5.7, 6.8]:
		for i in 3:
			box(.02, .03, .3, Color("#d9d9de"), -3.34, .35 + i * .45, zz, null, "metal")
	fb(1.4, .08, 1.4, Color("#8a5a2a"), 1.8, .75, 7.6)
	box(.1, .72, .1, Color("#5a3a1a"), 1.8, .36, 7.6)
	for p in [[1.8, 6.6], [1.8, 8.6], [.8, 7.6]]:
		box(.4, .45, .4, Color("#8a3fa0"), p[0], .25, p[1], null, "fabric")
	poster(-.9, 1.7, 3.12, "RRHH", "Bienvenid@", "#8a3fa0"); poster(2.4, 1.7, 3.12, "CAA", "Valores", "#0b2a4a")
	plant(-3.4, 8.4, .4, .7, 0, true)
	# Centro de copiado
	for x in [-2.6, -1.2]:
		fb(1.1, 1.1, .7, Color("#dad4c8"), x, .55, 10.2)
		box(.45, .06, .25, Color("#2f6f8f"), x, 1.14, 10.15, null, "plastic")
		box(.9, .04, .5, Color("#bfb8aa"), x, 1.12, 10.3, null, "plastic")
		box(.6, .12, .02, Color("#3a3a40"), x, .4, 10.56, null, "plastic")
		box(.6, .12, .02, Color("#3a3a40"), x, .7, 10.56, null, "plastic")
	box(.5, .04, .3, Color.WHITE, -2.6, .95, 10.65)
	fb(1.6, .9, .6, Color("#cfd4da"), 1.4, .45, 10.2); box(1.4, .05, .5, Color("#2a2a30"), 1.4, .93, 10.2)
	fb(2.2, .8, .8, Color("#8a8a92"), .2, .4, 13.9)
	for i in 4:
		box(.4, .1, .3, Color.WHITE, -.4 + i * .5, .85, 13.9)
	fb(.45, .7, .4, Color("#333333"), -3.4, .35, 13.6)
	poster(2.8, 1.7, 9.12, "COPIAS", "e impresión", "#1f7f8f")
	# Operaciones
	fb(.6, 2, 3, Color("#7a6a5a"), -3.55, 1, 17.4)
	for i in 3:
		box(.4, .4, .8, Color("#b98b5a"), -3.45, .5 + i * .7, 16.7 + i * .5)
	fb(.8, .8, .8, Color("#b98b5a"), 2.8, .4, 19.5); box(.7, .6, .7, Color("#c99b6a"), 2.9, 1.1, 19.5)
	# Contabilidad
	_d2(14.2, 4.4)
	fb(.9, 1, .9, Color("#444444"), 15.2, .5, 7.8); box(.3, .02, .2, Color("#ffd34a"), 15.2, 1.02, 7.8, null, "plastic")
	var dial := MeshInstance3D.new(); var dc := CylinderMesh.new(); dc.top_radius = .08; dc.bottom_radius = .08; dc.height = .03
	dial.mesh = dc; dial.rotation_degrees.x = 90; dial.position = Vector3(15.2, .6, 7.36); dial.material_override = Mats.get_mat("metal", Color("#c9c9cf")); add_child(dial)
	fb(.5, 1.5, .9, Color("#8a9aa8"), 15.6, .75, 5.7)
	poster(9.2, 1.7, 3.12, "FINANZAS", "Cierre de mes", "#2f7a4a")
	# Ventas
	_d2(14.2, 10.4)
	box(2.4, 1.3, .05, Color("#f4f4f4"), 12.8, 1.7, 9.12, null, "plastic")
	box(2.5, .05, .07, Color("#9aa3ad"), 12.8, 1.04, 9.14, null, "metal")
	box(2, .05, .03, Color("#c0502a"), 12.8, 1.9, 9.15, null, "plastic"); box(1.6, .05, .03, Color("#2f6f8f"), 12.8, 1.6, 9.15, null, "plastic")
	fb(.9, .8, .4, Color("#8a5a2a"), 9, .4, 13.6); box(.15, .3, .15, Color("#ffc83a"), 9, .95, 13.6, null, "metal")
	poster(9.2, 1.7, 9.12, "VENTAS", "Meta x2", "#c0502a")
	# Gerencia
	fb(2.4, .08, 1.1, Color("#3a2a1a"), 12.5, .78, 17.2)
	box(.1, .76, 1, Color("#2a1a0a"), 11.4, .38, 17.2); box(.1, .76, 1, Color("#2a1a0a"), 13.6, .38, 17.2)
	box(.6, .4, .04, Color("#111111"), 12.5, 1.12, 17)
	screen_quad(.56, .34, desk_static_tex.texture(), Vector3(12.5, 1.12, 17.023))
	box(.6, .1, .6, Color("#1a1a1a"), 12.5, .5, 18.1); box(.6, .8, .1, Color("#1a1a1a"), 12.5, .95, 18.4)
	fb(.4, 2.2, 3, Color("#5a3a22"), 15.6, 1.1, 18.2)
	var bc := ["2f6f8f", "c0502a", "4c9a6a", "e8a03a", "8a3fa0"]
	for i in 5:
		box(.3, .3, .4, Color(bc[i]), 15.55, .6 + i * .4, 17 + i * .5, null, "plastic")
	fb(2, .4, .8, Color("#3a3a4a"), 10, .2, 20.3); box(2, .5, .15, Color("#3a3a4a"), 10, .6, 20.65)
	# cafetera y máquina expendedora
	fb(.5, .9, .6, Color("#dad4c8"), 7.6, .45, 9); box(.3, .14, .3, Color("#2a2a30"), 7.45, 1.0, 9, null, "metal")
	box(.06, .06, .06, Color("#e0302a"), 7.33, .8, 9.25).material_override = Mats.unshaded(Color("#e0302a"), 2.0)
	fb(.6, 1.5, .5, Color("#2f6f8f"), 4.4, .75, 15)
	var vg := box(.04, .7, .4, Color("#9fe0ff"), 4.72, 1.05, 15); vg.material_override = Mats.unshaded(Color("#9fe0ff"), 1.5)
	box(.04, .2, .3, Color("#ffc83a"), 4.72, .5, 15, null, "plastic")
	tv(3.2, 1.75, 2.86, PI, 1.1); tv(7.86, 1.7, 1.9, -PI / 2, 1.3)
	sgn(6, 2.55, -2.86, 0, "PISO 1", "#0b2a4a")


# ============ Piso 2 ============
const R2 := [[-4,4,3,9,"TALLER DE REPARACIÓN","#8a96a2","#1f4f7f"],[-4,4,9,15,"ALMACÉN DE PIEZAS","#7a7060","#8a6a2a"],[-4,4,15,21,"SOPORTE N2","#9ab5c4","#2f6f8f"],[8,16,3,9,"MARKETING","#c49ab5","#c0306a"],[8,16,9,15,"LEGAL","#b5ab9a","#5a4a2a"],[8,16,15,21,"CAPACITACIÓN","#9ac4a8","#2f7a4a"]]

func _floor2() -> void:
	floor_rect(OX + 4, OX + 8, -3, 21, Color("#5a6070"), "concrete")
	ceiling(4, 24, OX + 6, 9, Color("#b8bcc4"))
	for z in [0.0, 6.0, 12.0, 18.0]:
		lamp(OX + 6, z, Color("#dfe8ff"), 1, .6, 1.5, 8)
	wall(.2, 3, 6, IW, OX + 4, 1.5, 0); wall(.2, 3, 6, IW, OX + 8, 1.5, 0); wall(4, 3, .2, IW, OX + 6, 1.5, -3)
	box(1.8, 2.2, .1, Color("#9aa3ad"), OX + 6, 1.1, -2.88, null, "metal"); box(.03, 2.2, .12, Color("#333333"), OX + 6, 1.1, -2.86)
	box(.3, .12, .05, Color("#6ec1ff"), OX + 6, 2.45, -2.86, null, "plastic")
	box(2.0, .1, .14, Color("#7a8088"), OX + 6, 2.25, -2.86, null, "metal")
	_rooms(R2, OX, OX + 4)
	wX(OX + 4, 3, 21, [6, 12, 18]); wX(OX - 4, 3, 21, []); wX(OX + 8, 3, 21, [6, 12, 18]); wX(OX + 16, 3, 21, [])
	wZ(3, OX - 4, OX + 4); wZ(3, OX + 8, OX + 16); wZ(9, OX - 4, OX + 4); wZ(15, OX - 4, OX + 4); wZ(9, OX + 8, OX + 16); wZ(15, OX + 8, OX + 16); wZ(21, OX - 4, OX + 16)
	for g in [6.0, 12.0, 18.0]:
		Game.wk.append([OX + 3.5, OX + 4.5, g - .8, g + .8]); Game.wk.append([OX + 7.5, OX + 8.5, g - .8, g + .8])
		Game.wk.append([OX - 3.7, OX + 3.65, g - 2.5, g + 2.5]); Game.wk.append([OX + 8.4, OX + 15.6, g - 2.5, g + 2.5])
	Game.wk.append([OX + 4.4, OX + 7.7, -2.5, 20.6])
	logo(OX + 6, 1.9, 20.88, PI, 2.8); logo(OX + 6, 2.6, -2.86, 0, 1.2)
	tv(OX + 7.86, 1.8, 1.9, -PI / 2, 1.4)
	plant(OX + 4.6, -2.4, .4, .7)
	# Taller
	for bx in [OX - 1.6, OX + 1.6]:
		_bench(bx, 4.4)
	fb(.6, 1.8, 1.4, Color("#b03a2a"), OX + 3.5, .9, 7.2, "metal")
	for i in 5:
		box(.02, .02, 1.2, Color("#d9d9de"), OX + 3.19, .3 + i * .33, 7.2, null, "metal")
	fb(1.6, .8, .7, Color("#8a8a92"), OX - 3.2, .4, 8.4)
	poster(OX - 2.6, 1.7, 3.12, "TALLER", "Cambio de piezas", "#1f4f7f"); poster(OX + 1.2, 1.7, 3.12, "ESD", "Pulsera antiestática", "#a63b2f")
	# Almacén
	fb(.6, 2.1, 4, Color("#6a5a4a"), OX - 3.55, 1.05, 12); fb(.6, 2.1, 1.6, Color("#6a5a4a"), OX + 3.55, 1.05, 10)
	var cc := ["c0502a", "2f6f8f", "4c9a6a", "e8a03a", "8a3fa0"]
	for i in 5:
		for k in 3:
			box(.4, .3, .5, Color(cc[i]), OX - 3.3, .5 + i * .42, 10.6 + k * 1.1, null, "plastic")
			box(.4, .3, .5, Color(cc[i]), OX + 3.3, .5 + i * .42, 9.5 + k * .5, null, "plastic")
	fb(2.4, .9, .7, Color("#efe6d6"), OX, .45, 10.2); box(.5, .35, .04, Color("#111111"), OX, 1.2, 10.1)
	poster(OX - 1, 1.7, 9.12, "ALMACÉN", "Piezas y repuestos", "#8a6a2a")
	# Soporte N2
	_d2(OX - 2.4, 16.3); _d2(OX + .4, 16.3)
	fb(.5, 1.6, .9, Color("#8a9aa8"), OX + 3.5, .8, 17.5)
	box(2.2, 1.2, .05, Color("#f4f4f4"), OX + 1.8, 1.7, 15.12, null, "plastic")
	poster(OX - 3, 1.7, 15.12, "N2", "Escalamiento", "#2f6f8f")
	# Marketing, Legal y Capacitación
	_d2(OX + 10.4, 4.3); _d2(OX + 13.6, 4.3); tv(OX + 15.86, 1.8, 6.2, -PI / 2, 2)
	poster(OX + 9, 1.7, 3.12, "MARKETING", "Campañas", "#c0306a")
	_d2(OX + 10.4, 10.3); _d2(OX + 13.6, 10.3); fb(.5, 1.6, .9, Color("#8a9aa8"), OX + 15.5, .8, 13)
	poster(OX + 9, 1.7, 9.12, "LEGAL", "Contratos", "#5a4a2a")
	_d2(OX + 10.4, 16.4); fb(3, .08, 1.2, Color("#8a5a2a"), OX + 13, .75, 19.3)
	for p in [[OX + 12, 18.4], [OX + 13, 18.4], [OX + 14, 18.4]]:
		box(.4, .45, .4, Color("#2f7a4a"), p[0], .25, p[1], null, "fabric")
	tv(OX + 15.86, 1.9, 18, -PI / 2, 2.4)


func _bench(x: float, z: float) -> void:
	fb(2.6, .08, 1, Color("#6a6a72"), x, .95, z)
	box(.08, .93, .9, Color("#3a3a42"), x - 1.2, .47, z); box(.08, .93, .9, Color("#3a3a42"), x + 1.2, .47, z)
	box(1.2, .01, .7, Color("#2f4a5f"), x - .5, 1, z, null, "fabric")
	box(.5, .42, .5, Color("#20242c"), x - .5, 1.22, z, null, "metal")
	box(.4, .02, .4, Color("#1f7a4a"), x - .5, 1.45, z, null, "plastic")
	box(.1, .03, .35, Color("#2a2a2a"), x - .35, 1.47, z); box(.1, .03, .35, Color("#2a2a2a"), x - .2, 1.47, z)
	box(.2, .08, .12, Color("#e8a03a"), x + .7, 1, z + .1, null, "plastic")
	box(.5, .35, .04, Color("#111111"), x + .9, 1.3, z - .3)
	screen_quad(.46, .3, desk_static_tex.texture(), Vector3(x + .9, 1.3, z - .277))


# ============ Fase 3: objetos interactivos y decoración ============
static func mk_item(k: String) -> Node3D:
	var g := Node3D.new()
	var put := func(mesh: Mesh, c: Color, pos: Vector3, kind := "plastic"):
		var m := MeshInstance3D.new(); m.mesh = mesh; m.position = pos
		m.material_override = Mats.get_mat(kind, c); g.add_child(m); return m
	var cyl := func(r: float, h: float, r2 := -1.0) -> CylinderMesh:
		var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r if r2 < 0 else r2; c.height = h; c.radial_segments = 16; return c
	var bx := func(w: float, h: float, d: float) -> BoxMesh:
		var b := BoxMesh.new(); b.size = Vector3(w, h, d); return b
	match k:
		"coffee", "water":
			put.call(cyl.call(.045, .11, .034), Color("#f4f4f4"), Vector3.ZERO)
			put.call(cyl.call(.046, .03), Color("#8a4a2a") if k == "coffee" else Color("#2f6f8f"), Vector3.ZERO)
			var liq = put.call(cyl.call(.04, .006), Color("#6a3a1a") if k == "coffee" else Color("#b8e4ff"), Vector3(0, .05, 0))
			g.set_meta("liq", liq)
			if k == "coffee": put.call(cyl.call(.047, .008), Color("#e0e0e0"), Vector3(0, .058, 0))
		"paper":
			for i in 8: put.call(bx.call(.21, .004, .297), Color("#fafafa"), Vector3((i % 2) * .002, i * .0045, (i % 3) * .002))
			for i in 5: put.call(bx.call(.15, .001, .008), Color("#666a74"), Vector3(0, .038, -.09 + i * .04))
		"sand":
			put.call(bx.call(.14, .022, .1), Color("#e6c58a"), Vector3.ZERO)
			put.call(bx.call(.13, .01, .09), Color("#4c9a6a"), Vector3(0, .016, 0))
			put.call(bx.call(.12, .008, .08), Color("#c4302a"), Vector3(0, .024, 0))
			put.call(bx.call(.14, .022, .1), Color("#f2d8a0"), Vector3(0, .038, 0))
		"soda":
			put.call(cyl.call(.03, .12), Color("#c4302a"), Vector3.ZERO, "metal")
			put.call(cyl.call(.027, .008), Color("#cfd4da"), Vector3(0, .062, 0), "metal")
		"apple":
			var sp := SphereMesh.new(); sp.radius = .036; sp.height = .068
			put.call(sp, Color("#c4302a"), Vector3.ZERO)
			put.call(bx.call(.006, .025, .006), Color("#5a3a1a"), Vector3(0, .04, 0))
		"yog":
			put.call(cyl.call(.035, .08, .028), Color("#f4f4f4"), Vector3.ZERO)
			put.call(cyl.call(.036, .03), Color("#e86aa0"), Vector3.ZERO)
	return g


func _phase3() -> void:
	# nevera
	Game.dk.append([7.55, 10.2, .575, .6])
	var fg := Node3D.new(); fg.position = Vector3(7.55, 0, 10.2); add_child(fg)
	var wc := Color("#dfe3e8")
	box(.06, 1.75, .7, wc, .3, .875, 0, fg, "metal"); box(.65, 1.75, .04, wc, 0, .875, -.33, fg, "metal"); box(.65, 1.75, .04, wc, 0, .875, .33, fg, "metal")
	box(.65, .04, .7, wc, 0, 1.75, 0, fg, "metal"); box(.65, .04, .7, wc, 0, .02, 0, fg, "metal")
	for y in [.12, .58, 1.02, 1.42]: box(.58, .02, .62, Color("#cfd8e0"), 0, y, 0, fg, "plastic")
	var fl := OmniLight3D.new(); fl.position = Vector3(0, 1.5, 0); fl.light_color = Color("#e8f4ff"); fl.light_energy = .4; fl.omni_range = 1.2; fg.add_child(fl)
	for d in [["sand", .12, -.1], ["soda", .58, .12], ["apple", 1.02, 0.0], ["yog", 1.42, .1]]:
		var it := mk_item(d[0]); it.position = Vector3(-.05, d[1] + .07, d[2]); it.scale = Vector3.ONE * 1.8
		fg.add_child(it); fridge_items[d[0]] = it
	fridge_door = Node3D.new(); fridge_door.position = Vector3(-.34, 0, .35); fg.add_child(fridge_door)
	box(.06, 1.72, .7, Color("#eef1f4"), 0, .875, -.35, fridge_door, "metal")
	box(.03, .5, .04, Color("#9aa0a8"), -.045, 1.1, -.62, fridge_door, "metal")
	# impresora de la sala de copiado
	fb(.5, .8, .8, Color("#3a3a42"), -3.45, .4, 13.8, "metal")
	var pg := Node3D.new(); pg.position = Vector3(-3.45, 0, 13.8); add_child(pg)
	box(.46, .26, .7, Color("#e8e8ee"), 0, .93, 0, pg, "plastic"); box(.46, .05, .7, Color("#cfd3da"), 0, 1.08, 0, pg, "plastic")
	box(.02, .1, .3, Color("#2a2d36"), .24, .95, 0, pg, "plastic")
	printer_led = box(.02, .02, .02, Color("#38e08a"), .24, 1.02, .26, pg); printer_led.material_override = Mats.unshaded(Color("#38e08a"), 2.0)
	for i in 6:
		var sh := box(.2, .003, .28, Color("#fafafa"), .34, .98 + i * .004, 0, pg, "plastic"); sh.visible = false; printer_sheets.append(sh)
	# chorros de la cafetera y el dispensador
	var stream := func(x: float, y: float, z: float, c: Color) -> MeshInstance3D:
		var m := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = .008; cm.bottom_radius = .008; cm.height = .12
		m.mesh = cm; m.material_override = Mats.unshaded(c); m.position = Vector3(x, y, z); m.visible = false; add_child(m); return m
	coffee_stream = stream.call(7.42, .93, 9, Color("#5a3418"))
	water_stream = stream.call(7.43, .85, 3.8, Color("#9fd8ff"))
	# sala de cámaras: escritorio con 4 monitores
	Game.dk.append([-3.35, 1.0, .5, .85])
	box(.5, .8, 1.2, Color("#3a3a42"), -3.35, .4, 1.0, null, "metal")
	for i in 4:
		var mm := box(.04, .28, .4, Color.BLACK, -3.5, 1.15 + floor(i / 2.0) * .32, .7 + (i % 2) * .45)
		mm.material_override = Mats.unshaded(Color("#38e0ff") if i % 2 else Color("#40ff9a"), 1.2)
	# marcador del cable troncal en el rack (parpadea en rojo)
	trunk_mark = MeshInstance3D.new(); var tb := BoxMesh.new(); tb.size = Vector3(.25, .12, .05)
	trunk_mark.mesh = tb; trunk_mark.material_override = Mats.unshaded(Color("#ff2a2a"), 4.0)
	trunk_mark.position = Vector3(-9.8, 1.2, -1.88); trunk_mark.visible = false; add_child(trunk_mark)
	# baliza de alarma del data center (shader de pulso + barrido)
	var bm := MeshInstance3D.new(); var bq := QuadMesh.new(); bq.size = Vector2(2.2, 2.2); bm.mesh = bq
	var sh2 := Shader.new()
	sh2.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float on = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float glow = smoothstep(0.5, 0.0, d);
	float pulse = 0.55 + 0.45 * sin(TIME * 9.42);
	float sweep = 0.5 + 0.5 * sin(atan(UV.y - 0.5, UV.x - 0.5) * 2.0 - TIME * 6.0);
	ALBEDO = vec3(1.0, 0.12, 0.08) * glow * pulse * (0.35 + 0.65 * sweep) * on * 2.0;
}"""
	beacon_mat = ShaderMaterial.new(); beacon_mat.shader = sh2
	bm.material_override = beacon_mat; bm.rotation_degrees.x = 90; bm.position = Vector3(-8, 2.88, 0)
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bm)
	# piso 2: sala de juegos y decoración
	sgn(OX + 15.88, 2.78, 18, -PI / 2, "SALA DE JUEGOS", "#6a2fa0")
	floor_rect(OX + 11.5, OX + 14.9, 15.2, 17.8, Color("#3a2a6a"), "carpet", .01)
	fb(.9, .45, 2, Color("#6a2fa0"), OX + 13.4, .225, 16.5, "fabric")
	box(.22, .8, 2, Color("#5a2590"), OX + 12.95, .7, 16.5, null, "fabric")
	box(.2, .55, .2, Color("#5a2590"), OX + 13.4, .55, 15.5, null, "fabric"); box(.2, .55, .2, Color("#5a2590"), OX + 13.4, .55, 17.5, null, "fabric")
	fb(.4, .5, 1.8, Color("#15151a"), OX + 15.5, .25, 18, "plastic")
	box(.3, .05, .5, Color("#2a2a32"), OX + 15.5, .53, 17.6, null, "plastic")
	box(.03, .03, .03, Color("#38e0ff"), OX + 15.3, .5, 18.6).material_override = Mats.unshaded(Color("#38e0ff"), 3.0)
	box(.4, .9, .4, Color("#15151a"), OX + 15.5, .45, 16.6, null, "plastic"); box(.4, .9, .4, Color("#15151a"), OX + 15.5, .45, 19.4, null, "plastic")
	box(.45, .3, .45, Color("#c0306a"), OX + 11.6, .15, 17.8, null, "fabric"); box(.45, .3, .45, Color("#2f6fd0"), OX + 12.3, .15, 18.2, null, "fabric")
	poster(OX + 11.5, 1.7, 15.12, "GAME", "ON!", "#6a2fa0"); poster(OX + 14.6, 1.7, 15.12, "ONLINE", "4 jugadores", "#2f6fd0")
	for p in [[OX + 4.6, 3.6], [OX + 7.4, 20], [OX + 4.6, 20], [OX + 15.4, 3.6], [OX + 8.6, 9.4], [OX - 3.5, 15.4], [OX - 3.5, 3.6], [OX + 15.4, 15.4], [-3.4, 2.3], [3.4, 2.3]]:
		plant(p[0], p[1], .4, .9, 0, true)
	floor_rect(OX + 4.8, OX + 7.2, 7, 13, Color("#7a3a3a"), "carpet", .01)
	floor_rect(OX - 2.5, OX + 2.5, 4.5, 7.5, Color("#2f4a6a"), "carpet", .01)
	floor_rect(OX + 9.5, OX + 14.5, 4.5, 7.5, Color("#6a2f4a"), "carpet", .01)


# ============ Partículas de polvo (dust del original) ============
func _dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 70 if OS.has_feature("web") else 220
	p.lifetime = 14
	p.preprocess = 14
	p.position = Vector3(0, 1.5, 0)
	p.visibility_aabb = AABB(Vector3(-4, -1.5, -3), Vector3(8, 3, 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.5, 1.2, 2.8)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180
	pm.initial_velocity_min = .01
	pm.initial_velocity_max = .05
	pm.gravity = Vector3(0, -.004, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = .3
	pm.turbulence_noise_speed_random = .2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(.012, .012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, .92, .78, .55)
	q.material = m
	p.draw_pass_1 = q
	add_child(p)


# ============ animación ============
func blink_leds() -> void:
	if led_mm == null: return
	for k in led_mm.instance_count:
		if randf() < .25:
			led_mm.set_instance_color(k, Color("#111111") if randf() < .4 else led_base[k])
