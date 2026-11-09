#version 440
// Qt adapter of MyGo f7032a2cc755 plugins/glass/glass.glsl + paneMaterial(Clear).
// Copyright MyGo contributors, MIT. Original source and license retained.
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 panelSize;
    float paddingWidth;
    float uiScale;
    float pixelWidth;
    vec2 railOffset;
    vec2 railSize;
    float railFraction;
    float railThickness;
    float railFeather;
    vec4 playedColor;
    vec4 unplayedColor;
};
layout(binding=1) uniform sampler2D scene;
float sd(vec2 p){
    float r=panelSize.y*.5;vec2 q=abs(p-panelSize*.5)-(panelSize*.5-r);
    return min(max(q.x,q.y),0.)+length(max(q,0.))-r;
}
float glassLens(float t,float bezel){
    if(bezel<=0.||t>=bezel)return 0.;
    float u=1.-max(t,0.)/bezel;
    float v=1.-u*u*u*u;
    float a=sqrt(v*sqrt(v)),b=u*u*u,n=sqrt(a*a+b*b);
    float s=b/n,c=a/n,st=s/1.5,ct=sqrt(1.-st*st);
    return (s*ct-c*st)/(c*ct+s*st)/1.1180340;
}
vec2 glassNormal(vec2 p){
    vec2 h=panelSize*.5,q=p-h;
    float r=min(panelSize.y*.5*1.5,min(h.x,h.y));
    vec2 a=abs(q)-(h-r);
    if(a.x>0.||a.y>0.){vec2 m=max(a,vec2(0.));return sign(q)*m/max(length(m),.00001);}
    return a.x>a.y?vec2(sign(q.x),0.):vec2(0.,sign(q.y));
}
vec3 sampleUnder(vec2 p){
    vec2 uv=clamp((p+paddingWidth)/(panelSize+2.*paddingWidth),vec2(0.),vec2(1.));
    vec2 r=p+railOffset;
    vec3 c=texture(scene,uv).rgb;
    // The Canvas's live geometry/color, evaluated before refraction. This
    // avoids flattening a thin transparent Canvas into a full-width texture.
    float fade=railFeather;
    float ends=clamp(r.x/max(fade,.001),0.,1.)*clamp((railSize.x-r.x)/max(fade,.001),0.,1.);
    float core=1.-smoothstep(railThickness*.5-.35*uiScale,railThickness*.5+.35*uiScale,abs(r.y-railSize.y*.5));
    float a=core*ends;
    c=mix(c,unplayedColor.rgb,unplayedColor.a*a);
    float played=1.-smoothstep(railSize.x*railFraction-.3*uiScale,railSize.x*railFraction+.3*uiScale,r.x);
    return mix(c,playedColor.rgb,playedColor.a*a*played);
}
void main(){
    vec2 p=qt_TexCoord0*(panelSize+2.*paddingWidth)-paddingWidth;
    float d=sd(p),t=max(-d,0.),bezel=min(36.*uiScale,panelSize.y*.5);
    vec2 n=glassNormal(p),q=p-n*(1.6*bezel*glassLens(t,bezel));
    // Clear's sigma is one DIP. Small fixed Gaussian avoids pane frost.
    vec3 c=vec3(0.);float weights[3]=float[3](.2740686,.4518628,.2740686);
    for(int y=-1;y<=1;++y)for(int x=-1;x<=1;++x)c+=sampleUnder(q+vec2(x,y)*uiScale)*weights[x+1]*weights[y+1];
    // glassTone with low=.125 high=1.082 curve=1 saturation=1.
    c=clamp(vec3(.125)+c*(1.082-.125),0.,1.);
    float rim=.35*exp(-pow(t/pixelWidth,2.));
    c+=(abs(n.y)-c)*rim;
    float mask=1.-smoothstep(-pixelWidth*.5,pixelWidth*.5,d);
    // Cloudy scrubber's separate 0,1,6 black 25% shadow.
    float shadow=.25*exp(-pow(max(sd(p-vec2(0.,uiScale)),0.)/(3.*uiScale),2.)*.5)*(1.-mask);
    fragColor=vec4(c*mask,mask+shadow)*qt_Opacity;
}
