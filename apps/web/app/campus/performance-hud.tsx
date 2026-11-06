import { useEffect, useState } from "react";
import type { CampusScene } from "../../game/campus-scene";
import PixelText from "../../components/pixel-text";

export default function PerformanceHud({ scene }: { scene: () => CampusScene }) {
  const [sample, setSample] = useState(() => scene().performanceSnapshot());
  useEffect(() => {
    const timer = window.setInterval(() => setSample(scene().performanceSnapshot()), 500);
    return () => window.clearInterval(timer);
  }, [scene]);
  return <div className="performance-hud"><PixelText>{`FPS ${sample.fps} / ${sample.frameMs} ms`}</PixelText></div>;
}
