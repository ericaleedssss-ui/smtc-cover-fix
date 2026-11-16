// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/egoist/mygo/ui"
	"netease-music-mygo/internal/netease"
	"netease-music-mygo/internal/player"
)

var (
	homeInk    = ui.Hex("#1a1b22")
	homeOrange = ui.Hex("#ff6a3d")
)

// Rhine: the ranking column spans both rows of HomePageB.
func (a *app) rhineHomeLead(c *ui.Context, width, u float32) {
	col := (width - 60*u) / 4
	daily, left := 2*col+20*u, 3*col+40*u
	ui.Box(c.Key("home-lead")).Height((260 + 162*1.12) * u).Children(func() {
		a.rhineDaily(c.Key("daily"), daily, u)
		a.rhineFM(c.Key("fm"), daily+20*u, col, u)
		a.rhineRank(c.Key("rank"), left+20*u, col, u)
		a.rhineRail(c.Key("modes"), left, u)
	})
}

func (a *app) homeSurface() ui.Color {
	if !a.pal.dark && a.settings.Accent == "" {
		return ui.Hex("#ECEDF3")
	}
	return a.pal.bg
}

func (a *app) homeGlass() bool {
	return a.settings.LiquidGlass && !a.settings.PowerSaver
}

func (a *app) homeBackdrop(c *ui.Context) {
	track := a.pl.Current()
	if !a.homeGlass() || track == nil {
		a.homeSections.backdropCurrent, a.homeSections.backdropPrevious = nil, nil
		return
	}
	art := a.art.get(netease.Sized(track.Album.PicURL, 96), true)
	if art == nil || art.backdrop == nil {
		return
	}
	state := &a.homeSections
	if state.backdropCurrent != art {
		state.backdropPrevious, state.backdropCurrent = state.backdropCurrent, art
		state.backdropChanged = c.Now()
	}
	progress := min(1, float32(c.Now().Sub(state.backdropChanged))/float32(700*time.Millisecond))
	if a.motion == motionOff || c.Preferences().ReduceMotion || state.backdropPrevious == nil {
		progress = 1
	}
	progress = ui.EaseOut(progress)
	if progress >= 1 {
		state.backdropPrevious = nil
	}
	if progress < 1 {
		c.AnimationFrame()
	}
	previous := state.backdropPrevious
	ui.Box(c).Absolute().Top(0).Right(0).Bottom(0).Left(0).PassThrough().Draw(func(p *ui.Painter, r ui.Rect) {
		tone := art.tint
		if previous != nil {
			tone = previous.tint.Mix(tone, progress)
		}
		p.FillGradient(r, ui.LinearGradient{Angle: 180, Stops: []ui.GradientStop{
			{Color: tone.Alpha(.28), At: 0}, {Color: tone.Alpha(.04), At: 1},
		}}, 0)
		if previous != nil {
			p.ImageRegion(previous.backdrop, ui.Rect{W: 48, H: 48}, r, ui.ImageOptions{Tint: white.Alpha(.32 * (1 - progress))})
		}
		p.ImageRegion(art.backdrop, ui.Rect{W: 48, H: 48}, r, ui.ImageOptions{Tint: white.Alpha(.32 * progress)})
	})
}

func (a *app) homeCoverPlaceholder() ui.Color {
	if a.pal.dark {
		return a.pal.hover
	}
	return ui.Hex("#D6D8E1")
}

func (a *app) homeFrost(card ui.Element, radius float32) ui.Element {
	surface := white
	if a.pal.dark {
		surface = a.pal.bg.Mix(a.pal.text, .09)
	}
	card.Radius(radius)
	if a.homeGlass() {
		return card.Gradient(surface.Alpha(.66), surface.Alpha(.52), 180).Border(1, white.Alpha(.50))
	}
	return card.Border(0, ui.Transparent).Background(surface)
}

func homeRound(c *ui.Context, symbol *ui.SVG, title string, size, glyph float32, fg, bg ui.Color) ui.Element {
	button := ui.ButtonBase(c).Size(size, size).Radius(size / 2).Center().Label(title).Background(bg)
	if button.Hovered() {
		button.Background(bg.Mix(white, .12))
	}
	button.Children(func() { ui.Icon(c, symbol).Size(glyph, glyph).TextColor(fg) })
	return button
}

func (a *app) rhineDaily(c *ui.Context, width, u float32) {
	songs := a.daily
	loading := a.homeSections.dailyLoading
	index, owns := 0, false
	if current := a.pl.Current(); current != nil && a.pl.Radio() == "" && current.LocalPath == "" && current.ProgramID == 0 {
		for i := range songs {
			if current.ID == songs[i].ID {
				index, owns = i, true
				break
			}
		}
	}
	playing := owns && a.pl.Playing()
	toggle := func() {
		switch {
		case owns:
			a.pl.TogglePlay()
		case len(songs) > 0:
			a.pl.PlayQueue(songs, firstPlayable(songs))
		case a.profile == nil:
			a.openLogin()
		default:
			a.loadHomeDaily()
		}
	}
	now := c.Now()
	var total int64
	for _, song := range songs {
		total += song.Duration
	}
	minutes := (total + 30000) / 60000
	title := "今日推荐，等你来听"
	if loading {
		title = "正在挑选好音乐"
	}
	if len(songs) > 0 {
		title = songs[index].Name
	}
	card := ui.Box(c).Absolute().Top(0).Left(0).Size(width, 240*u).Radius(20 * u).Background(homeOrange)
	card.LinearGradient(ui.LinearGradient{Angle: 38, Stops: []ui.GradientStop{
		{At: .35, Color: homeOrange}, {At: 1, Color: ui.Hex("#ff805b")},
	}})
	hovered := card.Hovered()
	card.Children(func() {
		ui.Row(c).Absolute().Top(20 * u).Left(24 * u).Right(24 * u).Height(24 * u).AlignItems(ui.Center).Gap(8 * u).Children(func() {
			ui.Row(c).Gap(u).Height(24 * u).AlignItems(ui.Start).Children(func() {
				ui.Text(c, "每日推荐").FontSize(15 * u).FontWeight(900).TextColor(homeInk).SingleLine()
				ui.Text(c, "®").FontSize(8*u).FontWeight(700).TextColor(homeInk).Translate(0, -2*u)
			})
			ui.Textf(c, "No.%d", now.YearDay()).Font("Consolas").FontSize(10.5 * u).TextColor(homeInk.Alpha(.65))
			ui.Textf(c, "%s · %d TRACKS · %dH%02dM", strings.ToUpper(now.Format("01.02 Mon")), len(songs), minutes/60, minutes%60).
				Grow(1).MinWidth(0).TextAlign(ui.End).SingleLine().Font("Consolas").FontSize(11 * u).LetterSpacing(u).TextColor(homeInk.Alpha(.76))
		})
		ui.Box(c).Absolute().Top(48.5 * u).Left(24 * u).Right(24 * u).Height(1.5 * u).Background(homeInk)
		reduced := a.motion == motionOff || c.Preferences().ReduceMotion
		next := homeCopy{title: title}
		if len(songs) != 0 {
			next.key = fmt.Sprint(songs[index].ID)
			next.index, next.duration = index, songs[index].Length()
		}
		transition := &a.homeSections.dailyTitle
		if transition.current.key == next.key {
			transition.current = next
		}
		copy, opacity := transition.frame(c, next, reduced || next.key == "" || transition.current.key == "", 0)
		indexText, timeText := fmt.Sprintf("%02d/%d", copy.index+1, len(songs)), dailyClock(copy.duration)
		iw, _ := c.MeasureText(0, ui.Span{Text: indexText, Font: "Consolas", Size: 10 * u})
		tw, _ := c.MeasureText(0, ui.Span{Text: timeText, Font: "Consolas", Size: 10 * u})
		tagWidth := iw + tw + 22*u
		available := max(1, width-48*u-tagWidth-12*u)
		ui.Row(c).Absolute().Top(62*u).Left(24*u).Right(24*u).Height(68*u).Gap(12*u).AlignItems(ui.Start).
			Opacity(opacity).Translate(0, a.homeSections.dailyTitle.offset(c.Now(), 0)*6*u).Children(func() {
			headline := ui.ButtonBase(c.Key("title")).Label(copy.title).Tooltip(copy.title).
				Height(60 * u).MaxWidth(available).AlignItems(ui.Center).Justify(ui.Start).MinWidth(0).Shrink(1)
			headline.Children(func() {
				size := float32(60)
				titleWidth, _ := c.MeasureText(0, ui.Span{Text: copy.title, Size: 60 * u, Weight: 900, LetterSpacing: -2.7 * u})
				size = max(38, min(size, float32(math.Floor(float64(60*available/max(1, titleWidth))/2))*2))
				ui.Text(c, copy.title).MaxWidth(available).FontSize(size * u).LetterSpacing(-.045 * size * u).FontWeight(900).SingleLine().TextColor(homeInk)
			})
			if headline.Clicked() && (!loading || len(songs) > 0) {
				toggle()
			}
			if copy.index < len(songs) {
				ui.Row(c).Size(tagWidth, 23*u).Margin(6*u, 0, 0, 0).Padding(u).Radius(3*u).Border(1.2*u, homeInk).Shrink(0).Children(func() {
					background, ink := ui.Color{}, homeInk
					if playing {
						background, ink = homeInk, homeOrange
					}
					ui.Box(c).Width(iw + 10*u).FillHeight().Background(background).Center().Children(func() {
						ui.Text(c, indexText).Font("Consolas").FontSize(10 * u).TextColor(ink)
					})
					ui.Box(c).Width(tw + 10*u).FillHeight().Center().Children(func() {
						ui.Box(c).Absolute().Left(0).Top(0).Bottom(0).Width(1.2 * u).Background(homeInk)
						ui.Text(c, timeText).Font("Consolas").FontSize(10 * u).TextColor(homeInk)
					})
				})
			}
			fraction := b2f(hovered)
			if playing {
				fraction = 0
				if duration := a.pl.Duration(); duration > 0 {
					fraction = float32(float64(a.pl.Position()) / float64(duration))
				}
				c.After(50 * time.Millisecond)
			}
			if !reduced {
				d, ease := 500*time.Millisecond, homeCopyEase
				if playing {
					d, ease = 180*time.Millisecond, ui.Linear
				}
				fraction = headline.AnimateTo("underline", fraction, ui.Animation{Duration: d, Ease: ease})
			}
			headline.Draw(func(p *ui.Painter, r ui.Rect) {
				// Keep the original spacing with a small 2u downward correction.
				line := ui.Rect{X: r.X, Y: r.Y + 67*u, W: r.W, H: 3 * u}
				if playing {
					p.Fill(line, homeInk.Alpha(.18), 0)
				}
				line.W *= max(0, min(1, fraction))
				p.Fill(line, homeInk, 0)
			})
		})
		ui.Box(c).Absolute().Top(62*u).Right(7*u).Size(0, 10*u).PassThrough().Children(func() {
			ui.Text(c, "RHINE — DAILY 06:00").Absolute().Left(0).Top(0).Width(145*u).
				Font("Consolas").FontSize(8*u).LetterSpacing(1.3*u).TextColor(homeInk.Alpha(.48)).
				TransformOrigin(0, 0).Rotate(90)
		})
		if len(songs) > 1 {
			ui.Row(c).Absolute().Top(140 * u).Left(24 * u).Right(42 * u).Height(30 * u).Clip().Gap(0).AlignItems(ui.Center).Children(func() {
				ui.Text(c, "NEXT").Font("Consolas").FontSize(10 * u).LetterSpacing(u).Width(44 * u).Shrink(0).TextColor(homeInk.Alpha(.58))
				used, budget := float32(0), max(1, width-48*u-18*u-44*u-60*u)
				for offset := 1; offset <= min(3, len(songs)-1); offset++ {
					i := (copy.index + offset) % len(songs)
					w, _ := c.MeasureText(0, ui.Span{Text: songs[i].Name, Size: 22 * u, Weight: 900, LetterSpacing: -.44 * u})
					w = min(300*u, w)
					gap := float32(0)
					if offset > 1 {
						gap = 16 * u
					}
					if offset > 1 && used+gap+w > budget {
						break
					}
					w = min(w, max(1, budget-used-gap))
					used += gap + w
					button := ui.ButtonBase(c.Key(i)).Label("播放 " + songs[i].Name).Tooltip(songs[i].Name).
						MinWidth(0).Shrink(0).Height(30 * u).AlignItems(ui.Center).Justify(ui.Start)
					ink := homeInk
					if button.Hovered() || button.FocusVisible() {
						ink = white
					}
					if !reduced {
						ink = button.AnimateColor("ink", ink, ui.Animation{Duration: 200 * time.Millisecond, Ease: ui.Linear})
					}
					extra := 60 * u * b2f(button.Hovered() || button.FocusVisible())
					if !reduced {
						extra = button.AnimateTo("duration-width", extra, ui.Animation{Duration: 300 * time.Millisecond, Ease: ui.Linear})
					}
					button.Children(func() {
						if gap > 0 {
							ui.Text(c, "/").Width(gap).Shrink(0).TextAlign(ui.Center).FontSize(22 * u).FontWeight(900).TextColor(homeInk.Alpha(.45))
						}
						ui.Text(c, songs[i].Name).Width(w).Shrink(0).FontSize(22 * u).FontWeight(900).LetterSpacing(-.44 * u).TextColor(ink).SingleLine()
						ui.Box(c).Width(extra).Height(30 * u).Shrink(0).Clip().Justify(ui.Center).AlignItems(ui.Start).Children(func() {
							ui.Text(c, " ▸ "+dailyClock(songs[i].Length())).Font("Consolas").FontSize(10.5 * u).TextColor(white).SingleLine()
						})
					})
					if button.Clicked() {
						a.pl.PlayQueue(songs, i)
					}
				}
			})
		}
		a.rhineDailyArtists(c.Key("artists"), songs, copy.index, u)
		icon, label := iconPlay, "播放每日推荐"
		switch {
		case playing:
			icon, label = iconPause, "暂停每日推荐"
		case len(songs) == 0 && a.profile == nil && !loading:
			label = "登录后查看每日推荐"
		case len(songs) == 0 && !loading:
			label = "重新读取每日推荐"
		}
		play := homeRound(c.Key("play"), icon, label, 46*u, 17*u, homeOrange, homeInk).
			Absolute().Right(24 * u).Top(133 * u).Disabled(loading && len(songs) == 0)
		lift := b2f(hovered)
		if !reduced {
			lift = play.AnimateTo("lift", lift, ui.Animation{Duration: 300 * time.Millisecond, Ease: homeCopyEase})
		}
		play.Scale(1+.06*lift, 1+.06*lift).Shadow(0, 6*u, 12*u, 0, homeInk.Alpha(.25*lift))
		if play.Clicked() {
			toggle()
		}
	})
}

func dailyClock(d time.Duration) string { return clock(d.Truncate(time.Second)) }

func (a *app) rhineDailyArtists(c *ui.Context, songs []netease.Track, index int, u float32) {
	type credit struct {
		name string
		song int
	}
	key := func(artist netease.Artist) netease.Artist {
		if artist.ID != 0 {
			return netease.Artist{ID: artist.ID}
		}
		return artist
	}
	first := make(map[netease.Artist]int)
	for i, song := range songs {
		for _, artist := range song.Artists {
			if artist.Name == "" {
				continue
			}
			if k := key(artist); first[k] == 0 {
				first[k] = i + 1
			}
		}
	}
	var artists []credit
	for i := range songs {
		song := (index + i) % len(songs)
		for _, artist := range songs[song].Artists {
			k := key(artist)
			if i := first[k]; artist.Name != "" && i != 0 {
				delete(first, k)
				artists = append(artists, credit{artist.Name, i - 1})
			}
		}
	}
	if len(artists) == 0 {
		if !a.homeSections.dailyLoading && a.homeSections.dailyErr != "" {
			ui.Text(c, a.homeSections.dailyErr).Absolute().Top(178 * u).Left(24 * u).FontSize(12 * u).TextColor(homeInk)
		}
		return
	}
	ui.Row(c).Absolute().Top(178 * u).Left(24 * u).Right(94 * u).Height(20 * u).Clip().AlignItems(ui.Center).Children(func() {
		for i, artist := range artists[:min(5, len(artists))] {
			b := ui.ButtonBase(c.Key(i)).Label("播放 " + artist.name + " 的推荐曲目").Center().Shrink(0)
			ink := white
			weight := 500
			if i == 0 {
				weight = 700
			} else {
				ink = white.Alpha(.9)
			}
			if b.Hovered() {
				ink = homeInk
			}
			if a.motion != motionOff && !c.Preferences().ReduceMotion {
				ink = b.AnimateColor("ink", ink, ui.Animation{Duration: 200 * time.Millisecond, Ease: ui.Linear})
			}
			b.Children(func() {
				if i > 0 {
					ui.Text(c, "·").Width(12 * u).Shrink(0).TextAlign(ui.Center).FontSize(12.5 * u).TextColor(white.Alpha(.45))
				}
				ui.Text(c, artist.name).FontWeight(weight).FontSize(12.5 * u).SingleLine().TextColor(ink)
			})
			if b.Clicked() {
				a.pl.PlayQueue(songs, artist.song)
			}
		}
		if len(artists) > 5 {
			ui.Textf(c, " · 等 %d 位歌手", len(artists)-5).Shrink(0).FontSize(12.5 * u).TextColor(homeInk.Alpha(.6)).SingleLine()
		}
	})
}

func (a *app) rhineFM(c *ui.Context, x, width, u float32) {
	active := strings.HasPrefix(a.pl.Radio(), "fm:")
	busy := strings.HasPrefix(a.radioStarting, "fm:")
	current := a.pl.Current()
	has := active && current != nil
	playing := has && a.pl.Playing()
	pos, duration := time.Duration(0), time.Duration(0)
	title, subtitle := "听点新鲜的", "从一首歌开始，一直放下去"
	if has {
		title, subtitle = current.Name, current.ArtistNames()
		pos, duration = a.pl.Position(), a.pl.Duration()
		if playing {
			c.After(time.Second - pos%time.Second + 10*time.Millisecond)
		}
	} else if busy {
		subtitle = "正在调入私人 FM…"
	}
	ui.Box(c).Absolute().Left(x).Top(0).Size(width, 240*u).Radius(20 * u).Background(homeInk).Children(func() {
		ui.Text(c, "私人 FM").Absolute().Top(20 * u).Left(22 * u).FontSize(12 * u).TextColor(white.Alpha(.6))
		reduced := a.motion == motionOff || c.Preferences().ReduceMotion
		indicator := ui.Row(c.Key("on-air")).Absolute().Top(23 * u).Right(22 * u).Gap(6 * u).AlignItems(ui.Center)
		strength := b2f(playing)
		if !reduced {
			strength = indicator.AnimateTo("color", strength, ui.Animation{Duration: 400 * time.Millisecond})
		}
		on := white.Alpha(.32).Mix(homeOrange, strength)
		dot := ui.Hex("#3a3b44").Mix(homeOrange, strength)
		indicator.Children(func() {
			ui.Box(c).Size(6*u, 6*u).Radius(3*u).Background(dot).Shadow(0, 0, 5*u, 0, homeOrange.Alpha(.75*strength))
			ui.Text(c, "ON AIR").Font("Consolas").FontSize(10 * u).LetterSpacing(1.2 * u).TextColor(on)
		})
		copy, opacity := a.homeSections.fmTitle.frame(c, homeCopy{key: fmt.Sprint(has, ":", a.pl.RadioGeneration(), ":", func() int64 {
			if has {
				return current.ID
			}
			return 0
		}()), title: title, subtitle: subtitle}, reduced, 40*time.Millisecond)
		showSpectrum := playing && !reduced
		switching := !a.homeSections.fmTitle.start.IsZero() && c.Now().Sub(a.homeSections.fmTitle.start) < 260*time.Millisecond
		var rises [30]float32
		for i := range rises {
			bar := ui.Box(c.Key(fmt.Sprint("rise:", i))).Size(0, 0).PassThrough()
			rises[i] = b2f(playing && !switching)
			if !reduced {
				delay, duration := time.Duration(i)*14*time.Millisecond, 550*time.Millisecond
				if switching {
					delay, duration = 0, 220*time.Millisecond
				}
				rises[i] = bar.AnimateTo("rise", rises[i], ui.Animation{Duration: duration, Delay: delay, Ease: fmRiseEase})
			}
		}
		ui.Box(c).Absolute().Top(54 * u).Left(22 * u).Right(22 * u).Height(64 * u).Draw(func(p *ui.Painter, r ui.Rect) {
			barWidth := (r.W - 87*u) / 30
			step := barWidth + 3*u
			progress := float64(0)
			if duration > 0 {
				progress = float64(a.pl.Position()) / float64(duration)
			}
			var levels [player.Bands]float32
			if showSpectrum {
				levels, _ = a.pl.Levels()
			}
			// Smooth decoded bands at presentation rate without rebuilding layout.
			dt := float32(p.Now().Sub(a.homeSections.fmPaintAt).Seconds())
			if a.homeSections.fmPaintAt.IsZero() {
				dt = 1.0 / 120
			}
			a.homeSections.fmPaintAt = p.Now()
			moving := false
			for i := range a.homeSections.fmLevels {
				target := levels[i*len(levels)/30]
				value := a.homeSections.fmLevels[i]
				seconds := float32(.12)
				if target > value {
					seconds = .045
				}
				value += (target - value) * (1 - float32(math.Exp(float64(-max(0, dt)/seconds))))
				if value < .0005 {
					value = 0
				}
				a.homeSections.fmLevels[i] = value
				moving = moving || value > 0
			}
			if showSpectrum || moving {
				p.AnimationFrame()
			}
			for i := range 30 {
				height := (1 + float32(i%4)*.28) * u
				height = max(2*u, height+64*u*a.homeSections.fmLevels[i]*rises[i])
				color := homeOrange.Alpha(.32)
				if i < int(math.Ceil(progress*30)) {
					color = homeOrange
				}
				p.Fill(ui.Rect{X: r.X + step*float32(i), Y: r.Y + (r.H-height)/2, W: max(1, barWidth), H: height}, color, u)
			}
		})

		ui.Box(c.Key("song-copy")).Absolute().Top(134*u).Left(22*u).Right(74*u).Height(48*u).
			Opacity(opacity).Translate(0, a.homeSections.fmTitle.offset(c.Now(), 40*time.Millisecond)*4*u).Children(func() {
			ui.Row(c).Absolute().Top(0).Left(0).Right(0).Height(26 * u).AlignItems(ui.Center).Children(func() {
				ui.Text(c, copy.title).FontSize(19 * u).FontWeight(700).TextColor(white).SingleLine().MinWidth(0)
			})
			ui.Row(c).Absolute().Top(27 * u).Left(0).Right(0).Height(18 * u).AlignItems(ui.Center).Children(func() {
				ui.Text(c, copy.subtitle).FontSize(12 * u).TextColor(white.Alpha(.55)).SingleLine().MinWidth(0)
			})
		})
		symbol, label := iconPlay, "播放私人 FM"
		if playing {
			symbol, label = iconPause, "暂停私人 FM"
		}
		play := homeRound(c.Key("play"), symbol, label, 40*u, 16*u, homeInk, homeOrange).Absolute().Top(136 * u).Right(22 * u).Disabled(busy)
		scale := 1 + .06*b2f(play.Hovered())
		if !reduced {
			scale = play.AnimateTo("scale", scale, ui.Animation{Duration: 300 * time.Millisecond})
		}
		play.Scale(scale, scale)
		if play.Clicked() {
			switch {
			case has:
				a.pl.TogglePlay()
			case a.profile == nil:
				a.openLogin()
			default:
				a.playFM()
			}
		}
		ui.Row(c).Absolute().Bottom(16 * u).Left(14 * u).Right(22 * u).Height(32 * u).Gap(2 * u).AlignItems(ui.Center).Children(func() {
			heart := iconHeart
			if has && a.liked[current.ID] {
				heart = iconHeartFill
			}
			for i, action := range []struct {
				icon  *ui.SVG
				label string
				run   func()
			}{
				{heart, "喜欢当前 FM 歌曲", func() { a.toggleLike(current) }},
				{iconTrash, "不喜欢并跳过当前 FM 歌曲", a.trashFM},
				{iconNext, "下一首 FM 歌曲", a.pl.Next},
			} {
				disabled := !has || busy
				if i == 0 && has {
					disabled = disabled || a.profile == nil || a.liked == nil || a.likePending[current.ID]
				}
				b := ui.ButtonBase(c.Key(i)).Size(30*u, 30*u).Radius(15 * u).Center().Label(action.label).Disabled(disabled)
				color := white.Alpha(.13)
				if has {
					color = white.Alpha(.55)
				}
				if i == 0 && heart == iconHeartFill {
					color = homeOrange
				}
				hovered := b.Hovered()
				if hovered {
					b.Background(white.Alpha(.1))
				}
				var offset float32
				if action.icon == iconNext {
					offset = a.homeSections.fmNext.frame(c, hovered && !disabled, reduced)
				}
				b.Children(func() { ui.Icon(c, action.icon).Size(15*u, 15*u).TextColor(color).Translate(offset*u, 0) })
				if b.Clicked() {
					action.run()
				}
			}
			ui.Text(c, clock(pos)+" / "+clock(duration)).Grow(1).MinWidth(0).SingleLine().TextAlign(ui.End).
				Font("Consolas").FontSize(10.5 * u).TextColor(white.Alpha(.4))
		})
	})
}

type homeRankState struct {
	id                            int64
	rows                          []netease.ChartTrack
	loading, catalogLoading, menu bool
	err                           string
	request, expanded             int
	pointerX, pointerY            float32
	pointerIn                     bool
}

func (a *app) homeChartOptions() []*netease.Playlist {
	var options []*netease.Playlist
	for _, name := range []string{"飙升榜", "新歌榜", "热歌榜", "原创榜"} {
		for i := range a.charts {
			if a.charts[i].Name == name {
				options = append(options, &a.charts[i])
				break
			}
		}
	}
	if len(options) == 0 && len(a.charts) > 0 {
		options = append(options, &a.charts[0])
	}
	return options
}

func (a *app) loadHomeRank(id int64, refresh bool) {
	s := &a.homeRank
	var chart *netease.Playlist
	for _, option := range a.homeChartOptions() {
		if chart == nil || option.ID == id {
			chart = option
		}
	}
	if chart == nil || !refresh && s.id == chart.ID && (s.loading || len(s.rows) > 0) {
		return
	}
	s.id, s.expanded, s.menu = chart.ID, 0, false
	s.rows, s.err, s.loading = nil, "", true
	s.request++
	request, gen := s.request, a.accountGen
	go func() {
		rows, err := netease.ChartPreview(chart.ID)
		a.post(func() {
			if gen != a.accountGen || request != s.request {
				return
			}
			s.loading = false
			s.rows = rows
			if err != nil {
				s.err = "榜单加载失败"
			}
		})
	}()
}

func (a *app) rhineRank(c *ui.Context, x, width, u float32) {
	s := &a.homeRank
	options := a.homeChartOptions()
	title, update := "飙升榜", ""
	for _, option := range options {
		if s.id == option.ID {
			title, update = option.Name, option.UpdateFreq
		}
	}
	card := a.homeFrost(ui.Box(c).Absolute().Left(x).Top(0).Size(width, (260+162*1.12)*u), 20*u)
	card.Children(func() {
		ui.Row(c).Absolute().Left(20 * u).Right(20 * u).Top(16 * u).Height(24 * u).Gap(8 * u).AlignItems(ui.Center).Children(func() {
			selector := ui.ButtonBase(c.Key("chooser")).Label("切换榜单：" + title).Height(24 * u).Center().Gap(8 * u).Disabled(len(options) == 0)
			selector.Children(func() {
				ui.Text(c, title).FontSize(12 * u).FontWeight(660).SingleLine()
				ui.Icon(c, iconDown).Size(10*u, 10*u).TextColor(a.pal.muted)
			})
			if selector.Clicked() {
				s.menu = !s.menu
			}
			ui.PopoverBase(c.Key("options"), selector, &s.menu, func(popup ui.Element) {
				a.pane(popup, 14, false).AttachTo(selector, ui.AnchorBottomStart, ui.AnchorTopStart).Width(118 * u).Padding(4 * u).FocusGroup(ui.Vertical)
				for _, option := range options {
					b := ui.ButtonBase(c.Key(option.ID)).Label(option.Name).Height(30 * u).PaddingX(9 * u).AlignItems(ui.Center).Justify(ui.Start).Radius(8)
					if b.Hovered() {
						b.Background(a.pal.hover)
					}
					b.Children(func() { ui.Text(c, option.Name).FontSize(12 * u) })
					if b.Clicked() {
						s.menu = false
						a.loadHomeRank(option.ID, false)
					}
				}
			})
			ui.Text(c, update).FontSize(11 * u).TextColor(a.pal.muted).SingleLine()
		})
		if len(s.rows) > 0 {
			a.rhineRankRows(c.Key("songs"), u)
		} else if s.loading || s.catalogLoading {
			ui.Column(c).Absolute().Top(48 * u).Left(20 * u).Right(20 * u).Gap(15 * u).Children(func() {
				ui.Box(c).Height(138 * u).Radius(14 * u).Background(a.pal.hover)
				for range 5 {
					ui.Box(c).Height(12 * u).Width(100 * u).Radius(4).Background(a.pal.hover)
				}
			})
		} else {
			status := s.err
			if status == "" {
				status = "榜单暂无歌曲"
			}
			ui.Column(c).Absolute().Top(66 * u).Left(20 * u).Right(20 * u).Gap(8 * u).Children(func() {
				ui.Text(c, status).FontSize(12 * u).TextColor(a.pal.muted)
				if ui.Button(c.Key("retry"), "重新读取").Clicked() {
					if len(options) == 0 {
						a.loadHomeChartCatalog()
					} else {
						a.loadHomeRank(s.id, true)
					}
				}
			})
		}
		all := ui.ButtonBase(c.Key("all")).Absolute().Bottom(10*u).Right(10*u).Size(92*u, 30*u).Center().Label("全部榜单")
		ink := a.pal.text
		if all.Hovered() {
			ink = homeOrange
		}
		all.Children(func() { ui.Text(c, "全部榜单 ›").FontSize(12 * u).TextColor(ink) })
		if all.Clicked() {
			a.open(route{page: pageCharts})
		}
	})
}

func (a *app) rhineRankRows(c *ui.Context, u float32) {
	s := &a.homeRank
	list := ui.Column(c).Absolute().Top(48 * u).Left(20 * u).Right(20 * u).AlignItems(ui.Stretch)
	px, py, over := list.PointerPosition()
	selectRow := over && (!s.pointerIn || px != s.pointerX || py != s.pointerY)
	s.pointerX, s.pointerY, s.pointerIn = px, py, over
	list.Children(func() {
		for i, row := range s.rows {
			expanded := i == s.expanded
			target := float32(36)
			if expanded {
				target = 138
			}
			b := ui.ButtonBase(c.Key(row.ID)).Column().Justify(ui.Start).AlignItems(ui.Stretch).FocusRing(false).
				Label(fmt.Sprintf("播放第 %d 名：%s", i+1, row.Name)).Clip().Radius(14 * u)
			height := target * u
			if a.motion != motionOff && !c.Preferences().ReduceMotion {
				height = b.Animate("height", height, 380*time.Millisecond)
			}
			b.Height(height).Shrink(0)
			movement := "—"
			delta := row.Previous - (i + 1)
			emphasis := row.Ranked && (row.Previous <= 0 || delta >= 5)
			if row.Ranked {
				switch {
				case row.Previous <= 0:
					movement = "新!"
				case delta > 0:
					movement = fmt.Sprintf("↑%d", delta)
				case delta < 0:
					movement = fmt.Sprintf("↓%d", -delta)
				}
			}
			if selectRow && b.Hovered() || b.FocusVisible() {
				if s.expanded != i {
					s.expanded = i
					c.AnimationFrame()
				}
			}
			b.Children(func() {
				reveal := max(0, min(1, (height/u-36)/102))
				if reveal > .02 {
					ui.Box(c).Absolute().Top(0).Left(0).Right(0).Bottom(0).Opacity(reveal).PassThrough().
						Background(ui.Hex("#3e404a")).Radius(14 * u).Children(func() {
						a.coverFillOn(c, row.Album.PicURL, 640, 14*u, ui.Hex("#3E404A"))
						ui.Box(c).Absolute().Top(0).Left(0).Right(0).Bottom(0).Radius(14 * u).
							LinearGradient(ui.LinearGradient{Angle: 180, Stops: []ui.GradientStop{
								{At: .25, Color: ui.Transparent}, {At: 1, Color: ui.RGBA(10, 10, 14, .8)},
							}})
						ui.Textf(c, "%d", i+1).Absolute().Top(10 * u).Left(14 * u).FontSize(30 * u).FontWeight(900).TextColor(white)
						badge := white.Alpha(.22)
						if emphasis {
							badge = homeOrange
						}
						ui.Text(c, movement).Absolute().Top(12*u).Right(12*u).Padding(2*u, 8*u).
							Radius(10 * u).Background(badge).FontSize(11 * u).FontWeight(700).TextColor(white)
						ui.Column(c).Absolute().Bottom(14 * u).Left(14 * u).Right(53 * u).Gap(3 * u).Children(func() {
							ui.Text(c, row.Name).FontSize(18 * u).FontWeight(700).TextColor(white).SingleLine()
							ui.Text(c, row.ArtistNames()).FontSize(12 * u).TextColor(white.Alpha(.75)).SingleLine()
						})
						ui.Box(c).Absolute().Right(12*u).Bottom(12*u).Size(34*u, 34*u).Center().Radius(17 * u).Background(white).Children(func() {
							ui.Icon(c, iconPlay).Size(14*u, 14*u).TextColor(homeInk)
						})
					})
				}
				if reveal < .98 {
					ui.Row(c).Height(36 * u).PaddingX(4 * u).Gap(6 * u).AlignItems(ui.Center).Justify(ui.Start).Opacity(1 - reveal).Children(func() {
						ui.Textf(c, "%d", i+1).Width(28 * u).TextAlign(ui.Center).Font("Caveat, KaiTi").FontSize(24 * u)
						ui.Text(c, row.Name).FontSize(13 * u).SingleLine().MaxWidth(100 * u).MinWidth(0).Shrink(1)
						ui.Text(c, row.ArtistNames()).FontSize(11 * u).SingleLine().Grow(1).MinWidth(0).TextColor(a.pal.muted)
						color := a.pal.muted
						if emphasis {
							color = homeOrange
						}
						ui.Text(c, movement).Font("Caveat, KaiTi").FontSize(19 * u).TextColor(color).Shrink(0)
					})
				}
			})
			if b.Clicked() {
				tracks := make([]netease.Track, len(s.rows))
				for j := range tracks {
					tracks[j] = s.rows[j].Track
				}
				a.pl.PlayQueue(tracks, i)
			}
		}
	})
}

func (a *app) rhineRail(c *ui.Context, width, u float32) {
	state := &a.homeSections
	items := state.modes.items
	railUnit := 1.12 * u
	card := a.homeFrost(ui.Box(c).Absolute().Top(260*u).Left(0).Size(width, 162*railUnit).Clip(), 20*railUnit)
	x, y, inside := card.PointerPosition()
	bounds := card.Bounds()
	x, y = x+bounds.X, y+bounds.Y
	state.modeActivated = false
	if !inside && state.modeKeyboard == "" {
		state.modeHover = ""
		state.modeRevealed = ""
		if state.modeShifted {
			state.modeScroll.ScrollTo(state.modeRestX, 0, ui.Animation{Duration: 420 * time.Millisecond, Ease: ui.EaseInOut})
			state.modeShifted = false
		}
	} else {
		contains := func(r ui.Rect) bool { return r.W > 0 && x >= r.X && x < r.X+r.W && y >= r.Y && y < r.Y+r.H }
		candidate := ""
		// The expanded sleeve owns its complete information area, including
		// while neighbouring covers animate through their former positions.
		if contains(state.modeBounds[state.modeRevealed]) {
			candidate = state.modeRevealed
		} else {
			for _, item := range items {
				if contains(state.modeBounds[item.Key]) {
					candidate = item.Key
					break
				}
			}
		}
		if candidate != state.modeHover {
			state.modeHover, state.modeHoverAt = candidate, c.Now()
		}
		if candidate != "" && candidate != state.modeRevealed {
			remaining := state.modeHoverAt.Add(160 * time.Millisecond).Sub(c.Now())
			if remaining > 0 {
				c.After(remaining)
			} else {
				state.modeRevealed = candidate
				state.modeRevealAt = c.Now().Add(190 * time.Millisecond)
				state.modeActivated = true
				c.Invalidate()
			}
		}
	}
	if state.modeBounds == nil {
		state.modeBounds = make(map[string]ui.Rect)
	}
	state.modeKeyboard = ""
	card.Children(func() {
		capacity := max(2, int((width/railUnit-26)/132))
		cell := 112 * railUnit
		step := (width - 48*u - cell) / float32(capacity-1)
		ui.ScrollHorizontal(c.Key("rail")).ScrollbarInsets(0, 0, -30*railUnit, 0).TrackScroll(&state.modeScroll).Absolute().Top(14 * railUnit).Left(24 * u).Right(24 * u).Height(140 * railUnit).Children(func() {
			if len(items) == 0 && !state.modes.loading {
				message := state.modes.err
				if message == "" {
					message = "暂无个性推荐"
				}
				if a.profile == nil {
					message = "登录后查看个性推荐"
				}
				ui.Column(c).Size(width-48*u, 140*railUnit).Center().Gap(8 * u).Children(func() {
					ui.Text(c, message).FontSize(12 * u).TextColor(a.pal.muted)
					if ui.Button(c.Key("retry"), "重新读取").Clicked() {
						if a.profile == nil {
							a.openLogin()
						} else {
							a.loadHomeModes()
						}
					}
				})
				return
			}
			active, extra := -1, float32(0)
			for i, item := range items {
				if item.Key == state.modeRevealed {
					active = i
					extra = homeModeSpan(c, item, railUnit, step) - step
				}
			}
			contentWidth := max(width-48*u, float32(max(0, len(items)-1))*step+cell+extra)
			ui.Box(c).Size(contentWidth, 140*railUnit).Children(func() {
				if len(items) == 0 {
					for range capacity {
						ui.Box(c).Size(cell, cell).Radius(12 * railUnit).Background(a.homeCoverPlaceholder())
					}
				}
				for i, item := range items {
					x := float32(i) * step
					if active >= 0 && i > active {
						x += extra
					}
					a.rhineModeCard(c.Key(item.Key), item, cell, railUnit, step, width-48*u, x)
				}
			})
		})
		a.rhineRailArrows(c.Key("paging"), &state.modeScroll, step, u, "推荐", func() { state.modeHover, state.modeRevealed = "", ""; state.modeShifted = false })
	})
}

func homeModeSpan(c *ui.Context, item netease.HomeRecommendation, u, step float32) float32 {
	title := homeTextWidth(c, ui.Span{Text: item.Title, Size: 13 * u, Weight: 700})
	description := homeTextWidth(c, ui.Span{Text: item.Description, Size: 11 * u})
	info := max(136*u, min(242*u, max(title*.65, description*.45)))
	return float32(math.Ceil(float64((160*u+info)/step*2))) / 2 * step
}

func (a *app) rhineModeCard(c *ui.Context, item netease.HomeRecommendation, cell, u, step, viewport, x float32) {
	state := &a.homeSections
	button := ui.ButtonBase(c).Absolute().Top(0).Column().Height(136 * u).Shrink(0).Justify(ui.Start).Label(item.Title)
	if a.motion != motionOff && !c.Preferences().ReduceMotion {
		x = button.AnimateTo("cover-x", x, ui.Animation{Duration: 420 * time.Millisecond, Ease: ui.EaseInOut})
	}
	button.Left(x)
	state.modeBounds[item.Key] = button.Bounds()
	// Keep the active sleeve until another hover delay completes or the rail
	// is left. Moving covers must not collapse it under a stationary pointer.
	if button.FocusVisible() && state.modeRevealed != item.Key {
		state.modeRevealed = item.Key
		state.modeRevealAt = c.Now().Add(190 * time.Millisecond)
		state.modeActivated = true
		c.Invalidate()
	}
	if button.FocusVisible() {
		state.modeKeyboard = item.Key
	}
	expanded := state.modeRevealed == item.Key
	expandedSpan := homeModeSpan(c, item, u, step)
	span := cell
	if expanded {
		span = expandedSpan
	}
	if expanded && state.modeActivated {
		if !state.modeShifted {
			state.modeRestX = state.modeScroll.X
			state.modeShifted = true
		}
		index := 0
		for i, entry := range state.modes.items {
			if entry.Key == item.Key {
				index = i
				break
			}
		}
		target := max(state.modeRestX, float32(index)*step+expandedSpan+10*u-viewport)
		if target != state.modeScroll.X {
			state.modeScroll.ScrollTo(target, 0, ui.Animation{Duration: 420 * time.Millisecond, Ease: ui.EaseInOut})
		}
	}

	button.Width(span).Clip().AlignItems(ui.Start)
	reveal := b2f(expanded)
	if a.motion != motionOff && !c.Preferences().ReduceMotion {
		if expanded && c.Now().Before(state.modeRevealAt) {
			reveal = 0
			c.After(state.modeRevealAt.Sub(c.Now()))
		}
		if expanded {
			reveal = button.AnimateTo("info-reveal", reveal, ui.Animation{Duration: 180 * time.Millisecond})
		} else {
			reveal = button.Jump("info-reveal", 0)
		}
	}
	button.Children(func() {
		if span-cell > u {
			disc := ui.Box(c.Key("disc")).Absolute().Top(4*u).Size(104*u, 104*u).Radius(52 * u).Background(homeInk).PassThrough()
			disc.Left(24 * u)
			disc.Draw(func(p *ui.Painter, r ui.Rect) {
				for i := range 5 {
					m := float32(4+6*i) * u
					d := r.W - 2*m
					p.Stroke(ui.Rect{X: r.X + m, Y: r.Y + m, W: d, H: d}, white.Alpha(.15), d/2, u)
				}
				p.Fill(ui.Rect{X: r.X + .35*r.W, Y: r.Y + .35*r.W, W: .3 * r.W, H: .3 * r.W}, homeOrange, r.W*.15)
			})
			ui.Column(c.Key("info")).Absolute().Top(2 * u).Left(140 * u).Width(max(72*u, expandedSpan-160*u)).Gap(9 * u).Opacity(reveal).PassThrough().Children(func() {
				ui.Text(c, item.Title).Width(max(72*u, expandedSpan-160*u)).FontSize(13 * u).FontWeight(700).MaxLines(2)
				ui.Text(c, item.Description).Width(max(72*u, expandedSpan-160*u)).FontSize(11 * u).TextColor(a.pal.muted).MaxLines(2)
				ui.Text(c, item.Category).FontSize(10 * u).TextColor(homeOrange).SingleLine()
			})
		}
		cover := ui.Box(c.Key("cover")).Absolute().Top(0).Left(0).Size(cell, cell).Radius(12 * u)
		a.homeCoverShadow(c, cover, button.Hovered() || button.FocusVisible(), u)
		cover.Children(func() {
			a.coverFillOn(c, item.Cover, 256, 12*u, a.homeCoverPlaceholder())
			play := homeRound(c.Key("play"), iconPlay, "播放 "+item.Title, 30*u, 13*u, white, homeOrange).Absolute().Right(7 * u).Bottom(7 * u)
			if play.FocusVisible() {
				state.modeKeyboard = item.Key
				if state.modeRevealed != item.Key {
					state.modeRevealed = item.Key
					state.modeRevealAt = c.Now().Add(190 * time.Millisecond)
					state.modeActivated = true
					c.Invalidate()
				}
			}
			if !expanded && !play.FocusVisible() {
				play.Opacity(0)
			}
			if play.Clicked() {
				a.openHomeRecommendation(item, true)
			}
		})
		ui.Text(c.Key("caption"), item.Title).Absolute().Top(cell + 8*u).Left(0).Width(cell).FontSize(12 * u).FontWeight(600).SingleLine().TextAlign(ui.Center).Opacity(1 - reveal).PassThrough()
	})
	if button.Clicked() {
		a.openHomeRecommendation(item, false)
	}
}

func (a *app) rhineRailArrows(c *ui.Context, state *ui.ScrollState, step, u float32, label string, changed func()) {
	if state.MaxX <= 1 {
		return
	}
	for i := range 2 {
		previous := i == 0
		if previous && state.X <= 1 || !previous && state.X >= state.MaxX-1 {
			continue
		}
		glyph, direction, name := "›", float32(1), "下一页"
		b := ui.ButtonBase(c.Key(i)).Absolute().Top(0).Bottom(0).Width(26 * u).Center().Radius(12 * u)
		if previous {
			glyph, direction, name = "‹", -1, "上一页"
			b.Left(0)
		} else {
			b.Right(0)
		}
		b.Label(name + label)
		if b.Hovered() || b.FocusVisible() {
			b.Background(a.pal.bg.Alpha(.88))
		} else {
			b.Opacity(0)
		}
		b.Children(func() { ui.Text(c, glyph).FontSize(26 * u).TextColor(a.pal.text) })
		if b.Clicked() {
			if changed != nil {
				changed()
			}
			to := min(state.MaxX, max(0, state.X+step*direction))
			state.ScrollTo(to, 0, ui.Animation{Duration: 300 * time.Millisecond})
		}
	}
}

func (a *app) rhineHomeHeading(c *ui.Context, title, subtitle string, u float32) ui.Element {
	const fontSize, weight = 19, 700
	width, _ := c.MeasureText(0, ui.Span{Text: title, Size: fontSize * u, Weight: weight})
	node := ui.Text(c, title).FontSize(fontSize * u).FontWeight(weight)
	// Painter.Line only supports axis-aligned lines; preserve the QML path.
	ornament := homeCrescendo(width / u)
	node.Draw(func(p *ui.Painter, r ui.Rect) {
		p.Icon(ornament, iconRect(p, ui.Rect{X: r.X + u, Y: r.Y + r.H + 2*u, W: width + u, H: 7 * u}), homeOrange)
	})
	if subtitle != "" {
		ui.Text(c, subtitle).FontSize(11 * u).TextColor(a.pal.muted)
	}
	return node
}

type rhineRecentEntry struct {
	key, title, cover string
	at                time.Time
	bookmark          *memoBookmark
	open, play        func()
}

func (a *app) rhineHomeRecent(c *ui.Context, cols int, u float32) {
	memo := a.homeMemoAccount()
	state := &a.homeSections
	entries := make([]rhineRecentEntry, 0, len(state.recent.items)+len(memo.Recent))
	seen := make(map[int64]bool)
	for _, item := range state.recent.items {
		list := item.Playlist
		if seen[list.ID] {
			continue
		}
		seen[list.ID] = true
		entries = append(entries, rhineRecentEntry{
			key: fmt.Sprint("playlist:", list.ID), title: list.Name, cover: list.Cover(), at: item.At,
			open: func() { a.open(route{page: pagePlaylist, id: list.ID}) },
			play: func() { a.loadPlaylist(list.ID, true) },
		})
	}
	for i := range memo.Recent {
		b := &memo.Recent[i]
		song := b.Track
		play := func() { a.resumeMemo(*b) }
		open := play
		if song.Album.ID > 0 && song.LocalPath == "" {
			open = func() { a.open(route{page: pageAlbum, id: song.Album.ID}) }
		}
		entries = append(entries, rhineRecentEntry{historyKey(&song), song.Name, song.Album.PicURL, time.UnixMilli(b.At), b, open, play})
	}
	width, _ := c.Size()
	width -= 80 * u
	cell := (width - float32(cols-1)*20*u) / float32(cols)
	ui.Column(c.Key("recent")).Margin(20*u, 0, 34*u, 0).Gap(18 * u).Children(func() {
		ui.Row(c).Gap(24 * u).AlignItems(ui.Center).Children(func() {
			a.rhineHomeHeading(c, "最近播放", "接着上次听过的", u)
			ui.Box(c).Grow(1)
			if len(entries) > 0 {
				page := min((len(entries)-1)/cols, max(0, int(math.Round(float64(state.recentScroll.X/(width+20*u))))))
				ui.Row(c).Children(func() {
					ui.Textf(c, "%02d", page*cols+1).Font("Consolas").FontSize(10 * u).FontWeight(700)
					ui.Textf(c, "—%02d / ", min((page+1)*cols, len(entries))).Font("Consolas").FontSize(10 * u).TextColor(a.pal.muted)
					ui.Textf(c, "%02d", len(entries)).Font("Consolas").FontSize(10 * u).TextColor(homeOrange)
				})
			}
		})
		if len(entries) == 0 && !state.recent.loading {
			m := state.recent.err
			if m == "" {
				m = "还没有最近播放记录"
			}
			if a.profile == nil {
				m = "登录后查看最近播放"
			}
			ui.Column(c).Height(80 * u).AlignItems(ui.Start).Gap(6 * u).Children(func() {
				ui.Text(c, m).FontSize(12 * u).TextColor(a.pal.muted)
				if ui.Button(c.Key("retry"), "重新读取").Clicked() {
					if a.profile == nil {
						a.openLogin()
					} else {
						a.loadHomeRecent()
					}
				}
			})
			return
		}
		ui.Box(c.Key("timeline")).Height(cell + 67*u).Clip().Children(func() {
			ui.ScrollHorizontal(c.Key("history")).Fill().ScrollbarInsets(0, 0, -30*u, 0).TrackScroll(&state.recentScroll).Children(func() {
				ui.Row(c).Gap(20 * u).Children(func() {
					if len(entries) == 0 {
						for range cols {
							ui.Box(c).Size(cell, cell).Radius(12 * u).Background(a.homeCoverPlaceholder())
						}
					}
					for i, item := range entries {
						a.rhineRecentCover(c.Key(item.key), item, cell, u, i == 0)
					}
					// A short last page starts at the same horizontal boundary as the others.
					if remainder := len(entries) % cols; remainder > 0 && len(entries) > cols {
						ui.Box(c).Width(float32(cols-remainder)*(cell+20*u) - 20*u).Shrink(0)
					}
				})
			})
			if len(entries) > 0 {
				a.rhineRailArrows(c.Key("paging"), &state.recentScroll, width+20*u, u, "最近播放", nil)
			}
		})
	})
}

func (a *app) rhineRecentCover(c *ui.Context, item rhineRecentEntry, cell, u float32, first bool) {
	card := ui.ButtonBase(c).Column().Width(cell).Height(cell + 65*u).Shrink(0).Justify(ui.Start).AlignItems(ui.Start).Label(item.title)
	hot := card.Hovered() || card.FocusVisible()
	card.Children(func() {
		art := ui.Box(c).Size(cell, cell).Shrink(0).Radius(12 * u)
		a.homeCoverShadow(c, art, hot, u)
		if a.motion != motionOff && !c.Preferences().ReduceMotion {
			art.AnimatePose(ui.Pose{Y: -3 * u * b2f(hot)}, ui.Animation{Duration: 300 * time.Millisecond})
		}
		art.Children(func() {
			a.coverFillOn(c, item.cover, 512, 12*u, a.homeCoverPlaceholder())
			resume := first && item.bookmark != nil && item.bookmark.Position > 0 && item.bookmark.Track.Duration > 0
			if resume {
				fraction := min(1, float32(item.bookmark.Position)/float32(item.bookmark.Track.Duration))
				ui.Box(c).Absolute().Bottom(0).Left(4 * u).Right(4 * u).Height(3 * u).Background(white.Alpha(.3)).Children(func() {
					ui.Box(c).Height(3 * u).Width((cell - 8*u) * fraction).Background(homeOrange)
				})
				if !hot {
					ui.Text(c, "▸ 第 1 首 · "+clock(time.Duration(item.bookmark.Position)*time.Millisecond)).
						Absolute().Bottom(10*u).Left(9*u).Radius(6*u).Padding(4*u, 7*u).Background(homeInk.Alpha(.8)).
						Font("Consolas").FontSize(9 * u).TextColor(white)
				}
			}
			label := "播放 " + item.title
			if resume {
				label = "继续播放 " + item.title
			}
			play := homeRound(c.Key("play"), iconPlay, label, 34*u, 13*u, homeOrange, homeInk).Absolute().Right(9 * u).Bottom(9 * u)
			if !hot && !play.FocusVisible() {
				play.Opacity(0)
			}
			if play.Clicked() {
				item.play()
			}
		})
		staff := ui.Box(c).Width(cell).Height(17*u).Shrink(0).Margin(12*u, 0, 10*u, 0)
		staff.Draw(func(p *ui.Painter, r ui.Rect) {
			for i := range 5 {
				y := r.Y + float32(i)*4*u
				p.Line(r.X, y, r.X+r.W+20*u, y, u, a.pal.text.Alpha(.16))
			}
			if !item.at.IsZero() && item.at.UnixMilli() > 0 {
				when := item.at.In(time.Local)
				hour := float32((when.Hour()+18)%24) + float32(when.Minute())/60
				y := r.Y + (15-hour*14/24)*u
				ink := a.pal.muted
				if first {
					ink = homeOrange
				} else if hot {
					ink = a.pal.text
				}
				p.Fill(ui.Rect{X: r.X + 3*u, Y: y, W: 7 * u, H: 5 * u}, ink, 3*u)
				p.Line(r.X+9*u, y+2*u, r.X+9*u, y-8*u, u, ink)
			}
		})
		if stamp := recentStamp(item.at, c.Now()); stamp != "" {
			staff.Children(func() {
				ui.Text(c, stamp).Absolute().Top(2 * u).Left(15 * u).Font("Consolas").
					FontSize(9.5 * u).SingleLine().Height(11 * u).PaddingX(4 * u).Background(ui.Hex("#ECEDF3")).TextColor(a.pal.muted)
			})
		}
		ui.Text(c, item.title).FontSize(15 * u).FontWeight(650).SingleLine()
	})
	if card.Clicked() {
		item.open()
	}
}

func recentStamp(at, now time.Time) string {
	if at.UnixMilli() <= 0 || at.After(now.Add(5*time.Minute)) {
		return ""
	}
	minutes := max(0, int(now.Sub(at)/time.Minute))
	switch {
	case minutes < 10:
		return "JUST NOW"
	case minutes < 60:
		return fmt.Sprintf("%dM AGO", minutes)
	case minutes < 360:
		return fmt.Sprintf("%dH AGO", minutes/60)
	}
	at = at.In(now.Location())
	a := time.Date(at.Year(), at.Month(), at.Day(), 0, 0, 0, 0, time.UTC)
	b := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	days := int(b.Sub(a) / (24 * time.Hour))
	switch {
	case days <= 0:
		return at.Format("15:04")
	case days == 1:
		return "YESTERDAY"
	case days < 7:
		return fmt.Sprintf("%dD AGO", days)
	default:
		return fmt.Sprintf("%dW AGO", days/7)
	}
}

func (a *app) rhineHomePlaylists(c *ui.Context, width float32, cols int, u float32) {
	ui.Column(c.Key("curated")).Margin(34*u, 0, 0, 0).Gap(20 * u).Children(func() {
		a.rhineHomeHeading(c, "今日为你推荐", "", u)
		tabs := ui.Box(c).Height(36 * u)
		selectedX, selectedW := float32(0), float32(0)
		for i, filter := range playlistFilters {
			w, _ := c.MeasureText(0, ui.Span{Text: filter.label, Size: 13 * u})
			w += 28 * u
			if i == a.playlistFilter {
				selectedW = w
				break
			}
			selectedX += w + 12*u
		}
		if a.motion != motionOff && !c.Preferences().ReduceMotion {
			selectedX = tabs.AnimateTo("pill-x", selectedX, ui.Animation{Duration: 280 * time.Millisecond, Ease: homeCopyEase})
			selectedW = tabs.AnimateTo("pill-width", selectedW, ui.Animation{Duration: 280 * time.Millisecond, Ease: homeCopyEase})
		}
		// Absolute children paint above normal children in MyGo. Paint the
		// selection on the container itself so it cannot cover the captions.
		tabs.Draw(func(p *ui.Painter, r ui.Rect) {
			p.Fill(ui.Rect{X: r.X + selectedX, Y: r.Y, W: selectedW, H: 36 * u}, homeInk, 18*u)
		})
		tabs.Children(func() {
			ui.Row(c.Key("category-buttons")).Height(36 * u).Gap(12 * u).Children(func() {
				for i, filter := range playlistFilters {
					b := ui.ButtonBase(c.Key(i)).Label("歌单分类：" + filter.label).Height(36 * u).
						PaddingX(14 * u).Radius(18 * u).Center().Selected(a.playlistFilter == i)
					ink, background := a.pal.text, ui.Transparent
					if a.playlistFilter == i {
						background = ui.Transparent
						ink = homeOrange
					} else if b.Hovered() {
						background = a.pal.hover
					}
					if a.motion != motionOff && !c.Preferences().ReduceMotion {
						ink = b.AnimateColor("category-ink", ink, ui.Animation{Duration: 200 * time.Millisecond})
						background = b.AnimateColor("category-bg", background, ui.Animation{Duration: 240 * time.Millisecond})
					}
					b.Background(background)
					b.Children(func() { ui.Text(c, filter.label).FontSize(13 * u).TextColor(ink) })
					if b.Clicked() {
						a.choosePlaylistFilter(i)
					}
				}
			})
		})
		lists, loading, status := a.featured, a.homeLoading, a.homeErr
		filter := a.playlistFilter
		if filter != 0 {
			a.loadPlaylistFilter(filter)
			data := a.filteredPlaylists[filter]
			lists, loading, status = data.lists, data.loading, data.err
		}
		if len(lists) == 0 {
			if loading {
				a.playlistCardsSkeleton(c.Key("category-loading"), a.pageShimmer(c), cols, 168, false)
			} else {
				if status == "" {
					status = "暂无内容"
				}
				ui.Text(c, status).FontSize(12 * u).TextColor(a.pal.muted)
				if ui.Button(c.Key("retry"), "重新读取").Label("重新加载").Clicked() {
					if filter == 0 {
						a.loadHomeFeatured()
					} else {
						a.filteredPlaylists[filter] = nil
						a.loadPlaylistFilter(filter)
					}
				}
			}
		}
		if filter == 0 && a.style.err != "" {
			ui.Row(c).Gap(8 * u).AlignItems(ui.Center).Children(func() {
				ui.Text(c, a.style.err).FontSize(12 * u).TextColor(a.pal.muted)
				if ui.Button(c.Key("retry-style"), "重新读取风格推荐").Clicked() {
					a.loadStyle()
				}
			})
		}
		cell := (width - float32(cols-1)*20*u) / float32(cols)
		if len(lists) > 0 || filter == 0 && a.styleCardShown() {
			ui.Grid(c.Key("grid")).Columns(cols).GapX(20 * u).GapY(28 * u).Children(func() {
				if filter == 0 && a.styleCardShown() {
					a.styleCard(c.Key("style-songs"), cell)
				}
				for i := range lists {
					a.playlistCard(c.Key(lists[i].ID), &lists[i])
				}
			})
		}
	})
}

// homeWidthKey is what a single-line width measured by homeTextWidth depends on.
type homeWidthKey struct {
	text, font    string
	size, spacing float32
	weight        int
}

var homeWidths = map[homeWidthKey]float32{}

// homeTextWidth is c.MeasureText's width of span on one line, remembered:
// the recommendation rail measures every card's copy each frame it is
// built, which on scrolling and hovering is every frame, and measuring
// lays the text out again.
func homeTextWidth(c *ui.Context, span ui.Span) float32 {
	k := homeWidthKey{span.Text, span.Font, span.Size, span.LetterSpacing, int(span.Weight)}
	if w, ok := homeWidths[k]; ok {
		return w
	}
	if len(homeWidths) >= 256 {
		clear(homeWidths)
	}
	w, _ := c.MeasureText(0, span)
	homeWidths[k] = w
	return w
}

// fmRiseEase is the FM bars' rise, made once: an easing is a closure.
var fmRiseEase = ui.CubicBezier(.3, .7, .2, 1)

var homeCrescendos = map[float32]*ui.SVG{}

func homeCrescendo(width float32) *ui.SVG {
	if icon := homeCrescendos[width]; icon != nil {
		return icon
	}
	// Resizing can visit many fractional text widths; bound the tiny SVG cache.
	if len(homeCrescendos) >= 64 {
		clear(homeCrescendos)
	}
	icon := ui.MustParseSVG([]byte(fmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="7" viewBox="0 0 %g 7"><path d="M0 3.5 L%g .42 M0 3.5 L%g 6.58" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>`, width+1, width+1, width+1, width+1)))
	homeCrescendos[width] = icon
	return icon
}

// HomeRecentTimeline.qml: 90% caster, 12u drop, #141628 at .45, 300ms fade.
func (a *app) homeCoverShadow(c *ui.Context, art ui.Element, hot bool, u float32) {
	amount := b2f(hot)
	if a.motion != motionOff && !c.Preferences().ReduceMotion {
		amount = art.AnimateTo("home-shadow", amount, ui.Animation{Duration: 300 * time.Millisecond, Ease: ui.Linear})
	}
	art.Shadow(0, 0, 0, 0, ui.Transparent)
	art.Draw(func(p *ui.Painter, r ui.Rect) {
		if amount <= 0 {
			return
		}
		caster := ui.Rect{X: r.X + r.W*.05, Y: r.Y + r.H*.05, W: r.W * .9, H: r.H * .9}
		p.Shadow(caster, 12*u, 0, 12*u, 20*u, 0, ui.Hex("#141628").Alpha(.45*amount))
	})
}
