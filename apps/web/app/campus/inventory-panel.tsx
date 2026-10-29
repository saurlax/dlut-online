"use client";

import { useEffect, useRef } from "react";
import PixelText from "../../components/pixel-text";
import { GameButton } from "../../components/game-button";
import type { CharacterState, Item, Owned } from "../../game/character";

export const equipmentSlots = [
  ["head", "帽子"], ["top", "上装"], ["bottom", "下装"],
  ["feet", "鞋子"], ["backpack", "背包"],
] as const;

export type CarriedItem = { id:string; x:number; y:number; touch?:boolean };

export function PointerItem({ carried, state, items, host }: { carried:CarriedItem;state:CharacterState;items:Item[];host:HTMLElement }) {
  const cursor = useRef<HTMLDivElement>(null);
  const owned = state.inventory.find(v=>v.id===carried.id)!;
  useEffect(()=>{
    function move(point:{clientX:number;clientY:number}) {
      const bounds=host.getBoundingClientRect(),scale=bounds.width/host.clientWidth;
      cursor.current!.style.transform=`translate(${Math.round((point.clientX-bounds.left)/scale)-8}px,${Math.round((point.clientY-bounds.top)/scale)-8}px)`;
    }
    move({clientX:carried.x,clientY:carried.y});
    window.addEventListener("pointermove",move);
    return ()=>window.removeEventListener("pointermove",move);
  },[carried,host]);
  return <div ref={cursor} className="inventory-pointer" aria-label="拿起的物品"><ItemIcon item={items.find(i=>i.id===owned.itemId)!} color={owned.color} /></div>;
}

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

function LockedSlot() {
  return <svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true" shapeRendering="crispEdges">
    <path fill="currentColor" fillRule="evenodd" d="M6 3h4v1h1v4h1v6H4V8h1V4h1zm1 2v3h2V5zm0 5v2h2v-2z" />
  </svg>;
}

function Shortcut({ value }: { value:string }) {
  const digits = ["111101101101111","010110010010111","111001111100111","111001111001111","101101111001001","111100111001111","111100111101111","111001001001001","111101111101111","111101111001111"];
  return <svg className="slot-shortcut" viewBox="0 0 3 5" width="3" height="5" aria-hidden="true" shapeRendering="crispEdges">
    {[...digits[Number(value)]].map((v,i)=>v==="1"?<rect key={i} x={i%3} y={Math.floor(i/3)} width="1" height="1" fill="currentColor" />:null)}
  </svg>;
}

export function InventorySlot({ slot, owned, items, placeholder, locked=false, selected=false, label, shortcut, disabled, onClick, onPointerDown, onPointerMove, onPointerUp, onPointerCancel }: {
  slot:string; owned?:Owned; items:Item[]; locked?:boolean; selected?:boolean; label:string; shortcut?:string;
  placeholder?:Item;disabled?:boolean; onClick:(event:React.MouseEvent<HTMLButtonElement>)=>void;
  onPointerDown?:(event:React.PointerEvent<HTMLButtonElement>)=>void;onPointerMove?:(event:React.PointerEvent<HTMLButtonElement>)=>void;
  onPointerUp?:(event:React.PointerEvent<HTMLButtonElement>)=>void;onPointerCancel?:(event:React.PointerEvent<HTMLButtonElement>)=>void;
}) {
  const item=owned ? items.find(i=>i.id===owned.itemId)! : undefined;
  return <button type="button" className={`inventory-slot${locked?" is-locked":""}${selected?" is-selected":""}`}
    aria-label={`${label}${locked?" 未解锁":item?` ${item.name}`:" 空"}`} aria-pressed={selected} disabled={locked||disabled}
    data-slot={slot} onClick={onClick} onPointerDown={onPointerDown} onPointerMove={onPointerMove} onPointerUp={onPointerUp} onPointerCancel={onPointerCancel}>
    {item ? <ItemIcon item={item} color={owned!.color} /> : locked ? <LockedSlot /> : placeholder ? <span className="equipment-placeholder"><ItemIcon item={placeholder} color={0} /></span> : null}
    {shortcut&&<Shortcut value={shortcut} />}
  </button>;
}

export function InventoryPanel({ state, items, selected, setSelected, busy, onMove, preview, onActivate, carried, onCarry }: {
  state:CharacterState;items:Item[];selected:string;setSelected:(slot:string)=>void;busy:boolean;
  onMove:(id:string,slotId:string)=>Promise<boolean>; preview:React.ReactNode;
  onActivate:(slot:string)=>void;
  carried:CarriedItem|null;onCarry:(item:CarriedItem|null)=>void;
}) {
  const touch=useRef<{pointerId:number;id:string;slot:string;x:number;y:number;dragging:boolean}|null>(null);
  const lastPointer=useRef('mouse');
  const suppressClick=useRef(false);
  async function click(slotId:string,event:React.MouseEvent<HTMLButtonElement>) {
    if(suppressClick.current){suppressClick.current=false;return;}
    setSelected(slotId);
    if(slotId.startsWith("hotbar:"))onActivate(slotId);
    const owned=state.inventory.find(v=>v.slotId===slotId);
    if(!carried) {
      if(owned)onCarry({id:owned.id,x:event.clientX,y:event.clientY,touch:lastPointer.current==='touch'});
    } else if(owned?.id===carried.id) {
      onCarry(null);
    } else {
      const point={x:event.clientX,y:event.clientY,touch:lastPointer.current==='touch'};
      if(await onMove(carried.id,slotId))onCarry(owned?{id:owned.id,...point}:null);
    }
  }
  function pointerDown(slotId:string,event:React.PointerEvent<HTMLButtonElement>) {
    lastPointer.current=event.pointerType;
    if(event.pointerType!=='touch' || carried || busy)return;
    const owned=state.inventory.find(v=>v.slotId===slotId);
    if(!owned)return;
    touch.current={pointerId:event.pointerId,id:owned.id,slot:slotId,x:event.clientX,y:event.clientY,dragging:false};
    event.currentTarget.setPointerCapture(event.pointerId);
  }
  function pointerMove(event:React.PointerEvent<HTMLButtonElement>) {
    const drag=touch.current;if(!drag || drag.pointerId!==event.pointerId)return;
    if(!drag.dragging && Math.hypot(event.clientX-drag.x,event.clientY-drag.y)>8) {
      drag.dragging=true;onCarry({id:drag.id,x:event.clientX,y:event.clientY,touch:true});
    }
  }
  async function pointerUp(event:React.PointerEvent<HTMLButtonElement>) {
    const drag=touch.current;if(!drag || drag.pointerId!==event.pointerId)return;
    touch.current=null;if(!drag.dragging)return;
    suppressClick.current=true;
    window.setTimeout(()=>{suppressClick.current=false;},0);
    const target=document.elementFromPoint(event.clientX,event.clientY)?.closest<HTMLButtonElement>('.wardrobe-inventory [data-slot]');
    const slotId=target?.dataset.slot;
    if(!target || target.disabled || !slotId || slotId===drag.slot){onCarry(null);return;}
    const owned=state.inventory.find(v=>v.slotId===slotId);
    if(await onMove(drag.id,slotId)) {setSelected(slotId);if(slotId.startsWith('hotbar:'))onActivate(slotId);onCarry(owned?{id:owned.id,x:event.clientX,y:event.clientY,touch:true}:null);}
    else onCarry(null);
  }
  const slot=(key:string,label:string,locked=false,shortcut?:string)=><InventorySlot key={key} slot={key} label={label} items={items}
    placeholder={items.find(item=>item.slotId===key)}
    owned={state.inventory.find(v=>v.slotId===key&&v.id!==carried?.id)} locked={locked} selected={selected===key} disabled={busy} shortcut={shortcut}
    onClick={event=>void click(key,event)} onPointerDown={event=>pointerDown(key,event)} onPointerMove={pointerMove}
    onPointerUp={event=>void pointerUp(event)} onPointerCancel={()=>{touch.current=null;onCarry(null);}} />;
  return <>
    <div className="inventory-character-row">
      <div className="inventory-character-group">
      <PixelText>{state.profile!.name}</PixelText>
      <div className="equipment-grid">
        <div className="character-stage">{preview}</div>
        {equipmentSlots.map(([key,label])=><div className={`equipment-cell equipment-cell--${key}`} key={key}>{slot(key,label)}</div>)}
      </div>
      </div>
      {carried?.touch && <div className="inventory-held" aria-label="拿起的物品"><ItemIcon item={items.find(item=>item.id===state.inventory.find(v=>v.id===carried.id)!.itemId)!} color={state.inventory.find(v=>v.id===carried.id)!.color} /></div>}
    </div>
    <div className="inventory-capacity"><PixelText>{`背包 ${state.inventory.filter(v=>v.slotId.startsWith("bag:")).length}/${state.capacity}`}</PixelText></div>
    <div className="inventory-grid" aria-label="背包格子">{Array.from({length:30},(_,i)=>slot(`bag:${i}`,`背包格 ${i+1}`,i>=state.capacity))}</div>
    <div className="inventory-grid inventory-quickbar" aria-label="物品栏">{Array.from({length:10},(_,i)=>slot(`hotbar:${i}`,`物品栏 ${i+1}`,false,String((i+1)%10)))}</div>
  </>;
}

export function Hotbar({state,items,active,onSelect,onOpen,carriedId}:{state:CharacterState;items:Item[];active:string;onSelect:(slot:string)=>void;onOpen:()=>void;carriedId?:string}) {
  const slots = useRef<HTMLDivElement>(null);
  useEffect(() => {
    slots.current!.querySelector<HTMLButtonElement>(`[data-slot="${active}"]`)!.scrollIntoView({block:"nearest",inline:"nearest"});
  }, [active]);
  return <div className="inventory-hotbar" aria-label="快捷物品栏">
    <div className="hotbar-slots" ref={slots}>{Array.from({length:10},(_,i)=><InventorySlot key={i} slot={`hotbar:${i}`} label={`快捷栏 ${i+1}`} items={items}
      owned={state.inventory.find(v=>v.slotId===`hotbar:${i}`&&v.id!==carriedId)} selected={active===`hotbar:${i}`} shortcut={String((i+1)%10)} onClick={()=>onSelect(`hotbar:${i}`)} />)}</div>
    <GameButton aria-label="背包 (I)" onClick={onOpen}>I</GameButton>
  </div>;
}
