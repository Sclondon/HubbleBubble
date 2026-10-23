shader_type spatial;
// God rays standing up out of the pot: an open cone (wide at the top), added over what's behind, cut
// into shafts by noise running round it that drifts slowly, brightest at the brew and fading up into
// the dark, softest at the cone's edges as you look across it. The potion's colour and how strong
// come from the brew (Brew).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.5, 0.8);
uniform float strength = 0.4;

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float shafts(float u, float t) {
	float a = u * 22.0;
	float i = floor(a);
	float f = fract(a);
	float k = mix(hash(i + floor(t)), hash(i + 1.0 + floor(t)), smoothstep(0.0, 1.0, f));
	float k2 = mix(hash(i + floor(t) + 1.0), hash(i + 2.0 + floor(t)), smoothstep(0.0, 1.0, f));
	return mix(k, k2, smoothstep(0.0, 1.0, fract(t)));
}

void fragment() {
	float u = UV.x;
	// (a cylinder's v runs from its top down: turned over, so 0 is at the brew)
	float v = 1.0 - UV.y;
	float s = shafts(u + TIME * 0.004, TIME * 0.25);
	s = 0.08 + 0.92 * smoothstep(0.35, 0.85, s);
	// soft where the cone is seen edge on, fading up and away from the brew
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.2);
	float fade = pow(1.0 - v, 1.6) * smoothstep(0.0, 0.04, v);
	ALBEDO = tint * s * edge * fade * strength;
}
