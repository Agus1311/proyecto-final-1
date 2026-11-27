shader_type spatial;
// Asfalto PBR + demarcación vial pintada (estilo ATTT): líneas en espacio mundo,
// antialias con fwidth, desgaste, huellas de rodadura y charcos que reflejan el cielo.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rgh : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float tile = 4.0;
uniform bool along_z = false;          // calle transversal: las líneas corren en Z
uniform float wetness : hint_range(0.0, 1.0) = 0.45;
// líneas longitudinales: (posición transversal, ancho, tipo, 0)
// tipo 0 = continua blanca, 1 = segmentada blanca, 2 = continua amarilla, 3 = carril bus (continua ancha)
uniform vec4 lines[12];
uniform int n_lines = 0;
// tramos sin demarcación (intersecciones): (inicio, fin) en la coordenada longitudinal
uniform vec2 gaps[6];
uniform int n_gaps = 0;
// pasos peatonales (cebra): (centro longitudinal, medio ancho, transversal inicio, transversal fin)
uniform vec4 zebra[6];
uniform int n_zebra = 0;
// líneas de pare: (posición longitudinal, transversal inicio, transversal fin, 0)
uniform vec4 stops[8];
uniform int n_stops = 0;
// carriles (centros transversales) para las huellas de los neumáticos
uniform float lanes[8];
uniform int n_lanes = 0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float band(float d, float hw) {
	float w = fwidth(d) * 0.75 + 1e-4;
	return 1.0 - smoothstep(hw - w, hw + w, abs(d));
}

void fragment() {
	vec2 p = wp.xz;
	float L = along_z ? p.y : p.x;   // longitudinal
	float T = along_z ? p.x : p.y;   // transversal
	vec2 uv = p / tile;
	vec3 a = texture(alb, uv).rgb;
	float r = texture(rgh, uv).r;
	vec3 n = texture(nrm, uv).rgb;
	float nz = texture(noise, p * 0.021).r;
	float nz2 = texture(noise, p * 0.13 + vec2(0.37)).r;
	// variación de tono a gran escala (reparaciones y desgaste)
	a *= 0.88 + 0.22 * nz;
	// huellas de rodadura: más oscuras y pulidas
	float track = 0.0;
	for (int i = 0; i < n_lanes; i++) {
		float d = T - lanes[i];
		track = max(track, band(abs(d) - 0.78, 0.32));
	}
	a *= 1.0 - 0.13 * track;
	r = mix(r, r * 0.78, track);
	// pintura
	bool in_gap = false;
	for (int i = 0; i < n_gaps; i++) {
		if (L > gaps[i].x && L < gaps[i].y) { in_gap = true; }
	}
	float paint = 0.0;
	vec3 pcol = vec3(0.86);
	if (!in_gap) {
		for (int i = 0; i < n_lines; i++) {
			vec4 l = lines[i];
			float m = band(T - l.x, l.y * 0.5);
			if (l.z > 0.5 && l.z < 1.5) {
				float ph = fract(L / 12.0);
				m *= band(ph - 0.125, 0.125); // 3 m pintados, 9 m de espacio
			}
			if (m > paint) {
				paint = m;
				pcol = (l.z > 1.5 && l.z < 2.5) ? vec3(0.86, 0.62, 0.08) : vec3(0.88, 0.88, 0.86);
			}
		}
	}
	for (int i = 0; i < n_zebra; i++) {
		vec4 z = zebra[i];
		if (abs(L - z.x) < z.y && T > z.z && T < z.w) {
			float st = band(fract(T / 1.0) - 0.5, 0.28);
			paint = max(paint, st);
			pcol = vec3(0.9);
		}
	}
	for (int i = 0; i < n_stops; i++) {
		vec4 s = stops[i];
		if (T > s.y && T < s.z) {
			float m = band(L - s.x, 0.25);
			if (m > paint) { paint = m; pcol = vec3(0.9); }
		}
	}
	// desgaste de la pintura (más en las huellas)
	float wear = smoothstep(0.35, 0.75, nz2 + track * 0.35);
	paint *= 1.0 - 0.55 * wear;
	a = mix(a, pcol * (0.85 + 0.15 * nz2), paint);
	r = mix(r, 0.6, paint);
	n = mix(n, vec3(0.5, 0.5, 1.0), paint * 0.7);
	// charcos tras el aguacero de la tarde
	float pud = smoothstep(0.66, 0.71, nz * 0.75 + nz2 * 0.3) * wetness;
	float damp = wetness * 0.35 * (1.0 - track);
	a *= 1.0 - 0.38 * pud - 0.12 * damp;
	r = mix(r, 0.05, pud);
	r = mix(r, r * 0.8, damp);
	n = mix(n, vec3(0.5, 0.5, 1.0), pud * 0.92);
	ALBEDO = a;
	ROUGHNESS = r;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.0;
}
