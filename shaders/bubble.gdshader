shader_type spatial;
// A bubble swelling on the brew: a thin skin, clear in the middle and bright at the rim, with a glint.
// Its colour and how see-through it is are set on the material (from the PotionLook: bubble_colour,
// bubble_opacity, bubble_shine); how far gone each one is comes in its instance colour's alpha.
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec3 tint : source_color = vec3(0.7, 1.0, 0.85);
// 0 all but invisible, 1 a solid skin
uniform float opacity : hint_range(0.0, 1.0) = 0.75;
// How bright the rim and the glint are
uniform float shine : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 c = tint * COLOR.rgb * (0.7 + rim * 0.9 * shine);
	float glint = smoothstep(0.93, 0.99, dot(normalize(NORMAL), normalize(vec3(-0.4, 0.8, 0.5)))) * shine;
	ALBEDO = c + vec3(glint);
	ALPHA = clamp((0.15 + rim * 0.85) * opacity + glint, 0.0, 1.0) * COLOR.a;
}
