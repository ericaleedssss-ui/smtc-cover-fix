import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Controls.Basic as Controls

// Native folder geometry and animation, informed by MARGIN's hinged pocket interaction.
Item {
    id:folder
    required property var entry
    property var files:[]
    property bool loading:false
    property bool loaded:false
    property string error:""
    property real unit:1
    property bool dark:false
    property bool reduced:false
    property bool opened:false
    property bool materialActive:true
    property bool entranceActive:true
    property bool inViewport:true
    property int entranceDelay:0
    property bool entered:false
    property real entranceTime:0
    property bool cardsEntered:false
    property real cardsTime:0
    property int cardsDelay:0
    readonly property bool previewReady:files.length>0||loaded||error.length>0
    readonly property var previewRows:files.length?files.slice(0,4):previewReady?[entry]:[]
    readonly property bool assembled:entered&&entranceTime>=1450&&cardsEntered&&cardsTime>=1450
    property string fontFamily:""
    property color ink:dark?"#f0f0f3":"#292a32"
    property color muted:dark?"#b9bbc7":"#747583"
    readonly property bool hovering:pointer.hovered||activeFocus||menu.visible
    readonly property real k:width/340
    signal requested()
    signal selected(int index)
    signal viewAll()
    signal viewOriginal()
    height:350*k
    activeFocusOnTab:true
    // Pocket and song clocks run once; hover/open transforms remain independent.
    function progress(delay,duration){return reduced?1:Math.max(0,Math.min(1,(entranceTime-delay)/duration))}
    function easeOut(t){return 1-Math.pow(1-t,3)}
    function drop(t){var x=t-1;return 1+2.2*x*x*x+1.2*x*x}
    function revealCards(){
        if(!entered||!entranceActive||!inViewport||!previewReady||cardsEntered)return
        cardsEntered=true
        cardsDelay=Math.max(0,entranceDelay-entranceTime)
        if(reduced)cardsTime=1450
        else cardAssembly.restart()
    }
    function enter(){
        if(!entranceActive||!inViewport)return
        if(!entered){
            entered=true
            if(reduced)entranceTime=1450
            else assembly.restart()
        }
        if(!previewReady&&!loading)previewWarm.restart()
        revealCards()
    }
    function resetEntrance(){assembly.stop();cardAssembly.stop();previewWarm.stop();entered=false;cardsEntered=false;entranceTime=0;cardsTime=0;menu.close();opened=false}
    onEntranceActiveChanged:if(entranceActive)enter();else resetEntrance()
    onInViewportChanged:enter()
    onPreviewReadyChanged:revealCards()
    onReducedChanged:if(reduced&&entered){assembly.stop();entranceTime=1450;if(cardsEntered){cardAssembly.stop();cardsTime=1450}}
    Component.onCompleted:enter()
    SequentialAnimation {
        id:assembly
        PauseAnimation {duration:folder.entranceDelay}
        NumberAnimation {target:folder;property:"entranceTime";from:0;to:1450;duration:1450}
    }
    // The pocket can appear while loading; song layers always get their own full drop.
    SequentialAnimation {
        id:cardAssembly
        PauseAnimation {duration:folder.cardsDelay}
        NumberAnimation {target:folder;property:"cardsTime";from:0;to:1450;duration:1450}
    }
    function toggle(){opened=!opened;if(opened)requested()}
    function openOptions(){menu.open()}
    Keys.onReturnPressed:toggle()
    Keys.onSpacePressed:toggle()
    Keys.onEscapePressed:opened=false
    Accessible.role:Accessible.Button
    Accessible.name:entry.title+"，"+(opened?"收起":"打开文件夹")
    Accessible.onPressAction:toggle()
    HoverHandler {id:pointer}
    onHoveringChanged:if(hovering&&entranceActive&&inViewport&&!previewReady)previewWarm.restart()
    onVisibleChanged:if(!visible){menu.close();opened=false}
    Timer {id:previewWarm;interval:0;onTriggered:if(folder.entranceActive&&folder.inViewport&&!folder.previewReady)folder.requested()}
    Item {
        id:stage
        y:74*folder.k;width:340;height:266
        scale:folder.k;transformOrigin:Item.TopLeft
        property real px:folder.hovering&&!folder.reduced?(pointer.point.position.x/folder.width-.5)*3:0
        x:px
        Behavior on x {NumberAnimation{duration:folder.reduced?0:350;easing.type:Easing.OutCubic}}
        readonly property string backPath:"M 0 57 Q 0 36 21 36 L 145 36 C 169 36 174 3 199 3 L 317 3 Q 338 3 338 24 L 338 242 Q 338 264 316 264 L 22 264 Q 0 264 0 242 Z"
        readonly property string frontPath:"M 1 23 Q 1 2 23 2 L 116 2 C 143 2 146 31 173 31 L 316 31 Q 338 31 338 53 L 338 170 Q 338 192 316 192 L 23 192 Q 1 192 1 170 Z"
        Rectangle {x:24;y:238;width:292;height:35;radius:18;color:folder.dark?"#60000000":"#25222a42";opacity:folder.progress(0,900);layer.enabled:true;layer.effect:MultiEffect{blurEnabled:true;blurMax:32;blur:1;autoPaddingEnabled:true}}
        Item {
            id:contents;width:340;height:266
            Shape {
                anchors.fill:parent;opacity:folder.progress(0,900)
                transform:Translate{y:22*(1-folder.easeOut(folder.progress(0,1000)))}
                ShapePath {strokeWidth:1;strokeColor:folder.dark?"#718089a4":"#bcc2d0";fillGradient:LinearGradient{x1:0;y1:0;x2:280;y2:240;GradientStop{position:0;color:folder.dark?"#626b8e":"#8b97be"} GradientStop{position:.55;color:folder.dark?"#3c4666":"#b0b6ce"} GradientStop{position:1;color:folder.dark?"#20283e":"#e4e5ec"}} PathSvg{path:stage.backPath}}
            }
            Item {
              x:0;y:-100;width:340;height:364;clip:true
              Repeater {
                objectName:"musicFolderSheets"
                model:folder.previewRows
                Item {
                    id:sheet
                    objectName:"musicFolderSheet_"+index
                    required property var modelData
                    required property int index
                    readonly property int count:Math.min(4,folder.files.length||1)
                    readonly property int depth:count-1-index
                    readonly property real slot:index-(count-1)/2
                    readonly property real arrival:folder.reduced?1:Math.max(0,Math.min(1,(folder.cardsTime-180-depth*90)/900))
                    opacity:Math.min(1,arrival*3)
                    transform:Translate{y:-120*(1-folder.drop(sheet.arrival))}
                    x:38+slot*(folder.opened?15:folder.hovering?6:0)
                    y:198+(folder.opened?-84:folder.hovering?-27:36)-depth*(folder.opened?23:folder.hovering?12:13)-(sheetMouse.containsMouse?12:0)
                    width:264;height:174;rotation:slot*(folder.opened?4:folder.hovering?1.5:.6)
                    transformOrigin:Item.Bottom
                    Behavior on x {NumberAnimation{duration:folder.reduced?0:650;easing.type:Easing.OutCubic}}
                    Behavior on y {NumberAnimation{duration:folder.reduced?0:720;easing.type:Easing.OutBack;easing.overshoot:.65}}
                    Behavior on rotation {NumberAnimation{duration:folder.reduced?0:650;easing.type:Easing.OutCubic}}
                    Rectangle {anchors.fill:parent;radius:13;color:folder.dark?"#383c49":"#fafafa";border.width:1;border.color:folder.dark?"#738190":"#e2e4e9"}
                    Image {anchors.fill:parent;anchors.margins:4;source:rhine.personal.previewCover(String(sheet.modelData.cover||""));sourceSize:Qt.size(320,220);asynchronous:true;fillMode:Image.PreserveAspectCrop;layer.enabled:true;layer.effect:MultiEffect{maskEnabled:true;maskSource:sheetMask}}
                    Rectangle {id:sheetMask;anchors.fill:parent;anchors.margins:4;radius:10;visible:false;layer.enabled:true}
                    Rectangle {x:4;y:4;width:parent.width-8;height:40;radius:10;color:"#b0252833"}
                    Text {x:15;y:15;width:parent.width-30;text:sheet.modelData.title||"";elide:Text.ElideRight;color:"white";font.family:folder.fontFamily;font.pixelSize:16;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium})}
                    MouseArea {id:sheetMouse;anchors.fill:parent;enabled:folder.opened&&folder.files.length>0;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:folder.selected(sheet.index)}
                }
              }
            }
        }
        Item {
            id:front;objectName:"musicFolderFront";y:72+46*(1-folder.easeOut(folder.progress(420,1000)));width:340;height:194
            opacity:folder.progress(420,1000)
            transform:Scale {origin.x:170;origin.y:194;yScale:folder.opened?.86:folder.hovering?.95:1;Behavior on yScale{NumberAnimation{duration:folder.reduced?0:700;easing.type:Easing.OutBack;easing.overshoot:.6}}}
            Shape {id:pocketMask;visible:false;anchors.fill:parent;ShapePath{fillColor:"white";strokeColor:"transparent";PathSvg{path:stage.frontPath}}}
            Loader {
                anchors.fill:parent;active:folder.materialActive&&rhineRefractiveGlass
                sourceComponent:LiquidGlass {
                    background:contents;sampleX:0;sampleY:front.y
                    uiScale:1;radius:22;dark:folder.dark;refractive:true
                    refraction:.78;frosting:.30;tint:.09;rimStrength:.28;silhouette:pocketMask
                }
            }
            Shape {anchors.fill:parent;ShapePath{
                strokeWidth:1.2;strokeColor:folder.dark?"#90bcc6e2":"#eaffffff"
                fillGradient:LinearGradient{x1:0;y1:0;x2:75;y2:194
                    GradientStop{position:0;color:folder.dark?"#50404a64":"#406e799c"}
                    GradientStop{position:.4;color:folder.dark?"#b032394d":"#a0d6d9e4"}
                    GradientStop{position:1;color:folder.dark?"#f51f2432":"#f5f1f2f7"}}
                PathSvg{path:stage.frontPath}
            }}
            MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{folder.forceActiveFocus();folder.toggle()}}
            Column {x:23;y:110;width:235;spacing:5
                Text {width:parent.width;text:folder.entry.title||"";color:folder.ink;elide:Text.ElideRight;font.family:folder.fontFamily;font.pixelSize:21;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium})}
                Text {width:parent.width;text:folder.loading?"正在读取歌曲…":folder.error||String(folder.entry.trackCount||0)+" 首歌曲";color:folder.muted;elide:Text.ElideRight;font.family:folder.fontFamily;font.variableAxes:({"wght":400});font.pixelSize:16}
            }
        }
        Controls.Button {
            id:more;objectName:"musicFolderMore";x:267;y:195;width:54;height:54
            opacity:folder.progress(700,700)
            scale:(down?.94:1)*(.6+.4*folder.easeOut(folder.progress(700,700)))
            onClicked:folder.openOptions()
            contentItem:RhineIcon{name:"more";color:folder.ink}
            background:Rectangle{radius:13;color:more.hovered?(folder.dark?"#8a68718a":"#f5ffffff"):(folder.dark?"#80535970":"#b8f2f3f8");border.width:1;border.color:folder.dark?"#8290a2":"#d7dbe4"}
        }
    }
    RhineMenu {
        id:menu;objectName:"musicFolderMenu";popupType:Controls.Popup.Item
        x:Math.max(0,folder.width-width);y:folder.height-height-48*folder.k;width:205*folder.unit;padding:6*folder.unit
        unit:folder.unit;dark:folder.dark
        Controls.Action {text:folder.opened?"收起文件夹":"打开文件夹";onTriggered:folder.toggle()}
        Controls.Action {text:"查看全部歌曲";onTriggered:folder.viewAll()}
        Controls.Action {text:"在网易云打开";onTriggered:folder.viewOriginal()}
    }
}
