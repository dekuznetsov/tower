// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponics_farm_management/models/tower_state.dart';
import 'package:hydroponics_farm_management/repositories/tower_repository.dart';

// =============================================================================
// Manual mock infrastructure
// =============================================================================

class _CallRecord {
  final String path;
  final Object? value;
  final Map<String, Object?>? updateMap;

  const _CallRecord.set(this.path, this.value) : updateMap = null;
  const _CallRecord.update(this.path, this.updateMap) : value = null;

  @override
  String toString() => updateMap != null
      ? '_CallRecord.update($path, $updateMap)'
      : '_CallRecord.set($path, $value)';
}

class _MockDatabaseReference implements DatabaseReference {
  final String path;
  final List<_CallRecord> calls;
  final StreamController<DatabaseEvent> _onValueController;

  _MockDatabaseReference(this.path, this.calls, this._onValueController);

  @override
  DatabaseReference child(String path) {
    final newPath = this.path.isEmpty ? path : '${this.path}/$path';
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

const _towerPath = 'farms/farm_id_1/towers/tower_1';

void forAll(
  int numRuns,
  void Function(Random rng, int run) body, {
  int? seed,
}) {
  final effectiveSeed = seed ?? DateTime.now().microsecondsSinceEpoch;
  final rng = Random(effectiveSeed);
  for (var i = 0; i < numRuns; i++) {
    try {
      body(rng, i);
    } catch (e) {
      fail('Property failed on run $i (seed=$effectiveSeed): $e');
    }
  }
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // Feature: hydroponics-farm-management, Property 17: Interval Round-Trip Through Firebase
  // Validates: Requirements 13.2, 13.4
  group('Property 17: Interval Round-Trip Through Firebase', () {
    test(
      'Property 17: writing an interval via setIntervals and reading back via '
      'TowerState.fromMap preserves both intervalOnMin and intervalOffMin',
      () {
        forAll(200, (rng, _) {
          final interval = rng.nextInt(1440) + 1;

          final original = TowerState(
            pumpSpeed: 0,
            pumpMode: 'auto',
            pumpState: false,
            pumpSwitch: false,
            intervalOnMin: interval,
            intervalOffMin: interval,
            moisture: 0,
            waterLevelLow: false,
          );

          final roundTripped = TowerState.fromMap(original.toMap());

          expect(roundTripped.intervalOnMin, equals(interval));
          expect(roundTripped.intervalOffMin, equals(interval));
        });
      },
    );

    test(
      'Property 17 (distinct on/off): independent on and off intervals are '
      'both preserved through the round-trip',
      () {
        forAll(200, (rng, _) {
          final onMin = rng.nextInt(1440) + 1;
          final offMin = rng.nextInt(1440) + 1;

          final original = TowerState(
            pumpSpeed: 0,
            pumpMode: 'auto',
            pumpState: false,
            pumpSwitch: false,
            intervalOnMin: onMin,
            intervalOffMin: offMin,
            moisture: 0,
            waterLevelLow: false,
          );

          final roundTripped = TowerState.fromMap(original.toMap());

          expect(roundTripped.intervalOnMin, equals(onMin));
          expect(roundTripped.intervalOffMin, equals(offMin));
        });
      },
    );
  });

  group('TowerRepository', () {
    test('constructor builds a reference to the correct tower path', () {
      final harness = _makeTestHarness();
      final repo = TowerRepository(harness.db);
      expect(repo, isNotNull);
      expect(harness.calls, isEmpty);
    });

    group('setPumpMode', () {
      test("setPumpMode('auto') writes 'auto' to pump_mode child", () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        await repo.setPumpMode('auto');
        expect(harness.calls, hasLength(1));
        expect(harness.calls.first.path, equals('$_towerPath/pump_mode'));
        expect(harness.calls.first.value, equals('auto'));
      });

      test("setPumpMode('manual') writes 'manual' to pump_mode child", () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        await repo.setPumpMode('manual');
        expect(harness.calls.first.path, equals('$_towerPath/pump_mode'));
        expect(harness.calls.first.value, equals('manual'));
      });
    });

    group('setPumpSwitch', () {
      test('setPumpSwitch(true) writes true to pump_switch child', () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        await repo.setPumpSwitch(true);
        expect(harness.calls.first.path, equals('$_towerPath/pump_switch'));
        expect(harness.calls.first.value, equals(true));
      });

      test('setPumpSwitch(false) writes false to pump_switch child', () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        await repo.setPumpSwitch(false);
        expect(harness.calls.first.path, equals('$_towerPath/pump_switch'));
        expect(harness.calls.first.value, equals(false));
      });
    });

    group('setPumpSpeed', () {
      test('setPumpSpeed(128) writes 128 to pump_speed child', () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        await repo.setPumpSpeed(128);
        expect(harness.calls.first.path, equals('$_towerPath/pump_speed'));
        expect(harness.calls.first.value, equals(128));
      });

      test('setPumpSpeed(0) writes 0 to pump_speed child', () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        await repo.setPumpSpeed(0);
        expect(harness.calls.first.value, equals(0));
      });

      test('setPumpSpeed(255) writes 255 to pump_speed child', () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        await repo.setPumpSpeed(255);
        expect(harness.calls.first.value, equals(255));
      });
    });

    group('setIntervals', () {
      test('setIntervals(5, 10) calls update with correct map', () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        await repo.setIntervals(5, 10);
        expect(harness.calls, hasLength(1));
        expect(harness.calls.first.path, equals(_towerPath));
        expect(harness.calls.first.updateMap,
            equals({'interval_on_min': 5, 'interval_off_min': 10}));
      });

      test('setIntervals(1, 1440) writes boundary values correctly', () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);
        await repo.setIntervals(1, 1440);
        expect(harness.calls.first.updateMap,
            equals({'interval_on_min': 1, 'interval_off_min': 1440}));
      });
    });

    group('watchTower', () {
      test('watchTower() maps onValue DatabaseEvent to TowerState correctly',
          () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);

        final snapshotData = {
          'pump_speed': 200,
          'pump_mode': 'auto',
          'pump_state': true,
          'pump_switch': false,
          'interval_on_min': 15,
          'interval_off_min': 30,
          'sensors': {
            'moisture': 1024,
            'water_level_low': false,
          },
        };

        final emitted = <TowerState>[];
        final subscription = repo.watchTower().listen(emitted.add);

        harness.onValueController
            .add(_MockDatabaseEvent(_MockDataSnapshot(snapshotData)));

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(emitted, hasLength(1));
        final state = emitted.first;
        expect(state.pumpSpeed, equals(200));
        expect(state.pumpMode, equals('auto'));
        expect(state.pumpState, isTrue);
        expect(state.intervalOnMin, equals(15));
        expect(state.moisture, equals(1024));
      });

      test('watchTower() applies TowerState defaults for missing fields',
          () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);

        final emitted = <TowerState>[];
        final subscription = repo.watchTower().listen(emitted.add);

        harness.onValueController.add(
            _MockDatabaseEvent(_MockDataSnapshot({'pump_mode': 'manual'})));

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(emitted, hasLength(1));
        expect(emitted.first.pumpMode, equals('manual'));
        expect(emitted.first.pumpSpeed, equals(0));
        expect(emitted.first.moisture, equals(0));
      });

      test('watchTower() emits multiple TowerState values for multiple events',
          () async {
        final harness = _makeTestHarness();
        final repo = TowerRepository(harness.db);

        final emitted = <TowerState>[];
        final subscription = repo.watchTower().listen(emitted.add);

        harness.onValueController.add(
            _MockDatabaseEvent(_MockDataSnapshot({'pump_mode': 'auto'})));
        harness.onValueController.add(
            _MockDatabaseEvent(_MockDataSnapshot({'pump_mode': 'manual'})));

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(emitted, hasLength(2));
        expect(emitted[0].pumpMode, equals('auto'));
        expect(emitted[1].pumpMode, equals('manual'));
      });
    });
  });
}

// =============================================================================
// Minimal DataSnapshot / DatabaseEvent stubs
// =============================================================================

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
