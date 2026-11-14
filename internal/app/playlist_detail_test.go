// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"fmt"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/egoist/mygo/ui"

	"netease-music-mygo/internal/netease"
)

func playlistDetailFixture() *app {
	a := newTestApp()
	a.settings = defaultSettings()
	a.route = route{page: pagePlaylist, id: 42}
	tracks := make([]netease.Track, 80)
	for i := range tracks {
		tracks[i] = netease.Track{
			ID: int64(i + 1), Name: fmt.Sprintf("样本曲目 %02d", i+1), Duration: int64((198 + i) * 1000),
			Artists: []netease.Artist{{Name: fmt.Sprintf("样本歌手 %02d", i+1)}},
			Album:   netease.Album{Name: fmt.Sprintf("样本专辑 %02d", i+1)},
		}
	}
	a.playlists[42] = &netease.Playlist{
		ID: 42, Name: "晚风收音机",
		Description: strings.Repeat("从独立流行、民谣和轻爵士里选出的晚间曲目。适合在写字、散步或刚结束一天工作的时候听。", 8),
		Tracks:      tracks,
	}
	return a
}

// Compact playlists keep the album column, with its text starting 3/5 of
// the way through the flexible width after the fixed controls and gaps.
func TestPlaylistDetailColumns(t *testing.T) {
	for _, w := range []int{960, 1280, 1920} {
		t.Run(fmt.Sprint(w), func(t *testing.T) {
			a := playlistDetailFixture()
			tt := ui.NewTester(a.view, w, 840)
			tt.Frame()
			row, rowOK := tt.Find("样本曲目 01")
			artist, artistOK := tt.Find("样本歌手 01")
			album, albumOK := tt.Find("样本专辑 01")
			if !rowOK || !artistOK || !albumOK {
				t.Fatalf("row, artist, album = %v/%v/%v", rowOK, artistOK, albumOK)
			}
			const gap = 14
			flexible := row.W - 2*12 - 26 - 38 - 32 - 44 - 5*gap
			want := artist.X + flexible*3/5 + gap
			if math.Abs(float64(album.X-want)) > 1 {
				t.Fatalf("album starts at %.1f, want %.1f (row %+v, title starts at %.1f)", album.X, want, row, artist.X)
			}
		})
	}
}

// The sticky title stays in place during list scrolling and sends the list
// back to its hero when clicked, even on direct navigation to a playlist.
func TestPlaylistDetailSticky(t *testing.T) {
	a := playlistDetailFixture()
	tt := ui.NewTester(a.view, 960, 840)
	tt.Frame()
	if _, ok := tt.Find("回到歌单开头"); ok {
		t.Fatal("sticky title is visible when the hero is in view")
	}
	scroll := func() {
		tt.Wheel(630, 560, 0, 650)
		tt.Advance(time.Second)
		tt.Frame()
	}
	scroll()
	one, ok := tt.Find("回到歌单开头")
	if !ok || one.H != playlistTopHeight {
		t.Fatalf("sticky header after scroll = %+v, present %v", one, ok)
	}
	first, _ := a.trackList.Visible()
	scroll()
	next, _ := a.trackList.Visible()
	if two, ok := tt.Find("回到歌单开头"); !ok || two != one || next <= first {
		t.Fatalf("sticky header moved %+v to %+v, songs went %v to %v", one, two, first, next)
	}
	if err := tt.Click("回到歌单开头"); err != nil {
		t.Fatal(err)
	}
	tt.Frame()
	if _, ok := tt.Find("回到歌单开头"); ok {
		t.Fatal("sticky title remained after returning to the hero")
	}
	if r, ok := tt.Find("歌单简介"); !ok || r.Y < 50 || r.Y > 300 {
		t.Fatalf("the original description did not return to the viewport: %+v, %v", r, ok)
	}
}

// The description expands inline and gives the scrolling rows more room
// below it; closing it returns the rows to their former position.
func TestPlaylistDetailDescription(t *testing.T) {
	a := playlistDetailFixture()
	tt := ui.NewTester(a.view, 960, 840)
	rowY := func() float32 {
		tt.Frame()
		r, ok := tt.Find("样本曲目 01")
		if !ok {
			t.Fatal("first track missing")
		}
		return r.Y
	}
	before := rowY()
	if err := tt.Click("歌单简介"); err != nil {
		t.Fatal(err)
	}
	if after := rowY(); after <= before+60 {
		t.Fatalf("first row moved from %.1f to %.1f", before, after)
	}
	if err := tt.Click("歌单简介"); err != nil {
		t.Fatal(err)
	}
	if after := rowY(); after != before {
		t.Fatalf("first row stayed at %.1f, originally %.1f", after, before)
	}
}

// With NM_FRAMES set, saves the opened and scrolled playlist details in
// the three Rhine window widths using local fixture artwork.
func TestPlaylistDetailFrames(t *testing.T) {
	dir := os.Getenv("NM_FRAMES")
	if dir == "" {
		t.Skip("set NM_FRAMES to a directory to save frames")
	}
	for _, w := range []int{960, 1280, 1920} {
		a := playlistDetailFixture()
		fixture := homeFixture(t)
		paintHomeFixture(fixture)
		a.art = fixture.art
		pl := a.playlists[42]
		pl.CoverURL = fixture.daily[0].Album.PicURL
		wash := a.art.peek(netease.Sized(pl.CoverURL, 600) + "#backdrop")
		wash.backdrop = wash.bmp
		for _, item := range fixture.recPlaylists {
			url := item.CoverURL
			art := a.art.peek(netease.Sized(url, 400))
			a.art.add(netease.Sized(url, 240), art)
		}
		for i := range pl.Tracks {
			pl.Tracks[i].Album.PicURL = fixture.recPlaylists[i%len(fixture.recPlaylists)].CoverURL
		}
		// Keep a current song within the first viewport and below the sticky
		// header when scrolled, without running an audio stream.
		a.pl.Cue(pl.Tracks[8:])
		tt := ui.NewTester(a.view, w, 960)
		tt.SetDark(false)
		capture := func(stage string) {
			t.Helper()
			tt.Advance(time.Second)
			tt.Frame()
			f, err := os.Create(filepath.Join(dir, fmt.Sprintf("playlist-%d-%s.png", w, stage)))
			if err != nil {
				t.Fatal(err)
			}
			err = png.Encode(f, tt.Image())
			closed := f.Close()
			if err != nil {
				t.Fatal(err)
			}
			if closed != nil {
				t.Fatal(closed)
			}
		}
		tt.Frame()
		capture("overview")
		tt.Wheel(float32(w)*.65, 500, 0, 315)
		capture("sticky")
	}
}
