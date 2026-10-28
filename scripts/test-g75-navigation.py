"""Compile the actual return-source resolver against explicit navigation snapshots."""
from pathlib import Path
import argparse, subprocess, tempfile, os
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args()
q=a.qt_prefix.resolve();inc=q/'include/x86_64-linux-gnu/qt6';lib=q/'lib/x86_64-linux-gnu'
s=(a.source/'Qt/src/NativeHud.cpp').read_text(encoding='utf-8');start=s.index('QString NativeHud::navigationSourceName() const {');method=s[start:s.index('\nvoid NativeHud::brand()',start)]
fixture=r'''
#include <QCoreApplication>
#include <QJsonObject>
#include <QList>
#include <QDebug>
#include <memory>
struct MusicDirectory {QJsonObject item,parentItem;std::shared_ptr<MusicDirectory> parent;bool parentSongDetails=false,parentInfo=false;int parentLane=0;};
struct Discover {QString tab;};
struct MusicLibrary {std::shared_ptr<MusicDirectory> directory;bool directoryInfo=true;QJsonObject current;Discover data;Discover *discover=&data;quint64 accountGeneration()const{return 1;}};
struct NativeHud {
 struct ViewReturn {QString target,modal,mode;QJsonObject item;std::shared_ptr<MusicDirectory> directory;bool directoryInfo=false;int lane=0;quint64 account=1;};
 QList<ViewReturn> m_viewBack;MusicLibrary *m_music;QString profileFilter="created",m_profileItem;bool profileNavigated=false;
 QString navigationSourceName()const;
};
void check(bool x,const char *name){if(!x)qFatal("FAIL %s",name);qInfo()<<"PASS"<<name;}
'''
checks=r'''
int main(int argc,char **argv){QCoreApplication app(argc,argv);MusicLibrary m;NativeHud h;h.m_music=&m;m.directory=std::make_shared<MusicDirectory>();m.directory->item={{"key","target"}};
 NativeHud::ViewReturn previous;previous.target="target";h.m_viewBack={previous};check(h.navigationSourceName()=="主页","G75 home source");
 h.m_viewBack.last().modal="discover";m.discover->tab="charts";check(h.navigationSourceName()=="排行榜","G75 chart source");
 h.m_viewBack.last().modal="profile";h.profileFilter="collected";check(h.navigationSourceName()=="我的收藏","G75 collection source");
 h.m_viewBack.last().modal="search";check(h.navigationSourceName()=="搜索结果","G75 search source");
 h.m_viewBack.last().modal="";h.m_viewBack.last().mode="detail";h.m_viewBack.last().item={{"kind","song"},{"title","Original song"}};
 check(h.navigationSourceName()=="Original song","G75 actual source song title");
 for(int i=0;i<6;++i){const auto key=QString("next%1").arg(i);m.directory->item["key"]=key;h.m_viewBack.last().target=key;check(h.navigationSourceName()=="Original song"&&h.m_viewBack.size()==1,"G75 repeated turns retain the same source snapshot");}
 h.m_viewBack.clear();h.profileNavigated=true;h.m_profileItem=m.directory->item["key"].toString();check(h.navigationSourceName()=="我的收藏","G75 profile-return source survives record browsing");
 h.profileNavigated=false;h.m_profileItem.clear();m.directory->parentSongDetails=true;m.directory->parentItem={{"title","Parent song"}};check(h.navigationSourceName()=="Parent song","G75 directory fallback preserves actual parent song");
}
'''
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);cpp=d/'navigation.cpp';cpp.write_text(fixture+method+checks,encoding='utf-8');binary=d/'checks'
 subprocess.run(['g++','-std=c++20','-fPIC','-I'+str(inc),'-I'+str(inc/'QtCore'),str(cpp),'-L'+str(lib),'-Wl,-rpath,'+str(lib),'-lQt6Core','-o',str(binary)],check=True)
 subprocess.run([str(binary)],check=True,env={**os.environ,'LD_LIBRARY_PATH':str(lib)})
