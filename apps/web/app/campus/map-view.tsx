'use client';

import dynamic from 'next/dynamic';
import { useEffect, useState } from 'react';
import { readGameSession, type GameSession } from '../../game/game-session';

const MapCanvas = dynamic(() => import('./map-canvas'), { ssr: false });

export default function MapView() {
  const [session, setSession] = useState<GameSession | null>(null);
  useEffect(() => {
    const prepared = readGameSession();
    if (!prepared) {
      window.location.replace('/');
      return;
    }
    setSession(prepared);
  }, []);
  return session && <MapCanvas session={session} />;
}
