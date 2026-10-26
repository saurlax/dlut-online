"use client";

import { useEffect, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import PixelText from "../../components/pixel-text";
import { GameButton } from "../../components/game-button";
import type { CampusScene } from "../../game/campus-scene";
import "../../components/game-dialog.css";
import "./world-map.css";

type Snapshot = ReturnType<CampusScene["mapSnapshot"]>;
export default function WorldMap({
  portal,
  scene,
}: {
  portal: HTMLElement | null;
  scene: () => CampusScene;
}) {
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [landmark, setLandmark] = useState("");
  const [selected, setSelected] = useState("");
  const [error, setError] = useState("");
  useEffect(() => {
    function keydown(e: KeyboardEvent) {
      if (
        e.key.toLowerCase() !== "m" ||
        e.repeat ||
        e.ctrlKey ||
        e.metaKey ||
        e.altKey
      )
        return;
      const target = e.target as HTMLElement;
      if (target.closest('input,textarea,select,[contenteditable="true"]'))
        return;
      if (!snapshot && document.querySelector('[role="dialog"]')) return;
      e.preventDefault();
      setSnapshot(snapshot ? null : scene().mapSnapshot());
      setLandmark("");
      setSelected("");
      setError("");
    }
    document.addEventListener("keydown", keydown);
    return () => document.removeEventListener("keydown", keydown);
  }, [snapshot, scene]);
  return (
    <Dialog.Root
      open={snapshot !== null}
      onOpenChange={(open) => {
        if (!open) setSnapshot(null);
      }}
    >
      <Dialog.Portal container={portal}>
        <Dialog.Overlay className="game-dialog-overlay" />
        <Dialog.Content
          className="game-dialog world-map-dialog"
          aria-describedby={undefined}
          onCloseAutoFocus={(e) => e.preventDefault()}
        >
          <header className="game-dialog-header">
            <Dialog.Title>
              <PixelText>校园地图</PixelText>
            </Dialog.Title>
          </header>
          {snapshot && (
            <div className="world-map-content">
              <div
                className="world-map-art"
                style={{ width: snapshot.width, height: snapshot.height }}
              >
                <img
                  src="/campuses/eda/world-map.png"
                  width={snapshot.width}
                  height={snapshot.height}
                  alt="北朝上的开发区校区地图"
                  draggable={false}
                />
                {snapshot.landmarks.map((b) => (
                  <button
                    key={b.id}
                    className="world-map-landmark"
                    aria-pressed={selected === b.id}
                    aria-label={b.name}
                    title={b.name}
                    style={{
                      left: b.x,
                      top: b.y,
                      width: b.width,
                      height: b.height,
                    }}
                    onMouseEnter={() => setLandmark(b.name)}
                    onMouseLeave={() => setLandmark("")}
                    onFocus={() => setLandmark(b.name)}
                    onBlur={() => setLandmark("")}
                    onClick={() => { setSelected(b.id); setError(""); }}
                  />
                ))}
                {snapshot.player && (
                  <span
                    className="world-map-player"
                    role="img"
                    aria-label="你的位置"
                    style={{ left: snapshot.player.x, top: snapshot.player.y }}
                  />
                )}
              </div>
              <div className="world-map-caption">
                <PixelText>{snapshot.landmarks.find(b => b.id === selected)?.name || landmark || "北 ↑"}</PixelText>
              </div>
              <GameButton
                appearance="primary"
                disabled={!selected || !snapshot.player}
                onClick={() => {
                  if (scene().travelToLandmark(selected)) setSnapshot(null);
                  else setError("附近没有可通行落点");
                }}
              >快速前往</GameButton>
              {error && <p role="alert"><PixelText wrap>{error}</PixelText></p>}
              <Dialog.Close asChild>
                <GameButton>返回</GameButton>
              </Dialog.Close>
            </div>
          )}
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
