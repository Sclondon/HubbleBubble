shader_type spatial;
// The top of the brew. Its surface heaves with the heat and rings out in ripples where things land;
// two colours (what's in it now, and the last thing added) swirl through each other, stirred round
// by the stick, with a foamy rim, bright crests, and a glow when it's zapped.
render_mode unshaded, cull_disabled;

uniform vec3 colour = vec3(0.3, 0.75, 0.3);
uniform vec3 colour2 = vec3(0.3, 0.75, 0.3);
uniform float radius = 0.8;
uniform float spin = 0.0;
uniform float murk = 0.0;
uniform float boil = 0.0;
uniform float glow = 0.0;
uniform float now = 0.0;
// Ripples: x, z where it landed, the time it landed, how hard
uniform vec4 ripples[4];

varying vec2 p;
varying float crest;

float hash(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 q) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(q);
		q = q * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

float waves(vec2 at, float t) {
	float w = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 r = ripples[i];
		float age = now - r.z;
		if (age > 0.0 && age < 2.5 && r.w > 0.0) {
			float d = distance(at, r.xy);
			float front = age * 0.9;
			w += r.w * sin(d * 16.0 - age * 10.0) * exp(-age * 1.6) * exp(-abs(d - front) * 4.0);
		}
	}
	// The heat makes it heave and churn
	w += boil * (noise(at * 5.0 + vec2(t * 0.9, -t * 0.7)) - 0.5) * 0.9;
	return w;
}

void vertex() {
	p = VERTEX.xz;
	float edge = 1.0 - smoothstep(0.75, 1.0, length(p) / radius);
	float w = waves(p, TIME) * edge;
	VERTEX.y += w * 0.07;
	crest = w;
}

void fragment() {
	float r = length(p) / radius;
	float a = atan(p.y, p.x) + spin * 0.8 - r * 3.2 + TIME * 0.25;
	vec2 q = vec2(cos(a), sin(a)) * r * 2.6;
	float n = fbm(q * 1.4 + vec2(TIME * 0.15, -TIME * 0.1));
	float streak = smoothstep(0.42, 0.72, n);
	vec3 c = mix(colour, colour2, streak * 0.7);
	c *= 0.72 + 0.55 * fbm(q * 3.1 - TIME * 0.35);
	// Bright crests on the ripples and the boil
	c += vec3(0.3) * smoothstep(0.08, 0.35, crest) + colour * 0.4 * smoothstep(0.05, 0.25, crest);
	c -= vec3(0.12) * smoothstep(0.05, 0.3, -crest);
	// Foam round the rim, darker where it meets the iron
	float foam = smoothstep(0.82, 0.95, r) * (0.6 + 0.4 * noise(vec2(a * 8.0, TIME * 2.0)));
	c = mix(c, colour * 1.5 + vec3(0.15), foam * 0.55);
	c = mix(c, colour * 0.35, smoothstep(0.96, 1.0, r));
	c += mix(colour, vec3(1.0), 0.4) * glow;
	c = mix(c, vec3(0.22, 0.17, 0.1) * (0.8 + 0.4 * n), murk);
	ALBEDO = max(c, vec3(0.0));
}
