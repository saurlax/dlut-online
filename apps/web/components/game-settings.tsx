'use client';

import { useEffect, useState } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { GameButton, GameLink } from './game-button';
import PixelText from './pixel-text';
import GameDialogClose from './game-dialog-close';
import { interfaceSizes, setInterfaceScale, watchInterfaceGrid } from '../game/interface-scale';
import './game-dialog.css';
import './game-settings.css';

export default function GameSettings({ portal, inGame = false }: { portal: HTMLElement | null; inGame?: boolean }) {
  const [open, setOpen] = useState(false);
  const [fullscreen, setFullscreen] = useState(false);
  const [fullscreenError, setFullscreenError] = useState(false);
  const [interfaceScale, setScale] = useState<number>(1.5);

  useEffect(() => watchInterfaceGrid(grid => setScale(grid.scale)), []);

  useEffect(() => {
    function fullscreenChanged() { setFullscreen(Boolean(document.fullscreenElement)); }
    fullscreenChanged();
    document.addEventListener('fullscreenchange', fullscreenChanged);
    return () => document.removeEventListener('fullscreenchange', fullscreenChanged);
  }, []);

  useEffect(() => {
    if (!inGame) return;
    function keydown(event: KeyboardEvent) {
      if (event.key === 'Escape' && !event.defaultPrevented && !open && !document.querySelector('[role="dialog"]')) {
        event.preventDefault();
        setOpen(true);
      }
    }
    document.addEventListener('keydown', keydown);
    return () => document.removeEventListener('keydown', keydown);
  }, [open, inGame]);

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
    <Dialog.Root open={open} onOpenChange={setOpen}>
      {inGame ? <aside className="game-hud" aria-label="游戏界面">
        <Dialog.Trigger asChild><GameButton appearance="icon" aria-label="设置">⚙</GameButton></Dialog.Trigger>
      </aside> : <Dialog.Trigger asChild><GameButton>设置</GameButton></Dialog.Trigger>}
      <Dialog.Portal container={portal}>
        <Dialog.Overlay className="game-dialog-overlay" />
        <Dialog.Content className="game-dialog game-settings" aria-describedby={undefined}>
          <header className="game-dialog-header">
            <Dialog.Title><PixelText>设置</PixelText></Dialog.Title>
            <GameDialogClose />
          </header>
          <div className="settings-content">
            <div className="settings-interface-size">
              <PixelText>界面尺寸</PixelText>
              <div className="interface-size-options" role="group" aria-label="界面尺寸">
                {interfaceSizes.map(size => <GameButton key={size.scale} aria-pressed={interfaceScale === size.scale} onClick={() => setInterfaceScale(size.scale)}>{size.label}</GameButton>)}
              </div>
            </div>
            <GameButton onClick={toggleFullscreen}>{fullscreen ? '退出全屏' : '进入全屏'}</GameButton>
            {fullscreenError && <p className="settings-error" role="alert"><PixelText wrap>无法切换全屏</PixelText></p>}
            {inGame && <GameLink appearance="secondary" href="/">返回标题</GameLink>}
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
