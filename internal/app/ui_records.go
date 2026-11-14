// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"time"

	"github.com/egoist/mygo/ui"
	"netease-music-mygo/internal/netease"
)

// This is the shaft, pivot and cartridge geometry of RecordTonearm.qml.
var recordArm = ui.MustParseSVG([]byte(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 250">
<path d="M89 36C89 87 83 131 68 166C61 183 52 196 47 209" fill="none" stroke="#161519" stroke-opacity=".38" stroke-width="17" stroke-linecap="round"/>
<path d="M86 31C86 82 80 126 65 161C58 178 49 191 44 204" fill="none" stroke="#a8a69c" stroke-width="12" stroke-linecap="round"/>
<path d="M86 31C86 82 80 126 65 161C58 178 49 191 44 204" fill="none" stroke="#e9e7dd" stroke-width="8" stroke-linecap="round"/>
<circle cx="86" cy="22" r="20" fill="#aaa89e"/>
<circle cx="86" cy="21" r="17" fill="#e9e7dd"/>
<circle cx="86" cy="21" r="5" fill="#b7b5ab"/>
<g transform="translate(44 211) rotate(22)"><rect x="-13" y="-22" width="26" height="44" rx="5" fill="#e3dfd4" stroke="#b6b1a7"/><path d="M-8 -12H8M-8 11H8" stroke="#bab6ac" stroke-width="2"/><rect x="-2" y="20" width="4" height="7" rx="1" fill="#807d74"/></g>
</svg>`))

func (a *app) nowRecordStack(c *ui.Context, tr *netease.Track, art *artwork, size float32) {
	if size < 180 || tr.ProgramID != 0 {
		a.npCover(c, tr, art, size)
		return
	}
	order, at := a.pl.PlayOrder()
	queue := a.pl.Queue()
	ui.Box(c.Key("record-stack")).Size(size, size).AlignSelf(ui.Start).Children(func() {
		if at > 0 && at < len(order) {
			a.recordSleeve(c, queue, order[at-1], size, -1)
		}
		if next := a.pl.NextIndex(); at >= 0 && at < len(order) && next >= 0 && next != order[at] {
			a.recordSleeve(c, queue, next, size, 1)
		}
		a.npCover(c, tr, art, size)
		if a.npK > 0.99 {
			// A cached vector changes pose on pause and resume, with no
			// ongoing animation at either resting position.
			arm := ui.Box(c.Key("tonearm")).Absolute().Top(size*.08).Right(-size*.08).Size(size*.34, size*.71).
				PassThrough().TransformOrigin(.7167, .088)
			angle := float32(-12)
			if a.pl.Playing() && !a.pl.Loading() {
				angle = 0
			}
			if a.motion != motionOff {
				angle = arm.AnimateTo("angle", angle, ui.Animation{Duration: 280 * time.Millisecond})
			}
			arm.Rotate(angle).Children(func() { ui.Icon(c, recordArm).Size(size*.34, size*.71).PassThrough() })
		}
	})
}

func (a *app) recordSleeve(c *ui.Context, queue []netease.Track, index int, size, side float32) {
	if index < 0 || index >= len(queue) {
		return
	}
	tr := &queue[index]
	inset := size * .1
	label := "下一张唱片：" + tr.Name
	if side < 0 {
		label = "上一张唱片：" + tr.Name
	}
	// The visible edge gets its own hit target. The artwork itself never
	// intercepts a drag on the front sleeve.
	hit := ui.ButtonBase(c.Key(struct{ Edge float32 }{side})).Absolute().Top(size * .16).Height(size * .68).Width(inset).
		FocusRing(false).Label(label).Cursor(ui.CursorPointer)
	if side < 0 {
		hit.Left(-inset)
	} else {
		hit.Right(-inset)
	}
	sleeve := ui.Box(c.Key(struct{ Sleeve float32 }{side})).Absolute().Left(size*.09*side).Top(size*.06).Size(size*.94, size*.94).PassThrough().
		Radius(14).Background(ui.Hex("#716b65")).Shadow(0, 8, 22, -6, ui.RGBA(0, 0, 0, .5))
	lift := float32(0)
	if hit.Hovered() {
		lift = 1
	}
	if a.motion != motionOff {
		lift = sleeve.AnimateTo("fan", lift, ui.Snappy)
	}
	sleeve.Rotate(side*(5+4*lift)).Translate(side*size*.025*lift, -size*.04*lift)
	bmp := bitmap(a.art.get(netease.Sized(tr.Album.PicURL, 400), false))
	if in := artIn(sleeve, bmp); bmp != nil && in > 0 {
		sleeve.Children(func() {
			ui.Image(c, bmp).Absolute().Top(0).Left(0).Right(0).Bottom(0).
				Fit(ui.Cover).Radius(14).Opacity(in).PassThrough()
		})
	}
	if hit.Clicked() {
		a.pl.Jump(index)
	}
}
