#version 440
// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy internal/app/backdrop.go fogSource, adapted from MyGo to Qt GLSL.
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;
    float time;
    float bass;
    vec4 deep;
    vec4 fog;
};
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p),u=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);}
float fbm(vec2 p){float v=0.,amp=.5;for(int i=0;i<5;++i){v+=amp*noise(p);p=p*2.03+vec2(1.7,9.2);amp*=.5;}return v;}
void main(){
    vec2 uv=qt_TexCoord0,pos=uv*area,p=pos/max(area.y,1.)*2.4;
    float t=time;vec2 rise=vec2(0,t*.1);
    vec2 q=vec2(fbm(p+rise+vec2(0,t*.04)),fbm(p+rise+vec2(5.2,1.3)-vec2(t*.05,0)));
    float f=fbm(p+rise+.9*q),bank=fbm(p*.45+rise*.6+vec2(3.7,0));
    float cloud=smoothstep(.3-.06*bass,.78,f)*(.45+.75*smoothstep(.3,.65,bank));
    float m=smoothstep(-.1,.4,uv.y)*(1.-.5*smoothstep(.65,1.,uv.y));
    vec3 c=mix(deep.rgb,fog.rgb,min(cloud*m*(.85+.35*bass),1.));
    float g=length((uv-vec2(.5,.42))*vec2(1.,1.25));c*=1.08-.45*smoothstep(.2,.85,g);
    float cell=area.y/22.;vec2 sp=(pos+vec2(0,t*cell*.9))/cell,id=floor(sp);float h=hash(id+vec2(3.1,7.7));
    if(h>.93){vec2 at=vec2(hash(id+vec2(1.3,2.9)),hash(id+vec2(8.1,4.3)))*.8+.1;float d=length((fract(sp)-at)*cell)/max(cell*.05,.7);float glint=.5+.5*sin(t*(1.5+2.*h)+h*40.);c+=vec3(.75,.82,1.)*exp(-d*d)*glint*(.25+.3*m);}
    fragColor=vec4(c,1)*qt_Opacity;
}
