"""Preserve the former workflow's scrobble/private-FM source assertions."""
from pathlib import Path

APP = Path(__file__).resolve().parents[1] / 'app'
p = (APP / 'Qt/src/MusicPlayer.cpp').read_text(encoding='utf-8')
h = (APP / 'Qt/src/MusicPlayer.h').read_text(encoding='utf-8')
bridge = (APP / 'MusicBridge/worker.cjs').read_text(encoding='utf-8')
assert 'void MusicPlayer::updateScrobble(' in p
assert 'm_scrobbleAttempted = true;' in p
assert 'state["buffering"].toBool()' in p
assert 'scrobbleAccountId' in h
assert "'/scrobble': 'scrobble'" in bridge
assert "'/personal/fm/mode': 'personal_fm_mode'" in bridge
assert 'route = "/simi/song";' not in (APP / 'Qt/src/MusicDiscover.cpp').read_text(encoding='utf-8')
print('Validated real-playback scrobbles and private FM endpoint.')
