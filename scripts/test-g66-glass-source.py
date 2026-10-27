"""Actual QML layered-visibility and source-button events; use applied G66 tree.
Requires PySide6. Backend provenance/navigation is checked by compiled CI tests.
"""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
import sys, shutil, tempfile
from pathlib import Path
from PySide6.QtCore import QObject, Signal, Property, Slot, QUrl, Qt, QPoint, QPointF
from PySide6.QtGui import QGuiApplication, QFontDatabase
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
src = Path(sys.argv[1]).resolve()
app = QGuiApplication([])
f = QFontDatabase.addApplicationFont(str(src/'Assets/fonts/RhineMiSans-regular.otf'))
class Spy(QObject):
    changed=Signal()
    def __init__(self):
        super().__init__(); self.actions=[]
        self.data=dict(mode='archive',modal='',queueCount=40,queueIndex=0,queueOffset=0,
            queueCanCollect=True,accountUID='42',dark=False,reduced=True,queueRows=[dict(
            index=i,id=str(i),key='netease:'+str(i),title='Song '+str(i),artist='Artist',
            cover='',durationLabel='04:19',sourceTitle='飙升榜' if i else '',sourceLink=i!=0) for i in range(40)])
    @Property('QVariantMap',notify=changed)
    def state(self): return self.data
    @Slot(str)
    def action(self,name): self.actions.append(name)
    def update(self,**values): self.data.update(values); self.changed.emit(); QTest.qWait(100)
def find(item,name):
    if item.objectName()==name:return item
    for c in item.childItems():
        a=find(c,name)
        if a is not None:return a
with tempfile.TemporaryDirectory() as d:
    d=Path(d)
    for n in ('PlayerQueueGlass.qml','SideNavigation.qml','LiquidGlass.qml'):
        shutil.copy(src/'Qt/qml'/n,d/n)
    main=(src/'Qt/qml/Main.qml').read_text()
    a=main.index('    // Acyclic, queue-sized')
    b=main.index('    Loader {\n        id: glassQueueLoader',a)
    compositor=main[a:b]
    path=d/'Harness.qml'
    path.write_text('''import QtQuick
Item { id:root; width:1100; height:720
 property real stageScale:height/1080
 Item { id:baseVisual; anchors.fill:parent
   Rectangle {id:bg;anchors.fill:parent;color:"#e8e8df"}
   LiquidGlass {objectName:"centralGlass";x:350;y:180;width:430;height:330;background:bg}
 }
 MouseArea {anchors.fill:parent;onClicked:rhine.action("page")}
 SideNavigation {id:sideNavigation;anchors.fill:parent;background:bg;unit:root.stageScale;z:300}
'''+compositor+'''
 Loader {id:glassQueueLoader; active:rhine.state.modal==="player";z:350
   x:root.width-width-30; y:60*root.stageScale; width:430*root.stageScale;height:842*root.stageScale
   sourceComponent:PlayerQueueGlass { background:queueGlassBackdrop; unit:root.stageScale }
 }
}''')
    spy=Spy();v=QQuickView()
    v.rootContext().setContextProperty('rhine',spy)
    v.rootContext().setContextProperty('rhineFontFamily',QFontDatabase.applicationFontFamilies(f)[0])
    v.setSource(QUrl.fromLocalFile(str(path)));assert v.status()==QQuickView.Ready
    v.show();QTest.qWait(150)
    root=v.rootObject();glass=find(root,'centralGlass');rail=find(root,'sideNavigationRail')
    assert glass.isVisible() and rail.isVisible()
    for height in (720,1080):
        v.resize(1400,height);root.setWidth(1400);root.setHeight(height)
        for _ in range(3):
            spy.update(modal='player')
            assert glass.isVisible() and rail.isVisible()
            assert find(root,'centralGlass')==glass
            queue=find(root,'playerQueueGlass');assert queue is not None and queue.isVisible()
            backdrop=find(root,'queueGlassBackdrop')
            assert queue.property('background')==backdrop
            row=find(root,'queueRow_1');point=row.mapToScene(QPointF(30,row.height()/2)).toPoint()
            QTest.mouseMove(v,QPoint(5,5));QTest.mouseMove(v,point);QTest.qWait(80)
            button=find(root,'queueSource_1');assert button.isVisible() and button.property('label')=='来源：飙升榜'
            p=button.mapToScene(QPointF(button.width()/2,button.height()/2)).toPoint()
            QTest.mouseClick(v,Qt.LeftButton,Qt.NoModifier,p);QTest.qWait(30)
            assert spy.actions[-1]=='player:queue-source:1:netease%3A1'
            row=find(root,'queueRow_0');p=row.mapToScene(QPointF(30,row.height()/2)).toPoint()
            QTest.mouseMove(v,p);QTest.qWait(80)
            button=find(root,'queueSource_0')
            assert button.isVisible() and not button.property('actionable')
            assert button.property('label')=='暂无可追溯来源'
            before=len(spy.actions)
            QTest.mouseClick(v,Qt.LeftButton,Qt.NoModifier,button.mapToScene(QPointF(button.width()/2,button.height()/2)).toPoint())
            assert len(spy.actions)==before
            spy.update(modal='')
            assert glass.isVisible() and rail.isVisible() and find(root,'centralGlass')==glass
        spy.update(modal='settings');assert not rail.isVisible()
        spy.update(modal='');assert rail.isVisible()
        print(f'PASS {height}p: repeated glass coexistence, unchanged base instance, real source click, unknown-source no-op, other modal unchanged')
    spy.update(modal='player')
    v.grabWindow().save(str(src.parent/'queue-g66-preview.png'))
    import shiboken6
    v.close(); shiboken6.delete(v)
print('PASS: production acyclic two-tile backdrop uses page and navigation, excludes queue')
