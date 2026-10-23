shader_type spatial;
// Glass: the corner colour, mostly see-through, brighter where it turns away at the edges, lit only
// by the lights about it (the potion), with a glint where one catches it
render_mode blend_mix, cull_back, depth_draw_never;

uniform float clear = 0.28;

void fragment() {
	float edge = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = COLOR.rgb * (0.9 + edge * 0.6);
	ROUGHNESS = 0.15;
	SPECULAR = 0.8;
	ALPHA = clamp(clear + edge * 0.55, 0.0, 0.95);
}
