import QtQuick

Canvas {
    id:track
    property real fraction:0
    property real unit:1
    property bool dark:false
    property bool active:false
    property bool onGlass:false
    readonly property real featherWidth:Math.min(width*.15,42*unit)
    readonly property real lineThickness:(active?6:2)*unit
    readonly property color playedColor:active?(dark?"#edf2f1ef":"#ed484a49"):(onGlass?(dark?"#b7c9b5a2":"#a56e825f"):(dark?"#ddf5f6f1":"#b56e825f"))
    readonly property color unplayedColor:active?(dark?"#648f938f":"#649b9f9b"):(dark?"#389b9d98":"#24787570")
    onFractionChanged:requestPaint()
    onDarkChanged:requestPaint()
    onActiveChanged:requestPaint()
    onUnitChanged:requestPaint()
    onOnGlassChanged:requestPaint()
    onWidthChanged:requestPaint()
    onHeightChanged:requestPaint()
    onPaint:{
        var c=getContext("2d");c.clearRect(0,0,width,height);
        var fade=Math.min(width*.15,42*unit),thickness=lineThickness,mid=height/2;
        var end=Math.max(0,Math.min(width,width*fraction));
        c.save();
        // Feather vertically into the glass rim; no opaque rectangular rail.
        var halo=c.createLinearGradient(0,mid-4*unit,0,mid+5*unit);
        halo.addColorStop(0,"transparent");halo.addColorStop(.45,dark?"#36d2dfc6":"#246a805e");halo.addColorStop(1,"transparent");
        c.fillStyle=halo;c.fillRect(0,mid-4*unit,width,9*unit);
        c.fillStyle=unplayedColor;c.fillRect(0,mid-thickness/2,width,thickness);
        c.fillStyle=playedColor;c.fillRect(0,mid-thickness/2,end,thickness);
        // Smooth the progress junction as well as both external endpoints.
        if(end>1&&end<width){var join=c.createLinearGradient(Math.max(0,end-5*unit),0,end+5*unit,0);join.addColorStop(0,"transparent");join.addColorStop(.5,dark?"#249b9d98":"#12787570");join.addColorStop(1,"transparent");c.fillStyle=join;c.fillRect(Math.max(0,end-5*unit),mid-thickness/2,10*unit,thickness);}
        c.globalCompositeOperation="destination-in";
        var ends=c.createLinearGradient(0,0,width,0);ends.addColorStop(0,"transparent");ends.addColorStop(fade/Math.max(1,width),"white");ends.addColorStop(1-fade/Math.max(1,width),"white");ends.addColorStop(1,"transparent");c.fillStyle=ends;c.fillRect(0,0,width,height);c.restore();
    }
}
