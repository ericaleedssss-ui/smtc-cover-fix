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
// Selected material B; constants preserve the existing ShaderEffect interface.
const float rimWidth=.038;
const float opaqueSeat=1.0;
const float studyMaterial=1.0;
// Tonearm helpers. The arm lives in the record's own inclined plane, so the
// platter's perspective transform foreshortens it exactly like the disc.
float armSeg(vec2 p, vec2 a, vec2 b){vec2 pa=p-a,ba=b-a;float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);return length(pa-ba*h);}
float armBox(vec2 p, vec2 c, vec2 hs, float r){vec2 q=abs(p-c)-hs+r;return length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-r;}
vec4 armOver(vec4 dst, vec3 rgb, float a){return vec4(rgb*a,a)+dst*(1.0-a);}
// Satin metal cylinder: n runs -1..1 across the part, la is the key light
// component across it and lz its elevation.
vec3 armMetal(float n, float la, float lz, float dark){
    n=clamp(n,-1.0,1.0);
    vec2 N=vec2(n,sqrt(max(0.0,1.0-n*n)));
    vec2 Lv=normalize(vec2(la,lz));
    float dif=max(dot(N,Lv),0.0);
    float spe=pow(max(dot(N,normalize(Lv+vec2(0.0,1.0))),0.0),56.0);
    vec3 lo=mix(vec3(.25,.26,.23),vec3(.16,.19,.17),dark);
    vec3 hi=mix(vec3(.96,.94,.87),vec3(.70,.73,.68),dark);
    vec3 c=mix(lo,hi,dif)+vec3(1.0,.98,.90)*spe*.55;
    return c*(.82+.18*N.y);
}
// Warm satin headshell: the same cream light as the vinyl, with a broad,
// restrained reflection instead of the shaft's sharper polished highlight.
vec3 shellSatin(float n, float dark){
    n=clamp(n,-1.0,1.0);
    vec2 N=vec2(n,sqrt(max(0.0,1.0-n*n)));
    vec2 light=normalize(vec2(.74,.67));
    float dif=max(dot(N,light),0.0);
    float spe=pow(max(dot(N,normalize(light+vec2(0.0,1.0))),0.0),22.0);
    vec3 lo=mix(vec3(.53,.52,.46),vec3(.29,.33,.28),dark);
    vec3 hi=mix(vec3(.89,.87,.78),vec3(.69,.73,.64),dark);
    return mix(lo,hi,dif)+vec3(.98,.97,.90)*spe*.11;
}

float materialNoise(vec2 uv){
    vec2 c=floor(uv),f=fract(uv);f=f*f*(3.0-2.0*f);
    vec4 v=vec4(dot(c,vec2(127.1,311.7)),dot(c+vec2(1,0),vec2(127.1,311.7)),
                dot(c+vec2(0,1),vec2(127.1,311.7)),dot(c+vec2(1,1),vec2(127.1,311.7)));
    vec4 h=fract(sin(v)*43758.5453);
    return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y)-.5;
}
float vinylTwinReflection(float angle){
    // Tangential microgrooves form two opposite reflection fans.
    float axis=cos(angle+.60);
    return pow(abs(axis),8.0)*mix(.88,1.0,smoothstep(-.08,.08,axis));
}
void main() {
    if(shadowOnly>10.5){
        // Arm-local frame in units of effective length: pivot at the origin,
        // stylus at (1,0). Fixed key light from the upper right of the glass.
        vec2 p=vec2(qt_TexCoord0.x*1.42-.26,(qt_TexCoord0.y-.5)*.32);
        float lift=phase;
        vec2 J=vec2(.860,.0527);
        vec2 td=normalize(J);
        vec2 ht=vec2(.9363,-.3512),hn=vec2(.3512,.9363);
        // Enlarge only the cartridge assembly; retain shaft length and its
        // physical connection. Apply the same geometry to the cast shadow.
        vec2 q=vec2(dot(p-J,ht),dot(p-J,hn))/1.26;
        if(shadowOnly<11.5){
            // Cast shadow on the record: softer and lighter while lifted.
            vec2 bend=vec2(.34,.018);
            float d=armSeg(p,vec2(-.073,0.0),bend)-.017;
            d=min(d,armSeg(p,bend,J)-.012);
            d=min(d,armBox(p,vec2(-.128,0.0),vec2(.055,.041),.012));
            d=min(d,length(p)-.051);
            d=min(d,armBox(q,vec2(.066,0.0),vec2(.073,.028),.011));
            d=min(d,armSeg(q,vec2(.133,.025),vec2(.106,.070))-.0042);
            d=min(d,armSeg(q,vec2(.134,-.018),vec2(.177,-.031))-.0027);
            d=min(d,armBox(q,vec2(.184,-.034),vec2(.008,.005),.0025));
            float sw=.007+.020*lift+.012*(1.0-smoothstep(.20,.90,p.x));

            float a=(1.0-smoothstep(-sw,sw,d))*mix(.25,.15,lift);
            if(studyMaterial>.5){
                // A darker contact core near the stylus and a broad low
                // opacity penumbra. Lifting widens and weakens both.
                float contact=(1.0-smoothstep(-.002,.003+.004*lift,d))
                             *smoothstep(.64,.96,p.x)*(1.0-.75*lift);
                float penumbra=1.0-smoothstep(-sw*.7,sw*1.5,d);
                a=clamp(penumbra*mix(.24,.12,lift)+contact*.16,0.0,.42);
            }
            vec3 c=mix(vec3(.30,.24,.18),vec3(.05,.06,.05),darkMode);
            if(studyMaterial>.5)c=mix(vec3(.14,.13,.105),vec3(.035,.045,.035),darkMode);

            fragColor=vec4(c*a,a)*qt_Opacity;return;
        }
        // Depth of field along the arm: the headshell shares the record's focus,
        // the shaft softens toward the out-of-frame bearing; lifting adds blur.
        float w=mix(.0013,.010,1.0-smoothstep(.62,.96,p.x))+.0035*lift;
        float la=.74,lz=.67;
        vec4 o=vec4(0.0);
        // A compact pearl plinth and bearing cap keep the heavy end of the
        // arm legible without competing with the record's label.
        float d=length(p)-.074;
        o=armOver(o,mix(vec3(.46,.44,.39),vec3(.28,.30,.28),darkMode),1.0-smoothstep(-w,w,d));
        d=length(p)-.051;
        o=armOver(o,armMetal(dot(p/.051,vec2(.32,.947))*.9,.66,.76,darkMode),1.0-smoothstep(-w,w,d));
        d=abs(length(p)-.032)-.0032;
        o=armOver(o,mix(vec3(.35,.33,.29),vec3(.19,.21,.19),darkMode),(1.0-smoothstep(-w,w,d))*.58);
        // Counterweight: a restrained knurled barrel with a recessed seam.
        d=armBox(p,vec2(-.128,0.0),vec2(.055,.041),.012);
        vec3 cc=armMetal(p.y/.041,la,lz,darkMode)*(.94+.06*sin(p.x*620.0));
        cc*=1.0-.38*exp(-pow((p.x+.096)/.0032,2.0));
        o=armOver(o,cc,1.0-smoothstep(-w,w,d));
        // Two subtly offset shaft segments create the shallow S bend of a
        // real arm while retaining a single continuous highlight.
        vec2 bend=vec2(.34,.018);
        float th=clamp(dot(p,td)/length(J),0.0,1.0);
        float tr=mix(.0170,.0128,th);
        float shaftA=armSeg(p,vec2(-.073,0.0),bend)-tr;
        float shaftB=armSeg(p,bend,J)-tr*.94;
        d=min(shaftA,shaftB);
        float tn=(td.x*p.y-td.y*p.x)/tr;
        o=armOver(o,armMetal(tn,la,lz,darkMode),1.0-smoothstep(-w,w,d));
        // Gimbal cap and a narrow collar where the shaft meets the shell.
        d=length(p)-.025;
        o=armOver(o,armMetal(dot(p/.025,vec2(.32,.947))*.85,.66,.76,darkMode),1.0-smoothstep(-w,w,d));
        d=armSeg(p,J-td*.026,J)-.0185;
        float cn=(td.x*(p.y-J.y)-td.y*(p.x-J.x))/.0185;
        o=armOver(o,armMetal(cn,la,lz,darkMode)*.92,1.0-smoothstep(-w,w,d));
        // Cartridge body tucked behind the headshell.
        d=armBox(q,vec2(.116,0.0),vec2(.041,.022),.006);
        vec3 cartridge=mix(vec3(.35,.34,.29),vec3(.18,.21,.18),darkMode)+vec3(.06,.055,.04)*max(q.y/.022,0.0);
        o=armOver(o,cartridge,1.0-smoothstep(-w,w,d));
        // Small tapered headshell: two recessed mounting slots, a lower
        // bevel and a separate finger lift make the head read at a glance.
        float hd=armBox(q,vec2(.066,0.0),vec2(.073,.028),.011);
        vec3 hc=shellSatin(q.y/.028*.60,darkMode);
        float edge=exp(-pow((hd+.004)/.0026,2.0));
        hc+=vec3(.12,.115,.095)*edge*max(q.y/.028,0.0);
        hc*=1.0-.17*edge*max(-q.y/.028,0.0);
        float slot=min(armSeg(q,vec2(.035,.0115),vec2(.078,.0115)),armSeg(q,vec2(.035,-.0115),vec2(.078,-.0115)))-.0028;
        hc*=1.0-.38*(1.0-smoothstep(-w,w,slot));
        o=armOver(o,hc,1.0-smoothstep(-w,w,hd));
        // Finger lift and the tiny cantilever/stylus under the shell.
        d=armSeg(q,vec2(.133,.025),vec2(.106,.070))-.0042;
        o=armOver(o,armMetal((q.x-.122)/.020,.46,lz,darkMode),1.0-smoothstep(-w,w,d));
        d=armSeg(q,vec2(.134,-.018),vec2(.177,-.031))-.0027;
        o=armOver(o,mix(vec3(.26,.24,.20),vec3(.12,.13,.12),darkMode),1.0-smoothstep(-w,w,d));
        d=armBox(q,vec2(.184,-.034),vec2(.008,.005),.0025);
        o=armOver(o,mix(vec3(.18,.17,.14),vec3(.07,.08,.07),darkMode),1.0-smoothstep(-w,w,d));
        fragColor=o*qt_Opacity;return;
    }
    if(shadowOnly>9.5){
        // The offset lower rim is a narrow physical sidewall. No opaque disc
        // underneath the translucent material and no luminous thickness.
        vec2 q=qt_TexCoord0-.5;float r=length(q);
        float lip=smoothstep(.478,.486,r)*(1.0-smoothstep(.497,.501,r));
        float underside=smoothstep(-.20,.34,q.y);
        float leftSide=1.0-smoothstep(-.40,.05,q.x);
        lip=max(lip,leftSide*smoothstep(.470,.480,r)*(1.0-smoothstep(.497,.501,r)));
        float a=lip*mix(.16,.43,max(underside,leftSide*.65));
        vec3 material=mix(vec3(.66,.62,.55),vec3(.39,.42,.36),darkMode)*mix(1.0,.74,max(underside,leftSide*.7));
        if(rimWidth>0.0001){
            material=vec3(.07,.075,.07)*mix(1.1,.5,max(underside,leftSide*.7));
            a=lip*mix(.40,.78,max(underside,leftSide*.65));
        }
        fragColor=vec4(material*a,a)*qt_Opacity;return;
    }
    if(shadowOnly>8.5){
        // Five separated track boundaries across broad smooth clear-vinyl bands.
        vec2 q=qt_TexCoord0-.5;float r=length(q),angle=atan(q.y,q.x);
        // Derivatives precede spatial branches so edge filtering stays stable.
        float radiusPx=fwidth(r);vec2 surfacePx=fwidth(q);
        // The printed cover hides the centre; skip all material noise there.
        if(r<phase-.02||r>.507){fragColor=vec4(0.0);return;}
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
        // Directional pearlescent vinyl; broad softbox reflection follows grooves.
        float lobe=pow(max(cos(angle+.75),0.0),18.0);
        float reflected=exp(-pow((q.x*.84+q.y*.54-.10)/.040,2.0));
        // The resin and room lighting do not depend on the current cover.
        pigment=mix(mix(vec3(.76,.76,.70),vec3(.46,.50,.43),darkMode),
                    mix(vec3(.95,.94,.88),vec3(.70,.74,.66),darkMode),.5+.5*lit);
        // Pressed translucent PVC: radial microgrooves with a little uneven
        // resin density; stationary illumination reveals the surface relief.
        // Attenuate subpixel grooves instead of letting them shimmer in motion.
        float groovePhase=r*2700.0;
        float fineGroove=sin(groovePhase)*(1.0-smoothstep(.7,3.0,fwidth(groovePhase)));
        float resin=sin(q.x*37.0+sin(q.y*29.0))*sin(q.y*41.0-q.x*17.0);
        float satin=pow(max(cos(angle+2.15),0.0),14.0);
        pigment+=vec3(.020)*fineGroove*(.35+.65*satin);
        pigment+=vec3(.022,.020,.014)*resin;
        pigment+=vec3(.22,.225,.19)*satin*(.65+.35*fineGroove);
        pigment-=vec3(.10)*trackShade;
        pigment+=vec3(.97,.98,.91)*(lobe*.34+reflected*.20)*( .55+.45*groove);

        if(studyMaterial>.5){
            float twin=vinylTwinReflection(angle);
            float gp=r*4100.0;
            float grooves=sin(gp)*(1.0-smoothstep(.7,3.0,fwidth(gp)));
            float density=materialNoise(vec2(r*540.0,angle*28.0));
            vec3 base=mix(vec3(.77,.765,.70),vec3(.39,.44,.37),darkMode);
            pigment=base*(.98+.045*lit);
            pigment+=vec3(.24,.245,.22)*twin;
            pigment+=vec3(.015,.015,.012)*grooves*(.30+.70*twin);
            pigment+=vec3(.023,.021,.017)*density;
            pigment-=vec3(.070,.068,.057)*trackShade;
            pigment+=vec3(.025)*trackLight*twin;
        }
        float a=(.72+.12*sweep)*body+.12*seat;
        vec3 rgb=pigment*a;
        // A solid warm-ivory stamped seat, using the centre label's palette.
        // Opacity belongs to the material here; the original scene-wide depth
        // of field and glass-boundary fade remain downstream and unchanged.
        if(opaqueSeat>.5&&r>phase-.002&&r<seatOuter+.003){
            float mask=smoothstep(phase-.001,phase+.001,r)
                      *(1.0-smoothstep(seatOuter-.001,seatOuter+.002,r));
            float seatLight=dot(q,vec2(.707,-.707))/max(phase+.022,.001);
            vec3 ivory=mix(vec3(.89,.86,.76),vec3(.63,.66,.57),darkMode);
            ivory*=.96+.065*seatLight;
            float innerPress=exp(-pow((r-phase-.0025)/.0015,2.0));
            float outerPress=exp(-pow((r-seatOuter+.0025)/.0018,2.0));
            ivory*=1.0-.19*innerPress-.10*outerPress;
            float rolledLip=exp(-pow((r-seatOuter+.006)/.0025,2.0));
            ivory+=vec3(.10,.095,.075)*rolledLip*(.35+.65*max(lit,0.0));
            // Restrained warm-silver sheen across a solid, finely brushed
            // insert. Broad room reflections leave the etched text legible.
            vec2 radialSeat=normalize(q+vec2(1e-5));
            float shoulderN=clamp((r-phase-.022)/.025,-.85,.85);
            vec3 seatN=normalize(vec3(radialSeat*shoulderN,sqrt(1.0-shoulderN*shoulderN)));
            vec3 seatH=normalize(normalize(vec3(.54,-.54,.70))+normalize(vec3(0,-.38,.92)));
            float metalReflection=pow(max(dot(seatN,seatH),0.0),22.0);
            float windowReflection=exp(-pow((q.x*.84+q.y*.54-.10)/.065,2.0));
            ivory=mix(ivory,vec3(.72,.72,.66)*(.90+.10*seatLight),.36);
            ivory+=vec3(.16,.16,.145)*metalReflection;
            ivory+=vec3(.10,.105,.10)*windowReflection;
            ivory-=vec3(.035)*pow(max(cos(angle-.45),0.0),10.0);
            // Tiny cast-metal pits and a weak circular brush pattern become
            // visible in the light, without a flat screen-space noise layer.
            vec2 grainUV=q*1150.0;
            float filtered=1.0-smoothstep(.7,2.0,max(surfacePx.x,surfacePx.y)*1150.0);
            float pits=materialNoise(grainUV);
            float fine=materialNoise(q*1900.0);
            ivory+=(pits*.075+fine*.020)*filtered*(.45+.55*metalReflection);
            float brushPhase=r*4800.0;
            ivory+=sin(brushPhase)*.009*(1.0-smoothstep(.7,3.0,radiusPx*4800.0));
            rgb=mix(rgb,ivory,mask);
            a=mix(a,1.0,mask);
        }

        // A fine bright lip where the clear seat meets the milky body.
        float lip=exp(-pow((r-seatOuter)/.0016,2.0))*.50*(1.0-smoothstep(.49,.50,r));
        rgb=rgb*(1.0-lip)+vec3(1.0,.99,.96)*lip;a=a+lip*(1.0-a);
        // Outer contour: survives the left defocus so the disc still reads as a record.
        float leftEdge=1.0-smoothstep(-.40,.05,q.x);
        float contour=exp(-pow((r-.489)/.0065,2.0))*(.23+.06*leftEdge);
        rgb=rgb*(1.0-contour)+vec3(.49,.46,.39)*contour;a=a+contour*(1.0-a);
        // Bright inner lip on the lit (upper-right) side so the edge separates from the cream glass.
        float rimHi=exp(-pow((r-.481)/.0024,2.0))*.50*max(lit,0.0);
        rgb=rgb*(1.0-rimHi)+vec3(1.0,.99,.96)*rimHi;a=a+rimHi*(1.0-a);
        // Contact occlusion where the printed label sits on the vinyl.
        float ao=exp(-pow((r-phase-.004)/.005,2.0))*.12*smoothstep(phase-.004,phase,r);
        rgb=rgb*(1.0-ao)+vec3(.28,.22,.16)*ao;a=a+ao*(1.0-a);

        // Rounded charcoal-PVC outer band. Same physical
        // radius, plane, light and focal fade as the existing milky vinyl.
        if(rimWidth>0.0001&&r>.498-rimWidth-2.0*radiusPx){
            float start=.498-rimWidth;
            float aa=max(radiusPx,.00045);
            float band=smoothstep(start-aa,start+aa,r)
                       *(1.0-smoothstep(.498-aa,.501+aa,r));
            float across=clamp((r-start)/rimWidth,0.0,1.0);
            // A rolled cross section: the inner shoulder faces inward,
            // the satin crown faces up, the outer bevel rolls down to a wall.
            float nr=clamp((across-.46)*2.0,-.92,.98);
            float nz=sqrt(max(0.0,1.0-nr*nr));
            vec2 radial=normalize(q+vec2(1e-5));
            vec3 normal=normalize(vec3(radial*nr,nz));
            vec3 L=normalize(vec3(.54,-.54,.70));
            vec3 V=normalize(vec3(.0,-.38,.92));
            vec3 H=normalize(L+V);
            float diffuse=max(dot(normal,L),0.0);
            float specular=pow(max(dot(normal,H),0.0),24.0);
            float broad=pow(max(dot(normal,H),0.0),5.0);
            float fresnel=pow(1.0-max(dot(normal,V),0.0),4.0);
            // Graphite resin, warm room reflection, no pure-black outline.
            vec3 carbon=vec3(.034,.038,.036)+vec3(.065,.068,.062)*diffuse;
            carbon+=vec3(.115,.120,.108)*broad;
            carbon+=vec3(.32,.31,.27)*specular*.40;
            carbon+=vec3(.11,.12,.115)*fresnel;
            // Recessed attachment seam and a small inner shoulder catchlight.
            float seam=exp(-pow((across-.07)/.055,2.0));
            carbon*=1.0-.55*seam;
            float shoulder=exp(-pow((across-.18)/.055,2.0));
            carbon+=vec3(.10,.10,.085)*shoulder*(.18+.82*max(lit,0.0));
            float groovePhase=r*3700.0;
            float micro=sin(groovePhase)*(1.0-smoothstep(.7,3.0,radiusPx*3700.0));
            float twin=vinylTwinReflection(angle);
            carbon+=vec3(.20,.205,.19)*twin*(.35+.65*nz);
            carbon+=vec3(.014)*micro*(.30+.70*twin);
            float grooveMedium=sin(r*1900.0+.30*sin(angle*13.0));
            carbon+=vec3(.009)*grooveMedium*(.25+.75*twin)
                   *(1.0-smoothstep(.7,3.0,radiusPx*1900.0));
            // Fine irregular PVC grain, softly lit rather than a flat fill.
            vec2 grainUV=q*850.0;
            vec2 cell=floor(grainUV),f=fract(grainUV);
            f=f*f*(3.0-2.0*f);
            float h00=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
            float h10=fract(sin(dot(cell+vec2(1,0),vec2(127.1,311.7)))*43758.5453);
            float h01=fract(sin(dot(cell+vec2(0,1),vec2(127.1,311.7)))*43758.5453);
            float h11=fract(sin(dot(cell+vec2(1,1),vec2(127.1,311.7)))*43758.5453);
            float grain=mix(mix(h00,h10,f.x),mix(h01,h11,f.x),f.y)-.5;
            float filterGrain=1.0-smoothstep(.7,2.0,max(surfacePx.x,surfacePx.y)*850.0);
            carbon+=vec3(.040)*grain*filterGrain*(.35+.65*diffuse);
            float pores=materialNoise(q*1600.0);
            carbon-=vec3(.014)*smoothstep(.10,.40,pores)*filterGrain;
            carbon*=1.0-.26*smoothstep(.88,1.0,across);
            rgb=mix(rgb,carbon,band*.98);
            a=mix(a,1.0,band*.98);
        }
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
        float veil=mix(.025,.12,1.0-smoothstep(.35,.88,uv.x));
        vec3 cream=mix(vec3(.965,.950,.920),vec3(.24,.27,.23),darkMode);
        colour.rgb=mix(colour.rgb,cream*colour.a,veil);
        colour.rgb=clamp(colour.rgb,vec3(0.0),vec3(colour.a));
        float fade=.32+.68*smoothstep(.08,.74,uv.x);
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
        vec4 colour=texture(artwork,uv);
        // Small independent paper centre and pressed collar. This is part of
        // the record, not an accidental circle painted into fixture artwork.
        float label=1.0-smoothstep(.062,.064,r);
        float grain=sin(q.x*2100.0)*sin(q.y*1870.0)*.004;
        float key=dot(q,vec2(.707,-.707))/.064;
        vec3 paper=mix(vec3(.89,.86,.76),vec3(.63,.66,.57),darkMode);
        paper*=.96+.065*key+grain;
        float rim=exp(-pow((r-.061)/.0014,2.0));
        paper*=1.0-.10*rim;
        colour=vec4(paper,1.0)*label+colour*(1.0-label);
        float collar=exp(-pow((r-.026)/.0020,2.0));
        vec3 metal=mix(vec3(.48,.46,.38),vec3(.95,.94,.84),smoothstep(-.022,.022,q.y));
        colour=vec4(metal,1.0)*collar+colour*(1.0-collar);
        colour=colour*hole+vec4(vec3(.16,.13,.10)*.88,.88)*(1.0-hole);
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
        float softbox=exp(-pow((q.x*.84+q.y*.54-.10)/.038,2.0));
        float arc=pow(max(cos(angle+2.15),0.0),16.0)*smoothstep(phase+.045,.47,r);
        // A softer second window, independent of the primary bow-tie reflection.
        float fill=exp(-pow((q.x*.39-q.y*.92+.19)/.115,2.0));
        float a=clamp((bands+.26*sweep+rim+softbox*.30+arc*.24+fill*.085)*vinylOnly+band*(1.0-smoothstep(.47,.50,r)),0.0,.60);
        if(studyMaterial>.5){
            float twin=vinylTwinReflection(angle);
            float wideFan=pow(abs(cos(angle+.60)),4.0);
            float gp=r*4100.0;
            float grooves=sin(gp)*(1.0-smoothstep(.7,3.0,fwidth(gp)));
            a=(.22*twin+.035*wideFan+.018*grooves*twin)*vinylOnly;
            float outerBevel=exp(-pow((r-.493)/.0018,2.0));
            a+=outerBevel*.025;
        }
        if(rimWidth>0.0001)a*=1.0-.90*smoothstep(.498-rimWidth-.001,.498-rimWidth+.001,r);
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
        // Printed label is attached to the same surface and lighting field.
        // Rotate only the artwork; illumination stays fixed in platter space.
        float illumination=.88+.13*lit;
        float varnish=exp(-pow((q.x*.84+q.y*.54-.10)/.105,2.0));
        varnish+=.35*exp(-pow((q.x*.39-q.y*.92+.19)/.16,2.0));
        // Very fine paper grain is filtered as it approaches pixel size.
        vec2 grainPhase=uv*vec2(1100.0,970.0);
        float paper=sin(grainPhase.x)*sin(grainPhase.y)*.003*(1.0-smoothstep(.7,3.0,max(fwidth(grainPhase.x),fwidth(grainPhase.y))));
        c.rgb=c.rgb*illumination+vec3(.98,.97,.90)*c.a*varnish*.065;
        c.rgb+=paper*c.a;
        c.rgb=clamp(c.rgb,vec3(0.0),vec3(c.a));
        fragColor=c*qt_Opacity;return;
    }
    // Same fixed plane as the platter, with padded bounds for feathered light.
    vec2 p=(qt_TexCoord0-.5)*(shadowOnly>.5?1.64:1.90);
    float r=length(p);
    float edge=1.0-smoothstep(.74,.82,r);
    if(shadowOnly>.5) {
        // Reuse the existing 64px cover and nine taps for a soft, displaced
        // image reflection. No additional render target or blur pass.
        vec2 reflection=(p-vec2(-.33,.19))/vec2(.95,.83);
        float footprint=1.0-smoothstep(.38,.70,length(reflection));
        vec2 reflectedUV=vec2(reflection.x,-reflection.y);
        float a=-phase*6.28318530718;
        reflectedUV=mat2(cos(a),sin(a),-sin(a),cos(a))*reflectedUV+.5;
        vec4 reflected=vec4(0.0);
        for(int j=-1;j<=1;++j)for(int i=-1;i<=1;++i)
            reflected+=texture(artwork,clamp(reflectedUV+vec2(i,j)*.17,vec2(.01),vec2(.99)))/9.0;
        float contact=exp(-pow((r-.485)/.018,2.0))*.12;
        // Keep a restrained reflected image rather than a uniformly tinted halo.
        vec3 tint=reflected.rgb/max(reflected.a,.001);
        float lum=dot(tint,vec3(.299,.587,.114));
        // Dark artwork must not create a broad black cast shadow on the glass.
        float reflectionAlpha=footprint*reflected.a*.34*mix(.25,1.0,smoothstep(.10,.65,lum));
        tint=mix(vec3(lum),tint,1.05);
        tint=mix(tint,mix(vec3(.92,.89,.80),vec3(.29,.34,.28),darkMode),.15);
        vec4 image=vec4(clamp(tint,0.0,1.0)*reflectionAlpha,reflectionAlpha);
        vec4 shadow=vec4(vec3(.25,.22,.18)*contact,contact);
        fragColor=(shadow+image*(1.0-contact))*edge*qt_Opacity;
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
