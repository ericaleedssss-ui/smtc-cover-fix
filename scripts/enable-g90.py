"""G90: uniform album magazine and honest provider popularity data."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old[:100]);p.write_text(s.replace(old,new),encoding='utf-8')
edit('Qt/src/NativeHudDetail.cpp','(item["kind"] == "playlist" || (item["kind"] == "album" && music.directory->recordBrowse))','(item["kind"] == "playlist" || item["kind"] == "album")')
edit('MusicBridge/client/items.mjs','        unavailable: (rawItem.privilege?.st ?? 0) < 0,','''        ...(kind === 'song' && Number.isFinite(rawItem.pop ?? rawItem.popularity) && (rawItem.pop ?? rawItem.popularity) >= 0 && (rawItem.pop ?? rawItem.popularity) <= 100 ? {popularity:rawItem.pop ?? rawItem.popularity} : {}),
        unavailable: (rawItem.privilege?.st ?? 0) < 0,''')
# Inspect the actual endpoint body without manufacturing a heat value.
extra="""
test('G90 real song popularity survives normalization without substituting counts',()=>{
 assert.equal(parse({id:1,name:'Actual',pop:83},'song').popularity,83);
 assert.equal(parse({id:2,name:'Legacy',popularity:0},'song').popularity,0);
 for(const raw of [{playCount:999},{pop:null},{pop:101},{pop:'80'}])assert.equal(parse({id:3,name:'Unknown',...raw},'song').popularity,undefined);
});
"""
p=Path('Qt/tests/g82-archive-client.mjs');p.write_text(p.read_text()+extra,encoding='utf-8')
print('G90: all album routes use the magazine; only real pop/popularity supplies heat.')
edit('Qt/tests/UiChecks.cpp','    check(music.player.current == playbackBefore, "browsing an album does not change playback");','''    check(music.player.current == playbackBefore, "browsing an album does not change playback");
    check(findVisual(window->contentItem(),"playlistMagazinePage")&&findVisual(window->contentItem(),"magazineHeat_0"),
          "G90 ordinary artist-album route renders the shared magazine and heat column");''')
