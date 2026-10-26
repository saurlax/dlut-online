'use client';

import { useEffect, useRef } from 'react';
import { watchPixelGrid } from '../game/pixel-grid';

export default function TitleArt() {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const landscape = new Image();
    landscape.src = '/title/landscape.png';
    let stop: (() => void) | undefined;
    let disposed = false;
    landscape.decode().then(() => {
      if (disposed) return;
      stop = watchPixelGrid(({ pixel, width, height }) => {
        const surface = canvas.current!;
        // Only complete logical pixels are rendered; the last cell is clipped.
        surface.width = width + 1;
        surface.height = height + 1;
        surface.style.width = `${surface.width}px`;
        surface.style.height = `${surface.height}px`;
        surface.style.transform = `scale(${pixel})`;
        const context = surface.getContext('2d')!;
        context.imageSmoothingEnabled = false;
        const cover = Math.max(surface.width / landscape.width, surface.height / landscape.height);
        const artWidth = Math.ceil(landscape.width * cover);
        const artHeight = Math.ceil(landscape.height * cover);
        context.drawImage(landscape, Math.floor((surface.width - artWidth) / 2), surface.height - artHeight, artWidth, artHeight);
      });
    });
    return () => { disposed = true; stop?.(); };
  }, []);
  return <canvas ref={canvas} className="title-landscape" aria-hidden="true" />;
}
