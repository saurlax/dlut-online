import TitleArt from '../components/title-art';
import TitleMenu from '../components/title-menu';

export default function Home() {
  return (
    <main className="title-screen">
      <TitleArt />
      <h1 className="title-logo">
        <img src="/title/dlut-online.png" width="320" height="160" alt="DLUT Online" fetchPriority="high" />
      </h1>
      <TitleMenu />
    </main>
  );
}
