// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_settings.go panel and navigation, adapted to Qt Quick.
import QtQuick
import QtQuick.Controls.Basic as Controls

Item {
    id:root
    readonly property var state:rhine.state
    readonly property var prefs:state.preferences||({})
    readonly property var update:state.update||({})
    readonly property bool dark:state.dark===true
    readonly property color ink:dark?"#eeeeee":"#292929"
    readonly property color muted:dark?"#aaaaaa":"#777777"
    readonly property color hoverColor:dark?"#404040":"#eeeeee"
    property string category:state.settingsStartCategory||"account"
    property real revealProgress:1
    property var positions:({})
    readonly property var categories:[{id:"account",text:"账号",icon:"user",section:""},{id:"playback",text:"播放",icon:"play",section:"听歌"},{id:"lyrics",text:"歌词",icon:"comment",section:""},{id:"podcast",text:"播客",icon:"music",section:""},{id:"appearance",text:"外观",icon:"disc",section:"界面"},{id:"effects",text:"视觉效果",icon:"settings",section:""},{id:"storage",text:"下载与缓存",icon:"download",section:"系统"},{id:"window",text:"快捷键与窗口",icon:"batch",section:""},{id:"about",text:"关于",icon:"comment",section:""}]
    readonly property var entries:[
        {category:"account",group:"音乐平台",title:"当前平台",note:state.accountProviderName,action:"provider",value:"切换平台"},
        {category:"account",group:"音乐平台",title:state.accountUID?state.accountName:"尚未登录",note:state.accountMember||"",action:state.accountUID?"music:logout":"music:login",value:state.accountUID?"退出登录":"登录",hidden:state.localMusic},
        {category:"playback",group:"音频",title:"音质",note:prefs.quality||"standard",action:"quality",value:"选择音质",hidden:state.localMusic},
        {category:"playback",group:"音频",title:"替代音源",action:"alternative",toggle:true,on:prefs.alternative,hidden:state.accountProvider!=="netease"},
        {category:"playback",group:"声音",title:"输出设备",output:true},
        {category:"playback",group:"声音",title:"音效",note:"均衡器与预设音效，对所有歌曲生效",action:"sound:effects",value:rhine.soundEffects.info.menuNote},
        {category:"playback",group:"定时",title:"定时关闭",sleep:true},
        {category:"playback",group:"播放行为",title:"单曲播放时追加到队列",action:"single-play-mode",toggle:true,on:prefs.appendSingle},
        {category:"playback",group:"播放行为",title:"播放时显示官方播放器",action:"music:activate",toggle:true,on:prefs.officialWindow,hidden:state.localMusic},
        {category:"lyrics",group:"桌面歌词",title:"桌面歌词",action:"desktop:toggle",toggle:true,on:rhine.desktopLyrics.enabled},
        {category:"lyrics",group:"桌面歌词",title:"样式与字体",action:"desktop:settings",value:"配置与预览"},
        {category:"lyrics",group:"歌词",title:"显示翻译",toggle:true,on:(state.playerPreferences||{}).translation!==false,preference:"lyric-translation"},
        {category:"lyrics",group:"歌词",title:"歌词字号",lyricScale:true},
        {category:"podcast",group:"播放",title:"播客播放速度",speed:true},
        {category:"appearance",group:"界面",title:"主题",theme:true},
        {category:"appearance",group:"界面",title:"界面字体",note:rhine.uiFont,action:"interface:fonts",value:"选择与导入"},
        {category:"storage",group:"本地音乐",title:"文件夹管理",action:"discover",value:"打开",hidden:!state.localMusic},
        {category:"storage",group:"音乐来源",title:"本地音乐与在线平台",action:"provider",value:"管理来源"},
        {category:"window",group:"窗口",title:"全屏",action:"window:fullscreen",value:"切换"},
        {category:"window",group:"诊断",title:"帧数与性能面板",action:"performance:toggle",value:"显示 / 隐藏"},
        {category:"about",group:"Rhine Music Database",title:"当前版本",note:update.version,action:"music:project-home",value:"项目主页"},
        {category:"about",group:"软件更新",title:"启动时检查更新",action:"update:auto",toggle:true,on:prefs.autoUpdate},
        {category:"about",group:"软件更新",title:"更新状态",note:update.status,action:update.busy?"update:cancel":"update:check",value:update.busy?"取消":"检查更新"},
        {category:"about",group:"软件更新",title:"新版本",action:update.downloaded?"update:open":"update:download",value:update.downloaded?"打开下载目录":"下载",hidden:!update.available||update.busy},
        {category:"about",group:"软件更新",title:"发布说明",action:"update:release",value:"查看"},
        {category:"about",group:"开源项目",title:"网易云音乐 API",action:"music:project-author",value:"查看"},
        {category:"about",group:"开源项目",title:"QQ 音乐 API",action:"music:project-player",value:"查看"},
        {category:"about",group:"开源项目",title:"酷狗音乐 API",action:"music:project-kugou",value:"查看"},
        {category:"about",group:"开源项目",title:"RhineLabUI",action:"music:project-rhine",value:"查看"},
        {category:"about",group:"开源项目",title:"LyricsX",action:"music:project-lyricsx",value:"查看"},
        {category:"about",group:"开源项目",title:"LyricsKit",action:"music:project-lyricskit",value:"查看"},
        {category:"about",group:"开源项目",title:"Lyrimuse",action:"music:project-lyrimuse",value:"查看"}]
    readonly property var filtered:entries.filter(function(e){return !e.hidden&&(search.text.trim()?((e.title||"")+e.group+(e.note||"")).toLowerCase().indexOf(search.text.trim().toLowerCase())>=0:e.category===category);})
    function choose(id){positions[category]=scroll.contentY;category=id;search.clear();Qt.callLater(function(){scroll.contentY=positions[id]||0;});}
    component Command:RhineButton {
        id:command
        dark:root.dark
        font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13
    }
    Rectangle {anchors.fill:parent;color:Qt.rgba(0,0,0,.3*root.revealProgress);MouseArea {anchors.fill:parent;onClicked:rhine.action("back")}}
    Rectangle {
        id:panel;objectName:"settingsPage"
        width:Math.min(root.width-48,940);height:Math.max(320,root.height-72);anchors.centerIn:parent
        radius:26;color:RhineTheme.surface(root.dark)
        opacity:root.revealProgress
        scale:root.state.reduced||rhine.visualPreferences.motion!=="full"?1:.92+.08*root.revealProgress
        PopupGlass {anchors.fill:parent;popup:panel;radius:26;dark:root.dark;frosting:.85;tint:.86;refraction:0;rimStrength:0;opacity:.5}
        MouseArea {anchors.fill:parent;onPressed:panel.forceActiveFocus()}
        Text {x:32;y:24;text:"设置";color:root.ink;font.family:rhineFontFamily;font.pixelSize:20;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold})}
        Text {x:82;y:26;text:"/   "+(search.text.trim()?"搜索结果":(root.categories.filter(function(c){return c.id===root.category;})[0]||{}).text);color:root.muted;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:15}
        Controls.AbstractButton {objectName:"settingsClose";anchors.right:parent.right;anchors.rightMargin:18;y:17;width:34;height:34;hoverEnabled:true;Accessible.name:"关闭设置";onClicked:rhine.action("back")
            background:Rectangle {radius:5;color:parent.hovered?root.hoverColor:"transparent"}
                contentItem:Item {RhineIcon {name:"close";color:root.ink;anchors.centerIn:parent;width:18;height:18}}
            RhineToolTip {visible:parent.hovered;text:"关闭";delay:500}
        }
        Item {
            id:sidebar;x:22;y:70;width:174;height:panel.height-y-16
            Controls.TextField {id:search;objectName:"settingsSearch";width:parent.width;height:36;placeholderText:"搜索设置";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13;color:root.ink;selectByMouse:true;leftPadding:32;rightPadding:search.text?30:10
                background:Rectangle {radius:18;color:root.dark?"#333333":"#e0e0e2";border.width:1;border.color:search.activeFocus?root.muted:(root.dark?"#444444":"#d2d2d4");RhineIcon {x:10;anchors.verticalCenter:parent.verticalCenter;width:15;height:15;name:"search";color:root.muted}}
                Controls.AbstractButton {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:28;height:28;visible:!!search.text;Accessible.name:"清除搜索";onClicked:search.clear();contentItem:Item {RhineIcon {anchors.centerIn:parent;width:11;height:11;name:"close";color:root.muted}}}
                onTextChanged:scroll.contentY=0
            }
            Controls.ScrollView {y:50;width:parent.width;height:parent.height-y;clip:true;contentWidth:availableWidth
            Column {width:sidebar.width;spacing:3
                Repeater {model:root.categories;delegate:Column {
                    required property var modelData;width:sidebar.width;spacing:4
                    Text {visible:!!parent.modelData.section;height:visible?28:0;leftPadding:14;topPadding:8;text:parent.modelData.section;font.family:rhineFontFamily;font.pixelSize:12;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:root.muted}
                Controls.AbstractButton {
                    id:nav;objectName:"settingsCategory_"+modelData.id;property var modelData:parent.modelData;width:sidebar.width;height:40;hoverEnabled:true;Accessible.name:modelData.text
                    onClicked:root.choose(modelData.id)
                    background:Rectangle {radius:14;color:nav.hovered||nav.visualFocus||root.category===nav.modelData.id&&!search.text.trim()?root.hoverColor:"transparent";Behavior on color {ColorAnimation {duration:RhineTheme.noMotion?0:120}}
                        Rectangle {x:0;anchors.verticalCenter:parent.verticalCenter;width:3;height:14;radius:1.5;color:RhineTheme.accent(root.dark);visible:root.category===nav.modelData.id&&!search.text.trim()}
                    }
                    contentItem:Item {RhineIcon {x:14;anchors.verticalCenter:parent.verticalCenter;width:18;height:18;name:nav.modelData.icon;color:root.ink} Text {x:44;anchors.verticalCenter:parent.verticalCenter;text:nav.modelData.text;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14;color:root.ink}}
                }}}
            }}
        }
        Controls.ScrollView {
            id:view;x:226;y:70;width:panel.width-x-30;height:panel.height-y-30;clip:true
            visible:root.category!=="effects"||!!search.text.trim()
            contentWidth:availableWidth
            Flickable {id:scroll;contentWidth:width;contentHeight:rows.height;boundsBehavior:Flickable.StopAtBounds
                Column {id:rows;width:scroll.width;spacing:0
                    Repeater {model:root.filtered;delegate:Column {
                        id:setting;required property var modelData;required property int index;width:rows.width
                        readonly property bool heading:index===0||root.filtered[index-1].group!==modelData.group
                        Text {visible:setting.heading;width:parent.width;height:visible?40:0;leftPadding:16;topPadding:14;text:setting.modelData.group;font.family:rhineFontFamily;font.pixelSize:13;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:root.muted}
                        Item {width:parent.width;height:Math.max(64,label.implicitHeight+24)
                            Column {id:label;x:16;anchors.verticalCenter:parent.verticalCenter;width:parent.width-control.width-44;spacing:4
                                Text {width:parent.width;text:setting.modelData.title;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14;color:root.ink;wrapMode:Text.Wrap}
                                Text {visible:!!text;width:parent.width;text:setting.modelData.note||"";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13;color:root.muted;wrapMode:Text.Wrap}
                            }
                            Loader {id:control;anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter
                                sourceComponent:setting.modelData.toggle?toggle:setting.modelData.theme?themes:setting.modelData.output?outputSelect:setting.modelData.sleep?sleepSelect:setting.modelData.speed?speedSelect:setting.modelData.lyricScale?scaleSlider:command
                                Component {id:sleepSelect;RhineComboBox {objectName:"settingsSleep";width:150;model:[{value:0,label:"不定时"},{value:15,label:"15 分钟后"},{value:30,label:"30 分钟后"},{value:45,label:"45 分钟后"},{value:60,label:"60 分钟后"},{value:90,label:"90 分钟后"},{value:-1,label:"播完当前歌曲"}];textRole:"label";valueRole:"value";currentIndex:Math.max(0,model.findIndex(function(d){return d.value===rhine.sleepMinutes;}));onActivated:rhine.setSleep(currentValue)}}
                                Component {id:outputSelect;RhineComboBox {objectName:"settingsOutput";width:Math.min(220,view.width*.45);model:rhine.audioOutputs();textRole:"label";valueRole:"id";currentIndex:Math.max(0,model.findIndex(function(d){return d.id===(root.state.audioOutput||"");}));onPressedChanged:if(pressed)model=rhine.audioOutputs();onActivated:rhine.selectAudioOutput(currentValue)}}
                                Component {id:speedSelect;RhineComboBox {objectName:"settingsPodcastSpeed";width:110;model:[{value:.75,label:"0.75×"},{value:1,label:"1×"},{value:1.25,label:"1.25×"},{value:1.5,label:"1.5×"},{value:1.75,label:"1.75×"},{value:2,label:"2×"}];textRole:"label";valueRole:"value";currentIndex:Math.max(0,model.findIndex(function(d){return d.value===root.state.podcastSpeed;}));onActivated:rhine.setPlayerPreference("podcast-speed",String(currentValue))}}
                                Component {id:scaleSlider;Controls.Slider {width:140;from:.7;to:1.6;stepSize:.05;value:(root.state.playerPreferences||{}).lyricScale||1;onMoved:rhine.setPlayerPreference("lyric-scale",String(value))}}
                                Component {id:command;Command {text:setting.modelData.value||"打开";onClicked:rhine.action(setting.modelData.action)}}
                                Component {id:toggle;Controls.AbstractButton {
                                    id:switcher;objectName:"setting_"+setting.modelData.action;width:38;height:24;hoverEnabled:true;Accessible.name:setting.modelData.title;Accessible.role:Accessible.CheckBox;Accessible.checkable:true;Accessible.checked:setting.modelData.on===true
                                    onClicked:if(setting.modelData.preference)rhine.setPlayerPreference(setting.modelData.preference,setting.modelData.on?"off":"on");else rhine.action(setting.modelData.action)
                                    background:Rectangle {anchors.verticalCenter:parent.verticalCenter;width:38;height:22;radius:11;color:setting.modelData.on?(root.dark?"#9cb8aa":"#729e89"):(switcher.hovered?root.muted:(root.dark?"#555555":"#d4d4d4"));border.width:switcher.visualFocus?1:0;border.color:root.ink
                                        Rectangle {x:setting.modelData.on?19:3;y:3;width:16;height:16;radius:8;color:"white";Behavior on x {NumberAnimation {duration:RhineTheme.noMotion?0:160;easing.type:Easing.OutCubic}}}
                                    }
                                }}
                                Component {id:themes;Row {spacing:2;Repeater {model:[{key:"light",label:"浅色"},{key:"dark",label:"深色"},{key:"system",label:"系统"}];delegate:Command {required property var modelData;text:modelData.label;highlighted:root.prefs.theme===modelData.key;opacity:highlighted?1:.55;onClicked:rhine.action("theme:set:"+modelData.key)}}}}
                            }
                            Rectangle {anchors.bottom:parent.bottom;x:16;width:parent.width-32;height:1;color:root.dark?"#343434":"#e9e9e9"}
                        }
                    }}
                    Loader {
                        id:effectsSearch;width:parent.width
                        height:item?item.bodyHeight:0
                        active:!!search.text.trim()
                        sourceComponent:VisualEffectsSettings {query:search.text}
                    }
                    Text {visible:root.filtered.length===0&&(!effectsSearch.item||effectsSearch.item.filteredGroups.length===0);width:parent.width;padding:24;text:"没有匹配的设置";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14;color:root.muted}
                }
            }
        }
        Loader {x:view.x;y:view.y;width:view.width;height:view.height;active:root.category==="effects"&&!search.text.trim();sourceComponent:VisualEffectsSettings {}}
    }
}
