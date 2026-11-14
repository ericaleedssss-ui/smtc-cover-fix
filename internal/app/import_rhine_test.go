// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"crypto/sha256"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"netease-music-mygo/internal/download"
)

// Import reads a Qt INI, keeps recent plays and downloads, and leaves every source byte intact.
func TestLegacyRhineImport(t *testing.T) {
	oldDir, newDir := t.TempDir(), t.TempDir()
	ini := filepath.Join(oldDir, "settings.ini")
	song := filepath.Join(oldDir, "测试-123.mp3")
	fixture := `[panel]
theme=dark
volume=0.42
motion=reduced
search-history=[\"中文搜索\"]
play-history="[{\"kind\":\"song\",\"id\":\"123\",\"provider\":\"netease\",\"title\":\"测试\"}]"
auto-update=on
[weekly-score]
listening-score-v1-example=@ByteArray([{\"title\":\"\xe6\xb5\x8b\xe8\xaf\x95\"}])
`
	for path, body := range map[string]string{ini: fixture, song: "fake audio", filepath.Join(oldDir, "account.dpapi"): "fake credentials"} {
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	snapshot := func() map[string][32]byte {
		t.Helper()
		entries, err := os.ReadDir(oldDir)
		if err != nil {
			t.Fatal(err)
		}
		hashes := map[string][32]byte{}
		for _, entry := range entries {
			b, err := os.ReadFile(filepath.Join(oldDir, entry.Name()))
			if err != nil {
				t.Fatal(err)
			}
			hashes[entry.Name()] = sha256.Sum256(b)
		}
		return hashes
	}
	before := snapshot()
	dest := filepath.Join(newDir, "settings.json")
	if err := importLegacyRhine(oldDir, oldDir, dest); err != nil {
		t.Fatal(err)
	}
	read := func(name string, out any) {
		t.Helper()
		b, err := os.ReadFile(filepath.Join(newDir, name))
		if err != nil {
			t.Fatal(err)
		}
		if err := json.Unmarshal(b, out); err != nil {
			t.Fatal(err)
		}
	}
	var s settings
	read("settings.json", &s)
	if s.Appearance != "dark" || s.Volume != .42 || s.Motion != "lite" ||
		s.UpdateChecks || s.UpdateInstall || len(s.SearchHistory) != 1 || s.SearchHistory[0] != "中文搜索" {
		t.Fatal("settings did not map")
	}
	var history []playedSong
	read("history.json", &history)
	if len(history) != 1 || history[0].Track.ID != 123 || history[0].Track.Name != "测试" || history[0].At != 0 {
		t.Fatalf("history did not map: %+v", history)
	}
	var listening map[string][]struct{ Title string }
	read("rhine-listening.json", &listening)
	week := listening["weekly-score/listening-score-v1-example"]
	if len(week) != 1 || week[0].Title != "测试" {
		t.Fatal("the listening record lost its UTF-8")
	}
	var items []download.Item
	read("downloads.json", &items)
	if len(items) != 1 || items[0].Path != song || !items[0].ReadOnly {
		t.Fatal("the old download was not indexed read-only")
	}
	a := newTestApp()
	a.downloads = items
	a.downloadDelete = downloadDelete{open: true, path: song}
	a.deleteDownload()
	if err := os.WriteFile(dest, []byte("{}"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := importLegacyRhine(oldDir, oldDir, dest); err != nil {
		t.Fatal(err)
	}
	if b, err := os.ReadFile(dest); err != nil || string(b) != "{}" {
		t.Fatal("retry replaced existing settings")
	}
	after := snapshot()
	if len(before) != len(after) {
		t.Fatal("source file count changed")
	}
	for name, hash := range before {
		if after[name] != hash {
			t.Errorf("source changed: %s", name)
		}
	}
}

// A destination inside the legacy tree is rejected even when settings are absent.
func TestLegacyRhineImportRejectsSourceDestination(t *testing.T) {
	dir := t.TempDir()
	if err := importLegacyRhine(dir, "", filepath.Join(dir, "settings.json")); err == nil {
		t.Fatal("would import into the source")
	}
}
