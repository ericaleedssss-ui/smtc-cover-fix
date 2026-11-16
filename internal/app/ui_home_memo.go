// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"errors"
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
		err = registerHomeScoreFonts(dir)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
	}
}

func registerHomeScoreFonts(dir string) error {
	var fontErrors []error
	for _, name := range []string{"LongCang-Regular.ttf", "Caveat.ttf", "NotoMusic-Regular.ttf"} {
		data, err := os.ReadFile(filepath.Join(dir, "fonts", name))
		if os.IsNotExist(err) {
			// MyGo returns the executable directory for a standalone Windows build.
			data, err = os.ReadFile(filepath.Join(dir, "resources", "fonts", name))
		}
		if err == nil {
			err = ui.RegisterFont(data, "")
		}
		if err != nil {
			fontErrors = append(fontErrors, fmt.Errorf("score font %s: %w", name, err))
		}
	}
	return errors.Join(fontErrors...)
}
