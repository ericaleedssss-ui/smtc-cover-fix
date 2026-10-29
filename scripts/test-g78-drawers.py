"""Exercise production drawer geometry, material, pointer isolation and navigation alignment."""
from pathlib import Path
import os,runpy,tempfile,shutil,subprocess
repo=Path(__file__).resolve().parents[1]
shared=runpy.run_path(str(repo/'scripts/test-g77-qml.py'))
from PySide6.QtCore import QObject,Property,Signal,Slot,QUrl,QPoint,QPointF,Qt,QResource
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
c=shared['Controller']();app=shared['app'];errors=shared['errors']
class Backend(QObject):
 changed=Signal()
 def __init__(self):
  super().__init__();self.actions=[];self.s=dict(mode='archive',directoryOpen=False,modal='',dark=False,queueOpen=False,queueCollectionOpen=False,drawerBounds=dict(x=832,y=116,width=430,height=842),queueRows=[dict(index=0,key='netease:7',id='7',title='队列测试歌曲',artist='测试歌手',durationLabel='04:20',cover='',sourceTitle='测试来源',sourceLink=False)],queueCount=1,queueOffset=0,queuePageSize=40,queueCanCollect=False,queueRoaming=False,accountUID='42',accountProvider='netease',accountName='Erica',accountAvatar='',navigationCreated=[],navigationCollected=[])
 @Property('QVariantMap',notify=changed)
 def state(self):return self.s
 @Property(QObject,constant=True)
 def messages(self):return c
 @Slot(str)
 def action(self,s):
  self.actions.append(s)
  if s=='queue-close':self.queue(False)
  if s=='player:open':self.queue(not self.s['queueOpen'])
 @Slot(bool)
 def queue(self,on):self.s={**self.s,'queueOpen':on};self.changed.emit()
 @Slot(str)
 def hoverLink(self,s):pass
 @Slot(str,float,float)
 def hoverItem(self,s,x,y):pass
b=Backend()
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp)
 for name in ['DrawerFrost','DrawerInputGate','MessageDrawer','PlayerQueueGlass','SideNavigation','RhineIcon','LiquidGlass']:
  origin=repo/'maintained/Qt/qml'/f'{name}.qml';shutil.copyfile(origin if origin.exists() else repo.parent/'upstream/Qt/qml'/f'{name}.qml',d/f'{name}.qml')
 shutil.copyfile(repo.parent/'upstream/Qt/qml/GlobalTools.qml',d/'GlobalTools.qml')
 entries=[]
 for name in ['liquidGlass','softEdgeFade']:
  origin=repo/'maintained/Qt/shaders'/f'{name}.frag'
  if not origin.exists():origin=repo.parent/'upstream/Qt/shaders'/f'{name}.frag'
  out=d/f'{name}.frag.qsb'
  subprocess.run(['/root/.local/bin/pyside6-qsb','--glsl','150,300es','--hlsl','50','--msl','12','-o',str(out),str(origin)],check=True)
  entries.append('<file alias="'+name+'.frag.qsb">'+str(out)+'</file>')
 qrc=d/'shaders.qrc';qrc.write_text('<RCC><qresource prefix="/shaders">'+''.join(entries)+'</qresource></RCC>',encoding='utf-8')
 subprocess.run(['/root/.local/bin/pyside6-rcc','--binary','-o',str(d/'shaders.rcc'),str(qrc)],check=True);assert QResource.registerResource(str(d/'shaders.rcc'))

 (d/'Harness.qml').write_text('''import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.ApplicationWindow {
 id:root;visible:true;width:1280;height:1080
 property bool blocked:rhine.state.queueOpen||rhine.messages.state.open||tools.messageDrawerVisible
 property int presses:0
 property int entries:0
 property real unit:height/1080
 Rectangle {id:bg;anchors.fill:parent;color:"#aeb6a0"
  Rectangle {objectName:"underlyingButton";x:180;y:280;width:180;height:90;color:mouse.containsMouse?"red":"green"
   MouseArea {id:mouse;objectName:"underlyingMouse";anchors.fill:parent;hoverEnabled:true;onEntered:root.entries++;onClicked:root.presses++}
  }
 }
 Rectangle {objectName:"queueEntry";x:600;y:970;width:100;height:50;color:"#d5d8cd";MouseArea {anchors.fill:parent;onPressed:rhine.action("player:open")}}
 SideNavigation {id:nav;objectName:"testNavigation";anchors.fill:parent;background:bg;unit:root.unit}
 GlobalTools {id:tools;anchors.fill:parent;unit:root.unit;background:bg}
 DrawerInputGate {sceneRoot:root.contentItem;overlayLayer:Controls.Overlay.overlay;queueSurface:queue;collectionSurface:collection;blocked:root.blocked;onDismissed:{if(rhine.messages.state.open)rhine.messages.setOpen(false);if(rhine.state.queueOpen)rhine.action("queue-close");}}
 Item {id:collection;visible:false;z:360}
 PlayerQueueGlass {id:queue;objectName:"testQueue";visible:rhine.state.queueOpen;x:rhine.state.drawerBounds.x*root.unit;y:rhine.state.drawerBounds.y*root.unit;width:rhine.state.drawerBounds.width*root.unit;height:842*root.unit;z:350;background:bg;unit:root.unit;sampleX:x;sampleY:y}
}''',encoding='utf-8')
 engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('rhine',b);engine.rootContext().setContextProperty('rhineFontFamily',shared['font']);engine.load(QUrl.fromLocalFile(str(d/'Harness.qml')));assert engine.rootObjects(),errors
 w=engine.rootObjects()[0];QTest.qWait(100)
 def find(name):
  def descend(o):
   if o.objectName()==name:return o
   for x in o.childItems():
    r=descend(x)
    if r is not None:return r
  return descend(w.contentItem())
 def point(o):return o.mapToScene(o.boundingRect().center()).toPoint()
 def click(o):QTest.mouseClick(w,Qt.LeftButton,Qt.NoModifier,point(o));QTest.qWait(250)
 under=find('underlyingButton');mouse=find('underlyingMouse');p=point(under)
 QTest.mouseMove(w,p);QTest.qWait(50);assert mouse.property('containsMouse');before=w.property('entries')
 click(find('queueEntry'));QTest.qWait(80);assert b.s['queueOpen'],'opening press must not dismiss its own drawer'
 for _ in range(80):
  if not under.isEnabled() and not mouse.property('containsMouse'):break
  QTest.qWait(20)
 assert not under.isEnabled() and not mouse.property('containsMouse'),(under.isEnabled(),mouse.property('containsMouse'))
 QTest.mouseMove(w,QPoint(100,200));QTest.mouseMove(w,p);QTest.qWait(50);assert w.property('entries')==before
 QTest.mouseClick(w,Qt.LeftButton,Qt.NoModifier,p);QTest.qWait(80);assert not b.s['queueOpen'] and w.property('presses')==0 and under.isEnabled()
 # A second, independent click works only after the drawer has closed.
 QTest.mouseClick(w,Qt.LeftButton,Qt.NoModifier,p);QTest.qWait(20);assert w.property('presses')==1
 click(find('globalInbox'));assert c.opened
 assert not under.isEnabled() and not find('globalSearch').isEnabled()
 tint=find('messageList');assert tint is not None
 # Popup QObject is not a visual child; inspect its actual scene background instead.
 def frosts(o):
  out=[o] if o.objectName()=='drawerFrostTint' and o.isVisible() else []
  for child in o.childItems():out.extend(frosts(child))
  return out
 f=frosts(w.contentItem());assert len(f)==1,len(f)
 pos=f[0].mapToScene(QPointF(0,0));assert abs(pos.x()-832)<1 and abs(pos.y()-116)<1 and abs(f[0].width()-430)<1 and abs(f[0].height()-842)<1,(pos,f[0].size())
 # Conversation title changes cannot move the fixed header buttons.
 closePoint=point(find('messageClose'));c.startConversation('7','测试');QTest.qWait(50);assert point(find('messageClose'))==closePoint
 QTest.mouseMove(w,p);QTest.qWait(30);count=w.property('entries');assert not mouse.property('containsMouse')
 QTest.mouseClick(w,Qt.LeftButton,Qt.NoModifier,p);QTest.qWait(240);assert not c.opened and w.property('presses')==1 and under.isEnabled()
 # Rail and expanded navigation share one vertical centre; both section arrows share X.
 nav=find('testNavigation');nav.setProperty('expanded',True);QTest.qWait(180)
 created=find('createdPlaylistHeading');collected=find('collectedPlaylistHeading')
 def chevron(o):return next(x for x in o.childItems() if x.objectName()=='sectionChevron')
 assert abs(chevron(created).mapToScene(QPointF(0,0)).x()-chevron(collected).mapToScene(QPointF(0,0)).x())<.1
 rail=find('sideNavigationRail');assert abs(rail.y()+rail.height()/2-(nav.property('drawerY')+nav.property('drawerHeight')/2))<.1
 nav.setProperty('expanded',False)
 # Both surfaces have exactly the same bounds through resize/scaling.
 for width,height in [(960,540),(1280,720),(1920,1080)]:
  w.setWidth(width);w.setHeight(height);u=height/1080;virtualWidth=width/u;pw=min(430,max(320,virtualWidth*.29));b.s={**b.s,'drawerBounds':dict(x=virtualWidth-pw-18,y=116,width=pw,height=842)};b.changed.emit();QTest.qWait(80)
  click(find('globalInbox'));assert c.opened
  f=frosts(w.contentItem());assert len(f)==1
  pos=f[0].mapToScene(QPointF(0,0));assert abs(pos.x()-b.s['drawerBounds']['x']*u)<1 and abs(pos.y()-116*u)<1 and abs(f[0].width()-pw*u)<1 and abs(f[0].height()-842*u)<1
  w.grabWindow().save(str(repo.parent/f'g78-message-{width}x{height}.png'))
  click(find('messageClose'));b.queue(True);QTest.qWait(80);f=frosts(w.contentItem());assert len(f)==1
  assert abs(f[0].width()-pw*u)<1 and abs(f[0].height()-842*u)<1
  w.grabWindow().save(str(repo.parent/f'g78-queue-{width}x{height}.png'));b.queue(False)
 assert not errors,errors
 print('G78 PASS: matching bounds/material, no outside click-through or passive hover, restored input, fixed header, arrow X and rail centre, three window sizes.')
 w.close();engine.deleteLater();QTest.qWait(50)
