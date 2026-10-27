'use client';

import { useEffect, useState } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { GameButton, GameLink } from '../../components/game-button';
import PixelText from '../../components/pixel-text';
import GameDialogClose from '../../components/game-dialog-close';
import '../../components/game-dialog.css';

export default function GameHud({ portal }: { portal: HTMLElement | null }) {
  const [open, setOpen] = useState(false);
  const [fullscreen, setFullscreen] = useState(false);
  const [fullscreenError, setFullscreenError] = useState(false);

  useEffect(() => {
    function fullscreenChanged() { setFullscreen(Boolean(document.fullscreenElement)); }
    fullscreenChanged();
    document.addEventListener('fullscreenchange', fullscreenChanged);
    return () => document.removeEventListener('fullscreenchange', fullscreenChanged);
  }, []);

  useEffect(() => {
    function keydown(event: KeyboardEvent) {
      if (event.key === 'Escape' && !event.defaultPrevented && !open && !document.querySelector('[role="dialog"]')) {
        event.preventDefault();
        setOpen(true);
      }
    }
    document.addEventListener('keydown', keydown);
    return () => document.removeEventListener('keydown', keydown);
  }, [open]);

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
      <aside className="game-hud" aria-label="游戏界面">
        <Dialog.Trigger asChild>
          <GameButton appearance="icon" aria-label="设置">⚙</GameButton>
        </Dialog.Trigger>
      </aside>
      <Dialog.Portal container={portal}>
        <Dialog.Overlay className="game-dialog-overlay" />
        <Dialog.Content className="game-dialog game-settings" aria-describedby={undefined}>
          <header className="game-dialog-header">
            <Dialog.Title><PixelText>设置</PixelText></Dialog.Title>
            <GameDialogClose />
          </header>
          <div className="settings-content">
            <GameButton onClick={toggleFullscreen}>{fullscreen ? '退出全屏' : '进入全屏'}</GameButton>
            {fullscreenError && <p className="settings-error" role="alert"><PixelText wrap>无法切换全屏</PixelText></p>}
            <GameLink appearance="secondary" href="/">返回标题</GameLink>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
