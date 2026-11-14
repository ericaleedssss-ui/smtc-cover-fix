// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"fmt"
	"slices"
	"strconv"
	"strings"
	"time"
	"unicode/utf16"

	"github.com/egoist/mygo/ui"
	"netease-music-mygo/internal/netease"
)

type messagePage struct {
	rows               []netease.Message
	loaded, busy, more bool
	offset             int
	cursor             int64
	error              string
}

type conversation struct {
	messagePage
	scroll  ui.ListState
	draft   string
	sending bool
}

type messageState struct {
	open                  bool
	tab                   int
	counts                [4]int
	countBusy             bool
	pages                 [4]messagePage
	chats                 map[int64]*conversation
	peer                  int64
	name, recipient, note string
	scroll                ui.ListState
}

var messageTabs = []string{"私信", "评论", "@我", "通知"}

func (a *app) openMessages() {
	m := &a.messages
	a.collectionSocial.open = false
	m.open = true
	a.refreshMessages()
}

func (a *app) refreshMessages() {
	m := &a.messages
	if a.profile == nil {
		return
	}
	if !m.countBusy {
		m.countBusy = true
		gen := a.accountGen
		go func() {
			counts, err := netease.InboxCounts()
			a.post(func() {
				if gen != a.accountGen {
					return
				}
				m.countBusy = false
				if err == nil {
					m.counts = counts
				}
			})
		}()
	}
	a.loadMessages(true)
}

func (a *app) messageTab(tab int) {
	m := &a.messages
	if tab < 0 || tab >= len(m.pages) {
		return
	}
	m.tab, m.peer, m.note = tab, 0, ""
	m.scroll = ui.ListState{}
	if !m.pages[tab].loaded {
		a.loadMessages(true)
	}
}

func (a *app) openConversation(id int64, name string) {
	m := &a.messages
	if a.profile == nil || id <= 0 || id == a.profile.UserID {
		m.note = "请输入有效的对方用户 ID"
		return
	}
	a.collectionSocial.open = false
	m.open, m.peer, m.name, m.note = true, id, name, ""
	if name == "" {
		m.name = fmt.Sprintf("用户 %d", id)
	}
	if m.chats == nil {
		m.chats = make(map[int64]*conversation)
	}
	if m.chats[id] == nil {
		m.chats[id] = &conversation{}
	}
	a.loadMessages(true)
}

func mergeMessageRows(old, incoming []netease.Message, chat bool) []netease.Message {
	for _, msg := range incoming {
		i := slices.IndexFunc(old, func(first netease.Message) bool {
			switch {
			case !chat && msg.Peer > 0 && msg.ID == 0 && first.ID == 0 && msg.Time > 0:
				return first.Peer == msg.Peer && first.Time == msg.Time && first.Text == msg.Text
			case msg.ID > 0:
				return first.ID == msg.ID
			default:
				return first.Peer == msg.Peer && first.Time == msg.Time && first.Text == msg.Text && first.ResourceID == msg.ResourceID
			}
		})
		if i >= 0 {
			old[i] = msg
		} else {
			old = append(old, msg)
		}
	}
	return old
}

func (a *app) loadMessages(reset bool) {
	if a.profile == nil {
		return
	}
	m := &a.messages
	tab, peer, uid, gen := m.tab, m.peer, a.profile.UserID, a.accountGen
	page := &m.pages[tab]
	if peer != 0 {
		page = &m.chats[peer].messagePage
	}
	if page.busy || !reset && !page.more {
		return
	}
	page.busy, page.error = true, ""
	offset, before := page.offset, page.cursor
	if reset {
		offset, before = 0, 0
	}
	go func() {
		var data netease.Messages
		var err error
		if peer != 0 {
			data, err = netease.PrivateHistory(peer, uid, before)
		} else {
			data, err = netease.Inbox(tab, uid, offset, before)
		}
		a.post(func() {
			if gen != a.accountGen {
				return
			}
			page.busy = false
			if err != nil {
				page.error = "无法读取消息，请刷新重试"
				return
			}
			if peer == 0 && reset {
				page.rows = nil
			}
			page.rows = mergeMessageRows(page.rows, data.Rows, peer != 0)
			page.loaded = true
			if peer == 0 || !reset || page.cursor == 0 {
				page.more, page.cursor, page.offset = data.More && (peer == 0 && (tab == 0 || tab == 2) || data.Cursor > 0 && data.Cursor != before), data.Cursor, offset+len(data.Rows)
			}
			if peer != 0 {
				slices.SortStableFunc(page.rows, func(a, b netease.Message) int {
					if a.Time < b.Time {
						return 1
					}
					if a.Time > b.Time {
						return -1
					}
					return 0
				})
			}
		})
	}()
}

var sendPrivateText = netease.SendPrivateText

func (a *app) sendMessage() {
	m := &a.messages
	chat := m.chats[m.peer]
	if a.profile == nil || chat == nil || chat.sending {
		return
	}
	draft := chat.draft
	body := strings.TrimSpace(draft)
	if body == "" || len(utf16.Encode([]rune(body))) > 1000 {
		return
	}
	peer, gen := m.peer, a.accountGen
	chat.sending, chat.error = true, ""
	go func() {
		err := sendPrivateText(peer, body)
		a.post(func() {
			if gen != a.accountGen {
				return
			}
			chat.sending = false
			if err != nil {
				chat.error = "发送未确认，草稿已保留。请刷新会话确认后再重试。"
				return
			}
			if chat.draft == draft {
				chat.draft = ""
			}
			if m.peer == peer {
				a.loadMessages(true)
			}
		})
	}()
}

// Rhine: station messages open in a right-side drawer, over the current page.
func (a *app) messageDrawer(c *ui.Context) {
	m := &a.messages
	if !m.open {
		return
	}
	a.sideDrawer(c, "messages", "站内消息", &m.open, func() {
		p := a.pal
		ui.Row(c).Gap(8).AlignItems(ui.Center).Children(func() {
			if m.peer != 0 && iconButton(c.Key("back"), iconBack, 16, p.muted, "返回消息列表").Clicked() {
				a.messageTab(m.tab)
			}
			name := "站内消息"
			if m.peer != 0 {
				name = m.name
			}
			ui.Text(c, name).FontSize(20).FontWeight(700).Grow(1).Shrink(1).MinWidth(0).SingleLine()
			if a.profile != nil && iconButton(c.Key("refresh"), iconRepeat, 16, p.muted, "刷新消息").Clicked() {
				a.refreshMessages()
			}
			if iconButton(c.Key("close"), iconX, 16, p.muted, "关闭消息").Clicked() {
				m.open = false
			}
		})
		if a.profile == nil {
			a.empty(c, "登录网易云后查看站内消息")
			if ui.Button(c.Key("login"), "登录网易云").Clicked() {
				m.open = false
				a.openLogin()
			}
			return
		}
		page := &m.pages[m.tab]
		chat := m.chats[m.peer]
		if chat != nil {
			page = &chat.messagePage
		} else {
			tabs := slices.Clone(messageTabs)
			for i, n := range m.counts {
				if n > 0 {
					tabs[i] += fmt.Sprintf(" %d", n)
				}
			}
			a.segmentedControl(c.Key("tabs"), &m.tab, tabs, true, a.messageTab)
			if m.tab == 0 {
				ui.Row(c).Gap(8).AlignItems(ui.Center).Children(func() {
					ui.TextInputBase(c.Key("peer"), &m.recipient).Placeholder("对方用户 ID").Label("对方用户 ID").Grow(1).MinWidth(0).Height(32)
					if ui.Button(c.Key("new"), "新私信").Clicked() {
						id, _ := strconv.ParseInt(strings.TrimSpace(m.recipient), 10, 64)
						a.openConversation(id, "")
					}
				})
			}
		}
		switch {
		case page.error != "":
			ui.Text(c, page.error).FontSize(13).TextColor(p.muted)
		case m.note != "":
			ui.Text(c, m.note).FontSize(13).TextColor(p.muted)
		case page.busy && len(page.rows) == 0:
			ui.Text(c, "正在读取消息…").FontSize(13).TextColor(p.muted)
		case len(page.rows) == 0:
			ui.Text(c, "暂无消息").FontSize(13).TextColor(p.muted)
		}
		count := len(page.rows)
		if page.more {
			count++
		}
		state := &m.scroll
		if chat != nil {
			state = &chat.scroll
		}
		ui.List(c.Key(struct{ Peer int64 }{m.peer}), state, count, func(i int) {
			if i == len(page.rows) {
				if ui.Button(c.Key("more"), "加载更多").Disabled(page.busy).Clicked() {
					a.loadMessages(false)
				}
				return
			}
			a.messageRow(c.Key(i), page.rows[i], chat != nil)
		}).Grow(1).MinHeight(0)
		if chat != nil {
			ui.TextArea(c.Key("draft"), &chat.draft).Placeholder("写私信").Label("私信草稿").Height(78)
			if ui.Button(c.Key("send"), "发送私信").Disabled(chat.sending || strings.TrimSpace(chat.draft) == "" || len(utf16.Encode([]rune(chat.draft))) > 1000).Clicked() {
				a.sendMessage()
			}
		}
	})
}

func (a *app) messageRow(c *ui.Context, msg netease.Message, chat bool) {
	m, p := &a.messages, a.pal
	name := msg.Author.Nickname
	if name == "" {
		name = "平台通知"
	}
	label := name
	private := !chat && m.tab == 0 && msg.Peer > 0
	if private {
		label = "会话：" + name
	}
	openable := msg.ResourceID > 0
	row := ui.ButtonBase(c).Padding(10).Gap(10).Radius(14).AlignItems(ui.Start).Justify(ui.Start).Label(label).
		Disabled(!private && !openable)
	if row.Hovered() {
		row.Background(p.hover)
	}
	row.Children(func() {
		a.cover(c, msg.Author.AvatarURL, 120, 32, 16)
		ui.Column(c).Grow(1).Basis(0).MinWidth(0).Gap(4).Children(func() {
			if msg.Unread > 0 {
				name += fmt.Sprintf(" · %d 条未读", msg.Unread)
			}
			ui.Text(c, name).FontSize(13).FontWeight(650)
			if msg.Text != "" {
				ui.Text(c, msg.Text).FontSize(13).MaxLines(8)
			}
			if openable {
				ui.Text(c, msg.ResourceName).FontSize(13).TextColor(p.accent).SingleLine()
			}
			if msg.Time > 0 {
				ui.Text(c, commentTime(time.UnixMilli(msg.Time), c.Now())).FontSize(11).TextColor(p.muted)
			}
		})
	})
	if row.Clicked() {
		if private {
			a.openConversation(msg.Peer, msg.Author.Nickname)
			return
		}
		m.open = false
		switch msg.Kind {
		case "playlist":
			a.open(route{page: pagePlaylist, id: msg.ResourceID})
		case "album":
			a.open(route{page: pageAlbum, id: msg.ResourceID})
		case "song":
			a.openCollectionSocial(fmt.Sprintf("R_SO_4_%d", msg.ResourceID), msg.ResourceName, 0)
		}
	}
}

func (a *app) sideDrawer(c *ui.Context, key, label string, open *bool, content func()) {
	ui.Overlay(c, func() {
		w, _ := c.Size()
		panel := ui.Column(c.Key(key)).Absolute().Top(54).Right(14).Bottom(14).Width(min(440, w-28)).
			Padding(16).Gap(12).Label(label).TextColor(a.inkOn(false).text)
		a.pane(panel, 20, false)
		panel.Children(content)
		if panel.PressedOutside() || panel.OverlayShortcut(0, ui.KeyEscape) {
			*open = false
		}
	})
}

func (a *app) messageNav(c *ui.Context) {
	p, d := a.pal, a.side()
	b := ui.ButtonBase(c.Key("message-nav")).Height(d.row).PaddingX(10).Gap(10).Radius(8).AlignItems(ui.Center).
		Justify(ui.Start).FocusRing(false).Label("站内消息")
	if b.Hovered() || a.messages.open {
		b.Background(p.hover)
	}
	b.Children(func() {
		ui.Icon(c, iconComment).Size(d.icon, d.icon).TextColor(p.text)
		ui.Text(c, "站内消息").FontSize(d.navText).FontWeight(500).TextColor(p.text)
	})
	if b.Clicked() {
		a.collectionSocial.open = false
		a.openMessages()
	}
}
