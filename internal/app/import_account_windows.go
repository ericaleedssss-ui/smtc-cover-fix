// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"encoding/json"
	"os"
	"unsafe"

	"golang.org/x/sys/windows"

	"netease-music-mygo/internal/netease"
)

func importLegacyAccount(path string) error {
	encrypted, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if len(encrypted) == 0 || len(encrypted) > 1<<20 {
		return os.ErrInvalid
	}
	input := windows.DataBlob{Size: uint32(len(encrypted)), Data: &encrypted[0]}
	var output windows.DataBlob
	if err := windows.CryptUnprotectData(&input, nil, nil, 0, nil, windows.CRYPTPROTECT_UI_FORBIDDEN, &output); err != nil {
		return err
	}
	plain := unsafe.Slice(output.Data, output.Size)
	defer func() {
		clear(plain)
		windows.LocalFree(windows.Handle(uintptr(unsafe.Pointer(output.Data))))
	}()
	var cookies map[string]json.RawMessage
	if err := json.Unmarshal(plain, &cookies); err != nil {
		return err
	}
	var login, csrf string
	if err := json.Unmarshal(cookies["MUSIC_U"], &login); err != nil {
		return err
	}
	if token, ok := cookies["__csrf"]; ok {
		if err := json.Unmarshal(token, &csrf); err != nil {
			return err
		}
	}
	return netease.ImportSession(login, csrf)
}
