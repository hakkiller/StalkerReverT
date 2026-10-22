shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_back;
// Ядро «Электры»: пульсирующая сфера с бегущими дуговыми поясами.
uniform vec4 core_color : source_color = vec4(0.35, 0.65, 1.0, 1.0);
uniform vec4 arc_color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float pulse_speed = 1.6;
uniform float arc_speed = 2.2;
uniform float intensity = 1.0;
varying vec3 obj_pos;

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
	obj_pos = VERTEX;
}
void fragment() {
	vec3 nrm = normalize(obj_pos);
	vec2 sph = vec2(atan(nrm.y, nrm.x), acos(clamp(nrm.z, -1.0, 1.0)));
	float bands = fbm(sph * vec2(5.0, 3.0) + vec2(TIME * arc_speed, -TIME * arc_speed * 0.35));
	float arc = smoothstep(0.47, 0.50, bands) * smoothstep(0.56, 0.50, bands);
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(-VERTEX))), 2.0);
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed * TAU);
	float m = clamp(fres * 1.2 + arc * 1.5, 0.0, 1.0);
	EMISSION = core_color.rgb * fres * pulse * intensity + arc_color.rgb * arc * 3.5 * pulse * intensity;
	ALPHA = m;
}
