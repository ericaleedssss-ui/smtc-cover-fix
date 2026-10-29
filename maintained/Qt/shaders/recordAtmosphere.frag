#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    float shadowOnly;
    float darkMode;
};
layout(binding = 1) uniform sampler2D artwork;
void main() {
    if(shadowOnly>1.5){
        // Rotate texture coordinates inside an immobile circular surface.
        // Neither the platter's quad nor its perspective transform rotates.
        vec2 q=qt_TexCoord0-.5;
        float angle=-phase*6.28318530718;
        vec2 uv=mat2(cos(angle),sin(angle),-sin(angle),cos(angle))*q+.5;
        float mask=1.0-smoothstep(.496,.5,length(q));
        fragColor=texture(artwork,uv)*mask*qt_Opacity;return;
    }
    // Same fixed plane as the platter, with padded bounds for feathered light.
    vec2 p=(qt_TexCoord0-.5)*1.64;
    float r=length(p);
    float edge=1.0-smoothstep(.74,.82,r);
    vec3 ivory=mix(vec3(1.0,.94,.82),vec3(.80,.86,.70),darkMode);
    if(shadowOnly>.5) {
        // Low resolution, stationary cover-coloured bounce, not an opaque oval.
        vec2 uv=clamp(p*.72+.5,vec2(.13),vec2(.87));
        vec3 tint=vec3(0.0);
        for(int j=-1;j<=1;++j)for(int i=-1;i<=1;++i)
            tint+=texture(artwork,clamp(uv+vec2(i,j)*.16,vec2(.05),vec2(.95))).rgb/9.0;
        float contact=exp(-pow((r-.485)/.067,2.0))*.18;
        float bounce=exp(-pow(r/.53,4.0))*.12;
        float alpha=(contact+bounce)*edge;
        vec3 colour=mix(vec3(.35,.29,.22),tint,.45);
        fragColor=vec4(colour*alpha,alpha)*qt_Opacity;
    } else {
        float light=exp(-pow((r-.55)/.105,2.0))*.10;
        for(int i=0;i<3;++i){
            float t=fract(phase+float(i)/3.0);
            float radius=.49+t*.29;
            float envelope=sin(t*3.14159265)*(1.0-t);
            // Soft luminous ribbon accompanied by a finer highlight.
            light+=envelope*(.17*exp(-pow((r-radius)/.021,2.0))
                             +.33*exp(-pow((r-radius)/.0035,2.0)));
        }
        float alpha=clamp(light*edge,0.0,.48);
        fragColor=vec4(ivory*alpha,alpha)*qt_Opacity;
    }
}
