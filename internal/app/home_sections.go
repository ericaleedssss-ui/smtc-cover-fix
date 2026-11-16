package app

import (
	"github.com/egoist/mygo/ui"
	"netease-music-mygo/internal/netease"
	"time"
)

type homeSection[T any] struct {
	items   []T
	loading bool
	err     string
}

type homeSectionState struct {
	dailyLoading                      bool
	dailyErr                          string
	modes                             homeSection[netease.HomeRecommendation]
	recent                            homeSection[netease.RecentlyPlayedPlaylist]
	modeScroll, recentScroll          ui.ScrollState
	modeHover                         string
	modeRevealed                      string
	modeKeyboard                      string
	modeHoverAt                       time.Time
	modeRevealAt                      time.Time
	modeBounds                        map[string]ui.Rect
	modeActivated                     bool
	modeRestX                         float32
	modeShifted                       bool
	backdropCurrent, backdropPrevious *artwork
	backdropChanged                   time.Time
	dailyTitle, fmTitle               homeCopyTransition
	weekly                            homeWeeklyState
	fmLevels                          [30]float32
	fmPaintAt                         time.Time
	fmNext                            homeFMNextNudge
}

const (
	fmNextPush   = 200 * time.Millisecond
	fmNextReturn = 250 * time.Millisecond
)

type homeFMNextNudge struct {
	hovered bool
	start   time.Time
	from    float32
}

func (n *homeFMNextNudge) offset(now time.Time) float32 {
	if n.start.IsZero() {
		return 0
	}
	elapsed := now.Sub(n.start)
	if elapsed < fmNextPush {
		return n.from + (3-n.from)*ui.EaseOut(float32(elapsed)/float32(fmNextPush))
	}
	return 3 * (1 - ui.EaseOut(min(1, float32(elapsed-fmNextPush)/float32(fmNextReturn))))
}

func (n *homeFMNextNudge) frame(c *ui.Context, hovered, reduced bool) float32 {
	if reduced {
		*n = homeFMNextNudge{hovered: hovered}
		return 0
	}
	now := c.Now()
	if hovered && !n.hovered {
		n.from, n.start = n.offset(now), now
	}
	n.hovered = hovered
	if n.start.IsZero() || now.Sub(n.start) >= fmNextPush+fmNextReturn {
		n.start = time.Time{}
		return 0
	}
	c.AnimationFrame()
	return n.offset(now)
}

type homeCopy struct {
	key             string
	title, subtitle string
	index           int
	duration        time.Duration
}

type homeCopyTransition struct {
	current, target homeCopy
	start           time.Time
	fromOpacity     float32
	fromOffset      float32
}

var homeCopyEase = ui.CubicBezier(.22, .8, .24, 1)

func (s *homeCopyTransition) offset(now time.Time, hold time.Duration) float32 {
	if s.start.IsZero() {
		return 0
	}
	at := now.Sub(s.start)
	if at < 220*time.Millisecond {
		return s.fromOffset + (1-s.fromOffset)*homeCopyEase(float32(at)/float32(220*time.Millisecond))
	}
	if at < 220*time.Millisecond+hold {
		return 1
	}
	return 1 - homeCopyEase(min(1, float32(at-220*time.Millisecond-hold)/float32(220*time.Millisecond)))
}

// Rhine: swap the copy while it is invisible. FM holds for another 40 ms.
func (s *homeCopyTransition) frame(c *ui.Context, next homeCopy, reduced bool, hold time.Duration) (homeCopy, float32) {
	const fade = 220 * time.Millisecond
	now := c.Now()
	if reduced || s.current.title == "" {
		*s = homeCopyTransition{current: next, target: next}
		return next, 1
	}
	if next.key != s.target.key {
		previousOpacity := s.fromOpacity
		s.fromOpacity = 1
		s.fromOffset = s.offset(now, hold)
		if !s.start.IsZero() {
			at := now.Sub(s.start)
			switch {
			case at < fade:
				s.fromOpacity = previousOpacity * (1 - float32(at)/float32(fade))
			case at < fade+hold:
				s.fromOpacity = 0
			default:
				s.fromOpacity = min(1, float32(at-fade-hold)/float32(fade))
			}
		}
		s.target = next
		s.start = now
	} else {
		s.target = next
		if s.start.IsZero() {
			s.current = next
		}
	}
	if s.start.IsZero() {
		return s.current, 1
	}
	at := now.Sub(s.start)
	if at >= 2*fade+hold {
		s.current, s.start = s.target, time.Time{}
		return s.current, 1
	}
	// Follow the display's refresh cycle during the transition. A fixed 120 Hz
	// timer can miss a 120 Hz presentation deadline and stutter at half rate.
	c.Invalidate()
	if at < fade {
		return s.current, s.fromOpacity * (1 - float32(at)/float32(fade))
	}
	if at < fade+hold {
		return s.current, 0
	}
	s.current = s.target
	return s.current, float32(at-fade-hold) / float32(fade)
}

func (a *app) loadHomeDaily() {
	s := &a.homeSections
	if a.profile == nil || s.dailyLoading {
		return
	}
	s.dailyLoading, s.dailyErr = true, ""
	gen := a.accountGen
	go func() {
		songs, err := netease.DailySongs()
		a.post(func() {
			if gen != a.accountGen {
				return
			}
			s.dailyLoading = false
			if err != nil {
				s.dailyErr = "每日推荐加载失败"
				return
			}
			a.daily = songs
		})
	}()
}

func readHomeSection[T any](a *app, section *homeSection[T], fetch func() ([]T, error), failure string) {
	if a.profile == nil || section.loading {
		return
	}
	section.loading, section.err = true, ""
	gen := a.accountGen
	go func() {
		items, err := fetch()
		a.post(func() {
			if gen != a.accountGen {
				return
			}
			section.loading = false
			if err != nil {
				section.err = failure
				return
			}
			section.items = items
		})
	}()
}

func (a *app) loadHomeModes() {
	readHomeSection(a, &a.homeSections.modes, netease.HomeRecommendations, "个性推荐加载失败")
}

func (a *app) loadHomeRecent() {
	readHomeSection(a, &a.homeSections.recent, func() ([]netease.RecentlyPlayedPlaylist, error) {
		return netease.RecentPlaylists(18)
	}, "最近播放加载失败")
}

func (a *app) openHomeRecommendation(entry netease.HomeRecommendation, play bool) {
	if entry.Album {
		if play {
			a.playHomeAlbum(entry.ID)
		} else {
			a.open(route{page: pageAlbum, id: entry.ID})
		}
		return
	}
	if len(entry.Tracks) > 0 {
		if play {
			a.pl.PlayQueue(entry.Tracks, firstPlayable(entry.Tracks))
			return
		}
		a.open(route{page: pageHomeMix, query: entry.Key})
		return
	}
	if play {
		a.loadPlaylist(entry.ID, true)
	} else {
		a.open(route{page: pagePlaylist, id: entry.ID})
	}
}

func (a *app) homeMixPage(c *ui.Context) {
	for _, item := range a.homeSections.modes.items {
		if a.route.query != item.Key {
			continue
		}
		a.toolRows(c, item.Tracks, false, func(c *ui.Context) {
			a.heading(c, item.Title, item.Category)
			if pillButton(c.Key("play"), iconPlay, "播放全部", a.pal.accent, a.pal.onAccent).Clicked() {
				a.pl.PlayQueue(item.Tracks, firstPlayable(item.Tracks))
			}
		})
		return
	}
	a.centered(c, "这组推荐已更新", func() { a.open(route{page: pageHome}) })
}

func (a *app) playHomeAlbum(id int64) {
	if data := a.albums[id]; data != nil && data.album != nil {
		songs := data.album.Songs
		a.pl.PlayQueue(songs, firstPlayable(songs))
		return
	}
	gen, playing := a.accountGen, a.pl.RadioGeneration()
	go func() {
		album, err := albumDetail(id)
		a.post(func() {
			if gen != a.accountGen || playing != a.pl.RadioGeneration() {
				return
			}
			if err != nil || album == nil || len(album.Songs) == 0 {
				a.toast = "专辑暂时无法播放"
				return
			}
			a.albums[id] = &albumData{album: album}
			a.pl.PlayQueue(album.Songs, firstPlayable(album.Songs))
		})
	}()
}
