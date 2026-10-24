shader_type spatial;
// The island outside (models/island.glb), in Banjo-Kazooie's look: bright, flat-lit, every surface a
// blurry low-res texture. What each corner is made of comes in its colour's alpha (art/make_models.py):
// 1 plain, 0.9 grass, 0.8 rock, 0.7 water, 0.6 flowers, 0.5 leaves, 0.3 glowing. The textures are
// patterns of light and dark laid over the corner's own colour, sampled from the sides as well as
// from above so cliffs get streaks, not smears. Lit by a made-up sun of its own (the hut's dark
// fog left out), and fading into a blue haze far off.
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec3 sun = vec3(-0.45, 0.75, 0.5);
uniform vec3 haze : source_color = vec3(0.16, 0.26, 0.7);
uniform float texels = 3.0;
// The tree crowns wear this, tiled over them: clumps of leaves (textures/canopy_leafy.png, from
// Hemlock's Tower), dark green showing between
uniform sampler2D leaf_tex : source_color, filter_nearest, repeat_enable;

varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 9.1) * 0.15;
}

// Pixelated, as a low-res texture is
vec2 px(vec2 p) {
	return floor(p * texels) / texels;
}

// Brown cliffs: blotchy and streaked up and down, in a few hard tones
float rock(vec2 h) {
	float f = fbm(vec2(h.x * 0.55, h.y * 0.18)) * 0.6 + fbm(h * 0.3 + 11.0) * 0.4;
	float t = floor(f * 4.0) / 3.0;
	return 0.5 + t * 0.75;
}

// Grass: soft mottled clumps
float grass(vec2 p) {
	float f = fbm(p * 0.7) * 0.7 + vnoise(p * 3.0) * 0.3;
	return 0.72 + f * 0.5;
}

// Leaves: bunched round lumps with dark between
float leaves(vec2 p) {
	float f = vnoise(p * 1.6) * 0.6 + vnoise(p * 3.4 + 2.0) * 0.4;
	return 0.55 + smoothstep(0.3, 0.75, f) * 0.7;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 n = FRONT_FACING ? wn : -wn;
	float kind = COLOR.a;
	vec3 base = COLOR.rgb;
	// from above (x, z) or from the side (along the wall, up)
	vec2 top = px(wp.xz);
	vec2 side = px(abs(n.x) > abs(n.z) ? vec2(wp.z, wp.y) : vec2(wp.x, wp.y));
	float up = smoothstep(0.55, 0.8, abs(n.y));
	vec3 c = base;
	bool lit = true;
	if (kind > 0.95) {
		c = base;
	} else if (kind > 0.85) {
		c = base * mix(grass(side * vec2(1.0, 0.6)), grass(top), up);
	} else if (kind > 0.75) {
		c = base * mix(rock(side), rock(top * 0.8 + 5.0), up * 0.7);
	} else if (kind > 0.65) {
		// water: pale streaks running down a fall, rippling on a pool
		float s = vnoise(vec2(side.x * 3.0, side.y * 0.6 + TIME * 4.0));
		float r = vnoise(top * 1.5 + vec2(TIME * 0.4, TIME * 0.3));
		float streak = mix(smoothstep(0.5, 0.8, s), smoothstep(0.62, 0.8, r), up);
		c = mix(base, vec3(0.9, 0.97, 1.0), streak * 0.8);
		lit = false;
	} else if (kind > 0.55) {
		// flowers: yellow over the grass, with brighter dots
		c = base * grass(top);
		c = mix(c, vec3(1.0, 0.9, 0.3), step(0.82, hash(floor(wp.xz * texels * 1.5))) * 0.8);
	} else if (kind > 0.45) {
		vec2 lp = mix(vec2(abs(n.x) > abs(n.z) ? wp.z : wp.x, wp.y), wp.xz, up);
		vec2 tuv = lp / vec2(2.2, 1.4);
		vec4 t1 = texture(leaf_tex, tuv);
		vec4 t2 = texture(leaf_tex, tuv + vec2(0.5, 0.5));
		vec4 t = t1.a > 0.5 ? t1 : t2;
		c = mix(base * 0.35, t.rgb * 1.5 * mix(vec3(1.0), base * 2.0, 0.35), max(t1.a, t2.a));
	} else {
		c = base * 1.4;
		lit = false;
	}
	if (lit) {
		float l = 0.55 + 0.6 * max(dot(n, normalize(sun)), 0.0) + 0.1 * n.y;
		c *= l;
	}
	float dist = length(wp - CAMERA_POSITION_WORLD);
	c = mix(c, haze, smoothstep(40.0, 160.0, dist) * 0.65);
	ALBEDO = c;
}
