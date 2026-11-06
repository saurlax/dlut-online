import PixelText from '../components/pixel-text';

export default function NotFound() {
  return <main className="pixel-interface missing-page"><p><PixelText>DLUT Online</PixelText></p><h1><PixelText>这里还没有道路。</PixelText></h1><a href="/"><PixelText>返回首页</PixelText></a></main>;
}
