export interface OcclusionBuilding {
  x: number;
  y: number;
  width: number;
  height: number;
  heightMeters: number;
  style: string;
  footprint: [number, number][];
}

// Crops share the original texture. Each has its own ground contact depth.
export function buildingSlices(building: OcclusionBuilding) {
  const points = building.footprint;
  const minX = Math.min(...points.map((p) => p[0]));
  const maxX = Math.max(...points.map((p) => p[0]));
  const rise = building.style === "unverified" ? 0 : building.heightMeters;
  const width = building.width * 16,
    height = building.height * 16;
  const slices: {
    x: number;
    y: number;
    width: number;
    height: number;
    depth: number;
  }[] = [];
  for (let x = 0; x < width; x += 8) {
    const stripWidth = Math.min(8, width - x);
    const worldX = Math.max(
      minX + 0.0001,
      Math.min(maxX - 0.0001, building.x + (x + stripWidth / 2) / 16),
    );
    const crossings: number[] = [];
    for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
      const a = points[j],
        b = points[i];
      if (
        (a[0] <= worldX && worldX < b[0]) ||
        (b[0] <= worldX && worldX < a[0])
      ) {
        crossings.push(
          a[1] + ((worldX - a[0]) * (b[1] - a[1])) / (b[0] - a[0]),
        );
      }
    }
    crossings.sort((a, b) => a - b);
    const intervals: { north: number; south: number }[] = [];
    const cuts = new Set([0, height]);
    for (let i = 0; i < crossings.length; i += 2) {
      const interval = { north: crossings[i], south: crossings[i + 1] };
      intervals.push(interval);
      cuts.add(
        Math.max(
          0,
          Math.min(
            height,
            Math.floor((interval.north - rise - building.y) * 16) - 3,
          ),
        ),
      );
      cuts.add(
        Math.max(
          0,
          Math.min(height, Math.ceil((interval.south - building.y) * 16) + 3),
        ),
      );
    }
    const ys = [...cuts].sort((a, b) => a - b);
    for (let i = 0; i < ys.length - 1; i++) {
      const worldY = building.y + (ys[i] + ys[i + 1]) / 32;
      let contact = intervals[0].south;
      for (const interval of intervals) {
        if (
          worldY >= interval.north - rise - 3 / 16 &&
          worldY <= interval.south + 3 / 16
        )
          contact = interval.south;
      }
      const previous = slices[slices.length - 1];
      if (
        previous &&
        previous.x === x &&
        previous.depth === 100 + contact &&
        previous.y + previous.height === ys[i]
      ) {
        previous.height += ys[i + 1] - ys[i];
      } else {
        slices.push({
          x,
          y: ys[i],
          width: stripWidth,
          height: ys[i + 1] - ys[i],
          depth: 100 + contact,
        });
      }
    }
  }
  const merged: typeof slices = [];
  const adjacent = new Map<string, (typeof slices)[number]>();
  for (const slice of slices) {
    const key = `${slice.y}:${slice.height}:${slice.depth}`;
    const previous = adjacent.get(key);
    if (previous && previous.x + previous.width === slice.x)
      previous.width += slice.width;
    else {
      merged.push(slice);
      adjacent.set(key, slice);
    }
  }
  return merged;
}
