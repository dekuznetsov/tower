// Port of the Flutter `TowerRepository` (mobile/lib/repositories/tower_repository.dart).
// Encapsulates all Firebase Realtime Database write operations for a single tower.
// The web app never writes firmware-owned fields (pump_state, moisture, water_level_low).

import { ref, child, set, update, type Database } from 'firebase/database';
import type { PumpMode } from './towerState';

export const TOWER_PATH = 'farms/farm_id_1/towers/tower_1';

export interface TowerRepository {
  /** Writes `pump_mode` ('auto' | 'manual'). */
  setPumpMode(mode: PumpMode): Promise<void>;
  /** Writes `pump_switch` (operator intent in manual mode). */
  setPumpSwitch(on: boolean): Promise<void>;
  /** Writes `pump_speed` as an integer clamped to 0–255. */
  setPumpSpeed(speed: number): Promise<void>;
  /** Atomically writes `interval_on_min` and `interval_off_min`. */
  setIntervals(onMin: number, offMin: number): Promise<void>;
}

/** Creates a {@link TowerRepository} backed by the given database instance. */
export function createTowerRepository(database: Database): TowerRepository {
  const towerRef = ref(database, TOWER_PATH);

  return {
    setPumpMode: (mode) => set(child(towerRef, 'pump_mode'), mode),
    setPumpSwitch: (on) => set(child(towerRef, 'pump_switch'), on),
    setPumpSpeed: (speed) => {
      const clamped = Math.min(255, Math.max(0, Math.trunc(speed)));
      return set(child(towerRef, 'pump_speed'), clamped);
    },
    setIntervals: (onMin, offMin) =>
      update(towerRef, { interval_on_min: onMin, interval_off_min: offMin }),
  };
}
