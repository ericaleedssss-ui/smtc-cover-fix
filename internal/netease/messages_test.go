// SPDX-License-Identifier: AGPL-3.0-only
package netease

import (
	"encoding/base64"
	"encoding/hex"
	"io"
	"net/http"
	"strings"
	"testing"
)

// Inbox decodes the service's stringified payloads over the existing HTTP client.
func TestRhineM6InboxTransport(t *testing.T) {
	old := httpClient
	t.Cleanup(func() { httpClient = old })
	httpClient = &http.Client{Transport: browseTransport(func(r *http.Request) (*http.Response, error) {
		if r.Method != "POST" || r.URL.Host != "music.163.com" || r.URL.Path != "/weapi/msg/private/users" {
			t.Fatalf("unexpected request: %s %s", r.Method, r.URL)
		}
		if err := r.ParseForm(); err != nil {
			t.Fatal(err)
		}
		params, err := base64.StdEncoding.DecodeString(r.PostForm.Get("params"))
		if err != nil || len(params) == 0 || len(params)%16 != 0 {
			t.Fatal("invalid encrypted payload")
		}
		key, err := hex.DecodeString(r.PostForm.Get("encSecKey"))
		if err != nil || len(key) != 128 || webAPIKey().E != 65537 {
			t.Fatal("invalid encrypted key")
		}
		body := `{"code":200,"more":true,"msgs":[{"fromUser":{"userId":10,"nickname":"我"},"toUser":{"userId":20,"nickname":"好友"},"lastMsgTime":123,"lastMsg":"{\"msg\":\"分享一首歌\",\"song\":{\"id\":90,\"name\":\"海边\"}}"}]}`
		return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(body)), Header: make(http.Header)}, nil
	})}
	page, err := Inbox(0, 10, 0, 0)
	if err != nil || !page.More || page.Cursor != 123 || len(page.Rows) != 1 {
		t.Fatalf("wrong page: %+v, %v", page, err)
	}
	row := page.Rows[0]
	if row.Peer != 20 || row.Kind != "song" || row.ResourceID != 90 || row.Text != "分享一首歌" {
		t.Fatalf("wrong message: %+v", row)
	}
}
