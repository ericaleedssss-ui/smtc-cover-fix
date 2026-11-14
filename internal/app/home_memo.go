// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
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

type memoAccount struct {
	Listens    []memoListen
	Encounters map[string]memoEncounter
	Recent     []memoBookmark
}

type homeMemoState struct {
	loaded   bool
	accounts map[string]*memoAccount
	imported map[string]json.RawMessage
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
		e := m.Encounters[l.ID]
		if e.First == 0 || l.Start < e.First {
			e.First = l.Start
		}
		e.Count++
		m.Encounters[l.ID] = e
	}
}

// Rhine: keep the listening score on the existing playback event, free of a
// home-page timer. Each account owns its scores and playback bookmarks.
func (a *app) recordHomeListen(t netease.Track, played time.Duration, ended bool, now time.Time) {
	if t.ProgramID != 0 || played < historyAfter {
		return
	}
	m := a.homeMemoAccount()
	if m.Encounters == nil {
		m.Encounters = make(map[string]memoEncounter)
	}
	id := historyKey(&t)
	if t.ID != 0 {
		id = strconv.FormatInt(t.ID, 10)
	}
	m.add(memoListen{id, now.Add(-played).UnixMilli(), now.UnixMilli(), played.Milliseconds()})
	if len(m.Listens) > 5000 {
		m.Listens = slices.Clone(m.Listens[len(m.Listens)-5000:])
	}
	position := played.Milliseconds()
	if ended {
		position = 0
	}
	recent := slices.DeleteFunc(m.Recent, func(b memoBookmark) bool {
		return historyKey(&b.Track) == historyKey(&t)
	})
	m.Recent = append([]memoBookmark{{t, position, now.UnixMilli()}}, recent[:min(11, len(recent))]...)
	path, err := historyPath()
	if err == nil {
		saveHomeMemo(filepath.Join(filepath.Dir(path), "home-memo.json"), a.homeMemo.accounts)
	}
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
	pending map[string][]byte
}{pending: make(map[string][]byte)}

func saveHomeMemo(path string, accounts map[string]*memoAccount) {
	b, err := json.Marshal(accounts)
	if err != nil {
		return
	}
	w := &homeMemoWrites
	w.Lock()
	_, running := w.pending[path]
	w.pending[path] = b
	w.Unlock()
	if running {
		return
	}
	go func() {
		for {
			w.Lock()
			b := w.pending[path]
			if b == nil {
				delete(w.pending, path)
				w.Unlock()
				return
			}
			w.pending[path] = nil
			w.Unlock()
			if os.WriteFile(path+".part", b, 0o600) == nil {
				_ = os.Rename(path+".part", path)
			}
		}
	}()
}
