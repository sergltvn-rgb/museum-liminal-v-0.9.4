shader_type canvas_item;
render_mode blend_mix, unshaded;

// Diegetic CRT treatment for the museum's in-world service screens.
// Driven by game/CRTOverlay.gd; every strength is a token in game/UITheme.gd.
//
// Cost is the whole design. This runs over a live 3D feed on the CCTV tablet,
// so: no screen-texture read, no texture lookups at all, no branching, one
// full-screen quad of plain ALU. Real barrel distortion would need a
// screen-texture sample per pixel AND would bend the mini-map's room outlines,
// which are a read-out and have to stay straight -- so the curvature here is
// implied by the way the vignette collapses towards the corners instead.
//
// ACCESSIBILITY: every animated term is multiplied by a uniform the script sets
// to 0.0 when SettingsManager.reduced_flashes is on. With scanline_strength,
// roll_speed and flicker_strength at zero this shader is time-invariant -- it
// literally cannot move. Do not add a term that is not gated the same way.

uniform vec4 phosphor : source_color = vec4(0.2, 0.78, 0.42, 1.0);
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_pitch : hint_range(2.0, 16.0) = 3.0;
uniform float roll_speed : hint_range(0.0, 60.0) = 14.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.30;
uniform float vignette_power : hint_range(0.05, 2.0) = 0.30;
uniform float glow_strength : hint_range(0.0, 0.5) = 0.05;
uniform float flicker_strength : hint_range(0.0, 0.2) = 0.015;

void fragment() {
	// Tube falloff. x*y*(1-x)*(1-y) peaks at 1/16 dead centre and reaches 0 on
	// every edge; being a product of four terms it collapses much faster
	// towards a corner than towards an edge midpoint, which is exactly the
	// read a curved tube gives.
	float tube = UV.x * UV.y * (1.0 - UV.x) * (1.0 - UV.y);
	tube = clamp(pow(16.0 * tube, vignette_power), 0.0, 1.0);

	float dark = (1.0 - tube) * vignette_strength;

	// Scanline pitch is measured in framebuffer pixels, not UV, so the lines
	// keep their spacing when the window is resized instead of stretching into
	// bands.
	dark += (0.5 + 0.5 * cos((FRAGCOORD.y + TIME * roll_speed)
		* TAU / max(scanline_pitch, 1.0))) * scanline_strength;

	// Mains hum on the tube's brightness. Two incommensurate rates so it never
	// settles into a countable strobe, and biased positive so the clamp below
	// cannot swallow half of it and turn a wobble into a pulse.
	dark += (0.5 + 0.3 * sin(TIME * 8.7) + 0.2 * sin(TIME * 21.3))
		* flicker_strength;
	dark = clamp(dark, 0.0, 1.0);

	// Phosphor wash, strongest where the beam is.
	float tint = glow_strength * (0.35 + 0.65 * tube);

	// One mix-blended layer does both jobs: alpha is everything taken away plus
	// everything added, and the source colour is the phosphor weighted against
	// black by how much of that alpha is the wash. Compositing over a
	// background B gives B*(1 - dark - tint) + phosphor*tint.
	float a = clamp(dark + tint, 0.0, 1.0);
	COLOR = vec4(a > 0.0001 ? phosphor.rgb * (tint / a) : vec3(0.0), a);
}
