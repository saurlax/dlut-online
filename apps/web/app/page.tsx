import { GameLink } from '../components/game-button';
import TitleArt from '../components/title-art';

export default function Home() {
  return (
    <main className="title-screen">
      <TitleArt />
      <section className="title-menu pixel-interface" aria-label="游戏主菜单">
        <h1 className="title-logo">DLUT Online</h1>
        <GameLink className="campus-entry" href="/campus/" icon="sprout">进入校园</GameLink>
      </section>
    </main>
  );
}
