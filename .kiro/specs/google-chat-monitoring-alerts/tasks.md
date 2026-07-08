# Implementation Plan: Google Chat Monitoring Alerts

## Overview

Three phases: the pure alert logic and sender (with tests), the Cloud Function triggers, and
the Terraform/deploy wiring. Property tests sit beside the logic they validate. No task changes
the firmware, web client, or Flutter app.

---

## Tasks

- [x] 1. Package scaffolding (`functions/`)
  - [x] 1.1 Create the TypeScript Cloud Functions package
    - `package.json` (Node 20, firebase-functions, firebase-admin), `tsconfig.json`,
      `tsconfig.build.json` (emits `lib/index.js`), `vitest.config.ts`
    - _Requirements: 8.1, 10.2_
  - [x] 1.2 Ignore build artifacts (`functions/lib`, `functions/node_modules`)
    - _Requirements: 8.1_

- [x] 2. Pure alert logic and webhook sender (+ tests)
  - [x] 2.1 `monitoring.ts` — edge detection and offline check
    - `waterLevelEvent`, `pumpModeChanged`, `isOffline`, `OFFLINE_THRESHOLD_MS`
    - _Requirements: 2.1, 2.2, 3.1, 3.2, 4.2, 4.4, 6.1, 6.2, 7.1, 7.2_
  - [x] 2.2 `monitoring.ts` — message builders (Ukrainian, per severity)
    - low / restored / offline / online / pump-mode
    - _Requirements: 2.1, 3.1, 4.2, 5.1, 6.1_
  - [x] 2.3 `chat.ts` — `sendChatMessage` via global `fetch`
    - POST `{ text }`; throw on non-OK
    - _Requirements: 1.1, 1.3_
  - [x] 2.4 Property + unit tests (Vitest + fast-check)
    - N1 edge detection (incl. unchanged ⇒ null), N2 pump mode, N3 offline threshold,
      N5 sender contract, N6 message content; tagged `Property N#`
    - _Requirements: 10.1_

- [x] 3. Cloud Function triggers (`index.ts`)
  - [x] 3.1 `onSensorsWrite` — heartbeat + water alerts + back-online
    - Update `monitoring/last_seen`; clear `offline_notified` with online notice; send low/restored
    - _Requirements: 2.1, 2.2, 3.1, 3.2, 4.1, 5.1, 7.1, 8.1_
  - [x] 3.2 `onPumpModeWrite` — pump mode change notice
    - _Requirements: 6.1, 6.2_
  - [x] 3.3 `onOfflineCheck` — scheduled watchdog (fires once per episode)
    - _Requirements: 4.2, 4.3, 4.4_
  - [x] 3.4 Read the webhook from secret `GOOGLE_CHAT_WEBHOOK_URL`; region matches RTDB
    - _Requirements: 1.2, 8.1_

- [x] 4. Infrastructure & deployment (Terraform)
  - [x] 4.1 Enable Functions/Build/Artifact Registry/Run/Eventarc/Pub/Sub/Scheduler/Secret Manager APIs
    - _Requirements: 9.1_
  - [x] 4.2 `functions.tf` — Secret Manager secret + version for the webhook
    - _Requirements: 9.2_
  - [x] 4.3 `deploy.tf` — `firebase deploy --only functions`, ordered after RTDB + secret
    - Variables `google_chat_webhook_url` (sensitive), `deploy_functions`
    - _Requirements: 9.3, 9.4_
  - [x] 4.4 `firebase.json` functions codebase + build predeploy
    - _Requirements: 9.3_

- [x] 5. CI & documentation
  - [x] 5.1 CI job — functions typecheck, test, build
    - _Requirements: 10.2_
  - [x] 5.2 Update README (feature, structure, stack, "Сповіщення", testing) and infra README
    - _Requirements: 8.2_

---

## Manual / out-of-band prerequisites

- Create a **Google Chat incoming webhook** in the owner's space (Space → Apps & integrations
  → Webhooks) and pass the URL as `google_chat_webhook_url`.
- Blaze billing is required for Cloud Functions (already required by the base infrastructure).
- The RTDB trigger region (`europe-west1`) must match `rtdb_region`.
