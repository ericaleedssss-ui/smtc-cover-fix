#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 artworkSize;
    float radius;
    float sourceAspect;
};
layout(binding=1) uniform sampler2D source;
void main() {
    vec2 halfSize=artworkSize*.5;
    vec2 q=abs(qt_TexCoord0*artworkSize-halfSize)-(halfSize-vec2(radius));
    float d=length(max(q,0.0))+min(max(q.x,q.y),0.0)-radius;
    float aa=max(fwidth(d),.01);
    vec2 uv=qt_TexCoord0;
    float targetAspect=artworkSize.x/max(artworkSize.y,1.0);
    if(sourceAspect>targetAspect)uv.x=(uv.x-.5)*targetAspect/sourceAspect+.5;
    else uv.y=(uv.y-.5)*sourceAspect/targetAspect+.5;
    fragColor=texture(source,uv)*(1.0-smoothstep(-aa,aa,d))*qt_Opacity;
}
