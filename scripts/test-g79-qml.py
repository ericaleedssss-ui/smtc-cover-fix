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
 def state(self):return dict(dark=self.dark,reduced=False,queueOpen=False,accountProviderName='收藏歌单')
 @Property('QVariantMap',notify=changed)
 def messages(self):return dict(state=dict(open=False))
errors=[]
from PySide6.QtCore import qInstallMessageHandler
def log(kind,ctx,text):
 if any(k in text for k in ['TypeError','ReferenceError','Binding loop','unavailable','Unexpected token','Cannot override','Cannot assign','is not defined']):errors.append(text)
qInstallMessageHandler(log)
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);art=[]
 for i,color in enumerate(['#8b8e76','#4b5b50','#b6a58c']):
  image=QImage(640,640,QImage.Format_RGB32);image.fill(QColor(color));path=d/f'cover{i}.png';image.save(str(path));art.append(QUrl.fromLocalFile(str(path)).toString())
 for name in ['ArchiveReading','PlaylistShowcase','RecordStack','LiquidGlass','ArchiveActionIcon','RhineIcon','ArtistMarquee','ArchiveNavigator','NowPlayingPanel']:
  origin=repo/'maintained/Qt/qml'/f'{name}.qml';shutil.copyfile(origin if origin.exists() else src/'Qt/qml'/f'{name}.qml',d/f'{name}.qml')
  # Runtime loading accepts some syntax rejected by the release cache compiler.
  compiler=Path(QLibraryInfo.path(QLibraryInfo.LibraryExecutablesPath))/('qmlcachegen.exe' if os.name=='nt' else 'qmlcachegen')
  subprocess.run([str(compiler),'--only-bytecode','-o',str(d/f'{name}.qmlc'),str(d/f'{name}.qml')],check=True)
 entries=[]
 for name in ['liquidGlass','magazineEdgeFade','archiveIcon','softEdgeFade']:
  origin=repo/'maintained/Qt/shaders'/f'{name}.frag'
  if not origin.exists():origin=src/'Qt/shaders'/f'{name}.frag'
  out=d/f'{name}.frag.qsb';subprocess.run(['/root/.local/bin/pyside6-qsb','--glsl','150,300es','--hlsl','50','--msl','12','-o',str(out),str(origin)],check=True)
  entries.append('<file alias="'+name+'.frag.qsb">'+str(out)+'</file>')
 icons=''.join('<file alias="archive-'+name+'.png">'+str(repo/'maintained/Assets/icons'/('archive-'+name+'.png'))+'</file>' for name in ['play','shuffle','more'])
 icons+=''.join('<file alias="song-like-'+name+'.png">'+str(repo/'maintained/Assets/icons'/('song-like-'+name+'.png'))+'</file>' for name in ['on','off'])
 qrc=d/'shaders.qrc';qrc.write_text('<RCC><qresource prefix="/shaders">'+''.join(entries)+'</qresource><qresource prefix="/icons">'+icons+'</qresource></RCC>');subprocess.run(['/root/.local/bin/pyside6-rcc','--binary','-o',str(d/'shaders.rcc'),str(qrc)],check=True);assert QResource.registerResource(str(d/'shaders.rcc'))
 (d/'Harness.qml').write_text('''import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.ApplicationWindow {id:root;visible:true;width:1600;height:900;property real u:height/1080
Item {id:base;anchors.fill:parent;Rectangle {id:bg;z:-2;anchors.fill:parent;color:rhine.state.dark?"#30362c":"#d9d4c8";Repeater {model:18;Rectangle {x:index*120-900;y:-300;width:55;height:1800;rotation:28;color:rhine.state.dark?"#3e4637":"#e9e4d8"}}}}
ArchiveReading {id:reading;dark:rhine.state.dark;background:bg;materialLayer:base;controller:fixture;collection:true;unit:root.u;x:root.width*.50520833-28*root.u;y:400*root.u;width:root.width-x-31*root.u;height:440*root.u}
ArchiveNavigator {controller:rhine;navigation:({index:rhine.navPosition,total:5,name:'收藏歌单'});unit:root.u;dark:rhine.state.dark;width:implicitWidth;height:implicitHeight;x:reading.x+(reading.width-width)/2;y:reading.y+reading.height+16*root.u;downOffset:reading.x-x}
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
  w.setWidth(width);w.setHeight(height);QTest.qWait(100);page=find('playlistShowcase');stack=find('showcaseRecordStack');assert stack.x()>page.width()*.6;assert page.x()==0 and page.y()==0;position=page.mapToScene(QPointF(0,0));assert position.x()>width*.45 and page.width()<width*.55 and position.y()>=height*.36 and page.height()<height*.42
  meta=find('showcaseMetadata');date=find('showcaseDate');assert date.mapToItem(meta,date.boundingRect().bottomRight()).x()<=meta.width()+1,(width,height,meta.width())
  nav=find('archiveNavigator');assert abs(nav.x()+nav.width()/2-position.x()-page.width()/2)<1
  assert nav.y()>=position.y()+page.height() and nav.y()+nav.height()<976*height/1080
  assert abs(find('archiveBrowseNext').mapToScene(QPointF()).x()-position.x())<1
  title=find('showcaseTitle');assert title.x()+title.width()<stack.x()+stack.width()*.1
  for name in ['showcasePlay','showcaseShuffle','showcaseCollect','showcaseMore']:
   button=find(name);assert button.mapToItem(page,button.boundingRect().bottomRight()).x()<stack.x()
  w.grabWindow().save(str(repo.parent/f'g79-showcase-{width}x{height}.png'))
 w.setWidth(1600);w.setHeight(900);QTest.qWait(80)
 # Only content changes. Both the host and original material must survive each switch.
 reading=find('archiveReading');material=find('textFrostedPanel');assert material is not None
 for mode in [False,True,False,True]:
  reading.setProperty('collection',mode);QTest.qWait(100)
  assert find('archiveReading') is reading and find('textFrostedPanel') is material
  assert len(w.findChildren(QObject,'textFrostedPanel'))==1
  assert bool(find('playlistShowcase'))==mode
 assert abs(material.property('radius')-22*900/1080)<.001
 content=find('playlistShowcase');reading.setVisible(False);QTest.qWait(30);reading.setVisible(True);QTest.qWait(30);assert find('playlistShowcase') is content
 # Turning frosting off releases sampling while leaving collection controls usable.
 reading.setProperty('frosted',False);QTest.qWait(60);assert find('textFrostedPanel') is None and find('showcasePlay') is not None
 reading.setProperty('frosted',True);QTest.qWait(60);material=find('textFrostedPanel');assert material is not None

 images=[o for o in w.findChildren(QObject,'archiveActionImage') if o.property('source').toString()]
 assert len(images)==3 and all(o.property('ready') for o in images)
 nav=find('archiveNavigator');assert nav is not None
 assert abs(nav.x()+nav.width()/2-reading.x()-reading.width()/2)<1
 assert nav.y()>=reading.y()+reading.height() and nav.y()+nav.height()<976*900/1080
 assert abs(find('archiveBrowseNext').mapToScene(QPointF()).x()-reading.x())<1
 click(find('archiveColumnNext'));assert b.actions[-1]=='column-next' and find('archiveColumnNumber').property('text')=='04 / 05'
 click(find('archiveColumnPrevious'));assert b.actions[-1]=='column-prev' and find('archiveColumnNumber').property('text')=='03 / 05'
 click(find('archiveBrowseNext'));assert b.actions[-1]=='next'
 assert find('showcaseTags').property('text')=='摇滚 / 实验' and find('showcaseDate').property('text')=='2025-06-12'
 meta=find('showcaseMetadata');assert find('showcaseDate').mapToItem(meta,find('showcaseDate').boundingRect().bottomRight()).x()<=meta.width()+1
 hint=find('showcaseTabHint');assert hint.x()>reading.width()*.7
 b.dark=True;b.changed.emit();QTest.qWait(100);w.grabWindow().save(str(repo.parent/'g82-archive-dark.png'));b.dark=False;b.changed.emit();QTest.qWait(60)
 marquee=find('archiveArtistMarquee');assert marquee.property('distance')>0
 marquee.setProperty('shift',-marquee.property('distance'));click(find('archiveArtist_8'));assert c.actions[-1]==('artist','8')
 marquee.setProperty('shift',0)
 click(find('showcaseTitle'));assert c.actions[-1]==('details',)
 click(find('showcaseMore'));click(find('showcaseAppend'));assert c.actions[-1]==('append',)
 click(find('showcaseMore'));click(find('showcaseCopy'));assert c.actions[-1]==('copy',)
 click(find('showcaseMore'));click(find('showcaseDetails'));assert c.actions[-1]==('details',)
 click(find('showcasePlay'));assert c.actions[-1]==('play',)
 QTest.keyClick(w,Qt.Key_Space);QTest.qWait(50);assert c.actions[-1]==('shuffle',),(c.actions[-5:],w.isActive())
 QTest.keyClick(w,Qt.Key_F);QTest.qWait(50);assert c.collected
 assert any(o.property('source').toString().endswith('song-like-on.png') for o in w.findChildren(QObject,'showcaseCollectArtwork'))
 QTest.keyClick(w,Qt.Key_Tab);QTest.qWait(50);assert find('showcaseSongPreview').isVisible()
 QTest.keyClick(w,Qt.Key_Down);QTest.qWait(30);assert c.actions[-1]==('preview',0)
 QTest.keyClick(w,Qt.Key_Return);QTest.qWait(30);assert c.actions[-1]==('song',0)
 def wheel(item):
  local=item.mapToScene(item.boundingRect().center());globalPoint=QPointF(w.mapToGlobal(local.toPoint()))
  event=QWheelEvent(local,globalPoint,QPoint(),QPoint(0,-120),Qt.NoButton,Qt.NoModifier,Qt.ScrollUpdate,False);QCoreApplication.sendEvent(w,event);QTest.qWait(300)
 listing=find('showcaseSongPreview');oldY=listing.property('contentY');wheel(listing);assert listing.property('contentY')>oldY and c.at==0
 for _ in range(8):wheel(listing)
 assert c.at==0
 wheel(find('showcaseRecordStack'));QTest.qWait(600);assert c.at==1
 QTest.keyClick(w,Qt.Key_Left);QTest.qWait(800);assert c.at==0
 description=find('showcaseDescription');oldY=description.property('contentY');wheel(description);assert description.property('contentY')>oldY and c.at==0;
 for _ in range(8):wheel(description)
 assert c.at==0
 wheel(find('showcaseRecordStack'));QTest.qWait(600);assert c.at==1,c.actions
 QTest.keyClick(w,Qt.Key_Left);QTest.qWait(800);assert c.at==0,c.actions
 QTest.keyClick(w,Qt.Key_Right);QTest.qWait(800);assert c.at==1,c.actions
 QTest.keyClick(w,Qt.Key_Left);QTest.qWait(800);assert c.at==0,c.actions
 # A real cold image must leave the old group visible until decode finishes.
 import threading,time,http.server
 payload=(d/'cover1.png').read_bytes()
 class Handler(http.server.BaseHTTPRequestHandler):
  def do_GET(self):
   time.sleep(1.4 if 'slow-rear' in self.path else .25);self.send_response(200);self.send_header('Content-Type','image/png');self.end_headers()
   try:self.wfile.write(payload)
   except (BrokenPipeError,ConnectionResetError):pass
  def log_message(self,*args):pass
 server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
 old=find('playlistMainCover').property('source');c.art[1]=f'http://127.0.0.1:{server.server_port}/cold.png';c.lane=3;c.at=1;c.changed.emit();QTest.qWait(60)
 stack=find('showcaseRecordStack');assert stack.property('groupStage')==1 and find('playlistMainCover').property('source')==old
 deadline=time.monotonic()+4
 while stack.property('groupStage') and time.monotonic()<deadline:QTest.qWait(40)
 assert stack.property('groupStage')==0 and stack.property('groupOpacity')==1,(stack.property('groupStage'),stack.property('groupOpacity'),errors)
 c.lane=2;c.at=0;c.changed.emit();QTest.qWait(90);w.grabWindow().save(str(repo.parent/'g84-group-exit.png'));assert stack.property('groupStage')==2 and stack.property('groupShift')>2 and stack.property('groupScale')<.995;QTest.qWait(500);assert stack.property('groupStage')==0 and stack.property('groupShift')==0
 # An offscreen entering cover must not block a ready adjacent cover.
 c.art[2]=f'http://127.0.0.1:{server.server_port}/slow-rear.png';c.changed.emit();find('recordImage_netease:playlist:2').setProperty('source',QUrl(c.art[2]));QTest.qWait(30)
 QTest.keyClick(w,Qt.Key_Right);QTest.qWait(80);assert stack.property('turning') and not stack.property('queuedKey')
 QTest.qWait(700);assert c.at==1
 c.art=art.copy();c.at=0;c.changed.emit();QTest.qWait(650)
 # A burst coalesces to one recent direction; stale detents never replay later.
 for _ in range(3):QTest.keyClick(w,Qt.Key_Right)
 QTest.qWait(1800);assert c.at==2 and find('playlistShowcase').property('pendingMoves')==0,(c.at,c.actions[-6:],stack.property('busy'))
 before=len(c.actions);QTest.qWait(500);assert len(c.actions)==before
 server.shutdown();server.server_close()
 # Same-key metadata updates cannot replace the cached record source.
 image=find('playlistMainCover');source=image.property('source');c.changed.emit();QTest.qWait(80);assert image.property('source')==source
 assert find('textFrostedPanel') is material
 assert not errors,errors
 print('G81 shared original glass identity across content switches and frosting preference passed; G79 real QML passed: four sizes, right-side cover balance, actual mouse/play and Space/F/Tab/arrows/Enter behavior, reverse turns and stable image source.')
 w.close();engine.deleteLater();QTest.qWait(50)
