shader_type spatial;
// One puff of flame, the way stylized game fires are built (Breath of the Wild's, the campfire
// breakdowns on realtimevfx and 80.lv): a soft card turned to the camera, its shape a round-bottomed
// gradient that's eaten away by noise as it ages (alpha erosion), the noise turning and streaming up
// so no two look alike. What survives the erosion is coloured by how much of it survives: a white-hot
// heart, yellow, orange, a deep red rim. Added over what's behind, so it glows. INSTANCE_CUSTOM: seed,
// age (0 to 1); the instance colour's alpha is how strong.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float hdr = 1.4;

varying float seed;
varying float age;

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

float fbm(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 9.1) * 0.2;
}

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2] * sx, vec4(centre, 1.0));
	seed = INSTANCE_CUSTOM.x;
	age = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv.y = -uv.y;
	// a teardrop of soft gradient: round at the foot, drawn up to a tip
	vec2 q = uv;
	q.x *= 1.0 + max(q.y, 0.0) * 1.2;
	float shape = 1.0 - smoothstep(0.0, 1.0, length(q * vec2(1.0, 0.85) + vec2(0.0, 0.15)));
	// noise turning and streaming up through it
	float a = seed * 6.28 + TIME * 0.6;
	mat2 rot = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	float n = fbm(rot * uv * 2.2 + vec2(seed * 11.0, -TIME * 2.4));
	// eaten away as it ages
	float v = shape * (0.55 + 0.75 * n) - age * 0.55;
	float glow = smoothstep(0.05, 0.25, v);
	vec3 col = mix(vec3(0.55, 0.06, 0.01), vec3(1.0, 0.38, 0.05), smoothstep(0.1, 0.3, v));
	col = mix(col, vec3(1.0, 0.82, 0.3), smoothstep(0.3, 0.5, v));
	col = mix(col, vec3(1.0, 0.98, 0.85), smoothstep(0.5, 0.7, v));
	float life = smoothstep(0.0, 0.12, age);
	ALBEDO = col * glow * hdr * life * COLOR.a;
}
