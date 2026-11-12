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
		"campuses/eda/animals.json":       {Data: []byte(`[]`)},
	}, "eda")
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

func TestEntityTeleportUsesSafeLandings(t *testing.T) {
	w := testWorld(t)
	now := time.Now()
	w.loadAnimals([]animalDefinition{
		{ID: "eda-duck", Kind: "duck", Route: [][2]float64{{3.5, 7.5}, {4.5, 7.5}}},
	}, now)
	self, err := w.join(playerLook{Name: "Alice"})
	if err != nil {
		t.Fatal(err)
	}
	target, err := w.join(playerLook{Name: "Bob"})
	if err != nil {
		t.Fatal(err)
	}
	w.players[target].X, w.players[target].Y = 56, 56
	player := w.players[self]
	if !w.travelToEntity(self, target) || player.Revision != 1 ||
		math.Hypot(player.X-56, player.Y-56) != 16 || !w.canStand(player.X, player.Y) {
		t.Fatalf("did not arrive on walkable ground next to player: %+v", player)
	}
	if !w.travelToEntity(self, "eda-duck") || player.Revision != 2 || player.Y != 6.5*16 {
		t.Fatalf("did not arrive on the shore: %+v", player)
	}
	if w.travelToEntity(self, "missing") || w.travelToEntity(self, self) || player.Revision != 2 {
		t.Fatal("failed teleport changed the player")
	}
}

func TestAnimalGroupSteersIndependentlyNearShore(t *testing.T) {
	w := testWorld(t)
	for i := 4 * 8; i < 8*8; i++ {
		w.ground[[2]int{0, 0}][i] = waterGround
	}
	now := time.Now()
	err := w.loadAnimals([]animalDefinition{
		{ID: "duck-1", Kind: "duck", Route: [][2]float64{{2, 4.6}, {5.5, 4.6}, {5.5, 7}, {2, 7}}},
		{ID: "duck-2", Kind: "duck", Follow: "duck-1", Offset: [2]float64{1.5, 2}},
		{ID: "duck-3", Kind: "duck", Follow: "duck-1", Offset: [2]float64{-1, 1}},
	}, now)
	if err != nil {
		t.Fatal(err)
	}
	start := append([]animal(nil), w.animals...)
	travel := make([]float64, len(start))
	changedSpacing := false
	for tick := 1; tick <= 400; tick++ {
		before := append([]animal(nil), w.animals...)
		w.advanceAnimals(now.Add(time.Duration(tick) * 100 * time.Millisecond))
		guide := w.flocks[0].guide
		for i, member := range w.animals {
			if !w.flockCanOccupy(member.X, member.Y, true) {
				t.Fatalf("duck %s left the water on tick %d", member.ID, tick)
			}
			if math.Hypot(member.X-guide.X, member.Y-guide.Y) > 6*16 {
				t.Fatalf("duck %s drifted away on tick %d", member.ID, tick)
			}
			travel[i] += math.Hypot(member.X-before[i].X, member.Y-before[i].Y)
		}
		current := math.Hypot(w.animals[0].X-w.animals[1].X, w.animals[0].Y-w.animals[1].Y)
		initial := math.Hypot(start[0].X-start[1].X, start[0].Y-start[1].Y)
		changedSpacing = changedSpacing || math.Abs(current-initial) > 8
	}
	for i, distance := range travel {
		if distance < 8*16 {
			t.Fatalf("duck %s barely moved", w.animals[i].ID)
		}
	}
	if !changedSpacing {
		t.Fatal("the group moved as a rigid formation")
	}
}

func TestBoarsSpreadOutAndRegroup(t *testing.T) {
	w := testWorld(t)
	now := time.Now()
	// Open terrain leaves room for scattering in any direction.
	cells := make([]groundType, 64)
	for i := range cells {
		cells[i] = walkableGround
	}
	for y := 0; y < 32; y += 8 {
		for x := 0; x < 32; x += 8 {
			w.ground[[2]int{x, y}] = cells
		}
	}
	if err := w.loadAnimals([]animalDefinition{
		{ID: "boar-1", Kind: "boar", Route: [][2]float64{{11, 11}, {22, 11}, {22, 22}, {11, 22}}},
		{ID: "boar-2", Kind: "boar", Follow: "boar-1", Offset: [2]float64{-2.5, 2.5}},
		{ID: "boar-3", Kind: "boar", Follow: "boar-1", Offset: [2]float64{2.5, 2}},
		{ID: "boar-4", Kind: "boar", Follow: "boar-1", Offset: [2]float64{0, 4.75}},
	}, now); err != nil {
		t.Fatal(err)
	}
	var widest float64
	regrouped := math.Inf(1)
	for tick := 1; tick <= 340; tick++ {
		w.advanceAnimals(now.Add(time.Duration(tick) * 100 * time.Millisecond))
		diameter := 0.0
		for i, a := range w.animals {
			for _, b := range w.animals[i+1:] {
				diameter = max(diameter, math.Hypot(a.X-b.X, a.Y-b.Y)/16)
			}
		}
		if w.flocks[0].scatterTarget > 0 {
			widest = max(widest, diameter)
		} else if widest > 0 {
			regrouped = min(regrouped, diameter)
		}
	}
	if widest < 5.5 || widest-regrouped < 2 {
		t.Fatalf("herd should spread out and regroup, got %.2f m then %.2f m", widest, regrouped)
	}
}

func TestLandAnimalsSeeChaseAndReturn(t *testing.T) {
	for _, kind := range []string{"boar", "dog"} {
		t.Run(kind, func(t *testing.T) {
			w := testWorld(t)
			cells := make([]groundType, 64)
			for i := range cells {
				cells[i] = walkableGround
			}
			for x := 8; x < 32; x += 8 {
				w.ground[[2]int{x, 0}] = cells
			}
			now := time.Now()
			if err := w.loadAnimals([]animalDefinition{
				{ID: "one", Kind: kind, Route: [][2]float64{{4.2, 1.5}, {4.2, 5.5}, {3.2, 5.5}}},
				{ID: "two", Kind: kind, Follow: "one", Offset: [2]float64{-1.5, 0.8}},
			}, now); err != nil {
				t.Fatal(err)
			}
			id, err := w.join(playerLook{Name: "Player"})
			if err != nil {
				t.Fatal(err)
			}
			player := w.players[id]
			a := &w.animals[0]
			tick := 0
			step := func(count int) {
				for range count {
					tick++
					w.advanceAnimals(now.Add(time.Duration(tick) * 100 * time.Millisecond))
				}
			}
			player.X, player.Y = 6.5*16, 1.5*16
			step(1)
			if a.chaseTarget != "" {
				t.Fatal("detected the player through a building")
			}
			player.X, player.Y = 4.5*16, 5.5*16
			step(1)
			if a.chaseTarget != id || a.Pose != "chase" {
				t.Fatal("visible player did not trigger a chase")
			}
			start := math.Hypot(player.X-a.X, player.Y-a.Y)
			step(9)
			if math.Hypot(player.X-a.X, player.Y-a.Y) >= start-16 {
				t.Fatal("animal did not close the distance")
			}
			player.X = 13.5 * 16
			step(1)
			if a.chaseTarget != id {
				t.Fatal("animal lost a target beyond sight but still in pursuit range")
			}
			step(15)
			player.X = 30.5 * 16
			step(1)
			if a.Pose == "chase" || !a.returning {
				t.Fatal("animal did not break off and start returning")
			}
			if kind == "boar" {
				player.X, player.Y = a.X+16, a.Y
				step(1)
				if a.chaseTarget != id || a.Pose != "chase" || a.returning {
					t.Fatal("approaching a returning boar did not trigger a second chase")
				}
				player.X = 30.5 * 16
				step(1)
				if a.Pose == "chase" || !a.returning {
					t.Fatal("boar did not return after the second chase")
				}
			}
			step(100)
			if a.returning || math.Hypot(a.X-w.flocks[0].guide.X, a.Y-w.flocks[0].guide.Y) > 6*16 {
				t.Fatal("animal did not rejoin the group")
			}
		})
	}
}

func TestSpawnRegionRespectsCollisionsAndPlayerSpacing(t *testing.T) {
	w := testWorld(t)
	for i := 0; i < 16; i++ {
		id, err := w.join(playerLook{Name: "Guest"})
		if err != nil {
			t.Fatal(err)
		}
		p := w.players[id]
		if math.Abs(p.X-w.spawn[0]) > 120 || math.Abs(p.Y-w.spawn[1]) > 120 || !w.canStand(p.X, p.Y) {
			t.Fatal("spawn left its walkable local region")
		}
		for otherID, other := range w.players {
			if otherID != id && math.Hypot(p.X-other.X, p.Y-other.Y) < 16 {
				t.Fatal("spawn overlaps another player")
			}
		}
	}
}

func TestBuildingCourtyardRemainsWalkable(t *testing.T) {
	w := testWorld(t)
	b := &w.campus.Buildings[0]
	b.Footprint = [][2]float64{{3, 1}, {7, 1}, {7, 5}, {3, 5}}
	b.Holes = [][][2]float64{{{4, 2}, {6, 2}, {6, 4}, {4, 4}}}
	if !w.canStand(80, 48) || w.canStand(56, 48) {
		t.Fatal("courtyard opening and solid building walls must have different collision")
	}
}

func TestSportsCollisionUsesStructuresInsteadOfWholeField(t *testing.T) {
	w := testWorld(t)
	b := &w.campus.Buildings[0]
	b.Footprint = [][2]float64{{3, 1}, {7, 1}, {7, 5}, {3, 5}}
	b.CollisionPolygons = [][][2]float64{{{3, 1}, {4, 1}, {3, 5}}}
	if !w.canStand(80, 48) || w.canStand(52.8, 32) {
		t.Fatal("field must remain open while registered stand geometry blocks movement")
	}
}

func TestWorldLimitsSpeedAndRejectsStaleOrInvalidInputs(t *testing.T) {
	w := testWorld(t)
	id, err := w.join(playerLook{Name: "Alice"})
	if err != nil {
		t.Fatal(err)
	}
	p := w.players[id]
	p.X, p.Y = w.spawn[0], w.spawn[1]
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
