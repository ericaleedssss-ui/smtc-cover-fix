// MyGo plugins/glass/blur.go blurLevels + blur.metal effect weight, MIT.
#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;
    float bandHeight;
    float foot;
    float radius;
    float lo;
    float hi;
};
layout(binding=1) uniform sampler2D source;
layout(binding=2) uniform sampler2D blurred;
void main() {
    float t=clamp((qt_TexCoord0.y*area.y-48.0)/bandHeight,0.0,1.0);
    float wanted=radius*(foot>0.5?t:1.0-t);
    float w=clamp((wanted-lo)/(hi-lo),0.0,1.0);
    fragColor=mix(texture(source,qt_TexCoord0),texture(blurred,qt_TexCoord0),w)*qt_Opacity;
}
