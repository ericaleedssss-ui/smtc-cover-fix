package player

import (
	"testing"
	"time"
)

// Playback sampling excludes seeks, pauses and suspended clock intervals.
func TestConfirmedListening(t *testing.T) {
	for _, tc := range []struct{ wall, movement, want int }{
		{500, 500, 500}, {500, 250, 250}, {500, 540, 500},
		{500, 0, 0}, {500, -50, 0}, {500, 5000, 0}, {2500, 2500, 0},
	} {
		got := confirmedListening(time.Duration(tc.wall)*time.Millisecond, time.Duration(tc.movement)*time.Millisecond)
		if got.Milliseconds() != int64(tc.want) {
			t.Errorf("confirmedListening(%d, %d) = %v, want %d ms", tc.wall, tc.movement, got, tc.want)
		}
	}
}
