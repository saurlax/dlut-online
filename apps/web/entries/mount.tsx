import { createRoot } from 'react-dom/client';
import type { ReactNode } from 'react';
import PixelGrid from '../components/pixel-grid';
import '../app/globals.css';

export function mount(page: ReactNode) {
  createRoot(document.getElementById('root')!).render(<><PixelGrid />{page}</>);
}
