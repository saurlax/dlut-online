'use client';

import { useEffect, useRef } from 'react';
import type { CampusMap, CampusView } from '../../game/campus-scene';

const COLORS: Record<string, string> = {
  outside: '#778e5a', grass: '#93bb60', woodland: '#72934d', water: '#448f99',
  asphalt: '#777b72', path: '#c4b48b', 'red-walk': '#c7785e', paving: '#b8b59b',
  bridge: '#b9bea8', track: '#b46c55', court: '#719c8f', field: '#8aaa5a',
};
const STEP = 8;

export default function MiniMap({ data, view }: { data: CampusMap; view: CampusView }) {
  const canvas = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const element = canvas.current!;
    const context = element.getContext('2d')!;
    element.width = data.width / STEP;
    element.height = data.height / STEP;
    const cells = new Uint8Array(data.width * data.height);
    let offset = 0;
    for (let i = 0; i < data.materialRuns.length; i += 2) {
      cells.fill(data.materialRuns[i + 1], offset, offset + data.materialRuns[i]);
      offset += data.materialRuns[i];
    }
    for (let y = 0; y < element.height; y++) for (let x = 0; x < element.width; x++) {
      const cell = cells[(y * STEP + STEP / 2) * data.width + x * STEP + STEP / 2];
      context.fillStyle = COLORS[data.materials[cell]];
      context.fillRect(x, y, 1, 1);
    }
    context.fillStyle = '#dad6bd';
    for (const building of data.buildings) {
      context.beginPath();
      building.footprint.forEach(([x, y], i) => {
        if (i === 0) context.moveTo(x / STEP, y / STEP);
        else context.lineTo(x / STEP, y / STEP);
      });
      context.closePath();
      context.fill();
    }
    const x = Math.round(view.x / STEP);
    const y = Math.round(view.y / STEP);
    const width = Math.max(1, Math.round(view.width / STEP));
    const height = Math.max(1, Math.round(view.height / STEP));
    context.strokeStyle = '#123e70';
    context.lineWidth = 3;
    context.strokeRect(x + .5, y + .5, width, height);
    context.strokeStyle = '#fff3d0';
    context.lineWidth = 1;
    context.strokeRect(x + .5, y + .5, width, height);
  }, [data, view]);

  return (
    <div className="mini-map-frame">
      <span className="mini-map-north" aria-hidden="true">N ↑</span>
      <canvas ref={canvas} className="mini-map" role="img" aria-label="校园小地图，方框表示当前视野" />
    </div>
  );
}
