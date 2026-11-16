// SPDX-License-Identifier: AGPL-3.0-only
package netease

import (
	"io"
	"net/http"
	"net/http/cookiejar"
	"strconv"
	"strings"
	"testing"
)

// A previous report is comparable only when it ends just before the current
// calendar week; ranks from the completed week must use the rolling fallback.
func TestHomeWeeklyReportPeriods(t *testing.T) {
	oldClient, oldTransport := httpClient, http.DefaultTransport
	t.Cleanup(func() { httpClient = oldClient; http.DefaultTransport = oldTransport })
	const start = int64(1794182400000)
	for _, test := range []struct {
		name    string
		end     int64
		compare bool
	}{{"adjacent", start - 1, true}, {"same week", start, false}, {"gap", start - 3*86400000, false}} {
		t.Run(test.name, func(t *testing.T) {
			transport := browseTransport(func(r *http.Request) (*http.Response, error) {
				var body string
				switch r.URL.Path {
				case "/eapi/content/activity/listen/data/realtime/report":
					body = `{"code":200,"data":{"startTime":1794182400000,"listenTimeDistributionBlock":{"playDuration":120,"durationDetails":[{"period":"2026-11-09","duration":120}]}}}`
				case "/eapi/content/activity/listen/data/song/play/rank":
					body = `{"data":{"startTime":1,"songItems":[{"songId":9,"songName":"Wrong week","playCount":99}]}}`
				case "/weapi/v1/play/record":
					body = `{"code":200,"weekData":[{"song":{"id":42,"name":"Current"},"playCount":3}]}`
				case "/weapi/play-record/song/list":
					body = `{"code":200,"data":{"list":[{"data":{"id":42,"name":"Current","dt":180000},"playTime":1794190000000}]}}`
				case "/eapi/content/activity/listen/data/report":
					body = `{"data":{"endTime":` + strconv.FormatInt(test.end, 10) + `,"listenTimeDistributionBlock":{"playDuration":90}}}`
				default:
					t.Fatalf("unexpected request %s", r.URL.Path)
				}
				return &http.Response{StatusCode: 200, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(body))}, nil
			})
			jar, _ := cookiejar.New(nil)
			httpClient = &http.Client{Transport: transport, Jar: jar}
			http.DefaultTransport = transport
			var initial WeeklyScore
			score, err := HomeWeeklyScoreProgress(42, func(report WeeklyScore) { initial = report })
			if initial.Minutes != 120 || len(initial.Days) != 1 || len(initial.Ranking) != 0 || len(initial.Recent) != 0 || initial.ComparisonAvailable {
				t.Fatalf("initial report = %+v", initial)
			}
			if err != nil {
				t.Fatal(err)
			}
			if score.Minutes != 120 || len(score.Days) != 1 || score.Ranking[0].SongID != 42 || len(score.Recent) != 1 || score.ComparisonAvailable != test.compare {
				t.Fatalf("score = %+v", score)
			}
		})
	}
}
