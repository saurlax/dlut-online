export default function Home() {
  return (
    <main className="title-screen">
      <div className="title-landscape" aria-hidden="true" />
      <section className="title-menu" aria-label="游戏主菜单">
        <h1 className="title-logo">
          <img src="/title/dlut-online.png" width="320" height="160" alt="DLUT Online" fetchPriority="high" />
        </h1>
        <a className="campus-entry" href="/campus/">
          <span className="entry-arrow" aria-hidden="true" />
          进入校园
        </a>
      </section>
    </main>
  );
}
