"""G83: shared wheel routing, grouped archive covers, artist marquee and footer art."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old[:90]);p.write_text(s.replace(old,new),encoding='utf-8')
shutil.copyfile(root/'maintained/Qt/qml/ArtistMarquee.qml','Qt/qml/ArtistMarquee.qml')
edit('Qt/CMakeLists.txt','    qml/ArchiveActionIcon.qml\n','    qml/ArtistMarquee.qml\n    qml/ArchiveActionIcon.qml\n')
edit('Qt/CMakeLists.txt','set_source_files_properties(qml/ArchiveActionIcon.qml','set_source_files_properties(qml/ArtistMarquee.qml PROPERTIES QT_RESOURCE_ALIAS ArtistMarquee.qml)\nset_source_files_properties(qml/ArchiveActionIcon.qml')
# One existing route for ordinary archive areas, regardless of native hit targets.
edit('Qt/qml/Main.qml','    property real stageWidth:', '''    function routeWheel(wheel,source,action){
        var point=source.mapToItem(root.contentItem,wheel.x,wheel.y);
        if(archiveReading.collectionActive&&archiveReading.content&&point.y<976*root.stageScale&&!root.rightDrawerActive){
            archiveReading.content.wheelRecord(wheel);wheel.accepted=true;return;
        }
        rhine.wheelInput(point.x/root.stageScale,point.y/root.stageScale,wheel.pixelDelta.y,wheel.angleDelta.y);wheel.accepted=true;
    }
    property real stageWidth:''')
edit('Qt/qml/Main.qml','''            if(archiveReading.collectionActive&&archiveReading.content&&archiveReading.content.showSongs){archiveReading.content.scrollSongs(wheel);wheel.accepted=true;return;}
            rhine.wheelInput(wheel.x / root.stageScale, wheel.y / root.stageScale, wheel.pixelDelta.y, wheel.angleDelta.y);
            wheel.accepted = true;''','            root.routeWheel(wheel,inputLayer,"");')
edit('Qt/qml/Main.qml','''                        var p = mapToItem(inputLayer, wheel.x, wheel.y);
                        rhine.wheelInput(p.x / root.stageScale, p.y / root.stageScale, wheel.pixelDelta.y, wheel.angleDelta.y);
                        wheel.accepted = true;''','                        root.routeWheel(wheel,nativePointer,modelData.action);')
# Stop a native wheel inertia tail from the preceding view from moving this view.
edit('Qt/src/Engine.cpp','    // 鼠标滚轮一格的连续距离按帧衰减送出；列表行数仍按格立即推进。','''    if(app->hud.frame["mode"]=="archive"&&!app->music.directory&&(app->music.current["kind"]=="playlist"||app->music.current["kind"]=="album")&&m_wheelY<976&&app->hud.modal.isEmpty()&&!app->hud.queueOpen&&!app->hud.lyricsMode&&!app->hud.commentsOpen&&!app->hud.frame["viewer"].toBool()){
        m_wheelRemainingDistance=0;m_wheelDistance=0;m_wheelSteps=0;m_wheelDelta=0;m_wheelPending=false;
    }
    // 鼠标滚轮一格的连续距离按帧衰减送出；列表行数仍按格立即推进。''')
edit('Qt/src/NativeHud.cpp','            {"roamActive", m_music->player.roamActive},','            {"playerMode", m_music->player.mode},\n            {"roamActive", m_music->player.roamActive},')
edit('Qt/src/NativeHudPlayer.cpp','''        } else {
            icon(center - 156, "M 4 8''','''        } else if(player.mode!="shuffle") {
            icon(center - 156, "M 4 8''')
edit('Qt/qml/Main.qml','    GlobalTools {id:globalTools;', '''    ArchiveActionIcon {
        objectName:"playerShuffleArtwork"
        x:root.width/2-168*root.stageScale;y:1017*root.stageScale
        width:24*root.stageScale;height:width;z:14
        source:"qrc:/icons/archive-shuffle.png"
        tint:rhine.state.dark?"#b8c7a6":"#738063"
        visible:rhine.state.mode!=="boot"&&rhine.state.playerMode==="shuffle"&&!rhine.state.roamActive
    }
    GlobalTools {id:globalTools;''')
print('G83: archive group transitions/shared wheel input, real artist links/avatar retry and supplied shuffle artwork.')
