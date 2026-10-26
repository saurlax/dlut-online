import type { Metadata } from 'next';
import MapView from './map-view';

export const metadata: Metadata = { title: 'DLUT Online' };

export default function Campus() {
  return <MapView />;
}
