// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"crypto/sha256"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/egoist/mygo/ui"
	"netease-music-mygo/internal/netease"
)

// Older memo data is loaded only for the matching account, with lifetime
// encounters and listening-day totals derived from the imported plays.
func TestHomeMemoImport(t *testing.T) {
	dir := t.TempDir()
	oldPath := historyPath
	historyPath = func() (string, error) { return filepath.Join(dir, "history.json"), nil }
	defer func() { historyPath = oldPath }()
	a := newTestApp()
	a.homeMemo = homeMemoState{}
	a.profile = &netease.Profile{UserID: 42}
	key := fmt.Sprintf("listening-score-v1-%x", sha256.Sum256([]byte("netease:42")))
	now := time.Date(2026, 11, 15, 3, 0, 0, 0, time.UTC)
	first := now.Add(-30 * time.Minute).UnixMilli()
	raw := fmt.Sprintf(`{"weekly-score/%s":[{"id":"52","start":%d,"last":%d,"milliseconds":60000}],"recent-bookmarks/%s":{"list":{"source":{"provider":"netease"},"track":{"id":"52","kind":"song","title":"测试","duration":200000},"position":25000,"at":%d}}}`, key, first, first+60000, key, first)
	if err := os.WriteFile(filepath.Join(dir, "rhine-listening.json"), []byte(raw), 0600); err != nil {
		t.Fatal(err)
	}
	m := a.homeMemoAccount()
	if got := m.Encounters["52"]; got.Count != 1 || got.First != first {
		t.Fatalf("encounter = %+v", got)
	}
	if got := m.week(now); got != [7]int64{6: 60000} {
		t.Fatalf("week = %v", got)
	}
	if len(m.Recent) != 1 || m.Recent[0].Track.ID != 52 || m.Recent[0].Position != 25000 {
		t.Fatalf("recent = %v", m.Recent)
	}
	a.profile = &netease.Profile{UserID: 43}
	if other := a.homeMemoAccount(); len(other.Listens) != 0 || len(other.Recent) != 0 {
		t.Fatal("the next account inherited a memo")
	}
}

// The personalized recommendation rail adds columns at the requested
// widths while keeping the header at the specified scale.
func TestHomeResponsiveMeasures(t *testing.T) {
	for _, at := range []struct {
		w, cols     int
		scale, head float32
	}{
		{960, 5, .85, .85}, {1280, 6, 1, 1}, {1600, 7, 1.02, 1.08}, {1920, 9, 1.04, 1.12}, {2560, 12, 1.06, 1.24},
	} {
		tt := ui.NewTester(func(c *ui.Context) {
			cols, scale, head := homeMeasures(c)
			if cols != at.cols || scale != at.scale || head != at.head {
				t.Errorf("at %d got %d, %.2f, %.2f", at.w, cols, scale, head)
			}
		}, at.w, 800)
		tt.Frame()
	}
}

func homeFixture(t *testing.T) *app {
	t.Helper()
	a := newTestApp()
	accentHome(a)
	a.profile = &netease.Profile{UserID: 42, Nickname: "Rhine"}
	a.style = styleState{loaded: true, songs: netease.StyleSongs{
		Picked: netease.StyleCategory{Tags: []netease.StyleTag{{Name: "独立流行"}, {Name: "民谣"}}},
		Songs:  append([]netease.Track(nil), a.daily...),
	}}
	for i := range 24 {
		a.featured = append(a.featured, netease.Playlist{ID: int64(200 + i), Name: fmt.Sprintf("推荐精选 %d", i+1)})
	}
	for i := range 16 {
		a.recPlaylists = append(a.recPlaylists, netease.Playlist{ID: int64(300 + i), Name: fmt.Sprintf("私人推荐 %d", i+1)})
	}
	m := a.homeMemoAccount()
	now := time.Now()
	for i := range 7 {
		start := now.AddDate(0, 0, -i).Add(-35 * time.Minute)
		m.add(memoListen{"1", start.UnixMilli(), start.Add(time.Minute).UnixMilli(), 60000 * int64(2+i*3)})
	}
	m.Recent = []memoBookmark{{a.daily[0], 34000, now.UnixMilli()}, {a.daily[1], 59000, now.Add(-time.Hour).UnixMilli()}}
	return a
}

// Picking an FM shortcut opens the existing FM page.
func TestHomeFMShortcut(t *testing.T) {
	a := homeFixture(t)
	tt := ui.NewTester(a.view, 1280, 1100)
	tt.Frame()
	if err := tt.Click("首页 · 私人 FM"); err != nil {
		t.Fatal(err)
	}
	if a.route.page != pageFM {
		t.Fatalf("route = %v", a.route.page)
	}
}

// A bookmark starts the selected track at its saved time.
func TestHomeMemoResume(t *testing.T) {
	a := homeFixture(t)
	tr := netease.Track{Name: "本地样本", LocalPath: filepath.Join(t.TempDir(), "sample.flac"), Duration: 120000}
	a.homeMemoAccount().Recent = []memoBookmark{{Track: tr, Position: 34000}}
	tt := ui.NewTester(a.view, 1280, 1300)
	tt.Frame()
	if err := tt.Click("接着听 " + tr.Name); err != nil {
		t.Fatal(err)
	}
	if got := a.pl.Current(); got == nil || got.LocalPath != tr.LocalPath || a.pl.Position() != 34*time.Second || !a.pl.Playing() {
		t.Fatalf("resumed %v at %v, playing %v", got, a.pl.Position(), a.pl.Playing())
	}
}

// The style dialog requires a confirmed selection before writing, and
// choosing within another category replaces the earlier draft.
func TestHomeStyleSelection(t *testing.T) {
	a := homeFixture(t)
	a.style.cats = []netease.StyleCategory{
		{ID: 1, Name: "曲风", Tags: []netease.StyleTag{{ID: 11, Name: "独立流行"}, {ID: 12, Name: "民谣"}}},
		{ID: 2, Name: "情绪", Tags: []netease.StyleTag{{ID: 21, Name: "安静"}}},
	}
	tt := ui.NewTester(a.view, 1280, 1440)
	a.openStylePicker()
	tt.Frame()
	if err := chooseItem(tt, "风格：独立流行", "风格：民谣"); err != nil {
		t.Fatal(err)
	}
	if a.style.cat != 1 || len(a.style.picked) != 2 {
		t.Fatalf("draft = %v", a.style.picked)
	}
	if err := chooseItem(tt, "风格分类：情绪", "风格：安静"); err != nil {
		t.Fatal(err)
	}
	if a.style.cat != 2 || len(a.style.picked) != 1 || a.style.picked[0] != 21 {
		t.Fatalf("switched draft = %v", a.style.picked)
	}
	tt.Key(0, ui.KeyEscape)
	tt.Frame()
	if a.style.open || a.style.saving {
		t.Fatal("Escape did not dismiss the unsaved style draft")
	}
	a.openStylePicker()
	if a.style.cat != a.style.songs.Picked.ID {
		t.Fatal("reopening retained the discarded draft")
	}
}

// With NM_FRAMES set, saves the regular home page at every Rhine width.
func TestHomeResponsiveFrames(t *testing.T) {
	dir := os.Getenv("NM_FRAMES")
	if dir == "" {
		t.Skip("set NM_FRAMES to a directory to save frames")
	}
	font, err := os.ReadFile(filepath.Join("..", "..", "resources", "fonts", "LongCang-Regular.ttf"))
	if err != nil {
		t.Fatal(err)
	}
	if err := ui.RegisterFont(font, ""); err != nil {
		t.Fatal(err)
	}
	for _, w := range []int{960, 1280, 1600, 1920, 2560} {
		a := homeFixture(t)
		paintHomeFixture(a)
		tt := ui.NewTester(a.view, w, 1560)
		tt.SetDark(false)
		tt.Frame()
		tt.Advance(time.Second)
		tt.Frame()
		f, err := os.Create(filepath.Join(dir, fmt.Sprintf("home-%d.png", w)))
		if err != nil {
			t.Fatal(err)
		}
		err = png.Encode(f, tt.Image())
		closeErr := f.Close()
		if err != nil {
			t.Fatal(err)
		}
		if closeErr != nil {
			t.Fatal(closeErr)
		}
	}
}

// Use local bitmaps so fetching artwork cannot affect the home screenshots.
func paintHomeFixture(a *app) {
	colors := []color.RGBA{{87, 125, 149, 255}, {151, 92, 105, 255}, {131, 116, 162, 255}, {106, 142, 128, 255}, {166, 126, 79, 255}, {76, 103, 132, 255}, {163, 104, 83, 255}, {125, 134, 85, 255}}
	add := func(i int) string {
		url := fmt.Sprintf("https://example.com/home-cover-%d", i)
		tint := colors[i%len(colors)]
		img := image.NewRGBA(image.Rect(0, 0, 64, 64))
		for y := range 64 {
			for x := range 64 {
				light := (x + y) % 65 / 2
				if (x-31)*(x-31)+(y-31)*(y-31) < 340 {
					light += 19
				}
				img.SetRGBA(x, y, color.RGBA{tint.R + uint8(light), tint.G + uint8(light), tint.B + uint8(light), 255})
			}
		}
		bmp := ui.NewBitmap(img)
		for _, width := range []int{96, 120, 192, 200, 256, 320, 400, 600} {
			sized := netease.Sized(url, width)
			art := &artwork{bmp: bmp, tint: ui.RGB(tint.R, tint.G, tint.B), used: time.Now(), size: 16384}
			a.art.add(sized, art)
			a.art.add(sized+"#backdrop", art)
		}
		return url
	}
	for i := range a.daily {
		url := add(i)
		a.daily[i].Album.PicURL = url
		a.style.songs.Songs[i].Album.PicURL = url
	}
	for i := range a.recPlaylists {
		a.recPlaylists[i].CoverURL = add(i + 2)
	}
	for i := range a.featured {
		a.featured[i].CoverURL = a.recPlaylists[i].CoverURL
	}
	a.charts[0].CoverURL = a.recPlaylists[4].CoverURL
}
