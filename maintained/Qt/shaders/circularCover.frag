#version 440
// G64: circular ALPHA crop of the actual album image, including corners.
// Single sampled texture and a feathered 1px outer edge. The rectangular
// image never reaches the screen unchanged.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D coverSource;

void main() {
    vec2 point = qt_TexCoord0 * 2.0 - vec2(1.0);
    float radius = length(point);
    float circularAlpha = 1.0 - smoothstep(0.966, 1.005, radius);
    vec4 photo = texture(coverSource, qt_TexCoord0);
    fragColor = vec4(photo.rgb, photo.a * circularAlpha) * qt_Opacity;
}
