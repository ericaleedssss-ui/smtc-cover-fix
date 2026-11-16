// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"sync"
	"time"

	"netease-music-mygo/internal/netease"
)

type memoListen struct {
	ID                        string
	Start, Last, Milliseconds int64
}

type memoEncounter struct {
	First int64
	Count int
}

type memoBookmark struct {
	Track        netease.Track
	Position, At int64
}

type memoScoreQuote struct {
	Content, Author string
	CommentID       int64
}

type memoAccount struct {
	ScoreLayouts map[string]int            `json:",omitempty"`
	ScoreQuotes  map[string]memoScoreQuote `json:",omitempty"`
	Listens      []memoListen
	Encounters   map[string]memoEncounter
	Recent       []memoBookmark
}

type homeMemoState struct {
	loaded    bool
	accounts  map[string]*memoAccount
	imported  map[string]json.RawMessage
	listening *memoAccount
	session   int
	saved     time.Time
	painted   time.Time
}

func (a *app) homeMemoAccount() *memoAccount {
	state := &a.homeMemo
	if !state.loaded {
		state.loaded = true
		if path, err := historyPath(); err == nil {
			dir := filepath.Dir(path)
			if b, err := os.ReadFile(filepath.Join(dir, "home-memo.json")); err == nil {
				_ = json.Unmarshal(b, &state.accounts)
			}
			if b, err := os.ReadFile(filepath.Join(dir, "rhine-listening.json")); err == nil {
				_ = json.Unmarshal(b, &state.imported)
			}
		}
		if state.accounts == nil {
			state.accounts = make(map[string]*memoAccount)
		}
	}
	uid := ""
	if a.profile != nil {
		uid = strconv.FormatInt(a.profile.UserID, 10)
	}
	key := fmt.Sprintf("listening-score-v1-%x", sha256.Sum256([]byte("netease:"+uid)))
	if m := state.accounts[key]; m != nil {
		return m
	}
	m := &memoAccount{Encounters: make(map[string]memoEncounter)}
	state.accounts[key] = m
	var listens []memoListen
	_ = json.Unmarshal(state.imported["weekly-score/"+key], &listens)
	for _, l := range listens {
		if l.ID != "" && l.Start > 0 && l.Last >= l.Start && l.Milliseconds >= 10000 {
			m.add(l)
		}
	}
	var bookmarks map[string]struct {
		Source struct{ Provider string }
		Track  struct {
			ID, Kind, Title, Artist, Album, Cover string
			Duration                              int64
		}
		Position, At int64
	}
	_ = json.Unmarshal(state.imported["recent-bookmarks/"+key], &bookmarks)
	for _, b := range bookmarks {
		if b.Source.Provider != "netease" || b.Track.Kind != "song" {
			continue
		}
		id, _ := strconv.ParseInt(b.Track.ID, 10, 64)
		if id <= 0 {
			continue
		}
		tr := netease.Track{ID: id, Name: b.Track.Title, Duration: b.Track.Duration,
			Album:   netease.Album{Name: b.Track.Album, PicURL: b.Track.Cover},
			Artists: []netease.Artist{{Name: b.Track.Artist}}}
		m.Recent = append(m.Recent, memoBookmark{tr, b.Position, b.At})
	}
	slices.SortFunc(m.Recent, func(a, b memoBookmark) int {
		if a.At == b.At {
			return 0
		}
		if a.At > b.At {
			return -1
		}
		return 1
	})
	return m
}

func (m *memoAccount) add(l memoListen) {
	m.Listens = append(m.Listens, l)
	if l.Milliseconds >= 30000 {
		m.encounter(l.ID, l.Start)
	}
}

func (m *memoAccount) encounter(id string, start int64) {
	if m.Encounters == nil {
		m.Encounters = make(map[string]memoEncounter)
	}
	e := m.Encounters[id]
	if e.First == 0 || start < e.First {
		e.First = start
	}
	e.Count++
	m.Encounters[id] = e
}

// recordHomeProgress accumulates confirmed audio time and splits calendar days.
func (a *app) recordHomeProgress(t netease.Track, session int, position, elapsed time.Duration, now time.Time) {
	if t.ProgramID != 0 || elapsed < time.Millisecond {
		return
	}
	state := &a.homeMemo
	m := a.homeMemoAccount()
	id := historyKey(&t)
	if t.ID != 0 {
		id = strconv.FormatInt(t.ID, 10)
	}
	merge := state.listening == m && state.session == session
	state.listening, state.session = m, session
	for start := now.Add(-elapsed); start.Before(now); {
		midnight := time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, start.Location())
		end := midnight.AddDate(0, 0, 1)
		if end.After(now) {
			end = now
		}
		m.addProgress(id, start, end, midnight, merge)
		merge = false
		start = end
	}
	if len(m.Listens) > 5000 {
		m.Listens = slices.Clone(m.Listens[len(m.Listens)-5000:])
	}
	if m.Listens[len(m.Listens)-1].Milliseconds >= historyAfter.Milliseconds() {
		m.bookmark(t, position, now)
	}
	if now.Sub(state.saved) >= 10*time.Second {
		a.persistHomeMemo()
		state.saved = now
	}
	if now.Sub(state.painted) >= 15*time.Second && a.route.page == pageHome {
		state.painted = now
		a.redraw()
	}
}

func (m *memoAccount) addProgress(id string, start, end, midnight time.Time, merge bool) {
	delta := end.UnixMilli() - start.UnixMilli()
	if n := len(m.Listens); merge && n > 0 {
		last := &m.Listens[n-1]
		if last.ID == id && last.Start >= midnight.UnixMilli() && start.UnixMilli()-last.Last <= (20*time.Minute).Milliseconds() {
			if last.Milliseconds < 30000 && last.Milliseconds+delta >= 30000 {
				m.encounter(id, last.Start)
			}
			last.Milliseconds += delta
			last.Last = end.UnixMilli()
			return
		}
	}
	m.add(memoListen{id, start.UnixMilli(), end.UnixMilli(), delta})
}

func (m *memoAccount) bookmark(t netease.Track, position time.Duration, now time.Time) {
	if len(m.Recent) > 0 && historyKey(&m.Recent[0].Track) == historyKey(&t) {
		m.Recent[0] = memoBookmark{t, position.Milliseconds(), now.UnixMilli()}
		return
	}
	recent := slices.DeleteFunc(m.Recent, func(b memoBookmark) bool {
		return historyKey(&b.Track) == historyKey(&t)
	})
	m.Recent = append([]memoBookmark{{t, position.Milliseconds(), now.UnixMilli()}}, recent[:min(11, len(recent))]...)
}

func (a *app) finishHomeListen(t netease.Track, ended bool) {
	m := a.homeMemo.listening
	if m == nil {
		return
	}
	if ended && len(m.Recent) > 0 && historyKey(&m.Recent[0].Track) == historyKey(&t) {
		m.Recent[0].Position = 0
	}
	a.persistHomeMemo()
}

func (a *app) persistHomeMemo() <-chan struct{} {
	if path, err := historyPath(); a.homeMemo.loaded && err == nil {
		return saveHomeMemo(filepath.Join(filepath.Dir(path), "home-memo.json"), a.homeMemo.accounts)
	}
	return nil
}

func (a *app) resumeMemo(b memoBookmark) {
	position := min(max(b.Position, 0), max(b.Track.Duration-1000, 0))
	a.pl.PlayQueueFrom([]netease.Track{b.Track}, 0, time.Duration(position)*time.Millisecond)
}

func (m *memoAccount) week(now time.Time) [7]int64 {
	// The score follows the previous seven listening days; a day turns at 4am.
	start := now.Add(-4 * time.Hour)
	start = time.Date(start.Year(), start.Month(), start.Day(), 4, 0, 0, 0, start.Location()).AddDate(0, 0, -6)
	var days [7]int64
	for i := range days {
		end := start.AddDate(0, 0, 1)
		for _, l := range m.Listens {
			if l.Start >= start.UnixMilli() && l.Start < end.UnixMilli() {
				days[i] += l.Milliseconds
			}
		}
		start = end
	}
	return days
}

// Serialize snapshots per file so a slower write cannot lose a later listen.
var homeMemoWrites = struct {
	sync.Mutex
	pending map[string]*homeMemoWrite
}{pending: make(map[string]*homeMemoWrite)}

type homeMemoWrite struct {
	data []byte
	done chan struct{}
}

func saveHomeMemo(path string, accounts map[string]*memoAccount) <-chan struct{} {
	b, err := json.Marshal(accounts)
	if err != nil {
		return nil
	}
	w := &homeMemoWrites
	w.Lock()
	if pending := w.pending[path]; pending != nil {
		pending.data = b
		w.Unlock()
		return pending.done
	}
	pending := &homeMemoWrite{data: b, done: make(chan struct{})}
	w.pending[path] = pending
	w.Unlock()
	go func() {
		for {
			w.Lock()
			b := pending.data
			if b == nil {
				delete(w.pending, path)
				close(pending.done)
				w.Unlock()
				return
			}
			pending.data = nil
			w.Unlock()
			if err := writeHomeMemo(path, b); err != nil {
				log.Printf("保存听歌记录：%v", err)
			}
		}
	}()
	return pending.done
}

func writeHomeMemo(path string, b []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	if err := os.WriteFile(path+".part", b, 0o600); err != nil {
		return err
	}
	return os.Rename(path+".part", path)
}
