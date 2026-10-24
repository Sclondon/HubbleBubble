shader_type spatial;
// The sky over the island, a Banjo-Kazooie dusk: deep blue overhead, brighter blue down at the
// horizon, and a few stars up high
render_mode unshaded, cull_disabled, fog_disabled;

void fragment() {
	vec3 d = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz) * -1.0;
	float up = clamp(d.y * 1.3 + 0.1, 0.0, 1.0);
	vec3 c = mix(vec3(0.12, 0.28, 0.95), vec3(0.01, 0.02, 0.32), pow(up, 0.6));
	vec2 g = vec2(atan(d.x, d.z) * 40.0, d.y * 80.0);
	vec2 cell = floor(g);
	float r = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float star = step(0.95, r) * smoothstep(0.35, 0.0, length(fract(g) - 0.5));
	c += star * smoothstep(0.35, 0.7, d.y) * (0.5 + 0.4 * r);
	ALBEDO = c;
}
