shader_type spatial;
// A spark or a glint: a little bright four-pointed star turned to the camera, adding light
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = abs(UV * 2.0 - 1.0);
	float star = 1.0 - smoothstep(0.0, 0.3, uv.x * uv.y * 5.0 + (uv.x + uv.y) * 0.3);
	ALBEDO = COLOR.rgb * star * 2.0;
	ALPHA = star * COLOR.a;
}
