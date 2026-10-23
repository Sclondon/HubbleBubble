shader_type spatial;
// A little ring wave where a drop fell back into the brew: a thin pale ring on a flat card lying on
// the surface, spreading out, thinning and fading (a second fainter ring inside it, a moment behind).
// How far gone it is comes in the instance colour's alpha.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	float k = 1.0 - COLOR.a;
	float d = length(UV * 2.0 - 1.0);
	float r1 = 0.3 + 0.65 * k;
	float r2 = 0.15 + 0.5 * k;
	float w = 0.07 * (1.0 - 0.5 * k);
	float ring = 1.0 - smoothstep(0.0, w, abs(d - r1));
	ring = max(ring, (1.0 - smoothstep(0.0, w * 0.8, abs(d - r2))) * 0.5);
	ALBEDO = COLOR.rgb;
	ALPHA = ring * (1.0 - k) * (1.0 - k) * 0.85;
}
