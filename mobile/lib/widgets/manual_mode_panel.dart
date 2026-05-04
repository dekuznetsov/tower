import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydroponics_farm_management/models/tower_state.dart';
import 'package:hydroponics_farm_management/providers/tower_providers.dart';

/// Switch tile that reflects [TowerState.pumpState] and writes to
/// [pump_switch] via [TowerRepository.setPumpSwitch] when toggled.
///
/// Requirements: 12.1, 12.2, 12.5
class PumpSwitchTile extends ConsumerWidget {
  const PumpSwitchTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(towerStreamProvider);

    return asyncState.when(
      data: (state) => SwitchListTile(
        key: const Key('pump_switch_tile'),
        title: const Text('Pump'),
        subtitle: Text(state.pumpState ? 'Running' : 'Stopped'),
        value: state.pumpState,
        onChanged: (value) async {
          await ref.read(towerRepositoryProvider).setPumpSwitch(value);
        },
      ),
      loading: () => const SwitchListTile(
        key: Key('pump_switch_tile'),
        title: Text('Pump'),
        value: false,
        onChanged: null,
      ),
      error: (_, __) => const SwitchListTile(
        key: Key('pump_switch_tile'),
        title: Text('Pump'),
        value: false,
        onChanged: null,
      ),
    );
  }
}

/// Slider that maps 0.0–1.0 to 0%–100% display and 0–255 pump speed.
/// On change calls [TowerState.sliderToSpeed] and writes via
/// [TowerRepository.setPumpSpeed].
///
/// Requirements: 12.3, 12.4
class SpeedSlider extends ConsumerWidget {
  const SpeedSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(towerStreamProvider);

    return asyncState.when(
      data: (state) => _SpeedSliderContent(speedPercent: state.speedPercent),
      loading: () => const _SpeedSliderContent(speedPercent: 0.0),
      error: (_, __) => const _SpeedSliderContent(speedPercent: 0.0),
    );
  }
}

class _SpeedSliderContent extends ConsumerWidget {
  final double speedPercent;
  const _SpeedSliderContent({required this.speedPercent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayPercent = (speedPercent * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Speed', style: TextStyle(fontWeight: FontWeight.w500)),
            Text(
              key: const Key('speed_percent_label'),
              '$displayPercent%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(
          key: const Key('speed_slider'),
          value: speedPercent.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          label: '$displayPercent%',
          onChanged: (value) async {
            final speed = TowerState.sliderToSpeed(value);
            await ref.read(towerRepositoryProvider).setPumpSpeed(speed);
          },
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0%', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('100%', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

/// Panel shown when [pump_mode] is `'manual'`. Contains [PumpSwitchTile] and
/// [SpeedSlider] for direct pump control.
///
/// Requirements: 12.1, 12.2, 12.3, 12.4, 12.5
class ManualModePanel extends StatelessWidget {
  const ManualModePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('manual_mode_panel'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Mode Controls',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const PumpSwitchTile(),
            const SizedBox(height: 8),
            const SpeedSlider(),
          ],
        ),
      ),
    );
  }
}
