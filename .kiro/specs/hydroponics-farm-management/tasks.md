# Implementation Plan: Hydroponics Farm Management System

## Overview

Implementation proceeds in four phases that mirror the three-tier architecture:

1. **Firebase schema** — seed the database structure and security rules.
2. **ESP32 firmware** — connectivity, stream handling, auto/manual modes, PWM, sensor reporting, and safety interlock.
3. **Flutter mobile app** — data models, repository, Riverpod providers, and UI widgets.
4. **Integration wiring** — connect all layers and verify end-to-end flows.

Each phase builds on the previous one. Property-based tests are placed immediately after the component they validate so errors are caught early.

---

## Tasks

- [x] 1. Firebase Realtime Database — schema and seed data
  - [x] 1.1 Create the database JSON structure for `farms/farm_id_1/towers/tower_1`
    - Add all control fields: `pump_speed` (0), `pump_mode` ("manual"), `pump_state` (false), `pump_switch` (false), `interval_on_min` (1), `interval_off_min` (1)
    - Add `sensors/` sub-node with `moisture` (0) and `water_level_low` (false)
    - Export the seed JSON so it can be imported via the Firebase console or REST API
    - _Requirements: 1.1, 1.2, 1.3_

  - [x] 1.2 Write Firebase security rules
    - Allow authenticated read/write on `farms/` path
    - Deny unauthenticated access
    - _Requirements: 1.1_

- [x] 2. ESP32 firmware — project structure and build configuration
  - [x] 2.1 Set up the Arduino/PlatformIO project skeleton
    - Create `platformio.ini` (or Arduino sketch folder) targeting ESP32
    - Add library dependencies: `Firebase-ESP-Client`, `ArduinoJson`
    - Define compile-time constants: `SSID`, `PASSWORD`, `FIREBASE_HOST`, `FIREBASE_AUTH`, `TOWER_PATH`, `SENSORS_PATH`, `PUMP_GPIO` (18), `MOISTURE_PIN` (34), `WATER_LEVEL_PIN` (19), `PWM_CHANNEL` (0), `PWM_FREQ` (5000), `PWM_RESOLUTION` (8), `SENSOR_INTERVAL_MS` (30000)
    - _Requirements: 2.1, 6.1_

  - [x] 2.2 Implement PWM controller initialisation in `setup()`
    - Call `ledcSetup(PWM_CHANNEL, PWM_FREQ, PWM_RESOLUTION)` and `ledcAttachPin(PUMP_GPIO, PWM_CHANNEL)`
    - Verify duty cycle 0 is written on startup
    - _Requirements: 6.1_

- [x] 3. ESP32 firmware — connectivity manager
  - [x] 3.1 Implement `connectivitySetup()` — WiFi connect and Firebase auth
    - Block in `setup()` until WiFi is connected (blocking `delay(100)` loop is acceptable here only)
    - Call `Firebase.begin(&config, &auth)` and `Firebase.reconnectWiFi(true)`
    - Call `Firebase.beginStream` and `Firebase.setStreamCallback` for `TOWER_PATH`
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 3.2 Implement `connectivityLoop()` — non-blocking WiFi reconnect
    - In `loop()`, check `WiFi.status() != WL_CONNECTED` and call `WiFi.reconnect()` without blocking
    - _Requirements: 2.4_

- [x] 4. ESP32 firmware — in-memory state and `FirmwareState` struct
  - [x] 4.1 Define `FirmwareState` struct and global instance
    - Fields: `pump_mode` (String), `pump_speed` (int), `pump_switch` (bool), `interval_on_ms` (unsigned long), `interval_off_ms` (unsigned long), `pump_state` (bool), `moisture` (int), `water_level_low` (bool)
    - Initialise all fields to safe defaults (mode="manual", speed=0, state=false)
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 5. ESP32 firmware — safety interlock (`applyPumpState`)
  - [x] 5.1 Implement `applyPumpState(bool requestedOn)`
    - Read `WATER_LEVEL_PIN` with `digitalRead`; derive `actualOn = requestedOn && !waterLow`
    - Call `ledcWrite(PWM_CHANNEL, actualOn ? currentPumpSpeed : 0)`
    - Write `pump_state` to Firebase only when it changes, or when `waterLow && requestedOn` forces a false write
    - _Requirements: 8.1, 8.2, 8.3, 6.3, 6.4_

  - [x] 5.2 Write property test for safety interlock override (Property 10)
    - **Property 10: Safety Interlock Overrides All Pump Activation**
    - Generate random combinations of `pump_mode` ∈ {"auto","manual"}, `pump_switch` ∈ {true,false}, timer state ∈ {on,off}; mock `digitalRead` to return HIGH (water low)
    - Assert `ledcWrite` always called with 0 and `pump_state` written as false
    - **Validates: Requirements 8.1, 8.2, 8.3**

  - [x] 5.3 Write property test for safety interlock clear (Property 11)
    - **Property 11: Safety Interlock Clears on Water Restored**
    - After `water_level_low` transitions from true → false, assert pump resumes correct behaviour per `pump_mode`
    - **Validates: Requirements 8.4**

  - [x] 5.4 Write unit tests for `applyPumpState`
    - Test: pump on, water ok → `ledcWrite` called with `pump_speed`
    - Test: pump off → `ledcWrite` called with 0
    - Test: pump on, water low → `ledcWrite` called with 0, `pump_state` written false
    - _Requirements: 8.1, 8.2, 6.3, 6.4_

- [x] 6. ESP32 firmware — stream callback handler (`onFirebaseStream`)
  - [x] 6.1 Implement `onFirebaseStream(FirebaseStream data)` dispatch logic
    - Dispatch on `data.dataPath()`: `/pump_mode` → `handleModeChange`, `/pump_speed` → `handleSpeedChange`, `/pump_switch` → `handleSwitchChange`, `/interval_on_min` and `/interval_off_min` → `autoTimer.setOnInterval` / `setOffInterval`
    - Guard each branch with `data.dataType()` check before casting
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [x] 6.2 Implement `handleModeChange(String mode)`
    - Update `firmwareState.pump_mode`
    - If switching to auto: activate `autoTimer`; if switching to manual: deactivate `autoTimer`
    - _Requirements: 3.1, 4.4, 5.4_

  - [x] 6.3 Implement `handleSpeedChange(int speed)`
    - Update `firmwareState.pump_speed`; call `applyPumpState(firmwareState.pump_state)` to re-apply PWM
    - _Requirements: 3.2, 6.2_

  - [x] 6.4 Implement `handleSwitchChange(bool on)`
    - Only act when `firmwareState.pump_mode == "manual"`; call `applyPumpState(on)`
    - _Requirements: 3.3, 5.1, 5.2_

  - [x] 6.5 Write property test for stream callback mode dispatch (Property 2)
    - **Property 2: Stream Callback Dispatches Mode Change**
    - For any `pump_mode` ∈ {"auto","manual"}, call `onFirebaseStream` with path `/pump_mode`; assert `firmwareState.pump_mode` equals received value
    - **Validates: Requirements 3.1**

  - [x] 6.6 Write property test for stream callback speed dispatch (Property 3)
    - **Property 3: Stream Callback Applies Pump Speed to PWM**
    - Generate `pump_speed` ∈ [0, 255]; mock pump on and water ok; assert `ledcWrite` called with exact value
    - **Validates: Requirements 3.2, 6.2**

  - [x] 6.7 Write property test for manual mode pump switch (Property 4)
    - **Property 4: Manual Mode — Pump Switch Controls Pump State**
    - Generate `pump_switch` ∈ {true, false}; set mode="manual", water ok; assert pump state matches switch
    - **Validates: Requirements 3.3, 5.1, 5.2**

  - [x] 6.8 Write property test for auto mode ignores pump switch (Property 7)
    - **Property 7: Auto Mode Ignores Pump Switch**
    - Generate `pump_switch` ∈ {true, false}; set mode="auto"; assert no pump state change
    - **Validates: Requirements 5.4**

  - [x] 6.9 Write unit tests for `onFirebaseStream` dispatch
    - Test each path branch dispatches to the correct handler
    - Test malformed data type is ignored without crash
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 7. ESP32 firmware — auto mode timer
  - [x] 7.1 Implement `AutoTimer` struct with `tick()`, `setOnInterval()`, `setOffInterval()`, `activate()`, `deactivate()`
    - Use `millis()`-based elapsed time; toggle `pumpOn` when elapsed ≥ target interval
    - Call `applyPumpState(pumpOn)` on each toggle
    - Write `pump_state` to Firebase on each toggle (via `applyPumpState`)
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 7.2 Wire `autoTimer.tick()` into the main `loop()`
    - Call `autoTimer.tick()` on every loop iteration
    - _Requirements: 4.1, 4.2_

  - [x] 7.3 Write property test for auto timer cycling (Property 5)
    - **Property 5: Auto Timer Cycles at Correct Intervals**
    - Generate `on_min`, `off_min` ∈ [1, 60]; mock `millis()` to advance time; assert toggle occurs exactly at threshold, not before
    - **Validates: Requirements 3.4, 4.1**

  - [x] 7.4 Write property test for PWM duty cycle matches pump state (Property 8)
    - **Property 8: PWM Duty Cycle Matches Pump On/Off State**
    - Generate `pump_speed` ∈ [0, 255] and `pump_state` ∈ {true, false}; assert PWM=0 when off, PWM=speed when on and water ok
    - **Validates: Requirements 6.3, 6.4**

  - [x] 7.5 Write unit tests for `AutoTimer`
    - Test: timer inactive → no toggle
    - Test: elapsed < interval → no toggle
    - Test: elapsed ≥ on interval → pump turns off, `pump_state` written
    - Test: elapsed ≥ off interval → pump turns on, `pump_state` written
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 8. ESP32 firmware — sensor reporter
  - [x] 8.1 Implement `sensorLoop()` with 30-second `millis()` timer
    - Read `analogRead(MOISTURE_PIN)` and `digitalRead(WATER_LEVEL_PIN)`
    - Clamp `moisture` to 0–4095; log anomaly via `Serial` if out of range
    - Build `FirebaseJson` and call `Firebase.updateNode` to write to `SENSORS_PATH`
    - Re-evaluate safety interlock: if `waterLow`, call `applyPumpState(false)`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 8.1_

  - [x] 8.2 Wire `sensorLoop()` into the main `loop()`
    - _Requirements: 7.4_

  - [x] 8.3 Write property test for sensor values written to Firebase (Property 9)
    - **Property 9: Sensor Values Are Written to Firebase**
    - Generate `moisture` ∈ [0, 4095] and `water_level_low` ∈ {true, false}; mock `analogRead`/`digitalRead`; assert Firebase write contains exact values
    - **Validates: Requirements 7.3**

  - [x] 8.4 Write unit tests for `sensorLoop`
    - Test: 30 s not elapsed → no read, no write
    - Test: 30 s elapsed → reads both sensors, writes to Firebase
    - Test: `water_level_low` true → `applyPumpState(false)` called
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [x] 9. ESP32 firmware — error handling and stream timeout
  - [x] 9.1 Implement `onStreamTimeout` callback
    - Re-call `Firebase.beginStream` to reconnect the stream
    - Log timeout event via `Serial`
    - _Requirements: 2.3_

  - [x] 9.2 Add Firebase write error logging
    - After each `Firebase.setBool` / `Firebase.updateNode` call, check return value; log failure via `Serial`
    - _Requirements: 7.3, 4.3, 5.3_

- [x] 10. ESP32 firmware checkpoint
  - Ensure all firmware unit tests and property tests pass on host (native build).
  - Flash firmware to ESP32 and verify serial output shows WiFi connected, Firebase streaming, and sensor writes every 30 s.
  - Ask the user if any questions arise before proceeding to the Flutter app.

- [x] 11. Flutter app — project structure and dependencies
  - [x] 11.1 Add required packages to `pubspec.yaml`
    - `firebase_core`, `firebase_database`, `flutter_riverpod`
    - Add dev dependencies: `flutter_test`, `mockito`, `build_runner`, `fast_check` (or `hypothesis`)
    - Run `flutter pub get`
    - _Requirements: 9.1_

  - [x] 11.2 Initialise Firebase in `main.dart`
    - Call `Firebase.initializeApp()` with `DefaultFirebaseOptions.currentPlatform` before `runApp`
    - Wrap app root with `ProviderScope`
    - _Requirements: 9.1_

- [x] 12. Flutter app — `TowerState` data model
  - [x] 12.1 Implement `TowerState` class with all fields and `fromSnapshot` factory
    - Fields: `pumpSpeed`, `pumpMode`, `pumpState`, `pumpSwitch`, `intervalOnMin`, `intervalOffMin`, `moisture`, `waterLevelLow`
    - `fromSnapshot` uses null-coalescing defaults for all fields so the app never crashes on partial data
    - Implement `speedPercent` getter and `sliderToSpeed(double)` static method
    - Implement `waterLevelDisplay` getter returning `'Good'` or `'Low'`
    - _Requirements: 1.2, 1.3, 10.2, 12.3, 12.4_

  - [x] 12.2 Implement `toMap()` method on `TowerState` for test serialisation
    - Returns a `Map<String, dynamic>` matching the Firebase schema structure (including nested `sensors` key)
    - _Requirements: 1.2, 1.3_

  - [x] 12.3 Write property test for TowerState serialisation round-trip (Property 1)
    - **Property 1: TowerState Serialization Round-Trip**
    - Generate random valid `TowerState` instances; assert `TowerState.fromSnapshot(toMap(state))` equals original
    - **Validates: Requirements 1.2, 1.3**

  - [x] 12.4 Write property test for water level display mapping (Property 12)
    - **Property 12: Water Level Display Maps Boolean to String**
    - For `water_level_low` ∈ {true, false}, assert `waterLevelDisplay` returns `'Low'` or `'Good'` respectively
    - **Validates: Requirements 10.2**

  - [x] 12.5 Write property test for slider mapping monotonicity and bounds (Property 13)
    - **Property 13: Speed Slider Mapping Is Monotonic and Bounded**
    - Generate `p` ∈ [0.0, 1.0]; assert result ∈ [0, 255]; generate `p1 ≤ p2`; assert `sliderToSpeed(p1) ≤ sliderToSpeed(p2)`
    - **Validates: Requirements 12.4**

  - [x] 12.6 Write unit tests for `TowerState`
    - Test `fromSnapshot` with complete data, missing fields (defaults applied), and null sensors node
    - Test `waterLevelDisplay` for both boolean values
    - Test `sliderToSpeed` at 0.0, 0.5, and 1.0
    - Test `speedPercent` at 0, 128, and 255
    - _Requirements: 1.2, 1.3, 10.2, 12.3, 12.4_

- [x] 13. Flutter app — `TowerRepository`
  - [x] 13.1 Implement `TowerRepository` class
    - Constructor takes `FirebaseDatabase`; builds `DatabaseReference` to `farms/farm_id_1/towers/tower_1`
    - `watchTower()` returns `Stream<TowerState>` by mapping `_ref.onValue`
    - `setPumpMode(String)`, `setPumpSwitch(bool)`, `setPumpSpeed(int)`, `setIntervals(int, int)` write to correct child paths
    - _Requirements: 9.2, 11.2, 12.2, 12.4, 13.2_

  - [x] 13.2 Write property test for interval round-trip through Firebase (Property 17)
    - **Property 17: Interval Round-Trip Through Firebase**
    - Generate `interval` ∈ [1, 1440]; write via `setIntervals`; read back via `fromSnapshot`; assert same integer for both fields
    - **Validates: Requirements 13.2, 13.4**

  - [x] 13.3 Write unit tests for `TowerRepository`
    - Use `MockDatabaseReference` (mockito); assert correct Firebase paths and values for each write method
    - Assert `watchTower()` maps `onValue` events to `TowerState` correctly
    - _Requirements: 9.2, 11.2, 12.2, 12.4, 13.2_

- [x] 14. Flutter app — interval validation
  - [x] 14.1 Implement `validateInterval(String input)` function
    - Returns `null` (valid) for strings that parse as integers ≥ 1
    - Returns a non-null error message for empty strings, non-numeric strings, zero, negative integers, and decimal numbers
    - Does not call any Firebase write operation
    - _Requirements: 13.3_

  - [x] 14.2 Write property test for interval validation (Property 16)
    - **Property 16: Interval Validation Rejects Invalid Input**
    - Generate random strings including non-numeric, empty, zero, negative, and decimal; assert error message returned and no Firebase write invoked
    - **Validates: Requirements 13.3**

  - [x] 14.3 Write unit tests for `validateInterval`
    - Test valid: "1", "60", "1440"
    - Test invalid: "", "0", "-1", "1.5", "abc", " "
    - _Requirements: 13.3_

- [x] 15. Flutter app — Riverpod providers
  - [x] 15.1 Implement `towerRepositoryProvider` and `towerStreamProvider`
    - `towerRepositoryProvider`: `Provider<TowerRepository>` using `FirebaseDatabase.instance`
    - `towerStreamProvider`: `StreamProvider<TowerState>` wrapping `towerRepositoryProvider.watchTower()`
    - `connectionStatusProvider`: `Provider<bool>` returning `ref.watch(towerStreamProvider).hasValue`
    - _Requirements: 9.2, 9.4_

- [x] 16. Flutter app — UI widgets
  - [x] 16.1 Implement `ConnectionStatusBanner` widget
    - Shown when `connectionStatusProvider` is false; displays a visible connection-lost indicator
    - _Requirements: 9.4_

  - [x] 16.2 Implement `SensorCard` with `MoistureDisplay` and `WaterLevelDisplay`
    - `MoistureDisplay`: shows `TowerState.moisture` integer
    - `WaterLevelDisplay`: shows `TowerState.waterLevelDisplay` string (`'Good'` / `'Low'`)
    - Both update reactively from `towerStreamProvider`
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 16.3 Implement `ModeSwitchTile` widget
    - Reflects `TowerState.pumpMode`; on toggle writes opposite mode via `TowerRepository.setPumpMode`
    - _Requirements: 11.1, 11.2_

  - [x] 16.4 Implement `AutoModePanel` with `IntervalOnField` and `IntervalOffField`
    - Each field uses `validateInterval`; on valid submit writes to Firebase via `TowerRepository.setIntervals`
    - Displays inline validation error and highlights field in red on invalid input; does not write to Firebase
    - Shows snackbar on Firebase write failure
    - _Requirements: 13.1, 13.2, 13.3, 13.4_

  - [x] 16.5 Implement `ManualModePanel` with `PumpSwitchTile` and `SpeedSlider`
    - `PumpSwitchTile`: reflects `TowerState.pumpState`; on toggle writes to `pump_switch` via `TowerRepository.setPumpSwitch`
    - `SpeedSlider`: range 0.0–1.0 displayed as 0%–100%; on change calls `TowerState.sliderToSpeed` and writes via `TowerRepository.setPumpSpeed`
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

  - [x] 16.6 Implement `TowerDashboard` root widget
    - `ConsumerWidget` watching `towerStreamProvider`
    - Composes `ConnectionStatusBanner`, `SensorCard`, `ModeSwitchTile`, and conditionally `AutoModePanel` or `ManualModePanel` based on `pumpMode`
    - _Requirements: 9.3, 11.3_

  - [x] 16.7 Write property test for mode switch reflects and writes pump mode (Property 14)
    - **Property 14: Mode Switch Reflects and Writes Pump Mode**
    - For `pump_mode` ∈ {"auto","manual"}, assert `fromSnapshot` parses correctly and widget reflects it; assert toggle writes opposite mode
    - **Validates: Requirements 11.1, 11.2**

  - [x] 16.8 Write property test for panel visibility (Property 15)
    - **Property 15: Mode Determines Visible Control Panel**
    - For each `pump_mode`, assert exactly one panel is visible; assert both are never simultaneously visible or hidden
    - **Validates: Requirements 11.3, 12.1, 13.1**

  - [x] 16.9 Write widget tests for `TowerDashboard`
    - Test: `ConnectionStatusBanner` appears when stream has error
    - Test: `AutoModePanel` visible and `ManualModePanel` hidden when `pump_mode == 'auto'`
    - Test: `ManualModePanel` visible and `AutoModePanel` hidden when `pump_mode == 'manual'`
    - Test: sensor display updates when stream emits new `TowerState`
    - Test: pump switch reflects `pump_state` changes from Firebase
    - _Requirements: 9.3, 9.4, 10.3, 11.3, 12.1, 12.5, 13.1_

- [x] 17. Flutter app checkpoint
  - Ensure all Flutter unit tests, property tests, and widget tests pass (`flutter test`).
  - Run the app against the live Firebase project and verify sensor values update in real time.
  - Ask the user if any questions arise before proceeding to integration.

- [x] 18. Integration — wire all three tiers together
  - [x] 18.1 Verify Firebase schema matches both the ESP32 firmware paths and the Flutter `TowerRepository` paths
    - Confirm `TOWER_PATH` constant in firmware equals `farms/farm_id_1/towers/tower_1`
    - Confirm `SENSORS_PATH` constant equals `farms/farm_id_1/towers/tower_1/sensors`
    - _Requirements: 1.1, 2.3, 9.2_

  - [x] 18.2 Write integration test for Firebase write → stream update latency
    - Write a field to Firebase from a test client; measure time until `towerStreamProvider` emits the updated value
    - Assert update is received within the real-time sync latency of the Firebase service
    - _Requirements: 1.4_

  - [x] 18.3 Write integration test for end-to-end mode change flow
    - App writes `pump_mode = 'auto'` → Firebase → firmware stream callback updates `firmwareState.pump_mode`
    - Assert firmware auto timer activates and `pump_state` is written back to Firebase
    - _Requirements: 3.1, 4.1, 4.3_

- [x] 19. Final checkpoint — full system validation
  - Ensure all tests across all layers pass (firmware native tests, `flutter test`).
  - Verify no orphaned code: every module is imported and exercised by at least one test or integration path.
  - Ask the user if any questions arise.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP build.
- Each task references specific requirements for full traceability.
- Checkpoints (tasks 10, 17, 19) ensure incremental validation before moving to the next tier.
- Property tests validate universal correctness properties across randomly generated inputs (minimum 100 iterations each).
- Unit tests validate specific examples, boundary values, and error conditions.
- The ESP32 property tests use [rapidcheck](https://github.com/emil-e/rapidcheck); Flutter property tests use [fast_check](https://pub.dev/packages/fast_check) or [hypothesis](https://pub.dev/packages/hypothesis).
- Tag format for ESP32 tests: `// Feature: hydroponics-farm-management, Property N: <title>`
- Tag format for Flutter tests: `// Feature: hydroponics-farm-management, Property N: <title>`
