'use client';

import dynamic from 'next/dynamic';

const MapCanvas = dynamic(() => import('./map-canvas'), { ssr: false });

export default function MapView() {
  return <MapCanvas />;
}
