shader_type spatial;
// Fire wrapped round the pot: an open band (scripts/pot_fire.gd builds it to hug the pot's belly)
// with an animated texture on it. Two reads of fractal noise stream up it at different sizes and
// speeds, pushed sideways by a third so the tongues waver, and are cut against a gradient that fades
// with height: tall tongues licking up the iron, short ones at the back. The result is cut into flat
// tones (deep red, orange, a pale core near the foot) with hard edges, as the old console fires were.
// The pot hides the back of the band, so the flames read as coming round it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.92, 0.55);
uniform vec3 body : source_color = vec3(1.0, 0.5, 0.08);
uniform vec3 edge : source_color = vec3(0.78, 0.14, 0.03);
uniform float hdr = 1.25;
// How high the tongues reach (0 to 1 of the band), from the bellows
uniform float reach = 0.6;
uniform float clock = 0.0;
// (each ring its own flames)
uniform float seed = 0.0;

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

// (wraps every `period` cells across, so the band has no seam)
float vnoise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 i1 = i + vec2(1.0, 0.0);
	i.x = mod(i.x, period);
	i1.x = mod(i1.x, period);
	return mix(mix(hash(i), hash(i1), f.x), mix(hash(vec2(i.x, i.y + 1.0)), hash(vec2(i1.x, i.y + 1.0)), f.x), f.y);
}

float fbm(vec2 p, float period) {
	return vnoise(p, period) * 0.55 + vnoise(p * 2.0 + vec2(0.0, 3.1), period * 2.0) * 0.3 + vnoise(p * 4.0 + vec2(0.0, 7.7), period * 4.0) * 0.15;
}

void fragment() {
	float t = clock + seed;
	vec2 uv = UV;
	float y = uv.y;
	float around = uv.x * 24.0 + floor(seed * 3.0);
	// Pushed sideways, more toward the top
	float push = (vnoise(vec2(around * 0.5, y * 3.0 - t * 1.4), 12.0) - 0.5) * 1.6 * y;
	float a = fbm(vec2(around + push, y * 4.0 - t * 3.2), 24.0);
	float b = fbm(vec2(around * 1.7 - push, y * 6.5 - t * 4.6), 40.8);
	float n = a * 0.6 + b * 0.4;
	// Taller tongues in some places than others, slowly changing
	float tall = mix(0.55, 1.0, vnoise(vec2(around * 0.25, t * 0.4), 6.0)) * reach;
	float k = n * 1.5 - y / max(tall, 0.05) - 0.05 + 0.25 * (1.0 - smoothstep(0.0, 0.25, y)) * (n - 0.3);
	float foot = smoothstep(0.0, 0.06, y);
	if (k < 0.08 || foot < 0.5) {
		discard;
	}
	vec3 col = edge;
	col = mix(col, body, step(0.22, k));
	col = mix(col, core, step(0.42, k) * (1.0 - smoothstep(0.25, 0.5, y)));
	ALBEDO = col * hdr;
	ALPHA = 1.0;
}
