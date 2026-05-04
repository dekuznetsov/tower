import 'package:firebase_database/firebase_database.dart';

/// Data model representing the full state of a single hydroponic tower,
/// as stored in Firebase Realtime Database under
/// `farms/farm_id_1/towers/tower_1`.
class TowerState {
  final int pumpSpeed; // 0–255
  final String pumpMode; // 'auto' | 'manual'
  final bool pumpState; // actual pump on/off
  final bool pumpSwitch; // operator intent (manual mode)
  final int intervalOnMin;
  final int intervalOffMin;
  final int moisture; // ADC raw value 0–4095
  final bool waterLevelLow;

  const TowerState({
    required this.pumpSpeed,
    required this.pumpMode,
    required this.pumpState,
    required this.pumpSwitch,
    required this.intervalOnMin,
    required this.intervalOffMin,
    required this.moisture,
    required this.waterLevelLow,
  });

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  /// Parses a [DataSnapshot] from Firebase into a [TowerState].
  /// Delegates to [fromMap] so the parsing logic is testable without Firebase.
  factory TowerState.fromSnapshot(DataSnapshot snapshot) {
    final raw = Map<String, dynamic>.from(snapshot.value as Map);
    return TowerState.fromMap(raw);
  }

  /// Parses a plain [Map] (matching the Firebase schema) into a [TowerState].
  /// All fields use null-coalescing defaults so the app never crashes on
  /// partial data.
  factory TowerState.fromMap(Map<String, dynamic> data) {
    final sensors = data['sensors'] != null
        ? Map<String, dynamic>.from(data['sensors'] as Map)
        : <String, dynamic>{};

    return TowerState(
      pumpSpeed: (data['pump_speed'] as int?) ?? 0,
      pumpMode: (data['pump_mode'] as String?) ?? 'manual',
      pumpState: (data['pump_state'] as bool?) ?? false,
      pumpSwitch: (data['pump_switch'] as bool?) ?? false,
      intervalOnMin: (data['interval_on_min'] as int?) ?? 1,
      intervalOffMin: (data['interval_off_min'] as int?) ?? 1,
      moisture: (sensors['moisture'] as int?) ?? 0,
      waterLevelLow: (sensors['water_level_low'] as bool?) ?? false,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Serialises this [TowerState] to a [Map] that matches the Firebase schema,
  /// including the nested `sensors` key.  Used for test round-trips.
  Map<String, dynamic> toMap() {
    return {
      'pump_speed': pumpSpeed,
      'pump_mode': pumpMode,
      'pump_state': pumpState,
      'pump_switch': pumpSwitch,
      'interval_on_min': intervalOnMin,
      'interval_off_min': intervalOffMin,
      'sensors': {
        'moisture': moisture,
        'water_level_low': waterLevelLow,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Computed properties
  // ---------------------------------------------------------------------------

  /// Maps [pumpSpeed] (0–255) to a 0.0–1.0 slider value.
  double get speedPercent => pumpSpeed / 255.0;

  /// Maps a 0.0–1.0 slider percentage to an integer in the range 0–255.
  static int sliderToSpeed(double percent) =>
      (percent * 255).round().clamp(0, 255);

  /// Returns `'Low'` when [waterLevelLow] is `true`, otherwise `'Good'`.
  String get waterLevelDisplay => waterLevelLow ? 'Low' : 'Good';

  // ---------------------------------------------------------------------------
  // Equality & hashing
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TowerState &&
        other.pumpSpeed == pumpSpeed &&
        other.pumpMode == pumpMode &&
        other.pumpState == pumpState &&
        other.pumpSwitch == pumpSwitch &&
        other.intervalOnMin == intervalOnMin &&
        other.intervalOffMin == intervalOffMin &&
        other.moisture == moisture &&
        other.waterLevelLow == waterLevelLow;
  }

  @override
  int get hashCode => Object.hash(
        pumpSpeed,
        pumpMode,
        pumpState,
        pumpSwitch,
        intervalOnMin,
        intervalOffMin,
        moisture,
        waterLevelLow,
      );

  @override
  String toString() => 'TowerState('
      'pumpSpeed: $pumpSpeed, '
      'pumpMode: $pumpMode, '
      'pumpState: $pumpState, '
      'pumpSwitch: $pumpSwitch, '
      'intervalOnMin: $intervalOnMin, '
      'intervalOffMin: $intervalOffMin, '
      'moisture: $moisture, '
      'waterLevelLow: $waterLevelLow)';
}
