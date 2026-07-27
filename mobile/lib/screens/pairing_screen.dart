/// Bluetooth pairing flow (spec 5.3): scan → pick device → connect+bond →
/// register bracelet on the backend (serial from device_info) → pair to the
/// selected baby → live values within seconds.
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/l10n.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});
  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  List<ScanResult> _results = [];
  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _results = [];
    });
    try {
      final results = await ref.read(bleServiceProvider).scan();
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = 'Scan failed: $e — check Bluetooth permissions.');
    } finally {
      setState(() => _scanning = false);
    }
  }

  Future<void> _connect(ScanResult result) async {
    final baby = ref.read(selectedBabyProvider) ??
        (ref.read(babiesProvider).value?.isNotEmpty == true
            ? ref.read(babiesProvider).value!.first
            : null);
    if (baby == null) {
      setState(() => _error = 'Register a baby first, then pair.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final ble = ref.read(bleServiceProvider);
      await ble.connect(result.device);

      // Serial comes from the device_info characteristic; fall back to BLE id.
      final serial = ble.deviceSerial.isNotEmpty
          ? ble.deviceSerial
          : result.device.remoteId.str;

      final repo = ref.read(braceletRepositoryProvider);
      // Register (or find existing) bracelet on the backend, then pair.
      int braceletId;
      try {
        final bracelet = await repo.register(serial, ble.firmwareVersion);
        braceletId = bracelet.id;
      } catch (_) {
        // Already registered → find it in the list.
        final all = await repo.list();
        braceletId = all.firstWhere((b) => b.serialNumber == serial).id;
      }
      await repo.pair(braceletId, baby.id);
      ref.read(connectedBraceletIdProvider.notifier).state = braceletId;
      ref.read(selectedBabyProvider.notifier).state = baby;
      ref.invalidate(braceletsProvider);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/live');
      }
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('pair_bracelet'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _scanning || _connecting ? null : _scan,
              icon: _scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_scanning ? l.t('scanning') : 'Scan for bracelets'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(_scanning
                        ? 'Looking for Health Service devices…'
                        : 'No devices yet. Tap Scan.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final r = _results[i];
                      final name = r.device.platformName.isEmpty
                          ? r.device.remoteId.str
                          : r.device.platformName;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.watch),
                          title: Text(name),
                          subtitle: Text('RSSI ${r.rssi} dBm'),
                          trailing: _connecting
                              ? const CircularProgressIndicator()
                              : const Icon(Icons.link),
                          onTap: _connecting ? null : () => _connect(r),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
