#include "AudioEffects.h"
#include <QCoreApplication>
#include <cstdio>
#include <limits>
using namespace CloudyEffects;
static double rms(const std::vector<float> &x,size_t begin=0){double sum=0;for(size_t i=begin;i<x.size();++i)sum+=x[i]*x[i];return std::sqrt(sum/std::max<size_t>(1,x.size()-begin));}
static std::vector<float> tone(double frequency){std::vector<float> x(48000*2);for(int i=0;i<48000;++i)x[i*2]=x[i*2+1]=float(.1*std::sin(2*pi*frequency*i/48000));return x;}
int main(int argc,char **argv){QCoreApplication app(argc,argv);bool ok=true;auto check=[&](bool v,const char *s){std::printf("%s: %s\n",s,v?"PASS":"FAIL");ok&=v;};
    Processor p;p.reset(48000);Settings s;auto original=tone(62),x=original;p.set(s);p.process(x.data(),x.size()/2);check(x==original,"Disabled processor preserves exact PCM");
    s.on=true;p.set(s);p.process(x.data(),x.size()/2);check(rms(x)>0&&std::abs(rms(x)-rms(original))<1e-7,"Original preset keeps quiet PCM unchanged");
    s.bands[1]=12;p.reset(48000);p.set(s);x=tone(62);p.process(x.data(),x.size()/2);double low=rms(x,10000);p.reset(48000);p.set(s);x=tone(4000);p.process(x.data(),x.size()/2);check(low>rms(x,10000)*3,"Equalizer boosts selected frequency over distant band");
    s={};s.on=true;s.spatial="8d";p.reset(48000);p.set(s);x=tone(440);p.process(x.data(),x.size()/2);double sides=0;for(size_t i=0;i<x.size();i+=2)sides+=std::abs(x[i]-x[i+1]);check(sides>10,"8D creates time-varying interaural differences from mono");
    s.spatial="360";p.reset(48000);p.set(s);x=tone(440);for(size_t i=1;i<x.size();i+=2)x[i]=0;p.process(x.data(),x.size()/2);double right=0;for(size_t i=1;i<x.size();i+=2)right+=std::abs(x[i]);check(right>10,"360 virtual speaker produces opposite-ear crossfeed");
    s.spatial.clear();s.room="church";p.reset(48000);p.set(s);x.assign(48000*2,0);x[0]=x[1]=.5;p.process(x.data(),x.size()/2);check(rms(x,2000)>1e-6,"Room produces a decaying impulse tail");
    p.reset(48000);p.set(s);x.assign(48000*2,0);p.process(x.data(),x.size()/2);check(rms(x)==0,"Seek/source reset clears room and filter memories");
    s.room.clear();s.bands.fill(12);s.bass=s.treble=s.width=s.depth=s.vocal=s.loudness=1;p.reset(48000);p.set(s);x=tone(1000);for(auto &v:x)v*=100;p.process(x.data(),x.size()/2);check(std::all_of(x.begin(),x.end(),[](float v){return std::isfinite(v)&&std::abs(v)<=1;}),"Maximum processing remains finite and bounded");
    s={};s.on=true;p.reset(48000);p.set(s);s.bass=1;p.set(s,true);x=tone(62);p.process(x.data(),x.size()/2);check(std::all_of(x.begin(),x.end(),[](float v){return std::isfinite(v);}),"Automatic tuning glide produces finite PCM");
    auto map=s.map();map["bass"]=std::numeric_limits<double>::quiet_NaN();map["width"]=99;auto valid=Settings::fromMap(map);check(valid.bass==0&&valid.width==1,"Malformed saved gains are sanitized");
    return ok?0:1;
}
