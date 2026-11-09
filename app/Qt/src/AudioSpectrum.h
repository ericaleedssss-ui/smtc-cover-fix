// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy internal/player/stream.go spectrum/feed/analyze/fft, pinned 250da6d.
// Qt adapter: mono PCM, bounded timestamp cache, any decoded channel layout.
#pragma once
#include <QMap>
#include <QVariantList>
#include <array>
#include <algorithm>
#include <cmath>
#include <complex>
#include <span>
#include <vector>

class AudioSpectrum {
public:
    static constexpr int Size=1024, Bands=24;
    using Levels=std::array<float,Bands>;
    void reset(){rate=0;used=0;accAt=-1;chunks.clear();}
    void feed(qint64 at,std::span<const float> mono,int sampleRate){
        if(sampleRate<=0)return;
        if(rate!=sampleRate){reset();rate=sampleRate;
            for(int i=0;i<Size;++i)window[i]=float(.5-.5*std::cos(2*Pi*i/(Size-1)));
            const auto lo=std::log(40.),hi=std::log(14000.);
            for(int i=0;i<=Bands;++i)edges[i]=std::clamp(int(std::exp(lo+(hi-lo)*i/Bands)*Size/rate),1,Size/2-1);
            for(int i=1;i<=Bands;++i)edges[i]=std::max(edges[i],edges[i-1]+1);
        }
        if(at<0)at=accAt<0?0:accAt+used;
        if(accAt<0||at!=accAt+used){
            chunks.clear();used=0;const auto skip=(Size-at%Size)%Size;
            if(skip>=qint64(mono.size())){accAt=-1;return;}
            mono=mono.subspan(size_t(skip));accAt=at+skip;
        }
        for(auto sample:mono){acc[used++]=std::isfinite(sample)?sample:0;
            if(used==Size){analyze(accAt/Size);accAt+=Size;used=0;}
        }
    }
    Levels atMs(double ms)const{
        if(rate<=0||ms<0)return {};
        const auto key=qint64(ms*rate/1000)/Size;
        return chunks.value(key,{});
    }
    QVariantList values(double ms,bool live)const{QVariantList result;for(auto value:live?atMs(ms):Levels{})result.append(value);return result;}
private:
    static constexpr double Pi=3.14159265358979323846;
    int rate=0,used=0;
    qint64 accAt=-1;
    std::array<float,Size> window{},acc{};
    std::array<int,Bands+1> edges{};
    std::array<std::complex<double>,Size> transform{};
    QMap<qint64,Levels> chunks;
    void analyze(qint64 chunk){
        for(int i=0;i<Size;++i)transform[i]={double(acc[i]*window[i]),0};
        for(int i=1,j=0;i<Size;++i){int bit=Size>>1;for(;j&bit;bit>>=1)j^=bit;j^=bit;if(i<j)std::swap(transform[i],transform[j]);}
        for(int size=2;size<=Size;size<<=1){auto w=std::exp(std::complex<double>(0,-2*Pi/size));
            for(int start=0;start<Size;start+=size){std::complex<double> wk(1,0);
                for(int k=0;k<size/2;++k){auto a=transform[start+k],b=transform[start+k+size/2]*wk;transform[start+k]=a+b;transform[start+k+size/2]=a-b;wk*=w;}
            }
        }
        Levels bands{};
        for(int b=0;b<Bands;++b){double sum=0;for(int k=edges[b];k<edges[b+1];++k)sum+=std::abs(transform[k]);
            auto mag=sum/(edges[b+1]-edges[b])/(Size/4);mag*=1.+double(b)/6;
            bands[b]=float(std::clamp((20*std::log10(mag+1e-9)+60)/52,0.,1.));
        }
        chunks[chunk]=bands;
        while(chunks.size()>512)chunks.erase(chunks.begin());
    }
};
