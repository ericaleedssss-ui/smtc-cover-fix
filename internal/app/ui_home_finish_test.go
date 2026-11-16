package app

import (
	"github.com/egoist/mygo/ui"
	"os"
	"testing"
	"time"
)

// Reversing between settled sleeves must reveal the latest description and clear it on exit.
func TestHomeModeReverseReveal(t *testing.T) {
	a := homeFixture(t)
	paintHomeFixture(a)
	tt := ui.NewTester(a.view, 1280, 820)
	tt.Frame()
	for _, n := range []string{"私人推荐 1", "私人推荐 3", "私人推荐 2"} {
		r, ok := tt.Find(n)
		if !ok || r.W == 0 {
			t.Fatal("cover unavailable", n, r)
		}
		tt.Move(r.X+25, r.Y+25)
		for range 35 {
			tt.Advance(20 * time.Millisecond)
			tt.Frame()
		}
	}
	if a.homeSections.modeRevealed != "list:301" || !tt.HasText("留住此刻，听一组为你准备的音乐") {
		t.Fatal("latest description did not reveal")
	}
	if os.Getenv("NM_FRAMES") != "" {
		saveHomeAcceptance(t, "mode-reverse-description", tt.Image())
	}
	tt.Move(20, 30)
	tt.Frame()
	if a.homeSections.modeRevealed != "" {
		t.Fatal("pointer exit kept a sleeve active")
	}
}

// A keyboard-expanded recommendation must stay open away from the pointer and scroll its right edge into view.
func TestHomeModeKeyboardEdge(t *testing.T) {
	a := homeFixture(t)
	tt := ui.NewTester(a.view, 1280, 820)
	tt.Frame()
	tt.Move(20, 30)
	tt.Frame()
	for i := 0; i < 90 && !tt.Focused("私人推荐 16"); i++ {
		tt.Key(0, ui.KeyTab)
	}
	if !tt.Focused("私人推荐 16") {
		t.Fatal("last recommendation is unreachable by keyboard")
	}
	for range 40 {
		tt.Advance(20 * time.Millisecond)
		tt.Frame()
	}
	if a.homeSections.modeRevealed != "list:315" {
		t.Fatalf("keyboard sleeve collapsed: %q", a.homeSections.modeRevealed)
	}
	r, ok := tt.Find("私人推荐 16")
	if !ok || r.X < 40 || r.X+r.W > 935 {
		t.Fatalf("last sleeve is clipped: %+v, scroll %.2f/%.2f", r, a.homeSections.modeScroll.X, a.homeSections.modeScroll.MaxX)
	}
	tt.Key(0, ui.KeyTab)
	if !tt.Focused("播放 私人推荐 16") {
		t.Fatal("play control is unreachable")
	}
	for range 25 {
		tt.Advance(20 * time.Millisecond)
		tt.Frame()
	}
	if a.homeSections.modeRevealed != "list:315" {
		t.Fatal("focusing play collapsed its sleeve")
	}
}
