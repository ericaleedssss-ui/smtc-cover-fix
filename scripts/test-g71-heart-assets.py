"""Compile the production Qt resource-image loader and verify the supplied art bytes."""
from pathlib import Path
import argparse,subprocess,tempfile,os,hashlib
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args();src=a.source.resolve();repo=Path(__file__).resolve().parents[1];q=a.qt_prefix.resolve();inc=q/'include/x86_64-linux-gnu/qt6';lib=q/'lib/x86_64-linux-gnu';env={**os.environ,'LD_LIBRARY_PATH':str(lib)}
for name in ('song-like-on.png','song-like-off.png'):assert (src/'Assets/icons'/name).read_bytes()==(repo/'maintained/Assets/icons'/name).read_bytes()
s=(src/'Qt/src/Host.cpp').read_text(encoding='utf-8');method=s[s.index('QString Host::resourceImage('):]
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);qrc=d/'icons.qrc';qrc.write_text('<RCC><qresource prefix="/icons">'+''.join('<file alias="'+name+'">'+str(src/'Assets/icons'/name)+'</file>' for name in ('song-like-on.png','song-like-off.png'))+'</qresource></RCC>')
 subprocess.run([str(q/'lib/qt6/libexec/rcc'),'--binary','-o',str(d/'icons.rcc'),str(qrc)],check=True,env=env)
 fixture='''#include <QCoreApplication>\n#include <QResource>\n#include <QImage>\n#include <QCache>\n#include <QDebug>\nstruct Host{QCache<QString,QImage> images{32768};QString resourceImage(const QString&);};\n'''
 checks='''int main(int argc,char**argv){QCoreApplication app(argc,argv);if(!QResource::registerResource(argv[1]))return 1;Host host;for(const QString &name:{QString("song-like-on.png"),QString("song-like-off.png")}){const auto key=host.resourceImage(":/icons/"+name);if(key.isEmpty()||!host.images.object(key)->hasAlphaChannel()||*host.images.object(key)!=QImage(QString(argv[2])+"/"+name))return 2;const auto *before=host.images.object(key);host.resourceImage(key);if(before!=host.images.object(key))return 3;}if(!host.resourceImage("/not/a/compiled/icon").isEmpty())return 4;qInfo()<<"PASS production native icon loader preserves the supplied RGBA images, caches them and rejects non-resource paths";}'''
 cpp=d/'assets.cpp';cpp.write_text(fixture+method+checks,encoding='utf-8');binary=d/'checks'
 subprocess.run(['g++','-std=c++20','-fPIC','-I'+str(inc),'-I'+str(inc/'QtCore'),'-I'+str(inc/'QtGui'),str(cpp),'-L'+str(lib),'-Wl,-rpath,'+str(lib),'-lQt6Gui','-lQt6Core','-o',str(binary)],check=True,env=env)
 subprocess.run([str(binary),str(d/'icons.rcc'),str(src/'Assets/icons')],check=True,env=env)
