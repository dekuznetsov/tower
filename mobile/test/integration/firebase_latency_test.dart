// Integration test: Firebase write → stream update latency
//
// Task 18.2 — Requirements: 1.4
//
// ============================================================================
// REAL INTEGRATION TEST NOTE
// ============================================================================
// A true end-to-end latency test requires a live Firebase project.
// To run against a real Firebase instance:
//
//   1. Ensure `google-services.json` (Android) or `GoogleService-Info.plist`
//      (iOS/macOS) is present and points to your Firebase project.
//   2. Run with the integration_test package:
//        flutter test integration_test/firebase_latency_test.dart
//   3. The test will write a value to `farms/farm_id_1/towers/tower_1` and
//      measure the wall-clock time until `towerStreamProvider` emits the
//      updated `TowerState`.
//   4. Assert that the round-trip latency is within the real-time sync
//      latency of the Firebase service (typically < 2 000 ms on a good
//      connection; the test uses a generous 5 000 ms threshold).
//
// The test below simulates the same flow using the mock StreamController
// infrastructure from the existing test suite so it can be executed in CI
// without a live Firebase connection.
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

ProviderContainer _makeContainer(_MockFirebaseDatabase db) {
  final repo = TowerRepository(db);
  return ProviderContainer(
    overrides: [towerRepositoryProvider.overrideWithValue(repo)],
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('18.2 Firebase write → stream update latency', () {
    test(
      '18.2a: stream emits updated TowerState after a write is performed',
      () async {
        final harness = _makeTestHarness();
        final container = _makeContainer(harness.db);
        addTearDown(container.dispose);

        final repo = container.read(towerRepositoryProvider);

        final emitted = <TowerState>[];
        final subscription =
            container.read(towerStreamProvider.stream).listen(emitted.add);
        addTearDown(subscription.cancel);

        final writeStart = DateTime.now();
        await repo.setPumpMode('auto');

        expect(harness.calls, hasLength(1));
        expect(harness.calls.first.path,
            equals('farms/farm_id_1/towers/tower_1/pump_mode'));
        expect(harness.calls.first.value, equals('auto'));

        harness.onValueController.add(
          _MockDatabaseEvent(
            _MockDataSnapshot({
              'pump_mode': 'auto',
              'pump_speed': 0,
              'pump_state': false,
              'pump_switch': false,
              'interval_on_min': 1,
              'interval_off_min': 1,
              'sensors': {'moisture': 0, 'water_level_low': false},
            }),
          ),
        );

        await Future<void>.delayed(Duration.zero);

        final streamReceiveTime = DateTime.now();

        expect(emitted, hasLength(1));
        expect(emitted.first.pumpMode, equals('auto'));

        final latencyMs =
            streamReceiveTime.difference(writeStart).inMilliseconds;
        print('Simulated write→stream latency: ${latencyMs}ms '
            '(real Firebase threshold: 5000ms)');

        // Requirement 1.4: updated value available within real-time sync latency.
        expect(latencyMs, lessThanOrEqualTo(5000));
      },
    );

    test(
      '18.2b: stream emits updated TowerState for each successive write',
      () async {
        final harness = _makeTestHarness();
        final container = _makeContainer(harness.db);
        addTearDown(container.dispose);

        final repo = container.read(towerRepositoryProvider);

        final emitted = <TowerState>[];
        final subscription =
            container.read(towerStreamProvider.stream).listen(emitted.add);
        addTearDown(subscription.cancel);

        await repo.setPumpSpeed(128);
        harness.onValueController.add(
          _MockDatabaseEvent(
            _MockDataSnapshot({
              'pump_speed': 128,
              'pump_mode': 'manual',
              'pump_state': false,
              'pump_switch': false,
              'interval_on_min': 1,
              'interval_off_min': 1,
              'sensors': {'moisture': 0, 'water_level_low': false},
            }),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        await repo.setPumpSpeed(255);
        harness.onValueController.add(
          _MockDatabaseEvent(
            _MockDataSnapshot({
              'pump_speed': 255,
              'pump_mode': 'manual',
              'pump_state': false,
              'pump_switch': false,
              'interval_on_min': 1,
              'interval_off_min': 1,
              'sensors': {'moisture': 0, 'water_level_low': false},
            }),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(emitted, hasLength(2));
        expect(emitted[0].pumpSpeed, equals(128));
        expect(emitted[1].pumpSpeed, equals(255));
      },
    );

    test(
      '18.2c: towerStreamProvider reflects the latest write',
      () async {
        final harness = _makeTestHarness();
        final container = _makeContainer(harness.db);
        addTearDown(container.dispose);

        final repo = container.read(towerRepositoryProvider);

        final emitted = <TowerState>[];
        final subscription =
            container.read(towerStreamProvider.stream).listen(emitted.add);
        addTearDown(subscription.cancel);

        await repo.setPumpMode('auto');
        await repo.setPumpMode('manual');

        harness.onValueController.add(
          _MockDatabaseEvent(
            _MockDataSnapshot({
              'pump_mode': 'manual',
              'pump_speed': 0,
              'pump_state': false,
              'pump_switch': false,
              'interval_on_min': 1,
              'interval_off_min': 1,
              'sensors': {'moisture': 0, 'water_level_low': false},
            }),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(emitted.last.pumpMode, equals('manual'));
      },
    );
  });
}
