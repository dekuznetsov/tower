import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydroponics_farm_management/providers/tower_providers.dart';
import 'package:hydroponics_farm_management/utils/validate_interval.dart';

/// Text field for entering [interval_on_min].
/// Validates with [validateInterval]; on valid submit writes via
/// [TowerRepository.setIntervals]. Highlights in red on invalid input.
///
/// Requirements: 13.1, 13.2, 13.3, 13.4
class IntervalOnField extends ConsumerStatefulWidget {
  const IntervalOnField({super.key});

  @override
  ConsumerState<IntervalOnField> createState() => _IntervalOnFieldState();
}

class _IntervalOnFieldState extends ConsumerState<IntervalOnField> {
  final _controller = TextEditingController();
  String? _error;
  bool _initialised = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(int currentOffMin) async {
    final error = validateInterval(_controller.text);
    setState(() => _error = error);
    if (error != null) return;

    final onMin = int.parse(_controller.text.trim());
    try {
      await ref.read(towerRepositoryProvider).setIntervals(onMin, currentOffMin);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save interval — please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(towerStreamProvider);

    return asyncState.when(
      data: (state) {
        if (!_initialised) {
          _controller.text = '${state.intervalOnMin}';
          _initialised = true;
        }
        return _buildField(context, currentOffMin: state.intervalOffMin);
      },
      loading: () => _buildField(context, currentOffMin: 1),
      error: (_, __) => _buildField(context, currentOffMin: 1),
    );
  }

  Widget _buildField(BuildContext context, {required int currentOffMin}) {
    return TextField(
      key: const Key('interval_on_field'),
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-\d]'))],
      decoration: InputDecoration(
        labelText: 'Time On (min)',
        errorText: _error,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: _error != null ? Colors.red : Colors.grey,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: _error != null
                ? Colors.red
                : Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      onSubmitted: (_) => _submit(currentOffMin),
    );
  }
}

/// Text field for entering [interval_off_min].
/// Validates with [validateInterval]; on valid submit writes via
/// [TowerRepository.setIntervals]. Highlights in red on invalid input.
///
/// Requirements: 13.1, 13.2, 13.3, 13.4
class IntervalOffField extends ConsumerStatefulWidget {
  const IntervalOffField({super.key});

  @override
  ConsumerState<IntervalOffField> createState() => _IntervalOffFieldState();
}

class _IntervalOffFieldState extends ConsumerState<IntervalOffField> {
  final _controller = TextEditingController();
  String? _error;
  bool _initialised = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(int currentOnMin) async {
    final error = validateInterval(_controller.text);
    setState(() => _error = error);
    if (error != null) return;

    final offMin = int.parse(_controller.text.trim());
    try {
      await ref.read(towerRepositoryProvider).setIntervals(currentOnMin, offMin);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save interval — please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(towerStreamProvider);

    return asyncState.when(
      data: (state) {
        if (!_initialised) {
          _controller.text = '${state.intervalOffMin}';
          _initialised = true;
        }
        return _buildField(context, currentOnMin: state.intervalOnMin);
      },
      loading: () => _buildField(context, currentOnMin: 1),
      error: (_, __) => _buildField(context, currentOnMin: 1),
    );
  }

  Widget _buildField(BuildContext context, {required int currentOnMin}) {
    return TextField(
      key: const Key('interval_off_field'),
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-\d]'))],
      decoration: InputDecoration(
        labelText: 'Time Off (min)',
        errorText: _error,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: _error != null ? Colors.red : Colors.grey,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: _error != null
                ? Colors.red
                : Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      onSubmitted: (_) => _submit(currentOnMin),
    );
  }
}

/// Panel shown when [pump_mode] is `'auto'`. Contains [IntervalOnField] and
/// [IntervalOffField] for configuring the automatic pump cycle.
///
/// Requirements: 13.1, 13.2, 13.3, 13.4
class AutoModePanel extends StatelessWidget {
  const AutoModePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('auto_mode_panel'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auto Mode Settings',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const IntervalOnField(),
            const SizedBox(height: 12),
            const IntervalOffField(),
          ],
        ),
      ),
    );
  }
}
