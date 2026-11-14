// SPDX-License-Identifier: AGPL-3.0-only
package netease

import (
	"strconv"
)

func UserConnections(uid int64, followers bool, offset int) ([]User, bool, error) {
	suffix := strconv.FormatInt(uid, 10)
	path := "/api/user/getfollows/" + suffix
	if followers {
		path = "/api/user/getfolloweds/" + suffix
	}
	var res struct {
		Follows   []User `json:"follow"`
		Followers []User `json:"followeds"`
		More      bool   `json:"more"`
	}
	err := webAPI(path, map[string]any{"userId": uid, "time": "0", "limit": 30, "offset": offset, "order": true, "getcounts": "true"}, &res)
	if followers {
		return res.Followers, res.More, err
	}
	return res.Follows, res.More, err
}

func FollowUser(uid int64, follow bool) error {
	verb := "delfollow"
	if follow {
		verb = "follow"
	}
	return webAPI("/api/user/"+verb+"/"+strconv.FormatInt(uid, 10), map[string]any{}, &struct{}{})
}

func PostThreadComment(thread, text string, reply int64) error {
	verb := "add"
	data := map[string]any{"threadId": thread, "content": text}
	if reply > 0 {
		verb = "reply"
		data["commentId"] = strconv.FormatInt(reply, 10)
	}
	return eapiOK("/api/resource/comments/"+verb, data)
}

func PlaylistCollectors(id int64, offset int) ([]User, bool, error) {
	var res struct {
		Users []User `json:"subscribers"`
		More  bool   `json:"more"`
	}
	err := webAPI("/api/playlist/subscribers", map[string]any{"id": id, "offset": offset, "limit": 24}, &res)
	return res.Users, res.More, err
}
