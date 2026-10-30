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
        float lip=smoothstep(.478,.486,r)*(1.0-smoothstep(.497,.501,r));
        float underside=smoothstep(-.20,.34,q.y);
        float leftSide=1.0-smoothstep(-.40,.05,q.x);
        lip=max(lip,leftSide*smoothstep(.470,.480,r)*(1.0-smoothstep(.497,.501,r)));
        float a=lip*mix(.10,.46,max(underside,leftSide*.85));
        vec3 material=mix(vec3(.66,.62,.55),vec3(.39,.42,.36),darkMode)*mix(1.0,.74,max(underside,leftSide*.7));
        fragColor=vec4(material*a,a)*qt_Opacity;return;
    }
    if(shadowOnly>8.5){
        // Five separated track boundaries across broad smooth clear-vinyl bands.
        vec2 q=qt_TexCoord0-.5;float r=length(q),angle=atan(q.y,q.x);
        float seatOuter=phase+.044;
        float seat=smoothstep(phase-.003,phase+.002,r)*(1.0-smoothstep(seatOuter-.002,seatOuter+.002,r));
        float body=smoothstep(seatOuter-.002,seatOuter+.004,r)*(1.0-smoothstep(.493,.502,r));
        // Key light from the upper right: one broad soft bow-tie, fixed in place.
        float sweep=pow(abs(cos(angle+.75)),6.0);
        float lit=clamp(dot(normalize(q+vec2(1e-5)),vec2(.707,-.707)),-1.0,1.0);
        float trackShade=0.0,trackLight=0.0;
        for(int i=0;i<5;++i){
            float track=mix(seatOuter+.03,.474,float(i)/4.0);
            trackShade+=exp(-pow((r-track)/.0015,2.0));
            trackLight+=exp(-pow((r-track+.0032)/.0013,2.0));
        }
        vec3 pigment=mix(vec3(.87,.83,.77),vec3(.63,.67,.60),darkMode);
        pigment*=1.0+.05*lit;
        float groove=.5+.5*sin(r*700.0);
        pigment-=vec3(.28)*trackShade+vec3(.035)*groove;
        pigment+=vec3(.12)*trackLight+vec3(.08)*sweep+vec3(.05)*groove*sweep;
        float a=(.52+.06*sweep)*body+.10*seat;
        vec3 rgb=pigment*a;
        // A fine bright lip where the clear seat meets the milky body.
        float lip=exp(-pow((r-seatOuter)/.0016,2.0))*.50*(1.0-smoothstep(.49,.50,r));
        rgb=rgb*(1.0-lip)+vec3(1.0,.99,.96)*lip;a=a+lip*(1.0-a);
        // Outer contour: survives the left defocus so the disc still reads as a record.
        float leftEdge=1.0-smoothstep(-.40,.05,q.x);
        float contour=exp(-pow((r-.489)/.0055,2.0))*(.38+.14*leftEdge);
        rgb=rgb*(1.0-contour)+vec3(.36,.31,.25)*contour;a=a+contour*(1.0-a);
        // Bright inner lip on the lit (upper-right) side so the edge separates from the cream glass.
        float rimHi=exp(-pow((r-.481)/.0024,2.0))*.50*max(lit,0.0);
        rgb=rgb*(1.0-rimHi)+vec3(1.0,.99,.96)*rimHi;a=a+rimHi*(1.0-a);
        // Contact occlusion where the printed label sits on the vinyl.
        float ao=exp(-pow((r-phase-.004)/.010,2.0))*.24*smoothstep(phase-.004,phase,r);
        rgb=rgb*(1.0-ao)+vec3(.28,.22,.16)*ao;a=a+ao*(1.0-a);
        fragColor=vec4(rgb,a)*qt_Opacity;return;
    }
    if(shadowOnly>6.5){
        // Shared screen-space fade: every physical layer, including gloss and
        // shadows, loses focus and alpha together before the glass boundary.
        vec2 uv=qt_TexCoord0;
        float focus=smoothstep(.26,.81,uv.x);
        float spread=mix(.010,.00035,focus);
        vec2 dx=vec2(spread/max(phase,1.0),0),dy=vec2(0,spread);
        vec4 colour=texture(artwork,uv)*.28;
        colour+=(texture(artwork,uv+dx)+texture(artwork,uv-dx)+texture(artwork,uv+dy)+texture(artwork,uv-dy))*.12;
        colour+=(texture(artwork,uv+dx+dy)+texture(artwork,uv+dx-dy)+texture(artwork,uv-dx+dy)+texture(artwork,uv-dx-dy))*.06;
        float lum=dot(colour.rgb,vec3(.299,.587,.114));
        colour.rgb=mix(colour.rgb,vec3(lum),.16);
        colour.rgb=mix(colour.rgb,vec3(.56,.53,.48)*colour.a,.08);
        colour.rgb+=vec3(.05,.045,.036)*colour.a*(1.0-clamp(lum,0.0,1.0));
        vec2 sp=uv*vec2(phase,1.0);
        float key=1.0-smoothstep(.10,1.25,distance(sp,vec2(phase,0.0)));
        colour.rgb*=.97+.05*key;
        float s=sp.x*.62-sp.y*.78;
        float winLight=exp(-pow((s-.50)/.045,2.0))+.75*exp(-pow((s-.66)/.035,2.0));
        colour.rgb+=vec3(1.0,.95,.86)*colour.a*.04*winLight*smoothstep(.45,.75,uv.x);
        float grain=fract(sin(dot(floor(sp*900.0),vec2(12.9898,78.233)))*43758.5453)-.5;
        colour.rgb+=grain*.05*colour.a;
        float veil=mix(.07,.30,1.0-smoothstep(.35,.88,uv.x));
        vec3 cream=mix(vec3(.965,.950,.920),vec3(.24,.27,.23),darkMode);
        colour.rgb=mix(colour.rgb,cream*colour.a,veil);
        colour.rgb=clamp(colour.rgb,vec3(0.0),vec3(colour.a));
        float fade=.22+.78*smoothstep(.08,.74,uv.x);
        fade*=1.0-.10*smoothstep(.87,1.0,uv.x);
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
        vec4 colour=texture(artwork,uv)*hole+vec4(vec3(.16,.13,.10)*.88,.88)*(1.0-hole);
        float holeLip=exp(-pow((r-.0185)/.0012,2.0))*.55*smoothstep(-.014,.014,q.y);
        colour.rgb=colour.rgb*(1.0-holeLip)+vec3(1.0,.98,.94)*holeLip;colour.a=colour.a+holeLip*(1.0-colour.a);
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
        float sweep=pow(abs(cos(angle+.75)),6.0);
        float bands=0.0;
        for(int i=0;i<5;++i){
            float track=mix(phase+.074,.474,float(i)/4.0);
            // A recessed track and a neighboring thin reflection, not wire rings.
            bands+=exp(-pow((r-track-.002)/.0014,2.0))*(.07+.14*sweep);
        }
        float band=exp(-pow((q.x*.8+q.y*.6-.07)/.13,2.0))*.045;
        float rim=exp(-pow((r-.494)/.0018,2.0))*(.05+.08*sweep);
        float vinylOnly=vinyl*smoothstep(phase+.042,phase+.048,r);
        float a=clamp((bands+.13*sweep+rim)*vinylOnly+band*(1.0-smoothstep(.47,.50,r)),0.0,.34);
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
        float rr=length(q);
        float mask=1.0-smoothstep(.50-feather,.50,rr);
        vec4 c=texture(artwork,uv)*mask;
        float lit=clamp(dot(normalize(q+vec2(1e-5)),vec2(.707,-.707)),-1.0,1.0);
        float bevel=exp(-pow((rr-.488)/.008,2.0));
        c.rgb*=1.0-.22*smoothstep(.36,.50,rr);
        c.rgb*=1.0+.06*lit;
        c.rgb+=c.a*bevel*max(lit,0.0)*.22;
        c.rgb*=1.0-bevel*max(-lit,0.0)*.20;
        fragColor=c*qt_Opacity;return;
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
        float contact=exp(-pow((r-.485)/.035,2.0))*.27;
        float bounce=exp(-pow(r/.56,4.0))*.20;
        float alpha=(contact+bounce)*edge;
        vec3 colour=mix(vec3(.35,.29,.22),tint,.62);
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
