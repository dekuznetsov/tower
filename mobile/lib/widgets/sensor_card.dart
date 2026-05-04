import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydroponics_farm_management/providers/tower_providers.dart';

/// Displays the current moisture integer value from [TowerState.moisture].
/// Updates reactively from [towerStreamProvider].
///
/// Requirements: 10.1, 10.3
class MoistureDisplay extends ConsumerWidget {
  const MoistureDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(towerStreamProvider);

    return asyncState.when(
      data: (state) => _MoistureRow(moisture: state.moisture),
      loading: () => const _MoistureRow(moisture: 0),
      error: (_, __) => const _MoistureRow(moisture: 0),
    );
  }
}

class _MoistureRow extends StatelessWidget {
  final int moisture;
  const _MoistureRow({required this.moisture});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.water_drop_outlined, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 8),
        const Text('Moisture:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        Text(
          key: const Key('moisture_value'),
          '$moisture',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}

/// Displays the water level status string from [TowerState.waterLevelDisplay].
/// Shows `'Good'` or `'Low'`. Updates reactively from [towerStreamProvider].
///
/// Requirements: 10.2, 10.3
class WaterLevelDisplay extends ConsumerWidget {
  const WaterLevelDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(towerStreamProvider);

    return asyncState.when(
      data: (state) => _WaterLevelRow(display: state.waterLevelDisplay),
      loading: () => const _WaterLevelRow(display: 'Good'),
      error: (_, __) => const _WaterLevelRow(display: 'Good'),
    );
  }
}

class _WaterLevelRow extends StatelessWidget {
  final String display;
  const _WaterLevelRow({required this.display});

  @override
  Widget build(BuildContext context) {
    final isLow = display == 'Low';
    return Row(
      children: [
        Icon(
          isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          size: 20,
          color: isLow ? Colors.orange : Colors.green,
        ),
        const SizedBox(width: 8),
        const Text('Water Level:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        Text(
          key: const Key('water_level_value'),
          display,
          style: TextStyle(
            fontSize: 16,
            color: isLow ? Colors.orange : Colors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Card widget that groups [MoistureDisplay] and [WaterLevelDisplay].
///
/// Requirements: 10.1, 10.2, 10.3
class SensorCard extends StatelessWidget {
  const SensorCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('sensor_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sensors',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const MoistureDisplay(),
            const SizedBox(height: 8),
            const WaterLevelDisplay(),
          ],
        ),
      ),
    );
  }
}
