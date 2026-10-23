shader_type spatial;
// A shape of smoke popping out of the brew: a heart, a skull and crossbones, a star, a moon, a ghost,
// a spiral. Each is a distance field (a shape worked out from sums and cuts of circles, boxes and
// lines) on a card turned to the camera; noise scrolling up through it roughens and puffs out its
// edge so it reads as smoke, a pale rim and a softer middle, and as it ages it billows out, drifts
// apart and is eaten away from the thin parts first. INSTANCE_CUSTOM: which shape, its seed, its age
// (0 to 1); the instance colour is its colour and strength.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

varying float shape;
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
	return vnoise(p) * 0.5 + vnoise(p * 2.03 + 5.1) * 0.3 + vnoise(p * 4.1 + 9.7) * 0.2;
}

// --- the shapes (negative inside) ---

float circle(vec2 p, float r) { return length(p) - r; }

float box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float segment(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

float heart(vec2 p) {
	// (Inigo Quilez's heart)
	p.y += 0.55;
	p *= 1.35;
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		return (sqrt(dot(p - vec2(0.25, 0.75), p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0) / 1.35;
	}
	vec2 a = p - vec2(0.0, 1.0);
	vec2 b = p - 0.5 * max(p.x + p.y, 0.0);
	return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y) / 1.35;
}

float skull(vec2 p) {
	// Crossbones behind
	float bones = min(segment(p, vec2(-0.62, -0.62), vec2(0.62, 0.42), 0.07), segment(p, vec2(0.62, -0.62), vec2(-0.62, 0.42), 0.07));
	for (int i = 0; i < 4; i++) {
		vec2 e = vec2(i % 2 == 0 ? -0.62 : 0.62, i < 2 ? -0.62 : 0.42);
		vec2 o = normalize(e) * 0.06;
		bones = min(bones, min(circle(p - e - o.yx, 0.09), circle(p - e + o.yx, 0.09)));
	}
	// The head and its jaw
	float head = min(circle(p - vec2(0.0, 0.12), 0.44), box(p - vec2(0.0, -0.3), vec2(0.24, 0.16)) - 0.04);
	// Eyes, nose, teeth cut out
	float holes = min(circle(p - vec2(-0.17, 0.08), 0.12), circle(p - vec2(0.17, 0.08), 0.12));
	holes = min(holes, max(abs(p.x) * 1.6 + (p.y + 0.12) - 0.08, -(p.y + 0.16)));
	for (int i = -1; i <= 1; i++) {
		holes = min(holes, box(p - vec2(float(i) * 0.1 + 0.05, -0.4), vec2(0.012, 0.07)));
	}
	head = max(head, -holes);
	// The bones show only outside the head
	return min(head, max(bones, -(circle(p - vec2(0.0, 0.08), 0.5))));
}

float star(vec2 p) {
	// A five-pointed star
	float r = 0.62;
	float rf = 0.45;
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

float moon(vec2 p) {
	return max(circle(p, 0.55), -circle(p - vec2(0.26, 0.14), 0.47));
}

float ghost(vec2 p) {
	float wave = sin(p.x * 14.0 + age * 12.0) * 0.05;
	float body = min(circle(p - vec2(0.0, 0.12), 0.42), box(p - vec2(0.0, -0.2), vec2(0.42, 0.32)));
	body = max(body, -(p.y + 0.5 + wave));
	float eyes = min(circle(p - vec2(-0.15, 0.16), 0.08), circle(p - vec2(0.15, 0.16), 0.08));
	float mouth = circle(p - vec2(0.0, -0.05), 0.07);
	return max(body, -min(eyes, mouth));
}

float spiral(vec2 p) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float turns = (r - 0.05 - (a + PI) / TAU * 0.16) / 0.16;
	float d = abs(fract(turns + 0.5) - 0.5) * 0.16 - 0.035;
	return max(d, r - 0.62);
}

float shape_at(vec2 p) {
	int s = int(round(shape));
	if (s == 1) return heart(p);
	if (s == 2) return skull(p);
	if (s == 3) return star(p);
	if (s == 4) return moon(p);
	if (s == 5) return ghost(p);
	return spiral(p);
}

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	shape = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
	age = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, -2.0);
	float t = TIME * 0.6 + seed * 20.0;
	// Smoke rolling up through it pushes the shape about, more as it ages
	vec2 warp = vec2(fbm(p * 2.5 + vec2(seed * 9.0, -t)), fbm(p * 2.5 + vec2(-t, seed * 4.0))) - 0.5;
	p += warp * (0.06 + age * 0.3);
	float d = shape_at(p);
	float n = fbm(p * 4.0 + vec2(seed * 3.0, -t * 1.6));
	// A soft puffy edge, roughened by the noise
	float soft = 0.05 + age * 0.12;
	float inside = 1.0 - smoothstep(-soft, soft, d + (n - 0.5) * (0.08 + age * 0.2));
	// Pale at the rim, softer in the middle
	float rim = smoothstep(-0.16, -0.02, d);
	// Eaten away as it goes
	float eaten = smoothstep(age * 1.1 - 0.15, age * 1.1 + 0.15, n + 0.25);
	float life = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.55, 1.0, age));
	ALBEDO = COLOR.rgb * (0.85 + 0.35 * rim + 0.15 * n);
	ALPHA = inside * eaten * life * (0.75 + 0.25 * rim) * COLOR.a;
}
