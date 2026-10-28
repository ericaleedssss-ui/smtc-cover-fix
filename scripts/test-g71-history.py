"""Execute the production collection replacement helper and parent-inheritance block."""
from pathlib import Path
import argparse,subprocess,tempfile,os
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args();src=a.source.resolve();q=a.qt_prefix.resolve();inc=q/'include/x86_64-linux-gnu/qt6';lib=q/'lib/x86_64-linux-gnu'
s=(src/'Qt/src/NativeHudMusic.cpp').read_text(encoding='utf-8');method=s[s.index('void NativeHud::browseCollection('):]
s=(src/'Qt/src/MusicDirectory.cpp').read_text(encoding='utf-8');inherit=s[s.index('    next->recordBrowse=recordBrowse;'):s.index('    directory = next;',s.index('    next->recordBrowse=recordBrowse;'))]
fixture=r'''
#include <QCoreApplication>
#include <QJsonObject>
#include <QStringList>
#include <QVector>
#include <QDebug>
#include <memory>
struct MusicDirectory {std::shared_ptr<MusicDirectory> parent;QJsonObject item,parentItem;QString returnTab="overview";int parentPhysical=0,parentLane=0;bool parentInfo=false,parentSongDetails=false,recordBrowse=false;};
struct MusicLibrary {QString provider="netease";std::shared_ptr<MusicDirectory> directory;quint64 account=1;int changes=0;quint64 accountGeneration(){return account;}void changed(){++changes;}void enterDirectory(QJsonObject item,bool recordBrowse){auto next=std::make_shared<MusicDirectory>();next->item=item;
'''
fixture+=inherit+' directory=next;}};\n'
fixture+=r'''
struct NativeHud {struct Entry{QString target;quint64 account;QString originalEntry;};QVector<Entry> m_viewBack;MusicLibrary *m_music;QString tab,m_profileItem;bool profileNavigated=false;int trackOffset=8;void closeModal(bool){}void browseCollection(QJsonObject);};
QJsonObject item(QString id,QString kind="playlist"){return {{"provider","netease"},{"kind",kind},{"id",id},{"key","netease:"+kind+":"+id}};}
void check(bool b,const char *s){if(!b)qFatal("FAIL %s",s);qInfo()<<"PASS"<<s;}
int main(int argc,char **argv){QCoreApplication app(argc,argv);MusicLibrary music;NativeHud hud;hud.m_music=&music;
 auto entry=std::make_shared<MusicDirectory>();entry->item=item("entry");auto first=std::make_shared<MusicDirectory>();first->item=item("A");first->parent=entry;first->parentPhysical=19;first->parentLane=2;first->parentItem={{"title","Entry selection"}};first->parentInfo=true;first->returnTab="recommendations";music.directory=first;hud.profileNavigated=true;hud.m_profileItem="netease:playlist:A";hud.m_viewBack={{"netease:playlist:A",1,"search results and saved position"}};
 for(const auto &id:QStringList{"B","C","D","E","F"}){hud.browseCollection(item(id));check(music.directory->item["id"]==id&&music.directory->parent==entry&&music.directory->recordBrowse,"each cover replaces its folder without growing the parent chain");check(hud.m_profileItem==music.directory->item["key"].toString(),"profile return target follows the same cover session");check(hud.m_viewBack.size()==1&&hud.m_viewBack.last().target=="netease:playlist:"+id&&hud.m_viewBack.last().originalEntry=="search results and saved position","continuous browsing keeps one original entry and only updates its matching return target");}
 check(music.directory->parentPhysical==19&&music.directory->parentLane==2&&music.directory->parentInfo&&music.directory->parentItem==first->parentItem&&music.directory->returnTab=="recommendations","replacement preserves the exact original navigation selection");
 hud.browseCollection(item("album","album"));check(music.directory->item["kind"]=="album"&&hud.m_viewBack.size()==1&&hud.m_viewBack.last().target=="netease:album:album","album targets retain the real album kind and same browse-session entry");
 auto before=music.directory;auto invalid=item("bad");invalid["provider"]="qq";hud.browseCollection(invalid);hud.browseCollection(item("bad","song"));check(music.directory==before&&hud.m_viewBack.size()==1,"invalid provider or target cannot mutate the browse session or history");
}
'''
# The real helper must follow all declarations and precede main.
body=fixture.index('int main(');code=fixture[:body]+method+fixture[body:]
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);cpp=d/'history.cpp';cpp.write_text(code,encoding='utf-8');binary=d/'checks'
 subprocess.run(['g++','-std=c++20','-fPIC','-I'+str(inc),'-I'+str(inc/'QtCore'),str(cpp),'-L'+str(lib),'-Wl,-rpath,'+str(lib),'-lQt6Core','-o',str(binary)],check=True)
 subprocess.run([str(binary)],check=True,env={**os.environ,'LD_LIBRARY_PATH':str(lib)})
