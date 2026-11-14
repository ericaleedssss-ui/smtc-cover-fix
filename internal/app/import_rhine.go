// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"unicode/utf16"

	"netease-music-mygo/internal/netease"
)

func legacyImportArgs(args []string) (source, downloads string) {
	for i := 0; i < len(args); i++ {
		if args[i] != "--import-rhine" && args[i] != "--import-rhine-downloads" {
			continue
		}
		if i+1 == len(args) || strings.HasPrefix(args[i+1], "--") {
			log.Print("旧版数据导入：参数缺少目录")
			continue
		}
		if args[i] == "--import-rhine" {
			source = args[i+1]
		} else {
			downloads = args[i+1]
		}
		i++
	}
	return
}

func importLegacyRhine(source, downloads, dest string) error {
	if _, err := os.Lstat(dest); !errors.Is(err, os.ErrNotExist) {
		return err
	}
	source, err := filepath.EvalSymlinks(source)
	if err != nil {
		return fmt.Errorf("无法打开旧版数据目录：%w", err)
	}
	dir, err := filepath.EvalSymlinks(filepath.Dir(dest))
	if err != nil {
		return err
	}
	source, err = filepath.Abs(source)
	if err != nil {
		return err
	}
	if rel, err := filepath.Rel(source, dir); err == nil && filepath.IsLocal(rel) {
		return errors.New("新版数据目录不能位于导入源内")
	}
	if downloads != "" {
		downloads, err = filepath.EvalSymlinks(downloads)
		if err == nil {
			downloads, err = filepath.Abs(downloads)
		}
		if err != nil {
			return fmt.Errorf("解析旧版下载目录：%w", err)
		}
		if pathWithin(downloads, dir) || strings.EqualFold(downloads, dir) {
			return errors.New("新版数据目录不能位于旧版下载目录内")
		}
	}
	prefs, err := readLegacyPreferences(filepath.Join(source, "settings.ini"))
	if err != nil {
		return fmt.Errorf("读取旧版设置：%w", err)
	}
	s := legacySettings(prefs)
	history, err := legacyHistory(prefs["panel/play-history"])
	if err == nil {
		delete(prefs, "panel/play-history")
	}
	if err != nil {
		log.Print("旧版数据导入：播放历史格式无效")
	}
	if len(history) > 0 {
		if err := writeLegacyJSON(filepath.Join(dir, "history.json"), history); err != nil {
			return err
		}
	}
	listening := map[string]json.RawMessage{}
	for key, value := range prefs {
		if strings.HasPrefix(key, "recent-bookmarks/") || strings.HasPrefix(key, "weekly-score/") ||
			strings.HasPrefix(key, "playlist-listens/") || strings.HasPrefix(key, "weekly-score-quote/") {
			if json.Valid([]byte(value)) {
				listening[key] = json.RawMessage(value)
				delete(prefs, key)
			}
		}
	}
	if len(listening) > 0 {
		if err := writeLegacyJSON(filepath.Join(dir, "rhine-listening.json"), listening); err != nil {
			return err
		}
	}
	if downloads != "" {
		a := &app{downloadArtDir: filepath.Join(dir, "imported-download-covers")}
		items, err := a.scanDownloadFolder(downloads, nil)
		if err != nil {
			log.Print("旧版数据导入：无法打开指定的下载目录")
		}
		for i := range items {
			items[i].ReadOnly = true
		}
		if len(items) > 0 {
			if err := writeLegacyJSON(filepath.Join(dir, "downloads.json"), items); err != nil {
				return err
			}
		}
	}
	if err := importLegacyAccount(filepath.Join(source, "account.dpapi")); err != nil && !errors.Is(err, os.ErrNotExist) {
		log.Print("旧版数据导入：无法恢复网易云登录，请重新扫码")
	}
	for key := range prefs {
		log.Printf("旧版数据导入：忽略无对应项或无效的设置 %q", key)
	}
	return writeLegacyJSON(dest, s)
}

// Keep existing newer records and publish completed files only.
func writeLegacyJSON(path string, value any) error {
	if _, err := os.Lstat(path); !errors.Is(err, os.ErrNotExist) {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".rhine-import-")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	enc := json.NewEncoder(f)
	enc.SetIndent("", "  ")
	if err := enc.Encode(value); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	return os.Rename(f.Name(), path)
}

func readLegacyPreferences(path string) (map[string]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	prefs := map[string]string{}
	section := "General"
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 4096), 4<<20)
	for scanner.Scan() {
		line := strings.TrimSpace(strings.TrimPrefix(scanner.Text(), "\uFEFF"))
		if line == "" || strings.HasPrefix(line, ";") || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = strings.TrimSuffix(strings.TrimPrefix(line, "["), "]")
			continue
		}
		key, raw, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.ReplaceAll(strings.TrimSpace(key), "\\", "/")
		if decoded, err := url.PathUnescape(key); err == nil {
			key = decoded
		}
		prefs[section+"/"+key] = decodeQtValue(strings.TrimSpace(raw))
	}
	return prefs, scanner.Err()
}

func decodeQtValue(raw string) string {
	isBytes := strings.HasPrefix(raw, "@ByteArray(") && strings.HasSuffix(raw, ")")
	if isBytes {
		raw = raw[len("@ByteArray(") : len(raw)-1]
	} else if strings.HasPrefix(raw, "@@") {
		raw = raw[1:]
	}
	// QSettings wraps byte arrays and quotes values containing its separators.
	raw = strings.TrimSuffix(raw, "\x00")
	var out strings.Builder
	for i := 0; i < len(raw); i++ {
		ch := raw[i]
		if ch == '"' {
			continue
		}
		if ch != '\\' || i+1 == len(raw) {
			out.WriteByte(ch)
			continue
		}
		i++
		switch raw[i] {
		case 'n':
			out.WriteByte('\n')
		case 'r':
			out.WriteByte('\r')
		case 't':
			out.WriteByte('\t')
		case 'x':
			start := i + 1
			for i+1 < len(raw) && i-start < 3 && (!isBytes || i-start < 1) && strings.ContainsRune("0123456789abcdefABCDEF", rune(raw[i+1])) {
				i++
			}
			if i < start {
				out.WriteByte('x')
				continue
			}
			n, _ := strconv.ParseUint(raw[start:i+1], 16, 16)
			if n >= 0xD800 && n <= 0xDBFF && i+6 < len(raw) && raw[i+1:i+3] == "\\x" {
				low, err := strconv.ParseUint(raw[i+3:i+7], 16, 16)
				if err == nil && low >= 0xDC00 && low <= 0xDFFF {
					out.WriteRune(utf16.DecodeRune(rune(n), rune(low)))
					i += 6
					continue
				}
			}
			if isBytes {
				out.WriteByte(byte(n))
			} else {
				out.WriteRune(rune(n))
			}
		default:
			out.WriteByte(raw[i])
		}
	}
	return out.String()
}

func legacySettings(prefs map[string]string) settings {
	s := defaultSettings()
	take := func(key string, apply func(string) bool) {
		full := "panel/" + key
		if value, exists := prefs[full]; exists && apply(value) {
			delete(prefs, full)
		}
	}
	choice := func(key string, target *string, values ...string) {
		take(key, func(value string) bool {
			for _, valid := range values {
				if value == valid {
					*target = value
					return true
				}
			}
			return false
		})
	}
	toggle := func(key string, target *bool) {
		take(key, func(value string) bool {
			switch value {
			case "on", "true", "1":
				*target = true
			case "off", "false", "0":
				*target = false
			default:
				return false
			}
			return true
		})
	}
	number := func(key string, target *float64, lo, hi float64) {
		take(key, func(value string) bool {
			n, err := strconv.ParseFloat(value, 64)
			if err != nil || !(n >= lo && n <= hi) {
				return false
			}
			*target = n
			return true
		})
	}
	choice("theme", &s.Appearance, "system", "light", "dark")
	choice("quality", &s.Quality, "standard", "higher", "exhigh", "lossless", "hires")
	take("ui-font", func(value string) bool {
		for _, font := range uiFonts {
			if value == font.id || value == font.family {
				s.Font = font.id
				return true
			}
		}
		return false
	})
	choice("stage-style", &s.StageStyle, "", "partita", "tilt")
	choice("desktop-lyrics-style", &s.DeskStyle, "glass", "light", "outline", "color", "plain")
	take("motion", func(v string) bool {
		switch v {
		case "full":
			s.Motion = "full"
		case "reduced":
			s.Motion = "lite"
		default:
			return false
		}
		return true
	})
	toggle("disc-rotation", &s.BarSpin)
	toggle("lyric-translation", &s.LyricTrans)
	toggle("stage-sparks", &s.StageSparks)
	toggle("desktop-lyrics", &s.DeskLyrics)
	toggle("desktop-lyrics-locked", &s.DeskLock)
	number("volume", &s.Volume, 0, 1)
	number("lyric-scale", &s.LyricScale, .5, 3)
	number("desktop-lyrics-scale", &s.DeskScale, .5, 3)
	take("search-history", func(value string) bool {
		var history []string
		if json.Unmarshal([]byte(value), &history) != nil {
			return false
		}
		s.SearchHistory = history
		return true
	})
	s.UpdateChecks, s.UpdateInstall = false, false
	return s
}

func legacyHistory(raw string) ([]playedSong, error) {
	if raw == "" {
		return nil, nil
	}
	var entries []struct {
		ID, Kind, Title, Provider, Artist, Album, AlbumID, Cover string
		Artists                                                  []struct{ ID, Name string }
		Duration                                                 int64
	}
	if err := json.Unmarshal([]byte(raw), &entries); err != nil {
		return nil, err
	}
	songs := make([]playedSong, 0, min(len(entries), historyLimit))
	seen := map[int64]bool{}
	for _, e := range entries {
		id, _ := strconv.ParseInt(e.ID, 10, 64)
		if e.Kind != "song" || e.Provider != "netease" || id <= 0 || seen[id] {
			continue
		}
		seen[id] = true
		album, _ := strconv.ParseInt(e.AlbumID, 10, 64)
		track := netease.Track{ID: id, Name: e.Title, Duration: e.Duration,
			Album: netease.Album{ID: album, Name: e.Album, PicURL: e.Cover}}
		for _, a := range e.Artists {
			id, _ := strconv.ParseInt(a.ID, 10, 64)
			track.Artists = append(track.Artists, netease.Artist{ID: id, Name: a.Name})
		}
		if len(track.Artists) == 0 && e.Artist != "" {
			track.Artists = []netease.Artist{{Name: e.Artist}}
		}
		songs = append(songs, playedSong{Track: track})
		if len(songs) == historyLimit {
			break
		}
	}
	return songs, nil
}
