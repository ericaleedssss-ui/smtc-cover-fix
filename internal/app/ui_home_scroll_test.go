// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"fmt"
	"math"
	"testing"
	"time"

	"github.com/egoist/mygo/ui"
)

func TestHomeWheelOneNotch(t *testing.T) {
	for _, size := range []struct {
		width, height int
		step          float32
	}{{960, 640, 64.60}, {1280, 800, 76}, {1600, 900, 82.08}, {1920, 1000, 85.12}, {2560, 1400, 85.12}} {
		t.Run(fmt.Sprint(size.width), func(t *testing.T) {
			a := homeFixture(t)
			tt := ui.NewTester(a.view, size.width, size.height)
			tt.Frame()
			x, y := float32(size.width)/2, float32(size.height)/2
			tt.Wheel(x, y, 0, homeNotchDIPs())
			tt.Advance(250 * time.Millisecond)
			if got := a.pageScroll.Y; math.Abs(float64(got-size.step)) > .15 {
				t.Fatalf("one notch moved %.2f DIP, want %.2f", got, size.step)
			}
			tt.Wheel(x, y, 0, 2*homeNotchDIPs())
			tt.Wheel(x, y, 0, -homeNotchDIPs())
			tt.Advance(250 * time.Millisecond)
			if got := a.pageScroll.Y; math.Abs(float64(got-2*size.step)) > .15 {
				t.Fatalf("combined notches reached %.2f DIP, want %.2f", got, 2*size.step)
			}
			tt.Scroll(x, y, 0, 17)
			if got := a.pageScroll.Y; math.Abs(float64(got-(2*size.step+17))) > .15 {
				t.Fatalf("precise scroll reached %.2f DIP, want %.2f", got, 2*size.step+17)
			}
		})
	}
}

func TestHomeEdgeVisibilityAndInput(t *testing.T) {
	a := homeFixture(t)
	tt := ui.NewTester(a.view, 1280, 800)
	tt.Frame()
	tt.Frame()
	if a.homeEdge.shown || a.pageScroll.MaxY <= 0 {
		t.Fatal("expected hidden thumb with scrollable content")
	}
	tt.Wheel(500, 420, 0, homeNotchDIPs())
	if !a.homeEdge.shown {
		t.Fatal("wheel did not reveal thumb")
	}
	tt.Advance(699 * time.Millisecond)
	if !a.homeEdge.shown {
		t.Fatal("thumb retired before 700 ms")
	}
	tt.Advance(2 * time.Millisecond)
	if a.homeEdge.shown {
		t.Fatal("thumb stayed awake after 700 ms")
	}
	tt.Move(1275, 445)
	if !a.homeEdge.shown {
		t.Fatal("edge hover did not reveal thumb")
	}
	tt.Press(1275, 445)
	tt.Advance(34 * time.Millisecond)
	mid := a.pageScroll.Y
	tt.Move(1260, 690)
	tt.Advance(34 * time.Millisecond)
	if !a.homeEdge.dragging || a.pageScroll.Y <= mid {
		t.Fatalf("edge drag did not move page: %.2f to %.2f", mid, a.pageScroll.Y)
	}
	tt.Release(1260, 690)
	if a.homeEdge.dragging {
		t.Fatal("edge drag did not release")
	}
	tt.Key(0, ui.KeyEnd)
	tt.Advance(34 * time.Millisecond)
	if a.pageScroll.Y != a.pageScroll.MaxY {
		t.Fatalf("End reached %.2f, want %.2f", a.pageScroll.Y, a.pageScroll.MaxY)
	}
	tt.Key(0, ui.KeyHome)
	tt.Advance(34 * time.Millisecond)
	if a.pageScroll.Y != 0 {
		t.Fatalf("Home reached %.2f, want 0, moving=%t", a.pageScroll.Y, a.pageScroll.Scrolling())
	}
}
