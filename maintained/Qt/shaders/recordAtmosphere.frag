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
    if(shadowOnly>3.5){
        vec2 q=qt_TexCoord0-.5;float r=length(q);
        float band=exp(-pow((q.x*.8+q.y*.6-.07)/.13,2.0))*.20;
        float rim=exp(-pow((r-.491)/.0028,2.0))*(.38+.42*smoothstep(-.35,.35,-q.x-q.y));
        float inner=exp(-pow((r-.470)/.0020,2.0))*.12;
        float hub=exp(-pow((r-.025)/.004,2.0))*.42+exp(-pow(r/.012,2.0))*.50;
        float a=clamp(band*(1.0-smoothstep(.47,.50,r))+rim+inner+hub,0.0,.85)*(1.0-smoothstep(.499,.505,r));
        vec3 light=mix(vec3(1.0,.98,.91),vec3(.86,.91,.82),darkMode);
        fragColor=vec4(light*a,a)*qt_Opacity;return;
    }
    if(shadowOnly>2.5){
        vec2 uv=qt_TexCoord0;
        float mask=pow(smoothstep(0.0,.60,uv.x),4.0)*(1.0-smoothstep(.97,1.0,uv.x));
        mask*=smoothstep(0.0,.07,uv.y)*(1.0-smoothstep(.90,1.0,uv.y));
        fragColor=texture(artwork,uv)*mask*qt_Opacity;return;
    }
    if(shadowOnly>1.5){
        // Rotate texture coordinates inside an immobile circular surface.
        // Neither the platter's quad nor its perspective transform rotates.
        vec2 q=qt_TexCoord0-.5;
        float angle=-phase*6.28318530718;
        vec2 uv=mat2(cos(angle),sin(angle),-sin(angle),cos(angle))*q+.5;
        float mask=1.0-smoothstep(.495,.50,length(q));
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
        float contact=exp(-pow((r-.485)/.035,2.0))*.18;
        float bounce=exp(-pow(r/.53,4.0))*.12;
        float alpha=(contact+bounce)*edge;
        vec3 colour=mix(vec3(.35,.29,.22),tint,.45);
        fragColor=vec4(colour*alpha,alpha)*qt_Opacity;
    } else {
        // Separated travelling fronts with soft shoulders: preserve ripple
        // identity instead of four broad bands merging into a stationary fog.
        float light=0.0;
        for(int i=0;i<3;++i){
            float t=fract(phase+float(i)/3.0);
            float radius=.36+t*.45;
            float envelope=sqrt(max(0.0,sin(t*3.14159265)))*(1.0-t)*1.6;
            light+=envelope*(.70*exp(-pow((r-radius)/.026,2.0))+.32*exp(-pow((r-radius)/.010,2.0)));
        }
        float alpha=(1.0-exp(-light))*edge;
        fragColor=vec4(ivory*alpha,alpha)*qt_Opacity;
    }
}
