shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
// Замедление времени: расходящиеся круги-рябь.
uniform vec4 tint : source_color = vec4(0.45, 0.7, 1.0, 1.0);
uniform float speed = 0.9;
uniform float rings = 7.0;
uniform float intensity = 1.2;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float w = sin(r * rings * TAU * 0.5 - TIME * speed * TAU);
	float band = smoothstep(0.7, 1.0, w);
	float fade = smoothstep(1.0, 0.2, r);
	float m = band * fade;
	EMISSION = tint.rgb * m * intensity;
	ALPHA = m * 0.9;
}
