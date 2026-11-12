package realtime

import (
	"math"
	"testing"
	"time"
)

func TestAnimalAttackWindupDeathAndRespawn(t *testing.T) {
	w := testWorld(t)
	id, err := w.join(playerLook{Name: "测试玩家"})
	if err != nil {
		t.Fatal(err)
	}
	p := w.players[id]
	p.X, p.Y = 4*16, 4*16
	a := &animal{animalState: animalState{entityState: entityState{Kind: "boar", X: 3 * 16, Y: 4 * 16}}}
	now := time.Now()
	if !w.attackPlayer(a, p, now) || p.HP != 100 || a.AttackAt != now.UnixMilli() {
		t.Fatal("attack did not begin with a windup")
	}
	p.X = 6 * 16
	w.attackPlayer(a, p, now.Add(attackWindup))
	if p.HP != 100 || len(p.hits) != 0 {
		t.Fatal("attack landed after the player moved out of reach")
	}
	p.X = 4 * 16
	if w.attackPlayer(a, p, now.Add(2*attackWindup)) {
		t.Fatal("animal attacked again before its cooldown expired")
	}
	deaths := 0
	w.onDeath = func(name, cause string) {
		if name != p.Name || cause != animalAttacks["boar"].cause {
			t.Fatalf("incorrect death announcement: %q %q", name, cause)
		}
		deaths++
	}
	for hit := 1; hit <= 5; hit++ {
		now = now.Add(2 * time.Second)
		w.attackPlayer(a, p, now)
		w.attackPlayer(a, p, now.Add(attackWindup))
		if p.HP != max(0, 100-hit*22) {
			t.Fatalf("unexpected HP after hit %d: %d", hit, p.HP)
		}
	}
	if deaths != 1 || p.DeathAt == 0 || p.RespawnAt-p.DeathAt != respawnDelay.Milliseconds() {
		t.Fatal("death was not recorded once with a respawn deadline")
	}
	if len(p.hits) != 5 || p.hits[4] != (damageHit{5, p.DeathAt, -16, 0}) {
		t.Fatalf("hit feedback did not record the attack direction at impact: %+v", p.hits)
	}
	x, y := p.X, p.Y
	err = w.input(id, p.Revision, []movementInput{{Seq: 1, X: 1, MS: 50}}, now)
	if err != nil || p.X != x || p.Y != y {
		t.Fatal("dead player could move")
	}
	respawn := time.UnixMilli(p.RespawnAt)
	w.respawnPlayers(respawn.Add(-time.Millisecond))
	if p.HP != 0 {
		t.Fatal("player respawned before the deadline")
	}
	w.respawnPlayers(respawn)
	distance := math.Hypot(p.X-x, p.Y-y)
	if p.HP != 100 || p.DeathAt != 0 || distance < 5*16 || distance > 12*16 || !w.canStand(p.X, p.Y) {
		t.Fatal("player did not respawn at full health on nearby walkable ground")
	}
	a.X, a.Y = p.X, p.Y
	if w.nearestAnimalPlayer(a, attackReach, respawn) != nil ||
		w.nearestAnimalPlayer(a, attackReach, respawn.Add(respawnProtection)) != p {
		t.Fatal("respawn protection was not limited to its scheduled duration")
	}
}
