// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"unicode"

	"github.com/egoist/mygo/ui"
	"netease-music-mygo/internal/netease"
)

type scoreLabel struct {
	x, y, width, size, angle float32
	family                   string
	weight                   int
	track                    netease.Track
	highlight                bool
	decoration               int
}

func scoreHand(text string) (string, bool) {
	han := false
	for _, r := range text {
		if unicode.In(r, unicode.Hiragana, unicode.Katakana, unicode.Hangul) {
			return "", false
		}
		if unicode.Is(unicode.Han, r) {
			han = true
		}
	}
	if han {
		return "Long Cang", true
	}
	return "Caveat", true
}

func scoreTime(minutes float64) string {
	m := int(math.Floor(max(0, minutes) + .5))
	return fmt.Sprintf("%dh%02d", m/60, m%60)
}

func (a *app) rhineWeekly(c *ui.Context, width, u float32) {
	now := c.Now()
	state := &a.homeSections.weekly
	if a.win != nil && a.profile != nil && !state.loading && !state.fetched.IsZero() {
		if remaining := state.fetched.Add(2 * time.Minute).Sub(now); remaining > 0 {
			c.After(remaining)
		} else {
			a.loadHomeWeekly()
		}
	}
	w := a.cachedHomeScore(now)
	hasScore := w.online || w.minutes > 0
	quote := state.quote
	footerBase := float32(236) * u
	if w.online && quote.Content != "" {
		q := state.quoteMeasure.layout(c, quote.Content, width, u, w.variant)
		footerBase = 259*u + q.height
	}
	height := footerBase/u + 32
	var statusSpace float32
	if state.err != "" {
		statusSpace = 34
		height += statusSpace
	}
	ui.Box(c).Height(height * u).Children(func() {
		ui.Row(c).Absolute().Top(0).Left(0).Right(0).Height(30 * u).AlignItems(ui.Center).Children(func() {
			ui.Box(c).Width(155 * u).Shrink(0).Children(func() { a.rhineHomeHeading(c, "这一周的谱子", "", u) })
			sub := w.days[0].date.Format("01.02") + " — " + w.days[6].date.Format("01.02") + " · 一拍是一小时，一小节一天"
			if hasScore && !w.online {
				sub += " · 仅本机记录"
			}
			ui.Text(c, sub).MinWidth(0).Shrink(1).SingleLine().FontSize(11 * u).TextColor(a.pal.muted)
			ui.Box(c).Grow(1)
			if w.comparison {
				sign := "+"
				if w.minutes < w.previous {
					sign = "−"
				}
				ui.Row(c).Gap(7 * u).Rotate(-3).Children(func() {
					ui.Text(c, "比上周").Font("Long Cang").FontSize(23 * u).TextColor(homeOrange)
					number := ui.Text(c, sign+scoreTime(math.Abs(w.minutes-w.previous))).Font("Caveat").FontWeight(600).FontSize(24 * u).TextColor(homeOrange)
					scoreUnderline(number, u, homeOrange)
					arrow := "↑"
					if sign == "−" {
						arrow = "↓"
					}
					ui.Text(c, arrow).Font("Caveat").FontSize(26 * u).TextColor(homeOrange)
				})
			}
		})
		staff := ui.Box(c.Key("staff")).Absolute().Top(59 * u).Left(0).Right(0).Height(174 * u)
		bounds := staff.Bounds()
		width := bounds.W / u
		if state.loading && !hasScore {
			staff.Draw(func(p *ui.Painter, r ui.Rect) {
				for i := range 5 {
					y := r.Y + (7+float32(i)*11)*u
					p.Line(r.X+20*u, y, r.X+r.W-20*u, y, u, a.pal.text.Alpha(.12))
				}
			})
		} else if hasScore && width > 0 {
			key := fmt.Sprintf("%.2f:%s", width, state.scoreKey)
			if key != state.drawingKey {
				state.drawingKey = key
				state.drawing, state.labels = buildScoreDrawing(c, w, width, u)
			}

			staff.Children(func() {
				ui.Image(c.Key("notation"), state.drawing).Absolute().Left(0).Right(0).Top(0).Bottom(0).Fit(ui.FillBox).PassThrough()
				ui.Text(c, "𝄞").Absolute().Top(23 * u).Left(2 * u).Font("Noto Music").FontSize(40 * u).TextColor(a.pal.text)
				ui.Column(c).Absolute().Left(34 * u).Top(62 * u).Width(36 * u).Gap(-3 * u).Children(func() {
					ui.Textf(c, "%d", int(math.Round(w.minutes))/60).FontSize(21 * u).FontWeight(900).TextAlign(ui.Center)
					ui.Textf(c, "%02d", int(math.Round(w.minutes))%60).FontSize(21 * u).FontWeight(900).TextAlign(ui.Center)
				})

				longest := -1
				for i, d := range w.days {
					if d.minutes > 0 && (longest < 0 || d.minutes > w.days[longest].minutes) {
						longest = i
					}
				}
				if longest >= 0 {
					x, span := scoreDayBounds(w, width, longest)
					ui.Row(c).Absolute().Top(8 * u).Left((x + span/2 - 48) * u).Gap(2 * u).Children(func() {
						ui.Text(c, "最长").Font("Long Cang").FontSize(21 * u).TextColor(a.pal.muted)
						ui.Text(c, scoreTime(w.days[longest].minutes)).Font("Caveat").FontSize(22 * u).FontWeight(600).TextColor(a.pal.muted)
					})
				}
				for i, d := range w.days {
					x, span := scoreDayBounds(w, width, i)
					ui.Text(c, "周"+[]string{"日", "一", "二", "三", "四", "五", "六"}[d.date.Weekday()]).Absolute().Left((x + 8) * u).Top(39 * u).FontSize(11 * u).TextColor(a.pal.muted)
					text := scoreTime(d.minutes)
					if d.date.After(c.Now()) {
						text = "—"
					}
					ui.Text(c, text).Absolute().Left(x * u).Top(112 * u).Width(span * u).TextAlign(ui.Center).FontSize(10 * u).TextColor(a.pal.muted)
				}
				for i, label := range state.labels {
					b := ui.ButtonBase(c.Key(i)).Absolute().Left(label.x*u).Top(label.y*u).Size(label.width*u, (label.size+6)*u).Rotate(label.angle).Label("播放 " + label.track.Name)
					ink := a.pal.text
					if label.highlight || b.Hovered() {
						ink = homeOrange
					}
					b.Children(func() {
						text := ui.Text(c, label.track.Name).Font(label.family).FontSize(label.size * u).FontWeight(label.weight).TextColor(ink).SingleLine()
						if label.decoration != 0 {
							opacity := float32(.75)
							if b.Hovered() {
								opacity = .15
							}
							decorationInk := ui.Hex("#71737F")
							if label.highlight {
								decorationInk = homeOrange
							}
							if label.decoration == 1 {
								scoreUnderline(text, u, decorationInk.Alpha(opacity))
							} else {
								text.Draw(func(p *ui.Painter, r ui.Rect) {
									p.Icon(scoreWaveIcon, iconRect(p, ui.Rect{X: r.X, Y: r.Y + r.H - 2*u, W: r.W, H: 7 * u}), decorationInk.Alpha(opacity))
								})
							}
						}
					})
					hot := b.Hovered() || b.FocusVisible()
					draw, alpha := b2f(hot), b2f(hot)
					if a.motion != motionOff && !c.Preferences().ReduceMotion {
						draw = b.AnimateTo("hand-draw", draw, ui.Animation{Duration: 360 * time.Millisecond, Ease: ui.EaseInOut})
						alpha = b.AnimateTo("hand-opacity", alpha, ui.Animation{Duration: 140 * time.Millisecond, Ease: ui.Linear})
					}
					if alpha > 0 {
						b.Draw(func(p *ui.Painter, r ui.Rect) { scoreHandCircle(p, r, u, draw, alpha) })
					}
					if b.Clicked() {
						a.pl.PlayQueue([]netease.Track{label.track}, 0)
					}
				}
			})
		}
		if state.loading && !w.online {
			ui.Text(c, "正在读取听歌周报…").Absolute().Top(145 * u).Left(80 * u).FontSize(12 * u).TextColor(a.pal.muted)
		} else if state.err != "" {
			ui.Row(c).Absolute().Top(235 * u).Left(0).Gap(8 * u).AlignItems(ui.Center).Children(func() {
				message := state.err
				if hasScore && !w.online {
					message += "，显示本机记录"
				}
				ui.Text(c, message).FontSize(11 * u).TextColor(a.pal.muted)
				if ui.Button(c.Key("retry"), "重新读取").Clicked() {
					a.loadHomeWeekly()
				}
			})
		}
		if !hasScore && !state.loading && state.err == "" {
			ui.Text(c, "暂无听歌足迹").Absolute().Top(92 * u).Left(0).Right(0).TextAlign(ui.Center).FontSize(12 * u).TextColor(a.pal.muted)
		}
		footer := footerBase/u + statusSpace
		if w.online && quote.Content != "" {
			a.drawScoreQuote(c.Key("quote"), quote, state.quoteMeasure, w, u, statusSpace)
		}
		if w.top.SongName != "" {
			ui.Row(c).Absolute().Top(footer * u).Left(0).Gap(5 * u).AlignItems(ui.Center).Children(func() {
				ui.Text(c, w.label).Font("Long Cang").FontSize(20 * u).TextColor(homeOrange)
				family, supported := scoreHand(w.top.SongName)
				size := float32(21)
				if !supported {
					size = 13
				}
				b := ui.ButtonBase(c.Key("top-song")).Label("播放周谱最多循环：" + w.top.SongName).Height(27 * u).MaxWidth(278 * u).PaddingX(24 * u)
				ink := homeInk
				if b.Hovered() {
					ink = homeOrange
				}
				b.Children(func() { ui.Text(c, w.top.SongName).Font(family).FontSize(size * u).TextColor(ink).SingleLine() })
				hot := b2f(b.Hovered() || b.FocusVisible())
				draw, alpha := hot, hot
				if a.motion != motionOff && !c.Preferences().ReduceMotion {
					draw = b.AnimateTo("ring", hot, ui.Animation{Duration: 360 * time.Millisecond, Ease: ui.EaseInOut})
					alpha = b.AnimateTo("ring-alpha", hot, ui.Animation{Duration: 140 * time.Millisecond})
				}
				if alpha > 0 {
					b.Draw(func(p *ui.Painter, r ui.Rect) { r.X += 24 * u; r.W -= 48 * u; scoreHandCircle(p, r, u, draw, alpha) })
				}
				if b.Clicked() {
					a.pl.PlayQueue([]netease.Track{{ID: w.top.SongID, Name: w.top.SongName}}, 0)
				}
				ui.Textf(c, "×%d !!", w.top.PlayCount).Font("Caveat").FontSize(24 * u).Rotate(-4).TextColor(homeOrange)
			})
		}
		if hasScore {
			ui.Text(c, "音符按每日总时长，约至15分钟").Absolute().Top((footer + 6) * u).Right(0).FontSize(9 * u).TextColor(a.pal.muted)
		}
	})
}

type scoreQuoteMeasure struct {
	text, font                               string
	viewport, unit                           float32
	variant                                  int
	textSize, textWidth, width, height, left float32
	face                                     bool
}

func (q *scoreQuoteMeasure) layout(c *ui.Context, text string, width, u float32, variant int) scoreQuoteMeasure {
	if q.text == text && q.viewport == width && q.unit == u && q.variant == variant {
		return *q
	}
	font, hand := scoreHand(text)
	size := 15 * u
	if hand {
		size = 22 * u
	}
	face := variant != 1 && width > 640*u
	extra := float32(52) * u
	if face {
		extra = 88 * u
	}
	span := ui.Span{Text: text, Font: font, Size: size, Weight: 400}
	textWidth := min(homeTextWidth(c, span)+1, max(1, min(600*u, width-32*u)-extra))
	_, textHeight := c.MeasureText(textWidth, span)
	noteWidth := textWidth + extra
	anchor := [4]float32{.54, .62, .40, .56}[variant]
	left := max(12*u, min(width-noteWidth-12*u, width*anchor-noteWidth/2))
	*q = scoreQuoteMeasure{text, font, width, u, variant, size, textWidth, noteWidth, max(32*u, textHeight+10*u), left, face}
	return *q
}

var scoreQuoteStroke = ui.MustParseSVG([]byte(`<svg xmlns="http://www.w3.org/2000/svg" width="8" height="12" viewBox="0 0 8 12"><path d="M6 1 C0 2 0 8 2 10 C5 11 6 7 3 7" fill="none" stroke="currentColor" stroke-width="1.45" stroke-linecap="round"/></svg>`))
var scoreQuoteFace = ui.MustParseSVG([]byte(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="28" viewBox="0 0 32 28"><ellipse cx="7" cy="7" rx="2.3" ry="3"/><ellipse cx="23" cy="6" rx="2.3" ry="3"/><path d="M12 16 C14 21 18 21 21 16" fill="none" stroke="currentColor" stroke-width="1.45" stroke-linecap="round"/></svg>`))

func (a *app) drawScoreQuote(c *ui.Context, quote memoScoreQuote, q scoreQuoteMeasure, w scoreWeek, u, statusSpace float32) {
	rotation := [4]float32{-1.4, 1.1, -.6, 1.7}[w.variant]
	author := quote.Author
	if author == "" {
		author = "云村听友"
	}
	note := ui.ButtonBase(c).Label("查看周谱短评").Tooltip("热门短评 · "+author+"\n《"+w.top.SongName+"》 · 点击查看评论").
		Absolute().Top((247+statusSpace)*u).Left(q.left).Size(q.width, q.height).Rotate(rotation)
	ink := ui.Hex("#8C8E9A")
	if note.Hovered() {
		ink = ui.Hex("#646773")
	}
	note.Children(func() {
		ui.Text(c, quote.Content).Absolute().Left(23 * u).Top(3 * u).Width(q.textWidth).
			Font(q.font).FontSize(q.textSize).FontWeight(400).TextColor(ink)
		for _, x := range []float32{6, 14} {
			ui.Icon(c, scoreQuoteStroke).Absolute().Left(x*u).Top(0).Size(8*u, 12*u).TextColor(ink)
		}
		for i, x := range []float32{36, 43} {
			ui.Icon(c, scoreQuoteStroke).Absolute().Left(q.textWidth+x*u).Bottom(float32(3-i*2)*u).
				Size(8*u, 12*u).Rotate(180).TextColor(ink)
		}
		if q.face {
			tilt := float32(7)
			if w.variant == 2 {
				tilt = -9
			}
			ui.Icon(c, scoreQuoteFace).Absolute().Left(q.textWidth+55*u).Top(q.height/2-12*u).
				Size(32*u, 28*u).Rotate(tilt).TextColor(ui.Hex("#747782"))
		}
	})
	if note.Clicked() {
		a.openCollectionSocial(fmt.Sprint("R_SO_4_", w.top.SongID), w.top.SongName, 0)
	}
}

func rhythmAdvance(v int) float32 {
	n := 12 + 4*float32(math.Log2(float64(v)))
	if v == 3 || v == 6 || v == 12 {
		n += 6
	}
	if v <= 3 {
		n += 4
	}
	return n
}
func scoreDayBounds(w scoreWeek, width float32, index int) (float32, float32) {
	var needs [7]float32
	var sum float32
	for i, d := range w.days {
		needs[i] = 48
		if d.minutes > 0 {
			needs[i] = 24
			for _, v := range scoreRhythm(d.minutes, (i+w.variant)%4) {
				needs[i] += rhythmAdvance(v)
			}
		}
		sum += needs[i]
	}
	available := max(450, width-82)
	compression := min(1, available/(sum+105))
	slack := max(0, available-sum*compression)
	x := float32(78)
	for i := range index {
		x += needs[i]*compression + slack/7
	}
	return x, needs[index]*compression + slack/7
}

// Draw the original QML notation with SVG paths: MyGo Painter.Line cannot
// represent sloping stems, curved flags, ties, or the loose handwritten rings.
func buildScoreDrawing(c *ui.Context, w scoreWeek, width, u float32) (*ui.SVG, []scoreLabel) {
	var svg strings.Builder
	fmt.Fprintf(&svg, `<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="174" viewBox="0 0 %g 174">`, width, width)
	path := func(d, color string, stroke float32) {
		fmt.Fprintf(&svg, `<path d="%s" fill="none" stroke="%s" stroke-width="%g" stroke-linecap="round" stroke-linejoin="round"/>`, d, color, stroke)
	}
	for i := range 5 {
		y := 64 + i*9
		path(fmt.Sprintf("M0 %d H%g", y, width), "#C9CBD4", 1)
	}
	var labels []scoreLabel
	longest := 0
	for i, d := range w.days {
		if d.minutes > w.days[longest].minutes {
			longest = i
		}
	}
	type box struct{ x, y, w, h float32 }
	var occupied []box
	for i, d := range w.days {
		x, span := scoreDayBounds(w, width, i)
		end := x + span
		if i == 6 {
			path(fmt.Sprintf("M%g 64 V100", end), "#1A1B22", 2.6)
			path(fmt.Sprintf("M%g 64 V100", end-5), "#1A1B22", 1)
		} else {
			path(fmt.Sprintf("M%g 64 V100", end), "#C9CBD4", 1)
		}
		if d.minutes == 0 {
			fmt.Fprintf(&svg, `<rect x="%g" y="78" width="10" height="4" fill="#9699A4"/>`, x+span/2-5)
		}
	}
	for i, d := range w.days {
		if d.minutes == 0 {
			continue
		}
		x, span := scoreDayBounds(w, width, i)
		values := scoreRhythm(d.minutes, (i+w.variant)%4)
		var required float32
		for _, v := range values {
			required += rhythmAdvance(v)
		}
		// Qt compresses all days together, preserving their relative rhythm spacing.
		var totalNeed float32
		for day, entry := range w.days {
			need := float32(48)
			if entry.minutes > 0 {
				need = 24
				for _, value := range scoreRhythm(entry.minutes, (day+w.variant)%4) {
					need += rhythmAdvance(value)
				}
			}
			totalNeed += need
		}
		compress := min(1, max(450, width-82)/(totalNeed+105))
		nx := x + (span-required*compress)/2 + 6*compress
		hour, weight := float64(0), float64(0)
		for _, s := range d.sessions {
			hour += (float64(s.at.Hour()) + float64(s.at.Minute())/60) * s.weight
			weight += s.weight
		}
		y := float32(82)
		if weight > 0 {
			y = 113.5 - float32(hour/weight)/23*58.5
		}
		for n, v := range values {
			ny := y + []float32{0, -1, 1, 0, -.5}[(n+i+w.variant)%5]*5.85
			color := "#1A1B22"
			if weight == 0 {
				color = "#9699A4"
			}
			highlight := false
			for _, s := range d.sessions {
				if s.track.ID == w.top.SongID && w.top.SongID > 0 {
					highlight = true
				}
			}
			if highlight && n == 0 {
				color = "#FF6A3D"
			}
			for ly := float32(109); ly <= ny+1; ly += 9 {
				path(fmt.Sprintf("M%g %g H%g", nx-9, ly, nx+9), "#C9CBD4", 1)
			}
			up := ny > 82
			stemX, stemY := nx-5.52, ny+31.5
			if up {
				stemX, stemY = nx+5.52, ny-31.5
			}
			if v < 16 {
				path(fmt.Sprintf("M%g %g V%g", stemX, ny, stemY), color, 1.3)
				flags := 0
				if v <= 1 {
					flags = 2
				} else if v <= 3 {
					flags = 1
				}
				for f := range flags {
					direction := float32(1)
					if !up {
						direction = -1
					}
					fy := stemY + direction*float32(f)*7.65
					path(fmt.Sprintf("M%g %g Q%g %g %g %g", stemX, fy, stemX+8.1, fy+direction*9.9, stemX+6.75, fy+direction*20.7), color, 1.3)
				}
			}
			rx, ry, angle, stroke := 6.12, 4.5, -22, 1.5
			if v == 16 {
				rx, ry, angle, stroke = rx*1.18, ry*1.1, -12, 9*.32
			}
			ellipse := fmt.Sprintf(`<ellipse cx="%g" cy="%g" rx="%g" ry="%g" transform="rotate(%d %g %g)"`, nx, ny, rx, ry, angle, nx, ny)
			fill := color
			if v >= 8 {
				fill = "#ECEDF3"
			}
			fmt.Fprintf(&svg, `%s fill="%s"/>%s fill="none" stroke="%s" stroke-width="%g"/>`, ellipse, fill, ellipse, color, stroke)
			if v == 3 || v == 6 || v == 12 {
				fmt.Fprintf(&svg, `<circle cx="%g" cy="%g" r="1.6" fill="%s"/>`, nx+10.62, ny-2.7, color)
			}
			if n+1 < len(values) {
				direction := float32(-1)
				if up {
					direction = 1
				}
				yy := ny + direction*6.75
				next := nx + rhythmAdvance(v)*compress
				path(fmt.Sprintf("M%g %g Q%g %g %g %g", nx+4, yy, (nx+next)/2, yy+direction*6.75, next-4, yy), color, 1.3)
			}
			if highlight && n == 0 {
				seed := i*7 + 3
				var ring strings.Builder
				for k := 0; k <= 24; k++ {
					seed = (seed*9301 + 49297) % 233280
					t := float64(k) / 24 * 1.12
					angle := -2.2 + t*math.Pi*2
					q := 1 + (float64(seed)/233280-.5)*.1 + t*.07
					command := "L"
					if k == 0 {
						command = "M"
					}
					fmt.Fprintf(&ring, "%s%g %g ", command, float64(nx)+14*q*math.Cos(angle), float64(ny)+11*q*math.Sin(angle))
				}
				path(ring.String(), "#FF6A3D", 1.4)
			}
			nx += rhythmAdvance(v) * compress
		}
		if i == longest {
			var bracket strings.Builder
			fmt.Fprintf(&bracket, "M%g 39 V34 ", x+5)
			seed := 11
			steps := max(4, int(math.Round(float64((span-11)/26))))
			for k := 1; k <= steps; k++ {
				seed = (seed*9301 + 49297) % 233280
				fmt.Fprintf(&bracket, "L%g %g ", x+5+(span-11)*float32(k)/float32(steps), 34+(float64(seed)/233280-.5)*2.2)
			}
			fmt.Fprintf(&bracket, "L%g 39", x+span-6)
			path(bracket.String(), "#8C8E9A", 1.2)
		}
	}
	type candidate struct {
		session    scoreSession
		day, order int
		anchor     float32
		high       bool
	}
	var candidates []candidate
	seen := map[int64]bool{}
	for day, d := range w.days {
		if d.minutes <= 0 {
			continue
		}
		x, span := scoreDayBounds(w, width, day)
		for order, session := range d.sessions {
			if session.track.Name == "" || seen[session.track.ID] {
				continue
			}
			seen[session.track.ID] = true
			candidates = append(candidates, candidate{session, day, order, x + span*(.15+.7*float32(session.at.Hour())/24), session.track.ID == w.top.SongID})
		}
	}
	sort.SliceStable(candidates, func(i, j int) bool {
		a, b := candidates[i], candidates[j]
		if a.high != b.high {
			return a.high
		}
		return a.session.weight > b.session.weight
	})
	lx, lw := scoreDayBounds(w, width, longest)
	if w.days[longest].minutes > 0 {
		occupied = append(occupied, box{lx - 4, 3, lw + 8, 37})
	}
	var perDay [7]int
	decorated := 0
	for candidateIndex, item := range candidates {
		_, span := scoreDayBounds(w, width, item.day)
		if len(labels) >= int((width-78)/85)+4 || perDay[item.day] >= min(4, max(2, int(span/75))) {
			continue
		}
		var hash uint32
		for _, r := range fmt.Sprint(item.session.track.ID) {
			hash = hash*31 + uint32(r)
		}
		hand := item.high || (len(labels)+w.variant)%4 == 2
		family := ""
		size := float32(11.5) + float32(hash%3)*.75
		weight := 500
		if hand {
			if f, ok := scoreHand(item.session.track.Name); ok {
				family = f
				size = 18.5
				weight = 600
				if f == "Long Cang" {
					weight = 400
				}
				if item.high {
					size = 21
				}
			}
		}
		if item.high && family == "" {
			size = 14
			weight = 700
		}
		tw, _ := c.MeasureText(0, ui.Span{Text: item.session.track.Name, Font: family, Size: size * u, Weight: weight})
		tw = min(220, tw/u+10)
		upper, lower := []float32{-24, 8}, []float32{130, 151}
		if hash%2 != 0 {
			upper = []float32{8, -24}
		}
		if hash%3 == 0 {
			lower = []float32{151, 130}
		}
		preferAbove := family != ""
		switch w.variant % 4 {
		case 0:
			upper = []float32{-24, 8}
		case 1:
			preferAbove = (item.day+item.order)%2 == 0
		case 2:
			preferAbove = item.anchor < width/2
			upper = []float32{8, -24}
			lower = []float32{151, 130}
		case 3:
			upper, lower = []float32{-24, 8}, []float32{130, 151}
			preferAbove = item.high || candidateIndex%3 == 0
		}
		lanes := append(append([]float32{}, lower...), upper...)
		if preferAbove {
			lanes = append(append([]float32{}, upper...), lower...)
		}
		bestCost := float32(math.MaxFloat32)
		var best scoreLabel
		var bestBox box
		for laneIndex, lane := range lanes {
			for _, shift := range []float32{0, -18, 18, -38, 38} {
				spread := float32(0)
				if w.variant%4 == 2 {
					spread = 18
					if item.anchor < width/2 {
						spread = -18
					}
				}
				x := max(78, min(width-tw-8, item.anchor-tw/2+shift+spread))
				y := lane
				if family != "" {
					y += float32(int(hash%3)-1) * 2
				}
				b := box{x - 5, y - 5, tw + 10, size + 16}
				blocked := false
				for _, o := range occupied {
					if b.x < o.x+o.w && b.x+b.w > o.x && b.y < o.y+o.h && b.y+b.h > o.y {
						blocked = true
						break
					}
				}
				cost := float32(laneIndex)*18 + float32(math.Abs(float64(x+tw/2-item.anchor)))
				if !blocked && cost < bestCost {
					angle := float32(0)
					if family != "" {
						angle = float32(int(hash%7)-3) * 1.1
					}
					bestCost = cost
					bestBox = b
					best = scoreLabel{x, y, tw, size, angle, family, weight, item.session.track, item.high, 0}
				}
			}
		}
		if bestCost < float32(math.MaxFloat32) {
			occupied = append(occupied, bestBox)
			if best.family != "" && decorated < 2 {
				best.decoration = 2
				if best.highlight {
					best.decoration = 1
				}
				decorated++
			}
			labels = append(labels, best)
			perDay[item.day]++
		}
	}

	svg.WriteString("</svg>")
	return ui.MustParseSVG([]byte(svg.String())), labels
}

func weekDifference(ms int64) string {
	sign := "+"
	if ms < 0 {
		sign, ms = "−", -ms
	}
	return fmt.Sprintf("%s%d 小时 %02d 分钟", sign, ms/3600000, ms/60000%60)
}

// QML HandCircle's wrist wobble, overlap, and variable pen pressure. Segments
// use transformed fills because Painter.Line only supports axis-aligned lines.
func scoreHandCircle(p *ui.Painter, r ui.Rect, u, progress, opacity float32) {
	width, height := r.W+48*u, r.H*1.5+34*u
	left, top := r.X-24*u, r.Y-r.H*.25-17*u
	var px, py float32
	steps := int(math.Ceil(float64(112 * progress)))
	for k := 0; k <= steps; k++ {
		t := math.Min(float64(progress), float64(k)/112)
		a := -2.25 + t*math.Pi*2.34
		rx, ry := float64(width/2-4*u), float64(height/2-4*u)
		lap := math.Max(0, (t-.82)/.18)
		x := left + width/2 + float32(rx*(math.Cos(a)+.035*math.Sin(2*a)+.012*math.Sin(5*a))*(1-.035*lap)+lap*2*float64(u))
		y := top + height/2 + float32(ry*(math.Sin(a)+.075*math.Cos(2*a)+.022*math.Sin(3*a))+math.Cos(a)*1.2*float64(u)+lap*2*float64(u))
		if k > 0 {
			dx, dy := x-px, y-py
			length := float32(math.Hypot(float64(dx), float64(dy)))
			stroke := float32(1.45+.28*math.Sin(a+.8)+.12*math.Sin(3*a)) * u
			p.Transform(ui.Rotation(float32(math.Atan2(float64(dy), float64(dx))*180/math.Pi)), px, py, func() {
				p.Fill(ui.Rect{X: px, Y: py - stroke/2, W: length, H: stroke}, homeOrange.Alpha(opacity), stroke/2)
			})
		}
		px, py = x, y
	}
}

// Cached vector ornament, matching the two loose strokes on QML handwritten labels.
var scoreWaveIcon = ui.MustParseSVG([]byte(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 7" width="100" height="7"><path d="M8 3 Q18 1 28 3 Q38 5 48 3 Q58 1 68 3 Q78 5 88 3" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round"/></svg>`))

var scoreUnderlineIcon = ui.MustParseSVG([]byte(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 7" width="100" height="7"><path d="M4 1 Q45 2 96 1 M4 4 Q45 5 88 4" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round"/></svg>`))

func scoreUnderline(e ui.Element, u float32, ink ui.Color) {
	e.Draw(func(p *ui.Painter, r ui.Rect) {
		p.Icon(scoreUnderlineIcon, iconRect(p, ui.Rect{X: r.X, Y: r.Y + r.H - 2*u, W: r.W, H: 7 * u}), ink)
	})
}

// iconRect puts r on whole device pixels, origin and size each rounded.
// Painter.Icon caches an icon's mask by its size in pixels, which it gets
// by rounding both edges: at a fractional scroll offset that size flips by
// a pixel from frame to frame, and the icon is drawn again each time, for
// the score's staff a mask as wide as the page.
func iconRect(p *ui.Painter, r ui.Rect) ui.Rect {
	s := p.Scale()
	px := func(v float32) float32 { return float32(math.Round(float64(v*s))) / s }
	return ui.Rect{X: px(r.X), Y: px(r.Y), W: px(r.W), H: px(r.H)}
}
