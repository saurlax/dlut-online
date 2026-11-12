import { useEffect, useState } from "react";
import PixelText from "../../components/pixel-text";
import type { CampusScene } from "../../game/campus-scene";
import type { WorldSnapshot } from "../../game/players";
import type { RealtimeConnection } from "../../game/realtime";

type HitFeedback = { id: number; age: number; angle: number | null };

export default function HealthHud({ realtime, scene }: { realtime: RealtimeConnection; scene: () => CampusScene }) {
  const [vitals, setVitals] = useState({ hp: 100, seconds: 0, cause: "" });
  const [hits, setHits] = useState<HitFeedback[]>([]);

  useEffect(() => {
    let last = { hp: 100, seconds: 0, cause: "" };
    let lastHit = 0;
    return realtime.subscribe(event => {
      if (event.type === "disconnected" || event.type === "connected") {
        lastHit = 0;
        setHits([]);
      }
      if (event.type !== "world" && event.type !== "connected") return;
      const snapshot = event.data as WorldSnapshot;
      const recent = snapshot.hits;
      const latest = recent?.at(-1);
      if (recent && latest && latest.id > lastHit) {
        lastHit = latest.id;
        setHits(recent.map(hit => ({
          id: hit.id,
          age: Math.max(0, snapshot.time - hit.at),
          angle: hit.x || hit.y ? scene().damageAngle(hit.x, hit.y) : null,
        })));
      }
      const self = snapshot.players.find(player => player.id === snapshot.selfId)!;
      const seconds = self.respawnAt ? Math.max(0, Math.ceil((self.respawnAt - snapshot.time) / 1000)) : 0;
      const cause = self.deathCause ?? "";
      if (last.hp === self.hp && last.seconds === seconds && last.cause === cause) return;
      last = { hp: self.hp, seconds, cause };
      setVitals(last);
    });
  }, [realtime, scene]);

  const latest = hits.at(-1);
  return <>
    {latest && <div className="damage-feedback" aria-hidden="true">
      <div key={latest.id} className="damage-flash" style={{ animationDelay: `-${latest.age}ms` }} />
      {hits.map(hit => hit.angle !== null && <div key={`arrow-${hit.id}`} className="damage-indicator"
        style={{ transform: `rotate(${hit.angle}rad) translateY(-54px)`, animationDelay: `-${hit.age}ms` }} />)}
    </div>}
    <div className="health-meter" role="meter" aria-label="生命值" aria-valuemin={0} aria-valuemax={100} aria-valuenow={vitals.hp}>
      <div className="health-fill" style={{ transform: `scaleX(${vitals.hp / 100})` }} />
      <span>{vitals.hp} / 100</span>
    </div>
    {vitals.hp === 0 && <div className="death-screen" role="alert">
      <PixelText>你倒下了</PixelText>
      <PixelText>{vitals.cause}</PixelText>
      <PixelText>{vitals.seconds > 0 ? `${vitals.seconds} 秒后在附近复活` : "正在复活…"}</PixelText>
    </div>}
  </>;
}
