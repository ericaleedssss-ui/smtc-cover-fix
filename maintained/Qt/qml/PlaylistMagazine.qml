import QtQuick
import QtQuick.Window
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
    readonly property real heroHeight:Math.max(228,328*unit)
    readonly property real rowHeight:Math.max(58,65*unit)
    readonly property string session:controller.session
    property bool restoring:true
    property bool selecting:false
    property string activeRowMenu:""
    readonly property bool sticky:listing.contentY-listing.startY>heroHeight
    function toggleSubscription(){
        if(page.info.subscribed){unsubscribeDialog.collectionKey=page.session;unsubscribeDialog.open();}
        else page.controller.setSubscribed(page.session,true);
    }
    function openMore(button){var p=button.mapToItem(page,0,button.height+6*page.u);moreMenu.x=p.x;moreMenu.y=p.y;moreMenu.open();}
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
        textFormat:Text.PlainText;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter
    }
    component Action: Rectangle {
        property string label
        property string iconName:""
        property bool primary:false
        property bool compact:false
        signal invoked()
        width:compact?42*page.u:caption.implicitWidth+(iconName?55:34)*page.u;height:42*page.u;radius:compact?10*page.u:height/2
        color:primary?(actionMouse.containsMouse?"#69785b":"#7a866c"):(actionMouse.containsMouse?(page.dark?"#3c4c36":"#e1e7d6"):(page.dark?"#30372c":"#d9f0ede4"))
        opacity:enabled?1:.4
        border.width:primary?0:1;border.color:page.dark?"#3c6b785f":"#60ffffff"
        RhineIcon {visible:parent.iconName!=="";x:parent.compact?(parent.width-width)/2:16*page.u;anchors.verticalCenter:parent.verticalCenter;width:18*page.u;height:width;name:parent.iconName;color:parent.primary?"#f5f4e9":page.ink}
        Label {id:caption;x:(parent.iconName?42:17)*page.u;anchors.verticalCenter:parent.verticalCenter;visible:!parent.compact;text:parent.label;color:parent.primary?"#f5f4e9":page.ink;font.pixelSize:14*page.u}
        MouseArea {id:actionMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:parent.invoked()}
    }
    // One virtual list owns the hero and the tracks. No nested track scroller.
    ListView {
        id:listing
        readonly property real startY:originY
        onHeaderItemChanged:page.restore()
        objectName:"magazineTrackList"
        x:page.contentLeft;y:94*page.unit;width:parent.width-x-page.contentRight;height:Math.max(0,parent.height-y-84*page.unit)
        clip:true;reuseItems:true;cacheBuffer:page.rowHeight*4
        spacing:0
        // One capture for the virtual list; both edges fade in either scroll direction.
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
        layer.effect:ShaderEffect {
            objectName:"magazineEdgeFade"
            property variant source
            property size panelSize:Qt.size(listing.width,listing.height)
            property real topInset:stickyHeader.opacity*(stickyHeader.y+stickyHeader.height-listing.y)
            property real fadePx:32*page.u
            property real bottomFadePx:22*page.u
            property real fadeTop:listing.contentY-listing.startY>2*page.u?1:0
            fragmentShader:"qrc:/shaders/magazineEdgeFade.frag.qsb"
        }
        model:page.controller.tab==="songs"?page.controller:page.controller.socialRows
        boundsBehavior:Flickable.StopAtBounds
        onContentYChanged:if(!page.restoring)page.controller.savePosition(page.session,contentY-startY)
        onAtYEndChanged:if(atYEnd&&page.controller.tab==="songs"&&page.info.more&&!page.info.loading)page.controller.more()
        header:Item {
            visible:y+height>listing.contentY&&y<listing.contentY+listing.height
            width:listing.width;height:page.heroHeight+112*page.u+(page.selecting?52*page.u:0)
            Item {
                width:parent.width;height:page.heroHeight
                Item {id:records;x:20*page.unit;y:8*page.unit;width:Math.max(270*page.u,Math.min(360*page.unit,parent.width*.32));height:Math.max(204*page.u,Math.min(page.heroHeight-24*page.unit,290*page.unit))}
                Item {
                    id:details
                    x:records.x+records.width+30*page.unit;y:records.y+persistentRecords.frontY
                    width:Math.min(parent.width-x-12*page.unit,840*page.unit);height:persistentRecords.size
                    Column {
                        width:parent.width;height:actionRow.y-9*page.unit;spacing:7*page.unit;clip:true
                        Label {id:playlistTitle;objectName:"playlistTitle";width:parent.width;text:page.info.title||"正在读取歌单…";font.pixelSize:26*page.u;font.weight:Font.DemiBold;wrapMode:Text.Wrap;maximumLineCount:2;verticalAlignment:Text.AlignTop}
                        Item {width:1;height:5*page.unit}
                        Item {width:parent.width;height:Math.max(14*page.unit,Math.min(page.width>1150?42*page.unit:24*page.unit,details.height-actionRow.height-playlistTitle.implicitHeight-metaGroup.height-statistics.implicitHeight-38*page.unit))
                            Label {id:summary;objectName:"playlistDescriptionSummary";anchors.left:parent.left;anchors.top:parent.top;width:parent.width-22*page.unit;height:parent.height;text:page.info.description||"";wrapMode:Text.Wrap;maximumLineCount:page.width>1150?2:1;lineHeight:1.25;font.pixelSize:13*page.u;color:page.muted;verticalAlignment:Text.AlignTop}
                            RhineIcon {visible:summary.truncated;anchors.right:parent.right;anchors.top:parent.top;width:16*page.u;height:width;name:"more";color:page.muted}
                            MouseArea {objectName:"playlistDescriptionOpen";anchors.fill:parent;enabled:!!page.info.description;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:descriptionPopup.open();Controls.ToolTip.visible:containsMouse;Controls.ToolTip.delay:450;Controls.ToolTip.text:"查看完整简介"}
                        }
                        Row {id:metaGroup;width:parent.width;height:26*page.u;spacing:8*page.unit
                            Image {visible:!!page.info.creatorAvatar;width:24*page.u;height:width;source:page.info.creatorAvatar||"";asynchronous:true;sourceSize.width:64;sourceSize.height:64;fillMode:Image.PreserveAspectCrop}
                            Label {text:page.info.artist||"";width:Math.min(implicitWidth,130*page.u);height:parent.height;font.pixelSize:12*page.u
                                MouseArea {anchors.fill:parent;enabled:!!page.info.creatorID;cursorShape:Qt.PointingHandCursor;onClicked:rhine.action("profile:open:"+page.info.creatorID)}
                            }
                            Label {visible:(page.info.tags||[]).length>0;text:(page.info.tags||[]).slice(0,3).join(" / ");width:Math.min(implicitWidth,160*page.u);height:parent.height;font.pixelSize:12*page.u;color:page.muted}
                            Label {visible:!!page.info.createdDate;text:(page.info.createdDate||"")+" 创建";height:parent.height;font.pixelSize:12*page.u;color:page.muted}
                        }
                        Label {id:statistics;text:Number(page.info.total||0).toLocaleString()+" 首歌曲"+(page.info.subscribedCount!==undefined?"    收藏数 "+Number(page.info.subscribedCount).toLocaleString():"");color:page.muted;font.pixelSize:12*page.u}
                    }
                    Row {id:actionRow;objectName:"playlistActions";anchors.left:parent.left;anchors.bottom:parent.bottom;spacing:12*page.unit
                        Action {objectName:"magazinePlayAll";label:"播放全部";iconName:"play";primary:true;enabled:Number(page.info.total)>0;onInvoked:page.controller.bulk("play-all")}
                        Action {objectName:"magazineSubscribe";label:page.info.subscribed?"已收藏":"收藏";iconName:page.info.subscribed?"check":"collect";enabled:page.info.canSubscribe===true&&!page.info.likeBusy;onInvoked:page.toggleSubscription()}
                        Action {label:"下载";iconName:"download";enabled:page.info.canDownload===true&&!page.controller.downloading;onInvoked:page.controller.bulk("download-all")}
                        Action {id:heroMore;objectName:"magazineMore";label:"";iconName:"more";onInvoked:page.openMore(heroMore)}
                    }
                }

            }
            Item {
                y:page.heroHeight;width:parent.width;height:56*page.u
                Row {anchors.verticalCenter:parent.verticalCenter;spacing:25*page.unit
                    Repeater {model:[{key:"songs",label:"歌曲 "+(page.info.total||0)},{key:"comments",label:"评论"+(page.info.commentCount!==undefined?" "+page.info.commentCount:"")},{key:"collectors",label:"收藏者"+(page.info.collectorCount!==undefined?" "+Number(page.info.collectorCount).toLocaleString():"")}].filter(function(t){return t.key!=="collectors"||page.info.kind!=="album";})
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
                Label {x:parent.width-180*page.unit;width:32*page.u;horizontalAlignment:Text.AlignHCenter;text:"喜欢";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {x:parent.width-104*page.unit;text:"时长";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
            }
        }
        delegate:Loader {
            id:rowLoader
            objectName:"magazineRow_"+songIndex
            width:listing.width
            opacity:GraphicsInfo.api===GraphicsInfo.Software?Math.min(
                Math.max(0,Math.min(1,(y-listing.contentY-stickyHeader.opacity*(stickyHeader.y+stickyHeader.height-listing.y))/(32*page.u))),
                Math.max(0,Math.min(1,(listing.height-(y-listing.contentY))/(22*page.u)))):1
            height:item?item.implicitHeight:page.rowHeight
            // ListModel roles stay on this delegate; no per-frame JavaScript array rebuilding.
            property var song:page.controller.tab==="songs"?model.track:({})
            property int songIndex:page.controller.tab==="songs"?model.sourceIndex:-1
            property bool chosen:page.controller.tab==="songs"?model.chosen:false
            property bool heart:page.controller.tab==="songs"?model.heart===true:false
            property bool heartKnown:page.controller.tab==="songs"?model.heartKnown===true:true
            property var social:page.controller.tab!=="songs"?modelData:({})
            sourceComponent:Item {
                implicitHeight:page.controller.tab==="songs"?page.rowHeight:(page.controller.tab==="comments"?Math.max(102*page.u,socialText.implicitHeight+60*page.u):72*page.u)
                Rectangle {anchors.fill:parent;radius:7*page.unit;color:rowMouse.containsMouse||rowLoader.chosen?(page.dark?"#264f6344":"#207e9068"):"transparent"}
                Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:page.dark?"#1664765b":"#146b7b5c"}
                MouseArea {id:rowMouse;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton
                    onClicked:function(mouse){
                        if(page.controller.tab!=="songs"){if(rowLoader.social.id)rhine.action("profile:open:"+rowLoader.social.id);return;}
                        if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);
                        else if(page.selecting)page.controller.rowAction("select",rowLoader.song.identity);
                    }
                    onDoubleClicked:function(mouse){if(mouse.button===Qt.LeftButton&&page.controller.tab==="songs"&&!page.selecting)page.controller.rowAction("play",rowLoader.song.identity);}
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
                        MouseArea {objectName:"magazineTitleHit_"+rowLoader.songIndex;anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor;onClicked:function(mouse){if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);else if(page.selecting)page.controller.rowAction("select",rowLoader.song.identity);}onDoubleClicked:function(mouse){if(mouse.button===Qt.LeftButton&&!page.selecting)page.controller.rowAction("play",rowLoader.song.identity);}}
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
                    SongHeart {objectName:"magazineHeart_"+rowLoader.songIndex;x:parent.width-180*page.unit;anchors.verticalCenter:parent.verticalCenter;unit:page.u;liked:rowLoader.heart;known:rowLoader.heartKnown;pending:page.info.likeBusy===true||page.info.likesLoading===true;onToggled:if(rowLoader.heartKnown)page.controller.rowAction("like",rowLoader.song.identity);else page.controller.retryLikes()}
                    Label {x:parent.width-104*page.unit;width:52*page.unit;height:parent.height;text:rowLoader.song.durationLabel||"—";color:page.muted;font.pixelSize:12*page.u}
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
                Action {label:"重新读取喜欢状态";visible:!!page.info.likesError;onInvoked:page.controller.retryLikes()}
                Label {visible:page.controller.tab==="collectors"&&!!page.info.collectorError;text:page.info.collectorError||"";color:page.muted;font.pixelSize:12*page.u}
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
            width:Math.max(270*page.u,Math.min(360*page.unit,listing.width*.32));height:Math.max(204*page.u,Math.min(page.heroHeight-24*page.unit,290*page.unit))
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
                    PlaylistSearch {id:searchControl;anchors.right:parent.right;anchors.rightMargin:34*page.unit;anchors.verticalCenter:parent.verticalCenter;controller:page.controller;unit:page.u;dark:page.dark;onEditing:{page.restoring=true;listing.contentY=listing.startY;restoreTimer.restart();}}
                    RhineIcon {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:19*page.u;height:width;name:"filter";color:page.controller.filter==="all"?page.muted:page.accent
                        MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:filterMenu.popup()}
                    }
                }
    }
    // Sticky identity occupies its own masked band, above scrolling song text.
    Item {
        id:stickyHeader;objectName:"playlistStickyHeader"
        x:page.contentLeft;y:82*page.unit;width:listing.width;height:(page.selecting?164:108)*page.u;z:12
        opacity:Math.max(0,Math.min(1,(listing.contentY-listing.startY-page.heroHeight)/36))
        visible:opacity>0
        MouseArea {anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton;onWheel:function(wheel){wheel.accepted=false;}}
        Label {x:14*page.u;y:8*page.u;width:parent.width-28*page.u;height:34*page.u;text:page.info.title||"";font.pixelSize:20*page.u;font.weight:Font.DemiBold}
        Row {x:14*page.u;y:52*page.u;spacing:10*page.u
            Action {objectName:"stickyPlayAll";label:"播放";iconName:"play";compact:true;primary:true;enabled:Number(page.info.total)>0;onInvoked:page.controller.bulk("play-all")}
            Action {objectName:"stickySubscribe";label:page.info.subscribed?"已收藏":"收藏";iconName:page.info.subscribed?"check":"collect";compact:true;enabled:page.info.canSubscribe===true&&!page.info.likeBusy;onInvoked:page.toggleSubscription()
                Controls.ToolTip.visible:subscriptionHover.hovered;Controls.ToolTip.text:label
                HoverHandler {id:subscriptionHover}
            }
            Action {objectName:"stickyDownload";label:"下载全部";iconName:"download";compact:true;enabled:page.info.canDownload===true&&!page.controller.downloading;onInvoked:page.controller.bulk("download-all")}
            Action {id:stickyMore;objectName:"stickyMore";label:"更多";iconName:"more";compact:true;onInvoked:page.openMore(stickyMore)}
        }
        Row {x:14*page.u;y:108*page.u;spacing:8*page.u;visible:page.selecting
            Action {label:page.controller.selectedCount?"清空选择":"全选";onInvoked:page.controller.selectAll(page.controller.selectedCount===0)}
            Action {label:"加入队列";onInvoked:page.controller.bulk("append")}
            Action {label:"收藏歌曲";enabled:page.info.canCollect===true;onInvoked:page.controller.bulk("collect")}
            Action {label:"下载";enabled:page.info.canDownload===true;onInvoked:page.controller.bulk("download")}
            Action {label:"完成";onInvoked:{page.selecting=false;page.controller.selectAll(false);}}
        }
    }
    Controls.Dialog {
        id:unsubscribeDialog;objectName:"playlistUnsubscribeDialog"
        property string collectionKey:""
        parent:Controls.Overlay.overlay;anchors.centerIn:parent
        title:"取消收藏";modal:true;width:Math.min(380*page.u,page.width-40*page.u)
        standardButtons:Controls.Dialog.Ok|Controls.Dialog.Cancel
        contentItem:Label {text:page.info.kind==="album"?"确定取消收藏这张专辑吗？":"确定取消收藏这个歌单吗？";wrapMode:Text.Wrap;elide:Text.ElideNone;height:48*page.u}
        onAccepted:page.controller.setSubscribed(collectionKey,false)
    }
    function dismissTopOverlay(){if(descriptionPopup.visible){descriptionPopup.close();return true;}if(searchControl.expanded){searchControl.dismiss();return true;}return false;}
    MouseArea {
        anchors.fill:parent;z:40;visible:searchControl.expanded
        containmentMask:QtObject {function contains(position: point): bool {var p=searchControl.mapFromItem(page,position.x,position.y);return p.x<0||p.y<0||p.x>searchControl.width||p.y>searchControl.height;}}
        onPressed:function(mouse){mouse.accepted=false;Qt.callLater(searchControl.dismiss);}
    }

    Controls.Popup {
        id:descriptionPopup;objectName:"playlistDescriptionPopup"
        parent:Controls.Overlay.overlay;width:Math.min(580*page.u,page.width-40);height:Math.min(page.height-130*page.u,fullDescription.implicitHeight+84*page.u)
        x:Math.max(20,(page.width-width)/2);y:Math.max(60,Math.min(120*page.u,page.height-height-24))
        padding:20*page.u;modal:false;dim:false;closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        background:Rectangle {radius:12*page.u;color:page.dark?"#f02d3529":"#f5f4f1e8";border.width:1;border.color:page.dark?"#5a6b5948":"#b8ffffff"}
        contentItem:Item {
            Label {text:"歌单简介";font.weight:Font.DemiBold}
            RhineIcon {objectName:"playlistDescriptionClose";anchors.right:parent.right;width:18*page.u;height:width;name:"close";color:page.muted;MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:descriptionPopup.close()}}
            Flickable {x:0;y:34*page.u;width:parent.width;height:parent.height-y;contentHeight:fullDescription.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
                Text {id:fullDescription;width:parent.width;text:page.info.description||"";textFormat:Text.PlainText;wrapMode:Text.Wrap;lineHeight:1.45;color:page.ink;font.family:rhineFontFamily;font.pixelSize:14*page.u}
                Controls.ScrollBar.vertical:Controls.ScrollBar {}
            }
        }
    }
    component CollectionMenuItem:Controls.MenuItem {
        id:entry
        property string glyph:"more"
        implicitWidth:282*page.u;implicitHeight:46*page.u
        contentItem:Item {
            RhineIcon {x:8*page.u;anchors.verticalCenter:parent.verticalCenter;width:20*page.u;height:width;name:entry.glyph;color:page.muted}
            Label {x:42*page.u;width:parent.width-x;height:parent.height;text:entry.text;font.pixelSize:15*page.u}
        }
        background:Rectangle {radius:7*page.u;color:entry.highlighted?(page.dark?"#45553b":"#e2e8dc"):"transparent"}
    }
    Controls.Menu {
        id:moreMenu;parent:page;objectName:"playlistMoreMenu"
        padding:8*page.u
        background:Rectangle {implicitWidth:298*page.u;radius:12*page.u;color:page.dark?"#f52b3327":"#faf5f5ef";border.width:1;border.color:page.dark?"#516048":"#c8d3d7c9"}
        CollectionMenuItem {objectName:"collectionShare";text:"分享…";glyph:"share";onTriggered:page.controller.share()}
        CollectionMenuItem {objectName:"collectionBatch";text:"批量操作";glyph:"batch";onTriggered:{page.selecting=true;listing.contentY=listing.startY+page.heroHeight+100*page.u;}}
        CollectionMenuItem {objectName:"collectionAppend";text:"添加全部至播放队列";glyph:"next";enabled:!page.controller.busy;onTriggered:page.controller.bulk("append-all")}
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
