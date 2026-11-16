// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"crypto/sha256"
	"encoding/json"
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

// Scrolled artwork must be covered by the home navigation wash in either material mode.
func TestHomeNavigationCoversScrolledContent(t *testing.T) {
	for _, glass := range []bool{false, true} {
		a := homeFixture(t)
		a.settings.LiquidGlass = glass
		a.underTop = true
		tt := ui.NewTester(func(c *ui.Context) {
			ui.Box(c).Absolute().Top(0).Left(0).Right(0).Bottom(0).Background(homeOrange)
			a.pageTop(c)
		}, 1280, 720)
		tt.Frame()
		tt.Advance(time.Second)
		tt.Frame()
		got := color.NRGBAModel.Convert(tt.Image().At(4, 20)).(color.NRGBA)
		if got.R > 240 && got.G < 160 {
			t.Fatalf("glass=%t: scrolling artwork remains visible over navigation: %v", glass, got)
		}
	}
}

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
		{960, 5, .85, .85}, {1280, 6, 1, 1}, {1600, 6, 1.08, 1.1333333}, {1920, 7, 1.12, 1.24}, {2560, 9, 1.12, 1.24},
	} {
		tt := ui.NewTester(func(c *ui.Context) {
			cols, scale, head := homeMeasures(c)
			if cols != at.cols || abs32(scale-at.scale) > .001 || abs32(head-at.head) > .001 {
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
		a.homeSections.modes.items = append(a.homeSections.modes.items, netease.HomeRecommendation{
			ID: int64(300 + i), Key: fmt.Sprintf("list:%d", 300+i), Title: fmt.Sprintf("私人推荐 %d", i+1),
			Description: "留住此刻，听一组为你准备的音乐", Category: "为你定制",
		})
	}
	a.charts[0].Name, a.charts[0].UpdateFreq = "飙升榜", "每天更新"
	a.homeRank.id = a.charts[0].ID
	for i := range 6 {
		tr := a.daily[i%len(a.daily)]
		tr.ID = int64(600 + i)
		tr.Name = fmt.Sprintf("榜单曲目 %d", i+1)
		a.homeRank.rows = append(a.homeRank.rows, netease.ChartTrack{Track: tr, Previous: i * 3, Ranked: true})
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

// Clicking away from search dismisses input even when its suggestions close.
func TestHomeSearchOutsideUnfocus(t *testing.T) {
	a := homeFixture(t)
	tt := ui.NewTester(a.view, 1280, 820)
	tt.Frame()
	if err := tt.Click("搜索"); err != nil {
		t.Fatal(err)
	}
	tt.Frame()
	if !tt.Focused("搜索") {
		t.Fatal("search did not focus")
	}
	a.settings.SearchHistory = []string{"hello"}
	tt.ClickAt(700, 40)
	tt.Frame()
	if tt.Focused("搜索") {
		t.Fatal("outside header click kept search focused")
	}
	if err := tt.Click("搜索"); err != nil {
		t.Fatal(err)
	}
	tt.Frame()
	tt.ClickAt(930, 550)
	tt.Frame()
	if tt.Focused("搜索") {
		t.Fatal("outside content click kept search focused")
	}
	if err := tt.Click("搜索"); err != nil {
		t.Fatal(err)
	}
	tt.Frame()
	if err := tt.Click("hello"); err != nil {
		t.Fatal(err)
	}
	tt.Frame()
	if a.route.page != pageSearch || a.query != "hello" {
		t.Fatal("outside dismissal swallowed suggestion choice")
	}
}

// Rapidly crossing covers must still activate the final hovered recommendation.
func TestHomeModeRapidHover(t *testing.T) {
	a := homeFixture(t)
	tt := ui.NewTester(a.view, 1280, 820)
	tt.Frame()
	for range 6 {
		for _, label := range []string{"私人推荐 1", "私人推荐 3", "私人推荐 2"} {
			r, _ := tt.Find(label)
			tt.Move(r.X+30, r.Y+30)
			tt.Frame()
			tt.Advance(35 * time.Millisecond)
		}
	}
	tt.Advance(time.Second)
	tt.Frame()
	if a.homeSections.modeRevealed != "list:301" {
		t.Fatalf("final hover not activated: %s", a.homeSections.modeRevealed)
	}
}

// Expanding a recommendation must move its neighbours and keep the cover anchored.
func TestHomeModeRevealLayout(t *testing.T) {
	a := homeFixture(t)
	paintHomeFixture(a)
	tt := ui.NewTester(a.view, 1280, 820)
	tt.Frame()
	first, _ := tt.Find("私人推荐 1")
	second, _ := tt.Find("私人推荐 2")
	tt.Move(first.X+40, first.Y+40)
	tt.Frame()
	tt.Advance(170 * time.Millisecond)
	tt.Frame()
	tt.Advance(600 * time.Millisecond)
	tt.Frame()
	expanded, _ := tt.Find("私人推荐 1")
	shifted, _ := tt.Find("私人推荐 2")
	if expanded.X != first.X || expanded.W <= first.W || shifted.X <= second.X {
		t.Fatalf("reveal did not keep its anchor and push neighbours: %v %v / %v %v", first, expanded, second, shifted)
	}
	// The old hover condition collapsed the sleeve when its layout moved
	// beneath the pointer; entering its information and a gap must retain it.
	tt.Move(expanded.X+150, expanded.Y+30)
	tt.Frame()
	tt.Advance(600 * time.Millisecond)
	tt.Frame()
	if a.homeSections.modeRevealed != "list:300" {
		t.Fatal("moving into sleeve information cleared the active recommendation")
	}
	tt.Move(expanded.X+expanded.W+5, expanded.Y+135)
	tt.Frame()
	if a.homeSections.modeRevealed != "list:300" {
		t.Fatal("crossing a rail gap collapsed the sleeve")
	}
	if dir := os.Getenv("NM_FRAMES"); dir != "" {
		f, err := os.Create(filepath.Join(dir, "mode-expanded.png"))
		if err != nil {
			t.Fatal(err)
		}
		defer f.Close()
		if err := png.Encode(f, tt.Image()); err != nil {
			t.Fatal(err)
		}
	}
}

// Category backgrounds must leave the selected label visible, and recent
// timestamps must fit on one line below their full-width staff.
func TestHomeSectionDetailFrames(t *testing.T) {
	dir := os.Getenv("NM_FRAMES")
	if dir == "" {
		t.Skip("set NM_FRAMES to save frames")
	}
	a := homeFixture(t)
	paintHomeFixture(a)
	tt := ui.NewTester(func(c *ui.Context) {
		a.pal = paletteFor(c.Theme())
		ui.Column(c).Padding(40).Background(ui.Hex("#ECEDF3")).Children(func() {
			a.rhineHomeRecent(c, 6, 1)
			a.rhineHomePlaylists(c, 1200, 6, 1)
		})
	}, 1280, 1000)
	tt.SetDark(false)
	tt.Frame()
	tt.Advance(time.Second)
	tt.Frame()
	// Export the hovered cover too: shadows are reviewed visually.
	tt.Move(120, 140)
	for range 20 {
		tt.Advance(20 * time.Millisecond)
		tt.Frame()
	}
	saveHomeAcceptance(t, "home-recent-hover-shadow", tt.Image())
	tt.Move(520, 610)
	for range 20 {
		tt.Advance(20 * time.Millisecond)
		tt.Frame()
	}
	saveHomeAcceptance(t, "home-playlist-hover-shadow", tt.Image())
	f, err := os.Create(filepath.Join(dir, "home-section-details.png"))
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := png.Encode(f, tt.Image()); err != nil {
		t.Fatal(err)
	}
}

// Hovering the second ranked song expands it and clicking plays that row.
func TestHomeRankHoverAndPlay(t *testing.T) {
	a := homeFixture(t)
	tt := ui.NewTester(a.view, 1280, 820)
	row := "播放第 2 名：榜单曲目 2"
	tt.Frame()
	r, ok := tt.Find(row)
	if !ok {
		t.Fatal("rank row missing")
	}
	tt.Move(r.X+r.W/2, r.Y+r.H/2)
	tt.Frame()
	tt.Advance(420 * time.Millisecond)
	tt.Frame()
	expanded, _ := tt.Find(row)
	if a.homeRank.expanded != 1 || expanded.H <= r.H {
		t.Fatalf("rank row did not expand: %v to %v", r, expanded)
	}
	if err := tt.Click(row); err != nil {
		t.Fatal(err)
	}
	if track := a.pl.Current(); track == nil || track.ID != 601 {
		t.Fatalf("rank playback = %v", track)
	}
}

// Latin descenders must remain above the daily underline, including at fitted sizes.
func TestHomeDailyDescenderFrames(t *testing.T) {
	if os.Getenv("NM_FRAMES") == "" {
		t.Skip("set NM_FRAMES to save frames")
	}
	for i, title := range []string{"unhappy", "gypqj", "每日推荐 gypqj 长标题"} {
		a := homeFixture(t)
		a.daily[0].Name = title
		a.motion = motionOff
		tt := ui.NewTester(func(c *ui.Context) {
			a.pal = paletteFor(c.Theme())
			ui.Column(c).Padding(20).Children(func() { a.rhineDaily(c, 620, 1) })
		}, 660, 400)
		tt.SetDark(false)
		tt.Frame()
		tt.Move(80, 100)
		tt.Frame()
		saveHomeAcceptance(t, fmt.Sprintf("daily-descenders-%d", i), tt.Image())
	}
}

// Selecting the next daily recommendation starts the full queue at that song.
func TestHomeDailyNextStartsAtSelectedSong(t *testing.T) {
	a := homeFixture(t)
	tt := ui.NewTester(a.view, 1280, 820)
	tt.Frame()
	if err := tt.Click("播放 " + a.daily[1].Name); err != nil {
		t.Fatal(err)
	}
	if track := a.pl.Current(); track == nil || track.ID != a.daily[1].ID || len(a.pl.Queue()) != len(a.daily) {
		t.Fatalf("daily queue = %v, current = %v", a.pl.Queue(), track)
	}
}

// Rapid changes keep the displayed title, duration and NEXT on the same
// song until the fade swaps them, even when only one NEXT entry fits.
func TestHomeDailyNarrowRapidTrackChanges(t *testing.T) {
	a := homeFixture(t)
	songs := []netease.Track{
		{ID: 701, Name: "很长很长的标题，窄窗口中仍要给右侧的时长标签留出空间", Duration: 61999,
			Artists: []netease.Artist{{ID: 71, Name: "乐手甲"}, {ID: 72, Name: "乐手乙"}}},
		{ID: 702, Name: "很长很长的下一首，悬停后仍要给时长留出空间", Duration: 121999,
			Artists: []netease.Artist{{ID: 73, Name: "乐手丙"}, {ID: 74, Name: "乐手丁"}}},
		{ID: 703, Name: "第三首", Duration: 181999, Artists: []netease.Artist{{ID: 75, Name: "乐手戊"}}},
		{ID: 704, Name: "第四首", Duration: 241999, Artists: []netease.Artist{{ID: 76, Name: "乐手己"}}},
	}
	a.daily = songs
	a.pl.Cue(songs)
	tt := ui.NewTester(a.view, 960, 820)
	tt.SetScale(1.5)
	check := func(i int, duration string) {
		t.Helper()
		title, ok := tt.Find(songs[i].Name)
		tag, tagOK := tt.Find(duration)
		_, nextOK := tt.Find("播放 " + songs[(i+1)%len(songs)].Name)
		if !ok || !tagOK || !nextOK || title.X+title.W > tag.X || !tt.HasText("等 1 位歌手") {
			t.Fatalf("song %d has unsynced or overlapping title, duration and NEXT: %v, %v, %t", i, title, tag, nextOK)
		}
	}
	check(0, "1:01")
	next, ok := tt.Find("播放 " + songs[1].Name)
	if !ok {
		t.Fatal("the first NEXT entry did not fit")
	}
	if _, ok := tt.Find("播放 " + songs[2].Name); ok {
		t.Fatal("NEXT packed another name despite the long first entry")
	}
	tt.Move(next.X+next.W/2, next.Y+next.H/2)
	tt.Advance(320 * time.Millisecond)
	if !tt.HasText("▸ 2:01") {
		t.Fatal("NEXT did not show the full duration slot")
	}
	if dir := os.Getenv("NM_FRAMES"); dir != "" {
		f, err := os.Create(filepath.Join(dir, "daily-960-long-title.png"))
		if err != nil {
			t.Fatal(err)
		}
		defer f.Close()
		if err := png.Encode(f, tt.Image()); err != nil {
			t.Fatal(err)
		}
	}
	tt.Move(1, 1)
	a.pl.Cue(songs[1:])
	tt.Frame()
	tt.Advance(80 * time.Millisecond)
	a.pl.Cue(songs[2:])
	tt.Frame()
	check(0, "1:01")
	tt.Advance(300 * time.Millisecond)
	check(2, "3:01")
	a.pl.Cue(songs[3:])
	tt.Frame()
	tt.Advance(500 * time.Millisecond)
	check(3, "4:01")
	if err := tt.Click("播放 " + songs[0].Name); err != nil {
		t.Fatal(err)
	}
	if got := a.pl.Current(); got == nil || got.ID != songs[0].ID {
		t.Fatalf("wrapped NEXT selected %v", got)
	}
}

// Credits distinguish artist IDs and start the first matching daily song.
func TestHomeDailyArtistUsesFirstQueueMatch(t *testing.T) {
	a := homeFixture(t)
	songs := []netease.Track{
		{ID: 711, Name: "第一首", Artists: []netease.Artist{{ID: 1, Name: "同名乐手"}}},
		{ID: 712, Name: "第二首", Artists: []netease.Artist{{ID: 2, Name: "同名乐手"}}},
		{ID: 713, Name: "第三首", Artists: []netease.Artist{{ID: 1, Name: "更名的乐手"}}},
	}
	a.daily = songs
	a.pl.Cue(songs[2:])
	tt := ui.NewTester(a.view, 960, 820)
	count := 0
	for _, label := range tt.Texts() {
		if label == "播放 同名乐手 的推荐曲目" {
			count++
		}
	}
	if count != 1 {
		t.Fatalf("expected the other artist with the same name once, got %d", count)
	}
	if err := tt.Click("播放 更名的乐手 的推荐曲目"); err != nil {
		t.Fatal(err)
	}
	if got := a.pl.Current(); got == nil || got.ID != songs[0].ID {
		t.Fatalf("clicked credit selected %v instead of the artist's first song", got)
	}
}

// The FM card starts the station without navigating away from the home page.
func TestHomeFMShortcut(t *testing.T) {
	a := homeFixture(t)
	old := personalFM
	called := make(chan string, 1)
	personalFM = func(mode string) ([]netease.Track, error) {
		called <- mode
		return a.daily[:1], nil
	}
	defer func() { personalFM = old }()
	tt := ui.NewTester(a.view, 1280, 1100)
	tt.Frame()
	if err := tt.Click("播放私人 FM"); err != nil {
		t.Fatal(err)
	}
	select {
	case <-called:
	case <-time.After(time.Second):
		t.Fatal("the FM feed was not requested")
	}
	if a.route.page != pageHome || a.radioStarting != fmRadio(fmModes[a.fmMode].mode) {
		t.Fatalf("route = %v, station = %q", a.route.page, a.radioStarting)
	}
}

// Hovering FM Next nudges it once, including after a quick re-entry.
func TestHomeFMNextHoverNudge(t *testing.T) {
	a := homeFixture(t)
	a.pl.Cue(a.daily)
	a.pl.AttachRadio("fm:DEFAULT", nil)
	tt := ui.NewTester(a.view, 1280, 1100)
	r, ok := tt.Find("下一首 FM 歌曲")
	if !ok {
		t.Fatal("FM next button missing")
	}
	x, y := r.X+r.W/2, r.Y+r.H/2
	n := &a.homeSections.fmNext
	tt.Move(x, y)
	tt.Advance(200 * time.Millisecond)
	if got := n.offset(tt.Now()); got != 3 {
		t.Fatalf("at the end of the push, offset = %v, want 3", got)
	}
	tt.Move(1, 1)
	tt.Advance(80 * time.Millisecond)
	before := n.offset(tt.Now())
	tt.Move(x, y)
	if got := n.offset(tt.Now()); before <= 0 || got != before {
		t.Fatalf("re-entry moved from %v to %v", before, got)
	}
	tt.Advance(500 * time.Millisecond)
	if !n.start.IsZero() || n.offset(tt.Now()) != 0 {
		t.Fatal("still moving with the pointer held over FM Next")
	}
	if tt.FramePending() {
		t.Fatal("FM Next still asks for a frame after settling")
	}
	tt.Move(1, 1)
	tt.SetPreferences(ui.Preferences{ReduceMotion: true, TextScale: 1})
	tt.Move(x, y)
	if !n.start.IsZero() {
		t.Fatal("started a nudge with reduced motion enabled")
	}
}

// A bookmark starts the selected track at its saved time.
func TestHomeMemoResume(t *testing.T) {
	a := homeFixture(t)
	tr := netease.Track{Name: "本地样本", LocalPath: filepath.Join(t.TempDir(), "sample.flac"), Duration: 120000}
	a.homeMemoAccount().Recent = []memoBookmark{{Track: tr, Position: 34000}}
	tt := ui.NewTester(a.view, 1280, 1300)
	tt.Frame()
	if err := tt.Click(tr.Name); err != nil {
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
	for _, name := range []string{"LongCang-Regular.ttf", "Caveat.ttf", "NotoMusic-Regular.ttf"} {
		font, err := os.ReadFile(filepath.Join("..", "..", "resources", "fonts", name))
		if err != nil {
			t.Fatal(err)
		}
		if err := ui.RegisterFont(font, ""); err != nil {
			t.Fatal(err)
		}
	}

	for _, size := range [][2]int{{960, 640}, {1280, 800}, {1600, 900}, {1920, 1000}, {2560, 1400}} {
		w, height := size[0], size[1]
		a := homeFixture(t)
		paintHomeFixture(a)
		tt := ui.NewTester(a.view, w, height)
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
		for _, width := range []int{96, 120, 192, 200, 256, 320, 400, 512, 600, 640} {
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
	for i := range a.homeSections.modes.items {
		a.homeSections.modes.items[i].Cover = a.recPlaylists[i].CoverURL
	}
	for i := range a.homeRank.rows {
		a.homeRank.rows[i].Album.PicURL = a.recPlaylists[i+5].CoverURL
	}
	for i := range 8 {
		a.homeSections.recent.items = append(a.homeSections.recent.items, netease.RecentlyPlayedPlaylist{
			Playlist: a.recPlaylists[i], At: time.Now().Add(time.Duration(-i-1) * time.Hour),
		})
	}
	for i := range a.featured {
		a.featured[i].CoverURL = a.recPlaylists[i].CoverURL
	}
	a.charts[0].CoverURL = a.recPlaylists[4].CoverURL
}

// Playing across midnight splits the score without counting time spent paused.
func TestHomeProgressAcrossMidnight(t *testing.T) {
	a := newTestApp()
	midnight := time.Date(2026, 11, 16, 0, 0, 0, 0, time.FixedZone("CST", 8*60*60))
	a.homeMemo.saved = midnight
	track := netease.Track{ID: 42, Name: "Track"}
	account := a.homeMemoAccount()
	for i := -19; i <= 0; i++ {
		a.recordHomeProgress(track, 1, time.Second*time.Duration(i+20), time.Second, midnight.Add(time.Second*time.Duration(i)))
	}
	// Only the half seconds either side of midnight were heard here.
	a.recordHomeProgress(track, 2, 40*time.Second, time.Second, midnight.Add(500*time.Millisecond))
	if len(account.Listens) != 3 {
		t.Fatalf("listens = %+v", account.Listens)
	}
	if got := account.Listens[0].Milliseconds; got != 20000 {
		t.Fatalf("first play = %d ms", got)
	}
	before, after := account.Listens[1], account.Listens[2]
	if before.Last != midnight.UnixMilli() || after.Start != midnight.UnixMilli() ||
		before.Milliseconds != 500 || after.Milliseconds != 500 {
		t.Fatalf("split = %+v / %+v", before, after)
	}
}

// The first listen on a fresh profile creates the directory and survives exit.
func TestHomeMemoWritesNewProfile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "data", "home-memo.json")
	m := &memoAccount{Listens: []memoListen{{"42", 1000, 11000, 10000}}}
	first := saveHomeMemo(path, map[string]*memoAccount{"test": m})
	m.Listens[0].Last, m.Listens[0].Milliseconds = 12000, 11000
	last := saveHomeMemo(path, map[string]*memoAccount{"test": m})
	<-first
	<-last
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var saved map[string]*memoAccount
	if err := json.Unmarshal(b, &saved); err != nil {
		t.Fatal(err)
	}
	if saved["test"] == nil || len(saved["test"].Listens) != 1 || saved["test"].Listens[0].Milliseconds != 11000 {
		t.Fatalf("saved progress = %s", b)
	}
}

// Many style tags scroll independently of the confirmation buttons.
func TestHomeStylePickerScroll(t *testing.T) {
	a := homeFixture(t)
	a.motion = motionOff
	tags := make([]netease.StyleTag, 60)
	for i := range tags {
		tags[i] = netease.StyleTag{ID: int64(i + 1), Name: fmt.Sprintf("标签 %d", i+1)}
	}
	a.style.cats = []netease.StyleCategory{{ID: 1, Name: "曲风", Tags: tags}}
	a.openStylePicker()
	tt := ui.NewTester(a.view, 960, 540)
	tt.Frame()
	confirm, ok := tt.Find("确认")
	if !ok || confirm.Y+confirm.H > 540 {
		t.Fatalf("confirmation outside the window: %+v", confirm)
	}
	first, ok := tt.Find("风格：标签 1")
	if !ok {
		t.Fatal("first tag is not visible")
	}
	for range 4 {
		tt.Scroll(first.X+first.W/2, first.Y+first.H/2, 0, 380)
		tt.Advance(250 * time.Millisecond)
		tt.Frame()
	}
	if err := tt.Click("风格：标签 60"); err != nil {
		t.Fatal(err)
	}
	if len(a.style.picked) != 1 || a.style.picked[0] != 60 {
		t.Fatalf("draft = %v", a.style.picked)
	}
}
