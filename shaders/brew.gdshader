shader_type spatial;
// The brew's surface, after GameCommon's water: deeper and darker in the middle, a ragged rim of foam
// lapping at the iron, faint pale lines, glints where a light catches it, a heave that gets rougher
// and more bubbly with the heat. Real waves on top of that: the heights, slopes and foam of the wave
// pool (scripts/waves.gd) come in `waves`, so the stick leaves a foaming wake and things dropped in
// send rings across; crests catch the light and froth white. Stirred round, it dips into a vortex in
// the middle and climbs the iron (`vortex`, from how fast it's going round).
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
// How fast it's going round (radians a second, either way)
uniform float vortex = 0.0;
// Things in the brew, as Salmon Run 2's water draws round its fish: x, z, how wide it is where it
// meets the surface, and how much it's bobbing (more froth). Each gets a ragged collar of foam with
// the brew pushed up into a little lip round it, and a shadow of it under the surface.
uniform vec4 bodies[10];
uniform int body_count = 0;
uniform float clock = 0.0;
uniform sampler2D waves : filter_linear, repeat_disable;
// As scripts/waves.gd writes them
uniform float height_range = 0.12;
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

// The pot's soft hexagon: how far out its side is at the angle of p, as a share of radius
float pent(vec2 p) {
	return 1.0 + 0.06 * cos(6.0 * atan(p.y, p.x));
}

vec4 wave_at(vec2 p) {
	vec4 t = texture(waves, p / (radius * 1.07 * 2.0) + 0.5);
	vec3 w = t.rgb * 2.0 - 1.0;
	return vec4(w.r * height_range, w.g * slope_range, w.b * slope_range, t.a);
}

// The dip of a stirred brew: down in the middle, up at the iron (no more or less brew overall)
float dip(vec2 p) {
	float r = length(p) / radius;
	return min(vortex * vortex, 30.0) * 0.0022 * (r * r - 0.5);
}

// The swell that's always on it: three trains of waves crossing, taller and quicker with the boil,
// slower in a thick brew. Height in x, slope in yz.
vec3 swell(vec2 p, float t) {
	float slow = mix(1.0, 0.45, thickness);
	float a = 0.012 + 0.03 * boil;
	vec2 d1 = vec2(0.96, 0.28);
	vec2 d2 = vec2(-0.37, 0.93);
	vec2 d3 = vec2(0.66, -0.75);
	float p1 = dot(p, d1) * 9.0 + t * 2.1 * slow;
	float p2 = dot(p, d2) * 13.0 - t * 2.7 * slow;
	float p3 = dot(p, d3) * 19.0 + t * 3.4 * slow;
	float h = a * (sin(p1) + 0.6 * sin(p2) + 0.35 * sin(p3));
	vec2 g = a * (cos(p1) * 9.0 * d1 + 0.6 * cos(p2) * 13.0 * d2 + 0.35 * cos(p3) * 19.0 * d3);
	return vec3(h, g);
}

void vertex() {
	local = VERTEX.xz;
	vec2 p = VERTEX.xz;
	float edge = 1.0 - smoothstep(0.8, 1.0, length(p) / (radius * pent(p)));
	float slow = mix(1.0, 0.4, thickness);
	float h = swell(p, clock).x;
	h += boil * (vnoise(p * 9.0 + vec2(TIME * 2.3, -TIME * 1.9) * slow) - 0.5) * 0.05;
	vec4 w = wave_at(p);
	h += w.x + dip(p);
	VERTEX.y += h * edge;
	heave = h;
}

void fragment() {
	vec2 p = local;
	float r = length(p) / (radius * pent(p));
	float t = clock;
	vec4 w = wave_at(p);
	// The vortex's own slope: out from the middle, steeper toward the iron
	vec2 slope = w.yz + swell(p, t).yz * (1.0 - smoothstep(0.8, 1.0, r)) + (p / radius) * min(vortex * vortex, 30.0) * 0.0044 * 2.0 / radius;
	// The waves' slope bends the surface (and so the light on it)
	vec3 n_local = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(mat3(MODEL_MATRIX) * n_local, 0.0)).xyz);
	vec2 q = p + slope * 0.06;
	float n = vnoise(q * 6.0 + vec2(t * 0.21, 0.0)) * 0.65 + vnoise(q * 13.0 - vec2(0.0, t * 0.29)) * 0.35;
	// Deeper, darker toward the middle
	float depth = clamp(1.0 - r * r, 0.0, 1.0) * 0.85;
	depth = 1.0 - (1.0 - depth) * (1.0 - depth);
	vec3 colour = mix(liquid, deep, depth * 0.8);
	colour *= 1.0 + heave * 5.0 + (n - 0.5) * 0.25;
	// Pale lines wandering, swirled
	float pixel = max(length(fwidth(p)), 0.0001);
	float wide = 0.02 + pixel * 0.3;
	float line = (1.0 - smoothstep(wide * 0.5, wide, net(q * 3.2, t * 0.5))) * lines * 0.3;
	// Foam lapping at the iron, and a broken line standing off it
	float lap = 0.82 + 0.18 * sin(t * 1.7 + n * 5.0);
	float edge = (1.0 - r) * radius;
	float reach = 0.07 * lap * (1.0 - 0.6 * (1.0 - n));
	float white = 1.0 - cut(edge, reach);
	float off = edge / max(0.07 * lap, 0.0001);
	white = max(white, cut(off, 1.6) * (1.0 - cut(off, 2.0)) * cut(n, 0.52) * 0.8);
	// Wave crests froth, the steep sides of a wake catch pale
	float steep = length(slope);
	white = max(white, cut(w.x * (0.6 + 0.8 * n), 0.02) * 0.8);
	white = max(white, cut(steep * (0.5 + n), 0.85) * 0.5);
	// A collar of foam round everything in it, ragged and churning, the brew dark just inside
	float collar = 0.0;
	float under = 0.0;
	for (int i = 0; i < body_count; i++) {
		vec4 b = bodies[i];
		float d = distance(p, b.xy);
		float r = b.z;
		float rag = (vnoise(vec2(atan(p.y - b.y, p.x - b.x) * 3.0 + t * 2.0, t * 1.5 + float(i) * 7.0)) - 0.5) * r * 0.6;
		float band = 0.035 + r * 0.45 + b.w * 0.03;
		collar = max(collar, smoothstep(r - 0.01, r + 0.004, d + rag * 0.4) * (1.0 - smoothstep(r + band * 0.5, r + band, d + rag)));
		under = max(under, 1.0 - smoothstep(r * 0.6, r * 1.05, d));
		// a second, broken ring standing off it
		float off = abs(d - (r + band * 1.9 + sin(t * 3.0 + float(i)) * 0.01));
		collar = max(collar, (1.0 - smoothstep(0.004, 0.012, off)) * step(0.55, n) * 0.8);
	}
	colour *= 1.0 - under * 0.35;
	float collar_white = cut(collar, 0.5);
	white = max(white, collar_white);
	// The wake and splashes leave foam
	white = max(white, cut(w.a * (0.6 + 0.6 * n), 0.45) * 0.85);
	// The boil throws up foam in patches
	white = max(white, cut(vnoise(q * 9.0 + t * 2.0) * boil, 0.55) * 0.7);
	colour = mix(colour, mix(colour, foam, 0.45), line * (1.0 - white));
	colour = mix(colour, foam, white * 0.9);
	// (the collars a clean white, whatever the brew, so they always show)
	colour = mix(colour, mix(foam, vec3(1.0), 0.7), collar_white);
	colour += foam * smoothstep(0.08, 0.6, steep) * 0.18;
	colour = mix(colour, vec3(0.2, 0.15, 0.09) * (0.7 + 0.5 * n), murk);
	// Shaded by its own slopes against a light from above and behind (so the waves always show), and
	// a gleam on the faces of the waves turned to catch it
	float face = dot(n_local, normalize(vec3(-0.25, 1.0, -0.55)));
	float shade = mix(0.45, 1.35, smoothstep(0.82, 1.0, face));
	vec3 lv = normalize((VIEW_MATRIX * vec4(normalize(vec3(-0.2, 1.0, -0.9)), 0.0)).xyz);
	float gleam = pow(max(dot(reflect(-VIEW, NORMAL), lv), 0.0), 28.0) * (1.0 - murk) * (1.0 - white);
	colour = colour * shade + foam * gleam * 0.55;
	ALBEDO = colour;
	EMISSION = vec3(0.35) * collar_white + (mix(liquid, foam, white * 0.5) * (glow * (0.7 + 0.3 * n) + boil * 0.15) * (1.0 - murk)) * shade + foam * gleam * glow * 0.6 + vec3(1.0, 0.95, 0.8) * flash * 0.35;
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
