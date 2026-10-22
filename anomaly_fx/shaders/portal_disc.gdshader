shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
// Телепорт: закрученное кольцо с бегущей волной внутрь.
uniform vec4 tint : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float speed = 1.4;
uniform float intensity = 1.6;

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
	float swirl = fbm(vec2(a * 3.0 - TIME * speed * 2.0, r * 7.0 + TIME * speed));
	float wave = 0.5 + 0.5 * sin(r * 18.0 + TIME * speed * 5.0);
	float ring = smoothstep(0.35, 0.75, r) * smoothstep(1.05, 0.8, r);
	float core = smoothstep(0.45, 0.0, r);
	float m = (0.4 + 0.6 * swirl) * ring + core * wave * 0.5;
	EMISSION = tint.rgb * m * intensity;
	ALPHA = clamp(m, 0.0, 1.0);
}
