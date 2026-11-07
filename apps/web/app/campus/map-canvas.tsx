import { useEffect, useMemo, useRef, useState } from "react";
import { CampusScene, type CampusMap, type EnvironmentAnimations } from "../../game/campus-scene";
import type { SiteFixtureData } from "../../game/site-fixtures";
import GameHud from "./game-hud";
import Wardrobe from "./wardrobe";
import WorldMap from "./world-map";
import Minimap from "./minimap";
import PerformanceHud from "./performance-hud";
import Chat from "./chat";
import Environment from "./environment";
import Joystick from "./joystick";
import PixelText from "../../components/pixel-text";
import type { GameSession } from "../../game/game-session";
import type { WorldSnapshot } from "../../game/players";
import { RealtimeConnection } from "../../game/realtime";
import "./map.css";

export default function MapCanvas({session}: {session:GameSession}) {
  const scene = useRef<CampusScene | null>(null);
  const realtime=useMemo(()=>new RealtimeConnection(session.token),[session.token]);
  const host = useRef<HTMLDivElement>(null);
  const [loaded, setLoaded] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState(false);
  const [interfaceHost, setInterfaceHost] = useState<HTMLDivElement | null>(
    null,
  );
  useEffect(() => {
    if (!loaded) return;
    scene.current!.connectMovement((inputs, revision) => realtime.movement(inputs, revision), id => realtime.travel(id));
    const unsubscribe = realtime.subscribe(event => {
      if (event.type === "world" || event.type === "connected") {
        scene.current!.receiveWorld(event.data as WorldSnapshot); return;
      }
      if (event.type === "disconnected" || event.type === "auth_error") {
        scene.current!.disconnectMovement(); return;
      }
      if (event.type !== "weather") return;
      const result = event.data as { available: boolean; weather: { weather_code: number }; serverTime: number };
      scene.current!.setEnvironment(result.serverTime, result.available ? result.weather.weather_code : null);
    });
    realtime.start();
    return () => { unsubscribe(); realtime.stop(); scene.current!.disconnectMovement(); };
  }, [loaded, realtime]);

  useEffect(() => {
    const abort = new AbortController();
    let campus: CampusScene | undefined;
    async function start() {
      const [response, animationResponse, fixtureResponse] = await Promise.all([
        fetch("/campuses/eda/map.json", { signal: abort.signal }),
        fetch("/campuses/eda/animations/manifest.json", { signal: abort.signal }),
        fetch("/campuses/eda/site-fixtures.json", { signal: abort.signal }),
      ]);
      if (!response.ok || !animationResponse.ok || !fixtureResponse.ok) throw new Error("Map request failed");
      const data: CampusMap = await response.json();
      const animations: EnvironmentAnimations = await animationResponse.json();
      const fixtures: SiteFixtureData = await fixtureResponse.json();
      await document.fonts.load('12px "Fusion Pixel"', session.state.profile.name);
      if (abort.signal.aborted) return;
      setProgress(20);
      campus = new CampusScene(data, animations, fixtures);
      scene.current = campus;
      await campus.start(host.current!, abort.signal, value => setProgress(20 + Math.round(value * 75)));
      if (abort.signal.aborted) return;
      campus.setCharacter(session.state, session.items);
      setLoaded(true);
    }
    start().catch(() => {
      if (!abort.signal.aborted) { abort.abort(); campus?.destroy(); setError(true); }
    });
    return () => {
      abort.abort();
      campus?.destroy();
    };
  }, [session]);

  return (
    <div className="campus-map">
      <div
        className="campus-canvas"
        ref={host}
        aria-label="开发区校区像素地图"
      />
      {loaded && <Environment realtime={realtime} />}
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
            <PerformanceHud scene={()=>scene.current!} realtime={realtime} name={session.state.profile.name} />
            <Joystick onMove={(x,y)=>scene.current!.setTouchMovement(x,y)} />
            <Chat realtime={realtime} />
            <Minimap scene={()=>scene.current!} />
            <WorldMap portal={interfaceHost} scene={()=>scene.current!} />
            <Wardrobe
              session={session}
              portal={interfaceHost}
              onCharacter={(state, items) => {
                scene.current!.setCharacter(state, items);
                realtime.appearance();
              }}
            />
          </>
        )}
      </div>
    </div>
  );
}
