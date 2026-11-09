import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects

Rectangle {
    id: page
    objectName: artistMode ? "artistProfilePage" : "userProfilePage"
    property real unit: 1
    property bool artistMode: false
    property var hudState: rhine.state
    property var viewMemory: ({})
    signal viewSaved(var memory)
    property string memoryKey: ""
    readonly property var person: artistMode ? (hudState.artistProfile || {}) : (hudState.profile || {})
    readonly property bool dark: hudState.dark === true
    readonly property bool reduced: hudState.reduced === true || rhine.visualPreferences.motion !== "full"
    readonly property bool own: !artistMode && hudState.profileOwn === true
    readonly property bool social: !artistMode && ["follows", "followers"].indexOf(hudState.profileSection) >= 0
    signal conversationRequested(string uid, string name)
    readonly property color ink: dark ? "#e4e8db" : "#30392e"
    readonly property color muted: dark ? "#a3ad97" : "#7e8775"
    readonly property color accent: dark ? "#becbad" : "#788567"
    readonly property color shade: dark ? "#30342e" : "#f0f0f0"
    readonly property real inset:40*unit
    readonly property string viewKey: artistMode ? String(person.key) + ":" + hudState.artistTab :
        hudState.profileID + ":" + hudState.profileSection + ":" + hudState.profileFilter + ":" + hudState.profileRecentKind + ":" + hudState.profileRankPeriod
    readonly property bool overview: !artistMode && hudState.profileSection === "music" &&
        ["all", "playlists", "albums", "artists"].indexOf(hudState.profileFilter) >= 0
    // Stable section identities, like Cloudy's keyed foldGrid first row.
    // Filtering changes visibility; it never replaces the Repeater model.
    readonly property var collectionData:rhine.profileContent
    function sectionSpec(key) {
        if(artistMode)return {show:key===(hudState.artistTab==="albums"?"artistAlbums":"artistSongs"),title:key==="artistAlbums"?"发行专辑":"热门歌曲",list:key!=="artistAlbums"};
        var titles={created:"创建的歌单",collected:"收藏的歌单",albums:"收藏的专辑",artists:"关注的歌手",subscriptions:"订阅的播客"};
        if(overview)return {title:titles[key]||"",list:key==="subscriptions",show:key==="created"?["all","playlists"].indexOf(hudState.profileFilter)>=0:key==="collected"?own&&["all","playlists"].indexOf(hudState.profileFilter)>=0:key==="albums"?own&&["all","albums"].indexOf(hudState.profileFilter)>=0:key==="artists"?own&&["all","artists"].indexOf(hudState.profileFilter)>=0:key==="subscriptions"?own&&hudState.profileFilter==="all":false};
        return {show:key==="legacy",list:true,title:hudState.profileSection==="notes"?"动态":hudState.profileSection==="follows"?"关注":hudState.profileSection==="followers"?"粉丝":hudState.profileSection==="programs"?"播客节目":hudState.profileSection==="podcasts"?"创建的播客":({playlist:"最近歌单",song:"歌曲历史",album:"专辑历史",ranking:"听歌排行"})[hudState.profileRecentKind]||"听歌记录"};
    }
    property var unfolded: ({})
    property var orders: ({})
    color: dark ? "#22281f" : "#ffffff"
    clip: true
    function cover(url) { return rhine.personal.previewCover(String(url || "")); }
    function singleLine(value) { return String(value || "").replace(/\s+/g, " ").trim(); }
    function countLabel(value) {
        var n = Math.max(0, Math.floor(Number(value) || 0));
        return n >= 10000 ? Math.floor(n / 10000) + "万" : String(n);
    }
    function saveView() {
        if(!memoryKey)return;
        var memory=Object.assign({},viewMemory);
        memory[memoryKey]={scroll:reading.contentY,query:search.text,unfolded:unfolded,orders:orders};
        viewSaved(memory);
    }
    function restoreView() {
        var key=artistMode?String(person.key||""):String(hudState.profileID||"");
        if(key===memoryKey)return;
        saveView();memoryKey=key;
        var memory=viewMemory[key]||{};unfolded=memory.unfolded||{};orders=memory.orders||{};
        search.text=memory.query||"";restoreScroll.position=Number(memory.scroll||0);restoreScroll.restart();
    }
    Timer {id:restoreScroll;property real position:0;interval:300;onTriggered:reading.contentY=Math.min(position,Math.max(0,reading.contentHeight-reading.height))}
    Component.onCompleted:restoreView()
    Component.onDestruction:saveView()
    Connections {target:rhine;function onStateChanged(){page.restoreView();}}
    Connections {target:rhine;function onPointerPressed(x,y){
        if(!page.visible||signatureEditor.visible||biography.visible)return;
        var p=searchFrame.mapFromItem(null,x,y);
        if(p.x<0||p.y<0||p.x>searchFrame.width||p.y>searchFrame.height)page.releaseSearchFocus();
    }}
    function change(action) {
        search.focus = false;
        contentMotion.run(function(){rhine.action(action);reading.contentY=0;});
    }
    function dismissTopOverlay() {
        if (signatureEditor.visible) { if (!hudState.profileSignatureSaving) signatureEditor.close(); return true; }
        if (biography.visible) { biography.close(); return true; }
        if (search.activeFocus) { search.focus = false; page.forceActiveFocus(); return true; }
        return false;
    }
    function snapshot(key) { return (collectionData.profileCollections || {})[key] || {}; }
    function rowsFor(key) {
        var source = artistMode ? (key === "artistAlbums" ? collectionData.artistAlbums : collectionData.artistSongs) :
            key === "legacy" ? collectionData.profileRows : snapshot(key === "created" || key === "collected" ? "playlists" : key).rows;
        var rows = [], q = search.text.trim().toLowerCase();
        for (var i = 0; i < (source || []).length; ++i) {
            var item = source[i];
            if (key === "created" && item.owned !== true || key === "collected" && item.owned === true) continue;
            var match = String(item.title || "") + " " + String(item.artist || "") + " " + String(item.description || "");
            if (q && match.toLowerCase().indexOf(q) < 0) continue;
            rows.push({item:item, source:key === "created" || key === "collected" ? "playlists" : key, index:i});
        }
        var order = orders[key] || 0;
        if (order) rows.sort(function(a,b) { return order === 1 ? String(a.item.title).localeCompare(String(b.item.title)) : key==="albums"?String(a.item.artist||"").localeCompare(String(b.item.artist||"")):Number(b.item.trackCount || 0) - Number(a.item.trackCount || 0); });
        return rows;
    }
    function actionFor(row, operation) {
        if (row.source === "artistSongs") return "music:" + (operation === "play" ? "play-row:" : "track:") + row.index;
        if (row.source === "artistAlbums") return "music:artist-album:" + row.index;
        if (row.source === "legacy") return "profile:" + (operation === "play" ? "play:" : "item:") + row.index;
        return "profile:collection-" + operation + ":" + row.source + ":" + row.index;
    }
    function focusRow(row, item, mouse) {
        var p = item.mapToItem(null, mouse.x, mouse.y);
        rhine.hoverItem(actionFor(row, "item"), p.x / unit, p.y / unit);
    }
    function navigateKey(key) {
        if (biography.visible || search.activeFocus) return;
        var cards = [];
        for (var i = 0; i < sections.count; ++i) {
            var section = sections.itemAt(i);
            if (!section || !section.visible) continue;
            for (var j = 0; j < Math.min(section.shown,section.cardItems.count); ++j) {var slot=section.cardItems.itemAt(j);if(slot)cards.push(slot);}
        }
        if (!cards.length) return;
        var current = -1;
        for (var n = 0; n < cards.length; ++n) if ((cards[n].item&&cards[n].item.focused)||hudState.focusAction===actionFor(cards[n].row,"item")) current = n;
        if (key === "Enter") { if (current >= 0) rhine.action(actionFor(cards[current].row,"item")); return; }
        var columns = cards[Math.max(0,current)].columnCount;
        var move = key === "ArrowDown" ? columns : key === "ArrowUp" ? -columns : key === "ArrowLeft" ? -1 : key === "ArrowRight" ? 1 : 0;
        if (!move) return;
        var card = cards[current < 0 ? 0 : Math.max(0,Math.min(cards.length-1,current+move))];
        if (!artistMode) rhine.action(card.row.source === "legacy" ? "profile:focus:" + card.row.index : "profile:collection-focus:" + card.row.source + ":" + card.row.index);
        var y = card.mapToItem(content,0,0).y;
        if (y < reading.contentY) reading.contentY = y;
        else if (y + card.height > reading.contentY + reading.height) reading.contentY = y + card.height - reading.height;
    }
    onViewKeyChanged: { reading.contentY = 0; }
    RhineContentMotion {id:contentMotion;objectName:"profileContentMotion"}
    Timer { id:scrollReveal;interval:1100 }
    Timer { interval:160;repeat:true;running:search.text.trim().length>0 && page.overview && page.visible
        onTriggered: {
            var keys = page.own ? ["playlists","albums","artists","subscriptions"] : ["playlists"];
            for (var i=0;i<keys.length;++i) { var s=page.snapshot(keys[i]); if(s.more && !s.loading && !s.error) rhine.action("profile:collection-more:"+keys[i]); }
        }
    }
    function releaseSearchFocus() {
        if (search.activeFocus) { search.focus = false; page.forceActiveFocus(); }
    }
    MouseArea {anchors.fill:parent;onPressed:page.releaseSearchFocus();onWheel:function(event){event.accepted=true;}}
    component Label: Text {
        color:page.ink;textFormat:Text.PlainText;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:15*page.unit;elide:Text.ElideRight
    }
    component Button: Controls.AbstractButton {
        id:button
        property string label
        property string iconName:""
        property bool selected:false
        property bool primary:false
        signal invoked()
        width:caption.implicitWidth+(28+(iconName?26:0))*page.unit;height:34*page.unit
        hoverEnabled:true;focusPolicy:Qt.StrongFocus
        background:Rectangle {
            radius:height/2
            color:button.primary?(button.down?"#59684d":"#7a866c"):button.down?(page.dark?"#484b46":"#e3e3e3"):(button.selected||button.hovered||button.visualFocus)?page.shade:"transparent"
            border.width:button.visualFocus?1:0;border.color:page.accent
            Behavior on color {ColorAnimation {duration:page.reduced?0:100}}
        }
        contentItem:Item {Row {anchors.centerIn:parent;spacing:8*page.unit;RhineIcon {visible:!!button.iconName;name:button.iconName;width:18*page.unit;height:width;anchors.verticalCenter:parent.verticalCenter;color:button.primary?"#f6f6ee":page.ink}Label {id:caption;text:button.label;color:button.primary?"#f6f6ee":page.ink;font.pixelSize:13*page.unit;font.weight:button.selected?Font.DemiBold:Font.Normal;font.variableAxes:({"wght":button.selected?Font.DemiBold:Font.Normal})}}}
        Accessible.role:Accessible.Button;Accessible.name:label;Accessible.onPressAction:invoked()
        HoverHandler {cursorShape:Qt.PointingHandCursor}
        onClicked:invoked()
        onPressed:page.releaseSearchFocus()
    }
    component Card: Item {
        id:card
        objectName:"profileCard_"+row.source+"_"+row.index
        required property var row
        property bool list:false
        property int columnCount:1
        readonly property var entry:row.item
        readonly property string entryAction:page.actionFor(row,"item")
        readonly property bool focused:(page.hudState.keyboardNavigation&&page.hudState.focusAction===entryAction) || cardMouse.containsMouse || playMouse.containsMouse || creditMouse.containsMouse || messageButton.hovered
        readonly property bool round:entry.kind==="artist" || entry.kind==="user"
        readonly property bool playable:["playlist","album","song"].indexOf(entry.kind)>=0
        readonly property bool noteCard:entry.kind==="note"
        readonly property bool currentSong:entry.kind==="song"&&String(entry.id)===String(rhine.nowPlaying.info.id)&&String(entry.provider||"netease")===String(rhine.nowPlaying.info.provider||"netease")
        readonly property bool ownPlaylist:page.own&&entry.kind==="playlist"&&row.source==="playlists"
        readonly property bool creditLink:!ownPlaylist&&(!!entry.creatorID || (entry.artists || []).length>0)
        readonly property real padding:(list?10:0)*page.unit
        readonly property real artSize:list?(page.social?72:64)*page.unit:width-2*padding
        readonly property bool nearViewport: {
            var scroll = reading.contentY;
            var layoutY = card.y, layoutHeight = content.height;
            var p = card.mapToItem(content, 0, 0);
            return page.visible && p.y + height >= scroll - reading.height*.5 && p.y <= scroll + reading.height*1.5;
        }
        height:list?(noteCard?Math.max(88*page.unit,title.implicitHeight+46*page.unit):(page.social?100:88)*page.unit):artSize+10*page.unit+Math.ceil(13*page.unit*1.35)*2+4*page.unit+Math.ceil(12*page.unit*1.35)
        Rectangle {objectName:"profileCardHover";anchors.fill:parent;radius:8*page.unit;color:page.shade;opacity:card.list&&card.focused?1:0;Behavior on opacity {NumberAnimation {duration:page.reduced?0:120}}}
        MouseArea {id:cardMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor
            onPressed:page.releaseSearchFocus()
            acceptedButtons:Qt.LeftButton|Qt.RightButton
            onEntered:if(!page.hudState.keyboardNavigation)page.focusRow(card.row,this,{x:mouseX,y:mouseY})
            onPositionChanged:function(mouse){page.focusRow(card.row,this,mouse);}
            onExited:if(!page.artistMode)rhine.action("profile:blur")
            onClicked:function(mouse){
                if(mouse.button===Qt.LeftButton)rhine.action(card.entryAction);
                else if(card.entry.kind==="song" && card.row.source==="legacy") {var p=mapToItem(null,mouse.x,mouse.y);rhine.magazine.showSongMenu("profile",card.row.index,(card.entry.provider||"netease")+":"+card.entry.id,p.x,p.y);}
            }
        }
        Item {
            id:art;x:card.padding;width:card.artSize;height:width
            y:page.social?(card.height-height)/2:card.padding+(card.focused&&!card.list?-5*page.unit:0)
            scale:card.focused&&!card.list?1.015:1
            Behavior on scale {NumberAnimation {duration:page.reduced?0:200;easing.type:Easing.OutCubic}}
            Behavior on y {NumberAnimation {duration:page.reduced?0:200;easing.type:Easing.OutCubic}}
            Rectangle {id:artShadow;anchors.fill:parent;radius:card.round?width/2:14*page.unit;color:"black";visible:false}
            Rectangle {objectName:"profileRoundHover";anchors.fill:parent;anchors.margins:-6*page.unit;radius:width/2;color:page.shade;opacity:card.round&&!card.list&&card.focused?1:0;Behavior on opacity {NumberAnimation {duration:page.reduced?0:120}}}
            MultiEffect {anchors.fill:artShadow;source:artShadow;visible:!card.list&&card.nearViewport;shadowEnabled:true;blurEnabled:true;blurMax:24;blur:.35;shadowBlur:card.focused?.8:.3;shadowVerticalOffset:(card.focused?8:2)*page.unit;shadowOpacity:card.focused?.16:.06;autoPaddingEnabled:true}
            Rectangle {id:artClip;anchors.fill:parent;radius:card.round?width/2:14*page.unit;color:page.shade;clip:true
                layer.enabled:true;layer.effect:MultiEffect {maskEnabled:true;maskSource:artMask}
                RhineIcon {anchors.centerIn:parent;width:Math.min(38*page.unit,parent.width*.3);height:width;name:card.round?"user":card.noteCard?"comment":"disc";color:page.muted}
                ProfileArtwork {id:cardArtwork;objectName:"profileCardArtwork";anchors.fill:parent;url:card.entry.cover || (card.entry.resource || {}).cover || "";requested:card.nearViewport;sourceSize:Qt.size(card.list?160:360,card.list?160:360);visible:false}
                ShaderEffect {anchors.fill:parent;property variant source:cardArtwork;property size artworkSize:Qt.size(width,height);property real radius:artClip.radius;property real sourceAspect:cardArtwork.implicitWidth/Math.max(1,cardArtwork.implicitHeight);fragmentShader:"qrc:/shaders/roundedArtwork.frag.qsb";visible:cardArtwork.status===Image.Ready}
                Rectangle {anchors.fill:parent;color:"black";opacity:card.focused&&!card.round?.12:0;Behavior on opacity {NumberAnimation {duration:page.reduced?0:180}}}
                Label {anchors.centerIn:parent;visible:card.entry.kind==="ranking";text:"▂ ▆ ▃";font.pixelSize:34*page.unit;color:page.accent}
            }
            Item {id:artMask;anchors.fill:artClip;layer.enabled:true;visible:false;Rectangle {anchors.fill:parent;radius:artClip.radius;color:"white"}}
            Rectangle {visible:!card.list&&Number(card.entry.playCount)>0;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:8*page.unit;width:playCountRow.width+14*page.unit;height:plays.implicitHeight+4*page.unit;radius:height/2;color:"#59000000"
                Row {id:playCountRow;anchors.centerIn:parent;spacing:3*page.unit
                    RhineIcon {width:10*page.unit;height:width;anchors.verticalCenter:parent.verticalCenter;name:"cloudyHeadset";color:"white"}
                    Label {id:plays;font.pixelSize:10.5*page.unit;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:"white";text:page.countLabel(card.entry.playCount)}
                }
            }
            Rectangle {
                objectName:"profileCardPlay"
                anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:10*page.unit
                width:(card.list?30:38)*page.unit;height:width;radius:width/2
                color:page.accent;visible:card.playable
                opacity:card.focused?1:0;scale:card.focused?1:.85
                Behavior on opacity {NumberAnimation {duration:page.reduced?0:160}}
                Behavior on scale {NumberAnimation {duration:page.reduced?0:220;easing.type:Easing.OutCubic}}
                RhineIcon {anchors.centerIn:parent;width:16*page.unit;height:width;name:"cloudyPlay";color:"white";visible:page.hudState.profilePlayKey!==card.entry.key}
                Controls.BusyIndicator {anchors.centerIn:parent;width:24*page.unit;height:width;running:page.hudState.profilePlayKey===card.entry.key;visible:running}
                MouseArea {id:playMouse;anchors.fill:parent;hoverEnabled:true;enabled:card.focused&&!page.hudState.profilePlayKey;cursorShape:Qt.PointingHandCursor;onClicked:rhine.action(page.actionFor(card.row,"play"))}
            }
        }
        PlayingBars {x:art.x+art.width+16*page.unit;y:title.y+(title.height-height)/2;visible:card.list&&card.currentSong;unit:page.unit;color:page.accent;motionAllowed:card.nearViewport&&RhineTheme.fullMotion}
        Label {id:title;x:card.list?art.x+art.width+(card.currentSong?42:16)*page.unit:card.padding;y:page.social?(card.height-height-(credit.text?credit.height+6*page.unit:0))/2:card.list?16*page.unit:art.height+10*page.unit;width:Math.max(0,parent.width-x-card.padding-(page.social?messageButton.width+14*page.unit:0))
            text:(card.entry.rank?String(card.entry.rank).padStart(2,"0")+"  ":"")+page.singleLine(card.entry.title||"未命名")
            font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium});font.pixelSize:(card.list?15:13)*page.unit
            horizontalAlignment:card.round&&!card.list?Text.AlignHCenter:Text.AlignLeft
            wrapMode:card.noteCard||!card.list?Text.Wrap:Text.NoWrap;maximumLineCount:card.noteCard?1000:card.list?1:2;lineHeight:card.list?1:1.35
            color:card.focused?page.accent:page.ink;Behavior on color {ColorAnimation {duration:page.reduced?0:140}}
        }
        Label {id:credit;objectName:"profileCardCredit";x:title.x;y:title.y+title.height+4*page.unit;width:title.width;font.pixelSize:(card.list?13:12)*page.unit
            maximumLineCount:1;wrapMode:Text.NoWrap;clip:true
            visible:!card.round||card.list;text:card.ownPlaylist?(card.entry.trackCount||0)+" 首":page.singleLine(card.entry.artist)+(card.entry.trackCount!==undefined&&card.entry.kind!=="song"&&card.entry.kind!=="note"?((card.entry.artist||"")?" · ":"")+(card.entry.trackCount||0)+(card.entry.kind==="radio"?" 期":" 首"):card.entry.date?" · "+card.entry.date:card.entry.listeningCount!==undefined?" · "+card.entry.listeningCount+" 次":"")
            color:creditMouse.containsMouse?page.accent:page.muted
            MouseArea {id:creditMouse;anchors.fill:parent;hoverEnabled:true;enabled:card.creditLink&&card.row.source!=="legacy"&&card.row.source!=="artistSongs"&&card.row.source!=="artistAlbums";cursorShape:Qt.PointingHandCursor;onClicked:rhine.action(page.actionFor(card.row,"creator"))}
        }
        Controls.AbstractButton {
            id:messageButton;objectName:"profileMessageButton";visible:page.social
            anchors.right:parent.right;anchors.rightMargin:card.padding;anchors.verticalCenter:parent.verticalCenter
            width:80*page.unit;height:30*page.unit;hoverEnabled:true;focusPolicy:Qt.StrongFocus
            enabled:!!page.hudState.accountUID&&String(card.entry.id)!==String(page.hudState.accountUID)&&rhine.messages.state.supported
            Accessible.name:"私信 "+String(card.entry.title||"")
            opacity:enabled?1:.4
            background:Rectangle {radius:height/2;color:messageButton.down?(page.dark?"#484b46":"#e3e3e3"):messageButton.hovered||messageButton.visualFocus?page.shade:"transparent";border.width:1;border.color:page.dark?"#30ffffff":"#1c000000"
                Behavior on color {ColorAnimation {duration:page.reduced?0:120}}
            }
            contentItem:Item {
                RhineIcon {x:13*page.unit;anchors.verticalCenter:parent.verticalCenter;width:16*page.unit;height:width;name:"message";color:page.muted}
                Label {x:35*page.unit;anchors.verticalCenter:parent.verticalCenter;text:"私信";font.pixelSize:13*page.unit;color:page.muted}
            }
            HoverHandler {cursorShape:messageButton.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
            onClicked:page.conversationRequested(String(card.entry.id),String(card.entry.title||""))
        }
    }
    component Section: Column {
        id:section
        objectName:"profileSection_"+group
        required property string group
        required property string heading
        property bool list:false
        readonly property var rows:page.rowsFor(group)
        property var status:group==="legacy"?({loading:page.hudState.profileLoading,error:page.hudState.profileError,more:page.hudState.profileMore}):page.artistMode?({loading:page.hudState.artistTab==="albums"?page.hudState.artistAlbumsLoading:page.hudState.artistLoading,more:page.hudState.artistTab==="albums"&&page.hudState.artistAlbumsMore}):page.snapshot(group==="created"||group==="collected"?"playlists":group)
        property bool expanded:page.unfolded[group]===true||search.text.trim().length>0||group==="legacy"||page.artistMode||(page.overview&&page.hudState.profileFilter!=="all")
        property int columns:page.social?Math.max(1,Math.min(3,Math.floor((width+24*page.unit)/(500*page.unit)))):list?1:Math.max(2,Math.floor((width+20*page.unit)/(188*page.unit)))
        readonly property var sortLabels:group==="albums"?["按收藏时间","按专辑名","按艺人"]:["默认顺序","按名称","按歌曲数"]
        readonly property int shown:expanded?rows.length:Math.min(columns,rows.length)
        property alias cardItems:cardRepeater
        width:content.width;spacing:14*page.unit
        function toggle() {flip();}
        function flip(){var value=Object.assign({},page.unfolded);value[group]=!expanded;page.unfolded=value;}
        property int renderedCount:shown
        property bool visited:false
        Component.onCompleted:if(visible)visited=true
        onShownChanged:if(visible)updateCount()
        onVisibleChanged:if(visible){visited=true;updateCount();}
        function updateCount(){renderedCount=Math.max(renderedCount,shown);}
        // An integer model grows/shrinks without resetting surviving delegates.
        readonly property real slotHeight:list?(page.social?100:88)*page.unit:(width-(columns-1)*20*page.unit)/columns+10*page.unit+Math.ceil(13*page.unit*1.35)*2+4*page.unit+Math.ceil(12*page.unit*1.35)
        Item {width:parent.width;height:28*page.unit
            Row {anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;spacing:10*page.unit
                Label {objectName:"profileHeading_"+section.group;text:section.heading;font.pixelSize:19*page.unit;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold});anchors.verticalCenter:parent.verticalCenter}
                Label {text:section.rows.length+(section.status.more?"+":"");color:page.muted;font.pixelSize:13*page.unit;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});anchors.verticalCenter:parent.verticalCenter}
            }
            Row {objectName:"profileSectionActions_"+section.group;anchors.right:parent.right;spacing:10*page.unit
                Controls.AbstractButton {id:orderButton;objectName:"profileOrder_"+section.group;visible:!section.list&&section.rows.length>1;width:orderContents.width+20*page.unit;height:28*page.unit;hoverEnabled:true;Accessible.name:"排序："+section.sortLabels[page.orders[section.group]||0];onClicked:orderMenu.open()
                    background:Rectangle {radius:height/2;color:orderButton.hovered||orderButton.visualFocus?page.shade:"transparent"}
                    contentItem:Item {Row {id:orderContents;anchors.centerIn:parent;spacing:5*page.unit
                        RhineIcon {anchors.verticalCenter:parent.verticalCenter;width:12*page.unit;height:width;name:"cloudyUpDown";color:page.muted}
                        Label {text:section.sortLabels[page.orders[section.group]||0];font.pixelSize:12.5*page.unit;color:orderButton.hovered?page.ink:page.muted}
                    }}
                    RhineMenu {id:orderMenu;y:orderButton.height;dark:page.dark;Repeater {model:section.sortLabels;delegate:RhineMenuItem {required property int index;required property string modelData;text:modelData;checkable:true;checked:(page.orders[section.group]||0)===index;onTriggered:{var orders=Object.assign({},page.orders);orders[section.group]=index;page.orders=orders;}}}}
                }
                Controls.AbstractButton {id:foldButton;objectName:"profileExpand_"+section.group;visible:!page.artistMode&&section.group!=="legacy"&&!search.text.trim().length&&page.hudState.profileFilter==="all"&&(section.rows.length>section.columns||section.status.more===true);width:foldContents.width+24*page.unit;height:28*page.unit;hoverEnabled:true;Accessible.name:section.expanded?"收起":"展开全部 "+section.rows.length;onClicked:section.toggle()
                    background:Rectangle {radius:height/2;color:foldButton.down?page.shade:foldButton.hovered?(page.dark?"#484b46":"#e3e3e3"):page.shade}
                    contentItem:Item {Row {id:foldContents;anchors.centerIn:parent;spacing:6*page.unit
                        Label {text:foldButton.Accessible.name;font.pixelSize:12.5*page.unit}
                        RhineIcon {anchors.verticalCenter:parent.verticalCenter;width:12*page.unit;height:width;name:"cloudyDown";color:page.muted;rotation:section.expanded?180:0;Behavior on rotation {NumberAnimation {duration:page.reduced?0:180;easing.type:Easing.OutCubic}}}
                    }}
                }
            }
        }
        ProfileTabs {
            objectName:"profileRankPeriod"
            visible:section.group==="legacy"&&page.hudState.profileFilter==="recent"&&page.hudState.profileRecentKind==="ranking"
            options:[{label:"所有时间",key:"all"},{label:"最近一周",key:"week"}]
            current:page.hudState.profileRankPeriod;unit:page.unit;dark:page.dark;reduced:page.reduced;segmentWidth:92*page.unit
            onChosen:function(key){page.change("profile:rank-period:"+key);}
        }
        Item {id:sectionBody;objectName:"profileSectionBody_"+section.group;width:parent.width;clip:true
            function shownHeight(){
                if(!section.list||page.hudState.profileSection!=="notes")return Math.max(0,Math.ceil(section.shown/section.columns)*(section.slotHeight+grid.rowSpacing)-grid.rowSpacing);
                var bottom=0;
                for(var i=0;i<Math.min(section.shown,cardRepeater.count);++i){
                    var card=cardRepeater.itemAt(i);
                    if(card)bottom=Math.max(bottom,card.y+card.height);
                }
                return bottom;
            }
            height:shownHeight()
            // Tab changes already animate the whole content. Do not animate
            // hundreds of rows' geometry underneath the same fade.
            Behavior on height {enabled:!contentMotion.busy;NumberAnimation {duration:page.reduced?0:260;easing.type:Easing.InOutCubic}}
            Grid {id:grid;width:parent.width;columns:section.columns;columnSpacing:(page.social?24:20)*page.unit;rowSpacing:section.list?6*page.unit:28*page.unit
                move:Transition {NumberAnimation {properties:"x,y";duration:page.reduced?0:240;easing.type:Easing.OutCubic}}
                Repeater {id:cardRepeater;model:section.rows.length
                    // Cheap layout slots for the complete data set; only the
                    // visible rows allocate text, effects, input handlers and art.
                    delegate:Loader {
                        id:slot
                        required property int index
                        readonly property int columnCount:section.columns
                        readonly property var row:section.rows[index]
                        readonly property real estimatedHeight:section.list?(page.social?100:88)*page.unit:width+10*page.unit+Math.ceil(13*page.unit*1.35)*2+4*page.unit+Math.ceil(12*page.unit*1.35)
                        width:Math.max(0,(grid.width-(grid.columns-1)*grid.columnSpacing)/grid.columns)
                        height:item?item.height:estimatedHeight
                        readonly property bool nearViewport:{var scroll=reading.contentY;var layout=content.height;var position=y;var p=mapToItem(content,0,0);return section.visible&&page.visible&&p.y+height>=scroll-reading.height*.25&&p.y<=scroll+reading.height*1.25;}
                        active:section.visited&&(index<section.columns*2||(index<section.shown&&nearViewport))
                        asynchronous:true
                        sourceComponent:Card {row:slot.row;columnCount:section.columns;list:section.list;width:slot.width}
                    }
                }
            }
        }
        Label {visible:section.status.loading===true;text:"正在读取…";color:page.muted;font.pixelSize:13*page.unit}
        Label {visible:!section.status.loading&&!section.status.error&&section.rows.length===0;text:search.text?"没有匹配的内容":section.group==="created"?"还没有公开的歌单":"暂无内容";color:page.muted;font.pixelSize:14*page.unit}
        Row {visible:!!section.status.error;spacing:10*page.unit
            Label {width:Math.min(460*page.unit,section.width-110*page.unit);text:section.status.error||"";color:page.muted;wrapMode:Text.Wrap}
            Button {label:"重新加载";onInvoked:rhine.action(section.group==="legacy"?"profile:retry":"profile:collection-retry:"+section.group)}
        }
        Button {visible:section.status.more===true&&!section.status.loading&&section.expanded;label:"加载更多 ↓";onInvoked:rhine.action(page.artistMode?"music:artist-more":section.group==="legacy"?"profile:more":"profile:collection-more:"+section.group)}
    }
    Flickable {
        id:reading;objectName:"profileReading"
        x:page.inset;y:24*page.unit;width:page.width-2*x;height:page.height-y-12*page.unit
        clip:true;contentWidth:width;contentHeight:content.height+24*page.unit;boundsBehavior:Flickable.StopAtBounds
        onContentYChanged:scrollReveal.restart()
        WheelHandler {target:null;onWheel:function(event){reading.cancelFlick();reading.contentY=Math.max(0,Math.min(Math.max(0,reading.contentHeight-reading.height),reading.contentY-(event.pixelDelta.y||event.angleDelta.y*.6)*page.unit));event.accepted=true;}}
        Controls.ScrollBar.vertical:Controls.ScrollBar {
            id:scrollBar;objectName:"profileScrollBar";parent:page;x:page.width-width-3*page.unit;y:reading.y;height:reading.height;width:18*page.unit;padding:5*page.unit;minimumSize:.05
            policy:Controls.ScrollBar.AlwaysOn;hoverEnabled:true
            opacity:size<1&&(scrollReveal.running||reading.moving||hovered||pressed||edgeHover.hovered)?1:0
            Behavior on opacity {NumberAnimation {duration:page.reduced?0:180}}
            contentItem:Rectangle {implicitWidth:6*page.unit;radius:width/2;color:page.dark?"#90bfccad":"#88758364"}
            background:Item {}
        }
        Column {
            id:content;width:reading.width;spacing:30*page.unit
            Item {width:parent.width;height:page.social?48*page.unit:232*page.unit
                Label {visible:page.social;anchors.verticalCenter:parent.verticalCenter;width:parent.width;text:(page.own?"我的":(page.person.nickname||"用户")+"的")+(page.hudState.profileSection==="followers"?"粉丝":"关注");font.pixelSize:26*page.unit;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold})}
                Item {id:portrait;y:8*page.unit;width:212*page.unit;height:width
                    visible:!page.social
                    Rectangle {anchors.fill:parent;anchors.topMargin:14*page.unit;anchors.bottomMargin:-14*page.unit;radius:width/2;color:page.dark?"#24000000":"#12727b65"}
                    ProfileArtwork {id:avatar;anchors.fill:parent;url:(page.artistMode?page.person.cover:page.person.avatarUrl)||"";sourceSize.width:480;sourceSize.height:480
                        layer.enabled:true;layer.effect:MultiEffect {maskEnabled:true;maskSource:avatarMask}
                    }
                    Item {id:avatarMask;anchors.fill:parent;layer.enabled:true;visible:false;Rectangle {anchors.fill:parent;radius:width/2;color:"white"}}
                    MouseArea {anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:biography.open()}
                }
                Column {x:portrait.width+30*page.unit;y:Math.max(18*page.unit,portrait.height-height);width:parent.width-x;spacing:10*page.unit
                    visible:!page.social
                    Label {text:page.artistMode?"歌手":page.own?"我的主页":"用户";color:page.accent;font.pixelSize:12*page.unit;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold})}
                    Label {objectName:"profileNickname";width:parent.width;text:page.person.nickname||page.person.title||"正在读取资料…";font.pixelSize:32*page.unit;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold})}
                    Row {visible:!page.artistMode;spacing:6*page.unit
                        Button {objectName:"profileFollows";label:(page.person.follows||0)+" 关注";onInvoked:page.change("profile:section:follows")}
                        Label {text:"·";color:page.muted;anchors.verticalCenter:parent.verticalCenter}
                        Button {objectName:"profileFollowers";label:(page.person.followeds||0)+" 粉丝";onInvoked:page.change("profile:section:followers")}
                    }
                    Label {visible:page.artistMode;text:(page.person.trackCount||0)+" 首歌曲";color:page.muted;font.pixelSize:13*page.unit}
                    Label {objectName:"profileSignature";width:parent.width;text:page.person.signature||page.person.description||"这个人还没有留下简介。";color:signatureMouse.containsMouse?page.accent:page.muted;font.pixelSize:14*page.unit;wrapMode:Text.Wrap;maximumLineCount:2;lineHeight:1.4
                        MouseArea {id:signatureMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{if(page.own){signatureText.text=page.person.signature||"";signatureEditor.open();}else biography.open();}}
                    }
                    Row {spacing:8*page.unit
                        Button {objectName:"profileArtistEntry";visible:!page.artistMode&&Number(page.person.artistId||0)>0;label:"歌手页";iconName:"cloudyUser";onInvoked:rhine.action("profile:artist")}
                        Button {visible:page.artistMode&&!!page.person.userID;label:"个人主页 ↗";onInvoked:rhine.action("profile:open:"+page.person.userID)}
                        Button {visible:page.artistMode;label:"▶ 播放全部";primary:true;onInvoked:rhine.action("music:play-loaded")}
                        Button {visible:page.artistMode;label:"关注 / 取消";onInvoked:rhine.action("music:subscribe")}
                        Button {objectName:"profileHistoryEntry";visible:!page.artistMode&&page.own;label:"听歌记录";iconName:"userRanking";onInvoked:page.change("profile:filter:recent")}
                    }
                }
            }
            Flow {width:parent.width;spacing:14*page.unit
                Rectangle {id:searchFrame;objectName:"profileSearchFrame";width:Math.min(300*page.unit,content.width*.40);height:34*page.unit;radius:height/2;color:search.activeFocus?(page.dark?"#22281f":"#ffffff"):searchHover.hovered?(page.dark?"#383c36":"#e9e9e9"):page.shade;border.width:1;border.color:search.activeFocus?page.accent:(page.dark?"#18ffffff":"#16000000")
                    Behavior on color {ColorAnimation {duration:page.reduced?0:120}}
                    Rectangle {anchors.fill:parent;anchors.margins:-3*page.unit;radius:height/2;color:"transparent";border.width:3*page.unit;border.color:page.dark?"#358b9980":"#35788567";opacity:search.activeFocus?1:0;Behavior on opacity {NumberAnimation {duration:page.reduced?0:130}}}
                    HoverHandler {id:searchHover;cursorShape:Qt.IBeamCursor}
                    TapHandler {onTapped:search.forceActiveFocus()}
                    RhineIcon {x:13*page.unit;anchors.verticalCenter:parent.verticalCenter;width:14*page.unit;height:width;name:"search";color:page.muted}
                    TextInput {id:search;objectName:"profileSearch";x:36*page.unit;width:parent.width-x-32*page.unit;height:parent.height;verticalAlignment:Text.AlignVCenter;clip:true;selectByMouse:true;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13*page.unit;color:page.ink
                        onTextChanged:reading.contentY=0
                        Keys.onEscapePressed:function(event){text="";focus=false;event.accepted=true;}
                        Label {anchors.fill:parent;verticalAlignment:Text.AlignVCenter;visible:!search.text&&!search.preeditText;text:page.social?"搜索名称和简介":"搜索歌单、专辑、歌手和播客";font.pixelSize:12*page.unit;color:page.muted}
                    }
                    Label {anchors.right:parent.right;anchors.rightMargin:12*page.unit;anchors.verticalCenter:parent.verticalCenter;text:"×";visible:search.text.length>0;MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:search.text=""}}
                }
                ProfileTabs {objectName:"profileFilters";unit:page.unit;dark:page.dark;reduced:page.reduced;segmentWidth:(page.artistMode?96:58)*page.unit
                    visible:!page.social
                    options:page.artistMode?[{label:"热门歌曲",key:"songs"},{label:"发行专辑",key:"albums"}]:page.own?[{label:"全部",key:"all"},{label:"歌单",key:"playlists"},{label:"专辑",key:"albums"},{label:"歌手",key:"artists"},{label:"动态",key:"notes"},{label:"播客",key:"podcasts"}]:[{label:"全部",key:"all"},{label:"歌单",key:"playlists"},{label:"动态",key:"notes"},{label:"播客",key:"podcasts"}]
                    current:page.artistMode?page.hudState.artistTab:page.hudState.profileSection==="music"?page.hudState.profileFilter:page.hudState.profileSection==="programs"?"podcasts":page.hudState.profileSection
                    onChosen:function(key){page.change(page.artistMode?"music:artist-tab:"+key:["notes","podcasts"].indexOf(key)>=0?"profile:section:"+key:"profile:filter:"+key);}
                }
            }
            ProfileTabs {objectName:"profileHistoryTabs";visible:!page.artistMode&&page.hudState.profileSection==="music"&&page.hudState.profileFilter==="recent"
                unit:page.unit;dark:page.dark;reduced:page.reduced;segmentWidth:100*page.unit
                options:[{label:"最近歌单",key:"playlist"},{label:"歌曲历史",key:"song"},{label:"专辑历史",key:"album"},{label:"听歌排行",key:"ranking"}]
                current:page.hudState.profileRecentKind
                onChosen:function(key){page.change("profile:recent-kind:"+key);}
            }
            Column {width:parent.width;spacing:32*page.unit;opacity:contentMotion.progress;enabled:!contentMotion.busy
                transform:Translate {y:contentMotion.offset}
                Repeater {id:sections;model:["created","collected","albums","artists","subscriptions","artistSongs","artistAlbums","legacy"]
                    delegate:Section {required property string modelData;readonly property var spec:page.sectionSpec(modelData);group:modelData;heading:spec.title||"";visible:spec.show===true;list:spec.list===true}
                }
                Button {visible:page.own&&page.overview;label:"＋ 创建歌单";onInvoked:rhine.action("profile:create")}
            }
        }
    }
    Item {x:page.width-24*page.unit;y:reading.y;width:24*page.unit;height:reading.height;HoverHandler {id:edgeHover}}
    RhinePopup {
        id:signatureEditor;objectName:"profileSignatureEditor"
        anchors.centerIn:parent;width:Math.min(page.width-48*page.unit,560*page.unit);height:300*page.unit
        modal:true;focus:true;padding:24*page.unit
        closePolicy:page.hudState.profileSignatureSaving?Controls.Popup.NoAutoClose:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        onOpened:signatureText.forceActiveFocus()
        Connections {target:rhine;function onProfileSignatureSaved(){signatureEditor.close();}}
        contentItem:Column {spacing:14*page.unit
            Label {text:"编辑签名";font.pixelSize:21*page.unit;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold})}
            Controls.TextArea {id:signatureText;objectName:"profileSignatureInput";width:parent.width;height:126*page.unit;wrapMode:TextEdit.Wrap;selectByMouse:true;enabled:!page.hudState.profileSignatureSaving;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:15*page.unit;color:page.ink
                background:Rectangle {color:page.shade;radius:6*page.unit;border.width:signatureText.activeFocus?1:0;border.color:page.accent}
            }
            Label {width:parent.width;text:page.hudState.profileSignatureError||"";color:page.hudState.profileSignatureError?"#b64d51":page.muted;font.pixelSize:12*page.unit}
            Row {spacing:12*page.unit
                Button {label:page.hudState.profileSignatureSaving?"正在保存…":"保存";primary:true;enabled:!page.hudState.profileSignatureSaving;onInvoked:rhine.saveProfileSignature(signatureText.text)}
                Button {label:"取消";enabled:!page.hudState.profileSignatureSaving;onInvoked:signatureEditor.close()}
            }
        }
    }
    RhinePopup {
        id:biography;objectName:"profileBiography";anchors.centerIn:parent;width:Math.min(page.width-48*page.unit,600*page.unit);height:Math.min(page.height-48*page.unit,bioText.implicitHeight+160*page.unit)
        modal:true;focus:true;padding:26*page.unit;closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        enter:Transition {NumberAnimation {property:"opacity";from:0;to:1;duration:page.reduced?0:180}}
        exit:Transition {NumberAnimation {property:"opacity";from:1;to:0;duration:page.reduced?0:130}}
        background:Rectangle {radius:20*page.unit;color:page.dark?"#30382b":"#fafbf5";border.width:1;border.color:page.shade}
        contentItem:Column {spacing:18*page.unit
            Label {text:page.person.nickname||page.person.title||"个人资料";width:parent.width;font.pixelSize:24*page.unit;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold})}
            Flickable {width:parent.width;height:Math.max(0,biography.availableHeight-86*page.unit);contentHeight:bioText.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
                Label {id:bioText;width:parent.width;text:page.person.signature||page.person.description||"暂无简介";wrapMode:Text.Wrap;elide:Text.ElideNone;lineHeight:1.6;font.pixelSize:16*page.unit}
                Controls.ScrollBar.vertical:Controls.ScrollBar {}
            }
            Button {label:"关闭";onInvoked:biography.close()}
        }
    }
}
