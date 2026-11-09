// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_album.go / ui_playlist.go, adapted to the native collection model.
import QtQuick
import QtQuick.Effects
import QtQuick.Window
import QtQuick.Controls.Basic as Controls
Item {
    id:page
    objectName:"playlistMagazinePage"
    required property var controller
    required property Item background
    property Item glassBackground:background
    property real unit:1
    readonly property real u:Math.max(.9,unit)
    readonly property var info:controller.info
    readonly property bool dark:rhine.state.dark===true
    readonly property color ink:RhineTheme.ink(dark)
    readonly property color muted:RhineTheme.muted(dark)
    readonly property color accent:RhineTheme.accent(dark)
    readonly property real contentLeft:Math.max(84*unit,width*.072)
    readonly property real contentRight:34*unit
    readonly property real heroHeight:Math.max(228,260*u)
    readonly property real rowHeight:52*u
    readonly property string session:controller.session
    property bool restoring:true
    property bool selecting:false
    property string activeRowMenu:""
    readonly property bool reduced:rhine.state.reduced===true||rhine.visualPreferences.motion!=="full"
    readonly property color playingInk:dark?"#c6d6ae":"#526b3e"
    property Item hoveredRow:null
    readonly property bool contextOpen:controller.songMenu.visible===true&&controller.songMenu.scope==="directory"
    property string locatedKey:""
    readonly property real playingY:listing.headerItem?listing.headerItem.y+listing.headerItem.height+controller.playingRow*rowHeight:0
    Rectangle {anchors.fill:parent;color:RhineTheme.surface(page.dark)}
    Item {
        anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;height:Math.min(parent.height,620*page.u);clip:true
        opacity:(page.dark?.6:.42)*(1-.6*Math.min(1,Math.max(0,(listing.contentY-listing.startY)/300)))
        Image {id:coverAura;anchors.fill:parent;source:rhineCollectionBaseline?(page.info.cover||""):rhine.personal.sizedCover(page.info.cover||"",600);sourceSize:Qt.size(600,600);asynchronous:true;fillMode:Image.PreserveAspectCrop;visible:false}
        // Alpha varies only vertically. MultiEffect samples normalized UVs,
        // so one column preserves the mask without a full-page mask texture.
        Item {id:auraMask;width:rhineCollectionBaseline?parent.width:1;height:parent.height;visible:false;layer.enabled:true;Rectangle {anchors.fill:parent;gradient:Gradient {GradientStop {position:0;color:"white"}GradientStop {position:1;color:"transparent"}}}}
        MultiEffect {anchors.fill:parent;source:coverAura;blurEnabled:true;blurMax:64;blur:1;maskEnabled:true;maskSource:auraMask;maskThresholdMin:.5;maskSpreadAtMin:1}
    }
    readonly property bool playingInView:controller.playingRow>=0&&playingY>=listing.contentY+(stickyHeader.visible?stickyHeader.y+stickyHeader.height-listing.y:0)&&playingY+rowHeight<=listing.contentY+listing.height
    function hoverRow(row) {
        if(contextOpen&&row.song.identity!==controller.songMenu.identity)return;
        if(controller.tab!=="songs")return;
        hoveredRow=row;
        hoverGlass.follow(row.y+4*unit,listing.moving);
    }
    function clearHover(force) {if(contextOpen&&!force)return;hoveredRow=null;hoverGlass.dismiss();}
    function locateCurrentSong() {
        if(controller.tab!=="songs"||controller.playingRow<0||!listing.headerItem)return;
        clearHover();listing.cancelFlick();locateScroll.stop();
        const band=stickyHeader.height;
        const top=listing.headerItem.y;
        const bottom=Math.max(top,top+listing.contentHeight-listing.height);
        const destination=Math.max(top,Math.min(bottom,playingY-(listing.height+band-rowHeight)/2));
        if(reduced){listing.contentY=destination;locatedKey=controller.playingKey;locateFlash.restart();}
        else {locateScroll.to=destination;locateScroll.start();}
    }
    Timer {id:locateFlash;interval:1100;onTriggered:page.locatedKey=""}
    NumberAnimation {id:locateScroll;target:listing;property:"contentY";duration:360;easing.type:Easing.InOutCubic;onFinished:{page.locatedKey=page.controller.playingKey;locateFlash.restart();}}
    Timer {id:scrollReveal;interval:1100}
    Connections {target:page.controller
        function onModelAboutToBeReset(){page.clearHover(true);locateScroll.stop();}
        function onPlaybackChanged(){page.locatedKey="";locateScroll.stop();}
        function onMenuChanged(){
            if(page.contextOpen){
                for(var i=0;i<listing.count;++i){var row=listing.itemAtIndex(i);if(row&&row.song.identity===page.controller.songMenu.identity){page.hoverRow(row);break;}}
            }else page.clearHover(true);
        }
    }
    readonly property bool sticky:listing.contentY-listing.startY>heroHeight
    // Headers and delegates share the same responsive columns.
    function titleX(){return 74*page.unit+Math.max(40,42*page.unit);}
    function artistX(w){return w*.44;}
    function artistWidth(w){return w*.23-20*page.unit;}
    function secondaryX(w){return w*.67;}
    function secondaryWidth(w){return Math.max(24*page.unit,w-secondaryX(w)-188*page.u);}
    function secondaryCenter(w){return secondaryX(w)+secondaryWidth(w)/2;}
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
    onSessionChanged:{selecting=false;page.clearHover();locateScroll.stop();page.restore();}
    Timer {id:restoreTimer;interval:0;onTriggered:{listing.contentY=listing.startY+page.controller.scrollPosition;page.restoring=false;}}
    Component.onCompleted:page.restore()
    function menuFor(item,sourceIndex,identity,mouse) {
        var p=item.mapToItem(null,mouse.x,mouse.y);
        controller.showSongMenu("directory",sourceIndex,identity,p.x,p.y);
    }
    component Label: Text {
        color:page.ink;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:15*page.u
        textFormat:Text.PlainText;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter
    }
    component CollectionHeader:Item {
        Rectangle {
            id:collectionCover;objectName:"collectionHeaderCover"
            x:12*page.u;y:8*page.u;width:212*page.u;height:width;radius:14*page.u;color:page.dark?"#12ffffff":"#09000000"
            layer.enabled:true;layer.effect:MultiEffect {shadowEnabled:true;shadowColor:"#55000000";shadowBlur:.7;shadowVerticalOffset:18*page.u}
            ProfileArtwork {anchors.fill:parent;url:page.info.cover||"";sourceSize:Qt.size(600,600);layer.enabled:true;layer.effect:MultiEffect {maskEnabled:true;maskSource:collectionMask;maskThresholdMin:.5;maskSpreadAtMin:1}}
        }
        Item {id:collectionMask;width:collectionCover.width;height:collectionCover.height;visible:false;layer.enabled:true;Rectangle {anchors.fill:parent;radius:14*page.u;color:"white"}}
        Column {
            x:collectionCover.x+collectionCover.width+28*page.u;y:collectionCover.y+Math.max(0,collectionCover.height-implicitHeight)
            width:parent.width-x-12*page.u;spacing:8*page.u
            Label {text:page.info.kind==="album"?"专辑":"歌单";font.pixelSize:12*page.u;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:page.accent}
            Label {objectName:"playlistTitle";width:parent.width;text:page.info.title||"正在读取…";font.pixelSize:30*page.u;font.weight:Font.ExtraBold;font.variableAxes:({"wght":Font.ExtraBold});font.letterSpacing:-.6*page.u;wrapMode:Text.Wrap;maximumLineCount:2;lineHeight:1.2}
            Row {width:parent.width;spacing:8*page.u;height:22*page.u
                ProfileArtwork {visible:!!page.info.creatorAvatar;url:page.info.creatorAvatar||"";width:20*page.u;height:width;sourceSize:Qt.size(48,48)}
                ArtistMarquee {visible:page.info.kind==="album";unit:page.u;height:parent.height;width:Math.min(implicitWidth,parent.width*.55);people:page.info.artists||[];fallback:page.info.artist||"";onPersonClicked:id=>{var people=page.info.artists||[];for(var i=0;i<people.length;++i)if(String(people[i].id)===String(id)){rhine.action("music:artist:"+i);break;}}}
                Label {visible:page.info.kind!=="album";text:page.info.artist||"";height:parent.height;font.pixelSize:13*page.u;color:page.muted
                    MouseArea {anchors.fill:parent;enabled:!!page.info.creatorID;cursorShape:Qt.PointingHandCursor;onClicked:rhine.action("profile:open:"+page.info.creatorID)}
                }
                Label {height:parent.height;text:page.info.kind==="album"?(page.info.date||""):(page.info.createdDate||"");font.pixelSize:12.5*page.u;color:page.muted}
            }
            Label {id:summary;objectName:"playlistDescriptionSummary";width:parent.width;text:page.info.description||"";visible:!!text;font.pixelSize:12.5*page.u;color:page.muted;wrapMode:Text.Wrap;maximumLineCount:2;lineHeight:1.45
                MouseArea {objectName:"playlistDescriptionOpen";anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:descriptionPopup.open()}
            }
            Row {objectName:"playlistActions";spacing:10*page.u
                Action {objectName:"magazinePlayAll";label:"播放全部";iconName:"play";primary:true;enabled:Number(page.info.total)>0;onInvoked:page.controller.bulk("play-all")}
                Action {objectName:"magazineSubscribe";label:page.info.subscribed?"已收藏":"收藏";iconName:page.info.subscribed?"check":"collect";enabled:page.info.canSubscribe===true&&!page.info.likeBusy;onInvoked:page.toggleSubscription()}
                Action {label:"下载";iconName:"download";enabled:page.info.canDownload===true&&!page.controller.downloading;onInvoked:page.controller.bulk("download-all")}
                Action {id:heroMore;objectName:"magazineMore";label:"更多";compact:true;iconName:"more";onInvoked:page.openMore(heroMore)}
            }
        }
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
        x:page.contentLeft;y:94*page.unit;width:parent.width-x-page.contentRight;height:Math.max(0,parent.height-y-28*page.unit)
        clip:true;reuseItems:true;cacheBuffer:page.rowHeight*4
        spacing:0
        // Keep the top fade; the lower edge stays opaque beneath the player glass.
        // With both fades off the shader is exactly an identity pass. Render
        // the list directly until scrolling actually needs the top mask.
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software&&(rhineCollectionBaseline||contentY-startY>2*page.u)
        layer.effect:ShaderEffect {
            objectName:"magazineEdgeFade"
            property variant source
            property size panelSize:Qt.size(listing.width,listing.height)
            property real topInset:stickyHeader.opacity*(stickyHeader.y+stickyHeader.height-listing.y)
            property real fadePx:32*page.u
            property real bottomFadePx:0
            property real fadeTop:listing.contentY-listing.startY>2*page.u?1:0
            fragmentShader:"qrc:/shaders/magazineEdgeFade.frag.qsb"
        }
        model:page.controller.tab==="songs"?page.controller:page.controller.socialRows
        boundsBehavior:Flickable.StopAtBounds
        onContentYChanged:{
            if(!page.restoring){page.controller.savePosition(page.session,contentY-startY);scrollReveal.restart();}
            page.clearHover();
        }
        onMovementStarted:locateScroll.stop()
        PlaylistHoverGlass {
            id:hoverGlass;objectName:"magazineHoverGlass";parent:listing.contentItem;z:-1
            width:listing.width;height:Math.max(1,page.rowHeight-8*page.unit)
            unit:page.unit;dark:page.dark;reduced:page.reduced
            background:page.glassBackground;refractive:rhineRefractiveGlass
            sampleOrigin:page.mapToItem(page.glassBackground,listing.x,listing.y-listing.contentY)
        }
        Controls.ScrollBar.vertical:Controls.ScrollBar {
            id:trackScroll;objectName:"magazineScrollBar"
            parent:page;x:listing.x+listing.width+8*page.unit;y:listing.y;height:listing.height;z:15
            width:18*page.u;padding:5*page.u;minimumSize:.05
            policy:Controls.ScrollBar.AlwaysOn;hoverEnabled:true
            readonly property bool revealed:size<1&&(scrollReveal.running||listing.moving||hovered||pressed||edgeHover.hovered)
            opacity:revealed?1:0
            Behavior on opacity {NumberAnimation {duration:page.reduced?0:180}}
            contentItem:Rectangle {implicitWidth:6*page.u;radius:width/2;color:page.dark?"#90bfccad":"#88758364"}
            background:Item {}
        }
        onAtYEndChanged:if(atYEnd&&page.controller.tab==="songs"&&page.info.more&&!page.info.loading)page.controller.more()
        header:Item {
            visible:y+height>listing.contentY&&y<listing.contentY+listing.height
            width:listing.width;height:page.heroHeight+168*page.u+(page.selecting?52*page.u:0)
            CollectionHeader {width:parent.width;height:page.heroHeight}
            Item {
                y:page.heroHeight;width:parent.width;height:56*page.u
                Row {anchors.verticalCenter:parent.verticalCenter;spacing:25*page.unit
                    Repeater {model:[{key:"songs",label:"歌曲 "+(page.info.total||0)},{key:"comments",label:"评论"+(page.info.commentCount!==undefined?" "+page.info.commentCount:"")},{key:page.info.kind==="album"?"intro":"collectors",label:page.info.kind==="album"?"专辑详情":"收藏者"+(page.info.collectorCount!==undefined?" "+Number(page.info.collectorCount).toLocaleString():"")}].filter(function(t){return t.key!=="collectors"||page.info.kind!=="album";})
                        delegate:Item {required property var modelData;width:tabLabel.implicitWidth;height:43*page.u
                            Label {id:tabLabel;anchors.verticalCenter:parent.verticalCenter;text:modelData.label;color:page.controller.tab===modelData.key?page.ink:page.muted;font.weight:page.controller.tab===modelData.key?Font.DemiBold:Font.Normal;font.variableAxes:({"wght":page.controller.tab===modelData.key?Font.DemiBold:Font.Normal})}
                            Rectangle {anchors.bottom:parent.bottom;width:28*page.unit;height:3*page.unit;radius:1;color:page.accent;visible:page.controller.tab===modelData.key}
                            MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{if(modelData.key==="intro")descriptionPopup.open();else{page.controller.setTab(modelData.key);page.restore();}}}
                        }
                    }
                }

            }
            Row {x:6*page.unit;y:page.heroHeight+113*page.u;spacing:10*page.unit;visible:page.selecting
                Action {label:page.controller.selectedCount?page.controller.selectedCount+" 首已选 · 清空":"全选";onInvoked:page.controller.selectAll(page.controller.selectedCount===0)}
                Action {label:"加入队列";iconName:"next";onInvoked:page.controller.bulk("append")}
                Action {label:"收藏";iconName:"collect";enabled:page.info.canCollect===true;onInvoked:page.controller.bulk("collect")}
                Action {label:"下载";iconName:"download";enabled:page.info.canDownload===true;onInvoked:page.controller.bulk("download")}
                Action {label:"移除";iconName:"remove";visible:page.info.editable===true;onInvoked:page.controller.bulk("remove")}
                Action {label:"完成";onInvoked:{page.selecting=false;page.controller.selectAll(false);}}
            }
            Item {y:parent.height-48*page.u;width:parent.width;height:48*page.u;visible:page.controller.tab==="songs"
                Rectangle {width:parent.width;height:1;y:2;color:page.dark?"#306a7c60":"#1973805f"}
                Label {objectName:"magazineHeaderIndex";x:10*page.unit;width:35*page.unit;horizontalAlignment:Text.AlignHCenter;text:page.selecting?"选择":"#";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {objectName:"magazineHeaderTitle";x:page.titleX();width:page.artistX(parent.width)-x-20*page.unit;horizontalAlignment:Text.AlignLeft;text:"标题";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {objectName:"magazineHeaderArtist";x:page.artistX(parent.width);width:page.artistWidth(parent.width);horizontalAlignment:Text.AlignLeft;text:"艺术家";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {objectName:"magazineHeaderSecondary";width:page.secondaryWidth(parent.width);x:page.secondaryCenter(parent.width)-width/2;horizontalAlignment:page.info.kind==="album"?Text.AlignHCenter:Text.AlignLeft;text:page.info.kind==="album"?"热度":"专辑";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {objectName:"magazineHeaderHeart";x:parent.width-148*page.u;width:32*page.u;horizontalAlignment:Text.AlignHCenter;text:"喜欢";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
                Label {objectName:"magazineHeaderDuration";x:parent.width-96*page.u;width:60*page.u;horizontalAlignment:Text.AlignHCenter;text:"时长";height:parent.height;color:page.muted;font.pixelSize:12*page.u}
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
            property var song:page.controller.tab==="songs"?(model.track||{}):({})
            property int songIndex:page.controller.tab==="songs"&&model.sourceIndex!==undefined?model.sourceIndex:-1
            property bool chosen:page.controller.tab==="songs"&&model.chosen===true
            property bool heart:page.controller.tab==="songs"?model.heart===true:false
            property bool heartKnown:page.controller.tab==="songs"?model.heartKnown===true:true
            property var social:page.controller.tab!=="songs"?modelData:({})
            readonly property bool isCurrent:page.controller.tab==="songs"&&song.identity===page.controller.playingKey
            readonly property bool isHovered:page.hoveredRow===rowLoader
            ListView.onPooled:if(page.hoveredRow===rowLoader)page.clearHover(true)
            ListView.onReused:if(page.hoveredRow===rowLoader)page.clearHover(true)
            Component.onDestruction:if(page.hoveredRow===rowLoader)page.clearHover(true)
            sourceComponent:Item {
                implicitHeight:page.controller.tab==="songs"?page.rowHeight:(page.controller.tab==="comments"?Math.max(102*page.u,socialText.implicitHeight+60*page.u):72*page.u)
                HoverHandler {id:rowHover
                    onHoveredChanged:{if(hovered)page.hoverRow(rowLoader);else Qt.callLater(function(){if(!rowHover.hovered&&page.hoveredRow===rowLoader)page.clearHover();});}
                    onPointChanged:if(hovered&&page.hoveredRow!==rowLoader)page.hoverRow(rowLoader)
                }
                Rectangle {anchors.fill:parent;anchors.margins:2*page.unit;radius:8*page.unit
                    color:rowLoader.chosen?(page.dark?"#264f6344":"#207e9068"):rowLoader.isCurrent?(page.locatedKey===rowLoader.song.identity?(page.dark?"#486c8053":"#307d935e"):(page.dark?"#205f734b":"#14748a59")):"transparent"
                    Behavior on color {ColorAnimation {duration:page.reduced?0:240}}
                }
                Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:page.dark?"#1664765b":"#146b7b5c"}
                MouseArea {id:rowMouse;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton
                    onClicked:function(mouse){
                        if(page.controller.tab!=="songs"){if(rowLoader.social.id)rhine.action("profile:open:"+rowLoader.social.id);return;}
                        if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);
                        else if(page.selecting)page.controller.rowAction("select",rowLoader.song.identity);
                    }
                    onDoubleClicked:function(mouse){if(mouse.button===Qt.LeftButton&&page.controller.tab==="songs"&&!page.selecting)page.controller.rowAction("play",rowLoader.song.identity);}
                }
                Item {id:songContent;anchors.fill:parent;visible:page.controller.tab==="songs"
                    property real lift:rowLoader.isHovered&&!page.reduced?1.018:1
                    Behavior on lift {NumberAnimation {duration:320;easing.type:Easing.OutBack;easing.overshoot:.55}}
                    // Scale each cell around its own origin; column widths and row hit boxes stay fixed.
                    Component.onCompleted: {
                        for(let i=0;i<children.length;++i)children[i].scale=Qt.binding(function(){return songContent.lift;});
                    }
                    Label {objectName:"magazineIndex_"+rowLoader.songIndex;visible:page.selecting||(!rowLoader.isCurrent&&!rowLoader.isHovered);x:10*page.unit;width:35*page.unit;horizontalAlignment:Text.AlignHCenter;height:parent.height;text:page.selecting?(rowLoader.chosen?"✓":"○"):String(rowLoader.songIndex+1).padStart(2,"0");font.pixelSize:12*page.u;color:page.muted}
                    Item {objectName:"magazineHoverPlay_"+rowLoader.songIndex;x:10*page.unit;width:35*page.unit;height:parent.height
                        visible:rowLoader.isHovered&&!rowLoader.isCurrent&&!page.selecting
                        RhineIcon {anchors.centerIn:parent;width:14*page.u;height:width;name:"play";color:page.ink}
                        MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;acceptedButtons:Qt.LeftButton|Qt.RightButton
                            onClicked:function(mouse){if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);else page.controller.rowAction("play",rowLoader.song.identity);}
                        }
                        Accessible.role:Accessible.Button;Accessible.name:"播放 "+(rowLoader.song.title||"");Accessible.onPressAction:page.controller.rowAction("play",rowLoader.song.identity)
                    }
                    Item {objectName:"magazinePlaying_"+rowLoader.songIndex;x:10*page.unit;width:35*page.unit;height:parent.height;visible:rowLoader.isCurrent&&!page.selecting
                        PlayingBars {anchors.centerIn:parent;unit:page.u;color:page.playingInk;live:page.controller.playbackActive;motionAllowed:!page.reduced&&rowLoader.y>=listing.contentY&&rowLoader.y<listing.contentY+listing.height&&RhineTheme.fullMotion}
                    }
                    Rectangle {id:art;x:60*page.unit;anchors.verticalCenter:parent.verticalCenter;width:Math.max(40,42*page.unit);height:width;radius:3;color:page.dark?"#3a4433":"#dce1d1"
                        Image {objectName:"magazineRowArtwork";anchors.fill:parent;source:rhineCollectionBaseline?(rowLoader.song.cover||""):rhine.personal.sizedCover(rowLoader.song.cover||"",96);asynchronous:true;sourceSize.width:96;sourceSize.height:96;fillMode:Image.PreserveAspectCrop}
                        Rectangle {anchors.fill:parent;color:"#52000000";visible:coverMouse.containsMouse}
                        RhineIcon {anchors.centerIn:parent;width:18*page.u;height:width;name:"play";color:"#ffffff";visible:coverMouse.containsMouse}
                        MouseArea {id:coverMouse;objectName:"magazineCoverPlay_"+rowLoader.songIndex;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor
                            onClicked:function(mouse){if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);else page.controller.rowAction(page.selecting?"select":"play",rowLoader.song.identity);}}
                    }
                    Label {objectName:"magazineTitle_"+rowLoader.songIndex;transformOrigin:Item.Left;horizontalAlignment:Text.AlignLeft;x:page.titleX();width:page.artistX(parent.width)-x-20*page.unit;height:parent.height;text:rowLoader.song.title||"";font.pixelSize:15*page.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium});color:rowLoader.isCurrent?page.playingInk:rowLoader.song.unavailable?page.muted:page.ink
                        MouseArea {objectName:"magazineTitleHit_"+rowLoader.songIndex;anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor;onClicked:function(mouse){if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);else if(page.selecting)page.controller.rowAction("select",rowLoader.song.identity);}onDoubleClicked:function(mouse){if(mouse.button===Qt.LeftButton&&!page.selecting)page.controller.rowAction("play",rowLoader.song.identity);}}
                    }
                    Item {id:artistArea;objectName:"magazineArtist_"+rowLoader.songIndex;x:page.artistX(parent.width);width:page.artistWidth(parent.width);height:parent.height;clip:true
                        transformOrigin:Item.Left
                        Label {anchors.fill:parent;horizontalAlignment:Text.AlignLeft;visible:!(rowLoader.song.artists||[]).length;text:rowLoader.song.artist||"";color:rowLoader.isCurrent?page.playingInk:page.muted;font.pixelSize:14*page.u}
                        Row {anchors.left:parent.left;height:parent.height
                            Repeater {model:rowLoader.song.artists||[]
                                delegate:Label {required property var modelData;required property int index
                                    width:Math.min(implicitWidth+6*page.unit,artistArea.width/Math.max(1,(rowLoader.song.artists||[]).length));height:artistArea.height
                                    horizontalAlignment:Text.AlignLeft;text:(index?" / ":"")+(modelData.name||"");color:rowLoader.isCurrent?page.playingInk:page.muted;font.pixelSize:14*page.u
                                    MouseArea {anchors.fill:parent;enabled:!!parent.modelData.id;cursorShape:Qt.PointingHandCursor;acceptedButtons:Qt.LeftButton|Qt.RightButton
                                        onClicked:function(mouse){if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);else page.controller.rowAction(page.selecting?"select":"artist:"+parent.index,rowLoader.song.identity);}}
                                }
                            }
                        }
                    }
                    Label {objectName:"magazineAlbum_"+rowLoader.songIndex;horizontalAlignment:Text.AlignLeft;visible:page.info.kind!=="album";x:page.secondaryX(parent.width);width:page.secondaryWidth(parent.width);height:parent.height;text:rowLoader.song.album||"";color:page.muted;font.pixelSize:14*page.u
                        MouseArea {anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor;enabled:!!rowLoader.song.albumID;onClicked:function(mouse){if(mouse.button===Qt.RightButton)page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);else page.controller.rowAction(page.selecting?"select":"album",rowLoader.song.identity);}}
                    }
                    Item {objectName:"magazineHeat_"+rowLoader.songIndex;visible:page.info.kind==="album";width:page.secondaryWidth(parent.width);x:page.secondaryCenter(parent.width)-width/2;height:parent.height
                        readonly property bool known:typeof rowLoader.song.popularity==="number"&&Number.isFinite(rowLoader.song.popularity)&&Number(rowLoader.song.popularity)>=0&&Number(rowLoader.song.popularity)<=100
                        Rectangle {anchors.centerIn:parent;width:Math.min(88*page.u,parent.width-12*page.unit);height:4*page.u;radius:height/2;color:page.dark?"#42677957":"#30788567";visible:parent.known
                            Rectangle {height:parent.height;width:parent.width*(Number(rowLoader.song.popularity)||0)/100;radius:height/2;color:page.accent}
                        }
                        Label {anchors.fill:parent;horizontalAlignment:Text.AlignHCenter;visible:!parent.known;text:"—";font.pixelSize:12*page.u;color:page.muted}
                        MouseArea {anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.NoButton;RhineToolTip {visible:parent.containsMouse;text:parent.parent.known?"接口热度 "+rowLoader.song.popularity+" / 100":"接口未提供热度"}}
                    }
                    SongHeart {objectName:"magazineHeart_"+rowLoader.songIndex;x:parent.width-148*page.u;anchors.verticalCenter:parent.verticalCenter;unit:page.u;liked:rowLoader.heart;known:rowLoader.heartKnown;pending:page.info.likeBusy===true||page.info.likesLoading===true;onToggled:if(rowLoader.heartKnown)page.controller.rowAction("like",rowLoader.song.identity);else page.controller.retryLikes()}
                    Label {objectName:"magazineDuration_"+rowLoader.songIndex;horizontalAlignment:Text.AlignHCenter;x:parent.width-96*page.u;width:60*page.u;height:parent.height;text:rowLoader.song.durationLabel||"—";color:page.muted;font.pixelSize:12*page.u}
                    RhineIcon {x:parent.width-24*page.u;anchors.verticalCenter:parent.verticalCenter;width:20*page.u;height:width;name:"more";color:page.muted
                        MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:function(mouse){page.menuFor(this,rowLoader.songIndex,rowLoader.song.identity,mouse);}}
                    }
                }
                Item {anchors.fill:parent;visible:page.controller.tab!=="songs"
                    Image {x:12*page.unit;y:14*page.unit;width:36*page.u;height:width;source:rhineCollectionBaseline?(rowLoader.social.avatar||""):rhine.personal.sizedCover(rowLoader.social.avatar||"",80);asynchronous:true;sourceSize.width:80;sourceSize.height:80;fillMode:Image.PreserveAspectCrop}
                    Label {x:65*page.unit;y:12*page.unit;width:parent.width-100*page.unit;height:25*page.u;text:rowLoader.social.name||"";font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium})}
                    Label {id:socialText;x:65*page.unit;y:43*page.unit;width:parent.width-100*page.unit;text:rowLoader.social.content||"";wrapMode:Text.Wrap;elide:Text.ElideNone;color:page.muted;font.pixelSize:14*page.u}
                }
            }
        }
        footer:Item {
            width:listing.width;height:page.controller.downloading?170*page.u:112*page.u
            Item {
            // Keep song artwork beneath the glass, while footer text/actions
            // remain in the readable area above the fixed playback controls.
            width:parent.width;height:Math.min(parent.height,Math.max(0,page.height-104*page.unit-(listing.y+parent.y-listing.contentY)));clip:true
            Column {anchors.horizontalCenter:parent.horizontalCenter;spacing:12*page.unit;y:18*page.unit
                Action {label:"重新读取喜欢状态";visible:!!page.info.likesError;onInvoked:page.controller.retryLikes()}
                Label {visible:page.controller.tab==="collectors"&&!!page.info.collectorError;text:page.info.collectorError||"";color:page.muted;font.pixelSize:12*page.u}
                Label {anchors.horizontalCenter:parent.horizontalCenter;objectName:"playlistResultStatus";text:page.info.loadError || page.controller.status || (page.controller.tab==="songs"&&page.controller.query&&page.info.visibleCount===0&&!page.info.loading&&!page.controller.busy?(page.info.searchComplete?"没有匹配的歌曲":"当前已载入曲目无匹配，可重试读取其余曲目"):page.info.loading?"正在载入曲目…":page.controller.tab==="songs"?"已载入 "+(page.info.loaded||0)+" / "+(page.info.total||0)+" 首":"");color:page.muted;font.pixelSize:12*page.u}
                Action {anchors.horizontalCenter:parent.horizontalCenter;visible:page.controller.downloading===true;label:"取消下载";onInvoked:page.controller.cancelDownload()}
                Action {anchors.horizontalCenter:parent.horizontalCenter;visible:page.controller.tab==="songs"?page.info.more===true:page.info.socialMore===true;label:page.info.loading||page.info.socialLoading?"正在读取…":"加载更多";enabled:!page.info.loading&&!page.info.socialLoading;onInvoked:page.controller.more()}
            }
            }
        }
    }
    Item {
        x:listing.x+listing.width-4*page.unit;y:listing.y;width:page.width-x;height:listing.height;z:14
        HoverHandler {id:edgeHover}
    }
    Rectangle {
        id:locateButton;objectName:"magazineLocateCurrent"
        x:listing.x+listing.width-width-20*page.unit;y:listing.y+listing.height-height-20*page.unit;z:14
        width:36*page.u;height:width;radius:width/2
        readonly property bool available:page.controller.tab==="songs"&&page.controller.playingRow>=0&&!page.playingInView
        opacity:available?1:0;visible:opacity>.001;enabled:available
        color:page.dark?(locateMouse.containsMouse?"#db414b37":"#bd343e2d"):(locateMouse.containsMouse?"#ecf3f3e9":"#ccecefe2")
        border.width:1;border.color:page.dark?"#38ffffff":"#70ffffff"
        Behavior on opacity {NumberAnimation {duration:page.reduced?0:180}}
        RhineIcon {anchors.centerIn:parent;width:18*page.u;height:width;name:"locate";color:page.playingInk}
        MouseArea {id:locateMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:page.locateCurrentSong()}
        RhineToolTip {visible:locateMouse.containsMouse;delay:500;text:"定位到当前歌曲"}
        Accessible.role:Accessible.Button;Accessible.name:"定位到当前歌曲";Accessible.onPressAction:page.locateCurrentSong()
    }
    // The editor lives outside the resetting ListView model. Filtering down to
    // zero rows must never destroy the focused TextInput or its edit buffer.
    Item {
        id:searchHost;x:page.contentLeft;y:listing.y+page.heroHeight+56*page.u-(listing.contentY-listing.startY)
        width:listing.width;height:56*page.u;z:3
        visible:page.controller.tab==="songs"&&y>=listing.y-1&&y<listing.y+listing.height
                Label {x:12*page.u;anchors.verticalCenter:parent.verticalCenter;text:page.controller.query?"找到 "+listing.count+" 首":"共 "+(page.info.total||0)+" 首";font.pixelSize:12.5*page.u;color:page.muted}
                Item {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:420*page.u;height:38*page.u;visible:page.controller.tab==="songs"
                    RhineComboBox {objectName:"collectionSort";anchors.right:parent.right;anchors.rightMargin:32*page.u;width:112*page.u;unit:page.u;model:["默认排序","按歌名","按歌手","按时长"];currentIndex:page.controller.sort;onActivated:{page.controller.setSort(currentIndex);page.restore();}}
                    PlaylistSearch {id:searchControl;anchors.right:parent.right;anchors.rightMargin:156*page.u;anchors.verticalCenter:parent.verticalCenter;controller:page.controller;unit:page.u;dark:page.dark;onEditing:{page.restoring=true;listing.contentY=listing.startY;restoreTimer.restart();}}
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
        ProfileArtwork {x:14*page.u;y:11*page.u;width:28*page.u;height:width;url:page.info.cover||"";sourceSize:Qt.size(64,64)}
        Label {x:54*page.u;y:8*page.u;width:parent.width-x-14*page.u;height:34*page.u;text:page.info.title||"";font.pixelSize:13.5*page.u;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold})}
        Row {x:14*page.u;y:52*page.u;spacing:10*page.u
            Action {objectName:"stickyPlayAll";label:"播放";iconName:"play";compact:true;primary:true;enabled:Number(page.info.total)>0;onInvoked:page.controller.bulk("play-all")}
            Action {objectName:"stickySubscribe";label:page.info.subscribed?"已收藏":"收藏";iconName:page.info.subscribed?"check":"collect";compact:true;enabled:page.info.canSubscribe===true&&!page.info.likeBusy;onInvoked:page.toggleSubscription()
                RhineToolTip {visible:subscriptionHover.hovered;text:parent.label}
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
    RhineDialog {
        id:unsubscribeDialog;objectName:"playlistUnsubscribeDialog"
        property string collectionKey:""
        unit:page.u;dark:page.dark;title:"取消收藏";confirmText:"取消收藏";destructive:true
        message:page.info.kind==="album"?"确定取消收藏这张专辑吗？":"确定取消收藏这个歌单吗？"
        onAccepted:page.controller.setSubscribed(collectionKey,false)
    }
    function dismissTopOverlay(){if(descriptionPopup.visible){descriptionPopup.close();return true;}if(searchControl.expanded){searchControl.dismiss();return true;}return false;}
    MouseArea {
        anchors.fill:parent;z:40;visible:searchControl.expanded
        containmentMask:QtObject {function contains(position: point): bool {var p=searchControl.mapFromItem(page,position.x,position.y);return p.x<0||p.y<0||p.x>searchControl.width||p.y>searchControl.height;}}
        onPressed:function(mouse){mouse.accepted=false;Qt.callLater(searchControl.dismiss);}
    }

    RhinePopup {
        id:descriptionPopup;objectName:"playlistDescriptionPopup"
        parent:Controls.Overlay.overlay;width:Math.min(580*page.u,page.width-40);height:Math.min(page.height-130*page.u,fullDescription.implicitHeight+84*page.u)
        x:Math.max(20,(page.width-width)/2);y:Math.max(60,Math.min(120*page.u,page.height-height-24))
        padding:20*page.u;modal:false;dim:false;closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        popupType:Controls.Popup.Item
        background:PopupGlass {popup:descriptionPopup;unit:page.u;radius:12*page.u;dark:page.dark;frosting:.84;tint:.23}
        contentItem:Item {
            Label {text:page.info.kind==="album"?"专辑详情":"歌单简介";font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold})}
            Item {objectName:"playlistDescriptionClose";anchors.right:parent.right;width:32*page.u;height:width;RhineIcon {anchors.centerIn:parent;width:18*page.u;height:width;name:"close";color:page.muted}MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:descriptionPopup.close()}}
            Flickable {id:descriptionReader;objectName:"playlistDescriptionReader";x:0;y:34*page.u;width:parent.width;height:parent.height-y;contentHeight:fullDescription.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
                Text {id:fullDescription;objectName:"playlistDescriptionText";width:parent.width;text:page.info.description||"";textFormat:Text.PlainText;wrapMode:Text.Wrap;lineHeight:1.45;color:page.ink;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14*page.u}
                WheelHandler {
                    target:null
                    onWheel:function(event){
                        var delta=event.pixelDelta.y!==0?event.pixelDelta.y:event.angleDelta.y/120*48*page.u;
                        descriptionReader.cancelFlick();
                        descriptionReader.contentY=Math.max(0,Math.min(Math.max(0,descriptionReader.contentHeight-descriptionReader.height),descriptionReader.contentY-delta));
                        event.accepted=true;
                    }
                }
                Controls.ScrollBar.vertical:Controls.ScrollBar {}
            }
        }
    }
    component CollectionMenuItem:RhineMenuItem {
        id:entry
        property string glyph:"more"
        unit:page.u;dark:page.dark;implicitWidth:256*page.u;implicitHeight:39*page.u
        contentItem:Item {
            RhineIcon {x:8*page.u;anchors.verticalCenter:parent.verticalCenter;width:20*page.u;height:width;name:entry.glyph;color:page.muted}
            Label {x:42*page.u;width:parent.width-x;height:parent.height;text:entry.text;font.pixelSize:15*page.u}
        }
    }
    RhineMenu {
        id:moreMenu;unit:page.u;dark:page.dark;parent:page;objectName:"playlistMoreMenu"
        padding:8*page.u
        popupType:Controls.Popup.Item

        CollectionMenuItem {objectName:"collectionShare";text:"分享…";glyph:"share";onTriggered:page.controller.share()}
        CollectionMenuItem {objectName:"collectionBatch";text:"批量操作";glyph:"batch";onTriggered:{page.selecting=true;listing.contentY=listing.startY+page.heroHeight+100*page.u;}}
        CollectionMenuItem {objectName:"collectionAppend";text:"添加全部至播放队列";glyph:"next";enabled:!page.controller.busy;onTriggered:page.controller.bulk("append-all")}
    }
    RhineMenu {
        id:filterMenu;unit:page.u;dark:page.dark;objectName:"playlistFilterMenu"
        popupType:Controls.Popup.Item

        font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14*page.u
        palette.window:page.dark?"#2b3327":"#f2f0e7";palette.text:page.ink;palette.highlight:page.dark?"#45553b":"#dfe7d3";palette.highlightedText:page.ink
        RhineMenuItem {text:"全部歌曲";onTriggered:{page.controller.setFilter("all");page.restore();}}
        RhineMenuItem {text:"已喜欢的歌曲";onTriggered:{page.controller.setFilter("liked");page.restore();}}
        RhineMenuItem {text:"可播放歌曲";onTriggered:{page.controller.setFilter("available");page.restore();}}
    }
}
