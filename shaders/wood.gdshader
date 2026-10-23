shader_type spatial;
// Wood: grain running along the piece (its own Y), lines of darker late-wood wandering with noise,
// the odd knot, a rough bumpy surface from the grain; tinted by the corner colour, lit by the lights.
render_mode cull_back;

uniform vec3 light_wood : source_color = vec3(0.78, 0.55, 0.3);
uniform vec3 dark_wood : source_color = vec3(0.32, 0.18, 0.08);
uniform float grain = 70.0;

varying vec3 lp;

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

float rings(vec3 p) {
	// distance from the heart of the log (along Y), pushed about so the lines wander and stretch
	// grain running along the stick: lines round it that wander a little as they go
	float a = atan(p.z, p.x);
	float r = a * grain / 12.0 + vnoise(vec2(p.y * 3.0, a * 1.5)) * 1.2 + vnoise(vec2(p.y * 0.8, a + 7.0)) * 0.6;
	return fract(r);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float g = rings(lp);
	float line = smoothstep(0.0, 0.25, g) * (1.0 - smoothstep(0.55, 1.0, g));
	float fine = vnoise(vec2(lp.y * 12.0, atan(lp.z, lp.x) * 40.0));
	vec3 c = mix(dark_wood, light_wood, 0.55 + line * 0.3 + fine * 0.15);
	ALBEDO = c * mix(vec3(1.0), COLOR.rgb * 1.6, 0.25);
	// the grain stands up a little
	float e = 0.002;
	float gx = rings(lp + vec3(e, 0.0, 0.0)) - g;
	float gz = rings(lp + vec3(0.0, 0.0, e)) - g;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(mat3(MODEL_MATRIX) * vec3(-gx, 0.0, -gz) * 0.3, 0.0)).xyz);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
