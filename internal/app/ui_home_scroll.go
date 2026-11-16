// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"runtime"
	"time"

	"github.com/egoist/mygo/ui"
)

// MyGo uses a spring for a zero-duration animation. Settle direct input on the next frame.
var homeScrollSnap = ui.Animation{Duration: time.Nanosecond, Ease: ui.Linear}

type homeEdgeState struct {
	until       time.Time
	destination float32
	wheeling    bool
	dragging    bool
	grab        float32
	shown       bool
}

// MyGo reports discrete wheel input in native line units converted to DIPs.
var homeWindowsNotch = func() float32 { return 99 }

func homeNotchDIPs() float32 {
	switch runtime.GOOS {
	case "windows":
		return homeWindowsNotch()
	case "darwin":
		return 40
	default:
		return 50
	}
}

func (a *app) homeWheel(ev ui.InputEvent, u float32, reduceMotion bool) bool {
	if ev.Kind != ui.InputScroll || ev.DY == 0 || ev.Mods&(ui.Shift|ui.Ctrl) != 0 {
		return false
	}
	s, edge := &a.pageScroll, &a.homeEdge
	edge.until = ev.Time.Add(700 * time.Millisecond)
	if ev.Precise {
		edge.wheeling = false
		return false
	}
	base := s.Y
	if edge.wheeling && s.Scrolling() {
		base = edge.destination
	}
	// Rhine: only a discrete wheel uses HomePageB's 76u step.
	edge.destination = min(s.MaxY, max(0, base+ev.DY/homeNotchDIPs()*76*u))
	edge.wheeling = true
	animation := homeScrollSnap
	if !reduceMotion && a.motion != motionOff {
		animation = ui.Animation{Duration: 150 * time.Millisecond, Ease: ui.EaseOut}
	}
	s.ScrollTo(s.X, edge.destination, animation)
	return true
}

func (a *app) homeScrollbar(c *ui.Context, top, u float32) {
	scroll, edge := &a.pageScroll, &a.homeEdge
	if scroll.MaxY <= 0 {
		edge.shown, edge.dragging = false, false
		return
	}
	bar := ui.Box(c).Absolute().Top(top).Bottom(12 * u).Right(0).Width(14 * u).
		Focusable().FocusRing(false).Role(ui.RoleScroll).Label("首页滚动条").Cursor(ui.CursorPointer)
	track := bar.Bounds().H
	_, viewport := c.Size()
	if track <= 0 {
		track = max(1, viewport-top-12*u)
	}
	thumb := min(track, max(44*u, track*viewport/(viewport+scroll.MaxY)))
	travel := max(1, track-thumb)
	offset := scroll.Y / scroll.MaxY * travel
	reduceMotion := c.Preferences().ReduceMotion
	bar.HandleInput(func(ev ui.InputEvent) bool {
		seek := func(y float32) {
			c.Invalidate()
			edge.wheeling = false
			edge.until = ev.Time.Add(700 * time.Millisecond)
			scroll.ScrollTo(scroll.X, min(scroll.MaxY, max(0, y/travel*scroll.MaxY)), homeScrollSnap)
		}
		switch ev.Kind {
		case ui.InputPointerDown:
			if ev.Button != 0 {
				return false
			}
			edge.dragging = true
			edge.grab = thumb / 2
			if ev.Y >= offset && ev.Y <= offset+thumb {
				edge.grab = ev.Y - offset
			}
			seek(ev.Y - edge.grab)
			return true
		case ui.InputPointerMove:
			if edge.dragging {
				seek(ev.Y - edge.grab)
				return true
			}
		case ui.InputPointerUp:
			if edge.dragging && ev.Button == 0 {
				edge.dragging = false
				edge.until = ev.Time.Add(700 * time.Millisecond)
				return true
			}
		case ui.InputKeyDown:
			destination := scroll.Y
			switch ev.Key {
			case ui.KeyUp:
				destination -= 60 * u
			case ui.KeyDown:
				destination += 60 * u
			case ui.KeyPageUp:
				destination -= viewport * .85
			case ui.KeyPageDown:
				destination += viewport * .85
			case ui.KeyHome:
				destination = 0
			case ui.KeyEnd:
				destination = scroll.MaxY
			default:
				return false
			}
			seek(destination / scroll.MaxY * travel)
			return true
		case ui.InputScroll:
			if a.homeWheel(ev, u, reduceMotion) {
				return true
			}
			if ev.Precise && ev.DY != 0 && ev.Mods&(ui.Shift|ui.Ctrl) == 0 {
				seek((scroll.Y + ev.DY) / scroll.MaxY * travel)
				return true
			}
		}
		return false
	})
	now := c.Now()
	awake := now.Before(edge.until)
	if awake {
		c.After(edge.until.Sub(now))
	}
	edge.shown = awake || bar.Hovered() || bar.FocusVisible() || edge.dragging
	alpha := b2f(edge.shown)
	slide := alpha
	if a.motion != motionOff && !c.Preferences().ReduceMotion {
		alpha = bar.AnimateTo("alpha", alpha, ui.Animation{Duration: 240 * time.Millisecond})
		slide = bar.AnimateTo("slide", slide, ui.Animation{Duration: 240 * time.Millisecond, Ease: ui.EaseOut})
	}
	ink := ui.Hex("#71737F").Alpha(.48)
	if edge.dragging {
		ink = ui.Hex("#71737F").Alpha(.8)
		bar.Cursor(ui.CursorGrabbing)
	}
	bar.Children(func() {
		ui.Box(c).Absolute().Top(offset).Right((-12+14*slide)*u).Size(4*u, thumb).
			Radius(2 * u).Background(ink).Opacity(alpha).PassThrough()
	})
}
