// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"sync"
	"syscall"
	"unsafe"
)

func init() {
	homeWindowsNotch = sync.OnceValue(func() float32 {
		const getWheelScrollLines = 0x68
		var lines uint32
		proc := syscall.NewLazyDLL("user32.dll").NewProc("SystemParametersInfoW")
		ok, _, _ := proc.Call(getWheelScrollLines, 0, uintptr(unsafe.Pointer(&lines)), 0)
		if ok == 0 || lines == 0 || lines >= 100 {
			lines = 3
		}
		return float32(lines) * 33
	})
}
