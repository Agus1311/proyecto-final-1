shader_type sky;
// Cielo tropical: degradado según la hora, disco y halo del sol, y cúmulos
// proyectados en un plano alto (se tiñen de naranja al atardecer).

uniform vec3 top_col : source_color = vec3(0.16, 0.34, 0.74);
uniform vec3 hor_col : source_color = vec3(0.6, 0.74, 0.88);
uniform vec3 gnd_col : source_color = vec3(0.3, 0.34, 0.36);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.86);
uniform float dusk = 0.0;
uniform float cover = 0.48;
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 sd3 = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	float sd = max(dot(d, sd3), 0.0);
	vec3 c = mix(hor_col, top_col, pow(clamp(h, 0.0, 1.0), 0.42));
	// resplandor cálido alrededor del sol (más amplio al atardecer)
	c += sun_col * (pow(sd, 6.0) * mix(0.25, 0.9, dusk) + pow(sd, 48.0) * 0.6);
	c = mix(c, gnd_col, smoothstep(0.0, -0.06, h));
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.08) * 0.22 + vec2(TIME * 0.0012, TIME * 0.0004);
		float n = texture(cloud_noise, uv).r * 0.62 + texture(cloud_noise, uv * 2.9 + 0.3).r * 0.28 + texture(cloud_noise, uv * 8.1 + 0.7).r * 0.1;
		float cl = smoothstep(1.0 - cover, 1.0 - cover + 0.22, n) * smoothstep(0.0, 0.12, h);
		float thick = smoothstep(1.0 - cover + 0.1, 1.0, n);
		vec3 lit = mix(vec3(1.0), sun_col * 1.3 + vec3(0.1, 0.05, 0.1), dusk * 0.85);
		vec3 shade = mix(vec3(0.62, 0.66, 0.72), vec3(0.45, 0.32, 0.42), dusk);
		vec3 cc = mix(lit, shade, thick * 0.7) * (0.85 + 0.6 * pow(sd, 4.0));
		c = mix(c, cc, cl * 0.92);
	}
	// disco solar
	c += sun_col * smoothstep(0.9994, 0.9998, sd) * 22.0 * (1.0 - smoothstep(0.0, -0.02, h));
	COLOR = c;
}
