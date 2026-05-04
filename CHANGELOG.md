# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-05-05

### Added

#### Firebase
- Realtime Database schema for `farms/farm_id_1/towers/tower_1` with all control and sensor fields
- Security rules: authenticated read/write on `farms/` path; unauthenticated access denied
- Seed data JSON for console and REST API import
- Firebase CLI deployment configuration

#### ESP32 Firmware (PlatformIO / Arduino)
- PlatformIO project with `esp32dev` and `native` build environments
- WiFi connectivity manager with non-blocking reconnect loop
- Firebase stream subscription on `farms/farm_id_1/towers/tower_1` with stream timeout recovery
- `FirmwareState` struct holding all in-memory control and sensor state
- Stream callback dispatcher (`onFirebaseStream`) for `pump_mode`, `pump_speed`, `pump_switch`, `interval_on_min`, `interval_off_min`
- Auto mode timer (`AutoTimer`) — non-blocking `millis()`-based on/off cycling
- Manual mode handler — pump switch control via Firebase stream
- PWM pump speed control via LEDC (GPIO 18, channel 0, 5000 Hz, 8-bit)
- Safety interlock (`applyPumpState`) — forces PWM to 0 and writes `pump_state = false` when `water_level_low` is true
- Sensor reporter — reads moisture (GPIO 34 ADC) and water level (GPIO 19) every 30 seconds, writes to Firebase
- Firebase write error logging via Serial
- GoogleTest unit tests for all firmware modules
- rapidcheck property-based tests (Properties 2–5, 7–11)

#### Flutter Mobile App
- Firebase initialization with `ProviderScope` root
- `TowerState` data model with `fromSnapshot` factory, `toMap`, `speedPercent`, `sliderToSpeed`, `waterLevelDisplay`
- `TowerRepository` — typed Firebase read/write layer for all control fields
- `validateInterval` — input validation for auto mode interval fields
- Riverpod providers: `towerRepositoryProvider`, `towerStreamProvider`, `connectionStatusProvider`
- `ConnectionStatusBanner` — shown when Firebase stream is unavailable
- `SensorCard` with `MoistureDisplay` and `WaterLevelDisplay`
- `ModeSwitchTile` — reflects and writes `pump_mode`
- `AutoModePanel` with `IntervalOnField` and `IntervalOffField` — inline validation, snackbar on write failure
- `ManualModePanel` with `PumpSwitchTile` and `SpeedSlider` (0–100% → 0–255)
- `TowerDashboard` root widget — conditionally renders Auto or Manual panel based on `pump_mode`
- flutter_test unit tests, mockito-based repository tests, and widget tests
- fast_check property-based tests (Properties 1, 12–17)

#### Hardware Documentation
- Full bill of materials with AliExpress search keywords (13 components, ~$15–25 USD)
- ASCII wiring diagram: ESP32 ↔ IRF520 MOSFET ↔ pump, moisture sensor, XKC-Y25 water level sensor
- GPIO assignment table and power supply requirements
- Assembly notes for MOSFET, capacitive moisture sensor, and XKC-Y25
- Enclosure layout diagram

#### Project
- `README.md` with architecture overview, getting started guide, and database schema reference
- `LICENSE` — Mozilla Public License 2.0

[1.0.0]: https://github.com/your-username/hydroponics-farm-management/releases/tag/v1.0.0
