'use client';

import { useLayoutEffect } from 'react';
import { watchPixelGrid } from '../game/pixel-grid';

export default function PixelGrid() {
  useLayoutEffect(() => watchPixelGrid(({ pixel, width, height, compact }) => {
    const root = document.documentElement;
    root.style.setProperty('--pixel-scale', String(pixel));
    root.style.setProperty('--view-width', `${width}px`);
    root.style.setProperty('--view-height', `${height}px`);
    root.style.setProperty('--center-x', `${Math.floor(width / 2)}px`);
    root.style.setProperty('--center-y', `${Math.floor(height / 2)}px`);
    root.style.setProperty('--panel-width', `${Math.min(180, 2 * Math.floor((width - 16) / 2))}px`);
    root.style.setProperty('--about-width', `${Math.min(272, 2 * Math.floor((width - 16) / 2))}px`);
    root.style.setProperty('--panel-max-height', `${2 * Math.floor((height - 16) / 2)}px`);
    root.dataset.pixelCompact = String(compact);
    root.dataset.pixelNarrow = String(width < 160);
  }), []);
  return null;
}
