shader_type spatial;
// One tongue of the fire under the pot, after the "simple fire shader" breakdown on realtimevfx: a
// plain card standing up and turned to the camera; its shape is all noise. The same fractal noise is
// read twice at different sizes and speeds streaming upward and multiplied, cut by a teardrop mask,
// given a ragged border by a third read pushed through a smoothstep, and the whole card waved side
// to side, more toward the top. What's left is cut into three flat tones (a pale core, orange, deep
// red at the edge), bright enough to bloom. Each card has its own seed and age (INSTANCE_CUSTOM).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.95, 0.62);
uniform vec3 body : source_color = vec3(1.0, 0.52, 0.1);
uniform vec3 edge : source_color = vec3(0.82, 0.16, 0.04);
// How bright (above 1 blooms)
uniform float hdr = 1.8;
uniform float intensity = 1.0;
uniform float border_threshold = 0.42;
uniform float border_smoothness = 0.1;
uniform float wave_size = 7.0;
uniform float wave_speed = 5.0;
uniform float wave_amount = 0.07;

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

float fbm(vec2 p) {
	return (vnoise(p) * 0.5 + vnoise(p * 2.03 + 7.1) * 0.25 + vnoise(p * 4.07 + 3.3) * 0.125 + vnoise(p * 8.11 + 1.9) * 0.0625) / 0.9375;
}

void vertex() {
	// Stood upright and turned round to face the camera
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
	float t = TIME + seed * 17.0;
	// Waves: the card swung side to side, more at the top
	uv.x += sin(uv.y * wave_size + t * wave_speed + seed * 6.0) * wave_amount * uv.y;
	float n1 = fbm(uv * vec2(3.0, 2.0) + vec2(seed * 10.0, -t * 1.5));
	float n2 = fbm(uv * vec2(5.0, 3.4) + vec2(-seed * 7.0, -t * 2.4));
	float n = n1 * n2 * 2.2;
	// A teardrop: wide and round at the foot, drawn up to a point
	float w = mix(0.46, 0.05, pow(uv.y, 0.75));
	float side = 1.0 - smoothstep(w * 0.55, w, abs(uv.x - 0.5));
	float foot = smoothstep(0.0, 0.14, uv.y);
	float mask = side * foot * (1.0 - uv.y * 0.85);
	float body_k = clamp(n * mask * 2.4 * intensity, 0.0, 1.0);
	// The border: a third read of the noise, sharpened and cut
	float b = fbm(uv * vec2(4.0, 2.6) + vec2(seed * 3.0, -t * 3.1));
	float border = smoothstep(border_threshold - border_smoothness, border_threshold, b * (1.0 - uv.y) * 1.6 + mask * 0.45);
	// Young cards swell, old ones thin and go
	float life = smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(0.6, 1.0, age));
	float a = body_k * border * life;
	vec3 col = edge;
	col = mix(col, body, smoothstep(0.34, 0.38, a));
	col = mix(col, core, smoothstep(0.64, 0.68, a));
	ALBEDO = col * hdr * COLOR.rgb;
	ALPHA = smoothstep(0.1, 0.14, a) * COLOR.a;
}
