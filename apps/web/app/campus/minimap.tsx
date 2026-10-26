"use client";
import { useEffect, useRef } from "react";
import type { CampusScene } from "../../game/campus-scene";
import "./minimap.css";

export default function Minimap({ scene }: { scene: () => CampusScene }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const terrain = scene().minimapTerrain();
    const context = canvas.current!.getContext("2d", {
      willReadFrequently: true,
    })!;
    context.imageSmoothingEnabled = false;
    let frame = 0,
      lastTime = -Infinity,
      lastPosition = "";
    function draw(time: number) {
      frame = requestAnimationFrame(draw);
      if (time - lastTime < 100) return;
      lastTime = time;
      const player = scene().minimapPosition();
      const x = Math.round(player.x),
        y = Math.round(player.y);
      const position = `${x}:${y}:${player.direction}:${player.active}`;
      if (position === lastPosition) return;
      lastPosition = position;
      context.fillStyle = "#778e5a";
      context.fillRect(0, 0, 64, 64);
      context.drawImage(terrain, 32 - x, 32 - y);
      if (player.active) {
        context.fillStyle = "#123e70";
        context.fillRect(30, 30, 5, 5);
        context.fillStyle = "#fff3d0";
        context.fillRect(31, 31, 3, 3);
        const [dx, dy] = [
          [0, 1],
          [1, 0],
          [0, -1],
          [-1, 0],
        ][player.direction];
        context.fillStyle = "#f4ce69";
        context.fillRect(32 + dx * 3, 32 + dy * 3, 1, 1);
      }
      const image = context.getImageData(0, 0, 64, 64);
      for (let y = 0; y < 64; y++)
        for (let x = 0; x < 64; x++) {
          const radius = (x - 31.5) ** 2 + (y - 31.5) ** 2,
            index = (y * 64 + x) * 4;
          if (radius > 32 ** 2) image.data[index + 3] = 0;
          else if (radius > 30 ** 2) {
            const color = radius > 31 ** 2 ? [18, 62, 112] : [255, 243, 208];
            image.data.set([...color, 255], index);
          }
        }
      context.putImageData(image, 0, 0);
    }
    frame = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(frame);
  }, [scene]);
  return (
    <button
      className="pixel-minimap"
      aria-label="打开校园地图"
      onClick={() => window.dispatchEvent(new Event("do:open-map"))}
    >
      <canvas ref={canvas} width={64} height={64} aria-hidden="true" />
    </button>
  );
}
