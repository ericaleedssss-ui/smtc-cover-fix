package app

import (
	"testing"
	"time"

	"github.com/egoist/mygo/ui"

	"netease-music-mygo/internal/lyrics"
	"netease-music-mygo/internal/netease"
)

// playingApp is an app playing a track with lyrics, at a position the test
// sets with pl.Seek, and the number of times its view was built.
func playingApp() (*app, *ui.Tester, *int) {
	a := newTestApp()
	a.settings = defaultSettings()
	tr := netease.Track{ID: 7, Name: "宝船", Artists: []netease.Artist{{Name: "DOUDOU"}}, Duration: 200000}
	a.pl.Cue([]netease.Track{tr})
	// A line every 10 seconds, sung over the first 5 of them.
	var lrc string
	for i := range 12 {
		lrc += "[0" + string(rune('0'+i*10/60)) + ":" + string(rune('0'+i*10%60/10)) + "0.00]一二三四五六\n"
	}
	lines := lyrics.Build(lrc, "", "")
	for i := range lines {
		l := &lines[i]
		l.End = l.At + 5*time.Second
		l.Words = lyrics.SpreadWords(l.Text, l.At, l.End)
	}
	a.pl.SetLyrics(lines)
	a.pl.Hold(0)
	builds := 0
	tt := ui.NewTester(func(c *ui.Context) { builds++; a.view(c) }, 1200, 800)
	return a, tt, &builds
}

// framesAt counts the frames the view asks for over a second, at 60 a
// second, with playback held at pos.
func framesAt(a *app, tt *ui.Tester, pos time.Duration) int {
	a.pl.Seek(pos)
	tt.Frame()
	tt.Advance(time.Second)
	tt.Frame()
	asked := 0
	for range 60 {
		tt.Advance(time.Second / 60)
		if tt.FramePending() {
			asked++
			tt.Frame()
		}
	}
	return asked
}

// The bar's cover turning asks for a few frames a second, which only paint it:
// the view isn't built for it, as a pose at the display's rate would have the
// window painted, for what doesn't change.
func TestBarDiscFrames(t *testing.T) {
	a, tt, builds := playingApp()
	a.pl.TogglePlay()
	tt.Frame()
	if !a.pl.Playing() {
		t.Skip("the fixture doesn't play")
	}
	tt.Advance(time.Second)
	tt.Frame()
	was := *builds
	if n := framesAt(a, tt, 12*time.Second); n > 16 {
		t.Errorf("it asks for %d frames a second", n)
	}
	if n := *builds - was; n > 4 {
		t.Errorf("it built the view %d times", n)
	}
}

// Now Playing asks for frames only as fast as what it shows changes. The
// Tester runs timers as it settles a frame, so this counts only what does
// not change for a while: a frame log of the app (MYGO_FRAME_STATS) measures
// the rest.
func TestNowPlayingFrameBudget(t *testing.T) {
	a, tt, _ := playingApp()
	a.settings.BarSpin = false
	if n := framesAt(a, tt, 12*time.Second); n > 3 {
		t.Errorf("a page under the player: %d frames a second", n)
	}
	// Its rows still, the wall asks for no more than the lyrics beside it
	// do: it moves only as it is moved.
	tt.SetPreferences(ui.Preferences{ReduceMotion: true})
	a.nowPlaying, a.npPane = true, paneLyrics
	lyricsFrames := framesAt(a, tt, 12*time.Second)
	a.npPane = paneWall
	if n := framesAt(a, tt, 12*time.Second); n > lyricsFrames+3 {
		t.Errorf("the wall, still: %d frames a second, the lyrics %d", n, lyricsFrames)
	}
	tt.SetPreferences(ui.Preferences{})
	a.npPane = paneStage
	a.settings.StageSparks = true
	for _, s := range stageStyles {
		a.settings.StageStyle = s.id
		if n := framesAt(a, tt, 18*time.Second); n > 12 {
			t.Errorf("the stage between lines, in %s: %d frames a second", s.label, n)
		}
	}
}

// A paused Now Playing tab transition requests frames only while it runs.
func TestNowPlayingTabSettles(t *testing.T) {
	a, tt, _ := playingApp()
	a.settings.Fog = false
	a.nowPlaying = true
	tt.Frame()
	tt.Advance(time.Second)
	tt.Frame()
	a.choosePane(paneQueue)
	tt.Frame()
	if a.npPaneAt.IsZero() || !tt.FramePending() {
		t.Fatal("tab content did not start its transition")
	}
	tt.Advance(2 * time.Second)
	tt.Frame()
	tt.Advance(100 * time.Millisecond)
	if tt.FramePending() {
		t.Fatal("settled tab still requests frames")
	}
}

// Another song's backdrop fades in over the last one's, which is then let
// go, so that the backdrop stops asking for frames.
func TestBackdropFadeEnds(t *testing.T) {
	a, tt, _ := coverApp(t)
	a.art.art[netease.Sized("a", 600)+"#backdrop"] = &artwork{tint: ui.RGB(200, 40, 40)}
	a.art.art[netease.Sized("b", 600)+"#backdrop"] = &artwork{tint: ui.RGB(40, 40, 200)}
	q := a.pl.Queue()
	q[1].Album.PicURL, q[2].Album.PicURL = "a", "b"
	tt.Frame()
	a.pl.Next()
	tt.Frame()
	if a.backdropCache.before == nil {
		t.Fatal("the backdrop changed songs without fading")
	}
	tt.Advance(backdropFade + 100*time.Millisecond)
	tt.Frame()
	if a.backdropCache.before != nil {
		t.Error("the last song's backdrop still fades after the fade")
	}
}

// The FM stack stops requesting frames after its covers have changed places.
func TestFMCoverRestFrames(t *testing.T) {
	a := newTestApp()
	a.pl.Cue([]netease.Track{{ID: 1}, {ID: 2}, {ID: 3}})
	a.pl.AttachRadio(fmRadio(netease.FMDefault), func(func([]netease.Track)) {})
	tt := ui.NewTester(func(c *ui.Context) { a.fmCovers(c, a.pl.Current()) }, 360, 300)
	tt.Frame()
	a.pl.Next()
	tt.Frame()
	tt.Advance(3 * time.Second)
	tt.Frame()
	for range 10 {
		tt.Advance(100 * time.Millisecond)
		if tt.FramePending() {
			t.Fatal("the resting FM stack still asks for frames")
		}
	}
}

// The category capsule asks for no frames once it has reached its selected label.
func TestPlaylistFilterRestFrames(t *testing.T) {
	a := newTestApp()
	a.settings = defaultSettings()
	a.motion = motionFull
	a.featured = []netease.Playlist{{ID: 1}}
	tt := ui.NewTester(func(c *ui.Context) {
		a.pal = paletteFor(c.Theme())
		a.recommendedPlaylists(c)
	}, 1180, 700)
	tt.Frame()
	tt.Frame()
	tt.Advance(3 * time.Second)
	tt.Frame()
	for range 10 {
		tt.Advance(100 * time.Millisecond)
		if tt.FramePending() {
			t.Fatal("the settled category capsule still asks for frames")
		}
	}
}

// The home cards and listening memo stop requesting frames once settled.
func TestHomeMemoRestFrames(t *testing.T) {
	a := homeFixture(t)
	tt := ui.NewTester(a.view, 1280, 1100)
	tt.Frame()
	tt.Advance(3 * time.Second)
	tt.Frame()
	for range 10 {
		tt.Advance(100 * time.Millisecond)
		if tt.FramePending() {
			t.Fatal("the settled home page asks for another frame")
		}
	}
}

// The playlist's glass and sticky header request no frames when the page is
// still, including after scrolling with the current track held in view.
func TestPlaylistDetailRestFrames(t *testing.T) {
	a := playlistDetailFixture()
	a.pl.Cue(a.playlists[42].Tracks[8:])
	tt := ui.NewTester(a.view, 1280, 960)
	tt.Frame()
	for _, scrolled := range []bool{false, true} {
		if scrolled {
			tt.Wheel(700, 500, 0, 315)
		}
		tt.Advance(time.Second)
		tt.Frame()
		_, sticky := tt.Find("回到歌单开头")
		if sticky != scrolled {
			t.Fatalf("sticky header shown = %v, wanted %v", sticky, scrolled)
		}
		for range 10 {
			tt.Advance(100 * time.Millisecond)
			if tt.FramePending() {
				t.Fatalf("settled playlist requests a frame, scrolled = %v", scrolled)
			}
		}
	}
}
