"use client";

import { useEffect, useRef, useState } from "react";
import Phaser from "phaser";
import { CampusScene, type CampusMap } from "../../game/campus-scene";
import GameHud from "./game-hud";
import Wardrobe from "./wardrobe";
import { pixelGrid, watchPixelGrid } from "../../game/pixel-grid";
import PixelText from "../../components/pixel-text";
import "./map.css";

export default function MapCanvas() {
  const scene = useRef<CampusScene | null>(null);
  const host = useRef<HTMLDivElement>(null);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(false);
  const [interfaceHost, setInterfaceHost] = useState<HTMLDivElement | null>(
    null,
  );

  useEffect(() => {
    const abort = new AbortController();
    let game: Phaser.Game | undefined;
    let stop: (() => void) | undefined;
    async function start() {
      const response = await fetch("/campuses/eda/map.json", {
        signal: abort.signal,
      });
      if (!response.ok) throw new Error("Map request failed");
      const data: CampusMap = await response.json();
      if (abort.signal.aborted) return;
      const campus = new CampusScene(data, () => setLoaded(true));
      scene.current = campus;
      const grid = pixelGrid();
      game = new Phaser.Game({
        type: Phaser.WEBGL,
        parent: host.current!,
        pixelArt: true,
        backgroundColor: "#737d61",
        scale: {
          mode: Phaser.Scale.NONE,
          width: grid.width + 1,
          height: grid.height + 1,
          autoRound: false,
        },
        callbacks: {
          postBoot: (instance) => {
            stop = watchPixelGrid(({ pixel, width, height }) => {
              instance.canvas.style.width = `${width + 1}px`;
              instance.canvas.style.height = `${height + 1}px`;
              instance.canvas.style.transform = `scale(${pixel})`;
              instance.scale.resize(width + 1, height + 1);
            });
          },
        },
        scene: campus,
        render: { antialias: false, roundPixels: true },
      });
    }
    start().catch(() => {
      if (!abort.signal.aborted) setError(true);
    });
    return () => {
      abort.abort();
      stop?.();
      game?.destroy(true);
    };
  }, []);

  return (
    <div className="campus-map">
      <div
        className="campus-canvas"
        ref={host}
        aria-label="开发区校区像素地图"
      />
      <div className="pixel-interface" ref={setInterfaceHost}>
        {!loaded && !error && (
          <div
            className="map-progress"
            role="progressbar"
            aria-label="地图加载中"
          />
        )}
        {error && (
          <p className="map-error" role="alert">
            <PixelText wrap>地图加载失败</PixelText>
          </p>
        )}
        {loaded && (
          <>
            <GameHud portal={interfaceHost} />
            <Wardrobe
              portal={interfaceHost}
              onCharacter={(state, items) =>
                scene.current!.setCharacter(state, items)
              }
            />
          </>
        )}
      </div>
    </div>
  );
}
