import 'package:firebase_database/firebase_database.dart';
import 'package:hydroponics_farm_management/models/tower_state.dart';

/// Repository that encapsulates all Firebase Realtime Database read/write
/// operations for a single hydroponic tower.
///
/// All control fields are written to `farms/farm_id_1/towers/tower_1`.
/// The [watchTower] stream maps incoming `onValue` events to typed
/// [TowerState] objects so callers never touch raw Firebase snapshots.
class TowerRepository {
  final DatabaseReference _ref;

  /// Creates a [TowerRepository] backed by [db].
  ///
  /// The internal [DatabaseReference] is pinned to the path
  /// `farms/farm_id_1/towers/tower_1`.
  TowerRepository(FirebaseDatabase db)
      : _ref = db.ref('farms/farm_id_1/towers/tower_1');

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns a live [Stream] of [TowerState] by mapping the Firebase
  /// `onValue` stream.  Each emission reflects the full tower snapshot at
  /// the time of the event.
  Stream<TowerState> watchTower() =>
      _ref.onValue.map((event) => TowerState.fromSnapshot(event.snapshot));

  // ---------------------------------------------------------------------------
  // Write — control fields
  // ---------------------------------------------------------------------------

  /// Writes [mode] (`'auto'` or `'manual'`) to `pump_mode`.
  ///
  /// Requirements: 11.2
  Future<void> setPumpMode(String mode) =>
      _ref.child('pump_mode').set(mode);

  /// Writes [on] to `pump_switch`.
  ///
  /// Requirements: 12.2
  Future<void> setPumpSwitch(bool on) =>
      _ref.child('pump_switch').set(on);

  /// Writes [speed] (0–255) to `pump_speed`.
  ///
  /// Requirements: 12.4
  Future<void> setPumpSpeed(int speed) =>
      _ref.child('pump_speed').set(speed);

  /// Atomically writes [onMin] to `interval_on_min` and [offMin] to
  /// `interval_off_min` using a single `update` call.
  ///
  /// Requirements: 13.2
  Future<void> setIntervals(int onMin, int offMin) =>
      _ref.update({'interval_on_min': onMin, 'interval_off_min': offMin});
}
