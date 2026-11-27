shader_type spatial;
// Bahía de Panamá: agua verdosa, oleaje de varias escalas, fresnel y destello del sol.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform sampler2D nmap : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 deep : source_color = vec3(0.09, 0.22, 0.24);
uniform vec3 shallow : source_color = vec3(0.2, 0.33, 0.29);
uniform float speed = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * speed;
	float sw = sin(wp.x * 0.045 + t * 0.9) * 0.11 + sin(wp.z * 0.07 - t * 1.2) * 0.08 + sin((wp.x + wp.z) * 0.13 + t * 1.7) * 0.04;
	VERTEX.y += sw;
}

void fragment() {
	float t = TIME * speed;
	vec2 p = wp.xz;
	vec3 n1 = texture(nmap, p * 0.031 + vec2(0.011, 0.006) * t).rgb;
	vec3 n2 = texture(nmap, p * 0.087 + vec2(-0.017, 0.013) * t).rgb;
	vec3 n3 = texture(nmap, p * 0.0071 + vec2(0.002, -0.003) * t).rgb;
	vec3 n = normalize((n1 - 0.5) * 1.0 + (n2 - 0.5) * 0.6 + (n3 - 0.5) * 1.3 + vec3(0.0, 0.0, 0.5));
	float dist = length(VERTEX);
	float far_f = clamp(dist / 900.0, 0.0, 1.0);
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(0.9, 0.35, far_f);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(shallow, deep, clamp(0.35 + n.y * 0.4 + far_f * 0.5, 0.0, 1.0)) * (1.0 - fres * 0.6);
	ROUGHNESS = mix(0.06, 0.12, far_f);
	METALLIC = 0.0;
	SPECULAR = 0.62;
}
