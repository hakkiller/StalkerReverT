shader_type canvas_item;
// Хазард-полосы 45°: жёлтый/чёрный, как на макете БУНКЕР.

uniform vec4 col_a : source_color = vec4(0.909, 0.725, 0.235, 1.0);
uniform vec4 col_b : source_color = vec4(0.051, 0.051, 0.051, 1.0);
uniform float stripes = 6.0;

void fragment() {
	float v = fract((UV.x + UV.y) * stripes);
	COLOR = v < 0.5 ? col_a : col_b;
}
