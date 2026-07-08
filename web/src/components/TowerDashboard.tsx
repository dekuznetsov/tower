import { useMemo } from 'react';
import { db } from '../firebase';
import { useTower } from '../data/useTower';
import { createTowerRepository } from '../data/towerRepository';
import { useAuth } from '../auth/useAuth';
import { ConnectionBanner } from './ConnectionBanner';
import { SensorCard } from './SensorCard';
import { ModeSwitch } from './ModeSwitch';
import { AutoModePanel } from './AutoModePanel';
import { ManualModePanel } from './ManualModePanel';

export function TowerDashboard() {
  const { state, connected } = useTower();
  const { user, signOutUser } = useAuth();
  const repo = useMemo(() => createTowerRepository(db), []);

  return (
    <div className="dashboard">
      <header className="topbar">
        <h1>Hydroponics Farm</h1>
        <div className="topbar-user">
          <span>{user?.email}</span>
          <button type="button" onClick={() => void signOutUser()}>
            Вийти
          </button>
        </div>
      </header>

      <ConnectionBanner connected={connected} />

      {state === null ? (
        <p className="loading">Завантаження даних теплиці…</p>
      ) : (
        <main className="grid">
          <SensorCard moisture={state.moisture} waterLevelLow={state.waterLevelLow} />
          <ModeSwitch mode={state.pumpMode} onChange={(m) => void repo.setPumpMode(m)} />
          {state.pumpMode === 'auto' ? (
            <AutoModePanel
              intervalOnMin={state.intervalOnMin}
              intervalOffMin={state.intervalOffMin}
              onSave={(on, off) => void repo.setIntervals(on, off)}
            />
          ) : (
            <ManualModePanel
              pumpSwitch={state.pumpSwitch}
              pumpState={state.pumpState}
              pumpSpeed={state.pumpSpeed}
              onToggle={(on) => void repo.setPumpSwitch(on)}
              onSpeedChange={(s) => void repo.setPumpSpeed(s)}
            />
          )}
        </main>
      )}
    </div>
  );
}
