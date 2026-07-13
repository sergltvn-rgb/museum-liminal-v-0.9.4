shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

// Force-field glass for the Anomalous Core containment dome.
// damage = 0.0 -> intact museum glass (subtle refraction, calm rim glow).
// damage = 1.0 -> breached field (cracks, strobing, heavy aberration).
// GameManager drives "damage" and "anomaly_color" at runtime.

uniform vec4 glass_tint : source_color = vec4(0.75, 0.88, 0.92, 1.0);
uniform vec4 anomaly_color : source_color = vec4(0.45, 0.85, 0.95, 1.0);
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float refraction_strength : hint_range(0.0, 0.3) = 0.06;
uniform float aberration : hint_range(0.0, 0.03) = 0.007;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Cheap procedural noise -- no textures needed, fits the PS1 look.
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
	// The damaged field trembles and bulges slightly.
	VERTEX += NORMAL * sin(TIME * 14.0 + VERTEX.y * 9.0) * 0.006 * damage;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);

	// Screen-space refraction: base curvature plus damage wobble.
	vec2 wobble = vec2(
		noise2(v_local.xy * 6.0 + TIME * 2.0),
		noise2(v_local.zy * 6.0 - TIME * 1.7)) - 0.5;
	vec2 offset = NORMAL.xy * (refraction_strength * (0.35 + fresnel))
		+ wobble * 0.03 * damage;
	vec2 uv = SCREEN_UV - offset;

	// Chromatic aberration: split RGB samples, wider when breached.
	float ab = aberration * (1.0 + 2.5 * damage) * (0.4 + fresnel);
	vec3 seen;
	seen.r = texture(screen_texture, uv + vec2(ab, 0.0)).r;
	seen.g = texture(screen_texture, uv).g;
	seen.b = texture(screen_texture, uv - vec2(ab, 0.0)).b;

	// Crack web fades in with damage.
	float web = noise2(v_local.xz * 14.0) * noise2(v_local.yx * 17.0 + 5.0);
	float cracks = smoothstep(0.68, 0.72, web) * damage;

	// Flicker: slow shimmer when intact, hard strobing when breached.
	float calm = 0.92 + 0.08 * sin(TIME * 1.5 + v_local.y * 3.0);
	float strobe = 0.45 + 0.55 * step(0.35,
		fract(TIME * 7.0 + noise2(vec2(TIME * 3.0, v_local.y * 2.0))));
	float flicker = mix(calm, strobe, damage);

	ALBEDO = seen * mix(glass_tint.rgb, anomaly_color.rgb, 0.25 * damage);
	ROUGHNESS = 0.06 + 0.25 * cracks;
	SPECULAR = 0.6;
	EMISSION = anomaly_color.rgb
		* (fresnel * (0.25 + 2.2 * damage) + cracks * 1.6) * flicker;
	ALPHA = clamp(0.88 + 0.12 * fresnel - 0.25 * damage * (1.0 - flicker),
		0.2, 1.0);
}
