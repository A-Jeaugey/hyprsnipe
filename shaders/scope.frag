#version 440
// Scope lens: magnified snapshot inside the circle, darkened screen outside.
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
};
layout(binding = 1) uniform sampler2D shot;

void main() {
    vec2 p = qt_TexCoord0 * resolution;
    float d = distance(p, center);
    float outside = smoothstep(radius - 1.5, radius + 1.5, d);
    // Soft inner shadow near the lens edge, like a real scope
    float ring = smoothstep(radius * 0.80, radius, d) * 0.35;

    // Inside the lens: the snapshot, magnified around the aim point
    float z = mix(zoom * 0.82, zoom, arm);
    vec2 uv = (center + (p - center) / z) / resolution;
    vec4 lens = texture(shot, uv);
    vec4 inside = hasShot > 0.5
        ? vec4(lens.rgb * (1.0 - ring), 1.0)
        : vec4(0.0, 0.0, 0.0, ring);

    vec4 dark = vec4(0.0, 0.0, 0.0, darkness);
    fragColor = mix(inside, dark, outside) * qt_Opacity;
}
