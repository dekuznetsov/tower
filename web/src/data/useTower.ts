// Realtime subscription hook: mirrors the Flutter StreamProvider that wraps the
// Firebase `onValue` stream. Emits the live TowerState plus connection status.

import { useEffect, useState } from 'react';
import { ref, onValue } from 'firebase/database';
import { db } from '../firebase';
import { parseTowerState, type TowerState } from './towerState';
import { TOWER_PATH } from './towerRepository';

export interface TowerSnapshot {
  state: TowerState | null;
  connected: boolean;
}

export function useTower(): TowerSnapshot {
  const [state, setState] = useState<TowerState | null>(null);
  const [connected, setConnected] = useState<boolean>(true);

  useEffect(() => {
    const towerRef = ref(db, TOWER_PATH);
    const connectedRef = ref(db, '.info/connected');

    const unsubTower = onValue(towerRef, (snapshot) => {
      setState(parseTowerState(snapshot.val()));
    });
    const unsubConnected = onValue(connectedRef, (snapshot) => {
      setConnected(snapshot.val() === true);
    });

    return () => {
      unsubTower();
      unsubConnected();
    };
  }, []);

  return { state, connected };
}
