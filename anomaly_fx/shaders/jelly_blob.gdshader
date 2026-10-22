shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
// Желеобразная масса: колышется вершинным шумом, полупрозрачное свечение.
uniform vec4 tint : source_color = vec4(0.65, 0.95, 0.3, 1.0);
uniform float wobble_amp = 0.12;
uniform float wobble_speed = 2.2;
uniform float intensity = 0.9;
void vertex() {
	float w = sin(VERTEX.x * 3.1 + TIME * wobble_speed)
	        * sin(VERTEX.y * 2.7 - TIME * wobble_speed * 1.3)
	        * sin(VERTEX.z * 3.4 + TIME * wobble_speed * 0.8);
	VERTEX += NORMAL * w * wobble_amp;
}
void fragment() {
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(-VERTEX))), 1.6);
	EMISSION = tint.rgb * (0.25 + fres * 1.1) * intensity;
	ALBEDO = tint.rgb;
	ALPHA = 0.72;
}
