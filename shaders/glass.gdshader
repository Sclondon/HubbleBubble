shader_type spatial;
// Glass: the corner colour, mostly see-through, brighter where it turns away at the edges, with a
// glint of the lamp on it
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

uniform float clear = 0.28;

void fragment() {
	float edge = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float glint = smoothstep(0.92, 0.99, dot(normalize(NORMAL), normalize(vec3(-0.4, 0.7, 0.6))));
	ALBEDO = COLOR.rgb * (0.9 + edge * 0.6) + vec3(glint);
	ALPHA = clamp(clear + edge * 0.55 + glint, 0.0, 0.95);
}
