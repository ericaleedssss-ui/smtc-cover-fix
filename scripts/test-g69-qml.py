"""Real production QML event tests with a 4,080-row fixture model (no account/network).
Full C++/Windows/real-account validation is separate; fixture art is never installed.
"""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import sys,tempfile,shutil
from PySide6.QtCore import QObject,Signal,Property,Slot,QAbstractListModel,QModelIndex,QUrl,QPointF,Qt
from PySide6.QtGui import QGuiApplication,QFontDatabase,QImage,QPainter,QColor,QLinearGradient,QFont
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
src=Path(sys.argv[1]).resolve();repo=Path(__file__).resolve().parents[1]
app=QGuiApplication([])
f=QFontDatabase.addApplicationFont(str(src/'Assets/fonts/RhineMiSans-regular.otf'))
font=QFontDatabase.applicationFontFamilies(f)[0]
QFontDatabase.addApplicationFont(str(src/'Assets/fonts/RhineMiSans-demibold.otf'))
class Controller(QAbstractListModel):
    changed=Signal();menuChanged=Signal()
    def __init__(self,images):
        super().__init__();self.actions=[];self.position=0.;self.q='';self.f='all';self.t='songs';self.menu={'visible':False};self.selection=set();self.images=images
        self.meta=dict(key='netease:playlist:1',id='1',title='PROJECT / 一些缓慢生长的声音',artist='离线交互测试',creatorID='42',createdDate='2024-06-18',total=4080,loaded=4080,cover=images[0],description='留给午后、窗边和一个人的声音。\n不赶时间地听完一张唱片。',subscribedCount=12340,commentCount=236,editable=True,canCollect=True,canDownload=True,more=False,loading=False)
        self.rear=[dict(key='netease:playlist:'+str(i+2),id=str(i+2),title='收藏歌单 '+str(i+2),cover=images[i+1]) for i in range(3)]
    def rowCount(self,parent=QModelIndex()):return 0 if parent.isValid() else 4080
    def roleNames(self):return {257:b'track',258:b'sourceIndex',259:b'chosen',260:b'heart'}
    def data(self,index,role=Qt.DisplayRole):
        n=index.row()
        if role==257:return dict(id=str(60000+n),identity='netease:'+str(60000+n),kind='song',provider='netease',title=['Maia','Go!','緩やかな日々','Dawn Chorus','shanty'][n%5],artist=['CANTOMA','Public Service Broadcasting','mouse on the keys','Flying Lotus','Slowdive'][n%5],album=['Out of Town','The Race for Space','an anxious object','Cosmogramma','everything is alive'][n%5],albumID='44',cover=self.images[n%4],durationLabel='04:12')
        if role==258:return n
        if role==259:return n in self.selection
        if role==260:return n%3==0
    @Property(bool,notify=changed)
    def active(self):return True
    @Property('QVariantMap',notify=changed)
    def info(self):return self.meta
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
    def search(self,q):self.q=q;self.actions.append(('search',q));self.changed.emit()
    @Slot(str)
    def setFilter(self,f):self.f=f;self.actions.append(('filter',f));self.changed.emit()
    @Slot(str)
    def setTab(self,t):self.t=t;self.changed.emit()
    @Slot()
    def more(self):self.actions.append(('more',))
    @Slot(str)
    def openCover(self,k):
        self.actions.append(('open',k))
        selected=next(x for x in self.rear if x['key']==k);old=self.meta.copy()
        self.meta={**self.meta,**selected};self.position=0
        self.rear=[{k:old[k] for k in ('key','id','title','cover')}]+[x for x in self.rear if x['key']!=k];self.changed.emit()
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
    @Slot()
    def share(self):self.actions.append(('share',))
    @Slot()
    def cancelRemoval(self):pass
    @Slot()
    def removeConfirmed(self):pass
class Spy(QObject):
    changed=Signal()
    def __init__(self,c):super().__init__();self.c=c;self.actions=[];self.data=dict(mode='detail',directoryOpen=True,dark=False,reduced=False,modal='',queueOpen=False)
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
with tempfile.TemporaryDirectory() as tmp:
    d=Path(tmp);images=[]
    # Clearly synthetic, deterministic TEST sleeves. Production only reads account collections.
    for i,colors in enumerate([('#14292a','#cf5e3c'),('#283653','#d7b783'),('#b9af9e','#536b54'),('#43475e','#b3a7ba')]):
        image=QImage(640,640,QImage.Format_RGB32);p=QPainter(image);g=QLinearGradient(0,0,640,640);g.setColorAt(0,QColor(colors[0]));g.setColorAt(1,QColor(colors[1]));p.fillRect(image.rect(),g);p.setPen(QColor('#cfc9b5'));p.setFont(QFont(font,26));p.drawText(40,70,'OFFLINE / COLLECTION '+str(i+1));p.setPen(QColor('#90cfc9b5'));p.drawEllipse(75+i*10,150,460,460);p.end();path=d/('sleeve'+str(i)+'.png');image.save(str(path));images.append(QUrl.fromLocalFile(str(path)).toString())
    for name in ('RhineIcon','GlobalTools','RecordStack','PlaylistMagazine','SongContextMenu','LiquidGlass'):
        origin=repo/'maintained/Qt/qml'/f'{name}.qml';shutil.copyfile(origin if origin.exists() else src/'Qt/qml'/f'{name}.qml',d/f'{name}.qml')
    (d/'Harness.qml').write_text('''import QtQuick
Item {id:root;width:1400;height:900
 Rectangle {id:bg;anchors.fill:parent;color:rhine.state.dark?"#252b23":"#e9e7df"}
 Text {x:90;y:40;text:"RHINE / 音乐资料库";font.family:rhineFontFamily;font.pixelSize:13;color:"#707c63"}
 PlaylistMagazine {anchors.left:parent.left;anchors.right:parent.right;height:parent.height-90;controller:rhine.magazine;background:bg;unit:root.height/1080}
 GlobalTools {anchors.fill:parent;background:bg;unit:root.height/1080}
 SongContextMenu {anchors.fill:parent;controller:rhine.magazine;background:bg}
 Rectangle {x:24;y:parent.height-82;width:parent.width-48;height:68;radius:34;color:"#eeeae2";border.color:"#d3d7c9"
 Text {x:24;anchors.verticalCenter:parent.verticalCenter;text:"离线交互验收数据  ·  底部原播放栏保持不变";font.family:rhineFontFamily;font.pixelSize:14;color:"#6e7c60"}
 }
}''',encoding='utf-8')
    c=Controller(images);spy=Spy(c);v=QQuickView();v.rootContext().setContextProperty('rhine',spy);v.rootContext().setContextProperty('rhineFontFamily',font)
    warnings=[];v.engine().warnings.connect(lambda items:warnings.extend(x.toString() for x in items))
    v.setSource(QUrl.fromLocalFile(str(d/'Harness.qml')));assert v.status()==QQuickView.Ready
    v.show();QTest.qWait(400);root=v.rootObject()
    for width,height in ((1400,900),(960,720),(1920,1080)):
        v.resize(width,height);root.setWidth(width);root.setHeight(height);QTest.qWait(150)
        listing=find(root,'magazineTrackList');assert listing is not None
        listing.setProperty('contentY',listing.property('startY'));QTest.qWait(100)
        click(v,find(root,'magazinePlayAll'));assert c.actions[-1]==('bulk','play-all')
        click(v,find(root,'globalSearch'));assert spy.actions[-1]=='search'
        row=find(root,'magazineRow_0');assert row is not None
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
            v.grabWindow().save(str(repo.parent/'g69-magazine-preview.png'))
        print('PASS QML:',width,height,'real cover play, row right-click/next, global search, sticky header, bounded delegates')
    # Fan out a real rear sleeve, then click its exposed right edge.
    listing=find(root,'magazineTrackList');listing.setProperty('contentY',listing.property('startY'));QTest.qWait(100)
    sleeve=find(root,'recordSleeve_'+c.rear[0]['key']);target=c.rear[0]['key'];oldKey=c.meta['key']
    QTest.mouseMove(v,sleeve.mapToScene(QPointF(sleeve.width()/2,sleeve.height()/2)).toPoint());QTest.qWait(260)
    before=len([a for a in c.actions if a[0]=='open'])
    click(v,sleeve,Qt.LeftButton,QPointF(sleeve.width()-3,sleeve.height()/2));QTest.qWait(600)
    assert c.meta['key']==target and c.rear[0]['key']==oldKey,c.actions[-5:]
    assert len([a for a in c.actions if a[0]=='open'])==before+1
    print('PASS QML: exposed rear record click navigates once after the 520ms animation and returns original front to the rear')
    spy.data['dark']=True;spy.data['reduced']=True;spy.changed.emit();QTest.qWait(100)
    listing.setProperty('contentY',listing.property('startY'));QTest.qWait(100)
    v.grabWindow().save(str(repo.parent/'g69-magazine-dark-preview.png'))
    assert not [w for w in warnings if 'ReferenceError' in w or 'TypeError' in w or 'Cannot assign' in w],warnings
    v.setSource(QUrl());QTest.qWait(50)
