"""Real archive component, mouse and keyboard QA; fixture artwork never ships."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile,shutil,subprocess
from PySide6.QtCore import QLibraryInfo,QObject,Signal,Property,Slot,QUrl,Qt,QPointF,QPoint,QCoreApplication,QResource
from PySide6.QtGui import QGuiApplication,QImage,QColor,QFontDatabase,QWheelEvent
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parents[1];src=repo.parent/'upstream';app=QGuiApplication([])
fid=QFontDatabase.addApplicationFont(str(src/'Assets/fonts/RhineMiSans-regular.otf'));font=QFontDatabase.applicationFontFamilies(fid)[0]
class Controller(QObject):
 changed=Signal()
 def __init__(self,art):super().__init__();self.art=art;self.at=0;self.actions=[];self.collected=False
 @Property('QVariantMap',notify=changed)
 def info(self):return dict(key='netease:playlist:'+str(self.at),id=str(self.at),kind='playlist',title=['电子、摇滚、实验、意识、迷走','沿着夜色缓慢生长','午后的松弛感'][self.at],artist='QA / 显式离线数据',description='在电子的律动与摇滚的呐喊之间，收集那些游走于秩序与混沌的声音。\n这里是关于实验、意识与边界的歌单，适合在深夜、旅途中或独处时聆听。',creatorID='7',cover=self.art[self.at],total=15,durationLabel='1 小时 26 分钟',canSubscribe=True,subscribed=self.collected,editable=False,recordsLoading=False,recordsMore=False,recordPosition=self.at+1,recordCount=3)
 @Property('QVariantList',notify=changed)
 def covers(self):return [self.recordNeighbour(-1),self.recordNeighbour(1)]
 @Property('QVariantList',notify=changed)
 def songs(self):return [dict(title='歌曲 '+str(i+1),artist='真实接口样式测试',id=str(i+1),kind='song') for i in range(15)]
 @Property(bool,notify=changed)
 def busy(self):return False
 @Property(str,notify=changed)
 def status(self):return ''
 @Slot(int,result='QVariantMap')
 def recordNeighbour(self,n):
  at=(self.at+n)%3
  return dict(key='netease:playlist:'+str(at),title='歌单 '+str(at),cover=self.art[at],kind='playlist',side=-1 if n<0 else 1)
 @Slot()
 def prepareRecords(self):pass
 @Slot(str)
 def openCover(self,k):self.actions.append(('cover',k));self.at=int(k.split(':')[-1]);self.changed.emit()
 @Slot(str)
 def operate(self,op):
  self.actions.append((op,))
  if op=='subscribe' and not self.collected:self.collected=True;self.changed.emit()
 @Slot()
 def confirmUnsubscribe(self):self.actions.append(('unsubscribe',));self.collected=False;self.changed.emit()
 @Slot()
 def refresh(self):self.actions.append(('refresh',))
 @Slot(int)
 def preview(self,n):self.actions.append(('preview',n))
 @Slot(int)
 def playSong(self,n):self.actions.append(('song',n))
class Backend(QObject):
 changed=Signal()
 @Property('QVariantMap',notify=changed)
 def state(self):return dict(dark=False,reduced=False,queueOpen=False,accountProviderName='收藏歌单')
 @Property('QVariantMap',notify=changed)
 def messages(self):return dict(state=dict(open=False))
errors=[]
from PySide6.QtCore import qInstallMessageHandler
def log(kind,ctx,text):
 if any(k in text for k in ['TypeError','ReferenceError','Binding loop','unavailable','Unexpected token']):errors.append(text)
qInstallMessageHandler(log)
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);art=[]
 for i,color in enumerate(['#8b8e76','#4b5b50','#b6a58c']):
  image=QImage(640,640,QImage.Format_RGB32);image.fill(QColor(color));path=d/f'cover{i}.png';image.save(str(path));art.append(QUrl.fromLocalFile(str(path)).toString())
 for name in ['PlaylistShowcase','RecordStack','LiquidGlass']:
  origin=repo/'maintained/Qt/qml'/f'{name}.qml';shutil.copyfile(origin if origin.exists() else src/'Qt/qml'/f'{name}.qml',d/f'{name}.qml')
  # Runtime loading accepts some syntax rejected by the release cache compiler.
  compiler=Path(QLibraryInfo.path(QLibraryInfo.LibraryExecutablesPath))/('qmlcachegen.exe' if os.name=='nt' else 'qmlcachegen')
  subprocess.run([str(compiler),'--only-bytecode','-o',str(d/f'{name}.qmlc'),str(d/f'{name}.qml')],check=True)
 entries=[]
 for name in ['liquidGlass','magazineEdgeFade']:
  origin=repo/'maintained/Qt/shaders'/f'{name}.frag'
  if not origin.exists():origin=src/'Qt/shaders'/f'{name}.frag'
  out=d/f'{name}.frag.qsb';subprocess.run(['/root/.local/bin/pyside6-qsb','--glsl','150,300es','--hlsl','50','--msl','12','-o',str(out),str(origin)],check=True)
  entries.append('<file alias="'+name+'.frag.qsb">'+str(out)+'</file>')
 qrc=d/'shaders.qrc';qrc.write_text('<RCC><qresource prefix="/shaders">'+''.join(entries)+'</qresource></RCC>');subprocess.run(['/root/.local/bin/pyside6-rcc','--binary','-o',str(d/'shaders.rcc'),str(qrc)],check=True);assert QResource.registerResource(str(d/'shaders.rcc'))
 (d/'Harness.qml').write_text('''import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.ApplicationWindow {id:root;visible:true;width:1600;height:900;property real u:height/1080
Rectangle {id:bg;anchors.fill:parent;color:"#d9d4c8";Repeater {model:18;Rectangle {x:index*120-900;y:-300;width:55;height:1800;rotation:28;color:"#e9e4d8"}}}
PlaylistShowcase {id:page;controller:fixture;background:bg;x:root.width*.50520833-28*root.u;y:400*root.u;width:root.width-x-31*root.u;height:440*root.u;unit:root.u}
}''')
 c=Controller(art);b=Backend();engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('fixture',c);engine.rootContext().setContextProperty('rhine',b);engine.rootContext().setContextProperty('rhineFontFamily',font);engine.load(QUrl.fromLocalFile(str(d/'Harness.qml')));assert engine.rootObjects(),errors;w=engine.rootObjects()[0];w.requestActivate();QTest.qWait(300)
 def find(name):
  def descend(o):
   if o.objectName()==name:return o
   for ch in o.childItems():
    f=descend(ch)
    if f:return f
  return descend(w.contentItem())
 def click(o):assert o is not None;QTest.mouseClick(w,Qt.LeftButton,Qt.NoModifier,o.mapToScene(o.boundingRect().center()).toPoint());QTest.qWait(60)
 for width,height in [(1600,900),(960,540),(960,720),(1920,1080)]:
  w.setWidth(width);w.setHeight(height);QTest.qWait(100);page=find('playlistShowcase');stack=find('showcaseRecordStack');assert stack.x()>page.width()*.6;assert page.x()>width*.45 and page.width()<width*.55 and page.y()>=height*.36 and page.height()<height*.42
  title=find('showcaseTitle');assert title.x()+title.width()<stack.x()+stack.width()*.1
  for name in ['showcasePlay','showcaseShuffle','showcaseCollect','showcaseMore']:
   button=find(name);assert button.mapToItem(page,button.boundingRect().bottomRight()).x()<stack.x()
  w.grabWindow().save(str(repo.parent/f'g79-showcase-{width}x{height}.png'))
 w.setWidth(1600);w.setHeight(900);QTest.qWait(80)
 click(find('showcaseMore'));click(find('showcaseAppend'));assert c.actions[-1]==('append',)
 click(find('showcaseMore'));click(find('showcaseCopy'));assert c.actions[-1]==('copy',)
 click(find('showcaseMore'));click(find('showcaseDetails'));assert c.actions[-1]==('details',)
 click(find('showcasePlay'));assert c.actions[-1]==('play',)
 QTest.keyClick(w,Qt.Key_Space);QTest.qWait(50);assert c.actions[-1]==('shuffle',),(c.actions[-5:],w.isActive())
 QTest.keyClick(w,Qt.Key_F);QTest.qWait(50);assert c.collected
 QTest.keyClick(w,Qt.Key_Tab);QTest.qWait(50);assert find('showcaseSongPreview').isVisible()
 QTest.keyClick(w,Qt.Key_Down);QTest.qWait(30);assert c.actions[-1]==('preview',0)
 QTest.keyClick(w,Qt.Key_Return);QTest.qWait(30);assert c.actions[-1]==('song',0)
 def wheel(item):
  local=item.mapToScene(item.boundingRect().center());globalPoint=QPointF(w.mapToGlobal(local.toPoint()))
  event=QWheelEvent(local,globalPoint,QPoint(),QPoint(0,-120),Qt.NoButton,Qt.NoModifier,Qt.ScrollUpdate,False);QCoreApplication.sendEvent(w,event);QTest.qWait(300)
 listing=find('showcaseSongPreview');oldY=listing.property('contentY');wheel(listing);assert listing.property('contentY')>oldY and c.at==0
 oldY=listing.property('contentY');wheel(find('showcaseRecordStack'));assert listing.property('contentY')>oldY and c.at==0
 QTest.keyClick(w,Qt.Key_Tab);QTest.qWait(30);wheel(listing);QTest.qWait(600);assert c.at==1,c.actions
 QTest.keyClick(w,Qt.Key_Left);QTest.qWait(800);assert c.at==0,c.actions
 QTest.keyClick(w,Qt.Key_Right);QTest.qWait(800);assert c.at==1,c.actions
 QTest.keyClick(w,Qt.Key_Left);QTest.qWait(800);assert c.at==0,c.actions
 # Same-key metadata updates cannot replace the cached record source.
 image=find('playlistMainCover');source=image.property('source');c.changed.emit();QTest.qWait(80);assert image.property('source')==source
 assert not errors,errors
 print('G79 real QML passed: four sizes, right-side cover balance, actual mouse/play and Space/F/Tab/arrows/Enter behavior, reverse turns and stable image source.')
 w.close();engine.deleteLater();QTest.qWait(50)
