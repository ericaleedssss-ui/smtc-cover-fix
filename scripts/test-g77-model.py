"""Compile production MessageCenter with the existing asynchronous Qt transport fixture."""
from pathlib import Path
import argparse,os,subprocess,tempfile,shutil
p=argparse.ArgumentParser();p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args();repo=Path(__file__).resolve().parents[1];qt=a.qt_prefix.resolve();inc=qt/'include/x86_64-linux-gnu/qt6';lib=qt/'lib/x86_64-linux-gnu';env={**os.environ,'LD_LIBRARY_PATH':str(lib)}
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp)
 shutil.copyfile(repo/'scripts/fixtures/g71/MusicLibrary.h',d/'MusicLibrary.h')
 for n in ('MessageCenter.h','MessageCenter.cpp'):shutil.copyfile(repo/'maintained/Qt/src'/n,d/n)
 (d/'checks.cpp').write_text(r'''
#include "MessageCenter.h"
#include <QCoreApplication>
#include <QTest>
#include <cassert>
static void tick(){QTest::qWait(20);}
static QJsonObject person(QString uid="7"){return {{"userId",uid},{"nickname","真实发送者"},{"avatarUrl","https://example.invalid/avatar"},{"authStatus",1}};}
static QJsonObject msg(QString mid,int t,QString text,QString from="7"){return {{"id",mid},{"fromUser",person(from)},{"time",t},{"msg",QString::fromUtf8(QJsonDocument(QJsonObject{{"type",1},{"msg",text}}).toJson())}};}
int main(int argc,char**argv){QCoreApplication app(argc,argv);Host host;MusicLibrary music(&host);music.uid="42";music.provider="netease";music.account=1;int fail=0,sendCount=0;bool missing=false;
 music.api.fixture=[&](QString route,QJsonObject p)->MusicReply{
  if(fail)return {{},"token=private must not leak"};
  if(route=="/pl/count")return {QJsonObject{{"msg",505},{"comment",2},{"forward",1},{"notice",0}}, {}};
  if(route=="/msg/private")return {QJsonObject{{"msgs",QJsonArray{QJsonObject{{"fromUser",person()},{"lastMsgTime",1000},{"lastMsg","{\"msg\":\"你好\"}"},{"newMsgCount",63}}}},{"more",false}}, {}};
  if(route=="/msg/comments")return {QJsonObject{{"comments",QJsonArray{QJsonObject{{"id",8},{"user",person()},{"content","评论正文"},{"updateTime",2000}}}}}, {}};
  if(route=="/msg/forwards")return {QJsonObject{{"forwards",QJsonArray{QJsonObject{{"id",9},{"user",person()},{"json","{\"msg\":\"提到了你\"}"},{"time",2000}}}}}, {}};
  if(route=="/msg/notices")return {missing?QJsonObject{{"invalid",true}}:QJsonObject{{"notices",QJsonArray{QJsonObject{{"id",10},{"notice","{\"content\":\"真实通知\"}"},{"time",2000}}}}}, {}};
  if(route=="/msg/private/history")return {QJsonObject{{"msgs",p["before"].toInteger()==0?QJsonArray{msg("2",2000,"最新"),msg("1",1000,"旧消息")}:QJsonArray{msg("0",500,"更早")}},{"more",p["before"].toInteger()==0}}, {}};
  if(route=="/send/text"){++sendCount;assert(p["user_ids"]=="7"&&p["msg"]=="草稿消息");return {QJsonObject{{"code",200}}, {}};}
  assert(false);return {};
 };
 MessageCenter c(&music);c.setOpen(true);tick();assert(c.rowCount()==1);assert(c.state()["counts"].toList()[0]==505);assert(c.data(c.index(0),MessageCenter::Row).toMap()["unread"]==63);
 c.activate(0);tick();assert(c.history().size()==2&&c.history()[0].toMap()["text"]=="旧消息");c.older();tick();assert(c.history().size()==3&&c.history()[0].toMap()["text"]=="更早");
 c.setDraft("草稿消息");c.setOpen(false);c.setOpen(true);tick();assert(c.draft()=="草稿消息");c.leaveConversation();c.startConversation("7","名字");tick();assert(c.draft()=="草稿消息");
 c.send();c.send();assert(sendCount==1);tick();assert(c.draft().isEmpty());
 c.setDraft("失败时保留");fail=1;c.send();tick();assert(c.draft()=="失败时保留"&&c.state()["error"].toString().contains("草稿"));assert(!c.state()["error"].toString().contains("token"));fail=0;
 c.leaveConversation();c.selectTab(1);c.selectTab(2);c.selectTab(3);tick();assert(c.rowCount()==1&&c.data(c.index(0),MessageCenter::Row).toMap()["text"]=="真实通知");c.selectTab(1);tick();assert(c.data(c.index(0),MessageCenter::Row).toMap()["text"]=="评论正文");
 c.allRead();assert(c.state()["counts"].toList()[0]==505&&c.state()["feedback"].toString().contains("未提供"));
 c.selectTab(0);tick();c.activate(0);c.setDraft("不能跨账户");c.refresh();music.account=2;music.uid="99";music.changed();tick();assert(c.state()["peer"].toString().isEmpty()&&c.draft().isEmpty());
 missing=true;c.selectTab(3);tick();assert(!c.state()["error"].toString().isEmpty());
 music.uid.clear();music.account++;music.changed();c.refresh();tick();assert(!c.state()["supported"].toBool()&&c.rowCount()==0&&c.state()["counts"].toList().isEmpty());
 qInfo("G77 production controller: four APIs, counts, history pagination, deduped send, drafts, failure redaction, stale-account isolation, unsupported read and malformed data passed.");
}
'''.replace('#include <QCoreApplication>','#include <QCoreApplication>\n#include <QJsonDocument>'))
 flags=['-I'+str(d),'-I'+str(inc)]+['-I'+str(inc/n) for n in ['QtCore','QtTest']];mocs=[]
 for n in ['MusicLibrary.h','MessageCenter.h']:
  target=d/('moc_'+n+'.cpp');subprocess.run([str(qt/'lib/qt6/libexec/moc'),*flags,str(d/n),'-o',str(target)],check=True,env=env);mocs.append(str(target))
 binary=d/'checks';subprocess.run(['g++','-std=c++20','-fPIC',*flags,str(d/'MessageCenter.cpp'),str(d/'checks.cpp'),*mocs,'-L'+str(lib),'-lQt6Core','-lQt6Test','-o',str(binary)],check=True,env=env);subprocess.run([str(binary)],env=env,check=True)
