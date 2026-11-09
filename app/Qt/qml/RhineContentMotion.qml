import QtQuick

// Cloudy ui_expand.go motionPane: 280 ms, cubic-bezier(.22,.8,.24,1).
// Preparation never steals the outgoing frame; reveal only after it is ready.
Item {
    id: motion
    property bool noMotion: RhineTheme.noMotion
    property bool fullMotion: RhineTheme.fullMotion
    property real progress: 1
    property real distance: 8
    property real side: -1
    readonly property real offset: fullMotion ? side * distance * (1-progress) : 0
    property bool ready: true
    property bool waiting: false
    readonly property bool busy: waiting || outgoing.running || incoming.running
    property var pending: null
    function run(action) {
        pending=action;
        if(outgoing.running)return;
        incoming.stop();
        if(!ready){waiting=true;return;}
        begin();
    }
    function begin() {
        waiting=false;
        if(noMotion){finish();return;}
        side=-1;outgoing.restart();
    }
    function finish() {
        waiting=false;outgoing.stop();incoming.stop();
        var action=pending;pending=null;
        if(action)action();
        progress=1;
    }
    onReadyChanged:if(ready&&waiting)begin()
    onNoMotionChanged:if(noMotion&&ready)finish()
    NumberAnimation {
        id:outgoing;target:motion;property:"progress";to:0;duration:100;easing.type:Easing.InCubic
        onFinished:{if(!motion.ready){motion.waiting=true;return;}var action=motion.pending;motion.pending=null;if(action)action();motion.side=1;incoming.restart();}
    }
    NumberAnimation {id:incoming;target:motion;property:"progress";from:0;to:1;duration:280;easing.type:Easing.BezierSpline;easing.bezierCurve:[.22,.8,.24,1,1,1]}
}
