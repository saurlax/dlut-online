"use client";

import { useEffect, useRef } from "react";
import { request } from "../../game/game-session";
import "./environment.css";

export default function Environment({token}:{token:string}) {
  const canvas=useRef<HTMLCanvasElement>(null);
  useEffect(()=>{
    const surface=canvas.current!, context=surface.getContext('2d')!;
    let weatherCode:number|null=null, serverOffset=0, active=true, frame=0;
    function resize(){surface.width=Math.ceil(window.innerWidth/4);surface.height=Math.ceil(window.innerHeight/4);}
    async function refresh(){
      try {const result=await request('/api/v1/weather',token);if(active){weatherCode=result.weather.weather_code;serverOffset=result.serverTime-Date.now();}}
      catch {if(active)weatherCode=null;}
    }
    function draw(time:number){
      const w=surface.width,h=surface.height;
      context.clearRect(0,0,w,h);
      const date=new Date(Date.now()+serverOffset+8*3600000);
      const hour=date.getUTCHours()+date.getUTCMinutes()/60;
      const daylight=Math.max(0,Math.min(1,Math.sin((hour-6)*Math.PI/12)*2));
      context.fillStyle=`rgba(15,30,65,${(1-daylight)*0.36})`;context.fillRect(0,0,w,h);
      if(weatherCode!==null){
        const rain=(weatherCode>=51 && weatherCode<=67)||(weatherCode>=80 && weatherCode<=82)||weatherCode>=95;
        const snow=(weatherCode>=71 && weatherCode<=77)||(weatherCode>=85 && weatherCode<=86);
        const fog=weatherCode===45||weatherCode===48;
        if(rain||snow){
          context.fillStyle=rain?'rgba(186,220,237,.7)':'rgba(255,255,255,.85)';
          const count=Math.floor(w*h/(rain?600:900));
          for(let i=0;i<count;i++){
            const x=((i*89+Math.floor(time/(rain?70:220)))%w);
            const y=((i*137+Math.floor(time/(rain?35:130)))%h);
            context.fillRect(x,y,1,rain?3:1);
          }
        }
        if(fog){context.fillStyle='rgba(218,228,224,.28)';context.fillRect(0,0,w,h);}
      }
      frame=requestAnimationFrame(draw);
    }
    resize();window.addEventListener('resize',resize);void refresh();
    const timer=window.setInterval(()=>void refresh(),5*60*1000);
    frame=requestAnimationFrame(draw);
    return ()=>{active=false;cancelAnimationFrame(frame);clearInterval(timer);window.removeEventListener('resize',resize);};
  },[token]);
  return <canvas ref={canvas} className="environment-overlay" aria-hidden="true" />;
}
