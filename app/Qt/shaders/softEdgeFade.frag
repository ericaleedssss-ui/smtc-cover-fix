#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 panelSize;
    float horizontal;
    float fadePx;
    float fadeStart;
    float fadeEnd;
    float blurStrength;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 size = max(panelSize, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    float position = (horizontal > 0.5 ? uv.x * size.x : uv.y * size.y);
    float length = horizontal > 0.5 ? size.x : size.y;
    float band = min(max(1.0, fadePx), length * 0.32);
    float a = fadeStart > .5 ? smoothstep(0.0, band, position) : 1.0;
    float b = fadeEnd > .5 ? smoothstep(0.0, band, length - position) : 1.0;
    float clarity = min(a, b);
    vec4 result = texture(source, uv);
    // Blur a little only where the fade is happening. The centre remains crisp.
    float radius = (1.0 - clarity) * blurStrength;
    if (radius > 0.08) {
        vec4 average = vec4(0.0);
        float total = 0.0;
        for (int j = -1; j <= 1; ++j) {
            for (int i = -1; i <= 1; ++i) {
                vec2 delta = vec2(float(i), float(j));
                float weight = 1.0 / (1.0 + dot(delta, delta));
                average += texture(source, clamp(uv + delta * radius / size, vec2(0), vec2(1))) * weight;
                total += weight;
            }
        }
        result = average / total;
    }
    fragColor = result * clarity * qt_Opacity;
}
