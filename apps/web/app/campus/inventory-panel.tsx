"use client";

import { useEffect, useRef } from "react";
import PixelText from "../../components/pixel-text";
import { GameButton } from "../../components/game-button";
import type { CharacterState, Item, Owned } from "../../game/character";

export const equipmentSlots = [
  ["head", "帽子"], ["top", "上装"], ["bottom", "下装"],
  ["feet", "鞋子"], ["backpack", "背包"],
] as const;

function ItemIcon({ item, color }: { item: Item; color: number }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const c = canvas.current!.getContext("2d")!;
    c.clearRect(0,0,16,16);
    const ink = "#183c59", fabric = ["#2877b4","#ac5a65","#53976d","#d2a255"][color];
    const rect = (x:number,y:number,w:number,h:number,fill:string) => { c.fillStyle=fill; c.fillRect(x,y,w,h); };
    switch (item.slotId) {
      case "top":
        rect(4,2,8,12,ink); rect(1,3,14,5,ink); rect(5,3,6,10,fabric); rect(2,4,12,3,fabric);
        rect(6,2,4,2,"#fff3d0"); rect(8,5,1,7,"#a4ced8"); break;
      case "bottom":
        if(item.key==="skirt") { rect(4,3,8,4,ink);rect(3,7,10,3,ink);rect(2,10,12,4,ink);rect(5,4,6,3,fabric);rect(4,7,8,3,fabric);rect(3,10,10,3,fabric); }
        else {rect(3,2,10,12,ink);rect(4,3,8,10,fabric);rect(7,7,2,7,"#fff3d0");rect(4,4,8,1,"#194975");} break;
      case "feet":
        rect(2,3,4,7,ink);rect(9,3,4,7,ink);rect(1,9,6,4,ink);rect(8,9,6,4,ink);
        rect(3,4,2,5,fabric);rect(10,4,2,5,fabric);rect(2,10,4,1,"#dce5dd");rect(9,10,4,1,"#dce5dd"); break;
      case "head":
        rect(4,3,8,1,ink);rect(3,4,10,6,ink);rect(1,10,14,2,ink);rect(4,4,8,5,fabric);rect(7,5,2,2,"#e8dfae"); break;
      case "backpack":
        rect(6,1,4,3,ink);rect(7,2,2,2,"#fff3d0");rect(4,3,8,1,ink);rect(3,4,10,10,ink);rect(4,5,8,8,fabric);
        rect(5,8,6,4,ink);rect(6,9,4,2,"#a4ced8");rect(7,5,2,2,"#e8dfae");
        if(item.capacity>=20) {rect(1,7,2,5,ink);rect(13,7,2,5,ink);}
        if(item.capacity===30) rect(4,3,8,2,"#d2a255"); break;
    }
  },[item,color]);
  return <canvas ref={canvas} width={16} height={16} aria-hidden="true" />;
}

function EmptySlot({ locked }: { locked:boolean }) {
  return <svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true" shapeRendering="crispEdges">
    {locked ? <path fill="currentColor" fillRule="evenodd" d="M6 3h4v1h1v4h1v6H4V8h1V4h1zm1 2v3h2V5zm0 5v2h2v-2z" /> : <path fill="currentColor" d="M2 2h4v1H3v3H2zm8 0h4v4h-1V3h-3zM2 10h1v3h3v1H2zm11 0h1v4h-4v-1h3z" />}
  </svg>;
}

function Shortcut({ value }: { value:string }) {
  const digits = ["111101101101111","010110010010111","111001111100111","111001111001111","101101111001001","111100111001111","111100111101111","111001001001001","111101111101111","111101111001111"];
  return <svg className="slot-shortcut" viewBox="0 0 3 5" width="3" height="5" aria-hidden="true" shapeRendering="crispEdges">
    {[...digits[Number(value)]].map((v,i)=>v==="1"?<rect key={i} x={i%3} y={Math.floor(i/3)} width="1" height="1" fill="currentColor" />:null)}
  </svg>;
}

export function InventorySlot({ slot, owned, items, locked=false, selected=false, label, shortcut, disabled, onClick, onDoubleClick, onDropItem }: {
  slot:string; owned?:Owned; items:Item[]; locked?:boolean; selected?:boolean; label:string; shortcut?:string;
  disabled?:boolean; onClick:()=>void; onDoubleClick?:()=>void; onDropItem?:(id:string)=>void;
}) {
  const item=owned ? items.find(i=>i.id===owned.itemId)! : undefined;
  return <button type="button" className={`inventory-slot${locked?" is-locked":""}${selected?" is-selected":""}`}
    aria-label={`${label}${locked?" 未解锁":item?` ${item.name}`:" 空"}`} aria-pressed={selected} disabled={locked||disabled}
    title={item?.name||label} data-slot={slot} onClick={onClick} onDoubleClick={onDoubleClick}
    draggable={Boolean(owned)&&!disabled} onDragStart={e=>e.dataTransfer.setData("text/plain",owned!.id)}
    onDragOver={e=>{if(onDropItem&&!locked)e.preventDefault();}} onDrop={e=>{e.preventDefault();onDropItem?.(e.dataTransfer.getData("text/plain"));}}>
    {item ? <ItemIcon item={item} color={owned!.color} /> : <EmptySlot locked={locked} />}
    {shortcut&&<Shortcut value={shortcut} />}
  </button>;
}

export function InventoryPanel({ state, items, selected, setSelected, busy, onAction, preview, onTurn, active, onActivate }: {
  state:CharacterState;items:Item[];selected:string;setSelected:(slot:string)=>void;busy:boolean;
  onAction:(action:"wear"|"move",id:string,slotId?:string)=>void; preview:React.ReactNode; onTurn:()=>void;
  active:string;onActivate:(slot:string)=>void;
}) {
  const owned=state.inventory.find(v=>v.slotId===selected),item=owned&&items.find(i=>i.id===owned.itemId)!;
  const quick=selected.startsWith("hotbar:");
  const storage=quick||selected.startsWith("bag:");
  const destinations=quick ? Array.from({length:state.capacity},(_,i)=>`bag:${i}`) : Array.from({length:10},(_,i)=>`hotbar:${i}`);
  const destination=destinations.find(slot=>!state.inventory.some(v=>v.slotId===slot));
  function drop(id:string,slot:string) {
    const moving=state.inventory.find(v=>v.id===id);
    if(!moving)return;
    if(equipmentSlots.some(([key])=>key===slot)) {
      if(items.find(i=>i.id===moving.itemId)!.slotId===slot && moving.slotId!==slot)onAction("wear",id);
    } else onAction("move",id,slot);
  }
  const slot=(key:string,label:string,locked=false,shortcut?:string)=><InventorySlot key={key} slot={key} label={label} items={items}
    owned={state.inventory.find(v=>v.slotId===key)} locked={locked} selected={selected===key} disabled={busy} shortcut={shortcut}
    onClick={()=>{setSelected(key);if(key.startsWith("hotbar:"))onActivate(key);}} onDoubleClick={()=>{const v=state.inventory.find(v=>v.slotId===key);if(v)onAction("wear",v.id);}}
    onDropItem={id=>drop(id,key)} />;
  return <>
    <div className="inventory-character-row">
      <div className="inventory-character"><PixelText>{state.profile!.name}</PixelText><div className="character-stage">{preview}</div><GameButton onClick={onTurn}>转身</GameButton></div>
      <div className="equipment-grid">{equipmentSlots.map(([key,label])=><div className="equipment-cell" key={key}>{slot(key,label)}<PixelText>{label}</PixelText></div>)}<div className="equipment-cell">{slot(active,"手持")}<PixelText>手持</PixelText></div></div>
    </div>
    <div className="inventory-capacity"><PixelText>{`背包 ${state.inventory.filter(v=>v.slotId.startsWith("bag:")).length}/${state.capacity}`}</PixelText></div>
    <div className="inventory-grid" aria-label="背包格子">{Array.from({length:30},(_,i)=>slot(`bag:${i}`,`背包格 ${i+1}`,i>=state.capacity))}</div>
    <div className="inventory-capacity"><PixelText>物品栏</PixelText></div>
    <div className="inventory-grid inventory-quickbar" aria-label="物品栏">{Array.from({length:10},(_,i)=>slot(`hotbar:${i}`,`物品栏 ${i+1}`,false,String((i+1)%10)))}</div>
    <div className="inventory-actions">
      <div className="inventory-selection"><PixelText>{item?.name||"选择物品"}</PixelText></div>
      {owned&&<GameButton disabled={busy} onClick={()=>onAction("wear",owned.id)}>{storage?"穿上":"脱下"}</GameButton>}
      {owned&&storage&&destination&&<GameButton disabled={busy} onClick={()=>onAction("move",owned.id,destination)}>{quick?"放入背包":"移至物品栏"}</GameButton>}
    </div>
  </>;
}

export function Hotbar({state,items,active,onSelect,onOpen}:{state:CharacterState;items:Item[];active:string;onSelect:(slot:string)=>void;onOpen:()=>void}) {
  return <div className="inventory-hotbar" aria-label="快捷物品栏">
    <div className="hotbar-slots">{Array.from({length:10},(_,i)=><InventorySlot key={i} slot={`hotbar:${i}`} label={`快捷栏 ${i+1}`} items={items}
      owned={state.inventory.find(v=>v.slotId===`hotbar:${i}`)} selected={active===`hotbar:${i}`} shortcut={String((i+1)%10)} onClick={()=>onSelect(`hotbar:${i}`)} />)}</div>
    <GameButton aria-label="背包 (I)" onClick={onOpen}>I</GameButton>
  </div>;
}
