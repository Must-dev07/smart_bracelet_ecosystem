// Live Monitoring: subscribes to the BLE vitals stream, shows real-time
// tiles, persists every reading to SQLite (offline-first), reports BLE loss
// to the backend, and shows the reconnection status prominently.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../providers/providers.dart';
import '../services/vitals_source.dart';
import '../utils/l10n.dart';
import '../widgets/common_widgets.dart';

class LiveMonitoringScreen extends ConsumerStatefulWidget {
  const LiveMonitoringScreen({super.key});
  @override
  ConsumerState<LiveMonitoringScreen> createState() =>
      _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends ConsumerState<LiveMonitoringScreen> {
  StreamSubscription<LiveVitals>? _persistSub;
  StreamSubscription<BleStatus>? _statusSub;
  Timer? _ticker;
  DateTime _lastSaved = DateTime.fromMillisecondsSinceEpoch(0);
  BleStatus? _prevStatus;

  @override
  void initState() {
    super.initState();
    final ble = ref.read(bleServiceProvider);
    final repo = ref.read(measurementRepositoryProvider);
    final sync = ref.read(syncServiceProvider);
    sync.start();

    // Persist at most one sample per 5 s to SQLite (device notifies faster).
    _persistSub = ble.vitals.listen((v) {
      final braceletId = ref.read(connectedBraceletIdProvider);
      if (braceletId == null) return;
      if (DateTime.now().difference(_lastSaved).inSeconds >= 5) {
        _lastSaved = DateTime.now();
        repo.saveLocal(v.toMeasurement(braceletId));
      }
    });

    // Report BLE link loss to the backend once per drop.
    _statusSub = ble.status.listen((s) {
      final braceletId = ref.read(connectedBraceletIdProvider);
      if (_prevStatus == BleStatus.connected &&
          s == BleStatus.reconnecting &&
          braceletId != null) {
        sync.reportBleLost(braceletId);
      }
      _prevStatus = s;
    });

    // Redraw once a second so "connected for Xs" / "last packet Xs ago" /
    // the freshness indicator stay accurate even when no new packet arrives.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _persistSub?.cancel();
    _statusSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vitals = ref.watch(liveVitalsProvider).value;
    final status = ref.watch(bleStatusProvider).value ?? BleStatus.disconnected;
    final baby = ref.watch(selectedBabyProvider);
    final units = ref.watch(unitsProvider);
    final l = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(baby == null ? l.t('live') : '${l.t('live')} — ${baby.name}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: ConnectionStatusChip(status: status)),
          ),
        ],
      ),
      body: status == BleStatus.disconnected
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth_disabled, size: 72),
                  const SizedBox(height: 12),
                  const Text('No bracelet connected.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/pairing'),
                    icon: const Icon(Icons.bluetooth_searching),
                    label: Text(l.t('pair_bracelet')),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (status == BleStatus.reconnecting)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              '${l.t('reconnecting')} Readings are stored locally and will sync automatically.')),
                    ]),
                  ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    VitalTile(
                      icon: Icons.favorite,
                      label: l.t('heart_rate'),
                      value: vitals?.heartRate?.toStringAsFixed(0) ?? '--',
                      unit: 'bpm',
                      color: AppColors.critical,
                    ),
                    VitalTile(
                      icon: Icons.thermostat,
                      label: l.t('temperature'),
                      value: vitals?.temperature == null
                          ? '--'
                          : units == 'imperial'
                              ? (vitals!.temperature! * 9 / 5 + 32)
                                  .toStringAsFixed(1)
                              : vitals!.temperature!.toStringAsFixed(1),
                      unit: units == 'imperial' ? '°F' : '°C',
                      color: AppColors.warning,
                    ),
                    VitalTile(
                      icon: Icons.air,
                      label: l.t('spo2'),
                      value: vitals?.spo2?.toStringAsFixed(0) ?? '--',
                      unit: '%',
                      color: AppColors.info,
                    ),
                    VitalTile(
                      icon: Icons.battery_5_bar,
                      label: l.t('battery'),
                      value: vitals?.battery?.toStringAsFixed(0) ?? '--',
                      unit: '%',
                      color: AppColors.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions_run),
                    title: Text(l.t('movement')),
                    subtitle: Text(vitals?.movement == null
                        ? '--'
                        : 'magnitude ${(vitals!.movement!['magnitude'] as num?)?.toStringAsFixed(2) ?? '--'}'),
                    trailing: Icon(
                      (vitals?.skinContact ?? true)
                          ? Icons.check_circle
                          : Icons.warning,
                      color: (vitals?.skinContact ?? true)
                          ? AppColors.accent
                          : AppColors.critical,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ConnectionDetailsCard(ble: ref.watch(bleServiceProvider)),
                const DisclaimerBanner(),
              ],
            ),
    );
  }
}

/// Section 6 telemetry beyond the vitals themselves: how fresh is the data,
/// how fast are packets arriving, how long has this connection been up, and
/// how many times has it had to reconnect. Rebuilt every second by the
/// screen's ticker so relative times ("3s ago") stay accurate between packets.
class _ConnectionDetailsCard extends StatelessWidget {
  final VitalsSource ble;
  const _ConnectionDetailsCard({required this.ble});

  @override
  Widget build(BuildContext context) {
    final lastPacket = ble.lastPacketAt;
    final freshnessSeconds =
        lastPacket == null ? null : DateTime.now().difference(lastPacket).inSeconds;
    final isFresh = freshnessSeconds != null && freshnessSeconds <= 10;
    final connectedSince = ble.connectedSince;
    final duration =
        connectedSince == null ? null : DateTime.now().difference(connectedSince);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFresh ? Icons.sensors : Icons.sensors_off,
                  size: 18,
                  color: isFresh ? AppColors.accent : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text('Connection details',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Data freshness',
              value: freshnessSeconds == null
                  ? 'No packets yet'
                  : (isFresh ? '${freshnessSeconds}s ago (live)' : '${freshnessSeconds}s ago (stale)'),
              warn: !isFresh,
            ),
            _DetailRow(
              label: 'Packet rate',
              value: '${ble.packetsPerMinute} / min',
            ),
            _DetailRow(
              label: 'Connection duration',
              value: duration == null ? '--' : _formatDuration(duration),
            ),
            _DetailRow(
              label: 'Reconnection attempts',
              value: '${ble.reconnectAttempts}',
              warn: ble.reconnectAttempts > 0,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  const _DetailRow({required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: warn ? AppColors.warning : null,
            ),
          ),
        ],
      ),
    );
  }
}
