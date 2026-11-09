#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 panelSize;
    float paddingWidth;
    float cornerRadius;
    float darkMode;
    float shadowStrength;
};
layout(binding=1) uniform sampler2D blurred;
layout(binding=2) uniform sampler2D scene;
float rounded(vec2 p,vec2 halfSize,float radius) {
    vec2 q=abs(p)-halfSize+radius;
    return length(max(q,0.0))+min(max(q.x,q.y),0.0)-radius;
}
float gaussian(float value) {
    return exp(-value*value);
}
void main() {
    vec2 canvas=panelSize+vec2(2.0*paddingWidth);
    vec2 p=qt_TexCoord0*canvas-paddingWidth;
    vec2 center=p-panelSize*.5;
    float radius=min(cornerRadius,min(panelSize.x,panelSize.y)*.5);
    float d=rounded(center,panelSize*.5,radius);
    float mask=1.0-smoothstep(-.8,.8,d);
    float depth=max(-d,0.0);
    float bevel=clamp(min(panelSize.x,panelSize.y)*.12,8.0,22.0);
    float edge=exp(-depth/bevel);
    // The optical normal follows the rounded contour, including straight sides.
    vec2 gradient=vec2(
        rounded(center+vec2(.5,0),panelSize*.5,radius)-rounded(center-vec2(.5,0),panelSize*.5,radius),
        rounded(center+vec2(0,.5),panelSize*.5,radius)-rounded(center-vec2(0,.5),panelSize*.5,radius));
    vec2 n=gradient/max(length(gradient),.0001);
    float opticalEdge=exp(-depth/4.5);
    vec2 refracted=qt_TexCoord0+n*edge*4.0/canvas;
    vec3 soft=texture(blurred,refracted).rgb;
    vec2 dispersion=n*2.6*opticalEdge/canvas;
    vec3 sharp=vec3(texture(scene,refracted+dispersion).r,
                    texture(scene,refracted).g,
                    texture(scene,refracted-dispersion).b);
    vec3 base=mix(soft,sharp,opticalEdge*.58);
    vec3 tint=mix(vec3(.97,.96,.92),vec3(.11,.13,.12),darkMode);
    base=mix(base,tint,mix(.16,.34,darkMode));
    vec2 uv=p/max(panelSize,vec2(1.0));
    // A broad reflection rises from the lower surface into the body. Its width
    // scales with the panel, so both the small card and reading panel have depth.
    // Keep the centre quiet: this is a reflected environment, not a bright spot.
    float lower=gaussian((uv.y-1.03)/.34);
    float lateral=.68+.32*gaussian((uv.x-.52)/.55);
    float reflection=lower*lateral*mix(.18,.23,darkMode);
    float upper=gaussian((uv.y-.18)/.28);
    base*=1.0-upper*mix(.065,.095,darkMode);
    base=mix(base,vec3(.98,.985,.97),reflection);
    // A shallow inner concavity separates the fine rim from the soft reflection.
    float inner=gaussian((depth-bevel*.46)/(bevel*.36));
    base*=1.0-inner*.035*max(-n.y,0.0);
    // Broad environmental reflections taper along the contour instead of
    // outlining it uniformly. A quiet base retains the shape between glints.
    float topGlint=gaussian((uv.x-.19)/.26)*smoothstep(.25,.8,-n.y);
    float rightGlint=gaussian((uv.y-.62)/.30)*smoothstep(.25,.8,n.x);
    float bottomGlint=gaussian((uv.x-.73)/.32)*smoothstep(.25,.8,n.y);
    float leftGlint=gaussian((uv.y-.30)/.26)*smoothstep(.25,.8,-n.x);
    float glint=clamp(topGlint*.85+rightGlint*.42+bottomGlint*.72+leftGlint*.36,0.0,1.0);
    float rimWidth=mix(.45,1.15,glint);
    float rim=gaussian((d+.9)/rimWidth);
    float shoulder=gaussian((depth-3.0)/2.4)*glint;
    base=mix(base,vec3(.99,.99,.975),shoulder*.12);
    float interiorSweep=gaussian((uv.y+.26*uv.x-.13)/.15)*.025;
    interiorSweep+=gaussian((uv.y-.22*uv.x-.86)/.21)*.018;
    base=mix(base,vec3(.99,.99,.975),interiorSweep);
    float direction=dot(n,normalize(vec2(-.35,1.0)));
    base=mix(base,vec3(1.0),rim*(.10+.64*glint));
    float innerRim=gaussian((d+2.35)/.85);
    base*=1.0-innerRim*.055*(.55+.45*max(-direction,0.0));
    float shadowDistance=rounded(center-vec2(0.0,4.0),panelSize*.5,radius);
    float shadow=shadowStrength*.12*exp(-max(shadowDistance,0.0)*max(shadowDistance,0.0)/65.0)*(1.0-mask);
    fragColor=vec4(base*mask,mask)+vec4(vec3(.12,.13,.10)*shadow,shadow);
    fragColor*=qt_Opacity;
}
