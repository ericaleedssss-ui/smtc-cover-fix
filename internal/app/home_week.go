// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"math"
	"math/rand/v2"
	"slices"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/egoist/mygo/ui"

	"netease-music-mygo/internal/netease"
)

type homeWeeklyState struct {
	report       *netease.WeeklyScore
	loading      bool
	err          string
	fetched      time.Time
	quote        memoScoreQuote
	quoteMeasure scoreQuoteMeasure
	quoteKey     string
	drawingKey   string
	drawing      *ui.SVG
	labels       []scoreLabel
	scoreKey     string
	cached       scoreWeek
}

// Rebuild the score only when its source changes, never on every hover frame.
func (a *app) cachedHomeScore(now time.Time) scoreWeek {
	s := &a.homeSections.weekly
	m := a.homeMemoAccount()
	var last memoListen
	if len(m.Listens) > 0 {
		last = m.Listens[len(m.Listens)-1]
	}
	key := fmt.Sprintf("%p:%p:%d:%d:%v:%s", m, s.report, len(m.Listens), len(m.Recent), last, now.Format("2006-01-02"))
	if key != s.scoreKey {
		s.scoreKey = key
		s.cached = a.homeScore(now)
		s.drawingKey = ""
	}
	return s.cached
}

var fetchHomeWeekly = netease.HomeWeeklyScoreProgress
var fetchScoreComments = netease.HomeScoreComments

func (a *app) loadHomeWeekly() {
	s := &a.homeSections.weekly
	if a.profile == nil || s.loading {
		return
	}
	s.loading, s.err = true, ""
	gen, uid := a.accountGen, a.profile.UserID
	go func() {
		report, err := fetchHomeWeekly(uid, func(report netease.WeeklyScore) {
			a.post(func() {
				if gen != a.accountGen {
					return
				}
				if previous := s.report; previous != nil && previous.StartTime == report.StartTime {
					report.Ranking, report.RankingLabel = previous.Ranking, previous.RankingLabel
					report.Recent = previous.Recent
					report.PreviousMinutes, report.ComparisonAvailable = previous.PreviousMinutes, previous.ComparisonAvailable
				} else {
					s.quoteKey, s.quote = "", memoScoreQuote{}
				}
				s.report = &report
			})
		})
		a.post(func() {
			if gen != a.accountGen {
				return
			}
			s.loading, s.fetched = false, time.Now()
			if err != nil || report == nil || len(report.Days) == 0 {
				s.err = "听歌周报加载失败"
				return
			}
			s.report = report
			top := scoreTop(report.Ranking)
			key := fmt.Sprint(report.Days[0].Date, ":", top.SongID)
			if key == s.quoteKey {
				return
			}
			memo := a.homeMemoAccount()
			s.quoteKey, s.quote = key, memo.ScoreQuotes[key]
			if top.SongID <= 0 || s.quote.Content != "" {
				return
			}
			go func() {
				comments, err := fetchScoreComments(top.SongID)
				a.post(func() {
					if gen != a.accountGen || key != s.quoteKey {
						return
					}
					if err != nil {
						s.quoteKey = ""
						return
					}
					selected := scoreQuote(comments, fmt.Sprint(uid, ":", key))
					if selected.Content == "" {
						return
					}
					s.quote = memoScoreQuote{selected.Content, selected.User.Nickname, selected.ID}
					if memo.ScoreQuotes == nil {
						memo.ScoreQuotes = make(map[string]memoScoreQuote)
					}
					memo.ScoreQuotes[key] = s.quote
					a.pruneScoreMemo(memo, time.Now())
					a.persistHomeMemo()
				})
			}()
		})
	}()
}

func scoreTop(rows []netease.ScoreRank) netease.ScoreRank {
	var top netease.ScoreRank
	for _, row := range rows {
		if row.PlayCount > top.PlayCount {
			top = row
		}
	}
	return top
}

// Whole, short comments only, following HomePage.cpp. Never shorten a story.
func scoreQuote(rows []netease.Comment, key string) netease.Comment {
	var choices []netease.Comment
	for _, row := range rows {
		text := strings.TrimSpace(row.Content)
		limit := 62
		for _, r := range text {
			if unicode.Is(unicode.Han, r) {
				limit = 24
				break
			}
		}
		n := utf8.RuneCountInString(text)
		lower := strings.ToLower(text)
		if n < 4 || n > limit || strings.ContainsAny(text, "\r\n@") || strings.Contains(lower, "http://") || strings.Contains(lower, "https://") || strings.Contains(lower, "www.") || strings.Contains(text, "回复") || strings.Contains(text, "转发") {
			continue
		}
		row.Content = text
		choices = append(choices, row)
	}
	if len(choices) == 0 {
		return netease.Comment{}
	}
	slices.SortStableFunc(choices, func(a, b netease.Comment) int { return b.LikedCount - a.LikedCount })
	hash := sha256.Sum256([]byte(key))
	return choices[int(binary.BigEndian.Uint32(hash[:4])%uint32(min(5, len(choices))))]
}

type scoreSession struct {
	track  netease.Track
	at     time.Time
	weight float64
}
type scoreDay struct {
	date     time.Time
	minutes  float64
	sessions []scoreSession
}
type scoreWeek struct {
	days               [7]scoreDay
	minutes, previous  float64
	comparison, online bool
	top                netease.ScoreRank
	label              string
	variant            int
}

// Calendar weeks and calendar midnight match the Qt report, including DST.
func calendarWeek(now time.Time) time.Time {
	d := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	return d.AddDate(0, 0, -(int(d.Weekday())+6)%7)
}

func (a *app) homeScore(now time.Time) scoreWeek {
	memo := a.homeMemoAccount()
	report := a.homeSections.weekly.report
	w := scoreWeek{label: "本机本周循环最多"}
	start := calendarWeek(now)
	if report != nil && len(report.Days) > 0 {
		if d, err := time.ParseInLocation("2006-01-02", report.Days[0].Date, now.Location()); err == nil && !now.Before(d) && now.Before(d.AddDate(0, 0, 7)) {
			start = d
			w.online = true
			w.minutes, w.previous, w.comparison = report.Minutes, report.PreviousMinutes, report.ComparisonAvailable
			w.top, w.label = scoreTop(report.Ranking), report.RankingLabel
		}
	}
	tracks := map[string]netease.Track{}
	for _, b := range memo.Recent {
		tracks[historyKey(&b.Track)] = b.Track
		tracks[fmt.Sprint(b.Track.ID)] = b.Track
	}
	if w.online {
		for _, ob := range report.Recent {
			tracks[fmt.Sprint(ob.Track.ID)] = ob.Track
		}
	}
	for i := range w.days {
		d := &w.days[i]
		d.date = start.AddDate(0, 0, i)
		end := d.date.AddDate(0, 0, 1)
		if w.online {
			for _, row := range report.Days {
				if row.Date == d.date.Format("2006-01-02") {
					d.minutes = row.Minutes
				}
			}
		}
		for _, l := range memo.Listens {
			if l.Start < d.date.UnixMilli() || l.Start >= end.UnixMilli() || l.Milliseconds < 10000 {
				continue
			}
			if !w.online {
				d.minutes += float64(l.Milliseconds) / 60000
			}
			d.sessions = append(d.sessions, scoreSession{tracks[l.ID], time.UnixMilli(l.Start).In(now.Location()), float64(l.Milliseconds) / 60000})
		}
		if w.online {
			for _, ob := range report.Recent {
				at := time.UnixMilli(ob.At).In(now.Location())
				if at.Before(d.date) || !at.Before(end) {
					continue
				}
				duplicate := false
				for _, s := range d.sessions {
					if s.track.ID == ob.Track.ID && math.Abs(float64(s.at.UnixMilli()-ob.At)) < 300000 {
						duplicate = true
						break
					}
				}
				if !duplicate {
					d.sessions = append(d.sessions, scoreSession{ob.Track, at, min(15, max(.25, float64(ob.Track.Duration)/60000))})
				}
			}
		}
		slices.SortFunc(d.sessions, func(a, b scoreSession) int { return a.at.Compare(b.at) })
		if !w.online {
			w.minutes += d.minutes
		}
	}
	// Local counts are separate from the rolling online ranking and never inferred
	// from the upstream history, which has already been de-duplicated.
	if !w.online {
		counts := map[string]int{}
		for _, l := range memo.Listens {
			if l.Start >= start.UnixMilli() && l.Start < start.AddDate(0, 0, 7).UnixMilli() && l.Milliseconds >= 30000 {
				counts[l.ID]++
			}
		}
		for id, n := range counts {
			if tr := tracks[id]; tr.Name != "" && (n > w.top.PlayCount || n == w.top.PlayCount && tr.ID < w.top.SongID) {
				w.top = netease.ScoreRank{SongID: tr.ID, SongName: tr.Name, PlayCount: n}
			}
		}
	}
	w.variant = a.scoreLayout(memo, start, now, w.online)
	return w
}

// Rhine: keep the first composition picked for this account and report.
func (a *app) scoreLayout(memo *memoAccount, start, now time.Time, online bool) int {
	key := start.Format("2006-01-02")
	if layout, exists := memo.ScoreLayouts[key]; exists && layout >= 0 && layout < 4 {
		return layout
	}
	if !online || a.win == nil {
		hash := sha256.Sum256([]byte(key))
		return int(hash[0] % 4)
	}
	layout := rand.IntN(4)
	if memo.ScoreLayouts == nil {
		memo.ScoreLayouts = make(map[string]int)
	}
	memo.ScoreLayouts[key] = layout
	a.pruneScoreMemo(memo, now)
	a.persistHomeMemo()
	return layout
}

func (a *app) pruneScoreMemo(memo *memoAccount, now time.Time) {
	cutoff := now.AddDate(0, 0, -35).Format("2006-01-02")
	for key := range memo.ScoreLayouts {
		if key < cutoff {
			delete(memo.ScoreLayouts, key)
		}
	}
	for key := range memo.ScoreQuotes {
		if key < cutoff {
			delete(memo.ScoreQuotes, key)
		}
	}
}

// Values are quarter-hour units. Splitting changes density, never total time.
func scoreRhythm(minutes float64, style int) []int {
	units := max(1, int(math.Floor(min(1440, minutes)/15+.5)))
	var values []int
	for units > 0 {
		for _, v := range []int{16, 12, 8, 6, 4, 3, 2, 1} {
			if v <= units {
				values = append(values, v)
				units -= v
				break
			}
		}
	}
	target := []int{3, 5, 4, 2}[style%4]
	parts := map[int][2]int{16: {8, 8}, 12: {8, 4}, 8: {4, 4}, 6: {4, 2}, 4: {2, 2}, 3: {2, 1}, 2: {1, 1}}
	for len(values) < target && len(values) < 8 {
		at := -1
		for i, v := range values {
			if v > 1 && (at < 0 || v > values[at]) {
				at = i
			}
		}
		if at < 0 {
			break
		}
		pair := parts[values[at]]
		values = append(values[:at], append([]int{pair[0], pair[1]}, values[at+1:]...)...)
	}
	return values
}
