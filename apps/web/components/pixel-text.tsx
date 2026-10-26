'use client';

import { useLayoutEffect, useRef } from 'react';

// Rasterize once at the font's native size, then let the shared grid scale it.
export default function PixelText({ children, wrap = false }: { children: string; wrap?: boolean }) {
  const host = useRef<HTMLSpanElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  useLayoutEffect(() => {
    let disposed = false;
    let observer: ResizeObserver | undefined;
    document.fonts.load('12px "Fusion Pixel"', children).then(() => {
      if (disposed) return;
      function draw() {
        const surface = canvas.current!;
        const context = surface.getContext('2d', { willReadFrequently: true })!;
        context.font = '12px "Fusion Pixel"';
        const width = wrap ? host.current!.clientWidth : Math.ceil(context.measureText(children).width);
        const lines = [''];
        function append(text: string) {
          const last = lines.length - 1;
          if (lines[last] && context.measureText(lines[last] + text).width > width) lines.push(text.trimStart());
          else lines[last] += text;
        }
        for (const word of children.match(/[A-Za-z0-9.-]+|[^A-Za-z0-9.-]/gu)!) {
          if (context.measureText(word).width <= width) append(word);
          else for (const character of word) append(character);
        }
        surface.width = width;
        surface.height = lines.length * 14 - 2;
        context.font = '12px "Fusion Pixel"';
        context.fillStyle = getComputedStyle(surface).color;
        lines.forEach((line, index) => context.fillText(line, 0, 10 + index * 14));
        const image = context.getImageData(0, 0, surface.width, surface.height);
        for (let i = 3; i < image.data.length; i += 4) image.data[i] = image.data[i] >= 128 ? 255 : 0;
        context.putImageData(image, 0, 0);
      }
      draw();
      if (wrap) {
        observer = new ResizeObserver(draw);
        observer.observe(host.current!);
      }
    });
    return () => { disposed = true; observer?.disconnect(); };
  }, [children, wrap]);
  return <span ref={host} className={`pixel-text${wrap ? ' pixel-text--wrap' : ''}`}><span className="pixel-text-content">{children}</span><canvas ref={canvas} width={children.length * 12} height="12" aria-hidden="true" /></span>;
}
