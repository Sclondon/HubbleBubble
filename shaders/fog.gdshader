shader_type spatial;
// A bank of fog hanging in the hut: a big soft card turned to the camera, a slow billow of noise
// rolling through it, thin and see-through. It is lit by the lights about it (the potion, the fire),
// so it glows in their colours where they reach and sinks into the dark where they do not.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert, specular_disabled;

uniform float density = 0.35;

varying float seed;

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

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2] * sx, vec4(centre, 1.0));
	seed = fract(centre.x * 3.7 + centre.y * 1.3 + centre.z * 5.1);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME * 0.05;
	float n = vnoise(uv * 1.6 + vec2(t + seed * 9.0, -t * 0.6)) * 0.6 + vnoise(uv * 3.4 + vec2(-t * 1.4, t + seed * 4.0)) * 0.4;
	float soft = 1.0 - smoothstep(0.2, 1.0, length(uv));
	// (lit as if it faced the camera)
	NORMAL = vec3(0.0, 0.0, 1.0);
	ALBEDO = vec3(0.8, 0.8, 0.85);
	ALPHA = clamp(soft * smoothstep(0.3, 0.8, n) * density, 0.0, 1.0);
	ROUGHNESS = 1.0;
}
