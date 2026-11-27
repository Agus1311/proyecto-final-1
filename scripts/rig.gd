class_name Rig
extends Node3D
## Personaje cartoon (port de Zrig/ZGen del original) con contorno y piel con SSS.

var hd: Node3D
var body: Node3D
var aL: Node3D
var aR: Node3D
var lL: Node3D
var lR: Node3D
var name_label: Label3D
var bubble: Label3D
var bubble_t := 0.0
var traits := {}
var k := 0.0

const ACC := [Color("#2f6f8f"), Color("#4c9a6a"), Color("#c4503f"), Color("#8a5fb0"), Color("#e8a77c"), Color("#3a3f9a")]
const INK := Color("#111111")
const MOUTH := Color("#7a2a2a")
const PANT := Color("#2a2a3a")
const SHOE := Color("#1c1c26")

static var _sph: SphereMesh
static var _cyl: CylinderMesh
static var _box: BoxMesh
static var _cone: CylinderMesh
static var _torus: TorusMesh


static func _hash(s: String) -> int:
	var h := 2166136261
	for c in s.to_utf8_buffer():
		h = ((h ^ c) * 16777619) & 0xffffffff
	return h


static func make_traits(nm: String) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = _hash(nm)
	var pk := func(a: Array): return a[r.randi() % a.size()]
	return {"hair": pk.call([0,1,2,3,4]), "glasses": pk.call([0,0,1,2]), "beard": pk.call([0,0,0,1,2]),
		"brow": pk.call([.05,.08]), "mouth": pk.call([0,1,2]), "tie": r.randf() < .35, "badge": r.randf() < .7,
		"pack": r.randf() < .3, "color": pk.call(ACC), "tilt": pk.call([.08,.2,.3])}


static func _meshes() -> void:
	if _sph: return
	_sph = SphereMesh.new(); _sph.radius = 1; _sph.height = 2; _sph.radial_segments = 32; _sph.rings = 16
	_cyl = CylinderMesh.new(); _cyl.top_radius = 1; _cyl.bottom_radius = 1; _cyl.height = 1; _cyl.radial_segments = 28
	_box = BoxMesh.new(); _box.size = Vector3.ONE
	_cone = CylinderMesh.new(); _cone.top_radius = 0; _cone.bottom_radius = 1; _cone.height = 1; _cone.radial_segments = 12
	_torus = TorusMesh.new(); _torus.inner_radius = .86; _torus.outer_radius = 1.0


func _cloth(c: Color) -> StandardMaterial3D:
	return Mats.get_mat("fabric", c)


func _put(mesh: Mesh, mat: Material, s: Vector3, p: Vector3, parent: Node3D, rx := 0.0, rz := 0.0, outline := false) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = mat
	if outline:
		var m2: Material = mat.duplicate()
		m2.next_pass = Mats.outline()
		o.material_override = m2
	o.scale = s
	o.position = p
	o.rotation = Vector3(rx, 0, rz)
	parent.add_child(o)
	return o


var look := {}

static func create(shirt: Color, skin: Color, hair: Color, nm: String, lk := {}) -> Rig:
	_meshes()
	var g := Rig.new()
	g.name = nm
	g.look = lk
	g._build(shirt, skin, hair, nm)
	return g


func _build(shirt: Color, skin: Color, hair: Color, nm: String) -> void:
	traits = make_traits(nm)
	for kk in look.get("t", {}): traits[kk] = look.t[kk]
	k = randf() * 10
	var t := traits
	var sk := Mats.skin(skin)
	var hm: StandardMaterial3D = Mats.skin(hair).duplicate()
	hm.roughness = .8
	hm.subsurf_scatter_enabled = false
	var dk := skin.darkened(.2)
	body = Node3D.new(); add_child(body)
	var RX := .17
	var RZ := .12
	# torso
	_put(_cyl, _cloth(shirt), Vector3(RX, .62, RZ), Vector3(0, .93, 0), body, 0, 0, true)
	_put(_sph, _cloth(shirt), Vector3(RX, .09, RZ), Vector3(0, 1.24, 0), body)
	_put(_sph, _cloth(shirt), Vector3(RX, .07, RZ), Vector3(0, .63, 0), body)
	if t.pack:
		_put(_sph, _cloth(t.color), Vector3(.15, .2, .07), Vector3(0, .95, -(RZ + .03)), body)
	if t.tie:
		_put(_box, Mats.get_mat("fabric", t.color), Vector3(.05, .3, .012), Vector3(0, .9, RZ + .008), body)
	if t.badge:
		_put(_box, Mats.get_mat("plastic", Color("#222222")), Vector3(.014, .24, .01), Vector3(.07, 1.02, RZ + .006), body)
		_put(_box, Mats.get_mat("plastic", Color.WHITE), Vector3(.075, .1, .012), Vector3(.07, .88, RZ + .007), body)
	# cabeza
	hd = Node3D.new(); hd.position = Vector3(0, 1.42, 0); body.add_child(hd)
	_put(_sph, sk, Vector3(.18, .2, .17), Vector3.ZERO, hd, 0, 0, true)
	_put(_sph, sk, Vector3(.03, .045, .03), Vector3(-.18, -.025, 0), hd)
	_put(_sph, sk, Vector3(.03, .045, .03), Vector3(.18, -.025, 0), hd)
	var ink := Mats.unshaded(INK)
	for s in [-1, 1]:
		_put(_sph, ink, Vector3(.027, .037, .012), Vector3(s * .064, .012, .156), hd)
		_put(_sph, Mats.unshaded(Color.WHITE), Vector3(.008, .01, .006), Vector3(s * .064 + .007, .026, .166), hd)
		_put(_box, hm, Vector3(.062, t.brow * .3, .012), Vector3(s * .064, .078, .147), hd, 0, s * t.tilt)
	_put(_sph, Mats.skin(dk), Vector3(.02, .026, .022), Vector3(0, -.03, .172), hd)
	var mm := Mats.unshaded(MOUTH)
	if t.mouth == 2:
		_put(_sph, Mats.unshaded(Color("#3a1010")), Vector3(.035, .022, .012), Vector3(0, -.088, .152), hd)
	else:
		_put(_box, mm, Vector3(.09 if t.mouth else .07, .011, .01), Vector3(0, -.085, .153), hd)
		if t.mouth == 1:
			for s in [-1, 1]:
				_put(_box, mm, Vector3(.03, .011, .01), Vector3(s * .046, -.079, .15), hd, 0, s * .5)
	# pelo
	if int(t.hair) >= 0:
		_put(_sph, hm, Vector3(.192, .17, .182), Vector3(0, .045, -.012), hd, -.32)
	if look.get("cap", false):
		var cm := Mats.get_mat("fabric", Color("#111111"))
		_put(_sph, cm, Vector3(.198, .15, .19), Vector3(0, .07, -.005), hd, -.2)
		_put(_box, cm, Vector3(.15, .014, .1), Vector3(0, .098, .2), hd, .18)
	match int(t.hair):
		0:
			for i in 4:
				_put(_cone, hm, Vector3(.03, .075, .03), Vector3((i - 1.5) * .052, .122, .136), hd, PI + .25)
		1:
			for i in 8:
				var a := i / 8.0 * TAU
				var z := cos(a) * .14 - .02
				_put(_sph, hm, Vector3(.065, .065, .065), Vector3(sin(a) * .15, .1 + (.07 if z > .05 else 0.0), z), hd)
		2:
			_put(_sph, hm, Vector3(.2, .24, .08), Vector3(0, -.08, -.12), hd)
			_put(_sph, hm, Vector3(.04, .2, .12), Vector3(-.175, -.06, -.03), hd)
			_put(_sph, hm, Vector3(.04, .2, .12), Vector3(.175, -.06, -.03), hd)
		3:
			_put(_sph, hm, Vector3(.07, .07, .07), Vector3(0, .24, -.04), hd)
		4:
			_put(_sph, hm, Vector3(.1, .07, .13), Vector3(0, .2, .04), hd)
	if t.glasses:
		var gk := .058 if t.glasses == 2 else .05
		var gm := Mats.get_mat("metal", Color("#1a1a22"))
		for s in [-1, 1]:
			var ring := _put(_torus, gm, Vector3(gk, gk, gk), Vector3(s * .064, .012, .162), hd)
			ring.rotation.x = PI / 2
		_put(_box, gm, Vector3(.03, .008, .008), Vector3(0, .02, .163), hd)
	if t.beard == 1:
		_put(_sph, Mats.skin(skin.darkened(.3)), Vector3(.148, .07, .12), Vector3(0, -.12, .035), hd)
	elif t.beard == 2:
		_put(_sph, hm, Vector3(.155, .085, .13), Vector3(0, -.125, .04), hd)
	# extremidades
	aL = _limb(-(RX + .06), 1.2, .045, .5, _cloth(shirt), sk, true)
	aR = _limb(RX + .06, 1.2, .045, .5, _cloth(shirt), sk, true)
	var pant: Color = look.get("pant", PANT)
	lL = _limb(-.09, .62, .065, .55, _cloth(pant), Mats.get_mat("plastic", SHOE), false)
	lR = _limb(.09, .62, .065, .55, _cloth(pant), Mats.get_mat("plastic", SHOE), false)
	_outfit(shirt, skin, RX, RZ)
	# nombre y globo de diálogo
	name_label = Label3D.new()
	name_label.text = nm
	name_label.font = CanvasTex.font(true)
	name_label.font_size = 36
	name_label.pixel_size = .0026
	name_label.outline_size = 14
	name_label.outline_modulate = Color(0.06, 0.1, 0.14, .85)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position.y = 1.9
	name_label.no_depth_test = false
	add_child(name_label)
	bubble = Label3D.new()
	bubble.font = CanvasTex.font(true)
	bubble.font_size = 36
	bubble.pixel_size = .0032
	bubble.modulate = Color("#2a2230")
	bubble.outline_size = 22
	bubble.outline_modulate = Color(1, 1, 1, .96)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.width = 520
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.position.y = 2.35
	bubble.visible = false
	add_child(bubble)


func _outfit(shirt: Color, skin: Color, RX: float, RZ: float) -> void:
	var o: String = look.get("outfit", "")
	match o:
		"suit":
			_put(_box, Mats.get_mat("fabric", Color.WHITE), Vector3(.09, .34, .012), Vector3(0, .98, RZ + .004), body)
			_put(_box, Mats.get_mat("fabric", Color("#c4302a")), Vector3(.05, .3, .014), Vector3(0, .9, RZ + .01), body)
		"coat":
			_put(_cyl, _cloth(shirt), Vector3(RX + .015, .38, RZ + .015), Vector3(0, .47, 0), body)
		"cyber":
			var c1 := Mats.unshaded(Color("#38e0ff"), 2.5)
			var c2 := Mats.unshaded(Color("#c040ff"), 2.5)
			_put(_box, Mats.get_mat("plastic", Color("#1a1d28")), Vector3(.27, .1, .075), Vector3(0, .025, .17), hd)
			_put(_box, c2, Vector3(.23, .065, .02), Vector3(0, .025, .212), hd)
			_put(_box, c1, Vector3(.3, .012, .012), Vector3(0, 1.12, RZ + .02), body)
			_put(_box, c2, Vector3(.012, .5, .012), Vector3(.1, .95, RZ + .02), body)
			_put(_box, c2, Vector3(.012, .5, .012), Vector3(-.1, .95, RZ + .02), body)
			for a in [aL, aR]:
				_put(_box, c1, Vector3(.012, .38, .012), Vector3(.047, -.3, 0), a)
		"armor":
			var steel := Mats.get_mat("metal", Color("#c9ced6"))
			var gold := Mats.get_mat("metal", Color("#d0a030"))
			_put(_cyl, steel, Vector3(.2, .5, .145), Vector3(0, 1.0, 0), body)
			for s2 in [-1, 1]:
				_put(_sph, steel, Vector3(.11, .075, .12), Vector3(s2 * .245, 1.3, 0), body, 0, s2 * .35)
			_put(_box, gold, Vector3(.3, .03, .03), Vector3(0, .82, .17), body)
			_put(_sph, steel, Vector3(.2, .17, .19), Vector3(0, .05, -.005), hd, -.32)
			_put(_box, Mats.unshaded(Color("#111111")), Vector3(.22, .03, .02), Vector3(0, .03, .185), hd)
			_put(_box, Mats.get_mat("fabric", Color("#c4302a")), Vector3(.04, .13, .22), Vector3(0, .27, 0), hd)


func _limb(x: float, y: float, r: float, ln: float, mat: Material, end_mat: Material, arm: bool) -> Node3D:
	var p := Node3D.new()
	p.position = Vector3(x, y, 0)
	body.add_child(p)
	_put(_cyl, mat, Vector3(r, ln, r), Vector3(0, -ln / 2, 0), p, 0, 0, true)
	if arm:
		_put(_sph, mat, Vector3(.06, .06, .06), Vector3.ZERO, p)
		_put(_sph, end_mat, Vector3(.062, .062, .062), Vector3(0, -.52, 0), p)
	else:
		_put(_sph, end_mat, Vector3(.075, .05, .115), Vector3(0, -.57, .03), p)
	return p


func say(txt: String, sec := 3.5) -> void:
	bubble.text = txt
	bubble.visible = true
	bubble_t = sec


## Animación: sentado (sb=1), caminando (fase ph) o saludando.
func animate(dt: float, t: float, sit: float, walking: bool, ph: float, anim := "") -> void:
	if bubble_t > 0:
		bubble_t -= dt
		if bubble_t <= 0:
			bubble.visible = false
	var sw := sin(ph) * .6 if walking else 0.0
	var al := -sw * .9
	var ar := sw * .9
	# quieto: respiración (el torso sube y baja) y balanceo leve de los brazos
	var br := 0.0 if walking or sit > .5 else sin(t / 620.0 + k * 3.0)
	if body: body.scale.y = 1.0 + br * .012
	if hd: hd.position.y = hd.get_meta("y0", hd.position.y) + br * .008
	if hd and not hd.has_meta("y0"): hd.set_meta("y0", hd.position.y)
	if not walking and sit <= .5:
		al += br * .04; ar -= br * .04
	if sit > .5:
		al = -.95 + sin(t / 95.0 + k) * .1
		ar = -.95 + sin(t / 120.0 + k) * .1
	if anim == "wave":
		ar = -2.8 + sin(t / 110.0) * .4
	elif anim == "chat":
		ar = -.7 + sin(t / 170.0 + k) * .45
	elif anim == "sweep":
		al = -.8 + sin(t / 200.0) * .4
		ar = al
	elif anim == "phone":
		ar = -2.5; al = -.3
	lL.rotation.x = -sit * 1.55 + sw
	lR.rotation.x = -sit * 1.55 - sw
	aL.rotation.x = al
	aR.rotation.x = ar
