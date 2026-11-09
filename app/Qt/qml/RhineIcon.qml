import QtQuick
import QtQuick.Shapes
Item {
    id: icon
    property string name: "more"
    property bool filled:false
    readonly property bool solidGlyph:["settings","history","folder","comment"].indexOf(name)>=0
    property color color: "#50594b"
    width:24; height:24
    // Unchanged SVG markup from Cloudy icons.go, scoped to source-port surfaces.
    readonly property var originals: ({
        cloudyWand:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72\" /><path d=\"m14 7 3 3\" /><path d=\"M5 6v4\" /><path d=\"M19 14v4\" /><path d=\"M10 2v2\" /><path d=\"M7 8H3\" /><path d=\"M21 16h-4\" /><path d=\"M11 3H9\" /></svg>",
        cloudyParty:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M5.8 11.3 2 22l10.7-3.79\" /><path d=\"M4 3h.01\" /><path d=\"M22 8h.01\" /><path d=\"M15 2h.01\" /><path d=\"M22 20h.01\" /><path d=\"m22 2-2.24.75a2.9 2.9 0 0 0-1.96 3.12c.1.86-.57 1.63-1.45 1.63h-.38c-.86 0-1.6.6-1.76 1.44L14 10\" /><path d=\"m22 13-.82-.33c-.86-.34-1.82.2-1.98 1.11c-.11.7-.72 1.22-1.43 1.22H17\" /><path d=\"m11 2 .33.82c.34.86-.2 1.82-1.11 1.98C9.52 4.9 9 5.52 9 6.23V7\" /><path d=\"M11 13c1.93 1.93 2.83 4.17 2 5-.83.83-3.07-.07-5-2-1.93-1.93-2.83-4.17-2-5 .83-.83 3.07.07 5 2Z\" /></svg>",
        cloudyGuitar:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"m11.9 12.1 4.514-4.514\" /><path d=\"M20.1 2.3a1 1 0 0 0-1.4 0l-1.114 1.114A2 2 0 0 0 17 4.828v1.344a2 2 0 0 1-.586 1.414A2 2 0 0 1 17.828 7h1.344a2 2 0 0 0 1.414-.586L21.7 5.3a1 1 0 0 0 0-1.4z\" /><path d=\"m6 16 2 2\" /><path d=\"M8.2 9.9C8.7 8.8 9.8 8 11 8c2.8 0 5 2.2 5 5 0 1.2-.8 2.3-1.9 2.8l-.9.4A2 2 0 0 0 12 18a4 4 0 0 1-4 4c-3.3 0-6-2.7-6-6a4 4 0 0 1 4-4 2 2 0 0 0 1.8-1.2z\" /><circle cx=\"11.5\" cy=\"12.5\" r=\".5\" fill=\"currentColor\" /></svg>",
        cloudyWine:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M8 22h8\" /><path d=\"M7 10h10\" /><path d=\"M12 15v7\" /><path d=\"M12 15a5 5 0 0 0 5-5c0-2-.5-4-2-8H9c-1.5 4-2 6-2 8a5 5 0 0 0 5 5Z\" /></svg>",
        cloudyPiano:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M18.5 8c-1.4 0-2.6-.8-3.2-2A6.87 6.87 0 0 0 2 9v11a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-8.5C22 9.6 20.4 8 18.5 8\" /><path d=\"M2 14h20\" /><path d=\"M6 14v4\" /><path d=\"M10 14v4\" /><path d=\"M14 14v4\" /><path d=\"M18 14v4\" /></svg>",
        cloudyZap:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z\" /></svg>",
        cloudyMicVocal:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"m11 7.601-5.994 8.19a1 1 0 0 0 .1 1.298l.817.818a1 1 0 0 0 1.314.087L15.09 12\" /><path d=\"M16.5 21.174C15.5 20.5 14.372 20 13 20c-2.058 0-3.928 2.356-6 2-2.072-.356-2.775-3.369-1.5-4.5\" /><circle cx=\"16\" cy=\"7\" r=\"5\" /></svg>",
        cloudyDisc:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"M6 12c0-1.7.7-3.2 1.8-4.2\" /><circle cx=\"12\" cy=\"12\" r=\"2\" /><path d=\"M18 12c0 1.7-.7 3.2-1.8 4.2\" /></svg>",
        cloudyMoonStar:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9\" /><path d=\"M20 3v4\" /><path d=\"M22 5h-4\" /></svg>",
        cloudyFan:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M10.827 16.379a6.082 6.082 0 0 1-8.618-7.002l5.412 1.45a6.082 6.082 0 0 1 7.002-8.618l-1.45 5.412a6.082 6.082 0 0 1 8.618 7.002l-5.412-1.45a6.082 6.082 0 0 1-7.002 8.618l1.45-5.412Z\" /><path d=\"M12 12v.01\" /></svg>",
        cloudyGlobe:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20\" /><path d=\"M2 12h20\" /></svg>",
        cloudyReload:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M20 7v5h-5\"/><path d=\"M20 12a8 8 0 1 0-2.3 5.7\"/></svg>",
        userRanking:"<svg t=\"1794152823721\" class=\"icon\" viewBox=\"0 0 1024 1024\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\" p-id=\"5460\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"200\" height=\"200\"><path d=\"M821.555 0H1024v1023.949H821.555z m-274.79 551.885h201.984v472.064H546.765zM269.67 267.725h208.948v756.224H269.67zM0 749.158h199.22v274.79H0z\" fill=\"currentColor\" p-id=\"5461\"></path></svg>",
        cloudyClose:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M18 6 6 18\"/><path d=\"m6 6 12 12\"/></svg>",
        cloudyTrash:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M3 6h18\"/><path d=\"M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6\"/><path d=\"M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2\"/></svg>",
        cloudyHeart:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7z\"/></svg>",
        cloudyHeartFill:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"currentColor\"><path d=\"M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7z\"/></svg>",
        cloudyUpDown:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"m7 15 5 5 5-5\"/><path d=\"m7 9 5-5 5 5\"/></svg>",
        cloudyHeadset:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3\"/></svg>",
        cloudyPlay:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"currentColor\"><path d=\"M7 4.6v14.8c0 .8.9 1.3 1.6.9l12-7.4c.6-.4.6-1.3 0-1.7l-12-7.4C7.9 3.3 7 3.8 7 4.6z\"/></svg>",
        cloudyPause:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"currentColor\"><rect x=\"5.5\" y=\"4\" width=\"4.5\" height=\"16\" rx=\"1.4\"/><rect x=\"14\" y=\"4\" width=\"4.5\" height=\"16\" rx=\"1.4\"/></svg>",
        cloudyNext:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"currentColor\"><path d=\"M3 5.6v12.8c0 .8.9 1.3 1.6.8l9.4-6.4c.6-.4.6-1.2 0-1.6L4.6 4.8C3.9 4.3 3 4.8 3 5.6z\"/><path d=\"M12 5.6v12.8c0 .8.9 1.3 1.6.8l9.4-6.4c.6-.4.6-1.2 0-1.6l-9.4-6.4c-.7-.5-1.6 0-1.6.8z\" transform=\"translate(-1.5 0)\"/></svg>",
        cloudyPrev:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"currentColor\"><g transform=\"matrix(-1 0 0 1 24 0)\"><path d=\"M3 5.6v12.8c0 .8.9 1.3 1.6.8l9.4-6.4c.6-.4.6-1.2 0-1.6L4.6 4.8C3.9 4.3 3 4.8 3 5.6z\"/><path d=\"M12 5.6v12.8c0 .8.9 1.3 1.6.8l9.4-6.4c.6-.4.6-1.2 0-1.6l-9.4-6.4c-.7-.5-1.6 0-1.6.8z\" transform=\"translate(-1.5 0)\"/></g></svg>",
        cloudyShuffle:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M2 18h1.4c1.3 0 2.5-.6 3.3-1.7l6.1-8.6c.8-1.1 2-1.7 3.3-1.7H22\"/><path d=\"m18 2 4 4-4 4\"/><path d=\"M2 6h1.9c1.5 0 2.9.9 3.6 2.2\"/><path d=\"M22 18h-5.9c-1.3 0-2.6-.7-3.3-1.8l-.5-.8\"/><path d=\"m18 14 4 4-4 4\"/></svg>",
        cloudyRepeat:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"m17 2 4 4-4 4\"/><path d=\"M3 11v-1a4 4 0 0 1 4-4h14\"/><path d=\"m7 22-4-4 4-4\"/><path d=\"M21 13v1a4 4 0 0 1-4 4H3\"/></svg>",
        cloudyRepeat1:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"m17 2 4 4-4 4\"/><path d=\"M3 11v-1a4 4 0 0 1 4-4h14\"/><path d=\"m7 22-4-4 4-4\"/><path d=\"M21 13v1a4 4 0 0 1-4 4H3\"/><path d=\"M11 10h1v4\"/></svg>",
        cloudyVolume:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M11 4.7a.7.7 0 0 0-1.2-.5L6.4 7.6A1.4 1.4 0 0 1 5.4 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.4a1.4 1.4 0 0 1 1 .4l3.4 3.4a.7.7 0 0 0 1.2-.5z\"/><path d=\"M16 9a5 5 0 0 1 0 6\"/><path d=\"M19.4 18.4a9 9 0 0 0 0-12.8\"/></svg>",
        cloudyMute:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M11 4.7a.7.7 0 0 0-1.2-.5L6.4 7.6A1.4 1.4 0 0 1 5.4 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.4a1.4 1.4 0 0 1 1 .4l3.4 3.4a.7.7 0 0 0 1.2-.5z\"/><line x1=\"22\" x2=\"16\" y1=\"9\" y2=\"15\"/><line x1=\"16\" x2=\"22\" y1=\"9\" y2=\"15\"/></svg>",
        cloudyDown:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"m6 9 6 6 6-6\"/></svg>",
        cloudyUser:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"8\" r=\"4\"/><path d=\"M4 21a8 8 0 0 1 16 0\"/></svg>",
        cloudyDownload:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M12 3v10\"/><path d=\"m7.5 8.5 4.5 4.5 4.5-4.5\"/><path d=\"M4 15v4a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4\"/></svg>",
        cloudyCopy:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"9\" y=\"9\" width=\"12\" height=\"12\" rx=\"2\"/><path d=\"M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1\"/></svg>",
        cloudyLink:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7\"/><path d=\"M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7\"/></svg>",
        cloudyMore:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"currentColor\"><circle cx=\"5\" cy=\"12\" r=\"1.9\"/><circle cx=\"12\" cy=\"12\" r=\"1.9\"/><circle cx=\"19\" cy=\"12\" r=\"1.9\"/></svg>",
        cloudyAlbum:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"9.5\"/><circle cx=\"12\" cy=\"12\" r=\"2.5\"/></svg>",
        cloudySettings:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z\"/><circle cx=\"12\" cy=\"12\" r=\"3\"/></svg>",
        cloudyThumb:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M7 10v12\"/><path d=\"M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h2.76a2 2 0 0 0 1.79-1.11L12 2a3.13 3.13 0 0 1 3 3.88Z\"/></svg>",
        cloudyBack:"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"m15 18-6-6 6-6\"/></svg>"
    })
    readonly property string originalSvg:originals[name==="cloudyHeart"&&filled?"cloudyHeartFill":name]||""
    Image {anchors.fill:parent;visible:!!icon.originalSvg;source:visible?"data:image/svg+xml;utf8,"+encodeURIComponent(icon.originalSvg.replace(/currentColor/g,"rgb("+Math.round(icon.color.r*255)+","+Math.round(icon.color.g*255)+","+Math.round(icon.color.b*255)+")")):"";sourceSize:Qt.size(Math.max(24,width*2),Math.max(24,height*2));opacity:icon.color.a;smooth:true}
    readonly property var paths: ({
        user:"M 12 12 A 4 4 0 1 0 12 4 A 4 4 0 1 0 12 12 M 4 22 V 20 A 8 8 0 0 1 20 20 V 22",
        history:"M 4.3 17.9 A 10.5 10.5 0 1 1 8.5 22 A 1.05 1.05 0 0 1 9.2 20 A 8.4 8.4 0 1 0 5.9 16.7 A 1.05 1.05 0 0 1 4.3 17.9 Z M 11 5.5 A 1 1 0 0 1 13 5.5 V 11 H 17 A 1 1 0 0 1 17 13 H 12 A 1 1 0 0 1 11 12 Z",
        folder:"M 3 4 H 9.3 Q 10 4 10.5 4.6 L 12.5 7 H 21 Q 23 7 23 9 V 20 Q 23 22 21 22 H 3 Q 1 22 1 20 V 6 Q 1 4 3 4 Z M 3.2 6.2 V 19.8 H 20.8 V 9.2 H 11.5 L 9 6.2 Z",
        crown:"M 3 6 L 7 10 L 12 4 L 17 10 L 21 6 L 19 20 H 5 Z",
        logout:"M 10 3 H 5 Q 3 3 3 5 V 19 Q 3 21 5 21 H 10 M 9 12 H 22 M 17 7 L 22 12 L 17 17",
        switchAccount:"M 3 7 H 20 M 16 3 L 20 7 L 16 11 M 21 17 H 4 M 8 13 L 4 17 L 8 21",
        disc:"M 12 2 A 10 10 0 1 0 12 22 A 10 10 0 1 0 12 2 M 12 9 A 3 3 0 1 0 12 15 A 3 3 0 1 0 12 9",
        chevron:"M 5 9 L 12 16 L 19 9",
        message:"M 3 5 H 21 V 20 H 3 Z M 3 5 L 12 13 L 21 5",
        search:"M 10.5 3 A 7.5 7.5 0 1 0 10.5 18 A 7.5 7.5 0 1 0 10.5 3 M 16 16 L 22 22",
        music:"M 9 18 V 5 L 21 3 V 16 M 9 7 L 21 5 M 9 18 C 9 22 2 23 2 19 C 2 15 9 15 9 18 M 21 16 C 21 20 14 21 14 17 C 14 13 21 13 21 16",
        settings:"M 11 1.4 Q 12 .8 13 1.4 L 21 6 Q 22 6.6 22 7.8 V 17 Q 22 18.2 21 18.8 L 13 23 Q 12 23.6 11 23 L 3 18.5 Q 2 18 2 16.8 V 7.8 Q 2 6.6 3 6 Z M 12 3.8 L 4.3 8.2 V 16.4 L 12 20.8 L 19.7 16.4 V 8.2 Z M 12 7 A 5 5 0 1 1 12 17 A 5 5 0 1 1 12 7 Z M 12 9.3 A 2.7 2.7 0 1 0 12 14.7 A 2.7 2.7 0 1 0 12 9.3 Z",
        back:"M 14 5 L 7 12 L 14 19 M 7 12 H 22",
        play:"M 7 3 L 21 12 L 7 21 Z",
        previousTrack:"M 5 4 V 20 M 19 4 L 8 12 L 19 20 Z",
        nextTrack:"M 19 4 V 20 M 5 4 L 16 12 L 5 20 Z",
        shuffle:"M 18 14 L 22 18 L 18 22 M 18 2 L 22 6 L 18 10 M 2 18 H 4.5 C 10 18 14 6 19.5 6 H 22 M 2 6 H 4.5 C 7 6 8.5 8 10 10 M 14 14 C 15.5 16 17 18 19.5 18 H 22",
        repeat:"M 17 2 L 21 6 L 17 10 M 21 6 H 7 A 4 4 0 0 0 3 10 M 7 22 L 3 18 L 7 14 M 3 18 H 17 A 4 4 0 0 0 21 14",
        repeatOne:"M 17 2 L 21 6 L 17 10 M 21 6 H 7 A 4 4 0 0 0 3 10 M 7 22 L 3 18 L 7 14 M 3 18 H 17 A 4 4 0 0 0 21 14 M 10 10 L 12 9 V 15 M 10 15 H 14",
        pause:"M 8 4 V 20 M 16 4 V 20",
        volume:"M 11 5 L 6 9 H 3 V 15 H 6 L 11 19 Z M 15 8 A 6 6 0 0 1 15 16 M 18 4 A 11 11 0 0 1 18 20",
        mute:"M 11 5 L 6 9 H 3 V 15 H 6 L 11 19 Z M 16 9 L 22 15 M 22 9 L 16 15",
        next:"M 3 5 H 15 M 3 11 H 12 M 3 17 H 10 M 19 12 V 22 M 14 17 H 24",
        comment:"M 4 2 H 20 Q 22 2 22 4 V 16 Q 22 18 20 18 H 10 L 4 23 V 18 H 3 Q 1 18 1 16 V 4 Q 1 2 4 2 Z M 3.3 4.3 V 15.7 H 6.3 V 18.2 L 9.2 15.7 H 19.7 V 4.3 Z M 6 7 H 17 V 9 H 6 Z M 6 11 H 14 V 13 H 6 Z",
        collect:"M 4 5 H 10 L 13 8 H 22 V 21 H 3 V 5 Z M 12 11 V 18 M 8.5 14.5 H 15.5",
        download:"M 12 2 V 16 M 6 10 L 12 16 L 18 10 M 3 17 V 22 H 21 V 17",
        share:"M 14 3 H 22 V 11 M 22 3 L 10 15 M 9 5 H 3 V 22 H 20 V 15",
        link:"M 10 15 L 15 10 M 8 12 L 5 15 C 0 20 5 25 10 20 L 13 17 M 12 8 L 15 5 C 20 0 25 5 20 10 L 17 13",
        remove:"M 3 6 H 21 M 9 6 V 2 H 15 V 6 M 6 6 L 7 22 H 17 L 18 6 M 10 10 V 18 M 14 10 V 18",
        heart:"M 12 21 C 7 17 2 13 2 7 C 2 1 9 0 12 6 C 15 0 22 1 22 7 C 22 13 17 17 12 21 Z",
        // Cloudy icons.go, unchanged iconHeart/iconHeartFill path (AGPL-3.0-only).
        cloudyHeart:"M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7z",
        cloudyCopy:"M11 9h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-8a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2z M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1",
        cloudyNext:"M3 5.6v12.8c0 .8.9 1.3 1.6.8l9.4-6.4c.6-.4.6-1.2 0-1.6L4.6 4.8C3.9 4.3 3 4.8 3 5.6z M10.5 5.6v12.8c0 .8.9 1.3 1.6.8l9.4-6.4c.6-.4.6-1.2 0-1.6l-9.4-6.4c-.7-.5-1.6 0-1.6.8z",
        cloudySettings:"M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z M15 12a3 3 0 1 0-6 0a3 3 0 1 0 6 0",
        cloudyWave:"M2 13a2 2 0 0 0 2-2V7a2 2 0 0 1 4 0v13a2 2 0 0 0 4 0V4a2 2 0 0 1 4 0v13a2 2 0 0 0 4 0v-4a2 2 0 0 1 2-2",
        cloudyThumb:"M7 10v12 M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H3V10h4l5-8a3.13 3.13 0 0 1 3 3.88z",
        cloudyAdd:"M12 5v14 M5 12h14",
        filter:"M 2 4 H 22 L 15 12 V 21 L 9 18 V 12 Z",
        batch:"M 3 5 H 21 M 3 12 H 12 M 3 19 H 10 M 15 17 L 18 20 L 23 14",
        check:"M 3 12 L 9 18 L 22 4",
        locate:"M 12 2 V 5 M 12 19 V 22 M 2 12 H 5 M 19 12 H 22 M 12 5 A 7 7 0 1 0 12 19 A 7 7 0 1 0 12 5 M 12 10 A 2 2 0 1 0 12 14 A 2 2 0 1 0 12 10",
        close:"M 5 5 L 19 19 M 19 5 L 5 19",
        more:"M 3 12 H 4 M 11.5 12 H 12.5 M 20 12 H 21"
    })
    Shape {
        visible:!icon.originals[icon.name]
        width:24; height:24; scale:Math.min(icon.width,icon.height)/24; transformOrigin:Item.TopLeft
        ShapePath {
            strokeColor:icon.solidGlyph||icon.name==="cloudyNext"||(icon.name==="cloudyHeart"&&icon.filled)?"transparent":icon.color; strokeWidth:icon.name.startsWith("cloudy")?1.75:1.65; capStyle:ShapePath.RoundCap; joinStyle:ShapePath.RoundJoin
            fillRule:ShapePath.OddEvenFill
            fillColor:(icon.solidGlyph || icon.name==="play" || icon.name==="cloudyNext" || icon.filled) ? icon.color : "transparent"
            PathSvg { path:icon.paths[icon.name] || icon.paths.more }
        }
    }
}
