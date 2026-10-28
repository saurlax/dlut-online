"use client";

import { useEffect, useRef, useState } from "react";
import Phaser from "phaser";
import { CampusScene, type CampusMap, type EnvironmentAnimations } from "../../game/campus-scene";
import GameHud from "./game-hud";
import Wardrobe from "./wardrobe";
import WorldMap from "./world-map";
import Minimap from "./minimap";
import Chat from "./chat";
import Environment from "./environment";
import { pixelGrid, watchPixelGrid } from "../../game/pixel-grid";
import PixelText from "../../components/pixel-text";
import type { GameSession } from "../../game/game-session";
import "./map.css";

export default function MapCanvas({session}: {session:GameSession}) {
  const scene = useRef<CampusScene | null>(null);
  const host = useRef<HTMLDivElement>(null);
  const [loaded, setLoaded] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState(false);
  const [interfaceHost, setInterfaceHost] = useState<HTMLDivElement | null>(
    null,
  );

  useEffect(() => {
    const abort = new AbortController();
    let game: Phaser.Game | undefined;
    let stop: (() => void) | undefined;
    let loadFailed = false;
    async function start() {
      const [response, animationResponse] = await Promise.all([
        fetch("/campuses/eda/map.json", { signal: abort.signal }),
        fetch("/campuses/eda/animations/manifest.json", { signal: abort.signal }),
      ]);
      if (!response.ok || !animationResponse.ok) throw new Error("Map request failed");
      const data: CampusMap = await response.json();
      const animations: EnvironmentAnimations = await animationResponse.json();
      await document.fonts.load('12px "Fusion Pixel"', session.state.profile.name);
      if (abort.signal.aborted) return;
      setProgress(20);
      const campus = new CampusScene(data, () => {
        if (loadFailed) return;
        campus.setCharacter(session.state, session.items);
        setLoaded(true);
      }, animations, value => setProgress(20 + Math.round(value * 75)), () => {loadFailed=true;setError(true);});
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
  }, [session]);

  return (
    <div className="campus-map">
      <div
        className="campus-canvas"
        ref={host}
        aria-label="开发区校区像素地图"
      />
      {loaded && <Environment token={session.token} />}
      <div className="pixel-interface" ref={setInterfaceHost}>
        {!loaded && !error && (
          <div
            className="map-progress"
            role="progressbar"
            aria-label="地图加载中"
            aria-valuemin={0} aria-valuemax={100} aria-valuenow={progress}
          ><div className="map-progress-fill" style={{width:`${progress}%`}} /></div>
        )}
        {error && (
          <p className="map-error" role="alert">
            <PixelText wrap>地图加载失败</PixelText>
          </p>
        )}
        {loaded && (
          <>
            <GameHud portal={interfaceHost} />
            <Chat token={session.token} />
            <Minimap scene={()=>scene.current!} />
            <WorldMap portal={interfaceHost} scene={()=>scene.current!} />
            <Wardrobe
              session={session}
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
