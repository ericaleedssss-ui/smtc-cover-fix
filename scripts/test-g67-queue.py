"""Actual Qt 6.12 mouse-event checks for the maintained QML queue.

Run: python scripts/test-g65-queue.py /path/to/applied/Rhine/source
Requires PySide6. Uses an action spy; compiled C++ mutations are separately
covered by the real-window checks in Qt/tests/UiChecks.cpp on Windows CI.
"""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
import sys
import tempfile
import shutil
from pathlib import Path
from PySide6.QtCore import QObject, Property, Signal, Slot, QUrl, QPoint, QPointF, Qt
from PySide6.QtGui import QGuiApplication, QFontDatabase, QWheelEvent
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest

source = Path(sys.argv[1]).resolve()
maintained = Path(__file__).resolve().parents[1] / 'maintained'
app = QGuiApplication([])
font_id = QFontDatabase.addApplicationFont(str(source / 'Assets/fonts/RhineMiSans-regular.otf'))
font = QFontDatabase.applicationFontFamilies(font_id)[0]

class Spy(QObject):
    changed = Signal()
    def __init__(self):
        super().__init__()
        self.actions = []
        self.data = {'queueCount': 4080, 'queueIndex': 0, 'queueOffset': 0,
                     'queuePageSize': 40, 'queueCanCollect': True, 'reduced': True}
        self.page(0)
    def page(self, start):
        self.data['queueOffset'] = start
        self.data['queueRows'] = [dict(index=i, id=str(650000+i), key='netease:'+str(650000+i),
            title=['You Got Me', "Didn't Cha Know", 'Witch Doctor', '长长的歌名测试，超出可用空间应当省略'][i%4],
            artist=['The Roots', 'Erykah Badu', 'Erykah Badu / The Roots', 'MONO NO AWARE'][i%4],
            cover='', durationLabel='04:19', sourceTitle='测试歌单', sourceLink=True)
            for i in range(start, start+40)]
        self.changed.emit()
    @Property('QVariantMap', notify=changed)
    def state(self): return self.data
    @Slot(str)
    def action(self, name): self.actions.append(name)

with tempfile.TemporaryDirectory() as temp:
    temp = Path(temp)
    shutil.copy(maintained/'Qt/qml/PlayerQueueGlass.qml', temp)
    shutil.copy(source/'Qt/qml/LiquidGlass.qml', temp)
    def build(nested=False, unit=2/3):
        spy = Spy()
        view = QQuickView()
        view.rootContext().setContextProperty('rhine', spy)
        view.rootContext().setContextProperty('rhineFontFamily', font)
        panel = f'''PlayerQueueGlass {{ objectName: "probeQueue"; x: 700; y: 70;
            width: 430*{unit}; height:842*{unit}; unit:{unit}; z:245; background:bg }}'''
        # Exactly the stacking relationship in G64 versus G65 Main.qml.
        qml = '''import QtQuick
Item { width:1100; height:720
 Item { id: baseVisual; anchors.fill:parent
  Rectangle { id:bg; anchors.fill:parent; color:"#e8e8df" }
  NESTED
 }
 MouseArea { anchors.fill:parent; onClicked: rhine.action("page-intercepted") }
 ROOT
}'''.replace('NESTED', panel if nested else '').replace('ROOT', '' if nested else panel)
        path = temp / ('Nested.qml' if nested else 'Root.qml')
        path.write_text(qml)
        view.setSource(QUrl.fromLocalFile(str(path)))
        assert view.status() == QQuickView.Ready
        view.show(); QTest.qWait(120)
        return spy, view
    def find(item, name):
        if item.objectName() == name: return item
        for child in item.childItems():
            found = find(child, name)
            if found is not None: return found
    def target(view, name):
        item = find(view.rootObject(), name)
        assert item is not None and item.isVisible(), name
        return item
    def move(view, name):
        item = target(view, name)
        point = item.mapToScene(QPointF(item.width()/2,item.height()/2)).toPoint()
        QTest.mouseMove(view, QPoint(5,5)); QTest.mouseMove(view, point)
        QTest.qWait(100)
        return item, point
    def click(view, spy, name, expected):
        # Hidden hover actions become visible by moving over their row first.
        if name.startswith(('queueRemove_', 'queueCollect_', 'queueSource_')):
            move(view, 'queueRow_'+name.split('_')[1])
        item, point = move(view, name)
        assert item.isEnabled(), name
        before = len(spy.actions)
        QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, point)
        QTest.qWait(40)
        assert spy.actions[before:] == [expected], (name, spy.actions[before:], expected)

    old, oldview = build(nested=True)
    click(oldview, old, 'queueRowPlay_1', 'page-intercepted')
    oldview.close(); oldview.deleteLater(); QTest.qWait(30)
    print('PASS: reproduced G64 ancestor stacking interception with a real mouse click')
    for scale in (2/3, 1):
        spy, view = build(unit=scale)
        # At full scale, grow the window so the test panel is not clipped.
        if scale == 1:
            view.resize(1200, 980); view.rootObject().setHeight(980); QTest.qWait(50)
        row, _ = move(view, 'queueRow_1')
        assert row.property('hovered'), 'row hover feedback'
        click(view, spy, 'queueRowPlay_1', 'player:queue-play:1:netease%3A650001')
        click(view, spy, 'queueCoverPlay_2', 'player:queue-play:2:netease%3A650002')
        click(view, spy, 'queueSource_1', 'player:queue-source:1:netease%3A650001')
        click(view, spy, 'queueCollect_1', 'player:queue-collect:1:netease%3A650001')
        click(view, spy, 'queueRemove_1', 'player:remove:1:netease%3A650001')
        click(view, spy, 'queueCollectAll', 'player:queue-collect-all')
        click(view, spy, 'queueNext', 'player:queue-page-next')
        spy.page(40); QTest.qWait(80)
        click(view, spy, 'queueRowPlay_41', 'player:queue-play:41:netease%3A650041')
        click(view, spy, 'queueCoverPlay_42', 'player:queue-play:42:netease%3A650042')
        row, _ = move(view, 'queueRow_41'); assert row.property('hovered')
        click(view, spy, 'queuePrevious', 'player:queue-page-prev')
        listing = target(view, 'playerQueueList')
        point = listing.mapToScene(QPointF(listing.width()/2,listing.height()/2))
        event = QWheelEvent(point, point, QPoint(), QPoint(0,-240), Qt.NoButton,
                           Qt.NoModifier, Qt.NoScrollPhase, False)
        app.sendEvent(view, event); QTest.qWait(350)
        assert listing.property('contentY') > 0, 'wheel scroll'
        y = listing.property('contentY')
        spy.data['queueRows'][5]['cover'] = 'file:///missing-deliberate-art.png'
        spy.changed.emit(); QTest.qWait(50)
        assert listing.property('contentY') == y, 'metadata refresh must preserve scroll'
        spy.page(4040); QTest.qWait(60)
        click(view, spy, 'queueCoverPlay_4041', 'player:queue-play:4041:netease%3A654041')
        assert not target(view, 'queueNext').isEnabled(), 'last page next disabled'
        click(view, spy, 'queueClear', 'player:clear')
        click(view, spy, 'queueClose', 'queue-close')
        spy.data['dark'] = True; spy.changed.emit(); QTest.qWait(30)
        click(view, spy, 'queueRowPlay_4041', 'player:queue-play:4041:netease%3A654041')
        spy.data['queueRoaming'] = True; spy.changed.emit(); QTest.qWait(30)
        click(view, spy, 'queueClear', 'roam:exit')
        spy.data['queueRows'] = []; spy.data['queueCount'] = 0; spy.changed.emit(); QTest.qWait(30)
        assert not target(view, 'queueCollectAll').isEnabled()
        print(f'PASS: real mouse/hover/wheel, first/second/final page, dark/empty/FM, scale={scale}')
        spy.data['queueCount']=4080; spy.page(0); spy.data['dark']=False; spy.data['queueRoaming']=False; spy.changed.emit(); QTest.qWait(40)
        move(view, 'queueRow_1')
        if scale == 2/3:
            view.grabWindow().save(str(source.parent/'queue-g65-local-preview.png'))
        view.close(); view.deleteLater(); QTest.qWait(20)
    # Main.qml must use the same root-level arrangement as the passing harness.
    main = (source/'Qt/qml/Main.qml').read_text()
    assert main.index('id: glassQueueLoader') > main.index('id: inputLayer')
    print('PASS: production Main.qml queue loader follows the page input layer')
