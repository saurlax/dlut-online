'use client';

import dynamic from 'next/dynamic';
import { useEffect, useState } from 'react';
import { readGameSession, type GameSession } from '../../game/game-session';
import { BaseAuthStore } from 'pocketbase';

const MapCanvas = dynamic(() => import('./map-canvas'), { ssr: false });

export default function MapView() {
  const [session, setSession] = useState<GameSession | null>(null);
  useEffect(() => {
    const prepared = readGameSession();
    const auth = new BaseAuthStore();
    if (prepared) auth.save(prepared.token);
    if (!prepared || !auth.isValid) {
      window.location.replace('/');
      return;
    }
    setSession(prepared);
  }, []);
  return session && <MapCanvas session={session} />;
}
