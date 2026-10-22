shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
// Воронка на земле: спиральные рукава, вращение по TIME.
uniform vec4 tint : source_color = vec4(0.55, 0.4, 0.95, 1.0);
uniform float speed = 1.1;
uniform float arms = 5.0;
uniform float twist = 12.0;
uniform float intensity = 1.7;

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
	float a = atan(p.y, p.x);
	float swirl = fbm(vec2(a * 2.5 + r * twist * 0.5 - TIME * speed * 2.5, r * 5.0 - TIME * speed));
	float spiral = 0.5 + 0.5 * sin(a * arms + r * twist - TIME * speed * 4.0);
	float m = mix(swirl, spiral, 0.4) * smoothstep(1.0, 0.15, r);
	EMISSION = tint.rgb * m * intensity * (0.7 + 0.3 * sin(TIME * 2.0));
	ALPHA = m * smoothstep(1.05, 0.55, r);
}
