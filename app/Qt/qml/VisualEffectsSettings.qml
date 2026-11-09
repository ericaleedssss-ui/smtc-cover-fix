// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_settings.go settingsEffectsPage, adapted to Qt Quick.
import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.ScrollView {
    id:page
    objectName:"visualEffectsSettings"
    property string query:""
    readonly property real bodyHeight:groupsColumn.height
    readonly property var filteredGroups:groups.map(function(group){
        var needle=query.trim().toLowerCase();
        var all=!needle||group.title.toLowerCase().indexOf(needle)>=0;
        return {title:group.title,rows:group.rows.filter(function(row){return all||(row.title+row.note).toLowerCase().indexOf(needle)>=0;})};
    }).filter(function(group){return group.rows.length>0;})
    readonly property var prefs:rhine.visualPreferences
    readonly property bool dark:rhine.state.dark===true
    readonly property color ink:dark?"#eeeeee":"#242424"
    readonly property color muted:dark?"#aaaaaa":"#777777"
    readonly property bool noMotion:prefs.motion==="off"||rhine.state.reduced
    contentWidth:availableWidth;clip:true
    readonly property var groups:[
        {title:"省电",rows:[{key:"powerSaver",title:"省电模式",note:"一键关闭液态玻璃、封面旋转、微光和烟雾；再关一次恢复原样"}]},
        {title:"播放栏",rows:[{key:"liquidGlass",title:"液态玻璃播放栏",note:"播放栏化作悬浮的玻璃胶囊，透出并折射其下的内容"},{key:"glassClear",title:"玻璃透明度",note:"越高越能看清背后的内容，文字会更难读",slider:true,parentKey:"liquidGlass"},{key:"glassBend",title:"折射强度",note:"胶囊边缘弯折背后内容的程度",slider:true,parentKey:"liquidGlass"},{key:"barSpin",title:"封面旋转",note:"播放时胶囊里的封面像黑胶一样缓慢转动"}]},
        {title:"播放页",rows:[{key:"npLight",title:"微光",note:"当前歌词、进度条与音量带一层柔和的微光"},{key:"glowLevel",title:"微光强度",note:"",slider:true,parentKey:"npLight"},{key:"fog",title:"烟雾背景",note:"背景化作封面色调的烟雾，随低音起伏"},{key:"smoke",title:"进度条烟雾",note:"进度条化作拖着烟雾的光点，随音乐起伏"}]},
        {title:"界面",rows:[{key:"glassPanels",title:"界面玻璃",note:"菜单、弹窗和设置使用玻璃材质；关闭后为纯色，显卡占用更低"},{key:"motion",title:"界面动画",note:"精简时只保留淡入淡出",segmented:true}]}
    ]
    Column {
        id:groupsColumn
        width:page.availableWidth;spacing:18
        Repeater {model:page.filteredGroups;delegate:Column {
            id:group;required property var modelData;width:parent.width;spacing:7
            Text {leftPadding:16;text:group.modelData.title;font.family:rhineFontFamily;font.pixelSize:13;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:page.muted}
            Rectangle {width:parent.width;height:groupRows.height;radius:20;color:page.dark?"#303030":"#fafafa";border.color:page.dark?"#414141":"#e4e4e6"
                Column {id:groupRows;width:parent.width
                    Repeater {model:group.modelData.rows;delegate:Item {
                        id:row;required property var modelData;required property int index
                        width:groupRows.width;height:Math.max(64,copy.implicitHeight+26)
                        readonly property bool subordinate:modelData.slider===true
                        readonly property bool available:!modelData.parentKey||page.prefs[modelData.parentKey]===true
                        opacity:available?1:.4
                        Rectangle {x:subordinate?30:20;y:0;width:parent.width-x-20;height:1;visible:row.index>0;color:page.dark?"#424242":"#e7e7e7"}
                        Rectangle {x:30;y:16;width:2;height:parent.height-32;visible:row.subordinate;color:page.dark?"#555555":"#e4e4e4"}
                        Column {id:copy;x:row.subordinate?48:20;anchors.verticalCenter:parent.verticalCenter;width:Math.max(70,parent.width-x-control.width-36);spacing:6
                            Text {width:parent.width;text:row.modelData.title;font.family:rhineFontFamily;font.pixelSize:14;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:page.ink;wrapMode:Text.Wrap}
                            Text {visible:!!text;width:parent.width;text:row.modelData.note||"";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12;color:page.muted;wrapMode:Text.Wrap;lineHeight:1.2}
                        }
                        Loader {id:control;anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;enabled:row.available
                            sourceComponent:row.modelData.slider?slider:row.modelData.segmented?modes:toggle
                            Component {id:toggle;Controls.AbstractButton {
                                id:button;objectName:"effect_"+row.modelData.key;width:36;height:24;hoverEnabled:true;Accessible.name:row.modelData.title;Accessible.role:Accessible.CheckBox;Accessible.checkable:true;Accessible.checked:page.prefs[row.modelData.key]===true
                                onClicked:rhine.setVisualPreference(row.modelData.key,!page.prefs[row.modelData.key])
                                background:Rectangle {y:2;width:36;height:20;radius:10;color:page.prefs[row.modelData.key]?RhineTheme.accent(page.dark):(page.dark?"#626269":"#bdbdc3");opacity:button.hovered?.85:1;border.width:button.visualFocus?1:0;border.color:page.ink
                                    Rectangle {x:page.prefs[row.modelData.key]?19:3;y:3;width:14;height:14;radius:7;color:"white";Behavior on x {NumberAnimation {duration:page.noMotion?0:160;easing.type:Easing.OutCubic}}}
                                }
                            }}
                            Component {id:slider;Row {spacing:12
                                Controls.Slider {id:range;objectName:"effect_"+row.modelData.key;width:150;height:24;from:0;to:1;stepSize:.01;value:Number(page.prefs[row.modelData.key]);onMoved:rhine.setVisualPreference(row.modelData.key,value)
                                    background:Rectangle {x:range.leftPadding;y:10;width:range.availableWidth;height:4;radius:2;color:page.dark?"#555555":"#dedee0";Rectangle {width:range.visualPosition*parent.width;height:4;radius:2;color:RhineTheme.accent(page.dark)}}
                                    handle:Rectangle {x:range.leftPadding+range.visualPosition*(range.availableWidth-width);y:4;width:16;height:16;radius:8;color:"white";border.color:"#dddddd"}
                                }
                                Text {width:36;height:24;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;text:Math.round(Number(page.prefs[row.modelData.key])*100)+"%";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12;color:page.muted}
                            }}
                            Component {id:modes;Rectangle {width:160;height:30;radius:15;color:page.dark?"#454545":"#eaeaed"
                                Row {anchors.fill:parent;anchors.margins:2;Repeater {model:[{key:"full",text:"完整"},{key:"lite",text:"精简"},{key:"off",text:"关闭"}];delegate:Controls.AbstractButton {
                                    id:mode;required property var modelData;width:52;height:26;hoverEnabled:true;onClicked:rhine.setVisualPreference("motion",modelData.key)
                                    background:Rectangle {radius:13;color:page.prefs.motion===mode.modelData.key?(page.dark?"#777777":"white"):mode.hovered?(page.dark?"#555555":"#dedee0"):"transparent"}
                                    contentItem:Text {text:mode.modelData.text;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12;color:page.ink;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
                                }}}
                            }}
                        }
                    }}
                }
            }
        }}
    }
}
