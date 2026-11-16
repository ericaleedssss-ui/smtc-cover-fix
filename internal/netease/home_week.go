// SPDX-License-Identifier: AGPL-3.0-only
package netease

import (
	"errors"
	"slices"
	"strconv"
	"strings"
	"time"
)

type ScoreDay struct {
	Date    string
	Minutes float64
}
type ScoreObservation struct {
	Track Track
	At    int64
}
type ScoreRank struct {
	SongID    int64
	SongName  string
	PlayCount int
}
type WeeklyScore struct {
	Days                     []ScoreDay
	Minutes, PreviousMinutes float64
	StartTime, EndTime       int64
	ComparisonAvailable      bool
	Ranking                  []ScoreRank
	RankingLabel             string
	Recent                   []ScoreObservation
}

type scoreReport struct {
	Data struct {
		StartTime, EndTime          int64
		ListenTimeDistributionBlock struct {
			PlayDuration    *float64
			DurationDetails []struct {
				Period   string
				Duration float64
			}
		}
	}
}

// Rhine: HomePage.cpp uses the realtime report as the sole source of online
// daily duration. Timed history is only an observation, never another total.
func HomeWeeklyScore(uid int64) (*WeeklyScore, error) {
	return HomeWeeklyScoreProgress(uid, nil)
}

// HomeWeeklyScoreProgress publishes the current daily report before fetching
// the optional ranking, history and comparison for that report.
func HomeWeeklyScoreProgress(uid int64, ready func(WeeklyScore)) (*WeeklyScore, error) {
	var current scoreReport
	if err := eapiPost("/api/content/activity/listen/data/realtime/report", map[string]any{"type": "week"}, &current); err != nil {
		return nil, err
	}
	block := current.Data.ListenTimeDistributionBlock
	if block.PlayDuration == nil || len(block.DurationDetails) == 0 {
		return nil, errors.New("暂未生成本周听歌报告")
	}
	score := &WeeklyScore{Minutes: *block.PlayDuration, StartTime: current.Data.StartTime, EndTime: current.Data.EndTime, RankingLabel: "本周循环最多"}
	for _, d := range block.DurationDetails {
		if _, err := time.Parse("2006-01-02", d.Period); err == nil {
			score.Days = append(score.Days, ScoreDay{d.Period, max(0, d.Duration)})
		}
	}
	if len(score.Days) == 0 {
		return nil, errors.New("暂未生成本周听歌报告")
	}
	slices.SortFunc(score.Days, func(a, b ScoreDay) int { return strings.Compare(a.Date, b.Date) })
	if ready != nil {
		ready(*score)
	}
	var rank struct {
		Data struct {
			StartTime int64
			SongItems []ScoreRank
		}
	}
	if err := eapiPost("/api/content/activity/listen/data/song/play/rank", map[string]any{"type": "week"}, &rank); err == nil && rank.Data.StartTime == score.StartTime {
		score.Ranking = rank.Data.SongItems
	}
	if len(score.Ranking) == 0 {
		var fallback struct {
			WeekData []struct {
				Song      Track
				PlayCount int
			}
		}
		if err := webAPI("/api/v1/play/record", map[string]any{"uid": uid, "type": 1}, &fallback); err == nil {
			score.RankingLabel = "近7天循环最多"
			for _, row := range fallback.WeekData {
				score.Ranking = append(score.Ranking, ScoreRank{row.Song.ID, row.Song.Name, row.PlayCount})
			}
		}
	}
	var recent struct {
		Data struct {
			List []struct {
				Data     Track
				PlayTime int64
			}
		}
	}
	if err := webAPI("/api/play-record/song/list", map[string]any{"limit": 1000}, &recent); err == nil {
		for _, row := range recent.Data.List {
			if row.Data.ID > 0 && row.PlayTime > 0 {
				score.Recent = append(score.Recent, ScoreObservation{row.Data, row.PlayTime})
			}
		}
	}
	var previous scoreReport
	if err := eapiPost("/api/content/activity/listen/data/report", map[string]any{"type": "week"}, &previous); err == nil {
		end := previous.Data.EndTime
		if duration := previous.Data.ListenTimeDistributionBlock.PlayDuration; duration != nil && end < score.StartTime && score.StartTime-end <= int64(48*time.Hour/time.Millisecond) {
			score.PreviousMinutes, score.ComparisonAvailable = *duration, true
		}
	}
	return score, nil
}

func HomeScoreComments(id int64) ([]Comment, error) {
	var reply Comments
	if err := webAPI("/api/v1/resource/hotcomments/R_SO_4_"+strconv.FormatInt(id, 10), map[string]any{"limit": 50, "offset": 0}, &reply); err != nil {
		return nil, err
	}
	return reply.Hot, nil
}
