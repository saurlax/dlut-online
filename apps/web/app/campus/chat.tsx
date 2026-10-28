"use client";

import { useEffect, useRef, useState } from "react";
import { flushSync } from "react-dom";
import { request } from "../../game/game-session";
import PixelText from "../../components/pixel-text";
import { GameButton } from "../../components/game-button";
import "./chat.css";

type ChatEvent = {type:"join"|"leave"|"message";name:string;text?:string};
type Message = {line:string; receivedAt:number};

export default function Chat({token}:{token:string}) {
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
    const abort=new AbortController();
    async function connect() {
      const response=await fetch('/api/v1/chat/events',{headers:{Authorization:token},signal:abort.signal});
      if(!response.ok || !response.body) throw new Error('聊天连接失败');
      const reader=response.body.pipeThrough(new TextDecoderStream()).getReader();
      let buffer="";
      while(true) {
        const {value,done}=await reader.read(); if(done) break;
        buffer+=value;
        let end:number;
        while((end=buffer.indexOf('\n\n'))>=0) {
          const entry=buffer.slice(0,end); buffer=buffer.slice(end+2);
          if(!entry.startsWith('data: ')) continue;
          const event:ChatEvent=JSON.parse(entry.slice(6));
          const line=event.type==='message' ? `${event.name}：${event.text}` : `${event.name} ${event.type==='join'?'进入了服务器':'离开了服务器'}`;
          setMessages(current=>[...current.slice(-49),{line,receivedAt:Date.now()}]);
        }
      }
      if(!abort.signal.aborted) addMessages(['聊天连接断开']);
    }
    void connect().catch(()=>{if(!abort.signal.aborted)addMessages(['聊天连接断开']);});
    return ()=>abort.abort();
  },[token]);
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
        const result=await request('/api/v1/commands',token,{command:text.trim()});
        addMessages(result.message.split('\n'));
      } else await request('/api/v1/chat/messages',token,{text});
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
