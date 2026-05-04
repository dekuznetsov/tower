import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydroponics_farm_management/providers/tower_providers.dart';

/// Displays a visible connection-lost banner when [connectionStatusProvider]
/// is false (stream loading or in error state).
///
/// Requirements: 9.4
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectionStatusProvider);

    if (isConnected) return const SizedBox.shrink();

    return Container(
      key: const Key('connection_status_banner'),
      width: double.infinity,
      color: Colors.red.shade700,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text(
            'Connection lost — reconnecting…',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
