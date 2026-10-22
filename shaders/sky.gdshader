shader_type spatial;
// The night over the tower: deep blue overhead to violet at the horizon, with stars
render_mode unshaded, cull_disabled;

void fragment() {
	vec3 d = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz) * -1.0;
	float up = clamp(d.y * 1.4 + 0.15, 0.0, 1.0);
	vec3 c = mix(vec3(0.33, 0.2, 0.5), vec3(0.06, 0.05, 0.2), pow(up, 0.7));
	vec2 g = vec2(atan(d.x, d.z) * 40.0, d.y * 80.0);
	vec2 cell = floor(g);
	float r = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float star = step(0.93, r) * smoothstep(0.35, 0.0, length(fract(g) - 0.5));
	c += star * step(0.05, d.y) * (0.6 + 0.4 * r);
	ALBEDO = c;
}
