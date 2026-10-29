"""Real production QML event tests with a 4,080-row fixture model (no account/network).
Full C++/Windows/real-account validation is separate; fixture art is never installed.
"""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import sys,tempfile,shutil,subprocess
from PySide6.QtCore import QObject,Signal,Property,Slot,QAbstractListModel,QModelIndex,QUrl,QPointF,QPoint,Qt,QResource
from PySide6.QtGui import QGuiApplication,QFontDatabase,QImage,QPainter,QColor,QLinearGradient,QFont,QWheelEvent
from PySide6.QtQuick import QQuickView
from PySide6.QtQml import QQmlProperty
from PySide6.QtTest import QTest
src=Path(sys.argv[1]).resolve();repo=Path(__file__).resolve().parents[1]
app=QGuiApplication([])
f=QFontDatabase.addApplicationFont(str(src/'Assets/fonts/RhineMiSans-regular.otf'))
font=QFontDatabase.applicationFontFamilies(f)[0]
QFontDatabase.addApplicationFont(str(src/'Assets/fonts/RhineMiSans-demibold.otf'))
class Controller(QAbstractListModel):
    changed=Signal();menuChanged=Signal()
    def __init__(self,images):
        super().__init__();self.actions=[];self.position=0.;self.q='';self.f='all';self.t='songs';self.menu={'visible':False};self.selection=set();self.images=images;self.ids=list(range(4080))
        self.meta=dict(key='netease:playlist:1',id='1',title='PROJECT / 一些缓慢生长的声音',artist='离线交互测试',creatorID='42',createdDate='2024-06-18',total=4080,loaded=4080,cover=images[0],description='留给午后、窗边和一个人的声音。\n不赶时间地听完一张唱片。',subscribedCount=12340,commentCount=236,editable=True,canSubscribe=True,subscribed=False,canCollect=True,canDownload=True,more=False,loading=False)
        self.likesKnown=True;self.detailCoverRefresh=False;self.catalogIndex=0;self.catalog=[self.meta.copy()]+[dict(key=('netease:album:' if i==7 else 'netease:playlist:')+str(i+1),id=str(i+1),title='收藏 '+str(i+1),kind='album' if i==7 else 'playlist',artist='真实测试创建者',cover=images[i%4]) for i in range(1,8)]
    @property
    def rear(self):return [{**self.catalog[(self.catalogIndex+d)%len(self.catalog)],"side":d} for d in (-1,1)]
    @Slot(int,result='QVariantMap')
    def recordNeighbour(self,offset):return self.catalog[(self.catalogIndex+offset)%len(self.catalog)]
    @Slot()
    def prepareRecords(self):self.actions.append(("records-more",))
    def rowCount(self,parent=QModelIndex()):return 0 if parent.isValid() else len(self.ids)
    def roleNames(self):return {257:b'track',258:b'sourceIndex',259:b'chosen',260:b'heart',261:b'heartKnown'}
    def data(self,index,role=Qt.DisplayRole):
        n=self.ids[index.row()]
        if role==257:return dict(id=str(60000+n),identity='netease:'+str(60000+n),kind='song',provider='netease',title=['Maia','Go!','緩やかな日々','Dawn Chorus','shanty'][n%5],artist=['CANTOMA','Public Service Broadcasting','mouse on the keys','Flying Lotus','Slowdive'][n%5],album=['Out of Town','The Race for Space','an anxious object','Cosmogramma','everything is alive'][n%5],albumID='44',cover=self.images[n%4],durationLabel='04:12',popularity=83 if n%3==0 else (0 if n%3==2 else None))
        if role==258:return n
        if role==259:return n in self.selection
        if role==260:return n%3==0
        if role==261:return self.likesKnown
    @Property(bool,notify=changed)
    def active(self):return True
    @Property('QVariantMap',notify=changed)
    def info(self):return {**self.meta,"visibleCount":len(self.ids),"searchComplete":True,"recordCount":len(self.catalog),"recordPosition":self.catalogIndex+1,"recordsMore":False}
    @Property('QVariantList',notify=changed)
    def covers(self):return self.rear
    @Property('QVariantList',notify=changed)
    def socialRows(self):return []
    @Property(str,notify=changed)
    def session(self):return self.meta['key']
    @Property(str,notify=changed)
    def query(self):return self.q
    @Property(str,notify=changed)
    def filter(self):return self.f
    @Property(str,notify=changed)
    def tab(self):return self.t
    @Property(float,notify=changed)
    def scrollPosition(self):return self.position
    @Property(str,notify=changed)
    def status(self):return ''
    @Property(int,notify=changed)
    def selectedCount(self):return len(self.selection)
    @Property(bool,notify=changed)
    def busy(self):return False
    @Property(bool,notify=changed)
    def downloading(self):return False
    @Slot()
    def cancelDownload(self):self.actions.append(('cancel-download',))
    @Property(int,notify=changed)
    def removalCount(self):return 0
    @Property('QVariantMap',notify=menuChanged)
    def songMenu(self):return self.menu
    @Slot(str,float)
    def savePosition(self,key,y):self.position=y
    @Slot(int,result=int)
    def viewRow(self,n):return n
    @Slot(str)
    def search(self,q):
        self.q=q;self.actions.append(('search',q));self.beginResetModel()
        haystacks=['Maia CANTOMA Out of Town','Go! Public Service Broadcasting The Race for Space','緩やかな日々 mouse on the keys an anxious object','Dawn Chorus Flying Lotus Cosmogramma','shanty Slowdive everything is alive']
        self.ids=[n for n in range(4080) if q.lower() in haystacks[n%5].lower()];self.endResetModel();self.changed.emit()
    @Slot(str)
    def setFilter(self,f):self.f=f;self.actions.append(('filter',f));self.changed.emit()
    @Slot(str)
    def setTab(self,t):self.t=t;self.changed.emit()
    @Slot()
    def more(self):self.actions.append(('more',))
    @Slot(str)
    def openCover(self,k):
        self.actions.append(('open',k))
        self.beginResetModel();self.catalogIndex=next(i for i,x in enumerate(self.catalog) if x['key']==k)
        self.meta={**self.meta,**self.catalog[self.catalogIndex]};
        if self.detailCoverRefresh:self.meta["cover"]+="?detail-size=1024"
        self.position=0;self.q='';self.ids=list(range(4080));self.endResetModel();self.changed.emit()

    @Slot(str,str)
    def rowAction(self,op,key):self.actions.append((op,key))
    @Slot(bool)
    def selectAll(self,on):self.selection={0,1} if on else set();self.changed.emit()
    @Slot(str)
    def bulk(self,op):self.actions.append(('bulk',op))
    @Slot(str,int,str,float,float)
    def showSongMenu(self,scope,index,key,x,y):
        self.actions.append(('context',scope,index,key));self.menu=dict(visible=True,x=x,y=y,title='点击的歌曲',comments=10335,canRemove=True,canCollect=True,canDownload=True,playable=True);self.menuChanged.emit()
    @Slot(str,float,float)
    def showHitMenu(self,hit,x,y):self.actions.append(('hit',hit))
    @Slot(str)
    def songAction(self,op):self.actions.append(('song',op));self.closeMenu()
    @Slot()
    def closeMenu(self):self.menu={'visible':False};self.menuChanged.emit()
    @Slot(str,bool)
    def setSubscribed(self,key,enabled):
        self.actions.append(('subscribe',key,enabled))
        if key==self.meta['key']:self.meta['subscribed']=enabled;self.changed.emit()
    @Slot()
    def retryLikes(self):self.actions.append(("retry-likes",))
    @Slot()
    def share(self):self.actions.append(('share',))
    @Slot()
    def cancelRemoval(self):pass
    @Slot()
    def removeConfirmed(self):pass
class Spy(QObject):
    changed=Signal()
    def __init__(self,c):super().__init__();self.c=c;self.actions=[];self.data=dict(mode='detail',directoryOpen=True,dark=False,reduced=False,modal='',queueOpen=False,returnSource='我的收藏',accountUID='42',accountName='Erica_P',accountProvider='netease',accountProviderName='网易云音乐',accountMember='VIP',accountAvatar=c.images[0])
    @Property('QVariantMap',notify=changed)
    def state(self):return self.data
    @Property(QObject,constant=True)
    def magazine(self):return self.c
    @Slot(str)
    def action(self,s):self.actions.append(s)
def find(item,name):
    if item.objectName()==name:return item
    for child in item.childItems():
        found=find(child,name)
        if found is not None:return found
    return None
def click(view,item,button=Qt.LeftButton,point=None):
    assert item is not None
    if point is None:point=QPointF(item.width()/2,item.height()/2)
    point=item.mapToScene(point).toPoint();QTest.mouseMove(view,point);QTest.mouseClick(view,button,Qt.NoModifier,point);QTest.qWait(120)
def checkColumnAlignment(v,root,c):
    for kind in ('playlist','album'):
        c.meta['kind']=kind;c.changed.emit();QTest.qWait(100)
        listing=find(root,'magazineTrackList');listing.setProperty('contentY',listing.property('startY'));QTest.qWait(100)
        for header,cell in [('Title','magazineTitle_0'),('Artist','magazineArtist_0'),('Secondary','magazineHeat_0' if kind=='album' else 'magazineAlbum_0'),('Heart','magazineHeart_0'),('Duration','magazineDuration_0')]:
            a=find(root,'magazineHeader'+header);b=find(root,cell);assert a is not None and b is not None,(kind,header)
            ax=a.mapToScene(QPointF(a.width()/2,0)).x();bx=b.mapToScene(QPointF(b.width()/2,0)).x()
            assert abs(ax-bx)<.5,(kind,header,ax,bx)
        if kind=='album':
            artist=find(root,'magazineArtist_0');heart=find(root,'magazineHeart_0');heat=find(root,'magazineHeat_0')
            middle=(artist.mapToScene(QPointF(artist.width()/2,0)).x()+heart.mapToScene(QPointF(heart.width()/2,0)).x())/2
            assert abs(heat.mapToScene(QPointF(heat.width()/2,0)).x()-middle)<.5
            assert heat.mapToScene(QPointF()).x()>artist.mapToScene(QPointF(artist.width(),0)).x()
            assert heat.mapToScene(QPointF(heat.width(),0)).x()<heart.mapToScene(QPointF()).x()
    c.meta['artistAvatar']=c.images[0];c.changed.emit();QTest.qWait(100)
    avatar=find(root,'magazineArtistAvatar');assert avatar.isVisible() and avatar.property('source').toString()==c.images[0]

def checkAlbumDescription(v,root,c,long=True):
    # Match the Windows self-test's actual Chinese fixture rather than a separate
    # English-only paragraph. A short description should fit without scrolling.
    native='十首歌，十次心动。\n无数个清晨、无数个深夜、无数个黄昏，记录一路走来的声音。\n'
    c.meta['description']=native*80 if long else '这是一段完整的简短专辑简介。'
    c.changed.emit();QTest.qWait(100)
    click(v,find(root,'playlistDescriptionOpen'));QTest.qWait(230)
    reader=find(v.contentItem(),'playlistDescriptionReader');text=find(v.contentItem(),'playlistDescriptionText')
    assert reader is not None and reader.isVisible() and text.property('text')==c.meta['description'],(v.width(),v.height(),reader.isVisible() if reader else None,find(root,'playlistDescriptionOpen').mapToScene(QPointF(0,0)),find(root,'magazineTrackList').property('contentY'))
    assert (reader.property('contentHeight')>reader.height())==long,(reader.property('contentHeight'),reader.height(),long)
    point=reader.mapToScene(QPointF(reader.width()/2,reader.height()/2));before=reader.property('contentY')
    listing=find(root,'magazineTrackList');listBefore=listing.property('contentY')
    QTest.mouseMove(v,point.toPoint());QTest.qWait(80)
    event=QWheelEvent(point,v.mapToGlobal(point.toPoint()),QPoint(),QPoint(0,-120),Qt.NoButton,Qt.NoModifier,Qt.NoScrollPhase,False)
    QGuiApplication.sendEvent(v,event);QTest.qWait(230)
    assert listing.property('contentY')==listBefore,('description wheel leaked to tracks',listBefore,listing.property('contentY'))
    after=reader.property('contentY')
    assert (after>before) if long else after==before,(before,after,reader.property('contentHeight'),reader.height(),point,long)
    click(v,find(v.contentItem(),'playlistDescriptionClose'));QTest.qWait(230);assert not reader.isVisible()

with tempfile.TemporaryDirectory() as tmp:
    d=Path(tmp);images=[]
    # Clearly synthetic, deterministic TEST sleeves. Production only reads account collections.
    for i,colors in enumerate([('#14292a','#cf5e3c'),('#283653','#d7b783'),('#b9af9e','#536b54'),('#43475e','#b3a7ba')]):
        image=QImage(640,640,QImage.Format_RGB32);p=QPainter(image);g=QLinearGradient(0,0,640,640);g.setColorAt(0,QColor(colors[0]));g.setColorAt(1,QColor(colors[1]));p.fillRect(image.rect(),g);p.setPen(QColor('#cfc9b5'));p.setFont(QFont(font,26));p.drawText(40,70,'OFFLINE / COLLECTION '+str(i+1));p.setPen(QColor('#90cfc9b5'));p.drawEllipse(75+i*10,150,460,460);p.end();path=d/('sleeve'+str(i)+'.png');image.save(str(path));images.append(QUrl.fromLocalFile(str(path)).toString())
    for name in ('ArtistMarquee','RhineIcon','GlobalTools','RecordStack','PlaylistMagazine','SongContextMenu','LiquidGlass','PlaylistSearch','SongHeart'):
        origin=repo/'maintained/Qt/qml'/f'{name}.qml';shutil.copyfile(origin if origin.exists() else src/'Qt/qml'/f'{name}.qml',d/f'{name}.qml')
    entries=[]
    for name in ('magazineEdgeFade','liquidGlass','softEdgeFade'):
        origin=repo/'maintained/Qt/shaders'/f'{name}.frag'
        if not origin.exists():origin=src/'Qt/shaders'/f'{name}.frag'
        out=d/f'{name}.frag.qsb'
        subprocess.run(['/root/.local/bin/pyside6-qsb','--glsl','150,300es','--hlsl','50','--msl','12','-o',str(out),str(origin)],check=True)
        entries.append('<file alias="'+name+'.frag.qsb">'+str(out)+'</file>')
    qrc=d/'icons.qrc';qrc.write_text('<RCC><qresource prefix="/icons">'+''.join('<file alias="'+name+'">'+str(repo/'maintained/Assets/icons'/name)+'</file>' for name in ('song-like-on.png','song-like-off.png'))+'</qresource><qresource prefix="/shaders">'+''.join(entries)+'</qresource></RCC>')
    subprocess.run(['/root/.local/bin/pyside6-rcc','--binary','-o',str(d/'icons.rcc'),str(qrc)],check=True);assert QResource.registerResource(str(d/'icons.rcc'))
    (d/'Harness.qml').write_text('''import QtQuick
Item {id:root;width:1400;height:900
 Rectangle {id:bg;anchors.fill:parent;color:rhine.state.dark?"#252b23":"#e9e7df"}
 Text {x:100*root.height/1080;y:59*root.height/1080;text:"RHINE / 音乐资料库";font.family:rhineFontFamily;font.pixelSize:14*root.height/1080;color:"#384333"}
 Text {x:100*root.height/1080;y:80*root.height/1080;text:rhine.state.returnSource;font.family:rhineFontFamily;font.pixelSize:11*root.height/1080;color:"#384333";opacity:.58}
 PlaylistMagazine {anchors.left:parent.left;anchors.right:parent.right;height:parent.height-90;controller:rhine.magazine;background:bg;unit:root.height/1080}
 GlobalTools {anchors.fill:parent;background:bg;unit:root.height/1080;topRightReserved:132}
 SongContextMenu {anchors.fill:parent;controller:rhine.magazine;background:bg}
 Rectangle {x:24;y:parent.height-82;width:parent.width-48;height:68;radius:34;color:"#eeeae2";border.color:"#d3d7c9"
 Text {x:24;anchors.verticalCenter:parent.verticalCenter;text:"离线交互验收数据  ·  底部原播放栏保持不变";font.family:rhineFontFamily;font.pixelSize:14;color:"#6e7c60"}
 }
}''',encoding='utf-8')
    c=Controller(images);spy=Spy(c);v=QQuickView();v.rootContext().setContextProperty('rhine',spy);v.rootContext().setContextProperty('rhineFontFamily',font)
    warnings=[];v.engine().warnings.connect(lambda items:warnings.extend(x.toString() for x in items))
    v.setSource(QUrl.fromLocalFile(str(d/'Harness.qml')));assert v.status()==QQuickView.Ready
    v.show();QTest.qWait(400);root=v.rootObject()
    if '--album-description-only' in sys.argv:
        c.meta={**c.meta,'kind':'album','date':'2024-03-02','artists':[{'id':'5','name':'Actual album artist'}]}
        c.changed.emit();QTest.qWait(180)
        for width,height in ((1400,900),(960,540),(960,720),(1920,1080)):
            v.resize(width,height);root.setWidth(width);root.setHeight(height);QTest.qWait(150)
            listing=find(root,'magazineTrackList');listing.setProperty('contentY',listing.property('startY'));QTest.qWait(150)
            checkColumnAlignment(v,root,c)
            checkAlbumDescription(v,root,c,long=False)
            checkAlbumDescription(v,root,c,long=True)
            print('PASS G91 album/playlist columns, portrait binding, short/long description and wheel:',width,height)
        assert not [w for w in warnings if 'ReferenceError' in w or 'TypeError' in w or 'Binding loop' in w],warnings
        print('PASS G90 focused production QML: album full description opens, actual wheel scrolls, close restores interaction')
        v.setSource(QUrl());QTest.qWait(50)
        sys.exit(0)
    for width,height in ((1400,900),(960,540),(960,720),(1920,1080)):
        v.resize(width,height);root.setWidth(width);root.setHeight(height);QTest.qWait(150)
        listing=find(root,'magazineTrackList');assert listing is not None
        listing.setProperty('contentY',listing.property('startY'));QTest.qWait(100)
        assert not find(root,'playlistSearchCaption').property('truncated')
        click(v,find(root,'magazinePlayAll'));assert c.actions[-1]==('bulk','play-all')
        click(v,find(root,'globalSearch'));assert spy.actions[-1]=='search'
        row=find(root,'magazineRow_0');assert row is not None
        titleHit=find(root,'magazineTitleHit_0');before=len(c.actions);click(v,titleHit);assert len(c.actions)==before
        QTest.mouseDClick(v,Qt.LeftButton,Qt.NoModifier,titleHit.mapToScene(titleHit.boundingRect().center()).toPoint());QTest.qWait(80);assert c.actions[-1][0]=='play' and not any(x[0]=='detail' for x in c.actions[before:])
        click(v,find(root,'magazineCoverPlay_0'));assert c.actions[-1]==('play','netease:60000')
        click(v,row,Qt.RightButton,QPointF(row.width()*.38,row.height()/2));assert c.actions[-1]==('context','directory',0,'netease:60000')
        menu=find(v.contentItem(),'songMenu_next');assert menu is not None
        click(v,menu);assert c.actions[-1]==('song','next')
        listing.setProperty('contentY',1000);QTest.qWait(100);assert find(root,'playlistStickyHeader').isVisible()
        # A finite set of delegates despite 4,080 actual model rows.
        def count(item):return (1 if item.objectName().startswith('magazineRow_') else 0)+sum(count(x) for x in item.childItems())
        assert count(root)<60,count(root)
        if width==1400:
            listing.setProperty('contentY',listing.property('startY'));QTest.qWait(100)
            v.grabWindow().save(str(repo.parent/'g71-magazine-preview.png'))
        print('PASS QML:',width,height,'real cover play, row right-click/next, global search, sticky header, bounded delegates')
    # Actual input events plus model resets and noisy backend refreshes.
    listing=find(root,'magazineTrackList');listing.setProperty('contentY',listing.property('startY'));QTest.qWait(80)
    search=find(root,'playlistSearch');click(v,search);QTest.qWait(240)
    field=find(root,'playlistSearchInput');assert field.hasActiveFocus()
    for value in ('a','ab','abc','ab','a','','Maia','Flying Lotus','everything is alive','no-such-song'):
        QTest.keyClick(v,Qt.Key_A,Qt.ControlModifier);QTest.keyClick(v,Qt.Key_Backspace)
        QGuiApplication.clipboard().setText(value);QTest.keyClick(v,Qt.Key_V,Qt.ControlModifier);QTest.qWait(40)
        for _ in range(4):c.changed.emit();QTest.qWait(20)
        assert field.property('text')==value and c.q==value and field.hasActiveFocus(),(value,c.q,field.property('text'))
        if value=='no-such-song':assert c.rowCount()==0 and '没有匹配' in find(root,'playlistResultStatus').property('text')
    QTest.keyClick(v,Qt.Key_A,Qt.ControlModifier);QTest.keyClick(v,Qt.Key_Backspace);QTest.keyClick(v,Qt.Key_A);QTest.keyClick(v,Qt.Key_B);QTest.keyClick(v,Qt.Key_Backspace)
    assert c.q=='a' and field.property('text')=='a'
    click(v,find(root,'playlistSearchClear'));assert c.q=='' and c.rowCount()==4080 and field.hasActiveFocus()
    original=c.meta['key'];c.meta['key']='netease:playlist:reentry';c.q='';c.changed.emit();QTest.qWait(100)
    click(v,find(root,'playlistSearch'));QGuiApplication.clipboard().setText('Maia');QTest.keyClick(v,Qt.Key_V,Qt.ControlModifier);assert c.q=='Maia' and field.hasActiveFocus()
    c.meta['key']=original;c.q='';c.changed.emit();c.search('');QTest.qWait(360)
    print('PASS G71 QML: append/delete/paste/clear/no-result, noisy backend/model resets, focus and page reentry')
    # G76: unknown is a distinct UI state, and background completion updates every heart.
    c.likesKnown=False;c.meta['likesLoading']=True;c.dataChanged.emit(c.index(0),c.index(c.rowCount()-1),[260,261]);c.changed.emit();QTest.qWait(60)
    assert not find(root,'magazineHeart_0').property('known') and not find(find(root,'magazineHeart_0'),'songHeartIcon').isVisible()
    before=len(c.actions);click(v,find(root,'magazineHeart_0'));assert not any(a[0]=='like' for a in c.actions[before:])
    c.likesKnown=True;c.meta['likesLoading']=False;c.dataChanged.emit(c.index(0),c.index(c.rowCount()-1),[260,261]);c.changed.emit();QTest.qWait(60)
    for n in (0,3):assert find(root,'magazineHeart_'+str(n)).property('known') and find(find(root,'magazineHeart_'+str(n)),'songHeartIcon').property('source').toString().endswith('song-like-on.png')
    print('PASS G76 QML: unknown hearts never appear as confirmed unliked; multiple hearts update automatically on data completion')
    # Shared heart geometry has a real filled state and an immutable row action.
    listing.setProperty('contentY',listing.property('startY'));QTest.qWait(80)
    heart=find(root,'magazineHeart_0');icon=find(heart,'songHeartIcon');assert icon.property('source').toString().endswith('song-like-on.png')
    click(v,heart);assert c.actions[-1]==('like','netease:60000')
    assert find(find(root,'magazineHeart_1'),'songHeartIcon').property('source').toString().endswith('song-like-off.png')
    # Collapse with a retained query, re-open for ordinary text selection, then clear.
    click(v,find(root,'playlistSearch'));QGuiApplication.clipboard().setText('Maia');QTest.keyClick(v,Qt.Key_V,Qt.ControlModifier);QTest.qWait(80)
    field=find(root,'playlistSearchInput');QTest.mouseMove(v,field.mapToScene(QPointF(8,field.height()/2)).toPoint());QTest.qWait(80)
    assert v.cursor().shape()==Qt.IBeamCursor,v.cursor().shape()
    expandedWidth=search.width();titleItem=find(root,'playlistTitle');click(v,titleItem);QTest.qWait(240)
    assert not search.property('expanded') and c.q=='Maia' and search.width()<expandedWidth,(search.property('expanded'),c.q,search.width(),expandedWidth,field.hasActiveFocus())
    click(v,search);assert field.hasActiveFocus() and field.property('text')=='Maia'
    QTest.keyClick(v,Qt.Key_A,Qt.ControlModifier);QTest.keyClick(v,Qt.Key_X,Qt.ControlModifier);assert c.q=='' and c.rowCount()==4080
    # Button bottom alignment is independent of missing or long description.
    def bottom(item):return item.mapToScene(QPointF(0,item.height())).y()
    cover=find(root,'playlistMainCover');actions=find(root,'playlistActions')
    for description in ('','A real short introduction',('Long actual introduction. '*160)):
        c.meta['description']=description;c.changed.emit();QTest.qWait(100)
        assert abs(bottom(cover)-bottom(actions))<1,(bottom(cover),bottom(actions))
    click(v,find(root,'playlistDescriptionOpen'));QTest.qWait(100);assert find(v.contentItem(),'playlistDescriptionClose') is not None
    click(v,find(v.contentItem(),'playlistDescriptionClose'));QTest.qWait(60)
    # Shared account actions and reserved native-window-button space.
    bar=find(root,'globalAccountBar');assert bar.x()+bar.width()<=v.width()-132
    click(v,find(root,'globalProfile'));assert spy.actions[-1]=='profile:open:42'
    click(v,find(root,'globalAccountArrow'));click(v,find(v.contentItem(),'accountMenuPlaylists'));assert spy.actions[-2:]==['profile:open:42','profile:filter:created']
    before=len(spy.actions);click(v,find(root,'globalInbox'));assert len(spy.actions)==before
    print('PASS G71 QML: I-beam, retained-query collapse/reopen, cut/clear, fixed button alignment, full description, real account actions and window-button clearance')
    # G74: collection state, confirmation and a captured identity at the sticky controls.
    listing=find(root,'magazineTrackList');listing.setProperty('contentY',1000);QTest.qWait(360)
    sticky=find(root,'playlistStickyHeader');assert sticky.isVisible()
    assert not any(isinstance(x, QObject) and x.objectName()=='playlistMainCover' for x in sticky.children())
    start=len(c.actions);click(v,find(root,'stickyPlayAll'));assert ('bulk','play-all') in c.actions[start:]
    start=len(c.actions);click(v,find(root,'stickySubscribe'));assert ('subscribe',c.meta['key'],True) in c.actions[start:]
    start=len(c.actions);click(v,find(root,'stickySubscribe'))
    dialog=find(v.contentItem(),'playlistUnsubscribeDialog')
    # Popup is a QObject rather than a visual child of the overlay.
    from PySide6.QtCore import QMetaObject
    if dialog is None:dialog=root.findChild(QObject,'playlistUnsubscribeDialog')
    assert dialog.property('visible') and len([x for x in c.actions[start:] if x[0]=='subscribe'])==0
    QMetaObject.invokeMethod(dialog,'reject');QTest.qWait(80);assert c.meta['subscribed']
    click(v,find(root,'stickySubscribe'));QMetaObject.invokeMethod(dialog,'accept');QTest.qWait(80)
    assert c.actions[-1]==('subscribe',c.meta['key'],False) and not c.meta['subscribed']
    click(v,find(root,'stickyMore'));QTest.qWait(80)
    v.grabWindow().save(str(repo.parent/'g74-sticky-menu-preview.png'))
    start=len(c.actions);click(v,find(v.contentItem(),'collectionShare'));assert ('share',) in c.actions[start:]
    click(v,find(root,'stickyMore'));start=len(c.actions);click(v,find(v.contentItem(),'collectionAppend'));assert ('bulk','append-all') in c.actions[start:]
    click(v,find(root,'stickyMore'));click(v,find(v.contentItem(),'collectionBatch'));assert find(root,'playlistMagazinePage').property('selecting')
    find(root,'playlistMagazinePage').setProperty('selecting',False);listing.setProperty('contentY',1000);QTest.qWait(100)
    v.grabWindow().save(str(repo.parent/'g74-sticky-preview.png'))
    # Bottom delegates fade as well as the top band in the software renderer.
    fadeRows=[]
    def rowsIn(item):
        if item.objectName().startswith('magazineRow_'):fadeRows.append(item)
        for child in item.childItems():rowsIn(child)
    rowsIn(root)
    if os.environ.get('QT_QUICK_BACKEND')=='software':assert any(0<x.opacity()<1 for x in fadeRows),[(x.objectName(),x.opacity()) for x in fadeRows]
    else:assert QQmlProperty(listing,'layer.enabled').read(), 'RHI uses the list shader mask, not per-row opacity'
    print('PASS G74: sticky play/subscribe, confirmation/cancel, no identity art and two-edge fade')
    # G74: use the actual exposed left corner; no navigation before motion ends.
    listing.setProperty('contentY',listing.property('startY'));QTest.qWait(360)
    stack=find(root,'playlistRecordStack')
    for side in (-1,1):
        target=next(x for x in c.rear if x['side']==side)['key']
        hit=find(root,'recordHit_'+target);point=hit.mapToScene(QPointF(6,hit.height()*.6)).toPoint()
        before=len([x for x in c.actions if x[0]=='open'])
        QTest.mouseMove(v,point);QTest.qWait(240)
        QTest.mouseClick(v,Qt.LeftButton,Qt.NoModifier,point);QTest.qWait(180)
        assert stack.property('turning') and len([x for x in c.actions if x[0]=='open'])==before
        incoming=find(root,'recordSleeve_'+target);assert incoming.isVisible() and incoming.opacity()==1
        QTest.qWait(500)
        outgoing=find(root,'recordSleeve_'+target)
        assert not stack.property('turning') and c.meta['key']==target
        assert abs(outgoing.x()-stack.property('frontX'))<.01 and abs(outgoing.y()-stack.property('frontY'))<.01
        assert outgoing.rotation()==0 and outgoing.opacity()==1
    assert c.catalogIndex==0
    print('PASS G74: real previous-corner click, delayed navigation and stable centre after both turn directions')
    # G75: sample the real QML scene during both directions, including the last frame.
    import json,time
    motionEvidence=[];motionFrames=[];c.detailCoverRefresh=True
    def recordKey(item):
        data=item.property('record')
        if hasattr(data,'toVariant'):data=data.toVariant()
        return data.get('key','')
    for direction in (1,-1):
        listing.setProperty('contentY',listing.property('startY'));QTest.qWait(360)
        mainKey=c.meta['key'];target=next(x for x in c.rear if x['side']==direction)['key']
        leavingKey=next(x for x in c.rear if x['side']==-direction)['key']
        enteringKey=c.recordNeighbour(2*direction)['key']
        beforeMain=find(root,'recordSleeve_'+mainKey);beforeChosen=find(root,'recordSleeve_'+target);chosenSource=beforeChosen.property('coverSource')
        hit=find(root,'recordHit_'+target);point=hit.mapToScene(QPointF(6 if direction<0 else hit.width()/2,hit.height()*.6)).toPoint()
        QTest.mouseMove(v,point);QTest.qWait(260)
        QTest.mouseClick(v,Qt.LeftButton,Qt.NoModifier,point)
        assert stack.property('turning')
        watched={k:find(root,'recordSleeve_'+k) for k in (leavingKey,mainKey,target,enteringKey)}
        assert all(x is not None for x in watched.values())
        layers={key:QQmlProperty(card,'layer.enabled').read() for key,card in watched.items()}
        assert watched[mainKey]==beforeMain and watched[target]==beforeChosen
        entered=watched[enteringKey];assert entered.y()>stack.property('frontY')+stack.property('size')*.1
        samples=[];marks=[.04,.25,.5,.75,.98];started=time.monotonic()
        while stack.property('turning'):
            progress=float(stack.property('progress'));rows={}
            for key,card in watched.items():
                rows[key]=[card.x(),card.y(),card.rotation(),card.opacity()]
                if abs(card.property('slot'))<=1 or card.opacity()>.01:assert recordKey(card)==key,(key,recordKey(card),progress)
            for key,card in watched.items():assert QQmlProperty(card,'layer.enabled').read()==layers[key],'cover render target must not toggle at the handoff'
            assert abs(watched[mainKey].opacity()-1)<.001,'main card must move to the side, never fade out'
            samples.append(dict(t=time.monotonic()-started,p=progress,cards=rows))
            if marks and progress>=marks[0]:
                marks.pop(0);image=v.grabWindow();origin=stack.mapToScene(QPointF(-70,-20)).toPoint()
                motionFrames.append((direction,progress,image.copy(max(0,origin.x()),max(0,origin.y()),int(stack.width()+170),int(stack.height()+160))))
            QTest.qWait(12)
            assert time.monotonic()-started<3
        for key,card in watched.items():
            if key==leavingKey:assert not recordKey(card) and card.opacity()==0
            else:assert recordKey(card)==key
        assert watched[mainKey].property('slot')==-direction and watched[target].property('slot')==0 and entered.property('slot')==direction
        assert watched[target]==find(root,'recordSleeve_'+target)
        terminal={key:[card.x(),card.y(),card.rotation(),card.opacity()] for key,card in watched.items() if key!=leavingKey}
        last=samples[-1]
        assert last['p']>.96,last['p']
        for key,end in terminal.items():
            assert max(abs(last['cards'][key][j]-end[j]) for j in (0,1))<4,(direction,key,last['cards'][key],end)
        def assertPaintedTarget():
            art=QImage(QUrl(chosenSource).toLocalFile());expected=art.pixelColor(art.width()//2,art.height()//2)
            frame=v.grabWindow();point=watched[target].mapToScene(QPointF(watched[target].width()/2,watched[target].height()/2));ratio=frame.devicePixelRatio()
            actual=frame.pixelColor(round(point.x()*ratio),round(point.y()*ratio))
            assert max(abs(expected.red()-actual.red()),abs(expected.green()-actual.green()),abs(expected.blue()-actual.blue()))<30,(expected.name(),actual.name())
        assertPaintedTarget()
        QTest.qWait(260)
        assertPaintedTarget()
        for key,end in terminal.items():
            card=watched[key];assert max(abs(card.x()-end[0]),abs(card.y()-end[1]))<.02,(key,end,card.x(),card.y())
        assert c.meta['key']==target
        assert watched[target].property('coverSource')==chosenSource and c.meta['cover']!=chosenSource,'detail size/URL refresh must not reload the displayed sleeve'
        motionEvidence.append(dict(direction=direction,leaving=leavingKey,main=mainKey,target=target,entering=enteringKey,samples=samples,terminal=terminal))
    c.detailCoverRefresh=False
    (repo.parent/'g75-motion-samples.json').write_text(json.dumps(motionEvidence),encoding='utf-8')
    # A contact sheet is an intermediate visual check, never installed as UI art.
    sheet=QImage(5*540,2*470,QImage.Format_RGB32);sheet.fill(QColor('#e9e7df'));painter=QPainter(sheet)
    for n,(direction,progress,frame) in enumerate(motionFrames[:10]):
        x=(n%5)*540;y=(n//5)*470;painter.drawImage(x,y+24,frame.scaled(530,430,Qt.KeepAspectRatio,Qt.SmoothTransformation));painter.setPen(QColor('#30392e'));painter.drawText(x+12,y+18,f'direction {direction}, progress {progress:.3f}')
    painter.end();sheet.save(str(repo.parent/'g75-turn-contact-sheet.png'))
    print('PASS G75: sampled both directions; A exits, B stays opaque and moves aside, C retains identity, D inserts from below; last frame and post-navigation positions are continuous')
    # G76: emulate first-use network images, not pre-cached file thumbnails.
    import threading,http.server
    class SlowArt(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            time.sleep(.18)
            n=int(self.path.split('?')[0].split('/')[-1].split('.')[0])%len(images)
            payload=Path(QUrl(images[n]).toLocalFile()).read_bytes()
            try:self.send_response(200);self.send_header('Content-Type','image/png');self.send_header('Content-Length',str(len(payload)));self.end_headers();self.wfile.write(payload)
            except (BrokenPipeError,ConnectionResetError):pass
        def log_message(self,*args):pass
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),SlowArt);threading.Thread(target=lambda:server.serve_forever(poll_interval=.05),daemon=True).start()
    savedCatalog,savedMeta,savedIndex=c.catalog,c.meta.copy(),c.catalogIndex
    fresh=[dict(key='netease:playlist:'+str(7600+i),id=str(7600+i),kind='playlist',title='Cold '+str(i),cover=f'http://127.0.0.1:{server.server_port}/{i}.png') for i in range(4)]
    c.catalog=fresh;c.catalogIndex=1;c.meta={**savedMeta,**fresh[1]};c.position=0;c.changed.emit();QTest.qWait(12)
    target=fresh[2]['key'];hit=find(root,'recordHit_'+target);point=hit.mapToScene(QPointF(hit.width()/2,hit.height()*.6)).toPoint()
    before=len([a for a in c.actions if a[0]=='open']);QTest.mouseMove(v,point);QTest.mouseClick(v,Qt.LeftButton,Qt.NoModifier,point)
    assert stack.property('queuedKey')==target and not stack.property('turning'),'cold art should be decoded before starting the unchanged turn'
    QTest.mouseClick(v,Qt.LeftButton,Qt.NoModifier,point)
    started=time.monotonic()
    while not stack.property('turning') and time.monotonic()-started<3:QTest.qWait(12)
    assert stack.property('turning') and len([a for a in c.actions if a[0]=='open'])==before
    for record in fresh:
        card=find(root,'recordSleeve_'+record['key']);assert card is not None and not card.property('imageLoading')
    QTest.qWait(650);assert c.meta['key']==target and len([a for a in c.actions if a[0]=='open'])==before+1
    c.catalog=savedCatalog;c.catalogIndex=savedIndex;c.meta=savedMeta;c.position=0;c.changed.emit();QTest.qWait(360);server.shutdown();server.server_close()
    print('PASS G76 QML: immediate cold-image click and duplicate click wait for decode, then execute one unchanged 460ms turn')
    # Every exposed sleeve maps to its own key, title and single navigation.
    retainedStack=find(root,'playlistRecordStack')
    for ordinal in range(5):
        listing.setProperty('contentY',listing.property('startY'));QTest.qWait(80)
        previewKey=c.rear[1]['key'];expectedIndex=c.catalogIndex+1;oldKey=c.meta['key']
        sleeve=find(root,'recordSleeve_'+previewKey)
        QTest.mouseMove(v,sleeve.mapToScene(QPointF(sleeve.width()/2,sleeve.height()/2)).toPoint());QTest.qWait(260)
        hit=find(root,'recordHit_'+previewKey)
        QTest.mouseMove(v,hit.mapToScene(QPointF(hit.width()/2,hit.height()/2)).toPoint());QTest.qWait(240)
        assert find(root,'recordTargetInfo').isVisible() and find(root,'recordTargetTitle').property('text')==c.rear[1]['title']
        if ordinal==1:v.grabWindow().save(str(repo.parent/'g71-record-hover.png'))
        before=len([a for a in c.actions if a[0]=='open'])
        click(v,hit);QTest.qWait(600)
        assert c.meta['key']==previewKey and c.catalogIndex==expectedIndex and c.rear[0]['key']==oldKey and retainedStack==find(root,'playlistRecordStack')
        assert len([a for a in c.actions if a[0]=='open'])==before+1
    previewKey=c.rear[-1]['key'];sleeve=find(root,'recordSleeve_'+previewKey)
    QTest.mouseMove(v,sleeve.mapToScene(QPointF(sleeve.width()/2,sleeve.height()/2)).toPoint());QTest.qWait(250)
    thumb=find(root,'recordPreview_'+previewKey);before=len([a for a in c.actions if a[0]=='open'])
    click(v,thumb);click(v,thumb);QTest.qWait(600)
    assert c.meta['key']==previewKey and len([a for a in c.actions if a[0]=='open'])==before+1
    print('PASS G71 QML: ordered neighbours across more than three collections, exact target labels, thumbnail choice and rapid-click suppression')
    spy.data['dark']=True;spy.data['reduced']=True;spy.changed.emit();QTest.qWait(100)
    listing.setProperty('contentY',listing.property('startY'));QTest.qWait(100)
    sleeve=find(root,'recordSleeve_'+c.rear[0]['key']);QTest.mouseMove(v,sleeve.mapToScene(QPointF(sleeve.width()/2,sleeve.height()/2)).toPoint());QTest.qWait(240)
    target=c.rear[0]['key'];thumb=find(root,'recordPreview_'+target);point=thumb.mapToScene(QPointF(thumb.width()/2,thumb.height()/2)).toPoint();before=len([a for a in c.actions if a[0]=='open'])
    QTest.mouseClick(v,Qt.LeftButton,Qt.NoModifier,point);QTest.mouseClick(v,Qt.LeftButton,Qt.NoModifier,point);QTest.qWait(240)
    assert c.meta['key']==target and len([a for a in c.actions if a[0]=='open'])==before+1
    print('PASS G71 QML: reduced-motion double click selects exactly one immutable target')
    c.search('');c.meta={**c.meta,'kind':'album','date':'2024-03-02','artists':[{'id':'5','name':'Actual album artist'}]};c.changed.emit()
    listing.setProperty('contentY',listing.property('startY'));QTest.qWait(180)
    assert find(root,'magazineHeat_0').property('known') and not find(root,'magazineHeat_1').property('known') and find(root,'magazineHeat_2').property('known')
    checkAlbumDescription(v,root,c)
    print('PASS G90 album QML: actual heat states and real full-description open, mouse-wheel scroll and close')
    v.grabWindow().save(str(repo.parent/'g71-magazine-dark-preview.png'))
    assert not [w for w in warnings if 'ReferenceError' in w or 'TypeError' in w or 'Cannot assign' in w or 'Binding loop' in w],warnings
    v.setSource(QUrl());QTest.qWait(50)
