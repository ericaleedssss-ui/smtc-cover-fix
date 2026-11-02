#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 panelSize;
    float unit;
};
layout(binding=1) uniform sampler2D source;
void main() {
    vec2 size = max(panelSize, vec2(1.0));
    float y = qt_TexCoord0.y * size.y;
    float top = smoothstep(0.0, min(178.0 * unit, size.y * .35), y);
    float bottom = smoothstep(0.0, min(198.0 * unit, size.y * .38), size.y - y);
    float clarity = min(top, bottom);
    float blur = (1.0 - clarity) * 2.5 * unit;
    vec4 color = texture(source, qt_TexCoord0);
    // Only the two edge bands run the Gaussian kernel. The reading area keeps
    // the original texture exactly sharp, including small translated text.
    if (blur > .05) {
        color = vec4(0.0);
        float total = 0.0;
        for (int j = -3; j <= 3; ++j) {
            for (int i = -3; i <= 3; ++i) {
                vec2 offset = vec2(float(i), float(j));
                float weight = exp(-dot(offset, offset) / 4.5);
                color += texture(source, clamp(qt_TexCoord0 + offset * blur / size, vec2(0.0), vec2(1.0))) * weight;
                total += weight;
            }
        }
        color /= total;
    }
    fragColor = color * clarity * qt_Opacity;
}
