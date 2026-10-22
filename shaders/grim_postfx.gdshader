
shader_type canvas_item;
// "Grim Zone" post effect: desaturation, sickly tint, washed blacks,
// vignette, per-pixel film grain, subtle flicker. Attach to a full-rect
// ColorRect inside a top CanvasLayer. All uniforms are safe to animate.
//
// ПАК №3 (фикс «пикселей»):
// 1) screen_tex теперь filter_linear (было filter_nearest — при любом
//    несовпадении разрешения слой давал блочную «мозаику» по всему экрану).
// 2) Зерно считается по НАСТОЯЩИМ пикселям экрана (FRAGCOORD), а не по
//    крупной сетке floor(SCREEN_UV * 220) — раньше «зерном» были блоки ~9px
//    на FullHD, мерцающие как битые пиксели.
// 3) uniform grain_scale удалён (кодом нигде не задавался).

uniform float desaturation : hint_range(0.0, 1.0) = 0.32;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec4 tint_color : source_color = vec4(0.55, 0.60, 0.48, 1.0);
uniform float wash : hint_range(0.0, 1.0) = 0.45; // lifted, faded blacks
uniform float vignette_strength : hint_range(0.0, 3.0) = 1.1;
uniform float vignette_radius : hint_range(0.1, 1.5) = 0.62;
uniform float grain_amount : hint_range(0.0, 0.4) = 0.05;
uniform float grain_speed = 1.5;
uniform float flicker_amount : hint_range(0.0, 0.1) = 0.02;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
        vec3 col = texture(screen_tex, SCREEN_UV).rgb;

        // desaturate towards luminance, then push into a sickly tint
        float lum = dot(col, vec3(0.299, 0.587, 0.114));
        col = mix(col, vec3(lum), desaturation);
        col = mix(col, tint_color.rgb * (lum * 0.9 + 0.1), tint_strength);

        // washed-out blacks / faded film
        col = mix(col, col * 0.75 + vec3(0.06, 0.062, 0.055), wash);

        // vignette (aspect-correct)
        vec2 d = SCREEN_UV - vec2(0.5);
        d.x *= SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
        float vig = smoothstep(vignette_radius + 0.45, vignette_radius - 0.35, length(d));
        col *= clamp(mix(1.0, vig, clamp(vignette_strength, 0.0, 2.0)), 0.0, 1.0);

        // мелкое зерно 1:1 к пикселям экрана (без крупных блоков)
        float g = hash(FRAGCOORD.xy + vec2(fract(TIME * grain_speed) * 91.7));
        col += (g - 0.5) * grain_amount;

        // dying-light flicker
        col *= 1.0 - flicker_amount * sin(TIME * 13.0 + hash(vec2(floor(TIME * 3.0), 7.0)) * 6.28);

        COLOR = vec4(col, 1.0);
}
