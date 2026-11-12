import { useEffect, useRef, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { Map as LibreMap, Marker, setWorkerUrl, type LngLatBoundsLike } from "maplibre-gl";
import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?url";
import { GameButton } from "../../components/game-button";
import PixelText from "../../components/pixel-text";
import { interfaceGrid } from "../../game/interface-scale";
import type { AtlasCampus, AtlasLandmark, Coordinate, WorldAtlas } from "../../game/world-atlas";
import "maplibre-gl/dist/maplibre-gl.css";

setWorkerUrl(workerUrl);

export default function AtlasMap({player, onTravel}: {player: Coordinate | null; onTravel: (landmark: AtlasLandmark) => boolean}) {
  const host = useRef<HTMLDivElement>(null);
  const map = useRef<LibreMap | null>(null);
  const [atlas, setAtlas] = useState<WorldAtlas | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState("");
  const [selected, setSelected] = useState<AtlasLandmark | null>(null);
  const [labels, setLabels] = useState<{element: HTMLElement; content: ReactNode}[]>([]);
  const selectedKey = useRef<string | null>(null);

  useEffect(() => {
    const abort = new AbortController();
    const markers: Marker[] = [];
    let observer: ResizeObserver | undefined;
    let labelObserver: ResizeObserver | undefined;
    let labelFrame = 0;
    async function start() {
      const response = await fetch("/world/atlas/manifest.json", {signal:abort.signal});
      if (!response.ok) throw new Error("Atlas request failed");
      const data: WorldAtlas = await response.json();
      if (abort.signal.aborted) return;
      setAtlas(data);
      const pixelRatio = () => window.devicePixelRatio * interfaceGrid().scale;
      const instance = new LibreMap({container:host.current!, pixelRatio:pixelRatio(), renderWorldCopies:false,
        minZoom:6, maxZoom:18, maxPitch:0,
        ...(player ? {center:player, zoom:17} : {bounds:data.bounds}),
        maxBounds:[[data.bounds[0][0]-2,data.bounds[0][1]-2],[data.bounds[1][0]+2,data.bounds[1][1]+2]],
        attributionControl:false, dragRotate:false, pitchWithRotate:false, touchPitch:false,
        style:{version:8, sources:{region:{type:"image",url:data.image,coordinates:data.coordinates}},
          layers:[{id:"sea",type:"background",paint:{"background-color":"#5094a8"}},
            {id:"region",type:"raster",source:"region",paint:{"raster-resampling":"nearest","raster-fade-duration":0}}]},
      });
      map.current=instance;
      instance.touchZoomRotate.disableRotation();
      instance.keyboard.disableRotation();
      instance.getCanvas().setAttribute("aria-label","大连全域像素地图");
      instance.on("error", () => { if (!abort.signal.aborted) setError("地图加载失败"); });
      observer=new ResizeObserver(() => {
        const ratio = pixelRatio();
        if (instance.getPixelRatio() !== ratio) instance.setPixelRatio(ratio);
        else instance.resize();
      });
      observer.observe(host.current!);
      instance.on("load", () => {
        for (const campus of data.campuses) {
          instance.addSource(campus.id,{type:"image",url:campus.image,coordinates:campus.coordinates});
          instance.addLayer({id:campus.id,type:"raster",source:campus.id,minzoom:10,
            paint:{"raster-resampling":"nearest","raster-fade-duration":0,"raster-opacity":["interpolate",["linear"],["zoom"],10,0,12,1]}});
        }
        const close=(ring:Coordinate[]) => [...ring,ring[0]];
        instance.addSource("landmarks",{type:"geojson",data:{type:"FeatureCollection",features:data.landmarks.map(landmark => ({
          type:"Feature",id:landmark.key,properties:{key:landmark.key},
          geometry:{type:"Polygon",coordinates:[close(landmark.polygon),...landmark.holes.map(close)]},
        }))}});
        instance.addLayer({id:"landmark-fill",type:"fill",source:"landmarks",minzoom:12,
          paint:{"fill-color":"#efd180","fill-opacity":["case",["boolean",["feature-state","selected"],false],0.7,0.01]}});
        instance.addLayer({id:"landmark-lines",type:"line",source:"landmarks",minzoom:14,
          paint:{"line-color":"#fff0a1","line-opacity":["case",["boolean",["feature-state","selected"],false],1,0],"line-width":1}});
        const choose=(landmark:AtlasLandmark) => {
          if (selectedKey.current) instance.setFeatureState({source:"landmarks",id:selectedKey.current},{selected:false});
          selectedKey.current=landmark.key;
          instance.setFeatureState({source:"landmarks",id:landmark.key},{selected:true});
          setSelected(landmark);setError("");scheduleLabels();
        };
        const byKey=new Map(data.landmarks.map(landmark=>[landmark.key,landmark]));
        instance.on("click","landmark-fill",event=>choose(byKey.get(event.features![0].properties.key)!));
        instance.on("mouseenter","landmark-fill",()=>{instance.getCanvas().style.cursor="pointer";});
        instance.on("mouseleave","landmark-fill",()=>{instance.getCanvas().style.cursor="";});
        const portals:{element:HTMLElement;content:ReactNode}[]=[];
        const mapLabels:{element:HTMLElement;minZoom:number;maxZoom:number;priority:number;key?:string;marker:Marker}[]=[];
        for (const campus of data.campuses) {
          const button=document.createElement("button");button.type="button";button.className="atlas-campus-label";
          button.addEventListener("click",event=>{event.stopPropagation();fitCampus(campus);});
          const anchor=campus.id==="lingshui"?"top-right":campus.id==="eda"?"bottom-left":"bottom";
          const marker=new Marker({element:button,anchor,offset:campus.id==="lingshui"?[-8,8]:[8,-8]}).setLngLat(campus.center).addTo(instance);
          markers.push(marker);
          portals.push({element:button,content:<PixelText>{campus.name}</PixelText>});
          mapLabels.push({element:button,marker,minZoom:6,maxZoom:13,priority:0});
        }
        for (const place of data.places) {
          if (data.campuses.some(campus=>Math.hypot(campus.center[0]-place.point[0],campus.center[1]-place.point[1])<0.04)) continue;
          const label=document.createElement("span");label.className="atlas-place-label";
          const marker=new Marker({element:label,anchor:"bottom"}).setLngLat(place.point).addTo(instance);
          markers.push(marker);
          portals.push({element:label,content:<PixelText>{place.name}</PixelText>});
          mapLabels.push({element:label,marker,minZoom:6,maxZoom:13,priority:1});
        }
        for (const detail of data.labels) {
          const landmark=byKey.get(detail.key);
          const label=document.createElement(landmark?"button":"span");
          label.className=`atlas-detail-label atlas-label-${detail.kind}`;
          label.title=landmark?.name??detail.name;
          if (label instanceof HTMLButtonElement) {
            label.type="button";
            label.addEventListener("click",event=>{event.stopPropagation();choose(landmark!);});
          }
          const marker=new Marker({element:label,anchor:"center"}).setLngLat(detail.point).addTo(instance);
          markers.push(marker);
          portals.push({element:label,content:<PixelText>{detail.name}</PixelText>});
          mapLabels.push({element:label,marker,key:detail.key,minZoom:detail.minZoom,maxZoom:19,
            priority:landmark?.primary?2:detail.kind==="area"?3:detail.kind==="road"?4:5});
        }
        if (player) {
          const element=document.createElement("span");element.className="atlas-player";element.setAttribute("role","img");element.setAttribute("aria-label","你的位置");
          markers.push(new Marker({element}).setLngLat(player).addTo(instance));
        }
        function layoutLabels() {
          const zoom=instance.getZoom();
          const viewport=host.current!.getBoundingClientRect();
          const occupied=Array.from(host.current!.parentElement!.querySelectorAll(".atlas-navigation,.atlas-zoom,.atlas-selection,.atlas-attribution")).map(element=>element.getBoundingClientRect());
          for (const label of [...mapLabels].sort((a,b)=>(a.key===selectedKey.current?-1:a.priority)-(b.key===selectedKey.current?-1:b.priority))) {
            label.element.style.visibility="hidden";
            if (zoom<label.minZoom||zoom>=label.maxZoom) continue;
            const rect=label.element.getBoundingClientRect();
            if (rect.right<viewport.left||rect.left>viewport.right||rect.bottom<viewport.top||rect.top>viewport.bottom) continue;
            const intersects=(other:DOMRect)=>rect.left<other.right+3&&rect.right>other.left-3&&rect.top<other.bottom+3&&rect.bottom>other.top-3;
            if (occupied.some(intersects)) continue;
            label.element.style.visibility="visible";occupied.push(rect);
          }
        }
        function scheduleLabels() {cancelAnimationFrame(labelFrame);labelFrame=requestAnimationFrame(layoutLabels);}
        labelObserver=new ResizeObserver(scheduleLabels);
        mapLabels.forEach(label=>labelObserver!.observe(label.element));
        instance.on("move",scheduleLabels);instance.on("resize",scheduleLabels);instance.on("click",scheduleLabels);
        scheduleLabels();setLabels(portals);setLoaded(true);
      });
    }
    start().catch(()=>{if(!abort.signal.aborted)setError("地图加载失败");});
    return () => {abort.abort();cancelAnimationFrame(labelFrame);labelObserver?.disconnect();observer?.disconnect();markers.forEach(marker=>marker.remove());map.current?.remove();map.current=null;};
  }, [player?.[0], player?.[1]]);

  function fitCampus(campus:AtlasCampus) {
    const width=host.current!.clientWidth;
    map.current!.fitBounds(campus.bounds as LngLatBoundsLike,{padding:{top:20,bottom:70,left:15,right:Math.min(120,width*.34)},duration:600});
  }
  return <div className="atlas-view">
    <div className="atlas-canvas" ref={host} />
    {!loaded&&!error&&<div className="atlas-loading" role="progressbar" aria-label="地图加载中" />}
    <nav className="atlas-navigation" aria-label="地图定位">
      {atlas?.campuses.map(campus=><GameButton key={campus.id} disabled={!loaded} onClick={()=>fitCampus(campus)}>{campus.name}</GameButton>)}
      <GameButton disabled={!loaded} onClick={()=>map.current!.fitBounds(atlas!.bounds,{padding:12,duration:600})}>大连全域</GameButton>
    </nav>
    <div className="atlas-zoom" role="group" aria-label="地图缩放">
      <GameButton disabled={!loaded} aria-label="放大地图" onClick={()=>map.current!.zoomIn()}>+</GameButton>
      <GameButton disabled={!loaded} aria-label="缩小地图" onClick={()=>map.current!.zoomOut()}>−</GameButton>
    </div>
    {selected&&<div className="atlas-selection">
      <PixelText wrap>{selected.name}</PixelText>
      <GameButton appearance="primary" onClick={()=>{if(!onTravel(selected))setError("暂时无法传送");}}>快速前往</GameButton>
    </div>}
    {error&&<p className="atlas-error" role="alert"><PixelText>{error}</PixelText></p>}
    <footer className="atlas-attribution">
      <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer"><PixelText>© OpenStreetMap</PixelText></a>
      <a href="https://www.naturalearthdata.com/" target="_blank" rel="noreferrer"><PixelText>Natural Earth</PixelText></a>
      <a href="/world/atlas/NOTICE.txt" target="_blank" rel="noreferrer"><PixelText>Mapzen / USGS / NOAA</PixelText></a>
    </footer>
    {labels.map(({element,content},index)=>createPortal(content,element,String(index)))}
  </div>;
}
