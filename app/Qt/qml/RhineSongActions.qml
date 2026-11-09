import QtQuick
import QtQuick.Controls.Basic as Controls

Row {
    id:actions
    property string prefix:"song"
    property real iconSize:20
    spacing:4;width:72;height:34
    Controls.AbstractButton {
        id:like;objectName:actions.prefix+"Like";width:34;height:34;hoverEnabled:true
        enabled:!rhine.nowPlaying.info.likeBusy
        Accessible.name:rhine.nowPlaying.info.liked?"取消喜欢":"喜欢"
        onClicked:rhine.action("music:like-current")
        background:Rectangle {radius:17;color:like.hovered||like.visualFocus?"#18ffffff":"transparent"}
        contentItem:Item {RhineIcon {anchors.centerIn:parent;width:actions.iconSize;height:width;name:"cloudyHeart";filled:rhine.nowPlaying.info.liked===true;color:filled?"#ef6575":"#b3ffffff"}}
    }
    Controls.AbstractButton {
        id:more;objectName:actions.prefix+"More";width:34;height:34;hoverEnabled:true;Accessible.name:"更多"
        onClicked:{var p=mapToItem(null,0,height);rhine.magazine.showSongMenu("playing",0,"",p.x,p.y);}
        background:Rectangle {radius:17;color:more.hovered||more.visualFocus?"#18ffffff":"transparent"}
        contentItem:Item {RhineIcon {anchors.centerIn:parent;width:actions.iconSize;height:width;name:"cloudyMore";color:"#b3ffffff"}}
    }
}
