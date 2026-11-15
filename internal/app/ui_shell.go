package app

import (
	"fmt"
	"strings"

	"github.com/egoist/mygo/ui"
)

// The header and player have separate width responses in RhineTheme.qml.
func headerScale(width float32) float32 {
	if width < 1280 {
		return max(0.85, width/1280)
	}
	return 1 + min(0.24, (width-1280)/2400)
}

func playerIslandScale(width float32) float32 {
	if width < 1280 {
		return max(0.85, width/1280)
	}
	return 1 + min(0.06, (width-1280)/4000)
}

func (a *app) shellHeader(c *ui.Context, height float32) {
	width, _ := c.Size()
	u := headerScale(width)
	chrome := c.TitleBar()
	padding := 40 * playerIslandScale(width)
	accent := ui.RGB(255, 106, 61)
	ink := ui.RGB(26, 27, 34)
	if a.route.page != pageHome {
		left := max(6*u, chrome.Left)
		ui.Box(c.Key("rhine-return")).Absolute().Top(0).Left(left).Height(height).Center().Children(func() {
			label := "返回首页"
			toSearch := len(a.history) > 0 && a.history[len(a.history)-1].page == pageSearch
			if toSearch {
				label = "返回搜索"
			}
			if iconButton(c.Key("return"), iconBack, 17*u, a.pal.text, label).Size(30*u, 34*u).Clicked() {
				if toSearch {
					a.back()
				} else {
					a.open(route{page: pageHome})
				}
			}
		})
	}
	ui.Row(c.Key("rhine-header")).Absolute().Left(max(padding, chrome.Left)).Right(max(padding, chrome.Right)).
		Top(0).Height(height).AlignItems(ui.Center).Gap(24 * u).Children(func() {
		mark := ui.ButtonBase(c.Key("brand")).Label("Rhine 首页").Gap(0).AlignItems(ui.Center)
		mark.Children(func() {
			ui.Text(c, "rhine").FontSize(22 * u).FontWeight(900).TextColor(a.pal.text)
			ui.Text(c, ".").FontSize(22 * u).FontWeight(900).TextColor(accent)
		})
		if mark.Clicked() {
			if a.route.page == pageSearch {
				a.back()
			} else {
				a.open(route{page: pageHome})
			}
		}
		ui.Row(c.Key("rhine-nav")).Padding(3 * u).Radius(22 * u).Background(a.pal.hover.Over(a.pal.bg)).
			AlignItems(ui.Center).Children(func() {
			mine := a.profile != nil && a.route.page == pageUser && a.route.id == a.profile.UserID
			tabs := []struct {
				label    string
				selected bool
				open     func()
			}{
				{"推荐", a.route.page == pageHome, func() { a.open(route{page: pageHome}) }},
				{"FM", strings.HasPrefix(a.pl.Radio(), "fm:"), func() {
					if a.profile == nil {
						a.openLogin()
						return
					}
					a.playFM()
				}},
				{"排行榜", a.route.page == pageCharts, func() { a.open(route{page: pageCharts}) }},
				{"播客", a.route.page == pagePodcasts || a.route.page == pagePodcast, func() { a.open(route{page: pagePodcasts}) }},
				{"我的", mine, func() {
					if a.profile == nil {
						a.openLogin()
						return
					}
					a.open(route{page: pageUser, id: a.profile.UserID})
				}},
			}
			for _, tab := range tabs {
				button := ui.ButtonBase(c.Key(tab.label)).Label(tab.label).Height(30 * u).PaddingX(14 * u).
					Radius(16 * u).AlignItems(ui.Center).Justify(ui.Center)
				color := a.pal.text
				if tab.selected {
					button.Background(ink)
					color = accent
				} else if button.Hovered() {
					button.Background(a.pal.press)
				}
				button.Children(func() {
					ui.Text(c, tab.label).FontSize(14 * u).FontWeight(550).TextColor(color).SingleLine()
				})
				if button.Clicked() {
					a.accountOpen = false
					tab.open()
				}
			}
		})
		ui.Box(c).Grow(1).MinWidth(0)
		searchWidth := min(320*u, 260*u+max(0, width-1280)*0.08)
		ui.Box(c).Width(searchWidth).Shrink(1).MinWidth(100).Children(func() {
			a.searchField(c)
		})
		if iconButton(c.Key("rhine-settings"), iconSettings, 19*u, a.pal.text, "设置").Clicked() {
			a.accountOpen = false
			a.openSettings()
		}
		a.shellAccount(c, 34*u)
	})
	if a.accountHover && !a.accountOpen {
		preview := ui.Column(c.Key("rhine-account-preview")).Absolute().Top(height - 13*u).
			Right(max(padding, chrome.Right)).Width(245).Padding(16).Gap(7).PassThrough()
		a.pane(preview, 20, false)
		preview.Children(func() { a.shellAccountIdentity(c) })
	}
}

func (a *app) shellAccount(c *ui.Context, size float32) {
	button := ui.ButtonBase(c.Key("rhine-account")).Size(size, size).Radius(size / 2).
		Center().Label("我的账号").Expanded(a.accountOpen)
	button.Children(func() {
		if a.profile != nil && a.profile.AvatarURL != "" {
			a.avatar(c, a.profile.AvatarURL, size, a.pal.press)
		} else {
			ui.Icon(c, iconUser).Size(18, 18).TextColor(a.pal.text)
		}
	})
	a.accountHover = button.Hovered() && !a.login.open
	if button.Clicked() {
		a.accountOpen = !a.accountOpen
	}
	a.shellAccountMenu(c, button)
}

func (a *app) shellAccountIdentity(c *ui.Context) {
	ui.Text(c, "RHINE / 个人音乐档案").FontSize(11).TextColor(a.pal.muted)
	ui.Text(c, a.profileName()).FontSize(17).FontWeight(650).SingleLine()
	if a.profile != nil {
		if d := a.users[a.profile.UserID]; d != nil && d.user != nil {
			ui.Text(c, fmt.Sprintf("%d 关注  ·  %d 粉丝", d.user.Follows, d.user.Followeds)).
				FontSize(11).TextColor(a.pal.muted)
		}
	}
}

func (a *app) shellAccountMenu(c *ui.Context, anchor ui.Element) {
	ui.PopoverBase(c.Key("rhine-account-menu"), anchor, &a.accountOpen, func(panel ui.Element) {
		a.pane(panel, 20, false)
		panel.AttachTo(anchor, ui.AnchorBottomEnd, ui.AnchorTopEnd).Margin(8, 0, 0, 0).Width(268).
			Padding(8).Gap(3).Role(ui.RoleMenu).FocusGroup(ui.Vertical).Label("个人音乐档案")
		a.paneMotion(panel)
		ui.Column(c).Padding(8).Gap(4).Children(func() { a.shellAccountIdentity(c) })
		if a.profile == nil {
			if a.menuItem(c, iconUser, "登录网易云音乐", "").AutoFocus().Clicked() {
				a.accountOpen = false
				a.openLogin()
			}
			if a.menuItem(c, iconFolder, "导入本地音乐", "").Clicked() {
				a.accountOpen = false
				a.open(route{page: pageLocalLibrary})
			}
			if a.menuItem(c, iconDownload, "下载歌曲", "").Clicked() {
				a.accountOpen = false
				a.open(route{page: pageDownloads})
			}
			return
		}
		if a.menuItem(c, iconUser, "我的主页", "").AutoFocus().Clicked() {
			a.accountOpen = false
			a.open(route{page: pageUser, id: a.profile.UserID})
		}
		links := []struct {
			label string
			icon  *ui.SVG
			open  func()
		}{
			{"消息", iconComment, a.openMessages},
			{"播放历史", iconHistory, func() { a.open(route{page: pageRecent}) }},
			{"我喜欢的音乐", iconHeart, func() {
				if id := a.likedPlaylist(); id != 0 {
					a.open(route{page: pagePlaylist, id: id})
				} else {
					a.openMine(mineMade)
				}
			}},
			{"导入本地音乐", iconFolder, func() { a.open(route{page: pageLocalLibrary}) }},
			{"我的歌单与收藏", iconQueue, func() { a.openMine(mineMade) }},
			{"新建歌单", iconPlus, func() { a.newPlaylist(nil) }},
			{"下载歌曲", iconDownload, func() { a.open(route{page: pageDownloads}) }},
			{"退出登录", iconSignOut, a.signOut},
		}
		for _, link := range links {
			if a.menuItem(c, link.icon, link.label, "").Clicked() {
				a.accountOpen = false
				link.open()
			}
		}
	})
}
