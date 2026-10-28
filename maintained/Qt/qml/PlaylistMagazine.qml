import QtQuick
import QtQuick.Controls.Basic as Controls
Item {
    id:page
    objectName:"playlistMagazinePage"
    required property var controller
    required property Item background
    property real unit:1
    readonly property real u:Math.max(.9,unit)
    readonly property var info:controller.info
    readonly property bool dark:rhine.state.dark===true
    readonly property color ink:dark?"#e4e8db":"#30392e"
    readonly property color muted:dark?"#a3ad97":"#7e8775"
    readonly property color accent:dark?"#becbad":"#788567"
    readonly property real contentLeft:Math.max(84*unit,width*.072)
    readonly property real contentRight:34*unit
    readonly property real heroHeight:Math.max(312,352*unit)
    readonly property real rowHeight:Math.max(58,65*unit)
    readonly property string session:controller.session
    property bool restoring:true
    property bool selecting:false
    property string activeRowMenu:""
    readonly property bool sticky:listing.contentY-listing.startY>heroHeight
    function navigateKey(key) {
        if(controller.tab!=="songs" || rhine.state.queueOpen) return;
        var action=String(rhine.state.focusAction||"");
        if(action.indexOf("music:track:")===0){var row=controller.viewRow(Number(action.split(":")[2]));if(row>=0){listing.currentIndex=row;listing.positionViewAtIndex(row,ListView.Contain);}}
    }
    function restore() { restoring=true;restoreTimer.restart(); }
    onSessionChanged:{selecting=false;page.restore();}
    Timer {id:restoreTimer;interval:0;onTriggered:{listing.contentY=listing.startY+page.controller.scrollPosition;page.restoring=false;}}
    Component.onCompleted:page.restore()
    function menuFor(item,sourceIndex,identity,mouse) {
        var p=item.mapToItem(null,mouse.x,mouse.y);
        controller.showSongMenu("directory",sourceIndex,identity,p.x,p.y);
    }
    component Label: Text {
        color:page.ink;font.family:rhineFontFamily;font.pixelSize:15*page.u
        elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter
    }
    component Action: Rectangle {
        property string label
        property string iconName:""
        property bool primary:false
        signal invoked()
        width:caption.implicitWidth+(iconName?55:34)*page.u;height:42*page.u;radius:height/2
        color:primary?(actionMouse.containsMouse?"#69785b":"#7a866c"):(actionMouse.containsMouse?(page.dark?"#3c4c36":"#e1e7d6"):(page.dark?"#30372c":"#d9f0ede4"))
        opacity:enabled?1:.4
        border.width:primary?0:1;border.color:page.dark?"#3c6b785f":"#60ffffff"
        RhineIcon {visible:parent.iconName!=="";x:16*page.u;anchors.verticalCenter:parent.verticalCenter;width:18*page.u;height:width;name:parent.iconName;color:parent.primary?"#f5f4e9":page.ink}
        Label {id:caption;x:(parent.iconName?42:17)*page.u;anchors.verticalCenter:parent.verticalCenter;text:parent.label;color:parent.primary?"#f5f4e9":page.ink;font.pixelSize:14*page.u}
        MouseArea {id:actionMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:parent.invoked()}
    }
    // One virtual list owns the hero and the tracks. No nested track scroller.
    ListView {
        id:listing
        readonly property real startY:originY
        onHeaderItemChanged:page.restore()
        objectName:"magazineTrackList"
        x:page.contentLeft;y:94*page.unit;width:parent.width-x-page.contentRight;height:parent.height-y
        clip:true;reuseItems:true;cacheBuffer:page.rowHeight*4
        spacing:0
        model:page.controller.tab==="songs"?page.controller:page.controller.socialRows
        boundsBehavior:Flickable.StopAtBounds
        onContentYChanged:if(!page.restoring)page.controller.savePosition(page.session,contentY-startY)
        onAtYEndChanged:if(atYEnd&&page.controller.tab==="songs"&&page.info.more&&!page.info.loading)page.controller.more()
        header:Item {
            width:listing.width;height:page.heroHeight+112*page.u+(page.selecting?52*page.u:0)
            Item {
                width:parent.width;height:page.heroHeight
                Item {id:records;x:20*page.unit;y:8*page.unit;width:Math.min(330*page.unit,parent.width*.30);height:Math.min(page.heroHeight-25*page.unit,330*page.unit)}
                Column {
                    id:details
                    x:records.x+records.width+32*page.unit+((persistentRecords.expanded||persistentRecords.turning)?Math.min(190*page.unit,parent.width*.16):0);y:15*page.unit
                    Behavior on x {NumberAnimation {duration:rhine.state.reduced?0:180;easing.type:Easing.OutCubic}}
                    width:Math.min(parent.width-x-10*page.unit,800*page.unit);spacing:13*page.unit
                    Label {width:parent.width;text:page.info.title||"正在读取歌单…";font.pixelSize:30*page.u;font.weight:Font.DemiBold;wrapMode:Text.Wrap;maximumLineCount:2;verticalAlignment:Text.AlignTop}
                    Row {spacing:10*page.unit;visible:!!page.info.creatorAvatar || !!page.info.artist || !!page.info.createdDate
                        Image {visible:!!page.info.creatorAvatar;width:28*page.u;height:width;source:page.info.creatorAvatar||"";asynchronous:true;sourceSize.width:64;sourceSize.height:64;fillMode:Image.PreserveAspectCrop}
                        Label {text:page.info.artist||"";height:28*page.u;font.pixelSize:14*page.u
                            MouseArea {anchors.fill:parent;enabled:!!page.info.creatorID;cursorShape:Qt.PointingHandCursor;onClicked:rhine.action("profile:open:"+page.info.creatorID)}
                        }
                        Label {visible:!!page.info.createdDate;text:(page.info.createdDate||"")+" 创建";height:28*page.u;color:page.muted;font.pixelSize:14*page.u}
                    }
                    Label {text:Number(page.info.total||0).toLocaleString()+" 首歌曲"+(page.info.subscribedCount!==undefined?"     "+Number(page.info.subscribedCount).toLocaleString()+" 次收藏":"");color:page.muted;font.pixelSize:14*page.u}
                    Label {visible:!!page.info.description;width:parent.width;text:page.info.description||"";wrapMode:Text.Wrap;maximumLineCount:3;lineHeight:1.35;font.pixelSize:14*page.u;color:page.muted;verticalAlignment:Text.AlignTop}
                    Row {spacing:13*page.unit
                        Action {objectName:"magazinePlayAll";label:"播放全部";iconName:"play";primary:true;enabled:Number(page.info.total)>0;onInvoked:page.controller.bulk("play-all")}
                        Action {label:"下载";iconName:"download";enabled:page.info.canDownload===true;onInvoked:page.controller.bulk("download-all")}
                        Action {objectName:"magazineMore";label:"";iconName:"more";onInvoked:moreMenu.popup()}
                    }
                    Label {visible:page.info.loading===true;text:"正在读取歌单…";font.pixelSize:12*page.u;color:page.muted}
                }
            }
            Item {
                y:page.heroHeight;width:parent.width;height:56*page.u
                Row {anchors.verticalCenter:parent.verticalCenter;spacing:25*page.unit
                    Repeater {model:[{key:"songs",label:"歌曲 "+(page.info.total||0)},{key:"comments",label:"评论"+(page.info.commentCount!==undefined?" "+page.info.commentCount:"")},{key:"collectors",label:"收藏者"}]
                        delegate:Item {required property var modelData;width:tabLabel.implicitWidth;height:43*page.u
                            Label {id:tabLabel;anchors.verticalCenter:parent.verticalCenter;text:modelData.label;color:page.controller.tab===modelData.key?page.ink:page.muted;font.weight:page.controller.tab===modelData.key?Font.DemiBold:Font.Normal}
                            Rectangle {anchors.bottom:parent.bottom;width:28*page.unit;height:3*page.unit;radius:1;color:page.accent;visible:page.controller.tab===modelData.key}
                            MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{page.controller.setTab(modelData.key);page.restore();}}
                        }
                    }
                }

            }
            Row {x:6*page.unit;y:page.heroHeight+57*page.u;spacing:10*page.unit;visible:page.selecting
                Action {label:page.controller.selectedCount?page.controller.selectedCount+" 首已选 · 清空":"全选";onInvoked:page.controller.selectAll(page.controller.selectedCount===0)}
                Action {label:"加入队列";iconName:"next";onInvoked:page.controller.bulk("append")}
                Action {label:"收藏";iconName:"collect";enabled:page.info.canCollect===true;onInvoked:page.controller.bulk("collect")}
                Action {label:"下载";iconName:"download";enabled:page.info.canDownload===true;onInvoked:page.controller.bulk("download")}
                Action {label:"移除";iconName:"remove";visible:page.info.editable===true;onInvoked:page.controller.bulk("remove")}
                Action {label:"完成";onInvoked:{page.selecting=false;page.controller.selectAll(false);}}
            }
            Item {y:parent.height-48*page.u;width:parent.width;height:48*page.u;visible:page.controller.tab==="songs"
                Rectangle {width:parent.width;height:1;y:2;color:page.dark?"#306a7c60":"#1973805f"}
                Label {x:12*page.unit;text:page.selecting?"选择":"#";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {x:62*page.unit;text:"标题";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {x:parent.width*.42;text:"艺术家";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {x:parent.width*.65;text:"专辑";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {x:parent.width-164*page.unit;width:42*page.unit;horizontalAlignment:Text.AlignHCenter;text:"喜欢";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {x:parent.width-110*page.unit;text:"时长";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
            }
        }
        delegate:Loader {
            id:rowLoader
            objectName:"magazineRow_"+songIndex
            width:listing.width
            height:item?item.implicitHeight:page.rowHeight
            // ListModel roles stay on this delegate; no per-frame JavaScript array rebuilding.
            property var song:page.controller.tab==="songs"?model.track:({})
            property int songIndex:page.controller.tab==="songs"?model.sourceIndex:-1
            property bool chosen:page.controller.tab==="songs"?model.chosen:false
            property bool heart:page.controller.tab==="songs"?model.heart:false
            property var social:page.controller.tab!=="songs"?modelData:({})
            sourceComponent:Item {
                implicitHeight:page.controller.tab==="songs"?page.rowHeight:(page.controller.tab==="comments"?Math.max(102*page.u,socialText.implicitHeight+60*page.u):72*page.u)
                Rectangle {anchors.fill:parent;radius:7*page.unit;color:rowMouse.containsMouse||rowLoader.chosen?(page.dark?"#264f6344":"#207e9068"):"transparent"}
                Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:page.dark?"#1664765b":"#146b7b5c"}
                MouseArea {id:rowMouse;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton
                    onClicked:function(mouse){
                        if(page.controller.tab!=="songs"){if(rowLoader.social.id)rhine.action("profile:open:"+rowLoader.social.id);return;}
                        if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);
                        else page.controller.rowAction(page.selecting?"select":"detail",rowLoader.song.identity);
                    }
                }
                Item {anchors.fill:parent;visible:page.controller.tab==="songs"
                    Label {x:10*page.unit;width:35*page.unit;height:parent.height;text:page.selecting?(rowLoader.chosen?"✓":"○"):String(rowLoader.songIndex+1).padStart(2,"0");font.pixelSize:12*page.u;color:page.muted}
                    Rectangle {id:art;x:60*page.unit;anchors.verticalCenter:parent.verticalCenter;width:Math.max(40,44*page.unit);height:width;radius:3;color:page.dark?"#3a4433":"#dce1d1"
                        Image {anchors.fill:parent;source:rowLoader.song.cover||"";asynchronous:true;sourceSize.width:96;sourceSize.height:96;fillMode:Image.PreserveAspectCrop}
                        Rectangle {anchors.fill:parent;color:"#52000000";visible:coverMouse.containsMouse}
                        RhineIcon {anchors.centerIn:parent;width:18*page.u;height:width;name:"play";color:"#ffffff";visible:coverMouse.containsMouse}
                        MouseArea {id:coverMouse;objectName:"magazineCoverPlay_"+rowLoader.songIndex;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor
                            onClicked:function(mouse){if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);else page.controller.rowAction(page.selecting?"select":"play",rowLoader.song.identity);}}
                    }
                    Label {x:art.x+art.width+18*page.unit;width:parent.width*.42-x-22*page.unit;height:parent.height;text:rowLoader.song.title||"";font.pixelSize:17*page.u;font.weight:Font.Medium;color:rowLoader.song.unavailable?page.muted:page.ink
                        MouseArea {anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor;onClicked:function(mouse){if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);else page.controller.rowAction(page.selecting?"select":"detail",rowLoader.song.identity);}}
                    }
                    Item {id:artistArea;x:parent.width*.42;width:parent.width*.23-22*page.unit;height:parent.height;clip:true
                        Label {anchors.fill:parent;visible:!(rowLoader.song.artists||[]).length;text:rowLoader.song.artist||"";color:page.muted;font.pixelSize:14*page.u}
                        Row {height:parent.height
                            Repeater {model:rowLoader.song.artists||[]
                                delegate:Label {required property var modelData;required property int index
                                    width:Math.min(implicitWidth+6*page.unit,artistArea.width/Math.max(1,(rowLoader.song.artists||[]).length));height:artistArea.height
                                    text:(index?" / ":"")+(modelData.name||"");color:page.muted;font.pixelSize:14*page.u
                                    MouseArea {anchors.fill:parent;enabled:!!parent.modelData.id;cursorShape:Qt.PointingHandCursor;acceptedButtons:Qt.LeftButton|Qt.RightButton
                                        onClicked:function(mouse){if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);else page.controller.rowAction(page.selecting?"select":"artist:"+parent.index,rowLoader.song.identity);}}
                                }
                            }
                        }
                    }
                    Label {x:parent.width*.65;width:parent.width*.35-188*page.unit;height:parent.height;text:rowLoader.song.album||"";color:page.muted;font.pixelSize:14*page.u
                        MouseArea {anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor;enabled:!!rowLoader.song.albumID;onClicked:function(mouse){if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);else page.controller.rowAction(page.selecting?"select":"album",rowLoader.song.identity);}}
                    }
                    SongHeart {objectName:"magazineHeart_"+rowLoader.songIndex;x:parent.width-164*page.unit;anchors.verticalCenter:parent.verticalCenter;unit:page.u;liked:rowLoader.heart;pending:page.info.likeBusy===true;onToggled:page.controller.rowAction("like",rowLoader.song.identity)}
                    Label {x:parent.width-112*page.unit;width:64*page.unit;height:parent.height;text:rowLoader.song.durationLabel||"—";color:page.muted;font.pixelSize:12*page.u}
                    RhineIcon {x:parent.width-32*page.unit;anchors.verticalCenter:parent.verticalCenter;width:20*page.u;height:width;name:"more";color:page.muted
                        MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:function(mouse){page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);}}
                    }
                }
                Item {anchors.fill:parent;visible:page.controller.tab!=="songs"
                    Image {x:12*page.unit;y:14*page.unit;width:36*page.u;height:width;source:rowLoader.social.avatar||"";asynchronous:true;sourceSize.width:80;sourceSize.height:80;fillMode:Image.PreserveAspectCrop}
                    Label {x:65*page.unit;y:12*page.unit;width:parent.width-100*page.unit;height:25*page.u;text:rowLoader.social.name||"";font.weight:Font.Medium}
                    Label {id:socialText;x:65*page.unit;y:43*page.unit;width:parent.width-100*page.unit;text:rowLoader.social.content||"";wrapMode:Text.Wrap;elide:Text.ElideNone;color:page.muted;font.pixelSize:14*page.u}
                }
            }
        }
        footer:Item {
            width:listing.width;height:page.controller.downloading?170*page.u:112*page.u
            Column {anchors.horizontalCenter:parent.horizontalCenter;spacing:12*page.unit;y:18*page.unit
                Label {anchors.horizontalCenter:parent.horizontalCenter;objectName:"playlistResultStatus";text:page.info.loadError || page.controller.status || (page.controller.tab==="songs"&&page.controller.query&&page.info.visibleCount===0&&!page.info.loading&&!page.controller.busy?(page.info.searchComplete?"没有匹配的歌曲":"当前已载入曲目无匹配，可重试读取其余曲目"):page.info.loading?"正在载入曲目…":page.controller.tab==="songs"?"已载入 "+(page.info.loaded||0)+" / "+(page.info.total||0)+" 首":"");color:page.muted;font.pixelSize:12*page.u}
                Action {anchors.horizontalCenter:parent.horizontalCenter;visible:page.controller.downloading===true;label:"取消下载";onInvoked:page.controller.cancelDownload()}
                Action {anchors.horizontalCenter:parent.horizontalCenter;visible:page.controller.tab==="songs"?page.info.more===true:page.info.socialMore===true;label:page.info.loading||page.info.socialLoading?"正在读取…":"加载更多";enabled:!page.info.loading&&!page.info.socialLoading;onInvoked:page.controller.more()}
            }
        }
    }
    // Keep the active record animation alive when a new folder resets rows.
    Item {
        x:listing.x;y:listing.y;width:listing.width;height:listing.height;clip:true
        z:persistentRecords.expanded||persistentRecords.turning?8:2
        RecordStack {
            id:persistentRecords;objectName:"playlistRecordStack"
            x:20*page.unit;y:8*page.unit-(listing.contentY-listing.startY)
            width:Math.min(330*page.unit,listing.width*.30);height:Math.min(page.heroHeight-25*page.unit,330*page.unit)
            visible:y+height>0&&y<listing.height
            controller:page.controller;unit:page.unit;reduced:rhine.state.reduced===true;background:page.background
        }
    }
    // The editor lives outside the resetting ListView model. Filtering down to
    // zero rows must never destroy the focused TextInput or its edit buffer.
    Item {
        id:searchHost;x:page.contentLeft;y:listing.y+page.heroHeight-(listing.contentY-listing.startY)
        width:listing.width;height:56*page.u;z:3
        visible:page.controller.tab==="songs"&&y>=listing.y-1&&y<listing.y+listing.height
                Item {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:280*page.unit;height:38*page.u;visible:page.controller.tab==="songs"
                    PlaylistSearch {anchors.right:parent.right;anchors.rightMargin:34*page.unit;anchors.verticalCenter:parent.verticalCenter;controller:page.controller;unit:page.u;dark:page.dark;onEditing:{page.restoring=true;listing.contentY=listing.startY;restoreTimer.restart();}}
                    RhineIcon {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:19*page.u;height:width;name:"filter";color:page.controller.filter==="all"?page.muted:page.accent
                        MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:filterMenu.popup()}
                    }
                }
    }
    // The compact header floats over the scrolling hero; it never owns a second song list.
    Item {
        objectName:"playlistStickyHeader"
        x:page.contentLeft;y:88*page.unit;width:parent.width-x-page.contentRight;height:66*page.u
        visible:page.sticky;z:4
        MouseArea {anchors.fill:parent;onClicked:{}
            onWheel:function(event){listing.contentY=Math.max(0,Math.min(listing.contentHeight-listing.height,listing.contentY-(event.pixelDelta.y||event.angleDelta.y*page.unit*.6)));event.accepted=true;}}
        LiquidGlass {anchors.fill:parent;background:page.background;sampleX:parent.x;sampleY:parent.y;uiScale:page.u;radius:12*page.unit;dark:page.dark}
        Image {x:13*page.unit;y:10*page.unit;width:44*page.unit;height:width;source:page.info.cover||"";sourceSize.width:96;sourceSize.height:96;asynchronous:true}
        Label {x:72*page.unit;width:parent.width-280*page.unit;height:parent.height;text:page.info.title||"";font.pixelSize:18*page.u;font.weight:Font.DemiBold}
        Action {anchors.right:parent.right;anchors.rightMargin:16*page.unit;anchors.verticalCenter:parent.verticalCenter;label:"播放";iconName:"play";primary:true;onInvoked:page.controller.bulk("play-all")}
    }
    Controls.Menu {
        id:moreMenu
        font.family:rhineFontFamily;font.pixelSize:14*page.u
        palette.window:page.dark?"#2b3327":"#f2f0e7";palette.text:page.ink;palette.highlight:page.dark?"#45553b":"#dfe7d3";palette.highlightedText:page.ink
        Controls.MenuItem {text:"分享歌单";onTriggered:page.controller.share()}
        Controls.MenuItem {text:"批量操作";onTriggered:page.selecting=true}
        Controls.MenuItem {text:"添加全部至播放队列";enabled:!page.controller.busy;onTriggered:page.controller.bulk("append-all")}
    }
    Controls.Menu {
        id:filterMenu
        font.family:rhineFontFamily;font.pixelSize:14*page.u
        palette.window:page.dark?"#2b3327":"#f2f0e7";palette.text:page.ink;palette.highlight:page.dark?"#45553b":"#dfe7d3";palette.highlightedText:page.ink
        Controls.MenuItem {text:"全部歌曲";onTriggered:{page.controller.setFilter("all");page.restore();}}
        Controls.MenuItem {text:"已喜欢的歌曲";onTriggered:{page.controller.setFilter("liked");page.restore();}}
        Controls.MenuItem {text:"可播放歌曲";onTriggered:{page.controller.setFilter("available");page.restore();}}
    }
}
