# Implementation Plan: Web App, Google OAuth & Terraform Delivery

## Overview

Implementation proceeds in seven phases:

1. **Repo scaffolding** — web project skeleton and secret hygiene.
2. **Web data layer** — port `TowerState`, realtime hook, repository, validation (+ tests).
3. **Auth & authorization** — Google OAuth, allowlist gate, access states.
4. **UI parity** — dashboard, panels, banner (+ component tests).
5. **Security rules** — allowlist enforcement.
6. **Terraform infrastructure** — project, Firebase, Auth, RTDB, web app, Hosting.
7. **Deployment & wiring** — Terraform-driven rules/seed/allowlist/hosting deploy, docs, CI.

Property tests are placed immediately after the component they validate. No task marks the
firmware or the existing Flutter app for change.

---

## Tasks

- [x] 1. Repository scaffolding and secret hygiene
  - [x] 1.1 Scaffold the Vite React + TypeScript app under `web/`
    - `npm create vite@latest web -- --template react-ts`; add `firebase`
    - Add `web/src/firebase.ts` reading `VITE_FB_*` from `import.meta.env`
    - Add `web/.env.example` documenting required variables
    - _Requirements: 1.1, 1.2, 1.3_
  - [x] 1.2 Update `.gitignore` for secrets and build artifacts
    - Ignore `web/.env`, `web/dist`, `**/*.tfstate*`, `**/.terraform/`, service-account keys
    - _Requirements: 13.2_

- [x] 2. Web data layer (port from Flutter) + tests
  - [x] 2.1 Port `TowerState` to `web/src/data/towerState.ts`
    - `parseTowerState` (null-coalescing defaults), `toMap` (nested `sensors`),
      `sliderToSpeed` (clamp 0–255), `speedPercent`, `waterLevelDisplay`
    - _Requirements: 4.3, 6.4_
  - [x] 2.2 Implement `useTower` realtime hook
    - Subscribe `onValue` on `farms/farm_id_1/towers/tower_1`; track `.info/connected`
    - _Requirements: 4.1, 4.2, 4.4_
  - [x] 2.3 Implement `towerRepository.ts` write methods
    - `setPumpMode`, `setPumpSwitch`, `setPumpSpeed`, `setIntervals` (atomic `update`);
      no writes to `pump_state`/`moisture`/`water_level_low`
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  - [x] 2.4 Implement `validateInterval` (positive integer only)
    - _Requirements: 6.5_
  - [x] 2.5 Property + unit tests (Vitest + fast-check, ≥100 iters)
    - W1 round-trip, W2 water display, W3 slider, W5 interval validation, W6 interval round-trip
    - Tag: `// Feature: web-app-google-auth, Property W#: ...`
    - _Requirements: 12.1, 12.2_

- [x] 3. Authentication and allowlist authorization
  - [x] 3.1 Implement `AuthProvider` + `useAuth`
    - `onAuthStateChanged`; expose `{ user, status, signIn, signOut }`
    - _Requirements: 2.2, 2.3, 2.4_
  - [x] 3.2 Implement `SignInScreen` (Google popup + redirect fallback, error display)
    - _Requirements: 2.1, 2.2, 2.5_
  - [x] 3.3 Implement allowlist check and `AccessDenied`
    - On sign-in read `/allowlist/{uid}`; set status `allowed` / `not_allowed`
    - _Requirements: 3.1, 3.2, 3.3, 3.4_
  - [x] 3.4 Route by status in `App.tsx`
    - loading / signed_out / not_allowed / allowed
    - _Requirements: 3.2, 3.3_
  - [x] 3.5 Component tests for access gating (W7) and firmware-field write guard (W8)
    - _Requirements: 12.1_

- [x] 4. UI parity with the Flutter dashboard + tests
  - [x] 4.1 `ConnectionBanner` (shown when disconnected)
    - _Requirements: 6.1_
  - [x] 4.2 `SensorCard` (moisture + Good/Low)
    - _Requirements: 6.2_
  - [x] 4.3 `ModeSwitch`, `AutoModePanel` (intervals), `ManualModePanel` (switch + speed slider)
    - Panel visible iff matching `pump_mode`
    - _Requirements: 6.3, 6.4, 6.5_
  - [x] 4.4 `TowerDashboard` composition wired to `useTower` + repository
    - _Requirements: 4.2, 5.1, 5.2, 5.3, 5.4_
  - [x] 4.5 Component test for panel visibility by mode (W4)
    - _Requirements: 12.1_

- [x] 5. Security rules — allowlist enforcement
  - [x] 5.1 Update `firebase/database.rules.json` to allowlist-gated `farms/`
    - `/allowlist` read-only to clients, write denied; `$other` denied
    - _Requirements: 7.1, 7.2, 7.3_
  - [x] 5.2 Verify firmware credential compatibility (documentation + rules note)
    - _Requirements: 7.4_

- [x] 6. Terraform infrastructure
  - [x] 6.1 `versions.tf` — providers `google`/`google-beta` + `backend "gcs"`
    - _Requirements: 8.4_
  - [x] 6.2 `variables.tf` + `terraform.tfvars.example`
    - project_id, billing_account, region, site_id, authorized_domains,
      oauth_client_id/secret (sensitive), allowlist_uids, admin_credentials_path
    - _Requirements: 8.3, 8.5_
  - [x] 6.3 `main.tf` — project services + `google_firebase_project`
    - Enable identitytoolkit, firebasedatabase, firebasehosting, firebase APIs
    - _Requirements: 8.1_
  - [x] 6.4 `database.tf` — `google_firebase_database_instance`
    - _Requirements: 8.2_
  - [x] 6.5 `auth.tf` — Identity Platform config + Google `default_supported_idp_config`
    - _Requirements: 8.2, 8.3_
  - [x] 6.6 `webapp.tf` — `google_firebase_web_app` + `web_app_config` data source
    - _Requirements: 8.2, 9.1_
  - [x] 6.7 `hosting.tf` — `google_firebase_hosting_site`
    - _Requirements: 8.2_
  - [x] 6.8 `outputs.tf` — web_config, database_url, hosting_url
    - _Requirements: 9.1, 9.3_
  - [x] 6.9 `terraform fmt`/`validate` clean
    - _Requirements: 12.3_

- [x] 7. Deployment, wiring, docs
  - [x] 7.1 Config wiring — render Terraform outputs to `web/.env`
    - Script/`local-exec` producing `VITE_FB_*` from outputs; no secrets committed
    - _Requirements: 9.1, 9.2_
  - [x] 7.2 `deploy.tf` — rules deploy (`firebase deploy --only database`)
    - `null_resource` + `local-exec`, `depends_on` database instance
    - _Requirements: 10.3, 11.1_
  - [x] 7.3 `deploy.tf` — seed data + allowlist (idempotent REST)
    - PUT `seed_data.json`; PATCH allowlist from `allowlist_uids` via privileged credential
    - _Requirements: 11.2, 11.3, 11.4_
  - [x] 7.4 `deploy.tf` — Hosting deploy from `web/dist`
    - `firebase deploy --only hosting` (or `google_firebase_hosting_release`), `depends_on` site
    - _Requirements: 10.1, 10.2, 10.3_
  - [x] 7.5 CI — `terraform fmt/validate`, web `vitest`, build
    - _Requirements: 12.1, 12.3_
  - [x] 7.6 Documentation
    - `infra/terraform/README.md` (prereqs: billing, OAuth consent screen; variables; apply)
    - Update `CLAUDE.md` and this spec set with the web client + access model
    - _Requirements: 13.1, 13.3_

---

## Manual / out-of-band prerequisites (cannot be automated in this repo)

- Create a **billing account** and link it (Blaze) — required for Identity Platform and RTDB.
- Configure the **GCP OAuth consent screen** and create an **OAuth client id/secret** for the
  Google sign-in provider; supply as sensitive Terraform variables.
- Provide the initial **allowlist** of authorized uids/emails.
- Confirm the **Hosting domain** (default `*.web.app` or custom).
