'use client';

import { useEffect, useRef, useState } from 'react';
import type { CampusMap, CampusView } from '../../game/campus-scene';
import MiniMap from './mini-map';

export default function GameHud({ data, view }: { data: CampusMap; view: CampusView }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [showMap, setShowMap] = useState(true);
  const [fullscreen, setFullscreen] = useState(false);
  const [fullscreenError, setFullscreenError] = useState(false);

  useEffect(() => {
    setShowMap(localStorage.getItem('dlut-online:show-minimap') !== 'false');
    function fullscreenChanged() { setFullscreen(Boolean(document.fullscreenElement)); }
    function keydown(event: KeyboardEvent) {
      if (event.key === 'Escape' && !dialog.current!.open) {
        event.preventDefault();
        dialog.current!.showModal();
      }
    }
    document.addEventListener('fullscreenchange', fullscreenChanged);
    document.addEventListener('keydown', keydown);
    return () => {
      document.removeEventListener('fullscreenchange', fullscreenChanged);
      document.removeEventListener('keydown', keydown);
    };
  }, []);

  async function toggleFullscreen() {
    setFullscreenError(false);
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await document.documentElement.requestFullscreen();
    } catch {
      setFullscreenError(true);
    }
  }

  return (
    <>
      <aside className="game-hud" aria-label="游戏界面">
        {showMap && <MiniMap data={data} view={view} />}
        <button className="hud-settings" type="button" aria-label="设置" aria-haspopup="dialog" onClick={() => dialog.current!.showModal()}>
          <svg viewBox="0 0 16 16" aria-hidden="true" shapeRendering="crispEdges">
            <path fill="currentColor" fillRule="evenodd" d="M6 1h4v2h2V2h2v2h-1v2h2v4h-2v2h1v2h-2v-1h-2v2H6v-2H4v1H2v-2h1v-2H1V6h2V4H2V2h2v1h2V1ZM6 6v4h4V6H6Z" />
          </svg>
        </button>
      </aside>
      <dialog className="game-settings" ref={dialog} aria-labelledby="settings-title" onClick={event => { if (event.target === dialog.current) dialog.current.close(); }}>
        <div className="settings-content">
          <h2 id="settings-title">设置</h2>
          <label className="settings-option">
            <span>显示小地图</span>
            <input type="checkbox" checked={showMap} onChange={event => {
              setShowMap(event.target.checked);
              localStorage.setItem('dlut-online:show-minimap', String(event.target.checked));
            }} />
          </label>
          <button className="settings-action" type="button" onClick={toggleFullscreen}>{fullscreen ? '退出全屏' : '进入全屏'}</button>
          {fullscreenError && <p className="settings-error" role="alert">无法切换全屏</p>}
          <a className="settings-action" href="/">返回标题</a>
          <form method="dialog"><button className="settings-resume" type="submit">继续游戏</button></form>
        </div>
      </dialog>
    </>
  );
}
