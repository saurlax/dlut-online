import Phaser from "phaser";
import { drawCharacter, type CharacterState, type Item } from "./character";

export interface TileRegion {
  x: number;
  y: number;
  width: number;
  height: number;
  runs: number[];
}

export interface CampusMap {
  tileSize: number;
  chunkSize: number;
  width: number;
  height: number;
  textures: string[];
  focus: [number, number];
  chunks: { x: number; y: number; layers: number[][]; overview: number[] }[];
  buildings: {
    id: string;
    image: string;
    x: number;
    y: number;
    width: number;
    height: number;
    footprint: [number, number][];
    depth: number;
  }[];
  plantPrototypes: Record<
    string,
    { width: number; height: number; runs: number[] }
  >;
  plants: {
    id: number;
    prototype: string;
    x: number;
    y: number;
    depth: number;
  }[];
}

interface Rectangle {
  x: number;
  y: number;
  width: number;
  height: number;
  tile: number;
}

// Merge identical horizontal runs vertically. TileSprites repeat the original
// 16px image; large generated map textures or atlases are never created.
function rectangles(region: TileRegion): Rectangle[] {
  const result: Rectangle[] = [];
  let previous = new Map<string, Rectangle>();
  let current = new Map<string, Rectangle>();
  let position = 0;
  for (let i = 0; i < region.runs.length; i += 2) {
    let remaining = region.runs[i];
    const tile = region.runs[i + 1];
    while (remaining > 0) {
      const x = position % region.width;
      const y = Math.floor(position / region.width);
      const length = Math.min(remaining, region.width - x);
      if (tile >= 0) {
        const key = `${x}:${length}:${tile}`;
        const above = previous.get(key);
        if (above) {
          above.height += 1;
          current.set(key, above);
        } else {
          const rectangle = { x, y, width: length, height: 1, tile };
          result.push(rectangle);
          current.set(key, rectangle);
        }
      }
      remaining -= length;
      position += length;
      if (position % region.width === 0) {
        previous = current;
        current = new Map();
      }
    }
  }
  return result;
}

export class CampusScene extends Phaser.Scene {
  private activeRegions = new Map<
    string,
    Phaser.GameObjects.Container | Phaser.GameObjects.Image
  >();
  private viewKey = "";
  private actor?: Phaser.GameObjects.Image;
  private characterState?: CharacterState;
  private itemCatalog: Item[] = [];
  private direction = 0;
  private keys = new Set<string>();
  private pose = "";

  private walkable(x: number, y: number) {
    const tx = Math.floor(x / 16),
      ty = Math.floor(y / 16),
      size = this.campus.chunkSize;
    const chunk = this.campus.chunks.find(
      (c) => tx >= c.x && ty >= c.y && tx < c.x + size && ty < c.y + size,
    );
    if (!chunk) return false;
    const target = (ty - chunk.y) * size + tx - chunk.x;
    let material = "outside";
    for (const runs of chunk.layers) {
      let count = 0;
      for (let i = 0; i < runs.length; i += 2) {
        count += runs[i];
        if (count > target) {
          if (runs[i + 1] >= 0) material = this.campus.textures[runs[i + 1]];
          break;
        }
      }
    }
    if (!/^(grass|path|asphalt|redwalk|track|court)/.test(material))
      return false;
    for (const b of this.campus.buildings) {
      let inside = false;
      const p = b.footprint;
      for (let i = 0, j = p.length - 1; i < p.length; j = i++) {
        if (
          p[i][1] > y / 16 !== p[j][1] > y / 16 &&
          x / 16 <
            ((p[j][0] - p[i][0]) * (y / 16 - p[i][1])) / (p[j][1] - p[i][1]) +
              p[i][0]
        )
          inside = !inside;
      }
      if (inside) return false;
    }
    return true;
  }

  private animateCharacter(step: number) {
    const state = this.characterState!;
    const texture = this.textures.get(
      "player",
    ) as Phaser.Textures.CanvasTexture;
    drawCharacter(
      texture.canvas,
      state.profile!.appearance,
      state.inventory
        .filter((v) => !v.slotId.startsWith("bag:"))
        .map((v) => ({
          key: this.itemCatalog.find((i) => i.id === v.itemId)!.key,
          color: v.color,
        })),
      this.direction,
      step,
    );
    texture.refresh();
  }

  setCharacter(state: CharacterState, items: Item[]) {
    this.characterState = state;
    this.itemCatalog = items;
    this.pose = "";
    if (!state.profile) {
      this.actor?.destroy();
      this.actor = undefined;
      return;
    }
    const canvas = document.createElement("canvas");
    drawCharacter(
      canvas,
      state.profile.appearance,
      state.inventory
        .filter((v) => !v.slotId.startsWith("bag:"))
        .map((v) => ({
          key: items.find((i) => i.id === v.itemId)!.key,
          color: v.color,
        })),
    );
    const previous = this.actor ? { x: this.actor.x, y: this.actor.y } : null;
    this.actor?.destroy();
    if (this.textures.exists("player")) this.textures.remove("player");
    this.textures.addCanvas("player", canvas);
    let x = previous?.x ?? this.campus.focus[0] * 16,
      y = previous?.y ?? this.campus.focus[1] * 16;
    if (!this.walkable(x, y)) {
      find: for (let r = 0; r < 20; r++) {
        for (let dy = -r; dy <= r; dy++) {
          for (let dx = -r; dx <= r; dx++) {
            const px = (this.campus.focus[0] + dx) * 16 + 8,
              py = (this.campus.focus[1] + dy) * 16 + 8;
            if (this.walkable(px, py)) {
              x = px;
              y = py;
              break find;
            }
          }
        }
      }
    }

    this.actor = this.add
      .image(x, y, "player")
      .setOrigin(0.5, 1)
      .setDepth(100 + y / 16);
  }

  constructor(
    private readonly campus: CampusMap,
    private readonly onReady: () => void,
  ) {
    super("campus");
  }

  preload() {
    for (const texture of this.campus.textures) {
      this.load.image(texture, `/campuses/eda/tiles/${texture}.png`);
    }
    for (const building of this.campus.buildings) {
      this.load.image(
        `building:${building.id}`,
        `/campuses/eda/${building.image}`,
      );
    }
  }

  create() {
    this.cameras.main.setBounds(
      0,
      0,
      this.campus.width * 16,
      this.campus.height * 16,
    );
    this.cameras.main.setRoundPixels(true);
    this.cameras.main.setZoom(1);
    this.updateBounds();
    this.cameras.main.centerOn(
      this.campus.focus[0] * 16,
      this.campus.focus[1] * 16,
    );
    this.scale.on("resize", () => {
      const camera = this.cameras.main;
      camera.setSize(this.scale.width, this.scale.height);
      this.updateBounds();
      camera.centerOn(this.campus.focus[0] * 16, this.campus.focus[1] * 16);
    });
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      this.scale.removeAllListeners("resize");
      this.activeRegions.clear();
    });
    const down = (event: KeyboardEvent) => {
      if (!event.repeat) this.keys.add(event.key.toLowerCase());
    };
    const up = (event: KeyboardEvent) =>
      this.keys.delete(event.key.toLowerCase());
    const blur = () => this.keys.clear();
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    window.addEventListener("blur", blur);
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
      window.removeEventListener("blur", blur);
    });
    this.onReady();
  }

  private updateBounds() {
    const camera = this.cameras.main;
    const width = this.campus.width * 16;
    const height = this.campus.height * 16;
    const padX = Math.max(0, (camera.width / camera.zoom - width) / 2);
    const padY = Math.max(0, (camera.height / camera.zoom - height) / 2);
    camera.setBounds(-padX, -padY, width + padX * 2, height + padY * 2);
  }

  private addRegion(key: string, region: TileRegion, depth: number) {
    const container = this.add
      .container(region.x * 16, region.y * 16)
      .setDepth(depth);
    for (const rectangle of rectangles(region)) {
      const tile = this.add
        .tileSprite(
          rectangle.x * 16,
          rectangle.y * 16,
          rectangle.width * 16,
          rectangle.height * 16,
          this.campus.textures[rectangle.tile],
        )
        .setOrigin(0);
      container.add(tile);
    }
    this.activeRegions.set(key, container);
  }

  update(time: number, delta: number) {
    if (this.actor) {
      const paused =
        Boolean(document.querySelector('[role="dialog"]')) ||
        !document.hasFocus();
      if (paused) this.keys.clear();
      const dx =
        Number(this.keys.has("d") || this.keys.has("arrowright")) -
        Number(this.keys.has("a") || this.keys.has("arrowleft"));
      const dy =
        Number(this.keys.has("s") || this.keys.has("arrowdown")) -
        Number(this.keys.has("w") || this.keys.has("arrowup"));
      if (dx || dy) {
        this.direction = dx ? (dx > 0 ? 1 : 3) : dy > 0 ? 0 : 2;
        const distance = (32 * Math.min(delta, 50)) / 1000 / Math.hypot(dx, dy);
        const x = this.actor.x + dx * distance,
          y = this.actor.y + dy * distance;
        const v = this.cameras.main.worldView;
        if (
          v.contains(x, y) &&
          this.walkable(x - 3, y) &&
          this.walkable(x + 3, y)
        )
          this.actor.setPosition(x, y).setDepth(100 + y / 16);
      }
      const step = dx || dy ? Math.floor(time / 160) % 3 : 0;
      const pose = `${this.direction}:${step}`;
      if (pose !== this.pose) {
        this.animateCharacter(step);
        this.pose = pose;
      }
    }

    const camera = this.cameras.main;
    const view = camera.worldView;
    const size = this.campus.chunkSize;
    const minX = Math.floor(view.left / (size * 16));
    const minY = Math.floor(view.top / (size * 16));
    const maxX = Math.ceil(view.right / (size * 16));
    const maxY = Math.ceil(view.bottom / (size * 16));
    const viewKey = `${minX},${minY},${maxX},${maxY}`;
    if (viewKey === this.viewKey) return;
    this.viewKey = viewKey;
    const visible = new Set<string>();
    for (const chunk of this.campus.chunks) {
      if (
        chunk.x < minX * size ||
        chunk.y < minY * size ||
        chunk.x >= maxX * size ||
        chunk.y >= maxY * size
      )
        continue;
      chunk.layers.forEach((runs, i) => {
        const key = `ground:${chunk.x}:${chunk.y}:${i}`;
        visible.add(key);
        if (!this.activeRegions.has(key))
          this.addRegion(
            key,
            { x: chunk.x, y: chunk.y, width: size, height: size, runs },
            i,
          );
      });
    }
    for (const building of this.campus.buildings) {
      if (
        building.x + building.width < minX * size ||
        building.y + building.height < minY * size ||
        building.x > maxX * size ||
        building.y > maxY * size
      )
        continue;
      const key = `building:${building.id}`;
      visible.add(key);
      if (!this.activeRegions.has(key)) {
        const image = this.add
          .image(building.x * 16, building.y * 16, `building:${building.id}`)
          .setOrigin(0)
          .setDepth(100 + building.depth);
        this.activeRegions.set(key, image);
      }
    }
    for (const plant of this.campus.plants) {
      const prototype = this.campus.plantPrototypes[plant.prototype];
      if (
        plant.x + prototype.width < minX * size ||
        plant.y + prototype.height < minY * size ||
        plant.x > maxX * size ||
        plant.y > maxY * size
      )
        continue;
      const key = `plant:${plant.id}`;
      visible.add(key);
      if (!this.activeRegions.has(key))
        this.addRegion(
          key,
          { ...prototype, x: plant.x, y: plant.y },
          100 + plant.depth,
        );
    }
    for (const [key, container] of this.activeRegions) {
      if (!visible.has(key)) {
        container.destroy(true);
        this.activeRegions.delete(key);
      }
    }
  }
}
