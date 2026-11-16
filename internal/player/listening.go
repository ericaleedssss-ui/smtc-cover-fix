package player

import (
	"time"

	"github.com/egoist/mygo"
)

const listeningInterval = 500 * time.Millisecond

func (p *Player) armListening() {
	if p.ListeningProgress == nil || p.track == nil || p.track.ProgramID != 0 ||
		p.out == nil || p.info == nil || p.loading || p.seeking || !p.playing {
		return
	}
	if p.listeningAt.IsZero() {
		p.listeningAt, p.listeningPosition = time.Now(), p.Position()
	}
	if p.listeningTimer != nil {
		return
	}
	var timer *time.Timer
	timer = time.AfterFunc(listeningInterval, func() {
		mygo.RunOnMain(func() {
			if p.listeningTimer != timer {
				return
			}
			p.listeningTimer = nil
			p.sampleListening(time.Now())
			p.armListening()
		})
	})
	p.listeningTimer = timer
}

func (p *Player) sampleListening(now time.Time) {
	if p.listeningAt.IsZero() || p.ListeningProgress == nil || p.out == nil || p.track == nil || p.seeking {
		return
	}
	position := p.Position()
	elapsed := confirmedListening(now.Sub(p.listeningAt), position-p.listeningPosition)
	p.listeningAt, p.listeningPosition = now, position
	if elapsed > 0 {
		p.ListeningProgress(*p.track, p.gen, position, elapsed, now)
	}
}

// A stall may advance less than wall time. Reject jumps and long gaps.
func confirmedListening(wall, movement time.Duration) time.Duration {
	if wall <= 0 || wall > 1500*time.Millisecond || movement <= 0 || movement > wall+250*time.Millisecond {
		return 0
	}
	return min(wall, movement)
}

// ResetListeningSample settles the last interval before playback or the account changes.
func (p *Player) ResetListeningSample() {
	p.sampleListening(time.Now())
	p.listeningAt = time.Time{}
	if p.listeningTimer != nil {
		p.listeningTimer.Stop()
		p.listeningTimer = nil
	}
}

// RestartListeningSample closes the previous account's interval.
func (p *Player) RestartListeningSample() {
	p.ResetListeningSample()
	p.armListening()
}
