shader_type spatial;
// The brew's surface, after GameCommon's water: deeper and darker in the middle, a ragged rim of foam
// lapping at the iron, pale lines wandering over it and swirling round with the stick, glints where
// a light catches it, a slow heave (faster and rougher with the heat) and rings where things land or
// bubbles burst. It shines by its own glow too. Colours and the rest come from a PotionLook.
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
// Rings: x, z, when it began, how strong
uniform vec4 rings[12];

varying vec3 at;
varying float heave;
varying float spark;

// (whole-number hashing, as the water has it: every square of the noise agrees about its corners)
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

float ring_at(vec2 p, out float froth) {
	float slow = mix(1.0, 0.45, thickness);
	float best = 0.0;
	froth = 0.0;
	for (int i = 0; i < 12; i++) {
		vec4 r = rings[i];
		float age = (clock - r.z) * slow;
		if (age < 0.0 || age > 1.6 || r.w <= 0.0) {
			continue;
		}
		float k = age / 1.6;
		float d = distance(p, r.xy);
		float out_at = 0.03 * r.w + 0.42 * age * (1.0 - 0.3 * k);
		float band = (0.018 + 0.012 * min(r.w, 1.5)) * (1.0 - 0.4 * k);
		float fade = pow(1.0 - k, 1.3) * min(r.w * 2.0, 1.0);
		float here = 1.0 - smoothstep(band * 0.5, band, abs(d - out_at));
		best = max(best, here * fade);
		froth = max(froth, (1.0 - smoothstep(0.0, out_at, d)) * (1.0 - smoothstep(0.0, 0.3, age)) * step(0.7, r.w));
	}
	return best;
}

varying vec2 local;

void vertex() {
	local = VERTEX.xz;
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = VERTEX.xz;
	float edge = 1.0 - smoothstep(0.7, 1.0, length(p) / radius);
	float slow = mix(1.0, 0.4, thickness);
	float h = sin(p.x * 5.0 + TIME * 1.3 * slow) * sin(p.y * 4.3 - TIME * 1.1 * slow) * 0.01;
	h += boil * (vnoise(p * 7.0 + vec2(TIME * 1.7, -TIME * 1.3) * slow) - 0.5) * 0.06;
	float froth;
	h += ring_at(p, froth) * 0.025;
	VERTEX.y += h * edge;
	heave = h;
}

void fragment() {
	vec2 p = local;
	float r = length(p) / radius;
	float t = clock;
	vec2 q = swirled(p, spin * 0.8 + t * swirl);
	float n = vnoise(q * 6.0 + vec2(t * 0.21, 0.0)) * 0.65 + vnoise(q * 13.0 - vec2(0.0, t * 0.29)) * 0.35;
	// Deeper, darker toward the middle
	float depth = clamp(1.0 - r * r, 0.0, 1.0) * 0.85;
	depth = 1.0 - (1.0 - depth) * (1.0 - depth);
	vec3 colour = mix(liquid, deep, depth * 0.8);
	colour *= 1.0 + heave * 6.0 + (n - 0.5) * 0.25;
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
	float froth;
	float ring = ring_at(p, froth);
	white = max(white, cut(ring * (0.55 + 0.9 * n), 0.4));
	white = max(white, cut(froth * n, 0.35) * 0.9);
	// The boil throws up foam in patches
	white = max(white, cut(vnoise(q * 9.0 + t * 2.0) * boil, 0.55) * 0.7);
	colour = mix(colour, mix(colour, foam, 0.45), line * (1.0 - white));
	colour = mix(colour, foam, white * 0.9);
	colour = mix(colour, vec3(0.2, 0.15, 0.09) * (0.7 + 0.5 * n), murk);
	ALBEDO = colour;
	EMISSION = mix(liquid, foam, white * 0.5) * (glow * (0.7 + 0.3 * n) + boil * 0.15) * (1.0 - murk) + vec3(1.0, 0.95, 0.8) * flash * 0.35;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec2 g = q / 0.05;
	spark = vnoise(g * vec2(0.55, 1.0) + vec2(t * 0.9, t * 0.35)) * vnoise(g * vec2(1.0, 0.6) * 1.37 - vec2(t * 0.6, t * 0.8) + 23.0);
	spark *= (1.0 - white) * (1.0 - murk);
}

void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += (0.35 + 0.65 * facing) * ATTENUATION * LIGHT_COLOR / PI;
	float aim = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 16.0);
	float flick = smoothstep(0.45, 0.55, spark * (0.25 + aim)) * smoothstep(0.05, 0.3, aim);
	SPECULAR_LIGHT += flick * glints * ATTENUATION * LIGHT_COLOR / PI;
}
