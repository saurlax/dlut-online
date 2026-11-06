import { lazy, Suspense, useEffect, useState } from 'react';
import { readGameSession, type GameSession } from '../../game/game-session';
import { BaseAuthStore } from 'pocketbase';

const MapCanvas = lazy(() => import('./map-canvas'));

export default function MapView() {
  const [session, setSession] = useState<GameSession | null>(null);
  useEffect(() => {
    const prepared = readGameSession();
    const auth = new BaseAuthStore();
    if (prepared && !prepared.guest) auth.save(prepared.token);
    if (!prepared || (prepared.guest ? prepared.guest.expiresAt<=Date.now() : !auth.isValid)) {
      window.location.replace('/');
      return;
    }
    setSession(prepared);
  }, []);
  return session && <Suspense fallback={null}><MapCanvas session={session} /></Suspense>;
}
