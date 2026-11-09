// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy 250da6d ui_wall.go wallPane/backdropOver; Qt texture adapter.
#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;
    float foot;
};
layout(binding=1) uniform sampler2D sharpSource;
layout(binding=2) uniform sampler2D blurSource;
layout(binding=3) uniform sampler2D backdropSource;
void main() {
    vec2 uv=qt_TexCoord0;
    vec2 padded=(uv*area+vec2(48.0))/(area+vec2(96.0));
    vec4 bg=texture(backdropSource,uv);
    vec4 sharp=texture(sharpSource,padded);
    vec4 blurred=texture(blurSource,padded);
    vec4 covers=blurred;
    // Source-over the same live backdrop, then reproduce upstream fade.
    vec4 composed=covers+bg*(1.0-covers.a);
    float fade=foot>0.5?0.7*smoothstep(0.0,0.9,uv.y):1.0-smoothstep(0.1,0.85,uv.y);
    fragColor=mix(composed,bg,fade)*qt_Opacity;
}
