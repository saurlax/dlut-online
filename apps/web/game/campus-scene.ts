import Phaser from "phaser";
import { drawCharacter, type CharacterState, type Item } from "./character";
import { buildingSlices } from "./occlusion";

export interface TileRegion {
  x: number;
  y: number;
  width: number;
  height: number;
  runs: number[];
}

export interface EnvironmentAnimations {
  water: {
    image: string;
    frameWidth: number;
    frameHeight: number;
    frameDurationMs: number;
    framesByTile: Record<string, number[]>;
  };
  trees: { frameDurationMs: number; offsets: number[]; fixedRootPixels: number };
}

export interface CampusMap {
  tileSize: number;
  chunkSize: number;
  width: number;
  height: number;
  textures: string[];
  focus: [number, number];
  materials: string[];
  materialRuns: number[];
  chunks: { x: number; y: number; layers: number[][]; overview: number[] }[];
  buildings: {
    id: string;
    name: string;
    image: string;
    x: number;
    y: number;
    width: number;
    height: number;
    footprint: [number, number][];
    depth: number;
    heightMeters: number;
    style: string;
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
    Phaser.GameObjects.Container | Phaser.GameObjects.Group
  >();
  private viewKey = "";
  private actor?: Phaser.GameObjects.Image;
  private nameTag?: Phaser.GameObjects.Image;
  private characterState?: CharacterState;
  private itemCatalog: Item[] = [];
  private direction = 0;
  private keys = new Set<string>();
  private pose = "";
  private environmentTick = "";
  private readonly occlusionCanvas = document.createElement('canvas');

  minimapTerrain() {
    const palette: Record<string, string> = {
      outside: '#778e5a', grass: '#93bb60', woodland: '#608044', water: '#448f99',
      asphalt: '#777b72', path: '#c4b48b', 'red-walk': '#c7785e', paving: '#b8b59b',
      bridge: '#b9bea8', track: '#b46c55', court: '#719c8f', field: '#8aaa5a',
    };
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(this.campus.width / 2);
    canvas.height = Math.ceil(this.campus.height / 2);
    const context = canvas.getContext('2d')!;
    let offset = 0;
    for (let i = 0; i < this.campus.materialRuns.length; i += 2) {
      const count = this.campus.materialRuns[i];
      context.fillStyle = palette[this.campus.materials[this.campus.materialRuns[i + 1]]];
      for (let j = offset; j < offset + count; j++) {
        const x = j % this.campus.width, y = Math.floor(j / this.campus.width);
        if (x % 2 === 1 && y % 2 === 1) context.fillRect(Math.floor(x / 2), Math.floor(y / 2), 1, 1);
      }
      offset += count;
    }
    context.fillStyle = '#e2d5b4';
    for (const building of this.campus.buildings) {
      context.beginPath();
      building.footprint.forEach(([x,y], i) => i === 0 ? context.moveTo(x/2,y/2) : context.lineTo(x/2,y/2));
      context.closePath(); context.fill();
    }
    return canvas;
  }

  minimapPosition() {
    return this.actor
      ? { x: this.actor.x / 32, y: this.actor.y / 32, direction: this.direction, active: true }
      : { x: this.campus.focus[0] / 2, y: this.campus.focus[1] / 2, direction: 0, active: false };
  }

  mapSnapshot() {
    return {
      width: Math.ceil(this.campus.width / 10),
      height: Math.ceil(this.campus.height / 10),
      player: this.actor ? { x: Math.round(this.actor.x / 160), y: Math.round(this.actor.y / 160) } : null,
      landmarks: this.campus.buildings.filter(b=>!b.id.endsWith('-podium')).map(b=>{
        const xs=b.footprint.map(p=>p[0]),ys=b.footprint.map(p=>p[1]);
        const x=Math.floor(Math.min(...xs)/10),y=Math.floor(Math.min(...ys)/10);
        return {id:b.id,name:b.name,x,y,width:Math.max(1,Math.ceil(Math.max(...xs)/10)-x),height:Math.max(1,Math.ceil(Math.max(...ys)/10)-y)};
      }),
    };
  }

  travelToLandmark(id: string) {
    const building = this.campus.buildings.find(b => b.id === id)!;
    const xs = building.footprint.map(p => p[0]);
    const ys = building.footprint.map(p => p[1]);
    // Prefer open ground just south of the footprint; this is not an inferred entrance.
    const targetX = Math.floor((Math.min(...xs) + Math.max(...xs)) / 2);
    const targetY = Math.ceil(Math.max(...ys)) + 2;
    for (let radius = 0; radius <= 32; radius++) {
      for (let dy = -radius; dy <= radius; dy++) {
        for (let dx = -radius; dx <= radius; dx++) {
          if (Math.max(Math.abs(dx), Math.abs(dy)) !== radius) continue;
          const x = (targetX + dx) * 16 + 8;
          const y = (targetY + dy) * 16 + 8;
          if (!this.walkable(x - 3, y) || !this.walkable(x + 3, y)) continue;
          this.keys.clear();
          this.actor!.setPosition(x, y).setDepth(100 + y / 16);
          this.cameras.main.centerOn(x, y);
          return true;
        }
      }
    }
    return false;
  }

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
    if (!/^(grass|woodland|field|path|asphalt|red-walk|track|court|paving|bridge)-/.test(material))
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
        .filter((v) => !v.slotId.startsWith("hotbar:") && !v.slotId.startsWith("bag:"))
        .map((v) => ({
          key: this.itemCatalog.find((i) => i.id === v.itemId)!.key,
          color: v.color,
        })),
      this.direction,
      step,
      state.profile!.gender,
    );
    texture.refresh();
  }

  setCharacter(state: CharacterState, items: Item[]) {
    this.characterState = state;
    this.itemCatalog = items;
    this.pose = "";
    if (!state.profile) {
      this.cameras.main.stopFollow();
      this.actor?.destroy();
      this.nameTag?.destroy();
      this.nameTag = undefined;
      this.actor = undefined;
      return;
    }
    const canvas = document.createElement("canvas");
    drawCharacter(
      canvas,
      state.profile.appearance,
      state.inventory
        .filter((v) => !v.slotId.startsWith("hotbar:") && !v.slotId.startsWith("bag:"))
        .map((v) => ({
          key: items.find((i) => i.id === v.itemId)!.key,
          color: v.color,
        })),
      0, 0, state.profile.gender,
    );
    this.setNameTag(state.profile.name);
    if (this.actor) {
      const texture = this.textures.get("player") as Phaser.Textures.CanvasTexture;
      texture.context.clearRect(0, 0, 16, 32);
      texture.context.drawImage(canvas, 0, 0);
      texture.refresh();
      this.nameTag!.setPosition(this.actor.x, this.actor.y - 35);
      return;
    }
    if (this.textures.exists("player")) this.textures.remove("player");
    this.textures.addCanvas("player", canvas);
    let x = this.campus.focus[0] * 16,
      y = this.campus.focus[1] * 16;
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
    this.cameras.main.startFollow(this.actor, true, 1, 1);
    this.nameTag!.setPosition(x, y - 35);
  }

  private setNameTag(username: string) {
    this.nameTag?.destroy();
    if (this.textures.exists("player-name")) this.textures.remove("player-name");
    const canvas = document.createElement("canvas"), context = canvas.getContext("2d")!;
    context.font = '12px "Fusion Pixel"';
    canvas.width = 2 * Math.ceil((context.measureText(username).width + 2) / 2);
    canvas.height = 14;
    context.font = '12px "Fusion Pixel"';
    context.fillStyle = "#fff3d0";
    context.fillText(username, 0, 10);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height);
    for (let i = 3; i < pixels.data.length; i += 4) pixels.data[i] = pixels.data[i] >= 128 ? 255 : 0;
    context.putImageData(pixels, 0, 0);
    this.textures.addCanvas("player-name", canvas);
    this.nameTag = this.add.image(0, 0, "player-name").setOrigin(0.5, 1).setDepth(100000);
  }

  constructor(
    private readonly campus: CampusMap,
    private readonly onReady: () => void,
    private readonly environment: EnvironmentAnimations,
    private readonly onProgress: (progress:number)=>void,
    private readonly onLoadError: ()=>void,
  ) {
    super("campus");
  }

  preload() {
    this.load.on('progress', this.onProgress);
    this.load.on('loaderror', this.onLoadError);
    this.load.spritesheet('water-animation', `/campuses/eda/${this.environment.water.image}`, {
      frameWidth: this.environment.water.frameWidth,
      frameHeight: this.environment.water.frameHeight,
    });
    for (const texture of this.campus.textures) {
      if (this.environment.water.framesByTile[texture]) continue;
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
    this.cameras.main.setDeadzone(this.scale.width / 2, this.scale.height / 2);
    this.updateBounds();
    this.cameras.main.centerOn(
      this.campus.focus[0] * 16,
      this.campus.focus[1] * 16,
    );
    this.scale.on("resize", () => {
      const camera = this.cameras.main;
      camera.setSize(this.scale.width, this.scale.height);
      this.updateBounds();
      camera.setDeadzone(camera.width / 2, camera.height / 2);
      if (!this.actor) {
        camera.centerOn(this.campus.focus[0] * 16, this.campus.focus[1] * 16);
      }
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

  private addRegion(key: string, region: TileRegion, depth: number, windPhase?: number) {
    const container = this.add
      .container(region.x * 16, region.y * 16)
      .setDepth(depth);
    const animatedTiles: Phaser.GameObjects.TileSprite[] = [];
    for (const rectangle of rectangles(region)) {
      const frames = this.environment.water.framesByTile[this.campus.textures[rectangle.tile]];
      const tile = this.add
        .tileSprite(
          rectangle.x * 16,
          rectangle.y * 16,
          rectangle.width * 16,
          rectangle.height * 16,
          frames ? 'water-animation' : this.campus.textures[rectangle.tile],
          frames ? frames[Math.floor(this.time.now / this.environment.water.frameDurationMs) % frames.length] : undefined,
        )
        .setOrigin(0);
      if (frames) tile.setData('waterFrames', frames);
      if (windPhase !== undefined && (rectangle.y + rectangle.height) * 16 <= region.height * 16 - this.environment.trees.fixedRootPixels) {
        tile.setData('wind', { phase: windPhase, x: tile.x });
        const trees = this.environment.trees;
        tile.x += trees.offsets[(Math.floor(this.time.now / trees.frameDurationMs) + windPhase) % trees.offsets.length];
      }
      if (frames || tile.getData('wind')) animatedTiles.push(tile);
      container.add(tile);
    }
    container.setData('animatedTiles', animatedTiles);
    this.activeRegions.set(key, container);
  }

  update(time: number, delta: number) {
    this.animateEnvironment(time);
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
      const sprinting = this.keys.has("shift");
      if (dx || dy) {
        this.direction = dx ? (dx > 0 ? 1 : 3) : dy > 0 ? 0 : 2;
        const speed = sprinting ? 64 : 32;
        const distance = (speed * Math.min(delta, 50)) / 1000 / Math.hypot(dx, dy);
        const x = this.actor.x + dx * distance,
          y = this.actor.y + dy * distance;
        if (
          this.walkable(x - 3, y) &&
          this.walkable(x + 3, y)
        )
          this.actor.setPosition(x, y).setDepth(100 + y / 16);
      }
      const step = dx || dy ? Math.floor(time / (sprinting ? 80 : 160)) % 3 : 0;
      const pose = `${this.direction}:${step}`;
      if (pose !== this.pose) {
        this.animateCharacter(step);
        this.pose = pose;
      }
      this.nameTag!.setPosition(Math.round(this.actor.x), Math.round(this.actor.y) - 35);
    }

    const camera = this.cameras.main;
    const view = camera.worldView;
    const size = this.campus.chunkSize;
    const minX = Math.floor(view.left / (size * 16));
    const minY = Math.floor(view.top / (size * 16));
    const maxX = Math.ceil(view.right / (size * 16));
    const maxY = Math.ceil(view.bottom / (size * 16));
    const viewKey = `${minX},${minY},${maxX},${maxY}`;
    if (viewKey === this.viewKey) { this.updateOcclusion(delta); return; }
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
        const parts = buildingSlices(building).map(slice => this.add
          .image(building.x * 16, building.y * 16, `building:${building.id}`)
          .setOrigin(0).setCrop(slice.x, slice.y, slice.width, slice.height)
          .setDepth(slice.depth).setData('occlusionCrop', slice));
        this.activeRegions.set(key, this.add.group(parts));
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
          plant.id,
        );
    }
    for (const [key, container] of this.activeRegions) {
      if (!visible.has(key)) {
        container.destroy(true);
        this.activeRegions.delete(key);
      }
    }
    this.updateOcclusion(delta);
  }

  private updateOcclusion(delta: number) {
    const step = .55 * delta / 180;
    const fade = (alpha: number, hidden: boolean) => {
      const target = hidden ? .45 : 1;
      return alpha < target ? Math.min(target, alpha + step) : Math.max(target, alpha - step);
    };
    const actor = this.actor;
    const canvas = this.occlusionCanvas;
    canvas.width = 16; canvas.height = 32;
    const context = canvas.getContext('2d', {willReadFrequently:true})!;
    const actorAlpha = actor
      ? (this.textures.get('player') as Phaser.Textures.CanvasTexture).context.getImageData(0,0,16,32).data
      : null;
    const left = actor ? Math.round(actor.x-8) : 0, top = actor ? Math.round(actor.y-32) : 0;
    const overlaps = (image: CanvasImageSource, x: number, y: number, sx: number, sy: number, width: number, height: number, repeat: boolean) => {
      const x1 = Math.max(left,x), y1 = Math.max(top,y), x2 = Math.min(left+16,x+width), y2 = Math.min(top+32,y+height);
      if (x1>=x2 || y1>=y2) return false;
      context.clearRect(0,0,16,32);
      if (repeat) {
        for (let py=Math.floor((y1-y)/16)*16; py<y2-y; py+=16) {
          for (let px=Math.floor((x1-x)/16)*16; px<x2-x; px+=16) context.drawImage(image,x+px-left,y+py-top);
        }
      } else {
        context.drawImage(image,sx+x1-x,sy+y1-y,x2-x1,y2-y1,x1-left,y1-top,x2-x1,y2-y1);
      }
      const data = context.getImageData(0,0,16,32).data;
      for (let i=3;i<data.length;i+=4) if (data[i] && actorAlpha![i]) return true;
      return false;
    };
    for (const [key,object] of this.activeRegions) {
      if (key.startsWith('building:')) {
        const parts = (object as Phaser.GameObjects.Group).getChildren() as Phaser.GameObjects.Image[];
        const hidden = Boolean(actor && parts.some(part => {
          if (part.depth <= actor.depth) return false;
          const crop = part.getData('occlusionCrop') as {x:number;y:number;width:number;height:number};
          return overlaps(part.texture.getSourceImage() as CanvasImageSource,Math.round(part.x)+crop.x,Math.round(part.y)+crop.y,crop.x,crop.y,crop.width,crop.height,false);
        }));
        const alpha = fade(parts[0].alpha, hidden);
        for (const part of parts) part.setAlpha(alpha);
      } else if (key.startsWith('plant:')) {
        const plant = object as Phaser.GameObjects.Container;
        const hidden = Boolean(actor && plant.depth>actor.depth && plant.list.some(child => {
          const tile = child as Phaser.GameObjects.TileSprite;
          return overlaps(tile.texture.getSourceImage() as CanvasImageSource,Math.round(plant.x+tile.x),Math.round(plant.y+tile.y),0,0,tile.width,tile.height,true);
        }));
        plant.setAlpha(fade(plant.alpha, hidden));
      }
    }
  }

  private animateEnvironment(time: number) {
    const water = this.environment.water;
    const trees = this.environment.trees;
    const tick = `${Math.floor(time / water.frameDurationMs)}:${Math.floor(time / trees.frameDurationMs)}`;
    if (tick === this.environmentTick) return;
    this.environmentTick = tick;
    const view = this.cameras.main.worldView;
    for (const object of this.activeRegions.values()) {
      if (!(object instanceof Phaser.GameObjects.Container)) continue;
      for (const tile of object.getData('animatedTiles') as Phaser.GameObjects.TileSprite[]) {
        const x = object.x + tile.x, y = object.y + tile.y;
        if (x + tile.width < view.left - 16 || x > view.right + 16 ||
            y + tile.height < view.top - 16 || y > view.bottom + 16) continue;
        const frames = tile.getData('waterFrames') as number[] | undefined;
        if (frames) {
          const frame = frames[Math.floor(time / water.frameDurationMs) % frames.length];
          if (Number(tile.frame.name) !== frame) tile.setFrame(frame);
        }
        const wind = tile.getData('wind') as { phase: number; x: number } | undefined;
        if (wind) {
          const offset = trees.offsets[(Math.floor(time / trees.frameDurationMs) + wind.phase) % trees.offsets.length];
          tile.x = wind.x + offset;
        }
      }
    }
  }
}
