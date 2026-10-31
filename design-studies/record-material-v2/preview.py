"""Real archive component, mouse and keyboard QA; fixture artwork never ships."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import PySide6
import tempfile,shutil,subprocess
from PySide6.QtCore import QLibraryInfo,QObject,Signal,Property,Slot,QUrl,Qt,QPointF,QPoint,QCoreApplication,QResource
from PySide6.QtGui import QGuiApplication,QImage,QColor,QFontDatabase,QWheelEvent,QPainter
from PySide6.QtQml import QQmlApplicationEngine,QQmlComponent
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
repo=Path(os.environ['RHINE_MATERIAL_REPO']);src=Path(os.environ.get('RHINE_TEST_SOURCE',repo.parent/'upstream'));app=QGuiApplication([])
output=Path(os.environ.get('RHINE_TEST_OUTPUT',repo.parent));output.mkdir(parents=True,exist_ok=True)
def qt_tool(name):
 native=Path(PySide6.__file__).resolve().parent/(name+'.exe' if os.name=='nt' else name)
 return str(native) if native.is_file() else shutil.which('pyside6-'+name)
fid=QFontDatabase.addApplicationFont(str(src/'Assets/fonts/RhineMiSans-regular.otf'));font=QFontDatabase.applicationFontFamilies(fid)[0]
class Controller(QObject):
 changed=Signal()
 lane=2
 def __init__(self,art):super().__init__();self.art=art.copy();self.at=0;self.actions=[];self.collected=False
 @Property('QVariantMap',notify=changed)
 def info(self):return dict(key='netease:playlist:'+str(self.at),id=str(self.at),kind='playlist',title=['电子、摇滚、实验、意识、迷走','沿着夜色缓慢生长','午后的松弛感'][self.at],recordLane=self.lane,identities=[dict(id='7',name='Artist one / 很长的艺人名字'),dict(id='8',name='Second artist')],identityAvatar=self.art[0],identityCanOpen=True,loaded=True,artist='QA / 显式离线数据',description='在电子的律动与摇滚的呐喊之间，收集那些游走于秩序与混沌的声音。\n这里是关于实验、意识与边界的歌单，适合在深夜、旅途中或独处时聆听。\n' * 4,tags=['摇滚','实验'],createdDate='2025-06-12',creatorID='7',cover=self.art[self.at],total=15,durationLabel='1 小时 26 分钟',canSubscribe=True,subscribed=self.collected,editable=False,recordsLoading=False,recordsMore=False,recordPosition=self.at+1,recordCount=3)
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
 @Slot(str)
 def openIdentity(self,id):self.actions.append(('artist',id))
 @Slot()
 def retryIdentityAvatar(self):self.actions.append(('avatar_retry',))
 @Slot(int)
 def playSong(self,n):self.actions.append(('song',n))
class Backend(QObject):
 changed=Signal()
 dark=False
 reduced=False
 def __init__(self):super().__init__();self.navIndex=3;self.actions=[]
 @Slot(str)
 def action(self,action):
  self.actions.append(action)
  if action=='column-next':self.navIndex=self.navIndex%5+1
  elif action=='column-prev':self.navIndex=(self.navIndex-2)%5+1
  self.changed.emit()
 @Property(int,notify=changed)
 def navPosition(self):return self.navIndex
 @Property('QVariantMap',notify=changed)
 def state(self):return dict(dark=self.dark,reduced=self.reduced,queueOpen=False,accountProviderName='收藏歌单')
 @Property('QVariantMap',notify=changed)
 def messages(self):return dict(state=dict(open=False))
errors=[]
from PySide6.QtCore import qInstallMessageHandler
def log(kind,ctx,text):
 if any(k in text for k in ['TypeError','ReferenceError','Binding loop','unavailable','Unexpected token','Cannot override','Cannot assign','is not defined','setPaused() cannot']):errors.append(text)
qInstallMessageHandler(log)
class PlaybackFixture(Controller):
 playbackChanged=Signal()
 linesChanged=Signal()
 playing=True
 loading=False
 missingCover=False
 currentLine=1
 @Property('QVariantMap',notify=Controller.changed)
 def info(self):
  return dict(session='netease:'+str(self.at+1),id=str(self.at+1),title=['晚风里的唱片','另一首歌曲','第三首'][self.at],album='专辑名称',albumID='8',artist='RHINE / 材质研究',artists=[dict(id='7',name='Artist one'),dict(id='8',name='Second artist')],coverPixels='' if self.missingCover else self.art[self.at],artistAvatar=self.art[0],date='2024-03-02',tags=['Jazz','Soul'],canLike=True,likeKnown=True,likeBusy=False,liked=False)
 @Property('QVariantMap',notify=playbackChanged)
 def playback(self):return dict(playing=self.playing and not self.loading,loading=self.loading,seekable=True,index=self.currentLine,timed=True,lyricStatus='ready')
 @Property('QVariantList',notify=linesChanged)
 def lines(self):return [dict(startMs=i*2500,text=['把晚风留在这一刻','让音乐慢慢流过房间','不必急着去往下个地方'][i%3],translation='' ) for i in range(30)]
 @Slot(str)
 def operate(self,op):self.actions.append((op,))
 @Slot(int,str)
 def seekLine(self,index,session):self.actions.append(('seek',index,session))
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);art=[]

 # A deliberately non-circular poster: the paper centre must be independent
 # of cover art, while fixed varnish stays aligned as this artwork turns.
 from PySide6.QtGui import QLinearGradient,QFont
 from PySide6.QtCore import QRectF
 for i,palette in enumerate([['#23444c','#e4b091','#d58b64'],['#282f44','#d4bdcc','#ab778d'],['#3d5342','#e8d8a9','#c3a65c']]):
  image=QImage(640,640,QImage.Format_ARGB32_Premultiplied);image.fill(Qt.transparent)
  painter=QPainter(image);painter.setRenderHint(QPainter.Antialiasing)
  painter.setClipRegion(__import__('PySide6.QtGui',fromlist=['QRegion']).QRegion(0,0,640,640,__import__('PySide6.QtGui',fromlist=['QRegion']).QRegion.Ellipse))
  gradient=QLinearGradient(0,0,640,640);gradient.setColorAt(0,QColor(palette[0]));gradient.setColorAt(1,QColor(palette[1]));painter.fillRect(0,0,640,640,gradient)
  painter.setPen(Qt.NoPen);painter.setBrush(QColor(palette[2]));painter.drawEllipse(330,85,190,190)
  painter.setBrush(QColor(palette[0]));painter.drawEllipse(-180,350,950,640)
  painter.setPen(QColor('#eee8d8'));painter.setFont(QFont(font,38,QFont.Light));painter.drawText(QRectF(60,180,450,100),Qt.AlignLeft,'AFTER HOURS')
  painter.setFont(QFont(font,12));painter.drawText(QRectF(65,270,400,50),Qt.AlignLeft,'R H I N E   /   M A T E R I A L   S T U D Y')
  painter.end();path=d/f'cover{i}.png';image.save(str(path));art.append(QUrl.fromLocalFile(str(path)).toString())
 for name in ['ArchiveReading','PlaylistShowcase','RecordStack','LiquidGlass','ArchiveActionIcon','RhineIcon','ArtistMarquee','ArchiveNavigator','NowPlayingPanel','RecordTonearm','NowPlayingShortcut']:
  origin=repo/'maintained/Qt/qml'/f'{name}.qml';shutil.copyfile(origin if origin.exists() else src/'Qt/qml'/f'{name}.qml',d/f'{name}.qml')
  # Runtime loading accepts some syntax rejected by the release cache compiler.
  compiler=Path(QLibraryInfo.path(QLibraryInfo.LibraryExecutablesPath))/('qmlcachegen.exe' if os.name=='nt' else 'qmlcachegen')
  subprocess.run([str(compiler),'--only-bytecode','-o',str(d/f'{name}.qmlc'),str(d/f'{name}.qml')],check=True)
 entries=[]
 for name in ['liquidGlass','magazineEdgeFade','archiveIcon','softEdgeFade','recordAtmosphere']:
  origin=repo/'maintained/Qt/shaders'/f'{name}.frag'
  if not origin.exists():origin=src/'Qt/shaders'/f'{name}.frag'
  out=d/f'{name}.frag.qsb';subprocess.run([qt_tool('qsb'),'--glsl','150,300es','--hlsl','50','--msl','12','-o',str(out),str(origin)],check=True)
  entries.append('<file alias="'+name+'.frag.qsb">'+str(out)+'</file>')
 icons=''.join('<file alias="archive-'+name+'.png">'+str(repo/'maintained/Assets/icons'/('archive-'+name+'.png'))+'</file>' for name in ['play','shuffle','more'])
 icons+=''.join('<file alias="song-like-'+name+'.png">'+str(repo/'maintained/Assets/icons'/('song-like-'+name+'.png'))+'</file>' for name in ['on','off'])
 qrc=d/'shaders.qrc';qrc.write_text('<RCC><qresource prefix="/shaders">'+''.join(entries)+'</qresource><qresource prefix="/icons">'+icons+'</qresource></RCC>',encoding='utf-8');subprocess.run([qt_tool('rcc'),'--binary','-o',str(d/'shaders.rcc'),str(qrc)],check=True);assert QResource.registerResource(str(d/'shaders.rcc'))

 (d/'Harness.qml').write_text("""import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.ApplicationWindow {id:root;visible:true;width:1540;height:700;property real u:1.5
Item {id:base;anchors.fill:parent;Rectangle {id:bg;z:-2;anchors.fill:parent;color:rhine.state.dark?"#30362c":"#d9d4c8";Repeater {model:18;Rectangle {x:index*120-900;y:-300;width:55;height:1800;rotation:28;color:rhine.state.dark?"#3e4637":"#e9e4d8"}}}}
NowPlayingShortcut {unit:root.u;x:root.width-98*root.u;y:root.height-69*root.u;width:36*root.u;height:width;available:true;playing:fixture.playback.playing;dark:rhine.state.dark;onOpenRequested:rhine.action("player:now-playing")}
ArchiveReading {id:reading;dark:rhine.state.dark;background:bg;materialLayer:base;controller:archive;playbackController:fixture;playing:true;collection:true;unit:root.u;x:14;y:20;width:root.width-28;height:root.height-40}
}""")
 c=PlaybackFixture(art);a=Controller(art);b=Backend();engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('fixture',c);engine.rootContext().setContextProperty('archive',a);engine.rootContext().setContextProperty('rhine',b);engine.rootContext().setContextProperty('rhineFontFamily',font);engine.load(QUrl.fromLocalFile(str(d/'Harness.qml')));assert engine.rootObjects(),errors;w=engine.rootObjects()[0];w.requestActivate();QTest.qWait(250)
 def find(name):
  def walk(o):
   if o.objectName()==name:return o
   for ch in o.childItems():
    found=walk(ch)
    if found:return found
  return walk(w.contentItem())
 def click(o):assert o is not None;QTest.mouseClick(w,Qt.LeftButton,Qt.NoModifier,o.mapToScene(o.boundingRect().center()).toPoint());QTest.qWait(60)
 def wait_until(predicate,timeout=5000):
  for _ in range(timeout//20):
   if predicate():return
   QTest.qWait(20)
  assert predicate(),('timed out',page.property('swapStage'),page.property('swapProgress'),errors[-6:])
 reading=find('archiveReading');page=find('nowPlayingPanel')
 QTest.qWait(2000)
 QTest.mouseMove(w,QPoint(3,3));c.playing=False;c.playbackChanged.emit();QTest.qWait(600)
 page.setProperty('spinPhase',.08)
 find('nowRecordPrint').setProperty('spinAngle',28);find('nowTonearmPlane').setProperty('pose',0);QTest.qWait(650)
 w.grabWindow().save(str(output/'material-v2.png'))
 b.dark=True;b.changed.emit();QTest.qWait(300);w.grabWindow().save(str(output/'material-v2-dark.png'));b.dark=False;b.changed.emit();QTest.qWait(150)
 print('PREVIEW_SAVED',output,errors,flush=True)
 w.close();engine.deleteLater();QTest.qWait(30)
