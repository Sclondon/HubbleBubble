shader_type spatial;
// Everything solid: the colour painted on its corners, lit by the lights about it (the fire under
// the pot, the brew's own glow, the moon through the window, candles), the light wrapping a little
// round the shoulders of things the way the old consoles' soft shading did. `glow` makes it shine by
// itself; `flash` whites it for an instant.
render_mode cull_disabled, specular_disabled;

uniform vec3 tint = vec3(1.0);
uniform float flash = 0.0;
uniform float glow = 0.0;
uniform float wrap = 0.4;

void fragment() {
	vec3 c = COLOR.rgb * tint;
	ALBEDO = c;
	EMISSION = c * glow * 1.4 + vec3(1.0, 0.95, 0.85) * flash;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float d = dot(NORMAL, LIGHT);
	float w = clamp((d + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += w * w * ATTENUATION * LIGHT_COLOR / PI;
}
