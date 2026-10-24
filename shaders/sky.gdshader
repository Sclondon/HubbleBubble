shader_type spatial;
// The sky over the island, Banjo-Kazooie's dusk over Gruntilda's Lair: deep blue overhead, brighter
// blue down at the horizon, a sickly green glow round the lair (out past the hut's window, -Z), and
// a few stars up high
render_mode unshaded, cull_disabled, fog_disabled;

void fragment() {
	vec3 d = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz) * -1.0;
	float up = clamp(d.y * 1.3 + 0.1, 0.0, 1.0);
	vec3 c = mix(vec3(0.12, 0.28, 0.95), vec3(0.01, 0.02, 0.32), pow(up, 0.6));
	float toward = max(dot(normalize(vec2(d.x, d.z)), normalize(vec2(0.25, -1.0))), 0.0);
	float lair = pow(toward, 5.0) * smoothstep(0.75, 0.05, d.y);
	c = mix(c, vec3(0.05, 0.45, 0.18), lair * 0.75);
	vec2 g = vec2(atan(d.x, d.z) * 40.0, d.y * 80.0);
	vec2 cell = floor(g);
	float r = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float star = step(0.95, r) * smoothstep(0.35, 0.0, length(fract(g) - 0.5));
	c += star * smoothstep(0.35, 0.7, d.y) * (0.5 + 0.4 * r);
	ALBEDO = c;
}
