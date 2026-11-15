package app

import (
	"fmt"
	"image/png"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/egoist/mygo/ui"

	"netease-music-mygo/internal/netease"
)

func TestRhineShellLayout(t *testing.T) {
	for _, width := range []int{960, 1280, 1920} {
		t.Run(fmt.Sprint(width), func(t *testing.T) {
			a := newTestApp()
			a.settings = defaultSettings()
			a.homeLoading = false
			tt := ui.NewTester(a.view, width, 720)
			tt.Frame()
			tt.Advance(2 * time.Second)
			tt.Frame()
			for _, label := range []string{"推荐", "FM", "排行榜", "播客", "我的", "搜索", "设置", "我的账号", "待播", "桌面歌词", "音量"} {
				r, ok := tt.Find(label)
				if !ok || r.W == 0 || r.X < 0 || r.X+r.W > float32(width) {
					t.Errorf("%q is outside the shell: %+v", label, r)
				}
			}
			if _, ok := tt.Find("下载歌曲"); ok {
				t.Fatal("downloads is still a primary navigation entry")
			}
			for range 15 {
				tt.Advance(time.Second)
				if tt.FramePending() {
					t.Fatal("idle shell requested a frame")
				}
			}
		})
	}
}

func TestRhineShellEntries(t *testing.T) {
	a := homeFixture(t)
	a.profile = &netease.Profile{UserID: 1, Nickname: "Rhine"}
	tt := ui.NewTester(a.view, 1280, 720)
	tt.Frame()
	r, ok := tt.Find("我的账号")
	if !ok {
		t.Fatal("account control is missing")
	}
	tt.Move(r.X+r.W/2, r.Y+r.H/2)
	tt.Frame()
	if !a.accountHover || !tt.HasText("RHINE / 个人音乐档案") {
		t.Fatal("account hover preview did not open")
	}
	click := func(label string) {
		t.Helper()
		if err := tt.Click(label); err != nil {
			t.Fatal(err)
		}
		tt.Frame()
		tt.Advance(time.Second)
		tt.Frame()
	}
	click("我的账号")
	if !a.accountOpen {
		t.Fatal("account menu did not open")
	}
	tt.Key(0, ui.KeyEscape)
	tt.Frame()
	if a.accountOpen || a.route.page != pageHome {
		t.Fatal("Escape did not close only the account menu")
	}
	click("待播")
	if !a.islandQueueOpen || a.nowPlaying {
		t.Fatal("queue did not open over the current page")
	}
	tt.Key(0, ui.KeyEscape)
	tt.Frame()
	if a.islandQueueOpen {
		t.Fatal("Escape did not close the queue")
	}
	click("我的")
	if a.route != (route{page: pageUser, id: 1}) {
		t.Fatalf("我的 did not open the listener's profile: %+v", a.route)
	}
	click("推荐")
	if a.route.page != pageHome {
		t.Fatal("推荐 did not return home")
	}
	click("设置")
	if !a.settingsOpen {
		t.Fatal("settings did not open")
	}
}

func TestRhineShellFrames(t *testing.T) {
	dir := os.Getenv("NM_FRAMES")
	if dir == "" {
		t.Skip("set NM_FRAMES to export offscreen shell images")
	}
	for _, width := range []int{960, 1280, 1920} {
		a := homeFixture(t)
		paintHomeFixture(a)
		tt := ui.NewTester(a.view, width, width*9/16)
		tt.SetDark(false)
		tt.Frame()
		tt.Advance(time.Second)
		tt.Frame()
		f, err := os.Create(filepath.Join(dir, fmt.Sprintf("go-%d.png", width)))
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
	}
}
