'use client';

import { useEffect, useRef } from 'react';
import { watchPixelGrid } from '../game/pixel-grid';

export default function TitleArt() {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const landscape = new Image();
    const logo = new Image();
    landscape.src = '/title/landscape.png';
    logo.src = '/title/dlut-online.png';
    let stop: (() => void) | undefined;
    let disposed = false;
    Promise.all([landscape.decode(), logo.decode()]).then(() => {
      if (disposed) return;
      stop = watchPixelGrid(({ pixel, width, height, compact }) => {
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
        const logoWidth = 2 * Math.floor(Math.min(320, width * .9, height * (compact ? .6 : 1.44)) / 2);
        context.drawImage(logo, Math.floor((width - logoWidth) / 2), Math.floor(height * (width < 350 ? .08 : .02)), logoWidth, logoWidth / 2);
      });
    });
    return () => { disposed = true; stop?.(); };
  }, []);
  return <canvas ref={canvas} className="title-landscape" aria-hidden="true" />;
}
