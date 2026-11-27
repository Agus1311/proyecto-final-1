class_name Cars
extends RefCounted
## Vehículos procedurales con secciones transversales (loft superelíptico):
## superdeportivo con pintura con barniz (clearcoat), rines, frenos y luces LED;
## autos del tráfico (sedán, SUV, hatchback, pick-up, taxi), MiBus y diablo rojo.

const TEX := "res://assets/textures/city/"
static var _mats := {}
static var _meshes := {}


static func tex(n: String) -> Texture2D:
	return load(TEX + n + ".png")


# ---------------- materiales ----------------
static func paint(col: Color, metallic := .55) -> StandardMaterial3D:
	var k := "paint" + col.to_html() + str(metallic)
	if _mats.has(k): return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.metallic_specular = .6
	m.roughness = .3
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = .03
	m.normal_enabled = true
	m.normal_texture = tex("flake_normal")
	m.normal_scale = .06
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(6, 6, 6)
	_mats[k] = m
	return m


static func mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind): return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"glass":
			m.albedo_color = Color(.02, .025, .03, .82)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			m.metallic = .2; m.roughness = .02; m.metallic_specular = 1.0
		"glass_clear":
			m.albedo_color = Color(.55, .6, .65, .35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = .02; m.metallic_specular = 1.0
		"carbon":
			m.albedo_texture = tex("carbon_albedo"); m.normal_enabled = true; m.normal_texture = tex("carbon_normal")
			m.roughness_texture = tex("carbon_rough"); m.uv1_triplanar = true; m.uv1_scale = Vector3(3, 3, 3)
			m.clearcoat_enabled = true; m.clearcoat = .8; m.clearcoat_roughness = .05
		"black":
			m.albedo_color = Color(.035, .035, .04); m.roughness = .55
		"trim":
			m.albedo_color = Color(.08, .08, .09); m.roughness = .35; m.metallic = .3
		"chrome":
			m.albedo_color = Color(.85, .86, .88); m.metallic = 1.0; m.roughness = .08
		"alu":
			m.albedo_texture = tex("alu_albedo"); m.normal_enabled = true; m.normal_texture = tex("alu_normal")
			m.roughness_texture = tex("alu_rough"); m.metallic = 1.0; m.uv1_triplanar = true; m.uv1_scale = Vector3(4, 4, 4)
		"rim_dark":
			m.albedo_color = Color(.12, .12, .13); m.metallic = .9; m.roughness = .25
		"tire":
			m.albedo_texture = tex("tire_albedo"); m.normal_enabled = true; m.normal_texture = tex("tire_normal")
			m.roughness_texture = tex("tire_rough"); m.normal_scale = .8
		"disc":
			m.albedo_color = Color(.42, .42, .44); m.metallic = .9; m.roughness = .35
		"caliper":
			m.albedo_color = Color("#d8a400"); m.roughness = .3; m.clearcoat_enabled = true
		"head":
			m.albedo_color = Color.WHITE; m.emission_enabled = true; m.emission = Color("#eaf4ff"); m.emission_energy_multiplier = 4.0
		"head_off":
			m.albedo_color = Color(.85, .88, .9); m.metallic = .8; m.roughness = .1
		"tail":
			m.albedo_color = Color("#ff1a10"); m.emission_enabled = true; m.emission = Color("#ff1208"); m.emission_energy_multiplier = 2.6
		"indicator":
			m.albedo_color = Color("#ffa020"); m.emission_enabled = true; m.emission = Color("#ff9010"); m.emission_energy_multiplier = 1.4
		"leather":
			m.albedo_texture = tex("leather_albedo"); m.normal_enabled = true; m.normal_texture = tex("leather_normal")
			m.roughness_texture = tex("leather_rough"); m.uv1_triplanar = true; m.uv1_scale = Vector3(3, 3, 3)
		"plastic_grey":
			m.albedo_color = Color(.18, .18, .19); m.roughness = .6
		"bus_glass":
			m.albedo_color = Color(.04, .06, .07); m.metallic = .3; m.roughness = .03
	_mats[kind] = m
	return m


static func tex_mat(t: String, rough := .45, emis := 0.0) -> StandardMaterial3D:
	var k := "tex_" + t + str(rough) + str(emis)
	if _mats.has(k): return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(t)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if emis > 0:
		m.emission_enabled = true; m.emission_texture = tex(t); m.emission_energy_multiplier = emis
	if t.begins_with("bus_"):
		m.clearcoat_enabled = true; m.clearcoat = .7
	_mats[k] = m
	return m


# ---------------- geometría base ----------------
## Sección superelíptica: s = [x, semiancho, y_inf, y_sup, exponente, factor_ancho_superior, factor_ancho_inferior]
static func _ring(s: Array, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var yc: float = (s[2] + s[3]) * .5
	var hh: float = (s[3] - s[2]) * .5
	var e: float = 2.0 / float(s[4])
	for i in n:
		var th := TAU * i / n
		var c := cos(th); var sn := sin(th)
		var y := yc + hh * signf(sn) * pow(absf(sn), e)
		var z: float = s[1] * signf(c) * pow(absf(c), e)
		var f := (y - yc) / maxf(hh, .001)
		if f > 0: z *= lerpf(1.0, s[5], f)
		else: z *= lerpf(1.0, s[6], -f)
		out.append(Vector3(s[0], y, z))
	return out


## Superficie lofteada (cerrada en los extremos). glass_fn(centro, normal) -> true para vidrio.
static func loft(secs: Array, n: int, body: Material, glass: Material = null, glass_fn := Callable()) -> ArrayMesh:
	var rings: Array = []
	for s in secs: rings.append(_ring(s, n))
	var st_b := SurfaceTool.new(); st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_g := SurfaceTool.new(); st_g.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_g := false
	for r in rings.size() - 1:
		var A: PackedVector3Array = rings[r]
		var B: PackedVector3Array = rings[r + 1]
		for i in n:
			var j := (i + 1) % n
			var q := [A[i], B[i], B[j], A[j]]
			var cen: Vector3 = (q[0] + q[1] + q[2] + q[3]) * .25
			var nor: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
			var st := st_b
			if glass != null and glass_fn.is_valid() and glass_fn.call(cen, nor):
				st = st_g; has_g = true
			for t in [[0, 2, 1], [0, 3, 2]]:
				for k in t:
					var v: Vector3 = q[k]
					st.set_uv(Vector2(v.x * .5, v.y * .5))
					st.add_vertex(v)
	# tapas
	for e in [0, rings.size() - 1]:
		var R: PackedVector3Array = rings[e]
		var c := Vector3.ZERO
		for v in R: c += v
		c /= R.size()
		for i in n:
			var j := (i + 1) % n
			if e == 0:
				st_b.add_vertex(c); st_b.add_vertex(R[i]); st_b.add_vertex(R[j])
			else:
				st_b.add_vertex(c); st_b.add_vertex(R[j]); st_b.add_vertex(R[i])
	st_b.generate_normals(); st_b.generate_tangents()
	var mesh := st_b.commit()
	mesh.surface_set_material(0, body)
	if has_g:
		st_g.generate_normals(); st_g.generate_tangents()
		st_g.commit(mesh)
		mesh.surface_set_material(1, glass)
	return mesh


## Sólido de revolución alrededor del eje Z (para neumáticos y rines). prof: [radio, z]
static func lathe(prof: Array, seg: int, m: Material) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in prof.size() - 1:
		for k in seg:
			var a0 := TAU * k / seg; var a1 := TAU * (k + 1) / seg
			var p := [
				Vector3(cos(a0) * prof[i][0], sin(a0) * prof[i][0], prof[i][1]),
				Vector3(cos(a1) * prof[i][0], sin(a1) * prof[i][0], prof[i][1]),
				Vector3(cos(a1) * prof[i + 1][0], sin(a1) * prof[i + 1][0], prof[i + 1][1]),
				Vector3(cos(a0) * prof[i + 1][0], sin(a0) * prof[i + 1][0], prof[i + 1][1])]
			var uvs := [Vector2(float(k) / seg * 6, float(i) / prof.size()), Vector2(float(k + 1) / seg * 6, float(i) / prof.size()),
				Vector2(float(k + 1) / seg * 6, float(i + 1) / prof.size()), Vector2(float(k) / seg * 6, float(i + 1) / prof.size())]
			for t in [[0, 2, 1], [0, 3, 2]]:
				for q in t:
					st.set_uv(uvs[q]); st.add_vertex(p[q])
	st.generate_normals(); st.generate_tangents()
	var mesh := st.commit()
	mesh.surface_set_material(0, m)
	return mesh


static func _bx(p: Node3D, sz: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = sz
	mi.mesh = bm; mi.material_override = m
	mi.position = pos; mi.rotation = rot
	p.add_child(mi)
	return mi


static func _cyl(p: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, seg := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = seg
	mi.mesh = cm; mi.material_override = m
	mi.position = pos; mi.rotation = rot
	p.add_child(mi)
	return mi


# ---------------- ruedas ----------------
static func wheel(r := .36, w := .28, sport := true) -> Node3D:
	var key := "wheel%s%s%s" % [r, w, sport]
	var g := Node3D.new()
	if not _meshes.has(key):
		var hw := w * .5
		var tire := lathe([[r * .72, -hw * .9], [r * .9, -hw], [r * .99, -hw * .8], [r, -hw * .4], [r, hw * .4], [r * .99, hw * .8], [r * .9, hw], [r * .72, hw * .9]], 32, mat("tire"))
		var rim_r := r * .72
		var rim := lathe([[rim_r, hw * .92], [rim_r * .97, hw * .8], [rim_r * .9, hw * .5], [rim_r * .35, hw * .5], [rim_r * .2, hw * .7], [0.0, hw * .7]], 28, mat("alu") if sport else mat("rim_dark"))
		var barrel := lathe([[rim_r * .98, -hw * .9], [rim_r * .98, hw * .9]], 24, mat("rim_dark"))
		_meshes[key] = [tire, rim, barrel]
	var ms: Array = _meshes[key]
	for m in ms:
		var mi := MeshInstance3D.new(); mi.mesh = m; g.add_child(mi)
	var rim_r2 := r * .72
	var spokes := 5 if sport else 6
	for i in spokes:
		var a := TAU * i / spokes
		for off in ([-.09, .09] if sport else [0.0]):
			var s := _bx(g, Vector3(rim_r2 * .95, .035 if sport else .05, .025), Vector3(cos(a + off) * rim_r2 * .5, sin(a + off) * rim_r2 * .5, w * .5 * .55), mat("alu") if sport else mat("rim_dark"))
			s.rotation.z = a + off
	_cyl(g, r * .12, .04, Vector3(0, 0, w * .5 * .62), mat("chrome"), Vector3(PI / 2, 0, 0), 12)
	return g


## Rueda completa con disco y pinza (fija) en un nodo «hub» que gira con la dirección.
static func wheel_assembly(r: float, w: float, sport: bool, side: float) -> Dictionary:
	var hub := Node3D.new()
	var spin := Node3D.new(); hub.add_child(spin)
	var wh := wheel(r, w, sport)
	wh.rotation.y = 0.0 if side > 0 else PI
	spin.add_child(wh)
	if sport:
		_cyl(hub, r * .62, .03, Vector3(0, 0, -side * .03), mat("disc"), Vector3(PI / 2, 0, 0), 24)
		_bx(hub, Vector3(.16, .1, .06), Vector3(-.1, r * .42, side * .0), mat("caliper"))
	return {"hub": hub, "spin": spin}


# ---------------- superdeportivo (diseño propio en cuña, sin logotipos) ----------------
static func supercar(col := Color("#f2c200")) -> Node3D:
	var g := Node3D.new()
	g.name = "Superdeportivo"
	var body := paint(col, .5)
	# carrocería inferior (secciones de atrás hacia adelante; X = adelante)
	var low := [
		[-2.30, .80, .30, .66, 3.2, .86, .80],
		[-2.18, .95, .20, .80, 3.6, .88, .74],
		[-1.85, 1.0, .15, .87, 4.2, .86, .72],
		[-1.38, 1.0, .14, .86, 4.6, .84, .72],
		[-.85, .95, .13, .80, 4.8, .82, .78],
		[-.25, .94, .13, .78, 4.8, .84, .80],
		[.45, .96, .13, .76, 4.6, .84, .80],
		[1.05, 1.0, .14, .76, 4.2, .82, .74],
		[1.45, 1.0, .14, .74, 3.8, .8, .72],
		[1.9, .95, .15, .58, 3.2, .78, .74],
		[2.2, .82, .17, .42, 2.8, .8, .8],
		[2.33, .62, .21, .32, 2.4, .82, .86]]
	var lm := MeshInstance3D.new(); lm.mesh = loft(low, 32, body); g.add_child(lm)
	# habitáculo (techo de pintura, parabrisas y ventanas laterales de vidrio)
	var cab := [
		[-1.55, .7, .7, .82, 3.0, .8, 1.0],
		[-1.1, .66, .7, .98, 3.2, .74, 1.0],
		[-.5, .64, .7, 1.12, 3.4, .7, 1.0],
		[0.0, .65, .7, 1.14, 3.4, .7, 1.0],
		[.45, .68, .7, 1.06, 3.2, .74, 1.0],
		[.9, .72, .7, .86, 3.0, .8, 1.0],
		[1.2, .74, .7, .74, 2.8, .84, 1.0]]
	var glass_fn := func(c: Vector3, nr: Vector3) -> bool:
		if c.x > .28 and nr.y > .2: return true            # parabrisas
		if absf(nr.z) > .55 and c.y > .8 and c.y < 1.06 and c.x > -.95 and c.x < .95: return true  # laterales
		if c.x < -1.0 and nr.y > .3 and c.x > -1.5: return true  # ventana del motor
		return false
	var cm := MeshInstance3D.new(); cm.mesh = loft(cab, 24, body, mat("glass"), glass_fn); g.add_child(cm)
	# tomas de aire laterales, faldones, difusor, splitter y alerón
	for s in [-1.0, 1.0]:
		_bx(g, Vector3(.8, .24, .05), Vector3(-1.0, .5, s * .955), mat("carbon"), Vector3(0, s * .08, .16))
		_bx(g, Vector3(2.3, .07, .05), Vector3(-.1, .19, s * .9), mat("carbon"))
		# espejos
		var mir := _bx(g, Vector3(.18, .09, .14), Vector3(.62, .9, s * .84), body)
		_bx(mir, Vector3(.02, .07, .12), Vector3(-.09, 0, 0), mat("chrome"))
		_bx(g, Vector3(.08, .03, .1), Vector3(.62, .86, s * .76), mat("trim"))
		# faros LED rasgados en el frente y firma «Y»
		_bx(g, Vector3(.12, .06, .4), Vector3(2.19, .34, s * .58), mat("black"), Vector3(0, s * .42, 0))
		_bx(g, Vector3(.06, .022, .36), Vector3(2.23, .355, s * .58), mat("head"), Vector3(0, s * .42, 0))
		_bx(g, Vector3(.05, .02, .16), Vector3(2.2, .32, s * .72), mat("head"), Vector3(0, s * .9, .25))
		# luces traseras
		_bx(g, Vector3(.05, .055, .5), Vector3(-2.29, .6, s * .5), mat("tail"))
		_bx(g, Vector3(.05, .12, .04), Vector3(-2.28, .55, s * .74), mat("tail"))
		_bx(g, Vector3(.04, .03, .12), Vector3(1.72, .66, s * .97), mat("indicator"))
		# escape cuádruple
		for o in [-.07, .07]:
			_cyl(g, .045, .14, Vector3(-2.3, .34, s * .14 + o), mat("chrome"), Vector3(0, 0, PI / 2), 12)
	_bx(g, Vector3(.05, .03, .5), Vector3(-2.3, .62, 0), mat("tail"))
	_bx(g, Vector3(.08, .12, 1.0), Vector3(2.3, .25, 0), mat("black"))
	_bx(g, Vector3(.22, .03, 1.6), Vector3(2.24, .17, 0), mat("carbon"))
	_bx(g, Vector3(.35, .2, 1.4), Vector3(-2.2, .3, 0), mat("trim"))
	for i in 5:
		_bx(g, Vector3(.4, .16, .02), Vector3(-2.18, .27, -.5 + i * .25), mat("carbon"))
	_bx(g, Vector3(.38, .04, 1.86), Vector3(-2.05, 1.02, 0), mat("carbon"), Vector3(0, 0, -.06))
	for s in [-.55, .55]:
		_bx(g, Vector3(.08, .2, .03), Vector3(-2.0, .9, s), mat("carbon"))
	# rejillas del capó y techo «Y»
	for s in [-.3, .3]:
		_bx(g, Vector3(.42, .02, .16), Vector3(1.55, .66, s), mat("black"), Vector3(0, 0, -.16))
	for i in 6:
		_bx(g, Vector3(.03, .02, .9), Vector3(-1.25 - i * .07, .83 - i * .006, 0), mat("black"))
	# interior visible: asientos y volante
	for s in [-.32, .32]:
		_bx(g, Vector3(.55, .1, .42), Vector3(-.35, .42, s), mat("leather"))
		_bx(g, Vector3(.12, .58, .42), Vector3(-.62, .66, s), mat("leather"), Vector3(0, 0, .25))
	var sw := _cyl(g, .17, .04, Vector3(.38, .78, -.32), mat("leather"), Vector3(0, 0, PI / 2 - .35), 20)
	sw.name = "Volante"
	_bx(g, Vector3(.3, .2, 1.5), Vector3(.55, .65, 0), mat("trim"))
	# ruedas
	var wheels := []
	for wp in [[1.42, .385, .28, true, .92], [-1.38, .4, .33, false, .93]]:
		for s in [-1.0, 1.0]:
			var a := wheel_assembly(wp[1], wp[2], true, s)
			a.hub.position = Vector3(wp[0], wp[1], s * wp[4])
			a.front = wp[3]
			g.add_child(a.hub)
			wheels.append(a)
	g.set_meta("wheels", wheels)
	g.set_meta("steer", sw)
	# faros reales para la noche
	for s in [-1.0, 1.0]:
		var sl := SpotLight3D.new()
		sl.position = Vector3(2.15, .5, s * .62)
		sl.rotation = Vector3(-.06, -PI / 2, 0)
		sl.spot_range = 45; sl.spot_angle = 26; sl.light_energy = 0.0; sl.light_color = Color("#eaf2ff")
		sl.shadow_enabled = false
		sl.name = "Faro"
		g.add_child(sl)
	return g


# ---------------- autos del tráfico ----------------
const PROFILES := {
	"sedan": {"L": 4.6, "W": .9, "low": [[-2.3, .76, .32, .74, 3.0, .9, .9], [-2.0, .88, .28, .86, 3.6, .9, .88], [-1.0, .9, .26, .86, 4.0, .9, .88], [.6, .9, .26, .84, 4.0, .9, .88], [1.7, .88, .28, .78, 3.6, .86, .88], [2.25, .8, .32, .66, 3.0, .84, .9], [2.32, .66, .36, .58, 2.6, .8, .9]],
		"cab": [[-1.45, .78, .84, .9, 3.0, .86, 1.0], [-1.1, .76, .84, 1.36, 3.0, .82, 1.0], [.1, .76, .84, 1.42, 3.0, .82, 1.0], [.7, .78, .84, 1.3, 3.0, .84, 1.0], [1.15, .8, .84, .9, 3.0, .88, 1.0]], "wr": .33, "wx": [1.4, -1.38]},
	"suv": {"L": 4.8, "W": .95, "low": [[-2.4, .86, .38, .98, 3.6, .92, .9], [-2.1, .94, .34, 1.06, 4.4, .92, .88], [.8, .95, .34, 1.06, 4.4, .92, .88], [1.8, .93, .36, 1.02, 4.0, .9, .88], [2.35, .86, .4, .92, 3.4, .88, .9], [2.42, .74, .46, .82, 3.0, .86, .9]],
		"cab": [[-2.3, .86, 1.04, 1.7, 3.6, .88, 1.0], [.2, .86, 1.04, 1.78, 3.6, .86, 1.0], [.9, .88, 1.04, 1.64, 3.4, .88, 1.0], [1.45, .9, 1.04, 1.1, 3.0, .9, 1.0]], "wr": .38, "wx": [1.5, -1.5]},
	"hatch": {"L": 4.1, "W": .86, "low": [[-2.0, .8, .32, .84, 3.4, .9, .9], [-1.8, .86, .3, .88, 4.0, .9, .88], [.6, .86, .28, .84, 4.0, .9, .88], [1.55, .84, .3, .76, 3.6, .86, .88], [2.0, .76, .34, .64, 3.0, .84, .9], [2.06, .62, .38, .56, 2.6, .8, .9]],
		"cab": [[-1.98, .8, .84, 1.36, 3.2, .84, 1.0], [.0, .8, .84, 1.44, 3.2, .82, 1.0], [.6, .8, .84, 1.32, 3.0, .84, 1.0], [1.15, .82, .84, .88, 3.0, .88, 1.0]], "wr": .32, "wx": [1.3, -1.28]},
	"pickup": {"L": 5.3, "W": .96, "low": [[-2.65, .92, .5, 1.0, 4.4, .96, .9], [-1.0, .94, .48, 1.02, 4.6, .96, .88], [1.6, .94, .48, 1.04, 4.4, .94, .88], [2.5, .9, .5, .98, 3.6, .9, .9], [2.6, .78, .54, .88, 3.0, .88, .9]],
		"cab": [[-.6, .88, 1.0, 1.84, 4.0, .88, 1.0], [.4, .88, 1.0, 1.86, 4.0, .86, 1.0], [1.1, .9, 1.0, 1.62, 3.4, .88, 1.0], [1.6, .9, 1.0, 1.06, 3.0, .9, 1.0]], "wr": .4, "wx": [1.75, -1.7]},
}


static func traffic_car(kind: String, col: Color, taxi := false, plate := 0) -> Node3D:
	var P: Dictionary = PROFILES[kind]
	var g := Node3D.new()
	var body := paint(col, .35 if not taxi else .1)
	var key := "car_" + kind + col.to_html() + str(taxi)
	if not _meshes.has(key):
		var gf := func(c: Vector3, nr: Vector3) -> bool:
			return absf(nr.y) < .93 and c.y > float(P.cab[0][2]) + .06 and c.y < float(P.cab[1][3]) - .06
		_meshes[key] = [loft(P.low, 20, body), loft(P.cab, 20, body, mat("glass"), gf)]
	for m in _meshes[key]:
		var mi := MeshInstance3D.new(); mi.mesh = m; g.add_child(mi)
	var L: float = P.L; var W: float = P.W
	var fy: float = (P.low[-1][2] + P.low[-1][3]) * .5
	for s in [-1.0, 1.0]:
		_bx(g, Vector3(.05, .1, .34), Vector3(L / 2 + .01, fy + .04, s * W * .62), mat("head_off"))
		_bx(g, Vector3(.05, .12, .3), Vector3(-L / 2 - .01, fy + .14, s * W * .64), mat("tail"))
		_bx(g, Vector3(.14, .08, .1), Vector3(L * .2, float(P.cab[0][2]) + .02, s * (W + .02)), body)
	_bx(g, Vector3(.06, .18, W * 1.1), Vector3(L / 2, fy - .1, 0), mat("trim"))
	# placas delantera y trasera
	var pm := tex_mat("plate%d" % (plate % 12), .3)
	for e in [1.0, -1.0]:
		var pq := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(.42, .21); pq.mesh = qm
		pq.material_override = pm
		pq.position = Vector3(e * (L / 2 + .03), fy - .08, 0); pq.rotation.y = PI / 2 * e
		g.add_child(pq)
	if taxi:
		var ts := _bx(g, Vector3(.5, .16, .22), Vector3(-.1, float(P.cab[1][3]) + .08, 0), tex_mat("taxi_sign", .4, .6))
		ts.rotation.y = PI / 2
	var wheels := []
	var wr: float = P.wr
	for x in P.wx:
		for s in [-1.0, 1.0]:
			var a := wheel_assembly(wr, .24, false, s)
			a.hub.position = Vector3(x, wr, s * (W - .06))
			g.add_child(a.hub)
			wheels.append(a)
	g.set_meta("wheels", wheels)
	g.set_meta("len", L)
	return g


# ---------------- autobuses ----------------
static func bus(diablo := false) -> Node3D:
	var g := Node3D.new()
	var L := 11.6 if not diablo else 10.4
	var H := 3.1 if not diablo else 2.7
	var side := tex_mat("bus_diablo_side" if diablo else "bus_mibus_side", .35)
	var white := paint(Color("#f4f6f8") if not diablo else Color("#c8161f"), .1)
	_bx(g, Vector3(L, H, 2.5), Vector3(0, H / 2 + .45, 0), white)
	for s in [-1.0, 1.0]:
		var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(L - .1, H - .1); q.mesh = qm
		q.material_override = side
		q.position = Vector3(0, H / 2 + .45, s * 1.256)
		q.rotation.y = 0.0 if s > 0 else PI
		g.add_child(q)
	var fq := MeshInstance3D.new(); var fqm := QuadMesh.new(); fqm.size = Vector2(2.4, H - .1); fq.mesh = fqm
	fq.material_override = tex_mat("bus_mibus_front", .2) if not diablo else mat("bus_glass")
	fq.position = Vector3(L / 2 + .01, H / 2 + .45, 0); fq.rotation.y = PI / 2
	g.add_child(fq)
	_bx(g, Vector3(.05, 1.2, 2.2), Vector3(-L / 2 - .01, H * .7 + .45, 0), mat("bus_glass"))
	_bx(g, Vector3(3.2, .38, 1.7), Vector3(-1.2, H + .64, 0), mat("plastic_grey"))
	for s in [-1.0, 1.0]:
		_bx(g, Vector3(.05, .18, .3), Vector3(-L / 2 - .02, .9, s * 1.0), mat("tail"))
		_bx(g, Vector3(.05, .16, .34), Vector3(L / 2 + .02, .85, s * .95), mat("head_off"))
	var wheels := []
	for x in [L * .33, -L * .3]:
		for s in [-1.0, 1.0]:
			var a := wheel_assembly(.52, .32, false, s)
			a.hub.position = Vector3(x, .52, s * 1.08)
			g.add_child(a.hub)
			wheels.append(a)
	g.set_meta("wheels", wheels)
	g.set_meta("len", L)
	return g


## Gira las ruedas según la distancia recorrida y orienta las delanteras.
static func roll(car: Node3D, dist: float, steer := 0.0) -> void:
	var ws: Array = car.get_meta("wheels", [])
	for a in ws:
		var r: float = .36
		a.spin.rotation.z -= dist / r
		if a.get("front", false):
			a.hub.rotation.y = steer
