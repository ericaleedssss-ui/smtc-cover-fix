"""Real archive component, mouse and keyboard QA; fixture artwork never ships."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile,shutil,subprocess
from PySide6.QtCore import QLibraryInfo,QObject,Signal,Property,Slot,QUrl,Qt,QPointF,QPoint,QCoreApplication,QResource
from PySide6.QtGui import QGuiApplication,QImage,QColor,QFontDatabase,QWheelEvent,QPainter
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
class PlaybackFixture(Controller):
 playbackChanged=Signal()
 linesChanged=Signal()
 playing=True
 currentLine=1
 @Property('QVariantMap',notify=Controller.changed)
 def info(self):
  return dict(session='netease:'+str(self.at+1),id=str(self.at+1),title=['现在正在播放的真实歌曲','另一首歌曲','第三首'][self.at],album='专辑名称',artist='Artist one / Second artist',artists=[dict(id='7',name='Artist one'),dict(id='8',name='Second artist')],coverPixels=self.art[self.at],artistAvatar=self.art[0],date='2024-03-02',tags=['Jazz','Soul'],canLike=True,likeKnown=True,likeBusy=False,liked=False)
 @Property('QVariantMap',notify=playbackChanged)
 def playback(self):return dict(playing=self.playing,seekable=True,index=self.currentLine,timed=True,lyricStatus='ready')
 @Property('QVariantList',notify=linesChanged)
 def lines(self):return [dict(startMs=i*2500,text=('新歌' if self.at else '在火星上跳舞吧')+' · '+str(i+1),translation='让重力暂时失效') for i in range(30)]
 @Slot(str)
 def operate(self,op):self.actions.append((op,))
 @Slot(int,str)
 def seekLine(self,index,session):self.actions.append(('seek',index,session))
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);art=[]
 for i,color in enumerate(['#8b8e76','#4b5b50','#b6a58c']):
  image=QImage(640,640,QImage.Format_ARGB32_Premultiplied);image.fill(Qt.transparent);painter=QPainter(image);painter.setRenderHint(QPainter.Antialiasing);painter.setPen(Qt.NoPen);painter.setBrush(QColor(color));painter.drawEllipse(2,2,636,636);painter.setBrush(QColor('#a9b399'));painter.drawEllipse(90,130,260,260);painter.end();path=d/f'cover{i}.png';image.save(str(path));art.append(QUrl.fromLocalFile(str(path)).toString())
 for name in ['ArchiveReading','PlaylistShowcase','RecordStack','LiquidGlass','ArchiveActionIcon','RhineIcon','ArtistMarquee','ArchiveNavigator','NowPlayingPanel']:
  origin=repo/'maintained/Qt/qml'/f'{name}.qml';shutil.copyfile(origin if origin.exists() else src/'Qt/qml'/f'{name}.qml',d/f'{name}.qml')
  # Runtime loading accepts some syntax rejected by the release cache compiler.
  compiler=Path(QLibraryInfo.path(QLibraryInfo.LibraryExecutablesPath))/('qmlcachegen.exe' if os.name=='nt' else 'qmlcachegen')
  subprocess.run([str(compiler),'--only-bytecode','-o',str(d/f'{name}.qmlc'),str(d/f'{name}.qml')],check=True)
 entries=[]
 for name in ['liquidGlass','magazineEdgeFade','archiveIcon','softEdgeFade','recordAtmosphere']:
  origin=repo/'maintained/Qt/shaders'/f'{name}.frag'
  if not origin.exists():origin=src/'Qt/shaders'/f'{name}.frag'
  out=d/f'{name}.frag.qsb';subprocess.run(['/root/.local/bin/pyside6-qsb','--glsl','150,300es','--hlsl','50','--msl','12','-o',str(out),str(origin)],check=True)
  entries.append('<file alias="'+name+'.frag.qsb">'+str(out)+'</file>')
 icons=''.join('<file alias="archive-'+name+'.png">'+str(repo/'maintained/Assets/icons'/('archive-'+name+'.png'))+'</file>' for name in ['play','shuffle','more'])
 icons+=''.join('<file alias="song-like-'+name+'.png">'+str(repo/'maintained/Assets/icons'/('song-like-'+name+'.png'))+'</file>' for name in ['on','off'])
 qrc=d/'shaders.qrc';qrc.write_text('<RCC><qresource prefix="/shaders">'+''.join(entries)+'</qresource><qresource prefix="/icons">'+icons+'</qresource></RCC>');subprocess.run(['/root/.local/bin/pyside6-rcc','--binary','-o',str(d/'shaders.rcc'),str(qrc)],check=True);assert QResource.registerResource(str(d/'shaders.rcc'))

 (d/'Harness.qml').write_text("""import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.ApplicationWindow {id:root;visible:true;width:1600;height:900;property real u:height/1080
Item {id:base;anchors.fill:parent;Rectangle {id:bg;z:-2;anchors.fill:parent;color:rhine.state.dark?"#30362c":"#d9d4c8";Repeater {model:18;Rectangle {x:index*120-900;y:-300;width:55;height:1800;rotation:28;color:rhine.state.dark?"#3e4637":"#e9e4d8"}}}}
ArchiveReading {id:reading;dark:rhine.state.dark;background:bg;materialLayer:base;controller:archive;playbackController:fixture;playing:true;collection:true;unit:root.u;x:root.width*.50520833-28*root.u;y:400*root.u;width:root.width-x-31*root.u;height:440*root.u}
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
 reading=find('archiveReading');glass=find('textFrostedPanel');assert find('nowPlayingPanel') and glass
 for width,height in [(1600,900),(960,540),(960,720),(1920,1080)]:
  w.setWidth(width);w.setHeight(height);QTest.qWait(80);page=find('nowPlayingPanel');disc=find('nowRecord');lyric=find('nowPlayingLyrics');assert disc.x()>page.width()*.6 and lyric.x()+lyric.width()<disc.x()+5*height/1080
  assert page.height()==440*height/1080 and abs(page.width()-reading.width())<1
  w.grabWindow().save(str(repo.parent/f'g86-now-playing-{width}x{height}.png'))
 w.setWidth(1600);w.setHeight(900);QTest.qWait(80)
 spin=find('nowRecordPrint');base=find('nowRecordBase');platter=find('nowRecordPlatter');edge=find('nowRecordContactEdge')
 assert base and platter and edge and find('nowRecordShadow')
 assert base.findChild(QObject,'nowRecordTilt').property('angle')==32
 assert edge.y()==3*page.property('unit') and base.rotation()==0 and platter.rotation()==0
 angle=spin.property('spinAngle');QTest.qWait(180);assert spin.property('spinAngle')>angle+.3
 assert spin.rotation()==0 and base.rotation()==0 and platter.rotation()==0 and edge.rotation()==0
 c.playing=False;c.playbackChanged.emit();QTest.qWait(200);angle=spin.property('spinAngle');QTest.qWait(150);assert abs(spin.property('spinAngle')-angle)<.01 and find('nowRecordRings').opacity()==0
 # Four orientations must change the printed artwork, never the fixed rim/plane.
 points=[QPointF(0,0),QPointF(base.width(),0),QPointF(0,base.height()),QPointF(base.width(),base.height())]
 fixed=[base.mapToScene(p) for p in points]
 for turn in [0,90,180,270]:
  spin.setProperty('spinAngle',turn);QTest.qWait(35)
  assert [base.mapToScene(p) for p in points]==fixed and spin.rotation()==0
  w.grabWindow().save(str(repo.parent/f'g87-fixed-disc-{turn}.png'))
 c.playing=True;c.playbackChanged.emit();QTest.qWait(120);assert spin.property('spinAngle')>angle+.1
 page=find('nowPlayingPanel');page.setVisible(False);angle=spin.property('spinAngle');QTest.qWait(120);assert abs(spin.property('spinAngle')-angle)<.01;page.setVisible(True)
 click(find('nowComments'));assert c.actions[-1]==('comments',)
 click(find('nowLike'));assert c.actions[-1]==('like',)
 click(find('nowShare'));assert c.actions[-1]==('share',)
 click(find('nowMore'));click(find('nowCollect'));assert c.actions[-1]==('collect',)
 click(find('nowDetails'));assert c.actions[-1]==('details',)
 click(find('nowPlayingTitleHit'));assert c.actions[-1]==('details',)
 listing=find('nowPlayingLyrics');old=listing.property('contentY');pos=listing.mapToScene(listing.boundingRect().center());event=QWheelEvent(pos,QPointF(w.mapToGlobal(pos.toPoint())),QPoint(),QPoint(0,-120),Qt.NoButton,Qt.NoModifier,Qt.ScrollUpdate,False);QCoreApplication.sendEvent(w,event);QTest.qWait(80);assert listing.property('contentY')>old and not page.property('following') and not a.actions
 QTest.qWait(300);before=listing.property('contentY');c.currentLine=2;c.playbackChanged.emit();QTest.qWait(70);assert listing.property('contentY')==before
 click(find('nowLyricsFollow'));click(find('nowLyric_2'));assert c.actions[-1]==('seek',2,'netease:1')
 c.at=1;c.currentLine=0;c.changed.emit();c.linesChanged.emit();c.playbackChanged.emit();QTest.qWait(120);assert find('nowPlayingTitle').property('text')=='另一首歌曲' and page.property('following')
 b.dark=True;b.changed.emit();QTest.qWait(80);w.grabWindow().save(str(repo.parent/'g86-now-playing-dark.png'))
 reading.setProperty('playing',False);QTest.qWait(80);assert find('playlistShowcase') and find('textFrostedPanel') is glass and not find('nowPlayingPanel')
 assert not errors,errors
 print('G86 real QML passed: original glass identity, four layouts, tilted disc motion/pause/hidden stop, lyrics scroll/follow/seek, current song switch and all four actions plus collect/details.')
 w.close();engine.deleteLater();QTest.qWait(50)
