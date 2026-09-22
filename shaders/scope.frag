#version 440
// Darkens the whole screen except a circular lens around the aim point.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;
    float radius;
    float darkness;
};

void main() {
    vec2 p = qt_TexCoord0 * resolution;
    float d = distance(p, center);
    float outside = smoothstep(radius - 1.5, radius + 1.5, d);
    // Soft inner shadow near the lens edge, like a real scope
    float ring = smoothstep(radius * 0.80, radius, d) * (1.0 - outside) * 0.35;
    float a = max(outside * darkness, ring);
    fragColor = vec4(0.0, 0.0, 0.0, a) * qt_Opacity;
}
