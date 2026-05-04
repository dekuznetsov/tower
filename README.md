# Hydroponics Farm Management System

A full-stack IoT system for remote monitoring and control of hydroponic growing towers. Built on three tiers: **Firebase Realtime Database** as the communication backbone, **ESP32 firmware** running on each tower's microcontroller, and a **Flutter mobile app** for the farm operator.

---

## Features

- **Real-time monitoring** — live soil moisture and reservoir water level readings pushed to the app every 30 seconds
- **Auto mode** — pump cycles on/off on configurable time intervals without any manual intervention
- **Manual mode** — turn the pump on/off and set speed from the app on demand
- **PWM speed control** — 0–100% pump speed mapped to 8-bit PWM duty cycle (0–255)
- **Safety interlock** — pump is forced off automatically when the water reservoir runs low, protecting the pump from dry-run damage
- **Offline resilience** — firmware continues operating on last known state during WiFi or Firebase outages; app shows a connection banner when disconnected

---

## Architecture

```
┌─────────────────────┐        ┌──────────────────────────┐        ┌─────────────────────┐
│   Flutter Mobile    │        │  Firebase Realtime DB    │        │   ESP32 Firmware    │
│        App          │        │                          │        │                     │
│                     │──────▶ │  farms/farm_id_1/        │ ──────▶│  Stream callback    │
│  Riverpod providers │        │    towers/tower_1/       │        │  Auto mode timer    │
│  TowerRepository    │◀────── │      pump_mode           │ ◀───── │  Safety interlock   │
│  UI widgets         │        │      pump_speed          │        │  PWM controller     │
│                     │        │      pump_switch         │        │  Sensor reporter    │
└─────────────────────┘        │      pump_state          │        └─────────────────────┘
                                │      interval_on_min     │
                                │      interval_off_min    │
                                │      sensors/            │
                                │        moisture          │
                                │        water_level_low   │
                                └──────────────────────────┘
```

The firmware and the mobile app never communicate directly — all coordination flows through Firebase. The firmware is the authoritative source for `pump_state` and sensor readings; the app is the authoritative source for operator intent.

---

## Repository Structure

```
├── firebase/               # Database schema, security rules, and seed data
│   ├── seed_data.json      # Initial database structure for import
│   ├── database.rules.json # Firebase security rules
│   └── README.md           # Import instructions and field reference
│
├── firmware/               # ESP32 C++/Arduino firmware (PlatformIO)
│   ├── src/                # Production source files
│   ├── test/               # Unit tests and property-based tests (GoogleTest + rapidcheck)
│   └── platformio.ini      # Build configuration for esp32dev and native targets
│
├── mobile/                 # Flutter mobile application
│   ├── lib/                # App source (models, repository, providers, UI)
│   └── test/               # Unit, property, and widget tests
│
└── hardware/               # Wiring diagram and bill of materials
    └── README.md           # Component list (AliExpress), GPIO assignments, assembly notes
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Database | Firebase Realtime Database |
| Firmware | C++ / Arduino framework on ESP32 (PlatformIO) |
| Firmware libraries | Firebase-ESP-Client, ArduinoJson, rapidcheck |
| Mobile app | Flutter 3 / Dart |
| App state management | flutter_riverpod |
| App Firebase client | firebase_core, firebase_database |
| Firmware testing | GoogleTest + rapidcheck (property-based) |
| App testing | flutter_test, mockito |

---

## Hardware

The device is built around an **ESP32 DevKit v1** and all components are available on AliExpress for ~$15–25 USD.

| Component | Purpose |
|---|---|
| ESP32 DevKit v1 (38-pin) | Microcontroller — WiFi, Firebase, PWM, ADC |
| Capacitive Soil Moisture Sensor v1.2 | Moisture reading on GPIO 34 (ADC) |
| XKC-Y25 non-contact liquid level sensor | Water level detection on GPIO 19 |
| IRF520 MOSFET module | PWM-controlled switch for the 12V pump on GPIO 18 |
| 12V DC submersible pump (3–5W) | Water delivery to the tower |
| 12V 2A DC power adapter | Powers the pump |
| LM2596 DC-DC step-down module | Steps 12V down to 5V for the ESP32 |

See [`hardware/README.md`](hardware/README.md) for the full bill of materials, wiring diagram, and assembly notes.

### GPIO Assignments

| GPIO | Mode | Connected to |
|---|---|---|
| GPIO 18 | PWM output | IRF520 MOSFET SIG (pump control) |
| GPIO 34 | ADC input | Moisture sensor AOUT |
| GPIO 19 | Digital input | XKC-Y25 water level sensor OUT |

---

## Getting Started

### 1. Firebase Setup

1. Create a Firebase project and enable **Realtime Database**.
2. Import the seed data from `firebase/seed_data.json` via the Firebase Console (**Realtime Database → ⋮ → Import JSON**).
3. Deploy the security rules:
   ```bash
   npm install -g firebase-tools
   firebase login
   firebase deploy --only database
   ```

See [`firebase/README.md`](firebase/README.md) for detailed import instructions and REST API alternatives.

### 2. ESP32 Firmware

**Prerequisites:** [PlatformIO](https://platformio.org/) (VS Code extension or CLI)

1. Open the `firmware/` folder in VS Code with the PlatformIO extension, or use the CLI.
2. Copy `firmware/src/config.h.example` to `firmware/src/config.h` and fill in your credentials:
   ```cpp
   #define SSID          "your_wifi_ssid"
   #define PASSWORD      "your_wifi_password"
   #define FIREBASE_HOST "your-project-id-default-rtdb.firebaseio.com"
   #define FIREBASE_AUTH "your_database_secret_or_id_token"
   ```
3. Flash to the ESP32:
   ```bash
   pio run --target upload --environment esp32dev
   ```
4. Monitor serial output:
   ```bash
   pio device monitor
   ```

**Run firmware tests on host (no hardware required):**
```bash
pio test --environment native
```

### 3. Flutter Mobile App

**Prerequisites:** [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.0, a Firebase project with the Android/iOS app registered.

1. Add your `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) to the appropriate platform folder inside `mobile/`.
2. Install dependencies:
   ```bash
   cd mobile
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```
4. Run tests:
   ```bash
   flutter test
   ```

---

## Database Schema

```
farms/
  farm_id_1/
    towers/
      tower_1/
        pump_speed:       Integer   (0–255, PWM duty cycle — written by app)
        pump_mode:        String    ("auto" | "manual" — written by app)
        pump_state:       Boolean   (actual on/off — written by firmware)
        pump_switch:      Boolean   (operator intent in manual mode — written by app)
        interval_on_min:  Integer   (minutes pump stays on in auto mode — written by app)
        interval_off_min: Integer   (minutes pump stays off in auto mode — written by app)
        sensors/
          moisture:         Integer   (ADC raw value 0–4095 — written by firmware)
          water_level_low:  Boolean   (true = reservoir low — written by firmware)
```

---

## Safety Interlock

When `water_level_low` is `true`, the firmware immediately sets PWM to 0 and writes `pump_state = false` to Firebase — regardless of `pump_mode`, `pump_switch`, or the auto timer state. This prevents the pump from running dry. Normal operation resumes automatically once the water level is restored.

---

## Testing

The project uses property-based testing (PBT) throughout to verify correctness properties across randomly generated inputs (minimum 100 iterations each).

**Firmware (native build):**
```bash
cd firmware
pio test --environment native
```

**Flutter app:**
```bash
cd mobile
flutter test
```

Key correctness properties verified by tests:

- `TowerState` serialization round-trip through Firebase snapshot
- Safety interlock overrides all pump activation when water is low
- Auto timer cycles at correct `millis()`-based intervals
- PWM duty cycle always matches pump on/off state
- Interval validation rejects non-integer and out-of-range input
- Mode switch panel visibility is mutually exclusive

---

## Built With

### Development Tools

| Tool | Purpose |
|---|---|
| [VS Code](https://code.visualstudio.com/) | Primary code editor |
| [Kiro](https://kiro.dev/) | AI-powered IDE used for spec-driven development, code generation, and implementation |
| [PlatformIO](https://platformio.org/) | ESP32 firmware build system, dependency management, and test runner |
| [Firebase CLI](https://firebase.google.com/docs/cli) | Deploying database security rules (`firebase deploy --only database`) |
| [Flutter SDK](https://flutter.dev/) | Mobile app build toolchain and test runner |
| [Git](https://git-scm.com/) | Version control |

### AI Assistance

This project was developed with the help of [Kiro](https://kiro.dev/) — an AI-powered development environment. Kiro was used throughout the entire development lifecycle:

- **Spec-driven design** — requirements, architecture design, and implementation task planning were created collaboratively using Kiro's spec workflow
- **Code generation** — firmware C++ source, Flutter Dart source, Firebase rules, and test suites were generated and refined with Kiro
- **Property-based test design** — correctness properties and PBT scenarios were defined and implemented with AI assistance
- **Documentation** — hardware wiring diagrams, BOM, and this README were produced with Kiro

---

## License

[Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/)

This project is licensed under the MPL-2.0. You may use, modify, and distribute this code, but any modifications to MPL-licensed files must be released under the same license. Larger works may combine this code with code under other licenses.
