// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"fmt"
	"image/png"
	"os"
	"path/filepath"
	"testing"
	"time"
	_ "time/tzdata"

	"github.com/egoist/mygo/ui"
	"netease-music-mygo/internal/netease"
)

// A DST week uses calendar midnight, and an expired online report falls back at the next Monday.
func TestHomeScoreDSTBoundary(t *testing.T) {
	loc, err := time.LoadLocation("America/New_York")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, 11, 1, 23, 59, 0, 0, loc)
	start := calendarWeek(now)
	if start.Format("2006-01-02") != "2026-10-26" || start.AddDate(0, 0, 7).Sub(start) != 169*time.Hour {
		t.Fatal("DST week used fixed hours", start)
	}
	a := newTestApp()
	a.homeSections.weekly.report = &netease.WeeklyScore{Days: []netease.ScoreDay{{Date: "2026-10-26", Minutes: 60}}, Minutes: 60}
	if !a.homeScore(now).online {
		t.Fatal("valid report lost on DST day")
	}
	next := time.Date(2026, 11, 2, 0, 0, 0, 0, loc)
	got := a.homeScore(next)
	if got.online || got.minutes != 0 || got.days[0].date != next {
		t.Fatal("previous week leaked past midnight", got)
	}
}

// The SVG icon renderer is monochrome: staff and orange accents must retain separate masks.
func TestHomeScoreKeepsInkLayers(t *testing.T) {
	var layers []scoreLayer
	w := scoreWeek{top: netease.ScoreRank{SongID: 1}}
	w.days[0].minutes = 25
	w.days[0].sessions = []scoreSession{{track: netease.Track{ID: 1}, weight: 1}}
	tt := ui.NewTester(func(c *ui.Context) { layers, _ = buildScoreDrawing(c, w, 1200, 1) }, 1200, 300)
	tt.Frame()
	gray, orange := false, false
	for _, layer := range layers {
		gray = gray || layer.color == ui.Hex("#C9CBD4")
		orange = orange || layer.color == homeOrange
	}
	if !gray || !orange {
		t.Fatalf("notation lost staff or highlight ink: %v", layers)
	}
}

// Online totals must not be inflated by local or de-duplicated upstream history.
func TestHomeScoreCalendarAndTotals(t *testing.T) {
	a := newTestApp()
	now := time.Date(2026, 11, 15, 3, 0, 0, 0, time.UTC)
	start := calendarWeek(now)
	if start.Format("2006-01-02") != "2026-11-09" {
		t.Fatal(start)
	}
	tr := netease.Track{ID: 52, Name: "晨光", Duration: 180000}
	at := start.Add(2 * time.Hour)
	m := a.homeMemoAccount()
	m.Recent = []memoBookmark{{Track: tr}}
	m.Listens = []memoListen{{"52", at.UnixMilli(), at.Add(time.Minute).UnixMilli(), 60000}}
	a.homeSections.weekly.report = &netease.WeeklyScore{Days: []netease.ScoreDay{{Date: "2026-11-09", Minutes: 125}}, Minutes: 125,
		Recent: []netease.ScoreObservation{{Track: tr, At: at.Add(time.Minute).UnixMilli()}}}
	w := a.homeScore(now)
	if !w.online || w.days[0].minutes != 125 || len(w.days[0].sessions) != 1 || w.comparison {
		t.Fatalf("report = %+v", w)
	}
	w = a.homeScore(now.AddDate(0, 0, 1))
	if w.online || w.minutes != 0 || w.days[0].date.Format("2006-01-02") != "2026-11-16" {
		t.Fatalf("stale week = %+v", w)
	}
}

// Equivalent note rhythms must preserve the rounded daily duration at every density.
func TestHomeScoreRhythm(t *testing.T) {
	for minutes := 15; minutes <= 1440; minutes += 15 {
		for style := range 4 {
			sum := 0
			for _, v := range scoreRhythm(float64(minutes), style) {
				sum += v
			}
			if sum != minutes/15 {
				t.Fatalf("%d minutes, variant %d became %d units", minutes, style, sum)
			}
		}
	}
}

// Quoted comments stay whole and exclude replies, links, and long stories.
func TestHomeScoreQuote(t *testing.T) {
	rows := []netease.Comment{{Content: "这是完整的一条短评", LikedCount: 8}, {Content: "http://example.com", LikedCount: 90}, {Content: "回复 @朋友：你好", LikedCount: 99}, {Content: "这是一段很长很长的故事我们不能把它截断后冒充为作者写下的短评", LikedCount: 100}}
	got := scoreQuote(rows, "42:2026-11-09:52")
	if got.Content != rows[0].Content {
		t.Fatalf("quote = %q", got.Content)
	}
}

// Fast song changes must show the latest target after the invisible swap;
// reducing motion interrupts immediately without scheduling another frame.
func TestHomeCopyInterrupt(t *testing.T) {
	var state homeCopyTransition
	next := homeCopy{key: "a", title: "A"}
	var shown homeCopy
	var opacity float32
	reduced := false
	tt := ui.NewTester(func(c *ui.Context) { shown, opacity = state.frame(c, next, reduced, 40*time.Millisecond) }, 200, 100)
	tt.Frame()
	next = homeCopy{key: "b", title: "B"}
	tt.Frame()
	tt.Advance(110 * time.Millisecond)
	tt.Frame()
	if shown.title != "A" || opacity >= 1 {
		t.Fatal(shown, opacity)
	}
	next = homeCopy{key: "c", title: "C"}
	tt.Frame()
	tt.Advance(270 * time.Millisecond)
	tt.Frame()
	if shown.title != "C" {
		t.Fatal(shown)
	}
	reduced = true
	next = homeCopy{key: "d", title: "D"}
	tt.Frame()
	if shown.title != "D" || opacity != 1 || !state.start.IsZero() {
		t.Fatal(shown, opacity, state)
	}
}

// Export the entire score with real font files and deterministic synthetic data.
func TestHomeScoreFrames(t *testing.T) {
	dir := os.Getenv("NM_FRAMES")
	if dir == "" {
		t.Skip("set NM_FRAMES")
	}
	for _, name := range []string{"LongCang-Regular.ttf", "Caveat.ttf", "NotoMusic-Regular.ttf"} {
		data, err := os.ReadFile(filepath.Join("..", "..", "resources", "fonts", name))
		if err != nil {
			t.Fatal(err)
		}
		if err := ui.RegisterFont(data, ""); err != nil {
			t.Fatal(err)
		}
	}
	for i, width := range []int{960, 1280, 1600, 1920, 2560} {
		a := newTestApp()
		a.profile = &netease.Profile{UserID: 42}
		start := calendarWeek(time.Now()).AddDate(0, 0, 7)
		now := start.AddDate(0, 0, 6).Add(12 * time.Hour)
		report := &netease.WeeklyScore{Minutes: 760, PreviousMinutes: 500, ComparisonAvailable: true, RankingLabel: "本周循环最多", Ranking: []netease.ScoreRank{{SongID: 1, SongName: "起风了", PlayCount: 12}}}
		for i := range 7 {
			d := start.AddDate(0, 0, i)
			report.Days = append(report.Days, netease.ScoreDay{Date: d.Format("2006-01-02"), Minutes: float64(25 + i*20)})
			report.Recent = append(report.Recent, netease.ScoreObservation{Track: netease.Track{ID: int64(i + 1), Name: []string{"起风了", "Morning Light", "晴天", "夜曲", "First Love", "旅途", "再见"}[i], Duration: 180000}, At: d.Add(time.Duration(7+i*2) * time.Hour).UnixMilli()})
		}
		a.homeSections.weekly.report = report
		a.homeSections.weekly.quote = memoScoreQuote{Content: "夕阳落下的时候，耳机里恰好响起这首歌。", Author: "Rhine"}
		a.homeMemoAccount().ScoreLayouts = map[string]int{start.Format("2006-01-02"): i % 4}
		tt := ui.NewTester(func(c *ui.Context) {
			a.pal = paletteFor(c.Theme())
			ui.Box(c).Fill().Padding(30).Background(ui.Hex("#ECEDF3")).Children(func() { a.rhineWeekly(c, float32(width-60), 1) })
		}, width, 430)
		tt.Advance(now.Sub(tt.Now()))
		tt.Frame()
		tt.Frame()
		f, err := os.Create(filepath.Join(dir, fmt.Sprintf("weekly-%d.png", width)))
		if err != nil {
			t.Fatal(err)
		}
		err = png.Encode(f, tt.Image())
		f.Close()
		if err != nil {
			t.Fatal(err)
		}
	}
}
