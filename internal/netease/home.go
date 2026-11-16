package netease

import (
	"encoding/json"
	"strconv"
	"strings"
	"time"
)

type HomeRecommendation struct {
	ID                                       int64
	Album                                    bool
	Key, Title, Cover, Description, Category string
	Tracks                                   []Track
}

type homeText struct {
	Title string
}

type homeElement struct {
	MainTitle homeText
	SubTitle  homeText
	Image     struct{ ImageURL string }
}

// HomeRecommendations is the mobile home feed used by the Qt recommendation rail.
func HomeRecommendations() ([]HomeRecommendation, error) {
	var reply struct {
		Data struct {
			Blocks []struct {
				BlockCode string
				UIElement homeElement
				Creatives []struct {
					Resources []struct {
						ResourceID      json.RawMessage
						ResourceType    string
						Valid           *bool
						UIElement       homeElement
						ResourceExtInfo struct {
							SongData struct {
								Track
								Artists  []Artist `json:"artists"`
								Album    Album    `json:"album"`
								Duration int64    `json:"duration"`
							}
						}
					}
				}
			}
		}
	}
	if err := webAPI("/api/homepage/block/page", map[string]any{"refresh": false}, &reply); err != nil {
		return nil, err
	}
	var recommendations []HomeRecommendation
	seen := map[string]bool{}
	for _, block := range reply.Data.Blocks {
		code := block.BlockCode
		if strings.Contains(code, "PLAYLIST_RCMD") || strings.Contains(code, "TOPLIST") || strings.Contains(code, "DAILY") || strings.Contains(code, "PERSONAL_FM") {
			continue
		}
		category := block.UIElement.SubTitle.Title
		if category == "" {
			category = block.UIElement.MainTitle.Title
		}
		var songs []Track
		seenTracks := map[int64]bool{}
		for _, creative := range block.Creatives {
			for _, resource := range creative.Resources {
				if resource.Valid != nil && !*resource.Valid {
					continue
				}
				if resource.ResourceType == "song" {
					raw := resource.ResourceExtInfo.SongData
					song := raw.Track
					if len(song.Artists) == 0 {
						song.Artists = raw.Artists
					}
					if song.Album.ID == 0 {
						song.Album = raw.Album
					}
					if song.Duration == 0 {
						song.Duration = raw.Duration
					}
					if song.ID > 0 && !seenTracks[song.ID] {
						songs = append(songs, song)
						seenTracks[song.ID] = true
					}
					continue
				}
				if resource.ResourceType != "album" && resource.ResourceType != "list" {
					continue
				}
				id, _ := strconv.ParseInt(strings.Trim(string(resource.ResourceID), `"`), 10, 64)
				key := resource.ResourceType + ":" + strconv.FormatInt(id, 10)
				title := resource.UIElement.MainTitle.Title
				if id <= 0 || title == "" || seen[key] {
					continue
				}
				seen[key] = true
				cover := resource.UIElement.Image.ImageURL
				if strings.Contains(cover, ".music.126.net/") {
					cover, _, _ = strings.Cut(cover, "?")
				}
				recommendations = append(recommendations, HomeRecommendation{
					ID: id, Album: resource.ResourceType == "album", Key: key, Title: title, Cover: cover,
					Description: resource.UIElement.SubTitle.Title, Category: category,
				})
			}
		}
		key := "home:" + code
		if len(songs) > 0 && category != "" && !seen[key] {
			seen[key] = true
			names := make([]string, 0, 3)
			for _, song := range songs[:min(3, len(songs))] {
				names = append(names, song.Name)
			}
			recommendations = append(recommendations, HomeRecommendation{
				Key: key, Title: category, Cover: songs[0].Album.PicURL, Description: strings.Join(names, " · "),
				Category: "为你定制", Tracks: songs,
			})
		}
	}
	return recommendations, nil
}

type RecentlyPlayedPlaylist struct {
	Playlist Playlist
	At       time.Time
}

func RecentPlaylists(limit int) ([]RecentlyPlayedPlaylist, error) {
	var reply struct {
		Data struct {
			List []struct {
				Data     Playlist
				PlayTime int64
			}
		}
	}
	if err := webAPI("/api/play-record/playlist/list", map[string]any{"limit": limit}, &reply); err != nil {
		return nil, err
	}
	lists := make([]RecentlyPlayedPlaylist, 0, len(reply.Data.List))
	for _, record := range reply.Data.List {
		if record.Data.ID > 0 {
			lists = append(lists, RecentlyPlayedPlaylist{Playlist: record.Data, At: time.UnixMilli(record.PlayTime)})
		}
	}
	return lists, nil
}
