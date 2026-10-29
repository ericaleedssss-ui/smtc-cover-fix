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
float segmentDistance(vec2 p,vec2 a,vec2 b){
    vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));
}
void main() {
    if(shadowOnly>5.5){
        // An ivory arm and its small cartridge, expressed in the platter plane.
        // No rectangular player body and no rotating background geometry.
        vec2 uv=qt_TexCoord0;
        vec2 pivot=vec2(.70,.04),bend=vec2(.78,.14),tip=vec2(.82,.25);
        float rod=min(segmentDistance(uv,pivot,bend),segmentDistance(uv,bend,tip));
        float arm=1.0-smoothstep(.0055,.0080,rod);
        float hub=1.0-smoothstep(.032,.036,length(uv-pivot));
        vec2 v=normalize(tip-bend),n=vec2(-v.y,v.x),q=uv-tip;
        float body=max(abs(dot(q,n))-.014,abs(dot(q,v))-.033);
        float head=1.0-smoothstep(0.0,.003,body);
        float a=max(max(arm,head),hub*.8)*.84;
        float shine=1.0-smoothstep(.002,.006,rod);
        vec3 tone=mix(vec3(.83,.82,.78),vec3(1.0),max(shine,head*.8));
        float cap=1.0-smoothstep(.012,.016,length(uv-pivot));
        tone=mix(tone,vec3(.76,.76,.72),cap*.45);
        fragColor=vec4(tone*a,a)*qt_Opacity;return;
    }
    if(shadowOnly>4.5){
        // Partial loss of the lower/right silhouette, with the top/left rim
        // retained. This compositing gradient never rotates with the artwork.
        vec2 uv=qt_TexCoord0;
        float merge=smoothstep(.08,.98,uv.x)*smoothstep(.08,.98,uv.y);
        float focus=smoothstep(.02,.54,uv.x);
        float soft=(1.0-focus)*.65;
        vec2 blur=vec2(.002+.006*(1.0-focus));
        vec4 centre=texture(artwork,uv);
        vec4 feathered=centre*.4;
        feathered+=(texture(artwork,uv+blur)+texture(artwork,uv-blur)+texture(artwork,uv+vec2(blur.x,-blur.y))+texture(artwork,uv+vec2(-blur.x,blur.y)))*.15;
        float hole=smoothstep(.017,.020,length(uv-.5));
        fragColor=mix(centre,feathered,soft)*(.38+.62*focus)*(1.0-.32*merge)*hole*qt_Opacity;return;
    }
    if(shadowOnly>3.5){
        vec2 q=qt_TexCoord0-.5;float r=length(q);
        float band=exp(-pow((q.x*.8+q.y*.6-.07)/.13,2.0))*.12;
        float rim=exp(-pow((r-.491)/.0028,2.0))*(.38+.42*smoothstep(-.35,.35,-q.x-q.y));
        float inner=exp(-pow((r-.470)/.0020,2.0))*.12;
        float hub=exp(-pow((r-.022)/.0025,2.0))*.18;
        // Fine grooves live outside the unchanged-size cover label.
        float vinyl=smoothstep(.407,.418,r)*(1.0-smoothstep(.483,.498,r));
        float grooves=pow(.5+.5*cos(r*728.85),6.0)*.15*vinyl;
        float a=clamp(band*(1.0-smoothstep(.47,.50,r))+rim+inner+hub+grooves,0.0,.85)*(1.0-smoothstep(.499,.505,r));
        vec3 light=mix(vec3(1.0,.98,.91),vec3(.86,.91,.82),darkMode);
        fragColor=vec4(light*a,a)*qt_Opacity;return;
    }
    if(shadowOnly>2.5){
        vec2 uv=qt_TexCoord0;
        float mask=pow(smoothstep(0.0,.72,uv.x),1.4)*(1.0-smoothstep(.97,1.0,uv.x));
        mask*=smoothstep(0.0,.07,uv.y)*(1.0-smoothstep(.90,1.0,uv.y));
        fragColor=texture(artwork,uv)*mask*qt_Opacity;return;
    }
    if(shadowOnly>1.5){
        // Rotate texture coordinates inside an immobile circular surface.
        // Neither the platter's quad nor its perspective transform rotates.
        vec2 q=qt_TexCoord0-.5;
        float angle=-phase*6.28318530718;
        vec2 uv=mat2(cos(angle),sin(angle),-sin(angle),cos(angle))*q+.5;
        float feather=mix(.004,.026,smoothstep(-.1,.8,q.x+q.y));
        float mask=1.0-smoothstep(.50-feather,.50,length(q));
        fragColor=texture(artwork,uv)*mask*qt_Opacity;return;
    }
    // Same fixed plane as the platter, with padded bounds for feathered light.
    vec2 p=(qt_TexCoord0-.5)*(shadowOnly>.5?1.64:1.90);
    float r=length(p);
    float edge=1.0-smoothstep(.74,.82,r);
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
        // Neutral translucent white sheets. Their broad interiors overlap;
        // source-over alpha makes each overlap gently brighter, never coloured.
        vec4 sheets=vec4(0.0);
        for(int i=0;i<3;++i){
            float t=fract(phase+float(i)/3.0);
            float front=.23+t*.68;
            float inside=smoothstep(front-.43,front-.34,r);
            float outside=1.0-smoothstep(front-.03,front+.06,r);
            float life=smoothstep(0.0,.13,t)*(1.0-smoothstep(.55,1.0,t));
            float a=mix(.36,.30,darkMode)*inside*outside*life;
            vec3 colour=vec3(1.0);
            sheets=vec4(colour*a,a)+sheets*(1.0-a);
        }
        float boundary=1.0-smoothstep(.84,.95,r);
        fragColor=sheets*boundary*qt_Opacity;
    }
}
