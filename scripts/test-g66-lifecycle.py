"""Real Qt comment-model page transitions and stable delegate checks."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
import sys,shutil,tempfile
from pathlib import Path
from PySide6.QtCore import QObject,Signal,Property,Slot,QUrl,Qt,QPoint,QPointF
from PySide6.QtGui import QGuiApplication,QFontDatabase,QWheelEvent
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
import shiboken6
src=Path(sys.argv[1]).resolve()
app=QGuiApplication([])
f=QFontDatabase.addApplicationFont(str(src/'Assets/fonts/RhineMiSans-regular.otf'))
class Spy(QObject):
    changed=Signal()
    def __init__(self):
        super().__init__();self.data={}
    @Property('QVariantMap',notify=changed)
    def state(self):return self.data
    @Slot(str)
    def action(self,s):pass
    def publish(self,opened,session='song:1',count=12):
        rows=[dict(id=str(i),author='Author '+str(i),content='Comment '+str(i)+' text '*15,date='2026-10-28',avatar='',userID='42',likedCount=2,quote={}) for i in range(count)]
        self.data=dict(commentsOpen=opened,commentsBounds=dict(x=20,y=20,width=600,height=450) if opened else None,
            commentsRows=rows if opened else [],commentsFeatured=rows[:5] if opened else [],
            commentsSession=session,commentsTitle='Comments',commentsTotal=count,commentsMore=False,
            commentsLoading=False,commentsError='',modal='',dark=False)
        self.changed.emit()
def find(item,name):
    if item.objectName()==name:return item
    for c in item.childItems():
        found=find(c,name)
        if found is not None:return found
with tempfile.TemporaryDirectory() as temporary:
    t=Path(temporary);shutil.copy(src/'Qt/qml/CommentsPage.qml',t)
    main=(src/'Qt/qml/Main.qml').read_text()
    a=main.index('    Loader {\n        id: commentsLoader')
    b=main.index('    Loader {\n        id: profileLoader',a)
    loader=main[a:b]
    p=t/'Harness.qml';p.write_text('''import QtQuick
Item { id:root; width:800;height:540
 property real stageScale:1
 property var commentsScrollMemory:({})
'''+loader+'\n}')
    spy=Spy();spy.publish(False)
    v=QQuickView();v.rootContext().setContextProperty('rhine',spy)
    v.rootContext().setContextProperty('rhineFontFamily',QFontDatabase.applicationFontFamilies(f)[0])
    v.setSource(QUrl.fromLocalFile(str(p)));assert v.status()==QQuickView.Ready
    v.show();QTest.qWait(50)
    root=v.rootObject();loader=find(root,'commentsLoader')
    for i in range(40):
        spy.publish(True,'album:'+str(i));QTest.qWait(12)
        assert loader.property('active') and loader.property('item') is not None
        author=find(root,'commentAuthor');assert author is not None
        for j in range(4):
            spy.data['unrelatedPlaybackPosition']=j
            spy.changed.emit();QTest.qWait(2)
            assert find(root,'commentAuthor')==author, 'state refresh rebuilt stable featured model'
        reading=find(root,'commentsReading');point=reading.mapToScene(QPointF(200,200))
        wheel=QWheelEvent(point,point,QPoint(),QPoint(0,-240),Qt.NoButton,Qt.NoModifier,Qt.NoScrollPhase,False)
        QTest.mouseMove(v,point.toPoint());app.sendEvent(v,wheel);QTest.qWait(70)
        assert reading.property('contentY')>0
        spy.publish(False,'album:'+str(i))
        # Closing hides immediately, then releases models outside the state notifier.
        assert not loader.isVisible()
        QTest.qWait(12)
        assert not loader.property('active') and loader.property('item') is None
    v.close();shiboken6.delete(v)
print('PASS: 40 album/comment exits, 160 state updates retain featured delegates, real wheel events, deferred teardown releases page')
