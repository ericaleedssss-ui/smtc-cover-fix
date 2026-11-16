package netease

import (
	"io"
	"net/http"
	"strings"
	"testing"
)

// Mixed home resources must keep albums and lists, drop invalid items, and group songs.
func TestHomeRecommendationFeed(t *testing.T) {
	original := httpClient
	t.Cleanup(func() { httpClient = original })
	httpClient = &http.Client{Transport: browseTransport(func(r *http.Request) (*http.Response, error) {
		if r.URL.Path != "/weapi/homepage/block/page" {
			t.Fatalf("unexpected path %s", r.URL.Path)
		}
		body := `{"code":200,"data":{"blocks":[{"blockCode":"HOMEPAGE_DAILY","creatives":[{"resources":[{"resourceId":2,"resourceType":"list","uiElement":{"mainTitle":{"title":"exclude"}}}]}]},{"blockCode":"HOMEPAGE_MIX","uiElement":{"mainTitle":{"title":"怀旧"}},"creatives":[{"resources":[{"resourceId":"33","resourceType":"album","uiElement":{"mainTitle":{"title":"专辑"},"image":{"imageUrl":"https://p1.music.126.net/a.jpg?watermark"}}},{"resourceId":"mv1","resourceType":"mv"},{"resourceId":88,"resourceType":"list","valid":false},{"resourceType":"song","resourceExtInfo":{"songData":{"id":11,"name":"街灯","artists":[{"name":"乐队"}],"album":{"id":2,"picUrl":"cover"},"duration":120000}}}]}]}]}}`
		return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(body)), Header: make(http.Header)}, nil
	})}
	items, err := HomeRecommendations()
	if err != nil || len(items) != 2 {
		t.Fatalf("recommendations = %+v, %v", items, err)
	}
	if album := items[0]; !album.Album || album.ID != 33 || album.Cover != "https://p1.music.126.net/a.jpg" {
		t.Fatalf("bad album card: %+v", album)
	}
	mix := items[1]
	if len(mix.Tracks) != 1 || mix.Tracks[0].Duration != 120000 || mix.Tracks[0].ArtistNames() != "乐队" || mix.Cover != "cover" {
		t.Fatalf("bad mix: %+v", mix)
	}
}

// Rank history distinguishes new chart entries from positions that did not change.
func TestHomeChartPositions(t *testing.T) {
	original := httpClient
	t.Cleanup(func() { httpClient = original })
	httpClient = &http.Client{Transport: browseTransport(func(r *http.Request) (*http.Response, error) {
		if r.URL.Query().Get("n") != "6" {
			t.Fatalf("preview loaded more than six songs: %s", r.URL)
		}
		body := `{"code":200,"playlist":{"tracks":[{"id":1},{"id":2},{"id":3}],"trackIds":[{"id":1,"lr":1},{"id":2,"lr":0},{"id":3,"lr":8}]}}`
		return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(body)), Header: make(http.Header)}, nil
	})}
	rows, err := ChartPreview(42)
	if err != nil || len(rows) != 3 || !rows[1].Ranked || rows[1].Previous != 0 || rows[2].Previous != 8 {
		t.Fatalf("chart preview = %+v, %v", rows, err)
	}
}
