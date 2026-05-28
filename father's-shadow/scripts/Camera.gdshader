// PSX / VHS Post-Processing Shader for Godot 4
// Применять на CanvasLayer (layer=10) > ColorRect (Full Rect)
//
// Настройки в Inspector (ShaderMaterial):
//   resolution_divider, color_depth, dither_strength,
//   scanline_strength, vhs_noise, chromatic_aberration,
//   tape_crease_speed/count/strength, color_bleed,
//   vignette_strength, tracking_error

shader_type canvas_item;

// ─── Параметры ────────────────────────────────────────────────────────────────
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float resolution_divider   : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float color_depth          : hint_range(1.0, 32.0, 1.0) = 24.0;
uniform float dither_strength      : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_strength    : hint_range(0.0, 1.0) = 0.25;
uniform float vhs_noise            : hint_range(0.0, 1.0) = 0.18;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.005;
uniform float tape_crease_speed    : hint_range(0.0, 5.0) = 1.2;
uniform float tape_crease_count    : hint_range(0.0, 20.0) = 1.2;
uniform float tape_crease_strength : hint_range(0.0, 0.05) = 0.012;
uniform float color_bleed          : hint_range(0.0, 0.02) = 0.004;
uniform float vignette_strength    : hint_range(0.0, 1.0) = 0.45;
uniform float tracking_error       : hint_range(0.0, 1.0) = 0.15;

// ─── Вспомогательные функции ──────────────────────────────────────────────────

float hash(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float bayer4x4(vec2 pos) {
    int x = int(mod(pos.x, 4.0));
    int y = int(mod(pos.y, 4.0));
    int bayer[16] = int[](
         0,  8,  2, 10,
        12,  4, 14,  6,
         3, 11,  1,  9,
        15,  7, 13,  5
    );
    return float(bayer[y * 4 + x]) / 16.0;
}

vec3 quantize_color(vec3 color, float depth) {
    float levels = pow(2.0, depth / 3.0);
    return floor(color * levels + 0.5) / levels;
}

// ─── Основной фрагмент ────────────────────────────────────────────────────────
void fragment() {
    // SCREEN_UV — правильные UV для screen_texture в Godot 4
    vec2 uv = SCREEN_UV;
    float t  = TIME;

    // Размер пикселя экрана
    vec2 px_size = SCREEN_PIXEL_SIZE;

    // ── 1. PSX-пиксели ────────────────────────────────────────────────────────
    vec2 snapped_uv = floor(uv / (px_size * resolution_divider))
                      * (px_size * resolution_divider);

    // ── 2. Tape Crease ────────────────────────────────────────────────────────
    float crease_y      = fract(uv.y * tape_crease_count - t * tape_crease_speed);
    float crease        = smoothstep(0.92, 1.0, crease_y)
                        + smoothstep(0.92, 1.0, 1.0 - crease_y);
    float crease_offset = crease * tape_crease_strength
                        * sin(t * 7.3 + uv.y * 23.7);
    vec2 distorted_uv   = snapped_uv + vec2(crease_offset, 0.0);

    // ── 3. Tracking Error ─────────────────────────────────────────────────────
    float track_band  = step(0.94, fract(uv.y * 3.0 - t * 0.3));
    float track_noise = (hash(vec2(uv.y * 50.0, floor(t * 12.0))) - 0.5)
                      * tracking_error * track_band * 0.04;
    distorted_uv.x   += track_noise;

    // ── 4. Хроматическая аберрация ────────────────────────────────────────────
    float ca    = chromatic_aberration
                + length((uv - 0.5) * 2.0) * chromatic_aberration * 0.5;
    vec2 ca_dir = (uv - 0.5) * 2.0;

    vec4 col_r = texture(screen_texture, clamp(distorted_uv + ca_dir * ca, 0.0, 1.0));
    vec4 col_g = texture(screen_texture, clamp(distorted_uv,               0.0, 1.0));
    vec4 col_b = texture(screen_texture, clamp(distorted_uv - ca_dir * ca, 0.0, 1.0));

    vec3 color = vec3(col_r.r, col_g.g, col_b.b);

    // ── 5. Color Bleed ────────────────────────────────────────────────────────
    if (color_bleed > 0.0) {
        vec3 bl = texture(screen_texture, clamp(distorted_uv - vec2(color_bleed, 0.0), 0.0, 1.0)).rgb;
        vec3 br = texture(screen_texture, clamp(distorted_uv + vec2(color_bleed, 0.0), 0.0, 1.0)).rgb;
        color.r = mix(color.r, (color.r + bl.r + br.r) / 3.0, 0.5);
        color.b = mix(color.b, (color.b + bl.b + br.b) / 3.0, 0.5);
    }

    // ── 6. VHS-шум ────────────────────────────────────────────────────────────
    if (vhs_noise > 0.0) {
        float frame      = floor(t * 24.0);
        float grain      = hash(snapped_uv / px_size + vec2(frame * 1.7, frame * 3.1));
        float line_noise = hash(vec2(floor(uv.y / px_size.y), frame));
        float line_band  = step(1.0 - vhs_noise * 0.03, line_noise);
        color += (grain - 0.5) * vhs_noise * 0.15;
        color += line_band * (grain - 0.5) * 0.3;
    }

    // ── 7. Дизеринг (Bayer 4×4) ───────────────────────────────────────────────
    if (dither_strength > 0.0) {
        vec2 px     = floor(uv / px_size);
        float dith  = (bayer4x4(px) - 0.5) * dither_strength * (1.0 / color_depth);
        color += vec3(dith);
    }

    // ── 8. Квантизация (PSX palette) ─────────────────────────────────────────
    color = quantize_color(clamp(color, 0.0, 1.0), color_depth);

    // ── 9. Сканлайны ─────────────────────────────────────────────────────────
    if (scanline_strength > 0.0) {
        float line = sin(uv.y / px_size.y * PI);
        line = pow(abs(line), 0.8);
        color *= 1.0 - scanline_strength * (1.0 - line) * 0.6;
    }

    // ── 10. Виньетирование ────────────────────────────────────────────────────
    if (vignette_strength > 0.0) {
        vec2  vu  = (uv - 0.5) * 2.0;
        float vig = dot(vu, vu);
        color *= 1.0 - vig * vignette_strength * 0.5;
    }

    COLOR = vec4(color, 1.0);
}
