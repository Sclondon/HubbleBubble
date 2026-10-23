shader_type spatial;
// A puff of steam or smoke: a card turned to the camera, a soft ragged cloud cut from noise that
// streams up through it. Colour, and how far gone it is (in the alpha), come on the instance colour.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float soft = 1.0;

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

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

varying float seed;

void vertex() {
	// Turned to face the camera, keeping its size
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	seed = fract(MODEL_MATRIX[3].x * 13.1 + MODEL_MATRIX[3].z * 7.7 + float(INSTANCE_ID) * 0.37);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	float n = vnoise(uv * 3.0 + vec2(seed * 50.0, -TIME * 1.2)) * 0.6 + vnoise(uv * 7.0 + vec2(-seed * 20.0, -TIME * 2.0)) * 0.4;
	float cloud = smoothstep(1.0, 0.25, d + (n - 0.5) * 0.9 * soft);
	ALBEDO = COLOR.rgb * (0.8 + 0.4 * n);
	ALPHA = cloud * COLOR.a;
}
