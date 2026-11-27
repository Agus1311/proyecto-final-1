class_name CityWest
extends Node3D
## Ampliación de la ciudad hacia el oeste de CAA Corp (x > 260), siguiendo la costa real:
##   · Mercado de Mariscos con su muelle y las pangas de los pescadores (x 260–660)
##   · Calle hacia la Plaza 5 de Mayo y el barrio de Curundú (ramal norte en x = 330)
##   · Cinta Costera 3: viaducto sobre el mar con el Casco Antiguo al fondo (x 660–1150)
##   · Calzada de Amador con las islas Naos, Perico y Flamenco (x 1150–2350)
## Todo se genera por código (geometría propia, sin modelos de terceros).
const D = preload("res://scripts/city/city_data.gd")

const X0 := 260.0           # fin del tramo original de la Av. Balboa
const XM := 660.0           # fin del tramo del Mercado (empieza el viaducto)
const XC := 1150.0          # fin del viaducto (empieza la Calzada)
const XE := 2350.0          # fin de la Calzada (Isla Flamenco)
const NX := 330.0           # ramal norte hacia 5 de Mayo y Curundú
const NZ := 335.0           # fin del ramal
const PIER_X := 424.0
const PLAZA := Vector2(330, 170)

## Islas de la Calzada: [x0, x1, z0, z1, nombre]
const ISLANDS := [[1380.0, 1520.0, -180.0, -40.0, "Isla Naos"], [1780.0, 1900.0, -160.0, -40.0, "Isla Perico"], [2180.0, 2350.0, -220.0, -40.0, "Isla Flamenco"]]

var city: City
var walkers_def: Array = []   # rutas de peatones que el City crea con add_walker()


func build(c: City) -> void:
	city = c
	_road()
	_market()
	_north_branch()
	_plaza_5_mayo()
	_curundu()
	_viaduct()
	_casco()
	_causeway()
	_islands()
	_far_landmarks()
	_walkable()


# ---------------- utilidades ----------------
func _g(nm: String) -> Node3D:
	var g := Node3D.new(); g.name = nm; add_child(g); return g


func _mat(c: Color, r := .8) -> StandardMaterial3D:
	return city.col_mat(c, r)


# ---------------- calzada continua (mismos carriles que la Av. Balboa) ----------------
func _road() -> void:
	var g := _g("Calzada_oeste")
	var x := X0
	while x < XE:
		var x1 := minf(x + 120.0, XE)
		city.ground(x, x1, -28.6, -1.3, .0, city.road_mat, g)
		x = x1
	var curb := city.pbr("curb", 2.0, Color(1, 1, 1), .8)
	city.box(Vector3(XE - X0, .16, .3), Vector3((XE + X0) / 2, .08, -1.15), curb, g)
	city.box(Vector3(XE - X0, .16, .3), Vector3((XE + X0) / 2, .08, -28.75), curb, g)
	# isleta central con jardineras (con un retorno frente al Mercado y otro al final)
	var med := city.pbr("grass", 3.0, Color(.85, .95, .8), .8)
	for seg in [[X0 + 4, NX - 10], [NX + 10, PIER_X - 12], [PIER_X + 12, XE - 30]]:
		city.box(Vector3(seg[1] - seg[0], .2, 2.6), Vector3((seg[0] + seg[1]) / 2, .1, -17.1), med, g)
	# acera norte en el tramo del Mercado (después el viaducto y la Calzada tienen la suya)
	var pav := city.pbr("pavers", 2.0, Color(1, .99, .96), .9)
	city.ground(X0, NX - 8, -1.3, 12.0, .14, pav, g)
	city.ground(NX + 8, XM, -1.3, 12.0, .14, pav, g)


# ---------------- Mercado de Mariscos ----------------
func _market() -> void:
	var g := _g("Mercado_de_Mariscos")
	var pav := city.pbr("promenade", 2.0, Color(1, .97, .9), .7)
	city.ground(X0, XM, -45.1, -28.9, .14, pav, g)
	city.box(Vector3(XM - X0, 1.4, .6), Vector3((XM + X0) / 2, .3, D.SEAWALL), _mat(Color("#9a958a")), g)
	# nave del mercado: techo a dos aguas azul y paredes blancas con letrero
	var cx := 425.0
	var white := _mat(Color("#f2efe6"), .7)
	var blue := _mat(Color("#2a6db0"), .5)
	city.box(Vector3(92, 5.6, 11), Vector3(cx, 2.8, -38.4), white, g)
	for s in [-1, 1]:
		var roof := city.box(Vector3(94, .35, 7.0), Vector3(cx, 6.4, -38.4 + s * 2.9), blue, g)
		roof.rotation.x = s * .32
	for i in 12:
		city.box(Vector3(3.2, 2.6, .12), Vector3(cx - 44 + 4 + i * 7.6, 1.6, -32.85), _mat(Color("#28323c"), .3), g)  # vitrinas
	city.label("MERCADO DE MARISCOS", 170, Color("#1d4f8a"), Vector3(cx, 4.7, -32.7), 0.0, g)
	city.label("Pescado fresco · Ceviche · Mariscos", 64, Color("#2a2a2a"), Vector3(cx, 3.5, -32.7), 0.0, g)
	# puestos de comida frente a la nave (toldos de colores)
	var cols := [Color("#e8433f"), Color("#f2c200"), Color("#2f9a5a"), Color("#2f6fd0"), Color("#ff8a3a")]
	for i in 8:
		var px := cx - 40 + i * 11.0
		city.box(Vector3(4.2, .9, 1.6), Vector3(px, .6, -31.0), _mat(Color("#b8b0a0")), g)
		var aw := city.box(Vector3(4.8, .12, 2.6), Vector3(px, 2.6, -31.2), _mat(cols[i % 5], .6), g)
		aw.rotation.x = -.18
		for k in 3:
			city.box(Vector3(.6, .25, .5), Vector3(px - 1.2 + k * 1.2, 1.18, -31.0), _mat([Color("#d0d8e0"), Color("#f0a070"), Color("#c06050")][k], .4), g)  # hieleras y pescado
		city.box(Vector3(.08, 2.0, .08), Vector3(px - 2.3, 1.6, -30.0), _mat(Color("#555555")), g)
		city.box(Vector3(.08, 2.0, .08), Vector3(px + 2.3, 1.6, -30.0), _mat(Color("#555555")), g)
	city.sts.append({"x": cx - 18.0, "z": -29.8, "r": 2.4, "kind": "ceviche", "l": "🦐 Ceviche de corvina · $4 (E)"})
	city.sts.append({"x": cx + 26.0, "z": -29.8, "r": 2.4, "kind": "comm", "id": "pos", "l": "💳 Puesto de Doña Lucy: «el datáfono no conecta» (E)"})
	# muelle de madera con pangas
	var wood := city.pbr("promenade", 1.2, Color(.62, .46, .32), .6)
	city.box(Vector3(8, .5, 40), Vector3(PIER_X, .1, -65), wood, g)
	for k in 9:
		for s in [-1, 1]:
			city.box(Vector3(.4, 3.2, .4), Vector3(PIER_X + s * 3.8, -1.2, -47 - k * 4.6), _mat(Color("#5a4636")), g)
	for i in 6:
		var b := _panga(cols[i % 5])
		b.position = Vector3(PIER_X + (6.2 if i % 2 else -6.2), -.45, -52 - (i / 2) * 9.0)
		b.rotation.y = PI / 2 + (city.rnd(i) - .5) * .3
		g.add_child(b)
	city.label("⛵ Lanchas", 40, Color.WHITE, Vector3(PIER_X, 2.6, -46.5), 0.0, g)
	city.sts.append({"x": PIER_X, "z": -82.0, "r": 3.2, "kind": "boat", "l": "🚤 Subir a la lancha · misiones y carrera (E)"})
	# competencia de lanchas del puerto: arco de largada, banderines y público en el paseo
	var arch_c := [Color("#e8433f"), Color("#f4f4f4"), Color("#2f6fd0")]
	for s2 in [-1, 1]:
		city.box(Vector3(.5, 7, .5), Vector3(PIER_X + s2 * 14, 2.6, -96), _mat(Color("#f4f4f4"), .4), g)
	city.box(Vector3(28.5, 1.6, .4), Vector3(PIER_X, 6.4, -96), _mat(Color("#1d1f24"), .5), g)
	city.label("🏁 COMPETENCIA DE LANCHAS", 110, Color("#f2c200"), Vector3(PIER_X, 6.4, -95.7), 0.0, g)
	for k in 14:
		city.box(Vector3(.9, .9, .05), Vector3(PIER_X - 13 + k * 2, 5.2, -96), _mat(arch_c[k % 3], .6), g).rotation.z = PI / 4
	for k in 3:   # gradas en el paseo, frente al muelle
		city.box(Vector3(26, .5, 1.4), Vector3(PIER_X + 26, .35 + k * .5, -41.0 - k * 1.2), _mat(Color("#9aa0a8"), .6), g)
	city.sts.append({"x": PIER_X + 1.0, "z": -50.0, "r": 2.8, "kind": "boat_race", "l": "🏁 Competencia de lanchas · 4 lanchas, premio $120 (E)"})
	walkers_def.append({"pts": [Vector3(PIER_X + 15, 0, -39.4), Vector3(PIER_X + 37, 0, -39.4)], "sp": .5, "n": 6, "pause": .9})
	# pelícanos posados en los pilotes
	for i in 5:
		var pel := _pelican()
		pel.position = Vector3(PIER_X + (3.8 if i % 2 else -3.8), .45, -50 - i * 6.5)
		pel.rotation.y = city.rnd(i * 3) * TAU
		g.add_child(pel)
	# vendedores y compradores que caminan entre los puestos
	walkers_def.append({"pts": [Vector3(cx - 42, 0, -29.6), Vector3(cx + 42, 0, -29.6)], "sp": 1.1, "n": 4, "pause": .35})
	walkers_def.append({"pts": [Vector3(cx - 30, 0, -34.0), Vector3(cx + 36, 0, -34.0)], "sp": .9, "n": 3, "pause": .5})
	walkers_def.append({"pts": [Vector3(PIER_X - 1.6, 0, -46), Vector3(PIER_X - 1.6, 0, -82), Vector3(PIER_X + 1.6, 0, -82), Vector3(PIER_X + 1.6, 0, -46)], "sp": .8, "n": 3, "pause": .4, "loop": true})


func _panga(c: Color) -> Node3D:
	var b := Node3D.new()
	var hull := city.box(Vector3(6.4, .9, 1.9), Vector3(0, .35, 0), _mat(Color("#f4f4f0"), .5), b)
	hull.name = "casco"
	city.box(Vector3(6.5, .22, 1.95), Vector3(0, .05, 0), _mat(c, .5), b)
	city.box(Vector3(1.2, .7, 1.7), Vector3(2.9, .5, 0), _mat(Color("#f4f4f0"), .5), b).rotation.z = .5
	city.box(Vector3(.5, .7, .4), Vector3(-3.2, .7, 0), _mat(Color("#1d1f24"), .4), b)   # motor fuera de borda
	return b


func _pelican() -> Node3D:
	var p := Node3D.new()
	city.box(Vector3(.35, .32, .62), Vector3(0, .25, 0), _mat(Color("#8a8478")), p)
	city.box(Vector3(.14, .38, .14), Vector3(0, .55, .22), _mat(Color("#e8e2d0")), p)
	city.box(Vector3(.08, .08, .42), Vector3(0, .7, .45), _mat(Color("#e0a040"), .5), p)
	return p


# ---------------- ramal norte: Calle hacia 5 de Mayo y Curundú ----------------
func _north_branch() -> void:
	var g := _g("Ramal_5_de_Mayo")
	city.ground(NX - 6, NX + 6, -1.3, NZ, .06, city.pbr("asphalt", 4.0, Color(.9, .9, .9), .8), g)
	var pav := city.pbr("pavers", 2.0, Color(1, .99, .96), .9)
	city.ground(NX - 9.5, NX - 6, 12, NZ, .14, pav, g)
	city.ground(NX + 6, NX + 9.5, 12, NZ, .14, pav, g)
	# línea central amarilla
	var z := 2.0
	while z < NZ - 4:
		city.box(Vector3(.16, .02, 2.4), Vector3(NX, .075, z), city.unlit(Color("#f2c200"), .6), g)
		z += 5.0
	city.label("Plaza 5 de Mayo · Curundú ⬆", 40, Color.WHITE, Vector3(NX - 10.5, 3.2, 3.0), -PI / 2, g)
	city.box(Vector3(.14, 3.2, .14), Vector3(NX - 10.5, 1.6, 3.6), _mat(Color("#3a3d44")), g)
	# edificios bajos a ambos lados del ramal
	for i in 9:
		var zz := 26.0 + i * 13.0
		if absf(zz - PLAZA.y) < 40: continue
		for s in [-1, 1]:
			var h := 7.0 + city.rnd(i * 2 + s) * 9.0
			var tint: Color = [Color("#e8d8b8"), Color("#c8e0e8"), Color("#f0c8b0"), Color("#d8e8c0")][(i + (s + 1)) % 4]
			city._tower(Vector3(NX + s * 22.0, 0, zz), 18, 11, h, tint, Color("#5a5048"), 2.0, i * 7.0 + s, g)
	walkers_def.append({"pts": [Vector3(NX - 7.8, 0, 14), Vector3(NX - 7.8, 0, NZ - 6)], "sp": 1.2, "n": 4, "pause": .2})
	walkers_def.append({"pts": [Vector3(NX + 7.8, 0, NZ - 6), Vector3(NX + 7.8, 0, 14)], "sp": 1.3, "n": 4, "pause": .2})


func _plaza_5_mayo() -> void:
	var g := _g("Plaza_5_de_Mayo")
	var c := PLAZA
	city.ground(c.x - 34, c.x - 9.5, c.y - 34, c.y + 34, .16, city.pbr("pavers", 1.6, Color(.95, .9, .82), .9), g)
	city.ground(c.x + 9.5, c.x + 34, c.y - 34, c.y + 34, .16, city.pbr("pavers", 1.6, Color(.95, .9, .82), .9), g)
	# monumento central (obelisco con base escalonada) en la isleta de la calle
	for k in 3:
		city.box(Vector3(6 - k * 1.6, .5, 6 - k * 1.6), Vector3(c.x - 21, .4 + k * .5, c.y), _mat(Color("#d8d2c4"), .6), g)
	var ob := city.box(Vector3(1.4, 14, 1.4), Vector3(c.x - 21, 8.5, c.y), _mat(Color("#ece6d8"), .5), g)
	ob.name = "obelisco"
	city.box(Vector3(.9, 1.2, .9), Vector3(c.x - 21, 16.1, c.y), _mat(Color("#c8b070"), .3), g)
	city.label("Plaza 5 de Mayo", 54, Color.WHITE, Vector3(c.x - 21, 3.6, c.y - 3.2), PI, g)
	# fuente a la derecha de la calle
	city.box(Vector3(8, .6, 8), Vector3(c.x + 21, .45, c.y), _mat(Color("#cfc8b8"), .6), g)
	var water := city.box(Vector3(7.2, .1, 7.2), Vector3(c.x + 21, .78, c.y), city.sea_mat, g)
	water.name = "fuente"
	city.box(Vector3(.8, 2.4, .8), Vector3(c.x + 21, 1.6, c.y), _mat(Color("#cfc8b8"), .6), g)
	# bancas y árboles
	for i in 8:
		var a := i * TAU / 8
		for side in [-21, 21]:
			city.box(Vector3(2.2, .45, .6), Vector3(c.x + side + cos(a) * 11, .45, c.y + sin(a) * 11), _mat(Color("#6a4a2a")), g).rotation.y = -a
	# comercios alrededor (antigua estación del tren, tiendas)
	city._tower(Vector3(c.x - 52, 0, c.y), 18, 40, 9, Color("#e8c890"), Color("#7a4a2a"), 1.0, 31.0, g)
	city._tower(Vector3(c.x + 52, 0, c.y - 10), 20, 30, 18, Color("#d0d8e0"), Color("#3a4a5a"), 3.0, 37.0, g)
	city.sts.append({"x": c.x + 12.0, "z": c.y - 20.0, "r": 2.4, "kind": "comm", "id": "kiosk", "l": "📱 Kiosco de celulares: «me llegó un SMS del banco» (E)"})
	city.sts.append({"x": c.x - 12.0, "z": c.y + 22.0, "r": 2.2, "kind": "fruit", "l": "🍍 Raspao y frutas · $2 (E)"})
	city.box(Vector3(2.4, 1.0, 1.4), Vector3(c.x - 12.0, .6, c.y + 23.6), _mat(Color("#f2c200"), .5), g)
	city.box(Vector3(2.4, 1.6, 1.4), Vector3(c.x + 12.0, 1.0, c.y - 21.6), _mat(Color("#2f6fd0"), .5), g)
	# gente dando vueltas a la plaza
	walkers_def.append({"pts": _ring(Vector3(c.x - 21, 0, c.y), 13.0, 10), "sp": .9, "n": 5, "pause": .25, "loop": true})
	walkers_def.append({"pts": _ring(Vector3(c.x + 21, 0, c.y), 13.0, 10), "sp": 1.0, "n": 5, "pause": .25, "loop": true})


func _ring(c: Vector3, r: float, n: int) -> Array:
	var a := []
	for i in n: a.append(c + Vector3(cos(i * TAU / n) * r, 0, sin(i * TAU / n) * r))
	return a


func _curundu() -> void:
	var g := _g("Curundu")
	var tints := [Color("#f0a0a0"), Color("#a0d0f0"), Color("#f0e090"), Color("#a8e0a8"), Color("#d0b0f0"), Color("#f8c890")]
	# multifamiliares de 4 pisos con balcones de colores
	for i in 6:
		for s in [-1, 1]:
			var zz := 230.0 + (i % 3) * 34.0
			var xx: float = NX + s * (26.0 + (i / 3) * 34.0)
			var bg := Node3D.new(); bg.position = Vector3(xx, 0, zz); g.add_child(bg)
			city.box(Vector3(22, 12.5, 12), Vector3(0, 6.25, 0), _mat(tints[(i + s + 2) % 6], .85), bg)
			for f in 4:
				for w in 5:
					city.box(Vector3(2.2, 1.3, .12), Vector3(-8.8 + w * 4.4, 1.8 + f * 3.0, -6.05 * s), _mat(Color("#2a3440"), .3), bg)
					city.box(Vector3(2.8, .14, .9), Vector3(-8.8 + w * 4.4, 1.0 + f * 3.0, -6.4 * s), _mat(Color("#e8e2d4"), .7), bg)
			city.box(Vector3(22.4, .3, 12.4), Vector3(0, 12.6, 0), _mat(Color("#8a7a6a")), bg)
	# cancha de básquet con niños jugando
	var cc := Vector3(NX + 26, 0, 318)
	city.ground(cc.x - 9, cc.x + 9, cc.z - 6, cc.z + 6, .16, _mat(Color("#3a7a5a"), .9), g)
	for s in [-1, 1]:
		city.box(Vector3(.14, 3.2, .14), Vector3(cc.x + s * 8.2, 1.6, cc.z), _mat(Color("#d8d8d8"), .3), g)
		city.box(Vector3(.1, 1.0, 1.6), Vector3(cc.x + s * 8.0, 3.2, cc.z), _mat(Color("#f4f4f4"), .3), g)
	walkers_def.append({"pts": _ring(cc, 4.5, 6), "sp": 2.6, "n": 4, "pause": .1, "loop": true, "kids": true})
	# Infocentro comunitario
	var ic := Vector3(NX - 26, 0, 318)
	city.box(Vector3(16, 4.4, 10), ic + Vector3(0, 2.2, 0), _mat(Color("#f4f0e6"), .7), g)
	city.box(Vector3(16.4, .3, 10.4), ic + Vector3(0, 4.5, 0), _mat(Color("#2a8a6a"), .6), g)
	city.label("INFOCENTRO CURUNDÚ", 46, Color("#1a5a44"), ic + Vector3(5.2, 3.4, 0), PI / 2, g)
	city.sts.append({"x": ic.x + 9.4, "z": ic.z, "r": 2.6, "kind": "comm", "id": "info", "l": "📡 Infocentro de Curundú: «no hay internet para las tareas» (E)"})
	city.label("Curundú", 70, Color.WHITE, Vector3(NX - 10.5, 4.0, 222), PI / 2, g)
	walkers_def.append({"pts": [Vector3(NX - 7.8, 0, 226), Vector3(NX - 18, 0, 300), Vector3(NX - 7.8, 0, 330)], "sp": 1.0, "n": 3, "pause": .3})


# ---------------- Cinta Costera 3: viaducto sobre el mar ----------------
func _viaduct() -> void:
	var g := _g("Cinta_Costera_3")
	var conc := _mat(Color("#b8b4ac"), .85)
	# mar al norte de la calzada desde aquí hasta el final
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(XE + 300 - XM, 900); pm.subdivide_width = 60; pm.subdivide_depth = 30
	mi.mesh = pm; mi.material_override = city.sea_mat
	mi.position = Vector3((XM + XE + 300) / 2, -.9, 449)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	# tablero, pilas y barandas
	city.box(Vector3(XC - XM, 1.2, 28.6), Vector3((XM + XC) / 2, -.62, -15.0), conc, g)
	var x := XM + 15.0
	while x < XC:
		for zz in [-6.0, -24.0]:
			city.box(Vector3(2.2, 9, 2.2), Vector3(x, -5.6, zz), conc, g)
		x += 30.0
	for zz in [-.6, -29.4]:
		city.box(Vector3(XC - XM, 1.1, .25), Vector3((XM + XC) / 2, .55, zz), _mat(Color("#e8e8e8"), .4), g)
	# ciclovía y paseo del lado del mar (sur), como en la Cinta Costera 3 real
	city.ground(XM, XC, -35.0, -29.6, .1, city.pbr("bikelane", 3.0), g)
	city.box(Vector3(XC - XM, 1.0, 6.0), Vector3((XM + XC) / 2, -.45, -32.3), conc, g)
	city.box(Vector3(XC - XM, 1.1, .25), Vector3((XM + XC) / 2, .55, -35.2), _mat(Color("#e8e8e8"), .4), g)
	city.label("Cinta Costera 3", 90, Color.WHITE, Vector3(XM + 30, 3.0, -35.6), 0.0, g)
	walkers_def.append({"pts": [Vector3(XM + 6, 0, -32.0), Vector3(XC - 6, 0, -32.0)], "sp": 4.8, "n": 3, "bike": true, "pause": 0.0})
	walkers_def.append({"pts": [Vector3(XC - 6, 0, -33.4), Vector3(XM + 6, 0, -33.4)], "sp": 2.6, "n": 3, "pause": .05})


## El Casco Antiguo visto desde el viaducto: casas coloniales de colores, techos de teja y las torres de la catedral.
func _casco() -> void:
	var g := _g("Casco_Antiguo")
	city.ground(700, 1100, 90, 420, -.2, city.pbr("pavers", 3.0, Color(.85, .78, .68), .9), g)
	city.box(Vector3(400, 3.2, 2), Vector3(900, -.4, 90), _mat(Color("#a89a84")), g)   # muralla (Paseo Esteban Huertas)
	var cols := [Color("#f2d48a"), Color("#e89a7a"), Color("#a8d0c8"), Color("#f4f0e6"), Color("#d8a8c8"), Color("#f0c070")]
	var tile := _mat(Color("#a8502e"), .8)
	for i in 34:
		var xx := 712.0 + (i % 17) * 22.5
		var zz := 104.0 + (i / 17) * 26.0 + city.rnd(i) * 6
		var h := 9.0 + city.rnd(i * 3) * 5
		city.box(Vector3(20, h, 18), Vector3(xx, h / 2, zz), _mat(cols[i % 6], .85), g)
		var r := city.box(Vector3(21, .5, 10), Vector3(xx, h + .9, zz - 4), tile, g); r.rotation.x = .35
		var r2 := city.box(Vector3(21, .5, 10), Vector3(xx, h + .9, zz + 4), tile, g); r2.rotation.x = -.35
		for w in 4:
			city.box(Vector3(2.0, 2.6, .3), Vector3(xx - 7 + w * 4.6, h - 3.4, zz - 9.1), _mat(Color("#3a2a1a"), .5), g)
			city.box(Vector3(2.8, .2, 1.0), Vector3(xx - 7 + w * 4.6, h - 4.8, zz - 9.5), _mat(Color("#2a2a2a"), .4), g)   # balcón
	# catedral: fachada blanca con dos torres
	var cx := 905.0; var cz := 175.0
	city.box(Vector3(30, 20, 14), Vector3(cx, 10, cz), _mat(Color("#f2eee4"), .7), g)
	for s in [-1, 1]:
		city.box(Vector3(7, 34, 7), Vector3(cx + s * 13, 17, cz - 3), _mat(Color("#f6f2ea"), .6), g)
		var cap := city.box(Vector3(5, 5, 5), Vector3(cx + s * 13, 36.5, cz - 3), _mat(Color("#d8d0c0"), .5), g)
		cap.rotation.y = PI / 4
	city.label("Casco Antiguo", 90, Color.WHITE, Vector3(cx, 46, cz - 6), PI, g)


# ---------------- Calzada de Amador ----------------
func _causeway() -> void:
	var g := _g("Calzada_de_Amador")
	var sand := city.pbr("grass", 4.0, Color(.82, .9, .72), .7)
	city.ground(XC, XE, -1.3, 9.0, .12, sand, g)
	city.ground(XC, XE, -41.0, -28.9, .12, sand, g)
	city.ground(XC, XE, -36.4, -32.0, .14, city.pbr("bikelane", 3.0), g)
	for zz in [9.0, -41.0]:
		city.box(Vector3(XE - XC, 1.6, 2.0), Vector3((XC + XE) / 2, -.6, zz + (1.0 if zz > 0 else -1.0)), _mat(Color("#8a8a80")), g)  # escollera
	# palmeras a lo largo de la Calzada (un solo MultiMesh)
	var xf := []
	var x := XC + 8.0
	while x < XE - 8:
		for zz in [4.0, -30.6, -38.4]:
			var hh := (6.0 + city.rnd(x * .13 + zz) * 3.0) / 8.0
			xf.append(Transform3D(Basis().rotated(Vector3.UP, city.rnd(x + zz) * TAU).scaled(Vector3(hh, hh, hh)), Vector3(x + city.rnd(x) * 4, .15, zz)))
		x += 16.0
	var palms := city._mm(city._palm(), null, xf)
	palms.reparent(g)
	# museo de la biodiversidad: cubiertas inclinadas de colores (diseño propio)
	var mz := 30.0
	city.ground(XC + 20, XC + 120, 9.0, 70.0, .14, city.pbr("pavers", 2.0, Color(.95, .95, .92), .9), g)
	city.box(Vector3(60, 9, 30), Vector3(XC + 70, 4.5, mz + 10), _mat(Color("#e8e8e0"), .6), g)
	var mc := [Color("#e8433f"), Color("#f2c200"), Color("#2f9a5a"), Color("#2f6fd0"), Color("#ff8a3a"), Color("#a040c0")]
	for i in 7:
		var p := city.box(Vector3(16, .5, 14), Vector3(XC + 46 + i * 8.5, 11 + (i % 3) * 1.6, mz + 4 + (i % 2) * 10), _mat(mc[i % 6], .5), g)
		p.rotation = Vector3((i % 3 - 1) * .3, i * .4, (i % 2 - .5) * .5)
	city.label("Museo de la Biodiversidad", 54, Color("#1d1f24"), Vector3(XC + 70, 5.6, mz - 5.2), PI, g)
	city.label("Calzada de Amador", 70, Color.WHITE, Vector3(XC + 4, 3.6, 7), PI, g)
	# trotadores y ciclistas en la ciclovía de la Calzada
	walkers_def.append({"pts": [Vector3(XC + 6, 0, -33.2), Vector3(XE - 10, 0, -33.2)], "sp": 5.2, "n": 4, "bike": true, "pause": 0.0})
	walkers_def.append({"pts": [Vector3(XE - 10, 0, -35.2), Vector3(XC + 6, 0, -35.2)], "sp": 2.8, "n": 5, "pause": .04})
	walkers_def.append({"pts": [Vector3(XC + 6, 0, 2.5), Vector3(XE - 10, 0, 2.5)], "sp": 1.2, "n": 5, "pause": .2})


func _islands() -> void:
	var g := _g("Islas")
	var sand := city.pbr("grass", 4.0, Color(.86, .92, .72), .7)
	for i in ISLANDS.size():
		var isl: Array = ISLANDS[i]
		var x0: float = isl[0]; var x1: float = isl[1]; var z0: float = isl[2]; var z1: float = isl[3]
		var cx := (x0 + x1) / 2
		city.ground(x0, x1, z0, z1, .1, sand, g)
		city.box(Vector3(x1 - x0 + 4, 1.4, z1 - z0 + 4), Vector3(cx, -.65, (z0 + z1) / 2), _mat(Color("#7a7468")), g)
		city.label(isl[4], 80, Color.WHITE, Vector3(cx, 12, z0 + 30), 0.0, g)
		# restaurantes y edificios bajos con techos de colores
		for k in 4:
			var bx := x0 + 18 + k * (x1 - x0 - 36) / 3.0
			city.box(Vector3(14, 5, 10), Vector3(bx, 2.5, z0 + 60), _mat(Color("#f4f0e6"), .7), g)
			city.box(Vector3(15, .4, 11), Vector3(bx, 5.2, z0 + 60), _mat([Color("#e8433f"), Color("#2f6fd0"), Color("#2f9a5a"), Color("#f2c200")][k], .6), g)
		# marina con muelle flotante y veleros
		var mx := x0 - 6.0
		city.box(Vector3(4, .4, 60), Vector3(mx, .05, (z0 + z1) / 2), city.pbr("promenade", 1.2, Color(.62, .46, .32), .6), g)
		for k in 4:
			var yacht := Node3D.new()
			city.box(Vector3(9, 1.4, 3), Vector3(0, .3, 0), _mat(Color("#f8f8f4"), .3), yacht)
			city.box(Vector3(.2, 11, .2), Vector3(.5, 6, 0), _mat(Color("#d8d8d8"), .3), yacht)
			yacht.position = Vector3(mx - 6.5, -.3, z0 + 18 + k * 13)
			yacht.rotation.y = PI / 2
			g.add_child(yacht)
		# cerro con faro en Flamenco
		if i == 2:
			var hill := city.box(Vector3(80, 26, 80), Vector3(cx + 30, 6, z0 + 40), _mat(Color("#4a7a3a"), .9), g)
			hill.rotation.y = .4
			city.box(Vector3(3, 12, 3), Vector3(cx + 30, 25, z0 + 40), _mat(Color("#f4f4f4"), .4), g)
			city.box(Vector3(3.4, 2, 3.4), Vector3(cx + 30, 32, z0 + 40), city.unlit(Color("#ffe08a"), 2.0), g)
		walkers_def.append({"pts": [Vector3(x0 + 10, 0, z0 + 70), Vector3(x1 - 10, 0, z0 + 70)], "sp": 1.0, "n": 3, "pause": .3})


## Puente de las Américas y la isla Taboga en el horizonte (baja resolución: solo se ven de lejos).
func _far_landmarks() -> void:
	var g := _g("Horizonte_oeste")
	var steel := _mat(Color("#3a5a6a"), .5)
	var bx := 1350.0; var bz := 760.0
	city.box(Vector3(1100, 3, 18), Vector3(bx, 60, bz), steel, g)   # tablero
	for i in 21:
		var t := (i - 10) / 10.0
		var y := 60 + 70 * (1 - t * t)
		city.box(Vector3(55, 3, 3), Vector3(bx + t * 300, y, bz), steel, g)
		city.box(Vector3(2, y - 60, 2), Vector3(bx + t * 300, 60 + (y - 60) / 2, bz), steel, g)
	for s in [-1, 1]:
		city.box(Vector3(8, 60, 8), Vector3(bx + s * 300, 30, bz), steel, g)
	var tab := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 420; sm.height = 300; sm.radial_segments = 24; sm.rings = 8
	tab.mesh = sm; tab.material_override = _mat(Color("#4a6a4a"), .95)
	tab.position = Vector3(1800, -40, -2700)
	tab.scale = Vector3(1.6, 1, 1)
	g.add_child(tab)
	city.label("Isla Taboga", 300, Color(1, 1, 1, .8), Vector3(1800, 160, -2500), 0.0, g)


# ---------------- zonas caminables y agua ----------------
func _walkable() -> void:
	city.wk.append([X0 - 12, XM, -44.6, 9.6])                 # tramo del Mercado (acera, avenida y paseo)
	city.wk.append([PIER_X - 3.6, PIER_X + 3.6, -84.0, -44.0])  # muelle
	city.wk.append([NX - 9.4, NX + 9.4, -2.0, NZ])               # ramal norte
	city.wk.append([PLAZA.x - 34, PLAZA.x + 34, PLAZA.y - 34, PLAZA.y + 34])
	city.wk.append([NX - 46, NX + 46, 214, NZ])                  # Curundú
	city.wk.append([XM - 4, XC + 4, -35.0, -1.2])                # viaducto y su paseo
	city.wk.append([XC, XE - 2, -40.6, 8.6])                     # Calzada
	city.wk.append([XC + 20, XC + 120, 8.0, 70.0])               # museo
	for isl in ISLANDS:
		city.wk.append([isl[0] + 2, isl[1] - 2, isl[2] + 2, isl[3] + 1])
	# edificios de Curundú y del ramal como obstáculos [x, z, semiancho, semifondo]
	for i in 6:
		for s in [-1, 1]:
			city.dk.append([NX + s * (26.0 + (i / 3) * 34.0), 230.0 + (i % 3) * 34.0, 11.2, 6.2])
	city.dk.append([NX - 26, 318, 8.2, 5.2])
	city.dk.append([425.0, -38.4, 46.2, 5.7])   # nave del mercado


## ¿Hay agua navegable en (x, z)? Para la lancha.
static func is_water(x: float, z: float) -> bool:
	if x < -1500 or x > 2700 or z < -1400: return false
	if x < XM:
		return z < -46.5 and not (absf(x - PIER_X) < 4.6 and z > -86.0)
	if x < XC:
		return z < -36.0
	if z > -42.5: return false
	for isl in ISLANDS:
		if x > isl[0] - 9 and x < isl[1] + 2 and z > isl[2] - 2: return false
	return true


## Rectángulos para el minimapa: [x0, x1, z0, z1, color]
func minimap_rects() -> Array:
	var r := [
		[XM, XE + 300, -1.2, 900.0, Color("#1d4a5a")],
		[X0, XM, -45.2, -28.6, Color("#b8ad96")],
		[X0, XE, -28.6, -1.3, Color("#3a3d44")],
		[X0, XM, -1.3, 12.0, Color("#8a8478")],
		[X0, XM, 12.0, 400.0, Color("#2a2730")],
		[NX - 6, NX + 6, -1.3, NZ, Color("#3a3d44")],
		[PLAZA.x - 34, PLAZA.x + 34, PLAZA.y - 34, PLAZA.y + 34, Color("#b8ad96")],
		[700.0, 1100.0, 90.0, 420.0, Color("#8a6a4a")],
		[XC, XE, -41.0, 9.0, Color("#4a7a3a")],
		[PIER_X - 4, PIER_X + 4, -85.0, -45.0, Color("#8a6a4a")],
	]
	for isl in ISLANDS: r.append([isl[0], isl[1], isl[2], isl[3], Color("#4a7a3a")])
	return r
