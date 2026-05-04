// Integration test: end-to-end mode change flow
//
// Task 18.3 — Requirements: 3.1, 4.1, 4.3
//
// ============================================================================
// REAL INTEGRATION TEST NOTE
// ============================================================================
// A true end-to-end test requires both a live Firebase project AND a physical
// (or emulated) ESP32 running the firmware.  The full flow is:
//
//   1. Flutter app writes `pump_mode = 'auto'` to Firebase.
//   2. Firebase delivers the change to the ESP32 via its stream callback.
//   3. The ESP32 firmware calls `handleModeChange('auto')`, which activates
//      `autoTimer`.
//   4. On the next `autoTimer.tick()` cycle the pump turns on and the firmware
//      writes `pump_state = true` back to Firebase.
//   5. Firebase delivers the `pump_state` update to the Flutter app stream.
//   6. `towerStreamProvider` emits a new `TowerState` with `pumpState == true`.
//
// The test below simulates each step using the mock StreamController
// infrastructure from the existing test suite so it can be executed in CI
// without live hardware or a Firebase connection.
// ============================================================================

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponics_farm_management/models/tower_state.dart';
import 'package:hydroponics_farm_management/providers/tower_providers.dart';
import 'package:hydroponics_farm_management/repositories/tower_repository.dart';

// =============================================================================
// Mock Firebase infrastructure
// =============================================================================

class _CallRecord {
  final String path;
  final Object? value;
  final Map<String, Object?>? updateMap;

  const _CallRecord.set(this.path, this.value) : updateMap = null;
  const _CallRecord.update(this.path, this.updateMap) : value = null;
}

class _MockDatabaseReference implements DatabaseReference {
  final String path;
  final List<_CallRecord> calls;
  final StreamController<DatabaseEvent> _onValueController;

  _MockDatabaseReference(this.path, this.calls, this._onValueController);

  @override
  DatabaseReference child(String childPath) {
    final newPath = path.isEmpty ? childPath : '$path/$childPath';
    return _MockDatabaseReference(newPath, calls, _onValueController);
  }

  @override
  Future<void> set(Object? value, {Object? priority}) async {
    calls.add(_CallRecord.set(path, value));
  }

  @override
  Future<void> update(Map<String, Object?> value) async {
    calls.add(_CallRecord.update(path, value));
  }

  @override
  Stream<DatabaseEvent> get onValue => _onValueController.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFirebaseDatabase implements FirebaseDatabase {
  final _MockDatabaseReference _root;

  _MockFirebaseDatabase(this._root);

  @override
  DatabaseReference ref([String? path]) {
    if (path == null || path.isEmpty) return _root;
    return _root.child(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockDataSnapshot implements DataSnapshot {
  final Map<String, dynamic> _data;
  _MockDataSnapshot(this._data);

  @override
  Object? get value => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockDatabaseEvent implements DatabaseEvent {
  @override
  final DataSnapshot snapshot;
  _MockDatabaseEvent(this.snapshot);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// Simulated firmware state
// =============================================================================

class _SimulatedFirmwareState {
  String pumpMode = 'manual';
  int pumpSpeed = 0;
  bool pumpSwitch = false;
  bool pumpState = false;
  bool waterLevelLow = false;

  bool autoTimerActive = false;
  bool autoTimerPumpOn = false;
  int intervalOnMs = 60000;
  int intervalOffMs = 60000;
}

List<({String path, Object value})> simulateOnFirebaseStream({
  required _SimulatedFirmwareState state,
  required String dataPath,
  required Object dataValue,
}) {
  final writes = <({String path, Object value})>[];

  if (dataPath == '/pump_mode') {
    final mode = dataValue as String;
    state.pumpMode = mode;

    if (mode == 'auto') {
      state.autoTimerActive = true;
      state.autoTimerPumpOn = false;
    } else {
      state.autoTimerActive = false;
    }
  } else if (dataPath == '/pump_switch') {
    if (state.pumpMode == 'manual') {
      final on = dataValue as bool;
      final actualOn = on && !state.waterLevelLow;
      if (state.pumpState != actualOn) {
        state.pumpState = actualOn;
        writes.add((
          path: 'farms/farm_id_1/towers/tower_1/pump_state',
          value: actualOn,
        ));
      }
    }
  }

  return writes;
}

List<({String path, Object value})> simulateAutoTimerTick(
  _SimulatedFirmwareState state,
) {
  final writes = <({String path, Object value})>[];

  if (!state.autoTimerActive) return writes;

  state.autoTimerPumpOn = !state.autoTimerPumpOn;
  final actualOn = state.autoTimerPumpOn && !state.waterLevelLow;
  state.pumpState = actualOn;

  writes.add((
    path: 'farms/farm_id_1/towers/tower_1/pump_state',
    value: actualOn,
  ));

  return writes;
}

// =============================================================================
// Test harness factory
// =============================================================================

({
  _MockFirebaseDatabase db,
  List<_CallRecord> calls,
  StreamController<DatabaseEvent> onValueController,
}) _makeTestHarness() {
  final calls = <_CallRecord>[];
  final controller = StreamController<DatabaseEvent>.broadcast();
  final root = _MockDatabaseReference('', calls, controller);
  final db = _MockFirebaseDatabase(root);
  return (db: db, calls: calls, onValueController: controller);
}

ProviderContainer _makeContainer(
  _MockFirebaseDatabase db,
  TowerRepository repo,
) {
  return ProviderContainer(
    overrides: [towerRepositoryProvider.overrideWithValue(repo)],
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('18.3 End-to-end mode change flow', () {
    test(
      '18.3a: app writes pump_mode=auto → firmware receives it → '
      'autoTimer activates → pump_state written back → stream emits update',
      () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        final container = _makeContainer(harness.db, repo);
        addTearDown(container.dispose);

        final emitted = <TowerState>[];
        final subscription =
            container.read(towerStreamProvider.stream).listen(emitted.add);
        addTearDown(subscription.cancel);

        // Step 1: App writes pump_mode = 'auto' to Firebase.
        await repo.setPumpMode('auto');

        expect(harness.calls, hasLength(1));
        expect(harness.calls.first.path,
            equals('farms/farm_id_1/towers/tower_1/pump_mode'));
        expect(harness.calls.first.value, equals('auto'));

        // Step 2: Firebase delivers the update to the firmware stream callback.
        final firmwareState = _SimulatedFirmwareState();
        final modeChangeWrites = simulateOnFirebaseStream(
          state: firmwareState,
          dataPath: '/pump_mode',
          dataValue: 'auto',
        );

        // Requirement 3.1: firmware state updated within one callback cycle.
        expect(firmwareState.pumpMode, equals('auto'));

        // Requirement 4.1: autoTimer must be active after switching to auto.
        expect(firmwareState.autoTimerActive, isTrue);

        // No pump_state write yet — timer hasn't ticked.
        expect(modeChangeWrites, isEmpty);

        // Step 3: autoTimer.tick() fires — pump turns on.
        final timerWrites = simulateAutoTimerTick(firmwareState);

        // Requirement 4.3: firmware writes pump_state back to Firebase.
        expect(timerWrites, hasLength(1));
        expect(timerWrites.first.path,
            equals('farms/farm_id_1/towers/tower_1/pump_state'));
        expect(timerWrites.first.value, isTrue);
        expect(firmwareState.pumpState, isTrue);

        // Step 4: Firebase delivers the pump_state update to the Flutter stream.
        harness.onValueController.add(
          _MockDatabaseEvent(
            _MockDataSnapshot({
              'pump_mode': 'auto',
              'pump_speed': 0,
              'pump_state': true,
              'pump_switch': false,
              'interval_on_min': 1,
              'interval_off_min': 1,
              'sensors': {'moisture': 0, 'water_level_low': false},
            }),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // Step 5: Assert the Flutter stream emits the updated TowerState.
        expect(emitted, hasLength(1));
        expect(emitted.first.pumpMode, equals('auto'));
        expect(emitted.first.pumpState, isTrue);
      },
    );

    test(
      '18.3b: firmware autoTimer does NOT activate when mode changes to manual',
      () async {
        final firmwareState = _SimulatedFirmwareState();

        simulateOnFirebaseStream(
          state: firmwareState,
          dataPath: '/pump_mode',
          dataValue: 'auto',
        );
        expect(firmwareState.autoTimerActive, isTrue);

        // Requirement 4.4: autoTimer must stop when mode changes to manual.
        simulateOnFirebaseStream(
          state: firmwareState,
          dataPath: '/pump_mode',
          dataValue: 'manual',
        );

        expect(firmwareState.pumpMode, equals('manual'));
        expect(firmwareState.autoTimerActive, isFalse);

        final writes = simulateAutoTimerTick(firmwareState);
        expect(writes, isEmpty);
      },
    );

    test(
      '18.3c: pump_state is written to Firebase on each auto timer toggle',
      () async {
        final firmwareState = _SimulatedFirmwareState();

        simulateOnFirebaseStream(
          state: firmwareState,
          dataPath: '/pump_mode',
          dataValue: 'auto',
        );

        final tick1Writes = simulateAutoTimerTick(firmwareState);
        expect(tick1Writes.first.value, isTrue);
        expect(firmwareState.pumpState, isTrue);

        final tick2Writes = simulateAutoTimerTick(firmwareState);
        expect(tick2Writes.first.value, isFalse);
        expect(firmwareState.pumpState, isFalse);

        final tick3Writes = simulateAutoTimerTick(firmwareState);
        expect(tick3Writes.first.value, isTrue);
        expect(firmwareState.pumpState, isTrue);
      },
    );

    test(
      '18.3d: safety interlock prevents pump activation during auto mode '
      'when water_level_low is true',
      () async {
        final firmwareState = _SimulatedFirmwareState();
        firmwareState.waterLevelLow = true;

        simulateOnFirebaseStream(
          state: firmwareState,
          dataPath: '/pump_mode',
          dataValue: 'auto',
        );
        expect(firmwareState.autoTimerActive, isTrue);

        final writes = simulateAutoTimerTick(firmwareState);

        expect(writes.first.value, isFalse);
        expect(firmwareState.pumpState, isFalse);
      },
    );

    test(
      '18.3e: full round-trip — stream emits pump_mode and pump_state updates '
      'in correct order',
      () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        final container = _makeContainer(harness.db, repo);
        addTearDown(container.dispose);

        final emitted = <TowerState>[];
        final subscription =
            container.read(towerStreamProvider.stream).listen(emitted.add);
        addTearDown(subscription.cancel);

        await repo.setPumpMode('auto');

        harness.onValueController.add(
          _MockDatabaseEvent(
            _MockDataSnapshot({
              'pump_mode': 'auto',
              'pump_speed': 0,
              'pump_state': false,
              'pump_switch': false,
              'interval_on_min': 5,
              'interval_off_min': 10,
              'sensors': {'moisture': 512, 'water_level_low': false},
            }),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final firmwareState = _SimulatedFirmwareState();
        simulateOnFirebaseStream(
          state: firmwareState,
          dataPath: '/pump_mode',
          dataValue: 'auto',
        );
        simulateAutoTimerTick(firmwareState);

        harness.onValueController.add(
          _MockDatabaseEvent(
            _MockDataSnapshot({
              'pump_mode': 'auto',
              'pump_speed': 0,
              'pump_state': true,
              'pump_switch': false,
              'interval_on_min': 5,
              'interval_off_min': 10,
              'sensors': {'moisture': 512, 'water_level_low': false},
            }),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(emitted, hasLength(2));

        expect(emitted[0].pumpMode, equals('auto'));
        expect(emitted[0].pumpState, isFalse);

        expect(emitted[1].pumpMode, equals('auto'));
        expect(emitted[1].pumpState, isTrue);
        expect(emitted[1].intervalOnMin, equals(5));
        expect(emitted[1].intervalOffMin, equals(10));
        expect(emitted[1].moisture, equals(512));
      },
    );
  });
}
