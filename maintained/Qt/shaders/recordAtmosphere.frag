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
    if(shadowOnly>9.5){
        // The offset lower rim is a narrow physical sidewall. No opaque disc
        // underneath the translucent material and no luminous thickness.
        vec2 q=qt_TexCoord0-.5;float r=length(q);
        float lip=smoothstep(.487,.491,r)*(1.0-smoothstep(.497,.501,r));
        float underside=smoothstep(-.12,.32,q.y);
        float a=lip*mix(.025,.19,underside);
        vec3 material=mix(vec3(.48,.45,.39),vec3(.39,.42,.36),darkMode);
        fragColor=vec4(material*a,a)*qt_Opacity;return;
    }
    if(shadowOnly>8.5){
        // Five separated track boundaries across broad smooth clear-vinyl bands.
        vec2 q=qt_TexCoord0-.5;float r=length(q),angle=atan(q.y,q.x);
        float annulus=smoothstep(phase-.003,phase+.006,r)*(1.0-smoothstep(.493,.502,r));
        float sweep=pow(abs(cos(angle-.65)),16.0);
        float trackShade=0.0;
        for(int i=0;i<5;++i){
            float track=mix(phase+.024,.476,float(i)/4.0);
            trackShade+=exp(-pow((r-track)/.0015,2.0));
        }
        vec3 pigment=mix(vec3(.64,.62,.57),vec3(.63,.67,.60),darkMode);
        pigment-=vec3(.24)*trackShade;
        pigment+=vec3(.12)*sweep;
        float a=(.28+.06*sweep)*annulus;
        fragColor=vec4(pigment*a,a)*qt_Opacity;return;
    }
    if(shadowOnly>6.5){
        // Shared screen-space fade: every physical layer, including gloss and
        // shadows, loses focus and alpha together before the glass boundary.
        vec2 uv=qt_TexCoord0;
        float focus=smoothstep(.26,.81,uv.x);
        float spread=mix(.024,.00035,focus);
        vec2 dx=vec2(spread/max(phase,1.0),0),dy=vec2(0,spread);
        vec4 colour=texture(artwork,uv)*.28;
        colour+=(texture(artwork,uv+dx)+texture(artwork,uv-dx)+texture(artwork,uv+dy)+texture(artwork,uv-dy))*.12;
        colour+=(texture(artwork,uv+dx+dy)+texture(artwork,uv+dx-dy)+texture(artwork,uv-dx+dy)+texture(artwork,uv-dx-dy))*.06;
        float fade=.12+.88*smoothstep(.10,.76,uv.x);
        fade*=1.0-.24*smoothstep(.87,1.0,uv.x);
        fade*=1.0-.22*smoothstep(.82,1.0,uv.y);
        // LiquidGlass has a 22-unit radius in a 440-unit-high content area.
        vec2 size=vec2(phase,1.0),q=abs((uv-.5)*size)-size*.5+.05;
        float d=length(max(q,vec2(0)))+min(max(q.x,q.y),0.0)-.05;
        float clipMask=1.0-smoothstep(-.001,0.0,d);
        fragColor=colour*fade*clipMask*qt_Opacity;return;
    }
    if(shadowOnly>4.5){
        // The aperture belongs to the assembled platter; the outer composite
        // handles focal fade so no isolated reflection can survive it.
        vec2 uv=qt_TexCoord0;
        vec2 q=uv-.5;float r=length(q);
        float hole=smoothstep(.016,.0175,r);
        vec4 colour=texture(artwork,uv)*hole;
        // Regular inner wall: upper interior is darker, lower lip catches light.
        // This is inside the aperture, rather than an irregular cast shadow.
        float wall=smoothstep(.016,.0175,r)*(1.0-smoothstep(.020,.022,r));
        float facing=smoothstep(-.014,.014,q.y);
        vec3 material=mix(vec3(.40,.37,.32),vec3(.85,.82,.74),facing);
        float a=wall*.48;
        fragColor=(vec4(material*a,a)+colour*(1.0-a))*qt_Opacity;return;
    }
    if(shadowOnly>3.5){
        vec2 q=qt_TexCoord0-.5;float r=length(q),angle=atan(q.y,q.x);
        float vinyl=smoothstep(phase-.002,phase+.008,r)*(1.0-smoothstep(.495,.502,r));
        float sweep=pow(abs(cos(angle-.65)),16.0);
        float bands=0.0;
        for(int i=0;i<5;++i){
            float track=mix(phase+.024,.476,float(i)/4.0);
            // A recessed track and a neighboring thin reflection, not wire rings.
            bands+=exp(-pow((r-track-.002)/.0014,2.0))*(.07+.14*sweep);
        }
        float band=exp(-pow((q.x*.8+q.y*.6-.07)/.13,2.0))*.045;
        float rim=exp(-pow((r-.494)/.0018,2.0))*(.05+.08*sweep);
        float a=clamp((bands+.10*sweep+rim)*vinyl+band*(1.0-smoothstep(.47,.50,r)),0.0,.34);
        vec3 light=mix(vec3(1.0,.98,.93),vec3(.87,.92,.85),darkMode);
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
