/// Alerts list with active/resolved filter; every row carries severity badge.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/l10n.dart';
import '../widgets/common_widgets.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String? _status = 'active';

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertsProvider(_status));
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('alerts'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String?>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('Active')),
                ButtonSegment(value: 'resolved', label: Text('Resolved')),
                ButtonSegment(value: null, label: Text('All')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: DisclaimerBanner(),
          ),
          Expanded(
            child: alerts.when(
              data: (list) => list.isEmpty
                  ? const Center(child: Text('No alerts — all readings normal.'))
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(alertsProvider),
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final a = list[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: SeverityBadge(severity: a.severity),
                              title: Text(a.type.replaceAll('_', ' ')),
                              subtitle: Text(
                                  '${a.babyName} · ${a.triggeredAt.toLocal().toString().split('.').first}'),
                              trailing: a.isActive
                                  ? const Icon(Icons.circle,
                                      color: Colors.red, size: 12)
                                  : const Icon(Icons.check,
                                      color: Colors.green),
                              onTap: () => Navigator.of(context).pushNamed(
                                  '/alert-detail',
                                  arguments: a.id),
                            ),
                          );
                        },
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('Could not load alerts (offline?).')),
            ),
          ),
        ],
      ),
    );
  }
}
