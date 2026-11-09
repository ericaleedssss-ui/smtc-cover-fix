import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Dialogs
import QtQuick.Controls as Controls
import Rhine.Native 1.0

Window {
    id: root
    RhineDialog {
        objectName:"nativeCompactConfirmation"
        visible:rhine.state.modal==="confirm"&&!rhine.state.closing
        unit:Math.max(.9,root.stageScale)
        title:"确认移除"
        message:(rhine.state.confirmTitle||"")+"\n\n"+(rhine.state.localMusic?"只移除本地索引，磁盘音乐文件保持原样。":"此操作将同步至"+rhine.state.accountProviderName+"。")
        confirmText:"确认移除";cancelText:"取消";destructive:true
        onAccepted:rhine.action("confirm:yes")
        onRejected:rhine.action("close-modal")
    }
    readonly property bool rightDrawerActive:rhine.state.queueOpen===true||rhine.messages.state.open===true||globalTools.messageDrawerVisible
    // 清理 hover 会同步发布 stateChanged；等绑定求值结束再写后端状态。
    onRightDrawerActiveChanged:if(rightDrawerActive)Qt.callLater(clearDrawerHover)
    function clearDrawerHover(){if(!rightDrawerActive)return;hoverClearTimer.stop();rhine.hoverItem("",0,0);rhine.hoverLink("");rhine.pointer("pointerleave",0,0);}
    property var commentsScrollMemory: ({})
    property var discoverScrollMemory: ({})
    property var profileViewMemory: ({})
    readonly property bool songDetailVisible:rhine.state.currentKind==="song"&&!rhine.state.viewer&&(rhine.state.mode==="detail"||rhine.state.lyricsMode)
    readonly property bool profileSurfaceVisible: rhine.state.modal === "profile" ||
        (rhine.state.artistPage === true && !rhine.state.modal && !rhine.state.viewer && !rhine.state.lyricsMode)
    property real backdropStrength: rhine.state.modal === "discover" && !rhine.state.closing ? 1 : 0
    Behavior on backdropStrength { NumberAnimation { duration: rhine.state.reduced ? 0 : 180 } }
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: {
              if(profileLoader.item&&profileLoader.item.dismissTopOverlay())return;
              if(artistProfileLoader.item&&artistProfileLoader.item.dismissTopOverlay())return;
            if(archiveReading.dismissTopOverlay())return;
            if(globalTools.dismiss())return;
            if(rhine.state.mode==="archive"&&rhine.state.nowPlaying===true){rhine.nowPlaying.operate("browse");return;}
            if(magazineLoader.item&&magazineLoader.item.dismissTopOverlay())return;
            if(rhine.magazine.songMenu.visible)rhine.magazine.closeMenu();
            else if(rhine.magazine.removalCount>0)rhine.magazine.cancelRemoval();
            else if(root.songDetailVisible&&!rhine.state.modal)rhine.action("player:detail-close");
            else rhine.action("back");
            inputLayer.forceActiveFocus();
        }
    }
    property real pendingHoverX: 0
    property real pendingHoverY: 0
    Timer {
        id: hoverClearTimer
        interval: 80
        onTriggered: if (!rhine.state.keyboardNavigation) rhine.hoverItem("", root.pendingHoverX, root.pendingHoverY)
    }
    width: 1280
    height: 720
    minimumWidth: 960
    minimumHeight: 540
    visible: true
    property bool windowsFrameless: Qt.platform.os === "windows"
    flags: (windowsFrameless ? Qt.FramelessWindowHint : 0) | Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint | Qt.WindowFullscreenButtonHint
    title: "RHINE MUSIC DATABASE"
    color: "#e7e7e1"
    DesktopLyrics {
        id: desktopLyricsWindow
        backend: rhine
    }
    FolderDialog {
        id: localFolderDialog
        objectName: "localMusicFolderDialog"
        title: "导入本地音乐文件夹"
        onAccepted: rhine.importLocal([selectedFolder])
    }
    FileDialog {
        id: localFileDialog
        objectName: "localMusicFileDialog"
        title: "导入本地音乐文件"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["音乐文件 (*.mp3 *.flac *.m4a *.mp4 *.aac *.ogg *.opus *.ape *.wav *.aiff *.aif *.wv *.wma *.mpc)"]
        onAccepted: rhine.importLocal(selectedFiles)
    }
    Connections {
        target: rhine
        function onLocalImportRequested(folder: bool) {
            if (folder) {
                localFolderDialog.open();
            } else {
                localFileDialog.open();
            }
        }
    }
    property real stageScale: height / 1080
    function routeWheel(wheel,source,action){
        var point=source.mapToItem(root.contentItem,wheel.x,wheel.y);
        if(sideNavigation.consumeWheel(point,wheel)){wheel.accepted=true;return;}
        if(archiveReading.collectionActive&&archiveReading.content&&point.y<976*root.stageScale&&!root.rightDrawerActive){
            archiveReading.content.wheelRecord(wheel);wheel.accepted=true;return;
        }
        rhine.wheelInput(point.x/root.stageScale,point.y/root.stageScale,wheel.pixelDelta.y,wheel.angleDelta.y);wheel.accepted=true;
    }
    property real stageWidth: width / stageScale
    onVisibilityChanged: function (visibility) {
        rhine.setVisible(visible && visibility !== Window.Minimized);
    }
    onWidthChanged: rhine.resize(width, height)
    onHeightChanged: rhine.resize(width, height)
    Component.onCompleted: {
        rhine.resize(width, height);
        inputLayer.forceActiveFocus();
    }
    Shortcut {
        sequences: [StandardKey.Quit]
        onActivated: Qt.quit()
    }
    Shortcut {
        sequences: Qt.platform.os === "osx" ? [StandardKey.FullScreen, "F11"] : ["F11"]
        onActivated: rhine.toggleFullscreen()
    }
    Item {
        id: baseVisual
        anchors.fill: parent
    Item {
        id: backgroundLayer
        z:-2
        anchors.fill: parent
        Rectangle {
            objectName: "libraryBackground2D"
            anchors.fill: parent
            // The glass surfaces still sample backgroundLayer. This static
            // rectangle needs no scene renderer or animation-driven updates.
            gradient: Gradient {
                GradientStop { position: 0; color: rhine.state.dark ? "#252a23" : "#f7f4ed" }
                GradientStop { position: 1; color: rhine.state.dark ? "#20251e" : "#efebe1" }
            }
        }
        Rectangle {
            objectName: "profileWindowBackground"
            anchors.fill: parent
            z: 1
            visible: root.profileSurfaceVisible
            color: rhine.state.dark === true ? "#22281f" : "#ffffff"
        }
    }
    Loader {
        objectName: "glassPlayerBar"
        active: rhine.state.mode !== "boot"
        x: 32 * root.stageScale; y: 990 * root.stageScale
        width: root.width - 64 * root.stageScale; height: 78 * root.stageScale
        sourceComponent: LiquidGlass {
            background: magazineLoader.active && magazineLoader.visible ? playerContentBackdrop : backgroundLayer
            sampleX: 32 * root.stageScale; sampleY: 990 * root.stageScale
            uiScale: root.stageScale; radius: 39 * root.stageScale
            dark: rhine.state.dark === true
            refractive: rhineRefractiveGlass
            materialEnabled:rhine.visualPreferences.liquidGlass!==false
            refraction:Number(rhine.visualPreferences.glassBend)*2.4
            frosting:(1-Number(rhine.visualPreferences.glassClear))*.5
            tint:(1-Number(rhine.visualPreferences.glassClear))*.25;rimStrength:.78
        }
    }
    Hud {
        anchors.fill: parent
        engine: rhine
    }
    Item {
        id: circularPlayerCover
        objectName: "circularPlayerCover"
        x: 45 * root.stageScale
        y: 1000 * root.stageScale
        width: 60 * root.stageScale
        height: 60 * root.stageScale
        z: 16
        opacity:songDetailLayer.barElementsOpacity
        visible: rhine.state.mode !== "boot" && !!rhine.state.playerCoverUrl
        NumberAnimation on rotation {from:0;to:360;duration:20000;loops:Animation.Infinite;running:circularPlayerCover.visible&&rhine.nowPlaying.playback.playing&&rhine.visualPreferences.barSpin&&!rhine.state.reduced&&rhine.visualPreferences.motion==="full"}
        Image {
            id: discPhoto
            objectName: "playerBarCoverImage"
            anchors.fill: parent
            source: rhine.state.playerCoverUrl || ""
            // Decode for this small disc, independently of the detail cover.
            // Power-of-two buckets retain physical-pixel detail at any DPR and
            // avoid a new decode for every pixel of a window resize.
            readonly property int decodeSide: Math.pow(2, Math.ceil(Math.log(Math.max(128, width * Screen.devicePixelRatio)) / Math.LN2))
            sourceSize: Qt.size(decodeSide, decodeSide)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
        }
        ShaderEffectSource {
            id: discTexture
            anchors.fill: parent
            sourceItem: discPhoto
            hideSource: true
            live: true
            smooth: true
            visible: false
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: rhine.state.dark ? "#34493e" : "#b9bfae"
            visible: discPhoto.status !== Image.Ready
            Text {
                anchors.centerIn: parent
                text: "♪"
                color: rhine.state.dark ? "#d4dfd0" : "#6e7a63"
                font.pixelSize: 25 * root.stageScale
            }
        }
        ShaderEffect {
            objectName: "circularCoverShader"
            anchors.fill: parent
            property var coverSource: discTexture
            fragmentShader: "qrc:/shaders/circularCover.frag.qsb"
            visible: discPhoto.status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.max(.5, root.stageScale * .8)
            border.color: rhine.state.dark ? "#70c5d2c3" : "#aaf6f4e7"
        }
    }

    // Playback edge-trail is decorative and never captures mouse input.
    // Actual seek is the straight upper stadium tangent, independently owned
    // by playbackSeekArea and unaffected by this short transition.
    Canvas {
        id: capsuleEdgeTrail
        objectName: "capsuleEdgeTrail"
        x: 32 * root.stageScale
        y: 990 * root.stageScale
        width: root.width - 64 * root.stageScale
        height: 78 * root.stageScale
        z: 15
        visible: edgeMotion.running && !rhine.state.reduced
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        property real travel: 1
        property string trackKey: String(rhine.state.playerTrackKey || "")
        property string priorTrack: ""
        onTrackKeyChanged: {
            var next = trackKey;
            if (priorTrack.length && next.length && priorTrack !== next &&
                !edgeMotion.running && !rhine.state.reduced) {
                edgeMotion.restart();
            }
            priorTrack = next;
        }
        onTravelChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        NumberAnimation {
            id: edgeMotion
            target: capsuleEdgeTrail
            property: "travel"
            from: 0
            to: 1
            duration: 1270
            easing.type: Easing.InOutCubic
        }
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!edgeMotion.running || width < height + 1) return;
            var r = height / 2;
            var straight = width - 2 * r;
            var halfCircle = Math.PI * r;
            var distance = 2 * halfCircle + straight;
            function pointAt(d) {
                d = Math.max(0, Math.min(distance, d));
                var theta;
                if (d <= halfCircle) {
                    theta = -Math.PI / 2 + d / r;
                    return [width - r + r * Math.cos(theta), r + r * Math.sin(theta)];
                }
                d -= halfCircle;
                if (d <= straight) return [width - r - d, height];
                d -= straight;
                theta = Math.PI / 2 + d / r;
                return [r + r * Math.cos(theta), r + r * Math.sin(theta)];
            }
            var head = travel * distance;
            var length = Math.min(distance * .22, 174 * root.stageScale);
            var start = Math.max(0, head - length);
            var fade = Math.min(1, (1 - travel) * 17);
            var spectrum = [[99, 191, 217], [141, 158, 229],
                            [197, 144, 217], [232, 163, 161]];
            for (var pass = 0; pass < 2; ++pass) {
                for (var i = 0; i < 22; ++i) {
                    var f0 = i / 22, f1 = (i + 1) / 22;
                    var from = pointAt(start + (head - start) * f0);
                    var to = pointAt(start + (head - start) * f1);
                    ctx.beginPath();
                    ctx.moveTo(from[0], from[1]);
                    ctx.lineTo(to[0], to[1]);
                    ctx.lineWidth = (pass === 0 ? 10 : 3.2) * root.stageScale;
                    ctx.lineCap = "round";
                    var step = Math.min(2, Math.floor(f1 * 3));
                    var blend = Math.min(1, f1 * 3 - step);
                    var a = spectrum[step], b = spectrum[step + 1];
                    var red = Math.round(a[0] + (b[0] - a[0]) * blend);
                    var green = Math.round(a[1] + (b[1] - a[1]) * blend);
                    var blue = Math.round(a[2] + (b[2] - a[2]) * blend);
                    var opacity = pass === 0
                        ? fade * .22 * (.38 + .62 * f1)
                        : fade * .94 * (.19 + .81 * f1 * f1);
                    ctx.strokeStyle = "rgba(" + red + "," + green + "," + blue + "," + opacity + ")";
                    ctx.stroke();
                }
            }
        }
    }
    // Lyrics/detail hit areas still come from the native HUD. Only the
    // text pixels move, so a long title never blocks the click handlers.
    Loader {
        id: titleMarqueeLoader
        opacity:songDetailLayer.barElementsOpacity
        objectName: "playerTitleMarqueeLoader"
        property var bounds: rhine.state.playerTitleBounds
        active: !!bounds && !!rhine.state.playerTitle && rhine.state.mode !== "boot"
        x: (bounds ? bounds.x : 109) * root.stageScale
        y: (bounds ? bounds.y : 1003) * root.stageScale
        width: (bounds ? bounds.width : 130) * root.stageScale
        height: (bounds ? bounds.height : 29) * root.stageScale
        z: 14
        sourceComponent: PlayerTitleMarquee {
            value: rhine.state.playerTitle || ""
            unit: root.stageScale
        }
    }
    }
    Loader {
        objectName: "pageBackdropBlur"
        anchors.left: parent.left; anchors.top: parent.top
        width: root.width; height: 976 * root.stageScale
        z: 150; active: root.backdropStrength > .001
        opacity: root.backdropStrength
        sourceComponent: Item {
            ShaderEffectSource {
                id: backdropSource; sourceItem: baseVisual
                sourceRect: Qt.rect(0, 0, width, height)
                width: parent.width; height: parent.height
                visible: false; live: true; hideSource: false
            }
            MultiEffect {
                anchors.fill: parent; source: backdropSource
                blurEnabled: true; blurMax: 8; blur: .45
                autoPaddingEnabled: false
            }
        }
    }
    // 透明 QML 输入层使用原舞台坐标；可见画面由同一份字形和材质绘制。
    MouseArea {
        id: inputLayer
        anchors.fill: parent
        hoverEnabled: !(magazineLoader.active && magazineLoader.visible)
        acceptedButtons: Qt.LeftButton
        focus: true
        onPressed: function (mouse) {
            // The magazine renders below the native player, but owns its content input.
            if (magazineLoader.active && magazineLoader.visible && mouse.y >= 94 * root.stageScale && mouse.y < 984 * root.stageScale) {
                mouse.accepted = false;
                return;
            }
            forceActiveFocus();
            rhine.pointer("pointerdown", mouse.x / root.stageScale, mouse.y / root.stageScale);
        }
        onPositionChanged: function (mouse) {
            rhine.pointer("pointermove", mouse.x / root.stageScale, mouse.y / root.stageScale);
        }
        onReleased: function (mouse) {
            rhine.pointer("pointerup", mouse.x / root.stageScale, mouse.y / root.stageScale);
        }
        onExited: rhine.pointer("pointerleave", 0, 0)
        onCanceled: rhine.pointer("pointercancel", 0, 0)
        onWheel: function (wheel) {
            if (magazineLoader.active && magazineLoader.visible && wheel.y >= 94 * root.stageScale && wheel.y < 984 * root.stageScale) {
                wheel.accepted = false;
                return;
            }
            root.routeWheel(wheel,inputLayer,"");
        }
        Keys.onPressed: function (event) {
            event.accepted = rhine.keyEvent(event.key, event.modifiers, event.text);
        }
    }
    Item {
        id: controls
        width: root.stageWidth
        height: 1080
        scale: root.stageScale
        transformOrigin: Item.TopLeft
        Repeater {
            model: rhine.hits
            delegate: Item {
                required property var modelData
                objectName: "nativeHit_" + modelData.action
                x: modelData.x
                y: modelData.y + (rhine.state.modal && !modelData.fixed ? rhine.state.modalOffset || 0 : 0)
                width: modelData.width
                height: modelData.height
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Accessible.onPressAction: rhine.action(modelData.action)
                Rectangle {
                    anchors.fill: parent
                    visible: modelData.navigation === true && rhine.state.focusAction === modelData.action
                    color: rhine.state.dark ? "#24bac39b" : "#16777b60"
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    visible: modelData.fixed === true && modelData.width <= 80 && nativePointer.containsMouse
                    color: rhine.state.dark ? "#1fc1c6aa" : "#14777b60"
                }
                RhineToolTip {visible:nativePointer.containsMouse && modelData.fixed === true;delay:550;text:modelData.label || ""}
                MouseArea {
                    id: nativePointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        hoverClearTimer.stop();
                        rhine.pointer("pointerleave", 0, 0);
                        if (modelData.link) { rhine.hoverLink(modelData.action); }
                        if ((modelData.navigation || modelData.rowOwner) && !rhine.state.keyboardNavigation) {
                            var p = mapToItem(inputLayer, mouseX, mouseY);
                            rhine.hoverItem(modelData.rowOwner || modelData.action, p.x / root.stageScale, p.y / root.stageScale);
                        }
                    }
                    onPositionChanged: function(mouse) {
                        if (modelData.navigation || modelData.rowOwner) {
                            hoverClearTimer.stop();
                            var p = mapToItem(inputLayer, mouse.x, mouse.y);
                            rhine.hoverItem(modelData.rowOwner || modelData.action, p.x / root.stageScale, p.y / root.stageScale);
                        }
                    }
                    onExited: {
                        if (modelData.link) { rhine.hoverLink(""); }
                        if ((modelData.navigation || modelData.rowOwner) && !rhine.state.keyboardNavigation) {
                            var p = mapToItem(inputLayer, mouseX, mouseY);
                            root.pendingHoverX = p.x / root.stageScale;
                            root.pendingHoverY = p.y / root.stageScale;
                            hoverClearTimer.restart();
                        }
                    }
                    acceptedButtons:Qt.LeftButton|Qt.RightButton
                    onPressed:function(mouse) {
                        inputLayer.forceActiveFocus();
                        if(mouse.button===Qt.RightButton){var p=mapToItem(null,mouse.x,mouse.y);rhine.magazine.showHitMenu(modelData.action,p.x,p.y);}
                        else if(!(rhine.state.directoryOpen&&(rhine.state.currentKind==="album"||rhine.state.currentKind==="radio"||rhine.state.currentKind==="artist")&&modelData.action.startsWith("music:track:")))rhine.action(modelData.action);
                    }
                    onDoubleClicked:function(mouse){if(mouse.button===Qt.LeftButton&&rhine.state.directoryOpen&&(rhine.state.currentKind==="album"||rhine.state.currentKind==="radio"||rhine.state.currentKind==="artist")&&modelData.action.startsWith("music:track:"))rhine.action(modelData.action.replace("music:track:","music:play-row:"));}
                    onWheel: function (wheel) {
                        root.routeWheel(wheel,nativePointer,modelData.action);
                    }
                }
            }
        }
    }
    Loader {
        objectName: "desktopSettingsLoader"
        active: rhine.state.modal === "desktop-settings"
        width:Math.min(root.width-40,800)
        height:Math.min(root.height-72,800)
        anchors.centerIn:parent
        z:400
        sourceComponent: DesktopLyricsPreferences { backend: rhine }
    }
    Loader {
        id:settingsLoader
        objectName:"settingsPageLoader"
        property bool wanted:rhine.state.modal==="settings"
        property real progress:0
        active:["settings","desktop-settings","interface-fonts"].indexOf(rhine.state.modal)>=0||progress>0
        visible:wanted||progress>0
        enabled:wanted
        onWantedChanged:{settingsMotion.stop();settingsMotion.to=wanted?1:0;settingsMotion.duration=rhine.state.reduced||rhine.visualPreferences.motion==="off"?0:280;settingsMotion.start();}
        Component.onCompleted:if(wanted)progress=1
        NumberAnimation {id:settingsMotion;target:settingsLoader;property:"progress";easing.type:Easing.BezierSpline;easing.bezierCurve:[.22,.8,.24,1,1,1]}
        anchors.fill:parent;z:390
        sourceComponent:SettingsPage {revealProgress:settingsLoader.progress}
    }
    Loader {
        objectName:"interfaceFontsLoader"
        active:rhine.state.modal==="interface-fonts"
        width:Math.min(root.width-48*root.stageScale,720*root.stageScale)
        height:Math.min(root.height-64*root.stageScale,760*root.stageScale)
        anchors.centerIn:parent;z:400
        sourceComponent:InterfaceFonts {unit:Math.max(.9,root.stageScale)}
    }
    // 密码只在输入组件和单次登录请求中短暂存在，提交后立即清空。
    Item {
        id: formFields
        visible: rhine.state.modal === "playlist-form" || (rhine.state.modal === "login" && (rhine.state.loginMethod === "phone" || rhine.state.loginMethod === "email"))
        x: (rhine.state.inputX || 0) * root.stageScale
        y: (rhine.state.modalOffset || 0) * root.stageScale
        width: (rhine.state.inputWidth || 0) * root.stageScale
        height: root.height
        opacity: rhine.state.modalOpacity || 0
        onVisibleChanged: {
            accountField.text = "";
            passwordField.text = "";
            if (visible) {
                accountField.forceActiveFocus();
            }
        }
        function submit() {
            rhine.submitForm(accountField.text, passwordField.text);
            passwordField.text = "";
        }
        Rectangle {
            x: 0
            y: 430 * root.stageScale
            width: parent.width
            height: 55 * root.stageScale
            color: rhine.state.dark ? "#30312b" : "#d9d8ce"
            radius:8*root.stageScale;border.width:accountField.activeFocus?1:0;border.color:"#879b7b"
        }
        TextInput {
            id: accountField
            objectName: "accountField"
            x: 14 * root.stageScale
            y: 430 * root.stageScale
            width: parent.width - 28 * root.stageScale
            height: 55 * root.stageScale
            verticalAlignment: TextInput.AlignVCenter
            color: rhine.state.dark ? "#eeeeeb" : "#161914"
            font.pixelSize: 19 * root.stageScale
            font.family:rhineFontFamily;font.variableAxes:({"wght":400})
            selectByMouse:true
            cursorVisible: activeFocus && !rhine.performance.idle
            maximumLength: 100
            Accessible.name: rhine.state.modal === "playlist-form" ? "歌单名称" : "登录账号"
            Keys.onReturnPressed: {
                if (rhine.state.modal !== "login") {
                    formFields.submit();
                } else {
                    passwordField.forceActiveFocus();
                }
            }
            Keys.onEscapePressed: rhine.action("close-modal")
        }
        Rectangle {
            visible: rhine.state.modal === "login"
            x: 0
            y: 541 * root.stageScale
            width: parent.width
            height: 55 * root.stageScale
            color: rhine.state.dark ? "#30312b" : "#d9d8ce"
            radius:8*root.stageScale;border.width:passwordField.activeFocus?1:0;border.color:"#879b7b"
        }
        TextInput {
            id: passwordField
            objectName: "passwordField"
            visible: rhine.state.modal === "login"
            x: 14 * root.stageScale
            y: 541 * root.stageScale
            width: parent.width - 28 * root.stageScale
            height: 55 * root.stageScale
            verticalAlignment: TextInput.AlignVCenter
            color: rhine.state.dark ? "#eeeeeb" : "#161914"
            font.pixelSize: 19 * root.stageScale
            font.family:rhineFontFamily;font.variableAxes:({"wght":400})
            selectByMouse:true
            cursorVisible: activeFocus && !rhine.performance.idle
            maximumLength: 256
            echoMode: TextInput.Password
            Accessible.name: "密码"
            Keys.onReturnPressed: formFields.submit()
            Keys.onEscapePressed: rhine.action("close-modal")
        }
        RhineButton {
            x: parent.width - width
            y: (rhine.state.modal === "login" ? 611 : 530) * root.stageScale
            width: 170 * root.stageScale
            height: 36 * root.stageScale
            unit:root.stageScale;primary:true
            text:rhine.state.modal === "login" ? "登录" : "保存"
            Accessible.role: Accessible.Button
            Accessible.name: "提交表单"
            Accessible.onPressAction: formFields.submit()
            onClicked:formFields.submit()
        }
    }
    Repeater {
        model: ["seek", "volume"]
        delegate: MouseArea {
            id: adjustment
            required property string modelData
            objectName: modelData === "seek" ? "playbackSeekArea" : "playbackVolumeArea"
            property var region: rhine.state[modelData]
            readonly property bool isSeek: modelData === "seek"
            readonly property bool interacting: isSeek && (containsMouse || pressed)
            readonly property real duration: Math.max(0, Number(rhine.state.playbackDuration) || 0)
            readonly property real fraction: duration > 0 ? Math.max(0, Math.min(1, (Number(rhine.state.playbackPosition) || 0) / duration)) : 0
            readonly property real shownFraction: pressed && isSeek ? Math.max(0, Math.min(1, mouseX / Math.max(1,width))) : fraction
            function timestamp(seconds) {
                var total = Math.max(0, Math.floor(seconds));
                return Math.floor(total / 60).toString().padStart(2,"0") + ":" + (total % 60).toString().padStart(2,"0");
            }
            hoverEnabled: isSeek
            z: isSeek ? 210 : 0
            visible: !!region
            opacity:isSeek?songDetailLayer.barElementsOpacity:1
            enabled: visible && !rhine.state.closing
            x: region ? region.x * root.stageScale : 0
            y: region ? region.y * root.stageScale : 0
            width: region ? region.width * root.stageScale : 0
            height: region ? region.height * root.stageScale : 0
            cursorShape: Qt.PointingHandCursor
            onPressed: function (mouse) {
                if (!isSeek || rhine.state.playbackSeekable === true) rhine.adjustPlayer(modelData, mouse.x, width);
            }
            onPositionChanged: function (mouse) {
                if (pressed && (!isSeek || rhine.state.playbackSeekable === true)) {
                    rhine.adjustPlayer(modelData, mouse.x, width);
                }
            }
            SoftSeekTrack {
                id: seekTrack
                objectName: "playbackSeekTrack"
                visible: adjustment.isSeek
                width: parent.width
                height: 12 * root.stageScale
                y: 10 * root.stageScale - height / 2
                unit:root.stageScale;dark:rhine.state.dark===true;onGlass:true;active:adjustment.interacting
                fraction:adjustment.shownFraction
            }
            Item {
                id: chorusMarker
                objectName: "playbackChorusMarker"
                readonly property real seconds: Number(rhine.state.chorusSeconds)
                visible: adjustment.interacting && seconds > 0 && seconds < adjustment.duration && rhine.state.playbackSeekable === true
                width: 22 * root.stageScale; height: width
                x: adjustment.width * seconds / Math.max(1, adjustment.duration) - width/2
                y: 10 * root.stageScale - height/2
                Rectangle {
                    anchors.centerIn: parent; width: (chorusHover.containsMouse ? 8 : 6) * root.stageScale
                    height: width; radius: width/2; color: "#faf8ef"
                    border.width: .6 * root.stageScale; border.color: "#a5aa91"
                }
                MouseArea {
                    id: chorusHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: rhine.adjustPlayer("seek", chorusMarker.seconds, adjustment.duration)
                }
            }
            GlassSeekThumb {
                id:seekThumb
                objectName: "playbackSeekThumb"
                unit:root.stageScale;dark:rhine.state.dark===true;background:backgroundLayer
                track:seekTrack
                hovered:adjustment.isSeek&&adjustment.containsMouse&&adjustment.duration>0
                pressed:adjustment.isSeek&&adjustment.pressed&&adjustment.duration>0
                blocked:edgeMotion.running&&!RhineTheme.noMotion
                session:String(rhine.state.playerTrackKey||"")
                fraction:adjustment.shownFraction
                x: Math.max(0, Math.min(parent.width - width, parent.width * displayFraction - width / 2))
                y: 10 * root.stageScale - height / 2
            }
            Rectangle {
                objectName: "playbackSeekTime"
                visible: adjustment.interacting && adjustment.duration > 0
                width: seekTime.implicitWidth + 24 * root.stageScale
                height: 30 * root.stageScale; radius: height / 2
                x: Math.max(8 * root.stageScale, Math.min(parent.width - width - 8 * root.stageScale, parent.width * (chorusHover.containsMouse ? chorusMarker.seconds / Math.max(1, adjustment.duration) : adjustment.shownFraction) - width/2))
                y: -36 * root.stageScale
                color: rhine.state.dark ? "#35392f" : "#faf8ef"
                border.width: .7 * root.stageScale
                border.color: rhine.state.dark ? "#59604e" : "#d8dacb"
                Text {
                    id: seekTime
                    objectName: "playbackSeekTimeText"
                    anchors.centerIn: parent
                    text: chorusHover.containsMouse ? "副歌 · " + adjustment.timestamp(chorusMarker.seconds) : adjustment.timestamp(adjustment.shownFraction * adjustment.duration) + " / " + adjustment.timestamp(adjustment.duration)
                    color: rhine.state.dark ? "#eeeede" : "#4b503f"
                    font.family: rhineFontFamily; font.pixelSize: 13 * root.stageScale; font.weight: Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold})
                }
            }
        }
    }
    Connections {
        target: rhine
        function onClearCredentials() {
            accountField.text = "";
            passwordField.text = "";
        }
    }

    Rectangle {
        visible: searchInput.visible
        x: searchInput.x
        y: searchInput.y
        width: searchInput.width
        height: searchInput.height
        color: rhine.state.dark ? "#ffffff" : "#141613"
        opacity: (rhine.state.modalOpacity || 0) * 0.045
    }
    TextInput {
        id: searchInput
        objectName: "musicSearchInput"
        verticalAlignment: TextInput.AlignVCenter
        leftPadding: 14 * root.stageScale
        rightPadding: 14 * root.stageScale
        renderType: Text.NativeRendering
        visible: rhine.state.modal === "search" || rhine.state.modal === "saved"
        enabled: !rhine.state.closing
        x: (rhine.state.inputX || 0) * root.stageScale
        y: ((rhine.state.inputY || 302) + (rhine.state.modalOffset || 0)) * root.stageScale
        width: (rhine.state.inputWidth || 0) * root.stageScale
        height: 54 * root.stageScale
        font.family: rhineFontFamily;font.variableAxes:({"wght":400})
        font.pixelSize: 22 * root.stageScale
        color: rhine.state.dark ? "#ebebeb" : "#141613"
        opacity: rhine.state.modalOpacity || 0
        clip: true
        cursorVisible: activeFocus && !rhine.performance.idle
        selectByMouse: true
        Accessible.name: rhine.state.localMusic ? "检索本地歌曲、歌手、专辑或文件夹" : "搜索歌曲、歌手、专辑或歌单"
        onTextEdited: rhine.query(text)
        onVisibleChanged: {
            if (visible) {
                text = rhine.state.query || "";
                forceActiveFocus();
            } else {
                inputLayer.forceActiveFocus();
            }
        }
        Keys.onEscapePressed: rhine.action("close-modal")
        Keys.onReturnPressed: function (event) {
            rhine.searchAccepted(text, event.modifiers);
        }
        Text {
            anchors.fill: parent
            visible: searchInput.text.length === 0 && !searchInput.preeditText
            text: rhine.state.localMusic ? "检索本地歌曲、歌手、专辑或文件夹" : "搜索歌曲、歌手、专辑或歌单"
            font: searchInput.font
            leftPadding: searchInput.leftPadding
            verticalAlignment: Text.AlignVCenter
            color: "#777777"
        }
    }
    Shortcut {
        sequence: "F10"
        onActivated: profiler.toggleVisible()
    }
    Loader {
        id: magazineLoader
        onStatusChanged:rhine.tracePipeline("qml.magazine.status-"+status)
        objectName: "playlistMagazineLoader"
        parent:baseVisual
        x:0; y:0; width:root.width; height:1080*root.stageScale
        z:-1
        readonly property bool wanted:rhine.magazine.active && !rhine.state.viewer && rhine.state.mode!=="boot"
        active:false
        function syncActivation(){active=wanted;}
        onWantedChanged:Qt.callLater(syncActivation)
        Component.onCompleted:Qt.callLater(syncActivation)
        // Legacy blocking native pages paint above the room. Retain this
        // Loader and its view state beneath them; the nonblocking queue never
        // changes this visibility condition.
        visible:active && (!rhine.state.modal || rhine.state.modal==="discover")
        sourceComponent: PlaylistMagazine {controller:rhine.magazine; background:backgroundLayer; glassBackground:backgroundLayer; unit:root.stageScale}
    }
    ArchiveReading {
        id:archiveReading
        property var bounds:rhine.state.readingPanel
        visible:!!bounds
        x:(bounds?bounds.x:0)*root.stageScale;y:(bounds?bounds.y:0)*root.stageScale
        width:(bounds?bounds.width:0)*root.stageScale;height:(bounds?bounds.height:0)*root.stageScale
        z:84
        background:backgroundLayer;materialLayer:baseVisual;controller:rhine.showcase
        unit:root.stageScale;dark:rhine.state.dark===true;frosted:rhine.state.textFrosted===true
        playing:rhine.state.nowPlaying===true;playbackController:rhine.nowPlaying
        collection:(rhine.state.archiveCollection===true||rhine.state.currentKind==="playlist"||rhine.state.currentKind==="album")&&!rhine.state.directoryOpen
    }
    ArchiveNavigator {
        id:archiveNavigator
        controller:rhine;navigation:rhine.state.archiveNavigation||({})
        unit:root.stageScale;dark:rhine.state.dark===true;reduced:rhine.state.reduced===true
        width:implicitWidth;height:implicitHeight
        x:archiveReading.x+(archiveReading.width-width)/2
        y:Math.min(archiveReading.y+archiveReading.height+16*root.stageScale,976*root.stageScale-height-12*root.stageScale)
        downOffset:archiveReading.x-x
        z:84
        visible:rhine.state.mode==="archive"&&!rhine.state.directoryOpen&&!rhine.state.modal&&!rhine.state.viewer&&!rhine.state.lyricsMode&&!rhine.state.commentsOpen
    }
    NowPlayingShortcut {
        unit:root.stageScale;dark:rhine.state.dark===true;reduced:rhine.state.reduced===true
        available:!!rhine.state.playerTrackKey;playing:rhine.nowPlaying.playback.playing===true
        selected:rhine.state.nowPlaying===true&&rhine.state.mode==="archive"&&!rhine.state.modal&&!rhine.state.directoryOpen&&!rhine.state.lyricsMode
        blocked:root.rightDrawerActive;motionAllowed:root.visible&&root.visibility!==Window.Minimized
        x:root.width-86*root.stageScale;y:1012*root.stageScale
        width:36*root.stageScale;height:width;z:14
        visible:rhine.state.mode!=="boot"
        onOpenRequested:rhine.action("player:now-playing")
    }
    ArchiveActionIcon {
        objectName:"playerShuffleArtwork"
        x:root.width/2-156*root.stageScale;y:1017*root.stageScale
        width:24*root.stageScale;height:width;z:14
        source:"qrc:/icons/archive-shuffle.png"
        tint:rhine.state.dark?"#b8c7a6":"#738063"
        visible:rhine.state.mode!=="boot"&&rhine.state.playerMode==="shuffle"&&!rhine.state.roamActive
    }
    GlobalTools {id:globalTools;objectName:"globalTools";anchors.fill:parent;z:330;background:backgroundLayer;drawerBackground:queueGlassBackdrop;unit:root.stageScale;topRightReserved:root.windowsFrameless&&root.visibility!==Window.FullScreen?132*Math.max(.9,root.stageScale):0}
    // Overlay popups sample these lower layers; they never capture themselves.
    readonly property var popupGlassSources:songDetailVisible?[songDetailLayer]:[baseVisual,archiveReading]
    Rectangle {anchors.fill:parent;z:339;color:"black";opacity:songDetailLayer.progress*.4;visible:opacity>0}
    Item {
        id:songDetailLayer;objectName:"songDetailTransition"
        // Cloudy ui_nowplaying.go: reveal the fixed-size view through the bar's box.
        property real progress:0
        property bool retained:false
        property real flightRotation:0
        readonly property real barElementsOpacity:songDetailLoader.item&&songDetailLoader.item.flying?1-songDetailLoader.item.easeRange(progress,.001,.005):1
        onBarElementsOpacityChanged:rhine.setDetailFlightBarOpacity(barElementsOpacity)
        readonly property bool opened:root.songDetailVisible
        readonly property real barX:32*root.stageScale
        readonly property real barY:990*root.stageScale
        readonly property real barWidth:root.width-64*root.stageScale
        readonly property real barHeight:78*root.stageScale
        x:barX*(1-progress);y:barY*(1-progress)
        width:barWidth+(root.width-barWidth)*progress
        height:barHeight+(root.height-barHeight)*progress
        z:340;clip:true
        layer.enabled:progress>0&&progress<1
        layer.effect:MultiEffect {
            maskEnabled:true
            maskSource:detailRevealMask
            maskThresholdMin:.5;maskSpreadAtMin:1
        }
        Rectangle {
            id:detailRevealMask
            anchors.fill:parent
            radius:songDetailLayer.barHeight/2*(1-songDetailLayer.progress)
            color:"white";visible:false
            layer.enabled:rhinePipelineLegacy||(songDetailLayer.progress>0&&songDetailLayer.progress<1)
        }
        visible:retained
        enabled:opened
        function syncOpen(){
            flightRotation=((circularPlayerCover.rotation+180)%360)-180;
            if(opened)retained=true;
            detailReveal.stop();detailReveal.to=opened?1:0;
            detailReveal.duration=rhine.state.reduced||rhine.visualPreferences.motion==="off"?0:opened?580:500;
            detailReveal.easing.bezierCurve=opened?[.32,.72,0,1,1,1]:[.42,0,.12,1,1,1];
            detailReveal.start();
        }
        onOpenedChanged:syncOpen()
        Component.onCompleted:syncOpen()
        NumberAnimation {id:detailReveal;target:songDetailLayer;property:"progress";easing.type:Easing.BezierSpline;onFinished:if(!songDetailLayer.opened)songDetailLayer.retained=false}
        Loader {
            id:songDetailLoader;objectName:"songDetailLoader"
            onStatusChanged:rhine.tracePipeline("qml.song.status-"+status)
            active:songDetailLayer.retained
            x:-songDetailLayer.x;y:-songDetailLayer.y;width:root.width;height:root.height
            sourceComponent:SongDetailPage {
                revealProgress:songDetailLayer.progress;transitionOpen:songDetailLayer.opened
                barCover:Qt.rect(circularPlayerCover.x,circularPlayerCover.y,circularPlayerCover.width,circularPlayerCover.height)
                barTitle:Qt.rect(titleMarqueeLoader.x,titleMarqueeLoader.y,titleMarqueeLoader.width,titleMarqueeLoader.height)
                barScrub:Qt.rect((rhine.state.seek||{}).x*root.stageScale,(rhine.state.seek||{}).y*root.stageScale,(rhine.state.seek||{}).width*root.stageScale,(rhine.state.seek||{}).height*root.stageScale)
                barPlay:Qt.rect(root.width/2-29*root.stageScale,1000*root.stageScale,58*root.stageScale,58*root.stageScale)
                barRotation:songDetailLayer.flightRotation
                barDark:rhine.state.dark
            }
        }
    }
    SongContextMenu {anchors.fill:parent;z:500;controller:rhine.magazine;background:backgroundLayer;unit:root.stageScale}
    SoundEffectsDialog {controller:rhine.soundEffects}
    Rectangle {
        id:operationToast
        property string lastMessage:""
        readonly property bool wanted:(toastExpiry.running || rhine.magazine.downloading) && lastMessage!==""
        z:480;anchors.horizontalCenter:parent.horizontalCenter;y:root.height-150*root.stageScale
        opacity:wanted?1:0;visible:opacity>0;enabled:wanted
        Behavior on opacity {NumberAnimation {duration:RhineTheme.noMotion?0:160}}
        width:Math.min(root.width-40,toastText.implicitWidth+40);height:Math.max(48,toastText.implicitHeight+24);radius:16
        color:rhine.state.dark?"#ef30382b":"#f2f3f0e5";border.color:"#50758265"
        Text {id:toastText;anchors.centerIn:parent;width:Math.min(implicitWidth,parent.width-30);text:operationToast.lastMessage+(rhine.magazine.downloading?" · 点击取消下载":"");wrapMode:Text.Wrap;color:rhine.state.dark?"#e3e8d9":"#4a5940";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14}
        MouseArea {anchors.fill:parent;enabled:rhine.magazine.downloading;cursorShape:Qt.PointingHandCursor;onClicked:rhine.magazine.cancelDownload()}
        Timer {id:toastExpiry;interval:4500}
        Connections {target:rhine.magazine;function onChanged(){var message=rhine.magazine.status;if(message!==operationToast.lastMessage){operationToast.lastMessage=message;toastExpiry.restart();}}}
    }
    Loader {
        id: commentsLoader
        objectName: "commentsLoader"
        property var bounds: rhine.state.commentsBounds
        x: (bounds ? bounds.x : 0) * root.stageScale
        y: (bounds ? bounds.y : 0) * root.stageScale
        width: (bounds ? bounds.width : 0) * root.stageScale
        height: (bounds ? bounds.height : 0) * root.stageScale
        z: 100
        property bool wanted: rhine.state.commentsOpen === true && !!bounds
        active: false
        function syncActivation() { active = wanted; }
        onWantedChanged: Qt.callLater(syncActivation)
        Component.onCompleted: syncActivation()
        visible: wanted && rhine.state.modal !== "profile"
        sourceComponent: CommentsPage { scrollMemory: root.commentsScrollMemory }
    }
    Loader {
        id: profileLoader
        objectName: "userProfileLoader"
          x: 0; y: 112 * root.stageScale
          width: root.width; height: 872 * root.stageScale
        z: 190
        active: rhine.state.modal === "profile"
          sourceComponent: UserProfile { unit: Math.max(.9,root.stageScale); viewMemory:root.profileViewMemory; onViewSaved:function(memory){root.profileViewMemory=memory;} onConversationRequested:function(uid,name){globalTools.openConversation(uid,name)} }
    }
      Loader {
          id: artistProfileLoader
          objectName: "artistProfileLoader"
          x: 0; y: 112 * root.stageScale
          width: root.width; height: 872 * root.stageScale
          z: 89
          active: rhine.state.artistPage === true && !rhine.state.viewer && !rhine.state.lyricsMode
          visible: active && !rhine.state.modal
          sourceComponent: UserProfile { unit: Math.max(.9,root.stageScale); artistMode: true; viewMemory:root.profileViewMemory; onViewSaved:function(memory){root.profileViewMemory=memory;} }
      }
    Loader {
        objectName: "lyricsReadingLoader"
        property var bounds: rhine.state.lyricBounds
        x: (bounds ? bounds.x : 0) * root.stageScale; y: (bounds ? bounds.y : 0) * root.stageScale
        width: (bounds ? bounds.width : 0) * root.stageScale; height: (bounds ? bounds.height : 0) * root.stageScale
        z: 90; active: !!bounds
        sourceComponent: LyricsReading { unit: root.stageScale }
    }
    Loader {
        id: detailReaderLoader
        objectName: "readerLoader"
        property var bounds: rhine.state.readerBounds
        x: (bounds ? bounds.x : 0) * root.stageScale
        y: (bounds ? bounds.y : 0) * root.stageScale
        width: (bounds ? bounds.width : 0) * root.stageScale
        height: (bounds ? bounds.height : 0) * root.stageScale
        z: 99
        active: !!bounds
        sourceComponent: ReadingText {}
    }
    Loader {
        id: recommendationsLoader
        objectName: "recommendationsLoader"
        property var bounds: rhine.state.recommendationsBounds
        x: (bounds ? bounds.x : 0) * root.stageScale
        y: (bounds ? bounds.y : 0) * root.stageScale
        width: (bounds ? bounds.width : 0) * root.stageScale
        height: (bounds ? bounds.height : 0) * root.stageScale
        z: 100
        active: rhine.state.recommendationsOpen === true && !!bounds
        sourceComponent: RecommendationsPage {}
    }
    Connections {
        target: rhine
        function onPageNavigation(key) {
            if (rhine.state.queueOpen) return;
            if (profileLoader.active && profileLoader.item) profileLoader.item.navigateKey(key);
            else if (!rhine.state.modal) {
                if(artistProfileLoader.active && artistProfileLoader.item)artistProfileLoader.item.navigateKey(key);
                else if(magazineLoader.active && magazineLoader.item)magazineLoader.item.navigateKey(key);
                else if (commentsLoader.active && commentsLoader.visible && commentsLoader.item) commentsLoader.item.navigateKey(key);
                else if (recommendationsLoader.active && recommendationsLoader.item) recommendationsLoader.item.navigateKey(key);
                else if (detailReaderLoader.active && detailReaderLoader.item && rhine.state.currentKind === "song") detailReaderLoader.item.navigateKey(key);
            }
        }
    }
    Loader {
        id: discoverGlassLoader
        objectName: "discoverGlassLoader"
        anchors.fill: parent
        z: 180
        active: rhine.state.modal === "discover"
        sourceComponent: DiscoverGlass { background: backgroundLayer; unit: root.stageScale; scrollMemory: root.discoverScrollMemory }
    }
    // Acyclic, queue-sized lower-layer capture. These sources contain the
    // actual page and navigation glasses, but never the foreground queue.
    // Half-resolution tiles bound the extra texture cost to the panel area.
    Item {
        id:playerContentBackdrop
        objectName:"playerContentBackdrop"
        anchors.fill:parent;visible:false
        Loader {
            anchors.fill:parent
            active:magazineLoader.active && magazineLoader.visible
            sourceComponent:Item {
                ShaderEffectSource {
                    x:10*root.stageScale;y:968*root.stageScale;width:root.width-20*root.stageScale;height:112*root.stageScale
                    sourceItem:backgroundLayer;sourceRect:Qt.rect(x,y,width,height)
                    live:true;smooth:true;hideSource:false
                }
                ShaderEffectSource {
                    objectName:"playerMagazineTile"
                    x:10*root.stageScale;y:968*root.stageScale;width:root.width-20*root.stageScale;height:112*root.stageScale
                    sourceItem:magazineLoader;sourceRect:Qt.rect(x,y,width,height)
                    live:true;smooth:true;hideSource:false
                }
            }
        }
    }
    Item {
        id: queueGlassBackdrop
        objectName: "queueGlassBackdrop"
        anchors.fill: parent
        visible: false
        readonly property real pad: 22 * root.stageScale
        Loader {
            anchors.fill: parent
            active: root.rightDrawerActive
            sourceComponent: Item {
                ShaderEffectSource {
                    objectName: "queuePageTile"
                    x: glassQueueLoader.x - queueGlassBackdrop.pad
                    y: glassQueueLoader.y - queueGlassBackdrop.pad
                    width: glassQueueLoader.width + 2 * queueGlassBackdrop.pad
                    height: glassQueueLoader.height + 2 * queueGlassBackdrop.pad
                    sourceItem: baseVisual
                    sourceRect: Qt.rect(x, y, width, height)
                    textureSize: Qt.size(Math.max(1, Math.ceil(width / 2)), Math.max(1, Math.ceil(height / 2)))
                    live: true; smooth: true; hideSource: false
                }
                Loader {
                    anchors.fill:parent
                    // The magazine now belongs to baseVisual, already captured above.
                    active:false
                    sourceComponent:Item {
                        ShaderEffectSource {
                            objectName:"queueMagazineTile"
                            x:glassQueueLoader.x-queueGlassBackdrop.pad;y:glassQueueLoader.y-queueGlassBackdrop.pad
                            width:glassQueueLoader.width+2*queueGlassBackdrop.pad;height:glassQueueLoader.height+2*queueGlassBackdrop.pad
                            sourceItem:magazineLoader;sourceRect:Qt.rect(x,y,width,height)
                            textureSize:Qt.size(Math.max(1,Math.ceil(width/2)),Math.max(1,Math.ceil(height/2)))
                            live:true;smooth:true;hideSource:false
                        }
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: detailReaderLoader.active && detailReaderLoader.visible
                    sourceComponent: Item {
                        ShaderEffectSource {
                            objectName: "queueReaderTile"
                            x: glassQueueLoader.x - queueGlassBackdrop.pad
                            y: glassQueueLoader.y - queueGlassBackdrop.pad
                            width: glassQueueLoader.width + 2 * queueGlassBackdrop.pad
                            height: glassQueueLoader.height + 2 * queueGlassBackdrop.pad
                            sourceItem: detailReaderLoader
                            sourceRect: Qt.rect(x - detailReaderLoader.x, y - detailReaderLoader.y, width, height)
                            textureSize: Qt.size(Math.max(1, Math.ceil(width / 2)), Math.max(1, Math.ceil(height / 2)))
                            live: true; smooth: true; hideSource: false
                        }
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: commentsLoader.active && commentsLoader.visible
                    sourceComponent: Item {
                        ShaderEffectSource {
                            objectName: "queueCommentsTile"
                            x: glassQueueLoader.x - queueGlassBackdrop.pad
                            y: glassQueueLoader.y - queueGlassBackdrop.pad
                            width: glassQueueLoader.width + 2 * queueGlassBackdrop.pad
                            height: glassQueueLoader.height + 2 * queueGlassBackdrop.pad
                            sourceItem: commentsLoader
                            sourceRect: Qt.rect(x - commentsLoader.x, y - commentsLoader.y, width, height)
                            textureSize: Qt.size(Math.max(1, Math.ceil(width / 2)), Math.max(1, Math.ceil(height / 2)))
                            live: true; smooth: true; hideSource: false
                        }
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: recommendationsLoader.active && recommendationsLoader.visible
                    sourceComponent: Item {
                        ShaderEffectSource {
                            objectName: "queueRecommendationsTile"
                            x: glassQueueLoader.x - queueGlassBackdrop.pad
                            y: glassQueueLoader.y - queueGlassBackdrop.pad
                            width: glassQueueLoader.width + 2 * queueGlassBackdrop.pad
                            height: glassQueueLoader.height + 2 * queueGlassBackdrop.pad
                            sourceItem: recommendationsLoader
                            sourceRect: Qt.rect(x - recommendationsLoader.x, y - recommendationsLoader.y, width, height)
                            textureSize: Qt.size(Math.max(1, Math.ceil(width / 2)), Math.max(1, Math.ceil(height / 2)))
                            live: true; smooth: true; hideSource: false
                        }
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: discoverGlassLoader.active && discoverGlassLoader.visible
                    sourceComponent: Item {
                        ShaderEffectSource {
                            objectName: "queueDiscoverTile"
                            x: glassQueueLoader.x - queueGlassBackdrop.pad
                            y: glassQueueLoader.y - queueGlassBackdrop.pad
                            width: glassQueueLoader.width + 2 * queueGlassBackdrop.pad
                            height: glassQueueLoader.height + 2 * queueGlassBackdrop.pad
                            sourceItem: discoverGlassLoader
                            sourceRect: Qt.rect(x - discoverGlassLoader.x, y - discoverGlassLoader.y, width, height)
                            textureSize: Qt.size(Math.max(1, Math.ceil(width / 2)), Math.max(1, Math.ceil(height / 2)))
                            live: true; smooth: true; hideSource: false
                        }
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: profileLoader.active && profileLoader.visible
                    sourceComponent: Item {
                        ShaderEffectSource {
                            objectName: "queueProfileTile"
                            x: glassQueueLoader.x - queueGlassBackdrop.pad
                            y: glassQueueLoader.y - queueGlassBackdrop.pad
                            width: glassQueueLoader.width + 2 * queueGlassBackdrop.pad
                            height: glassQueueLoader.height + 2 * queueGlassBackdrop.pad
                            sourceItem: profileLoader
                            sourceRect: Qt.rect(x - profileLoader.x, y - profileLoader.y, width, height)
                            textureSize: Qt.size(Math.max(1, Math.ceil(width / 2)), Math.max(1, Math.ceil(height / 2)))
                            live: true; smooth: true; hideSource: false
                        }
                    }
                }
                ShaderEffectSource {
                    objectName: "queueNavigationTile"
                    x: glassQueueLoader.x - queueGlassBackdrop.pad
                    y: glassQueueLoader.y - queueGlassBackdrop.pad
                    width: glassQueueLoader.width + 2 * queueGlassBackdrop.pad
                    height: glassQueueLoader.height + 2 * queueGlassBackdrop.pad
                    sourceItem: sideNavigation
                    sourceRect: Qt.rect(x, y, width, height)
                    textureSize: Qt.size(Math.max(1, Math.ceil(width / 2)), Math.max(1, Math.ceil(height / 2)))
                    live: true; smooth: true; hideSource: false
                }
            }
        }
    }
    DrawerInputGate {
        anchors.fill:parent;sceneRoot:root.contentItem;overlayLayer:Controls.Overlay.overlay
        queueSurface:glassQueueLoader;collectionSurface:queueCollectionOverlay
        blocked:root.rightDrawerActive
        onDismissed:{if(rhine.messages.state.open)rhine.messages.setOpen(false);if(rhine.state.queueOpen)rhine.action("queue-close");}
    }
    Loader {
        id: glassQueueLoader
        objectName: "glassQueueLoader"
        property var bounds: rhine.state.drawerBounds || rhine.state.queueBounds
        active: rhine.state.queueOpen === true
        x: (bounds ? bounds.x : 0) * root.stageScale
        y: (bounds ? bounds.y : 0) * root.stageScale
        width: (bounds ? bounds.width : 430) * root.stageScale
        height: (bounds ? bounds.height : 842) * root.stageScale
        z: 350
        sourceComponent: PlayerQueueGlass {
            background: queueGlassBackdrop
            sampleX: glassQueueLoader.x
            sampleY: glassQueueLoader.y
            unit: root.stageScale
        }
    }
    Item {
        id: queueCollectionOverlay
        objectName: "queueCollectionOverlay"
        anchors.fill: parent
        z: 360
        visible: rhine.state.queueCollectionOpen === true
        enabled: visible
        MouseArea { anchors.fill: parent; onClicked: rhine.action("queue-collection-close"); onWheel: function(wheel) { wheel.accepted = true } }
        Rectangle { anchors.fill: parent; color: "#20000000" }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 500 * Math.max(.85, root.stageScale))
            height: Math.min(parent.height - 60, 580 * Math.max(.85, root.stageScale))
            radius: 20 * root.stageScale
            color: rhine.state.dark ? "#292d29" : "#f4f3eb"
            MouseArea { anchors.fill: parent; onClicked: {} }
            Text { x:24; y:22; text:"收藏到歌单"; color:rhine.state.dark ? "#e6e9df" : "#414a3c"
                font.family:rhineFontFamily;font.variableAxes:({"wght":400}); font.pixelSize:20 }
            Text { anchors.right:parent.right; anchors.rightMargin:24; y:24; text:"关闭"; color:"#77816d"
                MouseArea { anchors.fill:parent; enabled:!rhine.state.queueWriteLoading
                    cursorShape:Qt.PointingHandCursor; onClicked:rhine.action("queue-collection-close") } }
            ListView {
                id: queuePlaylistList
                objectName:"queuePlaylistList"
                anchors.fill:parent; anchors.topMargin:65; anchors.bottomMargin:70; anchors.leftMargin:16; anchors.rightMargin:16
                clip:true; spacing:6
                model:rhine.state.navigationCreated || []
                delegate: Rectangle {
                    required property var modelData
                    objectName: "queuePlaylist_" + modelData.id
                    width:queuePlaylistList.width; height:54; radius:9
                    color:pickMouse.containsMouse ? (rhine.state.dark ? "#424b3d" : "#e3e9d9") : "transparent"
                    Text { anchors.fill:parent; anchors.margins:12; verticalAlignment:Text.AlignVCenter
                        text:parent.modelData.title || "未命名歌单"; elide:Text.ElideRight
                        font.family:rhineFontFamily;font.variableAxes:({"wght":400}); font.pixelSize:16; color:rhine.state.dark ? "#e6e9df" : "#414a3c" }
                    MouseArea { id:pickMouse; anchors.fill:parent; hoverEnabled:true; enabled:!rhine.state.queueWriteLoading
                        cursorShape:Qt.PointingHandCursor
                        onClicked:rhine.action("music:playlist-pick:" + parent.modelData.id) }
                }
            }
            Text { x:24; y:parent.height-56; width:parent.width-48; height:40; wrapMode:Text.Wrap
                text:rhine.state.queueWriteLoading ? "正在收藏…" : ((rhine.state.navigationCreated || []).length ? (rhine.state.queueWriteStatus || "选择要收藏到的歌单") : "暂无歌单，或正在加载")
                color:"#77816d"; font.family:rhineFontFamily;font.variableAxes:({"wght":400}); font.pixelSize:13 }
        }
    }
    SideNavigation {
        id: sideNavigation
        anchors.fill: parent
        z: 300
        background: backgroundLayer
        unit: root.stageScale
    }
    WindowChrome {
        window: root
        centerControl:root.songDetailVisible
        topControlsWidth:globalTools.occupiedWidth
        enabled: root.windowsFrameless
        visible: root.windowsFrameless && root.visibility !== Window.FullScreen
        dark: root.songDetailVisible || rhine.state.dark === true
        z: 999
    }
    PerformancePanel {
        z: 1000
    }
}
