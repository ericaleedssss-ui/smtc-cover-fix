package app

import (
	"fmt"
	"runtime"
	"strings"
	"time"

	"github.com/egoist/mygo/plugins/glass"
	"github.com/egoist/mygo/ui"

	"netease-music-mygo/internal/netease"
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
	right := max(padding, chrome.Right)
	customCaption := runtime.GOOS == "windows"
	var caption ui.Element
	if customCaption {
		caption = ui.Box(c.Key("caption-hot-zone")).Absolute().Right(right-5*u).Top(0).
			Size(176*u, height+6*u).PassThrough()
	}
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
	ui.Row(c.Key("rhine-header")).Absolute().Left(max(padding, chrome.Left)).Right(right).
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
		spacer := ui.Box(c).Grow(1).MinWidth(0)
		if customCaption {
			spacer.Height(height).DragWindow()
		}
		searchWidth := min(320*u, 260*u+max(0, width-1280)*0.08)
		ui.Box(c).Width(searchWidth).Shrink(1).MinWidth(100).Children(func() {
			a.searchField(c)
		})
		if iconButton(c.Key("rhine-settings"), iconSettings, 19*u, a.pal.text, "设置").Clicked() {
			a.accountOpen = false
			a.openSettings()
		}
		ui.Row(c.Key("account-and-caption")).Shrink(0).AlignItems(ui.Center).Children(func() {
			avatar := a.shellAccount(c, 34*u)
			if customCaption {
				a.shellWindowControls(c, caption, avatar, u)
			}
		})
	})
}

func (a *app) shellAccount(c *ui.Context, size float32) ui.Element {
	button := ui.ButtonBase(c.Key("rhine-account")).Size(size, size).Radius(size / 2).
		Center().Background(a.pal.hover).Label("我的账号").Expanded(a.accountOpen)
	button.Children(func() {
		if a.profile != nil && a.profile.AvatarURL != "" {
			a.avatar(c, a.profile.AvatarURL, size, a.pal.press)
		} else {
			ui.Icon(c, iconUser).Size(18, 18).TextColor(a.pal.text)
		}
	})

	state := &a.accountPanel
	now := c.Now()
	hovered := button.Hovered() && !a.login.open && !a.settingsOpen && !a.messages.open
	if hovered != state.overAvatar {
		state.overAvatar = hovered
		state.revealAt = time.Time{}
		if hovered && !a.accountOpen {
			state.revealAt = now.Add(260 * time.Millisecond)
			c.After(260 * time.Millisecond)
		}
	}
	if button.Clicked() {
		state.revealAt = time.Time{}
		if state.pinned {
			a.accountOpen = false
		} else {
			a.accountOpen, state.pinned = true, true
		}
	}
	if hovered && !a.accountOpen && !state.revealAt.IsZero() && !now.Before(state.revealAt) {
		a.accountOpen = true
		state.revealAt = time.Time{}
	}
	if a.accountOpen && a.profile != nil && a.users[a.profile.UserID] == nil {
		a.loadUser(a.profile.UserID)
	}
	if a.accountOpen && a.profile != nil {
		a.loadAccountPanelDetails()
	}
	a.shellAccountMenu(c, button)
	if !a.accountOpen {
		state.pinned = false
		state.leaveAt = time.Time{}
	}
	return button
}

type shellAccountState struct {
	captionOpen, captionHeld      bool
	captionHideAt                 time.Time
	revealAt, leaveAt             time.Time
	overAvatar, pinned, switching bool
	detailsGen                    int
	detailsRequested              bool
	level                         netease.AccountLevel
	member                        netease.AccountMembership
}

func (a *app) shellWindowControls(c *ui.Context, hotZone, avatar ui.Element, u float32) {
	state := &a.accountPanel
	x, _, inside := hotZone.PointerPosition()
	inside = inside && (state.captionOpen || x >= 131*u)
	held := avatar.FocusVisible() || avatar.Pressed() || a.accountOpen || state.captionHeld
	now := c.Now()
	switch {
	case a.win != nil && !a.win.IsFocused():
		state.captionOpen = false
		state.captionHideAt = time.Time{}
	case inside || held:
		state.captionOpen = true
		state.captionHideAt = time.Time{}
	case state.captionOpen && state.captionHideAt.IsZero():
		state.captionHideAt = now.Add(300 * time.Millisecond)
		c.After(300 * time.Millisecond)
	case state.captionOpen && !now.Before(state.captionHideAt):
		state.captionOpen = false
	}
	target := float32(0)
	if state.captionOpen {
		target = 1
	}
	reveal := ui.Box(c.Key("caption-reveal")).Height(34 * u).Shrink(0).Clip()
	progress := target
	if a.motion != motionOff {
		progress = reveal.Animate("reveal", target, 300*time.Millisecond)
	}
	reveal.Width(131 * u * progress)
	state.captionHeld = false
	if !state.captionOpen && progress <= 0 {
		ui.Box(c.Key("caption-edge")).Absolute().Top(10*u).Right(-4*u).Size(3*u, 14*u).
			Radius(2 * u).Background(a.pal.muted.Alpha(.38)).PassThrough()
		return
	}
	reveal.Children(func() {
		ui.Row(c.Key("caption-buttons")).Absolute().Right(0).Width(123 * u).Height(34 * u).
			AlignItems(ui.Center).Gap(10 * u).Opacity(progress).Children(func() {
			ui.Box(c).Size(u, 16*u).Background(a.pal.muted.Alpha(.25))
			maxLabel, maxIcon := "最大化", iconWindowMaximize
			if a.win != nil && a.win.IsMaximized() {
				maxLabel, maxIcon = "还原", iconWindowRestore
			}
			for i, spec := range []struct {
				label string
				icon  *ui.SVG
			}{
				{"最小化", iconWindowMinimize}, {maxLabel, maxIcon}, {"关闭窗口", iconX},
			} {
				button := ui.ButtonBase(c.Key(i)).Label(spec.label).Size(30*u, 30*u).Center().
					Radius(15 * u).Disabled(!state.captionOpen || progress < .95)
				state.captionHeld = state.captionHeld || button.FocusVisible() || button.Pressed()
				color := a.pal.muted
				if button.Hovered() {
					button.Background(ui.RGBA(255, 255, 255, .75))
					color = ui.RGB(26, 27, 34)
					if i == 2 {
						button.Background(ui.RGB(255, 106, 61))
						color = white
					}
				}
				button.Children(func() {
					ui.Icon(c, spec.icon).Size(12*u, 12*u).TextColor(color)
				})
				if button.Clicked() && a.win != nil {
					switch i {
					case 0:
						a.win.Minimize()
					case 1:
						a.win.ToggleMaximize()
					case 2:
						a.win.Close()
					}
				}
			}
		})
	})
}

func (a *app) loadAccountPanelDetails() {
	state := &a.accountPanel
	if state.detailsGen != a.accountGen {
		state.detailsGen, state.detailsRequested = a.accountGen, false
		state.level, state.member = netease.AccountLevel{}, netease.AccountMembership{}
	}
	if state.detailsRequested || a.win == nil {
		return
	}
	state.detailsRequested = true
	gen, id := a.accountGen, a.profile.UserID
	go func() {
		level, err := netease.ReadAccountLevel()
		if err == nil {
			a.post(func() {
				if a.accountGen == gen {
					a.accountPanel.level = level
				}
			})
		}
	}()
	go func() {
		member, err := netease.ReadAccountMembership(id)
		if err == nil {
			a.post(func() {
				if a.accountGen == gen {
					a.accountPanel.member = member
				}
			})
		}
	}()
}

func (a *app) shellAccountMenu(c *ui.Context, avatar ui.Element) {
	state := &a.accountPanel
	width, height := c.Size()
	u := max(0.9, playerIslandScale(width))
	bounds := avatar.Bounds()
	reserved := c.TitleBar().Right
	if runtime.GOOS == "windows" && (state.captionOpen || state.pinned || a.accountOpen) {
		reserved = 131 * headerScale(width)
	}
	rightOffset := width - reserved - 14*u - bounds.X - bounds.W
	topOffset := 48*u - bounds.Y
	if a.accountOpen && state.pinned {
		ui.Overlay(c.Key("account-outside"), func() {
			// Consume a press outside the pinned menu while leaving its avatar
			// trigger available to close it.
			for i, r := range []ui.Rect{
				{W: width, H: bounds.Y},
				{Y: bounds.Y, W: bounds.X, H: bounds.H},
				{X: bounds.X + bounds.W, Y: bounds.Y, W: width - bounds.X - bounds.W, H: bounds.H},
				{Y: bounds.Y + bounds.H, W: width, H: height - bounds.Y - bounds.H},
			} {
				if r.W > 0 && r.H > 0 {
					ui.Box(c.Key(i)).Absolute().Left(r.X).Top(r.Y).Size(r.W, r.H).OnClick(func() {
						a.accountOpen = false
					})
				}
			}
		})
	}
	ui.PopoverBase(c.Key("rhine-account-menu"), avatar, &a.accountOpen, func(panel ui.Element) {
		a.pane(panel, 20, false)
		panel.AttachTo(avatar, ui.AnchorTopEnd, ui.AnchorTopEnd).Left(rightOffset).Top(topOffset).
			Width(min(380*u, width-32)).MaxHeight(max(150, height-120*u)).
			Padding(18 * u).Role(ui.RoleMenu).FocusGroup(ui.Vertical).Label("个人音乐档案")
		if a.motion != motionOff {
			fade := ui.Animation{Duration: 150 * time.Millisecond}
			panel.Transition(ui.ElementTransition{Animation: &fade, Enter: &ui.Motion{}})
		}
		if state.pinned || state.overAvatar || panel.Hovered() {
			state.leaveAt = time.Time{}
		} else if state.leaveAt.IsZero() {
			state.leaveAt = c.Now().Add(230 * time.Millisecond)
			c.After(230 * time.Millisecond)
		} else if !c.Now().Before(state.leaveAt) {
			a.accountOpen = false
		}
		ui.Scroll(c.Key("account-content")).Grow(1).MinHeight(0).Gap(8 * u).Children(func() {
			a.shellAccountIdentity(c, u)
			a.shellAccountActions(c, u)
		})
	})
}

func (a *app) shellAccountIdentity(c *ui.Context, u float32) {
	ink, muted, surface := ui.Hex("#30382d"), ui.Hex("#5b6654"), ui.Hex("#d7decb")
	if a.pal.dark {
		ink, muted, surface = ui.Hex("#eceee4"), ui.Hex("#c5ccbd"), ui.Hex("#464e3c")
	}
	var person *netease.User
	avatar, name := "", "欢迎来到 Rhine"
	if a.profile != nil {
		avatar, name = a.profile.AvatarURL, a.profile.Nickname
		if d := a.users[a.profile.UserID]; d != nil {
			person = d.user
		}
	}
	levelHeader, levelLabel, signature := "NETEASE", "", "让喜欢的音乐，留下自己的痕迹。"
	if person != nil {
		if person.Signature != "" {
			signature = person.Signature
		}
		if person.Level != nil {
			levelHeader = fmt.Sprintf("LV %d", *person.Level)
			levelLabel = fmt.Sprintf("Lv.%d", *person.Level)
			if *person.Level >= 10 {
				levelLabel = "MAX / 满级"
			}
		}
	}
	level := a.accountPanel.level
	if level.Level != nil {
		levelHeader = fmt.Sprintf("LV %d", *level.Level)
		levelLabel = fmt.Sprintf("Lv.%d", *level.Level)
	}
	if level.Full {
		levelLabel = "MAX / 满级"
	}
	ui.Row(c).Height(22 * u).AlignItems(ui.Center).Children(func() {
		ui.Text(c, "RHINE / 个人音乐档案").FontSize(10 * u).LetterSpacing(0.6).TextColor(muted).Grow(1)
		ui.Text(c, levelHeader).FontSize(11 * u).TextColor(muted)
	})
	ui.Box(c).Height(110 * u).Radius(14 * u).Clip().Background(surface).Center().Children(func() {
		if avatar != "" {
			ui.Box(c).Absolute().Top(0).Right(0).Bottom(0).Left(0).Children(func() {
				a.coverFill(c, avatar, 48, 14*u)
			})
			ui.Box(c).Absolute().Top(0).Right(0).Bottom(0).Left(0).Radius(14 * u).
				Material(glass.Glass{Tint: surface.Alpha(0.55)}).PassThrough()
		}
		ui.Box(c).Size(78*u, 78*u).Radius(39 * u).Background(ui.Hex("#f4f6ed")).Center().Children(func() {
			if avatar != "" {
				a.avatar(c, avatar, 70*u, surface)
			} else {
				ui.Icon(c, iconUser).Size(34*u, 34*u).TextColor(muted)
			}
		})
	})
	ui.Text(c, name).FontSize(25 * u).FontWeight(650).TextColor(ink).SingleLine()
	ui.Text(c, signature).FontSize(12 * u).TextColor(muted).MaxLines(2)
	accent := ui.Hex("#ff6a3d")
	ui.Row(c).Height(24 * u).AlignItems(ui.Center).Children(func() {
		member := a.accountPanel.member.Label
		if member == "" {
			member = "Rhine"
		}
		ui.Text(c, member).FontSize(12 * u).TextColor(accent).Grow(1)
		ui.Text(c, levelLabel).FontSize(11 * u).TextColor(muted)
	})
	progress := ui.Box(c).Height(4 * u).Radius(2 * u).Background(surface)
	fraction := float32(min(1, max(0, level.Progress)))
	if level.Full || person != nil && person.Level != nil && *person.Level >= 10 {
		fraction = 1
	}
	progress.Draw(func(p *ui.Painter, r ui.Rect) {
		if fraction > 0 {
			r.W *= fraction
			p.Fill(r, accent, 2*u)
		}
	})
	ui.Row(c).Height(66 * u).Children(func() {
		for i, label := range []string{"笔记", "关注", "粉丝"} {
			value := "—"
			if person != nil {
				switch i {
				case 0:
					if person.EventCount != nil {
						value = fmt.Sprint(*person.EventCount)
					}
				case 1:
					value = fmt.Sprint(person.Follows)
				case 2:
					value = fmt.Sprint(person.Followeds)
				}
			}
			item := ui.ButtonBase(c.Key(label)).Grow(1).Basis(0).Radius(12 * u).Center().Label(label).
				Disabled(a.profile == nil || i == 0)
			color := ink
			if item.Hovered() && i != 0 && a.profile != nil {
				item.Background(muted.Alpha(.12))
				color = accent
			}
			item.Children(func() {
				ui.Column(c).AlignItems(ui.Center).Gap(3 * u).Children(func() {
					ui.Text(c, value).FontSize(22 * u).FontWeight(650).TextColor(color)
					ui.Text(c, label).FontSize(12 * u).TextColor(muted)
				})
			})
			if item.Clicked() {
				a.accountOpen = false
				a.openAccountProfile(i)
			}
		}
	})
	ui.Box(c).Height(u).Background(muted.Alpha(.18))
}

func (a *app) openAccountProfile(tab int) {
	if a.profile == nil {
		a.openLogin()
		return
	}
	id := a.profile.UserID
	a.open(route{page: pageUser, id: id})
	d := a.users[id]
	if d != nil {
		d.tab = tab
		if tab > 0 && !d.connections[tab-1].loaded {
			a.loadConnections(d, id, tab)
		}
	}
}

func (a *app) shellAccountActions(c *ui.Context, u float32) {
	ink, muted := ui.Hex("#30382d"), ui.Hex("#5b6654")
	if a.pal.dark {
		ink, muted = ui.Hex("#eceee4"), ui.Hex("#c5ccbd")
	}
	signed := a.profile != nil
	profileLabel := "登录账户"
	if signed {
		profileLabel = "个人主页"
	}
	auth := func(fn func()) func() {
		return func() {
			if signed {
				fn()
			} else {
				a.openLogin()
			}
		}
	}
	links := []struct {
		label   string
		icon    *ui.SVG
		enabled bool
		open    func()
	}{
		{"消息", iconComment, true, auth(a.openMessages)},
		{"播放历史", iconHistory, true, auth(func() { a.open(route{page: pageRecent}) })},
		{"音乐来源", iconFolder, true, func() { a.openSettingsAt(settingsAccount) }},
		{"我喜欢的音乐", iconHeart, true, auth(func() {
			if id := a.likedPlaylist(); id != 0 {
				a.open(route{page: pagePlaylist, id: id})
			} else {
				a.openMine(mineMade)
			}
		})},
		{"导入本地音乐", iconFolder, a.route.page == pageLocalLibrary, a.pickLocalFolder},
		{profileLabel, iconUser, true, func() { a.openAccountProfile(0) }},
		{"我的歌单与收藏", iconFolder, signed, func() { a.openMine(mineMade) }},
		{"切换账号", iconUpDown, signed, func() { a.accountPanel.switching = true }},
		{"退出登录", iconSignOut, signed, a.signOut},
	}
	for i, link := range links {
		if i == 7 {
			ui.Row(c).Height(30 * u).AlignItems(ui.Center).Children(func() {
				member := a.accountPanel.member
				label := "会员身份 · 暂未读取"
				switch {
				case !member.Expires.IsZero():
					label = "会员有效期 · " + member.Expires.Format("2006.01.02")
				case member.Label != "":
					label = "会员身份 · " + member.Label
				}
				ui.Text(c, label).FontSize(12 * u).TextColor(muted)
			})
			ui.Box(c).Height(u).Background(muted.Alpha(.18))
		}
		row := ui.ButtonBase(c.Key(link.label)).Role(ui.RoleMenuItem).Label(link.label).Height(43 * u).
			PaddingX(10 * u).AlignItems(ui.Center).Justify(ui.Start).Gap(11 * u).Radius(11 * u).Disabled(!link.enabled)
		if i == 0 && a.accountPanel.pinned {
			row.AutoFocus()
		}
		if row.Hovered() || row.FocusVisible() {
			row.Background(muted.Alpha(.12))
		}
		row.Children(func() {
			color := ink
			if !link.enabled {
				color = ink.Alpha(.4)
			}
			ui.Icon(c, link.icon).Size(19*u, 19*u).TextColor(muted)
			ui.Text(c, link.label).FontSize(15 * u).FontWeight(500).TextColor(color)
		})
		if row.Clicked() {
			a.accountOpen = false
			link.open()
		}
	}
}

func (a *app) shellAccountSwitch(c *ui.Context) {
	open := &a.accountPanel.switching
	a.dialog(c, "shell-account-switch", 0.35, open, func(panel ui.Element) {
		a.pane(panel, 20, false)
		ink := a.inkOn(false)
		panel.Width(400).TextColor(ink.text)
		dialogHeader(c, ink, "切换账号", "将退出当前账号并打开登录页面。当前播放会停止。", func() { *open = false })
		dialogFooter(c, func() {
			if settingButton(c.Key("cancel"), ink, "取消", nil, false, false).Clicked() {
				*open = false
			}
			if dangerButton(c.Key("switch"), "退出并切换", nil, false).Clicked() {
				*open = false
				if a.pl.Playing() {
					a.pl.TogglePlay()
				}
				a.login.gen++
				a.signedIn(nil)
				gen := a.accountGen
				go func() {
					netease.Logout()
					a.post(func() {
						if a.accountGen == gen {
							a.openLogin()
						}
					})
				}()
			}
		})
	})
}
