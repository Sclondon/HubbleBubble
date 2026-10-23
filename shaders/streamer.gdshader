shader_type spatial;
// A streamer of steam or smoke, after The Wind Waker's: a thin ribbon, soft only at its very edges,
// fading at both ends. The ribbon itself is built each frame in scripts/streamers.gd; UV.x runs across
// it, UV.y along it, and its colour and fade come on the vertex colour.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float soft = 1.0 - smoothstep(0.55, 1.0, across);
	float ends = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	ALBEDO = COLOR.rgb;
	ALPHA = soft * ends * COLOR.a;
}
