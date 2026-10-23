shader_type spatial;
// The brew's surface, after GameCommon's water: deeper and darker in the middle, a ragged rim of foam
// lapping at the iron, pale lines wandering over it and swirling round with the stick, glints where
// a light catches it, a slow heave (faster and rougher with the heat). Real waves on top of that:
// the heights and slopes of the wave pool (scripts/waves.gd) come in `waves`, so the stick leaves a
// wake and things dropped in send rings across; crests catch the light and froth white.
// Colours and the rest come from a PotionLook.
render_mode cull_disabled, specular_disabled;

uniform vec3 liquid : source_color = vec3(0.3, 0.65, 0.55);
uniform vec3 deep : source_color = vec3(0.08, 0.22, 0.2);
uniform vec3 foam : source_color = vec3(0.85, 1.0, 0.92);
uniform float glow = 0.15;
uniform float lines = 0.45;
uniform float glints = 1.5;
uniform float thickness = 0.3;
uniform float swirl = 0.4;
uniform float radius = 0.8;
uniform float spin = 0.0;
uniform float boil = 0.0;
uniform float murk = 0.0;
uniform float flash = 0.0;
uniform float clock = 0.0;
uniform sampler2D waves : filter_linear, repeat_disable;
// As scripts/waves.gd writes them
uniform float height_range = 0.06;
uniform float slope_range = 1.5;

varying vec2 local;
varying float heave;
varying float spark;

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

float net(vec2 p, float t) {
	vec2 pull = vec2(vnoise(p * 0.5 + vec2(t * 0.11, 3.0)), vnoise(p * 0.5 + vec2(9.0, -t * 0.09))) - 0.5;
	vec2 w = p + pull * 1.6;
	float a = abs(vnoise(w + vec2(0.0, t * 0.17)) - 0.5);
	float b = abs(vnoise(w * 1.31 + vec2(17.0 - t * 0.13, 5.0)) - 0.5);
	return min(a, b);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

// Turns a point round the middle, by more nearer the middle (so it swirls)
vec2 swirled(vec2 p, float amount) {
	float r = length(p) / radius;
	float a = amount * (1.2 - r);
	float c = cos(a);
	float s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

vec3 wave_at(vec2 p) {
	vec3 w = texture(waves, p / (radius * 2.0) + 0.5).rgb * 2.0 - 1.0;
	return vec3(w.r * height_range, w.g * slope_range, w.b * slope_range);
}

void vertex() {
	local = VERTEX.xz;
	vec2 p = VERTEX.xz;
	float edge = 1.0 - smoothstep(0.75, 1.0, length(p) / radius);
	float slow = mix(1.0, 0.4, thickness);
	float h = sin(p.x * 5.0 + TIME * 1.3 * slow) * sin(p.y * 4.3 - TIME * 1.1 * slow) * 0.008;
	h += boil * (vnoise(p * 7.0 + vec2(TIME * 1.7, -TIME * 1.3) * slow) - 0.5) * 0.05;
	vec3 w = wave_at(p);
	h += w.x;
	VERTEX.y += h * edge;
	heave = h;
}

void fragment() {
	vec2 p = local;
	float r = length(p) / radius;
	float t = clock;
	vec3 w = wave_at(p);
	vec2 slope = w.yz;
	// The waves' slope bends the surface (and so the light on it)
	vec3 n_local = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(mat3(MODEL_MATRIX) * n_local, 0.0)).xyz);
	vec2 q = swirled(p, spin * 0.8 + t * swirl) + slope * 0.04;
	float n = vnoise(q * 6.0 + vec2(t * 0.21, 0.0)) * 0.65 + vnoise(q * 13.0 - vec2(0.0, t * 0.29)) * 0.35;
	// Deeper, darker toward the middle
	float depth = clamp(1.0 - r * r, 0.0, 1.0) * 0.85;
	depth = 1.0 - (1.0 - depth) * (1.0 - depth);
	vec3 colour = mix(liquid, deep, depth * 0.8);
	colour *= 1.0 + heave * 5.0 + (n - 0.5) * 0.25;
	// Pale lines wandering, swirled
	float pixel = max(length(fwidth(p)), 0.0001);
	float wide = 0.02 + pixel * 0.3;
	float line = (1.0 - smoothstep(wide * 0.5, wide, net(q * 3.2, t * 1.3))) * lines;
	// Foam lapping at the iron, and a broken line standing off it
	float lap = 0.82 + 0.18 * sin(t * 1.7 + n * 5.0);
	float edge = (1.0 - r) * radius;
	float reach = 0.07 * lap * (1.0 - 0.6 * (1.0 - n));
	float white = 1.0 - cut(edge, reach);
	float off = edge / max(0.07 * lap, 0.0001);
	white = max(white, cut(off, 1.6) * (1.0 - cut(off, 2.0)) * cut(n, 0.52) * 0.8);
	// Wave crests froth, the steep sides of a wake catch pale
	float steep = length(slope);
	white = max(white, cut(w.x * (0.6 + 0.8 * n), 0.012) * 0.9);
	white = max(white, cut(steep * (0.5 + n), 0.55) * 0.6);
	// The boil throws up foam in patches
	white = max(white, cut(vnoise(q * 9.0 + t * 2.0) * boil, 0.55) * 0.7);
	colour = mix(colour, mix(colour, foam, 0.45), line * (1.0 - white));
	colour = mix(colour, foam, white * 0.9);
	colour += foam * smoothstep(0.08, 0.6, steep) * 0.18;
	colour = mix(colour, vec3(0.2, 0.15, 0.09) * (0.7 + 0.5 * n), murk);
	ALBEDO = colour;
	EMISSION = mix(liquid, foam, white * 0.5) * (glow * (0.7 + 0.3 * n) + boil * 0.15) * (1.0 - murk) + vec3(1.0, 0.95, 0.8) * flash * 0.35;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec2 g = q / 0.05;
	spark = vnoise(g * vec2(0.55, 1.0) + vec2(t * 0.9, t * 0.35)) * vnoise(g * vec2(1.0, 0.6) * 1.37 - vec2(t * 0.6, t * 0.8) + 23.0);
	spark = max(spark, smoothstep(0.15, 0.7, steep) * 0.6);
	spark *= (1.0 - white) * (1.0 - murk);
}

void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	// (nothing from under the surface: the fire is below it, behind the iron)
	float above = smoothstep(-0.15, 0.25, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += (0.3 + 0.7 * facing) * above * ATTENUATION * LIGHT_COLOR / PI;
	float aim = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 16.0);
	float flick = smoothstep(0.45, 0.55, spark * (0.25 + aim)) * smoothstep(0.05, 0.3, aim);
	SPECULAR_LIGHT += (flick * glints + aim * 0.25) * above * ATTENUATION * LIGHT_COLOR / PI;
}
