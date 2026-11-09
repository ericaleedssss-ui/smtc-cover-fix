#version 440
// Inset SDF displacement adapted from Shu Ding, copyright (c) 2025, MIT.
// Full license and provenance: NOTICE and licenses/liquid-glass/.
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 panelSize;
    float paddingWidth;
    float cornerRadius;
    float darkMode;
    float refraction;
    float frosting;
    float tintAmount;
    float offsetCap;
    float rimStrength;
    float readingComfort;
    float customContour;
    vec3 contour;
    float shadowStrength;
};
layout(binding=1) uniform sampler2D blurred;
layout(binding=2) uniform sampler2D scene;
layout(binding=3) uniform sampler2D silhouette;
float rounded(vec2 p,vec2 halfSize,float r){
    vec2 q=abs(p)-halfSize+r;
    return min(max(q.x,q.y),0.)+length(max(q,0.))-r;
}
float satSmooth(float a,float b,float t){t=clamp((t-a)/(b-a),0.,1.);return t*t*(3.-2.*t);}
float panelDistance(vec2 p,float r){
    vec2 uv=p/max(panelSize,vec2(1.));
    float bow=pow(max(0.,sin(clamp(uv.x,0.,1.)*3.14159265)),3.);
    float top=contour.x*bow,bottom=contour.y*bow;
    vec2 size=panelSize+vec2(-contour.z*1.5*sin(clamp(uv.y,0.,1.)*3.14159265),bottom-top);
    return rounded(p-vec2(panelSize.x*.5,panelSize.y*.5+(top+bottom)*.5),size*.5,r);
}
void main(){
    vec2 canvas=panelSize+2.*paddingWidth;
    vec2 p=qt_TexCoord0*canvas-paddingWidth;
    vec2 uv=p/max(panelSize,vec2(1.));
    float r=min(cornerRadius,min(panelSize.x,panelSize.y)*.5);
    float d=panelDistance(p,r);
    float mask=1.-smoothstep(-.75,.75,d);
    if(customContour>.5)mask=texture(silhouette,qt_TexCoord0).a;
    vec2 ix=uv-.5;
    float insetDistance=rounded(ix,vec2(.3,.2),.6);
    float displace=satSmooth(.8,0.,insetDistance-.15);
    float scaled=satSmooth(0.,1.,displace);
    vec2 rawOffset=ix*(scaled-1.)*panelSize;
    vec2 offset=clamp(rawOffset,vec2(-offsetCap),vec2(offsetCap))*refraction;
    vec2 warped=clamp((p+paddingWidth+offset)/canvas,vec2(0.),vec2(1.));
    vec2 n=vec2(panelDistance(p+vec2(.5,0),r)-panelDistance(p-vec2(.5,0),r),
                panelDistance(p+vec2(0,.5),r)-panelDistance(p-vec2(0,.5),r));
    n/=max(length(n),.0001);
    float depth=max(-d,0.);
    float optical=exp(-depth/4.);
    vec2 dispersion=n*.70*optical/canvas;
    vec3 clear=vec3(texture(scene,warped+dispersion).r,texture(scene,warped).g,texture(scene,warped-dispersion).b);
    // A broad continuous reading zone, with the physical rim left clear.
    float quiet=readingComfort*(1.-smoothstep(.32,.80,uv.x))*smoothstep(3.,18.,depth);
    vec3 color=mix(clear,texture(blurred,warped).rgb,mix(frosting*(1.-.65*optical),.98,quiet));
    color=(color-.5)*1.06+.5;
    color=mix(color,mix(vec3(.98,.97,.935),vec3(.10,.13,.105),darkMode),max(tintAmount,darkMode*.42));
    color=mix(color,mix(vec3(.955,.945,.915),vec3(.105,.135,.115),darkMode),quiet*.70);
    float rim=exp(-pow((d+1.0)/.85,2.));
    float highlight=.26+.57*max(0.,dot(n,normalize(vec2(-.5,-1.))));
    color=mix(color,vec3(1.),rim*highlight*rimStrength);
    float lower=exp(-pow((uv.y-1.03)/.24,2.));
    color=mix(color,mix(vec3(.99,.99,.97),vec3(.7,.77,.65),darkMode),lower*.075);
    color*=1.-exp(-pow((depth-3.)/1.7,2.))*.055;
    float shadowDistance=panelDistance(p-vec2(0.,4.),r);
    float shadow=shadowStrength*.16*exp(-pow(max(shadowDistance,0.),2.)/70.)*(1.-mask);
    // Exact animated hover silhouette owns its own matching vector shadow.
    if(customContour>.5)shadow=0.;
    fragColor=(vec4(clamp(color,0.,1.)*mask,mask)+vec4(vec3(.13,.15,.11)*shadow,shadow))*qt_Opacity;
}
