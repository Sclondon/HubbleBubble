shader_type spatial;
// The top of the brew: a disc that swirls, with lighter streaks going round when it is stirred
render_mode unshaded, cull_disabled;

uniform vec3 colour = vec3(0.3, 0.75, 0.3);
uniform float spin = 0.0;
uniform float time_off = 0.0;
uniform float murk = 0.0;

varying vec2 p;

void vertex() {
	p = VERTEX.xz;
}

void fragment() {
	float r = length(p);
	float a = atan(p.y, p.x) + spin - r * 2.4;
	float swirl = sin(a * 3.0 + TIME * 0.6) * 0.5 + 0.5;
	float rings = sin(r * 18.0 - TIME * 2.0) * 0.5 + 0.5;
	vec3 c = colour * (0.75 + 0.35 * swirl) + vec3(0.12) * rings * (1.0 - r);
	c = mix(c, colour * 0.45, smoothstep(0.55, 0.95, r));
	c = mix(c, vec3(0.22, 0.17, 0.1) * (0.8 + 0.3 * swirl), murk);
	ALBEDO = c;
}
