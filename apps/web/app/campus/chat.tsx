"use client";

import { useEffect, useRef, useState } from "react";
import { request } from "../../game/game-session";
import PixelText from "../../components/pixel-text";
import "./chat.css";

type ChatEvent = {type:"join"|"leave"|"message";name:string;text?:string};

export default function Chat({token}:{token:string}) {
  const [messages,setMessages]=useState<string[]>([]);
  const [open,setOpen]=useState(false);
  const [text,setText]=useState("");
  const [error,setError]=useState("");
  const input=useRef<HTMLInputElement>(null);
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
          setMessages(current=>[...current.slice(-49),line]);
        }
      }
      if(!abort.signal.aborted) setError('聊天连接断开');
    }
    void connect().catch(()=>{if(!abort.signal.aborted)setError('聊天连接断开');});
    return ()=>abort.abort();
  },[token]);
  useEffect(()=>{
    function keydown(event:KeyboardEvent) {
      if(event.key!=='Enter' || event.repeat || event.ctrlKey || event.metaKey || event.altKey || (event.target as HTMLElement).closest('input,textarea,select,[contenteditable="true"]') || document.querySelector('[role="dialog"]')) return;
      event.preventDefault();setOpen(true);
    }
    document.addEventListener('keydown',keydown);
    return ()=>document.removeEventListener('keydown',keydown);
  },[]);
  useEffect(()=>{if(open)input.current?.focus();},[open]);
  async function submit(event:React.FormEvent) {
    event.preventDefault();
    if(!text.trim()){setOpen(false);return;}
    try {await request('/api/v1/chat/messages',token,{text});setText('');setError('');setOpen(false);}
    catch(e){setError((e as Error).message);}
  }
  return <div className="game-chat">
    <div className="chat-messages" aria-live="polite">{messages.slice(-6).map((line,index)=><PixelText key={index} wrap>{line}</PixelText>)}</div>
    {open && <form onSubmit={event=>void submit(event)}><input ref={input} aria-label="聊天消息" maxLength={200} value={text} onChange={event=>setText(event.target.value)} onKeyDown={event=>{event.stopPropagation();if(event.key==='Escape'){setOpen(false);setError('');}}} /></form>}
    {error && <PixelText wrap>{error}</PixelText>}
  </div>;
}
