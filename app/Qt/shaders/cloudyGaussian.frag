// MyGo glass.Blur Gaussian sigma in DIPs; Qt separable texture adapter.
#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;
    vec2 direction;
    float sigma;
    float composite;
    float bandHeight;
    float foot;
    float radius;
    float lo;
    float hi;
};
layout(binding=1) uniform sampler2D source;
layout(binding=2) uniform sampler2D original;
void main() {
    vec4 sum=vec4(0.0);float total=0.0;
    for(int i=-8;i<=8;++i){
        float x=float(i)*0.375;
        float w=exp(-0.5*x*x);
        sum+=texture(source,clamp(qt_TexCoord0+direction*x*sigma/area,vec2(0.0),vec2(1.0)))*w;
        total+=w;
    }
    vec4 blurred=sum/total;
    if(composite>0.5){
        float t=clamp((qt_TexCoord0.y*area.y-48.0)/bandHeight,0.0,1.0);
        float wanted=radius*(foot>0.5?t:1.0-t);
        float w=clamp((wanted-lo)/(hi-lo),0.0,1.0);
        blurred=mix(texture(original,qt_TexCoord0),blurred,w);
    }
    fragColor=blurred*qt_Opacity;
}
