import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydroponics_farm_management/models/tower_state.dart';
import 'package:hydroponics_farm_management/repositories/tower_repository.dart';

/// Provides a [TowerRepository] backed by [FirebaseDatabase.instance].
///
/// Requirements: 9.2
final towerRepositoryProvider = Provider<TowerRepository>((ref) {
  return TowerRepository(FirebaseDatabase.instance);
});

/// Provides a live stream of [TowerState] by delegating to
/// [towerRepositoryProvider]'s [TowerRepository.watchTower] method.
///
/// Requirements: 9.2
final towerStreamProvider = StreamProvider<TowerState>((ref) {
  return ref.watch(towerRepositoryProvider).watchTower();
});

/// Derives a simple connection-status boolean from [towerStreamProvider].
///
/// Returns `true` once the stream has emitted at least one value.
/// Returns `false` while loading or in an error state (drives ConnectionStatusBanner).
///
/// Requirements: 9.4
final connectionStatusProvider = Provider<bool>((ref) {
  return ref.watch(towerStreamProvider).hasValue;
});
