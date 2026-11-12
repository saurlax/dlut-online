package realtime

import (
	"fmt"
	"math"
	"time"
)

const interactionRange = 2.75 * 16
const petDuration = 1450 * time.Millisecond

type animalDefinition struct {
	ID, Kind, Name, Temperament, Follow string
	Route                               [][2]float64
	Offset                              [2]float64
}

type animalState struct {
	entityState
	Facing   int    `json:"facing"`
	Pose     string `json:"pose"`
	PetAt    int64  `json:"petAt,omitempty"`
	AttackAt int64  `json:"attackAt,omitempty"`
}

type routeLeg struct{ x, y, dx, dy, length float64 }

type animal struct {
	animalState
	temperament          string
	legs                 []routeLeg
	index, leg           int
	progress             float64
	rest, flee, pet      time.Time
	fleeDirection        int
	flocking             bool
	vx, vy               float64
	chaseTarget          string
	returning            bool
	attackTarget         string
	strikeAt, nextAttack time.Time
}

func (w *World) loadAnimals(definitions []animalDefinition, now time.Time) error {
	w.animalTick = now
	leaders := make(map[string]int)
	groups := make(map[string]int)
	for i, d := range definitions {
		a := animal{
			animalState: animalState{entityState: entityState{ID: d.ID, Kind: d.Kind, Name: d.Name, HP: maxHealth}, Facing: 1, Pose: "idle"},
			temperament: d.Temperament, index: i, rest: now.Add(2200 * time.Millisecond),
		}
		if d.Follow != "" {
			leader, ok := leaders[d.Follow]
			if !ok || w.animals[leader].Kind != d.Kind || d.Kind == "cat" {
				return fmt.Errorf("animal %s has invalid group leader %s", d.ID, d.Follow)
			}
			routeAnimal := &w.animals[leader]
			group, exists := groups[d.Follow]
			if !exists {
				group = len(w.flocks)
				groups[d.Follow] = group
				w.flocks = append(w.flocks, animalFlock{guide: *routeAnimal, members: []int{leader}, next: make([][2]float64, 1)})
				routeAnimal.flocking = true
			}
			a.X, a.Y = routeAnimal.X+d.Offset[0]*16, routeAnimal.Y+d.Offset[1]*16
			a.Pose, a.flocking = "walk", true
			flock := &w.flocks[group]
			flock.members = append(flock.members, len(w.animals))
			flock.next = append(flock.next, [2]float64{})
			w.animals = append(w.animals, a)
			continue
		}
		if len(d.Route) < 2 {
			return fmt.Errorf("animal %s needs a route with at least two points", d.ID)
		}
		a.leg = i % len(d.Route)
		for j, point := range d.Route {
			next := d.Route[(j+1)%len(d.Route)]
			dx, dy := (next[0]-point[0])*16, (next[1]-point[1])*16
			a.legs = append(a.legs, routeLeg{point[0] * 16, point[1] * 16, dx, dy, math.Hypot(dx, dy)})
		}
		a.place()
		if a.Kind != "cat" {
			a.Pose = "walk"
		}
		leaders[d.ID] = len(w.animals)
		w.animals = append(w.animals, a)
	}
	return nil
}

func (a *animal) place() {
	leg := a.legs[a.leg]
	a.X, a.Y = leg.x+leg.dx*a.progress, leg.y+leg.dy*a.progress
}

// Called under the world lock. Multiple connections share one simulation clock.
func (w *World) advanceAnimals(now time.Time) {
	elapsed := now.Sub(w.animalTick)
	if elapsed < 50*time.Millisecond {
		return
	}
	w.animalTick = now
	delta := min(elapsed, 100*time.Millisecond).Seconds()
	w.respawnPlayers(now)
	for i := range w.animals {
		a := &w.animals[i]
		switch {
		case a.flocking:
			continue
		case a.Kind == "cat":
			w.updateCat(a, now, delta)
		case a.Kind == "dog" || a.Kind == "boar":
			a.move(1, 1.05, delta)
		default:
			a.move(1, 0.65, delta)
		}
	}
	for i := range w.flocks {
		w.advanceFlock(&w.flocks[i], now, delta)
	}
}

func (a *animal) move(direction int, speed, delta float64) bool {
	count := len(a.legs)
	if direction < 0 && a.progress == 0 {
		a.leg = (a.leg + count - 1) % count
		a.progress = 1
	}
	leg := a.legs[a.leg]
	a.progress = max(0, min(1, a.progress+float64(direction)*speed*16*delta/leg.length))
	a.Facing = 1
	if leg.dx*float64(direction) < 0 {
		a.Facing = -1
	}
	arrived := a.progress == 1
	if arrived {
		a.leg, a.progress = (a.leg+1)%count, 0
	}
	a.place()
	return arrived
}

func (w *World) nearestAnimalPlayer(a *animal, radius float64, now time.Time) *playerState {
	var nearest *playerState
	_, hostile := animalAttacks[a.Kind]
	for _, p := range w.players {
		if p.HP == 0 || hostile && now.UnixMilli() < p.ProtectedUntil {
			continue
		}
		d := math.Hypot(p.X-a.X, p.Y-a.Y)
		if d < radius && w.clearAnimalPath(p, a) {
			radius, nearest = d, p
		}
	}
	return nearest
}

func (w *World) updateCat(a *animal, now time.Time, delta float64) {
	if now.Sub(a.pet) < petDuration {
		a.Pose = "happy"
		return
	}
	radius, speed := 2.5, 0.0
	switch a.temperament {
	case "wary":
		radius, speed = 2.8, 2.1
	case "shy":
		radius, speed = 4.5, 3
	}
	nearby := w.nearestAnimalPlayer(a, radius*16, now)
	if nearby != nil && speed > 0 {
		if !now.Before(a.flee) {
			forward, back := a.legs[a.leg], a.legs[a.leg]
			if a.progress == 0 {
				back = a.legs[(a.leg+len(a.legs)-1)%len(a.legs)]
			}
			x, y := a.X-nearby.X, a.Y-nearby.Y
			a.fleeDirection = 1
			if -(back.dx*x+back.dy*y)/back.length > (forward.dx*x+forward.dy*y)/forward.length {
				a.fleeDirection = -1
			}
		}
		a.flee = now.Add(850 * time.Millisecond)
		a.rest = time.Time{}
	}
	restPose := [...]string{"idle", "sleep", "groom"}
	switch {
	case now.Before(a.flee):
		a.move(a.fleeDirection, speed, delta)
		a.Pose = "flee"
	case now.Before(a.rest):
		a.Pose = restPose[(a.leg+a.index)%len(restPose)]
	case nearby != nil && a.temperament == "friendly":
		a.Facing, a.Pose = 1, "idle"
		if nearby.X < a.X {
			a.Facing = -1
		}
	default:
		a.Pose = "walk"
		if a.move(1, 0.85, delta) {
			a.rest = now.Add(4500 * time.Millisecond)
			if restPose[(a.leg+a.index)%len(restPose)] == "sleep" {
				a.rest = now.Add(9 * time.Second)
			}
		}
	}
}

func (w *World) clearAnimalPath(p *playerState, a *animal) bool {
	dx, dy := a.X-p.X, a.Y-p.Y
	steps := int(math.Ceil(math.Hypot(dx, dy) / 8))
	for step := 1; step <= steps; step++ {
		fraction := float64(step) / float64(steps)
		if !w.canStand(p.X+dx*fraction, p.Y+dy*fraction) {
			return false
		}
	}
	return true
}

func (w *World) petAnimal(playerID, targetID string, now time.Time) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.advanceAnimals(now)
	p := w.players[playerID]
	if p.HP == 0 {
		return
	}
	for i := range w.animals {
		a := &w.animals[i]
		if a.ID == targetID && a.temperament == "friendly" && now.Sub(a.pet) >= petDuration &&
			math.Hypot(p.X-a.X, p.Y-a.Y) < interactionRange && w.clearAnimalPath(p, a) {
			a.pet, a.PetAt, a.Pose = now, now.UnixMilli(), "happy"
			return
		}
	}
}
