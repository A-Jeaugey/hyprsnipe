#version 440
// Scope lens: magnified snapshot inside the circle, darkened screen outside.
// On fire, a bright impact star bursts at the aim point and a bullet streak
// flicks down through it.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;
    float radius;
    float darkness;
    float zoom;
    float hasShot;
    float arm;
    float fire;      // 0 -> 1 over the shot, drives impact + streak
};
layout(binding = 1) uniform sampler2D shot;

void main() {
    vec2 p = qt_TexCoord0 * resolution;
    float d = distance(p, center);
    float outside = smoothstep(radius - 1.5, radius + 1.5, d);
    float ring = smoothstep(radius * 0.80, radius, d) * 0.35;

    float z = mix(zoom * 0.82, zoom, arm);
    vec2 uv = (center + (p - center) / z) / resolution;
    vec4 lens = texture(shot, uv);
    vec4 inside = hasShot > 0.5
        ? vec4(lens.rgb * (1.0 - ring), 1.0)
        : vec4(0.0, 0.0, 0.0, ring);

    vec4 dark = vec4(0.0, 0.0, 0.0, darkness);
    vec4 col = mix(inside, dark, outside) * qt_Opacity;

    if (fire > 0.0) {
        vec2 q = p - center;

        // Impact star: bright core plus four spikes, bursts then fades
        float life = 1.0 - fire;                       // 1 at shot, 0 at end
        float core = exp(-d * d / (2.0 * 90.0 * 90.0 * fire));
        float spikeH = exp(-abs(q.y) / 3.0) * exp(-abs(q.x) / (140.0 * fire + 1.0));
        float spikeV = exp(-abs(q.x) / 3.0) * exp(-abs(q.y) / (140.0 * fire + 1.0));
        float star = (core + 0.7 * (spikeH + spikeV)) * life;

        // Bullet streak: a thin vertical line flicking downward past the target
        float travel = mix(-radius, radius, fire);
        float streak = exp(-abs(q.x) / 2.5) * exp(-abs(q.y - travel) / 40.0) * life;

        float flash = clamp(star + streak, 0.0, 1.0);
        col = mix(col, vec4(1.0, 1.0, 1.0, qt_Opacity), flash);
    }

    fragColor = col;
}
