'use client';

import { useState, type ReactNode } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { GameButton, GameIcon, GameLink } from './game-button';
import PixelText from './pixel-text';
import './game-dialog.css';
import './title-menu.css';

function CreditLink({ href, children }: { href: string; children: ReactNode }) {
  return <a href={href} target="_blank" rel="noopener noreferrer" className="about-line">{children}</a>;
}

export default function TitleMenu() {
  const [portal, setPortal] = useState<HTMLElement | null>(null);
  return (
    <section className="title-menu pixel-interface" aria-label="游戏主菜单" ref={setPortal}>
      <h1 className="title-logo">DLUT Online</h1>
      <Dialog.Root>
        <div className="title-actions">
          <GameLink className="campus-entry" href="/campus/">进入校园</GameLink>
          <Dialog.Trigger asChild><GameButton>关于</GameButton></Dialog.Trigger>
        </div>
        <Dialog.Portal container={portal}>
          <Dialog.Overlay className="game-dialog-overlay" />
          <Dialog.Content className="game-dialog about-dialog" aria-describedby={undefined}>
            <header className="game-dialog-header">
              <GameIcon name="info" />
              <Dialog.Title><PixelText>关于</PixelText></Dialog.Title>
            </header>
            <div className="about-body" onScroll={(event) => { event.currentTarget.scrollTop = Math.round(event.currentTarget.scrollTop); }}>
              <p><PixelText>DLUT Online</PixelText></p>
              <section>
                <h3><PixelText>地图数据</PixelText></h3>
                <CreditLink href="https://www.openstreetmap.org/copyright"><PixelText>© OpenStreetMap</PixelText><PixelText> contributors</PixelText></CreditLink>
                <CreditLink href="https://opendatacommons.org/licenses/odbl/1-0/"><PixelText>ODbL 1.0</PixelText></CreditLink>
              </section>
              <section>
                <h3><PixelText>字体</PixelText></h3>
                <CreditLink href="https://github.com/TakWolf/fusion-pixel-font"><PixelText>缝合像素字体</PixelText></CreditLink>
                <p className="about-line"><PixelText>TakWolf</PixelText><PixelText> 及上游作者</PixelText></p>
                <CreditLink href="/fonts/fusion-pixel/OFL.txt"><PixelText>SIL OFL 1.1</PixelText></CreditLink>
              </section>
              <section>
                <h3><PixelText>美术</PixelText></h3>
                <p className="about-line"><PixelText>地图贴图与图标</PixelText><PixelText>由本项目绘制</PixelText></p>
                <p className="about-line"><PixelText>标题插画采用</PixelText><PixelText>AI 生成与</PixelText><PixelText>像素整理</PixelText></p>
              </section>
              <section>
                <h3><PixelText>实景参考</PixelText></h3>
                <CreditLink href="https://www.dlut.edu.cn/"><PixelText>大连理工大学</PixelText></CreditLink>
                <CreditLink href="http://map.dlut.edu.cn/"><PixelText>校园地图</PixelText></CreditLink>
                <p className="about-line"><PixelText>参考照片版权</PixelText><PixelText>归原权利人</PixelText></p>
              </section>
              <section>
                <h3><PixelText>风格参考</PixelText></h3>
                <CreditLink href="https://stardewvalleywiki.com/File:ThePond.png"><PixelText>星露谷物语</PixelText></CreditLink>
                <p><PixelText>ConcernedApe</PixelText></p>
              </section>
              <section>
                <h3><PixelText>界面交互</PixelText></h3>
                <CreditLink href="https://www.radix-ui.com/primitives"><PixelText>Radix Primitives</PixelText></CreditLink>
                <CreditLink href="https://github.com/radix-ui/primitives/blob/main/LICENSE"><PixelText>MIT License</PixelText></CreditLink>
              </section>
            </div>
            <footer className="about-footer">
              <Dialog.Close asChild><GameButton appearance="primary">返回</GameButton></Dialog.Close>
            </footer>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
    </section>
  );
}
