// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy artistLinks layout adapter. RHINE user override: brighten, never underline.
import QtQuick

Item {
    id:line
    property var song:({})
    property bool includeAlbum:true
    property real pixelSize:15
    property color idleColor:"#99ffffff"
    property color hoverColor:"white"
    signal activated(string target)
    readonly property var parts:{
        var result=[],people=song.artists||[];
        if(!people.length)people=[{name:song.artist||""}];
        for(var i=0;i<people.length;++i){
            if(i)result.push({label:", ",target:""});
            result.push({label:String(people[i].name||""),target:people[i].id&&String(people[i].id)!=="0"?"artist:"+encodeURIComponent(people[i].id):""});
        }
        if(includeAlbum&&song.album){result.push({label:" — ",target:""});result.push({label:String(song.album),target:song.albumID&&String(song.albumID)!=="0"?"album":""});}
        return result;
    }
    implicitHeight:pixelSize*1.4
    implicitWidth:measurement.advanceWidth
    TextMetrics {id:measurement;text:line.parts.map(function(part){return part.label;}).join("");font.family:rhineFontFamily;font.pixelSize:line.pixelSize;font.variableAxes:({"wght":400})}
    clip:true
    function offset(index){var x=0;for(var i=0;i<index;++i){var part=labels.itemAt(i);if(part)x+=part.implicitWidth;}return x;}
    Repeater {id:labels;model:line.parts
        Text {
            id:caption
            required property var modelData
            required property int index
            objectName:"creditPart_"+index
            x:line.offset(index);width:Math.min(implicitWidth,Math.max(0,line.width-x));height:line.height
            text:modelData.label;textFormat:Text.PlainText;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter
            font.family:rhineFontFamily;font.pixelSize:line.pixelSize;font.variableAxes:({"wght":400});font.underline:false
            color:hit.containsMouse&&!!modelData.target?line.hoverColor:line.idleColor
            Behavior on color {ColorAnimation {duration:RhineTheme.noMotion?0:120}}
            Accessible.role:Accessible.Link;Accessible.name:text
            Accessible.onPressAction:if(modelData.target)line.activated(modelData.target)
            MouseArea {id:hit;anchors.fill:parent;hoverEnabled:true;enabled:!!caption.modelData.target;cursorShape:Qt.PointingHandCursor;onClicked:line.activated(caption.modelData.target)}
        }
    }
}
