/// History: paginated raw measurements from the backend, falling back to the
/// local SQLite cache when offline (offline-first requirement).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/l10n.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Measurement> _items = [];
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    final baby = ref.read(selectedBabyProvider);
    try {
      if (baby == null) throw StateError('no baby');
      final items =
          await ref.read(measurementRepositoryProvider).history(baby.id);
      setState(() => _items = items);
    } catch (_) {
      // Offline fallback: local SQLite rows.
      final rows = await ref.read(localDbProvider).recentMeasurements();
      setState(() {
        _offline = true;
        _items = rows
            .map((r) => Measurement(
                  braceletId: r['bracelet_id'] as int,
                  heartRate: r['heart_rate'] as double?,
                  temperature: r['temperature'] as double?,
                  spo2: r['spo2'] as double?,
                  battery: r['battery'] as double?,
                  skinContact: (r['skin_contact'] as int) == 1,
                  recordedAt: DateTime.parse(r['recorded_at'] as String),
                  synced: (r['synced'] as int) == 1,
                ))
            .toList();
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('history')), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_offline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.amber.withOpacity(.2),
                    child: const Text(
                        'Offline — showing locally stored readings.',
                        textAlign: TextAlign.center),
                  ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('No measurements yet.'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final m = _items[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                m.synced ? Icons.cloud_done : Icons.cloud_upload,
                                color: m.synced ? Colors.green : Colors.grey,
                              ),
                              title: Text(
                                  '❤ ${m.heartRate?.toStringAsFixed(0) ?? '--'} bpm · '
                                  '🌡 ${m.temperature?.toStringAsFixed(1) ?? '--'} °C · '
                                  'SpO₂ ${m.spo2?.toStringAsFixed(0) ?? '--'} %'),
                              subtitle: Text(m.recordedAt
                                  .toLocal()
                                  .toString()
                                  .split('.')
                                  .first),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
