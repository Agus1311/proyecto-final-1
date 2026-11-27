shader_type spatial;
// Fachadas de rascacielos (muro cortina, balcones y franjas) generadas en espacio local:
// cada edificio recibe color, semilla y estilo por instancia. Ventanas encendidas al atardecer.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

instance uniform vec4 tint : source_color = vec4(0.45, 0.62, 0.7, 1.0);
instance uniform vec4 frame : source_color = vec4(0.82, 0.83, 0.84, 1.0);
instance uniform float seed = 0.0;
instance uniform float style = 0.0;      // 0 muro cortina, 1 balcones, 2 franjas horizontales, 3 concreto
uniform float lit : hint_range(0.0, 1.0) = 0.0;
uniform float floor_h = 3.1;
uniform float bay = 1.6;
uniform sampler2D concrete : source_color, filter_linear_mipmap, repeat_enable;

varying vec3 mp;
varying vec3 mn;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453); }

void vertex() {
	mp = VERTEX;
	mn = NORMAL;
}

void fragment() {
	vec3 conc = texture(concrete, mp.xz * 0.2 + mp.yy * 0.2).rgb;
	if (abs(mn.y) > 0.6) {
		ALBEDO = vec3(0.55, 0.55, 0.53) * conc * 1.3;
		ROUGHNESS = 0.9;
	} else {
		vec2 f = abs(mn.x) > abs(mn.z) ? vec2(mp.z, mp.y) : vec2(mp.x, mp.y);
		float fy = f.y / floor_h;
		float fl = floor(fy);
		float fr = fract(fy);
		float fx = f.x / bay;
		float bi = floor(fx);
		float br = fract(fx);
		float wfx = fwidth(fx), wfy = fwidth(fy);
		float h = h21(vec2(bi, fl));
		float h2 = h21(vec2(floor(bi / 3.0), fl + 91.0));
		float slab_t = style > 0.5 && style < 1.5 ? 0.22 : (style > 1.5 ? 0.3 : 0.08);
		float mull_t = style > 2.5 ? 0.35 : 0.05;
		float slab = 1.0 - smoothstep(slab_t - wfy, slab_t + wfy, fr);
		float mull = 1.0 - smoothstep(mull_t - wfx, mull_t + wfx, min(br, 1.0 - br) * 2.0);
		float solid = max(slab, mull);
		if (fl < 1.0) { solid = mull * 0.6; }
		// interior detrás del vidrio: cortinas, persianas y luces
		float room = h2;
		float blinds = smoothstep(0.4, 0.45, fract(fr * 9.0)) * step(0.82, room);
		vec3 inside = vec3(0.045, 0.05, 0.055) + vec3(0.05, 0.04, 0.03) * room + blinds * 0.03;
		float on = step(1.0 - lit * 0.38, h) * lit;
		if (fl < 1.0) { on = lit * 0.9 + 0.1; }
		vec3 glass = mix(tint.rgb * 0.22, inside, 0.3 + lit * 0.3);
		vec3 framec = style > 2.5 ? frame.rgb * conc * 1.15 : frame.rgb;
		// sombra bajo los balcones
		float under = style > 0.5 && style < 1.5 ? smoothstep(slab_t + 0.12, slab_t, fr) * (1.0 - slab) : 0.0;
		ALBEDO = mix(glass, framec, solid) * (1.0 - under * 0.5);
		ROUGHNESS = mix(0.03 + h * 0.035, style > 2.5 ? 0.85 : 0.45, solid);
		METALLIC = mix(0.6, 0.0, solid);
		SPECULAR = mix(0.85, 0.5, solid);
		vec3 warm = mix(vec3(1.0, 0.78, 0.45), vec3(0.85, 0.9, 1.0), step(0.75, h));
		EMISSION = warm * on * (1.0 - solid) * (0.35 + h2 * 0.7) * (1.0 - blinds * 0.5);
	}
}
