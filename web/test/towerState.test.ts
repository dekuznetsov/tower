import { describe, it, expect } from 'vitest';
import fc from 'fast-check';
import {
  parseTowerState,
  toMap,
  sliderToSpeed,
  waterLevelDisplay,
  type TowerState,
} from '../src/data/towerState';

const arbTowerState = (): fc.Arbitrary<TowerState> =>
  fc.record({
    pumpSpeed: fc.integer({ min: 0, max: 255 }),
    pumpMode: fc.constantFrom<'auto' | 'manual'>('auto', 'manual'),
    pumpState: fc.boolean(),
    pumpSwitch: fc.boolean(),
    intervalOnMin: fc.integer({ min: 1, max: 1440 }),
    intervalOffMin: fc.integer({ min: 1, max: 1440 }),
    moisture: fc.integer({ min: 0, max: 4095 }),
    waterLevelLow: fc.boolean(),
  });

describe('TowerState', () => {
  // Feature: web-app-google-auth, Property W1: TowerState serialization round-trip
  it('W1: round-trips through toMap/parseTowerState', () => {
    fc.assert(
      fc.property(arbTowerState(), (state) => {
        expect(parseTowerState(toMap(state))).toEqual(state);
      }),
      { numRuns: 200 },
    );
  });

  // Feature: web-app-google-auth, Property W2: Water level display maps boolean to string
  it('W2: waterLevelDisplay maps false→Good, true→Low', () => {
    fc.assert(
      fc.property(fc.boolean(), (low) => {
        const state = parseTowerState({ sensors: { water_level_low: low } });
        expect(waterLevelDisplay(state)).toBe(low ? 'Low' : 'Good');
      }),
      { numRuns: 100 },
    );
  });

  // Feature: web-app-google-auth, Property W3: Speed slider mapping is monotonic and bounded
  it('W3: sliderToSpeed is bounded to 0–255 and monotonic', () => {
    fc.assert(
      fc.property(
        fc.double({ min: 0, max: 1, noNaN: true, noDefaultInfinity: true }),
        fc.double({ min: 0, max: 1, noNaN: true, noDefaultInfinity: true }),
        (a, b) => {
          const [p1, p2] = a <= b ? [a, b] : [b, a];
          const s1 = sliderToSpeed(p1);
          const s2 = sliderToSpeed(p2);
          expect(s1).toBeGreaterThanOrEqual(0);
          expect(s1).toBeLessThanOrEqual(255);
          expect(s2).toBeLessThanOrEqual(255);
          expect(Number.isInteger(s1)).toBe(true);
          expect(s1).toBeLessThanOrEqual(s2); // monotonic non-decreasing
        },
      ),
      { numRuns: 200 },
    );
  });

  // Unit: defaults on partial / missing / malformed data (never crashes)
  it('applies safe defaults for empty input', () => {
    expect(parseTowerState(null)).toEqual({
      pumpSpeed: 0,
      pumpMode: 'manual',
      pumpState: false,
      pumpSwitch: false,
      intervalOnMin: 1,
      intervalOffMin: 1,
      moisture: 0,
      waterLevelLow: false,
    });
  });

  it('coerces numeric strings and defaults unknown pump_mode to manual', () => {
    const s = parseTowerState({ pump_speed: '128', pump_mode: 'nonsense' });
    expect(s.pumpSpeed).toBe(128);
    expect(s.pumpMode).toBe('manual');
  });

  it('sliderToSpeed hits exact bounds', () => {
    expect(sliderToSpeed(0)).toBe(0);
    expect(sliderToSpeed(1)).toBe(255);
  });
});
