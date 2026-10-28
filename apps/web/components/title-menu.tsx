'use client';

import { useState } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { GameButton } from './game-button';
import CampusEntry from './campus-entry';
import PixelText from './pixel-text';
import GameDialogClose from './game-dialog-close';
import './game-dialog.css';
import './title-menu.css';

function CreditLink({ href, children }: { href: string; children: string }) {
  return <a href={href} target="_blank" rel="noopener noreferrer" className="about-line"><PixelText wrap>{children}</PixelText></a>;
}

export default function TitleMenu() {
  const [portal, setPortal] = useState<HTMLElement | null>(null);
  return (
    <section className="title-menu pixel-interface" aria-label="游戏主菜单" ref={setPortal}>
      <Dialog.Root>
        <div className="title-actions">
          <CampusEntry portal={portal} />
          <Dialog.Trigger asChild><GameButton>关于</GameButton></Dialog.Trigger>
        </div>
        <Dialog.Portal container={portal}>
          <Dialog.Overlay className="game-dialog-overlay" />
          <Dialog.Content className="game-dialog about-dialog" aria-describedby={undefined}>
            <header className="game-dialog-header">
              <Dialog.Title><PixelText>关于</PixelText></Dialog.Title>
              <GameDialogClose />
            </header>
            <div className="about-body" onScroll={(event) => { event.currentTarget.scrollTop = Math.round(event.currentTarget.scrollTop); }}>
              <p><PixelText wrap>DLUT Online</PixelText></p>
              <section>
                <h3><PixelText>地图数据</PixelText></h3>
                <CreditLink href="https://www.openstreetmap.org/copyright">© OpenStreetMap contributors</CreditLink>
                <CreditLink href="https://opendatacommons.org/licenses/odbl/1-0/">ODbL 1.0</CreditLink>
              </section>
              <section>
                <h3><PixelText>字体</PixelText></h3>
                <CreditLink href="https://github.com/TakWolf/fusion-pixel-font">缝合像素字体</CreditLink>
                <p className="about-line"><PixelText wrap>TakWolf 及上游作者</PixelText></p>
                <CreditLink href="/fonts/fusion-pixel/OFL.txt">SIL OFL 1.1</CreditLink>
              </section>
              <section>
                <h3><PixelText>美术</PixelText></h3>
                <p className="about-line"><PixelText wrap>地图贴图与图标由本项目绘制</PixelText></p>
                <p className="about-line"><PixelText wrap>标题插画采用 AI 生成与像素整理</PixelText></p>
              </section>
              <section>
                <h3><PixelText>实景参考</PixelText></h3>
                <CreditLink href="https://www.dlut.edu.cn/">大连理工大学</CreditLink>
                <CreditLink href="http://map.dlut.edu.cn/">校园地图</CreditLink>
                <p className="about-line"><PixelText wrap>参考照片版权归原权利人</PixelText></p>
              </section>
              <section>
                <h3><PixelText>风格参考</PixelText></h3>
                <CreditLink href="https://stardewvalleywiki.com/File:ThePond.png">星露谷物语</CreditLink>
                <p><PixelText wrap>ConcernedApe</PixelText></p>
              </section>
              <section>
                <h3><PixelText>界面交互</PixelText></h3>
                <CreditLink href="https://www.radix-ui.com/primitives">Radix Primitives</CreditLink>
                <CreditLink href="https://github.com/radix-ui/primitives/blob/main/LICENSE">MIT License</CreditLink>
              </section>
            </div>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
    </section>
  );
}
