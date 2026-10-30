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

showcase = read("qml/PlaylistShowcase.qml")
assert "wheelCarry-=whole;moveRecord(-whole);" in showcase, "large wheel deltas must preserve every whole navigation step"
assert "pendingMoves+step" in showcase, "navigation input during an animation must accumulate instead of overwrite"
assert "Math.max(-6,Math.min(6,pendingMoves+step))" in showcase, "queued navigation must be bounded"
assert "if(!controller.songs.length)return;" in showcase, "song navigation must tolerate an empty playlist"

print("Interaction state audit regressions passed.")
