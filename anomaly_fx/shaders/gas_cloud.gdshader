shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded, cull_disabled;
// Газовое облако: медленный fbm, мягкий край, лёгкая подсветка.
uniform vec4 tint : source_color = vec4(0.55, 0.75, 0.4, 1.0);
uniform float speed = 0.25;
uniform float alpha = 0.55;

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
	float n = fbm(UV * 3.0 + vec2(TIME * speed, TIME * speed * 0.3));
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float shape = smoothstep(0.35, 0.8, n) * smoothstep(1.0, 0.35, r);
	ALBEDO = tint.rgb * 0.7;
	EMISSION = tint.rgb * shape * 0.35;
	ALPHA = shape * alpha;
}
