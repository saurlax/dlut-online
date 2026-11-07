package realtime

import (
	"math"
	"testing"
	"testing/fstest"
	"time"
)

func testWorld(t *testing.T) *World {
	t.Helper()
	w, err := LoadWorld(fstest.MapFS{
		"campuses/eda/map.json":           {Data: []byte(`{"focus":[3,3],"offset":[0,0],"chunkSize":8,"textures":["grass-0","water-0"],"chunks":[{"x":0,"y":0,"layers":[[56,0,8,1]]}],"buildings":[{"id":"library","footprint":[[5,1],[6,1],[6,2],[5,2]]}]}`)},
		"campuses/eda/site-fixtures.json": {Data: []byte(`{"lamps":[{"position":[1.5,1.5]}],"noticeboards":[{"position":[2.5,1.5],"direction":[1,0],"width":1}]}`)},
	})
	if err != nil {
		t.Fatal(err)
	}
	return w
}

func TestWorldPlayersJoinAndLeaveWithoutSharingIdentity(t *testing.T) {
	w := testWorld(t)
	a, err := w.join(playerLook{Name: "Alice"})
	if err != nil {
		t.Fatal(err)
	}
	b, err := w.join(playerLook{Name: "Bob"})
	if err != nil {
		t.Fatal(err)
	}
	if a == b || len(w.snapshot(a).Players) != 2 {
		t.Fatal("players are not separately visible")
	}
	if w.players[a].X == w.players[b].X && w.players[a].Y == w.players[b].Y {
		t.Fatal("players spawned on top of each other")
	}
	w.leave(b)
	if len(w.snapshot(a).Players) != 1 {
		t.Fatal("disconnected player remains visible")
	}
}

func TestWorldLimitsSpeedAndRejectsStaleOrInvalidInputs(t *testing.T) {
	w := testWorld(t)
	id, err := w.join(playerLook{Name: "Alice"})
	if err != nil {
		t.Fatal(err)
	}
	p := w.players[id]
	now := p.clock
	x, y := p.X, p.Y
	input := movementInput{Seq: 1, X: 1, Y: 1, MS: 50}
	if err := w.input(id, 0, []movementInput{input}, now.Add(50*time.Millisecond)); err != nil {
		t.Fatal(err)
	}
	if distance := math.Hypot(p.X-x, p.Y-y); math.Abs(distance-2.4) > 0.00001 {
		t.Fatalf("diagonal speed: %f", distance)
	}
	x, y = p.X, p.Y
	if err := w.input(id, 0, []movementInput{input}, now.Add(50*time.Millisecond)); err != nil {
		t.Fatal(err)
	}
	if p.X != x || p.Y != y {
		t.Fatal("replayed input moved player twice")
	}
	for seq := 2; seq <= 30; seq++ {
		if err := w.input(id, 0, []movementInput{{Seq: seq, X: 1, MS: 50}}, now.Add(50*time.Millisecond)); err != nil {
			t.Fatal(err)
		}
	}
	if p.X-x > 7.2+0.00001 {
		t.Fatal("input flood bypassed server clock")
	}
	if err := w.input(id, 0, []movementInput{{Seq: 31, X: math.NaN(), MS: 50}}, now); err == nil {
		t.Fatal("invalid numeric input accepted")
	}
	if err := w.input(id, 0, []movementInput{{Seq: 31, X: 1, MS: 5000}}, now); err == nil {
		t.Fatal("unbounded simulation time accepted")
	}
}

func TestWorldCollisionsAndTravelInvalidateOldInputs(t *testing.T) {
	w := testWorld(t)
	for name, point := range map[string][2]float64{"water": {24, 120}, "building": {88, 24}, "lamp": {24, 24}, "noticeboard": {40, 24}, "outside": {-16, 0}} {
		if w.canStand(point[0], point[1]) {
			t.Errorf("%s is walkable", name)
		}
	}
	id, err := w.join(playerLook{Name: "Alice"})
	if err != nil {
		t.Fatal(err)
	}
	p := w.players[id]
	if !w.travel(id, "library") || !w.canStand(p.X, p.Y) {
		t.Fatal("registered landmark travel failed")
	}
	x, y := p.X, p.Y
	if err := w.input(id, 0, []movementInput{{Seq: 1, X: 1, MS: 50}}, time.Now()); err != nil {
		t.Fatal(err)
	}
	if p.X != x || p.Y != y || p.Ack != 0 {
		t.Fatal("old pre-travel input changed new position")
	}
	if w.travel(id, "arbitrary-position") {
		t.Fatal("unknown travel destination accepted")
	}
}
