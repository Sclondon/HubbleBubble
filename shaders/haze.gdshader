shader_type spatial;
// The glow standing up off a potion: big soft cards turned to the camera, added over what's behind,
// each a cloud of the potion's colour cut from slow noise that rolls upward, thinning at its edges
// and its top. Its colour comes on the material (from the PotionLook); each card's seed and age on
// INSTANCE_CUSTOM, how strong on the instance colour's alpha.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.3, 1.0, 0.8);
uniform float strength = 1.0;

varying float seed;
varying float age;

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

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 to = INV_VIEW_MATRIX[3].xyz - centre;
	to.y = 0.0;
	to = normalize(to + vec3(0.0001, 0.0, 0.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sx, 0.0), vec4(0.0, sy, 0.0, 0.0), vec4(to * sx, 0.0), vec4(centre, 1.0));
	seed = INSTANCE_CUSTOM.x;
	age = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME * 0.35 + seed * 9.0;
	vec2 w = vec2(uv.x + sin(uv.y * 3.0 + t * 2.0 + seed * 5.0) * 0.08 * uv.y, uv.y);
	float n = vnoise(w * vec2(3.0, 2.0) + vec2(seed * 7.0, -t)) * 0.6 + vnoise(w * vec2(6.0, 4.0) + vec2(-seed * 3.0, -t * 1.7)) * 0.4;
	// Wide at the foot (the pot's mouth), thinning as it rises
	float wide = mix(0.48, 0.3, uv.y);
	float side = 1.0 - smoothstep(wide * 0.1, wide, length(vec2(w.x - 0.5, (uv.y - 0.45) * 0.6)));
	float shape = side * smoothstep(0.0, 0.12, uv.y) * (1.0 - smoothstep(0.35, 1.0, uv.y));
	float life = smoothstep(0.0, 0.25, age) * (1.0 - smoothstep(0.6, 1.0, age));
	float a = shape * smoothstep(0.34, 0.8, n + shape * 0.2) * life;
	ALBEDO = tint * a * strength * COLOR.a;
	ALPHA = 1.0;
}
