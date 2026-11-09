import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Dialogs

Rectangle {
    id:page
    objectName:"desktopLyricsSettingsPage"
    required property var backend
    readonly property var settings:backend.desktopLyrics
    readonly property bool dark:rhine.state.dark===true
    readonly property color ink:dark?"#eeeeee":"#303030"
    readonly property color muted:dark?"#aaaaaa":"#777777"
    readonly property color hoverColor:dark?"#424242":"#eeeeee"
    property bool fontOpen:false
    property string colorTarget:""
    color:dark?"#252525":"#fafafa";radius:8;border.color:dark?"#4a4a4a":"#dddddd"
    focus:true
    function openColor(target){colorTarget=target;colorDialog.initialColor=settings[target+"Color"]||"#ffffff";colorDialog.open();}
    Keys.onEscapePressed:if(fontOpen)fontOpen=false;else backend.action("desktop:back")
    component Label:Text {font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14;color:page.ink;wrapMode:Text.Wrap}
    component Command:RhineButton {
        id:button;dark:page.dark;font.pixelSize:13
    }
    component Setting:Item {
        property string title
        property alias control:holder.data
        width:column.width;height:64
        Label {x:4;width:parent.width-holder.width-28;anchors.verticalCenter:parent.verticalCenter;text:parent.title}
        Row {id:holder;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:8}
        Rectangle {x:4;anchors.bottom:parent.bottom;width:parent.width-8;height:1;color:page.dark?"#383838":"#e7e7e7"}
    }
    MouseArea {anchors.fill:parent;onPressed:page.forceActiveFocus()}
    Row {x:24;y:18;spacing:12
        Controls.AbstractButton {width:34;height:34;hoverEnabled:true;Accessible.name:"返回设置";onClicked:page.backend.action("desktop:back")
            background:Rectangle {radius:5;color:parent.hovered?page.hoverColor:"transparent"}
            contentItem:Item {RhineIcon {anchors.centerIn:parent;width:18;height:18;name:"back";color:page.ink}}
        }
        Label {text:"桌面歌词";font.pixelSize:20;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});height:34;verticalAlignment:Text.AlignVCenter}
    }
    Controls.ScrollView {x:24;y:70;width:parent.width-48;height:parent.height-y-18;clip:true;contentWidth:availableWidth
        Column {id:column;width:parent.width;spacing:0
            Rectangle {
                objectName:"desktopSettingsPreview";width:parent.width;height:160;radius:12
                // Preview the configured lyric ink on a contrasting neutral surface.
                // The application theme must not make white desktop lyrics unreadable.
                readonly property color previewInk:page.settings.primaryColor||"white"
                color:(previewInk.r*.2126+previewInk.g*.7152+previewInk.b*.0722)>.55?"#373a3c":"#e4e5e7"
                Rectangle {anchors.centerIn:parent;width:parent.width-40;height:110;radius:8;visible:page.settings.style==="dark"||page.settings.style==="light";color:page.settings.backgroundColor||"#303030";opacity:Number(page.settings.backgroundOpacity||0)/100}
                Column {anchors.centerIn:parent;width:parent.width-64;spacing:10
                    Text {width:parent.width;text:page.settings.primary||"夜が明けるまで、ここにいて";elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter;font.family:page.settings.font==="MiSans"?"Rhine MiSans":page.settings.font;font.pixelSize:page.settings.size||32;font.weight:Font.ExtraBold;font.variableAxes:({"wght":Font.ExtraBold});color:page.settings.primaryColor||"white";style:["outline","color"].indexOf(page.settings.style)>=0?Text.Outline:Text.Normal;styleColor:"#b0000000"}
                    Text {width:parent.width;text:page.settings.secondary||"在天亮之前，请留在这里";elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:18;color:page.settings.secondaryColor||"#cccccc"}
                }
            }
            Setting {title:"桌面歌词";control:Command {text:page.settings.enabled?"关闭":"开启";onClicked:page.backend.action("desktop:toggle")}}
            Setting {title:"锁定位置";control:Command {text:page.settings.locked?"解除锁定":"锁定";onClicked:page.backend.action("desktop:lock")}}
            Setting {title:"样式";control:RhineComboBox {width:170;textRole:"label";valueRole:"key";model:[{key:"dark",label:"深色胶囊"},{key:"light",label:"浅色胶囊"},{key:"outline",label:"白色描边"},{key:"color",label:"彩色描边"},{key:"plain",label:"纯文字"}];currentIndex:model.findIndex(function(s){return s.key===page.settings.style;});onActivated:page.backend.setPlayerPreference("desktop-lyrics-style",currentValue)}}
            Setting {title:"字体";control:Command {text:(page.settings.font||"MiSans")+" ▾";onClicked:page.fontOpen=!page.fontOpen}}
            Setting {title:"字号";control:Row {spacing:10;Command {text:"−";onClicked:page.backend.action("desktop:smaller")} Label {text:page.settings.size||32;height:36;verticalAlignment:Text.AlignVCenter}Command {text:"+";onClicked:page.backend.action("desktop:larger")}}}
            Repeater {model:[{key:"primary",label:"原文颜色"},{key:"secondary",label:"译文颜色"},{key:"background",label:"背景颜色"}];delegate:Setting {required property var modelData;title:modelData.label;control:Controls.AbstractButton {width:34;height:30;onClicked:page.openColor(modelData.key);background:Rectangle {radius:4;color:page.settings[modelData.key+"Color"]||"#cccccc";border.color:page.muted} Accessible.name:modelData.label}}}
            Setting {title:"背景不透明度";control:Controls.Slider {width:170;from:0;to:100;stepSize:1;value:page.settings.backgroundOpacity;onMoved:page.backend.setDesktopOpacity(value)}}
            Setting {title:"配色方案";control:Row {spacing:8;Repeater {model:[{key:"oat",color:"#d1d5b5"},{key:"rose",color:"#e8c3c6"},{key:"sage",color:"#bfd3c8"}];delegate:Controls.AbstractButton {required property var modelData;width:28;height:28;onClicked:page.backend.applyDesktopPreset(modelData.key);background:Rectangle {radius:4;color:parent.modelData.color;border.color:page.muted}}}}}
            Setting {title:"文字明暗";control:Row {spacing:6;Command {objectName:"desktopSettingsDarkTone";text:"深色";onClicked:page.backend.setDesktopTone("dark")}Command {objectName:"desktopSettingsLightTone";text:"浅色";onClicked:page.backend.setDesktopTone("light")}}}
            Setting {title:"恢复默认";control:Command {text:"重置";onClicked:page.backend.action("desktop:reset")}}
        }
    }
    RhinePopup {
        id:fonts;objectName:"desktopSettingsFontMenu";parent:Controls.Overlay.overlay;anchors.centerIn:parent;width:Math.min(440,page.width-40);height:Math.min(400,page.height-40);padding:12;modal:true;dim:false;visible:page.fontOpen;onClosed:page.fontOpen=false
        contentItem:Column {spacing:8
            Controls.TextField {id:fontSearch;width:parent.width;height:36;placeholderText:"搜索字体";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14;selectByMouse:true}
            ListView {id:fontList;width:parent.width;height:fonts.height-72;clip:true;model:page.fontOpen?page.backend.desktopFonts().filter(function(f){return f.toLowerCase().indexOf(fontSearch.text.toLowerCase())>=0;}):[]
                delegate:Controls.ItemDelegate {required property string modelData;width:fontList.width;height:40;contentItem:Text {text:modelData;font.family:modelData==="MiSans"?"Rhine MiSans":page.backend.preparedFont(modelData);font.variableAxes:({"wght":400});font.pixelSize:14;color:page.ink;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}background:Rectangle {radius:4;color:parent.hovered?page.hoverColor:"transparent"}onClicked:{page.backend.setDesktopFont(modelData);page.fontOpen=false;}}
            }
        }
    }
    RhineColorPicker {id:colorDialog;title:"歌词颜色";onApplied:function(value){page.backend.setDesktopColor(page.colorTarget,value.toString());}onClosed:page.colorTarget=""}
}
