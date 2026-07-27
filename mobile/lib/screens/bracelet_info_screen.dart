/// Bracelet information: serial, firmware, battery, pairing state; commands
/// (rename / reset) via the BLE command characteristic; unpair action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/ble_service.dart';
import '../widgets/common_widgets.dart';

class BraceletInfoScreen extends ConsumerWidget {
  const BraceletInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bracelets = ref.watch(braceletsProvider);
    final ble = ref.read(bleServiceProvider);
    final status = ref.watch(bleStatusProvider).value ?? BleStatus.disconnected;
    final connectedId = ref.watch(connectedBraceletIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bracelet information')),
      body: bracelets.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No bracelet registered.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ConnectionStatusChip(status: status),
                  const SizedBox(height: 12),
                  for (final b in list)
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.watch,
                                color: b.id == connectedId
                                    ? Colors.green
                                    : null),
                            title: Text(b.serialNumber),
                            subtitle: Text(
                                'Firmware ${b.firmwareVersion.isEmpty ? "?" : b.firmwareVersion}'
                                ' · ${b.status}'
                                '${b.batteryLevel != null ? " · 🔋 ${b.batteryLevel!.toStringAsFixed(0)}%" : ""}'),
                          ),
                          OverflowBar(
                            children: [
                              if (b.id == connectedId &&
                                  status == BleStatus.connected) ...[
                                TextButton.icon(
                                  icon: const Icon(Icons.drive_file_rename_outline),
                                  label: const Text('Rename'),
                                  onPressed: () async {
                                    final name = await _prompt(context, 'New name');
                                    if (name != null && name.isNotEmpty) {
                                      await ble.sendCommand('rename:$name');
                                    }
                                  },
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.restart_alt),
                                  label: const Text('Reset'),
                                  onPressed: () => ble.sendCommand('reset'),
                                ),
                              ],
                              if (b.babyId != null)
                                TextButton.icon(
                                  icon: const Icon(Icons.link_off),
                                  label: const Text('Unpair'),
                                  onPressed: () async {
                                    await ref
                                        .read(braceletRepositoryProvider)
                                        .unpair(b.id);
                                    ref.invalidate(braceletsProvider);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Could not load bracelets (offline?).')),
      ),
    );
  }

  Future<String?> _prompt(BuildContext context, String title) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
  }
}
