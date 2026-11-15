package app

import (
	"fmt"
	"image/png"
	"os"
	"path/filepath"
	"runtime"
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

func TestRhineShellCaptionReveal(t *testing.T) {
	if runtime.GOOS != "windows" {
		t.Skip("custom caption is only enabled on Windows")
	}
	a := homeFixture(t)
	tt := ui.NewTester(a.view, 1280, 720)
	tt.Frame()
	avatar, ok := tt.Find("我的账号")
	if !ok {
		t.Fatal("account button is missing")
	}
	if _, ok := tt.Find("最大化"); ok {
		t.Fatal("caption controls are visible before hover")
	}
	tt.Move(avatar.X+avatar.W/2, avatar.Y+avatar.H/2)
	tt.Frame()
	tt.Advance(310 * time.Millisecond)
	tt.Frame()
	button, ok := tt.Find("最大化")
	if !ok || button.W == 0 {
		t.Fatal("hovering the avatar did not reveal the window controls")
	}
	tt.Move(button.X+button.W/2, button.Y+button.H/2)
	tt.Frame()
	if dir := os.Getenv("NM_FRAMES"); dir != "" {
		f, err := os.Create(filepath.Join(dir, "caption-hover.png"))
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
	tt.Advance(time.Second)
	tt.Frame()
	if !a.accountPanel.captionOpen {
		t.Fatal("caption closed while moving from the avatar to the controls")
	}
	tt.Move(20, 120)
	tt.Frame()
	tt.Advance(290 * time.Millisecond)
	tt.Frame()
	if !a.accountPanel.captionOpen {
		t.Fatal("caption closed before its exit delay")
	}
	tt.Advance(340 * time.Millisecond)
	tt.Frame()
	tt.Advance(310 * time.Millisecond)
	tt.Frame()
	if _, ok := tt.Find("最大化"); ok {
		t.Fatal("caption controls are visible after leaving")
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
	if a.accountOpen {
		t.Fatal("preview opened before the hover delay")
	}
	if runtime.GOOS == "windows" {
		// The caption opens from the right and moves the avatar to the left.
		tt.Advance(310 * time.Millisecond)
		tt.Frame()
		r, _ = tt.Find("我的账号")
		tt.Move(r.X+r.W/2, r.Y+r.H/2)
		tt.Frame()
	}
	tt.Advance(270 * time.Millisecond)
	tt.Frame()
	if !a.accountOpen || a.accountPanel.pinned || !tt.HasText("RHINE / 个人音乐档案") {
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
	if !a.accountOpen || !a.accountPanel.pinned {
		t.Fatal("account menu did not open")
	}
	tt.Key(0, ui.KeyEscape)
	tt.Frame()
	if a.accountOpen || a.route.page != pageHome {
		t.Fatal("Escape did not close only the account menu")
	}
	click("我的账号")
	click("设置")
	if a.accountOpen || a.settingsOpen {
		t.Fatal("the first click outside the pinned account menu must only dismiss it")
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
