"""Exercise production QML Loaders, retained Following scroll, queue and collection mouse actions.
The backend is a spy; actual C++ transitions/mutations are covered by Windows UiChecks.
"""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
import sys,shutil,tempfile
from pathlib import Path
from PySide6.QtCore import QObject,Signal,Property,Slot,QUrl,Qt,QPoint,QPointF
from PySide6.QtGui import QGuiApplication,QFontDatabase,QWheelEvent
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
src=Path(sys.argv[1]).resolve();app=QGuiApplication([])
f=QFontDatabase.addApplicationFont(str(src/'Assets/fonts/RhineMiSans-regular.otf'))
class Spy(QObject):
    changed=Signal();pageNavigation=Signal(str)
    def __init__(self):
        super().__init__();self.actions=[]
        self.data=dict(modal='discover',queueOpen=False,queueCollectionOpen=False,mode='archive',dark=False,reduced=True,
            discoverTab='following',discoverItems=[dict(id=str(i),title='关注歌单 '+str(i),artist='作者',kind='playlist',cover='') for i in range(90)],
            discoverCategory='保留筛选',queueCanCollect=True,queueCount=40,queueIndex=0,queueOffset=0,queueBounds=dict(x=1182,y=116,width=430,height=842),
            profileOwn=False,profileMore=False,profileLoading=False,profileError='',profileID='42',profileSection='music',profileFilter='created',profilePlayKey='',accountUID='42',navigationCreated=[dict(id='123',title='测试收藏歌单')],queueRows=[dict(index=i,id=str(i),key='netease:'+str(i),title='Song '+str(i),artist='Artist',cover='',durationLabel='04:19',sourceTitle='关注',sourceLink=True) for i in range(40)])
    @Property('QVariantMap',notify=changed)
    def state(self):return self.data
    @Slot(str)
    def action(self,name):
        self.actions.append(name)
        if name=='player:open':self.data['queueOpen']=not self.data['queueOpen']
        elif name=='queue-close':self.data['queueOpen']=False
        elif name.startswith('player:queue-collect:'):self.data['queueCollectionOpen']=True
        elif name=='queue-collection-close' or name.startswith('music:playlist-pick:'):self.data['queueCollectionOpen']=False
        elif name.startswith('player:queue-play:'):self.data['queueIndex']=int(name.split(':')[2])
        self.changed.emit()
    def update(self,**kw):self.data.update(kw);self.changed.emit();QTest.qWait(100)
def find(item,name):
    if item.objectName()==name:return item
    for child in item.childItems():
        hit=find(child,name)
        if hit is not None:return hit
def click(v,item):
    assert item is not None and item.isVisible()
    point=item.mapToScene(QPointF(item.width()/2,item.height()/2)).toPoint()
    QTest.mouseMove(v,point);QTest.mouseClick(v,Qt.LeftButton,Qt.NoModifier,point);QTest.qWait(100)
def wheel(v,item):
    point=item.mapToScene(QPointF(70,item.height()/2))
    event=QWheelEvent(point,point,QPoint(),QPoint(0,-480),Qt.NoButton,Qt.NoModifier,Qt.NoScrollPhase,False)
    app.sendEvent(v,event);QTest.qWait(350)
with tempfile.TemporaryDirectory() as tmp:
    d=Path(tmp)
    for p in (src/'Qt/qml').glob('*.qml'):shutil.copyfile(p,d/p.name)
    main=(src/'Qt/qml/Main.qml').read_text();a=main.index('    Loader {\n        id: commentsLoader');b=main.index('    WindowChrome {',a)
    block=main[a:b]
    (d/'Harness.qml').write_text('''import QtQuick
Item { id:root; width:1100; height:720
 property real stageScale:height/1080
 property var commentsScrollMemory:({})
 property var discoverScrollMemory:({})
 Loader {id:magazineLoader;active:false}
 Rectangle {id:backgroundLayer;anchors.fill:parent;color:"#e8e8df"}
 Item {id:baseVisual;anchors.fill:parent;Rectangle {anchors.fill:parent;color:"#e8e8df"}}
 MouseArea {anchors.fill:parent;onClicked:rhine.action("underlying-page")}
'''+block+'\n}')
    spy=Spy();v=QQuickView();v.rootContext().setContextProperty('rhine',spy)
    v.rootContext().setContextProperty('rhineFontFamily',QFontDatabase.applicationFontFamilies(f)[0])
    v.setSource(QUrl.fromLocalFile(str(d/'Harness.qml')));assert v.status()==QQuickView.Ready
    v.show();QTest.qWait(150);root=v.rootObject()
    for height in (720,1080):
        v.resize(1400,height);root.setWidth(1400);root.setHeight(height)
        # Match production queue stage geometry after resize.
        scale=height/1080;stage=1400/scale;panel=min(430,max(320,stage*.29))
        spy.update(queueBounds=dict(x=stage-panel-18,y=116,width=panel,height=842))
        loader=find(root,'discoverGlassLoader');page=loader.property('item');scroll=find(root,'discoverScroll')
        previousY=scroll.property('contentY')
        wheel(v,scroll);y=scroll.property('contentY');assert y>0,y
        expectedY=min(max(0,scroll.property('contentHeight')-scroll.height()),previousY+480*scale*.6)
        assert abs(y-expectedY)<.000001,(y,expectedY)
        assert not scroll.property('moving'), 'wheel must settle before capturing the retained position'
        QTest.qWait(250);assert scroll.property('contentY')==y
        for tick in range(12):
            spy.data['playbackPosition']=tick;spy.changed.emit();QTest.qWait(10)
        assert scroll.property('contentY')==y
        original=spy.data['discoverItems']
        for i in range(4):
            spy.action('player:open');QTest.qWait(100)
            assert spy.data['modal']=='discover' and loader.property('item')==page and scroll.property('contentY')==y
            assert spy.data['discoverTab']=='following' and spy.data['discoverItems'] is original
            queue=find(root,'playerQueueGlass');assert queue is not None and queue.isVisible()
            assert find(root,'queueDiscoverTile') is not None
            listing=find(root,'playerQueueList');wheel(v,listing)
            assert listing.property('contentY')>0 and scroll.property('contentY')==y
            listing.setProperty('contentY',0);QTest.qWait(50)
            click(v,find(root,'queueCoverPlay_1'));assert spy.data['queueIndex']==1
            row=find(root,'queueRow_1');QTest.mouseMove(v,row.mapToScene(QPointF(30,row.height()/2)).toPoint());QTest.qWait(80)
            click(v,find(root,'queueCollect_1'))
            assert find(root,'queueCollectionOverlay').isVisible() and loader.property('item')==page and scroll.property('contentY')==y
            click(v,find(root,'queuePlaylist_123'))
            assert spy.actions[-1]=='music:playlist-pick:123'
            assert not spy.data['queueCollectionOpen'] and spy.data['queueOpen']
            click(v,find(root,'queueClose'));assert not spy.data['queueOpen']
            assert loader.property('item')==page and scroll.property('contentY')==y
        print('PASS:',height,'Following instance/data/filter/scroll preserved; actual queue wheel/play/collect/pick/close')
    # Source routing has its own backend CI checks. The same retained-page rule applies to profile.
    spy.update(modal='profile',queueOpen=False,profileRows=[])
    loader=find(root,'userProfileLoader');page=loader.property('item');assert page is not None
    spy.update(queueOpen=True);assert loader.property('item')==page and find(root,'queueProfileTile') is not None
    spy.update(queueOpen=False);assert loader.property('item')==page
    print('PASS: profile Loader identity retained; acyclic live profile capture activated only with queue')

    v.setSource(QUrl()); QTest.qWait(100)  # Destroy QML while the backend context still exists.
