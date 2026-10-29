"""Exercise the generated portrait fixture through actual MusicApi decoding.
Only the IPC transport is replaced; the source parser and response checks are real.
"""
from pathlib import Path
import argparse,os,shutil,subprocess,tempfile
parser=argparse.ArgumentParser();parser.add_argument('source',type=Path);parser.add_argument('--qt-prefix',type=Path,required=True);args=parser.parse_args()
source=args.source.resolve();qt=args.qt_prefix.resolve();inc=qt/'include/x86_64-linux-gnu/qt6';lib=qt/'lib/x86_64-linux-gnu'
env={**os.environ,'LD_LIBRARY_PATH':str(lib)+':'+os.environ.get('LD_LIBRARY_PATH','')}
# Use precisely the response expression installed into the native Windows test.
checks=(source/'Qt/tests/UiChecks.cpp').read_text(encoding='utf-8')
line=next(line for line in checks.splitlines() if 'if (route == "/artist/detail")return ' in line)
response=line.split('return ',1)[1].strip().removesuffix(';')
with tempfile.TemporaryDirectory() as temporary:
    d=Path(temporary)
    for name in ('MusicApi.h','MusicApi.cpp'):shutil.copyfile(source/'Qt/src'/name,d/name)
    (d/'Host.h').write_text('''#pragma once
#include <QObject>
#include <QJsonObject>
#include <functional>
class Host:public QObject {public:
std::function<QJsonObject(QString,QJsonObject)> fixture;
void requestJson(QString route,QJsonObject args,std::function<void(QJsonObject,QString)> callback){callback(fixture(route,args),{});}
void acceptCookies(QString,int,QString){}
};
''',encoding='utf-8')
    (d/'checks.cpp').write_text('''#include "MusicApi.h"
#include <QCoreApplication>
#include <QDebug>
int main(int argc,char **argv){QCoreApplication app(argc,argv);Host host;MusicApi api(&host);
const QString artworkURL="file:///explicit-offline-portrait.png";
bool rejected=false,accepted=false;
host.fixture=[&](QString,QJsonObject){return QJsonObject{{"code",200},{"data",QJsonObject{{"artist",QJsonObject{{"avatar",artworkURL}}}}}};};
api.request("/artist/detail",{{"id","91001"}},[&](MusicReply reply){rejected=!reply.ok();});
if(!rejected){qCritical()<<"Malformed missing-body response was not rejected";return 1;}
host.fixture=[&](QString route,QJsonObject args){Q_UNUSED(route);Q_UNUSED(args);return '''+response+''';};
api.request("/artist/detail",{{"id","91001"}},[&](MusicReply reply){accepted=reply.ok()&&reply.value.toObject()["data"].toObject()["artist"].toObject()["avatar"].toString()==artworkURL;});
if(!accepted){qCritical()<<"Native portrait fixture did not survive real API decoding";return 1;}
qInfo()<<"PASS G91 actual MusicApi: malformed old envelope rejected; generated portrait fixture reaches the real artist avatar field.";
}
''',encoding='utf-8')
    flags=['-I'+str(d),'-I'+str(inc)]+['-I'+str(inc/name) for name in ('QtCore','QtNetwork')]
    binary=d/'checks';subprocess.run(['g++','-std=c++20','-fPIC',*flags,str(d/'MusicApi.cpp'),str(d/'checks.cpp'),'-L'+str(lib),'-lQt6Core','-lQt6Network','-o',str(binary)],check=True,env=env)
    subprocess.run([str(binary)],check=True,env=env)
