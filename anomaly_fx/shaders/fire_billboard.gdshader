shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
// Процедурное пламя: fbm поднимается, форма гаснет к вершине.
uniform vec4 col_low : source_color = vec4(1.0, 0.22, 0.04, 1.0);
uniform vec4 col_high : source_color = vec4(1.0, 0.8, 0.25, 1.0);
uniform vec2 noise_scale = vec2(2.6, 3.2);
uniform float speed = 1.4;
uniform float intensity = 2.0;

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
void vertex() {
	// ручной сферический билборд (работает во всех рендерерах, вкл. dummy)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	float n = fbm(UV * noise_scale + vec2(0.0, -TIME * speed));
	float radial = 1.0 - abs(UV.x - 0.5) * 2.0;
	float f = clamp((1.0 - UV.y) * (0.45 + 0.9 * n) * 1.9 * (0.35 + 0.65 * radial) - 0.25, 0.0, 1.0);
	float body = smoothstep(0.02, 0.4, f) * smoothstep(1.0, 0.55, UV.y + (1.0 - n) * 0.35);
	vec3 col = mix(col_low.rgb, col_high.rgb, smoothstep(0.15, 0.8, f));
	EMISSION = col * body * intensity;
	ALPHA = clamp(body * 1.25, 0.0, 1.0);
}
