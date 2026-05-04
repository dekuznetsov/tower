import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydroponics_farm_management/providers/tower_providers.dart';
import 'package:hydroponics_farm_management/widgets/auto_mode_panel.dart';
import 'package:hydroponics_farm_management/widgets/connection_status_banner.dart';
import 'package:hydroponics_farm_management/widgets/manual_mode_panel.dart';
import 'package:hydroponics_farm_management/widgets/mode_switch_tile.dart';
import 'package:hydroponics_farm_management/widgets/sensor_card.dart';

/// Root dashboard widget for the hydroponics tower.
///
/// Watches [towerStreamProvider] and composes:
/// - [ConnectionStatusBanner] — always present; visible only when disconnected
/// - [SensorCard] — moisture and water level readings
/// - [ModeSwitchTile] — toggle between auto and manual mode
/// - [AutoModePanel] — shown when pump_mode == 'auto'
/// - [ManualModePanel] — shown when pump_mode == 'manual'
///
/// Requirements: 9.3, 11.3
class TowerDashboard extends ConsumerWidget {
  const TowerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(towerStreamProvider);

    final isAuto = asyncState.whenOrNull(
          data: (state) => state.pumpMode == 'auto',
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydroponics Tower'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          const ConnectionStatusBanner(),
          Expanded(
            child: ListView(
              children: [
                const SensorCard(),
                const ModeSwitchTile(),
                if (isAuto) const AutoModePanel() else const ManualModePanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
