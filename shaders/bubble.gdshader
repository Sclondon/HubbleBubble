shader_type spatial;
// A bubble swelling on the brew: a thin skin in the brew's colour, clear in the middle and bright at
// the rim, with a glint. Each one's colour (and how far gone, in the alpha) comes on its instance colour.
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 c = COLOR.rgb * (0.7 + rim * 0.9);
	float glint = smoothstep(0.93, 0.99, dot(normalize(NORMAL), normalize(vec3(-0.4, 0.8, 0.5))));
	ALBEDO = c + vec3(glint);
	ALPHA = clamp(0.25 + rim * 0.7 + glint, 0.0, 1.0) * COLOR.a;
}
