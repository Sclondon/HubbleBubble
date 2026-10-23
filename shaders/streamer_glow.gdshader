shader_type spatial;
// A glowing tendril (shaders/streamer.gdshader, added over what is behind so it shines): a ribbon,
// fading at both ends. The ribbon itself is built each frame in scripts/streamers.gd; UV.x runs across
// it, UV.y along it, and its colour and fade come on the vertex colour.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float soft = 1.0 - smoothstep(0.25, 1.0, across);
	float ends = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	// Premultiplied with no alpha of its own: it adds light, and lays over the picture the same way
	ALBEDO = COLOR.rgb * soft * ends * COLOR.a;
	ALPHA = 0.0;
}
