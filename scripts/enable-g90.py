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

# Ordinary albums now use the same real description popup as playlists. Exercise
# that entry and wheel scrolling rather than expecting the retired native reader.
edit('Qt/tests/UiChecks.cpp','''    scrollText();
    backend.action("tab:comments");''','''    {
        const auto clickAlbumControl=[&](QQuickItem *item){
            if(!item||!item->isVisible())return false;
            const auto point=item->mapToScene(QPointF(item->width()/2,item->height()/2));
            QMouseEvent move(QEvent::MouseMove,point,window->mapToGlobal(point.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);
            QCoreApplication::sendEvent(window,&move);
            for(const auto type:{QEvent::MouseButtonPress,QEvent::MouseButtonRelease}){
                QMouseEvent event(type,point,window->mapToGlobal(point.toPoint()),Qt::LeftButton,type==QEvent::MouseButtonPress?Qt::LeftButton:Qt::NoButton,Qt::NoModifier);
                QCoreApplication::sendEvent(window,&event);
            }
            settle(230);return true;
        };
        check(clickAlbumControl(findVisual(window->contentItem(),"playlistDescriptionOpen")),"G90 album description opens through its real magazine entry");
        auto *reader=findVisual(window->contentItem(),"playlistDescriptionReader");
        auto *text=findVisual(window->contentItem(),"playlistDescriptionText");
        check(reader&&reader->isVisible()&&text&&text->property("text").toString()==music.current.value("description").toString(),"G90 album popup displays the actual complete description");
        if(reader){
            check(reader->property("contentHeight").toDouble()>reader->height(),"G90 long album description retains overflow content");
            const auto point=reader->mapToScene(QPointF(reader->width()/2,reader->height()/2));
            const auto before=reader->property("contentY").toDouble();
            QMouseEvent move(QEvent::MouseMove,point,window->mapToGlobal(point.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);
            QCoreApplication::sendEvent(window,&move);settle(80);
            QWheelEvent wheel(point,window->mapToGlobal(point.toPoint()),QPoint(),QPoint(0,-120),Qt::NoButton,Qt::NoModifier,Qt::NoScrollPhase,false);
            QCoreApplication::sendEvent(window,&wheel);settle(230);
            check(reader->property("contentY").toDouble()>before,"G90 album description scrolls with the actual mouse wheel");
        }
        check(clickAlbumControl(findVisual(window->contentItem(),"playlistDescriptionClose")),"G90 album description closes before reading comments");
        check(!reader||!reader->isVisible(),"G90 album description releases the comment interaction area");
    }
    backend.action("tab:comments");''')

# The old 8-repeat description fits entirely in the larger magazine popup on
# Windows. Overflow assertions need a deliberately long fixture, not a layout
# assumption carried over from the smaller native text reader.
edit('Qt/tests/UiChecks.cpp', '记录一路走来的声音。\\n").repeated(8);', '记录一路走来的声音。\\n").repeated(item["kind"] == "album" ? 80 : 8);')
