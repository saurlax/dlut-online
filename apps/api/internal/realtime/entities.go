package realtime

import (
	"fmt"
	"math"
	"sort"
	"strings"
	"time"
)

type campusEntity struct {
	entityState
	Campus string `json:"campus"`
}

func (w *World) entities(now time.Time) []entityState {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.advanceAnimals(now)
	entities := make([]entityState, 0, len(w.players)+len(w.animals))
	for _, p := range w.players {
		entities = append(entities, p.entityState)
	}
	for _, a := range w.animals {
		entities = append(entities, a.entityState)
	}
	return entities
}

func campusEntities(campuses map[string]Campus) []campusEntity {
	var entities []campusEntity
	now := time.Now()
	for campus, region := range campuses {
		for _, entity := range region.World.entities(now) {
			entities = append(entities, campusEntity{entity, campus})
		}
	}
	sort.Slice(entities, func(i, j int) bool {
		a, b := entities[i], entities[j]
		if a.Campus != b.Campus {
			return a.Campus < b.Campus
		}
		if a.Kind != b.Kind {
			return a.Kind < b.Kind
		}
		return a.ID < b.ID
	})
	return entities
}

func entityList(campuses map[string]Campus) string {
	var names []string
	for _, e := range campusEntities(campuses) {
		if e.Name == "" {
			names = append(names, e.ID)
		} else {
			names = append(names, e.Name)
		}
	}
	return strings.Join(names, ", ")
}

func entityName(e entityState) string {
	if e.Name == "" {
		return "未命名"
	}
	return e.Name
}

func resolveEntity(campuses map[string]Campus, target string) (campusEntity, error) {
	var names, ids []campusEntity
	for _, e := range campusEntities(campuses) {
		if e.ID == target {
			return e, nil
		}
		if e.Name != "" && strings.EqualFold(e.Name, target) {
			names = append(names, e)
		}
		if strings.HasPrefix(e.ID, target) {
			ids = append(ids, e)
		}
	}
	matches := names
	if len(matches) == 0 {
		matches = ids
	}
	switch len(matches) {
	case 0:
		return campusEntity{}, fmt.Errorf("找不到目标，输入 /entity 查看")
	case 1:
		return matches[0], nil
	default:
		ids := make([]string, 0, len(matches))
		for _, match := range matches {
			ids = append(ids, match.ID)
		}
		return campusEntity{}, fmt.Errorf("匹配到多个实体，请指定 ID：%s", strings.Join(ids, ", "))
	}
}

func (w *World) travelToEntity(playerID, targetID string) bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.advanceAnimals(time.Now())
	if w.players[playerID].HP == 0 {
		return false
	}
	var target entityState
	if p := w.players[targetID]; p != nil {
		target = p.entityState
	} else {
		for _, a := range w.animals {
			if a.ID == targetID {
				target = a.entityState
				break
			}
		}
	}
	if target.ID == "" || target.ID == playerID {
		return false
	}
	return w.landNear(playerID, target.X, target.Y)
}

func (w *World) landNear(id string, x, y float64) bool {
	tx, ty := int(math.Floor(x/16)), int(math.Floor(y/16))
	best := math.Inf(1)
	var bestX, bestY float64
	for radius := 1; radius <= 96; radius++ {
		for dy := -radius; dy <= radius; dy++ {
			for dx := -radius; dx <= radius; dx++ {
				if max(abs(dx), abs(dy)) != radius {
					continue
				}
				px, py := float64(tx+dx)*16+8, float64(ty+dy)*16+8
				d := math.Hypot(px-x, py-y)
				if d < 16 || d >= best || !w.canStand(px, py) {
					continue
				}
				best, bestX, bestY = d, px, py
			}
		}
		if best <= float64(radius)*16 {
			w.relocate(id, bestX, bestY)
			return true
		}
	}
	if !math.IsInf(best, 1) {
		w.relocate(id, bestX, bestY)
		return true
	}
	return false
}
