import { useEffect, useState } from "react";
import type { CampusScene } from "../../game/campus-scene";
import type { RealtimeConnection } from "../../game/realtime";
import PixelText from "../../components/pixel-text";

export default function PerformanceHud({ scene, realtime, name }: { scene: () => CampusScene; realtime: RealtimeConnection; name: string }) {
  const [sample, setSample] = useState(() => scene().performanceSnapshot());
  const [latency, setLatency] = useState(() => realtime.latencyMs);
  useEffect(() => {
    const timer = window.setInterval(() => {
      setSample(scene().performanceSnapshot());
      setLatency(realtime.latencyMs);
    }, 500);
    return () => window.clearInterval(timer);
  }, [scene, realtime]);
  return <div className="performance-hud"><PixelText>{`${name} ${sample.fps}FPS ${latency ?? "--"}ms`}</PixelText></div>;
}
