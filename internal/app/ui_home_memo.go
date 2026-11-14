// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"
	"netease-music-mygo/internal/netease"
)

// Rhine: the card rail adds columns at the same window widths as HomePageB.
func homeMeasures(c *ui.Context) (cols int, content, header float32) {
	w, _ := c.Size()
	stops := [...]struct {
		width           float32
		cols            int
		content, header float32
	}{
		{960, 5, .85, .85}, {1280, 6, 1, 1}, {1600, 7, 1.02, 1.08},
		{1920, 9, 1.04, 1.12}, {2560, 12, 1.06, 1.24},
	}
	left := stops[0]
	for _, right := range stops[1:] {
		if w < right.width {
			t := max(0, (w-left.width)/(right.width-left.width))
			return left.cols, left.content + (right.content-left.content)*t, left.header + (right.header-left.header)*t
		}
		left = right
	}
	return left.cols, left.content, left.header
}

func (a *app) homeHeading(c *ui.Context, now time.Time, scale float32) {
	hello := greeting(now)
	if a.profile != nil {
		hello += "，" + a.profile.Nickname
	}
	ui.Column(c).Gap(4).Margin(0, 0, 18, 0).Children(func() {
		ui.Textf(c, "%d月%d日 %s", now.Month(), now.Day(), weekday(now)).FontSize(12 * scale).
			FontWeight(600).TextColor(a.pal.muted).LetterSpacing(.4)
		ui.Text(c, hello).FontSize(30 * scale).FontWeight(700).LetterSpacing(-.6)
	})
}

func (a *app) homeShortcuts(c *ui.Context, scale float32) {
	ui.Row(c).Gap(12*scale).Margin(16*scale, 0, 0, 0).Children(func() {
		for _, item := range []struct {
			label string
			icon  *ui.SVG
			page  pageKind
		}{{"私人 FM", iconRadio, pageFM}, {"排行榜", iconCharts, pageCharts}} {
			b := ui.ButtonBase(c.Key(item.page)).Grow(1).Height(48 * scale).Radius(14).Gap(9).
				AlignItems(ui.Center).Justify(ui.Start).PaddingX(14).Label("首页 · " + item.label)
			bg := a.pal.hover
			if b.Hovered() {
				bg = a.pal.press
			}
			b.Background(bg).Children(func() {
				ui.Icon(c, item.icon).Size(18, 18).TextColor(a.pal.accent)
				ui.Text(c, item.label).FontSize(14 * scale).FontWeight(650)
			})
			if b.Clicked() {
				a.open(route{page: item.page})
			}
		}
	})
}

func (a *app) homeListening(c *ui.Context, now time.Time, scale float32) {
	m := a.homeMemoAccount()
	a.section(c, "个人听歌备忘")
	tr := a.pl.Current()
	if tr == nil && len(m.Recent) > 0 {
		tr = &m.Recent[0].Track
	}
	var e memoEncounter
	if tr != nil {
		id := historyKey(tr)
		if tr.ID != 0 {
			id = fmt.Sprint(tr.ID)
		}
		e = m.Encounters[id]
	}
	ui.Row(c).Gap(14 * scale).Children(func() {
		a.homeCassette(c.Key("cassette"), tr, e)
		a.homeScore(c.Key("score"), now, m.week(now), scale)
	})
	if len(m.Recent) == 0 {
		return
	}
	fold := ui.Row(c.Key("recent-memo")).Gap(8).AlignItems(ui.Center).Margin(12, 0, 0, 0)
	fold.Children(func() {
		if ui.Button(c.Key("view"), "最近播放").Clicked() {
			a.open(route{page: pageRecent})
		}
		for i, b := range m.Recent[:min(3, len(m.Recent))] {
			label := b.Track.Name
			if b.Position > 0 {
				label += fmt.Sprintf(" · %d:%02d", b.Position/60000, b.Position/1000%60)
			}
			button := ui.Button(c.Key(i), label).Shrink(1).MinWidth(0).Label("接着听 " + b.Track.Name)
			if button.Clicked() {
				a.resumeMemo(b)
			}
		}
	})
}

func memoGreeting(count int) string {
	switch {
	case count == 0:
		return "等一首心仪的歌"
	case count == 1:
		return "初次见面"
	case count < 5:
		return "又见面了"
	case count < 20:
		return "越来越熟悉"
	default:
		return "好久不见，老朋友"
	}
}

func (a *app) homeCassette(c *ui.Context, tr *netease.Track, e memoEncounter) {
	ink := a.pal.muted
	card := ui.Column(c).Size(150, 126).Shrink(0).Padding(10, 12).Gap(3).Radius(14).Background(a.pal.hover)
	card.Draw(func(p *ui.Painter, r ui.Rect) {
		tape := ui.Rect{X: r.X + 42, Y: r.Y + 12, W: 66, H: 36}
		p.Stroke(tape, ink.Alpha(.62), 6, 1.5)
		p.Stroke(ui.Rect{X: tape.X + 8, Y: tape.Y + 8, W: 50, H: 14}, ink.Alpha(.52), 6, 1)
		for _, x := range []float32{tape.X + 13, tape.X + 43} {
			p.Stroke(ui.Rect{X: x, Y: tape.Y + 11, W: 9, H: 9}, ink, 4.5, 1)
		}
		p.Line(tape.X+17, tape.Y+29, tape.X+49, tape.Y+29, 1, ink.Alpha(.62))
	}).Children(func() {
		ui.Box(c).Height(41)
		ui.Text(c, memoGreeting(e.Count)).FontSize(12).FontWeight(650).SingleLine()
		if e.Count > 0 {
			name := tr.Name
			ui.Textf(c, "%s · 第%d次相遇", name, e.Count).FontSize(10).SingleLine().TextColor(ink).Label(name)
			ui.Textf(c, "首次收听 %s", time.UnixMilli(e.First).In(time.Local).Format("2006.01.02")).FontSize(10).TextColor(ink)
		}
	})
}

func (a *app) homeScore(c *ui.Context, now time.Time, days [7]int64, scale float32) {
	hand := "Long Cang, KaiTi"
	ink := ui.Hex("#694d3d")
	var total int64
	for _, ms := range days {
		total += ms
	}
	c = c.Key("paper")
	ui.Column(c).Grow(1).MinWidth(0).Height(126).Padding(9, 16).Radius(14).Background(ui.Hex("#faf0de")).TextColor(ink).Children(func() {
		ui.Row(c).Justify(ui.SpaceBetween).Children(func() {
			ui.Text(c, "一周听歌谱").Font(hand).FontSize(22 * scale)
			ui.Textf(c, "%d 小时 %02d 分钟", total/3600000, total/60000%60).Font(hand).FontSize(16 * scale)
		})
		ui.Box(c).Height(46).Draw(func(p *ui.Painter, r ui.Rect) {
			for i := range 5 {
				y := r.Y + 11 + float32(i)*6
				p.Line(r.X, y, r.X+r.W, y, 1, ink.Alpha(.34))
			}
			cell := r.W / 7
			for i, ms := range days {
				x := r.X + float32(i)*cell
				if i > 0 {
					p.Line(x, r.Y+11, x, r.Y+35, 1, ink.Alpha(.27))
				}
				if ms == 0 {
					continue
				}
				count := 1 + min(3, int(ms/900000))
				for n := range count {
					nx := x + cell*float32(n+1)/float32(count+1)
					y := r.Y + 31 - 3*float32(min(7, int(ms/300000))+n%2)
					p.Fill(ui.Rect{X: nx - 4, Y: y, W: 8, H: 5}, ink, 3)
					p.Line(nx+3, y+2, nx+3, y-10, 1, ink)
				}
			}
		})
		start := now.Add(-4*time.Hour).AddDate(0, 0, -6)
		ui.Row(c).Children(func() {
			for i := range days {
				ui.Text(c, start.AddDate(0, 0, i).Format("01.02")).Grow(1).Center().Font(hand).FontSize(14 * scale)
			}
		})
	})
}
func loadHomeScoreFont() {
	dir, err := mygo.App.Path(mygo.PathResources)
	if err == nil {
		if b, err := os.ReadFile(filepath.Join(dir, "fonts", "LongCang-Regular.ttf")); err == nil {
			_ = ui.RegisterFont(b, "")
		}
	}
}
