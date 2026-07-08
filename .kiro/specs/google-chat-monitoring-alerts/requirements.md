# Requirements Document — Google Chat Monitoring Alerts

## Introduction

This document defines the requirements for proactively notifying the farm owner about
monitoring events via **Google Chat**. Alerts are produced by **Firebase Cloud Functions**
(2nd gen) that watch the Realtime Database and a scheduled watchdog, and are delivered to a
Google Chat space through an **incoming webhook**. Alerts are **edge-triggered** — sent only
on a genuine state change — so the 30-second sensor cadence never spams the channel.

This feature adds a backend-only subsystem (`functions/`) over the existing Firebase Realtime
Database. It changes neither the firmware, the web client, nor the Flutter app. It builds on
the backend defined in `hydroponics-farm-management` and the delivery pipeline in
`web-app-google-auth`.

## Glossary

- **Cloud_Function**: A Firebase Cloud Function (2nd gen) reacting to RTDB writes or a schedule.
- **Google_Chat**: Google's team-messaging product used as the alert destination.
- **Chat_Webhook**: A Google Chat incoming-webhook URL that accepts a JSON message posted to a
  space; stored as the secret `GOOGLE_CHAT_WEBHOOK_URL`.
- **RTDB**: The existing Firebase Realtime Database (`farms/farm_id_1/towers/tower_1`).
- **Heartbeat**: The `last_seen` timestamp updated on every sensor write, used to detect an
  offline device.
- **Offline_Threshold**: The maximum allowed gap since the last sensor write before the device
  is considered offline (default 3 minutes).
- **Edge_Trigger**: Alerting only on a transition (before ≠ after), never while a state persists.
- **Monitoring_Node**: `farms/{farmId}/towers/{towerId}/monitoring`, holding `last_seen` and
  `offline_notified`.
- **Firmware**: The ESP32 firmware; unchanged. It reports sensors every 30 seconds.

---

## Requirements

### Requirement 1: Alert Delivery via Google Chat Webhook

**User Story:** As a farm owner, I want alerts in Google Chat, so that I hear about problems
without keeping the app open.

#### Acceptance Criteria

1. THE Cloud_Function SHALL deliver alerts by POSTing a JSON `{ "text": ... }` payload to the
   Chat_Webhook.
2. THE Chat_Webhook URL SHALL be read from the secret `GOOGLE_CHAT_WEBHOOK_URL` and SHALL NOT
   be hard-coded or committed.
3. IF the webhook responds with a non-OK HTTP status, THEN THE Cloud_Function SHALL raise an
   error (so the platform records the failure) rather than fail silently.

---

### Requirement 2: Critical Low Water Alert

**User Story:** As a farm owner, I want an immediate alert when the reservoir runs low, so that
I can refill before the pump is affected.

#### Acceptance Criteria

1. WHEN `water_level_low` transitions to `true` (from `false` or unset), THE Cloud_Function
   SHALL send a critical low-water alert identifying the farm and tower.
2. WHILE `water_level_low` remains `true`, THE Cloud_Function SHALL NOT send repeated
   low-water alerts.

---

### Requirement 3: Water Restored Alert

**User Story:** As a farm owner, I want to know when the water level recovers, so that I know
normal operation resumed.

#### Acceptance Criteria

1. WHEN `water_level_low` transitions from `true` to `false`, THE Cloud_Function SHALL send a
   "water restored" notice.
2. WHEN the tower is first seeded with `water_level_low = false`, THE Cloud_Function SHALL NOT
   send a restored notice (no prior low state).

---

### Requirement 4: Device Offline Detection

**User Story:** As a farm owner, I want to be told when a tower stops reporting, so that I can
check power or WiFi.

#### Acceptance Criteria

1. THE Cloud_Function SHALL update the Heartbeat (`last_seen`) on every sensor write.
2. A scheduled Cloud_Function SHALL run periodically and, IF the gap since `last_seen` exceeds
   the Offline_Threshold AND no offline alert is outstanding, THEN it SHALL send an offline
   alert and mark `offline_notified = true`.
3. THE offline alert SHALL be sent at most once per offline episode.
4. IF `last_seen` has never been set, THEN THE Cloud_Function SHALL NOT report the device as
   offline.

---

### Requirement 5: Device Back-Online Notice

**User Story:** As a farm owner, I want confirmation that a previously offline tower recovered.

#### Acceptance Criteria

1. WHEN a sensor write arrives AND `offline_notified` is `true`, THE Cloud_Function SHALL send
   a "back online" notice and clear `offline_notified`.

---

### Requirement 6: Pump Mode Change Alert

**User Story:** As a farm owner, I want to know when the pump mode changes, so that I am aware
of configuration or forced changes.

#### Acceptance Criteria

1. WHEN `pump_mode` changes to a new non-empty value, THE Cloud_Function SHALL send a notice
   stating the previous and new mode.
2. WHEN `pump_mode` is written with an unchanged value, THE Cloud_Function SHALL NOT send a
   notice.

---

### Requirement 7: Edge-Triggered Alerting (Anti-Spam)

**User Story:** As a farm owner, I want relevant alerts only, so that I am not flooded by the
30-second sensor cadence.

#### Acceptance Criteria

1. THE Cloud_Function SHALL send an alert only on a genuine state transition (before ≠ after)
   for the watched field.
2. THE alert-decision logic SHALL be pure (no I/O) and independently testable.

---

### Requirement 8: Server-Side Execution

**User Story:** As a farm owner, I want alerts to work regardless of whether anyone has the app
open.

#### Acceptance Criteria

1. THE alert logic SHALL run as Cloud_Functions triggered by RTDB writes and a schedule — not
   in the web or mobile client.
2. THE feature SHALL NOT require changes to the firmware, web client, or Flutter app.

---

### Requirement 9: Terraform Provisioning & Deployment

**User Story:** As a maintainer, I want the alerting subsystem provisioned and deployed as code.

#### Acceptance Criteria

1. THE Terraform configuration SHALL enable the required GCP APIs (Cloud Functions, Cloud
   Build, Artifact Registry, Cloud Run, Eventarc, Pub/Sub, Cloud Scheduler, Secret Manager).
2. THE Terraform configuration SHALL create the `GOOGLE_CHAT_WEBHOOK_URL` secret in Secret
   Manager from a sensitive input variable.
3. THE Terraform workflow SHALL deploy the Cloud_Functions via the Firebase CLI, ordered after
   the RTDB instance and the secret.
4. THE feature SHALL be toggleable via a `deploy_functions` variable.

---

### Requirement 10: Testing

**User Story:** As a developer, I want the alert logic verified.

#### Acceptance Criteria

1. THE `functions/` package SHALL include unit and property-based tests (Vitest + fast-check)
   for edge detection, offline threshold, pump-mode change, message builders, and the webhook
   sender.
2. THE tests SHALL run in CI alongside a `typecheck` and `build`.
