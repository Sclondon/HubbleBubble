shader_type spatial;
// Fire, sparks and glows: shines by itself, adds to what is behind
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 colour = vec3(0.5, 1.0, 0.3);
uniform float strength = 1.0;

void fragment() {
	ALBEDO = COLOR.rgb * colour * strength;
	ALPHA = COLOR.a;
}
