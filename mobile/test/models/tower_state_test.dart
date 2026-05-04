// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponics_farm_management/models/tower_state.dart';

// ---------------------------------------------------------------------------
// Property-test helpers
// ---------------------------------------------------------------------------

/// Runs [body] [numRuns] times with a seeded [Random] instance.
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

TowerState randomTowerState(Random rng) {
  return TowerState(
    pumpSpeed: rng.nextInt(256),
    pumpMode: rng.nextBool() ? 'auto' : 'manual',
    pumpState: rng.nextBool(),
    pumpSwitch: rng.nextBool(),
    intervalOnMin: rng.nextInt(1440) + 1,
    intervalOffMin: rng.nextInt(1440) + 1,
    moisture: rng.nextInt(4096),
    waterLevelLow: rng.nextBool(),
  );
}

double randomDouble(Random rng, double min, double max) {
  return min + rng.nextDouble() * (max - min);
}

TowerState makeTowerState({
  int pumpSpeed = 0,
  String pumpMode = 'manual',
  bool pumpState = false,
  bool pumpSwitch = false,
  int intervalOnMin = 1,
  int intervalOffMin = 1,
  int moisture = 0,
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

void main() {
  group('Property Tests', () {
    // Feature: hydroponics-farm-management, Property 1: TowerState Serialization Round-Trip
    // Validates: Requirements 1.2, 1.3
    test(
      'Property 1: TowerState serialization round-trip — '
      'fromMap(toMap(state)) equals original state',
      () {
        forAll(200, (rng, _) {
          final original = randomTowerState(rng);
          final roundTripped = TowerState.fromMap(original.toMap());
          expect(
            roundTripped,
            equals(original),
            reason: 'Round-trip failed for: $original',
          );
        });
      },
    );

    // Feature: hydroponics-farm-management, Property 12: Water Level Display Maps Boolean to String
    // Validates: Requirements 10.2
    test(
      'Property 12: waterLevelDisplay returns "Low" for true and "Good" for false',
      () {
        for (final waterLevelLow in [true, false]) {
          final state = makeTowerState(waterLevelLow: waterLevelLow);
          expect(
            state.waterLevelDisplay,
            equals(waterLevelLow ? 'Low' : 'Good'),
          );
        }
        forAll(200, (rng, _) {
          final wll = rng.nextBool();
          final state = makeTowerState(waterLevelLow: wll);
          expect(state.waterLevelDisplay, equals(wll ? 'Low' : 'Good'));
        });
      },
    );

    // Feature: hydroponics-farm-management, Property 13: Speed Slider Mapping Is Monotonic and Bounded
    // Validates: Requirements 12.4
    test(
      'Property 13a: sliderToSpeed result is always in [0, 255] for p ∈ [0.0, 1.0]',
      () {
        forAll(500, (rng, _) {
          final p = randomDouble(rng, 0.0, 1.0);
          final result = TowerState.sliderToSpeed(p);
          expect(result, inInclusiveRange(0, 255));
        });
      },
    );

    test(
      'Property 13b: sliderToSpeed is monotonically non-decreasing',
      () {
        forAll(500, (rng, _) {
          final a = randomDouble(rng, 0.0, 1.0);
          final b = randomDouble(rng, 0.0, 1.0);
          final p1 = min(a, b);
          final p2 = max(a, b);
          final s1 = TowerState.sliderToSpeed(p1);
          final s2 = TowerState.sliderToSpeed(p2);
          expect(s1, lessThanOrEqualTo(s2));
        });
      },
    );
  });

  group('TowerState.fromMap', () {
    test('parses a complete data map correctly', () {
      final data = {
        'pump_speed': 128,
        'pump_mode': 'auto',
        'pump_state': true,
        'pump_switch': false,
        'interval_on_min': 5,
        'interval_off_min': 10,
        'sensors': {
          'moisture': 2048,
          'water_level_low': true,
        },
      };
      final state = TowerState.fromMap(data);
      expect(state.pumpSpeed, equals(128));
      expect(state.pumpMode, equals('auto'));
      expect(state.pumpState, isTrue);
      expect(state.pumpSwitch, isFalse);
      expect(state.intervalOnMin, equals(5));
      expect(state.intervalOffMin, equals(10));
      expect(state.moisture, equals(2048));
      expect(state.waterLevelLow, isTrue);
    });

    test('applies defaults for all missing fields', () {
      final state = TowerState.fromMap({});
      expect(state.pumpSpeed, equals(0));
      expect(state.pumpMode, equals('manual'));
      expect(state.pumpState, isFalse);
      expect(state.pumpSwitch, isFalse);
      expect(state.intervalOnMin, equals(1));
      expect(state.intervalOffMin, equals(1));
      expect(state.moisture, equals(0));
      expect(state.waterLevelLow, isFalse);
    });

    test('applies sensor defaults when sensors node is absent', () {
      final data = {
        'pump_speed': 100,
        'pump_mode': 'manual',
        'pump_state': false,
        'pump_switch': true,
        'interval_on_min': 3,
        'interval_off_min': 7,
      };
      final state = TowerState.fromMap(data);
      expect(state.moisture, equals(0));
      expect(state.waterLevelLow, isFalse);
      expect(state.pumpSpeed, equals(100));
    });

    test('applies sensor defaults when sensors node is an empty map', () {
      final data = {
        'pump_speed': 50,
        'pump_mode': 'auto',
        'sensors': <String, dynamic>{},
      };
      final state = TowerState.fromMap(data);
      expect(state.moisture, equals(0));
      expect(state.waterLevelLow, isFalse);
    });
  });

  group('TowerState.waterLevelDisplay', () {
    test('returns "Good" when waterLevelLow is false', () {
      expect(makeTowerState(waterLevelLow: false).waterLevelDisplay, equals('Good'));
    });

    test('returns "Low" when waterLevelLow is true', () {
      expect(makeTowerState(waterLevelLow: true).waterLevelDisplay, equals('Low'));
    });
  });

  group('TowerState.sliderToSpeed', () {
    test('returns 0 for slider position 0.0', () {
      expect(TowerState.sliderToSpeed(0.0), equals(0));
    });

    test('returns 128 for slider position 0.5', () {
      expect(TowerState.sliderToSpeed(0.5), equals(128));
    });

    test('returns 255 for slider position 1.0', () {
      expect(TowerState.sliderToSpeed(1.0), equals(255));
    });
  });

  group('TowerState.speedPercent', () {
    test('returns 0.0 for pumpSpeed 0', () {
      expect(makeTowerState(pumpSpeed: 0).speedPercent, equals(0.0));
    });

    test('returns approximately 128/255 for pumpSpeed 128', () {
      expect(makeTowerState(pumpSpeed: 128).speedPercent, closeTo(128 / 255.0, 1e-9));
    });

    test('returns 1.0 for pumpSpeed 255', () {
      expect(makeTowerState(pumpSpeed: 255).speedPercent, equals(1.0));
    });
  });

  group('TowerState equality', () {
    test('two identical TowerState instances are equal', () {
      final a = makeTowerState(pumpSpeed: 100, pumpMode: 'auto');
      final b = makeTowerState(pumpSpeed: 100, pumpMode: 'auto');
      expect(a, equals(b));
    });

    test('two TowerState instances with different fields are not equal', () {
      final a = makeTowerState(pumpSpeed: 100);
      final b = makeTowerState(pumpSpeed: 200);
      expect(a, isNot(equals(b)));
    });
  });
}
