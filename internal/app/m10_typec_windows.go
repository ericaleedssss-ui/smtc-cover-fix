//go:build windows && m10typec

package app

import (
	"log"

	"github.com/egoist/mygo"
)

func init() {
	shotHook = func(a *app) {
		for _, display := range mygo.Screen.Displays() {
			r := display.WorkArea
			if display.Primary || display.Label != `\\.\DISPLAY1` || r.Width < 900 || r.Height < 600 {
				continue
			}
			a.win.SetBounds(mygo.Rectangle{X: r.X + 20, Y: r.Y + 20, Width: min(1180, r.Width-40), Height: min(780, r.Height-40)})
			a.win.ShowInactive()
			return
		}
		log.Print("M10 Type-C display unavailable; keeping normal window placement")
	}
}
