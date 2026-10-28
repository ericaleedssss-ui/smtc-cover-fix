"""Load real drawer QML and exercise desktop input with an explicit offline model."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import sys,tempfile,shutil
from PySide6.QtCore import QObject,Signal,Property,Slot,QAbstractListModel,QModelIndex,QUrl,Qt,QPoint
from PySide6.QtGui import QGuiApplication,QColor,QFontDatabase
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parents[1];app=QGuiApplication([])
fid=QFontDatabase.addApplicationFont(str(repo.parent/'upstream/Assets/fonts/RhineMiSans-regular.otf'));font=QFontDatabase.applicationFontFamilies(fid)[0]
class Controller(QAbstractListModel):
 changed=Signal();historyChanged=Signal();draftChanged=Signal()
 def __init__(self):super().__init__();self.d='';self.peer='';self.opened=False;self.tab=0;self.sent=0;self.read=0;self.refreshes=0
 def rowCount(self,p=QModelIndex()):return 0 if p.isValid() else 20
 def roleNames(self):return {257:b'message'}
 def data(self,i,role):return dict(uid=str(i.row()+1),name='离线界面测试 '+str(i.row()),avatar='',badge='认证' if i.row()==0 else '',text='歌曲与近况 · 一条来自接口样式的测试消息',time=1793180000000,unread=63 if i.row()==0 else 0) if role==257 else None
 @Property('QVariantMap',notify=changed)
 def state(self):return dict(open=self.opened,supported=True,tab=self.tab,counts=[505,2,1,0],loading=False,more=False,error='',feedback='',peer=self.peer,peerName='对话用户',sending=False,allReadSupported=False)
 @Property('QVariantList',notify=historyChanged)
 def history(self):return [dict(key='a',text='这是明确标注的离线测试记录。',mine=False,time=1793180000000,image='',target=''),dict(key='b',text='测试回复',mine=True,time=1793180001000,image='',target='')] if self.peer else []
 @Property(str,notify=draftChanged)
 def draft(self):return self.d
 @draft.setter
 def draft(self,v):self.setDraft(v)
 @Slot(str)
 def setDraft(self,v):self.d=v;self.draftChanged.emit()
 @Slot(bool)
 def setOpen(self,v):self.opened=v;self.changed.emit()
 @Slot(int)
 def selectTab(self,t):self.tab=t;self.peer='';self.changed.emit();self.historyChanged.emit()
 @Slot(int)
 def activate(self,i):self.startConversation(str(i+1),'测试')
 @Slot(str,str)
 def startConversation(self,uid,name):self.peer=uid;self.changed.emit();self.historyChanged.emit();self.draftChanged.emit()
 @Slot()
 def leaveConversation(self):self.peer='';self.changed.emit();self.historyChanged.emit()
 @Slot()
 def send(self):self.sent+=1;self.d='';self.draftChanged.emit();self.changed.emit()
 @Slot()
 def refresh(self):self.refreshes+=1
 @Slot()
 def more(self):pass
 @Slot()
 def older(self):pass
 @Slot()
 def allRead(self):self.read+=1
errors=[]
def handler(kind,ctx,text):
 print(text)
 if any(n in text for n in ['Error','Cannot','is not defined','Binding loop']):errors.append(text)
from PySide6.QtCore import qInstallMessageHandler
qInstallMessageHandler(handler)
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);shutil.copyfile(repo/'maintained/Qt/qml/MessageDrawer.qml',d/'MessageDrawer.qml')
 (d/'Harness.qml').write_text('''import QtQuick
import QtQuick.Controls.Basic
ApplicationWindow {id:root;visible:true;width:1200;height:900
Rectangle {id:bg;anchors.fill:parent;color:"#b8bea7";Rectangle{x:700;y:180;width:280;height:300;color:"#526b49"}}
MessageDrawer {id:panel;controller:messageController;sceneBackground:bg;unit:.95;Component.onCompleted:open()}
}''')
 from PySide6.QtQml import QQmlApplicationEngine
 engine=QQmlApplicationEngine();c=Controller();engine.rootContext().setContextProperty('messageController',c);engine.rootContext().setContextProperty('rhineFontFamily',font);engine.load(QUrl.fromLocalFile(str(d/'Harness.qml')));assert engine.rootObjects(),errors
 window=engine.rootObjects()[0];QTest.qWait(450)
 def find(name):
  obj=window.findChild(QObject,name)
  if obj:return obj
  def descend(o):
   if o.objectName()==name:return o
   for x in o.childItems():
    r=descend(x)
    if r:return r
  return descend(window.contentItem())
 def click(o):
  assert o is not None
  p=o.mapToScene(o.boundingRect().center());QTest.mouseClick(window,Qt.LeftButton,Qt.NoModifier,QPoint(int(p.x()),int(p.y())));QTest.qWait(60)
 assert c.opened and find('messageList') is not None
 assert find('messageDrawer').property('x')>700
 window.grabWindow().save(str(repo.parent/'g77-message-preview.png'))
 for t in [1,2,3,0]:c.selectTab(t);QTest.qWait(10)
 c.activate(0);QTest.qWait(100);assert find('messageComposer').property('visible')
 editor=find('messageEditor');editor.forceActiveFocus();[QTest.keyClick(window,ord(ch.upper()),Qt.NoModifier) for ch in 'hello draft'];QTest.qWait(30);assert c.d=='HELLO DRAFT',c.d
 window.grabWindow().save(str(repo.parent/'g77-conversation-preview.png'))
 click(find('messageSend'));assert c.sent==1 and not c.d
 c.setDraft('saved draft');c.leaveConversation();c.startConversation('1','');QTest.qWait(40);assert editor.property('text')=='saved draft'
 click(find('messageBack'));assert not c.peer
 click(find('messageAllRead'));assert c.read==1
 click(find('messageRefresh'));assert c.refreshes==1
 click(find('messageClose'));QTest.qWait(230);assert not c.opened
 # Reopen, then close with an actual click outside the panel.
 panel=find('messageDrawer');panel.open();QTest.qWait(280);QTest.mouseClick(window,Qt.LeftButton,Qt.NoModifier,QPoint(150,200));QTest.qWait(230);assert not c.opened
 for width,height in [(960,540),(1920,1080)]:
  window.setWidth(width);window.setHeight(height);panel.open();QTest.qWait(280);assert panel.property('width')<width and panel.property('height')<height;panel.close();QTest.qWait(200)
 assert not errors,errors
 print('G77 production QML: load, four tabs, text entry, draft restore, send, all-read disclosure, refresh, close/outside, resize passed.')
 window.close();engine.deleteLater();QTest.qWait(30)
