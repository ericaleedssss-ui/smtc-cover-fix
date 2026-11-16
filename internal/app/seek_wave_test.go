package app

import (
	"netease-music-mygo/internal/player"
	"testing"
	"time"
)

// PCM peaks must transition over 120ms, retaining their current height on reversal and settling after pause.
func TestSeekWaveTransition(t *testing.T) {
	var s seekWave
	now := time.Unix(1, 0)
	var levels [player.Bands]float32
	levels[0], levels[1] = 1, .4
	v, _ := s.step(now, levels)
	if v[0] != 0 {
		t.Fatal("peak jumped immediately", v)
	}
	v, _ = s.step(now.Add(60*time.Millisecond), levels)
	if v[0] != .5 || v[1] != .2 {
		t.Fatal("band detail lost", v)
	}
	levels = [player.Bands]float32{}
	v, moving := s.step(now.Add(60*time.Millisecond), levels)
	if v[0] != .5 || !moving {
		t.Fatal("reversal snapped", v)
	}
	v, _ = s.step(now.Add(120*time.Millisecond), levels)
	if v[0] != .25 {
		t.Fatal("release did not interpolate", v)
	}
	v, moving = s.step(now.Add(180*time.Millisecond), levels)
	if v[0] != 0 || moving {
		t.Fatal("paused waveform did not settle", v)
	}
}
