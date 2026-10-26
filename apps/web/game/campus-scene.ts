import Phaser from 'phaser';

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
  buildings: { id: string; image: string; x: number; y: number; width: number; height: number; footprint: [number, number][]; depth: number }[];
  plantPrototypes: Record<string, { width: number; height: number; runs: number[] }>;
  plants: { id: number; prototype: string; x: number; y: number; depth: number }[];
}

interface Rectangle { x: number; y: number; width: number; height: number; tile: number }

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
  private activeRegions = new Map<string, Phaser.GameObjects.Container | Phaser.GameObjects.Image>();
  private viewKey = '';

  constructor(
    private readonly campus: CampusMap,
    private readonly onReady: () => void,
  ) {
    super('campus');
  }

  preload() {
    for (const texture of this.campus.textures) {
      this.load.image(texture, `/campuses/eda/tiles/${texture}.png`);
    }
    for (const building of this.campus.buildings) {
      this.load.image(`building:${building.id}`, `/campuses/eda/${building.image}`);
    }
  }

  create() {
    this.cameras.main.setBounds(0, 0, this.campus.width * 16, this.campus.height * 16);
    this.cameras.main.setRoundPixels(true);
    this.cameras.main.setZoom(2);
    this.updateBounds();
    this.cameras.main.centerOn(this.campus.focus[0] * 16, this.campus.focus[1] * 16);
    this.scale.on('resize', () => {
      const camera = this.cameras.main;
      camera.setSize(this.scale.width, this.scale.height);
      this.updateBounds();
      camera.centerOn(this.campus.focus[0] * 16, this.campus.focus[1] * 16);
    });
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      this.scale.removeAllListeners('resize');
      this.activeRegions.clear();
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
    const container = this.add.container(region.x * 16, region.y * 16).setDepth(depth);
    for (const rectangle of rectangles(region)) {
      const tile = this.add.tileSprite(
        rectangle.x * 16, rectangle.y * 16,
        rectangle.width * 16, rectangle.height * 16,
        this.campus.textures[rectangle.tile],
      ).setOrigin(0);
      container.add(tile);
    }
    this.activeRegions.set(key, container);
  }

  update() {
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
      if (chunk.x < minX * size || chunk.y < minY * size || chunk.x >= maxX * size || chunk.y >= maxY * size) continue;
      chunk.layers.forEach((runs, i) => {
        const key = `ground:${chunk.x}:${chunk.y}:${i}`;
        visible.add(key);
        if (!this.activeRegions.has(key)) this.addRegion(key, { x: chunk.x, y: chunk.y, width: size, height: size, runs }, i);
      });
    }
    for (const building of this.campus.buildings) {
      if (building.x + building.width < minX * size || building.y + building.height < minY * size || building.x > maxX * size || building.y > maxY * size) continue;
      const key = `building:${building.id}`;
      visible.add(key);
      if (!this.activeRegions.has(key)) {
        const image = this.add.image(building.x * 16, building.y * 16, `building:${building.id}`)
          .setOrigin(0).setDepth(100 + building.depth);
        this.activeRegions.set(key, image);
      }
    }
    for (const plant of this.campus.plants) {
      const prototype = this.campus.plantPrototypes[plant.prototype];
      if (plant.x + prototype.width < minX * size || plant.y + prototype.height < minY * size || plant.x > maxX * size || plant.y > maxY * size) continue;
      const key = `plant:${plant.id}`;
      visible.add(key);
      if (!this.activeRegions.has(key)) this.addRegion(key, { ...prototype, x: plant.x, y: plant.y }, 100 + plant.depth);
    }
    for (const [key, container] of this.activeRegions) {
      if (!visible.has(key)) {
        container.destroy(true);
        this.activeRegions.delete(key);
      }
    }
  }
}
