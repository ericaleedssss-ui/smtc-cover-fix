// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"
	"netease-music-mygo/internal/local"
	"netease-music-mygo/internal/netease"
)

type musicRoot struct {
	Path   string
	Tracks []netease.Track
}

type localLibraryState struct {
	roots      []musicRoot
	loaded     bool
	selected   string
	generation int
	cancel     context.CancelFunc
	status     string
}

var localLibraryPath = func() (string, error) {
	dir, err := mygo.App.Path(mygo.PathUserData)
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "local-library.json"), nil
}

func (a *app) loadLocalLibrary() {
	lib := &a.localLibrary
	if lib.loaded {
		return
	}
	lib.loaded = true
	path, err := localLibraryPath()
	if err != nil {
		return
	}
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return
	}
	var roots []musicRoot
	if err != nil || json.Unmarshal(b, &roots) != nil {
		lib.status = "无法读取本地音乐索引"
		return
	}
	lib.roots = roots
}

func saveLocalLibrary(path string, roots []musicRoot) error {
	f, err := os.CreateTemp(filepath.Dir(path), ".local-library-")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	err = json.NewEncoder(f).Encode(roots)
	closeErr := f.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	return os.Rename(f.Name(), path)
}

func (a *app) commitLocalLibrary(roots []musicRoot) bool {
	lib := &a.localLibrary
	path, err := localLibraryPath()
	if err == nil {
		err = saveLocalLibrary(path, roots)
	}
	if err != nil {
		lib.status = "无法保存本地索引，已保留原索引"
		return false
	}
	lib.roots = roots
	return true
}

func (a *app) pickLocalFolder() {
	go func() {
		dir, err := chooseDownloadFolder(a.win, "")
		if err != nil || dir == "" {
			return
		}
		a.post(func() { a.addLocalFolder(dir) })
	}()
}

func (a *app) addLocalFolder(dir string) {
	lib := &a.localLibrary
	if lib.cancel != nil {
		return
	}
	abs, err := filepath.Abs(dir)
	if err != nil || folderRoot(abs) {
		lib.status = "请选择具体音乐文件夹"
		return
	}
	if slices.ContainsFunc(lib.roots, func(r musicRoot) bool { return downloadPathKey(r.Path) == downloadPathKey(abs) }) {
		lib.status = "这个文件夹已经在资料库中"
		return
	}
	a.scanLocalLibrary(append(slices.Clone(lib.roots), musicRoot{Path: abs}))
}

func (a *app) stopLocalScan() {
	lib := &a.localLibrary
	if lib.cancel == nil {
		return
	}
	lib.cancel()
	lib.cancel = nil
	lib.generation++
	lib.status = "扫描已取消，保留原索引"
}

func (a *app) scanLocalLibrary(roots []musicRoot) {
	lib := &a.localLibrary
	if lib.cancel != nil || len(roots) == 0 {
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	lib.cancel = cancel
	lib.generation++
	gen := lib.generation
	lib.status = "正在读取本地音乐…"
	next := slices.Clone(roots)
	artDir := a.downloadArtDir
	go func() {
		defer cancel()
		failures := 0
		// Track conversion uses the existing local artwork cache and
		// tag conversion without sharing mutable view state.
		converter := app{downloadArtDir: artDir}
		for i := range next {
			songs, err := local.ScanContext(ctx, next[i].Path)
			if ctx.Err() != nil {
				return
			}
			if err != nil {
				failures++
				continue
			}
			tracks := make([]netease.Track, 0, len(songs))
			for _, s := range songs {
				if ctx.Err() != nil {
					return
				}
				tr := converter.downloadFileTrack(s)
				tr.ID = downloadFileID(tr.LocalPath)
				tracks = append(tracks, tr)
			}
			next[i].Tracks = tracks
		}
		a.post(func() {
			if gen != lib.generation {
				return
			}
			lib.cancel = nil
			if a.commitLocalLibrary(next) {
				lib.status = "扫描完成"
				if failures > 0 {
					lib.status = fmt.Sprintf("%d 个文件夹无法读取，已保留原索引", failures)
				}
			}
		})
	}()
}

func (a *app) removeLocalFolder(path string) {
	lib := &a.localLibrary
	if lib.cancel != nil {
		return
	}
	roots := slices.DeleteFunc(slices.Clone(lib.roots), func(r musicRoot) bool { return r.Path == path })
	if a.commitLocalLibrary(roots) {
		if lib.selected == path {
			lib.selected = ""
		}
		lib.status = "已移除文件夹索引"
	}
}

func (a *app) selectedLocalRoot() *musicRoot {
	lib := &a.localLibrary
	for i := range lib.roots {
		if lib.roots[i].Path == lib.selected {
			return &lib.roots[i]
		}
	}
	return nil
}

// Rhine: folders open a track list sourced from the existing local tag
// reader; removing a folder only drops it from the local index.
func (a *app) localLibraryPage(c *ui.Context) {
	lib, p := &a.localLibrary, a.pal
	if root := a.selectedLocalRoot(); root != nil {
		a.toolRows(c, root.Tracks, true, func(c *ui.Context) {
			a.heading(c, filepath.Base(root.Path), "本地音乐")
			ui.Row(c).Gap(10).Margin(0, 0, 16, 0).Children(func() {
				if ui.Button(c.Key("back"), "返回文件夹").Clicked() {
					lib.selected = ""
				}
				if pillButton(c.Key("play"), iconPlay, "播放文件夹", p.accent, p.onAccent).Disabled(len(root.Tracks) == 0).Clicked() {
					a.playList(root.Tracks, false)
				}
				if ui.Button(c.Key("original"), "打开文件夹").Clicked() {
					a.revealLocalFolder(root.Path)
				}
			})
		})
		return
	}
	a.scrollPage(c, func() {
		a.heading(c, "本地音乐", "文件夹")
		ui.Row(c).Gap(10).AlignItems(ui.Center).Children(func() {
			if pillButton(c.Key("add"), iconFolder, "添加文件夹", p.accent, p.onAccent).Disabled(lib.cancel != nil).Clicked() {
				a.pickLocalFolder()
			}
			if lib.cancel != nil {
				if ui.Button(c.Key("cancel"), "取消扫描").Clicked() {
					a.stopLocalScan()
				}
			} else if len(lib.roots) > 0 && ui.Button(c.Key("refresh"), "重新扫描").Clicked() {
				a.scanLocalLibrary(lib.roots)
			}
			if lib.status != "" {
				ui.Text(c, lib.status).FontSize(13).TextColor(p.muted)
			}
		})
		if len(lib.roots) == 0 {
			a.empty(c, "添加文件夹后可播放其中的音乐")
			return
		}
		ui.Grid(c).Columns(min(4, a.columns(c, 240))).Gap(14).Margin(24, 0, 0, 0).Children(func() {
			for _, root := range lib.roots {
				a.localFolderCard(c.Key(root.Path), root)
			}
		})
	})
}

func (a *app) selectLocalRoot(path string) {
	a.localLibrary.selected = path
	a.trackList, a.pageScroll = ui.ListState{}, ui.ScrollState{}
	a.plView = plView{}
}

func (a *app) revealLocalFolder(path string) {
	if err := mygo.Shell.OpenPath(path); err != nil {
		a.toast = "无法打开文件夹"
	}
}

func (a *app) localFolderCard(c *ui.Context, root musicRoot) {
	p := a.pal
	card := ui.ButtonBase(c).Column().Height(164).Padding(12).Gap(8).Radius(14).AlignItems(ui.Stretch).
		Justify(ui.Start).Background(p.hover).Label("打开 " + filepath.Base(root.Path))
	if card.Hovered() {
		card.Background(p.press)
	}
	a.contextMenu(card, false, func() [][]menuAction {
		return [][]menuAction{{
			{label: "打开文件夹", do: func() { a.revealLocalFolder(root.Path) }},
			{label: "移除索引", do: func() { a.removeLocalFolder(root.Path) }},
		}}
	}, nil)
	card.Children(func() {
		ui.Row(c).Gap(8).AlignItems(ui.Center).Children(func() {
			ui.Icon(c, iconFolder).Size(24, 24).TextColor(p.accent)
			ui.Text(c, filepath.Base(root.Path)).FontSize(15).FontWeight(650).Grow(1).MinWidth(0).SingleLine()
		})
		ui.Textf(c, "%d 首", len(root.Tracks)).FontSize(12).TextColor(p.muted)
		for _, track := range root.Tracks[:min(3, len(root.Tracks))] {
			ui.Text(c, strings.TrimSpace(track.Name)).FontSize(12).SingleLine().TextColor(p.muted)
		}
	})
	if card.Clicked() {
		a.selectLocalRoot(root.Path)
	}
}
