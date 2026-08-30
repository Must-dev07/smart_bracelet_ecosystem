// Bracelet information: nickname, serial, firmware, battery, last sync,
// pairing state. Two distinct "rename" actions exist and are labelled
// accordingly: a persisted app-level rename (always available, any role
// with access) and a BLE device-command rename (only when physically
// connected — writes the name to the bracelet's own firmware).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/vitals_source.dart';
import '../widgets/common_widgets.dart';

class BraceletInfoScreen extends ConsumerWidget {
  const BraceletInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bracelets = ref.watch(braceletsProvider);
    final ble = ref.read(bleServiceProvider);
    final status = ref.watch(bleStatusProvider).value ?? BleStatus.disconnected;
    final connectedId = ref.watch(connectedBraceletIdProvider);
    final role = ref.watch(authProvider).user?.role;
    final canPair = role == 'parent';

    return Scaffold(
      appBar: AppBar(title: const Text('Bracelets')),
      body: bracelets.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.watch_off_outlined, size: 64),
                      const SizedBox(height: 12),
                      const Text('No bracelet registered.'),
                      if (canPair) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/pairing'),
                          icon: const Icon(Icons.bluetooth),
                          label: const Text('Pair a bracelet'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(braceletsProvider),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ConnectionStatusChip(status: status),
                    const SizedBox(height: 12),
                    for (final b in list)
                      _BraceletCard(
                        bracelet: b,
                        isBleConnected:
                            b.id == connectedId && status == BleStatus.connected,
                        ble: ble,
                      ),
                  ],
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Could not load bracelets (offline?).')),
      ),
      floatingActionButton: canPair
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).pushNamed('/pairing'),
              icon: const Icon(Icons.bluetooth),
              label: const Text('Pair bracelet'),
            )
          : null,
    );
  }
}

class _BraceletCard extends ConsumerWidget {
  final Bracelet bracelet;
  final bool isBleConnected;
  final VitalsSource ble;

  const _BraceletCard({
    required this.bracelet,
    required this.isBleConnected,
    required this.ble,
  });

  Future<void> _renamePersisted(BuildContext context, WidgetRef ref) async {
    final name = await _prompt(context, 'Rename bracelet', bracelet.nickname);
    if (name == null || name.isEmpty) return;
    await ref.read(braceletRepositoryProvider).rename(bracelet.id, name);
    ref.invalidate(braceletsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = bracelet;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.watch, color: isBleConnected ? Colors.green : null),
            title: Text(b.displayName),
            subtitle: Text(
              [
                'Firmware ${b.firmwareVersion.isEmpty ? "?" : b.firmwareVersion}',
                b.status,
                if (b.batteryLevel != null)
                  '🔋 ${b.batteryLevel!.toStringAsFixed(0)}%',
                if (b.babyName != null && b.babyName!.isNotEmpty)
                  'paired: ${b.babyName}',
              ].join(' · '),
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.sync, size: 18),
            title: Text(
              b.lastSeenAt == null
                  ? 'Never synced'
                  : 'Last sync: ${b.lastSeenAt!.toLocal().toString().split('.').first}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.start,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.drive_file_rename_outline),
                label: const Text('Rename'),
                onPressed: () => _renamePersisted(context, ref),
              ),
              if (isBleConnected) ...[
                TextButton.icon(
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('Rename on device'),
                  onPressed: () async {
                    final name = await _prompt(context, 'New device name', '');
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
              TextButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Pairing history'),
                onPressed: () {
                  ref.read(selectedBraceletProvider.notifier).state = b;
                  Navigator.of(context).pushNamed('/bracelet-pairing-history');
                },
              ),
              if (b.babyId != null)
                TextButton.icon(
                  icon: const Icon(Icons.link_off),
                  label: const Text('Unpair'),
                  onPressed: () async {
                    await ref.read(braceletRepositoryProvider).unpair(b.id);
                    ref.invalidate(braceletsProvider);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<String?> _prompt(BuildContext context, String title, String initial) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('OK')),
      ],
    ),
  );
}
