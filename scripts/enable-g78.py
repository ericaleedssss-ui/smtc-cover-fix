"""G78: shared right-drawer frame/material, exclusive pointer input, aligned rail."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
def edit(name,old,new):
 p=Path(name);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(name,old[:90]);p.write_text(s.replace(old,new),encoding='utf-8')
for file in ['DrawerFrost.qml','DrawerInputGate.qml','MessageDrawer.qml','PlayerQueueGlass.qml','SideNavigation.qml']:
 shutil.copyfile(root/'maintained/Qt/qml'/file,Path('Qt/qml')/file)
edit('Qt/CMakeLists.txt','    qml/MessageDrawer.qml\n','    qml/MessageDrawer.qml\n    qml/DrawerFrost.qml\n    qml/DrawerInputGate.qml\n')
edit('Qt/CMakeLists.txt','set_source_files_properties(qml/MessageDrawer.qml','set_source_files_properties(qml/DrawerFrost.qml PROPERTIES QT_RESOURCE_ALIAS DrawerFrost.qml)\nset_source_files_properties(qml/DrawerInputGate.qml PROPERTIES QT_RESOURCE_ALIAS DrawerInputGate.qml)\nset_source_files_properties(qml/MessageDrawer.qml')
# Both surfaces consume the actual existing queue rectangle, including when it is closed.
edit('Qt/src/NativeHud.cpp','            {"queueBounds", queueOpen ? QJsonObject{','''            {"drawerBounds", QJsonObject{{"x",queueRect.x()},{"y",queueRect.y()},{"width",queueRect.width()},{"height",queueRect.height()}}},
            {"queueBounds", queueOpen ? QJsonObject{''')
edit('Qt/qml/GlobalTools.qml','    required property Item background','    required property Item background\n    property Item drawerBackground:background\n    readonly property bool messageDrawerVisible:inbox.visible')
edit('Qt/qml/GlobalTools.qml','onInvoked:inbox.open()', 'onInvoked:{if(rhine.state.queueOpen)rhine.action("queue-close");accountMenu.close();accountInfo.close();inbox.open();}')
edit('Qt/qml/GlobalTools.qml','sceneBackground:tools.background;dark:!!rhine.state.dark;unit:tools.u','sceneBackground:tools.drawerBackground;panelBounds:rhine.state.drawerBounds||({});dark:!!rhine.state.dark;unit:tools.unit')
edit('Qt/qml/Main.qml','background:backgroundLayer;unit:root.stageScale;topRightReserved:', 'background:backgroundLayer;drawerBackground:queueGlassBackdrop;unit:root.stageScale;topRightReserved:')
edit('Qt/qml/Main.qml','    property var commentsScrollMemory: ({})','''    readonly property bool rightDrawerActive:rhine.state.queueOpen===true||rhine.messages.state.open===true||globalTools.messageDrawerVisible
    onRightDrawerActiveChanged:if(rightDrawerActive){hoverClearTimer.stop();rhine.hoverItem("",0,0);rhine.hoverLink("");rhine.pointer("pointerleave",0,0);}
    property var commentsScrollMemory: ({})''')
edit('Qt/qml/Main.qml','            active: glassQueueLoader.active','            active: root.rightDrawerActive')
edit('Qt/qml/Main.qml','        property var bounds: rhine.state.queueBounds','        property var bounds: rhine.state.drawerBounds || rhine.state.queueBounds')
edit('Qt/qml/Main.qml','    Loader {\n        id: glassQueueLoader', '''    DrawerInputGate {
        anchors.fill:parent;sceneRoot:root.contentItem;overlayLayer:Controls.Overlay.overlay
        queueSurface:glassQueueLoader;collectionSurface:queueCollectionOverlay
        blocked:root.rightDrawerActive
        onDismissed:{if(rhine.messages.state.open)rhine.messages.setOpen(false);if(rhine.state.queueOpen)rhine.action("queue-close");}
    }
    Loader {
        id: glassQueueLoader''')
# Disabling the chrome's pointer surface must not remove its decoration.
edit('Qt/qml/Main.qml','        visible: enabled && root.visibility !== Window.FullScreen','        visible: root.windowsFrameless && root.visibility !== Window.FullScreen')
print('G78: one queue-sized frame, shared frosted material, exclusive drawer input and aligned navigation installed.')
fragment=(root/'maintained/G78-ui-checks.cppfrag').read_text(encoding='utf-8')
edit('Qt/tests/UiChecks.cpp','                    window->grabWindow().save(output+"/preview-message-conversation.png");',fragment+'                    window->grabWindow().save(output+"/preview-message-conversation.png");')
edit('Qt/tests/UiChecks.cpp','                backend.host.fixture=previousFixture;music.uid=previousUID;music.changed();refresh();','''                if(messages){
                    const auto priorModal=hud.modal;
                    clickVisual(findVisual(window->contentItem(),"globalInbox"));settle(300);
                    clickVisual(findVisual(window->contentItem(),"globalSearch"));settle(230);
                    check(!messages->state()["open"].toBool()&&hud.modal==priorModal&&music.directory==originalDirectory,"G78 outside click closes messages without triggering the search underneath");
                }
                backend.host.fixture=previousFixture;music.uid=previousUID;music.changed();refresh();''')
edit('Qt/tests/UiChecks.cpp','            reportRetention("opened");','''            reportRetention("opened");
            check(findVisual(window->contentItem(),"globalSearch")&&!findVisual(window->contentItem(),"globalSearch")->isEnabled()&&findVisual(window->contentItem(),"queueClose")&&findVisual(window->contentItem(),"queueClose")->isEnabled(),"G78 queue input stays active and background hover/click surfaces are disabled");''')
