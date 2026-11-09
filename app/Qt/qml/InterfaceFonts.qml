import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Dialogs

Rectangle {
    id: panel
    property real unit: 1
    readonly property bool dark: rhine.state.dark === true
    readonly property color ink: dark ? "#e5e6e3" : "#30352f"
    readonly property var referenceFonts:[{label:"默认",family:rhine.uiFonts.indexOf("Noto Sans SC")>=0?"Noto Sans SC":"Microsoft YaHei UI"},{label:"微软雅黑",family:"Microsoft YaHei UI"},{label:"等线",family:"DengXian"},{label:"黑体",family:"SimHei"},{label:"思源宋体",family:"Noto Serif SC"},{label:"宋体",family:"SimSun"},{label:"霞鹜文楷",family:"LXGW WenKai"},{label:"楷体",family:"KaiTi"},{label:"仿宋",family:"FangSong"}].filter(function(f){return rhine.uiFonts.indexOf(f.family)>=0;})
    color:dark?"#252924":"#ffffff"
    radius:8*unit
    border.width:1;border.color:dark?"#454943":"#dedede"
    component Tool: Controls.AbstractButton {
        id: tool
        property string glyph
        property string caption: ""
        property string tip: caption
        width: caption ? label.implicitWidth+52*panel.unit : 34*panel.unit
        height:34*panel.unit;hoverEnabled:true;focusPolicy:Qt.StrongFocus
        background:Rectangle {radius:6*panel.unit;color:tool.down?(panel.dark?"#50554b":"#dddddd"):tool.hovered||tool.visualFocus?(panel.dark?"#41453e":"#eeeeee"):"transparent";border.width:tool.visualFocus?1:0;border.color:panel.dark?"#a5ae9b":"#7e8775"}
        contentItem:Item {
            RhineIcon {x:10*panel.unit;anchors.verticalCenter:parent.verticalCenter;width:16*panel.unit;height:width;name:tool.glyph;color:panel.ink}
            Text {id:label;x:34*panel.unit;anchors.verticalCenter:parent.verticalCenter;text:tool.caption;color:panel.ink;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14*panel.unit}
        }
        HoverHandler {cursorShape:Qt.PointingHandCursor}
        RhineToolTip {visible:parent.hovered;text:parent.tip;delay:500}
        Accessible.name:tip
    }
    Column {
        x:24*panel.unit;y:24*panel.unit;width:parent.width-48*panel.unit;spacing:16*panel.unit
        Row {width:parent.width;height:34*panel.unit;spacing:12*panel.unit
            Text {width:parent.width-46*panel.unit;height:parent.height;verticalAlignment:Text.AlignVCenter;text:"界面字体";color:panel.ink;font.family:rhineFontFamily;font.pixelSize:22*panel.unit;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold})}
            Tool {objectName:"interfaceFontBack";glyph:"back";tip:"返回";onClicked:rhine.action("back")}
        }
        Controls.TextField {id:filter;objectName:"interfaceFontSearch";width:parent.width;height:38*panel.unit;placeholderText:"搜索字体";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:15*panel.unit;selectByMouse:true;color:panel.ink;placeholderTextColor:panel.dark?"#a4ab9f":"#80877b";leftPadding:12*panel.unit
            background:Rectangle {radius:6*panel.unit;color:panel.dark?"#33392f":"#f0f0f0";border.width:filter.activeFocus?1:0;border.color:panel.dark?"#a5ae9b":"#7e8775"}
        }
        ListView {
            id:fontList;objectName:"interfaceFontList"
            width:parent.width;height:Math.max(46*panel.unit,panel.height-270*panel.unit);clip:true
            model:rhine.uiFonts.filter(function(name){return name.toLowerCase().indexOf(filter.text.toLowerCase())>=0;})
            delegate:Controls.ItemDelegate {
                required property string modelData
                width:fontList.width;height:46*panel.unit
                highlighted:rhine.uiFont===modelData
                contentItem:Text {text:(rhine.uiFont===modelData?"✓  ":"")+modelData;font.family:rhine.preparedFont(modelData);font.variableAxes:({"wght":400});font.pixelSize:16*panel.unit;color:panel.ink;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}
                background:Rectangle {radius:6*panel.unit;color:parent.highlighted||parent.hovered?(panel.dark?"#41453e":"#eeeeee"):"transparent"}
                onClicked:rhine.setUiFont(modelData)
            }
            Controls.ScrollBar.vertical:Controls.ScrollBar {}
        }
        RhineComboBox {objectName:"interfaceReferenceFont";width:parent.width;height:36*panel.unit;model:panel.referenceFonts;textRole:"label";valueRole:"family";displayText:"Cloudy · "+((panel.referenceFonts.filter(function(f){return f.family===rhine.uiFont;})[0]||{}).label||"字体");onActivated:rhine.setUiFont(currentValue)}
        Row {spacing:12*panel.unit
            Tool {objectName:"interfaceFontImport";glyph:"folder";caption:"导入本地字体";onClicked:fontFile.open()}
            Tool {glyph:"history";tip:"恢复默认字体";onClicked:rhine.resetUiFont()}
        }
        Text {width:parent.width;text:rhine.fontError;color:"#b64d51";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13*panel.unit;wrapMode:Text.Wrap}
    }
    FileDialog {id:fontFile;title:"导入字体";nameFilters:["字体文件 (*.ttf *.otf *.ttc)"];onAccepted:rhine.importUiFont(selectedFile)}
}
