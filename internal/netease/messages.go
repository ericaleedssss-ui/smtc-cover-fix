// SPDX-License-Identifier: AGPL-3.0-only
package netease

import (
	"encoding/json"
	"errors"
	"strconv"
)

type Message struct {
	ID, Time, Peer int64
	Author         User
	Text           string
	Unread         int
	Kind           string
	ResourceID     int64
	ResourceName   string
}

type Messages struct {
	Rows   []Message
	More   bool
	Cursor int64
}

var inboxEndpoints = [...]struct{ path, field string }{
	{"/api/msg/private/users", "msgs"}, {"/api/v1/user/comments/", "comments"},
	{"/api/forwards/get", "forwards"}, {"/api/msg/notices", "notices"},
}

// Inbox loads one page in the private, comments, mentions or notices tab.
func Inbox(tab int, uid int64, offset int, before int64) (Messages, error) {
	if tab < 0 || tab >= len(inboxEndpoints) {
		return Messages{}, errors.New("invalid inbox tab")
	}
	ep := inboxEndpoints[tab]
	if tab == 1 {
		ep.path += strconv.FormatInt(uid, 10)
	}
	if before == 0 {
		before = -1
	}
	data := map[string]any{"offset": offset, "limit": 30, "total": "true", "uid": uid, "beforeTime": before, "time": before}
	return readMessages(ep.path, ep.field, data, tab, false, uid)
}

func PrivateHistory(peer, uid, before int64) (Messages, error) {
	return readMessages("/api/msg/private/history", "msgs", map[string]any{
		"userId": peer, "time": before, "limit": 30, "total": "true",
	}, 0, true, uid)
}

func SendPrivateText(peer int64, text string) error {
	return webAPI("/api/msg/private/send", map[string]any{
		"type": "text", "msg": text, "userIds": "[" + strconv.FormatInt(peer, 10) + "]",
	}, &struct{}{})
}

func InboxCounts() ([4]int, error) {
	var fields map[string]json.RawMessage
	var counts [4]int
	err := webAPI("/api/pl/count", map[string]any{}, &fields)
	nested := messageObject(fields["count"])
	for i, name := range []string{"msg", "comment", "forward", "notice"} {
		raw := fields[name]
		if raw == nil {
			raw = nested[name]
		}
		_ = json.Unmarshal(raw, &counts[i])
	}
	return counts, err
}

func readMessages(path, field string, data map[string]any, tab int, chat bool, uid int64) (Messages, error) {
	var body map[string]json.RawMessage
	if err := webAPI(path, data, &body); err != nil {
		return Messages{}, err
	}
	var rows []map[string]json.RawMessage
	if raw := body[field]; len(raw) == 0 || json.Unmarshal(raw, &rows) != nil {
		return Messages{}, errors.New("unknown message format")
	}
	var page Messages
	_ = json.Unmarshal(body["more"], &page.More)
	if !page.More {
		_ = json.Unmarshal(body["hasMore"], &page.More)
	}
	for _, row := range rows {
		msg := normalizeMessage(row, tab, chat, uid)
		page.Rows = append(page.Rows, msg)
		page.Cursor = msg.Time
		if tab == 1 {
			if updated := messageInt(row["updateTime"]); updated > 0 {
				page.Cursor = updated
			}
		}
	}
	page.More = page.More && len(page.Rows) > 0
	return page, nil
}

func messageObject(raw json.RawMessage) map[string]json.RawMessage {
	var object map[string]json.RawMessage
	if len(raw) > 0 && raw[0] == '"' {
		var s string
		if json.Unmarshal(raw, &s) == nil {
			raw = []byte(s)
		}
	}
	_ = json.Unmarshal(raw, &object)
	return object
}

func messageText(raw json.RawMessage) string {
	var s string
	_ = json.Unmarshal(raw, &s)
	return s
}

func messageInt(raw json.RawMessage) int64 {
	var n int64
	if json.Unmarshal(raw, &n) != nil {
		n, _ = strconv.ParseInt(messageText(raw), 10, 64)
	}
	return n
}

func normalizeMessage(row map[string]json.RawMessage, tab int, chat bool, uid int64) Message {
	payloadKey := "json"
	timeKey := "time"
	if chat {
		payloadKey = "msg"
	} else if tab == 0 {
		payloadKey = "lastMsg"
		timeKey = "lastMsgTime"
	} else if tab == 3 {
		payloadKey = "notice"
	}
	data := messageObject(row[payloadKey])
	var author User
	for _, raw := range []json.RawMessage{row["fromUser"], row["user"], data["user"]} {
		_ = json.Unmarshal(raw, &author)
		if author.UserID > 0 {
			break
		}
	}
	if !chat && tab == 0 && author.UserID == uid {
		var recipient User
		if json.Unmarshal(row["toUser"], &recipient) == nil && recipient.UserID > 0 {
			author = recipient
		}
	}
	m := Message{ID: messageInt(row["id"]), Peer: author.UserID, Author: author, Time: messageInt(row[timeKey]), Unread: int(messageInt(row["newMsgCount"]))}
	if m.Time <= 0 {
		m.Time = messageInt(row["updateTime"])
	}
	for _, raw := range []json.RawMessage{data["msg"], data["content"], row["content"], messageObject(row["comment"])["content"]} {
		if m.Text = messageText(raw); m.Text != "" {
			break
		}
	}
	for _, kind := range []string{"song", "album", "playlist"} {
		resource := messageObject(data[kind])
		if id := messageInt(resource["id"]); id > 0 {
			m.Kind, m.ResourceID, m.ResourceName = kind, id, messageText(resource["name"])
			break
		}
	}
	if m.Text == "" && m.ResourceID == 0 {
		m.Text = "此消息类型暂未支持"
		if messageObject(data["picInfo"]) != nil || messageText(data["picUrl"]) != "" {
			m.Text = "[图片]"
		}
	}
	return m
}
