// SPDX-License-Identifier: AGPL-3.0-only
// Port of Cloudy 250da6d internal/player/{effects,reverb,spatial}.go.
#pragma once
#include <array>
#include <vector>
#include <cmath>
#include <algorithm>
#include <QString>
#include <QVariantMap>

namespace CloudyEffects {
constexpr double pi=3.14159265358979323846;
constexpr std::array<double,10> frequencies{31,62,125,250,500,1000,2000,4000,8000,16000};
struct Settings {
    bool on=false;
    std::array<double,10> bands{};
    double bass=0,treble=0,width=0,depth=0,vocal=0,loudness=0,orbit=0;
    QString room,spatial;
    bool operator==(const Settings &)const=default;
    static Settings fromMap(const QVariantMap &m) {
        Settings s;s.on=m.value("on").toBool();const auto b=m.value("bands").toList();
        auto number=[](QVariant v,double lo,double hi){const double n=v.toDouble();return std::isfinite(n)?std::clamp(n,lo,hi):0.;};
        for(int i=0;i<10;++i)s.bands[i]=number(b.value(i),-12,12);
        s.bass=number(m.value("bass"),-1,1);s.treble=number(m.value("treble"),-1,1);
        s.width=number(m.value("width"),0,1);s.depth=number(m.value("depth"),0,1);
        s.vocal=number(m.value("vocal"),0,1);s.loudness=number(m.value("loudness"),0,1);s.orbit=number(m.value("orbit"),0,1);
        s.room=m.value("room").toString();s.spatial=m.value("spatial").toString();return s;
    }
    QVariantMap map() const {QVariantList b;for(auto v:bands)b.append(v);return {{"on",on},{"bands",b},{"bass",bass},{"treble",treble},{"width",width},{"depth",depth},{"vocal",vocal},{"loudness",loudness},{"orbit",orbit},{"room",room},{"spatial",spatial}};}
};
struct Memory {double x1=0,x2=0,y1=0,y2=0;};
struct Biquad {
    double b0=1,b1=0,b2=0,a1=0,a2=0;
    double run(Memory &s,double x)const {double y=b0*x+b1*s.x1+b2*s.x2-a1*s.y1-a2*s.y2;s.x2=s.x1;s.x1=x;s.y2=s.y1;s.y1=y;return y;}
    static Biquad peak(double rate,double f,double gain){
        if(gain==0||f>=rate*.45)return {};
        const double A=std::pow(10,gain/40),w=2*pi*f/rate,alpha=std::sin(w)/(2*1.41),c=std::cos(w),a=1+alpha/A;
        return {(1+alpha*A)/a,-2*c/a,(1-alpha*A)/a,-2*c/a,(1-alpha/A)/a};
    }
    static Biquad shelf(double rate,double f,double gain,bool high){
        if(gain==0||f>=rate*.45)return {};
        const double A=std::pow(10,gain/40),w=2*pi*f/rate,c=std::cos(w),sq=2*std::sqrt(A)*std::sin(w)/2*std::sqrt(2.);
        if(high){const double a=A+1-(A-1)*c+sq;return {A*(A+1+(A-1)*c+sq)/a,-2*A*(A-1+(A+1)*c)/a,A*(A+1+(A-1)*c-sq)/a,2*(A-1-(A+1)*c)/a,(A+1-(A-1)*c-sq)/a};}
        const double a=A+1+(A-1)*c+sq;return {A*(A+1-(A-1)*c+sq)/a,2*A*(A-1-(A+1)*c)/a,A*(A+1-(A-1)*c-sq)/a,-2*(A-1+(A+1)*c)/a,(A+1+(A-1)*c-sq)/a};
    }
};
struct Line {
    std::vector<double> buf;size_t at=0;
    Line(int n=4):buf(size_t(std::max(4,n)),0){}
    void push(double x){buf[at]=x;at=(at+1)%buf.size();}
    double back(double d)const {d=std::clamp(d,1.,double(buf.size()-1));size_t i=size_t(d),n=buf.size();double a=buf[(at+n-i)%n],b=buf[(at+n-i-1)%n];return a+(b-a)*(d-i);}
};
struct Shadow {double k=1,y=0;void set(double rate,double amount){k=1-std::exp(-2*pi*20000*std::pow(1600./20000,amount)/rate);}double run(double x){y+=k*(x-y);return y;}};
struct Room {const char *id,*label;double size,damp,wet;};
inline constexpr std::array<Room,6> rooms{{{"","无",0,0,0},{"bathroom","浴室",.42,.08,.32},{"church","教堂",.95,.25,.38},{"concert","演唱会",.86,.35,.34},{"hall","大厅",.78,.45,.28},{"room","房间",.5,.55,.2}}};
struct Reverb {
    struct Comb {Line line;double store=0,feedback=0,damp=0;double run(double x){double y=line.buf[line.at];store=y*(1-damp)+store*damp;line.push(x+store*feedback);return y;}};
    std::array<std::array<Comb,8>,2> comb;
    std::array<std::array<Line,4>,2> all;
    double wet=0;
    void setup(Room r,double rate){wet=r.wet;constexpr int ct[]{1116,1188,1277,1356,1422,1491,1557,1617},ap[]{556,441,341,225};for(int ch=0;ch<2;++ch){for(int i=0;i<8;++i)comb[ch][i]={Line(int((ct[i]+ch*23)*rate/44100)+1),0,r.size*.28+.7,r.damp*.4};for(int i=0;i<4;++i)all[ch][i]=Line(int((ap[i]+ch*23)*rate/44100)+1);}}
    void run(double &l,double &r){double in=(l+r)*.015,out[2]{};for(int ch=0;ch<2;++ch){double sum=0;for(auto &c:comb[ch])sum+=c.run(in);for(auto &a:all[ch]){double b=a.buf[a.at];a.push(sum+b*.5);sum=b-sum;}out[ch]=sum;}l=l*(1-wet*.4)+out[0]*wet*3;r=r*(1-wet*.4)+out[1]*wet*3;}
};
inline double itd(double az){double a=std::abs(std::asin(std::sin(az)));return .0875/343*(a+std::sin(a));}
struct Spatial {
    double rate=48000,angle=0;Line in,l,r,s;std::array<Shadow,2> near,far;Shadow crossL,crossR,rearL,rearR;Reverb early;
    void setup(double sr){*this=Spatial{};rate=sr;in=Line(int(sr*.002)+4);l=r=s=Line(int(sr*.03)+4);crossL.set(sr,.55);crossR.set(sr,.55);rearL.set(sr,.7);rearR.set(sr,.7);early.setup({"","",.35,.6,.14},sr);}
    void orbit(double &left,double &right,double speed){angle+=2*pi/((16-12*speed)*rate);if(angle>2*pi)angle-=2*pi;double mid=(left+right)/2,side=(left-right)/2;in.push(mid);double sn=std::sin(angle),behind=std::max(0.,-std::cos(angle)),late=itd(angle)*rate,ear[2]{};for(int ch=0;ch<2;++ch){near[ch].set(rate,.25*behind);far[ch].set(rate,std::abs(sn)*.9+.25*behind);ear[ch]=((ch==1)==(sn>=0))?near[ch].run(in.back(1)):far[ch].run(in.back(1+late))*(1-.55*std::abs(sn));}left=ear[0]+side*.35;right=ear[1]-side*.35;}
    void virtualize(double &left,double &right){l.push(left);r.push(right);s.push((left-right)/2);double el=left+.62*crossR.run(r.back(itd(pi/6)*rate)),er=right+.62*crossL.run(l.back(itd(pi/6)*rate));el+=.3*rearL.run(s.back(.012*rate));er-=.3*rearR.run(s.back(.012*rate*1.3));early.run(el,er);left=el*.62;right=er*.62;}
};
class Processor {
    double rate=48000,pre=1,env=0,attack=0,release=0;
    Settings applied,target,from;int glideLeft=0;bool tuned=false;
    std::array<Biquad,12> filters;std::array<std::array<Memory,2>,12> state{};
    Biquad vocal;Memory voice;Line dl,dr;Reverb reverb;Spatial spatial;QString roomID;
    void tune(Settings e){applied=e;double most=0;for(int i=0;i<10;++i){filters[i]=Biquad::peak(rate,frequencies[i],e.bands[i]);if(frequencies[i]<rate*.45)most=std::max(most,e.bands[i]);}filters[10]=Biquad::shelf(rate,100,e.bass*9,false);filters[11]=Biquad::shelf(rate,6000,e.treble*9,true);most=std::max({most,e.bass*9+std::max({e.bands[0],e.bands[1],0.}),e.treble*9+std::max({e.bands[8],e.bands[9],0.}),e.vocal*3});pre=std::pow(10,-most*.8/20);vocal=Biquad::peak(rate,2800,e.vocal*6);if(roomID!=e.room){roomID=e.room;reverb=Reverb{};for(auto r:rooms)if(e.room==r.id&&r.wet>0)reverb.setup(r,rate);}tuned=true;}
    static Settings mix(Settings a,Settings b,double k){for(int i=0;i<10;++i)b.bands[i]=a.bands[i]+(b.bands[i]-a.bands[i])*k;
        auto at=[k](double x,double y){return x+(y-x)*k;};b.bass=at(a.bass,b.bass);b.treble=at(a.treble,b.treble);b.width=at(a.width,b.width);b.depth=at(a.depth,b.depth);b.vocal=at(a.vocal,b.vocal);b.loudness=at(a.loudness,b.loudness);b.orbit=at(a.orbit,b.orbit);return b;}
  public:
    void reset(double sr){*this=Processor{};rate=sr;attack=1-std::exp(-1/(.005*sr));release=1-std::exp(-1/(.25*sr));dl=dr=Line(int(.012*sr));spatial.setup(sr);}
    void set(Settings e,bool glide=false){if(tuned&&target==e)return;from=applied;target=e;if(glide&&tuned&&applied.on&&e.on)glideLeft=int(2*rate);else{glideLeft=0;tune(e);}}
    static double soften(double x){if(x>.9)return .9+.1*std::tanh((x-.9)/.1);if(x<-.9)return -.9-.1*std::tanh((-x-.9)/.1);return x;}
    void process(float *data,size_t frames){if(!target.on)return;for(size_t i=0;i<frames;++i){if(glideLeft>0){if(glideLeft%512==0)tune(mix(from,target,1-glideLeft/(2*rate)));if(--glideLeft==0)tune(target);}auto &e=applied;double l=data[i*2]*pre,r=data[i*2+1]*pre;for(int k=0;k<12;++k){l=filters[k].run(state[k][0],l);r=filters[k].run(state[k][1],r);}double mid=(l+r)/2,side=(l-r)/2*(1+e.width)*(1-.3*e.vocal);if(e.vocal>0)mid=vocal.run(voice,mid);l=mid+side;r=mid-side;if(e.depth>0){double a=dl.buf[dl.at],b=dr.buf[dr.at];dl.push(l);dr.push(r);l-=.45*e.depth*b;r-=.45*e.depth*a;}
        if(e.spatial=="8d")spatial.orbit(l,r,e.orbit);else if(e.spatial=="360")spatial.virtualize(l,r);
        if(reverb.wet>0)reverb.run(l,r);if(e.loudness>0){double level=std::max(std::abs(l),std::abs(r));env+=(level>env?attack:release)*(level-env);double g=std::pow(10,e.loudness*8/20),db=20*std::log10(env+1e-9);if(db>-20)g*=std::pow(10,(db+20)*(1/(1+3*e.loudness)-1)/20);l*=g;r*=g;}data[i*2]=float(soften(l));data[i*2+1]=float(soften(r));}}
};
}
