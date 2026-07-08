// Cloud Functions (2nd gen) that watch the Realtime Database and post monitoring
// alerts to Google Chat via an incoming webhook. Alert-decision logic lives in
// ./monitoring (pure, unit-tested); these handlers are thin glue.
//
// NOTE: the RTDB trigger region must match the database instance region
// (rtdb_region in infra/terraform, default europe-west1).

import { onValueWritten } from 'firebase-functions/v2/database';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineSecret } from 'firebase-functions/params';
import { initializeApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
import { sendChatMessage } from './chat';
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
} from './monitoring';

initializeApp();

const REGION = 'europe-west1';
const WEBHOOK = defineSecret('GOOGLE_CHAT_WEBHOOK_URL');

interface Sensors {
  water_level_low?: boolean;
  moisture?: number;
}

interface Monitoring {
  last_seen?: number;
  offline_notified?: boolean;
}

// Sensor writes (every ~30 s) act as a heartbeat and carry the water level.
export const onSensorsWrite = onValueWritten(
  { ref: '/farms/{farmId}/towers/{towerId}/sensors', region: REGION, secrets: [WEBHOOK] },
  async (event) => {
    const { farmId, towerId } = event.params;
    const ref = { farmId, towerId };
    const before = (event.data.before.val() ?? undefined) as Sensors | undefined;
    const after = (event.data.after.val() ?? undefined) as Sensors | undefined;

    const monRef = getDatabase().ref(`/farms/${farmId}/towers/${towerId}/monitoring`);
    const mon = ((await monRef.get()).val() ?? {}) as Monitoring;

    // Heartbeat + recovery notice.
    await monRef.update({ last_seen: Date.now() });
    if (mon.offline_notified === true) {
      await monRef.update({ offline_notified: false });
      await sendChatMessage(WEBHOOK.value(), buildOnlineMessage(ref));
    }

    // Water level edge alerts.
    const evt = waterLevelEvent(before?.water_level_low, after?.water_level_low);
    if (evt === 'low') {
      await sendChatMessage(WEBHOOK.value(), buildWaterLowMessage(ref));
    } else if (evt === 'restored') {
      await sendChatMessage(WEBHOOK.value(), buildWaterRestoredMessage(ref));
    }
  },
);

// Pump mode changes (operator setting or a forced change).
export const onPumpModeWrite = onValueWritten(
  { ref: '/farms/{farmId}/towers/{towerId}/pump_mode', region: REGION, secrets: [WEBHOOK] },
  async (event) => {
    const before = event.data.before.val() as string | null;
    const after = event.data.after.val() as string | null;
    if (!pumpModeChanged(before, after)) return;
    await sendChatMessage(
      WEBHOOK.value(),
      buildPumpModeMessage({ farmId: event.params.farmId, towerId: event.params.towerId }, before, after),
    );
  },
);

// Offline watchdog: fires once when a device stops reporting.
export const onOfflineCheck = onSchedule(
  { schedule: 'every 2 minutes', region: REGION, secrets: [WEBHOOK] },
  async () => {
    const now = Date.now();
    const farms = ((await getDatabase().ref('/farms').get()).val() ?? {}) as Record<
      string,
      { towers?: Record<string, { monitoring?: Monitoring }> }
    >;

    for (const farmId of Object.keys(farms)) {
      const towers = farms[farmId]?.towers ?? {};
      for (const towerId of Object.keys(towers)) {
        const mon = towers[towerId]?.monitoring ?? {};
        const lastSeen = mon.last_seen ?? null;
        if (isOffline(lastSeen, now, OFFLINE_THRESHOLD_MS) && mon.offline_notified !== true) {
          await getDatabase()
            .ref(`/farms/${farmId}/towers/${towerId}/monitoring`)
            .update({ offline_notified: true });
          const minutes = Math.round((now - (lastSeen as number)) / 60000);
          await sendChatMessage(WEBHOOK.value(), buildOfflineMessage({ farmId, towerId }, minutes));
        }
      }
    }
  },
);
