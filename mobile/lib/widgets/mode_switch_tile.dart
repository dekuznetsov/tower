import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydroponics_farm_management/providers/tower_providers.dart';

/// A switch tile that reflects [TowerState.pumpMode] and writes the opposite
/// mode to Firebase via [TowerRepository.setPumpMode] when toggled.
///
/// Switch ON  → pump_mode == 'auto'
/// Switch OFF → pump_mode == 'manual'
///
/// Requirements: 11.1, 11.2
class ModeSwitchTile extends ConsumerWidget {
  const ModeSwitchTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(towerStreamProvider);

    return asyncState.when(
      data: (state) {
        final isAuto = state.pumpMode == 'auto';
        return SwitchListTile(
          key: const Key('mode_switch_tile'),
          title: const Text('Auto Mode'),
          subtitle: Text(isAuto ? 'Pump cycles automatically' : 'Manual control active'),
          value: isAuto,
          onChanged: (value) async {
            final repo = ref.read(towerRepositoryProvider);
            final newMode = value ? 'auto' : 'manual';
            await repo.setPumpMode(newMode);
          },
        );
      },
      loading: () => const SwitchListTile(
        key: Key('mode_switch_tile'),
        title: Text('Auto Mode'),
        value: false,
        onChanged: null,
      ),
      error: (_, __) => const SwitchListTile(
        key: Key('mode_switch_tile'),
        title: Text('Auto Mode'),
        value: false,
        onChanged: null,
      ),
    );
  }
}
