// SPDX-License-Identifier: AGPL-3.0-only
package app

import (
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/egoist/mygo/ui"
	"netease-music-mygo/internal/netease"
)

type connectionPage struct {
	rows                  []netease.User
	loaded, loading, more bool
	err                   string
}

func (a *app) loadConnections(d *userData, id int64, which int) {
	page := &d.connections[which-1]
	if page.loading || page.loaded && !page.more {
		return
	}
	page.loading, page.err = true, ""
	offset, gen := len(page.rows), a.accountGen
	go func() {
		users, more, err := netease.UserConnections(id, which == 2, offset)
		a.post(func() {
			if gen != a.accountGen || a.users[id] != d {
				return
			}
			page.loading = false
			if err != nil {
				page.err = "无法读取用户列表"
				return
			}
			page.rows = append(page.rows, users...)
			page.loaded, page.more = true, more && len(users) > 0
		})
	}()
}

func (a *app) followProfile(d *userData, id int64) {
	if a.profile == nil || a.profile.UserID == id || d.followPending {
		return
	}
	follow, gen := !d.user.Followed, a.accountGen
	d.followPending = true
	go func() {
		err := netease.FollowUser(id, follow)
		a.post(func() {
			if gen != a.accountGen || a.users[id] != d {
				return
			}
			d.followPending = false
			if err != nil {
				a.toast = "无法更新关注状态"
				return
			}
			d.user.Followed = follow
			if follow {
				d.user.Followeds++
			} else {
				d.user.Followeds = max(0, d.user.Followeds-1)
			}
		})
	}()
}

// Rhine: other listeners' profiles show public collections and their
// following/follower lists; the existing personal collection remains intact.
func (a *app) profileTabs(c *ui.Context, d *userData, id int64) bool {
	ui.Box(c).Margin(20, 0, 0, 0).Children(func() {
		a.segmentedControl(c.Key("profile-tabs"), &d.tab, []string{"音乐", "关注", "粉丝"}, true, func(i int) {
			d.tab = i
			if i > 0 && !d.connections[i-1].loaded {
				a.loadConnections(d, id, i)
			}
		})
	})
	if d.tab == 0 {
		return false
	}
	page := &d.connections[d.tab-1]
	if page.err != "" {
		ui.Text(c, page.err).FontSize(13).TextColor(a.pal.muted)
	}
	if page.loading && len(page.rows) == 0 {
		a.empty(c, "正在读取…")
	}
	if page.loaded && len(page.rows) == 0 {
		a.empty(c, "暂无用户")
	}
	for i := range page.rows {
		a.userRow(c.Key(page.rows[i].UserID), &page.rows[i])
	}
	if page.more || page.err != "" {
		if ui.Button(c.Key("more-connections"), "加载更多").Disabled(page.loading).Clicked() {
			a.loadConnections(d, id, d.tab)
		}
	}
	return true
}

type collectionSocialState struct {
	open               bool
	thread, title      string
	playlist           int64
	revision           uint64
	view               int
	loaded, busy, more bool
	latest, hot        []netease.Comment
	collectors         connectionPage
	pending            map[int64]bool
	draft, err         string
	reply              int64
	replyName          string
	posting            bool
	scroll             ui.ListState
}

var collectionComments = netease.ThreadComments

func (a *app) openCollectionSocial(thread, title string, playlist int64) {
	s := &a.collectionSocial
	a.messages.open = false
	if s.thread != thread {
		a.collectionSocial = collectionSocialState{thread: thread, title: title, playlist: playlist, revision: s.revision + 1, pending: make(map[int64]bool)}
	}
	s.open = true
	if !s.loaded {
		a.loadCollectionComments(true)
	}
}

func (a *app) loadCollectionComments(reset bool) {
	s := &a.collectionSocial
	if s.busy || !reset && !s.more {
		return
	}
	offset := len(s.latest)
	if reset {
		offset = 0
	}
	thread, gen, revision := s.thread, a.accountGen, s.revision
	s.busy, s.err = true, ""
	go func() {
		result, err := collectionComments(thread, offset, 30)
		a.post(func() {
			if gen != a.accountGen || revision != s.revision {
				return
			}
			s.busy = false
			if err != nil || result == nil {
				s.err = "无法读取评论"
				return
			}
			if reset {
				s.latest = nil
				s.hot = result.Hot
			}
			s.latest = append(s.latest, result.Latest...)
			s.loaded, s.more = true, result.More && len(result.Latest) > 0
		})
	}()
}

func (a *app) loadCollectors() {
	s := &a.collectionSocial
	d := &s.collectors
	if s.playlist <= 0 || d.loading || d.loaded && !d.more {
		return
	}
	d.loading, d.err = true, ""
	id, gen, revision, offset := s.playlist, a.accountGen, s.revision, len(d.rows)
	go func() {
		users, more, err := netease.PlaylistCollectors(id, offset)
		a.post(func() {
			if gen != a.accountGen || revision != s.revision {
				return
			}
			d.loading = false
			if err != nil {
				d.err = "无法读取收藏者"
				return
			}
			d.rows = append(d.rows, users...)
			d.loaded, d.more = true, more && len(users) > 0
		})
	}()
}

func (a *app) collectionLike(cm netease.Comment) {
	s := &a.collectionSocial
	if a.profile == nil || s.pending[cm.ID] {
		return
	}
	s.pending[cm.ID] = true
	thread, gen, revision := s.thread, a.accountGen, s.revision
	go func() {
		err := likeComment(thread, cm.ID, !cm.Liked)
		a.post(func() {
			if gen != a.accountGen || revision != s.revision {
				return
			}
			delete(s.pending, cm.ID)
			if err != nil {
				s.err = "点赞未成功，请重试"
				return
			}
			for _, list := range [][]netease.Comment{s.latest, s.hot} {
				for i := range list {
					if list[i].ID == cm.ID {
						list[i].Liked = !cm.Liked
						if cm.Liked {
							list[i].LikedCount = max(0, cm.LikedCount-1)
						} else {
							list[i].LikedCount = cm.LikedCount + 1
						}
					}
				}
			}
		})
	}()
}

func (a *app) postCollectionComment() {
	s := &a.collectionSocial
	draft := s.draft
	body := strings.TrimSpace(draft)
	if a.profile == nil || s.posting || body == "" || utf8.RuneCountInString(body) > 500 {
		return
	}
	thread, gen, revision, reply := s.thread, a.accountGen, s.revision, s.reply
	s.posting, s.err = true, ""
	go func() {
		err := netease.PostThreadComment(thread, body, reply)
		a.post(func() {
			if gen != a.accountGen || revision != s.revision {
				return
			}
			s.posting = false
			if err != nil {
				s.err = "发布未确认，草稿已保留，请刷新后检查"
				return
			}
			if s.draft == draft {
				s.draft = ""
				s.reply = 0
				s.replyName = ""
			}
			a.loadCollectionComments(true)
		})
	}()
}

func (a *app) collectionSocialDrawer(c *ui.Context) {
	s := &a.collectionSocial
	if !s.open {
		return
	}
	a.sideDrawer(c, "collection-social", "歌单社交", &s.open, func() {
		p := a.pal
		ui.Row(c).AlignItems(ui.Center).Gap(8).Children(func() {
			ui.Text(c, s.title).FontSize(19).FontWeight(700).Grow(1).Basis(0).MinWidth(0).SingleLine()
			if iconButton(c.Key("close"), iconX, 16, p.muted, "关闭评论").Clicked() {
				s.open = false
			}
		})
		labels := []string{"最新评论", "热门评论"}
		if s.playlist > 0 {
			labels = append(labels, "收藏者")
		}
		a.segmentedControl(c.Key("sort"), &s.view, labels, true, func(i int) {
			s.view = i
			s.scroll = ui.ListState{}
			if i == 2 && !s.collectors.loaded {
				a.loadCollectors()
			}
		})
		if s.view == 2 {
			d := &s.collectors
			if d.err != "" {
				ui.Text(c, d.err).FontSize(13).TextColor(p.muted)
			}
			if d.loading && len(d.rows) == 0 {
				a.empty(c, "正在读取…")
			}
			if d.loaded && len(d.rows) == 0 {
				a.empty(c, "暂无收藏者")
			}
			ui.Scroll(c.Key("collectors")).Grow(1).Children(func() {
				for i := range d.rows {
					u := &d.rows[i]
					if ui.Button(c.Key(u.UserID), "查看 "+u.Nickname).Clicked() {
						s.open = false
						a.open(route{page: pageUser, id: u.UserID})
					}
				}
				if d.more || d.err != "" {
					if ui.Button(c.Key("more"), "加载更多收藏者").Disabled(d.loading).Clicked() {
						a.loadCollectors()
					}
				}
			})
			return
		}
		if s.err != "" {
			ui.Text(c, s.err).FontSize(13).TextColor(p.muted)
			if ui.Button(c.Key("retry"), "重新加载评论").Disabled(s.busy).Clicked() {
				a.loadCollectionComments(true)
			}
		}
		rows := s.latest
		if s.view == 1 {
			rows = s.hot
		}
		if len(rows) == 0 {
			label := "暂无评论"
			if s.busy {
				label = "正在读取评论…"
			}
			a.empty(c, label)
		}
		more := s.view == 0 && s.more
		n := len(rows)
		if more {
			n++
		}
		ui.List(c.Key("comments"), &s.scroll, n, func(i int) {
			if i >= len(rows) {
				if ui.Button(c.Key("more"), "加载更多评论").Disabled(s.busy).Clicked() {
					a.loadCollectionComments(false)
				}
				return
			}
			a.collectionCommentRow(c.Key(rows[i].ID), rows[i])
		}).Grow(1).MinHeight(0)
		if a.profile != nil {
			if s.reply != 0 && ui.Button(c.Key("clear-reply"), "取消回复 "+s.replyName).Clicked() {
				s.reply = 0
				s.replyName = ""
			}
			ui.TextArea(c.Key("draft"), &s.draft).Placeholder("写评论").Label("评论草稿").Height(72)
			if ui.Button(c.Key("post"), "发布评论").Disabled(s.posting || strings.TrimSpace(s.draft) == "" || utf8.RuneCountInString(s.draft) > 500).Clicked() {
				a.postCollectionComment()
			}
		}
	})
}

func (a *app) collectionCommentRow(c *ui.Context, cm netease.Comment) {
	p, s := a.pal, &a.collectionSocial
	ui.Row(c).Padding(10).Gap(10).AlignItems(ui.Start).Radius(14).Background(p.hover).Children(func() {
		a.cover(c, cm.User.AvatarURL, 120, 32, 16)
		ui.Column(c).Grow(1).Basis(0).MinWidth(0).Gap(6).Children(func() {
			ui.Text(c, cm.User.Nickname).FontSize(13).FontWeight(650)
			ui.Text(c, cm.Content).FontSize(14).LineHeight(1.45)
			if len(cm.BeReplied) > 0 {
				r := cm.BeReplied[0]
				ui.Text(c, "@"+r.User.Nickname+"："+r.Content).FontSize(12).TextColor(p.muted)
			}
			ui.Row(c).AlignItems(ui.Center).Gap(8).Children(func() {
				if cm.Time > 0 {
					ui.Text(c, commentTime(time.UnixMilli(cm.Time), c.Now())).Grow(1).FontSize(11).TextColor(p.muted)
				}
				label := "赞"
				if cm.Liked {
					label = "取消赞"
				}
				if ui.Button(c.Key("like"), fmt.Sprintf("%s %d", label, cm.LikedCount)).Disabled(a.profile == nil || s.pending[cm.ID]).Clicked() {
					a.collectionLike(cm)
				}
				if a.profile != nil && ui.Button(c.Key("reply"), "回复").Clicked() {
					s.reply, s.replyName = cm.ID, cm.User.Nickname
				}
			})
		})
	})
}

func (a *app) playlistCommentsButton(c *ui.Context, pl *netease.Playlist) {
	if iconButton(c.Key("playlist-comments"), iconComment, 16, a.pal.muted, "歌单评论").Clicked() {
		a.messages.open = false
		a.openCollectionSocial(fmt.Sprintf("A_PL_0_%d", pl.ID), pl.Name, pl.ID)
	}
}
