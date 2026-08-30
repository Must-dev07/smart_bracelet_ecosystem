// Alerts list: status/severity filters, search, and an at-a-glance status
// dot that distinguishes untouched-active from acknowledged-but-still-open
// (Section 8: filtering + a lightweight audit trail).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
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
  String? _severity;
  String _query = '';

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by baby or alert type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _severity,
                  hint: const Text('Severity'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                  ],
                  onChanged: (v) => setState(() => _severity = v),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: DisclaimerBanner(),
          ),
          Expanded(
            child: alerts.when(
              data: (list) {
                final filtered = list.where((a) {
                  if (_severity != null && a.severity != _severity) return false;
                  if (_query.isEmpty) return true;
                  return a.babyName.toLowerCase().contains(_query) ||
                      a.type.toLowerCase().contains(_query);
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('No alerts match the current filters.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(alertsProvider),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final a = filtered[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: SeverityBadge(severity: a.severity),
                          title: Text(a.type.replaceAll('_', ' ')),
                          subtitle: Text(
                              '${a.babyName} · ${a.triggeredAt.toLocal().toString().split('.').first}'
                              '${a.acknowledgedAt != null && a.isActive ? ' · acknowledged' : ''}'),
                          trailing: _StatusDot(alert: a),
                          onTap: () => Navigator.of(context).pushNamed(
                              '/alert-detail',
                              arguments: a.id),
                        ),
                      );
                    },
                  ),
                );
              },
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

/// Red = untouched and active, amber = active but someone's acknowledged it,
/// green = resolved.
class _StatusDot extends StatelessWidget {
  final Alert alert;
  const _StatusDot({required this.alert});

  @override
  Widget build(BuildContext context) {
    if (!alert.isActive) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    }
    if (alert.acknowledgedAt != null) {
      return const Icon(Icons.remove_red_eye, color: Colors.amber, size: 20);
    }
    return const Icon(Icons.circle, color: Colors.red, size: 12);
  }
}
