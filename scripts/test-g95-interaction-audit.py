#!/usr/bin/env python3
"""Source-level regression guards for the maintained Qt interaction fixes."""
from pathlib import Path
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--source", type=Path, required=True, help="maintained/Qt source directory")
args = parser.parse_args()
root = args.source

def read(path):
    return (root / path).read_text(encoding="utf-8")

panel = read("qml/NowPlayingPanel.qml")
assert "Qt.callLater(follow)" not in panel, "lyric follow must not reschedule itself without a bound"
assert "positionViewAtIndex(playback.index,ListView.Contain)" in panel, "virtualized lyric target must be brought into the view"
assert "lyricFollowRetryScheduled" in panel, "lyric follow retry must be guarded"
assert "playback.index>=lyrics.count" in panel, "stale lyric indices must be ignored"

stack = read("qml/RecordStack.qml")
assert "Math.min(1,groupPreload.count)" not in stack, "group preload must inspect every incoming cover"
assert "i<groupPreload.count" in stack, "group preload must cover the complete incoming set"
assert "img.status===Image.Loading||img.status===Image.Null" in stack, "loading covers must delay the transition"

marquee = read("qml/PlayerTitleMarquee.qml")
pan = marquee.index("id: pan")
running_handler = marquee.find("onRunningChanged:", pan)
first_pause = marquee.find("PauseAnimation", pan)
assert running_handler != -1 and first_pause != -1 and running_handler < first_pause, "marquee stop handler must belong to its animation"
assert "if (!running) viewport.shift = 0" in marquee, "stopped marquee must return to a stable offset"

header = read("src/NowPlaying.h")
cpp = read("src/NowPlaying.cpp")
assert "m_coverRequest" in header and "m_avatarRequest" in header, "cover/avatar requests need independent identities"
assert "self->m_coverRequest!=request" in cpp and 'self->m_track["cover"].toString()!=url' in cpp, "stale cover callback must not overwrite current artwork"
assert "self->m_avatarRequest!=request" in cpp and "self->m_artistID!=artistID" in cpp, "stale avatar callback must not overwrite current artist"
assert "self->m_artistID==artistID" in cpp, "artist API response must be bound to the requested artist"

magazine = read("src/PlaylistMagazine.cpp")
assert "if(reset){m_socialOffset=0;m_socialTotal=0;m_social={};}" in magazine, "social pagination total must reset with its rows"

showcase_cpp = read("src/PlaylistShowcase.cpp")
showcase_h = read("src/PlaylistShowcase.h")
assert "m_identityRequest" in showcase_h and "m_identityKey" in showcase_h, "playlist identity artwork needs its own request identity"
assert "self->m_identityRequest!=request" in showcase_cpp and "self->m_identityKey!=cacheKey" in showcase_cpp, "stale playlist avatar callbacks must be rejected"
assert "m_identityKey=cacheKey;++m_identityRequest;m_identityPending=false" in showcase_cpp, "a changed playlist artist/user must invalidate prior identity work"
assert "m_previewPendingIndex" in showcase_h and "m_previewBatchStart" in showcase_h, "playlist preview must track one queued latest batch"
assert "m_previewPendingIndex=batchStart==m_previewBatchStart?-1:at;" in showcase_cpp, "preview requests must coalesce to the latest batch"
assert "if(pending>=0)self->preview(pending);" in showcase_cpp, "the latest selected preview must load after the current request"

showcase = read("qml/PlaylistShowcase.qml")
assert "wheelCarry-=whole;moveRecord(-whole);" in showcase, "large wheel deltas must preserve every whole navigation step"
assert "pendingMoves+step" in showcase, "navigation input during an animation must accumulate instead of overwrite"
assert "Math.max(-6,Math.min(6,pendingMoves+step))" in showcase, "queued navigation must be bounded"
assert "pendingUntil=Date.now()+5000" in showcase, "queued turns must survive a short sequence of animations"
assert "pendingMoves=0;wheelCarry=0;pendingUntil=0" in showcase, "queued navigation must not leak into a different playlist"
assert "if(!controller.songs.length)return;" in showcase, "song navigation must tolerate an empty playlist"

queue = read("qml/PlayerQueueGlass.qml")
assert "onPageStartChanged: syncRows()" in queue, "queue page changes must reset the list viewport even if row data is identical"
assert "var pageChanged = syncedPage !== pageStart;" in queue and "if (!rowsChanged && !pageChanged) return;" in queue, "queue synchronization must compare page identity separately from row content"

print("Interaction state audit regressions passed.")
