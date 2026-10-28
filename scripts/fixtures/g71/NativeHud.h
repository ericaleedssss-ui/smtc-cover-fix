#pragma once
#include <QJsonArray>
class NativeHud {public:bool lyricsMode=false,queueCollectionOpen=false;QJsonArray queueCollectionTracks,profileRows,recommendationSongs;quint64 queueCollectionAccount=0;};
