import { describe, it, expect } from 'vitest';
import fc from 'fast-check';
import {
  OFFLINE_THRESHOLD_MS,
  buildOfflineMessage,
  buildOnlineMessage,
  buildPumpModeMessage,
  buildWaterLowMessage,
  buildWaterRestoredMessage,
  isOffline,
  pumpModeChanged,
  waterLevelEvent,
} from '../src/monitoring';

const ref = { farmId: 'farm_id_1', towerId: 'tower_1' };

// Feature: google-chat-monitoring-alerts, Property N1: water level alerts are edge-triggered
describe('waterLevelEvent (edge detection)', () => {
  it('alerts "low" only on false/undefined → true transition', () => {
    expect(waterLevelEvent(false, true)).toBe('low');
    expect(waterLevelEvent(undefined, true)).toBe('low');
    expect(waterLevelEvent(true, true)).toBeNull(); // no repeat while still low
  });

  it('alerts "restored" only on true → false transition', () => {
    expect(waterLevelEvent(true, false)).toBe('restored');
    expect(waterLevelEvent(false, false)).toBeNull();
    expect(waterLevelEvent(undefined, false)).toBeNull(); // initial seed, no spam
  });

  it('never alerts when the value is unchanged (heartbeat writes)', () => {
    fc.assert(
      fc.property(fc.boolean(), (v) => {
        expect(waterLevelEvent(v, v)).toBeNull();
      }),
    );
  });
});

// Feature: google-chat-monitoring-alerts, Property N2: pump mode alert only on change
describe('pumpModeChanged', () => {
  it('true only on a change to a non-empty value', () => {
    expect(pumpModeChanged('auto', 'manual')).toBe(true);
    expect(pumpModeChanged('manual', 'manual')).toBe(false);
    expect(pumpModeChanged(undefined, 'auto')).toBe(true);
    expect(pumpModeChanged('auto', null)).toBe(false);
    expect(pumpModeChanged(null, null)).toBe(false);
  });
});

// Feature: google-chat-monitoring-alerts, Property N3: offline threshold semantics
describe('isOffline', () => {
  it('never offline when never seen', () => {
    expect(isOffline(null, Date.now())).toBe(false);
  });

  it('offline exactly when the gap exceeds the threshold', () => {
    fc.assert(
      fc.property(fc.integer({ min: 0, max: 60 * 60 * 1000 }), (gap) => {
        const now = 10_000_000;
        const lastSeen = now - gap;
        expect(isOffline(lastSeen, now, OFFLINE_THRESHOLD_MS)).toBe(gap > OFFLINE_THRESHOLD_MS);
      }),
    );
  });
});

// Feature: google-chat-monitoring-alerts, Property N6: messages identify farm/tower and intent
describe('message builders', () => {
  it('include the farm/tower and the right intent', () => {
    expect(buildWaterLowMessage(ref)).toContain('низький рівень води');
    expect(buildWaterLowMessage(ref)).toContain('farm_id_1');
    expect(buildWaterLowMessage(ref)).toContain('tower_1');
    expect(buildWaterRestoredMessage(ref)).toContain('відновлено');
    expect(buildOfflineMessage(ref, 5)).toContain('5 хв');
    expect(buildOnlineMessage(ref)).toContain('онлайн');
    expect(buildPumpModeMessage(ref, 'auto', 'manual')).toContain('auto → manual');
  });
});
