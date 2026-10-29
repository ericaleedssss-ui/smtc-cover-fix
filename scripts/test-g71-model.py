"""Compile and execute the production controller against Qt and explicit domain fixtures.
Requires a Qt development prefix and g++; does not compile the full Windows app.
"""
from pathlib import Path
import argparse,os,shutil,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--qt-prefix',type=Path,required=True);args=p.parse_args()
repo=Path(__file__).resolve().parents[1];source=args.source.resolve();qt=args.qt_prefix.resolve()
includes=qt/'include/x86_64-linux-gnu/qt6';lib=qt/'lib/x86_64-linux-gnu'
env={**os.environ,'LD_LIBRARY_PATH':str(lib)+':'+os.environ.get('LD_LIBRARY_PATH','')}
with tempfile.TemporaryDirectory() as tmp:
    d=Path(tmp)
    for f in (repo/'scripts/fixtures/g71').iterdir():shutil.copyfile(f,d/f.name)
    fixture=d/'MusicLibrary.h';text=fixture.read_text().replace('#include <QObject>','#include <QObject>\n#include <QImage>')
    text=text.replace('struct Host {','struct Host {void loadCover(QString url,std::function<void(QString)> cb,int){QTimer::singleShot(15,[cb,url]{cb(url);});}QImage image(QString key)const{if(key.isEmpty()||key.contains("missing"))return {};QImage i(64,80,QImage::Format_RGB32);i.fill(key.contains("portrait-B")?Qt::blue:Qt::green);return i;}')
    fixture.write_text(text)
    for name in ('PlaylistMagazine.h','PlaylistMagazine.cpp'):shutil.copyfile(repo/'maintained/Qt/src'/name,d/name)
    for name in ('MusicData.h','MusicData.cpp'):shutil.copyfile(source/'Qt/src'/name,d/name)
    # Reuse the production enqueueMany implementation, rather than a fixture imitation.
    cpp=(source/'Qt/src/MusicPlayer.cpp').read_text(encoding='utf-8');a=cpp.index('int MusicPlayer::enqueueMany(');b=cpp.index('\nvoid MusicPlayer::enqueue(',a)
    (d/'enqueue.cpp').write_text('#include "MusicLibrary.h"\n'+cpp[a:b],encoding='utf-8')
    mutation=(source/'Qt/src/MusicMutation.cpp').read_text(encoding='utf-8');start=mutation.index('void MusicLibrary::ensureLikedIDs(');end=mutation.index('void MusicLibrary::like(',start)
    (d/'likes.cpp').write_text('#include "MusicLibrary.h"\n'+mutation[start:end],encoding='utf-8')
    flags=['-I'+str(d),'-I'+str(includes)]+['-I'+str(includes/n) for n in ('QtCore','QtGui','QtNetwork','QtTest')]
    generated=[]
    for name in ('PlaylistMagazine.h','MusicLibrary.h'):
        output=d/('moc_'+name+'.cpp');subprocess.run([str(qt/'lib/qt6/libexec/moc'),*flags,str(d/name),'-o',str(output)],check=True,env=env);generated.append(str(output))
    binary=d/'checks'
    subprocess.run(['g++','-std=c++20','-O0','-g','-fPIC',*flags,str(d/'PlaylistMagazine.cpp'),str(d/'MusicData.cpp'),str(d/'enqueue.cpp'),str(d/'likes.cpp'),str(d/'checks.cpp'),*generated,'-L'+str(lib),'-Wl,-rpath,'+str(lib),'-lQt6Core','-lQt6Gui','-lQt6Network','-lQt6Test','-o',str(binary)],check=True,env=env)
    subprocess.run([str(binary)],check=True,env=env)
