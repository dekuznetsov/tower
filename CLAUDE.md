# Hydroponics Farm Management System

Full-stack IoT system for remote monitoring and control of hydroponic growing towers.
Imported from a Kiro spec — the authoritative specification lives in
`.kiro/specs/hydroponics-farm-management/` (`requirements.md`, `design.md`, `tasks.md`).
All 77 implementation tasks in that spec are complete.

## Architecture

Clients **never** talk directly — all coordination flows through Firebase Realtime
Database, which acts as a shared state machine. There are two frontends over one backend.

- **Firebase Realtime Database** (`firebase/`) — central data store and message bus.
  Schema, seed data, and security rules live here.
- **ESP32 firmware** (`firmware/`, C++/Arduino, PlatformIO) — one per tower; reads
  sensors, drives the pump via PWM, syncs state with Firebase.
- **Web app** (`web/`, React + TypeScript + Vite) — the **deployed** operator UI, on
  Firebase Hosting, Google OAuth sign-in, allowlist-gated. See
  `.kiro/specs/web-app-google-auth/`.
- **Flutter mobile app** (`mobile/`, Dart + Riverpod) — retained as the basis for future
  Android/iOS; **not currently deployed** (iOS publication is unavailable).

Authority split:
- Firmware is authoritative for `pump_state` and sensor readings.
- Clients are authoritative for operator intent (`pump_mode`, `pump_switch`, `pump_speed`,
  `interval_on_min`, `interval_off_min`). Clients never write firmware-owned fields.

## Access model

- Sign-in via **Google OAuth** (Firebase Auth). Authorization is by **allowlist**: a user
  may read/control `farms/` only if `/allowlist/{uid} === true`.
- Enforced authoritatively in `firebase/database.rules.json`; the web client also checks
  membership for a friendly gate. The allowlist is seeded out-of-band (Terraform/console),
  never writable by clients.
- The firmware uses a privileged credential and bypasses these rules — unaffected.

## Web conventions (`web/src/`)

- `firebase.ts` initializes the SDK from `VITE_FB_*` env (generated from Terraform outputs;
  never hard-coded). `data/towerState.ts` is the TS port of the Dart `TowerState`
  (`parseTowerState`/`toMap`/`sliderToSpeed`/`waterLevelLabel`) — keep it in sync with
  `mobile/lib/models/tower_state.dart`. `data/towerRepository.ts` mirrors the Dart repository
  and must never write `pump_state`/`moisture`/`water_level_low`.
- Auth/allowlist live in `auth/`; routing by auth status is the pure `components/StatusGate`.
- Tests: **Vitest + fast-check** in `web/test/` (properties tagged
  `// Feature: web-app-google-auth, Property W#`). Run `npm run test:run` / `typecheck` / `build`.

## Infrastructure (`infra/terraform/`)

Terraform (`google` + `google-beta`) provisions the project, Firebase, RTDB, Identity
Platform + Google provider, and Hosting. RTDB rules deploy, seed, allowlist seeding, and the
Hosting file upload run via the Firebase CLI wrapped in `null_resource`/`local-exec`
(providers can't do these natively). Root `firebase.json` maps hosting → `web/dist` and
database → rules. See `infra/terraform/README.md`.

## Firebase schema

```
farms/farm_id_1/towers/tower_1/
  pump_speed:       Integer (0–255, PWM duty cycle)
  pump_mode:        String  ('auto' | 'manual')
  pump_state:       Boolean (actual pump on/off — written by firmware)
  pump_switch:      Boolean (operator intent in manual mode)
  interval_on_min:  Integer (>= 1)
  interval_off_min: Integer (>= 1)
  sensors/
    moisture:         Integer (ADC raw 0–4095)
    water_level_low:  Boolean
```

## Firmware conventions (`firmware/src/`)

- **Never block** the main loop. All timing uses `millis()`-based state machines, not
  `delay()` (the one exception: blocking WiFi connect in `setup()`).
- **Safety interlock is the highest-priority gate.** `applyPumpState()` in
  `pump_control.cpp` is the single authoritative path for turning the pump on/off — every
  activation path (auto timer, manual switch, mode change, sensor read) goes through it.
  When `water_level_low` is true, PWM is forced to 0 and `pump_state=false`.
- Pin/peripheral constants live in `config.h`: pump PWM on GPIO 18 (LEDC channel 0,
  5000 Hz, 8-bit), moisture on GPIO 34 (ADC), water level on GPIO 19 (digital, active
  high). Sensors reported every 30 s.
- Modules: `connectivity`, `stream_handler`, `auto_timer`, `pump_control`,
  `sensor_reporter`, `firmware_state`.

## Mobile conventions (`mobile/lib/`)

- **Riverpod** for state; `StreamProvider` wraps the Firebase `onValue` stream — no manual
  `setState`. Providers in `providers/tower_providers.dart`.
- **`TowerRepository`** (`repositories/`) encapsulates all Firebase read/write; returns
  typed `TowerState` (`models/tower_state.dart`). Keep Firebase access out of widgets.
- Speed slider maps 0.0–1.0 ↔ 0–255 via `TowerState.sliderToSpeed` (clamped, monotonic).
- Interval fields validated by `utils/validate_interval.dart` (positive integers only;
  reject before any Firebase write).
- `fromSnapshot` uses null-coalescing defaults everywhere — the app must never crash on
  partial data.

## Testing

Per-layer. The spec defines 17 correctness properties (see `design.md` → Correctness
Properties); property-based tests must be tagged, e.g.:

```
// Feature: hydroponics-farm-management, Property 10: Safety interlock overrides all pump activation
```

- **Firmware**: native C++ unit + property tests (min 100 iterations) with mocked
  `millis`, `ledcWrite`, `analogRead`, `digitalRead`, and Firebase — see `firmware/test/`.
- **Mobile**: `flutter_test` + mockito unit tests, property tests, and widget tests —
  see `mobile/test/`.

When changing behavior, keep the spec (`.kiro/specs/…`) and this file in sync with the code.
