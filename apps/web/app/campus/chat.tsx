"use client";

import { useEffect, useRef, useState } from "react";
import { flushSync } from "react-dom";
import PixelText from "../../components/pixel-text";
import { GameButton } from "../../components/game-button";
import type { RealtimeConnection } from "../../game/realtime";
import "./chat.css";

type ChatEvent = {type:"join"|"leave"|"message";name:string;text?:string};
type Message = {line:string; receivedAt:number};

export default function Chat({realtime}:{realtime:RealtimeConnection}) {
  const [messages,setMessages]=useState<Message[]>([]);
  const [now,setNow]=useState(Date.now());
  const [open,setOpen]=useState(false);
  const [text,setText]=useState("");
  function addMessages(lines:string[]) {setMessages(current=>[...current,...lines.map(line=>({line,receivedAt:Date.now()}))].slice(-50));}
  const input=useRef<HTMLInputElement>(null);
  const history=useRef<HTMLDivElement>(null);
  useEffect(()=>{const timer=window.setInterval(()=>setNow(Date.now()),1000);return ()=>window.clearInterval(timer);},[]);
  useEffect(()=>{if(history.current)history.current.scrollTop=history.current.scrollHeight;},[messages,open]);
  useEffect(()=>{
    return realtime.subscribe(message=>{
      if(message.type==='disconnected'){addMessages(['连接断开，正在重连']);return;}
      if(message.type==='auth_error'){addMessages(['登录已失效，请返回首页']);return;}
      if(message.type!=='chat')return;
      const event=message.data as ChatEvent;
      const line=event.type==='message' ? `${event.name}：${event.text}` : `${event.name} ${event.type==='join'?'进入了服务器':'离开了服务器'}`;
      addMessages([line]);
    });
  },[realtime]);
  useEffect(()=>{
    function keydown(event:KeyboardEvent) {
      if((event.key!=='Enter' && event.key!=='/') || event.repeat || event.ctrlKey || event.metaKey || event.altKey || (event.target as HTMLElement).closest('input,textarea,select,[contenteditable="true"]') || document.querySelector('[role="dialog"]')) return;
      if(event.key==='/') setText('/');
      event.preventDefault();setOpen(true);
    }
    document.addEventListener('keydown',keydown);
    return ()=>document.removeEventListener('keydown',keydown);
  },[]);
  useEffect(()=>{if(open)input.current?.focus();},[open]);
  async function submit(event:React.FormEvent) {
    event.preventDefault();
    if(!text.trim()){setOpen(false);return;}
    try {
      if(text.trim().startsWith('/')) {
        const result=await realtime.send('command',text.trim());
        addMessages(result.split('\n'));
      } else await realtime.send('chat',text);
      setText('');setOpen(false);
    }
    catch(e){addMessages([(e as Error).message]);}
  }
  return <>
  <GameButton className="mobile-chat-button" aria-label={open ? "关闭聊天" : "打开聊天"} onClick={()=>{
    if(open) {setOpen(false);return;}
    flushSync(()=>setOpen(true));input.current?.focus();
  }}>{open ? "×" : "聊"}</GameButton>
  <div className="game-chat">
    <div ref={history} className={`chat-messages${open?' is-open':''}`} aria-live="polite">{messages.filter(message=>open || now-message.receivedAt<10000).map((message,index)=><PixelText key={index} wrap>{message.line}</PixelText>)}</div>
    {open && <form onSubmit={event=>void submit(event)}><input ref={input} aria-label="聊天消息" enterKeyHint="send" maxLength={200} value={text} onChange={event=>setText(event.target.value)} onKeyDown={event=>{event.stopPropagation();if(event.key==='Escape')setOpen(false);}} /></form>}
  </div>
  </>;
}
