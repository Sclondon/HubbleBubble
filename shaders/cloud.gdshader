shader_type spatial;
// A puff of 3D smoke: a ball pushed lumpy by noise that scrolls through it as it rolls upward, soft
// and see-through at its edges (thinning toward the rim as you look at it) and eaten away by more
// scrolling noise as it fades, lit pale on top and shaded underneath. Each puff's colour, and how far
// gone it is in the alpha, come on its instance colour; its seed on INSTANCE_CUSTOM.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

varying vec3 lp;
varying float seed;

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

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	vec3 o = vec3(seed * 31.0, -TIME * 0.6, seed * 17.0);
	float lump = noise3(VERTEX * 2.2 + o) * 0.6 + noise3(VERTEX * 4.5 + o * 1.3) * 0.4;
	VERTEX *= 0.8 + lump * 0.45;
	lp = VERTEX;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = smoothstep(0.05, 0.6, facing);
	vec3 o = vec3(seed * 13.0, -TIME * 0.9, seed * 7.0);
	float n = noise3(lp * 3.0 + o) * 0.65 + noise3(lp * 7.0 + o * 1.7) * 0.35;
	float fade = COLOR.a;
	// Going, it's eaten away from the thin parts first
	float body = smoothstep(1.0 - fade, 1.0 - fade + 0.35, n * 0.6 + rim * 0.55);
	// Pale on top, a shade darker underneath
	float up = clamp(lp.y * 0.8 + 0.5, 0.0, 1.0);
	ALBEDO = COLOR.rgb * (0.72 + 0.38 * up) * (0.9 + 0.2 * n);
	ALPHA = body * rim * 0.6;
}
