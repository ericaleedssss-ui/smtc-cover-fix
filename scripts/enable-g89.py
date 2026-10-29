"""G89: readable record rim/ripples, two-line lyrics, album route and quiet More."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old[:100]);p.write_text(s.replace(old,new),encoding='utf-8')
edit('Qt/src/NativeHudController.cpp','    } else if (name == "song-artist") {','''    } else if (name == "song-album") {
        const auto song=player.current;const auto albumID=song["albumID"].toString();
        if(!albumID.isEmpty()&&albumID!="0"){
            music.enterDirectory(MusicData::item("album",albumID,song["album"].toString(),song["artist"].toString(),song["provider"].toString(music.provider)));
            tab="overview";trackOffset=0;
        }
    } else if (name == "song-artist") {''')
edit('Qt/src/NativeHudController.cpp','    const bool destination = value == "player:now-playing" ||','    const bool destination = value == "player:song-album" || value == "player:now-playing" ||')
print('G89: actual playing-album detail route installed; transport and full lyric/detail routes preserved.')
