shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
// Радиационное пятно: пульсирующий жар с «гейгер»-дрожью.
uniform vec4 tint : source_color = vec4(1.0, 0.75, 0.25, 1.0);
uniform float speed = 1.1;
uniform float intensity = 1.3;

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
	float n = fbm(UV * 5.0 + TIME * 0.35);
	float geiger = step(0.82, fract(sin(floor(TIME * 11.0) * 12.9898) * 43758.5453));
	float pulse = 0.65 + 0.35 * sin(TIME * speed * TAU);
	float m = smoothstep(1.0, 0.05, r) * (0.4 + 0.6 * n) * pulse + geiger * smoothstep(0.9, 0.4, r) * 0.35;
	EMISSION = tint.rgb * m * intensity;
	ALPHA = clamp(m, 0.0, 1.0);
}
