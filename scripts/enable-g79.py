"""G79: archive playlist presentation and the existing footer heart artwork."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old[:90]);p.write_text(s.replace(old,new),encoding='utf-8')
for f in ['Qt/src/PlaylistShowcase.cpp','Qt/src/PlaylistShowcase.h','Qt/qml/PlaylistShowcase.qml','Qt/qml/RecordStack.qml']:
 shutil.copyfile(root/'maintained'/f,f)
edit('CMakeLists.txt','    Qt/src/MessageCenter.cpp','    Qt/src/PlaylistShowcase.cpp\n    Qt/src/PlaylistShowcase.h\n    Qt/src/MessageCenter.cpp')
edit('Qt/CMakeLists.txt','    qml/MessageDrawer.qml\n','    qml/PlaylistShowcase.qml\n    qml/MessageDrawer.qml\n')
edit('Qt/CMakeLists.txt','set_source_files_properties(qml/MessageDrawer.qml','set_source_files_properties(qml/PlaylistShowcase.qml PROPERTIES QT_RESOURCE_ALIAS PlaylistShowcase.qml)\nset_source_files_properties(qml/MessageDrawer.qml')
edit('Qt/src/Engine.h','#include "MessageCenter.h"','#include "MessageCenter.h"\n#include "PlaylistShowcase.h"')
edit('Qt/src/Engine.h','    Q_PROPERTY(QObject *messages READ messages CONSTANT)','    Q_PROPERTY(QObject *showcase READ showcase CONSTANT)\n    Q_PROPERTY(QObject *messages READ messages CONSTANT)')
edit('Qt/src/Engine.h','    QObject *messages() const','    QObject *showcase() const {return m_showcase;}\n    QObject *messages() const')
edit('Qt/src/Engine.h','    MessageCenter *m_messages = nullptr;','    MessageCenter *m_messages = nullptr;\n    PlaylistShowcase *m_showcase=nullptr;')
edit('Qt/src/Engine.cpp','    m_messages = new MessageCenter','    m_showcase = new PlaylistShowcase(&app->music,&app->hud,this);\n    connect(m_showcase,&PlaylistShowcase::navigate,this,&Engine::action);\n    m_messages = new MessageCenter')
edit('Qt/src/Engine.cpp','    delete m_messages; m_messages=nullptr;','    delete m_showcase;m_showcase=nullptr;\n    delete m_messages; m_messages=nullptr;')
edit('Qt/src/NativeHud.cpp','        readingPanel = QRectF(left, list ? 205 : 437,','        if(m_music->current["kind"]!="playlist"||m_music->directory)readingPanel = QRectF(left, list ? 205 : 437,')
# Suppress only the old playlist summary pixels/hits under the new shared archive panel.
edit('Qt/src/NativeHud.cpp','        const auto x = width * 0.50520833;\n        if (music.directory)', '        if(item["kind"]!="playlist"||music.directory){\n        const auto x = width * 0.50520833;\n        if (music.directory)')
edit('Qt/src/NativeHud.cpp','        text(QStringLiteral("第 %1 / %2 项")','        }\n        text(QStringLiteral("第 %1 / %2 项")')
edit('Qt/qml/Main.qml','    GlobalTools {id:globalTools;', '''    Loader {
        id:showcaseLoader;objectName:"playlistShowcaseLoader"
        active:rhine.state.mode==="archive"&&rhine.state.currentKind==="playlist"&&!rhine.state.directoryOpen&&!rhine.state.modal&&!rhine.state.lyricsMode&&!rhine.state.viewer
        x:120*root.stageScale;y:160*root.stageScale
        width:root.width-168*root.stageScale;height:680*root.stageScale;z:84
        sourceComponent:PlaylistShowcase {controller:rhine.showcase;background:backgroundLayer;unit:root.stageScale}
    }
    GlobalTools {id:globalTools;''')
# Footer keeps its count, hit target, comment entry and current-song source. Only artwork changes.
p=Path('Qt/src/NativeHudPlayer.cpp');s=p.read_text(encoding='utf-8')
s=s.replace('if (m_music->canMutate("/like")) {','if (!m_music->writeLoading && m_music->canMutate("/like")) {')
a=s.index('        const QJsonArray red = liked ?');b=s.index('        const auto redLabel',a)
s=s[:a]+'''        if(m_music->likedIDs||liked){
            const auto asset=m_host->resourceImage(liked?":/icons/song-like-on.png":":/icons/song-like-off.png");
            const auto size=QSizeF(m_host->image(asset).size()).scaled(QSizeF(24,24),Qt::KeepAspectRatio);
            image(asset,reactionX-size.width()/2,cy-size.height()/2,size.width(),size.height());
        }else centeredText("…",reactionX,cy,15);
'''+s[b:]
a=s.index('        icon(center + 218,');b=s.index('\n    }',a)
s=s[:a]+'''        const auto asset=m_host->resourceImage(":/icons/song-like-off.png");
        const auto size=QSizeF(m_host->image(asset).size()).scaled(QSizeF(24,24),Qt::KeepAspectRatio);
        image(asset,center+218-size.width()/2,cy-size.height()/2,size.width(),size.height());
        save();translate(center+218-12,cy-12);op({"path","M 3 3 L 21 21",1.6,QJsonArray{.70,.42,.42,1},QJsonArray{},0});restore();'''+s[b:]
p.write_text(s,encoding='utf-8')
print('G79: right-side archive magazine covers, working playlist operations/keys and shared footer heart assets installed.')

edit('Qt/tests/UiChecks.cpp','check(hasHudAction("open") && hasHudAction("music:playlist-info"),','check(findVisual(window->contentItem(),"showcasePlay") && findVisual(window->contentItem(),"showcaseMore"),')
fragment=(root/'maintained/G79-ui-checks.cppfrag').read_text(encoding='utf-8')
edit('Qt/tests/UiChecks.cpp','    const auto playlistPlayback = music.player.current;',fragment+'    const auto playlistPlayback = music.player.current;')

edit('Qt/qml/Main.qml','            if(globalTools.dismiss())return;','            if(showcaseLoader.item&&showcaseLoader.item.dismissTopOverlay())return;\n            if(globalTools.dismiss())return;')
edit('Qt/qml/Main.qml','            rhine.wheelInput(wheel.x / root.stageScale, wheel.y / root.stageScale, wheel.pixelDelta.y, wheel.angleDelta.y);','            if(showcaseLoader.active&&showcaseLoader.item.showSongs){showcaseLoader.item.scrollSongs(wheel);wheel.accepted=true;return;}\n            rhine.wheelInput(wheel.x / root.stageScale, wheel.y / root.stageScale, wheel.pixelDelta.y, wheel.angleDelta.y);')
