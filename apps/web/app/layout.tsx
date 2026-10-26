import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'DLUT Online',
  description: '以大连理工大学为主题的浏览器像素多人在线校园游戏。',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="zh-CN"><body>{children}</body></html>;
}
