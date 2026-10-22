shader_type spatial;
// A witch fading away (the Vanishing Draught): the solid look, see-through by `fade`
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

uniform vec3 sun_dir = vec3(0.35, 0.8, 0.55);
uniform vec3 sun_col = vec3(0.5, 0.46, 0.55);
uniform vec3 amb_col = vec3(0.74, 0.66, 0.82);
uniform vec3 lamp_pos = vec3(0.0, 0.5, 0.6);
uniform vec3 lamp_col = vec3(0.55, 0.8, 0.3);
uniform vec3 tint = vec3(1.0);
uniform float flash = 0.0;
uniform float glow = 0.0;
uniform float fade = 0.0;

varying vec3 lit;

void vertex() {
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 to_lamp = lamp_pos - at;
	float reach = 1.0 / (1.0 + dot(to_lamp, to_lamp) * 0.18);
	vec3 light = amb_col + sun_col * max(dot(n, normalize(sun_dir)), 0.0)
			+ lamp_col * reach * (0.3 + 0.7 * max(dot(n, normalize(to_lamp)), 0.0));
	lit = mix(light, vec3(1.0), glow);
}

void fragment() {
	vec3 c = COLOR.rgb * tint * lit;
	ALBEDO = mix(c, vec3(1.0, 0.95, 0.85), flash);
	ALPHA = 1.0 - fade;
}
