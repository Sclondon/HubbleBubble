shader_type canvas_item;
// The N64 filter, over the 3D blown up from a small picture: ordered dithering on the small
// picture's own pixel grid, then down to 5 bits a colour (the console's 16-bit frame buffer)

uniform float amount = 1.0;
uniform vec2 size = vec2(270.0, 480.0);

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = floor(UV * size);
	int i = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
	float d = (BAYER[i] / 16.0 - 0.5) / 31.0;
	vec3 q = floor((c.rgb + d) * 31.0 + 0.5) / 31.0;
	COLOR = vec4(mix(c.rgb, q, amount), 1.0);
}
