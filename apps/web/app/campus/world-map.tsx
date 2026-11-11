import { lazy, Suspense, useEffect, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import PixelText from "../../components/pixel-text";
import GameDialogClose from "../../components/game-dialog-close";
import type { CampusScene } from "../../game/campus-scene";
import { campuses, type Campus } from "../../game/campuses";
import "../../components/game-dialog.css";
import "./world-map.css";

const AtlasMap = lazy(() => import("./atlas-map"));

export default function WorldMap({portal, scene, currentCampus, onTravel}: {
  portal: HTMLElement | null;
  scene: () => CampusScene;
  currentCampus: Campus;
  onTravel: (campus: Campus, landmark: string) => void;
}) {
  const [open, setOpen] = useState(false);
  useEffect(() => {
    function keydown(event: KeyboardEvent) {
      if (event.key.toLowerCase() !== "m" || event.repeat || event.ctrlKey || event.metaKey || event.altKey) return;
      if ((event.target as HTMLElement).closest('input,textarea,select,[contenteditable="true"]')) return;
      if (!open && document.querySelector('[role="dialog"]')) return;
      event.preventDefault(); setOpen(!open);
    }
    function show() {
      if (!document.querySelector('[role="dialog"]')) setOpen(true);
    }
    document.addEventListener("keydown", keydown);
    window.addEventListener("do:open-map", show);
    return () => { document.removeEventListener("keydown", keydown); window.removeEventListener("do:open-map", show); };
  }, [open]);
  return <Dialog.Root open={open} onOpenChange={setOpen}>
    <Dialog.Portal container={portal}>
      <Dialog.Overlay className="game-dialog-overlay" />
      <Dialog.Content className="world-map-dialog" aria-describedby={undefined} onCloseAutoFocus={event => event.preventDefault()}>
        <header className="game-dialog-header">
          <Dialog.Title><PixelText>地图</PixelText></Dialog.Title>
          <GameDialogClose />
        </header>
        {open && <Suspense fallback={<div className="atlas-loading" role="progressbar" aria-label="地图加载中" />}>
          <AtlasMap player={scene().geographicPosition()} onTravel={landmark => {
            if (landmark.campus === currentCampus.id) {
              if (!scene().travelToLandmark(landmark.id)) return false;
            } else {
              onTravel(campuses.find(campus => campus.id === landmark.campus)!, landmark.id);
            }
            setOpen(false); return true;
          }} />
        </Suspense>}
      </Dialog.Content>
    </Dialog.Portal>
  </Dialog.Root>;
}
