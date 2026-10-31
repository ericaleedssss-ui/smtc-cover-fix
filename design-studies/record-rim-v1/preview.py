"""Interactive outer-rim study using production QML and shader, without editing them.

Run with the existing rhine-motion-qa PySide6 environment. --capture writes
deterministic comparison images and exits; without it the preview stays open.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

os.environ.setdefault('QT_QPA_PLATFORM', 'windows')
os.environ.setdefault('QT_QUICK_BACKEND', 'rhi')
os.environ.setdefault('QSG_RHI_BACKEND', 'd3d11')

import PySide6
from PySide6.QtCore import QObject, Signal, Property, Slot, QUrl, Qt, QResource
from PySide6.QtGui import (
    QGuiApplication, QImage, QColor, QPainter, QPainterPath, QLinearGradient,
    QFont, QFontDatabase,
)
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest

REPO = Path(__file__).resolve().parents[2]
UPSTREAM = Path(os.environ.get('RHINE_TEST_SOURCE', str(Path(tempfile.gettempdir()) / 'rhine-motion-qa/upstream')))
OUTPUT = Path(__file__).resolve().parent / 'output'


class Study(QObject):
    changed = Signal()

    def __init__(self):
        super().__init__()
        self.width = .038
        self.dark = False
        self.playing = False
        self.seat = True
        self.material = True

    @Property(float, notify=changed)
    def rimWidth(self):
        return self.width

    @Property('QVariantMap', notify=changed)
    def state(self):
        return dict(dark=self.dark, reduced=False, queueOpen=False)

    @Property(bool, notify=changed)
    def spinning(self):
        return self.playing

    @Property(float, notify=changed)
    def opaqueSeat(self):
        return 1.0 if self.seat else 0.0

    @Property(float, notify=changed)
    def studyMaterial(self):
        return 1.0 if self.material else 0.0

    @Slot(float)
    def setWidth(self, width):
        self.width = width
        self.material = True
        self.changed.emit()

    @Slot()
    def original(self):
        self.width = 0
        self.seat = False
        self.material = False
        self.changed.emit()

    @Slot()
    def toggleDark(self):
        self.dark = not self.dark
        self.changed.emit()

    @Slot()
    def togglePlaying(self):
        self.playing = not self.playing
        self.changed.emit()

    @Slot()
    def toggleSeat(self):
        self.seat = not self.seat
        self.changed.emit()

    @Slot(float, float, float, float)
    def wheelInput(self, *args):
        pass


class Playback(QObject):
    changed = Signal()
    playbackChanged = Signal()
    linesChanged = Signal()

    def __init__(self, study, art):
        super().__init__()
        self.study = study
        self.art = art
        study.changed.connect(self.playbackChanged)

    @Property('QVariantMap', notify=changed)
    def info(self):
        return dict(session='rim-study:1', id='1', title='晚风里的唱片',
                    album='AFTER HOURS / 离线示意封面', artist='RHINE',
                    artists=[dict(id='1', name='RHINE')],
                    coverPixels=self.art, date='2026-11-01', tags=['Jazz', 'Soul'],
                    canLike=True, likeKnown=True, likeBusy=False, liked=False)

    @Property('QVariantMap', notify=playbackChanged)
    def playback(self):
        return dict(playing=self.study.playing, loading=False, seekable=True,
                    index=1, timed=True, lyricStatus='ready')

    @Property('QVariantList', notify=linesChanged)
    def lines(self):
        return [dict(startMs=i * 2500, text=text, translation='') for i, text in enumerate([
            '把晚风留在这一刻', '让音乐慢慢流过房间', '不必急着去往下个地方'])]

    @Property(str, notify=changed)
    def status(self):
        return ''

    @Slot(str)
    def operate(self, operation):
        pass

    @Slot(str)
    def openArtist(self, artist):
        pass

    @Slot(int, str)
    def seekLine(self, index, session):
        pass


def shader_variant(source):
    # The maintained production shader is the only candidate source of truth.
    # Expose its fixed material constants as uniforms for preview controls.
    for name, value in [('rimWidth', '.038'), ('opaqueSeat', '1.0'), ('studyMaterial', '1.0')]:
        constant = f'const float {name}={value};'
        assert source.count(constant) == 1, constant
        source = source.replace(constant, '', 1)
    anchor = '    float darkMode;\n'
    source = source.replace(anchor, anchor + '    float rimWidth;\n    float opaqueSeat;\n    float studyMaterial;\n', 1)
    return source


HARNESS = '''import QtQuick
import QtQuick.Controls.Basic as C
C.ApplicationWindow {
    id:root; visible:true; width:1440; height:754
    title:"唱片外沿 · 材质预览"
    color:rhine.state.dark?"#252a25":"#eeebe4"
    property real u:(width-28)/1008
    property bool showTools:true
    Rectangle {
        id:toolbar; x:14;y:8;width:parent.width-28;height:60;visible:root.showTools
        color:"transparent"
        Row {spacing:10;anchors.verticalCenter:parent.verticalCenter
            C.Button {text:"原版对照";onClicked:study.original()}
            C.Button {text:"黑胶包边";onClicked:study.setWidth(.026)}
            C.Button {text:"加宽黑胶包边";onClicked:study.setWidth(.038)}
            Text {text:"厚度";anchors.verticalCenter:parent.verticalCenter;color:rhine.state.dark?"#e8e4d9":"#464d42";font.family:rhineFontFamily}
            C.Slider {width:140;from:0;to:.055;value:study.rimWidth;onMoved:study.setWidth(value)}
            C.Button {text:study.spinning?"暂停旋转":"看看旋转";onClicked:study.togglePlaying()}
            C.Button {text:"浅色 / 深色";onClicked:study.toggleDark()}
            C.Button {text:study.opaqueSeat>.5?"刻字圈：实体":"刻字圈：透明";onClicked:study.toggleSeat()}
            Text {text:"仅材质预览 · 示例封面";anchors.verticalCenter:parent.verticalCenter;color:rhine.state.dark?"#b3b9aa":"#77806e";font.family:rhineFontFamily}
        }
    }
    Item {
        id:scene;objectName:"studyScene";x:0;y:74;width:root.width;height:root.height-y;clip:true
        Item {id:base;anchors.fill:parent
            Rectangle {id:bg;z:-2;anchors.fill:parent;color:rhine.state.dark?"#30362c":"#d2c5b3"
                Repeater {model:18;Rectangle {x:index*120-900;y:-600;width:55;height:2200;rotation:28;color:rhine.state.dark?"#3e4637":"#e9e4d8"}}
            }
        }
        ArchiveReading {id:reading;dark:rhine.state.dark;background:bg;materialLayer:base;controller:fixture;
            playbackController:fixture;playing:true;collection:false;unit:root.u;
            x:14;y:12;width:parent.width-28;height:parent.height-24}
    }
}
'''


def qt_tool(name):
    return str(Path(PySide6.__file__).resolve().parent / (name + '.exe'))


def artwork(path, font):
    image = QImage(640, 640, QImage.Format_ARGB32_Premultiplied)
    image.fill(Qt.transparent)
    p = QPainter(image)
    p.setRenderHint(QPainter.Antialiasing)
    clip = QPainterPath()
    clip.addEllipse(0, 0, 640, 640)
    p.setClipPath(clip)
    gradient = QLinearGradient(0, 0, 640, 640)
    gradient.setColorAt(0, QColor('#23444c'))
    gradient.setColorAt(1, QColor('#e4b091'))
    p.fillRect(0, 0, 640, 640, gradient)
    p.setPen(Qt.NoPen)
    p.setBrush(QColor('#d58b64'))
    p.drawEllipse(330, 85, 190, 190)
    p.setBrush(QColor('#23444c'))
    p.drawEllipse(-180, 350, 950, 640)
    p.setPen(QColor('#eee8d8'))
    p.setFont(QFont(font, 38, QFont.Light))
    p.drawText(60, 250, 'AFTER HOURS')
    p.setFont(QFont(font, 12))
    p.drawText(65, 300, 'R H I N E   /   M A T E R I A L   S T U D Y')
    p.end()
    assert image.save(str(path))


def find(item, name):
    if item.objectName() == name:
        return item
    for child in item.childItems():
        result = find(child, name)
        if result is not None:
            return result


def capture(window, study, directory, font):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    page = find(window.contentItem(), 'nowPlayingPanel')
    from PySide6.QtCore import QPoint
    QTest.mouseMove(window, QPoint(3, 3))
    QTest.qWait(1000)
    page.setProperty('spinPhase', .08)
    find(window.contentItem(), 'nowRecordPrint').setProperty('spinAngle', 28)
    find(window.contentItem(), 'nowTonearmPlane').setProperty('pose', 0)
    QTest.qWait(650)
    samples = []
    for slug, title, width in [('original', '原版 · 乳白胶盘', 0),
                               ('thin', '方案 A · 哑光黑胶包边 + 暖银刻字圈', .026),
                               ('wide', '方案 B · 加宽黑胶包边 + 暖银刻字圈', .038)]:
        study.seat = slug != 'original'
        study.material = slug != 'original'
        study.width = width
        study.changed.emit()
        QTest.qWait(350)
        scene = find(window.contentItem(), 'studyScene')
        rect = scene.mapRectToScene(scene.boundingRect()).toRect()
        full = window.grabWindow()
        ratio = full.devicePixelRatio()
        shot = full.copy(round(rect.x()*ratio), round(rect.y()*ratio),
                         round(rect.width()*ratio), round(rect.height()*ratio))
        assert not shot.isNull()
        shot.setDevicePixelRatio(1)
        shot.save(str(OUTPUT / (slug + '.png')))
        samples.append((shot, title))
    # A single readable sheet keeps all three full panels and the same crop.
    panel_width = 1340
    panel_height = round(samples[0][0].height() * panel_width / samples[0][0].width())
    sheet = QImage(panel_width + 48, (panel_height + 65) * 3 + 24, QImage.Format_RGB32)
    sheet.fill(QColor('#eeeae2'))
    p = QPainter(sheet)
    p.setRenderHint(QPainter.SmoothPixmapTransform)
    p.setPen(QColor('#353e34'))
    p.setFont(QFont(font, 16, QFont.Medium))
    for i, (shot, title) in enumerate(samples):
        y = 24 + i * (panel_height + 65)
        p.drawText(24, y + 24, title)
        p.drawImage(24, y + 40, shot.scaledToWidth(panel_width, Qt.SmoothTransformation))
    p.end()
    sheet.save(str(OUTPUT / 'comparison.png'))
    window.grabWindow().save(str(OUTPUT / 'interactive-window.png'))
    study.dark = True
    study.setWidth(.038)
    QTest.qWait(350)
    window.grabWindow().save(str(OUTPUT / 'thin-dark-window.png'))
    print('CAPTURES', OUTPUT, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    app = QGuiApplication([])
    fid = QFontDatabase.addApplicationFont(str(UPSTREAM / 'Assets/fonts/RhineMiSans-regular.otf'))
    font = QFontDatabase.applicationFontFamilies(fid)[0]
    errors = []
    from PySide6.QtCore import qInstallMessageHandler
    def log(kind, context, message):
        if any(term in message for term in ['TypeError', 'ReferenceError', 'Binding loop',
                                            'Cannot assign', 'is not defined', 'Failed to', 'Error']):
            errors.append(message)
            print('QML', message, flush=True)
    qInstallMessageHandler(log)
    with tempfile.TemporaryDirectory(prefix='rhine-rim-') as tmp:
        directory = Path(tmp)
        artwork(directory / 'cover.png', font)
        for name in ['ArchiveReading', 'PlaylistShowcase', 'RecordStack', 'LiquidGlass',
                     'ArchiveActionIcon', 'RhineIcon', 'ArtistMarquee', 'NowPlayingPanel', 'RecordTonearm']:
            origin = REPO / 'maintained/Qt/qml' / (name + '.qml')
            if not origin.exists():
                origin = UPSTREAM / 'Qt/qml' / (name + '.qml')
            source = origin.read_text(encoding='utf-8')
            source = source.replace('fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"',
                                    'property real rimWidth:study.rimWidth;property real opaqueSeat:study.opaqueSeat;property real studyMaterial:study.studyMaterial;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"')
            if name == 'NowPlayingPanel':
                source = source.replace('x:-(5+8*armPlane.lift)*page.unit;y:(5+8*armPlane.lift)*page.unit;',
                    'x:-(study.studyMaterial>.5?1:.642)*(5+8*armPlane.lift)*page.unit;y:(study.studyMaterial>.5?1:1.6)*(5+8*armPlane.lift)*page.unit;')
            (directory / (name + '.qml')).write_text(source, encoding='utf-8')
        entries = []
        for name in ['liquidGlass', 'magazineEdgeFade', 'archiveIcon', 'softEdgeFade', 'recordAtmosphere']:
            origin = REPO / 'maintained/Qt/shaders' / (name + '.frag')
            if not origin.exists():
                origin = UPSTREAM / 'Qt/shaders' / (name + '.frag')
            if name == 'recordAtmosphere':
                local = directory / 'recordAtmosphere.frag'
                baseline = origin.read_text(encoding='utf-8')
                candidate = shader_variant(baseline)
                def focus_pass(text):
                    return text.split('    if(shadowOnly>6.5){', 1)[1].split('    if(shadowOnly>4.5){', 1)[0]
                assert focus_pass(candidate) == focus_pass(baseline), 'Keep production depth of field unchanged'
                local.write_text(candidate, encoding='utf-8')
                origin = local
            out = directory / (name + '.frag.qsb')
            subprocess.run([qt_tool('qsb'), '--glsl', '150,300es', '--hlsl', '50', '--msl', '12',
                            '-o', str(out), str(origin)], check=True, capture_output=True)
            entries.append('<file alias="' + name + '.frag.qsb">' + out.as_posix() + '</file>')
        icons = ''.join('<file alias="' + name + '.png">' +
                        (REPO / 'maintained/Assets/icons' / (name + '.png')).as_posix() + '</file>'
                        for name in ['archive-play', 'archive-shuffle', 'archive-more', 'song-like-on', 'song-like-off'])
        qrc = directory / 'shaders.qrc'
        qrc.write_text('<RCC><qresource prefix="/shaders">' + ''.join(entries) +
                       '</qresource><qresource prefix="/icons">' + icons + '</qresource></RCC>', encoding='utf-8')
        resource = directory / 'shaders.rcc'
        subprocess.run([qt_tool('rcc'), '--binary', '-o', str(resource), str(qrc)], check=True, capture_output=True)
        assert QResource.registerResource(str(resource))
        (directory / 'Harness.qml').write_text(HARNESS, encoding='utf-8')
        study = Study()
        fixture = Playback(study, QUrl.fromLocalFile(str(directory / 'cover.png')).toString())
        engine = QQmlApplicationEngine()
        for key, value in [('study', study), ('rhine', study), ('fixture', fixture), ('rhineFontFamily', font)]:
            engine.rootContext().setContextProperty(key, value)
        engine.load(QUrl.fromLocalFile(str(directory / 'Harness.qml')))
        assert engine.rootObjects(), errors
        window = engine.rootObjects()[0]
        if args.capture:
            capture(window, study, directory, font)
            window.close()
            assert not errors, errors
        else:
            print('PREVIEW_READY', flush=True)
            app.exec()
        del engine


if __name__ == '__main__':
    main()
