shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
// Кислотная лужа: пузырящиеся ячейки + свечение кромки.
uniform vec4 tint : source_color = vec4(0.45, 1.0, 0.25, 1.0);
uniform float bubble_speed = 0.6;
uniform float intensity = 1.4;

float hash12(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
	           mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++){ v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float cells = fbm(UV * 9.0 - vec2(TIME * bubble_speed, TIME * bubble_speed * 0.4));
	float bub = smoothstep(0.52, 0.85, cells);
	float rim = smoothstep(0.62, 0.95, r) * smoothstep(1.02, 0.9, r);
	float body = smoothstep(1.0, 0.55, r);
	float m = body * (0.25 + 0.75 * bub) + rim * 0.9;
	EMISSION = tint.rgb * m * intensity * (0.8 + 0.2 * sin(TIME * 3.0));
	ALPHA = clamp(m, 0.0, 1.0);
}
