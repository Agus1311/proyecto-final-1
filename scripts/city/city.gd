class_name City
extends Node3D
## Ciudad de Panamá: Av. Balboa (6 carriles + carril «SOLO BUS»), Cinta Costera (parque,
## ciclovía, paseo marítimo y malecón), rascacielos de Bella Vista, Punta Paitilla al este,
## Casco Antiguo, Cerro Ancón y el Puente de las Américas al oeste, barcos fondeados en la
## bahía. Tráfico con semáforos, MiBus con paradas, diablo rojo, taxis y peatones.

const D = preload("res://scripts/city/city_data.gd")
const T := "res://assets/textures/city/"

var main: Node
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var facade_mat: ShaderMaterial
var road_mat: ShaderMaterial
var sea_mat: ShaderMaterial
var lamp_mat: StandardMaterial3D
var noise_tex: NoiseTexture2D

var wk: Array = []           # zonas caminables [x0, x1, z0, z1]
var dk: Array = []           # obstáculos [x, z, semiancho, semifondo]
var sts: Array = []          # estaciones interactivas
var traffic: Array = []
var peds: Array = []
var parked: Array = []
var ships: Array = []
var beacons: Array = []
var marks: Array = []
var sig_lamps: Array = []    # [rojo, ámbar, verde, dirección (1 calzada norte / -1 sur / 0 transversal)]
var ped_lamps: Array = []
var sig_t := 0.0
var sig_state := "g"
var car: Node3D              # el superdeportivo del jugador
var car_home := Vector3(-2.5, 0, -3.4)
var guard: Rig
var departures: Array = []
var day_light := 1.0
var _built := false
var _time_min := 600.0


func _ready() -> void:
	visible = false


func tex(n: String) -> Texture2D:
	return load(T + n + ".png")


func pbr(n: String, meters: float, tint := Color.WHITE, ns := 1.0, rough_mul := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(n + "_albedo")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = tex(n + "_normal")
	m.normal_scale = ns
	m.roughness_texture = tex(n + "_rough")
	m.roughness = rough_mul
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / meters
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func col_mat(c: Color, rough := .8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m


func unlit(c: Color, e := 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = e
	return m


func box(sz: Vector3, pos: Vector3, m: Material, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = sz
	mi.mesh = bm; mi.material_override = m; mi.position = pos; mi.rotation = rot
	(parent if parent else self).add_child(mi)
	return mi


func ground(x0: float, x1: float, z0: float, z1: float, y: float, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(absf(x1 - x0), absf(z1 - z0))
	pm.subdivide_width = 0; pm.subdivide_depth = 0
	mi.mesh = pm; mi.material_override = m
	mi.position = Vector3((x0 + x1) / 2, y, (z0 + z1) / 2)
	(parent if parent else self).add_child(mi)
	return mi


func quad(sz: Vector2, pos: Vector3, ry: float, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = sz
	mi.mesh = qm; mi.material_override = m; mi.position = pos; mi.rotation.y = ry
	(parent if parent else self).add_child(mi)
	return mi


func sign_mat(n: String, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(n)
	m.roughness = .4
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	if emis > 0:
		m.emission_enabled = true; m.emission_texture = tex(n); m.emission_energy_multiplier = emis
	return m


func label(t: String, sz: int, c: Color, pos: Vector3, ry := 0.0, parent: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = t; l.font_size = sz; l.modulate = c; l.position = pos; l.rotation.y = ry
	l.font = Kit.bold(); l.outline_size = 0; l.pixel_size = .01
	(parent if parent else self).add_child(l)
	return l


## Pone a los vehículos y personajes en la capa 2 para que las calcomanías del asfalto no los pinten.
static func set_layer(n: Node, l := 2) -> void:
	if n is VisualInstance3D: (n as VisualInstance3D).layers = l
	for c in n.get_children(): set_layer(c, l)


func rnd(i: float) -> float:
	return fposmod(sin(i * 12.9898 + 78.233) * 43758.5453, 1.0)


# =====================================================================
var _step := -1
var west: CityWest


## Construcción por pasos: build_next() hace un paso por llamada (se usa en segundo plano mientras
## el jugador está en la oficina, para que salir a la calle no se trabe). build() termina lo que falte.
func begin(m: Node) -> void:
	if _step >= 0: return
	_step = 0
	main = m
	noise_tex = NoiseTexture2D.new()
	var fn := FastNoiseLite.new(); fn.frequency = .012; fn.fractal_octaves = 4; fn.seed = 7
	noise_tex.noise = fn; noise_tex.seamless = true; noise_tex.width = 512; noise_tex.height = 512
	noise_tex.generate_mipmaps = true


func build(m: Node) -> void:
	if _built: return
	begin(m)
	while build_next(): pass


func _steps() -> Array:
	return [_environment, _avenue, _cross_streets, _cinta_costera, _sea, _skyline, _landmarks, _destinations,
		_street_furniture, _vegetation, _west, _traffic, _pedestrians, _player_car, _collisions, _vis_ranges]


## Hace el siguiente paso de la construcción. Devuelve true mientras queden pasos.
func build_next() -> bool:
	if _built: return false
	var st := _steps()
	if _step < 0 or _step >= st.size(): return false
	var t0 := Time.get_ticks_usec()
	(st[_step] as Callable).call()
	if "buildtime=1" in OS.get_cmdline_user_args():
		print("  ", (st[_step] as Callable).get_method(), ": ", (Time.get_ticks_usec() - t0) / 1000, " ms")
	_step += 1
	if _step >= st.size():
		_built = true
		set_time(600)
		return false
	return true


func _west() -> void:
	west = CityWest.new(); west.name = "Oeste"
	add_child(west)
	west.build(self)
	for w in west.walkers_def: add_walker(w)


## Rangos de visibilidad: los objetos chicos dejan de dibujarse a cierta distancia.
## En una ciudad de 3 km esto ahorra miles de llamadas de dibujo por cuadro (clave en el navegador).
func _vis_ranges() -> void:
	for n in find_children("*", "GeometryInstance3D", true, false):
		if n is MultiMeshInstance3D: continue
		var gi := n as GeometryInstance3D
		if gi is Label3D:
			gi.visibility_range_end = maxf(220.0, (gi as Label3D).font_size * 4.5); continue
		var ab := gi.get_aabb()
		var sz := maxf(ab.size.x * gi.global_transform.basis.get_scale().x, maxf(ab.size.y, ab.size.z * gi.global_transform.basis.get_scale().z))
		if sz < 3.0: gi.visibility_range_end = 160.0
		elif sz < 12.0: gi.visibility_range_end = 380.0
		elif sz < 40.0: gi.visibility_range_end = 900.0
		if gi.visibility_range_end > 0: gi.visibility_range_end_margin = 12.0


# ---------------- cielo, sol y atmósfera ----------------
func _environment() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var cn := NoiseTexture2D.new(); var cf := FastNoiseLite.new()
	cf.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; cf.frequency = .004; cf.fractal_octaves = 5; cf.seed = 21
	cn.noise = cf; cn.seamless = true; cn.width = 1024; cn.height = 1024; cn.generate_mipmaps = true
	sky_mat.set_shader_parameter("cloud_noise", cn)
	var sky := Sky.new(); sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0
	env.ssao_enabled = true; env.ssao_radius = 1.6; env.ssao_intensity = 1.6; env.ssao_power = 1.4
	env.ssr_enabled = true; env.ssr_max_steps = 64; env.ssr_fade_in = .1; env.ssr_fade_out = 2.0; env.ssr_depth_tolerance = .4
	env.glow_enabled = true; env.glow_intensity = .5; env.glow_bloom = .06; env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = .00055
	env.fog_aerial_perspective = .55
	env.fog_sky_affect = .25
	env.fog_sun_scatter = .25
	env.fog_light_color = Color("#c9d6e0")
	env.adjustment_enabled = true; env.adjustment_contrast = 1.05; env.adjustment_saturation = 1.08
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if OS.has_feature("web") else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120 if OS.has_feature("web") else 260
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = .55
	sun.shadow_bias = .04
	sun.shadow_normal_bias = 1.4
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sun.rotation_order = EULER_ORDER_YXZ
	add_child(sun)


## Posición del sol según la hora (Panamá, ~9° N): sale por el este (−X), cruza por el sur
## (sobre la bahía) y se pone por el oeste (+X), detrás del Casco Antiguo.
func set_time(minutes: float) -> void:
	_time_min = minutes
	var f := clampf((minutes - 375.0) / 735.0, 0.0, 1.0)
	var el := sin(PI * f)
	var p := Vector3(-cos(PI * f), maxf(.035, el * 1.9), -sin(PI * f) * .75 - .25).normalized()
	sun.look_at_from_position(Vector3.ZERO, -p, Vector3.UP)
	var low := 1.0 - smoothstep(.05, .45, p.y)
	sun.light_color = Color("#fff4e2").lerp(Color("#ff9a52"), low)
	sun.light_energy = lerpf(1.0, .85, low)
	day_light = 1.0 - low
	var dusk := smoothstep(.9, .985, f)
	if facade_mat: facade_mat.set_shader_parameter("lit", dusk)
	if lamp_mat: lamp_mat.emission_energy_multiplier = lerpf(.0, 5.0, dusk)
	env.fog_light_color = Color("#b9cde0").lerp(Color("#f0a878"), low)
	env.tonemap_exposure = lerpf(.92, 1.12, low)
	var day_top := Color(.16, .34, .74); var day_hor := Color(.6, .74, .88); var day_sun := Color(1.0, .95, .86)
	var set_top := Color(.14, .16, .4); var set_hor := Color(1.0, .52, .3); var set_sun := Color(1.0, .55, .22)
	sky_mat.set_shader_parameter("top_col", day_top.lerp(set_top, low))
	sky_mat.set_shader_parameter("hor_col", day_hor.lerp(set_hor, low))
	sky_mat.set_shader_parameter("gnd_col", Color(.3, .34, .36).lerp(Color(.38, .26, .24), low))
	sky_mat.set_shader_parameter("sun_col", day_sun.lerp(set_sun, low))
	sky_mat.set_shader_parameter("dusk", low)
	if car:
		for c in car.get_children():
			if c is SpotLight3D: c.light_energy = 6.0 * dusk


# ---------------- Av. Balboa ----------------
func _avenue() -> void:
	road_mat = ShaderMaterial.new()
	road_mat.shader = load("res://shaders/road.gdshader")
	road_mat.set_shader_parameter("alb", tex("asphalt_albedo"))
	road_mat.set_shader_parameter("nrm", tex("asphalt_normal"))
	road_mat.set_shader_parameter("rgh", tex("asphalt_rough"))
	road_mat.set_shader_parameter("noise", noise_tex)
	var lines := [
		Vector4(-1.6, .12, 0, 0), Vector4(-5.6, .15, 0, 0), Vector4(-9.0, .22, 0, 0), Vector4(-12.4, .12, 1, 0),
		Vector4(-15.65, .12, 2, 0), Vector4(-18.55, .12, 2, 0), Vector4(-21.8, .12, 1, 0), Vector4(-25.2, .12, 1, 0), Vector4(-28.3, .15, 0, 0)]
	_set_arr(road_mat, "lines", lines, "n_lines")
	var gaps := []; var zeb := []; var stops := []
	for ix in D.IX:
		var x: float = ix[0]
		gaps.append(Vector2(x - 8.5, x + 8.5))
		zeb.append(Vector4(x, 2.2, -28.4, -1.5))
		stops.append(Vector4(x - 3.4, -15.6, -5.6, 0))
		stops.append(Vector4(x + 3.4, -28.3, -18.6, 0))
	_set_arr(road_mat, "gaps", gaps, "n_gaps")
	_set_arr(road_mat, "zebra", zeb, "n_zebra")
	_set_arr(road_mat, "stops", stops, "n_stops")
	road_mat.set_shader_parameter("lanes", PackedFloat32Array([-7.3, -10.7, -14.1, -20.1, -23.5, -26.9]))
	road_mat.set_shader_parameter("n_lanes", 6)
	# calzada en tramos (malla con subdivisión para la sombra y el SSR)
	var x := D.XB
	while x < D.XA:
		var x1 := minf(x + 120.0, D.XA)
		ground(x, x1, -28.6, -1.3, .0, road_mat)
		x = x1
	# bordillos y aceras
	var curb := pbr("curb", 2.0, Color(1, 1, 1), .8)
	var pav := pbr("pavers", 2.0, Color(1, .99, .96), .9)
	box(Vector3(D.XA - D.XB, .16, .3), Vector3((D.XA + D.XB) / 2, .08, -1.15), curb)
	box(Vector3(D.XA - D.XB, .16, .3), Vector3((D.XA + D.XB) / 2, .08, -28.75), curb)
	# acera norte, interrumpida por las calles transversales
	var segs := _segments(D.XB, D.XA, 7.0)
	for s in segs:
		ground(s[0], s[1], -1.0, 12.0, .156, pav)
		box(Vector3(s[1] - s[0], .15, 13.0), Vector3((s[0] + s[1]) / 2, .075, 5.5), curb)
	# isleta central con césped y bordillo, con huecos en las intersecciones (retornos)
	var grass := pbr("grass", 3.0, Color(.95, 1, .95), .8)
	for s in _segments(D.XB, D.XA, 8.5):
		var L: float = s[1] - s[0]
		box(Vector3(L, .22, 2.6), Vector3((s[0] + s[1]) / 2, .11, -17.1), curb)
		ground(s[0] + .15, s[1] - .15, -18.25, -15.95, .225, grass)
	# terreno detrás de los edificios
	ground(D.XB - 300, D.XA + 400, 12.0, 400.0, .02, pbr("grass", 4.0, Color(.75, .8, .7), .6))
	# calcomanías viales: SOLO BUS, flechas, tapas, manchas y grietas
	var bus_x := D.XA - 30.0
	while bus_x > D.XB + 20:
		if _far_from_ix(bus_x, 20):
			_decal("decal_solo_bus", Vector3(bus_x, 0, -7.3), Vector3(2.6, 1, 5.2), PI / 2)
		bus_x -= 85.0
	for ix in D.IX:
		var xx: float = ix[0]
		for z in [-10.7, -14.1]:
			_decal("decal_arrow", Vector3(xx - 22, 0, z), Vector3(1.0, 1, 4.6), -PI / 2)
		for z in [-20.1, -23.5]:
			_decal("decal_arrow", Vector3(xx + 22, 0, z), Vector3(1.0, 1, 4.6), PI / 2)
		_decal("decal_arrow_right", Vector3(xx + 22, 0, -26.9), Vector3(1.0, 1, 4.6), PI / 2)
	for i in 34:
		var px := lerpf(D.XB + 10, D.XA - 10, rnd(i * 3.1))
		var pz: float = [-7.3, -10.7, -14.1, -20.1, -23.5, -26.9][i % 6] + (rnd(i) - .5) * 1.2
		var k := i % 5
		if k == 0: _decal("decal_manhole", Vector3(px, 0, pz + .9), Vector3(.9, 1, .9), rnd(i) * TAU)
		elif k < 3: _decal("decal_oil%d" % (i % 3), Vector3(px, 0, pz), Vector3(1.4, 1, 2.6), PI / 2 + (rnd(i * 7) - .5) * .3)
		else: _decal("decal_crack", Vector3(px, 0, pz), Vector3(2.5, 1, 2.5), rnd(i * 5) * TAU)
	# vialetas reflectivas (ojos de gato) sobre las líneas segmentadas y amarillas
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new(); bm.size = Vector3(.12, .02, .1); mm.mesh = bm
	var xs := []
	var xx2 := D.XB + 6.0
	while xx2 < D.XA:
		if _far_from_ix(xx2, 9): xs.append(xx2)
		xx2 += 12.0
	var zs := [-12.4, -21.8, -25.2, -15.65, -18.55]
	mm.instance_count = xs.size() * zs.size()
	var n := 0
	for z in zs:
		for xv in xs:
			mm.set_instance_transform(n, Transform3D(Basis(), Vector3(xv + (6.0 if z > -16 and z < -15 or z < -18.5 and z > -19 else 0.0), .01, z))); n += 1
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	var cat := col_mat(Color("#f2f2e8"), .25, .2); cat.emission_enabled = true; cat.emission = Color("#fff4c8"); cat.emission_energy_multiplier = .4
	mmi.material_override = cat
	add_child(mmi)


func _set_arr(m: ShaderMaterial, nm: String, arr: Array, count: String) -> void:
	var pad := arr.duplicate()
	var size = {"lines": 12, "gaps": 6, "zebra": 6, "stops": 8}.get(nm, 8)
	while pad.size() < size: pad.append(Vector4.ZERO if (arr.size() == 0 or arr[0] is Vector4) else Vector2.ZERO)
	m.set_shader_parameter(nm, pad)
	m.set_shader_parameter(count, arr.size())


func _far_from_ix(x: float, d: float) -> bool:
	for ix in D.IX:
		if absf(x - float(ix[0])) < d: return false
	return true


## Tramos [x0, x1] entre XB y XA que evitan las intersecciones.
func _segments(a: float, b: float, half: float) -> Array:
	var cuts := []
	for ix in D.IX: cuts.append(float(ix[0]))
	cuts.sort()
	var out := []
	var x := a
	for c in cuts:
		if c - half > x: out.append([x, c - half])
		x = c + half
	if x < b: out.append([x, b])
	return out


func _decal(n: String, pos: Vector3, size: Vector3, ry: float) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex(n)
	d.size = size
	d.position = pos + Vector3(0, .3, 0)
	d.rotation.y = ry
	d.upper_fade = .2; d.lower_fade = .2
	d.cull_mask = 1
	d.albedo_mix = 1.0
	d.distance_fade_enabled = true; d.distance_fade_begin = 90; d.distance_fade_length = 30
	add_child(d)
	return d


# ---------------- calles transversales ----------------
func _cross_streets() -> void:
	var cm: ShaderMaterial = road_mat.duplicate()
	cm.set_shader_parameter("along_z", true)
	var lines := []
	var zeb := []
	var stops := []
	var gaps := [Vector2(-60, -1.3)]
	for ix in D.IX:
		var x: float = ix[0]
		lines.append(Vector4(x, .12, 2, 0)); lines.append(Vector4(x - 4.6, .12, 0, 0)); lines.append(Vector4(x + 4.6, .12, 0, 0))
		zeb.append(Vector4(3.6, 2.0, x - 5, x + 5))
		stops.append(Vector4(6.2, x, x + 5, 0))
	_set_arr(cm, "lines", lines, "n_lines")
	_set_arr(cm, "zebra", zeb, "n_zebra")
	_set_arr(cm, "stops", stops, "n_stops")
	_set_arr(cm, "gaps", gaps, "n_gaps")
	var la := PackedFloat32Array()
	for ix in D.IX: la.append(float(ix[0]) - 2.4); la.append(float(ix[0]) + 2.4)
	cm.set_shader_parameter("lanes", la); cm.set_shader_parameter("n_lanes", la.size())
	for ix in D.IX:
		var x: float = ix[0]
		ground(x - 5.2, x + 5.2, -1.3, 160.0, .005, cm)
		# rótulos de nombre de calle en la esquina
		var pole := box(Vector3(.09, 3.4, .09), Vector3(x + 6.6, 1.7, -.5), col_mat(Color("#2a2e34"), .5, .6))
		var s1 := quad(Vector2(1.6, .32), Vector3(x + 6.6, 3.2, -.5), 0, sign_mat("street_balboa"))
		var s2 := quad(Vector2(1.6, .32), Vector3(x + 6.6, 2.85, -.5), PI / 2, sign_mat(_street_tex(ix[1])))
		s1.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED; s2.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		# señal de PARE para quien sale de la calle transversal
		var sp := box(Vector3(.07, 2.4, .07), Vector3(x + 6.2, 1.35, 7.0), col_mat(Color("#8a8f96"), .4, .7))
		quad(Vector2(.75, .75), Vector3(x + 6.2, 2.45, 7.04), 0.0, sign_mat("sign_pare"))
		wk.append([x - 5.2, x + 5.2, 9.6, 30.0])


func _street_tex(n: String) -> String:
	match n:
		"Av. Federico Boyd": return "street_boyd"
		"Calle Uruguay": return "street_uruguay"
	return "street_29"


# ---------------- Cinta Costera ----------------
func _cinta_costera() -> void:
	var L := D.XA - D.XB
	var cx := (D.XA + D.XB) / 2
	var pav := pbr("pavers", 2.0, Color(.98, .96, .93), .9)
	var curb := pbr("curb", 2.0)
	ground(D.XB, D.XA, -31.6, -28.9, .156, pav)
	box(Vector3(L, .15, 2.8), Vector3(cx, .075, -30.2), curb)
	ground(D.XB, D.XA, -36.0, -31.6, .126, pbr("grass", 3.0, Color(.92, 1, .9), .8))
	box(Vector3(L, .12, 4.4), Vector3(cx, .06, -33.8), curb)
	var bike := pbr("bikelane", 4.0, Color.WHITE, .7)
	ground(D.XB, D.XA, -38.0, -36.0, .146, bike)
	box(Vector3(L, .14, 2.0), Vector3(cx, .07, -37.0), curb)
	# franjas de la ciclovía (pintura blanca)
	var wl := col_mat(Color("#ecece6"), .6)
	box(Vector3(L, .01, .1), Vector3(cx, .147, -36.08), wl); box(Vector3(L, .01, .1), Vector3(cx, .147, -37.92), wl)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	var dm := BoxMesh.new(); dm.size = Vector3(1.6, .01, .1); mm.mesh = dm
	mm.instance_count = int(L / 4.0)
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(D.XB + 2 + i * 4.0, .148, -37.0)))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = wl; add_child(mi)
	ground(D.XB, D.XA, -42.0, -38.0, .136, pbr("promenade", 2.0, Color(1, .97, .9), .7))
	box(Vector3(L, .13, 4.0), Vector3(cx, .065, -40.0), curb)
	ground(D.XB, D.XA, -45.1, -42.0, .146, pbr("pavers", 1.6, Color(.9, .88, .84), .9))
	box(Vector3(L, .14, 3.1), Vector3(cx, .07, -43.55), curb)
	# malecón con baranda de acero inoxidable
	box(Vector3(L, 1.0, .7), Vector3(cx, -.3, D.SEAWALL), curb)
	box(Vector3(L, .12, .9), Vector3(cx, .26, D.SEAWALL), pbr("curb", 1.5, Color(.95, .94, .9)))
	var steel := col_mat(Color("#c8ccd0"), .25, 1.0)
	box(Vector3(L, .06, .06), Vector3(cx, 1.3, D.SEAWALL + .1), steel)
	box(Vector3(L, .04, .04), Vector3(cx, .82, D.SEAWALL + .1), steel)
	var pm := MultiMesh.new(); pm.transform_format = MultiMesh.TRANSFORM_3D
	var cyl := CylinderMesh.new(); cyl.top_radius = .03; cyl.bottom_radius = .03; cyl.height = 1.1; cyl.radial_segments = 8; pm.mesh = cyl
	pm.instance_count = int(L / 2.5)
	for i in pm.instance_count:
		pm.set_instance_transform(i, Transform3D(Basis(), Vector3(D.XB + i * 2.5, .8, D.SEAWALL + .1)))
	var pmi := MultiMeshInstance3D.new(); pmi.multimesh = pm; pmi.material_override = steel; add_child(pmi)
	# escollera de rocas hacia el mar
	var rm := MultiMesh.new(); rm.transform_format = MultiMesh.TRANSFORM_3D
	var rock := SphereMesh.new(); rock.radius = 1.0; rock.height = 1.4; rock.radial_segments = 7; rock.rings = 4
	rm.mesh = rock
	var cnt := int(L / 1.6) * 2
	rm.instance_count = cnt
	for i in cnt:
		var xx := D.XB + (i / 2) * 1.6 + rnd(i) * 1.2
		var row := i % 2
		var s := .7 + rnd(i * 3.3) * .7
		var b := Basis.from_euler(Vector3(rnd(i * 1.7) * 3, rnd(i * 2.1) * 6, rnd(i * 4.3) * 3)).scaled(Vector3(s * 1.2, s * .7, s))
		rm.set_instance_transform(i, Transform3D(b, Vector3(xx, -.6 - row * .7, D.SEAWALL - 1.1 - row * 1.4)))
	var rmi := MultiMeshInstance3D.new(); rmi.multimesh = rm
	rmi.material_override = pbr("curb", 1.2, Color(.55, .52, .48), 1.6)
	add_child(rmi)
	# estacionamientos de la Cinta Costera
	for px in [-60.0, -290.0, -520.0]:
		var lot := ShaderMaterial.new(); lot.shader = road_mat.shader
		for k in ["alb", "nrm", "rgh", "noise"]: lot.set_shader_parameter(k, road_mat.get_shader_parameter(k))
		lot.set_shader_parameter("wetness", .2)
		ground(px - 22, px + 22, -36.0, -31.6, .132, lot)
		for i in 12:
			box(Vector3(.1, .01, 4.0), Vector3(px - 21 + i * 3.8, .137, -33.8), wl)
		for i in 5:
			if rnd(px + i) < .7:
				var c := Cars.traffic_car(["sedan", "suv", "hatch", "pickup"][i % 4], [Color("#b8bcc2"), Color("#1d1f24"), Color("#f2f2f2"), Color("#7a1e22"), Color("#2c4a7a")][(i + int(-px)) % 5], false, i + 3)
				c.position = Vector3(px - 19 + i * 3.8 * 2 + 1.9, .125, -33.8)
				c.rotation.y = PI / 2
				add_child(c)


# ---------------- mar ----------------
func _sea() -> void:
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = load("res://shaders/sea.gdshader")
	sea_mat.set_shader_parameter("nmap", tex("sea_normal"))
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(7000, 3600); pm.subdivide_width = 160; pm.subdivide_depth = 90
	mi.mesh = pm; mi.material_override = sea_mat
	mi.position = Vector3(-300, -.9, D.SEAWALL - 1800)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# barcos fondeados esperando su turno para el Canal
	var cols := [Color("#c4302a"), Color("#2f6fd0"), Color("#e8a03a"), Color("#4c9a6a"), Color("#8a5fb0"), Color("#d8d8d8")]
	for i in 9:
		var g := Node3D.new()
		var Ls := 120.0 + rnd(i) * 110.0
		box(Vector3(Ls, 11, 26), Vector3(0, 3.5, 0), col_mat(Color("#2a2f3a") if i % 2 else Color("#6a2420"), .6), g)
		box(Vector3(Ls * .98, 1.2, 25.6), Vector3(0, -1.2, 0), col_mat(Color("#8a2a24"), .7), g)
		box(Vector3(Ls * .16, 18, 22), Vector3(-Ls * .4, 18, 0), col_mat(Color("#eeeeee"), .5), g)
		box(Vector3(Ls * .08, 6, 18), Vector3(-Ls * .4, 30, 0), col_mat(Color("#dddddd"), .5), g)
		for k in 8:
			for r in 3:
				if rnd(i * 30 + k * 3 + r) > .2:
					box(Vector3(Ls * .085, 6.0, 7.6), Vector3(Ls * .3 - k * Ls * .085, 11.5 + r * 2.6 * 0.0 + (r % 2) * 2.6, (r - 1) * 8.0), col_mat(cols[(k + r + i) % 6], .7), g)
		g.position = Vector3(lerpf(-1800, 900, rnd(i + 4)), -.4, D.SEAWALL - 420 - i * 140 - rnd(i) * 120)
		g.rotation.y = (rnd(i * 9) - .5) * .8
		add_child(g)
		ships.append(g)


# ---------------- rascacielos de la Av. Balboa ----------------
func _skyline() -> void:
	facade_mat = ShaderMaterial.new()
	facade_mat.shader = load("res://shaders/facade.gdshader")
	facade_mat.set_shader_parameter("concrete", load("res://assets/textures/concrete_albedo.png"))
	var tints := [Color("#5f8ea0"), Color("#3f6f86"), Color("#7aa3b0"), Color("#4d7f7a"), Color("#8fb3c4"), Color("#2f4f6a"), Color("#a7c4cf")]
	var frames := [Color("#d8dadc"), Color("#f2f2ee"), Color("#9aa0a6"), Color("#e9e4da"), Color("#2c3036")]
	var skip := [[CityData.CAA_X + 4, 26.0], [-190.0, 24.0], [-340.0, 22.0], [-545.0, 24.0]]
	for ix in D.IX: skip.append([float(ix[0]), 11.0])
	var i := 0
	var x := D.XA - 8.0
	while x > D.XB + 10:
		var w := 16.0 + rnd(i + .5) * 12.0
		var cx := x - w / 2
		var ok := true
		for s in skip:
			if absf(cx - float(s[0])) < float(s[1]) + w / 2: ok = false
		if ok:
			var h := 55.0 + rnd(i * 1.7) * 150.0
			if rnd(i * 2.3) < .25: h = 30.0 + rnd(i) * 30.0
			var dd := 16.0 + rnd(i * 3.1) * 12.0
			_tower(Vector3(cx, 0, 13.0 + dd / 2 + rnd(i) * 3.0), w, dd, h, tints[i % tints.size()], frames[i % frames.size()], float(i % 4), float(i))
		x -= w + 5.0 + rnd(i * 5.5) * 7.0
		i += 1
	# segunda y tercera fila, más altas (Bella Vista / Obarrio)
	for k in 46:
		var xx := lerpf(D.XA - 20, D.XB + 20, rnd(k * 7.7))
		var zz := 62.0 + rnd(k * 2.9) * 120.0
		var near_ix := false
		for ix in D.IX:
			if absf(xx - float(ix[0])) < 12: near_ix = true
		if near_ix: continue
		var w2 := 18.0 + rnd(k) * 14.0
		_tower(Vector3(xx, 0, zz), w2, w2 * (.8 + rnd(k * 1.3) * .4), 80.0 + rnd(k * 4.1) * 170.0, tints[k % tints.size()], frames[(k + 2) % frames.size()], float((k + 1) % 4), 100.0 + k)


func _tower(pos: Vector3, w: float, d: float, h: float, tint: Color, frame: Color, style: float, seed: float, parent: Node3D = null) -> Node3D:
	var g := Node3D.new(); g.position = pos
	(parent if parent else self).add_child(g)
	var podium_h := 9.3 if rnd(seed * 1.1) < .6 else 0.0
	if podium_h > 0:
		var pm := _facade_box(Vector3(w + 6, podium_h, d + 4), Vector3(0, podium_h / 2, 0), g)
		_inst(pm, Color("#c8d4da"), Color("#e6e2da"), 3.0 if rnd(seed) < .5 else 0.0, seed + .5)
	var body := _facade_box(Vector3(w, h, d), Vector3(0, h / 2, 0), g)
	_inst(body, tint, frame, style, seed)
	# corona: cuarto de máquinas, antena y baliza roja
	box(Vector3(w * .45, 3.5, d * .45), Vector3(0, h + 1.75, 0), col_mat(Color("#cfd2d4"), .7), g)
	if h > 120 and rnd(seed * 3.3) > .4:
		var a := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = .15; cm.bottom_radius = .3; cm.height = h * .12
		a.mesh = cm; a.material_override = col_mat(Color("#cfd4da"), .3, .8); a.position = Vector3(0, h + 3.5 + h * .06, 0); g.add_child(a)
	var bc := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = .5; sm.height = 1.0
	bc.mesh = sm; bc.material_override = unlit(Color("#ff2a2a"), 3.0); bc.position = Vector3(0, h + 4.5 + (h * .12 if h > 120 else 0.0), 0)
	g.add_child(bc); beacons.append(bc)
	return g


func _facade_box(sz: Vector3, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = sz
	mi.mesh = bm; mi.material_override = facade_mat; mi.position = pos
	parent.add_child(mi)
	return mi


func _inst(mi: GeometryInstance3D, tint: Color, frame: Color, style: float, seed: float) -> void:
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("frame", frame)
	mi.set_instance_shader_parameter("style", style)
	mi.set_instance_shader_parameter("seed", seed)


# ---------------- hitos: Paitilla, Casco Antiguo, Cerro Ancón, Puente de las Américas ----------------
func _landmarks() -> void:
	var land := pbr("grass", 6.0, Color(.6, .7, .55), .5)
	var sand := col_mat(Color("#bfae86"), .95)
	# Punta Paitilla / Punta Pacífica: península al este con rascacielos
	ground(-1450, -820, -40, 160, .03, land)
	var pp := MeshInstance3D.new(); var cyl := CylinderMesh.new(); cyl.top_radius = 260; cyl.bottom_radius = 270; cyl.height = 2.0; cyl.radial_segments = 48
	pp.mesh = cyl; pp.material_override = land; pp.position = Vector3(-1050, -.2, -150); add_child(pp)
	var beach := MeshInstance3D.new(); var bcy := CylinderMesh.new(); bcy.top_radius = 272; bcy.bottom_radius = 280; bcy.height = 1.2; bcy.radial_segments = 48
	beach.mesh = bcy; beach.material_override = sand; beach.position = Vector3(-1050, -.7, -150); add_child(beach)
	var tints := [Color("#6f9fb3"), Color("#9ec1cf"), Color("#4c7a92"), Color("#c9dbe4"), Color("#5a8a8a")]
	for i in 34:
		var a := rnd(i * 3.7) * TAU
		var r := 30.0 + rnd(i * 1.3) * 210.0
		var p := Vector3(-1050 + cos(a) * r, 0, -150 + sin(a) * r * .9)
		var h := 90.0 + rnd(i + 11) * 190.0
		_tower(p, 20 + rnd(i) * 12, 20 + rnd(i * 2) * 10, h, tints[i % 5], Color("#e8eaec"), float(i % 3), 300.0 + i)
	# torre retorcida (Obarrio) y torre vela (Punta Pacífica)
	var tw := Node3D.new(); tw.position = Vector3(-640, 0, 210); add_child(tw)
	for k in 52:
		var fl := _facade_box(Vector3(26, 4.1, 26), Vector3(0, 2.05 + k * 4.1, 0), tw)
		fl.rotation.y = k * .035
		_inst(fl, Color("#9cc3d8"), Color("#f0f0f0"), 0.0, 777.0)
	var sp := PackedVector2Array([Vector2(0, 0), Vector2(30, 0), Vector2(30, 220), Vector2(22, 214), Vector2(12, 196), Vector2(4, 168), Vector2(0, 140)])
	var poly := CSGPolygon3D.new(); poly.polygon = sp; poly.depth = 24; poly.material = facade_mat
	poly.position = Vector3(-1180, 0, -250); poly.rotation.y = .5
	add_child(poly)
	# Casco Antiguo al otro lado de la bahía (oeste): casas coloniales, catedral y viaducto
	ground(560, 980, -560, -300, -.1, land)
	var pastel := [Color("#e8c9a0"), Color("#d98e6a"), Color("#f2e3b0"), Color("#9cc0a8"), Color("#e6b8b8"), Color("#f4f0e6"), Color("#c9d8e8")]
	for i in 70:
		var px := 600.0 + rnd(i * 2.2) * 340.0
		var pz := -320.0 - rnd(i * 3.4) * 220.0
		var hh := 9.0 + rnd(i) * 9.0
		var hb := box(Vector3(12 + rnd(i) * 8, hh, 10 + rnd(i * 5) * 8), Vector3(px, hh / 2, pz), col_mat(pastel[i % 7], .85))
		box(Vector3(hb.mesh.size.x + .6, .8, hb.mesh.size.z + .6), Vector3(px, hh + .4, pz), col_mat(Color("#a0523a"), .9))
	var cat := Node3D.new(); cat.position = Vector3(760, 0, -430); add_child(cat)
	var stone := col_mat(Color("#e9e2d2"), .9)
	box(Vector3(34, 20, 22), Vector3(0, 10, 0), stone, cat)
	for s in [-1.0, 1.0]:
		box(Vector3(7, 34, 7), Vector3(s * 15, 17, 9), col_mat(Color("#f4f2ec"), .7), cat)
		var cone := MeshInstance3D.new(); var cn := CylinderMesh.new(); cn.top_radius = .2; cn.bottom_radius = 4.0; cn.height = 7; cn.radial_segments = 8
		cone.mesh = cn; cone.material_override = col_mat(Color("#cfd6dc"), .3, .6); cone.position = Vector3(s * 15, 37.5, 9); cat.add_child(cone)
	# viaducto marino de la Cinta Costera 3 rodeando el Casco
	var deck := col_mat(Color("#cfcac0"), .8)
	var prev := Vector3.ZERO
	for k in 40:
		var a2 := lerpf(-.2, PI + .25, k / 39.0)
		var p2 := Vector3(780 + cos(a2) * 260, 6.5, -420 - sin(a2) * 190)
		if k > 0:
			var seg := box(Vector3(prev.distance_to(p2) + .5, 1.2, 16), (prev + p2) / 2, deck)
			seg.look_at_from_position((prev + p2) / 2, p2, Vector3.UP); seg.rotate_object_local(Vector3.UP, PI / 2)
			if k % 3 == 0:
				box(Vector3(2.2, 7, 2.2), Vector3(p2.x, 3.0, p2.z), deck)
		prev = p2
	# Cerro Ancón con la gran bandera de Panamá
	var hill := MeshInstance3D.new(); var hs := SphereMesh.new(); hs.radius = 1; hs.height = 2; hs.radial_segments = 40; hs.rings = 20
	hill.mesh = hs; hill.material_override = pbr("grass", 10.0, Color(.42, .58, .34), .6)
	hill.scale = Vector3(330, 199, 260); hill.position = Vector3(920, -18, 420); add_child(hill)
	var fp := box(Vector3(1.2, 46, 1.2), Vector3(905, 199, 400), col_mat(Color("#dfe3e8"), .3, .8))
	var flag := quad(Vector2(30, 20), Vector3(921, 210, 400), 0, sign_mat("flag_panama"))
	flag.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	flag.name = "Bandera"
	# Puente de las Américas a lo lejos (arco de acero)
	var br := Node3D.new(); br.position = Vector3(2300, 0, -1200); br.rotation.y = -.55; add_child(br)
	var steel := col_mat(Color("#4d6a7a"), .6, .6)
	box(Vector3(1650, 3, 22), Vector3(0, 62, 0), steel, br)
	for k in 41:
		var t2 := k / 40.0
		var xa := lerpf(-170, 170, t2)
		var ya := 62 + 55 * (1.0 - pow(xa / 170.0, 2))
		var xb2 := lerpf(-170, 170, (k + 1) / 40.0)
		var yb := 62 + 55 * (1.0 - pow(xb2 / 170.0, 2))
		if k < 40:
			var sg := box(Vector3(Vector2(xb2 - xa, yb - ya).length() + .5, 5, 18), Vector3((xa + xb2) / 2, (ya + yb) / 2, 0), steel, br)
			sg.rotation.z = atan2(yb - ya, xb2 - xa)
		if k % 4 == 0:
			box(Vector3(1.2, absf(ya - 62), 16), Vector3(xa, (ya + 62) / 2, 0), steel, br)
	for xp in [-500.0, -330.0, 330.0, 500.0]:
		box(Vector3(6, 62, 16), Vector3(xp, 31, 0), steel, br)


# ---------------- destinos: CAA Corp, bancos y casa ----------------
func _destinations() -> void:
	# torre de CAA Corp con su entrada
	var caa := _tower(Vector3(10, 0, 24), 22, 24, 92, Color("#3f6f86"), Color("#e8eaec"), 0.0, 4242.0)
	var lobby_glass := StandardMaterial3D.new(); lobby_glass.albedo_color = Color(.55, .7, .8, .35); lobby_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lobby_glass.roughness = .02; lobby_glass.metallic_specular = 1
	box(Vector3(7, 3.4, .3), Vector3(CityData.CAA_X, 1.7, 12.15), col_mat(Color("#15202a"), .4, .5))
	box(Vector3(5.6, 2.9, .1), Vector3(CityData.CAA_X, 1.6, 11.95), unlit(Color("#ffd7a8"), .9))
	box(Vector3(5.8, 3.0, .06), Vector3(CityData.CAA_X, 1.6, 11.85), lobby_glass)
	quad(Vector2(9, 2.8), Vector3(CityData.CAA_X, 6.2, 11.8), PI, sign_mat("caa_sign", .5))
	box(Vector3(11, .3, 4.2), Vector3(CityData.CAA_X, 4.0, 10.2), col_mat(Color("#2c3036"), .4, .7))
	# bandera de Panamá frente a la torre
	box(Vector3(.12, 9, .12), Vector3(-14, 4.5, 6), col_mat(Color("#cfd4da"), .25, .9))
	var f := quad(Vector2(3, 2), Vector3(-15.6, 8, 6), 0, sign_mat("flag_panama"))
	f.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	dk.append([-14, 6, .4, .4])
	# kiosco de empanadas y chicha
	var k := Node3D.new(); k.position = Vector3(-34, .15, 6.6); add_child(k)
	box(Vector3(3.4, 2.4, 2.2), Vector3(0, 1.2, 0), col_mat(Color("#f0c040"), .7), k)
	box(Vector3(3.8, .2, 2.6), Vector3(0, 2.5, 0), col_mat(Color("#c4302a"), .6), k)
	label("EMPANADAS · CHICHA", 46, Color("#7a1a10"), Vector3(0, 2.1, -1.12), PI, k)
	for i in 6:
		box(Vector3(.25, .45, .25), Vector3(-1 + i * .4, 1.05, -1.2), col_mat([Color("#c4302a"), Color("#2f8a3a"), Color("#e8a020")][i % 3], .3), k)
	dk.append([-34, 6.6, 2.0, 1.4])
	sts.append({"x": -34.0, "z": 4.6, "r": 1.8, "kind": "food", "l": "🥟 Empanadas y chicha · $3 (E)"})
	sts.append({"x": CityData.CAA_X, "z": 9.4, "r": 1.8, "kind": "caa_in", "l": "🏢 Entrar a CAA Corp (E)"})
	for d in D.DEST:
		if d.id == "home": _house(d)
		else: _bank(d)
	_mark(CityData.CAA_DEST)


func _bank(d: Dictionary) -> void:
	var g := Node3D.new(); g.position = Vector3(d.x, 0, 0); add_child(g)
	var tall: bool = d.tall == 1
	var W := 26.0 if tall else 32.0
	var Dp := 24.0 if tall else 22.0
	var H := 46.0 if tall else 20.0
	var stone := pbr("curb", 3.0, Color(.93, .9, .84), .6)
	box(Vector3(W, H, Dp), Vector3(0, H / 2, 12 + Dp / 2), stone, g)
	var gl := StandardMaterial3D.new(); gl.albedo_color = (d.col as Color).darkened(.3); gl.metallic = .5; gl.roughness = .04; gl.metallic_specular = 1
	box(Vector3(W - 4, H - 3, .4), Vector3(0, H / 2 + .5, 11.85), gl, g)
	var mull := col_mat(Color("#cfd4da"), .3, .9)
	for i in range(-6, 7): box(Vector3(.14, H - 3, .22), Vector3(i * (W - 4) / 12, H / 2 + .5, 11.7), mull, g)
	for j in range(1, 6): box(Vector3(W - 4, .14, .22), Vector3(0, j * (H - 3) / 6 + 1.5, 11.7), mull, g)
	var colm := pbr("curb", 2.0, Color(.97, .95, .9), .5)
	for i in range(-3, 4):
		var c := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = .5; cm.bottom_radius = .58; cm.height = 7; cm.radial_segments = 20
		c.mesh = cm; c.material_override = colm; c.position = Vector3(i * 4.4, 3.65, 10.2); g.add_child(c)
		dk.append([d.x + i * 4.4, 10.2, .6, .6])
	box(Vector3(W - 2, .7, 5.4), Vector3(0, 7.45, 9.8), col_mat(d.col, .5), g)
	box(Vector3(W - 1.4, .25, 5.8), Vector3(0, 7.9, 9.8), col_mat(d.acc, .3, .6), g)
	box(Vector3(15, .3, 3.4), Vector3(0, .3, 8.9), stone, g); box(Vector3(15, .3, 2.4), Vector3(0, .45, 8.4), stone, g)
	box(Vector3(4.0, 3.4, .05), Vector3(0, 1.9, 11.9), unlit(Color("#ffe2a8"), .8), g)
	quad(Vector2(16, 4), Vector3(0, H - 4.6 if not tall else H - 6, 11.6), PI, sign_mat(d.sign, .35), g)
	var atm := box(Vector3(1.2, 2.3, .9), Vector3(-10.5, 1.3, 11.3), col_mat(Color("#2a2e36"), .4, .5), g)
	box(Vector3(.9, .6, .05), Vector3(-10.5, 1.7, 10.82), unlit(Color("#38e0ff"), 1.2), g)
	sts.append({"x": d.x, "z": 8.0, "r": 2.8, "kind": "bank", "id": d.id, "l": "🏦 Entrar a %s (E)" % d.name})
	_mark(d)


func _house(d: Dictionary) -> void:
	var g := Node3D.new(); g.position = Vector3(d.x, 0, 0); add_child(g)
	ground(-17, 17, 12, 30, .16, pbr("grass", 3.0), g)
	ground(1, 9, 10, 22, .17, pbr("pavers", 1.5), g)
	var wall := col_mat(Color("#f1ece0"), .8)
	box(Vector3(18, 3.5, 10), Vector3(0, 1.9, 19), wall, g)
	box(Vector3(12.4, 3.2, 8.2), Vector3(2.4, 5.25, 19.4), col_mat(Color("#dfe3e8"), .7), g)
	var gl := StandardMaterial3D.new(); gl.albedo_color = Color(.45, .65, .78, .5); gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gl.roughness = .02; gl.metallic_specular = 1
	box(Vector3(10.6, 2.2, .1), Vector3(2.4, 5.25, 15.25), gl, g)
	box(Vector3(5.2, 2.0, .1), Vector3(5.4, 1.65, 13.95), gl, g)
	box(Vector3(5.0, 2.7, .12), Vector3(-5.2, 1.5, 13.95), col_mat(Color("#4a4f58"), .5, .4), g)
	box(Vector3(1.3, 2.4, .14), Vector3(.2, 1.35, 13.95), col_mat(Color("#7a4a2a"), .6), g)
	box(Vector3(18.6, .35, 10.6), Vector3(0, 3.85, 19), col_mat(Color("#30343c"), .6), g)
	box(Vector3(13, .35, 9), Vector3(2.4, 7.0, 19.4), col_mat(Color("#30343c"), .6), g)
	quad(Vector2(6, 1.5), Vector3(0, 2.55, 9.4), PI, sign_mat("home_sign", .4), g)
	box(Vector3(.12, 2.4, .12), Vector3(-2.6, 1.35, 9.35), col_mat(Color("#30343c")), g)
	box(Vector3(.12, 2.4, .12), Vector3(2.6, 1.35, 9.35), col_mat(Color("#30343c")), g)
	sts.append({"x": d.x, "z": 8.0, "r": 2.8, "kind": "home", "l": "🏠 Tu casa (E)"})
	_mark(d)


func _mark(d: Dictionary) -> void:
	var g := Node3D.new(); g.position = Vector3(d.x, 0, -3.0); add_child(g)
	var col: Color = d.acc
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 2.3; tm.outer_radius = 2.8; tm.rings = 40
	ring.mesh = tm; ring.scale = Vector3(1, .02, 1); ring.position.y = .05
	var rm := unlit(col, 2.0); rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rm.albedo_color.a = .85
	ring.material_override = rm; g.add_child(ring)
	var beam := MeshInstance3D.new(); var bc := CylinderMesh.new(); bc.top_radius = 1.6; bc.bottom_radius = 1.6; bc.height = 34; bc.cap_top = false; bc.cap_bottom = false
	beam.mesh = bc; beam.position.y = 17
	var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.albedo_color = Color(col.r, col.g, col.b, .16)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm; beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(beam)
	var l := label("%s %s" % [d.icon, d.name], 64, Color.WHITE, Vector3(0, 8, 0), 0, g)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true; l.outline_size = 14; l.outline_modulate = Color(0, 0, 0, .8)
	l.fixed_size = false; l.pixel_size = .02
	marks.append({"d": d, "g": g, "ring": ring, "beam": beam, "bm": bm})


# ---------------- mobiliario urbano ----------------
func _street_furniture() -> void:
	lamp_mat = unlit(Color("#fff0c8"), 0.0)
	lamp_mat.emission_energy_multiplier = 0.0
	var pole_m := col_mat(Color("#2e3238"), .45, .7)
	var pole := CylinderMesh.new(); pole.top_radius = .07; pole.bottom_radius = .12; pole.height = 1.0; pole.radial_segments = 8
	var arm := BoxMesh.new(); arm.size = Vector3(1.6, .09, .09)
	var head := BoxMesh.new(); head.size = Vector3(.85, .12, .32)
	var P := []; var A := []; var Hd := []
	var x := D.XA - 4
	var k := 0
	while x > D.XB:
		if _far_from_ix(x, 6):
			# poste doble en la isleta, sencillo en las aceras y decorativo en el paseo
			P.append(Transform3D(Basis().scaled(Vector3(1, 9.5, 1)), Vector3(x, 4.75, -17.1)))
			for s in [-1.0, 1.0]:
				A.append(Transform3D(Basis(), Vector3(x, 9.4, -17.1 + s * .8)).rotated_local(Vector3.UP, PI / 2))
				Hd.append(Transform3D(Basis(), Vector3(x, 9.3, -17.1 + s * 1.5)).rotated_local(Vector3.UP, PI / 2))
			if k % 2 == 0:
				P.append(Transform3D(Basis().scaled(Vector3(1, 8.5, 1)), Vector3(x + 12, 4.25 + .15, -.4)))
				A.append(Transform3D(Basis(), Vector3(x + 12, 8.5, -1.1)).rotated_local(Vector3.UP, PI / 2))
				Hd.append(Transform3D(Basis(), Vector3(x + 12, 8.4, -1.8)).rotated_local(Vector3.UP, PI / 2))
				P.append(Transform3D(Basis().scaled(Vector3(.8, 4.2, .8)), Vector3(x, 2.1, -41.4)))
				Hd.append(Transform3D(Basis().scaled(Vector3(.6, 2.0, 1.4)), Vector3(x, 4.3, -41.4)))
				dk.append([x + 12, -.4, .2, .2]); dk.append([x, -41.4, .2, .2])
		x -= 30.0
		k += 1
	_mm(pole, pole_m, P); _mm(arm, pole_m, A); _mm(head, lamp_mat, Hd)
	# bancas del paseo marítimo
	var seat := BoxMesh.new(); seat.size = Vector3(2.2, .1, .6)
	var back := BoxMesh.new(); back.size = Vector3(2.2, .45, .08)
	var S1 := []; var S2 := []
	x = D.XA - 6
	while x > D.XB:
		S1.append(Transform3D(Basis(), Vector3(x, .62, -42.9))); S2.append(Transform3D(Basis(), Vector3(x, .95, -42.62)))
		dk.append([x, -42.9, 1.2, .4])
		x -= 20
	var wood := Mats.get_mat("wood", Color("#9a6a3a"))
	_mm(seat, wood, S1); _mm(back, wood, S2)
	# semáforos (cabezales verticales rojo-ámbar-verde) y peatonales
	for ix in D.IX:
		var xx: float = ix[0]
		# calzada norte (circula hacia +X): los focos miran a −X
		_signal(Vector3(xx + 4.0, .15, -.9), 1, Vector3(-1, 0, 0), Vector3(0, 0, -1))
		_signal(Vector3(xx + 4.0, .22, -15.95), 1, Vector3(-1, 0, 0), Vector3(0, 0, 1))
		# calzada sur (circula hacia −X): los focos miran a +X
		_signal(Vector3(xx - 4.0, .15, -28.95), -1, Vector3(1, 0, 0), Vector3(0, 0, 1))
		_signal(Vector3(xx - 4.0, .22, -18.25), -1, Vector3(1, 0, 0), Vector3(0, 0, -1))
		# calle transversal (baja hacia −Z): los focos miran a +Z
		_signal(Vector3(xx + 5.8, .15, 4.6), 0, Vector3(0, 0, 1), Vector3(-1, 0, 0))
		for p in [Vector3(xx - 4.6, 0, -.6), Vector3(xx + 4.6, 0, -.6), Vector3(xx - 4.6, 0, -29.2), Vector3(xx + 4.6, 0, -29.2)]:
			var pg := Node3D.new(); pg.position = p; add_child(pg)
			box(Vector3(.1, 2.6, .1), Vector3(0, 1.3, 0), pole_m, pg)
			box(Vector3(.36, .5, .22), Vector3(0, 2.7, 0), col_mat(Color("#15171a"), .5), pg)
			var pm := unlit(Color("#ff3020"), 2.5)
			box(Vector3(.26, .36, .02), Vector3(0, 2.7, .12 if p.z < -10 else -.12), pm, pg)
			ped_lamps.append(pm)
	# paradas de MiBus
	for sx in D.BSTOPS:
		var g := Node3D.new(); g.position = Vector3(sx, .15, .9); add_child(g)
		box(Vector3(6, .16, 2.2), Vector3(0, 2.95, 0), col_mat(Color("#0b4f9c"), .4, .3), g)
		for xx in [-2.8, 2.8]: box(Vector3(.1, 2.9, .1), Vector3(xx, 1.45, .9), col_mat(Color("#cfd4da"), .25, .9), g)
		var gl := StandardMaterial3D.new(); gl.albedo_color = Color(.7, .85, .9, .28); gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gl.roughness = .02
		box(Vector3(6, 2.4, .05), Vector3(0, 1.5, .95), gl, g)
		box(Vector3(3.0, .1, .55), Vector3(0, .5, .6), Mats.get_mat("metal", Color("#9aa0a6")), g)
		var s := quad(Vector2(2.6, .65), Vector3(0, 3.42, -.9), PI, sign_mat("busstop_sign", .3), g)
		s.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		dk.append([sx, 1.5, 3.1, .5])
		sts.append({"x": sx, "z": -.2, "r": 2.2, "kind": "bus", "l": "🚌 Parada de MiBus (E)"})
	# señales informativas elevadas (pórticos) con destinos reales de cada sentido
	var gant := col_mat(Color("#8c939a"), .4, .8)
	for gp in [[-75.0, -1.0, -15.95, "sign_guide_w", -PI / 2, -6.0], [-90.0, -18.25, -28.9, "sign_guide_e", PI / 2, -23.5]]:
		var gx: float = gp[0]
		var z0: float = gp[1]; var z1: float = gp[2]
		box(Vector3(.35, 7.6, .35), Vector3(gx, 3.8, z0), gant)
		box(Vector3(.35, 7.6, .35), Vector3(gx, 3.8, z1), gant)
		box(Vector3(.3, .3, absf(z1 - z0)), Vector3(gx, 7.4, (z0 + z1) / 2), gant)
		box(Vector3(.3, .3, absf(z1 - z0)), Vector3(gx, 5.6, (z0 + z1) / 2), gant)
		quad(Vector2(6.4, 2.24), Vector3(gx + (-.25 if gp[4] < 0 else .25), 6.5, gp[5]), gp[4], sign_mat(gp[3], .15))
		dk.append([gx, z0, .3, .3])
	# límite de velocidad
	for sx2 in [150.0, -300.0, -620.0]:
		box(Vector3(.07, 2.4, .07), Vector3(sx2, 1.35, -.8), col_mat(Color("#8a8f96"), .4, .7))
		quad(Vector2(.6, .78), Vector3(sx2 - .05, 2.6, -.8), -PI / 2, sign_mat("sign_speed"))
	# monumento a Vasco Núñez de Balboa sobre el globo terráqueo, mirando al mar
	var mon := Node3D.new(); mon.position = Vector3(-96, .13, -40.0); add_child(mon)
	var marble := pbr("curb", 1.5, Color(.96, .95, .92), .5)
	box(Vector3(5, 1.2, 5), Vector3(0, .6, 0), marble, mon)
	box(Vector3(3.2, 3.0, 3.2), Vector3(0, 2.7, 0), marble, mon)
	var globe := MeshInstance3D.new(); var gs := SphereMesh.new(); gs.radius = 1.6; gs.height = 3.2
	globe.mesh = gs; globe.material_override = col_mat(Color("#6b8a5a"), .35, .7); globe.position = Vector3(0, 5.8, 0); mon.add_child(globe)
	var bronze := col_mat(Color("#5a4a30"), .35, .85)
	var fig := Node3D.new(); fig.position = Vector3(0, 7.3, 0); fig.rotation.y = PI; mon.add_child(fig)
	box(Vector3(.6, 1.1, .4), Vector3(0, 1.1, 0), bronze, fig)
	box(Vector3(.22, .9, .22), Vector3(-.15, .45, 0), bronze, fig); box(Vector3(.22, .9, .22), Vector3(.15, .45, 0), bronze, fig)
	var hd := MeshInstance3D.new(); var hs := SphereMesh.new(); hs.radius = .2; hs.height = .4; hd.mesh = hs; hd.material_override = bronze; hd.position = Vector3(0, 1.85, 0); fig.add_child(hd)
	box(Vector3(.14, .9, .14), Vector3(.45, 1.9, .1), bronze, fig, Vector3(0, 0, -.5))
	box(Vector3(.06, 1.6, .06), Vector3(.62, 2.3, .1), bronze, fig)
	box(Vector3(.9, .6, .03), Vector3(.98, 2.85, .1), bronze, fig)
	label("VASCO NÚÑEZ DE BALBOA", 40, Color("#3a2a10"), Vector3(0, 2.4, -1.62), PI, mon)
	dk.append([-96, -40, 2.7, 2.7])
	# mercado de mariscos (extremo oeste)
	var mk := Node3D.new(); mk.position = Vector3(225, 0, -36); add_child(mk)
	box(Vector3(46, 7, 16), Vector3(0, 3.5, 0), col_mat(Color("#e8e0d0"), .8), mk)
	box(Vector3(48, .6, 18), Vector3(0, 7.3, 0), col_mat(Color("#2f6f8f"), .6), mk)
	label("MERCADO DE MARISCOS", 160, Color("#0b3a5a"), Vector3(0, 5.6, 8.05), 0, mk)


func _mm(mesh: Mesh, m: Material, xf: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size(): mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = m
	add_child(mi)
	return mi


## Semáforo de poste con brazo. face = hacia dónde miran los focos (los conductores
## que se acercan lo ven de frente); arm = dirección del brazo sobre la calzada.
func _signal(pos: Vector3, dir: int, face: Vector3, arm: Vector3) -> void:
	var g := Node3D.new(); g.position = pos; add_child(g)
	var pm := col_mat(Color("#2e3238"), .45, .7)
	box(Vector3(.16, 5.6, .16), Vector3(0, 2.8, 0), pm, g)
	var am := box(Vector3(.1, .1, 2.6), Vector3(0, 5.5, 0) + arm * 1.3, pm, g)
	if absf(arm.x) > .5: am.rotation.y = PI / 2
	var hd := Node3D.new(); hd.position = Vector3(0, 5.0, 0) + arm * 2.4; g.add_child(hd)
	hd.look_at_from_position(hd.position, hd.position - face, Vector3.UP)
	# dentro de «hd», −Z local apunta hacia el lado opuesto a los conductores; los focos van en +Z
	box(Vector3(.3, 1.3, .36), Vector3.ZERO, col_mat(Color("#1a1c1f"), .5), hd)
	box(Vector3(.62, 1.62, .03), Vector3(0, 0, -.17), col_mat(Color("#101114"), .6), hd)
	var L := []
	for i in 3:
		var c: Color = [Color("#ff2a1a"), Color("#ffb400"), Color("#28e060")][i]
		var m := StandardMaterial3D.new(); m.albedo_color = c * .25; m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = 0.0
		var s := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = .13; sm.height = .18
		s.mesh = sm; s.material_override = m; s.position = Vector3(0, .38 - i * .38, .17); s.rotation.x = PI / 2
		hd.add_child(s)
		box(Vector3(.3, .03, .18), Vector3(0, .52 - i * .38, .26), col_mat(Color("#101114")), hd)
		L.append(m)
	L.append(dir)
	sig_lamps.append(L)
	dk.append([pos.x, pos.z, .25, .25])


# ---------------- vegetación ----------------
var _palm_mesh: ArrayMesh
var _tree_mesh: ArrayMesh


func _palm() -> ArrayMesh:
	if _palm_mesh: return _palm_mesh
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var H := 8.0
	var segs := 14; var rad := 9
	for i in segs:
		for k in rad:
			var t0 := float(i) / segs; var t1 := float(i + 1) / segs
			var r0 := lerpf(.27, .17, t0) * (1.0 + .25 * maxf(0, .12 - t0) * 8.0); var r1 := lerpf(.27, .17, t1) * (1.0 + .25 * maxf(0, .12 - t1) * 8.0)
			var b0 := .7 * t0 * t0; var b1 := .7 * t1 * t1
			var a0 := TAU * k / rad; var a1 := TAU * (k + 1) / rad
			var p := [Vector3(cos(a0) * r0 + b0, t0 * H, sin(a0) * r0), Vector3(cos(a1) * r0 + b0, t0 * H, sin(a1) * r0),
				Vector3(cos(a1) * r1 + b1, t1 * H, sin(a1) * r1), Vector3(cos(a0) * r1 + b1, t1 * H, sin(a0) * r1)]
			var uv := [Vector2(float(k) / rad, t0 * 7), Vector2(float(k + 1) / rad, t0 * 7), Vector2(float(k + 1) / rad, t1 * 7), Vector2(float(k) / rad, t1 * 7)]
			for tri in [[0, 2, 1], [0, 3, 2]]:
				for q in tri:
					st.set_uv(uv[q]); st.add_vertex(p[q])
	st.generate_normals(); st.generate_tangents()
	var m := st.commit()
	var bark := StandardMaterial3D.new(); bark.albedo_texture = tex("palm_bark_albedo"); bark.normal_enabled = true; bark.normal_texture = tex("palm_bark_normal"); bark.roughness = .9
	m.surface_set_material(0, bark)
	# corona de frondas (cada fronda en V, arqueada y caída)
	var sf := SurfaceTool.new(); sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	for f in n:
		var ang := TAU * f / n + (.2 if f % 2 else 0.0)
		var up := .55 - (f % 3) * .35
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-sin(ang), 0, cos(ang))
		var L := 3.3 + (f % 3) * .35
		var steps := 9
		for s in steps:
			var t0 := float(s) / steps; var t1 := float(s + 1) / steps
			var p0 := dir * L * t0 + Vector3(.7, H + up * L * t0 - .55 * L * t0 * t0, 0)
			var p1 := dir * L * t1 + Vector3(.7, H + up * L * t1 - .55 * L * t1 * t1, 0)
			var w0 := .55 * sin(PI * minf(1, .12 + t0)); var w1 := .55 * sin(PI * minf(1, .12 + t1))
			var drop0 := Vector3(0, -.18 * (1 - t0 * .5), 0); var drop1 := Vector3(0, -.18 * (1 - t1 * .5), 0)
			for half in [-1.0, 1.0]:
				var q := [p0, p1, p1 + side * w1 * half + drop1, p0 + side * w0 * half + drop0]
				var u0 := .5; var u1 = .5 + half * .5
				var uv2 := [Vector2(u0, t0), Vector2(u0, t1), Vector2(u1, t1), Vector2(u1, t0)]
				for tri in [[0, 1, 2], [0, 2, 3]]:
					for q2 in tri:
						sf.set_uv(uv2[q2]); sf.add_vertex(q[q2])
	sf.generate_normals(); sf.generate_tangents()
	sf.commit(m)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = tex("palm_frond"); fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; fm.alpha_scissor_threshold = .45
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED; fm.roughness = .7
	fm.backlight_enabled = true; fm.backlight = Color(.35, .45, .15)
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.surface_set_material(1, fm)
	# cocos
	var sc := SurfaceTool.new(); sc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sp := SphereMesh.new(); sp.radius = .12; sp.height = .24; sp.radial_segments = 8; sp.rings = 5
	for c in 5:
		var a := TAU * c / 5
		sc.append_from(sp, 0, Transform3D(Basis(), Vector3(.7 + cos(a) * .2, H - .25, sin(a) * .2)))
	sc.generate_normals()
	sc.commit(m)
	m.surface_set_material(2, col_mat(Color("#5a6a2a"), .6))
	_palm_mesh = m
	return m


func _tree(flowers: bool) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cm := CylinderMesh.new(); cm.top_radius = .12; cm.bottom_radius = .22; cm.height = 3.2; cm.radial_segments = 8
	st.append_from(cm, 0, Transform3D(Basis(), Vector3(0, 1.6, 0)))
	for b in 4:
		var a := TAU * b / 4 + .4
		var bc := CylinderMesh.new(); bc.top_radius = .05; bc.bottom_radius = .1; bc.height = 1.8; bc.radial_segments = 6
		st.append_from(bc, 0, Transform3D(Basis.from_euler(Vector3(.0, a, .75)), Vector3(cos(a) * .5, 3.6, sin(a) * .5)))
	st.generate_normals()
	var m := st.commit()
	var bark := StandardMaterial3D.new(); bark.albedo_texture = tex("palm_bark_albedo"); bark.albedo_color = Color(.7, .65, .6); bark.roughness = .9
	m.surface_set_material(0, bark)
	var sl := SurfaceTool.new(); sl.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new(); r.seed = 5 if flowers else 9
	for i in 46:
		var c := Vector3(r.randf_range(-2.2, 2.2), r.randf_range(4.0, 6.4), r.randf_range(-2.2, 2.2))
		var nrm := (c - Vector3(0, 4.8, 0)).normalized()
		var b := Basis.from_euler(Vector3(r.randf_range(-1, 1), r.randf_range(0, TAU), r.randf_range(-1, 1)))
		var s := r.randf_range(1.4, 2.2)
		var ax := b.x * s; var ay := b.y * s
		var q := [c - ax - ay, c + ax - ay, c + ax + ay, c - ax + ay]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for k in tri:
				sl.set_normal(nrm); sl.set_uv(uv[k]); sl.add_vertex(q[k])
	sl.generate_tangents()
	sl.commit(m)
	var lm := StandardMaterial3D.new()
	lm.albedo_texture = tex("leaves_guayacan" if flowers else "leaves_green")
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; lm.alpha_scissor_threshold = .5
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED; lm.roughness = .8
	lm.backlight_enabled = true; lm.backlight = Color(.3, .35, .1)
	m.surface_set_material(1, lm)
	return m


func _vegetation() -> void:
	var xf := []
	var add_row := func(z: float, step: float, off: float, jit: float, avoid_ix: float):
		var x := D.XA - off
		while x > D.XB:
			var xx := x + (rnd(x * .37 + z) - .5) * jit
			if avoid_ix <= 0 or _far_from_ix(xx, avoid_ix):
				var h := (6.5 + rnd(xx * .7 + z) * 4.5) / 8.0
				var b := Basis.from_euler(Vector3(0, rnd(xx) * TAU, (rnd(xx + z) - .5) * .08)).scaled(Vector3(h, h, h))
				xf.append(Transform3D(b, Vector3(xx, .2 if z > -18.4 and z < -15.8 else .15, z + (rnd(xx * .11) - .5) * .6)))
			x -= step
	add_row.call(-17.1, 14.0, 4.0, 2.0, 9.0)
	add_row.call(-32.6, 11.0, 2.0, 2.0, 0.0)
	add_row.call(-35.0, 17.0, 8.0, 3.0, 0.0)
	add_row.call(-.2, 26.0, 6.0, 2.0, 7.0)
	for p in [[-13, 16], [13, 15], [-10, 24], [12, 23.5]]:
		var h := (6.0 + rnd(p[0]) * 2.5) / 8.0
		xf.append(Transform3D(Basis().scaled(Vector3(h, h, h)), Vector3(-545 + p[0], .16, p[1])))
	var palms := _mm(_palm(), null, xf)
	palms.material_override = null
	palms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# guayacanes (flor amarilla) y árboles de sombra en el parque
	var tf := []; var tg := []
	var x := D.XA - 18
	var i := 0
	while x > D.XB:
		var b := Basis.from_euler(Vector3(0, rnd(x) * TAU, 0)).scaled(Vector3.ONE * (.8 + rnd(x * 2.7) * .4))
		(tf if i % 3 == 0 else tg).append(Transform3D(b, Vector3(x, .12, -33.9 + (rnd(x) - .5) * 1.2)))
		x -= 37.0
		i += 1
	var a := _mm(_tree(true), null, tf); a.material_override = null
	var b2 := _mm(_tree(false), null, tg); b2.material_override = null


# ---------------- tráfico ----------------
const COLS := [Color("#c4302a"), Color("#2f6fd0"), Color("#e6e8ea"), Color("#1c1d20"), Color("#4c6a5a"), Color("#b8bcc2"), Color("#7a3a2a"), Color("#f2f2f2"), Color("#3a4a5a"), Color("#9aa0a8"), Color("#20304a"), Color("#d8d0c0")]


func _traffic() -> void:
	var lanes := []
	for z in D.LANES_W: lanes.append({"z": z, "dir": 1, "cruise": [13.0, 16.5][lanes.size() % 2]})
	for z in D.LANES_E: lanes.append({"z": z, "dir": -1, "cruise": [12.0, 15.0, 18.0][(lanes.size() - 2) % 3]})
	var n := 0
	var kinds := ["sedan", "suv", "hatch", "sedan", "pickup", "suv"]
	# en el navegador hay menos autos (cada uno son varias mallas): mismo recorrido, más espaciados
	var per_lane := 3 if OS.has_feature("web") else 6
	for ln in lanes:
		for k in per_lane:
			var taxi := n % 4 == 0
			var c := Cars.traffic_car("sedan" if taxi else kinds[n % kinds.size()], Color("#f2c200") if taxi else COLS[(n * 5) % COLS.size()], taxi, n)
			var x := -200.0 + k * (432.0 / per_lane) + rnd(n) * 26.0
			c.position = Vector3(x, 0, ln.z)
			c.rotation.y = 0.0 if ln.dir > 0 else PI
			add_child(c); set_layer(c)
			traffic.append({"g": c, "ln": ln, "z": ln.z, "x": x, "v": ln.cruise * (.7 + rnd(n) * .3), "len": float(c.get_meta("len")), "dir": ln.dir, "bus": false})
			n += 1
	var bus_ln := {"z": D.BUS_LANE, "dir": 1, "cruise": 10.0}
	for bx in [-140.0, 60.0]:
		var b := Cars.bus(false)
		b.position = Vector3(bx, 0, D.BUS_LANE)
		add_child(b); set_layer(b)
		traffic.append({"g": b, "ln": bus_ln, "z": D.BUS_LANE, "x": bx, "v": 9.0, "len": 11.6, "dir": 1, "bus": true, "dwell": 0.0, "sn": INF})
	var dr := Cars.bus(true)
	dr.rotation.y = PI; dr.position = Vector3(-120, 0, D.LANES_E[2])
	add_child(dr); set_layer(dr)
	traffic.append({"g": dr, "ln": {"z": D.LANES_E[2], "dir": -1, "cruise": 11.0}, "z": D.LANES_E[2], "x": -120.0, "v": 10.0, "len": 10.4, "dir": -1, "bus": false})
	# autos estacionados de los empleados frente a CAA Corp (carril de estacionamiento)
	for i in (11 if OS.has_feature("web") else 22):
		var pc := Cars.traffic_car(kinds[(i + 2) % kinds.size()], COLS[(i * 7 + 3) % COLS.size()], false, i + 20)
		var px := -9.0 - i * 5.6
		if not _far_from_ix(px, 10): continue
		pc.position = Vector3(px, 0, D.PARK_Z)
		pc.rotation.y = 0.0
		add_child(pc); set_layer(pc)
		parked.append({"g": pc, "x": px, "v": 0.0, "state": "parked", "used": false})


func _sig_for(dir: int) -> String:
	if dir == 0:
		return "g" if sig_state == "r" else "r"
	return sig_state


func traffic_tick(dt: float, cx: float, player: Dictionary) -> void:
	sig_t = fmod(sig_t + dt, 36.0)
	var st := "g" if sig_t < 24 else ("y" if sig_t < 27 else "r")
	if st != sig_state:
		sig_state = st
		for L in sig_lamps:
			var s := _sig_for(L[3])
			for i in 3:
				var on := (s == "r" and i == 0) or (s == "y" and i == 1) or (s == "g" and i == 2)
				(L[i] as StandardMaterial3D).emission_energy_multiplier = 3.2 if on else 0.0
		for pm in ped_lamps:
			(pm as StandardMaterial3D).emission = Color("#28e060") if st == "r" else Color("#ff3020")
			(pm as StandardMaterial3D).albedo_color = (pm as StandardMaterial3D).emission
	for c in traffic:
		var d: int = c.dir
		var vt: float = c.ln.cruise
		var gap := 1e9; var vf := vt
		for o in traffic:
			if o == c or o.dir != d or absf(o.z - c.z) > 2.2: continue
			var dx: float = (o.x - c.x) * d - (o.len + c.len) / 2
			if dx > -1 and dx < gap: gap = dx; vf = o.v
		# el superdeportivo del jugador también cuenta
		if player.get("on", false) and absf(player.z - c.z) < 2.0:
			var dxp: float = (player.x - c.x) * d - (4.6 + c.len) / 2
			if dxp > -1 and dxp < gap: gap = dxp; vf = absf(player.v)
		if gap < 7 + c.v * .9:
			vt = minf(vt, 0.0 if gap < 3.5 else vf * .9)
		if sig_state != "g":
			for ix in D.IX:
				var sl: float = float(ix[0]) - 3.6 * d
				var dist: float = (sl - (c.x + d * c.len / 2)) * d
				if dist > .5 and dist < 30 and (sig_state == "r" or dist > c.v * 1.4):
					vt = minf(vt, maxf(0, sqrt(maxf(0, 2 * 5 * (dist - 1)))))
		if c.bus:
			var tz: float = c.ln.z
			var stop_x = null
			for s in D.BSTOPS:
				if c.x > s - 34 and c.x < s + 8: stop_x = s
			if stop_x != null:
				tz = -3.9
				var dist2: float = (float(stop_x) - 1.0) - c.x
				if c.dwell > 0:
					c.dwell -= dt; vt = 0
				elif absf(dist2) < .8 and c.v < 1 and c.sn != stop_x:
					c.dwell = 7.0; c.sn = stop_x; vt = 0
				elif dist2 > -.5 and c.sn != stop_x:
					vt = minf(vt, sqrt(maxf(0, 2 * 2.6 * maxf(0, dist2))) + (0.0 if dist2 < .8 else 1.2))
			c.z += (tz - c.z) * minf(1, dt * 1.3)
		if vt > c.v: c.v = minf(vt, c.v + 3.8 * dt)
		else: c.v = maxf(vt, c.v - 9 * dt)
		var mv: float = c.v * d * dt
		c.x += mv
		if d > 0 and c.x > cx + 240: c.x -= 480
		elif d < 0 and c.x < cx - 240: c.x += 480
		if d > 0 and c.x < cx - 250: c.x += 480
		elif d < 0 and c.x > cx + 250: c.x -= 480
		c.g.position = Vector3(c.x, 0, c.z)
		Cars.roll(c.g, absf(mv))


# ---------------- peatones ----------------
func _pedestrians() -> void:
	var sh := [Color("#e84a4a"), Color("#2f6fd0"), Color("#ffd23f"), Color("#4cb87a"), Color("#f2f2f2"), Color("#9a5fd0"), Color("#ff8a3a"), Color("#25c0c0")]
	var sk := [Color("#f1c9a5"), Color("#d9a47a"), Color("#b07a52"), Color("#8a5a3a"), Color("#5a3a26")]
	var hr := [Color("#1a1410"), Color("#3a2616"), Color("#6a4a2a"), Color("#111111")]
	var defs := [[-39.2, 1, 3.1, -420.0, 100.0], [-40.6, -1, 3.4, -420.0, 100.0], [-39.6, 1, 2.7, -500.0, -60.0], [-40.2, -1, 3.0, -300.0, 60.0],
		[-43.6, 1, 1.2, -300.0, 80.0], [-43.8, -1, 1.1, -400.0, 0.0], [-43.2, 1, 1.3, -500.0, -100.0], [-30.4, 1, 1.3, -220.0, 60.0],
		[-30.1, -1, 1.2, -300.0, 20.0], [-30.6, 1, 1.4, -450.0, -80.0], [3.6, 1, 1.3, -110.0, 28.0], [4.4, -1, 1.2, -110.0, 28.0],
		[2.2, 1, 1.4, -100.0, 20.0], [7.6, -1, 1.2, -60.0, 26.0], [-37.0, 1, 5.2, -600.0, 120.0], [-36.9, -1, 4.8, -600.0, 120.0]]
	for i in defs.size():
		var d: Array = defs[i]
		var look := {"t": {"hair": i % 4, "glasses": 1 if i % 5 == 0 else 0, "beard": 1 if i % 6 == 1 else 0, "mouth": 1, "tie": false, "badge": false, "pack": i % 3 == 0}}
		var r := Rig.create(sh[i % 8], sk[(i * 3) % 5], hr[i % 4], "Peatón", look)
		r.name_label.visible = false
		var x: float = d[3] + rnd(i + 3) * (d[4] - d[3])
		r.position = Vector3(x, .14, d[0])
		add_child(r); set_layer(r)
		peds.append({"r": r, "z": d[0], "dir": d[1], "sp": d[2], "x0": d[3], "x1": d[4], "x": x, "ph": rnd(i) * 6, "bike": d[2] > 4})


## Peatones con ruta (zonas nuevas): caminan por una polilínea, a veces se detienen a mirar
## alrededor y siguen. def: {pts, sp, n, pause, loop, bike, kids}
var walkers: Array = []


func add_walker(def: Dictionary) -> void:
	var sh := [Color("#e84a4a"), Color("#2f6fd0"), Color("#ffd23f"), Color("#4cb87a"), Color("#f2f2f2"), Color("#9a5fd0"), Color("#ff8a3a"), Color("#25c0c0")]
	var sk := [Color("#f1c9a5"), Color("#d9a47a"), Color("#b07a52"), Color("#8a5a3a"), Color("#5a3a26")]
	var hr := [Color("#1a1410"), Color("#3a2616"), Color("#6a4a2a"), Color("#111111")]
	var pts: Array = def.pts
	var L := 0.0
	for i in pts.size() - 1: L += (pts[i + 1] - pts[i]).length()
	if def.get("loop", false): L += (pts[0] - pts[pts.size() - 1]).length()
	for k in int(def.get("n", 1)):
		var i := walkers.size() + 300
		var look := {"t": {"hair": i % 4, "glasses": 1 if i % 5 == 0 else 0, "beard": 1 if i % 6 == 1 else 0, "mouth": 1, "tie": false, "badge": false, "pack": i % 3 == 0}}
		var r := Rig.create(sh[i % 8], sk[(i * 3) % 5], hr[i % 4], "Peatón", look)
		r.name_label.visible = false
		if def.get("kids", false): r.scale = Vector3.ONE * .72
		add_child(r); set_layer(r)
		walkers.append({"r": r, "pts": pts, "loop": def.get("loop", false), "L": L, "s": rnd(i) * L, "dir": 1 if k % 2 == 0 or def.get("loop", false) else -1,
			"sp": float(def.sp) * (.85 + rnd(i * 1.7) * .3), "pause": float(def.get("pause", .2)), "wait": 0.0, "ph": rnd(i) * 6, "bike": def.get("bike", false)})


func _path_pos(w: Dictionary) -> Array:
	var pts: Array = w.pts
	var s: float = w.s
	var n := pts.size()
	var segs := n if w.loop else n - 1
	for i in segs:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[(i + 1) % n]
		var l := (b - a).length()
		if s <= l or i == segs - 1:
			var f: float = clampf(s / maxf(l, .001), 0.0, 1.0)
			return [a.lerp(b, f), (b - a).normalized()]
		s -= l
	return [pts[0], Vector3.FORWARD]


func walker_tick(dt: float, t: float, cam_pos: Vector3) -> void:
	for w in walkers:
		var p0: Array = _path_pos(w)
		var pos: Vector3 = p0[0]
		var near := Vector2(pos.x - cam_pos.x, pos.z - cam_pos.z).length_squared() < 150.0 * 150.0
		w.r.visible = near
		var moving := true
		if w.wait > 0:
			w.wait -= dt; moving = false
		else:
			w.s += w.dir * w.sp * dt
			if w.loop:
				w.s = fposmod(w.s, w.L)
			elif w.s > w.L or w.s < 0:
				w.dir *= -1; w.s = clampf(w.s, 0, w.L)
				if randf() < .6: w.wait = 1.0 + randf() * 2.5
			if w.pause > 0 and randf() < w.pause * dt * .25:
				w.wait = 1.5 + randf() * 3.5     # se detiene a mirar el mar, el celular o una vitrina
		if not near: continue
		var p1: Array = _path_pos(w)
		var d: Vector3 = p1[1] * w.dir
		w.r.position = Vector3(p1[0].x, .14, p1[0].z)
		if moving and d.length_squared() > .01:
			w.r.rotation.y = lerp_angle(w.r.rotation.y, atan2(d.x, d.z), minf(1, dt * 8))
		if moving: w.ph += dt * w.sp * (3.2 if not w.bike else 1.6)
		w.r.animate(dt, t, 0, moving, w.ph)


func ped_tick(dt: float, t: float, cx: float) -> void:
	for p in peds:
		var near: bool = absf(p.x - cx) < 170
		p.r.visible = near
		if p.get("wait", 0.0) > 0:
			p.wait -= dt
			if near:
				p.r.position = Vector3(p.x, .14, p.z)
				p.r.animate(dt, t, 0, false, p.ph)
			continue
		if not p.bike and randf() < dt * .03: p.wait = 1.5 + randf() * 3.0   # pausa breve
		p.x += p.dir * p.sp * dt
		if p.x < p.x0 or p.x > p.x1:
			p.dir *= -1
			p.x = clampf(p.x, p.x0, p.x1)
		if not near: continue
		p.ph += dt * p.sp * (3.2 if not p.bike else 1.6)
		p.r.position = Vector3(p.x, .14, p.z)
		p.r.rotation.y = PI / 2 if p.dir > 0 else -PI / 2
		p.r.animate(dt, t, 0, true, p.ph)


# ---------------- superdeportivo del jugador ----------------
func _player_car() -> void:
	car = Cars.supercar(Color("#f2c200"))
	car.position = car_home
	car.rotation.y = 0.0
	add_child(car); set_layer(car)
	sts.append({"car": true, "r": 3.4, "kind": "car", "l": "🏎️ Subir al Lamborghini y manejar por la ciudad (E)"})


func park_car(x: float) -> void:
	car.position = Vector3(x, 0, -3.0)
	car.rotation = Vector3.ZERO


# ---------------- colisiones a pie ----------------
func _collisions() -> void:
	wk.append([D.XB + 10, D.XA - 10, -44.6, 9.6])


func free_at(x: float, z: float) -> bool:
	for d in dk:
		if absf(x - d[0]) < d[2] and absf(z - d[1]) < d[3]: return false
	for p in parked:
		if p.state == "parked" and p.g.visible and absf(x - p.x) < 2.4 and absf(z - D.PARK_Z) < 1.0: return false
	if car and not car.get_meta("driving", false) and absf(x - car.position.x) < 2.4 and absf(z - car.position.z) < 1.1: return false
	for r in wk:
		if x > r[0] and x < r[1] and z > r[2] and z < r[3]: return true
	return false


# ---------------- salida de los compañeros al terminar la jornada ----------------
func start_departures(names: Array) -> void:
	if departures.size(): return
	var t0 := Time.get_ticks_msec() + 1200.0
	var sh := [Color("#2f6f8f"), Color("#c4503f"), Color("#4c9a6a"), Color("#8a5fb0"), Color("#e8a77c"), Color("#3a3f9a")]
	var i := 0
	for p in parked:
		if i >= names.size(): break
		if p.used: continue
		p.used = true
		var r := Rig.create(sh[i % sh.size()], Color("#d9a47a") if i % 2 else Color("#f1c9a5"), Color("#1a1410"), str(names[i]))
		r.name_label.visible = false
		r.visible = false
		add_child(r); set_layer(r)
		var door := Vector3(CityData.CAA_X + (rnd(i) - .5) * 2, .15, 9.0)
		departures.append({"r": r, "car": p, "t0": t0 + i * 1500.0, "st": "wait", "pts": [Vector2(door.x, 2.6), Vector2(p.x, 2.6), Vector2(p.x, -1.2)], "pi": 0, "x": door.x, "z": door.z, "ph": 0.0})
		i += 1
	if guard == null:
		guard = Rig.create(Color("#6a7080"), Color("#c58f66"), Color("#111111"), "Guardia Rubén", {"outfit": "armor", "t": {"hair": -1, "glasses": 0, "beard": 0, "mouth": 0, "tie": false, "badge": false, "pack": false}})
		guard.position = Vector3(CityData.CAA_X - 3.5, .15, 9.2)
		guard.rotation.y = PI
		add_child(guard)
	guard.visible = true


func departures_tick(dt: float, t: float) -> void:
	var now := Time.get_ticks_msec()
	for d in departures:
		var r: Rig = d.r
		if d.st == "wait":
			if now >= d.t0:
				d.st = "walk"; r.visible = true; r.position = Vector3(d.x, .15, d.z)
			continue
		if d.st == "walk":
			if d.pi >= d.pts.size():
				d.st = "drive"; r.visible = false; d.car.state = "drive"; continue
			var p: Vector2 = d.pts[d.pi]
			var dv := p - Vector2(d.x, d.z)
			if dv.length() < .1:
				d.pi += 1; continue
			var step := dv.normalized() * 1.7 * dt
			d.x += step.x; d.z += step.y
			d.ph += dt * 9
			r.position = Vector3(d.x, .15, d.z)
			r.rotation.y = atan2(dv.x, dv.y)
			r.animate(dt, t, 0, true, d.ph)
	for c in parked:
		if c.state == "drive":
			c.v = minf(24.0, c.v + 6.0 * dt)
			c.g.position.x += c.v * dt
			var k := minf(1.0, (c.g.position.x - c.x) / 16.0)
			c.g.position.z = D.PARK_Z - k * (D.LANES_W[0] - D.PARK_Z) * -1.0
			c.g.rotation.y = -sin(k * PI) * .25
			Cars.roll(c.g, c.v * dt)
			if c.g.position.x > c.x + 300:
				c.state = "gone"; c.g.visible = false


func reset_departures() -> void:
	for d in departures: d.r.queue_free()
	departures.clear()
	for c in parked:
		c.state = "parked"; c.v = 0.0; c.used = false
		c.g.position = Vector3(c.x, 0, D.PARK_Z); c.g.rotation.y = 0.0; c.g.visible = true
	if guard: guard.visible = false


# ---------------- bucle ----------------
func tick(dt: float, t: float, cam_pos: Vector3, player: Dictionary) -> void:
	traffic_tick(dt, cam_pos.x, player)
	ped_tick(dt, t, cam_pos.x)
	walker_tick(dt, t, cam_pos)
	departures_tick(dt, t)
	for s in ships:
		s.position.x += .6 * dt * (1.0 if s.get_index() % 2 else -1.0) * 0.2
	var bl := int(t / 500.0) % 2 == 0
	for b in beacons:
		(b as MeshInstance3D).visible = bl
	for i in marks.size():
		var m: Dictionary = marks[i]
		var p := 1.0 + sin(t / 300.0 + i) * .06
		m.ring.scale = Vector3(p, .02, p)
		m.bm.albedo_color.a = .14 + sin(t / 400.0 + i) * .05
		m.g.visible = absf(cam_pos.x - m.d.x) < 400
