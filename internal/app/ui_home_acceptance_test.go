package app

import (
	"errors"
	"fmt"
	"github.com/egoist/mygo/ui"
	"image"
	"image/png"
	"netease-music-mygo/internal/netease"
	"netease-music-mygo/internal/player"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// Retrying the weekly failure clears its error and starts one new request, not one per frame.
func TestHomeWeeklyRetryInput(t *testing.T) {
	old := fetchHomeWeekly
	defer func() { fetchHomeWeekly = old }()
	called := make(chan struct{}, 4)
	fetchHomeWeekly = func(int64, func(netease.WeeklyScore)) (*netease.WeeklyScore, error) {
		called <- struct{}{}
		return nil, errors.New("offline")
	}
	a := homeFixture(t)
	a.homeSections.weekly.err = "听歌周报加载失败"
	tt := ui.NewTester(func(c *ui.Context) {
		a.pal = paletteFor(c.Theme())
		a.rhineWeekly(c, 1200, 1)
	}, 1280, 500)
	tt.Frame()
	if err := tt.Click("重新读取"); err != nil {
		t.Fatal(err)
	}
	if !a.homeSections.weekly.loading || a.homeSections.weekly.err != "" {
		t.Fatal("retry did not enter loading")
	}
	<-called
	tt.Frame()
	tt.Frame()
	select {
	case <-called:
		t.Fatal("rendering launched a duplicate request")
	default:
	}
}

func saveHomeAcceptance(t *testing.T, name string, img image.Image) {
	t.Helper()
	f, err := os.Create(filepath.Join(os.Getenv("NM_FRAMES"), name+".png"))
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := png.Encode(f, img); err != nil {
		t.Fatal(err)
	}
}

// Save each card's guest, loading, empty and failure presentation for visual review.
func TestHomeEmptyStateFrames(t *testing.T) {
	if os.Getenv("NM_FRAMES") == "" {
		t.Skip("set NM_FRAMES to save frames")
	}
	for _, state := range []string{"guest", "loading", "empty", "failure"} {
		a := homeFixture(t)
		a.daily, a.featured, a.recPlaylists, a.homeRank.rows = nil, nil, nil, nil
		a.homeSections = homeSectionState{}
		a.homeMemo = homeMemoState{loaded: true, accounts: make(map[string]*memoAccount)}
		a.style.songs.Songs = nil
		if state == "guest" {
			a.profile = nil
		}
		if state == "loading" {
			a.homeSections.dailyLoading, a.homeSections.modes.loading, a.homeSections.recent.loading = true, true, true
			a.homeSections.weekly.loading, a.homeRank.loading, a.homeLoading = true, true, true
			a.radioStarting = "fm:test"
		}
		if state == "failure" {
			a.homeSections.dailyErr = "每日推荐加载失败"
			a.homeSections.modes.err, a.homeSections.recent.err = "个性推荐加载失败", "最近播放加载失败"
			a.homeSections.weekly.err, a.homeRank.err, a.homeErr = "周报加载失败", "榜单加载失败", "推荐歌单加载失败"
		}
		for _, section := range []string{"lead", "recent", "weekly", "playlists"} {
			tt := ui.NewTester(func(c *ui.Context) {
				a.pal = paletteFor(c.Theme())
				ui.Column(c).Fill().Background(a.homeSurface()).Padding(24).Children(func() {
					switch section {
					case "lead":
						a.rhineHomeLead(c, 1232, 1)
					case "recent":
						a.rhineHomeRecent(c, 6, 1)
					case "weekly":
						a.rhineWeekly(c, 1232, 1)
					case "playlists":
						a.rhineHomePlaylists(c, 1232, 6, 1)
					}
				})
			}, 1280, 540)
			tt.SetDark(false)
			tt.Frame()
			tt.Advance(time.Second)
			tt.Frame()
			saveHomeAcceptance(t, fmt.Sprintf("%s-%s", state, section), tt.Image())
		}
	}
}

// Save the real decoded current cover through the production blur path and solid fallbacks.
func TestHomeCurrentCoverFrames(t *testing.T) {
	if os.Getenv("NM_FRAMES") == "" {
		t.Skip("set NM_FRAMES to save frames")
	}
	a := homeFixture(t)
	path := os.Getenv("NM_HOME_COVER")
	if path == "" {
		path = filepath.Join("..", "..", "resources", "icon.png")
	}
	file, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	img, _, err := image.Decode(file)
	file.Close()
	if err != nil {
		t.Fatal(err)
	}
	url := "https://example.com/current-cover"
	a.daily[0].Album.PicURL = url
	a.art.add(netease.Sized(url, 96)+"#backdrop", &artwork{bmp: ui.NewBitmap(img), backdrop: ui.NewBitmap(blurImage(img))})
	a.pl.Restore(player.Session{Queue: a.daily[:1], Order: []int{0}})
	var glass image.Image
	tt := ui.NewTester(a.view, 1280, 800)
	tt.SetDark(false)
	for _, mode := range []string{"glass", "solid", "power"} {
		a.settings.LiquidGlass, a.settings.PowerSaver = mode != "solid", mode == "power"
		tt.Frame()
		tt.Advance(time.Second)
		tt.Frame()
		saveHomeAcceptance(t, "current-cover-"+mode, tt.Image())
		if mode == "glass" {
			glass = tt.Image()
		} else {
			changed := 0
			frame := tt.Image()
			for y := 100; y < 670; y++ {
				for x := 0; x < 30; x++ {
					if glass.At(x, y) != frame.At(x, y) {
						changed++
					}
				}
			}
			t.Logf("%s removes backdrop in margin: %d / 17100 pixels", mode, changed)
			if changed == 0 {
				t.Fatal("current cover never reached the background")
			}
		}
	}
}

// After the 700 ms hold and 240 ms exit, no native or custom thumb may remain.
func TestHomeEdgeExitFrames(t *testing.T) {
	if os.Getenv("NM_FRAMES") == "" {
		t.Skip("set NM_FRAMES to save frames")
	}
	a := homeFixture(t)
	tt := ui.NewTester(a.view, 1280, 800)
	tt.SetDark(false)
	tt.Frame()
	tt.Frame()
	tt.Scroll(500, 420, 0, 76)
	tt.Advance(300 * time.Millisecond)
	tt.Frame()
	saveHomeAcceptance(t, "edge-visible", tt.Image())
	visible := tt.Image()
	tt.Advance(401 * time.Millisecond)
	tt.Frame()
	saveHomeAcceptance(t, "edge-exiting", tt.Image())
	tt.Advance(300 * time.Millisecond)
	tt.Frame()
	saveHomeAcceptance(t, "edge-hidden", tt.Image())
	before := tt.Image()
	tt.Advance(time.Second)
	tt.Frame()
	after := tt.Image()
	changed := 0
	for y := 100; y < 670; y++ {
		for x := 1266; x < 1280; x++ {
			if before.At(x, y) != after.At(x, y) {
				changed++
			}
		}
	}
	t.Logf("exit settled edge pixels changed: %d / %d", changed, 14*570)
	if changed != 0 {
		t.Fatal("edge did not settle after exit")
	}
	leftover := 0
	visiblePixels := 0
	for y := 100; y < 670; y++ {
		for x := 1266; x < 1280; x++ {
			// The header wash varies vertically, so compare the adjacent empty margin on the same row.
			if after.At(x, y) != after.At(1258, y) {
				leftover++
			}
			if visible.At(x, y) != after.At(x, y) {
				visiblePixels++
			}
		}
	}
	t.Logf("hidden edge non-background pixels: %d / 7980", leftover)
	t.Logf("visible thumb pixels removed: %d", visiblePixels)
	if visiblePixels == 0 {
		t.Fatal("scrollbar was never painted")
	}
	if leftover != 0 {
		t.Fatal("a scrollbar remains after exit")
	}
}
