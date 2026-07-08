import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, cleanup } from '@testing-library/react';
import type { TowerState } from '../src/data/towerState';

const h = vi.hoisted(() => ({
  state: null as TowerState | null,
  connected: true,
}));

vi.mock('../src/firebase', () => ({ db: {} }));
vi.mock('../src/data/useTower', () => ({
  useTower: () => ({ state: h.state, connected: h.connected }),
}));
vi.mock('../src/data/towerRepository', () => ({
  createTowerRepository: () => ({
    setPumpMode: vi.fn(),
    setPumpSwitch: vi.fn(),
    setPumpSpeed: vi.fn(),
    setIntervals: vi.fn(),
  }),
}));
vi.mock('../src/auth/useAuth', () => ({
  useAuth: () => ({ user: { email: 'op@example.com' }, signOutUser: vi.fn() }),
}));

import { TowerDashboard } from '../src/components/TowerDashboard';

const baseState = (mode: 'auto' | 'manual'): TowerState => ({
  pumpSpeed: 128,
  pumpMode: mode,
  pumpState: false,
  pumpSwitch: false,
  intervalOnMin: 5,
  intervalOffMin: 10,
  moisture: 2048,
  waterLevelLow: false,
});

beforeEach(() => {
  h.state = null;
  h.connected = true;
  cleanup();
});

describe('TowerDashboard (Property W4)', () => {
  // Feature: web-app-google-auth, Property W4: Mode determines visible panel
  it('W4: shows only the Auto panel when pump_mode is "auto"', () => {
    h.state = baseState('auto');
    render(<TowerDashboard />);
    expect(screen.getByRole('heading', { name: 'Авто-режим' })).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'Ручний режим' })).not.toBeInTheDocument();
  });

  it('W4: shows only the Manual panel when pump_mode is "manual"', () => {
    h.state = baseState('manual');
    render(<TowerDashboard />);
    expect(screen.getByRole('heading', { name: 'Ручний режим' })).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'Авто-режим' })).not.toBeInTheDocument();
  });

  it('shows the connection banner only when disconnected', () => {
    h.state = baseState('manual');
    h.connected = false;
    render(<TowerDashboard />);
    expect(screen.getByRole('status')).toHaveTextContent('Немає');
  });
});
