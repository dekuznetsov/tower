// Pure monitoring logic — no Firebase imports, so it is fully unit-testable.
// Decides whether an event warrants a Google Chat alert (edge-triggered) and
// builds the message text.

/** No sensor update for this long ⇒ the device is considered offline. */
export const OFFLINE_THRESHOLD_MS = 3 * 60 * 1000; // 3 minutes (firmware reports every 30 s)

export interface TowerRef {
  farmId: string;
  towerId: string;
}

export type WaterEvent = 'low' | 'restored' | null;

/**
 * Edge detection for the water level. Fires only on a genuine transition, so
 * the every-30s heartbeat writes never spam the channel.
 */
export function waterLevelEvent(
  before: boolean | undefined,
  after: boolean | undefined,
): WaterEvent {
  if (after === true && before !== true) return 'low';
  if (after === false && before === true) return 'restored';
  return null;
}

/** True when the pump mode actually changed to a new non-empty value. */
export function pumpModeChanged(
  before: string | undefined | null,
  after: string | undefined | null,
): boolean {
  return !!after && before !== after;
}

/**
 * Offline when we have seen the device before (lastSeen set) and the gap since
 * the last report exceeds the threshold. A never-seen device is not "offline".
 */
export function isOffline(
  lastSeen: number | null,
  now: number,
  thresholdMs: number = OFFLINE_THRESHOLD_MS,
): boolean {
  if (lastSeen === null) return false;
  return now - lastSeen > thresholdMs;
}

// ---------------------------------------------------------------------------
// Message builders (Ukrainian, plain text for the Google Chat `text` field)
// ---------------------------------------------------------------------------

const where = (r: TowerRef) => `Ферма ${r.farmId} / башта ${r.towerId}`;

export function buildWaterLowMessage(ref: TowerRef): string {
  return `🚨 *Критично: низький рівень води*\n${where(ref)}. Насос примусово вимкнено для захисту від роботи «на суху».`;
}

export function buildWaterRestoredMessage(ref: TowerRef): string {
  return `✅ Рівень води відновлено\n${where(ref)}. Нормальна робота відновлена.`;
}

export function buildOfflineMessage(ref: TowerRef, minutes: number): string {
  return `⚠️ Пристрій офлайн\n${where(ref)}: немає даних понад ${minutes} хв. Перевірте живлення та WiFi.`;
}

export function buildOnlineMessage(ref: TowerRef): string {
  return `🟢 Пристрій знову онлайн\n${where(ref)}. Дані знову надходять.`;
}

export function buildPumpModeMessage(
  ref: TowerRef,
  before: string | null | undefined,
  after: string | null | undefined,
): string {
  return `ℹ️ Режим помпи змінено: ${before ?? '—'} → ${after ?? '—'}\n${where(ref)}.`;
}
