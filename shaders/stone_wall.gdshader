shader_type spatial;
// The hut's round wall: dark bluish stones in uneven courses, each a rough rounded lump standing
// proud of deep mortar. The stones are a height field worked out here (which course, which stone,
// how far to its edge, a rough grain over it); its slope bends the normal, so the lights (the fire,
// the potion's coloured spot) rake across the lumps and the mortar lines fall into shadow. UV is
// (metres round the wall, metres up).
render_mode cull_disabled;

uniform vec3 stone : source_color = vec3(0.17, 0.2, 0.32);
uniform vec3 stone_dark : source_color = vec3(0.08, 0.09, 0.16);
uniform vec3 mortar : source_color = vec3(0.05, 0.05, 0.09);
uniform float course = 0.42;
uniform float bump = 1.0;

float hash(vec2 p) {
	ivec2 c = ivec2(floor(p));
	uint h = uint(c.x) * 668265261u ^ (uint(c.y) * 374761393u);
	h ^= h >> 15u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// x: how high the wall stands here (0 in the mortar, up to 1 on a stone's crown), y: which stone
vec2 stones(vec2 uv) {
	float row = floor(uv.y / course);
	float v = fract(uv.y / course);
	// each course has its own stone length and offset
	float len = 0.55 + 0.35 * hash(vec2(row, 7.0));
	float u = uv.x / len + hash(vec2(row, 3.0)) * 3.0;
	float col = floor(u);
	float w = 0.75 + 0.5 * hash(vec2(col, row + 31.0));
	float s = fract(u);
	// distance to the stone's edge, in metres, roughened so the edges aren't straight
	float rag = (vnoise(uv * 9.0) - 0.5) * 0.05;
	float dx = min(s, 1.0 - s) * len;
	float dy = min(v, 1.0 - v) * course;
	float d = min(dx, dy) + rag;
	float crown = smoothstep(0.0, 0.09, d - 0.02);
	float grain = vnoise(uv * 22.0) * 0.5 + vnoise(uv * 55.0) * 0.25;
	return vec2(crown * (0.75 + 0.25 * grain) + grain * 0.12 * crown, hash(vec2(col, row)));
}

void fragment() {
	vec2 uv = UV;
	vec2 st = stones(uv);
	float e = 0.008;
	float hx = stones(uv + vec2(e, 0.0)).x - st.x;
	float hy = stones(uv + vec2(0.0, e)).x - st.x;
	NORMAL_MAP = normalize(vec3(-hx / e * 0.06 * bump, -hy / e * 0.06 * bump, 1.0)) * 0.5 + 0.5;
	float shade = st.y;
	vec3 c = mix(stone, stone_dark, shade * 0.7 + (1.0 - st.x) * 0.3);
	c *= 0.85 + 0.3 * vnoise(uv * 3.0 + shade * 10.0);
	c = mix(mortar, c, smoothstep(0.05, 0.35, st.x));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
