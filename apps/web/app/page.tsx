import { GameLink } from '../components/game-button';

export default function Home() {
  return (
    <main className="title-screen">
      <div className="title-landscape" aria-hidden="true" />
      <section className="title-menu" aria-label="游戏主菜单">
        <h1 className="title-logo">
          <img src="/title/dlut-online.png" width="320" height="160" alt="DLUT Online" fetchPriority="high" />
        </h1>
        <GameLink className="campus-entry" href="/campus/" icon="sprout">进入校园</GameLink>
      </section>
    </main>
  );
}
