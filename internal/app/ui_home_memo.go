// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"
)

// Rhine: keep the HomePageB content and header width curves independent.
func homeMeasures(c *ui.Context) (cols int, content, header float32) {
	width, _ := c.Size()
	content = max(.85, width/1280)
	if width >= 1280 {
		content = 1 + min(.12, (width-1280)/4000)
	}
	inner := width - 80*content
	minWidth := min(208, 168+max(0, width-1280)/12)
	columns := max(2, int((inner+20*content)/((minWidth+20)*content)))
	return columns, content, headerScale(width)
}

func loadHomeScoreFont() {
	dir, err := mygo.App.Path(mygo.PathResources)
	if err == nil {
		for _, name := range []string{"LongCang-Regular.ttf", "Caveat.ttf", "NotoMusic-Regular.ttf"} {
			if b, err := os.ReadFile(filepath.Join(dir, "fonts", name)); err == nil {
				if err := ui.RegisterFont(b, ""); err != nil {
					fmt.Fprintf(os.Stderr, "score font %s: %v\n", name, err)
				}
			} else {
				fmt.Fprintf(os.Stderr, "score font %s: %v\n", name, err)
			}
		}
	}
}
