"""G82: archive content polish, real album track IDs, identity art and scrolling."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old[:90]);p.write_text(s.replace(old,new),encoding='utf-8')
for name in ['archive-play','archive-shuffle','archive-more']:
 shutil.copyfile(root/'maintained/Assets/icons'/f'{name}.png',f'Assets/icons/{name}.png')
shutil.copyfile(root/'maintained/Qt/qml/ArchiveActionIcon.qml','Qt/qml/ArchiveActionIcon.qml')
shutil.copyfile(root/'maintained/Qt/shaders/archiveIcon.frag','Qt/shaders/archiveIcon.frag')
edit('CMakeLists.txt','    Assets/icons/song-like-on.png','    Assets/icons/archive-play.png\n    Assets/icons/archive-shuffle.png\n    Assets/icons/archive-more.png\n    Assets/icons/song-like-on.png')
edit('CMakeLists.txt','    Qt/shaders/magazineEdgeFade.frag','    Qt/shaders/archiveIcon.frag\n    Qt/shaders/magazineEdgeFade.frag')
edit('Qt/CMakeLists.txt','    qml/ArchiveReading.qml\n','    qml/ArchiveActionIcon.qml\n    qml/ArchiveReading.qml\n')
edit('Qt/CMakeLists.txt','set_source_files_properties(qml/ArchiveReading.qml','set_source_files_properties(qml/ArchiveActionIcon.qml PROPERTIES QT_RESOURCE_ALIAS ArchiveActionIcon.qml)\nset_source_files_properties(qml/ArchiveReading.qml')
# Album detail has songs, not the playlist-only trackIds array. Preserve API order.
edit('MusicBridge/client/netease.mjs',
     "(info.trackIds || []).filter((x) => typeof x.id === 'number').map((x) => String(x.id)),",
     "album ? parsed(responseBody.songs, 'song', responseBody.privileges).map(song => song.id) : (info.trackIds || []).filter((x) => typeof x.id === 'number').map((x) => String(x.id)),")
# Keep genuine artist avatars instead of discarding them during normalization.
edit('MusicBridge/client/items.mjs','                name: artist.name,','                name: artist.name,\n                avatar: artist.img1v1Url || artist.picUrl || artist.avatarUrl || "",')
print('G82: album queues, identity avatars, content typography/actions, local wheel scrolling; cover motion unchanged.')
shutil.copyfile(root/'maintained/Qt/tests/g82-archive-client.mjs','Qt/tests/g82-archive-client.mjs')
edit('scripts/test.cjs',"    'Qt/tests/g71-collections-account.mjs',","    'Qt/tests/g71-collections-account.mjs',\n    'Qt/tests/g82-archive-client.mjs',")
# Exercise the formerly broken album tuple through the actual Windows Host/adapter.
edit('Qt/tests/UiChecks.cpp',
     '            item["trackCount"] = 10;\n            QJsonArray songs, ids;',
     '            item["trackCount"] = 10;\n            if(item["kind"]=="playlist")item["creatorAvatar"]=artworkURL;\n            QJsonArray songs, ids;')
edit('Qt/tests/UiChecks.cpp',
     '            return QJsonObject{{"body", QJsonObject{{"code", 200}, {"value", QJsonArray{item, songs, ids}}}}};',
     '            if(item["kind"]=="album"&&item["id"]=="81001")ids={};\n            return QJsonObject{{"body", QJsonObject{{"code", 200}, {"value", QJsonArray{item, songs, ids}}}}};')
