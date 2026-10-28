"use client";

import { useEffect, useRef, useState } from "react";
import "./joystick.css";

export default function Joystick({onMove}:{onMove:(x:number,y:number)=>void}) {
  const base=useRef<HTMLDivElement>(null);
  const pointer=useRef<number|null>(null);
  const [position,setPosition]=useState({x:0,y:0});
  const [active,setActive]=useState(false);

  function reset() {
    pointer.current=null;
    setPosition({x:0,y:0});setActive(false);onMove(0,0);
  }
  useEffect(()=>{
    const observer=new MutationObserver(()=>{if(document.querySelector('[role="dialog"]')) reset();});
    observer.observe(document.body,{childList:true,subtree:true});
    const hide=()=>{if(document.hidden)reset();};
    window.addEventListener('blur',reset);document.addEventListener('visibilitychange',hide);
    return ()=>{observer.disconnect();window.removeEventListener('blur',reset);document.removeEventListener('visibilitychange',hide);onMove(0,0);};
  },[onMove]);
  function move(event:React.PointerEvent<HTMLDivElement>) {
    if(pointer.current!==event.pointerId)return;
    const rect=base.current!.getBoundingClientRect();
    const radius=rect.width/2;
    const dx=(event.clientX-(rect.left+radius))/radius;
    const dy=(event.clientY-(rect.top+radius))/radius;
    const distance=Math.hypot(dx,dy), factor=distance>1?1/distance:1;
    const x=dx*factor,y=dy*factor;
    setPosition({x,y});onMove(distance<0.12?0:x,distance<0.12?0:y);
  }
  return <div ref={base} className={`mobile-joystick${active?' is-active':''}`} role="application" aria-label="移动摇杆"
    onPointerDown={event=>{if(pointer.current!==null || document.querySelector('[role="dialog"]'))return;event.preventDefault();pointer.current=event.pointerId;event.currentTarget.setPointerCapture(event.pointerId);setActive(true);move(event);}}
    onPointerMove={move}
    onPointerUp={event=>{if(pointer.current===event.pointerId)reset();}}
    onPointerCancel={event=>{if(pointer.current===event.pointerId)reset();}}
    onLostPointerCapture={event=>{if(pointer.current===event.pointerId)reset();}}>
    <div className="mobile-joystick-knob" style={{transform:`translate(${Math.round(position.x*19)}px, ${Math.round(position.y*19)}px)`}} />
  </div>;
}
