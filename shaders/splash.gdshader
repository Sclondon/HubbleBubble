// One tube of a splash, after Salmon Run 2's: a wall of brew with a ragged crest. UV.x goes once
// round the tube, UV.y from the surface (0) to the top (1). The brew in it streams down the wall.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 white : source_color = vec4(0.95, 1.0, 1.0, 1.0);
uniform vec4 pale : source_color = vec4(0.62, 0.9, 0.98, 1.0);
uniform vec4 blue : source_color = vec4(0.25, 0.62, 0.86, 1.0);
uniform float waves = 7.0;
uniform float phase = 0.0;
uniform float ragged = 0.3;
uniform float spent = 0.0;

float hash(vec2 p) {
	ivec2 c = ivec2(round(p));
	uint h = uint(c.x) * 668265261u ^ (uint(c.y) * 374761393u);
	h ^= h >> 15u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float round_a = UV.x * 6.2832;
	float crest = 1.0 - ragged * (0.5 + 0.35 * sin(round_a * waves + phase) + 0.15 * sin(round_a * waves * 2.7 + phase * 1.9));
	if (UV.y > crest) {
		discard;
	}
	float streak = noise(vec2(UV.x * waves * 3.0, UV.y * 2.2 + TIME * 3.0 + phase));
	if (streak < spent * (1.25 - UV.y * 0.6) - 0.1) {
		discard;
	}
	vec3 col = streak > 0.62 ? white.rgb : (streak > 0.36 ? pale.rgb : blue.rgb);
	col = mix(col, white.rgb, step(crest - 0.1, UV.y));
	ALBEDO = col;
}
