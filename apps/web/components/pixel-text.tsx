'use client';

import { useLayoutEffect, useRef } from 'react';

// Rasterize once at the font's native size, then let the shared grid scale it.
export default function PixelText({ children }: { children: string }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  useLayoutEffect(() => {
    let disposed = false;
    document.fonts.load('12px "Fusion Pixel"', children).then(() => {
      if (disposed) return;
      const surface = canvas.current!;
      const context = surface.getContext('2d', { willReadFrequently: true })!;
      context.font = '12px "Fusion Pixel"';
      const metrics = context.measureText(children);
      surface.width = Math.ceil(metrics.width);
      surface.height = 12;
      context.font = '12px "Fusion Pixel"';
      context.fillStyle = getComputedStyle(surface).color;
      context.fillText(children, 0, 10);
      const image = context.getImageData(0, 0, surface.width, 12);
      for (let i = 3; i < image.data.length; i += 4) image.data[i] = image.data[i] >= 128 ? 255 : 0;
      context.putImageData(image, 0, 0);
    });
    return () => { disposed = true; };
  }, [children]);
  return <span className="pixel-text"><span className="pixel-text-content">{children}</span><canvas ref={canvas} width={children.length * 12} height="12" aria-hidden="true" /></span>;
}
