// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"image/png"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/egoist/mygo/ui"

	"netease-music-mygo/internal/netease"
	"netease-music-mygo/internal/player"
)

func rhineM6Fixture(t *testing.T, screen string) *app {
	t.Helper()
	a := newTestApp()
	a.settings = defaultSettings()
	a.settings.Fog = false
	accentHome(a)
	a.profile = &netease.Profile{UserID: 10, Nickname: "星屿"}
	listener := netease.User{UserID: 20, Nickname: "青山入夜", Signature: "把喜欢的歌留在这里。", Follows: 21, Followeds: 8}
	switch screen {
	case "profile":
		a.route = route{page: pageUser, id: listener.UserID}
		a.users[listener.UserID] = &userData{
			user:      &listener,
			playlists: []netease.Playlist{{ID: 42, Name: "海边的晚风", TrackCount: 23}},
			connections: [2]connectionPage{
				{loaded: true, rows: []netease.User{{UserID: 30, Nickname: "山间回声"}}},
				{loaded: true, rows: []netease.User{{UserID: 40, Nickname: "夜航日记"}}},
			},
		}
	case "inbox":
		a.messages.open = true
		a.messages.counts = [4]int{2}
		for i := range a.messages.pages {
			a.messages.pages[i] = messagePage{loaded: true, rows: []netease.Message{
				{ID: 1, Peer: listener.UserID, Author: listener, Text: "分享一首适合在雨天听的歌。", Unread: 2},
			}}
		}
	case "comments":
		a = playlistDetailFixture()
		a.profile = &netease.Profile{UserID: 10, Nickname: "星屿"}
		row := netease.Comment{ID: 8, Content: "总会想起回家路上的这一段。", LikedCount: 12}
		row.User.ID, row.User.Nickname = listener.UserID, listener.Nickname
		a.collectionSocial = collectionSocialState{
			open: true, loaded: true, playlist: 42, thread: "A_PL_0_42", title: "海边的晚风",
			latest: []netease.Comment{row}, pending: make(map[int64]bool),
			collectors: connectionPage{loaded: true, rows: []netease.User{listener}},
		}
	case "records":
		a.nowPlaying = true
		tracks := []netease.Track{
			{ID: -1, Name: "雨后", Duration: 195000, LocalPath: filepath.Join(t.TempDir(), "one.mp3")},
			{ID: -2, Name: "海边的晚风", Duration: 220000, LocalPath: filepath.Join(t.TempDir(), "two.mp3")},
			{ID: -3, Name: "走进夜色", Duration: 188000, LocalPath: filepath.Join(t.TempDir(), "three.mp3")},
		}
		a.pl.Restore(player.Session{Queue: tracks, Order: []int{0, 1, 2}, At: 1})
		a.pl.SetLyrics(nil)
	case "folders":
		a.route = route{page: pageLocalLibrary}
		a.localLibrary = localLibraryState{loaded: true, roots: []musicRoot{
			{Path: filepath.Join(t.TempDir(), "音乐收藏"), Tracks: []netease.Track{{ID: -4, Name: "夏末", Duration: 190000}}},
		}}
	}
	return a
}

// The new controls reach the intended content and keep the source music intact.
func TestRhineM6Controls(t *testing.T) {
	for _, screen := range []string{"profile", "inbox", "comments", "records", "folders"} {
		t.Run(screen, func(t *testing.T) {
			a := rhineM6Fixture(t, screen)
			tt := ui.NewTester(a.view, 1280, 900)
			tt.Frame()
			tt.Advance(time.Second)
			tt.Frame()
			click := func(label string) {
				t.Helper()
				if err := tt.Click(label); err != nil {
					t.Fatal(err)
				}
				tt.Frame()
			}
			switch screen {
			case "profile":
				click("粉丝")
				if a.users[20].tab != 2 {
					t.Fatal("followers tab did not open")
				}
			case "inbox":
				click("@我")
				if a.messages.tab != 2 {
					t.Fatal("mentions tab did not open")
				}
				tt.Key(0, ui.KeyEscape)
				tt.Frame()
				if a.messages.open {
					t.Fatal("Escape did not close the inbox")
				}
			case "comments":
				click("回复")
				if a.collectionSocial.reply != 8 {
					t.Fatal("reply did not select the comment")
				}
			case "records":
				click("下一张唱片：走进夜色")
				if a.pl.Current().ID != -3 {
					t.Fatal("the next sleeve did not select its track")
				}
			case "folders":
				click("打开 音乐收藏")
				if a.selectedLocalRoot() == nil {
					t.Fatal("folder did not open")
				}
				click("返回文件夹")
				dir := t.TempDir()
				original := filepath.Join(dir, "sample.mp3")
				if err := os.WriteFile(original, []byte("fixture"), 0600); err != nil {
					t.Fatal(err)
				}
				old := localLibraryPath
				t.Cleanup(func() { localLibraryPath = old })
				localLibraryPath = func() (string, error) { return filepath.Join(dir, "index.json"), nil }
				if !a.commitLocalLibrary([]musicRoot{{Path: dir}}) {
					t.Fatal(a.localLibrary.status)
				}
				a.removeLocalFolder(dir)
				if len(a.localLibrary.roots) != 0 {
					t.Fatal(a.localLibrary.status)
				}
				b, err := os.ReadFile(original)
				if err != nil || string(b) != "fixture" {
					t.Fatalf("source music changed: %q, %v", b, err)
				}
			}
		})
	}
}

// The fixture frames can be exported without opening a Windows application window.
func TestRhineM6Frames(t *testing.T) {
	dir := os.Getenv("NM_FRAMES")
	if dir == "" {
		t.Skip("set NM_FRAMES to a directory to save frames")
	}
	for _, screen := range []string{"profile", "inbox", "comments", "records", "folders", "folder-tracks"} {
		t.Run(screen, func(t *testing.T) {
			fixture := screen
			if screen == "folder-tracks" {
				fixture = "folders"
			}
			a := rhineM6Fixture(t, fixture)
			if screen == "folder-tracks" {
				a.selectLocalRoot(a.localLibrary.roots[0].Path)
			}
			tt := ui.NewTester(a.view, 1280, 900)
			tt.SetDark(false)
			tt.Frame()
			tt.Advance(time.Second)
			tt.Frame()
			f, err := os.Create(filepath.Join(dir, screen+".png"))
			if err != nil {
				t.Fatal(err)
			}
			err = png.Encode(f, tt.Image())
			closeErr := f.Close()
			if err != nil {
				t.Fatal(err)
			}
			if closeErr != nil {
				t.Fatal(closeErr)
			}
		})
	}
}
