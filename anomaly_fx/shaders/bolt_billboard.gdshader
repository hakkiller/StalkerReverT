shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
// Вспышки молний: атлас 4 кадра, кадр меняется по TIME.
uniform sampler2D atlas : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(0.7, 0.85, 1.0, 1.0);
uniform float fps = 10.0;
uniform float frames = 4.0;
uniform float frame_offset = 0.0;
uniform float intensity = 1.6;
void vertex() {
	// ручной сферический билборд (работает во всех рендерерах, вкл. dummy)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
}
void fragment() {
	float f = floor(mod(TIME * fps + frame_offset, frames));
	vec2 uv = vec2(UV.x / frames + f / frames, UV.y);
	float t = texture(atlas, uv).r;
	float flick = 0.55 + 0.45 * fract(sin(floor(TIME * fps * 2.0) + frame_offset) * 437.58);
	EMISSION = tint.rgb * t * intensity * flick;
	ALPHA = t;
}
