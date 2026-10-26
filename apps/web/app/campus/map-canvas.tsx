'use client';

import { useEffect, useRef, useState } from 'react';
import Phaser from 'phaser';
import { CampusScene, type CampusMap } from '../../game/campus-scene';
import GameHud from './game-hud';
import './map.css';

export default function MapCanvas() {
  const host = useRef<HTMLDivElement>(null);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(false);

  useEffect(() => {
    const abort = new AbortController();
    let game: Phaser.Game | undefined;
    async function start() {
      const response = await fetch('/campuses/eda/map.json', { signal: abort.signal });
      if (!response.ok) throw new Error('Map request failed');
      const data: CampusMap = await response.json();
      if (abort.signal.aborted) return;
      const campus = new CampusScene(data, () => setLoaded(true));
      game = new Phaser.Game({
        type: Phaser.WEBGL,
        parent: host.current!,
        pixelArt: true,
        backgroundColor: '#737d61',
        scale: { mode: Phaser.Scale.RESIZE, width: host.current!.clientWidth, height: host.current!.clientHeight },
        scene: campus,
        render: { antialias: false, roundPixels: true },
      });
    }
    start().catch(() => {
      if (!abort.signal.aborted) setError(true);
    });
    return () => {
      abort.abort();
      game?.destroy(true);
    };
  }, []);

  return (
    <div className="campus-map">
      <div className="campus-canvas" ref={host} aria-label="开发区校区像素地图" />
      {!loaded && !error && <div className="map-progress" role="progressbar" aria-label="地图加载中" />}
      {error && <p className="map-error" role="alert">地图加载失败</p>}
      {loaded && <GameHud />}
      <span className="map-attribution">© OpenStreetMap contributors</span>
    </div>
  );
}
