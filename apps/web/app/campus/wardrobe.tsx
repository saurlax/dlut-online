"use client";
import { useCallback, useEffect, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import PixelText from "../../components/pixel-text";
import GameDialogClose from "../../components/game-dialog-close";
import { drawCharacter, type CharacterState, type Item } from "../../game/character";
import { request, ApiError, clearGameSession, saveGameSession, type GameSession } from "../../game/game-session";
import "../../components/game-dialog.css";
import "./wardrobe.css";
import { Hotbar, InventoryPanel, PointerItem, type CarriedItem } from "./inventory-panel";

export default function Wardrobe({portal,onCharacter,session}:{
  portal:HTMLElement|null;
  onCharacter:(state:CharacterState,items:Item[])=>void;
  session:GameSession;
}) {
  const [open,setOpen]=useState(false);
  const [state,setState]=useState(session.state);
  const items=session.items;
  const [error,setError]=useState("");
  const [busy,setBusy]=useState(false);
  const [selected,setSelected]=useState("hotbar:0");
  const [active,setActive]=useState("hotbar:0");
  const [carried,setCarried]=useState<CarriedItem|null>(null);
  function changeOpen(next:boolean) {setCarried(null);setOpen(next);}
  function publish(next:GameSession["state"],catalog:Item[]) {
    saveGameSession({...session,state:next});
    setState(next);onCharacter(next,catalog);
  }
  const drawPreview=useCallback((canvas:HTMLCanvasElement|null) => {
    if (!canvas) return;
    const wear = state.inventory
      .filter(v=>v.id !== (open ? carried?.id : undefined) && !v.slotId.startsWith("hotbar:") && !v.slotId.startsWith("bag:"))
      .map(v=>({key:items.find(i=>i.id===v.itemId)!.key,color:v.color}));
    drawCharacter(
      canvas,
      state.profile.appearance,
      wear,
      0, 0, state.profile.gender,
    );
  }, [open, state, items, carried]);
  async function run(action:()=>Promise<void>) {
    setBusy(true);setError("");
    try {await action();return true;}
    catch(e) {
      if(e instanceof ApiError && e.status===401) {
        clearGameSession();window.location.replace("/");return false;
      }
      setError((e as Error).message);
      return false;
    } finally {setBusy(false);}
  }
  useEffect(() => {
    function keydown(e: KeyboardEvent) {
      if (e.repeat || e.ctrlKey || e.metaKey || e.altKey || (e.target as HTMLElement).closest('input,textarea,select,[contenteditable="true"]')) return;
      if (e.code === "KeyI") {
        if (!open && document.querySelector('[role="dialog"]')) return;
        e.preventDefault(); if (!open) setSelected(active); changeOpen(!open);
      } else if (!document.querySelector('[role="dialog"]') && /^Digit[0-9]$/.test(e.code)) {
        const index = (Number(e.code.slice(-1)) + 9) % 10;
        e.preventDefault(); setActive(`hotbar:${index}`);
      }
    }
    document.addEventListener("keydown",keydown);
    return () => document.removeEventListener("keydown",keydown);
  },[open,active]);
  const previewCanvas = <canvas ref={drawPreview} className="character-preview" aria-label="角色预览" />;
  function moveItem(id:string,slotId:string) {
    return run(async()=>publish(await request("/api/v1/character/move",session.token,{id,slotId}),items));
  }
  return <Dialog.Root open={open} onOpenChange={changeOpen}>
    <Hotbar carriedId={open ? carried?.id : undefined} state={state} items={items} active={active} onSelect={setActive} onOpen={()=>{setSelected(active);changeOpen(true);}} />
    {open && carried && portal && <PointerItem carried={carried} state={state} items={items} host={portal} />}
    <Dialog.Portal container={portal}>
      <Dialog.Overlay className={`game-dialog-overlay${carried ? " inventory-carrying" : ""}`} />
      <Dialog.Content className={`game-dialog wardrobe wardrobe-inventory${carried ? " inventory-carrying" : ""}`} aria-describedby={undefined}>
        <header className="game-dialog-header">
          <Dialog.Title><PixelText>背包</PixelText></Dialog.Title>
          <GameDialogClose />
        </header>
        <div className="wardrobe-content">
          <InventoryPanel state={state} items={items} selected={selected} setSelected={setSelected} busy={busy || !!session.guest} onMove={moveItem} carried={carried} onCarry={setCarried} onActivate={setActive} preview={previewCanvas} />
          {error && <p role="alert"><PixelText wrap>{error}</PixelText></p>}
        </div>
      </Dialog.Content>
    </Dialog.Portal>
  </Dialog.Root>;
}
