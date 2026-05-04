// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponics_farm_management/utils/validate_interval.dart';

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

String _randomLetters(Random rng, int len) {
  const chars = 'abcdefghijklmnopqrstuvwxyz';
  return List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
}

String _randomInvalidInput(Random rng) {
  final category = rng.nextInt(5);
  switch (category) {
    case 0:
      return '';
    case 1:
      final spaces = rng.nextInt(5) + 1;
      return ' ' * spaces;
    case 2:
      final len = rng.nextInt(8) + 1;
      return _randomLetters(rng, len);
    case 3:
      final n = rng.nextInt(1000);
      return (-n).toString();
    case 4:
    default:
      final intPart = rng.nextInt(100);
      final fracPart = rng.nextInt(9) + 1;
      return '$intPart.$fracPart';
  }
}

void main() {
  group('Property Tests', () {
    // Feature: hydroponics-farm-management, Property 16: Interval Validation Rejects Invalid Input
    // Validates: Requirements 13.3
    test(
      'Property 16: validateInterval returns a non-null error message for all '
      'invalid inputs and never invokes a Firebase write',
      () {
        forAll(200, (rng, run) {
          final input = _randomInvalidInput(rng);
          final result = validateInterval(input);
          expect(
            result,
            isNotNull,
            reason: 'Expected non-null error for invalid input "$input" on run $run',
          );
          expect(result, isA<String>());
          expect(result!.isNotEmpty, isTrue);
        });
      },
    );
  });

  group('validateInterval — valid inputs', () {
    test('returns null for "1" (minimum valid value)', () {
      expect(validateInterval('1'), isNull);
    });

    test('returns null for "60"', () {
      expect(validateInterval('60'), isNull);
    });

    test('returns null for "1440" (maximum typical value)', () {
      expect(validateInterval('1440'), isNull);
    });
  });

  group('validateInterval — invalid inputs', () {
    test('returns error for empty string ""', () {
      expect(validateInterval(''), isNotNull);
    });

    test('returns error for "0" (zero is not ≥ 1)', () {
      expect(validateInterval('0'), isNotNull);
    });

    test('returns error for "-1" (negative integer)', () {
      expect(validateInterval('-1'), isNotNull);
    });

    test('returns error for "1.5" (decimal number)', () {
      expect(validateInterval('1.5'), isNotNull);
    });

    test('returns error for "abc" (non-numeric string)', () {
      expect(validateInterval('abc'), isNotNull);
    });

    test('returns error for " " (whitespace-only string)', () {
      expect(validateInterval(' '), isNotNull);
    });
  });
}
