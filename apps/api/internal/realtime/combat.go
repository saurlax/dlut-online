package realtime

import (
	"math"
	"time"
)

const (
	attackReach       = 1.9 * 16
	attackWindup      = 240 * time.Millisecond
	respawnDelay      = 4 * time.Second
	respawnProtection = 4 * time.Second
	damageFeedbackTTL = time.Second
)

type damageHit struct {
	ID int     `json:"id"`
	At int64   `json:"at"`
	X  float64 `json:"x"`
	Y  float64 `json:"y"`
}

type animalAttack struct {
	damage   int
	cooldown time.Duration
	cause    string
}

var animalAttacks = map[string]animalAttack{
	"boar": {22, 1350 * time.Millisecond, "被野猪撞死了"},
	"dog":  {15, 1150 * time.Millisecond, "被大狗咬死了"},
}

// Only the selected pursuit target can be hit, and only if still in reach at impact.
func (w *World) attackPlayer(a *animal, p *playerState, now time.Time) bool {
	if p == nil || a.attackTarget != "" && a.attackTarget != p.ID {
		a.attackTarget = ""
		return false
	}
	inReach := func() bool {
		return math.Hypot(p.X-a.X, p.Y-a.Y) <= attackReach && w.clearAnimalPath(p, a)
	}
	rule := animalAttacks[a.Kind]
	if a.attackTarget != "" {
		if now.Before(a.strikeAt) {
			return true
		}
		a.attackTarget = ""
		if inReach() {
			p.HP = max(0, p.HP-rule.damage)
			p.hitSequence++
			if len(p.hits) == 6 {
				copy(p.hits, p.hits[1:])
				p.hits = p.hits[:5]
			}
			p.hits = append(p.hits, damageHit{p.hitSequence, now.UnixMilli(), a.X - p.X, a.Y - p.Y})
			if p.HP == 0 {
				p.DeathAt, p.RespawnAt = now.UnixMilli(), now.Add(respawnDelay).UnixMilli()
				p.DeathCause = rule.cause
				p.Moving, p.Sprint = false, false
				p.Revision++
				a.chaseTarget, a.returning = "", true
				if w.onDeath != nil {
					w.onDeath(p.Name, p.DeathCause)
				}
			}
		}
		return false
	}
	if now.Before(a.nextAttack) || !inReach() {
		return false
	}
	a.AttackAt = now.UnixMilli()
	a.attackTarget = p.ID
	a.strikeAt = now.Add(attackWindup)
	a.nextAttack = now.Add(rule.cooldown)
	if p.X < a.X {
		a.Facing = -1
	} else {
		a.Facing = 1
	}
	return true
}

func (w *World) respawnPlayers(now time.Time) {
	for _, p := range w.players {
		if p.HP != 0 || now.UnixMilli() < p.RespawnAt {
			continue
		}
		x, y := w.respawnPosition(p.X, p.Y)
		w.relocate(p.ID, x, y)
		p.HP, p.DeathAt, p.RespawnAt, p.DeathCause = maxHealth, 0, 0, ""
		p.hits = p.hits[:0]
		p.ProtectedUntil = now.Add(respawnProtection).UnixMilli()
		p.clock, p.credit = now, 150
	}
}

func (w *World) respawnPosition(x, y float64) (float64, float64) {
	bestX, bestY, best := x, y, math.Inf(-1)
	for dy := -12; dy <= 12; dy++ {
		for dx := -12; dx <= 12; dx++ {
			distance := math.Hypot(float64(dx), float64(dy))
			if distance < 5 || distance > 12 {
				continue
			}
			px, py := x+float64(dx)*16, y+float64(dy)*16
			clearance := 12.0
			for _, a := range w.animals {
				if _, hostile := animalAttacks[a.Kind]; hostile {
					clearance = min(clearance, math.Hypot(px-a.X, py-a.Y)/16)
				}
			}
			score := clearance - 0.35*distance
			if score > best && w.canStand(px, py) {
				bestX, bestY, best = px, py, score
			}
		}
	}
	return bestX, bestY
}
