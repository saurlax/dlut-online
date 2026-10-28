import type { Metadata } from 'next';
import MapView from '../campus/map-view';

export const metadata: Metadata = { title: 'DLUT Online' };

export default function Game() {
  return <MapView />;
}
