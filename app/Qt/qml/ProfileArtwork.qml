import QtQuick

Image {
    id: art
    property string url: ""
    property bool requested: true
    property int attempts: 0
    property bool retrying: false
    readonly property string normalized: rhine.personal.previewCover(url)
    source: requested && !retrying ? normalized : ""
    asynchronous: true
    cache: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: 360
    sourceSize.height: 360
    onNormalizedChanged: { attempts = 0; retry.stop(); retrying = false; }
    onRequestedChanged: if (!requested) retry.stop()
    onStatusChanged: {
        if (status === Image.Ready) { attempts = 0; retry.stop(); }
        else if (status === Image.Error && requested && normalized && attempts < 3) retry.restart();
    }
    Timer {
        id: retry
        interval: 1500 * Math.pow(2, art.attempts)
        onTriggered: {
            if (!art.requested) return;
            ++art.attempts;
            art.retrying = true;
            Qt.callLater(function() { art.retrying = false; });
        }
    }
}
