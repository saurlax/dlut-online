package realtime

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/fs"
	"math"
	random "math/rand/v2"
	"strings"
	"sync"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/saurlax/dlut-online/apps/api/internal/characters"
	"github.com/saurlax/dlut-online/apps/api/internal/guest"
)

const walkSpeed = 48.0 // Native pixels per second; 16 pixels = 1 meter.

type movementInput struct {
	Seq    int     `json:"seq"`
	X      float64 `json:"x"`
	Y      float64 `json:"y"`
	MS     float64 `json:"ms"`
	Sprint bool    `json:"sprint"`
}

type outfit struct {
	Key   string `json:"key"`
	Color int    `json:"color"`
}

type playerLook struct {
	Name       string                `json:"name"`
	Gender     string                `json:"gender"`
	Appearance characters.Appearance `json:"appearance"`
	Wear       []outfit              `json:"wear"`
}

// Public IDs are connection IDs; account IDs and guest tokens never leave the server.
type playerState struct {
	ID        string     `json:"id"`
	X         float64    `json:"x"`
	Y         float64    `json:"y"`
	Direction int        `json:"direction"`
	Moving    bool       `json:"moving"`
	Sprint    bool       `json:"sprint"`
	Ack       int        `json:"ack"`
	Revision  int        `json:"revision"`
	Look      playerLook `json:"look"`
	clock     time.Time
	credit    float64
}

type worldSnapshot struct {
	SelfID  string        `json:"selfId"`
	Players []playerState `json:"players"`
}

type campusData struct {
	Focus     [2]float64 `json:"focus"`
	Offset    [2]float64 `json:"offset"`
	ChunkSize int        `json:"chunkSize"`
	Textures  []string   `json:"textures"`
	Chunks    []struct {
		X, Y   int
		Layers [][]int
	} `json:"chunks"`
	Buildings []struct {
		ID                string         `json:"id"`
		Footprint         [][2]float64   `json:"footprint"`
		Holes             [][][2]float64 `json:"holes"`
		CollisionPolygons [][][2]float64 `json:"collisionPolygons"`
	} `json:"buildings"`
}

type fixtureData struct {
	Lamps        []struct{ Position [2]float64 } `json:"lamps"`
	Noticeboards []struct {
		Position, Direction [2]float64
		Width               float64
	} `json:"noticeboards"`
}

type World struct {
	mu       sync.Mutex
	players  map[string]*playerState
	campus   campusData
	fixtures fixtureData
	ground   map[[2]int][]bool
	spawn    [2]float64
}

func LoadWorld(public fs.FS, campus string) (*World, error) {
	w := &World{players: map[string]*playerState{}, ground: map[[2]int][]bool{}}
	for name, target := range map[string]any{"map.json": &w.campus, "site-fixtures.json": &w.fixtures} {
		data, err := fs.ReadFile(public, "campuses/"+campus+"/"+name)
		if err != nil {
			return nil, fmt.Errorf("load multiplayer %s: %w", name, err)
		}
		if err = json.Unmarshal(data, target); err != nil {
			return nil, err
		}
	}
	for _, chunk := range w.campus.Chunks {
		cells := make([]bool, w.campus.ChunkSize*w.campus.ChunkSize)
		for _, runs := range chunk.Layers {
			offset := 0
			for i := 0; i < len(runs); i += 2 {
				count, index := runs[i], runs[i+1]
				if index >= 0 {
					material := strings.SplitN(w.campus.Textures[index], "-", 2)[0]
					// red-walk has a two-word material prefix.
					walkable := material == "grass" || material == "woodland" || material == "field" || material == "path" || material == "asphalt" || material == "red" || material == "track" || material == "court" || material == "paving" || material == "bridge"
					for j := offset; j < offset+count; j++ {
						cells[j] = walkable
					}
				}
				offset += count
			}
		}
		w.ground[[2]int{chunk.X, chunk.Y}] = cells
	}
	x, y := w.campus.Focus[0]*16, w.campus.Focus[1]*16
	if w.canStand(x, y) {
		w.spawn = [2]float64{x, y}
		return w, nil
	}
	for radius := 0; radius < 20; radius++ {
		for dy := -radius; dy <= radius; dy++ {
			for dx := -radius; dx <= radius; dx++ {
				x, y := (w.campus.Focus[0]+float64(dx))*16+8, (w.campus.Focus[1]+float64(dy))*16+8
				if w.canStand(x, y) {
					w.spawn = [2]float64{x, y}
					return w, nil
				}
			}
		}
	}
	return nil, fmt.Errorf("campus has no walkable multiplayer spawn")
}

func lookFor(app core.App, identity guest.Identity) (playerLook, error) {
	if identity.Name != "" {
		return playerLook{Name: identity.Name, Gender: "unspecified", Wear: []outfit{{"shirt", 0}, {"trousers", 0}, {"sneakers", 0}}}, nil
	}
	profile, err := app.FindFirstRecordByFilter("profiles", "userId = {:id}", dbx.Params{"id": identity.ID})
	if err != nil {
		return playerLook{}, err
	}
	look := playerLook{Name: profile.GetString("name"), Gender: profile.GetString("gender"), Wear: []outfit{}}
	if err = profile.UnmarshalJSONField("appearance", &look.Appearance); err != nil {
		return look, err
	}
	items, err := app.FindRecordsByFilter("inventory", "userId = {:id}", "slotId", 0, 0, dbx.Params{"id": identity.ID})
	if err != nil {
		return look, err
	}
	for _, item := range items {
		if strings.HasPrefix(item.GetString("slotId"), "bag:") || strings.HasPrefix(item.GetString("slotId"), "hotbar:") {
			continue
		}
		catalog, err := app.FindRecordById("items", item.GetString("itemId"))
		if err != nil {
			return look, err
		}
		look.Wear = append(look.Wear, outfit{catalog.GetString("key"), item.GetInt("color")})
	}
	return look, nil
}

func (w *World) join(look playerLook) (string, error) {
	var key [16]byte
	if _, err := rand.Read(key[:]); err != nil {
		return "", err
	}
	id := hex.EncodeToString(key[:])
	w.mu.Lock()
	defer w.mu.Unlock()
	x, y, candidates := 0.0, 0.0, 0
	for dy := -6; dy <= 6; dy++ {
		for dx := -6; dx <= 6; dx++ {
			px, py := w.spawn[0]+float64(dx)*20, w.spawn[1]+float64(dy)*20
			if !w.canStand(px, py) {
				continue
			}
			occupied := false
			for _, player := range w.players {
				if math.Hypot(px-player.X, py-player.Y) < 16 {
					occupied = true
					break
				}
			}
			if occupied {
				continue
			}
			candidates++
			if random.IntN(candidates) == 0 {
				x, y = px, py
			}
		}
	}
	if candidates == 0 {
		return "", fmt.Errorf("no free campus spawn")
	}
	w.players[id] = &playerState{ID: id, X: x, Y: y, Look: look, clock: time.Now(), credit: 150}
	return id, nil
}

func (w *World) leave(id string) { w.mu.Lock(); defer w.mu.Unlock(); delete(w.players, id) }

func (w *World) input(id string, revision int, commands []movementInput, now time.Time) error {
	if len(commands) == 0 || len(commands) > 12 {
		return fmt.Errorf("invalid input batch")
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	p := w.players[id]
	if revision != p.Revision {
		return nil
	}
	p.credit = math.Min(200, p.credit+now.Sub(p.clock).Seconds()*1000)
	p.clock = now
	for _, c := range commands {
		if c.Seq <= p.Ack {
			continue
		}
		if c.Seq != p.Ack+1 || math.IsNaN(c.X) || math.IsNaN(c.Y) || math.IsNaN(c.MS) || math.IsInf(c.X, 0) || math.IsInf(c.Y, 0) || math.IsInf(c.MS, 0) || math.Abs(c.X) > 1 || math.Abs(c.Y) > 1 || c.MS <= 0 || c.MS > 50 {
			return fmt.Errorf("invalid movement input")
		}
		ms := math.Min(c.MS, p.credit)
		p.credit -= ms
		p.Ack = c.Seq
		p.Moving = false
		p.Sprint = c.Sprint
		if c.X == 0 && c.Y == 0 {
			continue
		}
		if math.Abs(c.X) > math.Abs(c.Y) {
			if c.X > 0 {
				p.Direction = 1
			} else {
				p.Direction = 3
			}
		} else if c.Y > 0 {
			p.Direction = 0
		} else {
			p.Direction = 2
		}
		distance := walkSpeed * ms / 1000 / math.Max(1, math.Hypot(c.X, c.Y))
		if c.Sprint {
			distance *= 2
		}
		x, y := p.X+c.X*distance, p.Y+c.Y*distance
		if w.canStand(x, y) {
			p.Moving = x != p.X || y != p.Y
			p.X = x
			p.Y = y
		}
	}
	return nil
}

func (w *World) snapshot(id string) worldSnapshot {
	w.mu.Lock()
	defer w.mu.Unlock()
	self := w.players[id]
	snapshot := worldSnapshot{SelfID: id, Players: []playerState{}}
	for _, p := range w.players {
		if p.ID != id && math.Hypot(p.X-self.X, p.Y-self.Y) > 160*16 {
			continue
		}
		copy := *p
		if time.Since(p.clock) > 250*time.Millisecond {
			copy.Moving = false
		}
		snapshot.Players = append(snapshot.Players, copy)
	}
	return snapshot
}

func (w *World) appearance(id string, look playerLook) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.players[id].Look = look
}

func (w *World) travel(id, landmark string) bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	for _, b := range w.campus.Buildings {
		if b.ID != landmark {
			continue
		}
		minX, maxX, maxY := math.Inf(1), math.Inf(-1), math.Inf(-1)
		for _, p := range b.Footprint {
			minX = math.Min(minX, p[0])
			maxX = math.Max(maxX, p[0])
			maxY = math.Max(maxY, p[1])
		}
		tx, ty := math.Floor((minX+maxX)/2), math.Ceil(maxY)+2
		for radius := 0; radius <= 32; radius++ {
			for dy := -radius; dy <= radius; dy++ {
				for dx := -radius; dx <= radius; dx++ {
					if max(abs(dx), abs(dy)) != radius {
						continue
					}
					x, y := (tx+float64(dx))*16+8, (ty+float64(dy))*16+8
					if w.canStand(x, y) {
						p := w.players[id]
						p.X = x
						p.Y = y
						p.Moving = false
						p.Revision++
						return true
					}
				}
			}
		}
	}
	return false
}

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}

func (w *World) canStand(x, y float64) bool {
	if !w.walkable(x-3, y) || !w.walkable(x+3, y) {
		return false
	}
	x /= 16
	y /= 16
	for _, l := range w.fixtures.Lamps {
		if math.Hypot(x-(l.Position[0]-w.campus.Offset[0]), y-(l.Position[1]-w.campus.Offset[1])) < 3.0/16+0.14 {
			return false
		}
	}
	for _, b := range w.fixtures.Noticeboards {
		dx, dy := x-(b.Position[0]-w.campus.Offset[0]), y-(b.Position[1]-w.campus.Offset[1])
		if math.Abs(dx*b.Direction[0]+dy*b.Direction[1]) < b.Width/2+3.0/16 && math.Abs(-dx*b.Direction[1]+dy*b.Direction[0]) < 0.1+3.0/16 {
			return false
		}
	}
	return true
}

func insideFootprint(x, y float64, ring [][2]float64) bool {
	inside := false
	for i, j := 0, len(ring)-1; i < len(ring); j, i = i, i+1 {
		if (ring[i][1] > y) != (ring[j][1] > y) && x < (ring[j][0]-ring[i][0])*(y-ring[i][1])/(ring[j][1]-ring[i][1])+ring[i][0] {
			inside = !inside
		}
	}
	return inside
}

func (w *World) walkable(x, y float64) bool {
	tx, ty := int(math.Floor(x/16)), int(math.Floor(y/16))
	size := w.campus.ChunkSize
	cx, cy := int(math.Floor(float64(tx)/float64(size)))*size, int(math.Floor(float64(ty)/float64(size)))*size
	cells, ok := w.ground[[2]int{cx, cy}]
	if !ok || !cells[(ty-cy)*size+tx-cx] {
		return false
	}
	for _, b := range w.campus.Buildings {
		if b.CollisionPolygons != nil {
			for _, ring := range b.CollisionPolygons {
				if insideFootprint(x/16, y/16, ring) {
					return false
				}
			}
			continue
		}
		inside := false
		for _, p := range append([][][2]float64{b.Footprint}, b.Holes...) {
			if insideFootprint(x/16, y/16, p) {
				inside = !inside
			}
		}
		if inside {
			return false
		}
	}
	return true
}
