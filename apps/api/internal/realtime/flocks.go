package realtime

import (
	"math"
	random "math/rand/v2"
)

type animalFlock struct {
	guide                                                     animal
	members                                                   []int
	next                                                      [][2]float64
	elapsed                                                   float64
	scatter, scatterTarget, scatterHeading, nextScatterChange float64
}

func (flock *animalFlock) updateScatter(delta float64) {
	if flock.nextScatterChange == 0 {
		flock.nextScatterChange = flock.elapsed + 3 + 8*random.Float64()
	}
	if flock.elapsed >= flock.nextScatterChange {
		if flock.scatterTarget == 0 {
			flock.scatterTarget = 0.7 + 0.3*random.Float64()
			flock.scatterHeading = 2 * math.Pi * random.Float64()
			flock.nextScatterChange = flock.elapsed + 5 + 7*random.Float64()
		} else {
			flock.scatterTarget = 0
			flock.nextScatterChange = flock.elapsed + 5 + 10*random.Float64()
		}
	}
	flock.scatter += (flock.scatterTarget - flock.scatter) * min(1, 1.4*delta)
}

// The route guides the flock as a whole. Each animal steers from the previous
// positions and velocities, so changing the update order cannot change the flock.
func (w *World) advanceFlock(flock *animalFlock, delta float64) {
	const meters = 16
	water := flock.guide.Kind == "swan" || flock.guide.Kind == "duck"
	boar := flock.guide.Kind == "boar"
	pursuesPlayers := boar || flock.guide.Kind == "dog"
	speed, spacing := 1.05, 2.4
	if water {
		speed = 0.65
	}
	if flock.guide.Kind == "duck" {
		spacing = 1.65
	}
	flock.elapsed += delta
	guide := &flock.guide
	guide.move(1, speed, delta)
	leg := guide.legs[guide.leg]
	routeX, routeY := speed*leg.dx/leg.length, speed*leg.dy/leg.length
	spread := 0.0
	if boar {
		flock.updateScatter(delta)
		spread = flock.scatter
		spacing += 0.8 * spread
	}
	for slot, index := range flock.members {
		a := &w.animals[index]
		var centerX, centerY, averageX, averageY, separateX, separateY float64
		neighbors := 0
		for _, other := range flock.members {
			if other == index {
				continue
			}
			b := &w.animals[other]
			dx, dy := (b.X-a.X)/meters, (b.Y-a.Y)/meters
			distance := math.Hypot(dx, dy)
			if distance > 7 {
				continue
			}
			neighbors++
			centerX, centerY = centerX+dx, centerY+dy
			averageX, averageY = averageX+b.vx, averageY+b.vy
			if distance > 0 && distance < spacing {
				repel := 1.65 * (spacing - distance) / distance
				separateX, separateY = separateX-repel*dx, separateY-repel*dy
			}
		}
		phase := float64(slot) * 2.4
		targetX := routeX + 0.38*(guide.X-a.X)/meters + separateX + 0.28*math.Sin(flock.elapsed*1.17+phase)
		targetY := routeY + 0.38*(guide.Y-a.Y)/meters + separateY + 0.28*math.Cos(flock.elapsed*0.89+phase)
		if boar {
			angle := float64(slot)*2*math.Pi/float64(len(flock.members)) + flock.scatterHeading
			targetX += 2.3 * spread * math.Cos(angle)
			targetY += 2.3 * spread * math.Sin(angle)
		}
		if neighbors > 0 {
			count := float64(neighbors)
			cohesion := 0.19 * (1 - 0.8*spread)
			alignment := 0.38 * (1 - 0.65*spread)
			targetX += cohesion*centerX/count + alignment*(averageX/count-a.vx)
			targetY += cohesion*centerY/count + alignment*(averageY/count-a.vy)
		}
		maxSpeed := speed * (1.4 + 0.18*math.Sin(flock.elapsed*0.62+phase))
		if pursuesPlayers {
			if player := w.pursuitTarget(a, guide); player != nil {
				dx, dy := (player.X-a.X)/meters, (player.Y-a.Y)/meters
				distance := math.Hypot(dx, dy)
				// Keep room both around the target and between pursuing animals.
				approach := 3 * (distance - 1.3) / max(distance, 0.1)
				targetX, targetY = approach*dx+separateX, approach*dy+separateY
				maxSpeed = 3.65
				if boar {
					maxSpeed = 4.25
				}
			} else if a.returning {
				targetX, targetY = (guide.X-a.X)/meters, (guide.Y-a.Y)/meters
				maxSpeed = 2.8
			}
		}
		if magnitude := math.Hypot(targetX, targetY); magnitude > maxSpeed {
			targetX, targetY = targetX*maxSpeed/magnitude, targetY*maxSpeed/magnitude
		}
		blend := min(1, 2.8*delta)
		vx, vy := a.vx+(targetX-a.vx)*blend, a.vy+(targetY-a.vy)*blend
		flock.next[slot] = w.flockVelocity(a, vx, vy, delta, water)
	}
	for slot, index := range flock.members {
		a := &w.animals[index]
		a.vx, a.vy = flock.next[slot][0], flock.next[slot][1]
		a.X, a.Y = a.X+a.vx*delta*meters, a.Y+a.vy*delta*meters
		a.Pose = "idle"
		if math.Hypot(a.vx, a.vy) > 0.12 {
			a.Pose = "walk"
		}
		if a.chaseTarget != "" {
			a.Pose = "chase"
		}
		if a.vx > 0.08 {
			a.Facing = 1
		} else if a.vx < -0.08 {
			a.Facing = -1
		}
	}
}

func (w *World) pursuitTarget(a, guide *animal) *playerState {
	const territory = 18 * 16
	const pursuitDistance = 15 * 16
	if a.chaseTarget != "" {
		player := w.players[a.chaseTarget]
		if player != nil && math.Hypot(player.X-a.X, player.Y-a.Y) < pursuitDistance &&
			nearAnimalRoute(player.X, player.Y, guide.legs, territory) &&
			nearAnimalRoute(a.X, a.Y, guide.legs, territory) {
			return player
		}
		a.chaseTarget, a.returning = "", true
	}
	if a.returning {
		if math.Hypot(a.X-guide.X, a.Y-guide.Y) < 4*16 {
			a.returning = false
		}
		if a.Kind != "boar" || !nearAnimalRoute(a.X, a.Y, guide.legs, territory) {
			return nil
		}
	}
	sight := 9.0 * 16
	if a.Kind == "boar" {
		sight = 8 * 16
	}
	player := w.nearestAnimalPlayer(a, sight)
	if player != nil && nearAnimalRoute(player.X, player.Y, guide.legs, territory) {
		a.chaseTarget, a.returning = player.ID, false
		return player
	}
	return nil
}

func nearAnimalRoute(x, y float64, legs []routeLeg, radius float64) bool {
	for _, leg := range legs {
		dx, dy := x-leg.x, y-leg.y
		fraction := max(0, min(1, (dx*leg.dx+dy*leg.dy)/(leg.length*leg.length)))
		if math.Hypot(dx-leg.dx*fraction, dy-leg.dy*fraction) < radius {
			return true
		}
	}
	return false
}

func (w *World) flockVelocity(a *animal, vx, vy, delta float64, water bool) [2]float64 {
	for _, angle := range [...]float64{0, math.Pi / 5, -math.Pi / 5, math.Pi / 2, -math.Pi / 2} {
		sin, cos := math.Sincos(angle)
		x, y := vx*cos-vy*sin, vx*sin+vy*cos
		if w.flockCanOccupy(a.X+x*delta*16, a.Y+y*delta*16, water) &&
			w.flockCanOccupy(a.X+x*0.45*16, a.Y+y*0.45*16, water) {
			return [2]float64{x, y}
		}
	}
	return [2]float64{}
}

func (w *World) flockCanOccupy(x, y float64, water bool) bool {
	if !water {
		return w.canStand(x, y)
	}
	return w.groundAt(x, y) == waterGround &&
		w.groundAt(x-5, y) == waterGround && w.groundAt(x+5, y) == waterGround &&
		w.groundAt(x, y-5) == waterGround && w.groundAt(x, y+5) == waterGround
}
