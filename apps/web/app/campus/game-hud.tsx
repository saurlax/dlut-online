'use client';

import { useEffect, useState } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { GameButton, GameIcon, GameLink } from '../../components/game-button';
import PixelText from '../../components/pixel-text';
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
      if (event.key === 'Escape' && !event.defaultPrevented && !open) {
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
          <GameButton appearance="icon" icon="settings" aria-label="设置" />
        </Dialog.Trigger>
      </aside>
      <Dialog.Portal container={portal}>
        <Dialog.Overlay className="game-dialog-overlay" />
        <Dialog.Content className="game-dialog game-settings" aria-describedby={undefined}>
          <header className="game-dialog-header">
            <GameIcon name="sprout" />
            <Dialog.Title><PixelText>设置</PixelText></Dialog.Title>
          </header>
          <div className="settings-content">
            <GameButton icon={fullscreen ? 'window' : 'fullscreen'} onClick={toggleFullscreen}>{fullscreen ? '退出全屏' : '进入全屏'}</GameButton>
            {fullscreenError && <p className="settings-error" role="alert"><PixelText>无法切换全屏</PixelText></p>}
            <GameLink icon="home" appearance="secondary" href="/">返回标题</GameLink>
            <Dialog.Close asChild>
              <GameButton icon="sprout" appearance="primary">继续游戏</GameButton>
            </Dialog.Close>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
