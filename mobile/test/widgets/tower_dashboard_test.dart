// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponics_farm_management/models/tower_state.dart';
import 'package:hydroponics_farm_management/providers/tower_providers.dart';
import 'package:hydroponics_farm_management/repositories/tower_repository.dart';
import 'package:hydroponics_farm_management/widgets/auto_mode_panel.dart';
import 'package:hydroponics_farm_management/widgets/connection_status_banner.dart';
import 'package:hydroponics_farm_management/widgets/manual_mode_panel.dart';
import 'package:hydroponics_farm_management/widgets/mode_switch_tile.dart';
import 'package:hydroponics_farm_management/widgets/tower_dashboard.dart';

// ---------------------------------------------------------------------------
// Mock Firebase infrastructure
// ---------------------------------------------------------------------------

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

({
  TowerRepository repo,
  List<_CallRecord> calls,
}) _makeRepoHarness() {
  final calls = <_CallRecord>[];
  final onValueController = StreamController<DatabaseEvent>.broadcast();
  final root = _MockDatabaseReference('', calls, onValueController);
  final db = _MockFirebaseDatabase(root);
  final repo = TowerRepository(db);
  return (repo: repo, calls: calls);
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

TowerState makeTowerState({
  int pumpSpeed = 0,
  String pumpMode = 'manual',
  bool pumpState = false,
  bool pumpSwitch = false,
  int intervalOnMin = 5,
  int intervalOffMin = 10,
  int moisture = 1234,
  bool waterLevelLow = false,
}) {
  return TowerState(
    pumpSpeed: pumpSpeed,
    pumpMode: pumpMode,
    pumpState: pumpState,
    pumpSwitch: pumpSwitch,
    intervalOnMin: intervalOnMin,
    intervalOffMin: intervalOffMin,
    moisture: moisture,
    waterLevelLow: waterLevelLow,
  );
}

Widget buildTestApp({
  required Widget child,
  required StreamController<TowerState> streamController,
  required TowerRepository repo,
}) {
  return ProviderScope(
    overrides: [
      towerRepositoryProvider.overrideWithValue(repo),
      towerStreamProvider.overrideWith(
        (ref) => streamController.stream,
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

Widget buildDashboardApp({
  required StreamController<TowerState> streamController,
  required TowerRepository repo,
}) {
  return ProviderScope(
    overrides: [
      towerRepositoryProvider.overrideWithValue(repo),
      towerStreamProvider.overrideWith(
        (ref) => streamController.stream,
      ),
    ],
    child: const MaterialApp(home: TowerDashboard()),
  );
}

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

// ---------------------------------------------------------------------------
// Property 14: Mode Switch Reflects and Writes Pump Mode
// Feature: hydroponics-farm-management, Property 14: Mode Switch Reflects and Writes Pump Mode
// Validates: Requirements 11.1, 11.2
// ---------------------------------------------------------------------------

void main() {
  group('Property 14: Mode Switch Reflects and Writes Pump Mode', () {
    test(
      'Property 14a: TowerState.fromMap parses pump_mode correctly for both values',
      () {
        for (final mode in ['auto', 'manual']) {
          final state = TowerState.fromMap({'pump_mode': mode});
          expect(state.pumpMode, equals(mode));
        }
      },
    );

    testWidgets(
      'Property 14b-auto: ModeSwitchTile switch is ON when pumpMode==auto',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildTestApp(
          child: const ModeSwitchTile(),
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'auto'));
        await tester.pump();

        final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(tile.value, isTrue);

        await controller.close();
      },
    );

    testWidgets(
      'Property 14b-manual: ModeSwitchTile switch is OFF when pumpMode==manual',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildTestApp(
          child: const ModeSwitchTile(),
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'manual'));
        await tester.pump();

        final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(tile.value, isFalse);

        await controller.close();
      },
    );

    testWidgets(
      'Property 14c-auto: toggling ModeSwitchTile from auto writes manual',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildTestApp(
          child: const ModeSwitchTile(),
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'auto'));
        await tester.pump();

        await tester.tap(find.byType(Switch));
        await tester.pump();

        expect(harness.calls.last.value, equals('manual'));

        await controller.close();
      },
    );

    testWidgets(
      'Property 14c-manual: toggling ModeSwitchTile from manual writes auto',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildTestApp(
          child: const ModeSwitchTile(),
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'manual'));
        await tester.pump();

        await tester.tap(find.byType(Switch));
        await tester.pump();

        expect(harness.calls.last.value, equals('auto'));

        await controller.close();
      },
    );
  });

  // Feature: hydroponics-farm-management, Property 15: Mode Determines Visible Control Panel
  // Validates: Requirements 11.3, 12.1, 13.1
  group('Property 15: Mode Determines Visible Control Panel', () {
    testWidgets(
      'Property 15a: AutoModePanel visible and ManualModePanel absent when pump_mode==auto',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'auto'));
        await tester.pump();

        expect(find.byType(AutoModePanel), findsOneWidget);
        expect(find.byType(ManualModePanel), findsNothing);

        await controller.close();
      },
    );

    testWidgets(
      'Property 15b: ManualModePanel visible and AutoModePanel absent when pump_mode==manual',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'manual'));
        await tester.pump();

        expect(find.byType(ManualModePanel), findsOneWidget);
        expect(find.byType(AutoModePanel), findsNothing);

        await controller.close();
      },
    );

    testWidgets(
      'Property 15c-auto: exactly one panel visible when mode==auto',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'auto'));
        await tester.pump();

        final autoCount = tester.widgetList(find.byType(AutoModePanel)).length;
        final manualCount = tester.widgetList(find.byType(ManualModePanel)).length;

        expect(autoCount + manualCount, equals(1));

        await controller.close();
      },
    );

    testWidgets(
      'Property 15c-manual: exactly one panel visible when mode==manual',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'manual'));
        await tester.pump();

        final autoCount = tester.widgetList(find.byType(AutoModePanel)).length;
        final manualCount = tester.widgetList(find.byType(ManualModePanel)).length;

        expect(autoCount + manualCount, equals(1));

        await controller.close();
      },
    );
  });

  // Widget tests for TowerDashboard (Task 16.9)
  // Validates: Requirements 9.3, 9.4, 10.3, 11.3, 12.1, 12.5, 13.1
  group('TowerDashboard widget tests', () {
    testWidgets(
      '16.9a: ConnectionStatusBanner is visible when stream has an error',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.addError(Exception('Firebase connection lost'));
        await tester.pump();

        expect(find.byKey(const Key('connection_status_banner')), findsOneWidget);
        expect(find.text('Connection lost — reconnecting…'), findsOneWidget);

        await controller.close();
      },
    );

    testWidgets(
      '16.9a-connected: ConnectionStatusBanner is hidden when stream has data',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState());
        await tester.pump();

        expect(find.byKey(const Key('connection_status_banner')), findsNothing);

        await controller.close();
      },
    );

    testWidgets(
      '16.9b: AutoModePanel visible and ManualModePanel hidden when pump_mode==auto',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'auto'));
        await tester.pump();

        expect(find.byType(AutoModePanel), findsOneWidget);
        expect(find.byType(ManualModePanel), findsNothing);

        await controller.close();
      },
    );

    testWidgets(
      '16.9c: ManualModePanel visible and AutoModePanel hidden when pump_mode==manual',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'manual'));
        await tester.pump();

        expect(find.byType(ManualModePanel), findsOneWidget);
        expect(find.byType(AutoModePanel), findsNothing);

        await controller.close();
      },
    );

    testWidgets(
      '16.9d: sensor display updates reactively when stream emits new TowerState',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(moisture: 500, waterLevelLow: false));
        await tester.pump();

        expect(
          (tester.widget<Text>(find.byKey(const Key('moisture_value')))).data,
          equals('500'),
        );
        expect(
          (tester.widget<Text>(find.byKey(const Key('water_level_value')))).data,
          equals('Good'),
        );

        controller.add(makeTowerState(moisture: 3000, waterLevelLow: true));
        await tester.pump();

        expect(
          (tester.widget<Text>(find.byKey(const Key('moisture_value')))).data,
          equals('3000'),
        );
        expect(
          (tester.widget<Text>(find.byKey(const Key('water_level_value')))).data,
          equals('Low'),
        );

        await controller.close();
      },
    );

    testWidgets(
      '16.9e: PumpSwitchTile reflects pump_state changes from stream',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'manual', pumpState: false));
        await tester.pump();

        final switchFinder = find.byKey(const Key('pump_switch_tile'));
        expect(switchFinder, findsOneWidget);
        expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

        controller.add(makeTowerState(pumpMode: 'manual', pumpState: true));
        await tester.pump();

        expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

        await controller.close();
      },
    );

    testWidgets(
      '16.9f: dashboard switches panels when pump_mode changes in stream',
      (tester) async {
        final controller = StreamController<TowerState>();
        final harness = _makeRepoHarness();

        await tester.pumpWidget(buildDashboardApp(
          streamController: controller,
          repo: harness.repo,
        ));

        controller.add(makeTowerState(pumpMode: 'auto'));
        await tester.pump();
        expect(find.byType(AutoModePanel), findsOneWidget);
        expect(find.byType(ManualModePanel), findsNothing);

        controller.add(makeTowerState(pumpMode: 'manual'));
        await tester.pump();
        expect(find.byType(ManualModePanel), findsOneWidget);
        expect(find.byType(AutoModePanel), findsNothing);

        await controller.close();
      },
    );
  });
}
