// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_effects.go effectsDialog/presetTiles/customEffects, Qt adaptation.
import QtQuick
import QtQuick.Controls.Basic as Controls

RhinePopup {
    id:panel
    required property var controller
    readonly property var fx:controller.info
    readonly property color ink:dark?"#eeeeee":"#292929"
    readonly property color muted:dark?"#aaaaaa":"#777777"
    readonly property color faint:dark?"#808080":"#999999"
    readonly property color card:dark?"#18ffffff":"#aaffffff"
    readonly property color accent:"#49abc5"
    property int page:0
    objectName:"soundEffectsDialog"
    visible:controller.opened
    onOpened:{page=fx.preset==="custom"?1:0;scroll.contentY=0}
    onClosed:controller.close()
    modal:true;dim:true;cornerRadius:26
    anchors.centerIn:parent
    width:Math.min(760,parent?parent.width-40:760)
    height:Math.min(parent?parent.height-56:770,body.implicitHeight+128)
    padding:0
    closePolicy:Controls.Popup.CloseOnEscape
    background:Item {
        Rectangle {anchors.fill:parent;radius:26;color:panel.dark?"#35383d":"#d7dcdf"}
        PopupGlass {anchors.fill:parent;popup:panel;radius:26;dark:panel.dark;frosting:1;tint:.62;opacity:.6}
    }
    contentItem:Item {
        Item {id:head;width:parent.width;height:68
            Text {x:28;anchors.verticalCenter:parent.verticalCenter;text:"音效";color:panel.ink;font.family:rhineFontFamily;font.pixelSize:20;font.weight:Font.DemiBold;font.variableAxes:({"wght":600})}
            Controls.AbstractButton {objectName:"soundEffectsClose";anchors.right:parent.right;anchors.rightMargin:25;anchors.verticalCenter:parent.verticalCenter;width:28;height:28;Accessible.name:"关闭音效面板";onClicked:panel.controller.close();contentItem:RhineIcon {name:"cloudyClose";color:panel.muted}}
        }
        Flickable {
            id:scroll;objectName:"soundEffectsScroll";x:28;y:head.height;width:parent.width-56;height:parent.height-head.height-foot.height
            contentWidth:width;contentHeight:body.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
            Controls.ScrollBar.vertical:Controls.ScrollBar {width:5}
            Column {
                id:body;width:scroll.width;spacing:0;bottomPadding:8
                Rectangle {width:parent.width;height:65;radius:20;color:panel.card
                    Column {x:20;anchors.verticalCenter:parent.verticalCenter;width:parent.width-92;spacing:5
                        Label {text:"开启音效";bold:true;size:14}
                        Label {width:parent.width;text:panel.fx.on?"当前："+panel.fx.label+"，对所有歌曲生效":"已关闭；选一个预设或手动调节就会打开";color:panel.muted;size:12;elide:Text.ElideRight}
                    }
                    Controls.AbstractButton {id:onSwitch;objectName:"soundEffectsOn";anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;width:36;height:24;Accessible.name:"开启音效";Accessible.checkable:true;Accessible.checked:panel.fx.on;onClicked:panel.controller.setValue("on",!panel.fx.on)
                        contentItem:Item {Rectangle {anchors.centerIn:parent;width:36;height:20;radius:10;color:panel.fx.on?panel.accent:"#b5b6bb"}Rectangle {x:panel.fx.on?18:2;y:4;width:16;height:16;radius:8;color:"white"}}
                    }
                }
                Item {width:parent.width;height:56
                    Rectangle {y:18;width:134;height:28;radius:14;color:panel.dark?"#20ffffff":"#14000000"
                        Rectangle {x:panel.page*66+2;y:2;width:64;height:24;radius:12;color:panel.dark?"#66686e":"white"}
                        Row {Repeater {model:["预设","自定义"];delegate:Controls.AbstractButton {required property int index;required property string modelData;objectName:"soundEffectsPage"+index;width:67;height:28;Accessible.name:modelData;onClicked:{panel.page=index;scroll.contentY=0}contentItem:Label {text:parent.modelData;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;size:13}}}}
                    }
                }
                Column {visible:panel.page===0;width:parent.width
                    Section {title:"智能调音";chosen:panel.fx.on&&["smart","mood"].indexOf(panel.fx.preset)>=0?panel.fx.label:"";note:"每首歌自动选择，切歌时平滑过渡"}
                    Grid {width:parent.width;columns:2;spacing:10
                        Tile {width:(parent.width-10)/2;entry:({id:"smart",label:"智能音效",desc:"按网易云的曲风自动匹配最合适的预设",color:"#6d6af0",icon:"cloudyWand"});selected:panel.fx.on&&panel.fx.preset==="smart";onClicked:panel.controller.usePreset("smart")}
                        Tile {width:(parent.width-10)/2;entry:({id:"mood",label:"情绪调音",desc:"读取歌曲的情绪标签和歌词，按情绪调音",color:"#e0559a",icon:"cloudyHeart"});selected:panel.fx.on&&panel.fx.preset==="mood";onClicked:panel.controller.usePreset("mood")}
                    }
                    Section {title:"空间音效";chosen:panel.fx.on?(panel.fx.spatial==="8d"?"8D 环绕":panel.fx.spatial==="360"?"360° 环绕":""):"";note:"戴耳机效果最好，可以和任意预设一起用"}
                    Grid {width:parent.width;columns:2;spacing:10
                        Tile {width:(parent.width-10)/2;entry:({id:"8d",label:"8D 环绕",desc:"声音绕着头部缓缓转圈",color:"#1aa3c2",icon:"cloudyFan"});selected:panel.fx.on&&panel.fx.spatial==="8d";onClicked:panel.controller.toggleSpatial("8d")}
                        Tile {width:(parent.width-10)/2;entry:({id:"360",label:"360° 环绕",desc:"像坐在两只音箱前，声音在头外",color:"#21a37a",icon:"cloudyGlobe"});selected:panel.fx.on&&panel.fx.spatial==="360";onClicked:panel.controller.toggleSpatial("360")}
                    }
                    Item {width:parent.width;height:panel.fx.on&&panel.fx.spatial==="8d"?75:0;visible:height>0
                        AdjustRow {y:10;width:parent.width;field:"orbit";title:"转速";note:"约 "+Math.round(16-12*Number(panel.fx.orbit))+" 秒转一圈";onAdjust:function(v){panel.controller.setValue("orbit",v)}}
                    }
                    Section {title:"风格预设";chosen:panel.fx.on&&["smart","mood","custom"].indexOf(panel.fx.preset)<0?panel.fx.label:""}
                    Grid {width:parent.width;columns:3;spacing:10
                        Repeater {model:panel.controller.presets;delegate:Tile {required property var modelData;width:(parent.width-20)/3;entry:modelData;selected:panel.fx.on&&panel.fx.preset===entry.id;onClicked:panel.controller.usePreset(entry.id)}}
                    }
                }
                Column {visible:panel.page===1;width:parent.width;opacity:panel.fx.on?1:.55
                    Section {title:"均衡器";note:"双击推子归零"}
                    Rectangle {width:parent.width;height:210;radius:20;color:panel.card
                        Canvas {id:curve;x:14;y:38;width:parent.width-28;height:138;property var bands:panel.fx.bands;onBandsChanged:requestPaint();onWidthChanged:requestPaint();onPaint:{var c=getContext("2d");c.clearRect(0,0,width,height);var pts=[];for(var i=0;i<10;i++)pts.push({x:width*(i+.5)/10,y:height*(1-(Number(bands[i])+12)/24)});c.strokeStyle=panel.dark?"#22ffffff":"#18000000";c.lineWidth=1;c.beginPath();c.moveTo(0,height/2);c.lineTo(width,height/2);c.stroke();c.beginPath();c.moveTo(pts[0].x,pts[0].y);for(i=0;i<9;i++){var a=pts[Math.max(0,i-1)],b=pts[i],d=pts[i+1],e=pts[Math.min(9,i+2)];c.bezierCurveTo(b.x+(d.x-a.x)/6,b.y+(d.y-a.y)/6,d.x-(e.x-b.x)/6,d.y-(e.y-b.y)/6,d.x,d.y)}c.strokeStyle=panel.accent;c.lineWidth=2.5;c.stroke();c.lineTo(pts[9].x,height/2);c.lineTo(pts[0].x,height/2);c.closePath();c.fillStyle="#1a49abc5";c.fill()}}
                        Row {x:14;y:16;width:parent.width-28
                            Repeater {model:["31","62","125","250","500","1k","2k","4k","8k","16k"];delegate:Column {required property int index;required property string modelData;width:parent.width/10;spacing:4
                                Label {width:parent.width;text:Number(panel.fx.bands[parent.index]).toFixed(1);size:10.5;color:panel.faint;horizontalAlignment:Text.AlignHCenter}
                                Controls.Slider {id:band;objectName:"soundEffectsBand"+parent.index;anchors.horizontalCenter:parent.horizontalCenter;width:28;height:150;orientation:Qt.Vertical;from:-12;to:12;stepSize:.5;value:Number(panel.fx.bands[parent.index]);Accessible.name:parent.modelData+"Hz";onMoved:panel.controller.setBand(parent.index,value)
                                    background:Rectangle {x:13;y:6;width:2;height:138;radius:1;color:panel.dark?"#22ffffff":"#18000000"}
                                    handle:Rectangle {x:8;y:6+band.visualPosition*138-6;width:12;height:12;radius:6;color:"white";border.width:2;border.color:panel.accent}
                                    TapHandler {acceptedButtons:Qt.LeftButton;gesturePolicy:TapHandler.WithinBounds;onDoubleTapped:panel.controller.setBand(band.parent.index,0)}
                                }
                                Label {width:parent.width;text:parent.modelData;size:11;color:panel.muted;horizontalAlignment:Text.AlignHCenter}
                            }}
                        }
                    }
                    Section {title:"增强"}
                    Column {width:parent.width;spacing:1
                        AdjustRow {width:parent.width;field:"bass";title:"低音";note:"向左减弱，向右加强";minimum:-1;onAdjust:function(v){panel.controller.setValue(field,v)}}
                        AdjustRow {width:parent.width;field:"treble";title:"高音";note:"向左减弱，向右加强";minimum:-1;onAdjust:function(v){panel.controller.setValue(field,v)}}
                        AdjustRow {width:parent.width;field:"depth";title:"环绕深度";note:"声音前后的层次";onAdjust:function(v){panel.controller.setValue(field,v)}}
                        AdjustRow {width:parent.width;field:"width";title:"环绕强度";note:"左右声场的宽度";onAdjust:function(v){panel.controller.setValue(field,v)}}
                        Rectangle {width:parent.width;height:65;radius:16;color:panel.card
                            Column {x:20;anchors.verticalCenter:parent.verticalCenter;spacing:4;Label {text:"重置增强";bold:true}Label {text:"低音、高音和环绕都回到 0";size:12;color:panel.muted}}
                            RhineButton {anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;text:"重置";dark:panel.dark;onClicked:panel.controller.resetEnhance()}
                        }
                    }
                    Section {title:"人声与响度"}
                    AdjustRow {width:parent.width;field:"vocal";title:"人声增强";note:"居中的人声更靠前、更清楚，伴奏不受影响";onAdjust:function(v){panel.controller.setValue(field,v)}}
                    Item {width:1;height:1}
                    AdjustRow {width:parent.width;field:"loudness";title:"响度均衡";note:"压低过响的段落、抬起轻柔的段落";onAdjust:function(v){panel.controller.setValue(field,v)}}
                    Section {title:"环境"}
                    Rectangle {width:parent.width;height:65;radius:20;color:panel.card
                        Column {x:20;anchors.verticalCenter:parent.verticalCenter;spacing:4;Label {text:"环境音效";bold:true}Label {text:"让声音像在不同的空间里播放";size:12;color:panel.muted}}
                        RhineComboBox {objectName:"soundEffectsRoom";anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;width:120;dark:panel.dark;model:panel.controller.rooms;textRole:"label";currentIndex:{for(var i=0;i<model.length;i++)if(model[i].id===panel.fx.room)return i;return 0}onActivated:function(i){panel.controller.setValue("room",model[i].id)}}
                    }
                }
            }
        }
        Item {id:foot;width:parent.width;height:60;anchors.bottom:parent.bottom
            FooterButton {objectName:"soundEffectsReset";x:28;anchors.verticalCenter:parent.verticalCenter;text:"恢复原声";glyph:"cloudyReload";onClicked:panel.controller.usePreset("flat")}
            Label {anchors.right:done.left;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter;text:"调整后约半秒内生效";color:panel.faint;size:11.5;visible:panel.width>570}
            FooterButton {id:done;objectName:"soundEffectsDone";anchors.right:parent.right;anchors.rightMargin:28;anchors.verticalCenter:parent.verticalCenter;text:"完成";glyph:"check";primary:true;onClicked:panel.controller.close()}
        }
    }
    component Label:Text {property real size:14;property bool bold:false;color:panel.ink;font.family:rhineFontFamily;font.pixelSize:size;font.weight:bold?Font.DemiBold:Font.Normal;font.variableAxes:({"wght":bold?600:400});textFormat:Text.PlainText}
    component FooterButton:Controls.AbstractButton {
        id:button;property string glyph;property bool primary:false;implicitWidth:label.implicitWidth+56;implicitHeight:32;hoverEnabled:true
        background:Rectangle {radius:16;color:button.primary?panel.accent:(panel.dark?"#15ffffff":"#0a000000");border.width:button.primary?0:.5;border.color:panel.dark?"#20ffffff":"#18000000";opacity:button.down?.8:1}
        contentItem:Item {RhineIcon {x:17;anchors.verticalCenter:parent.verticalCenter;width:13;height:13;name:button.glyph;color:button.primary?"white":panel.ink}Label {id:label;x:35;anchors.verticalCenter:parent.verticalCenter;text:button.text;bold:true;size:13;color:button.primary?"white":panel.ink}}
    }
    component Section:Item {property string title;property string note:"";property string chosen:"";width:parent.width;height:44
        Row {x:18;anchors.verticalCenter:parent.verticalCenter;spacing:6
            Label {text:parent.parent.title;size:12.5;bold:true;color:panel.muted}
            Label {visible:!!parent.parent.chosen;text:"· "+parent.parent.chosen;size:12.5;bold:true;color:panel.accent}
            Label {text:parent.parent.note;size:11.5;color:panel.faint;visible:panel.width>650}
        }
    }
    component Tile:Controls.AbstractButton {
        id:tile;required property var entry;readonly property color tint:entry.color;property bool selected:false;objectName:"soundEffectsPreset_"+entry.id;height:72;hoverEnabled:true;Accessible.name:entry.label
        background:Rectangle {radius:14;color:tile.hovered?(panel.dark?"#28ffffff":"#caffffff"):panel.card;border.width:tile.selected?1.5:.5;border.color:tile.selected?panel.accent:(panel.dark?"#18ffffff":"#18000000")}
        contentItem:Item {
            Rectangle {x:14;y:17;width:38;height:38;radius:8;color:Qt.rgba(tile.tint.r,tile.tint.g,tile.tint.b,.16);RhineIcon {anchors.centerIn:parent;width:20;height:20;name:tile.entry.icon;color:tile.entry.color}}
            Column {x:64;anchors.verticalCenter:parent.verticalCenter;width:parent.width-x-(tile.selected?34:14);spacing:3
                Label {width:parent.width;text:tile.entry.label;bold:true;elide:Text.ElideRight}
                Label {width:parent.width;text:tile.selected&&["smart","mood"].indexOf(tile.entry.id)>=0&&panel.fx.note?panel.fx.note:tile.entry.desc;color:panel.muted;size:11.5;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;lineHeight:1.35}
            }
            Rectangle {visible:tile.selected;anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter;width:18;height:18;radius:9;color:panel.accent;RhineIcon {anchors.centerIn:parent;width:11;height:11;name:"check";color:"white"}}
        }
    }
    component AdjustRow:Rectangle {
        id:row;property string title;property string note;property string field;property real minimum:0;signal adjust(real value);height:65;radius:16;color:panel.card
        Column {x:20;anchors.verticalCenter:parent.verticalCenter;width:parent.width-range.width-80;spacing:4;Label {width:parent.width;text:row.title;bold:true}Label {width:parent.width;text:row.note;color:panel.muted;size:11.5;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight}}
        Controls.Slider {id:range;objectName:"soundEffectsAdjust_"+row.field;anchors.right:amount.left;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter;width:Math.min(180,row.width*.27);height:22;from:row.minimum;to:1;stepSize:.01;value:Number(panel.fx[row.field]);Accessible.name:row.title;onMoved:row.adjust(value)
            background:Rectangle {x:0;y:9;width:range.width;height:4;radius:2;color:panel.dark?"#22ffffff":"#18000000";Rectangle {width:range.visualPosition*parent.width;height:4;radius:2;color:panel.accent}}
            handle:Rectangle {x:range.visualPosition*(range.width-12);y:5;width:12;height:12;radius:6;color:"white";border.width:1;border.color:"#22000000"}
            TapHandler {onDoubleTapped:row.adjust(0)}
        }
        Label {id:amount;anchors.right:parent.right;anchors.rightMargin:18;anchors.verticalCenter:parent.verticalCenter;width:30;size:11.5;color:panel.muted;text:Math.round(Number(panel.fx[row.field])*100)+"%";horizontalAlignment:Text.AlignRight}
    }
}
