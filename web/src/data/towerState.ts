// Port of the Flutter `TowerState` model (mobile/lib/models/tower_state.dart).
// Mirrors the Firebase Realtime Database schema at
// `farms/farm_id_1/towers/tower_1`. All parsing uses defaults so the app never
// crashes on partial data.

export type PumpMode = 'auto' | 'manual';

export interface TowerState {
  pumpSpeed: number; // 0–255
  pumpMode: PumpMode; // 'auto' | 'manual'
  pumpState: boolean; // actual pump on/off (firmware-owned)
  pumpSwitch: boolean; // operator intent (manual mode)
  intervalOnMin: number;
  intervalOffMin: number;
  moisture: number; // ADC raw value 0–4095 (firmware-owned)
  waterLevelLow: boolean; // firmware-owned
}

// ---------------------------------------------------------------------------
// Coercion helpers — RTDB values can arrive as unexpected types.
// ---------------------------------------------------------------------------

function asInt(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string' && value.trim() !== '') {
    const n = Number(value);
    if (Number.isFinite(n)) return Math.trunc(n);
  }
  return fallback;
}

function asBool(value: unknown, fallback: boolean): boolean {
  if (typeof value === 'boolean') return value;
  return fallback;
}

function asMode(value: unknown): PumpMode {
  return value === 'auto' ? 'auto' : 'manual';
}

// ---------------------------------------------------------------------------
// Parsing / serialisation
// ---------------------------------------------------------------------------

/**
 * Parses a raw RTDB snapshot value into a {@link TowerState}, using
 * null-coalescing defaults for every field (default mode is 'manual', speed 0,
 * state false, intervals 1).
 */
export function parseTowerState(raw: unknown): TowerState {
  const data = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const sensors =
    data.sensors && typeof data.sensors === 'object'
      ? (data.sensors as Record<string, unknown>)
      : {};

  return {
    pumpSpeed: asInt(data.pump_speed, 0),
    pumpMode: asMode(data.pump_mode),
    pumpState: asBool(data.pump_state, false),
    pumpSwitch: asBool(data.pump_switch, false),
    intervalOnMin: asInt(data.interval_on_min, 1),
    intervalOffMin: asInt(data.interval_off_min, 1),
    moisture: asInt(sensors.moisture, 0),
    waterLevelLow: asBool(sensors.water_level_low, false),
  };
}

/**
 * Serialises a {@link TowerState} to a plain object matching the Firebase
 * schema, including the nested `sensors` key. Used for test round-trips.
 */
export function toMap(state: TowerState): Record<string, unknown> {
  return {
    pump_speed: state.pumpSpeed,
    pump_mode: state.pumpMode,
    pump_state: state.pumpState,
    pump_switch: state.pumpSwitch,
    interval_on_min: state.intervalOnMin,
    interval_off_min: state.intervalOffMin,
    sensors: {
      moisture: state.moisture,
      water_level_low: state.waterLevelLow,
    },
  };
}

// ---------------------------------------------------------------------------
// Computed helpers
// ---------------------------------------------------------------------------

/** Maps a 0.0–1.0 slider percentage to an integer pump speed in 0–255. */
export function sliderToSpeed(percent: number): number {
  const scaled = Math.round(percent * 255);
  return Math.min(255, Math.max(0, scaled));
}

/** Maps {@link TowerState.pumpSpeed} (0–255) to a 0.0–1.0 slider value. */
export function speedPercent(state: TowerState): number {
  return state.pumpSpeed / 255;
}

/** Maps a water-level-low boolean to its display label. */
export function waterLevelLabel(low: boolean): 'Good' | 'Low' {
  return low ? 'Low' : 'Good';
}

/** Returns `'Low'` when the reservoir is low, otherwise `'Good'`. */
export function waterLevelDisplay(state: TowerState): 'Good' | 'Low' {
  return waterLevelLabel(state.waterLevelLow);
}
