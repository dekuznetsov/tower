import { describe, it, expect, vi, beforeEach } from 'vitest';
import fc from 'fast-check';

// Mock the modular Firebase database API so we can assert on paths/payloads
// without a real database.
const setMock = vi.fn<(path: string, value: unknown) => Promise<void>>(() =>
  Promise.resolve(),
);
const updateMock = vi.fn<(path: string, value: unknown) => Promise<void>>(() =>
  Promise.resolve(),
);

vi.mock('firebase/database', () => ({
  ref: (_db: unknown, path: string) => ({ path }),
  child: (parent: { path: string }, p: string) => ({ path: `${parent.path}/${p}` }),
  set: (node: { path: string }, value: unknown) => setMock(node.path, value),
  update: (node: { path: string }, value: unknown) => updateMock(node.path, value),
}));

import { createTowerRepository, TOWER_PATH } from '../src/data/towerRepository';
import { parseTowerState, toMap } from '../src/data/towerState';

const fakeDb = {} as never;

beforeEach(() => {
  setMock.mockClear();
  updateMock.mockClear();
});

const FIRMWARE_FIELDS = ['pump_state', 'moisture', 'water_level_low'];

describe('TowerRepository', () => {
  it('writes control fields to the correct paths', async () => {
    const repo = createTowerRepository(fakeDb);
    await repo.setPumpMode('auto');
    await repo.setPumpSwitch(true);
    await repo.setPumpSpeed(200);

    expect(setMock).toHaveBeenCalledWith(`${TOWER_PATH}/pump_mode`, 'auto');
    expect(setMock).toHaveBeenCalledWith(`${TOWER_PATH}/pump_switch`, true);
    expect(setMock).toHaveBeenCalledWith(`${TOWER_PATH}/pump_speed`, 200);
  });

  it('clamps pump speed into 0–255', async () => {
    const repo = createTowerRepository(fakeDb);
    await repo.setPumpSpeed(999);
    await repo.setPumpSpeed(-50);
    expect(setMock).toHaveBeenCalledWith(`${TOWER_PATH}/pump_speed`, 255);
    expect(setMock).toHaveBeenCalledWith(`${TOWER_PATH}/pump_speed`, 0);
  });

  // Feature: web-app-google-auth, Property W6: Interval round-trip
  it('W6: setIntervals writes the same integers that parse back out', async () => {
    const repo = createTowerRepository(fakeDb);
    await fc.assert(
      fc.asyncProperty(
        fc.integer({ min: 1, max: 1440 }),
        fc.integer({ min: 1, max: 1440 }),
        async (onMin, offMin) => {
          updateMock.mockClear();
          await repo.setIntervals(onMin, offMin);
          expect(updateMock).toHaveBeenCalledWith(TOWER_PATH, {
            interval_on_min: onMin,
            interval_off_min: offMin,
          });
          // The written payload, once merged into a snapshot, parses back unchanged.
          const merged = { ...toMap(parseTowerState(null)), interval_on_min: onMin, interval_off_min: offMin };
          const parsed = parseTowerState(merged);
          expect(parsed.intervalOnMin).toBe(onMin);
          expect(parsed.intervalOffMin).toBe(offMin);
        },
      ),
      { numRuns: 100 },
    );
  });

  // Feature: web-app-google-auth, Property W8: Firmware-owned fields are never written
  it('W8: no repository method writes pump_state, moisture, or water_level_low', async () => {
    const repo = createTowerRepository(fakeDb);
    await repo.setPumpMode('manual');
    await repo.setPumpSwitch(false);
    await repo.setPumpSpeed(100);
    await repo.setIntervals(2, 3);

    const writtenPaths = setMock.mock.calls.map((c) => String(c[0]));
    for (const path of writtenPaths) {
      for (const field of FIRMWARE_FIELDS) {
        expect(path.endsWith(`/${field}`)).toBe(false);
      }
    }
    const updatePayloads = updateMock.mock.calls.map((c) => c[1] as Record<string, unknown>);
    for (const payload of updatePayloads) {
      for (const field of FIRMWARE_FIELDS) {
        expect(Object.keys(payload)).not.toContain(field);
      }
    }
  });
});
