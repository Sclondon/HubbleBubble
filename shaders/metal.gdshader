shader_type spatial;
// Polished brass (the taps, the cold-water pipe): its own colour (from the model), mirror-smooth and
// fully metal, so the potion's and the fire's light make hard bright highlights on it. The hut is
// nearly black, so there's no room for it to reflect; instead it reflects a made-up one, a warm band
// round the middle and dark above and below, tinted by `glint` (the brew's light), with a bright edge.
render_mode cull_disabled;

uniform vec3 glint : source_color = vec3(1.0, 0.8, 0.5);
uniform float reflect_strength = 0.35;

void fragment() {
	vec3 base = COLOR.rgb;
	ALBEDO = base;
	METALLIC = 1.0;
	ROUGHNESS = 0.22;
	SPECULAR = 0.8;
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	float band = exp(-r.y * r.y * 18.0) * 0.8 + smoothstep(0.6, 1.0, r.y) * 0.25;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = base * glint * (band + edge * 0.8) * reflect_strength;
}
