shader_type spatial;
// A witch fading away (the Vanishing Draught): the solid look, see-through by `fade`
render_mode cull_disabled, specular_disabled, blend_mix, depth_prepass_alpha;

uniform vec3 tint = vec3(1.0);
uniform float flash = 0.0;
uniform float glow = 0.0;
uniform float wrap = 0.4;
uniform float fade = 0.0;

void fragment() {
	vec3 c = COLOR.rgb * tint;
	ALBEDO = c;
	EMISSION = c * glow * 1.4 + vec3(1.0, 0.95, 0.85) * flash;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = 1.0 - fade;
}

void light() {
	float d = dot(NORMAL, LIGHT);
	float w = clamp((d + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += w * w * ATTENUATION * LIGHT_COLOR / PI;
}
