shader_type spatial;
// Cast iron: the pot's own colours (on its corners) roughened over with a pitted sandy grain the way
// a casting comes out of the mould, darker in the pits, and scratched about with thin bright scuffs
// where it's been knocked and scraped. The grain and the scratches bend the light (a bump), and it
// has a dull dark sheen, not a polish.
render_mode cull_disabled;

uniform float pitting = 1.0;
uniform float scratches = 1.0;

varying vec3 lp;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Pitted grain: a few sizes of noise, the pits sharp-bottomed
float grain(vec3 p) {
	float n = noise3(p * 18.0) * 0.5 + noise3(p * 45.0) * 0.3 + noise3(p * 110.0) * 0.2;
	return 1.0 - pow(1.0 - n, 2.0);
}

// Thin scratches: short straight scuffs in random directions, in cells over the surface
float scratch(vec3 p) {
	float best = 0.0;
	for (int k = 0; k < 3; k++) {
		vec3 q = p * (5.0 + float(k) * 3.0) + float(k) * 7.31;
		vec3 c = floor(q);
		vec3 f = fract(q) - 0.5;
		float h = hash3(c);
		if (h > 0.55) {
			continue;
		}
		float a = h * 40.0;
		vec3 dir = normalize(vec3(cos(a), sin(a * 1.7), sin(a)));
		float along = dot(f, dir);
		float off = length(f - dir * along);
		float len = 0.25 + 0.2 * hash3(c + 3.0);
		best = max(best, (1.0 - smoothstep(0.004, 0.016, off)) * (1.0 - smoothstep(len - 0.05, len, abs(along))));
	}
	return best;
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float g = grain(lp);
	float s = scratch(lp) * scratches;
	vec3 base = COLOR.rgb;
	vec3 c = base * mix(1.0, 0.55 + 0.6 * g, pitting);
	c = mix(c, base * 1.8 + vec3(0.08), s * 0.6);
	ALBEDO = c;
	// the grain and scratches bend the light
	float e = 0.004;
	float gx = grain(lp + vec3(e, 0.0, 0.0)) - g;
	float gy = grain(lp + vec3(0.0, e, 0.0)) - g;
	float gz = grain(lp + vec3(0.0, 0.0, e)) - g;
	vec3 bump = vec3(gx, gy, gz) * 6.0 * pitting;
	NORMAL = normalize(NORMAL - (VIEW_MATRIX * vec4(mat3(MODEL_MATRIX) * bump, 0.0)).xyz * 0.6);
	ROUGHNESS = mix(0.9, 0.5, s);
	METALLIC = 0.35;
	SPECULAR = 0.3;
}
