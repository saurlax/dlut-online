import { lazy, Suspense, useEffect, useState } from 'react';
import { readGameSession, returnToLogin, type GameSession } from '../../game/game-session';
import { BaseAuthStore } from 'pocketbase';

const MapCanvas = lazy(() => import('./map-canvas'));

export default function MapView() {
  const [session, setSession] = useState<GameSession | null>(null);
  useEffect(() => {
    const prepared = readGameSession();
    if (!prepared) {
      window.location.replace('/');
      return;
    }
    const auth = new BaseAuthStore();
    if (!prepared.guest) auth.save(prepared.token);
    if (prepared.guest ? prepared.guest.expiresAt <= Date.now() : !auth.isValid) {
      returnToLogin();
      return;
    }
    setSession(prepared);
  }, []);
  return session && <Suspense fallback={null}><MapCanvas session={session} /></Suspense>;
}
