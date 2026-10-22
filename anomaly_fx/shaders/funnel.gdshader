shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
// Смерч/вихрь: конус со скроллящимся шумом и вертикальными прожилками.
uniform vec4 tint : source_color = vec4(0.62, 0.62, 0.78, 1.0);
uniform float speed = 2.6;
uniform float intensity = 1.15;

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
	float n = fbm(vec2(UV.x * 5.0, UV.y * 2.2 - TIME * speed));
	float streaks = 0.5 + 0.5 * sin(UV.x * TAU * 18.0 + TIME * 4.0 + n * 6.0);
	float fade = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.75, UV.y);
	float m = (0.45 + 0.55 * n) * mix(1.0, streaks, 0.35) * fade;
	EMISSION = tint.rgb * m * intensity;
	ALPHA = m * 0.85;
}
