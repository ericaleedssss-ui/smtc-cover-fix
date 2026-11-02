#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 panelSize;
    float topInset;
    float fadePx;
    float fadeTop;
    float bottomFadePx;
};
layout(binding=1) uniform sampler2D source;
void main(){
    vec2 uv=qt_TexCoord0;
    float y=uv.y*panelSize.y;
    float band=max(1.0,fadePx);
    float top=fadeTop>.5?smoothstep(topInset,topInset+band,y):1.0;
    float bottom=smoothstep(0.0,max(1.0,bottomFadePx),panelSize.y-y);
    fragColor=texture(source,uv)*top*bottom*qt_Opacity;
}
