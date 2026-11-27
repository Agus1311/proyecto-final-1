class_name Mats
extends RefCounted
## Materiales PBR con texturas procedurales (albedo + normal + roughness),
## mapeo triplanar en espacio mundo para que nada se estire.

const TEX := "res://assets/textures/"
# tipo -> [textura, metros por repetición, normal_scale, metallic, tiñe con el color?]
const KINDS := {
	"plaster":  ["plaster", 2.0, 0.6, 0.0, true],
	"tile":     ["tile_checker", 2.0, 1.0, 0.0, false],
	"woodfloor":["wood_floor", 1.4, 1.0, 0.0, false],
	"carpet":   ["carpet", 0.8, 0.8, 0.0, true],
	"concrete": ["concrete", 2.5, 0.5, 0.0, true],
	"ceiling":  ["ceiling", 2.4, 0.7, 0.0, true],
	"wood":     ["wood", 1.2, 0.6, 0.0, true],
	"fabric":   ["fabric", 0.5, 0.8, 0.0, true],
	"metal":    ["metal", 0.8, 0.4, 0.75, true],
	"plastic":  ["plastic", 1.0, 0.3, 0.0, true],
	"rug":      ["rug", 3.0, 0.8, 0.0, false],
	"grille":   ["grille", 0.6, 1.0, 0.6, false],
}

static var _cache := {}
static var _tex := {}
static var _outline: ShaderMaterial


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(TEX + name + ".png")
	return _tex[name]


static func get_mat(kind: String, col: Color) -> StandardMaterial3D:
	var key := kind + col.to_html()
	if _cache.has(key):
		return _cache[key]
	var k: Array = KINDS.get(kind, KINDS["plastic"])
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(k[0] + "_albedo")
	m.albedo_color = col if k[4] else Color.WHITE
	m.normal_enabled = true
	m.normal_texture = tex(k[0] + "_normal")
	m.normal_scale = k[2]
	m.roughness_texture = tex(k[0] + "_rough")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 1.0
	m.metallic = k[3]
	m.metallic_specular = 0.5
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	var s := 1.0 / float(k[1])
	m.uv1_scale = Vector3(s, s, s)
	if kind == "rug":
		m.uv1_triplanar = false
		m.uv1_world_triplanar = false
		m.uv1_scale = Vector3.ONE
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m


static func unshaded(col: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "u" + col.to_html() + str(emission)
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	if emission > 0:
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
	_cache[key] = m
	return m


static var _screen_shader: Shader

## Pantalla emisiva. Las texturas de SubViewport llegan en sRGB "crudo", así que
## se convierten a lineal en el shader (si no, se ven lavadas/sin contraste).
static func screen(t: Texture2D, energy := 1.0) -> ShaderMaterial:
	if _screen_shader == null:
		_screen_shader = Shader.new()
		_screen_shader.code = """shader_type spatial;
uniform sampler2D tex : filter_linear, repeat_disable;
uniform float energy = 1.0;
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	c = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
	ALBEDO = vec3(0.004);
	ROUGHNESS = 0.42;
	SPECULAR = 0.3;
	EMISSION = c * energy;
}"""
	var m := ShaderMaterial.new()
	m.shader = _screen_shader
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("energy", energy)
	return m


static func glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.88, 0.95, 0.12)
	m.roughness = 0.02
	m.metallic = 0.2
	m.metallic_specular = 1.0
	_cache["glass"] = m
	return m


## Contorno tipo cartoon (como el BackSide negro del original).
static func outline() -> ShaderMaterial:
	if _outline == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_front;
uniform float grow = 0.012;
void vertex(){ VERTEX += NORMAL * grow; }
void fragment(){ ALBEDO = vec3(0.07, 0.05, 0.09); }"""
		_outline = ShaderMaterial.new()
		_outline.shader = sh
	return _outline


static func skin(col: Color) -> StandardMaterial3D:
	var key := "skin" + col.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.55
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.25
	_cache[key] = m
	return m
